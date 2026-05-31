import {
  buildAiCoachOverviewFromSnapshot,
  buildBlockedAiCoachOverview,
  buildDemoAiCoachOverview,
  isAiCoachOverviewEmpty,
} from '#/lib/data/ai-coach/context-readiness'
import type { AiCoachContextSnapshot, AiCoachOverview } from '#/lib/data/ai-coach/types'
import {
  pulsCalc,
  pulsCore,
  pulsIntegration,
  pulsPerformance,
  pulsWorkflow,
  resolveTenantContext,
} from '#/lib/data/client'
import { resolveAdapterData, resolveAdapterDataWithMeta } from '#/lib/data/result'

export type { AiCoachOverview, AiCoachContextDomain } from '#/lib/data/ai-coach/types'

type CountResult = { count: number | null; error: unknown }

async function countRows(
  queryPromise: PromiseLike<CountResult>,
  fallback = 0,
): Promise<number> {
  try {
    const result = await queryPromise
    if (result.error) return fallback
    return result.count ?? fallback
  } catch {
    return fallback
  }
}

function settledCount(
  result: PromiseSettledResult<number>,
  fallback: number | null = null,
): number | null {
  if (result.status === 'fulfilled') return result.value
  return fallback
}

async function fetchRealAiCoachOverview(userId: string): Promise<AiCoachOverview> {
  const ctx = await resolveTenantContext(userId)

  if (!ctx.tenantId) {
    return buildBlockedAiCoachOverview()
  }

  const tenantId = ctx.tenantId

  const [
    setupRow,
    dashboardRow,
    leaveOverviewRow,
    expenseOverviewRow,
    performanceOverviewRow,
    contractsOverviewRow,
    departmentCount,
    positionCount,
    employeeCount,
    reportingLineCount,
    leaveTypeCount,
    leaveBalanceCount,
    leaveRequestCount,
    expenseCategoryCount,
    expenseClaimCount,
    contractCount,
    performanceCycleCount,
    competencyTemplateCount,
    performanceScoreCount,
    competencyEvaluationCount,
    sourceNamespaceCount,
    inactiveErpConnectionCount,
  ] = await Promise.allSettled([
    pulsCalc()
      .from('setup_readiness_summary')
      .select('overall_readiness_pct')
      .eq('tenant_id', tenantId)
      .maybeSingle(),
    pulsCalc()
      .from('dashboard_overview')
      .select('tenant_id')
      .eq('tenant_id', tenantId)
      .maybeSingle(),
    pulsCalc()
      .from('leave_overview')
      .select('tenant_id')
      .eq('tenant_id', tenantId)
      .limit(1)
      .maybeSingle(),
    pulsCalc()
      .from('expense_overview')
      .select('tenant_id')
      .eq('tenant_id', tenantId)
      .limit(1)
      .maybeSingle(),
    pulsCalc()
      .from('performance_overview')
      .select('tenant_id')
      .eq('tenant_id', tenantId)
      .limit(1)
      .maybeSingle(),
    pulsCalc()
      .from('contracts_overview')
      .select('tenant_id')
      .eq('tenant_id', tenantId)
      .limit(1)
      .maybeSingle(),
    countRows(
      pulsCore()
        .from('departments')
        .select('id', { count: 'exact', head: true })
        .eq('tenant_id', tenantId)
        .eq('is_active', true),
    ),
    countRows(
      pulsCore()
        .from('positions')
        .select('id', { count: 'exact', head: true })
        .eq('tenant_id', tenantId)
        .eq('is_active', true),
    ),
    countRows(
      pulsCore()
        .from('employees')
        .select('id', { count: 'exact', head: true })
        .eq('tenant_id', tenantId)
        .eq('employment_status', 'active'),
    ),
    countRows(
      pulsCore()
        .from('employee_reporting_lines')
        .select('id', { count: 'exact', head: true })
        .eq('tenant_id', tenantId)
        .eq('is_active', true),
    ),
    countRows(
      pulsWorkflow()
        .from('leave_types')
        .select('id', { count: 'exact', head: true })
        .eq('tenant_id', tenantId)
        .eq('is_active', true),
    ),
    countRows(
      pulsWorkflow()
        .from('leave_balances')
        .select('id', { count: 'exact', head: true })
        .eq('tenant_id', tenantId),
    ),
    countRows(
      pulsWorkflow()
        .from('leave_requests')
        .select('id', { count: 'exact', head: true })
        .eq('tenant_id', tenantId),
    ),
    countRows(
      pulsWorkflow()
        .from('expense_categories')
        .select('id', { count: 'exact', head: true })
        .eq('tenant_id', tenantId)
        .eq('is_active', true),
    ),
    countRows(
      pulsWorkflow()
        .from('expense_claims')
        .select('id', { count: 'exact', head: true })
        .eq('tenant_id', tenantId),
    ),
    countRows(
      pulsWorkflow()
        .from('contracts')
        .select('id', { count: 'exact', head: true })
        .eq('tenant_id', tenantId),
    ),
    countRows(
      pulsPerformance()
        .from('performance_cycles')
        .select('id', { count: 'exact', head: true })
        .eq('tenant_id', tenantId),
    ),
    countRows(
      pulsPerformance()
        .from('competency_templates')
        .select('id', { count: 'exact', head: true })
        .eq('tenant_id', tenantId)
        .eq('is_active', true),
    ),
    countRows(
      pulsPerformance()
        .from('performance_scores')
        .select('id', { count: 'exact', head: true })
        .eq('tenant_id', tenantId),
    ),
    countRows(
      pulsPerformance()
        .from('competency_evaluations')
        .select('id', { count: 'exact', head: true })
        .eq('tenant_id', tenantId),
    ),
    countRows(
      pulsIntegration()
        .from('source_namespaces')
        .select('id', { count: 'exact', head: true })
        .eq('tenant_id', tenantId),
    ),
    countRows(
      pulsIntegration()
        .from('erp_connections')
        .select('id', { count: 'exact', head: true })
        .eq('tenant_id', tenantId)
        .eq('is_active', false),
    ),
  ])

  const setupData =
    setupRow.status === 'fulfilled' && !setupRow.value.error ? setupRow.value.data : null
  const setupQueryOk = setupRow.status === 'fulfilled' && !setupRow.value.error

  const snapshot: AiCoachContextSnapshot = {
    tenantPresent: true,
    employeeId: ctx.employeeId,
    employeeName: ctx.employeeName,
    setupReadinessPct:
      setupData?.overall_readiness_pct !== undefined &&
      setupData?.overall_readiness_pct !== null
        ? Number(setupData.overall_readiness_pct)
        : null,
    setupQueryOk,
    departmentCount: settledCount(departmentCount),
    positionCount: settledCount(positionCount),
    employeeCount: settledCount(employeeCount),
    reportingLineCount: settledCount(reportingLineCount),
    leaveTypeCount: settledCount(leaveTypeCount),
    leaveBalanceCount: settledCount(leaveBalanceCount),
    leaveRequestCount: settledCount(leaveRequestCount),
    expenseCategoryCount: settledCount(expenseCategoryCount),
    expenseClaimCount: settledCount(expenseClaimCount),
    performanceCycleCount: settledCount(performanceCycleCount),
    competencyTemplateCount: settledCount(competencyTemplateCount),
    performanceScoreCount: settledCount(performanceScoreCount),
    competencyEvaluationCount: settledCount(competencyEvaluationCount),
    contractCount: settledCount(contractCount),
    contractsOverviewPresent:
      contractsOverviewRow.status === 'fulfilled' &&
      !contractsOverviewRow.value.error &&
      Boolean(contractsOverviewRow.value.data),
    dashboardOverviewPresent:
      dashboardRow.status === 'fulfilled' &&
      !dashboardRow.value.error &&
      Boolean(dashboardRow.value.data),
    sourceNamespaceCount: settledCount(sourceNamespaceCount),
    inactiveErpConnectionPresent:
      settledCount(inactiveErpConnectionCount, 0) !== null &&
      (settledCount(inactiveErpConnectionCount, 0) ?? 0) >= 1,
    leaveOverviewPresent:
      leaveOverviewRow.status === 'fulfilled' &&
      !leaveOverviewRow.value.error &&
      Boolean(leaveOverviewRow.value.data),
    expenseOverviewPresent:
      expenseOverviewRow.status === 'fulfilled' &&
      !expenseOverviewRow.value.error &&
      Boolean(expenseOverviewRow.value.data),
    performanceOverviewPresent:
      performanceOverviewRow.status === 'fulfilled' &&
      !performanceOverviewRow.value.error &&
      Boolean(performanceOverviewRow.value.data),
  }

  return buildAiCoachOverviewFromSnapshot(snapshot, 'real')
}

export async function fetchAiCoachOverview(userId: string): Promise<AiCoachOverview> {
  return resolveAdapterData({
    operation: 'fetchAiCoachOverview',
    fetchReal: () => fetchRealAiCoachOverview(userId),
    fetchDemo: buildDemoAiCoachOverview,
    isEmpty: isAiCoachOverviewEmpty,
  })
}

export function fetchAiCoachOverviewWithMeta(userId: string) {
  return resolveAdapterDataWithMeta({
    operation: 'fetchAiCoachOverview',
    fetchReal: () => fetchRealAiCoachOverview(userId),
    fetchDemo: buildDemoAiCoachOverview,
    isEmpty: isAiCoachOverviewEmpty,
  })
}
