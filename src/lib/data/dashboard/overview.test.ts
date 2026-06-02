import { afterEach, describe, expect, it, vi } from 'vitest'

import {
  buildDashboardErpStatus,
  buildDashboardPageDataFromDemo,
  buildDashboardQueue,
  emptyDashboardPageData,
  fetchDashboardOverviewWithMeta,
  isDashboardEmpty,
  mapDashboardErpProvider,
} from '#/lib/data/dashboard/overview'
import type { DemoDashboardOverview } from '#/lib/demo/puls-demo-data'

vi.mock('#/lib/data/demo-mode', () => ({
  isPulsDemoModeEnabled: vi.fn(),
}))

vi.mock('#/lib/data/client', () => ({
  pulsCalc: vi.fn(),
  pulsIntegration: vi.fn(),
  pulsWorkflow: vi.fn(),
  resolveTenantContext: vi.fn(),
}))

import { isPulsDemoModeEnabled } from '#/lib/data/demo-mode'
import { resolveTenantContext } from '#/lib/data/client'

const demoEnabled = vi.mocked(isPulsDemoModeEnabled)
const resolveTenant = vi.mocked(resolveTenantContext)

function mockTenantContextWithoutTenant() {
  return {
    tenantId: null,
    tenantName: null,
    employeeId: null,
    employeeName: null,
    personaRole: 'employee' as const,
  }
}

describe('isDashboardEmpty', () => {
  it('returns true for all-zero baseline data', () => {
    expect(isDashboardEmpty(emptyDashboardPageData())).toBe(true)
  })

  it('returns false when any real metric is present', () => {
    const data = emptyDashboardPageData()
    data.stats.employeeCount = 1
    expect(isDashboardEmpty(data)).toBe(false)

    const erpData = emptyDashboardPageData()
    erpData.overview.erpStatus.mappedFields = 2
    expect(isDashboardEmpty(erpData)).toBe(false)
  })
})

describe('buildDashboardQueue', () => {
  const base = {
    activeCycleName: '2026 Q1',
    mappedFields: 10,
    totalFields: 10,
    pendingLeave: 0,
    pendingExpense: 0,
  }

  it('adds performance queue item when no active cycle exists', () => {
    const queue = buildDashboardQueue({ ...base, activeCycleName: null })
    expect(queue.map((item) => item.id)).toContain('q1')
  })

  it('adds ERP mapping queue item when mapping is incomplete', () => {
    const queue = buildDashboardQueue({ ...base, mappedFields: 3, totalFields: 10 })
    expect(queue.map((item) => item.id)).toContain('q2')
  })

  it('adds leave and expense queue items when pending counts are positive', () => {
    const queue = buildDashboardQueue({ ...base, pendingLeave: 2, pendingExpense: 1 })
    expect(queue.map((item) => item.id)).toEqual(['q3', 'q4'])
  })

  it('returns an empty queue when all conditions are clear', () => {
    expect(buildDashboardQueue(base)).toEqual([])
  })
})

describe('buildDashboardErpStatus', () => {
  it('uses connected label when ERP is active', () => {
    const status = buildDashboardErpStatus({
      hasConnection: true,
      isActive: true,
      mappedFields: 8,
      totalFields: 10,
      readiness: 80,
    })

    expect(status.statusLabelKey).toBe('dashboardSetup.erpCard.statusConnected')
    expect(status.mappedFields).toBe(8)
    expect(status.totalFields).toBe(10)
    expect(status.readiness).toBe(80)
  })

  it('uses pending label when ERP is inactive', () => {
    const status = buildDashboardErpStatus({
      hasConnection: true,
      isActive: false,
      mappedFields: 0,
      totalFields: 10,
      readiness: 0,
    })

    expect(status.statusLabelKey).toBe('dashboardSetup.erpCard.statusPending')
    expect(status.lastAttemptKey).toBe('dashboardSetup.erpCard.lastAttemptNone')
  })

  it('uses setup draft label when a source is selected but mapping has not started', () => {
    const status = buildDashboardErpStatus({
      hasConnection: true,
      isActive: false,
      setupStatus: 'draft',
      isEnabled: true,
      mappedFields: 0,
      totalFields: 0,
      readiness: 0,
    })

    expect(status.statusLabelKey).toBe('dashboardSetup.erpCard.statusSetupDraft')
    expect(status.descriptionKey).toBe('dashboardSetup.erpCard.descriptionSetupDraft')
  })

  it('uses mapping-ready copy when field contract exists but preflight has not run', () => {
    const status = buildDashboardErpStatus({
      hasConnection: true,
      isActive: false,
      setupStatus: 'mapping_ready',
      isEnabled: true,
      mappedFields: 12,
      totalFields: 12,
      readiness: 57,
    })

    expect(status.statusLabelKey).toBe('dashboardSetup.erpCard.statusMappingReady')
    expect(status.descriptionKey).toBe('dashboardSetup.erpCard.descriptionMappingReady')
  })

  it('uses preflight-ready copy when dry-run checks are complete', () => {
    const status = buildDashboardErpStatus({
      hasConnection: true,
      isActive: false,
      setupStatus: 'preflight_ready',
      isEnabled: true,
      mappedFields: 12,
      totalFields: 12,
      readiness: 100,
    })

    expect(status.statusLabelKey).toBe('dashboardSetup.erpCard.statusPreflightReady')
    expect(status.descriptionKey).toBe('dashboardSetup.erpCard.descriptionPreflightReady')
  })

  it('uses not configured copy when no ERP connection exists', () => {
    const status = buildDashboardErpStatus({
      hasConnection: false,
      isActive: null,
      mappedFields: 0,
      totalFields: 0,
      readiness: 0,
    })

    expect(status.statusLabelKey).toBe('dashboardSetup.erpCard.statusNotConfigured')
    expect(status.descriptionKey).toBe('dashboardSetup.erpCard.descriptionNotConfigured')
    expect(status.lastAttemptKey).toBe('dashboardSetup.erpCard.lastAttemptNone')
  })
})

describe('mapDashboardErpProvider', () => {
  it('maps known provider codes to product labels', () => {
    expect(mapDashboardErpProvider('canias')).toBe('Canias')
    expect(mapDashboardErpProvider('logo')).toBe('Logo')
    expect(mapDashboardErpProvider('csv_import')).toBe('CSV / Excel')
  })

  it('keeps unknown provider names and returns null for empty input', () => {
    expect(mapDashboardErpProvider('custom_erp')).toBe('custom_erp')
    expect(mapDashboardErpProvider(null)).toBeNull()
  })
})

describe('buildDashboardPageDataFromDemo', () => {
  it('composes demo overview, leave, and expense summaries', () => {
    const overview = {
      positionCount: 12,
      queue: [],
      recentActivities: [],
      erpStatus: {
        statusLabelKey: 'dashboardSetup.erpCard.statusPending',
        mappedFields: 6,
        totalFields: 10,
        lastAttemptKey: 'dashboardSetup.erpCard.lastAttemptValue',
        readiness: 60,
        descriptionKey: 'dashboardSetup.erpCard.descriptionPending',
      },
    } satisfies DemoDashboardOverview

    const data = buildDashboardPageDataFromDemo({
      overview,
      leave: {
        heroRemainingAnnual: 9,
        pendingCount: 1,
      } as never,
      expense: {
        monthlyLimit: 20000,
        pendingAmount: 500,
      } as never,
    })

    expect(data.stats.positionCount).toBe(12)
    expect(data.stats.dataReadinessPct).toBe(60)
    expect(data.leaveSummary.heroRemainingAnnual).toBe(9)
    expect(data.expenseSummary.monthlyLimit).toBe(20000)
  })
})

describe('fetchDashboardOverviewWithMeta', () => {
  afterEach(() => {
    demoEnabled.mockReset()
    resolveTenant.mockReset()
  })

  it('returns real empty when demo mode is off and tenant is missing', async () => {
    demoEnabled.mockReturnValue(false)
    resolveTenant.mockResolvedValue(mockTenantContextWithoutTenant())

    const result = await fetchDashboardOverviewWithMeta('user-1')

    expect(result).toEqual({
      source: 'real',
      status: 'empty',
      data: emptyDashboardPageData(),
    })
  })

  it('returns demo success when demo mode is on and tenant is missing', async () => {
    demoEnabled.mockReturnValue(true)
    resolveTenant.mockResolvedValue(mockTenantContextWithoutTenant())

    const result = await fetchDashboardOverviewWithMeta('user-1')

    expect(result.source).toBe('demo')
    expect(result.status).toBe('success')
    expect(result.data.stats.employeeCount).toBeGreaterThan(0)
    expect(result.data.overview.recentActivities.length).toBeGreaterThan(0)
  })
})
