import { afterEach, describe, expect, it, vi } from 'vitest'

import {
  buildDemoErpOverview,
  fetchErpOverviewWithMeta,
  isErpOverviewEmpty,
  mapProviderLabel,
} from '#/lib/data/setup/erp'

vi.mock('#/lib/data/demo-mode', () => ({
  isPulsDemoModeEnabled: vi.fn(),
}))

vi.mock('#/lib/data/client', () => ({
  pulsCalc: vi.fn(),
  pulsIntegration: vi.fn(),
  resolveTenantContext: vi.fn(),
}))

import { isPulsDemoModeEnabled } from '#/lib/data/demo-mode'
import { pulsCalc, pulsIntegration, resolveTenantContext } from '#/lib/data/client'

const demoEnabled = vi.mocked(isPulsDemoModeEnabled)
const resolveTenant = vi.mocked(resolveTenantContext)

function mockTenantContext() {
  return {
    tenantId: 'a0000001-0001-4001-8001-000000000001',
    tenantName: 'Puls Teknik',
    employeeId: 'a0000006-0006-4006-8006-000000000001',
    employeeName: 'Test User',
    personaRole: 'superadmin' as const,
  }
}

function mockTenantContextWithoutTenant() {
  return {
    tenantId: null,
    tenantName: null,
    employeeId: null,
    employeeName: null,
    personaRole: 'employee' as const,
  }
}

type QueryResult = { data?: unknown; error?: unknown }

function query(result: QueryResult) {
  const builder = {
    select: vi.fn(() => builder),
    eq: vi.fn(() => builder),
    order: vi.fn(() => builder),
    limit: vi.fn(() => builder),
    maybeSingle: vi.fn(async () => result),
    then(onFulfilled: (value: QueryResult) => unknown, onRejected?: (reason: unknown) => unknown) {
      return Promise.resolve(result).then(onFulfilled, onRejected)
    },
  }
  return builder
}

function client(results: Record<string, QueryResult>) {
  return {
    from: vi.fn((table: string) => query(results[table] ?? { data: [], error: null })),
  }
}

function setupSeededMocks(overrides: Partial<Record<string, QueryResult>> = {}) {
  resolveTenant.mockResolvedValue(mockTenantContext())
  vi.mocked(pulsIntegration).mockImplementation(
    () =>
      client({
        erp_connections: {
          data: {
            provider: 'canias',
            display_name: 'Canias ERP (Pasif)',
            is_active: false,
            last_sync_at: null,
            last_status: null,
          },
        },
        erp_field_mappings: {
          data: [
            {
              source_entity: 'employee',
              source_field: 'EMPLOYEE_CODE',
              target_schema: 'puls_core',
              target_table: 'employees',
              target_field: 'employee_code',
              is_required: false,
              is_sensitive: false,
              is_active: true,
            },
            {
              source_entity: 'employee',
              source_field: 'REDACTED_FIELD',
              target_schema: 'puls_core',
              target_table: 'employees',
              target_field: 'private_marker',
              is_required: false,
              is_sensitive: true,
              is_active: true,
            },
          ],
        },
        erp_sync_batches: { data: [] },
        source_namespaces: {
          data: [
            {
              id: 'namespace-1',
              code: 'CANIAS',
              name: 'Canias ERP Kaynagi',
              source_type: 'erp',
            },
          ],
        },
        entity_identity_map: {
          data: [{ source_namespace_id: 'namespace-1', canonical_table: 'departments' }],
        },
        ...overrides,
      }) as never,
  )
  vi.mocked(pulsCalc).mockImplementation(
    () =>
      client({
        setup_readiness_summary: { data: { integration_setup_pct: 80 }, error: null },
      }) as never,
  )
}

describe('ERP connector overview helpers', () => {
  afterEach(() => {
    vi.clearAllMocks()
  })

  it('does not collapse unknown providers into Canias', () => {
    expect(mapProviderLabel('logo')).toBe('Logo')
    expect(mapProviderLabel('workday_custom')).toBe('Workday Custom')
    expect(mapProviderLabel(null)).toBe('External data source')
  })

  it('enriches the legacy demo ERP payload into connector overview shape', async () => {
    const overview = await buildDemoErpOverview()

    expect(overview.provider.code).toBe('canias')
    expect(overview.readiness.checks.length).toBeGreaterThan(0)
    expect(overview.guardrails.some((guardrail) => guardrail.id === 'no_erp_writes')).toBe(true)
    expect(isErpOverviewEmpty(overview)).toBe(false)
  })
})

describe('fetchErpOverviewWithMeta', () => {
  afterEach(() => {
    vi.clearAllMocks()
  })

  it('returns real connector preflight data and hides sensitive field mappings', async () => {
    demoEnabled.mockReturnValue(false)
    setupSeededMocks()

    const result = await fetchErpOverviewWithMeta('user-1')

    expect(result.source).toBe('real')
    expect(result.status).toBe('success')
    expect(result.data.provider.label).toBe('Canias ERP (Pasif)')
    expect(result.data.provider.status).toBe('runtime_inactive')
    expect(result.data.namespaces).toHaveLength(1)
    expect(result.data.mappings).toHaveLength(1)
    expect(result.data.mappings[0].canonicalField).toBe('puls_core.employees.employee_code')
    expect(result.data.mappings.some((mapping) => mapping.sourceField === 'REDACTED_FIELD')).toBe(
      false,
    )
  })

  it('returns real empty when tenant is missing and demo mode is off', async () => {
    demoEnabled.mockReturnValue(false)
    resolveTenant.mockResolvedValue(mockTenantContextWithoutTenant())

    const result = await fetchErpOverviewWithMeta('user-1')

    expect(result.source).toBe('real')
    expect(result.status).toBe('empty')
    expect(result.data.readiness.status).toBe('blocked')
  })

  it('returns real no-connector onboarding state without demo fallback', async () => {
    demoEnabled.mockReturnValue(true)
    setupSeededMocks({
      erp_connections: { data: null, error: null },
      erp_field_mappings: { data: [], error: null },
      erp_sync_batches: { data: [], error: null },
      source_namespaces: { data: [], error: null },
      entity_identity_map: { data: [], error: null },
    })

    const result = await fetchErpOverviewWithMeta('user-1')

    expect(result.source).toBe('real')
    expect(result.status).toBe('success')
    expect(result.data.connectorState).toBe('no_connector')
    expect(result.data.providerOptions.map((option) => option.id)).toEqual([
      'canias',
      'logo',
      'csv_import',
      'custom_api',
    ])
    expect(isErpOverviewEmpty(result.data)).toBe(false)
  })

  it('uses enriched demo fallback only when demo mode is enabled', async () => {
    demoEnabled.mockReturnValue(true)
    resolveTenant.mockResolvedValue(mockTenantContextWithoutTenant())

    const result = await fetchErpOverviewWithMeta('user-1')

    expect(result.source).toBe('demo')
    expect(result.status).toBe('success')
    expect(result.fallbackReason).toBe('empty')
    expect(result.data.provider.code).toBe('canias')
    expect(result.data.guardrails.length).toBeGreaterThan(0)
  })

  it('keeps provider labels source-neutral for non-Canias providers', async () => {
    demoEnabled.mockReturnValue(false)
    setupSeededMocks({
      erp_connections: {
        data: {
          provider: 'logo',
          display_name: null,
          is_active: false,
          last_sync_at: null,
          last_status: null,
        },
      },
    })

    const result = await fetchErpOverviewWithMeta('user-1')

    expect(result.source).toBe('real')
    expect(result.data.provider.label).toBe('Logo')
    expect(result.data.status.system).toBe('Logo')
  })
})
