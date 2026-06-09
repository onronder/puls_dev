import {
  fetchDemoEmployeeAssignmentReadiness,
  fetchDemoEmployeesOverview,
} from '#/lib/demo/puls-demo-data'
import type { DemoEmployeeStatus, DemoEmployeesOverview } from '#/lib/demo/puls-demo-data'
import {
  fromSupabaseError,
  isDataAdapterError,
  parseRpcErrorCode,
} from '#/lib/data/errors'
import { pulsCalc, pulsCore, resolveTenantContext } from '#/lib/data/client'
import { fetchNamesByIds, uniqueNonNullIds } from '#/lib/data/core/lookups'
import { resolveAdapterData, resolveAdapterDataWithMeta } from '#/lib/data/result'
import type { EmployeeAssignmentReadinessEmployee } from '#/lib/data/setup/employee-assignment-readiness'

export type EmployeeListItem = {
  id: string
  fullName: string
  email: string | null
  employeeNumber: string | null
  employmentStatus: string | null
  isActive: boolean
  jobTitle: string | null
  departmentId: string | null
  departmentName: string | null
  positionId: string | null
  positionName: string | null
  managerEmployeeId: string | null
  managerName: string | null
  personaRole: string | null
  hireDate: string | null
}

export type EmployeeListStats = {
  total: number
  active: number
  inactive: number
  missingDepartment: number
  missingPosition: number
  missingManager: number
}

export type EmployeeRowForList = {
  id: string
  full_name: string | null
  email: string | null
  employee_code: string | null
  employment_status: string | null
  job_title: string | null
  persona_role: string | null
  hire_date: string | null
  department_id: string | null
  position_id: string | null
  manager_employee_id: string | null
}

export type EmployeesOverview = DemoEmployeesOverview
export type { DemoEmployeeStatus }

export type EmployeeAssignmentMutationInput = {
  departmentId: string | null
  positionId: string | null
  costCenterId: string | null
  managerEmployeeId: string | null
}

export type EmployeeAssignmentUpdateResult = {
  status: 'updated' | 'unchanged'
  employeeId: string
  departmentId: string | null
  positionId: string | null
  costCenterId: string | null
  managerEmployeeId: string | null
}

export type EmployeeAssignmentErrorMapping = {
  code: string
  toastKey: string
}

export function isActiveEmployeeStatus(status: string | null | undefined): boolean {
  return status === 'active'
}

export function mapEmployeeRow(
  row: EmployeeRowForList,
  lookups: {
    departmentNameMap: Map<string, string>
    positionNameMap: Map<string, string>
    managerNameMap: Map<string, string>
  },
): EmployeeListItem {
  const departmentId = row.department_id
  const positionId = row.position_id
  const managerEmployeeId = row.manager_employee_id
  const employmentStatus = row.employment_status

  return {
    id: row.id,
    fullName: row.full_name ?? '',
    email: row.email ?? null,
    employeeNumber: row.employee_code ?? null,
    employmentStatus,
    isActive: isActiveEmployeeStatus(employmentStatus),
    jobTitle: row.job_title ?? null,
    departmentId,
    departmentName: departmentId ? (lookups.departmentNameMap.get(departmentId) ?? null) : null,
    positionId,
    positionName: positionId ? (lookups.positionNameMap.get(positionId) ?? null) : null,
    managerEmployeeId,
    managerName: managerEmployeeId ? (lookups.managerNameMap.get(managerEmployeeId) ?? null) : null,
    personaRole: row.persona_role ?? null,
    hireDate: row.hire_date ?? null,
  }
}

const EMPLOYEE_ASSIGNMENT_ERROR_KEYS: Record<string, string> = {
  PULS_EMPLOYEE_ASSIGNMENT_FORBIDDEN: 'employeeAssignmentReadiness.edit.errors.forbidden',
  PULS_EMPLOYEE_ASSIGNMENT_NOT_FOUND: 'employeeAssignmentReadiness.edit.errors.notFound',
  PULS_EMPLOYEE_ASSIGNMENT_SOURCE_READ_ONLY: 'employeeAssignmentReadiness.edit.errors.sourceReadOnly',
  PULS_EMPLOYEE_ASSIGNMENT_INACTIVE_EMPLOYEE: 'employeeAssignmentReadiness.edit.errors.inactiveEmployee',
  PULS_EMPLOYEE_ASSIGNMENT_INVALID_DEPARTMENT: 'employeeAssignmentReadiness.edit.errors.invalidDepartment',
  PULS_EMPLOYEE_ASSIGNMENT_INVALID_POSITION: 'employeeAssignmentReadiness.edit.errors.invalidPosition',
  PULS_EMPLOYEE_ASSIGNMENT_POSITION_DEPARTMENT_MISMATCH:
    'employeeAssignmentReadiness.edit.errors.positionDepartmentMismatch',
  PULS_EMPLOYEE_ASSIGNMENT_INVALID_COST_CENTER:
    'employeeAssignmentReadiness.edit.errors.invalidCostCenter',
  PULS_EMPLOYEE_ASSIGNMENT_SELF_MANAGER: 'employeeAssignmentReadiness.edit.errors.selfManager',
  PULS_EMPLOYEE_ASSIGNMENT_INVALID_MANAGER: 'employeeAssignmentReadiness.edit.errors.invalidManager',
  PULS_EMPLOYEE_ASSIGNMENT_MANAGER_CYCLE: 'employeeAssignmentReadiness.edit.errors.managerCycle',
}

function parseEmployeeAssignmentUpdateResult(data: unknown): EmployeeAssignmentUpdateResult {
  const row = (data ?? {}) as Record<string, unknown>
  return {
    status: row.status === 'unchanged' ? 'unchanged' : 'updated',
    employeeId: String(row.employee_id ?? ''),
    departmentId: (row.department_id as string | null | undefined) ?? null,
    positionId: (row.position_id as string | null | undefined) ?? null,
    costCenterId: (row.cost_center_id as string | null | undefined) ?? null,
    managerEmployeeId: (row.manager_employee_id as string | null | undefined) ?? null,
  }
}

export function mapEmployeeAssignmentMutationError(error: unknown): EmployeeAssignmentErrorMapping {
  const message = isDataAdapterError(error)
    ? error.message
    : error instanceof Error
      ? error.message
      : ''
  const code = parseRpcErrorCode(message) ?? 'unknown'
  return {
    code,
    toastKey: EMPLOYEE_ASSIGNMENT_ERROR_KEYS[code] ?? 'employeeAssignmentReadiness.edit.errors.generic',
  }
}

export function buildEmployeeListStats(items: EmployeeListItem[]): EmployeeListStats {
  let active = 0
  let inactive = 0
  let missingDepartment = 0
  let missingPosition = 0
  let missingManager = 0

  for (const item of items) {
    if (item.isActive) active++
    else inactive++
    if (!item.departmentId) missingDepartment++
    if (!item.positionId) missingPosition++
    if (!item.managerEmployeeId) missingManager++
  }

  return {
    total: items.length,
    active,
    inactive,
    missingDepartment,
    missingPosition,
    missingManager,
  }
}

export function emptyEmployeeListStats(): EmployeeListStats {
  return {
    total: 0,
    active: 0,
    inactive: 0,
    missingDepartment: 0,
    missingPosition: 0,
    missingManager: 0,
  }
}

function isEmployeeListStatsEmpty(stats: EmployeeListStats): boolean {
  return stats.total === 0
}

function mapDemoAssignmentEmployeeToListItem(
  employee: EmployeeAssignmentReadinessEmployee,
): EmployeeListItem {
  return {
    id: employee.id,
    fullName: employee.displayName,
    email: employee.email,
    employeeNumber: employee.employeeNumber,
    employmentStatus: employee.isActive ? 'active' : 'inactive',
    isActive: employee.isActive,
    jobTitle: null,
    departmentId: employee.department?.id ?? null,
    departmentName: employee.department?.name ?? null,
    positionId: employee.position?.id ?? null,
    positionName: employee.position?.name ?? null,
    managerEmployeeId: employee.manager?.id ?? null,
    managerName: employee.manager?.displayName ?? null,
    personaRole: null,
    hireDate: null,
  }
}

async function fetchDemoEmployeeList(): Promise<EmployeeListItem[]> {
  const overview = await fetchDemoEmployeeAssignmentReadiness()
  return overview.employees.map(mapDemoAssignmentEmployeeToListItem)
}

async function fetchDemoEmployeeListStats(): Promise<EmployeeListStats> {
  const items = await fetchDemoEmployeeList()
  return buildEmployeeListStats(items)
}

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

  const managerIds = uniqueNonNullIds(employees.map((row) => row.manager_employee_id as string | null))

  const [leaveResult, managerNameMap] = await Promise.all([
    pulsCalc()
      .from('leave_overview')
      .select('employee_id, annual_leave_used, annual_leave_total')
      .eq('tenant_id', ctx.tenantId),
    fetchNamesByIds('employees', ctx.tenantId, managerIds),
  ])

  if (leaveResult.error) {
    throw fromSupabaseError(leaveResult.error, 'fetchEmployeesOverview', 'puls_calc', 'leave_overview')
  }

  const leaveByEmployee = new Map(
    (leaveResult.data ?? []).map((row) => [
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
    const managerId = row.manager_employee_id as string | null

    overview.byEmail[email] = {
      status: 'active',
      manager: managerId ? (managerNameMap.get(managerId) ?? '—') : overview.defaultManager,
      leaveUsed: leave?.used ?? 0,
      leaveTotal: leave?.total ?? 0,
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
      'id, full_name, email, employee_code, employment_status, job_title, persona_role, hire_date, department_id, position_id, manager_employee_id',
    )
    .eq('tenant_id', ctx.tenantId)
    .order('full_name', { ascending: true })

  if (error) {
    throw fromSupabaseError(error, 'fetchEmployeeList', 'puls_core', 'employees')
  }

  const rows = (data ?? []) as EmployeeRowForList[]
  const departmentIds = uniqueNonNullIds(rows.map((row) => row.department_id))
  const positionIds = uniqueNonNullIds(rows.map((row) => row.position_id))
  const managerIds = uniqueNonNullIds(rows.map((row) => row.manager_employee_id))

  const [departmentNameMap, positionNameMap, managerNameMap] = await Promise.all([
    fetchNamesByIds('departments', ctx.tenantId, departmentIds),
    fetchNamesByIds('positions', ctx.tenantId, positionIds),
    fetchNamesByIds('employees', ctx.tenantId, managerIds),
  ])

  return rows.map((row) =>
    mapEmployeeRow(row, { departmentNameMap, positionNameMap, managerNameMap }),
  )
}

async function fetchRealEmployeeListStats(userId: string): Promise<EmployeeListStats> {
  const items = await fetchRealEmployeeList(userId)
  return buildEmployeeListStats(items)
}

export async function updateEmployeeAssignment(
  userId: string,
  employeeId: string,
  input: EmployeeAssignmentMutationInput,
): Promise<EmployeeAssignmentUpdateResult> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    throw new Error('Missing tenant context')
  }

  const { data, error } = await pulsCore().rpc('update_employee_assignment', {
    p_employee_id: employeeId,
    p_department_id: input.departmentId,
    p_position_id: input.positionId,
    p_cost_center_id: input.costCenterId,
    p_manager_employee_id: input.managerEmployeeId,
  })

  if (error) {
    throw fromSupabaseError(error, 'updateEmployeeAssignment', 'puls_core', 'employees')
  }

  return parseEmployeeAssignmentUpdateResult(data)
}

export function fetchEmployeesOverviewWithMeta(userId: string) {
  return resolveAdapterDataWithMeta({
    operation: 'fetchEmployeesOverview',
    fetchReal: () => fetchRealEmployeesOverview(userId),
    fetchDemo: fetchDemoEmployeesOverview,
    isEmpty: isEmployeesOverviewEmpty,
  })
}

export function fetchEmployeeListWithMeta(userId: string) {
  return resolveAdapterDataWithMeta({
    operation: 'fetchEmployeeList',
    fetchReal: () => fetchRealEmployeeList(userId),
    fetchDemo: fetchDemoEmployeeList,
    isEmpty: (items) => items.length === 0,
  })
}

export function fetchEmployeeListStatsWithMeta(userId: string) {
  return resolveAdapterDataWithMeta({
    operation: 'fetchEmployeeListStats',
    fetchReal: () => fetchRealEmployeeListStats(userId),
    fetchDemo: fetchDemoEmployeeListStats,
    isEmpty: isEmployeeListStatsEmpty,
  })
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
    fetchDemo: fetchDemoEmployeeList,
    isEmpty: (items) => items.length === 0,
  })
}

export async function fetchEmployeeListStats(userId: string): Promise<EmployeeListStats> {
  return resolveAdapterData({
    operation: 'fetchEmployeeListStats',
    fetchReal: () => fetchRealEmployeeListStats(userId),
    fetchDemo: fetchDemoEmployeeListStats,
    isEmpty: isEmployeeListStatsEmpty,
  })
}
