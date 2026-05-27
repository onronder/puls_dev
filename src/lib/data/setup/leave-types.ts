import { fetchDemoLeaveTypesOverview } from '#/lib/demo/puls-demo-data'
import type { DemoLeaveTypesOverview } from '#/lib/demo/puls-demo-data'
import { DataAdapterError, fromSupabaseError, isDataAdapterError, parseRpcErrorCode } from '#/lib/data/errors'
import { pulsWorkflow, resolveTenantContext } from '#/lib/data/client'
import { resolveAdapterData } from '#/lib/data/result'
import {
  buildApprovalPolicyBindingInfo,
  parseApprovalPolicyJoin,
} from '#/lib/data/workflow/policy-binding-readiness'
import {
  normalizeLeaveTypeCode,
  type LeaveTypeFieldKey,
} from '#/lib/data/setup/leave-type-validation'

export type LeaveTypesOverview = DemoLeaveTypesOverview

export type LeaveTypeMutationInput = {
  name: string
  code: string
  defaultEntitlementDays: number | null
  requiresDocument: boolean
  carryOverAllowed: boolean
  maxCarryOverDays: number | null
  approvalPolicyId: string | null
}

export type LeaveTypeMutationErrorMapping = {
  fieldErrors: Partial<Record<LeaveTypeFieldKey, string>>
  toastKey?: string
}

const LEAVE_TYPE_LABEL_KEYS: Record<string, string> = {
  annual: 'leaveTypeSetup.types.annual',
  excuse: 'leaveTypeSetup.types.excuse',
  sick: 'leaveTypeSetup.types.sick',
  unpaid: 'leaveTypeSetup.types.unpaid',
  administrative: 'leaveTypeSetup.types.administrative',
  marriage: 'leaveTypeSetup.types.marriage',
  parental: 'leaveTypeSetup.types.parental',
  birth: 'leaveTypeSetup.types.parental',
  bereavement: 'leaveTypeSetup.types.bereavement',
}

const PULS_LEAVE_TYPE_ERROR_MAP: Record<
  string,
  { field: LeaveTypeFieldKey; i18nKey: string }
> = {
  PULS_LEAVE_TYPE_NAME_REQUIRED: {
    field: 'name',
    i18nKey: 'leaveTypeSetup.validation.nameRequired',
  },
  PULS_LEAVE_TYPE_CODE_REQUIRED: {
    field: 'code',
    i18nKey: 'leaveTypeSetup.validation.codeRequired',
  },
  PULS_LEAVE_TYPE_CODE_INVALID: {
    field: 'code',
    i18nKey: 'leaveTypeSetup.validation.codeInvalid',
  },
  PULS_LEAVE_TYPE_ENTITLEMENT_INVALID: {
    field: 'defaultEntitlementDays',
    i18nKey: 'leaveTypeSetup.validation.entitlementInvalid',
  },
  PULS_LEAVE_TYPE_CARRY_OVER_INVALID: {
    field: 'maxCarryOverDays',
    i18nKey: 'leaveTypeSetup.validation.carryOverInvalid',
  },
  PULS_LEAVE_TYPE_POLICY_INVALID: {
    field: 'approvalPolicyId',
    i18nKey: 'leaveTypeSetup.validation.policyInvalid',
  },
  PULS_LEAVE_TYPE_POLICY_MODULE_INVALID: {
    field: 'approvalPolicyId',
    i18nKey: 'leaveTypeSetup.validation.policyModuleInvalid',
  },
}

export { normalizeLeaveTypeCode }

function duplicate23505Mapping(error: DataAdapterError): LeaveTypeMutationErrorMapping | null {
  const haystack = `${error.message} ${error.hint ?? ''} ${error.details ?? ''}`.toLowerCase()

  if (
    haystack.includes('leave_types_tenant_id_code_key') ||
    haystack.includes('(tenant_id, code)')
  ) {
    return {
      fieldErrors: {
        code: 'leaveTypeSetup.validation.duplicateCode',
      },
    }
  }

  return null
}

export function mapLeaveTypeMutationError(error: unknown): LeaveTypeMutationErrorMapping {
  const fallback: LeaveTypeMutationErrorMapping = {
    fieldErrors: {},
    toastKey: 'leaveTypeSetup.errors.saveFailed',
  }

  if (!isDataAdapterError(error)) {
    return fallback
  }

  const pulsCode = parseRpcErrorCode(error.message)
  if (pulsCode) {
    const mapped = PULS_LEAVE_TYPE_ERROR_MAP[pulsCode]
    if (mapped) {
      return {
        fieldErrors: {
          [mapped.field]: mapped.i18nKey,
        },
      }
    }
  }

  if (error.code === '23505') {
    const duplicateMapping = duplicate23505Mapping(error)
    if (duplicateMapping) {
      return duplicateMapping
    }
  }

  return fallback
}

function emptyLeaveTypesOverview(): LeaveTypesOverview {
  return {
    typeCount: 0,
    paidCount: 0,
    docRequiredCount: 0,
    maxApprovalStepCount: 0,
    leaveTypes: [],
  }
}

function mapLeaveTypeRow(
  row: {
    id: string
    code: string
    name: string
    default_entitlement_days: number | null
    is_paid: boolean
    requires_document: boolean
    carry_over_allowed: boolean
    max_carry_over_days: number | null
    approval_policy_id: string | null
    approval_policies:
      | { name: string; module: string; is_active: boolean }
      | { name: string; module: string; is_active: boolean }[]
      | null
  },
  requiredStepCountByPolicy: Map<string, number>,
) {
  const code = row.code
  const policyId = row.approval_policy_id ?? null
  const policyMeta = parseApprovalPolicyJoin(row.approval_policies)
  const requiredStepCount = policyId ? (requiredStepCountByPolicy.get(policyId) ?? 0) : 0

  return {
    id: row.id,
    code,
    name: row.name,
    labelKey: LEAVE_TYPE_LABEL_KEYS[code] ?? code,
    defaultEntitlementDays:
      row.default_entitlement_days === null
        ? null
        : Number(row.default_entitlement_days),
    days: Number(row.default_entitlement_days ?? 0),
    paid: Boolean(row.is_paid),
    doc: Boolean(row.requires_document),
    carryOver: Boolean(row.carry_over_allowed),
    maxCarryOverDays:
      row.max_carry_over_days === null ? null : Number(row.max_carry_over_days),
    approvalPolicyId: policyId,
    approvalPolicyName: policyMeta.policyName,
    approvalStepCount: policyId ? requiredStepCount : 1,
    approvalPolicy: buildApprovalPolicyBindingInfo({
      expectedModule: 'leave',
      policyId,
      policyName: policyMeta.policyName,
      policyModule: policyMeta.policyModule,
      policyIsActive: policyMeta.policyIsActive,
      requiredStepCount,
    }),
  }
}

async function fetchRealLeaveTypesOverview(userId: string): Promise<LeaveTypesOverview> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) return emptyLeaveTypesOverview()

  const { data, error } = await pulsWorkflow()
    .from('leave_types')
    .select(
      'id, code, name, default_entitlement_days, is_paid, requires_document, carry_over_allowed, max_carry_over_days, approval_policy_id, approval_policies ( name, module, is_active )',
    )
    .eq('tenant_id', ctx.tenantId)
    .eq('is_active', true)
    .order('name', { ascending: true })

  if (error) {
    throw fromSupabaseError(error, 'fetchLeaveTypesOverview', 'puls_workflow', 'leave_types')
  }

  const policyIds = [
    ...new Set(
      (data ?? [])
        .map((row) => row.approval_policy_id as string | null)
        .filter((id): id is string => Boolean(id)),
    ),
  ]

  const requiredStepCountByPolicy = new Map<string, number>()
  if (policyIds.length > 0) {
    const { data: steps, error: stepsError } = await pulsWorkflow()
      .from('approval_policy_steps')
      .select('policy_id, is_required')
      .eq('tenant_id', ctx.tenantId)
      .in('policy_id', policyIds)

    if (stepsError) {
      throw fromSupabaseError(
        stepsError,
        'fetchLeaveTypesOverview',
        'puls_workflow',
        'approval_policy_steps',
      )
    }

    for (const step of steps ?? []) {
      if (!step.is_required) continue
      const policyId = step.policy_id as string
      requiredStepCountByPolicy.set(
        policyId,
        (requiredStepCountByPolicy.get(policyId) ?? 0) + 1,
      )
    }
  }

  const leaveTypes = (data ?? []).map((row) =>
    mapLeaveTypeRow(
      {
        id: row.id as string,
        code: row.code as string,
        name: row.name as string,
        default_entitlement_days: row.default_entitlement_days as number | null,
        is_paid: row.is_paid as boolean,
        requires_document: row.requires_document as boolean,
        carry_over_allowed: row.carry_over_allowed as boolean,
        max_carry_over_days: row.max_carry_over_days as number | null,
        approval_policy_id: row.approval_policy_id as string | null,
        approval_policies: row.approval_policies as
          | { name: string; module: string; is_active: boolean }
          | { name: string; module: string; is_active: boolean }[]
          | null,
      },
      requiredStepCountByPolicy,
    ),
  )

  const maxApprovalStepCount =
    leaveTypes.length > 0 ? Math.max(...leaveTypes.map((row) => row.approvalStepCount)) : 0

  return {
    typeCount: leaveTypes.length,
    paidCount: leaveTypes.filter((row) => row.paid).length,
    docRequiredCount: leaveTypes.filter((row) => row.doc).length,
    maxApprovalStepCount,
    leaveTypes,
  }
}

export async function fetchLeaveTypesOverview(userId: string): Promise<LeaveTypesOverview> {
  return resolveAdapterData({
    operation: 'fetchLeaveTypesOverview',
    fetchReal: () => fetchRealLeaveTypesOverview(userId),
    fetchDemo: fetchDemoLeaveTypesOverview,
    isEmpty: (data) => data.leaveTypes.length === 0,
  })
}

function buildLeaveTypeWritePayload(input: LeaveTypeMutationInput) {
  return {
    name: input.name.trim(),
    code: normalizeLeaveTypeCode(input.code),
    default_entitlement_days: input.defaultEntitlementDays,
    requires_document: input.requiresDocument,
    carry_over_allowed: input.carryOverAllowed,
    max_carry_over_days: input.carryOverAllowed ? input.maxCarryOverDays : null,
    approval_policy_id: input.approvalPolicyId,
  }
}

export async function createLeaveType(
  userId: string,
  input: LeaveTypeMutationInput,
): Promise<void> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    throw new Error('Missing tenant context')
  }

  const { error } = await pulsWorkflow()
    .from('leave_types')
    .insert({
      tenant_id: ctx.tenantId,
      ...buildLeaveTypeWritePayload(input),
      is_active: true,
    })
    .select('id')
    .single()

  if (error) {
    throw fromSupabaseError(error, 'createLeaveType', 'puls_workflow', 'leave_types')
  }
}

export async function updateLeaveType(
  userId: string,
  leaveTypeId: string,
  input: LeaveTypeMutationInput,
): Promise<void> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    throw new Error('Missing tenant context')
  }

  const { data, error } = await pulsWorkflow()
    .from('leave_types')
    .update(buildLeaveTypeWritePayload(input))
    .eq('tenant_id', ctx.tenantId)
    .eq('id', leaveTypeId)
    .select('id')
    .maybeSingle()

  if (error) {
    throw fromSupabaseError(error, 'updateLeaveType', 'puls_workflow', 'leave_types')
  }

  if (!data) {
    throw new DataAdapterError({
      code: 'not_found',
      message: 'Leave type was not updated',
      source: 'adapter',
      operation: 'updateLeaveType',
      schema: 'puls_workflow',
      table: 'leave_types',
    })
  }
}
