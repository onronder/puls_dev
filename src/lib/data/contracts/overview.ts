import { fetchDemoContractsOverview } from '#/lib/demo/puls-demo-data'
import type {
  DemoContractsOverview,
  DemoContractItem,
  DemoContractRiskStatus,
  DemoContractSignedStatus,
} from '#/lib/demo/puls-demo-data'
import { fromSupabaseError } from '#/lib/data/errors'
import { pulsCalc, pulsWorkflow, resolveTenantContext } from '#/lib/data/client'
import { resolveAdapterData } from '#/lib/data/result'

export type ContractsOverview = DemoContractsOverview

const CONTRACT_TYPE_KEYS: Record<string, string> = {
  indefinite: 'contractsSetup.types.indefinite',
  fixed_term: 'contractsSetup.types.fixedTerm',
  probation: 'contractsSetup.types.probation',
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

function mapSignatureStatus(status: string | null | undefined): DemoContractSignedStatus {
  return status === 'awaiting' ? 'pending' : 'signed'
}

function mapRiskStatus(
  riskBand: string | null | undefined,
  signatureStatus: string | null | undefined,
  endDate: string | null | undefined,
): DemoContractRiskStatus {
  if (signatureStatus === 'awaiting') return 'pending'
  if (endDate) {
    const threshold = new Date()
    threshold.setDate(threshold.getDate() + 60)
    if (new Date(`${endDate}T12:00:00`) <= threshold) return 'expiring'
  }
  if (riskBand === 'medium' || riskBand === 'high') return 'expiring'
  return 'ok'
}

function emptyContractsOverview(): ContractsOverview {
  return {
    activeContractCount: 0,
    expiringSoonCount: 0,
    pendingSignatureCount: 0,
    kvkkMissingCount: 0,
    contracts: [],
  }
}

async function fetchRealContractsOverview(userId: string): Promise<ContractsOverview> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) return emptyContractsOverview()

  const [summaryRow, contractsRow] = await Promise.all([
    pulsCalc()
      .from('dashboard_overview')
      .select('active_contract_count, expiring_contract_count')
      .eq('tenant_id', ctx.tenantId)
      .maybeSingle(),
    pulsWorkflow()
      .from('contracts')
      .select(
        `
        id,
        contract_type,
        start_date,
        end_date,
        signature_status,
        risk_band,
        employees ( full_name )
      `,
      )
      .eq('tenant_id', ctx.tenantId)
      .eq('status', 'active')
      .order('start_date', { ascending: false })
      .limit(50),
  ])

  if (summaryRow.error) {
    throw fromSupabaseError(
      summaryRow.error,
      'fetchContractsOverview',
      'puls_calc',
      'dashboard_overview',
    )
  }
  if (contractsRow.error) {
    throw fromSupabaseError(contractsRow.error, 'fetchContractsOverview', 'puls_workflow', 'contracts')
  }

  const contracts: DemoContractItem[] = (contractsRow.data ?? []).map((row) => {
    const employee = row.employees as { full_name?: string } | null
    const employeeName = employee?.full_name ?? '—'
    const contractType = row.contract_type as string
    const signatureStatus = row.signature_status as string | null
    const endDate = (row.end_date as string | null) ?? null

    return {
      id: row.id as string,
      employeeName,
      initials: getInitials(employeeName),
      typeKey: CONTRACT_TYPE_KEYS[contractType] ?? contractType,
      startDate: row.start_date as string,
      endDate,
      signed: mapSignatureStatus(signatureStatus),
      risk: mapRiskStatus(row.risk_band as string | null, signatureStatus, endDate),
    }
  })

  const pendingSignatureCount = contracts.filter((row) => row.signed === 'pending').length

  return {
    activeContractCount: Number(summaryRow.data?.active_contract_count ?? contracts.length),
    expiringSoonCount: Number(summaryRow.data?.expiring_contract_count ?? 0),
    pendingSignatureCount,
    kvkkMissingCount: 0,
    contracts,
  }
}

export async function fetchContractsOverview(userId: string): Promise<ContractsOverview> {
  return resolveAdapterData({
    operation: 'fetchContractsOverview',
    fetchReal: () => fetchRealContractsOverview(userId),
    fetchDemo: fetchDemoContractsOverview,
    isEmpty: (data) => data.contracts.length === 0,
  })
}
