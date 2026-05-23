import { fetchDemoErpOverview } from '#/lib/demo/puls-demo-data'
import type { DemoErpOverview, DemoErpSyncLevel } from '#/lib/demo/puls-demo-data'
import { fromSupabaseError } from '#/lib/data/errors'
import { pulsCalc, pulsIntegration, resolveTenantContext } from '#/lib/data/client'
import { resolveAdapterData } from '#/lib/data/result'

export type ErpOverview = DemoErpOverview

function emptyErpOverview(): ErpOverview {
  return {
    status: {
      system: 'Canias',
      status: 'beklemede',
      statusLabel: '—',
      mappedFields: 0,
      totalFields: 0,
      lastAttempt: '—',
      readiness: 0,
    },
    mappings: [],
    syncLogs: [],
  }
}

function isErpOverviewEmpty(data: ErpOverview): boolean {
  return data.mappings.length === 0 && data.syncLogs.length === 0 && data.status.mappedFields === 0
}

function formatSyncTimestamp(iso: string | null | undefined, locale = 'tr-TR'): string {
  if (!iso) return '—'
  try {
    return new Intl.DateTimeFormat(locale, {
      day: 'numeric',
      month: 'short',
      hour: '2-digit',
      minute: '2-digit',
    }).format(new Date(iso))
  } catch {
    return '—'
  }
}

function mapSyncLevel(status: string | null | undefined): DemoErpSyncLevel {
  switch (status) {
    case 'success':
      return 'success'
    case 'failed':
    case 'partial':
      return 'warning'
    default:
      return 'info'
  }
}

function mapProviderLabel(provider: string | null | undefined): DemoErpOverview['status']['system'] {
  if (provider === 'canias') return 'Canias'
  return 'Canias'
}

async function fetchRealErpOverview(userId: string): Promise<ErpOverview> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) return emptyErpOverview()

  const [connectionRow, mappingsRow, batchesRow, readinessRow] = await Promise.all([
    pulsIntegration()
      .from('erp_connections')
      .select('provider, display_name, is_active, last_sync_at, last_status')
      .eq('tenant_id', ctx.tenantId)
      .order('updated_at', { ascending: false })
      .limit(1)
      .maybeSingle(),
    pulsIntegration()
      .from('erp_field_mappings')
      .select('source_field, target_field, is_active, is_sensitive')
      .eq('tenant_id', ctx.tenantId)
      .eq('is_sensitive', false)
      .order('source_field', { ascending: true }),
    pulsIntegration()
      .from('erp_sync_batches')
      .select('id, created_at, status, error_summary, sync_type')
      .eq('tenant_id', ctx.tenantId)
      .order('created_at', { ascending: false })
      .limit(4),
    pulsCalc()
      .from('setup_readiness_summary')
      .select('integration_setup_pct')
      .eq('tenant_id', ctx.tenantId)
      .maybeSingle(),
  ])

  if (connectionRow.error) {
    throw fromSupabaseError(connectionRow.error, 'fetchErpOverview', 'puls_integration', 'erp_connections')
  }
  if (mappingsRow.error) {
    throw fromSupabaseError(
      mappingsRow.error,
      'fetchErpOverview',
      'puls_integration',
      'erp_field_mappings',
    )
  }
  if (batchesRow.error) {
    throw fromSupabaseError(
      batchesRow.error,
      'fetchErpOverview',
      'puls_integration',
      'erp_sync_batches',
    )
  }
  if (readinessRow.error) {
    throw fromSupabaseError(
      readinessRow.error,
      'fetchErpOverview',
      'puls_calc',
      'setup_readiness_summary',
    )
  }

  const mappings = (mappingsRow.data ?? []).map((row) => ({
    puls: (row.target_field as string) ?? '—',
    erp: (row.source_field as string) ?? '—',
    status: row.is_active ? ('mapped' as const) : ('pending' as const),
  }))

  const mappedFields = mappings.filter((row) => row.status === 'mapped').length
  const totalFields = mappings.length
  const readiness = Number(readinessRow.data?.integration_setup_pct ?? 0)
  const connection = connectionRow.data

  return {
    status: {
      system: mapProviderLabel(connection?.provider as string | null),
      status: 'beklemede',
      statusLabel: connection?.is_active ? 'Bağlı' : 'API erişimi bekleniyor',
      mappedFields,
      totalFields: totalFields || mappedFields,
      lastAttempt: formatSyncTimestamp(connection?.last_sync_at as string | null),
      readiness,
    },
    mappings,
    syncLogs: (batchesRow.data ?? []).map((row) => ({
      id: row.id as string,
      at: formatSyncTimestamp(row.created_at as string),
      level: mapSyncLevel(row.status as string | null),
      message:
        (row.error_summary as string | null) ??
        `${row.sync_type as string} · ${row.status as string}`,
    })),
  }
}

export async function fetchErpOverview(userId: string): Promise<ErpOverview> {
  return resolveAdapterData({
    operation: 'fetchErpOverview',
    fetchReal: () => fetchRealErpOverview(userId),
    fetchDemo: fetchDemoErpOverview,
    isEmpty: isErpOverviewEmpty,
  })
}
