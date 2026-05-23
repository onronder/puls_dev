import { fetchDemoPerformanceParametersOverview } from '#/lib/demo/puls-demo-data'
import type {
  DemoPerformanceParametersOverview,
  DemoPerformanceScoreBandTone,
} from '#/lib/demo/puls-demo-data'
import { fromSupabaseError } from '#/lib/data/errors'
import { pulsPerformance, resolveTenantContext } from '#/lib/data/client'
import { mapPerformanceStatusBandTone } from '#/lib/data/mappers'
import { resolveAdapterData } from '#/lib/data/result'
import type { StatusTone } from '#/components/puls/StatusPill'

export type PerformanceParametersOverview = DemoPerformanceParametersOverview

const KPI_NAME_KEYS: Record<string, string> = {
  operational: 'performanceParamsSetup.kpi.operational',
  customer: 'performanceParamsSetup.kpi.customer',
  financial: 'performanceParamsSetup.kpi.financial',
  development: 'performanceParamsSetup.kpi.development',
}

const SCORE_BAND_LABEL_KEYS: Record<string, string> = {
  very_good: 'performanceParamsSetup.scoreBands.excellent',
  good: 'performanceParamsSetup.scoreBands.good',
  expected: 'performanceParamsSetup.scoreBands.expected',
  development: 'performanceParamsSetup.scoreBands.development',
  risk: 'performanceParamsSetup.scoreBands.risk',
}

function mapToneToDemoTone(tone: StatusTone): DemoPerformanceScoreBandTone {
  if (tone === 'success' || tone === 'info' || tone === 'neutral' || tone === 'warning' || tone === 'danger') {
    return tone
  }
  return 'neutral'
}

function emptyPerformanceParametersOverview(): PerformanceParametersOverview {
  return {
    competencyTemplateCount: 0,
    kpiCategoryCount: 0,
    scoreBandCount: 0,
    hasActiveCycle: false,
    competencyTemplates: [],
    kpiCategories: [],
    scoreBands: [],
  }
}

async function fetchRealPerformanceParametersOverview(
  userId: string,
): Promise<PerformanceParametersOverview> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) return emptyPerformanceParametersOverview()

  const [templatesRow, kpiRow, bandsRow, cyclesRow] = await Promise.all([
    pulsPerformance()
      .from('competency_templates')
      .select('id, name, updated_at')
      .eq('tenant_id', ctx.tenantId)
      .eq('is_active', true)
      .order('sort_order', { ascending: true }),
    pulsPerformance()
      .from('kpi_category_weights')
      .select('id, category_code, category_name, weight_pct')
      .eq('tenant_id', ctx.tenantId)
      .eq('is_active', true)
      .order('sort_order', { ascending: true }),
    pulsPerformance()
      .from('score_bands')
      .select('id, band, label, min_score, max_score')
      .eq('tenant_id', ctx.tenantId)
      .eq('is_active', true)
      .order('sort_order', { ascending: true }),
    pulsPerformance()
      .from('performance_cycles')
      .select('id, status')
      .eq('tenant_id', ctx.tenantId)
      .eq('status', 'active')
      .limit(1),
  ])

  if (templatesRow.error) {
    throw fromSupabaseError(
      templatesRow.error,
      'fetchPerformanceParametersOverview',
      'puls_performance',
      'competency_templates',
    )
  }
  if (kpiRow.error) {
    throw fromSupabaseError(
      kpiRow.error,
      'fetchPerformanceParametersOverview',
      'puls_performance',
      'kpi_category_weights',
    )
  }
  if (bandsRow.error) {
    throw fromSupabaseError(
      bandsRow.error,
      'fetchPerformanceParametersOverview',
      'puls_performance',
      'score_bands',
    )
  }
  if (cyclesRow.error) {
    throw fromSupabaseError(
      cyclesRow.error,
      'fetchPerformanceParametersOverview',
      'puls_performance',
      'performance_cycles',
    )
  }

  const competencyTemplates = (templatesRow.data ?? []).map((row) => ({
    id: row.id as string,
    nameKey: row.name as string,
    areas: 0,
    updatedAt: ((row.updated_at as string | null) ?? '').slice(0, 10) || '—',
  }))

  const kpiCategories = (kpiRow.data ?? []).map((row) => ({
    id: row.id as string,
    nameKey:
      KPI_NAME_KEYS[row.category_code as string] ??
      (row.category_name as string),
    weight: Number(row.weight_pct ?? 0),
  }))

  const scoreBands = (bandsRow.data ?? []).map((row) => ({
    id: row.id as string,
    labelKey: SCORE_BAND_LABEL_KEYS[row.band as string] ?? (row.label as string),
    min: Number(row.min_score ?? 0),
    max: Number(row.max_score ?? 0),
    tone: mapToneToDemoTone(mapPerformanceStatusBandTone(row.band as string)),
  }))

  return {
    competencyTemplateCount: competencyTemplates.length,
    kpiCategoryCount: kpiCategories.length,
    scoreBandCount: scoreBands.length,
    hasActiveCycle: (cyclesRow.data ?? []).length > 0,
    competencyTemplates,
    kpiCategories,
    scoreBands,
  }
}

export async function fetchPerformanceParametersOverview(
  userId: string,
): Promise<PerformanceParametersOverview> {
  return resolveAdapterData({
    operation: 'fetchPerformanceParametersOverview',
    fetchReal: () => fetchRealPerformanceParametersOverview(userId),
    fetchDemo: fetchDemoPerformanceParametersOverview,
    isEmpty: (data) =>
      data.competencyTemplates.length === 0 &&
      data.kpiCategories.length === 0 &&
      data.scoreBands.length === 0,
  })
}
