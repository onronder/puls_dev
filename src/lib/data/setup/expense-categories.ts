import { fetchDemoExpenseCategoriesOverview } from '#/lib/demo/puls-demo-data'
import type { DemoExpenseCategoriesOverview } from '#/lib/demo/puls-demo-data'
import { fromSupabaseError } from '#/lib/data/errors'
import { pulsWorkflow, resolveTenantContext } from '#/lib/data/client'
import { resolveAdapterData } from '#/lib/data/result'

export type ExpenseCategoriesOverview = DemoExpenseCategoriesOverview

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
    approvalLevels: 0,
    categories: [],
  }
}

async function fetchRealExpenseCategoriesOverview(
  userId: string,
): Promise<ExpenseCategoriesOverview> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) return emptyExpenseCategoriesOverview()

  const { data, error } = await pulsWorkflow()
    .from('expense_categories')
    .select('id, code, name, monthly_limit, receipt_required_over, erp_account_code')
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

  const categories = (data ?? []).map((row) => {
    const code = row.code as string
    return {
      id: row.id as string,
      nameKey: EXPENSE_CATEGORY_NAME_KEYS[code] ?? (row.name as string),
      monthly: Number(row.monthly_limit ?? 0),
      docThreshold: Number(row.receipt_required_over ?? 0),
      code: (row.erp_account_code as string | null) ?? code,
    }
  })

  const totalMonthlyLimit = categories.reduce((sum, row) => sum + row.monthly, 0)
  const docThresholdMetric =
    categories.length > 0
      ? Math.max(...categories.map((row) => row.docThreshold))
      : 0

  return {
    categoryCount: categories.length,
    totalMonthlyLimit,
    docThresholdMetric,
    approvalLevels: categories.length > 0 ? 2 : 0,
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
