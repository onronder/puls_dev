export type ApprovalPolicyBindingStatus =
  | 'ready'
  | 'unbound'
  | 'policy_unavailable'
  | 'inactive_policy'
  | 'missing_required_steps'
  | 'module_mismatch'

export type ApprovalPolicyBindingInfo = {
  policyId: string | null
  policyName: string | null
  policyModule: string | null
  policyIsActive: boolean | null
  requiredStepCount: number
  status: ApprovalPolicyBindingStatus
}

export type ApprovalPolicyBindingInput = {
  expectedModule: 'expense' | 'leave'
  policyId: string | null
  policyName?: string | null
  policyModule: string | null
  policyIsActive: boolean | null
  requiredStepCount: number
}

export function computeApprovalPolicyBindingStatus(
  input: Omit<ApprovalPolicyBindingInput, 'policyName'>,
): ApprovalPolicyBindingStatus {
  if (!input.policyId) {
    return 'unbound'
  }

  if (input.policyIsActive === null && input.policyModule === null) {
    return 'policy_unavailable'
  }

  if (input.policyIsActive !== true) {
    return 'inactive_policy'
  }

  if (input.policyModule !== input.expectedModule) {
    return 'module_mismatch'
  }

  if (input.requiredStepCount < 1) {
    return 'missing_required_steps'
  }

  return 'ready'
}

export function buildApprovalPolicyBindingInfo(
  input: ApprovalPolicyBindingInput,
): ApprovalPolicyBindingInfo {
  return {
    policyId: input.policyId,
    policyName: input.policyName ?? null,
    policyModule: input.policyModule,
    policyIsActive: input.policyIsActive,
    requiredStepCount: input.requiredStepCount,
    status: computeApprovalPolicyBindingStatus(input),
  }
}

export function parseApprovalPolicyJoin(
  join: { name: string; module: string; is_active: boolean } | { name: string; module: string; is_active: boolean }[] | null,
): { policyName: string | null; policyModule: string | null; policyIsActive: boolean | null } {
  const row = Array.isArray(join) ? join[0] : join
  if (!row) {
    return { policyName: null, policyModule: null, policyIsActive: null }
  }

  return {
    policyName: row.name ?? null,
    policyModule: row.module ?? null,
    policyIsActive: typeof row.is_active === 'boolean' ? row.is_active : null,
  }
}
