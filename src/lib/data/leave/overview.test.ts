import { describe, expect, it } from 'vitest'

import { mapLeaveTypeFromLookup } from '#/lib/data/leave/overview'

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
