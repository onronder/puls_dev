import { describe, expect, it } from 'vitest'

import {
  DataAdapterError,
  fromRpcError,
  fromSupabaseError,
  isDataAdapterError,
  mapRpcErrorToI18nKey,
} from '#/lib/data/errors'

describe('DataAdapterError', () => {
  it('normalizes supabase errors without leaking table details to user message', () => {
    const error = fromSupabaseError(
      {
        code: '42501',
        message: 'permission denied for table performance_cycles',
        details: '',
        hint: 'Check RLS',
      } as import('@supabase/supabase-js').PostgrestError,
      'fetchPerformanceCycles',
      'puls_performance',
      'performance_cycles',
    )

    expect(error.code).toBe('42501')
    expect(error.operation).toBe('fetchPerformanceCycles')
    expect(error.schema).toBe('puls_performance')
    expect(error.table).toBe('performance_cycles')
    expect(error.message).toContain('permission denied')
    expect(error.hint).toBe('Check RLS')
    expect(error.details).toBeUndefined()
    expect(error.toUserMessage()).toBe(
      'Veri yüklenirken bir sorun oluştu. Lütfen daha sonra tekrar deneyin.',
    )
    expect(error.toUserMessage()).not.toContain('performance_cycles')
  })

  it('identifies adapter errors', () => {
    const error = new DataAdapterError({
      code: 'adapter_error',
      message: 'internal',
      source: 'adapter',
      operation: 'test',
    })

    expect(isDataAdapterError(error)).toBe(true)
    expect(isDataAdapterError(new Error('nope'))).toBe(false)
  })

  it('preserves supabase error details when present', () => {
    const error = fromSupabaseError(
      {
        code: '23505',
        message: 'duplicate key value violates unique constraint',
        details: 'Key (tenant_id, code)=(a, b) already exists.',
        hint: null,
      } as unknown as import('@supabase/supabase-js').PostgrestError,
      'createExpenseCategory',
      'puls_workflow',
      'expense_categories',
    )

    expect(error.details).toBe('Key (tenant_id, code)=(a, b) already exists.')
  })
})

describe('fromRpcError', () => {
  it('maps PULS prefix to i18n key without exposing raw SQL message', () => {
    const error = fromRpcError(
      {
        code: 'P0001',
        message: 'PULS_INSUFFICIENT_BALANCE: Insufficient leave balance.',
        details: '',
        hint: 'internal hint',
      } as import('@supabase/supabase-js').PostgrestError,
      'createLeaveRequest',
    )

    expect(error.i18nKey).toBe('leave.error.insufficientBalance')
    expect(error.message).toBe('leave.error.insufficientBalance')
    expect(error.message).not.toContain('Insufficient leave balance')
    expect(error.source).toBe('rpc')
  })

  it('falls back when prefix is unknown', () => {
    const error = fromRpcError(
      {
        code: 'P0001',
        message: 'some other database error',
        details: '',
        hint: '',
      } as import('@supabase/supabase-js').PostgrestError,
      'createLeaveRequest',
      'leave.error.submitFailed',
    )

    expect(error.i18nKey).toBe('leave.error.submitFailed')
  })

  it('maps leave-specific codes distinctly from expense codes', () => {
    expect(
      mapRpcErrorToI18nKey(
        'PULS_INVALID_LEAVE_TYPE: Leave type not found.',
        'leave.error.submitFailed',
        'createLeaveRequest',
      ),
    ).toBe('requestCreationReadiness.leave.invalidLeaveType')

    expect(
      mapRpcErrorToI18nKey(
        'PULS_INVALID_EXPENSE_CATEGORY: Category not found.',
        'expense.error.submitFailed',
        'createExpenseClaim',
      ),
    ).toBe('requestCreationReadiness.expense.invalidCategory')
  })

  it('maps shared codes using operation context', () => {
    expect(
      mapRpcErrorToI18nKey(
        'PULS_NO_APPROVER: No approver.',
        'leave.error.submitFailed',
        'createLeaveRequest',
      ),
    ).toBe('requestCreationReadiness.common.policyNotReady')

    expect(
      mapRpcErrorToI18nKey(
        'PULS_NO_APPROVER: No approver.',
        'expense.error.submitFailed',
        'createExpenseClaim',
      ),
    ).toBe('requestCreationReadiness.common.policyNotReady')
  })

  it('maps receipt-required expense guard to a user-facing expense message', () => {
    expect(
      mapRpcErrorToI18nKey(
        'PULS_RECEIPT_REQUIRED: This expense category requires a receipt.',
        'expense.error.submitFailed',
        'createExpenseClaim',
      ),
    ).toBe('expense.error.receiptRequired')
  })
})
