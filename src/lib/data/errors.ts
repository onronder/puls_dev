import type { PostgrestError } from '@supabase/supabase-js'

export type DataAdapterErrorFields = {
  code: string
  message: string
  hint?: string
  details?: string
  source: 'supabase' | 'adapter' | 'rpc'
  operation: string
  schema?: string
  table?: string
  i18nKey?: string
}

export class DataAdapterError extends Error {
  readonly code: string
  readonly hint?: string
  readonly details?: string
  readonly source: DataAdapterErrorFields['source']
  readonly operation: string
  readonly schema?: string
  readonly table?: string
  readonly i18nKey?: string

  constructor(fields: DataAdapterErrorFields) {
    super(fields.message)
    this.name = 'DataAdapterError'
    this.code = fields.code
    this.hint = fields.hint
    this.details = fields.details
    this.source = fields.source
    this.operation = fields.operation
    this.schema = fields.schema
    this.table = fields.table
    this.i18nKey = fields.i18nKey
  }

  toUserMessage(): string {
    return 'Veri yüklenirken bir sorun oluştu. Lütfen daha sonra tekrar deneyin.'
  }
}

const RPC_ERROR_I18N: Record<string, string> = {
  PULS_INVALID_DATES: 'leave.error.invalidDates',
  PULS_CROSS_YEAR_LEAVE: 'leave.error.crossYear',
  PULS_HALF_DAY_INVALID: 'leave.error.halfDayInvalid',
  PULS_DOCUMENT_REQUIRED: 'leave.error.documentRequired',
  PULS_INSUFFICIENT_BALANCE: 'leave.error.insufficientBalance',
  PULS_INVALID_LEAVE_TYPE: 'leave.error.invalidLeaveType',
  PULS_INVALID_DELEGATE: 'leave.error.invalidDelegate',
  PULS_INVALID_EXPENSE_CATEGORY: 'expense.error.invalidCategory',
  PULS_INVALID_AMOUNT: 'expense.error.invalidAmount',
  PULS_INVALID_CURRENCY: 'expense.error.invalidCurrency',
  PULS_FUTURE_EXPENSE_DATE: 'expense.error.futureDate',
  PULS_APPROVAL_NOT_FOUND: 'approval.error.notFound',
  PULS_APPROVAL_ALREADY_DECIDED: 'approval.error.alreadyDecided',
  PULS_APPROVAL_FORBIDDEN: 'approval.error.forbidden',
  PULS_SELF_APPROVAL: 'approval.error.selfApproval',
  PULS_INVALID_DECISION: 'approval.error.invalidDecision',
  PULS_POLICY_STEP_UNRESOLVED: 'approval.error.policyStepUnresolved',
  PULS_POLICY_NOT_FOUND: 'approval.error.policyNotFound',
  PULS_POLICY_STEP_NOT_FOUND: 'approval.error.policyChainInvalid',
  PULS_APPROVAL_CHAIN_INVALID: 'approval.error.policyChainInvalid',
}

const OPERATION_AWARE_RPC_ERROR_I18N: Record<
  string,
  Partial<Record<'createLeaveRequest' | 'createExpenseClaim' | 'decideApprovalRequest', string>>
> = {
  PULS_AUTH_REQUIRED: {
    createLeaveRequest: 'leave.error.authRequired',
    createExpenseClaim: 'expense.error.authRequired',
    decideApprovalRequest: 'approval.error.authRequired',
  },
  PULS_NO_APPROVER: {
    createLeaveRequest: 'leave.error.noApprover',
    createExpenseClaim: 'expense.error.noApprover',
    decideApprovalRequest: 'approval.error.forbidden',
  },
  PULS_POLICY_STEP_UNRESOLVED: {
    createLeaveRequest: 'leave.error.policyStepUnresolved',
    createExpenseClaim: 'expense.error.policyStepUnresolved',
    decideApprovalRequest: 'approval.error.policyStepUnresolved',
  },
  PULS_POLICY_NOT_FOUND: {
    createLeaveRequest: 'leave.error.policyNotFound',
    createExpenseClaim: 'expense.error.policyNotFound',
    decideApprovalRequest: 'approval.error.policyNotFound',
  },
  PULS_POLICY_STEP_NOT_FOUND: {
    createLeaveRequest: 'leave.error.policyNotFound',
    createExpenseClaim: 'expense.error.policyNotFound',
    decideApprovalRequest: 'approval.error.policyChainInvalid',
  },
  PULS_APPROVAL_CHAIN_INVALID: {
    createLeaveRequest: 'leave.error.submitFailed',
    createExpenseClaim: 'expense.error.submitFailed',
    decideApprovalRequest: 'approval.error.policyChainInvalid',
  },
}

type RpcOperation = keyof (typeof OPERATION_AWARE_RPC_ERROR_I18N)[string]

function isRpcOperation(operation: string): operation is RpcOperation {
  return (
    operation === 'createLeaveRequest' ||
    operation === 'createExpenseClaim' ||
    operation === 'decideApprovalRequest'
  )
}

export function parseRpcErrorCode(message: string): string | null {
  const match = message.match(/^PULS_[A-Z_]+/)
  return match?.[0] ?? null
}

export function mapRpcErrorToI18nKey(
  message: string,
  fallback = 'leave.error.submitFailed',
  operation?: string,
): string {
  const code = parseRpcErrorCode(message)
  if (!code) return fallback

  if (operation && isRpcOperation(operation)) {
    const operationKey = OPERATION_AWARE_RPC_ERROR_I18N[code]?.[operation]
    if (operationKey) return operationKey
  }

  return RPC_ERROR_I18N[code] ?? fallback
}

export function fromSupabaseError(
  error: PostgrestError,
  operation: string,
  schema?: string,
  table?: string,
): DataAdapterError {
  return new DataAdapterError({
    code: error.code ?? 'unknown',
    message: error.message,
    hint: error.hint ?? undefined,
    details: error.details?.trim() ? error.details : undefined,
    source: 'supabase',
    operation,
    schema,
    table,
  })
}

export function fromRpcError(
  error: PostgrestError,
  operation: string,
  fallbackKey = 'leave.error.submitFailed',
): DataAdapterError {
  const i18nKey = mapRpcErrorToI18nKey(error.message, fallbackKey, operation)
  return new DataAdapterError({
    code: parseRpcErrorCode(error.message) ?? error.code ?? 'rpc_error',
    message: i18nKey,
    hint: undefined,
    source: 'rpc',
    operation,
    schema: 'puls_workflow',
    i18nKey,
  })
}

export function adapterError(operation: string, code = 'adapter_error'): DataAdapterError {
  return new DataAdapterError({
    code,
    message: 'Adapter operation failed',
    source: 'adapter',
    operation,
  })
}

export function isDataAdapterError(error: unknown): error is DataAdapterError {
  return error instanceof DataAdapterError
}
