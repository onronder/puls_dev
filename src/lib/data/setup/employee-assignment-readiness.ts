import { fromSupabaseError } from '#/lib/data/errors'
import { pulsCore, resolveTenantContext } from '#/lib/data/client'
import { fetchDemoEmployeeAssignmentReadiness } from '#/lib/demo/puls-demo-data'
import { resolveAdapterDataWithMeta, type DataResult } from '#/lib/data/result'
import {
  isOrgEntityEditable,
  mapOrgEntitySource,
  type OrgSetupEntitySource,
} from '#/lib/data/setup/org-entity-source'

export type EmployeeAssignmentReadinessStatus =
  | 'ready'
  | 'missing_department'
  | 'missing_position'
  | 'missing_cost_center'
  | 'missing_manager'
  | 'inactive_reference'
  | 'partial'
  | 'unknown'

export type EmployeeAssignmentReadinessFilter =
  | 'all'
  | 'ready'
  | 'missing_department'
  | 'missing_position'
  | 'missing_cost_center'
  | 'missing_manager'

export type EmployeeAssignmentReadinessFlags = {
  hasDepartment: boolean
  hasPosition: boolean
  hasCostCenter: boolean
  hasManager: boolean
  hasInactiveReference: boolean
}

export type EmployeeAssignmentEntityRef = {
  id: string
  name: string
  code: string | null
  isActive: boolean
}

export type EmployeeAssignmentManagerRef = {
  id: string
  displayName: string
  email: string | null
  isActive: boolean
}

export type EmployeeAssignmentReadinessEmployee = {
  id: string
  displayName: string
  email: string | null
  employeeNumber: string | null
  isActive: boolean
  source: OrgSetupEntitySource
  canEditAssignment: boolean
  department: EmployeeAssignmentEntityRef | null
  position: EmployeeAssignmentEntityRef | null
  costCenter: EmployeeAssignmentEntityRef | null
  manager: EmployeeAssignmentManagerRef | null
  readiness: {
    status: EmployeeAssignmentReadinessStatus
    flags: EmployeeAssignmentReadinessFlags
  }
}

export type EmployeeAssignmentReadinessSummary = {
  total: number
  active: number
  ready: number
  missingDepartment: number
  missingPosition: number
  missingCostCenter: number
  missingManager: number
  inactiveReferences: number
}

export type EmployeeAssignmentReadinessOverview = {
  employees: EmployeeAssignmentReadinessEmployee[]
  summary: EmployeeAssignmentReadinessSummary
}

export type EmployeeAssignmentDepartmentOption = EmployeeAssignmentEntityRef

export type EmployeeAssignmentPositionOption = EmployeeAssignmentEntityRef & {
  departmentId: string | null
}

export type EmployeeAssignmentCostCenterOption = EmployeeAssignmentEntityRef

export type EmployeeAssignmentManagerOption = EmployeeAssignmentManagerRef

export type EmployeeAssignmentEditOptions = {
  departments: EmployeeAssignmentDepartmentOption[]
  positions: EmployeeAssignmentPositionOption[]
  costCenters: EmployeeAssignmentCostCenterOption[]
  managers: EmployeeAssignmentManagerOption[]
}

export type CostCenterAssignmentRow = {
  id: string
  employee_id: string
  cost_center_id: string
  starts_on: string
  updated_at: string
  is_active: boolean
}

export type ReportingLineRow = {
  id: string
  employee_id: string
  manager_employee_id: string
  starts_on: string
  created_at: string
  is_active: boolean
  relationship_type: string
}

export function buildEmployeeAssignmentReadinessFlags(input: {
  department: EmployeeAssignmentEntityRef | null
  position: EmployeeAssignmentEntityRef | null
  costCenter: EmployeeAssignmentEntityRef | null
  manager: EmployeeAssignmentManagerRef | null
}): EmployeeAssignmentReadinessFlags {
  const hasDepartment = input.department !== null
  const hasPosition = input.position !== null
  const hasCostCenter = input.costCenter !== null
  const hasManager = input.manager !== null
  const hasInactiveReference =
    (input.department !== null && !input.department.isActive) ||
    (input.position !== null && !input.position.isActive) ||
    (input.costCenter !== null && !input.costCenter.isActive) ||
    (input.manager !== null && !input.manager.isActive)

  return {
    hasDepartment,
    hasPosition,
    hasCostCenter,
    hasManager,
    hasInactiveReference,
  }
}

export function computeEmployeeAssignmentReadiness(
  flags: EmployeeAssignmentReadinessFlags,
  { isActiveEmployee }: { isActiveEmployee: boolean },
): EmployeeAssignmentReadinessStatus {
  if (!isActiveEmployee) return 'partial'
  if (flags.hasInactiveReference) return 'inactive_reference'
  if (!flags.hasDepartment) return 'missing_department'
  if (!flags.hasPosition) return 'missing_position'
  if (!flags.hasCostCenter) return 'missing_cost_center'
  if (!flags.hasManager) return 'missing_manager'
  return 'ready'
}

export function pickCurrentCostCenterAssignment<T extends CostCenterAssignmentRow>(
  rows: T[],
): T | null {
  const activeRows = rows.filter((row) => row.is_active)
  if (activeRows.length === 0) return null

  return [...activeRows].sort((left, right) => {
    const startsCompare = right.starts_on.localeCompare(left.starts_on)
    if (startsCompare !== 0) return startsCompare
    const updatedCompare = right.updated_at.localeCompare(left.updated_at)
    if (updatedCompare !== 0) return updatedCompare
    return left.id.localeCompare(right.id)
  })[0] ?? null
}

export function pickCurrentPrimaryManager<T extends ReportingLineRow>(
  rows: T[],
  cacheManagerId?: string | null,
): string | null {
  const primaryRows = rows.filter(
    (row) => row.is_active && row.relationship_type === 'primary_manager',
  )

  if (primaryRows.length > 0) {
    const picked = [...primaryRows].sort((left, right) => {
      const startsCompare = right.starts_on.localeCompare(left.starts_on)
      if (startsCompare !== 0) return startsCompare
      return right.created_at.localeCompare(left.created_at)
    })[0]
    return picked?.manager_employee_id ?? null
  }

  return cacheManagerId ?? null
}

export function buildEmployeeAssignmentReadinessSummary(
  employees: EmployeeAssignmentReadinessEmployee[],
): EmployeeAssignmentReadinessSummary {
  const summary: EmployeeAssignmentReadinessSummary = {
    total: employees.length,
    active: 0,
    ready: 0,
    missingDepartment: 0,
    missingPosition: 0,
    missingCostCenter: 0,
    missingManager: 0,
    inactiveReferences: 0,
  }

  for (const employee of employees) {
    if (!employee.isActive) continue

    summary.active += 1

    switch (employee.readiness.status) {
      case 'ready':
        summary.ready += 1
        break
      case 'missing_department':
        summary.missingDepartment += 1
        break
      case 'missing_position':
        summary.missingPosition += 1
        break
      case 'missing_cost_center':
        summary.missingCostCenter += 1
        break
      case 'missing_manager':
        summary.missingManager += 1
        break
      case 'inactive_reference':
        summary.inactiveReferences += 1
        break
      default:
        break
    }
  }

  return summary
}

export function applyEmployeeAssignmentReadinessFilter(
  employees: EmployeeAssignmentReadinessEmployee[],
  filter: EmployeeAssignmentReadinessFilter,
): EmployeeAssignmentReadinessEmployee[] {
  if (filter === 'all') return employees
  return employees.filter((employee) => employee.readiness.status === filter)
}

function emptyOverview(): EmployeeAssignmentReadinessOverview {
  return {
    employees: [],
    summary: buildEmployeeAssignmentReadinessSummary([]),
  }
}

type MasterRow = {
  id: string
  name: string
  code: string | null
  is_active: boolean
}

type EmployeeRow = {
  id: string
  full_name: string
  email: string | null
  employee_code: string | null
  employment_status: string
  external_source: string | null
  department_id: string | null
  position_id: string | null
  manager_employee_id: string | null
}

function mapEntityRef(row: MasterRow | undefined): EmployeeAssignmentEntityRef | null {
  if (!row) return null
  return {
    id: row.id,
    name: row.name,
    code: row.code,
    isActive: Boolean(row.is_active),
  }
}

function mapManagerRef(
  row: { id: string; full_name: string | null; email: string | null; employment_status: string } | undefined,
): EmployeeAssignmentManagerRef | null {
  if (!row) return null
  return {
    id: row.id,
    displayName: row.full_name ?? '—',
    email: row.email,
    isActive: row.employment_status === 'active',
  }
}

export function mapManagerRefFromVisibleRow(
  managerId: string | null,
  row: { id: string; full_name: string | null; email: string | null; employment_status: string } | undefined,
): EmployeeAssignmentManagerRef | null {
  const visible = mapManagerRef(row)
  if (visible || !managerId) return visible

  return {
    id: managerId,
    displayName: '—',
    email: null,
    isActive: true,
  }
}

async function buildEmployeeAssignmentReadinessFromRows(
  tenantId: string,
  rows: EmployeeRow[],
): Promise<EmployeeAssignmentReadinessEmployee[]> {
  if (rows.length === 0) return []

  const employeeIds = rows.map((row) => row.id)
  const departmentIds = [...new Set(rows.map((row) => row.department_id).filter(Boolean))] as string[]
  const positionIds = [...new Set(rows.map((row) => row.position_id).filter(Boolean))] as string[]

  const [
    departmentsResult,
    positionsResult,
    ccAssignmentsResult,
    reportingLinesResult,
  ] = await Promise.all([
    departmentIds.length > 0
      ? pulsCore()
          .from('departments')
          .select('id, name, code, is_active')
          .eq('tenant_id', tenantId)
          .in('id', departmentIds)
      : Promise.resolve({ data: [], error: null }),
    positionIds.length > 0
      ? pulsCore()
          .from('positions')
          .select('id, name, code, is_active')
          .eq('tenant_id', tenantId)
          .in('id', positionIds)
      : Promise.resolve({ data: [], error: null }),
    pulsCore()
      .from('employee_cost_center_assignments')
      .select('id, employee_id, cost_center_id, starts_on, updated_at, is_active')
      .eq('tenant_id', tenantId)
      .in('employee_id', employeeIds)
      .eq('is_active', true),
    pulsCore()
      .from('employee_reporting_lines')
      .select('id, employee_id, manager_employee_id, starts_on, created_at, is_active, relationship_type')
      .eq('tenant_id', tenantId)
      .in('employee_id', employeeIds)
      .eq('is_active', true)
      .eq('relationship_type', 'primary_manager'),
  ])

  if (departmentsResult.error) {
    throw fromSupabaseError(
      departmentsResult.error,
      'fetchEmployeeAssignmentReadiness',
      'puls_core',
      'departments',
    )
  }
  if (positionsResult.error) {
    throw fromSupabaseError(
      positionsResult.error,
      'fetchEmployeeAssignmentReadiness',
      'puls_core',
      'positions',
    )
  }
  if (ccAssignmentsResult.error) {
    throw fromSupabaseError(
      ccAssignmentsResult.error,
      'fetchEmployeeAssignmentReadiness',
      'puls_core',
      'employee_cost_center_assignments',
    )
  }
  if (reportingLinesResult.error) {
    throw fromSupabaseError(
      reportingLinesResult.error,
      'fetchEmployeeAssignmentReadiness',
      'puls_core',
      'employee_reporting_lines',
    )
  }

  const ccAssignmentsByEmployee = new Map<string, CostCenterAssignmentRow[]>()
  for (const row of ccAssignmentsResult.data ?? []) {
    const employeeId = row.employee_id as string
    const list = ccAssignmentsByEmployee.get(employeeId) ?? []
    list.push({
      id: row.id as string,
      employee_id: employeeId,
      cost_center_id: row.cost_center_id as string,
      starts_on: row.starts_on as string,
      updated_at: row.updated_at as string,
      is_active: Boolean(row.is_active),
    })
    ccAssignmentsByEmployee.set(employeeId, list)
  }

  const reportingLinesByEmployee = new Map<string, ReportingLineRow[]>()
  for (const row of reportingLinesResult.data ?? []) {
    const employeeId = row.employee_id as string
    const list = reportingLinesByEmployee.get(employeeId) ?? []
    list.push({
      id: row.id as string,
      employee_id: employeeId,
      manager_employee_id: row.manager_employee_id as string,
      starts_on: row.starts_on as string,
      created_at: row.created_at as string,
      is_active: Boolean(row.is_active),
      relationship_type: row.relationship_type as string,
    })
    reportingLinesByEmployee.set(employeeId, list)
  }

  const pickedCcByEmployee = new Map<string, CostCenterAssignmentRow>()
  for (const [employeeId, assignments] of ccAssignmentsByEmployee) {
    const picked = pickCurrentCostCenterAssignment(assignments)
    if (picked) pickedCcByEmployee.set(employeeId, picked)
  }

  const costCenterIds = [
    ...new Set([...pickedCcByEmployee.values()].map((row) => row.cost_center_id)),
  ]

  const managerIds = new Set<string>()
  for (const row of rows) {
    const fromReporting = pickCurrentPrimaryManager(
      reportingLinesByEmployee.get(row.id) ?? [],
      row.manager_employee_id,
    )
    if (fromReporting) managerIds.add(fromReporting)
  }

  const [costCentersResult, managersResult] = await Promise.all([
    costCenterIds.length > 0
      ? pulsCore()
          .from('cost_centers')
          .select('id, name, code, is_active')
          .eq('tenant_id', tenantId)
          .in('id', costCenterIds)
      : Promise.resolve({ data: [], error: null }),
    managerIds.size > 0
      ? pulsCore()
          .from('employees')
          .select('id, full_name, email, employment_status')
          .eq('tenant_id', tenantId)
          .in('id', [...managerIds])
      : Promise.resolve({ data: [], error: null }),
  ])

  if (costCentersResult.error) {
    throw fromSupabaseError(
      costCentersResult.error,
      'fetchEmployeeAssignmentReadiness',
      'puls_core',
      'cost_centers',
    )
  }
  if (managersResult.error) {
    throw fromSupabaseError(
      managersResult.error,
      'fetchEmployeeAssignmentReadiness',
      'puls_core',
      'employees',
    )
  }

  const departmentMap = new Map(
    (departmentsResult.data ?? []).map((row) => [row.id as string, row as MasterRow]),
  )
  const positionMap = new Map(
    (positionsResult.data ?? []).map((row) => [row.id as string, row as MasterRow]),
  )
  const costCenterMap = new Map(
    (costCentersResult.data ?? []).map((row) => [row.id as string, row as MasterRow]),
  )
  const managerMap = new Map(
    (managersResult.data ?? []).map((row) => [
      row.id as string,
      row as {
        id: string
        full_name: string | null
        email: string | null
        employment_status: string
      },
    ]),
  )

  return rows.map((row) => {
    const isActiveEmployee = row.employment_status === 'active'
    const department = row.department_id
      ? mapEntityRef(departmentMap.get(row.department_id))
      : null
    const position = row.position_id ? mapEntityRef(positionMap.get(row.position_id)) : null

    const pickedCc = pickedCcByEmployee.get(row.id)
    const costCenter = pickedCc
      ? mapEntityRef(costCenterMap.get(pickedCc.cost_center_id))
      : null

    const managerId = pickCurrentPrimaryManager(
      reportingLinesByEmployee.get(row.id) ?? [],
      row.manager_employee_id,
    )
    const manager = mapManagerRefFromVisibleRow(
      managerId,
      managerId ? managerMap.get(managerId) : undefined,
    )

    const flags = buildEmployeeAssignmentReadinessFlags({
      department,
      position,
      costCenter,
      manager,
    })
    const status = computeEmployeeAssignmentReadiness(flags, { isActiveEmployee })
    const source = mapOrgEntitySource(row.external_source)

    return {
      id: row.id,
      displayName: row.full_name ?? '—',
      email: row.email,
      employeeNumber: row.employee_code,
      isActive: isActiveEmployee,
      source,
      canEditAssignment: isOrgEntityEditable(source) && isActiveEmployee,
      department,
      position,
      costCenter,
      manager,
      readiness: { status, flags },
    }
  })
}

async function fetchEmployeeRowsForReadiness(
  tenantId: string,
  employeeId?: string | null,
): Promise<EmployeeRow[]> {
  let query = pulsCore()
    .from('employees')
    .select(
      'id, full_name, email, employee_code, employment_status, external_source, department_id, position_id, manager_employee_id',
    )
    .eq('tenant_id', tenantId)

  if (employeeId) {
    query = query.eq('id', employeeId)
  } else {
    query = query.order('full_name', { ascending: true })
  }

  const { data: employeeRows, error: employeeError } = await query

  if (employeeError) {
    throw fromSupabaseError(
      employeeError,
      'fetchEmployeeAssignmentReadiness',
      'puls_core',
      'employees',
    )
  }

  return (employeeRows ?? []) as EmployeeRow[]
}

function sortByName<T extends { name: string }>(rows: T[]): T[] {
  return [...rows].sort((left, right) => left.name.localeCompare(right.name, 'tr'))
}

function sortManagers(rows: EmployeeAssignmentManagerOption[]): EmployeeAssignmentManagerOption[] {
  return [...rows].sort((left, right) => left.displayName.localeCompare(right.displayName, 'tr'))
}

async function fetchRealEmployeeAssignmentEditOptions(
  userId: string,
): Promise<EmployeeAssignmentEditOptions> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    return {
      departments: [],
      positions: [],
      costCenters: [],
      managers: [],
    }
  }

  const [departmentsResult, positionsResult, costCentersResult, managersResult] = await Promise.all([
    pulsCore()
      .from('departments')
      .select('id, name, code, is_active')
      .eq('tenant_id', ctx.tenantId)
      .eq('is_active', true)
      .order('name', { ascending: true }),
    pulsCore()
      .from('positions')
      .select('id, name, code, department_id, is_active')
      .eq('tenant_id', ctx.tenantId)
      .eq('is_active', true)
      .order('name', { ascending: true }),
    pulsCore()
      .from('cost_centers')
      .select('id, name, code, is_active')
      .eq('tenant_id', ctx.tenantId)
      .eq('is_active', true)
      .order('name', { ascending: true }),
    pulsCore()
      .from('employees')
      .select('id, full_name, email, employment_status')
      .eq('tenant_id', ctx.tenantId)
      .eq('employment_status', 'active')
      .order('full_name', { ascending: true }),
  ])

  if (departmentsResult.error) {
    throw fromSupabaseError(
      departmentsResult.error,
      'fetchEmployeeAssignmentEditOptions',
      'puls_core',
      'departments',
    )
  }
  if (positionsResult.error) {
    throw fromSupabaseError(
      positionsResult.error,
      'fetchEmployeeAssignmentEditOptions',
      'puls_core',
      'positions',
    )
  }
  if (costCentersResult.error) {
    throw fromSupabaseError(
      costCentersResult.error,
      'fetchEmployeeAssignmentEditOptions',
      'puls_core',
      'cost_centers',
    )
  }
  if (managersResult.error) {
    throw fromSupabaseError(
      managersResult.error,
      'fetchEmployeeAssignmentEditOptions',
      'puls_core',
      'employees',
    )
  }

  return {
    departments: sortByName(
      (departmentsResult.data ?? []).map((row) => ({
        id: row.id as string,
        name: row.name as string,
        code: (row.code as string | null) ?? null,
        isActive: Boolean(row.is_active),
      })),
    ),
    positions: sortByName(
      (positionsResult.data ?? []).map((row) => ({
        id: row.id as string,
        name: row.name as string,
        code: (row.code as string | null) ?? null,
        departmentId: (row.department_id as string | null) ?? null,
        isActive: Boolean(row.is_active),
      })),
    ),
    costCenters: sortByName(
      (costCentersResult.data ?? []).map((row) => ({
        id: row.id as string,
        name: row.name as string,
        code: (row.code as string | null) ?? null,
        isActive: Boolean(row.is_active),
      })),
    ),
    managers: sortManagers(
      (managersResult.data ?? []).map((row) => ({
        id: row.id as string,
        displayName: (row.full_name as string | null) ?? '—',
        email: (row.email as string | null) ?? null,
        isActive: row.employment_status === 'active',
      })),
    ),
  }
}

export async function fetchEmployeeAssignmentEditOptions(
  userId: string,
): Promise<EmployeeAssignmentEditOptions> {
  return fetchRealEmployeeAssignmentEditOptions(userId)
}

async function fetchRealEmployeeAssignmentReadiness(
  userId: string,
): Promise<EmployeeAssignmentReadinessOverview> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) return emptyOverview()

  const rows = await fetchEmployeeRowsForReadiness(ctx.tenantId)
  if (rows.length === 0) return emptyOverview()

  const employees = await buildEmployeeAssignmentReadinessFromRows(ctx.tenantId, rows)
  return {
    employees,
    summary: buildEmployeeAssignmentReadinessSummary(employees),
  }
}

async function fetchRealCurrentEmployeeAssignmentReadiness(
  userId: string,
): Promise<EmployeeAssignmentReadinessEmployee | null> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId || !ctx.employeeId) return null

  const rows = await fetchEmployeeRowsForReadiness(ctx.tenantId, ctx.employeeId)
  if (rows.length === 0) return null

  const employees = await buildEmployeeAssignmentReadinessFromRows(ctx.tenantId, rows)
  return employees[0] ?? null
}

export function fetchCurrentEmployeeAssignmentReadinessWithMeta(userId: string) {
  return resolveAdapterDataWithMeta({
    operation: 'fetchCurrentEmployeeAssignmentReadiness',
    fetchReal: () => fetchRealCurrentEmployeeAssignmentReadiness(userId),
    fetchDemo: async () => {
      const overview = await fetchDemoEmployeeAssignmentReadiness()
      return overview.employees.find((employee) => employee.id === 'demo-e-ready') ?? null
    },
    isEmpty: (data) => data === null,
  })
}

export async function fetchCurrentEmployeeAssignmentReadiness(
  userId: string,
): Promise<EmployeeAssignmentReadinessEmployee | null> {
  const result = await fetchCurrentEmployeeAssignmentReadinessWithMeta(userId)
  if (result.status === 'error' && result.error) {
    throw result.error
  }
  return result.data
}

export function fetchEmployeeAssignmentReadinessWithMeta(userId: string) {
  return resolveAdapterDataWithMeta({
    operation: 'fetchEmployeeAssignmentReadiness',
    fetchReal: () => fetchRealEmployeeAssignmentReadiness(userId),
    fetchDemo: fetchDemoEmployeeAssignmentReadiness,
    isEmpty: (data) => data.employees.length === 0,
  })
}

export async function fetchEmployeeAssignmentReadiness(
  userId: string,
): Promise<EmployeeAssignmentReadinessOverview & { source: DataResult<unknown>['source'] }> {
  const result = await fetchEmployeeAssignmentReadinessWithMeta(userId)
  if (result.status === 'error' && result.error) {
    throw result.error
  }
  return {
    ...result.data,
    source: result.source,
  }
}
