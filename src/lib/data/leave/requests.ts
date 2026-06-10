import { DataAdapterError, fromRpcError } from '#/lib/data/errors'
import { pulsWorkflow, resolveTenantContext } from '#/lib/data/client'

export type CreateLeaveRequestPayload = {
  leaveTypeId: string
  startDate: string
  endDate: string
  halfDay?: boolean
  delegateEmployeeId?: string | null
  description?: string | null
  evidenceUploadId?: string | null
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

  return parseCreateLeaveRequestResult(data)
}

export async function createLeaveRequestWithEvidence(
  userId: string,
  payload: CreateLeaveRequestPayload,
): Promise<CreateLeaveRequestResult> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.employeeId) {
    throw new DataAdapterError({
      code: 'PULS_AUTH_REQUIRED',
      message: 'leave.error.authRequired',
      source: 'adapter',
      operation: 'createLeaveRequestWithEvidence',
      i18nKey: 'leave.error.authRequired',
    })
  }

  const { data, error } = await pulsWorkflow().rpc('create_leave_request_with_evidence', {
    p_leave_type_id: payload.leaveTypeId,
    p_start_date: payload.startDate,
    p_end_date: payload.endDate,
    p_half_day: payload.halfDay ?? false,
    p_delegate_employee_id: payload.delegateEmployeeId ?? null,
    p_description: payload.description ?? null,
    p_evidence_upload_id: payload.evidenceUploadId ?? null,
  })

  if (error) {
    throw fromRpcError(error, 'createLeaveRequest')
  }

  return parseCreateLeaveRequestResult(data)
}

function invalidCreateLeaveRequestResult(message: string): DataAdapterError {
  return new DataAdapterError({
    code: 'invalid_rpc_result',
    message,
    source: 'adapter',
    operation: 'createLeaveRequest',
    i18nKey: 'leave.error.submitFailed',
  })
}

function requireCreateResultString(value: unknown, field: string): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw invalidCreateLeaveRequestResult(
      `Missing or invalid ${field} in create_leave_request result`,
    )
  }
  return value
}

function parseCreateResultBusinessDays(value: unknown): number {
  if (value === null || value === undefined || value === '') {
    throw invalidCreateLeaveRequestResult(
      'Missing or invalid business_days in create_leave_request result',
    )
  }

  const parsed = Number(value)
  if (!Number.isFinite(parsed)) {
    throw invalidCreateLeaveRequestResult(
      'Missing or invalid business_days in create_leave_request result',
    )
  }

  return parsed
}

export function parseCreateLeaveRequestResult(data: unknown): CreateLeaveRequestResult {
  if (data === null || typeof data !== 'object' || Array.isArray(data)) {
    throw invalidCreateLeaveRequestResult('create_leave_request result is not an object')
  }

  const row = data as Record<string, unknown>
  const approverNameRaw = row.approver_name

  let approverName: string | null
  if (approverNameRaw === null || approverNameRaw === undefined) {
    approverName = null
  } else if (typeof approverNameRaw === 'string') {
    approverName = approverNameRaw
  } else {
    throw invalidCreateLeaveRequestResult(
      'Missing or invalid approver_name in create_leave_request result',
    )
  }

  return {
    leaveRequestId: requireCreateResultString(row.leave_request_id, 'leave_request_id'),
    approvalRequestId: requireCreateResultString(row.approval_request_id, 'approval_request_id'),
    businessDays: parseCreateResultBusinessDays(row.business_days),
    status: requireCreateResultString(row.status, 'status'),
    approverEmployeeId: requireCreateResultString(row.approver_employee_id, 'approver_employee_id'),
    approverName,
  }
}
