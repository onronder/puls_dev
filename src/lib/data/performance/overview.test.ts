import { afterEach, describe, expect, it, vi } from 'vitest'

import { fetchPerformanceOverviewWithMeta } from '#/lib/data/performance/overview'

vi.mock('#/lib/data/demo-mode', () => ({
  isPulsDemoModeEnabled: vi.fn(),
}))

vi.mock('#/lib/data/client', () => ({
  pulsCalc: vi.fn(),
  pulsCore: vi.fn(),
  pulsPerformance: vi.fn(),
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
    personaRole: 'manager' as const,
  }
}

describe('fetchPerformanceOverviewWithMeta', () => {
  afterEach(() => {
    demoEnabled.mockReset()
    resolveTenant.mockReset()
  })

  it('real empty tenant returns source real and status empty', async () => {
    demoEnabled.mockReturnValue(false)
    resolveTenant.mockResolvedValue(mockTenantContextWithoutTenant())

    const result = await fetchPerformanceOverviewWithMeta('user-1')

    expect(result.source).toBe('real')
    expect(result.status).toBe('empty')
    expect(result.data.employeeScopeCount).toBe(0)
    expect(result.data.templateDisplayByIndex).toEqual([])
  })

  it('uses demo fixture when demo mode is on and real is empty', async () => {
    demoEnabled.mockReturnValue(true)
    resolveTenant.mockResolvedValue(mockTenantContextWithoutTenant())

    const result = await fetchPerformanceOverviewWithMeta('user-1')

    expect(result.source).toBe('demo')
    expect(result.status).toBe('success')
    expect(result.data.employeeScopeCount).toBeGreaterThan(0)
    expect(result.data.templateDisplayByIndex.length).toBeGreaterThan(0)
  })
})
