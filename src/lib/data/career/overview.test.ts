import { afterEach, describe, expect, it, vi } from 'vitest'

import { fetchCareerOverviewWithMeta } from '#/lib/data/career/overview'

vi.mock('#/lib/data/demo-mode', () => ({
  isPulsDemoModeEnabled: vi.fn(),
}))

vi.mock('#/lib/data/client', () => ({
  pulsCore: vi.fn(),
  pulsPerformance: vi.fn(),
  resolveTenantContext: vi.fn(),
}))

import { isPulsDemoModeEnabled } from '#/lib/data/demo-mode'
import { resolveTenantContext } from '#/lib/data/client'

const demoEnabled = vi.mocked(isPulsDemoModeEnabled)
const resolveTenant = vi.mocked(resolveTenantContext)

function mockTenantContextWithoutEmployee() {
  return {
    tenantId: 'tenant-1',
    tenantName: 'Tenant',
    employeeId: null,
    employeeName: null,
    personaRole: 'employee' as const,
  }
}

describe('fetchCareerOverviewWithMeta', () => {
  afterEach(() => {
    demoEnabled.mockReset()
    resolveTenant.mockReset()
  })

  it('real empty tenant returns source real and status empty', async () => {
    demoEnabled.mockReturnValue(false)
    resolveTenant.mockResolvedValue(mockTenantContextWithoutEmployee())

    const result = await fetchCareerOverviewWithMeta('user-1')

    expect(result.source).toBe('real')
    expect(result.status).toBe('empty')
    expect(result.data.careerLadder).toEqual([])
    expect(result.data.careerGaps).toEqual([])
  })

  it('uses demo fixture when demo mode is on and real is empty', async () => {
    demoEnabled.mockReturnValue(true)
    resolveTenant.mockResolvedValue(mockTenantContextWithoutEmployee())

    const result = await fetchCareerOverviewWithMeta('user-1')

    expect(result.source).toBe('demo')
    expect(result.status).toBe('success')
    expect(result.data.careerLadder.length).toBeGreaterThan(0)
    expect(result.data.readinessPercent).toBeGreaterThan(0)
  })
})
