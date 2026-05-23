import { fetchDemoExpenseOverview } from '#/lib/demo/puls-demo-data'
import type {
  DemoExpenseApproval,
  DemoExpenseClaim,
  DemoExpenseOverview,
} from '#/lib/demo/puls-demo-data'
import { fromSupabaseError } from '#/lib/data/errors'
import { pulsCalc, pulsWorkflow, resolveTenantContext } from '#/lib/data/client'
import { resolveAdapterData } from '#/lib/data/result'

export type ExpenseOverview = DemoExpenseOverview

function getInitials(name: string): string {
  return name
    .split(' ')
    .filter(Boolean)
    .map((part) => part[0])
    .join('')
    .slice(0, 2)
    .toUpperCase()
}

function emptyExpenseOverview(): ExpenseOverview {
  return {
    approvedThisMonth: 0,
    monthlyLimit: 0,
    pendingAmount: 0,
    pendingCount: 0,
    yearTotal: 0,
    topCategory: { name: '—', pct: 0 },
    monthlyAverage: 0,
    claims: [],
    categories: [],
    categoryLimits: [],
    pendingApprovals: [],
  }
}

function isExpenseOverviewEmpty(data: ExpenseOverview): boolean {
  return data.claims.length === 0 && data.monthlyLimit === 0 && data.pendingCount === 0
}

async function fetchRealExpenseOverview(userId: string): Promise<ExpenseOverview> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.employeeId || !ctx.tenantId) return emptyExpenseOverview()

  const [overviewRow, claimsRow, categoriesRow, teamPendingRow] = await Promise.all([
    pulsCalc()
      .from('expense_overview')
      .select(
        'approved_this_month_amount, pending_expense_amount, expense_year_total, expense_monthly_average, top_expense_category, monthly_limit, limit_usage_pct',
      )
      .eq('tenant_id', ctx.tenantId)
      .eq('employee_id', ctx.employeeId)
      .maybeSingle(),
    pulsWorkflow()
      .from('expense_claims')
      .select(
        `
        id,
        title,
        amount,
        currency,
        expense_date,
        status,
        expense_categories ( name )
      `,
      )
      .eq('tenant_id', ctx.tenantId)
      .eq('employee_id', ctx.employeeId)
      .order('expense_date', { ascending: false })
      .limit(20),
    pulsWorkflow()
      .from('expense_categories')
      .select('id, code, name, monthly_limit')
      .eq('tenant_id', ctx.tenantId)
      .eq('is_active', true)
      .order('name', { ascending: true }),
    ctx.personaRole === 'manager' || ctx.personaRole === 'hr_admin' || ctx.personaRole === 'superadmin'
      ? pulsWorkflow()
          .from('expense_claims')
          .select(
            `
            id,
            title,
            amount,
            currency,
            expense_date,
            employees ( full_name ),
            expense_categories ( name )
          `,
          )
          .eq('tenant_id', ctx.tenantId)
          .eq('status', 'pending')
          .order('expense_date', { ascending: false })
          .limit(10)
      : Promise.resolve({ data: [], error: null }),
  ])

  if (overviewRow.error) {
    throw fromSupabaseError(overviewRow.error, 'fetchExpenseOverview', 'puls_calc', 'expense_overview')
  }
  if (claimsRow.error) {
    throw fromSupabaseError(claimsRow.error, 'fetchExpenseOverview', 'puls_workflow', 'expense_claims')
  }
  if (categoriesRow.error) {
    throw fromSupabaseError(
      categoriesRow.error,
      'fetchExpenseOverview',
      'puls_workflow',
      'expense_categories',
    )
  }
  if (teamPendingRow.error) {
    throw fromSupabaseError(
      teamPendingRow.error,
      'fetchExpenseOverview',
      'puls_workflow',
      'expense_claims',
    )
  }

  const overview = overviewRow.data
  const approvedThisMonth = Number(overview?.approved_this_month_amount ?? 0)
  const monthlyLimit = Number(overview?.monthly_limit ?? 0)
  const topCategoryName = (overview?.top_expense_category as string | null) ?? '—'
  const topCategoryPct =
    monthlyLimit > 0 ? Math.round((approvedThisMonth / monthlyLimit) * 100) : 0

  const claims: DemoExpenseClaim[] = (claimsRow.data ?? []).map((row) => {
    const category = row.expense_categories as { name?: string } | null
    return {
      id: row.id as string,
      title: row.title as string,
      category: category?.name ?? '—',
      amount: Number(row.amount ?? 0),
      currency: (row.currency as string | null) ?? 'TRY',
      expenseDate: row.expense_date as string,
      status: row.status as DemoExpenseClaim['status'],
    }
  })

  const pendingCount = claims.filter((row) => row.status === 'pending').length

  const categoryLimits = await Promise.all(
    (categoriesRow.data ?? []).map(async (row) => {
      const { data: spentRows, error } = await pulsWorkflow()
        .from('expense_claims')
        .select('amount')
        .eq('tenant_id', ctx.tenantId!)
        .eq('employee_id', ctx.employeeId!)
        .eq('category_id', row.id as string)
        .eq('status', 'approved')
        .gte('expense_date', new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString().slice(0, 10))

      if (error) {
        throw fromSupabaseError(error, 'fetchExpenseOverview', 'puls_workflow', 'expense_claims')
      }

      const monthSpent = (spentRows ?? []).reduce((sum, claim) => sum + Number(claim.amount ?? 0), 0)

      return {
        id: row.id as string,
        name: row.name as string,
        limit: Number(row.monthly_limit ?? 0),
        monthSpent,
      }
    }),
  )

  const pendingApprovals: DemoExpenseApproval[] = (teamPendingRow.data ?? []).map((row) => {
    const employee = row.employees as { full_name?: string } | null
    const category = row.expense_categories as { name?: string } | null
    const employeeName = employee?.full_name ?? '—'
    return {
      id: row.id as string,
      employeeName,
      initials: getInitials(employeeName),
      title: row.title as string,
      category: category?.name ?? '—',
      amount: Number(row.amount ?? 0),
      expenseDate: row.expense_date as string,
      currency: (row.currency as string | null) ?? undefined,
    }
  })

  return {
    approvedThisMonth,
    monthlyLimit,
    pendingAmount: Number(overview?.pending_expense_amount ?? 0),
    pendingCount,
    yearTotal: Number(overview?.expense_year_total ?? 0),
    topCategory: { name: topCategoryName, pct: topCategoryPct },
    monthlyAverage: Number(overview?.expense_monthly_average ?? 0),
    claims,
    categories: (categoriesRow.data ?? []).map((row) => ({
      id: row.id as string,
      label: row.name as string,
    })),
    categoryLimits,
    pendingApprovals,
  }
}

export async function fetchExpenseOverview(userId: string): Promise<ExpenseOverview> {
  return resolveAdapterData({
    operation: 'fetchExpenseOverview',
    fetchReal: () => fetchRealExpenseOverview(userId),
    fetchDemo: fetchDemoExpenseOverview,
    isEmpty: isExpenseOverviewEmpty,
  })
}
