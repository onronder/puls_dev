import { fetchDemoContractsOverview } from '#/lib/demo/puls-demo-data'
import type {
  DemoContractsOverview,
  DemoContractItem,
  DemoContractRiskStatus,
  DemoContractSignedStatus,
} from '#/lib/demo/puls-demo-data'
import { fromSupabaseError } from '#/lib/data/errors'
import { pulsCalc, pulsCore, pulsWorkflow, resolveTenantContext } from '#/lib/data/client'
import { resolveAdapterData, resolveAdapterDataWithMeta } from '#/lib/data/result'

export type ContractEvidenceSummary = {
  fileCount: number
  latestFileName: string | null
  latestFileSizeBytes: number | null
}

export type ContractItem = DemoContractItem & ContractEvidenceSummary

export type ContractsOverviewWithEvidence = Omit<DemoContractsOverview, 'contracts'> & {
  contracts: ContractItem[]
}

export type ContractsOverview = ContractsOverviewWithEvidence

const CONTRACT_TYPE_KEYS: Record<string, string> = {
  employment: 'contractsSetup.types.indefinite',
  indefinite: 'contractsSetup.types.indefinite',
  fixed_term: 'contractsSetup.types.fixedTerm',
  probation: 'contractsSetup.types.probation',
}

export type ContractRowInput = {
  id: string
  employee_id?: string | null
  contract_type: string
  start_date: string
  end_date?: string | null
  signature_status?: string | null
  risk_band?: string | null
  employeeName?: string | null
  employees?: { full_name?: string } | null
}

type ContractFileRow = {
  contract_id: string
  file_name?: string | null
  file_size_bytes?: number | null
  created_at?: string | null
}

export type MapContractRowOptions = {
  now?: Date
}

export function getContractInitials(name: string): string {
  return name
    .split(' ')
    .filter(Boolean)
    .map((part) => part[0])
    .join('')
    .slice(0, 2)
    .toUpperCase()
}

export function mapContractSignatureStatus(
  status: string | null | undefined,
): DemoContractSignedStatus {
  return status === 'awaiting' ? 'pending' : 'signed'
}

export type MapContractRiskStatusInput = {
  riskBand?: string | null
  signatureStatus?: string | null
  endDate?: string | null
  now?: Date
}

export function mapContractRiskStatus({
  riskBand,
  signatureStatus,
  endDate,
  now = new Date(),
}: MapContractRiskStatusInput): DemoContractRiskStatus {
  if (signatureStatus === 'awaiting') return 'pending'
  if (endDate) {
    const threshold = new Date(now)
    threshold.setDate(threshold.getDate() + 60)
    if (new Date(`${endDate}T12:00:00`) <= threshold) return 'expiring'
  }
  if (riskBand === 'medium' || riskBand === 'high') return 'expiring'
  return 'ok'
}

export function mapContractRow(
  row: ContractRowInput,
  options?: MapContractRowOptions & { evidence?: ContractEvidenceSummary },
): ContractItem {
  const employeeName = row.employeeName ?? row.employees?.full_name ?? '—'
  const contractType = row.contract_type
  const signatureStatus = row.signature_status ?? null
  const endDate = row.end_date ?? null
  const evidence = options?.evidence ?? {
    fileCount: 0,
    latestFileName: null,
    latestFileSizeBytes: null,
  }

  return {
    id: row.id,
    employeeName,
    initials: getContractInitials(employeeName),
    typeKey: CONTRACT_TYPE_KEYS[contractType] ?? contractType,
    startDate: row.start_date,
    endDate,
    signed: mapContractSignatureStatus(signatureStatus),
    risk: mapContractRiskStatus({
      riskBand: row.risk_band ?? null,
      signatureStatus,
      endDate,
      now: options?.now,
    }),
    ...evidence,
  }
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
        employee_id,
        contract_type,
        start_date,
        end_date,
        signature_status,
        risk_band
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
    throw fromSupabaseError(
      contractsRow.error,
      'fetchContractsOverview',
      'puls_workflow',
      'contracts',
    )
  }

  const contractRows = (contractsRow.data ?? []) as ContractRowInput[]
  const contractIds = contractRows.map((row) => row.id)
  const employeeIds = [
    ...new Set(contractRows.map((row) => row.employee_id).filter(Boolean) as string[]),
  ]
  let employeeNameMap = new Map<string, string>()

  if (employeeIds.length > 0) {
    const { data: employeeRows, error: employeesError } = await pulsCore()
      .from('employees')
      .select('id, full_name')
      .eq('tenant_id', ctx.tenantId)
      .in('id', employeeIds)

    if (employeesError) {
      throw fromSupabaseError(employeesError, 'fetchContractsOverview', 'puls_core', 'employees')
    }

    employeeNameMap = new Map(
      (employeeRows ?? []).map((row) => [
        row.id as string,
        (row.full_name as string | null) ?? '—',
      ]),
    )
  }

  let evidenceMap = new Map<string, ContractEvidenceSummary>()
  if (contractIds.length > 0) {
    const { data: fileRows, error: fileError } = await pulsWorkflow()
      .from('contract_files')
      .select('contract_id, file_name, file_size_bytes, created_at')
      .eq('tenant_id', ctx.tenantId)
      .order('created_at', { ascending: false })
      .in('contract_id', contractIds)

    if (fileError) {
      throw fromSupabaseError(
        fileError,
        'fetchContractsOverview',
        'puls_workflow',
        'contract_files',
      )
    }

    evidenceMap = new Map()
    for (const row of (fileRows ?? []) as ContractFileRow[]) {
      const existing = evidenceMap.get(row.contract_id) ?? {
        fileCount: 0,
        latestFileName: null,
        latestFileSizeBytes: null,
      }
      evidenceMap.set(row.contract_id, {
        fileCount: existing.fileCount + 1,
        latestFileName: existing.latestFileName ?? row.file_name ?? null,
        latestFileSizeBytes:
          existing.latestFileSizeBytes ??
          (row.file_size_bytes === null || row.file_size_bytes === undefined
            ? null
            : Number(row.file_size_bytes)),
      })
    }
  }

  const contracts = contractRows.map((row) =>
    mapContractRow(
      {
        ...row,
        employeeName: row.employee_id ? employeeNameMap.get(row.employee_id) : null,
      },
      {
        evidence: evidenceMap.get(row.id),
      },
    ),
  )

  const pendingSignatureCount = contracts.filter((row) => row.signed === 'pending').length

  return {
    activeContractCount: Number(summaryRow.data?.active_contract_count ?? contracts.length),
    expiringSoonCount: Number(summaryRow.data?.expiring_contract_count ?? 0),
    pendingSignatureCount,
    kvkkMissingCount: 0,
    contracts,
  }
}

export function fetchContractsOverviewWithMeta(userId: string) {
  return resolveAdapterDataWithMeta({
    operation: 'fetchContractsOverview',
    fetchReal: () => fetchRealContractsOverview(userId),
    fetchDemo: async () => {
      const demo = await fetchDemoContractsOverview()
      return {
        ...demo,
        contracts: demo.contracts.map((contract) => ({
          ...contract,
          fileCount: 0,
          latestFileName: null,
          latestFileSizeBytes: null,
        })),
      }
    },
    isEmpty: (data) => data.contracts.length === 0,
  })
}

export async function fetchContractsOverview(userId: string): Promise<ContractsOverview> {
  return resolveAdapterData({
    operation: 'fetchContractsOverview',
    fetchReal: () => fetchRealContractsOverview(userId),
    fetchDemo: async () => {
      const demo = await fetchDemoContractsOverview()
      return {
        ...demo,
        contracts: demo.contracts.map((contract) => ({
          ...contract,
          fileCount: 0,
          latestFileName: null,
          latestFileSizeBytes: null,
        })),
      }
    },
    isEmpty: (data) => data.contracts.length === 0,
  })
}
