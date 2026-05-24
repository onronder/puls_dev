import { DataAdapterError, fromRpcError } from '#/lib/data/errors'
import { pulsWorkflow, resolveTenantContext } from '#/lib/data/client'

export type CreateLeaveRequestPayload = {
  leaveTypeId: string
  startDate: string
  endDate: string
  halfDay?: boolean
  delegateEmployeeId?: string | null
  description?: string | null
}

export type CreateLeaveRequestResult = {
  leaveRequestId: string
  approvalRequestId: string
  businessDays: number
  status: string
  approverEmployeeId: string
  approverName: string | null
}

export async function createLeaveRequest(
  userId: string,
  payload: CreateLeaveRequestPayload,
): Promise<CreateLeaveRequestResult> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.employeeId) {
    throw new DataAdapterError({
      code: 'PULS_AUTH_REQUIRED',
      message: 'leave.error.authRequired',
      source: 'adapter',
      operation: 'createLeaveRequest',
      i18nKey: 'leave.error.authRequired',
    })
  }

  const { data, error } = await pulsWorkflow().rpc('create_leave_request', {
    p_leave_type_id: payload.leaveTypeId,
    p_start_date: payload.startDate,
    p_end_date: payload.endDate,
    p_half_day: payload.halfDay ?? false,
    p_delegate_employee_id: payload.delegateEmployeeId ?? null,
    p_description: payload.description ?? null,
  })

  if (error) {
    throw fromRpcError(error, 'createLeaveRequest')
  }

  const row = data as Record<string, unknown>
  return {
    leaveRequestId: row.leave_request_id as string,
    approvalRequestId: row.approval_request_id as string,
    businessDays: Number(row.business_days ?? 0),
    status: row.status as string,
    approverEmployeeId: row.approver_employee_id as string,
    approverName: (row.approver_name as string | null) ?? null,
  }
}
