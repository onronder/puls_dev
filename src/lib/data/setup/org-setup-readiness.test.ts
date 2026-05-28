import { describe, expect, it } from 'vitest'

import {
  buildOrgSetupReadinessSummary,
  computeCostCenterReadinessSummaryStatus,
  computeDepartmentReadinessStatus,
  computePositionReadinessStatus,
} from '#/lib/data/setup/org-setup-readiness'

describe('computeDepartmentReadinessStatus', () => {
  it('returns empty when total is zero', () => {
    expect(computeDepartmentReadinessStatus({ total: 0, active: 0 })).toBe('empty')
  })

  it('returns partial when total is positive but active is zero', () => {
    expect(computeDepartmentReadinessStatus({ total: 1, active: 0 })).toBe('partial')
    expect(computeDepartmentReadinessStatus({ total: 5, active: 0 })).toBe('partial')
  })

  it('returns partial when some rows are inactive', () => {
    expect(computeDepartmentReadinessStatus({ total: 3, active: 2 })).toBe('partial')
    expect(computeDepartmentReadinessStatus({ total: 10, active: 9 })).toBe('partial')
  })

  it('returns ready when all rows are active and total is positive', () => {
    expect(computeDepartmentReadinessStatus({ total: 1, active: 1 })).toBe('ready')
    expect(computeDepartmentReadinessStatus({ total: 4, active: 4 })).toBe('ready')
  })
})

describe('computePositionReadinessStatus', () => {
  it('mirrors department readiness rules', () => {
    expect(computePositionReadinessStatus({ total: 0, active: 0 })).toBe('empty')
    expect(computePositionReadinessStatus({ total: 2, active: 0 })).toBe('partial')
    expect(computePositionReadinessStatus({ total: 2, active: 1 })).toBe('partial')
    expect(computePositionReadinessStatus({ total: 2, active: 2 })).toBe('ready')
  })
})

describe('computeCostCenterReadinessSummaryStatus', () => {
  it('returns empty when total is zero', () => {
    expect(
      computeCostCenterReadinessSummaryStatus({ total: 0, mapped: 0, unmapped: 0 }),
    ).toBe('empty')
  })

  it('returns unmapped when any cost center needs mapping', () => {
    expect(
      computeCostCenterReadinessSummaryStatus({ total: 3, mapped: 2, unmapped: 1 }),
    ).toBe('unmapped')
    expect(
      computeCostCenterReadinessSummaryStatus({ total: 1, mapped: 0, unmapped: 1 }),
    ).toBe('unmapped')
  })

  it('returns ready when all cost centers are mapped', () => {
    expect(
      computeCostCenterReadinessSummaryStatus({ total: 1, mapped: 1, unmapped: 0 }),
    ).toBe('ready')
    expect(
      computeCostCenterReadinessSummaryStatus({ total: 5, mapped: 5, unmapped: 0 }),
    ).toBe('ready')
  })
})

describe('buildOrgSetupReadinessSummary', () => {
  it('aggregates department, position, and cost center counts with computed statuses', () => {
    const summary = buildOrgSetupReadinessSummary({
      departmentTotal: 3,
      departmentActive: 2,
      departmentSource: 'real',
      positionTotal: 2,
      positionActive: 2,
      positionSource: 'real',
      costCenterTotal: 4,
      costCenterMapped: 3,
      costCenterUnmapped: 1,
      costCenterSource: 'real',
    })

    expect(summary.departments).toEqual({ status: 'partial', total: 3, active: 2 })
    expect(summary.positions).toEqual({ status: 'ready', total: 2, active: 2 })
    expect(summary.costCenters).toEqual({
      status: 'unmapped',
      total: 4,
      active: 4,
      mapped: 3,
      unmapped: 1,
    })
  })

  it('sets demo_only only when adapter source is demo, not from row counts alone', () => {
    const fromDemo = buildOrgSetupReadinessSummary({
      departmentTotal: 0,
      departmentActive: 0,
      departmentSource: 'demo',
      positionTotal: 0,
      positionActive: 0,
      positionSource: 'real',
      costCenterTotal: 0,
      costCenterMapped: 0,
      costCenterUnmapped: 0,
      costCenterSource: 'real',
    })

    expect(fromDemo.departments.status).toBe('demo_only')
    expect(fromDemo.positions.status).toBe('empty')

    const emptyReal = buildOrgSetupReadinessSummary({
      departmentTotal: 0,
      departmentActive: 0,
      departmentSource: 'real',
      positionTotal: 0,
      positionActive: 0,
      positionSource: 'real',
      costCenterTotal: 0,
      costCenterMapped: 0,
      costCenterUnmapped: 0,
      costCenterSource: 'real',
    })

    expect(emptyReal.departments.status).toBe('empty')
    expect(emptyReal.positions.status).toBe('empty')
    expect(emptyReal.costCenters.status).toBe('empty')
  })
})
