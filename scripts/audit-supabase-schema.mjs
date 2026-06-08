#!/usr/bin/env node
/**
 * Read-only schema audit for an existing Supabase project.
 * Run locally after filling .env.local (never commit keys), or in CI with
 * VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY configured.
 *
 *   node scripts/audit-supabase-schema.mjs
 */
import { createClient } from '@supabase/supabase-js'
import { readFileSync, existsSync } from 'node:fs'
import { resolve } from 'node:path'

function parseEnvFile(path) {
  const env = {}
  for (const line of readFileSync(path, 'utf8').split('\n')) {
    const trimmed = line.trim()
    if (!trimmed || trimmed.startsWith('#')) continue
    const eq = trimmed.indexOf('=')
    if (eq === -1) continue
    env[trimmed.slice(0, eq).trim()] = trimmed.slice(eq + 1).trim()
  }
  return env
}

function loadAuditEnv() {
  const env = {
    VITE_SUPABASE_URL: process.env.VITE_SUPABASE_URL,
    VITE_SUPABASE_ANON_KEY: process.env.VITE_SUPABASE_ANON_KEY,
  }

  if (env.VITE_SUPABASE_URL && env.VITE_SUPABASE_ANON_KEY) return env

  const path = resolve(process.cwd(), '.env.local')
  if (!existsSync(path)) {
    if (process.env.GITHUB_ACTIONS === 'true') return env
    console.error('Missing .env.local — run: cp .env.example .env.local')
    process.exit(1)
  }

  const fileEnv = parseEnvFile(path)
  return {
    ...fileEnv,
    VITE_SUPABASE_URL: env.VITE_SUPABASE_URL ?? fileEnv.VITE_SUPABASE_URL,
    VITE_SUPABASE_ANON_KEY: env.VITE_SUPABASE_ANON_KEY ?? fileEnv.VITE_SUPABASE_ANON_KEY,
  }
}

const LOVABLE_TABLES = ['profiles', 'tenants', 'user_tenants', 'user_roles', 'audit_log']

const PULS_TABLES = [
  'departments',
  'positions',
  'employees',
  'erp_connections',
  'erp_field_mappings',
  'erp_sync_logs',
  'performans_competency_templates',
]

async function tableExists(supabase, table, schema = 'public') {
  const { data, error } = await supabase
    .schema(schema)
    .from(table)
    .select('*', { count: 'exact', head: true })
  if (error) {
    const msg = error.message ?? ''
    if (msg.includes('does not exist') || error.code === '42P01') return false
    return { error: msg, code: error.code }
  }
  return true
}

async function main() {
  const env = loadAuditEnv()
  const url = env.VITE_SUPABASE_URL
  const key = env.VITE_SUPABASE_ANON_KEY
  if (!url || !key) {
    if (process.env.GITHUB_ACTIONS === 'true') {
      console.log(
        'Supabase schema audit skipped: VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY are not configured for CI.',
      )
      return
    }

    console.error(
      'Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY in .env.local or the environment',
    )
    process.exit(1)
  }

  const supabase = createClient(url, key)
  console.log('Supabase schema audit\n')
  console.log(`Project URL: ${url}\n`)

  console.log('--- Lovable auth tables ---')
  for (const table of LOVABLE_TABLES) {
    const result = await tableExists(supabase, table)
    if (result === true) console.log(`  ✓ public.${table}`)
    else if (result === false) console.log(`  ✗ public.${table} (missing)`)
    else console.log(`  ? public.${table} — ${result.error}`)
  }

  console.log('\n--- Puls product tables ---')
  for (const table of PULS_TABLES) {
    const result = await tableExists(supabase, table)
    if (result === true) console.log(`  ✓ public.${table}`)
    else if (result === false) console.log(`  ✗ public.${table} (not migrated yet)`)
    else console.log(`  ? public.${table} — ${result.error}`)
  }

  const auditSchema = await tableExists(supabase, 'audit_logs', 'puls_audit')
  console.log('\n--- Audit ---')
  if (auditSchema === true) console.log('  ✓ puls_audit.audit_logs (Puls)')
  else console.log('  ○ puls_audit.audit_logs missing — will use public.audit_log if present')

  const { data: session } = await supabase.auth.getSession()
  console.log('\n--- Auth session ---')
  console.log(
    session.session
      ? `  Logged in as ${session.session.user.email}`
      : '  No active session (expected for audit script)',
  )
}

main().catch((err) => {
  console.error(err)
  process.exit(1)
})
