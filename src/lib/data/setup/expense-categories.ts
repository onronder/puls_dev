import { fetchDemoExpenseCategoriesOverview } from '#/lib/demo/puls-demo-data'
import type { DemoExpenseCategoriesOverview } from '#/lib/demo/puls-demo-data'
import { DataAdapterError, fromSupabaseError } from '#/lib/data/errors'
import { pulsWorkflow, resolveTenantContext } from '#/lib/data/client'
import { resolveAdapterData } from '#/lib/data/result'

export type ExpenseCategoriesOverview = DemoExpenseCategoriesOverview

export type ExpenseCategoryMutationInput = {
  name: string
  code: string
  monthlyLimit: number
  receiptRequiredOver: number
  accountingCode: string | null
}

const EXPENSE_CATEGORY_NAME_KEYS: Record<string, string> = {
  travel: 'expenseCategorySetup.categories.travel',
  meals: 'expenseCategorySetup.categories.meals',
  lodging: 'expenseCategorySetup.categories.lodging',
  software: 'expenseCategorySetup.categories.software',
  transport: 'expenseCategorySetup.categories.transport',
  other: 'expenseCategorySetup.categories.other',
}

function emptyExpenseCategoriesOverview(): ExpenseCategoriesOverview {
  return {
    categoryCount: 0,
    totalMonthlyLimit: 0,
    docThresholdMetric: 0,
    maxApprovalStepCount: 0,
    categories: [],
  }
}

function normalizeCategoryCode(code: string): string {
  return code.trim().toLowerCase().replace(/\s+/g, '_')
}

function normalizeOptionalText(value: string | null | undefined): string | null {
  const normalized = value?.trim()
  return normalized ? normalized : null
}

async function fetchRealExpenseCategoriesOverview(
  userId: string,
): Promise<ExpenseCategoriesOverview> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) return emptyExpenseCategoriesOverview()

  const { data, error } = await pulsWorkflow()
    .from('expense_categories')
    .select(
      'id, code, name, monthly_limit, receipt_required_over, erp_account_code, approval_policy_id, approval_policies(name)',
    )
    .eq('tenant_id', ctx.tenantId)
    .eq('is_active', true)
    .order('name', { ascending: true })

  if (error) {
    throw fromSupabaseError(
      error,
      'fetchExpenseCategoriesOverview',
      'puls_workflow',
      'expense_categories',
    )
  }

  const policyIds = [
    ...new Set(
      (data ?? [])
        .map((row) => row.approval_policy_id as string | null)
        .filter((id): id is string => Boolean(id)),
    ),
  ]

  const requiredStepCountByPolicy = new Map<string, number>()
  if (policyIds.length > 0) {
    const { data: steps, error: stepsError } = await pulsWorkflow()
      .from('approval_policy_steps')
      .select('policy_id, is_required')
      .eq('tenant_id', ctx.tenantId)
      .in('policy_id', policyIds)

    if (stepsError) {
      throw fromSupabaseError(
        stepsError,
        'fetchExpenseCategoriesOverview',
        'puls_workflow',
        'approval_policy_steps',
      )
    }

    for (const step of steps ?? []) {
      if (!step.is_required) continue
      const policyId = step.policy_id as string
      requiredStepCountByPolicy.set(
        policyId,
        (requiredStepCountByPolicy.get(policyId) ?? 0) + 1,
      )
    }
  }

  const categories = (data ?? []).map((row) => {
    const code = row.code as string
    const policyId = (row.approval_policy_id as string | null) ?? null
    const policyJoin = row.approval_policies as { name: string } | { name: string }[] | null
    const policyName = Array.isArray(policyJoin)
      ? policyJoin[0]?.name
      : policyJoin?.name

    return {
      id: row.id as string,
      name: row.name as string,
      nameKey: EXPENSE_CATEGORY_NAME_KEYS[code] ?? (row.name as string),
      categoryCode: code,
      monthly: Number(row.monthly_limit ?? 0),
      docThreshold: Number(row.receipt_required_over ?? 0),
      accountingCode: (row.erp_account_code as string | null) ?? null,
      code: (row.erp_account_code as string | null) ?? code,
      approvalPolicyId: policyId,
      approvalPolicyName: policyName ?? null,
      approvalStepCount: policyId ? (requiredStepCountByPolicy.get(policyId) ?? 0) : 1,
    }
  })

  const totalMonthlyLimit = categories.reduce((sum, row) => sum + row.monthly, 0)
  const docThresholdMetric =
    categories.length > 0 ? Math.max(...categories.map((row) => row.docThreshold)) : 0
  const maxApprovalStepCount =
    categories.length > 0 ? Math.max(...categories.map((row) => row.approvalStepCount)) : 0

  return {
    categoryCount: categories.length,
    totalMonthlyLimit,
    docThresholdMetric,
    maxApprovalStepCount,
    categories,
  }
}

export async function fetchExpenseCategoriesOverview(
  userId: string,
): Promise<ExpenseCategoriesOverview> {
  return resolveAdapterData({
    operation: 'fetchExpenseCategoriesOverview',
    fetchReal: () => fetchRealExpenseCategoriesOverview(userId),
    fetchDemo: fetchDemoExpenseCategoriesOverview,
    isEmpty: (data) => data.categories.length === 0,
  })
}

export async function createExpenseCategory(
  userId: string,
  input: ExpenseCategoryMutationInput,
): Promise<void> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    throw new Error('Missing tenant context')
  }

  const { error } = await pulsWorkflow()
    .from('expense_categories')
    .insert({
      tenant_id: ctx.tenantId,
      name: input.name.trim(),
      code: normalizeCategoryCode(input.code),
      monthly_limit: input.monthlyLimit,
      receipt_required_over: input.receiptRequiredOver,
      erp_account_code: normalizeOptionalText(input.accountingCode),
      is_active: true,
    })
    .select('id')
    .single()

  if (error) {
    throw fromSupabaseError(
      error,
      'createExpenseCategory',
      'puls_workflow',
      'expense_categories',
    )
  }
}

export async function updateExpenseCategory(
  userId: string,
  categoryId: string,
  input: ExpenseCategoryMutationInput,
): Promise<void> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    throw new Error('Missing tenant context')
  }

  const { data, error } = await pulsWorkflow()
    .from('expense_categories')
    .update({
      name: input.name.trim(),
      code: normalizeCategoryCode(input.code),
      monthly_limit: input.monthlyLimit,
      receipt_required_over: input.receiptRequiredOver,
      erp_account_code: normalizeOptionalText(input.accountingCode),
    })
    .eq('tenant_id', ctx.tenantId)
    .eq('id', categoryId)
    .select('id')
    .maybeSingle()

  if (error) {
    throw fromSupabaseError(
      error,
      'updateExpenseCategory',
      'puls_workflow',
      'expense_categories',
    )
  }

  if (!data) {
    throw new DataAdapterError({
      code: 'not_found',
      message: 'Expense category was not updated',
      source: 'adapter',
      operation: 'updateExpenseCategory',
      schema: 'puls_workflow',
      table: 'expense_categories',
    })
  }
}
