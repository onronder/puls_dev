import { fetchDemoLeaveTypesOverview } from '#/lib/demo/puls-demo-data'
import type { DemoLeaveTypesOverview } from '#/lib/demo/puls-demo-data'
import { fromSupabaseError } from '#/lib/data/errors'
import { pulsWorkflow, resolveTenantContext } from '#/lib/data/client'
import { resolveAdapterData } from '#/lib/data/result'
import {
  buildApprovalPolicyBindingInfo,
  parseApprovalPolicyJoin,
} from '#/lib/data/workflow/policy-binding-readiness'

export type LeaveTypesOverview = DemoLeaveTypesOverview

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

function emptyLeaveTypesOverview(): LeaveTypesOverview {
  return {
    typeCount: 0,
    paidCount: 0,
    docRequiredCount: 0,
    maxApprovalStepCount: 0,
    leaveTypes: [],
  }
}

async function fetchRealLeaveTypesOverview(userId: string): Promise<LeaveTypesOverview> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) return emptyLeaveTypesOverview()

  const { data, error } = await pulsWorkflow()
    .from('leave_types')
    .select(
      'id, code, name, default_entitlement_days, is_paid, requires_document, carry_over_allowed, approval_policy_id, approval_policies ( name, module, is_active )',
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

  const leaveTypes = (data ?? []).map((row) => {
    const code = row.code as string
    const policyId = (row.approval_policy_id as string | null) ?? null
    const policyMeta = parseApprovalPolicyJoin(
      row.approval_policies as
        | { name: string; module: string; is_active: boolean }
        | { name: string; module: string; is_active: boolean }[]
        | null,
    )
    const requiredStepCount = policyId ? (requiredStepCountByPolicy.get(policyId) ?? 0) : 0

    return {
      id: row.id as string,
      labelKey: LEAVE_TYPE_LABEL_KEYS[code] ?? code,
      days: Number(row.default_entitlement_days ?? 0),
      paid: Boolean(row.is_paid),
      doc: Boolean(row.requires_document),
      carryOver: Boolean(row.carry_over_allowed),
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
  })

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
