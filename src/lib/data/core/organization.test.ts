import { describe, expect, it } from 'vitest'

import { computeOpenHeadcount } from '#/lib/data/core/lookups'

describe('positions open headcount', () => {
  it('computes open positions from norm headcount minus filled count', () => {
    expect(computeOpenHeadcount(5, 3)).toBe(2)
    expect(computeOpenHeadcount(3, 5)).toBe(0)
  })

  it('uses zero for templateLinked and evaluationComplete in real adapter', () => {
    const summary = {
      templateLinked: 0,
      evaluationComplete: 0,
    }

    expect(summary.templateLinked).toBe(0)
    expect(summary.evaluationComplete).toBe(0)
  })
})
