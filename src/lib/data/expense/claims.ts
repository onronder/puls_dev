import { DataAdapterError, fromRpcError } from '#/lib/data/errors'
import { pulsWorkflow, resolveTenantContext } from '#/lib/data/client'

export type CreateExpenseClaimPayload = {
  categoryId: string
  title?: string | null
  amount: number
  currency?: string
  vatRate?: number | null
  vatIncluded?: boolean
  expenseDate: string
  description?: string | null
}

export type CreateExpenseClaimResult = {
  expenseClaimId: string
  approvalRequestId: string
  policyStatus: string
  status: string
  title: string
}

export async function createExpenseClaim(
  userId: string,
  payload: CreateExpenseClaimPayload,
): Promise<CreateExpenseClaimResult> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.employeeId) {
    throw new DataAdapterError({
      code: 'PULS_AUTH_REQUIRED',
      message: 'expense.error.authRequired',
      source: 'adapter',
      operation: 'createExpenseClaim',
      i18nKey: 'expense.error.authRequired',
    })
  }

  const { data, error } = await pulsWorkflow().rpc('create_expense_claim', {
    p_category_id: payload.categoryId,
    p_title: payload.title ?? null,
    p_amount: payload.amount,
    p_currency: payload.currency ?? 'TRY',
    p_vat_rate: payload.vatRate ?? null,
    p_vat_included: payload.vatIncluded ?? true,
    p_expense_date: payload.expenseDate,
    p_description: payload.description ?? null,
  })

  if (error) {
    throw fromRpcError(error, 'createExpenseClaim', 'expense.error.submitFailed')
  }

  const row = data as Record<string, unknown>
  return {
    expenseClaimId: row.expense_claim_id as string,
    approvalRequestId: row.approval_request_id as string,
    policyStatus: row.policy_status as string,
    status: row.status as string,
    title: row.title as string,
  }
}
