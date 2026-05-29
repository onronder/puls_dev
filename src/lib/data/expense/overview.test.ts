import { afterEach, describe, expect, it, vi } from 'vitest'

import {
  fetchExpenseOverviewWithMeta,
  mapClaimCategoryFromJoin,
} from '#/lib/data/expense/overview'

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

function mockTenantContextWithoutTenant() {
  return {
    tenantId: null,
    tenantName: null,
    employeeId: null,
    employeeName: null,
    personaRole: 'employee' as const,
  }
}

describe('mapClaimCategoryFromJoin', () => {
  it('maps active category join without false inactive flag', () => {
    expect(mapClaimCategoryFromJoin({ name: 'Seyahat', is_active: true })).toEqual({
      category: 'Seyahat',
      categoryIsActive: true,
    })
  })

  it('maps inactive category join for historical badge display', () => {
    expect(mapClaimCategoryFromJoin({ name: 'Eski eğitim', is_active: false })).toEqual({
      category: 'Eski eğitim',
      categoryIsActive: false,
    })
  })

  it('returns placeholder category when join is missing', () => {
    expect(mapClaimCategoryFromJoin(null)).toEqual({
      category: '—',
      categoryIsActive: true,
    })
  })

  it('treats join without is_active as active', () => {
    expect(mapClaimCategoryFromJoin({ name: 'Yemek' })).toEqual({
      category: 'Yemek',
      categoryIsActive: true,
    })
  })

  it('always returns boolean categoryIsActive for adapter consumers', () => {
    for (const result of [
      mapClaimCategoryFromJoin({ name: 'Seyahat', is_active: true }),
      mapClaimCategoryFromJoin({ name: 'Eski eğitim', is_active: false }),
      mapClaimCategoryFromJoin(null),
    ]) {
      expect(typeof result.categoryIsActive).toBe('boolean')
    }
  })
})

describe('fetchExpenseOverviewWithMeta', () => {
  afterEach(() => {
    demoEnabled.mockReset()
    resolveTenant.mockReset()
  })

  it('returns real empty when demo mode is off and tenant is missing', async () => {
    demoEnabled.mockReturnValue(false)
    resolveTenant.mockResolvedValue(mockTenantContextWithoutTenant())

    const result = await fetchExpenseOverviewWithMeta('user-1')

    expect(result.source).toBe('real')
    expect(result.status).toBe('empty')
    expect(result.data.claims).toEqual([])
    expect(result.fallbackReason).toBeUndefined()
  })

  it('returns demo success with fallbackReason empty when demo mode is on', async () => {
    demoEnabled.mockReturnValue(true)
    resolveTenant.mockResolvedValue(mockTenantContextWithoutTenant())

    const result = await fetchExpenseOverviewWithMeta('user-1')

    expect(result.source).toBe('demo')
    expect(result.status).toBe('success')
    expect(result.fallbackReason).toBe('empty')
    expect(result.data.claims.length).toBeGreaterThan(0)
  })
})
