import { afterEach, describe, expect, it, vi } from 'vitest'

import {
  buildDemoSettingsOverview,
  fetchSettingsOverviewWithMeta,
} from '#/lib/data/settings/overview'

vi.mock('#/lib/data/demo-mode', () => ({
  isPulsDemoModeEnabled: vi.fn(),
}))

vi.mock('#/lib/data/client', () => ({
  pulsAudit: vi.fn(),
  pulsCalc: vi.fn(),
  pulsIntegration: vi.fn(),
  resolveTenantContext: vi.fn(),
}))

import { isPulsDemoModeEnabled } from '#/lib/data/demo-mode'
import {
  pulsAudit,
  pulsCalc,
  pulsIntegration,
  resolveTenantContext,
} from '#/lib/data/client'

const demoEnabled = vi.mocked(isPulsDemoModeEnabled)
const resolveTenant = vi.mocked(resolveTenantContext)

type QueryResult = {
  data?: unknown
  error?: unknown
  count?: number | null
}

function query(result: QueryResult) {
  const builder = {
    select: vi.fn(() => builder),
    eq: vi.fn(() => builder),
    gte: vi.fn(() => builder),
    order: vi.fn(() => builder),
    limit: vi.fn(() => builder),
    maybeSingle: vi.fn(async () => ({
      data: result.data ?? null,
      error: result.error ?? null,
    })),
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

function mockTenantContext() {
  return {
    tenantId: 'a0000001-0001-4001-8001-000000000001',
    tenantName: 'Puls Teknik',
    employeeId: 'employee-1',
    employeeName: 'Admin User',
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

function setupSeededMocks() {
  resolveTenant.mockResolvedValue(mockTenantContext())
  vi.mocked(pulsCalc).mockImplementation(
    () =>
      client({
        setup_readiness_summary: {
          data: {
            core_setup_pct: 100,
            workflow_setup_pct: 100,
            integration_setup_pct: 100,
            performance_setup_pct: 100,
            overall_readiness_pct: 100,
          },
          error: null,
        },
      }) as never,
  )
  vi.mocked(pulsIntegration).mockImplementation(
    () =>
      client({
        erp_connections: {
          data: {
            provider: 'canias',
            display_name: 'Canias',
            is_active: false,
            is_enabled: true,
            setup_status: 'preflight_ready',
            setup_step: 'preflight',
          },
          error: null,
        },
        erp_field_mappings: { count: 12, error: null },
        source_namespaces: { count: 1, error: null },
      }) as never,
  )
  vi.mocked(pulsAudit).mockImplementation(
    () =>
      client({
        audit_logs: { count: 7, error: null },
      }) as never,
  )
}

describe('settings overview adapter', () => {
  afterEach(() => {
    vi.clearAllMocks()
  })

  it('returns tenant-scoped settings state for a seeded admin tenant', async () => {
    demoEnabled.mockReturnValue(false)
    setupSeededMocks()

    const result = await fetchSettingsOverviewWithMeta('user-1')

    expect(result.source).toBe('real')
    expect(result.status).toBe('success')
    expect(result.data.auditLogSensitiveCount).toBe(7)
    expect(result.data.sections.find((section) => section.id === 'tenant')?.value).toEqual({
      text: 'Puls Teknik',
    })
    expect(result.data.sections.find((section) => section.id === 'accountSecurity')?.status).toBe(
      'ready',
    )
    expect(result.data.sections.find((section) => section.id === 'roleAccess')?.status).toBe(
      'ready',
    )
    expect(result.data.sections.find((section) => section.id === 'notifications')).toMatchObject({
      status: 'ready',
      value: { key: 'settingsSetup.values.enabled' },
      helperKey: 'settingsSetup.helpers.notificationsReady',
    })
    expect(result.data.setupHubItems.find((item) => item.to === '/erp')).toMatchObject({
      status: 'ready',
      value: { key: 'settingsSetup.values.preflightReady' },
      hintKey: 'settingsSetup.setupHub.hints.connectorMapped',
    })
  })

  it('keeps a real locked settings state when tenant context is missing', async () => {
    demoEnabled.mockReturnValue(true)
    resolveTenant.mockResolvedValue(mockTenantContextWithoutTenant())

    const result = await fetchSettingsOverviewWithMeta('user-1')

    expect(result.source).toBe('real')
    expect(result.status).toBe('success')
    expect(result.data.sections.find((section) => section.id === 'tenant')?.status).toBe('locked')
    expect(result.data.sections.find((section) => section.id === 'notifications')?.status).toBe(
      'locked',
    )
    expect(result.data.setupHubItems.every((item) => item.status === 'locked')).toBe(true)
  })

  it('enriches legacy demo settings into product-owned section state', async () => {
    const overview = await buildDemoSettingsOverview()

    expect(overview.sections).toHaveLength(6)
    expect(overview.sections.every((section) => section.evidence.length > 0)).toBe(true)
    expect(overview.setupHubItems.map((item) => item.to)).toContain('/erp')
  })
})
