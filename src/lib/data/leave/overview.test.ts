import { afterEach, describe, expect, it, vi } from 'vitest'

import { fetchLeaveOverviewWithMeta, mapLeaveTypeFromLookup } from '#/lib/data/leave/overview'

vi.mock('#/lib/data/demo-mode', () => ({
  isPulsDemoModeEnabled: vi.fn(),
}))

vi.mock('#/lib/data/client', () => ({
  pulsCalc: vi.fn(),
  pulsWorkflow: vi.fn(),
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

describe('mapLeaveTypeFromLookup', () => {
  it('maps active join to typeIsActive true', () => {
    expect(mapLeaveTypeFromLookup({ name: 'Annual', is_active: true })).toEqual({
      typeLabel: 'Annual',
      typeIsActive: true,
    })
  })

  it('maps inactive join to typeIsActive false', () => {
    expect(mapLeaveTypeFromLookup({ name: 'Legacy admin', is_active: false })).toEqual({
      typeLabel: 'Legacy admin',
      typeIsActive: false,
    })
  })

  it('treats missing join as neutral active', () => {
    expect(mapLeaveTypeFromLookup(null)).toEqual({
      typeLabel: '—',
      typeIsActive: true,
    })
  })

  it('treats missing is_active as active when name exists', () => {
    expect(mapLeaveTypeFromLookup({ name: 'Annual' })).toEqual({
      typeLabel: 'Annual',
      typeIsActive: true,
    })
  })

  it('always returns boolean typeIsActive for adapter consumers', () => {
    for (const result of [
      mapLeaveTypeFromLookup({ name: 'Annual', is_active: true }),
      mapLeaveTypeFromLookup({ name: 'Legacy', is_active: false }),
      mapLeaveTypeFromLookup(null),
    ]) {
      expect(typeof result.typeIsActive).toBe('boolean')
    }
  })
})

describe('fetchLeaveOverviewWithMeta', () => {
  afterEach(() => {
    demoEnabled.mockReset()
    resolveTenant.mockReset()
  })

  it('real empty tenant returns source real and status empty', async () => {
    demoEnabled.mockReturnValue(false)
    resolveTenant.mockResolvedValue(mockTenantContextWithoutEmployee())

    const result = await fetchLeaveOverviewWithMeta('user-1')

    expect(result.source).toBe('real')
    expect(result.status).toBe('empty')
    expect(result.data.leaveTypes).toEqual([])
    expect(result.data.requests).toEqual([])
  })

  it('uses demo fixture when demo mode is on and real is empty', async () => {
    demoEnabled.mockReturnValue(true)
    resolveTenant.mockResolvedValue(mockTenantContextWithoutEmployee())

    const result = await fetchLeaveOverviewWithMeta('user-1')

    expect(result.source).toBe('demo')
    expect(result.status).toBe('success')
    expect(result.data.heroTotalAnnual).toBe(20)
    expect(result.data.leaveTypes.length).toBeGreaterThan(0)
    expect(result.data.leaveTypes.every((type) => typeof type.code === 'string')).toBe(true)
  })
})
