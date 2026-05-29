import {
  fetchDemoDepartmentsOverview,
  fetchDemoPositionsOverview,
} from '#/lib/demo/puls-demo-data'
import type { DemoDepartmentsOverview, DemoPositionsOverview } from '#/lib/demo/puls-demo-data'
import {
  DataAdapterError,
  fromSupabaseError,
  isDataAdapterError,
  parseRpcErrorCode,
} from '#/lib/data/errors'
import type { DepartmentFieldKey, PositionFieldKey } from '#/lib/data/setup/org-setup-validation'
import { pulsCalc, pulsCore, resolveTenantContext } from '#/lib/data/client'
import {
  computeOpenHeadcount,
  countActiveEmployeesByDepartment,
  countActiveEmployeesByPosition,
  fetchNamesByIds,
  uniqueNonNullIds,
} from '#/lib/data/core/lookups'
import { mapOrgEntitySource, isOrgEntityEditable, type OrgSetupEntitySource } from '#/lib/data/setup/org-entity-source'
import { normalizeOrgSetupCode } from '#/lib/data/setup/org-setup-validation'
import { resolveAdapterData, resolveAdapterDataWithMeta } from '#/lib/data/result'

export type DepartmentsOverview = DemoDepartmentsOverview
export type PositionsOverview = DemoPositionsOverview

export type DepartmentMutationInput = {
  name: string
  code: string
}

export type PositionMutationInput = {
  name: string
  code: string
  departmentId: string | null
  normHeadcount: number | null
}

export type DepartmentMutationErrorMapping = {
  fieldErrors: Partial<Record<DepartmentFieldKey, string>>
  toastKey?: string
}

export type PositionMutationErrorMapping = {
  fieldErrors: Partial<Record<PositionFieldKey, string>>
  toastKey?: string
}

const PULS_DEPARTMENT_ERROR_MAP: Record<string, { field: DepartmentFieldKey; i18nKey: string }> = {
  PULS_ORG_DEPARTMENT_NAME_REQUIRED: {
    field: 'name',
    i18nKey: 'orgSetupCrud.validation.nameRequired',
  },
  PULS_ORG_DEPARTMENT_CODE_REQUIRED: {
    field: 'code',
    i18nKey: 'orgSetupCrud.validation.codeRequired',
  },
  PULS_ORG_DEPARTMENT_CODE_INVALID: {
    field: 'code',
    i18nKey: 'orgSetupCrud.validation.codeInvalid',
  },
  PULS_ORG_DEPARTMENT_MANAGER_INVALID: {
    field: 'code',
    i18nKey: 'orgSetupCrud.validation.generic',
  },
  PULS_ORG_DEPARTMENT_COST_CENTER_INVALID: {
    field: 'code',
    i18nKey: 'orgSetupCrud.validation.generic',
  },
  PULS_ORG_DEPARTMENT_SOURCE_READ_ONLY: {
    field: 'code',
    i18nKey: 'orgSetupCrud.validation.sourceReadOnly',
  },
}

const PULS_POSITION_ERROR_MAP: Record<string, { field: PositionFieldKey; i18nKey: string }> = {
  PULS_ORG_POSITION_NAME_REQUIRED: {
    field: 'name',
    i18nKey: 'orgSetupCrud.validation.nameRequired',
  },
  PULS_ORG_POSITION_CODE_REQUIRED: {
    field: 'code',
    i18nKey: 'orgSetupCrud.validation.codeRequired',
  },
  PULS_ORG_POSITION_CODE_INVALID: {
    field: 'code',
    i18nKey: 'orgSetupCrud.validation.codeInvalid',
  },
  PULS_ORG_POSITION_DEPARTMENT_INVALID: {
    field: 'departmentId',
    i18nKey: 'orgSetupCrud.validation.departmentInvalid',
  },
  PULS_ORG_POSITION_NORM_INVALID: {
    field: 'normHeadcount',
    i18nKey: 'orgSetupCrud.validation.normInvalid',
  },
  PULS_ORG_POSITION_SOURCE_READ_ONLY: {
    field: 'code',
    i18nKey: 'orgSetupCrud.validation.sourceReadOnly',
  },
}

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
    const source = mapOrgEntitySource(row.external_source as string | null) as OrgSetupEntitySource
    return {
      id: row.id as string,
      name: row.name as string,
      code: (row.code as string | null) ?? null,
      manager: managerId ? (managerNameMap.get(managerId) ?? '—') : '—',
      count: countByDept.get(row.id as string) ?? 0,
      isActive,
      source,
      isEditable: isOrgEntityEditable(source),
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
    const source = mapOrgEntitySource(row.external_source as string | null) as OrgSetupEntitySource

    return {
      id: positionId,
      name: row.name as string,
      code: (row.code as string | null) ?? null,
      department: departmentId ? (departmentNameMap.get(departmentId) ?? '—') : '—',
      departmentId,
      normHeadcount,
      template: '—',
      evaluation: 0,
      open: computeOpenHeadcount(normHeadcount, filledCount),
      isActive: Boolean(row.is_active),
      source,
      isEditable: isOrgEntityEditable(source),
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

function duplicateDepartment23505Mapping(
  error: DataAdapterError,
): DepartmentMutationErrorMapping | null {
  const haystack = `${error.message} ${error.hint ?? ''} ${error.details ?? ''}`.toLowerCase()
  if (haystack.includes('(tenant_id, code)') || haystack.includes('departments')) {
    return { fieldErrors: { code: 'orgSetupCrud.validation.duplicateCode' } }
  }
  return null
}

function duplicatePosition23505Mapping(error: DataAdapterError): PositionMutationErrorMapping | null {
  const haystack = `${error.message} ${error.hint ?? ''} ${error.details ?? ''}`.toLowerCase()
  if (haystack.includes('(tenant_id, code)') || haystack.includes('positions')) {
    return { fieldErrors: { code: 'orgSetupCrud.validation.duplicateCode' } }
  }
  return null
}

export function mapDepartmentMutationError(error: unknown): DepartmentMutationErrorMapping {
  const fallback: DepartmentMutationErrorMapping = {
    fieldErrors: {},
    toastKey: 'orgSetupCrud.validation.generic',
  }

  if (!isDataAdapterError(error)) {
    return fallback
  }

  const pulsCode = parseRpcErrorCode(error.message)
  if (pulsCode) {
    const mapped = PULS_DEPARTMENT_ERROR_MAP[pulsCode]
    if (mapped) {
      return { fieldErrors: { [mapped.field]: mapped.i18nKey } }
    }
  }

  if (error.code === '23505') {
    const duplicateMapping = duplicateDepartment23505Mapping(error)
    if (duplicateMapping) return duplicateMapping
  }

  return fallback
}

export function mapPositionMutationError(error: unknown): PositionMutationErrorMapping {
  const fallback: PositionMutationErrorMapping = {
    fieldErrors: {},
    toastKey: 'orgSetupCrud.validation.generic',
  }

  if (!isDataAdapterError(error)) {
    return fallback
  }

  const pulsCode = parseRpcErrorCode(error.message)
  if (pulsCode) {
    const mapped = PULS_POSITION_ERROR_MAP[pulsCode]
    if (mapped) {
      return { fieldErrors: { [mapped.field]: mapped.i18nKey } }
    }
  }

  if (error.code === '23505') {
    const duplicateMapping = duplicatePosition23505Mapping(error)
    if (duplicateMapping) return duplicateMapping
  }

  return fallback
}

function buildDepartmentWritePayload(input: DepartmentMutationInput) {
  return {
    name: input.name.trim(),
    code: normalizeOrgSetupCode(input.code),
  }
}

function buildPositionWritePayload(input: PositionMutationInput) {
  return {
    name: input.name.trim(),
    code: normalizeOrgSetupCode(input.code),
    department_id: input.departmentId,
    norm_headcount: input.normHeadcount ?? 1,
  }
}

export async function createDepartment(
  userId: string,
  input: DepartmentMutationInput,
): Promise<void> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    throw new Error('Missing tenant context')
  }

  const { error } = await pulsCore()
    .from('departments')
    .insert({
      tenant_id: ctx.tenantId,
      ...buildDepartmentWritePayload(input),
      is_active: true,
    })
    .select('id')
    .single()

  if (error) {
    throw fromSupabaseError(error, 'createDepartment', 'puls_core', 'departments')
  }
}

export async function updateDepartment(
  userId: string,
  departmentId: string,
  input: DepartmentMutationInput,
): Promise<void> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    throw new Error('Missing tenant context')
  }

  const { data, error } = await pulsCore()
    .from('departments')
    .update(buildDepartmentWritePayload(input))
    .eq('tenant_id', ctx.tenantId)
    .eq('id', departmentId)
    .select('id')
    .maybeSingle()

  if (error) {
    throw fromSupabaseError(error, 'updateDepartment', 'puls_core', 'departments')
  }

  if (!data) {
    throw new DataAdapterError({
      code: 'not_found',
      message: 'Department was not updated',
      source: 'adapter',
      operation: 'updateDepartment',
      schema: 'puls_core',
      table: 'departments',
    })
  }
}

export async function createPosition(userId: string, input: PositionMutationInput): Promise<void> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    throw new Error('Missing tenant context')
  }

  const { error } = await pulsCore()
    .from('positions')
    .insert({
      tenant_id: ctx.tenantId,
      ...buildPositionWritePayload(input),
      is_active: true,
    })
    .select('id')
    .single()

  if (error) {
    throw fromSupabaseError(error, 'createPosition', 'puls_core', 'positions')
  }
}

export async function updatePosition(
  userId: string,
  positionId: string,
  input: PositionMutationInput,
): Promise<void> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    throw new Error('Missing tenant context')
  }

  const { data, error } = await pulsCore()
    .from('positions')
    .update(buildPositionWritePayload(input))
    .eq('tenant_id', ctx.tenantId)
    .eq('id', positionId)
    .select('id')
    .maybeSingle()

  if (error) {
    throw fromSupabaseError(error, 'updatePosition', 'puls_core', 'positions')
  }

  if (!data) {
    throw new DataAdapterError({
      code: 'not_found',
      message: 'Position was not updated',
      source: 'adapter',
      operation: 'updatePosition',
      schema: 'puls_core',
      table: 'positions',
    })
  }
}
