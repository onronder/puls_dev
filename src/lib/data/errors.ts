import type { PostgrestError } from '@supabase/supabase-js'

export type DataAdapterErrorFields = {
  code: string
  message: string
  hint?: string
  source: 'supabase' | 'adapter' | 'rpc'
  operation: string
  schema?: string
  table?: string
  i18nKey?: string
}

export class DataAdapterError extends Error {
  readonly code: string
  readonly hint?: string
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
  PULS_AUTH_REQUIRED: 'leave.error.authRequired',
  PULS_INVALID_DATES: 'leave.error.invalidDates',
  PULS_HALF_DAY_INVALID: 'leave.error.halfDayInvalid',
  PULS_DOCUMENT_REQUIRED: 'leave.error.documentRequired',
  PULS_INSUFFICIENT_BALANCE: 'leave.error.insufficientBalance',
  PULS_NO_APPROVER: 'leave.error.noApprover',
  PULS_INVALID_CATEGORY: 'expense.error.invalidCategory',
  PULS_INVALID_AMOUNT: 'expense.error.invalidAmount',
  PULS_INVALID_CURRENCY: 'expense.error.invalidCurrency',
  PULS_FUTURE_EXPENSE_DATE: 'expense.error.futureDate',
  PULS_APPROVAL_NOT_FOUND: 'approval.error.notFound',
  PULS_APPROVAL_ALREADY_DECIDED: 'approval.error.alreadyDecided',
  PULS_APPROVAL_FORBIDDEN: 'approval.error.forbidden',
  PULS_SELF_APPROVAL: 'approval.error.selfApproval',
  PULS_INVALID_DECISION: 'approval.error.invalidDecision',
}

export function parseRpcErrorCode(message: string): string | null {
  const match = message.match(/^PULS_[A-Z_]+/)
  return match?.[0] ?? null
}

export function mapRpcErrorToI18nKey(message: string, fallback = 'leave.error.submitFailed'): string {
  const code = parseRpcErrorCode(message)
  if (!code) return fallback
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
  const i18nKey = mapRpcErrorToI18nKey(error.message, fallbackKey)
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
