import { describe, expect, it } from 'vitest'

import { mapClaimCategoryFromJoin } from '#/lib/data/expense/overview'

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
