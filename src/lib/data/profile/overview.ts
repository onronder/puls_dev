import { fetchDemoProfileOverview } from '#/lib/demo/puls-demo-data'
import type { DemoProfileOverview } from '#/lib/demo/puls-demo-data'
import { fromSupabaseError } from '#/lib/data/errors'
import { pulsCalc, pulsCore, pulsWorkflow, resolveTenantContext } from '#/lib/data/client'
import { fetchNamesByIds } from '#/lib/data/core/lookups'
import { resolveAdapterData } from '#/lib/data/result'

export type ProfileOverview = DemoProfileOverview

function mapPersonaRoleKey(role: string | null | undefined): string {
  switch (role) {
    case 'superadmin':
    case 'hr_admin':
      return 'profileSetup.fields.roleValue'
    case 'manager':
      return 'persona.manager'
    default:
      return 'persona.employee'
  }
}

function emptyProfileOverview(fallbackEmail = '—'): ProfileOverview {
  return {
    fallbackEmail,
    departmentKey: '—',
    positionKey: '—',
    roleKey: 'persona.employee',
    statusKey: 'profileSetup.status.active',
    leaveRemaining: 0,
    leaveTotal: 0,
    leaveHintKey: 'profileSetup.selfHr.leaveHint',
    pendingExpenseAmount: 0,
    pendingExpenseCount: 0,
    performanceCycleKey: 'profileSetup.selfHr.performanceCycle',
    performanceHintKey: 'profileSetup.selfHr.performanceHint',
    recentActivities: [],
  }
}

function isProfileOverviewEmpty(data: ProfileOverview): boolean {
  return (
    data.leaveTotal === 0 &&
    data.pendingExpenseCount === 0 &&
    data.recentActivities.length === 0 &&
    data.departmentKey === '—'
  )
}

async function fetchRealProfileOverview(userId: string): Promise<ProfileOverview> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.employeeId) {
    return emptyProfileOverview()
  }

  const [employeeRow, leaveRow, expenseRow, performanceRow] = await Promise.all([
    pulsCore()
      .from('employees')
      .select('email, employment_status, persona_role, department_id, position_id')
      .eq('id', ctx.employeeId)
      .maybeSingle(),
    pulsCalc()
      .from('leave_overview')
      .select('annual_leave_remaining, annual_leave_total')
      .eq('tenant_id', ctx.tenantId!)
      .eq('employee_id', ctx.employeeId)
      .maybeSingle(),
    pulsCalc()
      .from('expense_overview')
      .select('pending_expense_amount')
      .eq('tenant_id', ctx.tenantId!)
      .eq('employee_id', ctx.employeeId)
      .maybeSingle(),
    pulsCalc()
      .from('performance_overview')
      .select('active_cycle_name, pending_review_count')
      .eq('tenant_id', ctx.tenantId!)
      .eq('employee_id', ctx.employeeId)
      .maybeSingle(),
  ])

  if (employeeRow.error) {
    throw fromSupabaseError(employeeRow.error, 'fetchProfileOverview', 'puls_core', 'employees')
  }
  if (leaveRow.error) {
    throw fromSupabaseError(leaveRow.error, 'fetchProfileOverview', 'puls_calc', 'leave_overview')
  }
  if (expenseRow.error) {
    throw fromSupabaseError(expenseRow.error, 'fetchProfileOverview', 'puls_calc', 'expense_overview')
  }
  if (performanceRow.error) {
    throw fromSupabaseError(
      performanceRow.error,
      'fetchProfileOverview',
      'puls_calc',
      'performance_overview',
    )
  }

  const departmentId = employeeRow.data?.department_id as string | null
  const positionId = employeeRow.data?.position_id as string | null
  const pendingCount = Number(performanceRow.data?.pending_review_count ?? 0)

  const [departmentNameMap, positionNameMap, pendingExpenseCountResult] = await Promise.all([
    departmentId
      ? fetchNamesByIds('departments', ctx.tenantId!, [departmentId])
      : Promise.resolve(new Map<string, string>()),
    positionId
      ? fetchNamesByIds('positions', ctx.tenantId!, [positionId])
      : Promise.resolve(new Map<string, string>()),
    pulsWorkflow()
      .from('expense_claims')
      .select('id', { count: 'exact', head: true })
      .eq('tenant_id', ctx.tenantId!)
      .eq('employee_id', ctx.employeeId)
      .eq('status', 'pending'),
  ])

  if (pendingExpenseCountResult.error) {
    throw fromSupabaseError(
      pendingExpenseCountResult.error,
      'fetchProfileOverview',
      'puls_workflow',
      'expense_claims',
    )
  }

  const cycleName = performanceRow.data?.active_cycle_name as string | null

  return {
    fallbackEmail: (employeeRow.data?.email as string | null) ?? '—',
    departmentKey: departmentId ? (departmentNameMap.get(departmentId) ?? '—') : '—',
    positionKey: positionId ? (positionNameMap.get(positionId) ?? '—') : '—',
    roleKey: mapPersonaRoleKey(employeeRow.data?.persona_role as string | null),
    statusKey:
      employeeRow.data?.employment_status === 'active'
        ? 'profileSetup.status.active'
        : 'profileSetup.status.inactive',
    leaveRemaining: Number(leaveRow.data?.annual_leave_remaining ?? 0),
    leaveTotal: Number(leaveRow.data?.annual_leave_total ?? 0),
    leaveHintKey: 'profileSetup.selfHr.leaveHint',
    pendingExpenseAmount: Number(expenseRow.data?.pending_expense_amount ?? 0),
    pendingExpenseCount: pendingExpenseCountResult.count ?? 0,
    performanceCycleKey: cycleName ?? 'profileSetup.selfHr.performanceCycle',
    performanceHintKey:
      pendingCount > 0
        ? 'profileSetup.selfHr.performanceHintPending'
        : 'profileSetup.selfHr.performanceHint',
    recentActivities: [],
  }
}

export async function fetchProfileOverview(userId: string): Promise<ProfileOverview> {
  return resolveAdapterData({
    operation: 'fetchProfileOverview',
    fetchReal: () => fetchRealProfileOverview(userId),
    fetchDemo: fetchDemoProfileOverview,
    isEmpty: isProfileOverviewEmpty,
  })
}
