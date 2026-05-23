import { fetchDemoLeaveOverview } from '#/lib/demo/puls-demo-data'
import type {
  DemoLeaveOverview,
  DemoLeaveApproval,
  DemoLeaveRequest,
  DemoUpcomingLeave,
  LeaveStatus,
} from '#/lib/demo/puls-demo-data'
import { fromSupabaseError } from '#/lib/data/errors'
import { pulsCalc, pulsWorkflow, resolveTenantContext } from '#/lib/data/client'
import { resolveAdapterData } from '#/lib/data/result'

export type LeaveOverview = DemoLeaveOverview
export type { LeaveStatus }

const LEAVE_TYPE_LABEL_KEYS: Record<string, string> = {
  annual: 'leave.types.annual',
  excuse: 'leave.types.excuse',
  sick: 'leave.types.sick',
}

function getInitials(name: string): string {
  return name
    .split(' ')
    .filter(Boolean)
    .map((part) => part[0])
    .join('')
    .slice(0, 2)
    .toUpperCase()
}

function emptyLeaveOverview(): LeaveOverview {
  return {
    heroRemainingAnnual: 0,
    heroUsedAnnual: 0,
    heroTotalAnnual: 0,
    balances: [],
    pendingCount: 0,
    requests: [],
    upcoming: [],
    pendingApprovals: [],
    leaveTypes: [],
    delegates: [],
    approvers: [],
  }
}

function isLeaveOverviewEmpty(data: LeaveOverview): boolean {
  return (
    data.requests.length === 0 &&
    data.balances.length === 0 &&
    data.heroTotalAnnual === 0 &&
    data.pendingApprovals.length === 0
  )
}

async function fetchRealLeaveOverview(userId: string): Promise<LeaveOverview> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.employeeId || !ctx.tenantId) return emptyLeaveOverview()

  const [overviewRow, balancesRow, requestsRow, leaveTypesRow, teamPendingRow] = await Promise.all([
    pulsCalc()
      .from('leave_overview')
      .select(
        'annual_leave_remaining, annual_leave_used, annual_leave_total, excuse_leave_remaining, sick_leave_remaining, pending_leave_count',
      )
      .eq('tenant_id', ctx.tenantId)
      .eq('employee_id', ctx.employeeId)
      .maybeSingle(),
    pulsWorkflow()
      .from('leave_balances')
      .select(
        `
        remaining_days,
        used_days,
        entitlement_days,
        carried_over_days,
        adjustment_days,
        leave_types ( code, name )
      `,
      )
      .eq('tenant_id', ctx.tenantId)
      .eq('employee_id', ctx.employeeId)
      .eq('period_year', new Date().getFullYear()),
    pulsWorkflow()
      .from('leave_requests')
      .select(
        `
        id,
        start_date,
        end_date,
        business_days,
        status,
        delegate:delegate_employee_id ( full_name ),
        leave_types ( name )
      `,
      )
      .eq('tenant_id', ctx.tenantId)
      .eq('employee_id', ctx.employeeId)
      .order('start_date', { ascending: false })
      .limit(20),
    pulsWorkflow()
      .from('leave_types')
      .select('id, code, name')
      .eq('tenant_id', ctx.tenantId)
      .eq('is_active', true)
      .order('name', { ascending: true }),
    ctx.personaRole === 'manager' || ctx.personaRole === 'hr_admin' || ctx.personaRole === 'superadmin'
      ? pulsWorkflow()
          .from('leave_requests')
          .select(
            `
            id,
            start_date,
            end_date,
            business_days,
            employees ( full_name ),
            leave_types ( name )
          `,
          )
          .eq('tenant_id', ctx.tenantId)
          .eq('status', 'pending')
          .order('start_date', { ascending: true })
          .limit(10)
      : Promise.resolve({ data: [], error: null }),
  ])

  if (overviewRow.error) {
    throw fromSupabaseError(overviewRow.error, 'fetchLeaveOverview', 'puls_calc', 'leave_overview')
  }
  if (balancesRow.error) {
    throw fromSupabaseError(balancesRow.error, 'fetchLeaveOverview', 'puls_workflow', 'leave_balances')
  }
  if (requestsRow.error) {
    throw fromSupabaseError(requestsRow.error, 'fetchLeaveOverview', 'puls_workflow', 'leave_requests')
  }
  if (leaveTypesRow.error) {
    throw fromSupabaseError(leaveTypesRow.error, 'fetchLeaveOverview', 'puls_workflow', 'leave_types')
  }
  if (teamPendingRow.error) {
    throw fromSupabaseError(
      teamPendingRow.error,
      'fetchLeaveOverview',
      'puls_workflow',
      'leave_requests',
    )
  }

  const overview = overviewRow.data
  const balances = (balancesRow.data ?? []).map((row) => {
    const leaveType = row.leave_types as { code?: string; name?: string } | null
    const code = (leaveType?.code ?? 'annual') as 'annual' | 'excuse' | 'sick'
    const total =
      Number(row.entitlement_days ?? 0) +
      Number(row.carried_over_days ?? 0) +
      Number(row.adjustment_days ?? 0)
    return {
      typeCode: code,
      labelKey: LEAVE_TYPE_LABEL_KEYS[code] ?? leaveType?.name ?? code,
      totalDays: total,
      usedDays: Number(row.used_days ?? 0),
      remainingDays: Number(row.remaining_days ?? 0),
    }
  })

  if (
    balances.length === 0 &&
    Number(overview?.annual_leave_total ?? 0) > 0
  ) {
    balances.push({
      typeCode: 'annual',
      labelKey: LEAVE_TYPE_LABEL_KEYS.annual,
      totalDays: Number(overview?.annual_leave_total ?? 0),
      usedDays: Number(overview?.annual_leave_used ?? 0),
      remainingDays: Number(overview?.annual_leave_remaining ?? 0),
    })
  }

  const requests: DemoLeaveRequest[] = (requestsRow.data ?? []).map((row) => {
    const leaveType = row.leave_types as { name?: string } | null
    const delegate = row.delegate as { full_name?: string } | null
    return {
      id: row.id as string,
      typeLabel: leaveType?.name ?? '—',
      startDate: row.start_date as string,
      endDate: row.end_date as string,
      businessDays: Number(row.business_days ?? 0),
      delegateName: delegate?.full_name ?? undefined,
      status: row.status as LeaveStatus,
    }
  })

  const today = new Date().toISOString().slice(0, 10)
  const upcoming: DemoUpcomingLeave[] = (requestsRow.data ?? [])
    .filter((row) => (row.start_date as string) >= today && row.status !== 'rejected')
    .slice(0, 5)
    .map((row) => {
      const leaveType = row.leave_types as { name?: string } | null
      return {
        id: row.id as string,
        whoName: ctx.employeeName ?? 'Sen',
        isSelf: true,
        typeLabel: leaveType?.name ?? '—',
        startDate: row.start_date as string,
        endDate: row.end_date as string,
        businessDays: Number(row.business_days ?? 0),
        status: row.status as LeaveStatus,
      }
    })

  const pendingApprovals: DemoLeaveApproval[] = (teamPendingRow.data ?? []).map((row) => {
    const employee = row.employees as { full_name?: string } | null
    const leaveType = row.leave_types as { name?: string } | null
    const employeeName = employee?.full_name ?? '—'
    return {
      id: row.id as string,
      employeeName,
      initials: getInitials(employeeName),
      typeLabel: leaveType?.name ?? '—',
      startDate: row.start_date as string,
      endDate: row.end_date as string,
      businessDays: Number(row.business_days ?? 0),
    }
  })

  return {
    heroRemainingAnnual: Number(overview?.annual_leave_remaining ?? 0),
    heroUsedAnnual: Number(overview?.annual_leave_used ?? 0),
    heroTotalAnnual: Number(overview?.annual_leave_total ?? 0),
    balances,
    pendingCount: Number(overview?.pending_leave_count ?? 0),
    requests,
    upcoming,
    pendingApprovals,
    leaveTypes: (leaveTypesRow.data ?? []).map((row) => ({
      id: row.id as string,
      label: row.name as string,
    })),
    delegates: [],
    approvers: [],
  }
}

export async function fetchLeaveOverview(userId: string): Promise<LeaveOverview> {
  return resolveAdapterData({
    operation: 'fetchLeaveOverview',
    fetchReal: () => fetchRealLeaveOverview(userId),
    fetchDemo: fetchDemoLeaveOverview,
    isEmpty: isLeaveOverviewEmpty,
  })
}
