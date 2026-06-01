import { fetchDemoErpOverview } from '#/lib/demo/puls-demo-data'
import { pulsCalc, pulsIntegration, resolveTenantContext } from '#/lib/data/client'
import { resolveAdapterData, resolveAdapterDataWithMeta } from '#/lib/data/result'

export type ConnectorReadinessStatus = 'ready' | 'partial' | 'blocked'
export type ConnectorMappingStatus = 'mapped' | 'pending'
export type ConnectorLifecycleState = 'no_tenant' | 'no_connector' | 'connector_selected'
export type ConnectorProviderStatus =
  | 'not_configured'
  | 'metadata_only'
  | 'runtime_inactive'
  | 'runtime_active'
export type ConnectorSyncLogLevel = 'success' | 'warning' | 'info'
export type ConnectorSetupStepId = 'source' | 'mapping' | 'namespace' | 'preflight' | 'runtime'

export type ConnectorSetupStep = {
  id: ConnectorSetupStepId
  labelKey: string
  descriptionKey: string
  status: ConnectorReadinessStatus
}

export type ConnectorProviderRequirement = {
  id:
    | 'source_profile'
    | 'canonical_mapping'
    | 'source_namespace'
    | 'identity_strategy'
    | 'transfer_mode'
    | 'runtime_boundary'
  labelKey: string
  descriptionKey: string
  status: ConnectorReadinessStatus
}

export type ConnectorReadinessCheck = {
  id:
    | 'provider_metadata'
    | 'runtime_boundary'
    | 'field_mapping'
    | 'source_namespace'
    | 'identity_reconciliation'
    | 'setup_readiness'
    | 'write_guardrail'
  labelKey: string
  status: ConnectorReadinessStatus
  value: string | number | boolean
}

export type ConnectorFieldMapping = {
  canonicalField: string
  sourceField: string
  sourceEntity: string
  status: ConnectorMappingStatus
  required: boolean
}

export type ConnectorNamespaceSummary = {
  id: string
  code: string
  name: string
  sourceType: string
  identityCount: number
}

export type ConnectorTransferMode = {
  id: 'manual_csv' | 'scheduled_file_exchange' | 'excel_xml' | 'staging_table' | 'api_future'
  labelKey: string
  status: ConnectorReadinessStatus
}

export type ConnectorGuardrail = {
  id:
    | 'canonical_mapping_required'
    | 'identity_reconciliation_required'
    | 'human_confirmation_required'
    | 'no_runtime_sync'
    | 'no_erp_writes'
    | 'no_credentials_in_repo'
  labelKey: string
  enforced: boolean
}

export type ConnectorSyncLog = {
  id: string
  at: string
  level: ConnectorSyncLogLevel
  message: string
}

export type ConnectorProviderOption = {
  id: 'canias' | 'logo' | 'csv_import' | 'custom_api'
  labelKey: string
  descriptionKey: string
  readinessLabelKey: string
  status: ConnectorReadinessStatus
  requirements: ConnectorProviderRequirement[]
}

export type ErpOverview = {
  connectorState: ConnectorLifecycleState
  provider: {
    code: string | null
    label: string
    displayName: string | null
    status: ConnectorProviderStatus
    statusLabelKey: string
    isActive: boolean
    lastAttempt: string
  }
  readiness: {
    score: number
    status: ConnectorReadinessStatus
    checks: ConnectorReadinessCheck[]
  }
  setupSteps: ConnectorSetupStep[]
  mappings: ConnectorFieldMapping[]
  namespaces: ConnectorNamespaceSummary[]
  transferModes: ConnectorTransferMode[]
  guardrails: ConnectorGuardrail[]
  providerOptions: ConnectorProviderOption[]
  syncLogs: ConnectorSyncLog[]
  status: {
    system: string
    status: 'beklemede'
    statusLabel: string
    mappedFields: number
    totalFields: number
    lastAttempt: string
    readiness: number
  }
}

type ErpConnectionRow = {
  provider?: string | null
  display_name?: string | null
  is_active?: boolean | null
  last_sync_at?: string | null
  last_status?: string | null
}

type ErpFieldMappingRow = {
  source_entity?: string | null
  source_field?: string | null
  target_schema?: string | null
  target_table?: string | null
  target_field?: string | null
  is_required?: boolean | null
  is_sensitive?: boolean | null
  is_active?: boolean | null
}

type ErpSyncBatchRow = {
  id?: string | null
  created_at?: string | null
  status?: string | null
  error_summary?: string | null
  sync_type?: string | null
}

type SourceNamespaceRow = {
  id?: string | null
  code?: string | null
  name?: string | null
  source_type?: string | null
}

type EntityIdentityRow = {
  source_namespace_id?: string | null
  canonical_table?: string | null
}

type SetupReadinessRow = {
  integration_setup_pct?: number | null
}

const PROVIDER_LABELS: Record<string, string> = {
  canias: 'Canias',
  logo: 'Logo',
  netsis: 'Netsis',
  sap: 'SAP',
}

const FALLBACK_PROVIDER_LABEL = 'External data source'

const CONNECTOR_PROVIDER_OPTIONS: ConnectorProviderOption[] = [
  {
    id: 'canias',
    labelKey: 'erp.providerOptions.canias.label',
    descriptionKey: 'erp.providerOptions.canias.description',
    readinessLabelKey: 'erp.providerOptions.canias.readiness',
    status: 'ready',
    requirements: [
      {
        id: 'source_profile',
        labelKey: 'erp.providerRequirements.sourceProfile.label',
        descriptionKey: 'erp.providerRequirements.sourceProfile.description',
        status: 'ready',
      },
      {
        id: 'canonical_mapping',
        labelKey: 'erp.providerRequirements.canonicalMapping.label',
        descriptionKey: 'erp.providerRequirements.canonicalMapping.description',
        status: 'ready',
      },
      {
        id: 'identity_strategy',
        labelKey: 'erp.providerRequirements.identityStrategy.label',
        descriptionKey: 'erp.providerRequirements.identityStrategy.description',
        status: 'ready',
      },
      {
        id: 'runtime_boundary',
        labelKey: 'erp.providerRequirements.runtimeBoundary.label',
        descriptionKey: 'erp.providerRequirements.runtimeBoundary.description',
        status: 'blocked',
      },
    ],
  },
  {
    id: 'logo',
    labelKey: 'erp.providerOptions.logo.label',
    descriptionKey: 'erp.providerOptions.logo.description',
    readinessLabelKey: 'erp.providerOptions.logo.readiness',
    status: 'partial',
    requirements: [
      {
        id: 'source_profile',
        labelKey: 'erp.providerRequirements.sourceProfile.label',
        descriptionKey: 'erp.providerRequirements.sourceProfile.description',
        status: 'partial',
      },
      {
        id: 'canonical_mapping',
        labelKey: 'erp.providerRequirements.canonicalMapping.label',
        descriptionKey: 'erp.providerRequirements.canonicalMapping.description',
        status: 'partial',
      },
      {
        id: 'source_namespace',
        labelKey: 'erp.providerRequirements.sourceNamespace.label',
        descriptionKey: 'erp.providerRequirements.sourceNamespace.description',
        status: 'partial',
      },
      {
        id: 'runtime_boundary',
        labelKey: 'erp.providerRequirements.runtimeBoundary.label',
        descriptionKey: 'erp.providerRequirements.runtimeBoundary.description',
        status: 'blocked',
      },
    ],
  },
  {
    id: 'csv_import',
    labelKey: 'erp.providerOptions.csv_import.label',
    descriptionKey: 'erp.providerOptions.csv_import.description',
    readinessLabelKey: 'erp.providerOptions.csv_import.readiness',
    status: 'ready',
    requirements: [
      {
        id: 'transfer_mode',
        labelKey: 'erp.providerRequirements.transferMode.label',
        descriptionKey: 'erp.providerRequirements.transferMode.description',
        status: 'ready',
      },
      {
        id: 'canonical_mapping',
        labelKey: 'erp.providerRequirements.canonicalMapping.label',
        descriptionKey: 'erp.providerRequirements.canonicalMapping.description',
        status: 'partial',
      },
      {
        id: 'source_namespace',
        labelKey: 'erp.providerRequirements.sourceNamespace.label',
        descriptionKey: 'erp.providerRequirements.sourceNamespace.description',
        status: 'partial',
      },
      {
        id: 'runtime_boundary',
        labelKey: 'erp.providerRequirements.runtimeBoundary.label',
        descriptionKey: 'erp.providerRequirements.runtimeBoundary.description',
        status: 'blocked',
      },
    ],
  },
  {
    id: 'custom_api',
    labelKey: 'erp.providerOptions.custom_api.label',
    descriptionKey: 'erp.providerOptions.custom_api.description',
    readinessLabelKey: 'erp.providerOptions.custom_api.readiness',
    status: 'blocked',
    requirements: [
      {
        id: 'source_profile',
        labelKey: 'erp.providerRequirements.sourceProfile.label',
        descriptionKey: 'erp.providerRequirements.sourceProfile.description',
        status: 'blocked',
      },
      {
        id: 'canonical_mapping',
        labelKey: 'erp.providerRequirements.canonicalMapping.label',
        descriptionKey: 'erp.providerRequirements.canonicalMapping.description',
        status: 'partial',
      },
      {
        id: 'identity_strategy',
        labelKey: 'erp.providerRequirements.identityStrategy.label',
        descriptionKey: 'erp.providerRequirements.identityStrategy.description',
        status: 'partial',
      },
      {
        id: 'runtime_boundary',
        labelKey: 'erp.providerRequirements.runtimeBoundary.label',
        descriptionKey: 'erp.providerRequirements.runtimeBoundary.description',
        status: 'blocked',
      },
    ],
  },
]

const TRANSFER_MODES: ConnectorTransferMode[] = [
  {
    id: 'manual_csv',
    labelKey: 'erp.transferModes.manual_csv',
    status: 'ready',
  },
  {
    id: 'scheduled_file_exchange',
    labelKey: 'erp.transferModes.scheduled_file_exchange',
    status: 'partial',
  },
  {
    id: 'excel_xml',
    labelKey: 'erp.transferModes.excel_xml',
    status: 'partial',
  },
  {
    id: 'staging_table',
    labelKey: 'erp.transferModes.staging_table',
    status: 'partial',
  },
  {
    id: 'api_future',
    labelKey: 'erp.transferModes.api_future',
    status: 'blocked',
  },
]

const CONNECTOR_GUARDRAILS: ConnectorGuardrail[] = [
  {
    id: 'canonical_mapping_required',
    labelKey: 'erp.guardrails.canonicalMappingRequired',
    enforced: true,
  },
  {
    id: 'identity_reconciliation_required',
    labelKey: 'erp.guardrails.identityReconciliationRequired',
    enforced: true,
  },
  {
    id: 'human_confirmation_required',
    labelKey: 'erp.guardrails.humanConfirmationRequired',
    enforced: true,
  },
  {
    id: 'no_runtime_sync',
    labelKey: 'erp.guardrails.noRuntimeSync',
    enforced: true,
  },
  {
    id: 'no_erp_writes',
    labelKey: 'erp.guardrails.noErpWrites',
    enforced: true,
  },
  {
    id: 'no_credentials_in_repo',
    labelKey: 'erp.guardrails.noCredentialsInRepo',
    enforced: true,
  },
]

function emptyErpOverview(connectorState: ConnectorLifecycleState = 'no_tenant'): ErpOverview {
  const checks = buildReadinessChecks({
    hasConnection: false,
    isActive: false,
    mappedFields: 0,
    totalFields: 0,
    namespaceCount: 0,
    identityCount: 0,
    setupReadinessPct: 0,
  })

  return buildOverview({
    connectorState,
    providerCode: null,
    providerLabel: FALLBACK_PROVIDER_LABEL,
    displayName: null,
    providerStatus: 'not_configured',
    providerStatusLabelKey: 'erp.providerStatus.not_configured',
    isActive: false,
    lastAttempt: '—',
    checks,
    mappings: [],
    namespaces: [],
    syncLogs: [],
  })
}

export function isErpOverviewEmpty(data: ErpOverview): boolean {
  return data.connectorState === 'no_tenant'
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

function formatProviderCode(provider: string | null | undefined): string | null {
  const normalized = provider?.trim()
  if (!normalized) return null
  return normalized
    .split(/[_\s-]+/)
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1).toLowerCase())
    .join(' ')
}

export function mapProviderLabel(
  provider: string | null | undefined,
  displayName?: string | null,
): string {
  const display = displayName?.trim()
  if (display) return display

  const normalized = provider?.trim().toLowerCase()
  if (!normalized) return FALLBACK_PROVIDER_LABEL

  return PROVIDER_LABELS[normalized] ?? formatProviderCode(normalized) ?? FALLBACK_PROVIDER_LABEL
}

function mapSyncLevel(status: string | null | undefined): ConnectorSyncLogLevel {
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

function buildReadinessChecks({
  hasConnection,
  isActive,
  mappedFields,
  totalFields,
  namespaceCount,
  identityCount,
  setupReadinessPct,
}: {
  hasConnection: boolean
  isActive: boolean
  mappedFields: number
  totalFields: number
  namespaceCount: number
  identityCount: number
  setupReadinessPct: number
}): ConnectorReadinessCheck[] {
  return [
    {
      id: 'provider_metadata',
      labelKey: 'erp.readinessChecks.providerMetadata',
      status: hasConnection ? 'ready' : 'blocked',
      value: hasConnection,
    },
    {
      id: 'runtime_boundary',
      labelKey: 'erp.readinessChecks.runtimeBoundary',
      status: hasConnection ? (isActive ? 'partial' : 'ready') : 'blocked',
      value: isActive ? 'active' : 'inactive',
    },
    {
      id: 'field_mapping',
      labelKey: 'erp.readinessChecks.fieldMapping',
      status: mappedFields > 0 ? 'ready' : totalFields > 0 ? 'partial' : 'blocked',
      value: `${mappedFields}/${totalFields}`,
    },
    {
      id: 'source_namespace',
      labelKey: 'erp.readinessChecks.sourceNamespace',
      status: namespaceCount > 0 ? 'ready' : hasConnection ? 'partial' : 'blocked',
      value: namespaceCount,
    },
    {
      id: 'identity_reconciliation',
      labelKey: 'erp.readinessChecks.identityReconciliation',
      status: identityCount > 0 ? 'ready' : namespaceCount > 0 ? 'partial' : 'blocked',
      value: identityCount,
    },
    {
      id: 'setup_readiness',
      labelKey: 'erp.readinessChecks.setupReadiness',
      status: setupReadinessPct >= 50 ? 'ready' : setupReadinessPct > 0 ? 'partial' : 'blocked',
      value: `${setupReadinessPct}%`,
    },
    {
      id: 'write_guardrail',
      labelKey: 'erp.readinessChecks.writeGuardrail',
      status: hasConnection ? 'ready' : 'blocked',
      value: true,
    },
  ]
}

function deriveReadinessStatus(checks: ConnectorReadinessCheck[]): ConnectorReadinessStatus {
  if (checks.every((check) => check.status === 'ready')) return 'ready'
  if (checks.some((check) => check.status === 'ready' || check.status === 'partial')) {
    return 'partial'
  }
  return 'blocked'
}

function deriveReadinessScore(checks: ConnectorReadinessCheck[]): number {
  if (checks.length === 0) return 0
  const score = checks.reduce((total, check) => {
    if (check.status === 'ready') return total + 1
    if (check.status === 'partial') return total + 0.5
    return total
  }, 0)

  return Math.round((score / checks.length) * 100)
}

function buildConnectorSetupSteps({
  connectorState,
  mappedFields,
  namespaceCount,
  identityCount,
  readinessStatus,
  isActive,
}: {
  connectorState: ConnectorLifecycleState
  mappedFields: number
  namespaceCount: number
  identityCount: number
  readinessStatus: ConnectorReadinessStatus
  isActive: boolean
}): ConnectorSetupStep[] {
  if (connectorState === 'no_tenant') {
    return ['source', 'mapping', 'namespace', 'preflight', 'runtime'].map((id) => ({
      id: id as ConnectorSetupStepId,
      labelKey: `erp.setupSteps.${id}.label`,
      descriptionKey: `erp.setupSteps.${id}.description`,
      status: 'blocked' as const,
    }))
  }

  return [
    {
      id: 'source',
      labelKey: 'erp.setupSteps.source.label',
      descriptionKey: 'erp.setupSteps.source.description',
      status: connectorState === 'connector_selected' ? 'ready' : 'partial',
    },
    {
      id: 'mapping',
      labelKey: 'erp.setupSteps.mapping.label',
      descriptionKey: 'erp.setupSteps.mapping.description',
      status:
        connectorState === 'connector_selected'
          ? mappedFields > 0
            ? 'ready'
            : 'partial'
          : 'blocked',
    },
    {
      id: 'namespace',
      labelKey: 'erp.setupSteps.namespace.label',
      descriptionKey: 'erp.setupSteps.namespace.description',
      status:
        connectorState === 'connector_selected'
          ? namespaceCount > 0 && identityCount > 0
            ? 'ready'
            : 'partial'
          : 'blocked',
    },
    {
      id: 'preflight',
      labelKey: 'erp.setupSteps.preflight.label',
      descriptionKey: 'erp.setupSteps.preflight.description',
      status: connectorState === 'connector_selected' ? readinessStatus : 'blocked',
    },
    {
      id: 'runtime',
      labelKey: 'erp.setupSteps.runtime.label',
      descriptionKey: 'erp.setupSteps.runtime.description',
      status:
        connectorState === 'connector_selected' ? (isActive ? 'partial' : 'ready') : 'blocked',
    },
  ]
}

function buildOverview({
  connectorState,
  providerCode,
  providerLabel,
  displayName,
  providerStatus,
  providerStatusLabelKey,
  isActive,
  lastAttempt,
  checks,
  mappings,
  namespaces,
  syncLogs,
}: {
  connectorState: ConnectorLifecycleState
  providerCode: string | null
  providerLabel: string
  displayName: string | null
  providerStatus: ConnectorProviderStatus
  providerStatusLabelKey: string
  isActive: boolean
  lastAttempt: string
  checks: ConnectorReadinessCheck[]
  mappings: ConnectorFieldMapping[]
  namespaces: ConnectorNamespaceSummary[]
  syncLogs: ConnectorSyncLog[]
}): ErpOverview {
  const mappedFields = mappings.filter((row) => row.status === 'mapped').length
  const totalFields = mappings.length
  const readinessScore = deriveReadinessScore(checks)
  const readinessStatus = deriveReadinessStatus(checks)
  const identityCount = namespaces.reduce((total, namespace) => total + namespace.identityCount, 0)

  return {
    connectorState,
    provider: {
      code: providerCode,
      label: providerLabel,
      displayName,
      status: providerStatus,
      statusLabelKey: providerStatusLabelKey,
      isActive,
      lastAttempt,
    },
    readiness: {
      score: readinessScore,
      status: readinessStatus,
      checks,
    },
    setupSteps: buildConnectorSetupSteps({
      connectorState,
      mappedFields,
      namespaceCount: namespaces.length,
      identityCount,
      readinessStatus,
      isActive,
    }),
    mappings,
    namespaces,
    transferModes: TRANSFER_MODES,
    guardrails: CONNECTOR_GUARDRAILS,
    providerOptions: CONNECTOR_PROVIDER_OPTIONS,
    syncLogs,
    status: {
      system: providerLabel,
      status: 'beklemede',
      statusLabel: providerStatusLabelKey,
      mappedFields,
      totalFields,
      lastAttempt,
      readiness: readinessScore,
    },
  }
}

export async function buildDemoErpOverview(): Promise<ErpOverview> {
  const demo = await fetchDemoErpOverview()
  const checks = buildReadinessChecks({
    hasConnection: true,
    isActive: false,
    mappedFields: demo.status.mappedFields,
    totalFields: demo.status.totalFields,
    namespaceCount: 1,
    identityCount: 0,
    setupReadinessPct: demo.status.readiness,
  })

  return buildOverview({
    connectorState: 'connector_selected',
    providerCode: 'canias',
    providerLabel: demo.status.system,
    displayName: demo.status.system,
    providerStatus: 'metadata_only',
    providerStatusLabelKey: 'erp.providerStatus.metadata_only',
    isActive: false,
    lastAttempt: demo.status.lastAttempt,
    checks,
    mappings: demo.mappings.map((mapping) => ({
      canonicalField: mapping.puls,
      sourceField: mapping.erp,
      sourceEntity: 'demo',
      status: mapping.status,
      required: false,
    })),
    namespaces: [
      {
        id: 'demo-canias',
        code: 'CANIAS',
        name: 'Canias demo namespace',
        sourceType: 'erp',
        identityCount: 0,
      },
    ],
    syncLogs: demo.syncLogs,
  })
}

async function fetchRealErpOverview(userId: string): Promise<ErpOverview> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) return emptyErpOverview('no_tenant')

  const [connectionRow, mappingsRow, batchesRow, readinessRow, namespacesRow, identitiesRow] =
    await Promise.all([
      pulsIntegration()
        .from('erp_connections')
        .select('provider, display_name, is_active, last_sync_at, last_status')
        .eq('tenant_id', ctx.tenantId)
        .order('updated_at', { ascending: false })
        .limit(1)
        .maybeSingle(),
      pulsIntegration()
        .from('erp_field_mappings')
        .select(
          'source_entity, source_field, target_schema, target_table, target_field, is_required, is_sensitive, is_active',
        )
        .eq('tenant_id', ctx.tenantId)
        .order('source_entity', { ascending: true })
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
      pulsIntegration()
        .from('source_namespaces')
        .select('id, code, name, source_type')
        .eq('tenant_id', ctx.tenantId)
        .eq('is_active', true)
        .order('priority_rank', { ascending: true }),
      pulsIntegration()
        .from('entity_identity_map')
        .select('source_namespace_id, canonical_table')
        .eq('tenant_id', ctx.tenantId)
        .eq('is_active', true),
    ])

  const connection =
    connectionRow.error || !connectionRow.data ? null : (connectionRow.data as ErpConnectionRow)
  const rawMappings = mappingsRow.error ? [] : ((mappingsRow.data ?? []) as ErpFieldMappingRow[])
  const batches = batchesRow.error ? [] : ((batchesRow.data ?? []) as ErpSyncBatchRow[])
  const readiness = readinessRow.error ? null : (readinessRow.data as SetupReadinessRow | null)
  const rawNamespaces = namespacesRow.error
    ? []
    : ((namespacesRow.data ?? []) as SourceNamespaceRow[])
  const identities = identitiesRow.error ? [] : ((identitiesRow.data ?? []) as EntityIdentityRow[])

  const identityCounts = identities.reduce<Record<string, number>>((counts, row) => {
    const namespaceId = row.source_namespace_id
    if (!namespaceId) return counts
    counts[namespaceId] = (counts[namespaceId] ?? 0) + 1
    return counts
  }, {})

  const mappings = rawMappings
    .filter((row) => row.is_sensitive !== true)
    .map((row) => {
      const canonicalField = [
        row.target_schema ?? 'puls',
        row.target_table ?? 'canonical',
        row.target_field ?? 'field',
      ].join('.')

      return {
        canonicalField,
        sourceField: row.source_field ?? '—',
        sourceEntity: row.source_entity ?? '—',
        status: row.is_active === false ? ('pending' as const) : ('mapped' as const),
        required: row.is_required === true,
      }
    })

  const mappedFields = mappings.filter((row) => row.status === 'mapped').length
  const namespaces = rawNamespaces.map((row) => ({
    id: row.id ?? `${row.code ?? 'namespace'}-${row.name ?? 'unknown'}`,
    code: row.code ?? '—',
    name: row.name ?? '—',
    sourceType: row.source_type ?? 'external',
    identityCount: identityCounts[row.id ?? ''] ?? 0,
  }))
  const identityCount = identities.length
  const setupReadinessPct = Number(readiness?.integration_setup_pct ?? 0)
  const checks = buildReadinessChecks({
    hasConnection: Boolean(connection),
    isActive: connection?.is_active === true,
    mappedFields,
    totalFields: mappings.length,
    namespaceCount: namespaces.length,
    identityCount,
    setupReadinessPct,
  })
  const providerCode = connection?.provider?.trim().toLowerCase() || null
  const providerLabel = mapProviderLabel(providerCode, connection?.display_name ?? null)
  const isActive = connection?.is_active === true
  const providerStatus: ConnectorProviderStatus = connection
    ? isActive
      ? 'runtime_active'
      : 'runtime_inactive'
    : 'not_configured'
  const providerStatusLabelKey = `erp.providerStatus.${providerStatus}`

  return buildOverview({
    connectorState: connection ? 'connector_selected' : 'no_connector',
    providerCode,
    providerLabel,
    displayName: connection?.display_name ?? null,
    providerStatus,
    providerStatusLabelKey,
    isActive,
    lastAttempt: formatSyncTimestamp(connection?.last_sync_at as string | null),
    checks,
    mappings,
    namespaces,
    syncLogs: batches.map((row, index) => ({
      id: row.id ?? `sync-${index}`,
      at: formatSyncTimestamp(row.created_at),
      level: mapSyncLevel(row.status),
      message: row.error_summary ?? `${row.sync_type ?? 'preflight'} · ${row.status ?? 'pending'}`,
    })),
  })
}

export async function fetchErpOverview(userId: string): Promise<ErpOverview> {
  return resolveAdapterData({
    operation: 'fetchErpOverview',
    fetchReal: () => fetchRealErpOverview(userId),
    fetchDemo: buildDemoErpOverview,
    isEmpty: isErpOverviewEmpty,
  })
}

export function fetchErpOverviewWithMeta(userId: string) {
  return resolveAdapterDataWithMeta({
    operation: 'fetchErpOverview',
    fetchReal: () => fetchRealErpOverview(userId),
    fetchDemo: buildDemoErpOverview,
    isEmpty: isErpOverviewEmpty,
  })
}
