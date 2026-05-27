import { describe, expect, it, vi } from 'vitest'

import { fromSupabaseError } from '#/lib/data/errors'
import {
  isDeactivateReasonTooLong,
  mapExpenseCategoryLifecycleError,
  mapExpenseCategoryLifecycleEventRow,
  mapExpenseCategoryMutationError,
  normalizeDeactivateReason,
  parseExpenseCategoryLifecycleRpcResult,
} from '#/lib/data/setup/expense-categories'

vi.mock('#/lib/data/client', () => ({
  pulsWorkflow: vi.fn(),
  resolveTenantContext: vi.fn(),
}))

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

  it('maps code duplicate 23505 when only details contains tenant_id+code', () => {
    const error = fromSupabaseError(
      {
        code: '23505',
        message: 'duplicate key value violates unique constraint',
        details: 'Key (tenant_id, code)=(tenant-a, travel) already exists.',
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

describe('mapExpenseCategoryLifecycleError', () => {
  it('maps active claims guard to lifecycle toast key', () => {
    const error = fromSupabaseError(
      {
        code: 'P0001',
        message:
          'PULS_EXPENSE_CATEGORY_IN_USE_ACTIVE_CLAIMS: category has open expense claims.',
        details: '',
        hint: null,
      } as unknown as import('@supabase/supabase-js').PostgrestError,
      'deactivateExpenseCategory',
      'puls_workflow',
      'expense_categories',
    )

    expect(mapExpenseCategoryLifecycleError(error)).toEqual({
      toastKey: 'expenseCategorySetup.lifecycle.errors.activeClaims',
    })
  })

  it('maps reason-too-long to lifecycle audit toast key', () => {
    const error = fromSupabaseError(
      {
        code: 'P0001',
        message:
          'PULS_EXPENSE_CATEGORY_LIFECYCLE_REASON_TOO_LONG: reason must be at most 500 characters.',
        details: '',
        hint: null,
      } as unknown as import('@supabase/supabase-js').PostgrestError,
      'deactivateExpenseCategory',
      'puls_workflow',
      'expense_categories',
    )

    expect(mapExpenseCategoryLifecycleError(error)).toEqual({
      toastKey: 'expenseCategorySetup.lifecycleAudit.reasonTooLong',
    })
  })

  it('maps restore duplicate accounting 23505 to guided toast key', () => {
    const error = fromSupabaseError(
      {
        code: '23505',
        message:
          'duplicate key value violates unique constraint "idx_puls_workflow_expense_categories_active_account_code_unique"',
        details: 'Key (tenant_id, erp_account_code)=(...) already exists.',
        hint: null,
      } as unknown as import('@supabase/supabase-js').PostgrestError,
      'restoreExpenseCategory',
      'puls_workflow',
      'expense_categories',
    )

    expect(mapExpenseCategoryLifecycleError(error)).toEqual({
      toastKey: 'expenseCategorySetup.lifecycle.errors.restoreDuplicateAccounting',
    })
  })
})

describe('normalizeDeactivateReason', () => {
  it('trims and returns null for blank input', () => {
    expect(normalizeDeactivateReason('  hello  ')).toBe('hello')
    expect(normalizeDeactivateReason('   ')).toBeNull()
    expect(normalizeDeactivateReason(null)).toBeNull()
  })
})

describe('isDeactivateReasonTooLong', () => {
  it('returns false for valid length and true above 500 chars', () => {
    expect(isDeactivateReasonTooLong('short note')).toBe(false)
    expect(isDeactivateReasonTooLong('x'.repeat(501))).toBe(true)
    expect(isDeactivateReasonTooLong('   ')).toBe(false)
  })
})

describe('parseExpenseCategoryLifecycleRpcResult', () => {
  it('maps state-change results with required eventId', () => {
    expect(
      parseExpenseCategoryLifecycleRpcResult({
        status: 'deactivated',
        category_id: 'cat-1',
        has_history: true,
        event_id: 'evt-1',
      }),
    ).toEqual({
      status: 'deactivated',
      categoryId: 'cat-1',
      hasHistory: true,
      eventId: 'evt-1',
    })

    expect(
      parseExpenseCategoryLifecycleRpcResult({
        status: 'restored',
        category_id: 'cat-1',
        event_id: 'evt-2',
      }),
    ).toEqual({
      status: 'restored',
      categoryId: 'cat-1',
      eventId: 'evt-2',
    })
  })

  it('maps idempotent results without eventId', () => {
    expect(
      parseExpenseCategoryLifecycleRpcResult({
        status: 'already_inactive',
        category_id: 'cat-1',
      }),
    ).toEqual({
      status: 'already_inactive',
      categoryId: 'cat-1',
    })

    expect(
      parseExpenseCategoryLifecycleRpcResult({
        status: 'already_active',
        category_id: 'cat-1',
      }),
    ).toEqual({
      status: 'already_active',
      categoryId: 'cat-1',
    })
  })

  it('throws when state-change result omits event_id', () => {
    expect(() =>
      parseExpenseCategoryLifecycleRpcResult({
        status: 'deactivated',
        category_id: 'cat-1',
        has_history: false,
      }),
    ).toThrow(/Missing event_id/)

    expect(() =>
      parseExpenseCategoryLifecycleRpcResult({
        status: 'restored',
        category_id: 'cat-1',
      }),
    ).toThrow(/Missing event_id/)
  })
})

describe('mapExpenseCategoryLifecycleEventRow', () => {
  it('maps snake_case lifecycle event rows', () => {
    expect(
      mapExpenseCategoryLifecycleEventRow({
        id: 'evt-1',
        category_id: 'cat-1',
        action: 'deactivated',
        reason: 'Budget review',
        actor_role: 'authenticated',
        occurred_at: '2026-05-25T12:00:00.000Z',
      }),
    ).toEqual({
      id: 'evt-1',
      categoryId: 'cat-1',
      action: 'deactivated',
      reason: 'Budget review',
      actorRole: 'authenticated',
      occurredAt: '2026-05-25T12:00:00.000Z',
    })
  })

  it('maps blank reason to null', () => {
    expect(
      mapExpenseCategoryLifecycleEventRow({
        id: 'evt-2',
        category_id: 'cat-1',
        action: 'restored',
        reason: null,
        actor_role: null,
        occurred_at: '2026-05-25T13:00:00.000Z',
      }),
    ).toEqual({
      id: 'evt-2',
      categoryId: 'cat-1',
      action: 'restored',
      reason: null,
      actorRole: null,
      occurredAt: '2026-05-25T13:00:00.000Z',
    })
  })
})

describe('fetchExpenseCategoryLifecycleEvents', () => {
  it('returns empty array when tenant context is missing', async () => {
    const { resolveTenantContext } = await import('#/lib/data/client')
    vi.mocked(resolveTenantContext).mockResolvedValueOnce({
      tenantId: null,
      tenantName: null,
      employeeId: null,
      employeeName: null,
      personaRole: 'employee',
    })

    const { fetchExpenseCategoryLifecycleEvents } = await import(
      '#/lib/data/setup/expense-categories'
    )

    await expect(fetchExpenseCategoryLifecycleEvents('user-1', 'cat-1')).resolves.toEqual([])
  })
})
