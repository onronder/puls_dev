import { describe, expect, it } from 'vitest'

import { fromSupabaseError } from '#/lib/data/errors'
import { mapExpenseCategoryMutationError } from '#/lib/data/setup/expense-categories'

describe('mapExpenseCategoryMutationError', () => {
  it('maps PULS guardrail codes to field i18n keys', () => {
    const error = fromSupabaseError(
      {
        code: 'P0001',
        message: 'PULS_EXPENSE_CATEGORY_CODE_INVALID: code must be lowercase slug.',
        details: '',
        hint: null,
      } as unknown as import('@supabase/supabase-js').PostgrestError,
      'createExpenseCategory',
      'puls_workflow',
      'expense_categories',
    )

    expect(mapExpenseCategoryMutationError(error)).toEqual({
      fieldErrors: {
        code: 'expenseCategorySetup.validation.codeInvalid',
      },
    })
  })

  it('maps code duplicate 23505 when tenant_id+code appears in message', () => {
    const error = fromSupabaseError(
      {
        code: '23505',
        message: 'duplicate key value violates unique constraint "expense_categories_tenant_id_code_key"',
        details: 'Key (tenant_id, code)=(...) already exists.',
        hint: null,
      } as unknown as import('@supabase/supabase-js').PostgrestError,
      'createExpenseCategory',
      'puls_workflow',
      'expense_categories',
    )

    expect(mapExpenseCategoryMutationError(error)).toEqual({
      fieldErrors: {
        code: 'expenseCategorySetup.validation.duplicateCode',
      },
    })
  })

  it('maps accounting duplicate 23505 when active account index appears', () => {
    const error = fromSupabaseError(
      {
        code: '23505',
        message:
          'duplicate key value violates unique constraint "idx_puls_workflow_expense_categories_active_account_code_unique"',
        details: 'Key (tenant_id, erp_account_code)=(...) already exists.',
        hint: null,
      } as unknown as import('@supabase/supabase-js').PostgrestError,
      'createExpenseCategory',
      'puls_workflow',
      'expense_categories',
    )

    expect(mapExpenseCategoryMutationError(error)).toEqual({
      fieldErrors: {
        erpAccountCode: 'expenseCategorySetup.validation.duplicateAccountingCode',
      },
    })
  })

  it('falls back to saveFailed for ambiguous 23505', () => {
    const error = fromSupabaseError(
      {
        code: '23505',
        message: 'duplicate key value violates unique constraint "some_other_key"',
        details: 'Key already exists.',
        hint: null,
      } as unknown as import('@supabase/supabase-js').PostgrestError,
      'createExpenseCategory',
      'puls_workflow',
      'expense_categories',
    )

    expect(mapExpenseCategoryMutationError(error)).toEqual({
      fieldErrors: {},
      toastKey: 'expenseCategorySetup.errors.saveFailed',
    })
  })
})
