import { fetchDemoCompanySetup } from '#/lib/demo/puls-demo-data'
import type { DemoCompanySetup } from '#/lib/demo/puls-demo-data'
import { DataAdapterError, fromSupabaseError, parseRpcErrorCode } from '#/lib/data/errors'
import { pulsCalc, pulsCore, pulsIntegration, pulsPerformance, resolveTenantContext } from '#/lib/data/client'
import { resolveAdapterData, resolveAdapterDataWithMeta } from '#/lib/data/result'

export type CompanySetupOverview = DemoCompanySetup

export const COMPANY_PROFILE_NAME_MAX_LENGTH = 120
export const COMPANY_PROFILE_INDUSTRY_MAX_LENGTH = 80

export const COMPANY_PROFILE_LOCALE_OPTIONS = [
  { value: 'tr-TR', labelKey: 'companySetup.edit.options.locale.tr' },
  { value: 'en-US', labelKey: 'companySetup.edit.options.locale.en' },
] as const

export const COMPANY_PROFILE_TIMEZONE_OPTIONS = [
  { value: 'Europe/Istanbul', labelKey: 'companySetup.edit.options.timezone.istanbul' },
  { value: 'Europe/Berlin', labelKey: 'companySetup.edit.options.timezone.berlin' },
  { value: 'Europe/London', labelKey: 'companySetup.edit.options.timezone.london' },
  { value: 'Asia/Dubai', labelKey: 'companySetup.edit.options.timezone.dubai' },
  { value: 'America/New_York', labelKey: 'companySetup.edit.options.timezone.newYork' },
  { value: 'UTC', labelKey: 'companySetup.edit.options.timezone.utc' },
] as const

export type CompanyProfileMutationInput = {
  displayName: string
  industry: string | null
  locale: string
  timezone: string
}

export type CompanyProfileUpdateResult = {
  status: 'updated' | 'unchanged'
  tenantId: string
  displayName: string
  industry: string | null
  locale: string
  timezone: string
  changedFields: string[]
}

export type CompanyProfileMutationErrorMapping = {
  code: string
  toastKey: string
}

const COMPANY_PROFILE_ERROR_I18N: Record<string, string> = {
  PULS_COMPANY_PROFILE_FORBIDDEN: 'companySetup.edit.errors.forbidden',
  PULS_COMPANY_PROFILE_NOT_FOUND: 'companySetup.edit.errors.notFound',
  PULS_COMPANY_PROFILE_INVALID_NAME: 'companySetup.edit.errors.invalidName',
  PULS_COMPANY_PROFILE_INVALID_INDUSTRY: 'companySetup.edit.errors.invalidIndustry',
  PULS_COMPANY_PROFILE_INVALID_LOCALE: 'companySetup.edit.errors.invalidLocale',
  PULS_COMPANY_PROFILE_INVALID_TIMEZONE: 'companySetup.edit.errors.invalidTimezone',
}

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

export function normalizeCompanyProfileInput(
  input: CompanyProfileMutationInput,
): CompanyProfileMutationInput {
  return {
    displayName: input.displayName.trim(),
    industry: input.industry?.trim() ? input.industry.trim() : null,
    locale: input.locale.trim(),
    timezone: input.timezone.trim(),
  }
}

export function isCompanyProfileFormDirty(
  baseline: CompanyProfileMutationInput,
  form: CompanyProfileMutationInput,
): boolean {
  const normalizedBaseline = normalizeCompanyProfileInput(baseline)
  const normalizedForm = normalizeCompanyProfileInput(form)

  return (
    normalizedBaseline.displayName !== normalizedForm.displayName ||
    normalizedBaseline.industry !== normalizedForm.industry ||
    normalizedBaseline.locale !== normalizedForm.locale ||
    normalizedBaseline.timezone !== normalizedForm.timezone
  )
}

function parseCompanyProfileUpdateResult(data: unknown): CompanyProfileUpdateResult {
  const row = (data ?? {}) as Record<string, unknown>
  const status = row.status === 'unchanged' ? 'unchanged' : 'updated'

  return {
    status,
    tenantId: String(row.tenant_id ?? ''),
    displayName: String(row.trade_name ?? ''),
    industry: typeof row.industry === 'string' ? row.industry : null,
    locale: String(row.locale ?? 'tr-TR'),
    timezone: String(row.timezone ?? 'Europe/Istanbul'),
    changedFields: Array.isArray(row.changed_fields)
      ? row.changed_fields.filter((field): field is string => typeof field === 'string')
      : [],
  }
}

export async function updateCompanyProfile(
  userId: string,
  input: CompanyProfileMutationInput,
): Promise<CompanyProfileUpdateResult> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    throw new DataAdapterError({
      code: 'PULS_COMPANY_PROFILE_FORBIDDEN',
      message: 'Tenant context is required.',
      source: 'adapter',
      operation: 'updateCompanyProfile',
      schema: 'puls_core',
      table: 'tenants',
      i18nKey: 'companySetup.edit.errors.forbidden',
    })
  }

  const normalized = normalizeCompanyProfileInput(input)
  const { data, error } = await pulsCore().rpc('update_company_profile', {
    p_trade_name: normalized.displayName,
    p_industry: normalized.industry,
    p_locale: normalized.locale,
    p_timezone: normalized.timezone,
  })

  if (error) {
    const code = parseRpcErrorCode(error.message) ?? error.code ?? 'rpc_error'
    throw new DataAdapterError({
      code,
      message: error.message,
      source: 'rpc',
      operation: 'updateCompanyProfile',
      schema: 'puls_core',
      table: 'tenants',
      i18nKey: COMPANY_PROFILE_ERROR_I18N[code] ?? 'companySetup.edit.errors.saveFailed',
    })
  }

  return parseCompanyProfileUpdateResult(data)
}

export function mapCompanyProfileMutationError(error: unknown): CompanyProfileMutationErrorMapping {
  const code =
    error instanceof DataAdapterError
      ? error.code
      : error instanceof Error
        ? (parseRpcErrorCode(error.message) ?? 'unknown')
        : 'unknown'

  const toastKey =
    error instanceof DataAdapterError && error.i18nKey
      ? error.i18nKey
      : COMPANY_PROFILE_ERROR_I18N[code] ?? 'companySetup.edit.errors.saveFailed'

  return { code, toastKey }
}
