import { fetchDemoLeaveTypesOverview } from '#/lib/demo/puls-demo-data'
import type { DemoLeaveTypesOverview } from '#/lib/demo/puls-demo-data'
import { fromSupabaseError } from '#/lib/data/errors'
import { pulsWorkflow, resolveTenantContext } from '#/lib/data/client'
import { resolveAdapterData } from '#/lib/data/result'

export type LeaveTypesOverview = DemoLeaveTypesOverview

const LEAVE_TYPE_LABEL_KEYS: Record<string, string> = {
  annual: 'leaveTypeSetup.types.annual',
  excuse: 'leaveTypeSetup.types.excuse',
  sick: 'leaveTypeSetup.types.sick',
  unpaid: 'leaveTypeSetup.types.unpaid',
  administrative: 'leaveTypeSetup.types.administrative',
  marriage: 'leaveTypeSetup.types.marriage',
  parental: 'leaveTypeSetup.types.parental',
  birth: 'leaveTypeSetup.types.parental',
  bereavement: 'leaveTypeSetup.types.bereavement',
}

function emptyLeaveTypesOverview(): LeaveTypesOverview {
  return {
    typeCount: 0,
    paidCount: 0,
    docRequiredCount: 0,
    leaveTypes: [],
  }
}

async function fetchRealLeaveTypesOverview(userId: string): Promise<LeaveTypesOverview> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) return emptyLeaveTypesOverview()

  const { data, error } = await pulsWorkflow()
    .from('leave_types')
    .select(
      'id, code, name, default_entitlement_days, is_paid, requires_document, carry_over_allowed',
    )
    .eq('tenant_id', ctx.tenantId)
    .eq('is_active', true)
    .order('name', { ascending: true })

  if (error) {
    throw fromSupabaseError(error, 'fetchLeaveTypesOverview', 'puls_workflow', 'leave_types')
  }

  const leaveTypes = (data ?? []).map((row) => {
    const code = row.code as string
    return {
      id: row.id as string,
      labelKey: LEAVE_TYPE_LABEL_KEYS[code] ?? code,
      days: Number(row.default_entitlement_days ?? 0),
      paid: Boolean(row.is_paid),
      doc: Boolean(row.requires_document),
      carryOver: Boolean(row.carry_over_allowed),
    }
  })

  return {
    typeCount: leaveTypes.length,
    paidCount: leaveTypes.filter((row) => row.paid).length,
    docRequiredCount: leaveTypes.filter((row) => row.doc).length,
    leaveTypes,
  }
}

export async function fetchLeaveTypesOverview(userId: string): Promise<LeaveTypesOverview> {
  return resolveAdapterData({
    operation: 'fetchLeaveTypesOverview',
    fetchReal: () => fetchRealLeaveTypesOverview(userId),
    fetchDemo: fetchDemoLeaveTypesOverview,
    isEmpty: (data) => data.leaveTypes.length === 0,
  })
}
