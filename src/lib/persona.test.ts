import { beforeEach, describe, expect, it, vi } from 'vitest'

import { resolvePersonaForUser } from '#/lib/persona'

type QueryResult = {
  data: unknown
  error: null
}

const queryResults = new Map<string, QueryResult>()

vi.mock('#/lib/supabase', () => {
  function makeQuery(key: string) {
    const chain = {
      select: vi.fn(() => chain),
      eq: vi.fn(() => chain),
      order: vi.fn(() => chain),
      limit: vi.fn(() => chain),
      maybeSingle: vi.fn(async () => queryResults.get(key) ?? { data: null, error: null }),
    }
    return chain
  }

  return {
    supabase: {
      schema: vi.fn((schemaName: string) => ({
        from: vi.fn((tableName: string) => makeQuery(`${schemaName}.${tableName}`)),
      })),
      from: vi.fn((tableName: string) => makeQuery(`public.${tableName}`)),
    },
  }
})

describe('resolvePersonaForUser', () => {
  beforeEach(() => {
    queryResults.clear()
  })

  it('uses puls_core employee links before legacy public membership', async () => {
    queryResults.set('puls_core.employees', {
      data: { persona_role: 'superadmin', tenant_id: 'core-tenant-1' },
      error: null,
    })
    queryResults.set('public.user_tenants', {
      data: { tenant_id: 'legacy-tenant-1', is_default: true },
      error: null,
    })

    await expect(resolvePersonaForUser('user-1')).resolves.toEqual({
      personaRole: 'superadmin',
      tenantId: 'core-tenant-1',
    })
  })

  it('keeps legacy public role fallback when no puls_core employee is linked', async () => {
    queryResults.set('public.user_tenants', {
      data: { tenant_id: 'legacy-tenant-1', is_default: true },
      error: null,
    })
    queryResults.set('public.user_roles', {
      data: { role: 'admin' },
      error: null,
    })

    await expect(resolvePersonaForUser('user-2')).resolves.toEqual({
      personaRole: 'hr_admin',
      tenantId: 'legacy-tenant-1',
    })
  })
})
