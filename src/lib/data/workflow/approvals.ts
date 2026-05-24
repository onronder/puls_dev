import { DataAdapterError, fromRpcError } from '#/lib/data/errors'
import { pulsWorkflow, resolveTenantContext } from '#/lib/data/client'

export type ApprovalDecision = 'approved' | 'rejected'

export type DecideApprovalRequestPayload = {
  approvalRequestId: string
  decision: ApprovalDecision
  note?: string | null
}

export type DecideApprovalRequestResult = {
  module: 'leave' | 'expense'
  parentId: string
  status: string
  approvalRequestId: string
  final: boolean
  nextApprovalRequestId?: string | null
  currentStepOrder?: number | null
}

export async function decideApprovalRequest(
  userId: string,
  payload: DecideApprovalRequestPayload,
): Promise<DecideApprovalRequestResult> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.employeeId) {
    throw new DataAdapterError({
      code: 'PULS_AUTH_REQUIRED',
      message: 'approval.error.forbidden',
      source: 'adapter',
      operation: 'decideApprovalRequest',
      i18nKey: 'approval.error.forbidden',
    })
  }

  const { data, error } = await pulsWorkflow().rpc('decide_approval_request', {
    p_approval_request_id: payload.approvalRequestId,
    p_decision: payload.decision,
    p_note: payload.note ?? null,
  })

  if (error) {
    throw fromRpcError(error, 'decideApprovalRequest', 'approval.error.forbidden')
  }

  const row = data as Record<string, unknown>
  return {
    module: row.module as 'leave' | 'expense',
    parentId: row.parent_id as string,
    status: row.status as string,
    approvalRequestId: row.approval_request_id as string,
    final: Boolean(row.final),
    nextApprovalRequestId: (row.next_approval_request_id as string | undefined) ?? null,
    currentStepOrder: (row.current_step_order as number | undefined) ?? null,
  }
}
