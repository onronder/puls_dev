import { DataAdapterError, fromSupabaseError, isDataAdapterError, parseRpcErrorCode } from '#/lib/data/errors'
import { fetchDemoExpenseCategoriesOverview } from '#/lib/demo/puls-demo-data'
import type { DemoExpenseCategoriesOverview } from '#/lib/demo/puls-demo-data'
import { pulsWorkflow, resolveTenantContext } from '#/lib/data/client'
import { resolveAdapterData } from '#/lib/data/result'
import {
  normalizeCategoryCode,
  type ExpenseCategoryFieldKey,
} from '#/lib/data/setup/expense-category-validation'

export type ExpenseCategoriesOverview = DemoExpenseCategoriesOverview

export type ExpenseCategoryLifecycleFilter = 'active' | 'inactive' | 'all'

export type ExpenseCategoryLifecycleEventAction = 'deactivated' | 'restored'

export type ExpenseCategoryLifecycleEvent = {
  id: string
  categoryId: string
  action: ExpenseCategoryLifecycleEventAction
  reason: string | null
  actorRole: string | null
  occurredAt: string
}

export type ExpenseCategoryLifecycleResult =
  | { status: 'deactivated'; categoryId: string; hasHistory: boolean; eventId: string }
  | { status: 'restored'; categoryId: string; eventId: string }
  | { status: 'already_inactive'; categoryId: string }
  | { status: 'already_active'; categoryId: string }

export const DEACTIVATE_REASON_MAX_LENGTH = 500

export type ExpenseCategoryLifecycleErrorMapping = {
  toastKey: string
}

const PULS_CATEGORY_LIFECYCLE_ERROR_MAP: Record<string, string> = {
  PULS_EXPENSE_CATEGORY_IN_USE_ACTIVE_CLAIMS: 'expenseCategorySetup.lifecycle.errors.activeClaims',
  PULS_EXPENSE_CATEGORY_NOT_FOUND: 'expenseCategorySetup.lifecycle.errors.notFound',
  PULS_EXPENSE_CATEGORY_FORBIDDEN: 'expenseCategorySetup.lifecycle.errors.forbidden',
  PULS_EXPENSE_CATEGORY_LIFECYCLE_REASON_TOO_LONG:
    'expenseCategorySetup.lifecycleAudit.reasonTooLong',
}

export function normalizeDeactivateReason(value: string | null | undefined): string | null {
  const normalized = value?.trim()
  return normalized ? normalized : null
}

export function isDeactivateReasonTooLong(value: string | null | undefined): boolean {
  const normalized = normalizeDeactivateReason(value)
  return normalized != null && normalized.length > DEACTIVATE_REASON_MAX_LENGTH
}

export function applyExpenseCategoryLifecycleFilter<
  T extends { isActive: boolean },
>(categories: T[], filter: ExpenseCategoryLifecycleFilter): T[] {
  switch (filter) {
    case 'active':
      return categories.filter((category) => category.isActive)
    case 'inactive':
      return categories.filter((category) => !category.isActive)
    default:
      return categories
  }
}

export function mapExpenseCategoryLifecycleError(
  error: unknown,
): ExpenseCategoryLifecycleErrorMapping {
  const fallback: ExpenseCategoryLifecycleErrorMapping = {
    toastKey: 'expenseCategorySetup.lifecycle.errors.generic',
  }

  if (!isDataAdapterError(error)) {
    return fallback
  }

  const pulsCode = parseRpcErrorCode(error.message)
  if (pulsCode) {
    const mapped = PULS_CATEGORY_LIFECYCLE_ERROR_MAP[pulsCode]
    if (mapped) {
      return { toastKey: mapped }
    }
  }

  if (error.code === '23505') {
    const haystack = `${error.message} ${error.hint ?? ''} ${error.details ?? ''}`.toLowerCase()
    const isAccountingDuplicate =
      haystack.includes('idx_puls_workflow_expense_categories_active_account_code_unique') ||
      haystack.includes('erp_account_code')

    if (isAccountingDuplicate) {
      return {
        toastKey: 'expenseCategorySetup.lifecycle.errors.restoreDuplicateAccounting',
      }
    }
  }

  return fallback
}

export function parseExpenseCategoryLifecycleRpcResult(
  data: unknown,
): ExpenseCategoryLifecycleResult {
  const row = data as Record<string, unknown>
  const status = row.status as ExpenseCategoryLifecycleResult['status']
  const categoryId = row.category_id as string
  const eventId = typeof row.event_id === 'string' ? row.event_id : String(row.event_id ?? '')

  switch (status) {
    case 'deactivated':
      return {
        status: 'deactivated',
        categoryId,
        hasHistory: Boolean(row.has_history),
        eventId,
      }
    case 'restored':
      return {
        status: 'restored',
        categoryId,
        eventId,
      }
    case 'already_inactive':
      return { status: 'already_inactive', categoryId }
    case 'already_active':
      return { status: 'already_active', categoryId }
    default:
      throw new Error(`Unexpected lifecycle RPC status: ${String(status)}`)
  }
}

export function mapExpenseCategoryLifecycleEventRow(
  row: Record<string, unknown>,
): ExpenseCategoryLifecycleEvent {
  return {
    id: row.id as string,
    categoryId: row.category_id as string,
    action: row.action as ExpenseCategoryLifecycleEventAction,
    reason: (row.reason as string | null) ?? null,
    actorRole: (row.actor_role as string | null) ?? null,
    occurredAt: row.occurred_at as string,
  }
}

export async function deactivateExpenseCategory(
  userId: string,
  categoryId: string,
  reason?: string | null,
): Promise<ExpenseCategoryLifecycleResult> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    throw new Error('Missing tenant context')
  }

  const { data, error } = await pulsWorkflow().rpc('deactivate_expense_category', {
    p_category_id: categoryId,
    p_reason: normalizeDeactivateReason(reason),
  })

  if (error) {
    throw fromSupabaseError(
      error,
      'deactivateExpenseCategory',
      'puls_workflow',
      'expense_categories',
    )
  }

  return parseExpenseCategoryLifecycleRpcResult(data)
}

export async function restoreExpenseCategory(
  userId: string,
  categoryId: string,
): Promise<ExpenseCategoryLifecycleResult> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    throw new Error('Missing tenant context')
  }

  const { data, error } = await pulsWorkflow().rpc('restore_expense_category', {
    p_category_id: categoryId,
  })

  if (error) {
    throw fromSupabaseError(
      error,
      'restoreExpenseCategory',
      'puls_workflow',
      'expense_categories',
    )
  }

  return parseExpenseCategoryLifecycleRpcResult(data)
}

export async function fetchExpenseCategoryLifecycleEvents(
  userId: string,
  categoryId: string,
  limit = 5,
): Promise<ExpenseCategoryLifecycleEvent[]> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    return []
  }

  const { data, error } = await pulsWorkflow()
    .from('expense_category_lifecycle_events')
    .select('id, category_id, action, reason, actor_role, occurred_at')
    .eq('category_id', categoryId)
    .order('occurred_at', { ascending: false })
    .order('id', { ascending: false })
    .limit(limit)

  if (error) {
    throw fromSupabaseError(
      error,
      'fetchExpenseCategoryLifecycleEvents',
      'puls_workflow',
      'expense_category_lifecycle_events',
    )
  }

  return (data ?? []).map((row) =>
    mapExpenseCategoryLifecycleEventRow(row as Record<string, unknown>),
  )
}

export type ExpenseCategoryMutationInput = {
  name: string
  code: string
  monthlyLimit: number
  receiptRequiredOver: number
  erpAccountCode: string | null
}

export type ExpenseCategoryMutationErrorMapping = {
  fieldErrors: Partial<Record<ExpenseCategoryFieldKey, string>>
  toastKey?: string
}

const EXPENSE_CATEGORY_NAME_KEYS: Record<string, string> = {
  travel: 'expenseCategorySetup.categories.travel',
  meals: 'expenseCategorySetup.categories.meals',
  lodging: 'expenseCategorySetup.categories.lodging',
  software: 'expenseCategorySetup.categories.software',
  transport: 'expenseCategorySetup.categories.transport',
  other: 'expenseCategorySetup.categories.other',
}

const PULS_CATEGORY_ERROR_MAP: Record<
  string,
  { field: ExpenseCategoryFieldKey; i18nKey: string }
> = {
  PULS_EXPENSE_CATEGORY_NAME_REQUIRED: {
    field: 'name',
    i18nKey: 'expenseCategorySetup.validation.nameRequired',
  },
  PULS_EXPENSE_CATEGORY_CODE_REQUIRED: {
    field: 'code',
    i18nKey: 'expenseCategorySetup.validation.codeRequired',
  },
  PULS_EXPENSE_CATEGORY_CODE_INVALID: {
    field: 'code',
    i18nKey: 'expenseCategorySetup.validation.codeInvalid',
  },
  PULS_EXPENSE_CATEGORY_MONTHLY_LIMIT_INVALID: {
    field: 'monthlyLimit',
    i18nKey: 'expenseCategorySetup.validation.monthlyLimitInvalid',
  },
  PULS_EXPENSE_CATEGORY_RECEIPT_THRESHOLD_INVALID: {
    field: 'receiptRequiredOver',
    i18nKey: 'expenseCategorySetup.validation.receiptThresholdInvalid',
  },
  PULS_EXPENSE_CATEGORY_ACCOUNT_CODE_INVALID: {
    field: 'erpAccountCode',
    i18nKey: 'expenseCategorySetup.validation.erpAccountCodeInvalid',
  },
}

export { normalizeCategoryCode }

function emptyExpenseCategoriesOverview(): ExpenseCategoriesOverview {
  return {
    categoryCount: 0,
    totalMonthlyLimit: 0,
    docThresholdMetric: 0,
    maxApprovalStepCount: 0,
    categories: [],
  }
}

function normalizeOptionalText(value: string | null | undefined): string | null {
  const normalized = value?.trim()
  return normalized ? normalized : null
}

function duplicate23505Mapping(error: DataAdapterError): ExpenseCategoryMutationErrorMapping | null {
  const haystack = `${error.message} ${error.hint ?? ''} ${error.details ?? ''}`.toLowerCase()

  const isCodeDuplicate =
    haystack.includes('expense_categories_tenant_id_code_key') ||
    haystack.includes('(tenant_id, code)')

  const isAccountingDuplicate =
    haystack.includes('idx_puls_workflow_expense_categories_active_account_code_unique') ||
    haystack.includes('erp_account_code')

  if (isCodeDuplicate && isAccountingDuplicate) {
    return null
  }

  if (isCodeDuplicate) {
    return {
      fieldErrors: {
        code: 'expenseCategorySetup.validation.duplicateCode',
      },
    }
  }

  if (isAccountingDuplicate) {
    return {
      fieldErrors: {
        erpAccountCode: 'expenseCategorySetup.validation.duplicateAccountingCode',
      },
    }
  }

  return null
}

export function mapExpenseCategoryMutationError(error: unknown): ExpenseCategoryMutationErrorMapping {
  const fallback: ExpenseCategoryMutationErrorMapping = {
    fieldErrors: {},
    toastKey: 'expenseCategorySetup.errors.saveFailed',
  }

  if (!isDataAdapterError(error)) {
    return fallback
  }

  const pulsCode = parseRpcErrorCode(error.message)
  if (pulsCode) {
    const mapped = PULS_CATEGORY_ERROR_MAP[pulsCode]
    if (mapped) {
      return {
        fieldErrors: {
          [mapped.field]: mapped.i18nKey,
        },
      }
    }
  }

  if (error.code === '23505') {
    const duplicateMapping = duplicate23505Mapping(error)
    if (duplicateMapping) {
      return duplicateMapping
    }
  }

  return fallback
}

async function fetchRealExpenseCategoriesOverview(
  userId: string,
): Promise<ExpenseCategoriesOverview> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) return emptyExpenseCategoriesOverview()

  const { data, error } = await pulsWorkflow()
    .from('expense_categories')
    .select(
      'id, code, name, monthly_limit, receipt_required_over, erp_account_code, approval_policy_id, is_active, approval_policies(name)',
    )
    .eq('tenant_id', ctx.tenantId)
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
      isActive: Boolean(row.is_active),
    }
  })

  const activeCategories = categories.filter((row) => row.isActive)
  const totalMonthlyLimit = activeCategories.reduce((sum, row) => sum + row.monthly, 0)
  const docThresholdMetric =
    activeCategories.length > 0 ? Math.max(...activeCategories.map((row) => row.docThreshold)) : 0
  const maxApprovalStepCount =
    activeCategories.length > 0
      ? Math.max(...activeCategories.map((row) => row.approvalStepCount))
      : 0

  return {
    categoryCount: activeCategories.length,
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
      erp_account_code: normalizeOptionalText(input.erpAccountCode),
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
      erp_account_code: normalizeOptionalText(input.erpAccountCode),
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
