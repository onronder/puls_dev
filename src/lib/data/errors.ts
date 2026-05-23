import type { PostgrestError } from '@supabase/supabase-js'

export type DataAdapterErrorFields = {
  code: string
  message: string
  hint?: string
  source: 'supabase' | 'adapter'
  operation: string
  schema?: string
  table?: string
}

export class DataAdapterError extends Error {
  readonly code: string
  readonly hint?: string
  readonly source: DataAdapterErrorFields['source']
  readonly operation: string
  readonly schema?: string
  readonly table?: string

  constructor(fields: DataAdapterErrorFields) {
    super(fields.message)
    this.name = 'DataAdapterError'
    this.code = fields.code
    this.hint = fields.hint
    this.source = fields.source
    this.operation = fields.operation
    this.schema = fields.schema
    this.table = fields.table
  }

  toUserMessage(): string {
    return 'Veri yüklenirken bir sorun oluştu. Lütfen daha sonra tekrar deneyin.'
  }
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
