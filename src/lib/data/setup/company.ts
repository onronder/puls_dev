import { fetchDemoCompanySetup } from '#/lib/demo/puls-demo-data'
import type { DemoCompanySetup } from '#/lib/demo/puls-demo-data'
import { fromSupabaseError } from '#/lib/data/errors'
import { pulsCalc, pulsCore, pulsIntegration, pulsPerformance, resolveTenantContext } from '#/lib/data/client'
import { resolveAdapterData, resolveAdapterDataWithMeta } from '#/lib/data/result'

export type CompanySetupOverview = DemoCompanySetup

function employeeBand(count: number): string {
  if (count <= 50) return '1-50 çalışan'
  if (count <= 250) return '51-250 çalışan'
  return '250+ çalışan'
}

function emptyCompanySetupOverview(): CompanySetupOverview {
  return {
    name: '—',
    vkn: '—',
    sector: '—',
    band: '—',
    language: 'tr-TR',
    timezone: 'Europe/Istanbul',
    package: '—',
    completion: 0,
    missing: 4,
    erpReadiness: '0 / 0',
    checklist: [
      { id: 'ck1', labelKey: 'companySetup.checklist.tenant', status: 'pending' },
      { id: 'ck2', labelKey: 'companySetup.checklist.employees', status: 'pending' },
      { id: 'ck3', labelKey: 'companySetup.checklist.erpMapping', status: 'pending' },
      { id: 'ck4', labelKey: 'companySetup.checklist.performanceCycle', status: 'pending' },
    ],
  }
}

function isCompanySetupEmpty(data: CompanySetupOverview): boolean {
  return data.name === '—' && data.completion === 0
}

async function fetchRealCompanySetupOverview(userId: string): Promise<CompanySetupOverview> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) return emptyCompanySetupOverview()

  const [tenantRow, readinessRow, employeeCount, mappedCount, mappingTotal, hasCycle] =
    await Promise.all([
      pulsCore()
        .from('tenants')
        .select('name, trade_name, legal_name, tax_no, industry, locale, timezone, plan_name')
        .eq('id', ctx.tenantId)
        .maybeSingle(),
      pulsCalc()
        .from('setup_readiness_summary')
        .select('core_setup_pct, integration_setup_pct, performance_setup_pct, overall_readiness_pct')
        .eq('tenant_id', ctx.tenantId)
        .maybeSingle(),
      pulsCore()
        .from('employees')
        .select('id', { count: 'exact', head: true })
        .eq('tenant_id', ctx.tenantId)
        .eq('employment_status', 'active'),
      pulsIntegration()
        .from('erp_field_mappings')
        .select('id', { count: 'exact', head: true })
        .eq('tenant_id', ctx.tenantId)
        .eq('is_active', true),
      pulsIntegration()
        .from('erp_field_mappings')
        .select('id', { count: 'exact', head: true })
        .eq('tenant_id', ctx.tenantId),
      pulsPerformance()
        .from('performance_cycles')
        .select('id', { count: 'exact', head: true })
        .eq('tenant_id', ctx.tenantId),
    ])

  if (tenantRow.error) {
    throw fromSupabaseError(tenantRow.error, 'fetchCompanySetupOverview', 'puls_core', 'tenants')
  }
  if (readinessRow.error) {
    throw fromSupabaseError(
      readinessRow.error,
      'fetchCompanySetupOverview',
      'puls_calc',
      'setup_readiness_summary',
    )
  }
  if (employeeCount.error) {
    throw fromSupabaseError(employeeCount.error, 'fetchCompanySetupOverview', 'puls_core', 'employees')
  }
  if (mappedCount.error || mappingTotal.error) {
    throw fromSupabaseError(
      mappedCount.error ?? mappingTotal.error!,
      'fetchCompanySetupOverview',
      'puls_integration',
      'erp_field_mappings',
    )
  }
  if (hasCycle.error) {
    throw fromSupabaseError(
      hasCycle.error,
      'fetchCompanySetupOverview',
      'puls_performance',
      'performance_cycles',
    )
  }

  const tenant = tenantRow.data
  const activeEmployees = employeeCount.count ?? 0
  const mappedFields = mappedCount.count ?? 0
  const totalFields = mappingTotal.count ?? 0
  const completion = Number(readinessRow.data?.overall_readiness_pct ?? 0)
  const hasEmployees = activeEmployees > 0
  const hasErpMapping = mappedFields > 0
  const hasPerformanceCycle = (hasCycle.count ?? 0) > 0

  const checklist: CompanySetupOverview['checklist'] = [
    {
      id: 'ck1',
      labelKey: 'companySetup.checklist.tenant',
      status: tenant ? 'done' : 'pending',
    },
    {
      id: 'ck2',
      labelKey: 'companySetup.checklist.employees',
      status: hasEmployees ? 'done' : 'pending',
    },
    {
      id: 'ck3',
      labelKey: 'companySetup.checklist.erpMapping',
      status: hasErpMapping ? 'done' : 'pending',
    },
    {
      id: 'ck4',
      labelKey: 'companySetup.checklist.performanceCycle',
      status: hasPerformanceCycle ? 'done' : 'pending',
    },
  ]

  const missing = checklist.filter((item) => item.status === 'pending').length

  return {
    name: tenant?.trade_name ?? tenant?.name ?? tenant?.legal_name ?? '—',
    vkn: tenant?.tax_no ? String(tenant.tax_no) : '—',
    sector: (tenant?.industry as string | null) ?? '—',
    band: employeeBand(activeEmployees),
    language: (tenant?.locale as string | null) ?? 'tr-TR',
    timezone: (tenant?.timezone as string | null) ?? 'Europe/Istanbul',
    package: (tenant?.plan_name as string | null) ?? '—',
    completion,
    missing,
    erpReadiness: `${mappedFields} / ${totalFields}`,
    checklist,
  }
}

export async function fetchCompanySetupOverview(userId: string): Promise<CompanySetupOverview> {
  return resolveAdapterData({
    operation: 'fetchCompanySetupOverview',
    fetchReal: () => fetchRealCompanySetupOverview(userId),
    fetchDemo: fetchDemoCompanySetup,
    isEmpty: isCompanySetupEmpty,
  })
}

export function fetchCompanySetupOverviewWithMeta(userId: string) {
  return resolveAdapterDataWithMeta({
    operation: 'fetchCompanySetupOverview',
    fetchReal: () => fetchRealCompanySetupOverview(userId),
    fetchDemo: fetchDemoCompanySetup,
    isEmpty: isCompanySetupEmpty,
  })
}
