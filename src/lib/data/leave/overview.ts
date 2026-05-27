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
import { fetchNamesByIds, uniqueNonNullIds } from '#/lib/data/core/lookups'
import { resolveAdapterData } from '#/lib/data/result'

export type LeaveOverview = Omit<DemoLeaveOverview, 'leaveTypes'> & {
  leaveTypes: { id: string; label: string; code: string; requiresDocument: boolean }[]
}
export type { LeaveStatus }

type LeaveTypeLookupJoin = { name?: string; is_active?: boolean } | null | undefined

export function mapLeaveTypeFromLookup(join: LeaveTypeLookupJoin): {
  typeLabel: string
  typeIsActive: boolean
} {
  if (!join?.name) {
    return { typeLabel: '—', typeIsActive: true }
  }

  return {
    typeLabel: join.name,
    typeIsActive: join.is_active !== false,
  }
}

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
        delegate_employee_id,
        leave_type_id
      `,
      )
      .eq('tenant_id', ctx.tenantId)
      .eq('employee_id', ctx.employeeId)
      .order('start_date', { ascending: false })
      .limit(20),
    pulsWorkflow()
      .from('leave_types')
      .select('id, code, name, requires_document')
      .eq('tenant_id', ctx.tenantId)
      .eq('is_active', true)
      .order('name', { ascending: true }),
    pulsWorkflow()
      .from('approval_requests')
      .select('id, leave_request_id, requester_employee_id')
      .eq('tenant_id', ctx.tenantId)
      .eq('module', 'leave')
      .eq('status', 'pending')
      .eq('approver_employee_id', ctx.employeeId)
      .neq('requester_employee_id', ctx.employeeId)
      .order('created_at', { ascending: true })
      .limit(10),
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
      'approval_requests',
    )
  }

  const approvalRows = teamPendingRow.data ?? []
  const historyRows = requestsRow.data ?? []
  const historyDelegateIds = uniqueNonNullIds(
    historyRows.map((row) => row.delegate_employee_id as string | null),
  )
  const historyLeaveTypeIds = uniqueNonNullIds(
    historyRows.map((row) => row.leave_type_id as string | null),
  )
  const leaveRequestIds = uniqueNonNullIds(
    approvalRows.map((row) => row.leave_request_id as string | null),
  )
  const requesterIds = uniqueNonNullIds(
    approvalRows.map((row) => row.requester_employee_id as string | null),
  )

  const [historyDelegateNameMap, leaveRequestRows, requesterNameMap] = await Promise.all([
    fetchNamesByIds('employees', ctx.tenantId, historyDelegateIds),
    leaveRequestIds.length > 0
      ? pulsWorkflow()
          .from('leave_requests')
          .select('id, start_date, end_date, business_days, leave_type_id')
          .eq('tenant_id', ctx.tenantId)
          .in('id', leaveRequestIds)
      : Promise.resolve({ data: [], error: null }),
    fetchNamesByIds('employees', ctx.tenantId, requesterIds),
  ])

  if (leaveRequestRows.error) {
    throw fromSupabaseError(
      leaveRequestRows.error,
      'fetchLeaveOverview',
      'puls_workflow',
      'leave_requests',
    )
  }

  const leaveTypeIds = uniqueNonNullIds([
    ...historyLeaveTypeIds,
    ...(leaveRequestRows.data ?? []).map((row) => row.leave_type_id as string | null),
  ])

  const leaveTypeMetaMap =
    leaveTypeIds.length > 0
      ? await (async () => {
          const { data, error } = await pulsWorkflow()
            .from('leave_types')
            .select('id, name, is_active')
            .eq('tenant_id', ctx.tenantId)
            .in('id', leaveTypeIds)

          if (error) {
            throw fromSupabaseError(error, 'fetchLeaveOverview', 'puls_workflow', 'leave_types')
          }

          return new Map(
            (data ?? []).map((row) => [
              row.id as string,
              mapLeaveTypeFromLookup({
                name: row.name as string,
                is_active: row.is_active as boolean,
              }),
            ]),
          )
        })()
      : new Map<string, { typeLabel: string; typeIsActive: boolean }>()

  function resolveLeaveTypeMeta(leaveTypeId: string | null | undefined) {
    return (
      leaveTypeMetaMap.get(leaveTypeId as string) ?? {
        typeLabel: '—',
        typeIsActive: true,
      }
    )
  }

  const leaveRequestById = new Map(
    (leaveRequestRows.data ?? []).map((row) => [row.id as string, row]),
  )

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

  const requests: DemoLeaveRequest[] = historyRows.map((row) => {
    const typeMeta = resolveLeaveTypeMeta(row.leave_type_id as string)
    return {
      id: row.id as string,
      typeLabel: typeMeta.typeLabel,
      typeIsActive: typeMeta.typeIsActive,
      startDate: row.start_date as string,
      endDate: row.end_date as string,
      businessDays: Number(row.business_days ?? 0),
      delegateName: historyDelegateNameMap.get(row.delegate_employee_id as string) ?? undefined,
      status: row.status as LeaveStatus,
    }
  })

  const today = new Date().toISOString().slice(0, 10)
  const upcoming: DemoUpcomingLeave[] = historyRows
    .filter((row) => (row.start_date as string) >= today && row.status !== 'rejected')
    .slice(0, 5)
    .map((row) => {
      const typeMeta = resolveLeaveTypeMeta(row.leave_type_id as string)
      return {
        id: row.id as string,
        whoName: ctx.employeeName ?? 'Sen',
        isSelf: true,
        typeLabel: typeMeta.typeLabel,
        typeIsActive: typeMeta.typeIsActive,
        startDate: row.start_date as string,
        endDate: row.end_date as string,
        businessDays: Number(row.business_days ?? 0),
        status: row.status as LeaveStatus,
      }
    })

  const pendingApprovals: DemoLeaveApproval[] = approvalRows.flatMap((row) => {
    const leaveRequest = leaveRequestById.get(row.leave_request_id as string)
    if (!leaveRequest) return []

    const employeeName = requesterNameMap.get(row.requester_employee_id as string) ?? '—'
    const typeMeta = resolveLeaveTypeMeta(leaveRequest.leave_type_id as string)

    return [
      {
        id: row.id as string,
        employeeName,
        initials: getInitials(employeeName),
        typeLabel: typeMeta.typeLabel,
        typeIsActive: typeMeta.typeIsActive,
        startDate: leaveRequest.start_date as string,
        endDate: leaveRequest.end_date as string,
        businessDays: Number(leaveRequest.business_days ?? 0),
      },
    ]
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
      code: row.code as string,
      requiresDocument: Boolean(row.requires_document),
    })),
    delegates: [],
    approvers: [],
  }
}

export async function fetchLeaveOverview(userId: string): Promise<LeaveOverview> {
  return resolveAdapterData({
    operation: 'fetchLeaveOverview',
    fetchReal: () => fetchRealLeaveOverview(userId),
    fetchDemo: async () => {
      const demo = await fetchDemoLeaveOverview()
      return {
        ...demo,
        leaveTypes: demo.leaveTypes.map((type) => ({
          ...type,
          code: type.id,
          requiresDocument: type.id === 'sick' || type.id === 'maternity',
        })),
      }
    },
    isEmpty: isLeaveOverviewEmpty,
  })
}
