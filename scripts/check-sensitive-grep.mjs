#!/usr/bin/env node
/**
 * Tiered sensitive-field grep for 09 migrations.
 * Allows literals only inside redact block-list markers and 09 smoke negative tests.
 */
import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve(import.meta.dirname, '..')

const SENSITIVE_PATTERN =
  /(?<![a-z_])(salary|salary_min|salary_max|maas|pay_band|payroll|compensation|tckn|iban|birth_date|dogum_tarihi|health|saglik|family|aile)(?![a-z_])/gi

const LEGACY_ALLOWLIST = new Set([
  'supabase/migrations/20260523143000_puls_schema_foundation.sql',
  'supabase/migrations/20260520130000_puls_on_lovable_auth.sql',
  'supabase/seed-demo.sql',
])

const CANONICAL_CONTEXT =
  /(CREATE TABLE|ADD COLUMN|target_field|target_table|canonical_table|canonical_schema|INSERT INTO puls_integration\.erp_field_mappings)/i

const RAW_PAYLOAD_FAIL = /raw_payload\s*=\s*(?!NULL)/i

function stripBlockListRegions(content) {
  const begin = '-- SENSITIVE_BLOCK_LIST_BEGIN'
  const end = '-- SENSITIVE_BLOCK_LIST_END'
  let result = ''
  let cursor = 0

  while (cursor < content.length) {
    const start = content.indexOf(begin, cursor)
    if (start === -1) {
      result += content.slice(cursor)
      break
    }
    result += content.slice(cursor, start)
    const finish = content.indexOf(end, start)
    if (finish === -1) {
      throw new Error('Unclosed SENSITIVE_BLOCK_LIST_BEGIN marker')
    }
    cursor = finish + end.length
  }

  return result
}

function rel(filePath) {
  return path.relative(root, filePath).split(path.sep).join('/')
}

function scanFile(filePath, { allowAll = false, checkCanonical = true, checkRawPayload = false } = {}) {
  const content = fs.readFileSync(filePath, 'utf8')
  const scanned = allowAll ? '' : stripBlockListRegions(content)
  const failures = []

  if (!allowAll) {
    for (const [index, line] of scanned.split('\n').entries()) {
      SENSITIVE_PATTERN.lastIndex = 0
      if (SENSITIVE_PATTERN.test(line)) {
        failures.push({ line: index + 1, text: line.trim(), reason: 'sensitive token outside allowlisted block-list region' })
      }
    }
  }

  if (checkCanonical) {
    for (const [index, line] of content.split('\n').entries()) {
      SENSITIVE_PATTERN.lastIndex = 0
      if (SENSITIVE_PATTERN.test(line) && CANONICAL_CONTEXT.test(line)) {
        failures.push({ line: index + 1, text: line.trim(), reason: 'sensitive token in canonical/mapping context' })
      }
    }
  }

  if (checkRawPayload) {
    for (const [index, line] of content.split('\n').entries()) {
      if (RAW_PAYLOAD_FAIL.test(line)) {
        failures.push({ line: index + 1, text: line.trim(), reason: 'non-NULL raw_payload assignment' })
      }
    }
  }

  return failures
}

function globFiles(patternDir, patternPrefix) {
  const dir = path.join(root, patternDir)
  if (!fs.existsSync(dir)) return []
  return fs
    .readdirSync(dir)
    .filter((name) => name.startsWith(patternPrefix))
    .map((name) => path.join(dir, name))
}

function globSmokeFiles() {
  const dir = path.join(root, 'docs/data')
  if (!fs.existsSync(dir)) return []
  return fs
    .readdirSync(dir)
    .filter((name) => /^09_.*_smoke\.sql$/.test(name))
    .map((name) => path.join(dir, name))
}

function walkDir(dir) {
  if (!fs.existsSync(dir)) return []
  const out = []
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name)
    if (entry.isDirectory()) out.push(...walkDir(full))
    else if (/\.(ts|tsx|js|jsx|mjs)$/.test(entry.name)) out.push(full)
  }
  return out
}

const failures = []

for (const file of globFiles('supabase/migrations', '20260525')) {
  if (LEGACY_ALLOWLIST.has(rel(file))) continue
  for (const hit of scanFile(file, { checkCanonical: true, checkRawPayload: true })) {
    failures.push({ file: rel(file), ...hit })
  }
}

for (const file of globSmokeFiles()) {
  for (const hit of scanFile(file, { allowAll: true, checkCanonical: false, checkRawPayload: true })) {
    failures.push({ file: rel(file), ...hit })
  }
}

for (const dir of ['src/lib/data', 'src/routes/_app']) {
  for (const file of walkDir(path.join(root, dir))) {
    const content = fs.readFileSync(file, 'utf8')
    for (const [index, line] of content.split('\n').entries()) {
      SENSITIVE_PATTERN.lastIndex = 0
      if (SENSITIVE_PATTERN.test(line)) {
        failures.push({
          file: rel(file),
          line: index + 1,
          text: line.trim(),
          reason: 'sensitive token in frontend/data adapter code',
        })
      }
    }
  }
}

if (failures.length) {
  console.error('Sensitive grep failed:')
  for (const f of failures) {
    console.error(`${f.file}:${f.line}: ${f.reason}`)
    console.error(`  ${f.text}`)
  }
  process.exit(1)
}

console.log('Sensitive grep OK')
