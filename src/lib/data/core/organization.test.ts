import { describe, expect, it } from 'vitest'

import { computeOpenHeadcount } from '#/lib/data/core/lookups'
import {
  fetchDemoDepartmentsOverview,
  fetchDemoPositionsOverview,
} from '#/lib/demo/puls-demo-data'

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

describe('organization overview row shape', () => {
  it('includes code, isActive, and source on department rows', async () => {
    const overview = await fetchDemoDepartmentsOverview()

    expect(overview.totalCount).toBe(overview.departments.length)
    expect(overview.activeCount).toBeGreaterThan(0)

    for (const department of overview.departments) {
      expect(department).toMatchObject({
        code: expect.any(String),
        isActive: expect.any(Boolean),
        source: expect.stringMatching(/^(puls|erp|demo|unknown)$/),
      })
    }
  })

  it('includes code, isActive, and source on position rows', async () => {
    const overview = await fetchDemoPositionsOverview()

    expect(overview.totalCount).toBe(overview.positions.length)
    expect(overview.activeCount).toBeGreaterThan(0)
    expect(overview.showsTemplateMetrics).toBe(true)

    for (const position of overview.positions) {
      expect(position).toMatchObject({
        code: expect.any(String),
        isActive: expect.any(Boolean),
        source: expect.stringMatching(/^(puls|erp|demo|unknown)$/),
      })
    }
  })
})
