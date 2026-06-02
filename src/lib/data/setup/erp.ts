import { fetchDemoErpOverview } from '#/lib/demo/puls-demo-data'
import { pulsCalc, pulsIntegration, resolveTenantContext } from '#/lib/data/client'
import { DataAdapterError, fromSupabaseError, isDataAdapterError } from '#/lib/data/errors'
import { resolveAdapterData, resolveAdapterDataWithMeta } from '#/lib/data/result'

export type ConnectorReadinessStatus = 'ready' | 'partial' | 'blocked'
export type ConnectorMappingStatus = 'mapped' | 'pending'
export type ConnectorLifecycleState = 'no_tenant' | 'no_connector' | 'connector_selected'
export type ConnectorSetupStatus =
  | 'draft'
  | 'setup_in_progress'
  | 'mapping_ready'
  | 'preflight_ready'
  | 'connected'
  | 'disabled'
  | 'archived'
  | 'error'
export type ConnectorSetupCurrentStep = 'source' | 'mapping' | 'namespace' | 'preflight' | 'runtime'
export type ConnectorProviderStatus =
  | 'not_configured'
  | 'setup_draft'
  | 'setup_in_progress'
  | 'mapping_ready'
  | 'preflight_ready'
  | 'disabled'
  | 'metadata_only'
  | 'runtime_inactive'
  | 'runtime_active'
export type ConnectorSyncLogLevel = 'success' | 'warning' | 'info'
export type ConnectorSetupStepId = 'source' | 'mapping' | 'namespace' | 'preflight' | 'runtime'
export type ConnectorCanonicalDataClassId =
  | 'employees'
  | 'departments'
  | 'positions'
  | 'cost_centers'
  | 'locations'
export type ConnectorPreflightCheckId =
  | 'source_profile'
  | 'required_mapping'
  | 'source_namespace'
  | 'identity_reconciliation'
  | 'credential_boundary'
  | 'runtime_boundary'
  | 'write_guardrail'

export type ConnectorSetupStep = {
  id: ConnectorSetupStepId
  labelKey: string
  descriptionKey: string
  status: ConnectorReadinessStatus
}

export type ConnectorSetupSummary = {
  labelKey: string
  valueKey: string
  hintKey: string
  progress: number | null
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
  targetSchema: string
  targetTable: string
  targetField: string
  sourceField: string
  sourceEntity: string
  status: ConnectorMappingStatus
  required: boolean
}

export type ConnectorCanonicalDataClass = {
  id: ConnectorCanonicalDataClassId
  labelKey: string
  descriptionKey: string
  pulsTarget: string
  mappedFields: number
  totalFields: number
  mappedRequiredFields: number
  requiredFields: number
  status: ConnectorReadinessStatus
}

export type ConnectorPreflightCheck = {
  id: ConnectorPreflightCheckId
  labelKey: string
  descriptionKey: string
  status: ConnectorReadinessStatus
}

export type ConnectorPreflightResult = {
  status: ConnectorReadinessStatus
  statusLabelKey: string
  summaryKey: string
  nextStepKey: string
  passedCount: number
  warningCount: number
  blockedCount: number
  safeToRunRuntime: false
  runtimeExecution: 'not_started'
  checks: ConnectorPreflightCheck[]
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
  setupAvailable: boolean
  requirements: ConnectorProviderRequirement[]
}

export type ErpOverview = {
  connectorState: ConnectorLifecycleState
  provider: {
    id: string | null
    code: string | null
    label: string
    displayName: string | null
    status: ConnectorProviderStatus
    statusLabelKey: string
    isActive: boolean
    lastAttempt: string
  }
  setup: {
    status: ConnectorSetupStatus | null
    currentStep: ConnectorSetupCurrentStep | null
    isEnabled: boolean
    ownedDomains: string[]
    selectedAt: string | null
    setupStartedAt: string | null
  }
  readiness: {
    score: number
    status: ConnectorReadinessStatus
    checks: ConnectorReadinessCheck[]
  }
  setupSummary: ConnectorSetupSummary
  setupSteps: ConnectorSetupStep[]
  preflight: ConnectorPreflightResult
  canonicalClasses: ConnectorCanonicalDataClass[]
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
  id?: string | null
  provider?: string | null
  display_name?: string | null
  is_active?: boolean | null
  last_sync_at?: string | null
  last_status?: string | null
  setup_status?: ConnectorSetupStatus | null
  setup_step?: ConnectorSetupCurrentStep | null
  is_enabled?: boolean | null
  owned_domains?: string[] | null
  selected_at?: string | null
  setup_started_at?: string | null
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

export type StartConnectorSetupInput = {
  providerId: ConnectorProviderOption['id']
}

export type StartConnectorSetupResult = {
  connectionId: string
  providerId: ConnectorProviderOption['id']
  setupStatus: ConnectorSetupStatus
  currentStep: ConnectorSetupCurrentStep
}

export type ConnectorSetupErrorMapping = {
  code:
    | 'missing_tenant'
    | 'admin_required'
    | 'provider_unavailable'
    | 'permission_denied'
    | 'save_failed'
  toastKey: string
}

const PROVIDER_LABELS: Record<string, string> = {
  canias: 'Canias',
  logo: 'Logo',
  netsis: 'Netsis',
  sap: 'SAP',
}

const FALLBACK_PROVIDER_LABEL = 'External data source'

const SETUP_PROVIDER_CONFIG: Partial<
  Record<
    ConnectorProviderOption['id'],
    {
      provider: 'canias' | 'csv'
      displayName: string
      connectionMethod: 'rest_api' | 'manual_import'
      connectionKey: string
      ownedDomains: string[]
  sourceType: 'erp' | 'file'
    }
  >
> = {
  canias: {
    provider: 'canias',
    displayName: 'Canias',
    connectionMethod: 'rest_api',
    connectionKey: 'canias-default',
    ownedDomains: ['employees', 'departments', 'positions', 'cost_centers'],
    sourceType: 'erp',
  },
  csv_import: {
    provider: 'csv',
    displayName: 'CSV / Excel',
    connectionMethod: 'manual_import',
    connectionKey: 'csv-excel-default',
    ownedDomains: ['employees', 'departments', 'positions', 'cost_centers'],
    sourceType: 'file',
  },
}

export type ConnectorDefaultFieldMapping = {
  sourceEntity: string
  sourceField: string
  targetSchema: string
  targetTable: string
  targetField: string
  required: boolean
}

type ConnectorCanonicalField = {
  targetField: string
  required: boolean
}

type ConnectorCanonicalDataClassDefinition = {
  id: ConnectorCanonicalDataClassId
  labelKey: string
  descriptionKey: string
  pulsTarget: string
  targetSchema: string
  targetTable: string
  fields: ConnectorCanonicalField[]
}

const CANONICAL_DATA_CLASSES: ConnectorCanonicalDataClassDefinition[] = [
  {
    id: 'employees',
    labelKey: 'erp.canonicalClasses.employees.label',
    descriptionKey: 'erp.canonicalClasses.employees.description',
    pulsTarget: 'puls_core.employees',
    targetSchema: 'puls_core',
    targetTable: 'employees',
    fields: [
      { targetField: 'employee_code', required: true },
      { targetField: 'full_name', required: true },
      { targetField: 'email', required: false },
      { targetField: 'hire_date', required: false },
    ],
  },
  {
    id: 'departments',
    labelKey: 'erp.canonicalClasses.departments.label',
    descriptionKey: 'erp.canonicalClasses.departments.description',
    pulsTarget: 'puls_core.departments',
    targetSchema: 'puls_core',
    targetTable: 'departments',
    fields: [
      { targetField: 'code', required: true },
      { targetField: 'name', required: true },
      { targetField: 'manager_employee_id', required: false },
    ],
  },
  {
    id: 'positions',
    labelKey: 'erp.canonicalClasses.positions.label',
    descriptionKey: 'erp.canonicalClasses.positions.description',
    pulsTarget: 'puls_core.positions',
    targetSchema: 'puls_core',
    targetTable: 'positions',
    fields: [
      { targetField: 'code', required: true },
      { targetField: 'name', required: true },
    ],
  },
  {
    id: 'cost_centers',
    labelKey: 'erp.canonicalClasses.costCenters.label',
    descriptionKey: 'erp.canonicalClasses.costCenters.description',
    pulsTarget: 'puls_core.cost_centers',
    targetSchema: 'puls_core',
    targetTable: 'cost_centers',
    fields: [
      { targetField: 'code', required: true },
      { targetField: 'name', required: true },
    ],
  },
  {
    id: 'locations',
    labelKey: 'erp.canonicalClasses.locations.label',
    descriptionKey: 'erp.canonicalClasses.locations.description',
    pulsTarget: 'puls_core.locations',
    targetSchema: 'puls_core',
    targetTable: 'locations',
    fields: [{ targetField: 'code', required: false }],
  },
]

const DEFAULT_FIELD_MAPPINGS: Partial<
  Record<ConnectorProviderOption['id'], ConnectorDefaultFieldMapping[]>
> = {
  canias: [
    {
      sourceEntity: 'employee',
      sourceField: 'EMPLOYEE_CODE',
      targetSchema: 'puls_core',
      targetTable: 'employees',
      targetField: 'employee_code',
      required: true,
    },
    {
      sourceEntity: 'employee',
      sourceField: 'FULL_NAME',
      targetSchema: 'puls_core',
      targetTable: 'employees',
      targetField: 'full_name',
      required: true,
    },
    {
      sourceEntity: 'employee',
      sourceField: 'EMAIL',
      targetSchema: 'puls_core',
      targetTable: 'employees',
      targetField: 'email',
      required: false,
    },
    {
      sourceEntity: 'employee',
      sourceField: 'HIRE_DATE',
      targetSchema: 'puls_core',
      targetTable: 'employees',
      targetField: 'hire_date',
      required: false,
    },
    {
      sourceEntity: 'department',
      sourceField: 'DEPT_CODE',
      targetSchema: 'puls_core',
      targetTable: 'departments',
      targetField: 'code',
      required: true,
    },
    {
      sourceEntity: 'department',
      sourceField: 'DEPT_NAME',
      targetSchema: 'puls_core',
      targetTable: 'departments',
      targetField: 'name',
      required: true,
    },
    {
      sourceEntity: 'department',
      sourceField: 'MANAGER_CODE',
      targetSchema: 'puls_core',
      targetTable: 'departments',
      targetField: 'manager_employee_id',
      required: false,
    },
    {
      sourceEntity: 'position',
      sourceField: 'POS_CODE',
      targetSchema: 'puls_core',
      targetTable: 'positions',
      targetField: 'code',
      required: true,
    },
    {
      sourceEntity: 'position',
      sourceField: 'POS_NAME',
      targetSchema: 'puls_core',
      targetTable: 'positions',
      targetField: 'name',
      required: true,
    },
    {
      sourceEntity: 'cost_center',
      sourceField: 'CC_CODE',
      targetSchema: 'puls_core',
      targetTable: 'cost_centers',
      targetField: 'code',
      required: true,
    },
    {
      sourceEntity: 'cost_center',
      sourceField: 'CC_NAME',
      targetSchema: 'puls_core',
      targetTable: 'cost_centers',
      targetField: 'name',
      required: true,
    },
    {
      sourceEntity: 'location',
      sourceField: 'LOC_CODE',
      targetSchema: 'puls_core',
      targetTable: 'locations',
      targetField: 'code',
      required: false,
    },
  ],
  csv_import: [
    {
      sourceEntity: 'employee',
      sourceField: 'employee_code',
      targetSchema: 'puls_core',
      targetTable: 'employees',
      targetField: 'employee_code',
      required: true,
    },
    {
      sourceEntity: 'employee',
      sourceField: 'full_name',
      targetSchema: 'puls_core',
      targetTable: 'employees',
      targetField: 'full_name',
      required: true,
    },
    {
      sourceEntity: 'employee',
      sourceField: 'email',
      targetSchema: 'puls_core',
      targetTable: 'employees',
      targetField: 'email',
      required: false,
    },
    {
      sourceEntity: 'department',
      sourceField: 'department_code',
      targetSchema: 'puls_core',
      targetTable: 'departments',
      targetField: 'code',
      required: true,
    },
    {
      sourceEntity: 'department',
      sourceField: 'department_name',
      targetSchema: 'puls_core',
      targetTable: 'departments',
      targetField: 'name',
      required: true,
    },
    {
      sourceEntity: 'position',
      sourceField: 'position_code',
      targetSchema: 'puls_core',
      targetTable: 'positions',
      targetField: 'code',
      required: true,
    },
    {
      sourceEntity: 'position',
      sourceField: 'position_name',
      targetSchema: 'puls_core',
      targetTable: 'positions',
      targetField: 'name',
      required: true,
    },
    {
      sourceEntity: 'cost_center',
      sourceField: 'cost_center_code',
      targetSchema: 'puls_core',
      targetTable: 'cost_centers',
      targetField: 'code',
      required: true,
    },
    {
      sourceEntity: 'cost_center',
      sourceField: 'cost_center_name',
      targetSchema: 'puls_core',
      targetTable: 'cost_centers',
      targetField: 'name',
      required: true,
    },
  ],
}

export function buildDefaultConnectorFieldMappings(
  providerId: ConnectorProviderOption['id'],
): ConnectorDefaultFieldMapping[] {
  return [...(DEFAULT_FIELD_MAPPINGS[providerId] ?? [])]
}

async function ensureDefaultConnectorFieldMappings({
  tenantId,
  connectionId,
  providerId,
}: {
  tenantId: string
  connectionId: string
  providerId: ConnectorProviderOption['id']
}): Promise<boolean> {
  const defaults = buildDefaultConnectorFieldMappings(providerId)
  if (defaults.length === 0) return false

  const existing = await pulsIntegration()
    .from('erp_field_mappings')
    .select('id')
    .eq('tenant_id', tenantId)
    .eq('connection_id', connectionId)
    .limit(1)

  if (existing.error) {
    throw fromSupabaseError(
      existing.error,
      'ensureDefaultConnectorFieldMappings',
      'puls_integration',
      'erp_field_mappings',
    )
  }

  if (Array.isArray(existing.data) && existing.data.length > 0) {
    return true
  }

  const write = await pulsIntegration()
    .from('erp_field_mappings')
    .insert(
      defaults.map((mapping) => ({
        tenant_id: tenantId,
        connection_id: connectionId,
        source_entity: mapping.sourceEntity,
        source_field: mapping.sourceField,
        target_schema: mapping.targetSchema,
        target_table: mapping.targetTable,
        target_field: mapping.targetField,
        transform_rule: {
          discovery_source: 'pr14_10_default',
          runtime_boundary: 'closed',
        },
        is_required: mapping.required,
        is_sensitive: false,
        is_active: true,
      })),
    )
    .select('id')

  if (write.error) {
    throw fromSupabaseError(
      write.error,
      'ensureDefaultConnectorFieldMappings',
      'puls_integration',
      'erp_field_mappings',
    )
  }

  return true
}

export function mapConnectorSetupError(error: unknown): ConnectorSetupErrorMapping {
  if (isDataAdapterError(error)) {
    if (error.code === 'PULS_CONNECTOR_TENANT_REQUIRED') {
      return { code: 'missing_tenant', toastKey: 'erp.errors.tenantMissing' }
    }
    if (error.code === 'PULS_CONNECTOR_ADMIN_REQUIRED') {
      return { code: 'admin_required', toastKey: 'erp.errors.adminRequired' }
    }
    if (error.code === 'PULS_CONNECTOR_PROVIDER_UNAVAILABLE') {
      return { code: 'provider_unavailable', toastKey: 'erp.errors.providerUnavailable' }
    }
    if (error.code === '42501') {
      return { code: 'permission_denied', toastKey: 'erp.errors.permissionDenied' }
    }
  }

  return { code: 'save_failed', toastKey: 'erp.errors.setupSaveFailed' }
}

const CONNECTOR_PROVIDER_OPTIONS: ConnectorProviderOption[] = [
  {
    id: 'canias',
    labelKey: 'erp.providerOptions.canias.label',
    descriptionKey: 'erp.providerOptions.canias.description',
    readinessLabelKey: 'erp.providerOptions.canias.readiness',
    status: 'ready',
    setupAvailable: true,
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
    setupAvailable: false,
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
    setupAvailable: true,
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
    setupAvailable: false,
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
    connectionId: null,
    providerCode: null,
    providerLabel: FALLBACK_PROVIDER_LABEL,
    displayName: null,
    providerStatus: 'not_configured',
    providerStatusLabelKey: 'erp.providerStatus.not_configured',
    isActive: false,
    lastAttempt: '—',
    setupStatus: null,
    setupStep: null,
    isEnabled: false,
    ownedDomains: [],
    selectedAt: null,
    setupStartedAt: null,
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

function mappingKey(mapping: Pick<ConnectorFieldMapping, 'targetSchema' | 'targetTable' | 'targetField'>) {
  return `${mapping.targetSchema}.${mapping.targetTable}.${mapping.targetField}`
}

function buildConnectorCanonicalClasses(
  mappings: ConnectorFieldMapping[],
): ConnectorCanonicalDataClass[] {
  const mappedFields = new Set(
    mappings.filter((mapping) => mapping.status === 'mapped').map((mapping) => mappingKey(mapping)),
  )

  return CANONICAL_DATA_CLASSES.map((definition) => {
    const totalFields = definition.fields.length
    const requiredFields = definition.fields.filter((field) => field.required).length
    const mappedCount = definition.fields.filter((field) =>
      mappedFields.has(
        `${definition.targetSchema}.${definition.targetTable}.${field.targetField}`,
      ),
    ).length
    const mappedRequiredFields = definition.fields.filter(
      (field) =>
        field.required &&
        mappedFields.has(
          `${definition.targetSchema}.${definition.targetTable}.${field.targetField}`,
        ),
    ).length
    const hasRequiredCoverage =
      requiredFields > 0 ? mappedRequiredFields >= requiredFields : mappedCount === totalFields
    const status: ConnectorReadinessStatus =
      mappedCount > 0 && hasRequiredCoverage ? 'ready' : mappedCount > 0 ? 'partial' : 'blocked'

    return {
      id: definition.id,
      labelKey: definition.labelKey,
      descriptionKey: definition.descriptionKey,
      pulsTarget: definition.pulsTarget,
      mappedFields: mappedCount,
      totalFields,
      mappedRequiredFields,
      requiredFields,
      status,
    }
  })
}

function deriveRequiredMappingStatus(
  canonicalClasses: ConnectorCanonicalDataClass[],
): ConnectorReadinessStatus {
  const classesWithRequiredFields = canonicalClasses.filter((row) => row.requiredFields > 0)
  if (classesWithRequiredFields.length === 0) return 'blocked'

  const readyCount = classesWithRequiredFields.filter((row) => row.status === 'ready').length
  if (readyCount === classesWithRequiredFields.length) return 'ready'
  if (readyCount > 0 || canonicalClasses.some((row) => row.mappedFields > 0)) return 'partial'
  return 'blocked'
}

function buildConnectorPreflightResult({
  connectorState,
  isActive,
  isEnabled,
  canonicalClasses,
  namespaceCount,
  identityCount,
}: {
  connectorState: ConnectorLifecycleState
  isActive: boolean
  isEnabled: boolean
  canonicalClasses: ConnectorCanonicalDataClass[]
  namespaceCount: number
  identityCount: number
}): ConnectorPreflightResult {
  const hasConnection = connectorState === 'connector_selected'
  const checks: ConnectorPreflightCheck[] = [
    {
      id: 'source_profile',
      labelKey: 'erp.preflightChecks.sourceProfile.label',
      descriptionKey: 'erp.preflightChecks.sourceProfile.description',
      status: hasConnection && isEnabled ? 'ready' : hasConnection ? 'partial' : 'blocked',
    },
    {
      id: 'required_mapping',
      labelKey: 'erp.preflightChecks.requiredMapping.label',
      descriptionKey: 'erp.preflightChecks.requiredMapping.description',
      status: hasConnection ? deriveRequiredMappingStatus(canonicalClasses) : 'blocked',
    },
    {
      id: 'source_namespace',
      labelKey: 'erp.preflightChecks.sourceNamespace.label',
      descriptionKey: 'erp.preflightChecks.sourceNamespace.description',
      status: namespaceCount > 0 ? 'ready' : hasConnection ? 'partial' : 'blocked',
    },
    {
      id: 'identity_reconciliation',
      labelKey: 'erp.preflightChecks.identityReconciliation.label',
      descriptionKey: 'erp.preflightChecks.identityReconciliation.description',
      status: identityCount > 0 ? 'ready' : namespaceCount > 0 ? 'partial' : 'blocked',
    },
    {
      id: 'credential_boundary',
      labelKey: 'erp.preflightChecks.credentialBoundary.label',
      descriptionKey: 'erp.preflightChecks.credentialBoundary.description',
      status: hasConnection ? 'ready' : 'blocked',
    },
    {
      id: 'runtime_boundary',
      labelKey: 'erp.preflightChecks.runtimeBoundary.label',
      descriptionKey: 'erp.preflightChecks.runtimeBoundary.description',
      status: hasConnection ? (isActive ? 'partial' : 'ready') : 'blocked',
    },
    {
      id: 'write_guardrail',
      labelKey: 'erp.preflightChecks.writeGuardrail.label',
      descriptionKey: 'erp.preflightChecks.writeGuardrail.description',
      status: hasConnection ? 'ready' : 'blocked',
    },
  ]
  const passedCount = checks.filter((check) => check.status === 'ready').length
  const warningCount = checks.filter((check) => check.status === 'partial').length
  const blockedCount = checks.filter((check) => check.status === 'blocked').length
  const status: ConnectorReadinessStatus =
    blockedCount > 0 ? 'blocked' : warningCount > 0 ? 'partial' : 'ready'

  return {
    status,
    statusLabelKey: `erp.preflightResult.status.${status}`,
    summaryKey: `erp.preflightResult.summary.${status}`,
    nextStepKey: `erp.preflightResult.nextStep.${status}`,
    passedCount,
    warningCount,
    blockedCount,
    safeToRunRuntime: false,
    runtimeExecution: 'not_started',
    checks,
  }
}

function buildConnectorSetupSummary({
  connectorState,
  setupStatus,
  isActive,
  isEnabled,
  mappedFields,
  totalFields,
  namespaceCount,
  identityCount,
  readinessScore,
  readinessStatus,
}: {
  connectorState: ConnectorLifecycleState
  setupStatus: ConnectorSetupStatus | null
  isActive: boolean
  isEnabled: boolean
  mappedFields: number
  totalFields: number
  namespaceCount: number
  identityCount: number
  readinessScore: number
  readinessStatus: ConnectorReadinessStatus
}): ConnectorSetupSummary {
  const summary = (
    valueKey: string,
    hintKey: string,
    progress: number | null = null,
  ): ConnectorSetupSummary => ({
    labelKey: 'erp.metrics.setup',
    valueKey,
    hintKey,
    progress,
  })

  if (connectorState !== 'connector_selected') {
    return summary('erp.setupSummary.values.notConfigured', 'erp.setupSummary.hints.notConfigured')
  }

  if (!isEnabled || setupStatus === 'disabled' || setupStatus === 'archived') {
    return summary('erp.setupSummary.values.disabled', 'erp.setupSummary.hints.disabled')
  }

  if (setupStatus === 'error') {
    return summary('erp.setupSummary.values.error', 'erp.setupSummary.hints.error')
  }

  if (isActive || setupStatus === 'connected') {
    return summary('erp.setupSummary.values.connected', 'erp.setupSummary.hints.connected', 100)
  }

  if (mappedFields === 0) {
    return summary('erp.setupSummary.values.draft', 'erp.setupSummary.hints.mappingPending')
  }

  if (totalFields > 0 && mappedFields < totalFields) {
    return summary('erp.setupSummary.values.mapping', 'erp.setupSummary.hints.mappingInProgress')
  }

  if (namespaceCount === 0) {
    return summary(
      'erp.setupSummary.values.mappingReady',
      'erp.setupSummary.hints.namespacePending',
    )
  }

  if (identityCount === 0) {
    return summary(
      'erp.setupSummary.values.namespaceReady',
      'erp.setupSummary.hints.identityPending',
    )
  }

  if (setupStatus === 'preflight_ready' || readinessStatus === 'ready') {
    return summary(
      'erp.setupSummary.values.preflightReady',
      'erp.setupSummary.hints.preflightReady',
      readinessScore,
    )
  }

  return summary(
    'erp.setupSummary.values.setupInProgress',
    'erp.setupSummary.hints.preflightPending',
  )
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
  connectionId,
  providerCode,
  providerLabel,
  displayName,
  providerStatus,
  providerStatusLabelKey,
  isActive,
  lastAttempt,
  setupStatus,
  setupStep,
  isEnabled,
  ownedDomains,
  selectedAt,
  setupStartedAt,
  checks,
  mappings,
  namespaces,
  syncLogs,
}: {
  connectorState: ConnectorLifecycleState
  connectionId: string | null
  providerCode: string | null
  providerLabel: string
  displayName: string | null
  providerStatus: ConnectorProviderStatus
  providerStatusLabelKey: string
  isActive: boolean
  lastAttempt: string
  setupStatus: ConnectorSetupStatus | null
  setupStep: ConnectorSetupCurrentStep | null
  isEnabled: boolean
  ownedDomains: string[]
  selectedAt: string | null
  setupStartedAt: string | null
  checks: ConnectorReadinessCheck[]
  mappings: ConnectorFieldMapping[]
  namespaces: ConnectorNamespaceSummary[]
  syncLogs: ConnectorSyncLog[]
}): ErpOverview {
  const mappedFields = mappings.filter((row) => row.status === 'mapped').length
  const totalFields = mappings.length
  const canonicalClasses = buildConnectorCanonicalClasses(mappings)
  const readinessScore = deriveReadinessScore(checks)
  const readinessStatus = deriveReadinessStatus(checks)
  const identityCount = namespaces.reduce((total, namespace) => total + namespace.identityCount, 0)
  const preflight = buildConnectorPreflightResult({
    connectorState,
    isActive,
    isEnabled,
    canonicalClasses,
    namespaceCount: namespaces.length,
    identityCount,
  })

  return {
    connectorState,
    provider: {
      id: connectionId,
      code: providerCode,
      label: providerLabel,
      displayName,
      status: providerStatus,
      statusLabelKey: providerStatusLabelKey,
      isActive,
      lastAttempt,
    },
    setup: {
      status: setupStatus,
      currentStep: setupStep,
      isEnabled,
      ownedDomains,
      selectedAt,
      setupStartedAt,
    },
    readiness: {
      score: readinessScore,
      status: readinessStatus,
      checks,
    },
    setupSummary: buildConnectorSetupSummary({
      connectorState,
      setupStatus,
      isActive,
      isEnabled,
      mappedFields,
      totalFields,
      namespaceCount: namespaces.length,
      identityCount,
      readinessScore,
      readinessStatus,
    }),
    setupSteps: buildConnectorSetupSteps({
      connectorState,
      mappedFields,
      namespaceCount: namespaces.length,
      identityCount,
      readinessStatus,
      isActive,
    }),
    preflight,
    canonicalClasses,
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
    connectionId: 'demo-canias',
    providerCode: 'canias',
    providerLabel: demo.status.system,
    displayName: demo.status.system,
    providerStatus: 'metadata_only',
    providerStatusLabelKey: 'erp.providerStatus.metadata_only',
    isActive: false,
    lastAttempt: demo.status.lastAttempt,
    setupStatus: 'preflight_ready',
    setupStep: 'preflight',
    isEnabled: true,
    ownedDomains: ['employees', 'departments', 'positions', 'cost_centers'],
    selectedAt: null,
    setupStartedAt: null,
    checks,
    mappings: demo.mappings.map((mapping) => ({
      canonicalField: mapping.puls,
      targetSchema: mapping.puls.split('.')[0] ?? 'puls',
      targetTable: mapping.puls.split('.')[1] ?? 'canonical',
      targetField: mapping.puls.split('.')[2] ?? 'field',
      sourceField: mapping.erp,
      sourceEntity: 'demo',
      status: mapping.status,
      required: false,
    })),
    namespaces: [
      {
        id: 'demo-canias',
        code: 'CANIAS',
        name: 'Canias source scope',
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
        .select('*')
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
      const targetSchema = row.target_schema ?? 'puls'
      const targetTable = row.target_table ?? 'canonical'
      const targetField = row.target_field ?? 'field'
      const canonicalField = [
        targetSchema,
        targetTable,
        targetField,
      ].join('.')

      return {
        canonicalField,
        targetSchema,
        targetTable,
        targetField,
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
  const setupStatus = connection?.setup_status ?? null
  const setupStep = connection?.setup_step ?? null
  const isEnabled = connection?.is_enabled !== false
  const ownedDomains = Array.isArray(connection?.owned_domains) ? connection.owned_domains : []
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
    ? !isEnabled || setupStatus === 'disabled'
      ? 'disabled'
      : isActive || setupStatus === 'connected'
        ? 'runtime_active'
        : setupStatus === 'preflight_ready'
          ? 'preflight_ready'
          : setupStatus === 'mapping_ready' || mappedFields > 0
            ? 'mapping_ready'
          : setupStatus === 'setup_in_progress'
            ? 'setup_in_progress'
            : setupStatus === 'draft'
              ? 'setup_draft'
              : 'runtime_inactive'
    : 'not_configured'
  const providerStatusLabelKey = `erp.providerStatus.${providerStatus}`

  return buildOverview({
    connectorState: connection ? 'connector_selected' : 'no_connector',
    connectionId: connection?.id ?? null,
    providerCode,
    providerLabel,
    displayName: connection?.display_name ?? null,
    providerStatus,
    providerStatusLabelKey,
    isActive,
    lastAttempt: formatSyncTimestamp(connection?.last_sync_at as string | null),
    setupStatus,
    setupStep,
    isEnabled,
    ownedDomains,
    selectedAt: connection?.selected_at ?? null,
    setupStartedAt: connection?.setup_started_at ?? null,
    checks,
    mappings,
    namespaces,
    syncLogs: batches.map((row, index) => ({
      id: row.id ?? `sync-${index}`,
      at: formatSyncTimestamp(row.created_at),
      level: mapSyncLevel(row.status),
      message: row.error_summary ?? `${row.sync_type ?? 'check'} · ${row.status ?? 'pending'}`,
    })),
  })
}

export async function startConnectorSetup(
  userId: string,
  input: StartConnectorSetupInput,
): Promise<StartConnectorSetupResult> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_TENANT_REQUIRED',
      message: 'Connector setup requires tenant context',
      source: 'adapter',
      operation: 'startConnectorSetup',
      i18nKey: 'erp.errors.tenantMissing',
    })
  }
  if (ctx.personaRole !== 'hr_admin' && ctx.personaRole !== 'superadmin') {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_ADMIN_REQUIRED',
      message: 'Connector setup requires admin permission',
      source: 'adapter',
      operation: 'startConnectorSetup',
      i18nKey: 'erp.errors.adminRequired',
    })
  }

  const config = SETUP_PROVIDER_CONFIG[input.providerId]
  if (!config) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_PROVIDER_UNAVAILABLE',
      message: 'Connector provider setup is not available',
      source: 'adapter',
      operation: 'startConnectorSetup',
      i18nKey: 'erp.errors.providerUnavailable',
    })
  }

  const existing = await pulsIntegration()
    .from('erp_connections')
    .select('id, setup_status, setup_step')
    .eq('tenant_id', ctx.tenantId)
    .eq('connection_key', config.connectionKey)
    .maybeSingle()

  if (existing.error) {
    throw fromSupabaseError(
      existing.error,
      'startConnectorSetup',
      'puls_integration',
      'erp_connections',
    )
  }

  const existingConnection =
    (existing.data as {
      id?: string
      setup_status?: ConnectorSetupStatus | null
      setup_step?: ConnectorSetupCurrentStep | null
    } | null) ?? null
  const existingId = existingConnection?.id ?? null
  if (existingId && existingConnection?.setup_status !== 'draft') {
    return {
      connectionId: existingId,
      providerId: input.providerId,
      setupStatus: existingConnection?.setup_status ?? 'draft',
      currentStep: existingConnection?.setup_step ?? 'mapping',
    }
  }

  const now = new Date().toISOString()
  const payload = {
    tenant_id: ctx.tenantId,
    provider: config.provider,
    display_name: config.displayName,
    connection_method: config.connectionMethod,
    is_active: false,
    sync_direction: 'erp_to_puls',
    connection_key: config.connectionKey,
    setup_status: 'draft',
    setup_step: 'mapping',
    is_enabled: true,
    selected_at: now,
    setup_started_at: now,
    owned_domains: config.ownedDomains,
    setup_metadata: {
      source_type: config.sourceType,
      runtime_boundary: 'closed',
      credential_boundary: 'reference_only_future',
      source_ownership: 'domain_level',
    },
    updated_by_employee_id: ctx.employeeId,
  }

  const write = existingId
    ? await pulsIntegration()
        .from('erp_connections')
        .update(payload)
        .eq('id', existingId)
        .select('id')
        .single()
    : await pulsIntegration()
        .from('erp_connections')
        .insert({ ...payload, created_by_employee_id: ctx.employeeId })
        .select('id')
        .single()

  if (write.error) {
    throw fromSupabaseError(
      write.error,
      'startConnectorSetup',
      'puls_integration',
      'erp_connections',
    )
  }

  const connectionId = (write.data?.id as string | undefined) ?? existingId ?? ''
  const hasMappingContract = await ensureDefaultConnectorFieldMappings({
    tenantId: ctx.tenantId,
    connectionId,
    providerId: input.providerId,
  })

  if (hasMappingContract) {
    const promote = await pulsIntegration()
      .from('erp_connections')
      .update({
        setup_status: 'mapping_ready',
        setup_step: 'namespace',
        updated_by_employee_id: ctx.employeeId,
      })
      .eq('id', connectionId)
      .select('id')
      .single()

    if (promote.error) {
      throw fromSupabaseError(
        promote.error,
        'startConnectorSetup',
        'puls_integration',
        'erp_connections',
      )
    }
  }

  return {
    connectionId,
    providerId: input.providerId,
    setupStatus: hasMappingContract ? 'mapping_ready' : 'draft',
    currentStep: hasMappingContract ? 'namespace' : 'mapping',
  }
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
