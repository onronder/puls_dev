import { describe, expect, it } from 'vitest'

import {
  buildNameMap,
  computeOpenHeadcount,
  countRowsById,
  uniqueNonNullIds,
} from '#/lib/data/core/lookups'

describe('uniqueNonNullIds', () => {
  it('deduplicates and filters nullish values', () => {
    expect(uniqueNonNullIds(['a', null, 'b', undefined, 'a', ''])).toEqual(['a', 'b'])
  })

  it('returns empty array for empty input', () => {
    expect(uniqueNonNullIds([])).toEqual([])
  })
})

describe('buildNameMap', () => {
  it('maps id to name', () => {
    const map = buildNameMap([
      { id: 'd1', name: 'Engineering' },
      { id: 'd2', name: 'Operations' },
    ])

    expect(map.get('d1')).toBe('Engineering')
    expect(map.get('d2')).toBe('Operations')
    expect(map.size).toBe(2)
  })
})

describe('countRowsById', () => {
  it('counts rows grouped by id field', () => {
    const counts = countRowsById([
      { id: 'p1' },
      { id: 'p1' },
      { id: 'p2' },
      { id: null },
    ])

    expect(counts.get('p1')).toBe(2)
    expect(counts.get('p2')).toBe(1)
    expect(counts.size).toBe(2)
  })
})

describe('computeOpenHeadcount', () => {
  it('returns non-negative open headcount', () => {
    expect(computeOpenHeadcount(5, 3)).toBe(2)
    expect(computeOpenHeadcount(3, 5)).toBe(0)
    expect(computeOpenHeadcount(0, 0)).toBe(0)
  })
})
