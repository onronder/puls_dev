#!/usr/bin/env node
import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve(import.meta.dirname, '..')
const tr = JSON.parse(fs.readFileSync(path.join(root, 'src/i18n/locales/tr-TR.json'), 'utf8'))
const en = JSON.parse(fs.readFileSync(path.join(root, 'src/i18n/locales/en-US.json'), 'utf8'))

function flatten(obj, prefix = '') {
  return Object.entries(obj).flatMap(([key, value]) => {
    const next = prefix ? `${prefix}.${key}` : key
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      return flatten(value, next)
    }
    return [[next, value]]
  })
}

const trKeys = new Set(flatten(tr).map(([k]) => k))
const enKeys = new Set(flatten(en).map(([k]) => k))

const missingInEn = [...trKeys].filter((k) => !enKeys.has(k))
const missingInTr = [...enKeys].filter((k) => !trKeys.has(k))

if (missingInEn.length || missingInTr.length) {
  console.error('i18n key mismatch')
  if (missingInEn.length) console.error('Missing in en-US:', missingInEn)
  if (missingInTr.length) console.error('Missing in tr-TR:', missingInTr)
  process.exit(1)
}

console.log('i18n keys OK')
