import { fetchDemoPerformanceOverview } from '#/lib/demo/puls-demo-data'
import type { DemoPerformanceOverview } from '#/lib/demo/puls-demo-data'
import { fromSupabaseError } from '#/lib/data/errors'
import { pulsCalc, pulsCore, pulsPerformance, resolveTenantContext } from '#/lib/data/client'
import { resolveAdapterData } from '#/lib/data/result'

export type PerformanceOverview = DemoPerformanceOverview

function emptyPerformanceOverview(): PerformanceOverview {
  return {
    employeeScopeCount: 0,
    evaluatorCount: 0,
    pendingReviews: 0,
    completedThisWeek: 0,
    overdueCount: 0,
    defaultCycleName: '—',
    templateDisplayByIndex: [],
  }
}

function isPerformanceOverviewEmpty(data: PerformanceOverview): boolean {
  return data.employeeScopeCount === 0 && data.templateDisplayByIndex.length === 0
}

async function fetchRealPerformanceOverview(userId: string): Promise<PerformanceOverview> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) return emptyPerformanceOverview()

  const [dashboardRow, templatesRow, employeeCount, evaluatorCount, pendingReviews] =
    await Promise.all([
      pulsCalc()
        .from('dashboard_overview')
        .select('active_cycle_name, employee_count')
        .eq('tenant_id', ctx.tenantId)
        .maybeSingle(),
      pulsPerformance()
        .from('competency_templates')
        .select('id, updated_at')
        .eq('tenant_id', ctx.tenantId)
        .eq('is_active', true)
        .order('sort_order', { ascending: true }),
      pulsCore()
        .from('employees')
        .select('id', { count: 'exact', head: true })
        .eq('tenant_id', ctx.tenantId)
        .eq('employment_status', 'active'),
      pulsCore()
        .from('employees')
        .select('id', { count: 'exact', head: true })
        .eq('tenant_id', ctx.tenantId)
        .in('persona_role', ['manager', 'hr_admin', 'superadmin']),
      pulsPerformance()
        .from('competency_evaluations')
        .select('id', { count: 'exact', head: true })
        .eq('tenant_id', ctx.tenantId)
        .in('status', ['draft', 'pending']),
    ])

  if (dashboardRow.error) {
    throw fromSupabaseError(
      dashboardRow.error,
      'fetchPerformanceOverview',
      'puls_calc',
      'dashboard_overview',
    )
  }
  if (templatesRow.error) {
    throw fromSupabaseError(
      templatesRow.error,
      'fetchPerformanceOverview',
      'puls_performance',
      'competency_templates',
    )
  }
  if (employeeCount.error) {
    throw fromSupabaseError(
      employeeCount.error,
      'fetchPerformanceOverview',
      'puls_core',
      'employees',
    )
  }
  if (evaluatorCount.error) {
    throw fromSupabaseError(
      evaluatorCount.error,
      'fetchPerformanceOverview',
      'puls_core',
      'employees',
    )
  }
  if (pendingReviews.error) {
    throw fromSupabaseError(
      pendingReviews.error,
      'fetchPerformanceOverview',
      'puls_performance',
      'competency_evaluations',
    )
  }

  const templateDisplayByIndex = (templatesRow.data ?? []).map((row) => ({
    areasCount: 0,
    updatedKey: ((row.updated_at as string | null) ?? '').slice(0, 10) || '—',
  }))

  return {
    employeeScopeCount: employeeCount.count ?? Number(dashboardRow.data?.employee_count ?? 0),
    evaluatorCount: evaluatorCount.count ?? 0,
    pendingReviews: pendingReviews.count ?? 0,
    completedThisWeek: 0,
    overdueCount: 0,
    defaultCycleName: (dashboardRow.data?.active_cycle_name as string | null) ?? '—',
    templateDisplayByIndex,
  }
}

export async function fetchPerformanceOverview(userId: string): Promise<PerformanceOverview> {
  return resolveAdapterData({
    operation: 'fetchPerformanceOverview',
    fetchReal: () => fetchRealPerformanceOverview(userId),
    fetchDemo: fetchDemoPerformanceOverview,
    isEmpty: isPerformanceOverviewEmpty,
  })
}
