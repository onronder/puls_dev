import {
  fetchDemoDepartmentsOverview,
  fetchDemoPositionsOverview,
} from '#/lib/demo/puls-demo-data'
import type { DemoDepartmentsOverview, DemoPositionsOverview } from '#/lib/demo/puls-demo-data'
import { fromSupabaseError } from '#/lib/data/errors'
import { pulsCalc, pulsCore, resolveTenantContext } from '#/lib/data/client'
import { resolveAdapterData } from '#/lib/data/result'

export type DepartmentsOverview = DemoDepartmentsOverview
export type PositionsOverview = DemoPositionsOverview

function emptyDepartmentsOverview(): DepartmentsOverview {
  return {
    departmentCount: 0,
    activeEmployees: 0,
    assignedManagers: 0,
    emptyManagers: 0,
    departments: [],
  }
}

function emptyPositionsOverview(): PositionsOverview {
  return {
    positionCount: 0,
    openPositions: 0,
    templateLinked: 0,
    evaluationComplete: 0,
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
        .select('id, name, manager_employee_id')
        .eq('tenant_id', ctx.tenantId)
        .eq('is_active', true)
        .order('name', { ascending: true }),
    ])

  if (orgError) {
    throw fromSupabaseError(orgError, 'fetchDepartmentsOverview', 'puls_calc', 'organization_overview')
  }
  if (deptError) {
    throw fromSupabaseError(deptError, 'fetchDepartmentsOverview', 'puls_core', 'departments')
  }

  const employeeCounts = await pulsCore()
    .from('employees')
    .select('department_id')
    .eq('tenant_id', ctx.tenantId)
    .eq('employment_status', 'active')

  if (employeeCounts.error) {
    throw fromSupabaseError(
      employeeCounts.error,
      'fetchDepartmentsOverview',
      'puls_core',
      'employees',
    )
  }

  const countByDept = new Map<string, number>()
  for (const row of employeeCounts.data ?? []) {
    const deptId = row.department_id as string | null
    if (!deptId) continue
    countByDept.set(deptId, (countByDept.get(deptId) ?? 0) + 1)
  }

  const mappedDepartments = (departments ?? []).map((row) => {
    return {
      id: row.id as string,
      name: row.name as string,
      manager: row.manager_employee_id ? '—' : '—',
      count: countByDept.get(row.id as string) ?? 0,
      status: 'active' as const,
    }
  })

  const total = Number(orgOverview?.department_total_count ?? mappedDepartments.length)
  const withManager = Number(orgOverview?.department_with_manager_count ?? 0)

  return {
    departmentCount: total,
    activeEmployees: Number(orgOverview?.active_employee_count ?? 0),
    assignedManagers: withManager,
    emptyManagers: Math.max(0, total - withManager),
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
        .select(
          `
          id,
          name,
          norm_headcount,
          department:departments ( name )
        `,
        )
        .eq('tenant_id', ctx.tenantId)
        .eq('is_active', true)
        .order('name', { ascending: true }),
    ])

  if (orgError) {
    throw fromSupabaseError(orgError, 'fetchPositionsOverview', 'puls_calc', 'organization_overview')
  }
  if (posError) {
    throw fromSupabaseError(posError, 'fetchPositionsOverview', 'puls_core', 'positions')
  }

  const mappedPositions = (positions ?? []).map((row) => {
    const department = row.department as { name?: string } | null
    return {
      id: row.id as string,
      name: row.name as string,
      department: department?.name ?? '—',
      template: '—',
      evaluation: 0,
      open: Math.max(0, Number(row.norm_headcount ?? 0)),
    }
  })

  return {
    positionCount: Number(orgOverview?.position_total_count ?? mappedPositions.length),
    openPositions: Number(orgOverview?.open_position_count ?? 0),
    templateLinked: mappedPositions.length,
    evaluationComplete: 0,
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
