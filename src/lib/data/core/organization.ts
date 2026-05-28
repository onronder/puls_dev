import {
  fetchDemoDepartmentsOverview,
  fetchDemoPositionsOverview,
} from '#/lib/demo/puls-demo-data'
import type { DemoDepartmentsOverview, DemoPositionsOverview } from '#/lib/demo/puls-demo-data'
import { fromSupabaseError } from '#/lib/data/errors'
import { pulsCalc, pulsCore, resolveTenantContext } from '#/lib/data/client'
import {
  computeOpenHeadcount,
  countActiveEmployeesByDepartment,
  countActiveEmployeesByPosition,
  fetchNamesByIds,
  uniqueNonNullIds,
} from '#/lib/data/core/lookups'
import { mapOrgEntitySource, type OrgSetupEntitySource } from '#/lib/data/setup/org-entity-source'
import { resolveAdapterData, resolveAdapterDataWithMeta } from '#/lib/data/result'

export type DepartmentsOverview = DemoDepartmentsOverview
export type PositionsOverview = DemoPositionsOverview

function emptyDepartmentsOverview(): DepartmentsOverview {
  return {
    departmentCount: 0,
    totalCount: 0,
    activeCount: 0,
    activeEmployees: 0,
    assignedManagers: 0,
    emptyManagers: 0,
    departments: [],
  }
}

function emptyPositionsOverview(): PositionsOverview {
  return {
    positionCount: 0,
    totalCount: 0,
    activeCount: 0,
    openPositions: 0,
    templateLinked: 0,
    evaluationComplete: 0,
    showsTemplateMetrics: false,
    positions: [],
  }
}

async function fetchRealDepartmentsOverview(userId: string): Promise<DepartmentsOverview> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) return emptyDepartmentsOverview()

  const [{ data: orgOverview, error: orgError }, { data: departments, error: deptError }] =
    await Promise.all([
      pulsCalc()
        .from('organization_overview')
        .select(
          'department_total_count, active_employee_count, department_with_manager_count',
        )
        .eq('tenant_id', ctx.tenantId)
        .maybeSingle(),
      pulsCore()
        .from('departments')
        .select('id, name, code, manager_employee_id, is_active, external_source')
        .eq('tenant_id', ctx.tenantId)
        .order('name', { ascending: true }),
    ])

  if (orgError) {
    throw fromSupabaseError(orgError, 'fetchDepartmentsOverview', 'puls_calc', 'organization_overview')
  }
  if (deptError) {
    throw fromSupabaseError(deptError, 'fetchDepartmentsOverview', 'puls_core', 'departments')
  }

  const rows = departments ?? []
  const managerIds = uniqueNonNullIds(rows.map((row) => row.manager_employee_id as string | null))

  const [countByDept, managerNameMap] = await Promise.all([
    countActiveEmployeesByDepartment(ctx.tenantId),
    fetchNamesByIds('employees', ctx.tenantId, managerIds),
  ])

  const mappedDepartments = rows.map((row) => {
    const managerId = row.manager_employee_id as string | null
    const isActive = Boolean(row.is_active)
    return {
      id: row.id as string,
      name: row.name as string,
      code: (row.code as string | null) ?? null,
      manager: managerId ? (managerNameMap.get(managerId) ?? '—') : '—',
      count: countByDept.get(row.id as string) ?? 0,
      isActive,
      source: mapOrgEntitySource(row.external_source as string | null) as OrgSetupEntitySource,
    }
  })

  const totalCount = mappedDepartments.length
  const activeCount = mappedDepartments.filter((row) => row.isActive).length
  const withManager = Number(orgOverview?.department_with_manager_count ?? 0)

  return {
    departmentCount: Number(orgOverview?.department_total_count ?? activeCount),
    totalCount,
    activeCount,
    activeEmployees: Number(orgOverview?.active_employee_count ?? 0),
    assignedManagers: withManager,
    emptyManagers: Math.max(0, activeCount - withManager),
    departments: mappedDepartments,
  }
}

async function fetchRealPositionsOverview(userId: string): Promise<PositionsOverview> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) return emptyPositionsOverview()

  const [{ data: orgOverview, error: orgError }, { data: positions, error: posError }] =
    await Promise.all([
      pulsCalc()
        .from('organization_overview')
        .select('position_total_count, open_position_count, filled_position_count')
        .eq('tenant_id', ctx.tenantId)
        .maybeSingle(),
      pulsCore()
        .from('positions')
        .select('id, name, code, norm_headcount, department_id, is_active, external_source')
        .eq('tenant_id', ctx.tenantId)
        .order('name', { ascending: true }),
    ])

  if (orgError) {
    throw fromSupabaseError(orgError, 'fetchPositionsOverview', 'puls_calc', 'organization_overview')
  }
  if (posError) {
    throw fromSupabaseError(posError, 'fetchPositionsOverview', 'puls_core', 'positions')
  }

  const rows = positions ?? []
  const departmentIds = uniqueNonNullIds(rows.map((row) => row.department_id as string | null))

  const [countByPosition, departmentNameMap] = await Promise.all([
    countActiveEmployeesByPosition(ctx.tenantId),
    fetchNamesByIds('departments', ctx.tenantId, departmentIds),
  ])

  const mappedPositions = rows.map((row) => {
    const positionId = row.id as string
    const departmentId = row.department_id as string | null
    const normHeadcount = Number(row.norm_headcount ?? 0)
    const filledCount = countByPosition.get(positionId) ?? 0

    return {
      id: positionId,
      name: row.name as string,
      code: (row.code as string | null) ?? null,
      department: departmentId ? (departmentNameMap.get(departmentId) ?? '—') : '—',
      template: '—',
      evaluation: 0,
      open: computeOpenHeadcount(normHeadcount, filledCount),
      isActive: Boolean(row.is_active),
      source: mapOrgEntitySource(row.external_source as string | null) as OrgSetupEntitySource,
    }
  })

  const totalCount = mappedPositions.length
  const activeCount = mappedPositions.filter((row) => row.isActive).length

  return {
    positionCount: Number(orgOverview?.position_total_count ?? activeCount),
    totalCount,
    activeCount,
    openPositions: Number(orgOverview?.open_position_count ?? 0),
    templateLinked: 0,
    evaluationComplete: 0,
    showsTemplateMetrics: false,
    positions: mappedPositions,
  }
}

export async function fetchDepartmentsOverview(userId: string): Promise<DepartmentsOverview> {
  return resolveAdapterData({
    operation: 'fetchDepartmentsOverview',
    fetchReal: () => fetchRealDepartmentsOverview(userId),
    fetchDemo: fetchDemoDepartmentsOverview,
    isEmpty: (data) => data.departments.length === 0,
  })
}

export async function fetchPositionsOverview(userId: string): Promise<PositionsOverview> {
  return resolveAdapterData({
    operation: 'fetchPositionsOverview',
    fetchReal: () => fetchRealPositionsOverview(userId),
    fetchDemo: fetchDemoPositionsOverview,
    isEmpty: (data) => data.positions.length === 0,
  })
}

export function fetchDepartmentsOverviewWithMeta(userId: string) {
  return resolveAdapterDataWithMeta({
    operation: 'fetchDepartmentsOverview',
    fetchReal: () => fetchRealDepartmentsOverview(userId),
    fetchDemo: fetchDemoDepartmentsOverview,
    isEmpty: (data) => data.departments.length === 0,
  })
}

export function fetchPositionsOverviewWithMeta(userId: string) {
  return resolveAdapterDataWithMeta({
    operation: 'fetchPositionsOverview',
    fetchReal: () => fetchRealPositionsOverview(userId),
    fetchDemo: fetchDemoPositionsOverview,
    isEmpty: (data) => data.positions.length === 0,
  })
}
