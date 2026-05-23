import { fetchDemoEmployeesOverview } from '#/lib/demo/puls-demo-data'
import type { DemoEmployeeStatus, DemoEmployeesOverview } from '#/lib/demo/puls-demo-data'
import { fromSupabaseError } from '#/lib/data/errors'
import { pulsCalc, pulsCore, resolveTenantContext } from '#/lib/data/client'
import { resolveAdapterData } from '#/lib/data/result'

export type EmployeeListItem = {
  id: string
  fullName: string
  email: string | null
  jobTitle: string | null
  departmentName: string | null
  positionName: string | null
  personaRole: string | null
  hireDate: string | null
}

export type EmployeeListStats = {
  employeeCount: number
  departmentCount: number
  positionCount: number | null
}

export type EmployeesOverview = DemoEmployeesOverview
export type { DemoEmployeeStatus }

function emptyEmployeesOverview(): EmployeesOverview {
  return {
    defaultStatus: 'active',
    defaultManager: '—',
    defaultLeave: { used: 0, total: 0 },
    performanceScopePendingKey: 'employeesSetup.detail.performancePending',
    byEmail: {},
  }
}

function isEmployeesOverviewEmpty(data: EmployeesOverview): boolean {
  return Object.keys(data.byEmail).length === 0
}

async function fetchRealEmployeesOverview(userId: string): Promise<EmployeesOverview> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) return emptyEmployeesOverview()

  const overview = emptyEmployeesOverview()

  const { data: listOverview, error: overviewError } = await pulsCalc()
    .from('employee_list_overview')
    .select('active_employee_count, department_count, position_count')
    .eq('tenant_id', ctx.tenantId)
    .maybeSingle()

  if (overviewError) {
    throw fromSupabaseError(overviewError, 'fetchEmployeesOverview', 'puls_calc', 'employee_list_overview')
  }

  if (listOverview?.active_employee_count) {
    overview.defaultLeave.total = 20
  }

  const { data: employees, error: employeesError } = await pulsCore()
    .from('employees')
    .select('id, email, full_name, manager_employee_id')
    .eq('tenant_id', ctx.tenantId)
    .eq('employment_status', 'active')
    .order('full_name', { ascending: true })

  if (employeesError) {
    throw fromSupabaseError(employeesError, 'fetchEmployeesOverview', 'puls_core', 'employees')
  }

  if (!employees?.length) return overview

  const leaveRows = ctx.employeeId
    ? await pulsCalc()
        .from('leave_overview')
        .select('employee_id, annual_leave_used, annual_leave_total')
        .eq('tenant_id', ctx.tenantId)
    : { data: [], error: null }

  if (leaveRows.error) {
    throw fromSupabaseError(leaveRows.error, 'fetchEmployeesOverview', 'puls_calc', 'leave_overview')
  }

  const leaveByEmployee = new Map(
    (leaveRows.data ?? []).map((row) => [
      row.employee_id as string,
      {
        used: Number(row.annual_leave_used ?? 0),
        total: Number(row.annual_leave_total ?? 0),
      },
    ]),
  )

  for (const row of employees) {
    const email = (row.email as string | null)?.toLowerCase()
    if (!email) continue

    const leave = leaveByEmployee.get(row.id as string)

    overview.byEmail[email] = {
      status: 'active',
      manager: overview.defaultManager,
      leaveUsed: leave?.used ?? 0,
      leaveTotal: leave?.total ?? overview.defaultLeave.total,
    }
  }

  return overview
}

async function fetchRealEmployeeList(userId: string): Promise<EmployeeListItem[]> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) return []

  const { data, error } = await pulsCore()
    .from('employees')
    .select(
      `
      id,
      full_name,
      email,
      job_title,
      persona_role,
      hire_date,
      departments ( name ),
      positions ( name )
    `,
    )
    .eq('tenant_id', ctx.tenantId)
    .order('full_name', { ascending: true })

  if (error) {
    throw fromSupabaseError(error, 'fetchEmployeeList', 'puls_core', 'employees')
  }

  return (data ?? []).map((row) => {
    const department = row.departments as { name?: string } | null
    const position = row.positions as { name?: string } | null

    return {
      id: row.id as string,
      fullName: (row.full_name as string | null) ?? '',
      email: (row.email as string | null) ?? null,
      jobTitle: (row.job_title as string | null) ?? null,
      departmentName: department?.name ?? null,
      positionName: position?.name ?? null,
      personaRole: (row.persona_role as string | null) ?? null,
      hireDate: (row.hire_date as string | null) ?? null,
    }
  })
}

async function fetchRealEmployeeListStats(userId: string): Promise<EmployeeListStats> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    return { employeeCount: 0, departmentCount: 0, positionCount: null }
  }

  const { data, error } = await pulsCalc()
    .from('employee_list_overview')
    .select('active_employee_count, department_count, position_count')
    .eq('tenant_id', ctx.tenantId)
    .maybeSingle()

  if (error) {
    throw fromSupabaseError(error, 'fetchEmployeeListStats', 'puls_calc', 'employee_list_overview')
  }

  return {
    employeeCount: Number(data?.active_employee_count ?? 0),
    departmentCount: Number(data?.department_count ?? 0),
    positionCount: data?.position_count == null ? null : Number(data.position_count),
  }
}

export async function fetchEmployeesOverview(userId: string): Promise<EmployeesOverview> {
  return resolveAdapterData({
    operation: 'fetchEmployeesOverview',
    fetchReal: () => fetchRealEmployeesOverview(userId),
    fetchDemo: fetchDemoEmployeesOverview,
    isEmpty: isEmployeesOverviewEmpty,
  })
}

export async function fetchEmployeeList(userId: string): Promise<EmployeeListItem[]> {
  return resolveAdapterData({
    operation: 'fetchEmployeeList',
    fetchReal: () => fetchRealEmployeeList(userId),
    fetchDemo: async () => [],
    isEmpty: (items) => items.length === 0,
  })
}

export async function fetchEmployeeListStats(userId: string): Promise<EmployeeListStats> {
  return resolveAdapterData({
    operation: 'fetchEmployeeListStats',
    fetchReal: () => fetchRealEmployeeListStats(userId),
    fetchDemo: async () => ({ employeeCount: 4, departmentCount: 3, positionCount: 3 }),
    isEmpty: (stats) =>
      stats.employeeCount === 0 && stats.departmentCount === 0 && (stats.positionCount ?? 0) === 0,
  })
}
