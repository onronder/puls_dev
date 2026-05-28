import { fetchDepartmentsOverviewWithMeta, fetchPositionsOverviewWithMeta } from '#/lib/data/core/organization'
import { fetchCostCenterReadinessOverviewWithMeta } from '#/lib/data/setup/cost-center-readiness'
import type { DataResult } from '#/lib/data/result'
import { resolveTenantContext } from '#/lib/data/client'

export type OrgSetupReadinessStatus =
  | 'ready'
  | 'empty'
  | 'partial'
  | 'unmapped'
  | 'demo_only'
  | 'unknown'

export type OrgSetupReadinessDomainSummary = {
  status: OrgSetupReadinessStatus
  total: number
  active: number
  mapped?: number
  unmapped?: number
}

export type OrgSetupReadinessSummary = {
  departments: OrgSetupReadinessDomainSummary
  positions: OrgSetupReadinessDomainSummary
  costCenters: OrgSetupReadinessDomainSummary & { mapped: number; unmapped: number }
}

export type OrgSetupReadinessOverview = {
  summary: OrgSetupReadinessSummary
}

export function computeDepartmentReadinessStatus({
  total,
  active,
}: {
  total: number
  active: number
}): OrgSetupReadinessStatus {
  if (total === 0) return 'empty'
  if (active === 0) return 'partial'
  if (active < total) return 'partial'
  if (active === total && total > 0) return 'ready'
  return 'unknown'
}

export function computePositionReadinessStatus({
  total,
  active,
}: {
  total: number
  active: number
}): OrgSetupReadinessStatus {
  return computeDepartmentReadinessStatus({ total, active })
}

export function computeCostCenterReadinessSummaryStatus({
  total,
  mapped,
  unmapped,
}: {
  total: number
  mapped: number
  unmapped: number
}): OrgSetupReadinessStatus {
  if (total === 0) return 'empty'
  if (unmapped > 0) return 'unmapped'
  if (mapped === total && total > 0) return 'ready'
  return 'unknown'
}

function applyDemoOnlyStatus(
  computed: OrgSetupReadinessStatus,
  source: DataResult<unknown>['source'],
): OrgSetupReadinessStatus {
  if (source === 'demo') return 'demo_only'
  return computed
}

export function buildOrgSetupReadinessSummary(input: {
  departmentTotal: number
  departmentActive: number
  departmentSource: DataResult<unknown>['source']
  positionTotal: number
  positionActive: number
  positionSource: DataResult<unknown>['source']
  costCenterTotal: number
  costCenterMapped: number
  costCenterUnmapped: number
  costCenterSource: DataResult<unknown>['source']
}): OrgSetupReadinessSummary {
  const departmentComputed = computeDepartmentReadinessStatus({
    total: input.departmentTotal,
    active: input.departmentActive,
  })
  const positionComputed = computePositionReadinessStatus({
    total: input.positionTotal,
    active: input.positionActive,
  })
  const costCenterComputed = computeCostCenterReadinessSummaryStatus({
    total: input.costCenterTotal,
    mapped: input.costCenterMapped,
    unmapped: input.costCenterUnmapped,
  })

  return {
    departments: {
      status: applyDemoOnlyStatus(departmentComputed, input.departmentSource),
      total: input.departmentTotal,
      active: input.departmentActive,
    },
    positions: {
      status: applyDemoOnlyStatus(positionComputed, input.positionSource),
      total: input.positionTotal,
      active: input.positionActive,
    },
    costCenters: {
      status: applyDemoOnlyStatus(costCenterComputed, input.costCenterSource),
      total: input.costCenterTotal,
      active: input.costCenterTotal,
      mapped: input.costCenterMapped,
      unmapped: input.costCenterUnmapped,
    },
  }
}

export async function fetchOrgSetupReadiness(userId: string): Promise<OrgSetupReadinessOverview> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    return {
      summary: buildOrgSetupReadinessSummary({
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
      }),
    }
  }

  const [departmentsResult, positionsResult, costCentersResult] = await Promise.all([
    fetchDepartmentsOverviewWithMeta(userId),
    fetchPositionsOverviewWithMeta(userId),
    fetchCostCenterReadinessOverviewWithMeta(userId),
  ])

  if (departmentsResult.status === 'error' && departmentsResult.error) {
    throw departmentsResult.error
  }
  if (positionsResult.status === 'error' && positionsResult.error) {
    throw positionsResult.error
  }
  if (costCentersResult.status === 'error' && costCentersResult.error) {
    throw costCentersResult.error
  }

  return {
    summary: buildOrgSetupReadinessSummary({
      departmentTotal: departmentsResult.data.totalCount,
      departmentActive: departmentsResult.data.activeCount,
      departmentSource: departmentsResult.source,
      positionTotal: positionsResult.data.totalCount,
      positionActive: positionsResult.data.activeCount,
      positionSource: positionsResult.source,
      costCenterTotal: costCentersResult.data.items.length,
      costCenterMapped: costCentersResult.data.exportReadyCount,
      costCenterUnmapped: costCentersResult.data.needsMappingCount,
      costCenterSource: costCentersResult.source,
    }),
  }
}
