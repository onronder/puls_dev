import { fromSupabaseError } from '#/lib/data/errors'
import { pulsWorkflow, resolveTenantContext } from '#/lib/data/client'

export type ApprovalPolicyOverviewItem = {
  id: string
  code: string
  name: string
  module: 'leave' | 'expense'
  requiredStepCount: number
}

export type ApprovalPolicyDetail = ApprovalPolicyOverviewItem & {
  steps: Array<{
    stepOrder: number
    approverType: string
    isRequired: boolean
  }>
}

export async function fetchApprovalPoliciesOverview(
  userId: string,
): Promise<ApprovalPolicyOverviewItem[]> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) return []

  const { data: policies, error: policiesError } = await pulsWorkflow()
    .from('approval_policies')
    .select('id, code, name, module')
    .eq('tenant_id', ctx.tenantId)
    .eq('is_active', true)
    .order('name', { ascending: true })

  if (policiesError) {
    throw fromSupabaseError(
      policiesError,
      'fetchApprovalPoliciesOverview',
      'puls_workflow',
      'approval_policies',
    )
  }

  const { data: steps, error: stepsError } = await pulsWorkflow()
    .from('approval_policy_steps')
    .select('policy_id, step_order, is_required')
    .eq('tenant_id', ctx.tenantId)

  if (stepsError) {
    throw fromSupabaseError(
      stepsError,
      'fetchApprovalPoliciesOverview',
      'puls_workflow',
      'approval_policy_steps',
    )
  }

  const requiredCountByPolicy = new Map<string, number>()
  for (const step of steps ?? []) {
    if (!step.is_required) continue
    const policyId = step.policy_id as string
    requiredCountByPolicy.set(policyId, (requiredCountByPolicy.get(policyId) ?? 0) + 1)
  }

  return (policies ?? []).map((row) => ({
    id: row.id as string,
    code: row.code as string,
    name: row.name as string,
    module: row.module as 'leave' | 'expense',
    requiredStepCount: requiredCountByPolicy.get(row.id as string) ?? 0,
  }))
}

export async function fetchApprovalPolicyDetail(
  userId: string,
  policyId: string,
): Promise<ApprovalPolicyDetail | null> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) return null

  const { data: policy, error: policyError } = await pulsWorkflow()
    .from('approval_policies')
    .select('id, code, name, module')
    .eq('tenant_id', ctx.tenantId)
    .eq('id', policyId)
    .maybeSingle()

  if (policyError) {
    throw fromSupabaseError(
      policyError,
      'fetchApprovalPolicyDetail',
      'puls_workflow',
      'approval_policies',
    )
  }

  if (!policy) return null

  const { data: steps, error: stepsError } = await pulsWorkflow()
    .from('approval_policy_steps')
    .select('step_order, approver_type, is_required')
    .eq('tenant_id', ctx.tenantId)
    .eq('policy_id', policyId)
    .order('step_order', { ascending: true })

  if (stepsError) {
    throw fromSupabaseError(
      stepsError,
      'fetchApprovalPolicyDetail',
      'puls_workflow',
      'approval_policy_steps',
    )
  }

  const mappedSteps = (steps ?? []).map((row) => ({
    stepOrder: row.step_order as number,
    approverType: row.approver_type as string,
    isRequired: Boolean(row.is_required),
  }))

  return {
    id: policy.id as string,
    code: policy.code as string,
    name: policy.name as string,
    module: policy.module as 'leave' | 'expense',
    requiredStepCount: mappedSteps.filter((step) => step.isRequired).length,
    steps: mappedSteps,
  }
}
