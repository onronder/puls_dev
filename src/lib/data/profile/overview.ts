import { fetchDemoProfileOverview } from '#/lib/demo/puls-demo-data'
import type { DemoProfileOverview } from '#/lib/demo/puls-demo-data'
import { fromSupabaseError } from '#/lib/data/errors'
import {
  pulsCalc,
  pulsCore,
  pulsWorkflow,
  resolveTenantContext,
  type TenantContext,
} from '#/lib/data/client'
import { fetchNamesByIds } from '#/lib/data/core/lookups'
import {
  mapProfileEmployeeFields,
  resolveProfileStatusKey,
} from '#/lib/data/profile/mapping'
import { resolveAdapterData, resolveAdapterDataWithMeta } from '#/lib/data/result'

export type ProfileEmployeeLinkStatus =
  | 'linked_employee'
  | 'tenant_without_employee'
  | 'no_tenant'

export type ProfileOverview = DemoProfileOverview & {
  tenantName: string | null
  employeeName: string | null
  employeeLinked: boolean
  accountLinkStatus: ProfileEmployeeLinkStatus
}

export function mapPersonaRoleKey(role: string | null | undefined): string {
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

export function buildProfileAccountLinkStatus(
  ctx: Pick<TenantContext, 'tenantId' | 'employeeId'>,
): ProfileEmployeeLinkStatus {
  if (!ctx.tenantId) return 'no_tenant'
  if (!ctx.employeeId) return 'tenant_without_employee'
  return 'linked_employee'
}

function baseEmptyProfileFields(fallbackEmail = '—'): DemoProfileOverview {
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

export function buildEmptyProfileOverview(
  ctx?: Pick<TenantContext, 'tenantId' | 'tenantName' | 'employeeId' | 'employeeName'>,
  fallbackEmail = '—',
): ProfileOverview {
  const accountLinkStatus = buildProfileAccountLinkStatus({
    tenantId: ctx?.tenantId ?? null,
    employeeId: ctx?.employeeId ?? null,
  })

  return {
    ...baseEmptyProfileFields(fallbackEmail),
    tenantName: ctx?.tenantName ?? null,
    employeeName: ctx?.employeeName ?? null,
    employeeLinked: accountLinkStatus === 'linked_employee',
    accountLinkStatus,
  }
}

export function buildProfileOverviewFromDemo(demo: DemoProfileOverview): ProfileOverview {
  return {
    ...demo,
    tenantName: 'Mert Teknik A.Ş.',
    employeeName: null,
    employeeLinked: true,
    accountLinkStatus: 'linked_employee',
  }
}

export async function fetchDemoProfileOverviewData(): Promise<ProfileOverview> {
  const demo = await fetchDemoProfileOverview()
  return buildProfileOverviewFromDemo(demo)
}

export function isProfileOverviewEmpty(data: ProfileOverview): boolean {
  return data.accountLinkStatus === 'no_tenant'
}

async function fetchRealProfileOverview(userId: string): Promise<ProfileOverview> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.employeeId) {
    return buildEmptyProfileOverview(ctx)
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
  const profileFields = mapProfileEmployeeFields(employeeRow.data)

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
    fallbackEmail: profileFields.email ?? '—',
    departmentKey: departmentId ? (departmentNameMap.get(departmentId) ?? '—') : '—',
    positionKey: positionId ? (positionNameMap.get(positionId) ?? '—') : '—',
    roleKey: mapPersonaRoleKey(profileFields.personaRole),
    statusKey: resolveProfileStatusKey(profileFields.employmentStatus),
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
    tenantName: ctx.tenantName,
    employeeName: ctx.employeeName,
    employeeLinked: true,
    accountLinkStatus: 'linked_employee',
  }
}

export async function fetchProfileOverview(userId: string): Promise<ProfileOverview> {
  return resolveAdapterData({
    operation: 'fetchProfileOverview',
    fetchReal: () => fetchRealProfileOverview(userId),
    fetchDemo: fetchDemoProfileOverviewData,
    isEmpty: isProfileOverviewEmpty,
  })
}

export function fetchProfileOverviewWithMeta(userId: string) {
  return resolveAdapterDataWithMeta({
    operation: 'fetchProfileOverview',
    fetchReal: () => fetchRealProfileOverview(userId),
    fetchDemo: fetchDemoProfileOverviewData,
    isEmpty: isProfileOverviewEmpty,
  })
}
