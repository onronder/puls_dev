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
import { pulsCalc, pulsIntegration, resolveTenantContext } from '#/lib/data/client'
import { resolveAdapterData } from '#/lib/data/result'

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

function emptyDashboardOverview(): DemoDashboardOverview {
  return {
    positionCount: 0,
    queue: [],
    recentActivities: [],
    erpStatus: {
      statusLabelKey: 'dashboardSetup.erpCard.statusPending',
      mappedFields: 0,
      totalFields: 0,
      lastAttemptKey: 'dashboardSetup.erpCard.lastAttemptValue',
      readiness: 0,
      descriptionKey: 'dashboardSetup.erpCard.description',
    },
  }
}

function emptyDashboardPageData(): DashboardPageData {
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

function isDashboardEmpty(data: DashboardPageData): boolean {
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

async function fetchRealDashboardOverview(userId: string): Promise<DashboardPageData> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) return emptyDashboardPageData()

  const [dashboardRow, erpRow, leaveRow, expenseRow, mappingCount, mappingTotal] =
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
        .eq('is_active', true)
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
  if (expenseRow.error) {
    throw fromSupabaseError(expenseRow.error, 'fetchDashboardOverview', 'puls_calc', 'expense_overview')
  }

  const mappedFields = mappingCount.count ?? 0
  const totalFields = Math.max(mappingTotal.count ?? 0, mappedFields)
  const readiness = Number(dashboardRow.data?.data_readiness_pct ?? 0)
  const pendingLeave = Number(dashboardRow.data?.pending_leave_count ?? 0)
  const pendingExpense = Number(dashboardRow.data?.pending_expense_count ?? 0)

  const queue: DemoDashboardOverview['queue'] = []
  if (dashboardRow.data?.active_cycle_name == null) {
    queue.push({
      id: 'q1',
      titleKey: 'dashboardSetup.queue.performancePeriod.title',
      metaKey: 'dashboardSetup.queue.performancePeriod.meta',
      to: '/performans',
      tone: 'info',
      icon: 'target',
    })
  }
  if (mappedFields < totalFields) {
    queue.push({
      id: 'q2',
      titleKey: 'dashboardSetup.queue.fieldMapping.title',
      metaKey: 'dashboardSetup.queue.fieldMapping.meta',
      to: '/erp',
      tone: 'warning',
      icon: 'plug',
    })
  }
  if (pendingLeave > 0) {
    queue.push({
      id: 'q3',
      titleKey: 'dashboardSetup.queue.leaveApproval.title',
      metaKey: 'dashboardSetup.queue.leaveApproval.meta',
      to: '/izin',
      tone: 'warning',
      icon: 'calendarCheck',
    })
  }
  if (pendingExpense > 0) {
    queue.push({
      id: 'q4',
      titleKey: 'dashboardSetup.queue.expenseApproval.title',
      metaKey: 'dashboardSetup.queue.expenseApproval.meta',
      to: '/masraf',
      tone: 'warning',
      icon: 'receipt',
    })
  }

  const overview: DemoDashboardOverview = {
    positionCount: Number(dashboardRow.data?.position_count ?? 0),
    queue,
    recentActivities: [],
    erpStatus: {
      statusLabelKey: erpRow.data?.is_active
        ? 'dashboard.erpConnected'
        : 'dashboardSetup.erpCard.statusPending',
      mappedFields,
      totalFields: totalFields || 12,
      lastAttemptKey: 'dashboardSetup.erpCard.lastAttemptValue',
      readiness,
      descriptionKey: 'dashboardSetup.erpCard.description',
    },
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
      erpProvider: (erpRow.data?.provider as string | null) ?? null,
      dataReadinessPct: readiness,
    },
    overview,
    leaveSummary: {
      heroRemainingAnnual: Number(leaveRow.data?.annual_leave_remaining ?? 0),
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
    fetchDemo: async () => {
      const [overview, leave, expense] = await Promise.all([
        fetchDemoDashboardOverview(),
        fetchDemoLeaveOverview(),
        fetchDemoExpenseOverview(),
      ])
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
    },
    isEmpty: isDashboardEmpty,
  })
}
