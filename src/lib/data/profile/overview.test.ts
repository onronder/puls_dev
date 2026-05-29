import { afterEach, describe, expect, it, vi } from 'vitest'

import {
  buildEmptyProfileOverview,
  buildProfileAccountLinkStatus,
  buildProfileOverviewFromDemo,
  fetchProfileOverviewWithMeta,
  isProfileOverviewEmpty,
} from '#/lib/data/profile/overview'
import type { DemoProfileOverview } from '#/lib/demo/puls-demo-data'

vi.mock('#/lib/data/demo-mode', () => ({
  isPulsDemoModeEnabled: vi.fn(),
}))

vi.mock('#/lib/data/client', () => ({
  pulsCalc: vi.fn(),
  pulsCore: vi.fn(),
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

function mockTenantContextWithoutEmployee() {
  return {
    tenantId: 'tenant-1',
    tenantName: 'Mert Teknik A.Ş.',
    employeeId: null,
    employeeName: null,
    personaRole: 'employee' as const,
  }
}

describe('buildProfileAccountLinkStatus', () => {
  it('returns linked_employee when employee id exists', () => {
    expect(
      buildProfileAccountLinkStatus({ tenantId: 'tenant-1', employeeId: 'employee-1' }),
    ).toBe('linked_employee')
  })

  it('returns tenant_without_employee when tenant exists without employee', () => {
    expect(buildProfileAccountLinkStatus({ tenantId: 'tenant-1', employeeId: null })).toBe(
      'tenant_without_employee',
    )
  })

  it('returns no_tenant when tenant is missing', () => {
    expect(buildProfileAccountLinkStatus({ tenantId: null, employeeId: null })).toBe('no_tenant')
  })
})

describe('buildEmptyProfileOverview', () => {
  it('carries tenant name and account link status from context', () => {
    const profile = buildEmptyProfileOverview(mockTenantContextWithoutEmployee())

    expect(profile.tenantName).toBe('Mert Teknik A.Ş.')
    expect(profile.accountLinkStatus).toBe('tenant_without_employee')
    expect(profile.employeeLinked).toBe(false)
  })
})

describe('isProfileOverviewEmpty', () => {
  it('returns true only for no_tenant', () => {
    expect(isProfileOverviewEmpty(buildEmptyProfileOverview(mockTenantContextWithoutTenant()))).toBe(
      true,
    )
  })

  it('returns false for tenant_without_employee so demo does not mask readiness', () => {
    expect(
      isProfileOverviewEmpty(buildEmptyProfileOverview(mockTenantContextWithoutEmployee())),
    ).toBe(false)
  })
})

describe('buildProfileOverviewFromDemo', () => {
  it('preserves demo metrics and marks linked demo metadata', () => {
    const demo = {
      fallbackEmail: 'demo@example.com',
      departmentKey: 'profileSetup.fields.departmentValue',
      positionKey: 'profileSetup.fields.positionValue',
      roleKey: 'profileSetup.fields.roleValue',
      statusKey: 'profileSetup.status.active',
      leaveRemaining: 8,
      leaveTotal: 14,
      leaveHintKey: 'profileSetup.selfHr.leaveHint',
      pendingExpenseAmount: 500,
      pendingExpenseCount: 1,
      performanceCycleKey: '2026 Q1',
      performanceHintKey: 'profileSetup.selfHr.performanceHint',
      recentActivities: [{ id: 'a1', who: 'Ayşe', whatKey: 'x', whenKey: 'y' }],
    } satisfies DemoProfileOverview

    const profile = buildProfileOverviewFromDemo(demo)

    expect(profile.leaveRemaining).toBe(8)
    expect(profile.recentActivities).toHaveLength(1)
    expect(profile.tenantName).toBe('Mert Teknik A.Ş.')
    expect(profile.employeeLinked).toBe(true)
    expect(profile.accountLinkStatus).toBe('linked_employee')
  })
})

describe('fetchProfileOverviewWithMeta', () => {
  afterEach(() => {
    demoEnabled.mockReset()
    resolveTenant.mockReset()
  })

  it('returns real empty when demo mode is off and tenant is missing', async () => {
    demoEnabled.mockReturnValue(false)
    resolveTenant.mockResolvedValue(mockTenantContextWithoutTenant())

    const result = await fetchProfileOverviewWithMeta('user-1')

    expect(result).toEqual({
      source: 'real',
      status: 'empty',
      data: buildEmptyProfileOverview(mockTenantContextWithoutTenant()),
    })
  })

  it('returns demo success when demo mode is on and tenant is missing', async () => {
    demoEnabled.mockReturnValue(true)
    resolveTenant.mockResolvedValue(mockTenantContextWithoutTenant())

    const result = await fetchProfileOverviewWithMeta('user-1')

    expect(result.source).toBe('demo')
    expect(result.status).toBe('success')
    expect(result.data.employeeLinked).toBe(true)
    expect(result.data.recentActivities.length).toBeGreaterThan(0)
  })

  it('returns real success for tenant_without_employee when demo mode is on', async () => {
    demoEnabled.mockReturnValue(true)
    resolveTenant.mockResolvedValue(mockTenantContextWithoutEmployee())

    const result = await fetchProfileOverviewWithMeta('user-1')

    expect(result.source).toBe('real')
    expect(result.status).toBe('success')
    expect(result.data.accountLinkStatus).toBe('tenant_without_employee')
    expect(result.data.employeeLinked).toBe(false)
    expect(result.data.tenantName).toBe('Mert Teknik A.Ş.')
  })
})
