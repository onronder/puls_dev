import {
  fetchDemoDashboardOverview,
  fetchDemoExpenseOverview,
  fetchDemoLeaveOverview,
} from '#/lib/demo/puls-demo-data'
import type {
  DemoDashboardOverview,
  DemoExpenseOverview,
  DemoLeaveOverview,
} from '#/lib/demo/puls-demo-data'
import { fromSupabaseError } from '#/lib/data/errors'
import { pulsCalc, pulsIntegration, pulsWorkflow, resolveTenantContext } from '#/lib/data/client'
import { resolveAdapterData, resolveAdapterDataWithMeta } from '#/lib/data/result'

export type DashboardStats = {
  tenantName: string | null
  employeeCount: number
  departmentCount: number
  competencyCount: number
  positionCount: number
  erpConnected: boolean
  erpProvider: string | null
  displayName: string | null
  dataReadinessPct: number
}

export type DashboardPageData = {
  stats: DashboardStats
  overview: DemoDashboardOverview
  leaveSummary: Pick<DemoLeaveOverview, 'heroRemainingAnnual' | 'pendingCount'>
  expenseSummary: Pick<DemoExpenseOverview, 'monthlyLimit' | 'pendingAmount'>
}

export type BuildDashboardQueueInput = {
  activeCycleName: string | null | undefined
  mappedFields: number
  totalFields: number
  pendingLeave: number
  pendingExpense: number
}

export type BuildDashboardErpStatusInput = {
  hasConnection: boolean
  isActive: boolean | null | undefined
  mappedFields: number
  totalFields: number
  readiness: number
}

type DashboardLeaveBalanceRow = {
  remaining_days?: number | null
  leave_types?: { code?: string | null } | null
}

export function emptyDashboardOverview(): DemoDashboardOverview {
  return {
    positionCount: 0,
    queue: [],
    recentActivities: [],
    erpStatus: {
      statusLabelKey: 'dashboardSetup.erpCard.statusNotConfigured',
      mappedFields: 0,
      totalFields: 0,
      lastAttemptKey: 'dashboardSetup.erpCard.lastAttemptNone',
      readiness: 0,
      descriptionKey: 'dashboardSetup.erpCard.descriptionNotConfigured',
    },
  }
}

export function emptyDashboardPageData(): DashboardPageData {
  return {
    stats: {
      tenantName: null,
      employeeCount: 0,
      departmentCount: 0,
      competencyCount: 0,
      positionCount: 0,
      erpConnected: false,
      erpProvider: null,
      displayName: null,
      dataReadinessPct: 0,
    },
    overview: emptyDashboardOverview(),
    leaveSummary: { heroRemainingAnnual: 0, pendingCount: 0 },
    expenseSummary: { monthlyLimit: 0, pendingAmount: 0 },
  }
}

export function isDashboardEmpty(data: DashboardPageData): boolean {
  const { stats, overview } = data
  const hasRealData =
    stats.employeeCount > 0 ||
    stats.departmentCount > 0 ||
    stats.positionCount > 0 ||
    stats.competencyCount > 0 ||
    stats.erpConnected ||
    overview.erpStatus.mappedFields > 0 ||
    stats.dataReadinessPct > 0

  return !hasRealData
}

export function buildDashboardQueue(input: BuildDashboardQueueInput): DemoDashboardOverview['queue'] {
  const queue: DemoDashboardOverview['queue'] = []

  if (input.activeCycleName == null) {
    queue.push({
      id: 'q1',
      titleKey: 'dashboardSetup.queue.performancePeriod.title',
      metaKey: 'dashboardSetup.queue.performancePeriod.meta',
      to: '/performans',
      tone: 'info',
      icon: 'target',
    })
  }
  if (input.totalFields > 0 && input.mappedFields < input.totalFields) {
    queue.push({
      id: 'q2',
      titleKey: 'dashboardSetup.queue.fieldMapping.title',
      metaKey: 'dashboardSetup.queue.fieldMapping.meta',
      to: '/erp',
      tone: 'warning',
      icon: 'plug',
    })
  }
  if (input.pendingLeave > 0) {
    queue.push({
      id: 'q3',
      titleKey: 'dashboardSetup.queue.leaveApproval.title',
      metaKey: 'dashboardSetup.queue.leaveApproval.meta',
      to: '/izin',
      tone: 'warning',
      icon: 'calendarCheck',
    })
  }
  if (input.pendingExpense > 0) {
    queue.push({
      id: 'q4',
      titleKey: 'dashboardSetup.queue.expenseApproval.title',
      metaKey: 'dashboardSetup.queue.expenseApproval.meta',
      to: '/masraf',
      tone: 'warning',
      icon: 'receipt',
    })
  }

  return queue
}

export function buildDashboardErpStatus(
  input: BuildDashboardErpStatusInput,
): DemoDashboardOverview['erpStatus'] {
  if (!input.hasConnection) {
    return {
      statusLabelKey: 'dashboardSetup.erpCard.statusNotConfigured',
      mappedFields: input.mappedFields,
      totalFields: input.totalFields,
      lastAttemptKey: 'dashboardSetup.erpCard.lastAttemptNone',
      readiness: input.readiness,
      descriptionKey: 'dashboardSetup.erpCard.descriptionNotConfigured',
    }
  }

  return {
    statusLabelKey: input.isActive
      ? 'dashboardSetup.erpCard.statusConnected'
      : 'dashboardSetup.erpCard.statusPending',
    mappedFields: input.mappedFields,
    totalFields: input.totalFields,
    lastAttemptKey: input.isActive
      ? 'dashboardSetup.erpCard.lastAttemptValue'
      : 'dashboardSetup.erpCard.lastAttemptNone',
    readiness: input.readiness,
    descriptionKey: input.isActive
      ? 'dashboardSetup.erpCard.descriptionConnected'
      : 'dashboardSetup.erpCard.descriptionPending',
  }
}

export function mapDashboardErpProvider(provider: string | null | undefined): string | null {
  if (!provider) return null

  const normalized = provider.trim().toLowerCase()
  if (normalized === 'canias') return 'Canias'
  if (normalized === 'logo') return 'Logo'
  if (normalized === 'csv' || normalized === 'csv_import') return 'CSV / Excel'

  return provider
}

export function buildDashboardPageDataFromDemo({
  overview,
  leave,
  expense,
}: {
  overview: DemoDashboardOverview
  leave: DemoLeaveOverview
  expense: DemoExpenseOverview
}): DashboardPageData {
  return {
    stats: {
      tenantName: 'Mert Teknik A.Ş.',
      displayName: null,
      employeeCount: 4,
      departmentCount: 3,
      competencyCount: 6,
      positionCount: overview.positionCount,
      erpConnected: false,
      erpProvider: 'Canias',
      dataReadinessPct: overview.erpStatus.readiness,
    },
    overview,
    leaveSummary: {
      heroRemainingAnnual: leave.heroRemainingAnnual,
      pendingCount: leave.pendingCount,
    },
    expenseSummary: {
      monthlyLimit: expense.monthlyLimit,
      pendingAmount: expense.pendingAmount,
    },
  }
}

export async function fetchDemoDashboardPageData(): Promise<DashboardPageData> {
  const [overview, leave, expense] = await Promise.all([
    fetchDemoDashboardOverview(),
    fetchDemoLeaveOverview(),
    fetchDemoExpenseOverview(),
  ])

  return buildDashboardPageDataFromDemo({ overview, leave, expense })
}

async function fetchRealDashboardOverview(userId: string): Promise<DashboardPageData> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) return emptyDashboardPageData()

  const [dashboardRow, erpRow, leaveRow, leaveBalancesRow, expenseRow, mappingCount, mappingTotal] =
    await Promise.all([
      pulsCalc()
        .from('dashboard_overview')
        .select(
          'employee_count, department_count, position_count, competency_template_count, pending_leave_count, pending_expense_count, data_readiness_pct, active_cycle_name',
        )
        .eq('tenant_id', ctx.tenantId)
        .maybeSingle(),
      pulsIntegration()
        .from('erp_connections')
        .select('provider, is_active')
        .eq('tenant_id', ctx.tenantId)
        .order('is_active', { ascending: false })
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle(),
      ctx.employeeId
        ? pulsCalc()
            .from('leave_overview')
            .select('annual_leave_remaining, pending_leave_count')
            .eq('tenant_id', ctx.tenantId)
            .eq('employee_id', ctx.employeeId)
            .maybeSingle()
        : Promise.resolve({ data: null, error: null }),
      ctx.employeeId
        ? pulsWorkflow()
            .from('leave_balances')
            .select('remaining_days, leave_types ( code )')
            .eq('tenant_id', ctx.tenantId)
            .eq('employee_id', ctx.employeeId)
            .eq('period_year', new Date().getFullYear())
        : Promise.resolve({ data: [], error: null }),
      ctx.employeeId
        ? pulsCalc()
            .from('expense_overview')
            .select('monthly_limit, pending_expense_amount')
            .eq('tenant_id', ctx.tenantId)
            .eq('employee_id', ctx.employeeId)
            .maybeSingle()
        : Promise.resolve({ data: null, error: null }),
      pulsIntegration()
        .from('erp_field_mappings')
        .select('id', { count: 'exact', head: true })
        .eq('tenant_id', ctx.tenantId)
        .eq('is_active', true),
      pulsIntegration()
        .from('erp_field_mappings')
        .select('id', { count: 'exact', head: true })
        .eq('tenant_id', ctx.tenantId),
    ])

  if (dashboardRow.error) {
    throw fromSupabaseError(dashboardRow.error, 'fetchDashboardOverview', 'puls_calc', 'dashboard_overview')
  }
  if (erpRow.error) {
    throw fromSupabaseError(erpRow.error, 'fetchDashboardOverview', 'puls_integration', 'erp_connections')
  }
  if (leaveRow.error) {
    throw fromSupabaseError(leaveRow.error, 'fetchDashboardOverview', 'puls_calc', 'leave_overview')
  }
  if (leaveBalancesRow.error) {
    throw fromSupabaseError(
      leaveBalancesRow.error,
      'fetchDashboardOverview',
      'puls_workflow',
      'leave_balances',
    )
  }
  if (expenseRow.error) {
    throw fromSupabaseError(expenseRow.error, 'fetchDashboardOverview', 'puls_calc', 'expense_overview')
  }

  const mappedFields = mappingCount.count ?? 0
  const totalFields = mappingTotal.count ?? 0
  const readiness = Number(dashboardRow.data?.data_readiness_pct ?? 0)
  const pendingLeave = Number(dashboardRow.data?.pending_leave_count ?? 0)
  const pendingExpense = Number(dashboardRow.data?.pending_expense_count ?? 0)
  const annualBalance = ((leaveBalancesRow.data ?? []) as DashboardLeaveBalanceRow[]).find(
    (row) => row.leave_types?.code === 'annual' || row.leave_types?.code === 'yillik',
  )
  const annualLeaveRemaining =
    annualBalance?.remaining_days ?? Number(leaveRow.data?.annual_leave_remaining ?? 0)

  const overview: DemoDashboardOverview = {
    positionCount: Number(dashboardRow.data?.position_count ?? 0),
    queue: buildDashboardQueue({
      activeCycleName: dashboardRow.data?.active_cycle_name,
      mappedFields,
      totalFields,
      pendingLeave,
      pendingExpense,
    }),
    recentActivities: [],
    erpStatus: buildDashboardErpStatus({
      hasConnection: Boolean(erpRow.data),
      isActive: erpRow.data?.is_active,
      mappedFields,
      totalFields,
      readiness,
    }),
  }

  return {
    stats: {
      tenantName: ctx.tenantName,
      displayName: ctx.employeeName,
      employeeCount: Number(dashboardRow.data?.employee_count ?? 0),
      departmentCount: Number(dashboardRow.data?.department_count ?? 0),
      competencyCount: Number(dashboardRow.data?.competency_template_count ?? 0),
      positionCount: Number(dashboardRow.data?.position_count ?? 0),
      erpConnected: Boolean(erpRow.data?.is_active),
      erpProvider: mapDashboardErpProvider(erpRow.data?.provider as string | null),
      dataReadinessPct: readiness,
    },
    overview,
    leaveSummary: {
      heroRemainingAnnual: Number(annualLeaveRemaining),
      pendingCount: Number(leaveRow.data?.pending_leave_count ?? pendingLeave),
    },
    expenseSummary: {
      monthlyLimit: Number(expenseRow.data?.monthly_limit ?? 0),
      pendingAmount: Number(expenseRow.data?.pending_expense_amount ?? pendingExpense),
    },
  }
}

export async function fetchDashboardOverview(userId: string): Promise<DashboardPageData> {
  return resolveAdapterData({
    operation: 'fetchDashboardOverview',
    fetchReal: () => fetchRealDashboardOverview(userId),
    fetchDemo: fetchDemoDashboardPageData,
    isEmpty: isDashboardEmpty,
  })
}

export function fetchDashboardOverviewWithMeta(userId: string) {
  return resolveAdapterDataWithMeta({
    operation: 'fetchDashboardOverview',
    fetchReal: () => fetchRealDashboardOverview(userId),
    fetchDemo: fetchDemoDashboardPageData,
    isEmpty: isDashboardEmpty,
  })
}
