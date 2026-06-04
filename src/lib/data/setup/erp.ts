import { fetchDemoErpOverview } from '#/lib/demo/puls-demo-data'
import { pulsCalc, pulsIntegration, resolveTenantContext } from '#/lib/data/client'
import {
  DataAdapterError,
  fromSupabaseError,
  isDataAdapterError,
  parseRpcErrorCode,
} from '#/lib/data/errors'
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
export type ConnectorAuthMode =
  | 'none'
  | 'api_key'
  | 'basic_auth'
  | 'bearer_token'
  | 'oauth2_client_credentials'
  | 'sftp_password'
  | 'connection_string'
  | 'custom_secret_ref'
export type ConnectorCredentialState =
  | 'not_required'
  | 'missing'
  | 'configured'
  | 'verified'
  | 'failed'
  | 'revoked'
export type ConnectorCredentialHandoffStatus =
  | 'not_required'
  | 'not_started'
  | 'requested'
  | 'reference_pending'
  | 'ready_for_verification'
  | 'verified'
  | 'failed'
  | 'revoked'
export type ConnectorCredentialHandoffAction =
  | 'none'
  | 'complete_setup_first'
  | 'request_secure_reference'
  | 'handoff_requested'
  | 'await_reference'
  | 'verify_reference'
  | 'review_failure'
  | 'restore_access'
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
export type ConnectorSyncLogLevel = 'success' | 'warning' | 'error' | 'info'
export type ConnectorSetupStepId = 'source' | 'mapping' | 'namespace' | 'preflight' | 'runtime'
export type ConnectorLifecycleStage =
  | 'source_selection'
  | 'mapping'
  | 'namespace'
  | 'credential'
  | 'preflight'
  | 'runtime_closed'
  | 'connected'
  | 'disabled'
  | 'error'
export type ConnectorCanonicalDataClassId =
  | 'employees'
  | 'departments'
  | 'positions'
  | 'cost_centers'
  | 'locations'
export type ConnectorSourceCapabilityId =
  | 'source_profile'
  | 'domain_ownership'
  | 'canonical_mapping'
  | 'identity_namespace'
  | 'credential_reference'
  | 'transfer_method'
  | 'api_runtime'
  | 'writeback'
export type ConnectorDomainOwnershipStatus = 'owned_by_current' | 'owned_by_other' | 'available'
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

export type ConnectorLifecycle = {
  stage: ConnectorLifecycleStage
  status: ConnectorReadinessStatus
  labelKey: string
  descriptionKey: string
  nextActionKey: string
  runtimeEligible: false
}

export type ConnectorSourceCapability = {
  id: ConnectorSourceCapabilityId
  labelKey: string
  descriptionKey: string
  status: ConnectorReadinessStatus
}

export type ConnectorDomainOwnership = {
  id: ConnectorCanonicalDataClassId
  labelKey: string
  pulsTarget: string
  status: ConnectorDomainOwnershipStatus
  ownerProviderCode: string | null
  ownerProviderLabel: string | null
  ownerConnectionId: string | null
  mappedFields: number
  totalFields: number
}

export type ConnectorProviderRequirement = {
  id:
    | 'source_profile'
    | 'canonical_mapping'
    | 'source_namespace'
    | 'identity_strategy'
    | 'credential_boundary'
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
    | 'credential_boundary'
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

export type ConnectorCredentialBoundary = {
  authMode: ConnectorAuthMode
  required: boolean
  state: ConnectorCredentialState
  status: ConnectorReadinessStatus
  statusLabelKey: string
  descriptionKey: string
  lastVerifiedAt: string | null
  lastFailedAt: string | null
  errorCode: string | null
}

export type ConnectorCredentialHandoff = {
  status: ConnectorCredentialHandoffStatus
  action: ConnectorCredentialHandoffAction
  readiness: ConnectorReadinessStatus
  requestable: boolean
  blockedBy: 'none' | 'mapping' | 'namespace' | 'identity' | 'not_required' | 'verified'
  statusLabelKey: string
  descriptionKey: string
  actionLabelKey: string
  actionDescriptionKey: string
  requestedAt: string | null
  requestedByEmployeeId: string | null
  updatedAt: string | null
  captureBoundary: 'server_side_write_only'
}

export type ConnectorImportPreviewStatus =
  | 'not_available'
  | 'no_batch'
  | 'ready_to_preview'
  | 'preview_ready'
  | 'blocked'

export type ConnectorImportPreviewAction =
  | 'none'
  | 'complete_setup_first'
  | 'run_dry_run_preview'
  | 'review_errors'
  | 'review_preview'

export type ConnectorImportPreviewBatchStatus =
  | 'uploaded'
  | 'normalized'
  | 'validated'
  | 'previewed'
  | 'applied'
  | 'failed'
  | 'cancelled'

export type ConnectorImportPreviewRecordStatus =
  | 'pending'
  | 'validated'
  | 'error'
  | 'applied'
  | 'skipped'

export type ConnectorImportPreviewRecordAction = 'create' | 'update' | 'skip' | null

export type ConnectorImportPreviewBatch = {
  id: string
  sourceNamespaceId: string
  sourceNamespaceCode: string
  status: ConnectorImportPreviewBatchStatus
  mode: 'dry_run' | 'apply'
  rowCount: number
  createCount: number
  updateCount: number
  skipCount: number
  errorCount: number
  violationCount: number
  sourceChecksum: string | null
  validatedAt: string | null
  previewedAt: string | null
  createdAt: string | null
  updatedAt: string | null
}

export type ConnectorImportPreviewRecord = {
  id: string
  rowNumber: number
  entityType: string
  externalId: string
  status: ConnectorImportPreviewRecordStatus
  action: ConnectorImportPreviewRecordAction
  skipCode: string | null
  errorCodes: string[]
  warningCodes: string[]
  canonicalId: string | null
  previewedAt: string | null
}

export type ConnectorImportPreviewSummary = {
  rowCount: number
  createCount: number
  updateCount: number
  skipCount: number
  errorCount: number
  warningCount: number
}

export type ConnectorImportPreview = {
  status: ConnectorImportPreviewStatus
  readiness: ConnectorReadinessStatus
  statusLabelKey: string
  descriptionKey: string
  action: ConnectorImportPreviewAction
  actionLabelKey: string
  actionDescriptionKey: string
  batch: ConnectorImportPreviewBatch | null
  records: ConnectorImportPreviewRecord[]
  summary: ConnectorImportPreviewSummary
  safeToApply: false
}

export type ConnectorApplyReadinessStatus =
  | 'not_available'
  | 'needs_preview'
  | 'review_ready'
  | 'review_requested'
  | 'blocked'

export type ConnectorApplyReadinessAction =
  | 'none'
  | 'run_preview_first'
  | 'request_human_review'
  | 'review_requested'
  | 'resolve_blockers'

export type ConnectorApplyReadinessBlockerId =
  | 'no_connector'
  | 'no_batch'
  | 'preview_required'
  | 'row_errors'
  | 'credential_not_verified'
  | 'dry_run_only'
  | 'apply_execution_closed'

export type ConnectorApplyReadinessCheckId =
  | 'preview_classification'
  | 'row_findings'
  | 'credential_reference'
  | 'human_review'
  | 'execution_boundary'

export type ConnectorApplyReadinessCheck = {
  id: ConnectorApplyReadinessCheckId
  labelKey: string
  descriptionKey: string
  status: ConnectorReadinessStatus
  valueKey: string
}

export type ConnectorApplyReadinessBlocker = {
  id: ConnectorApplyReadinessBlockerId
  labelKey: string
  descriptionKey: string
}

export type ConnectorApplyReadiness = {
  status: ConnectorApplyReadinessStatus
  readiness: ConnectorReadinessStatus
  statusLabelKey: string
  descriptionKey: string
  action: ConnectorApplyReadinessAction
  actionLabelKey: string
  actionDescriptionKey: string
  requestable: boolean
  safeToApply: false
  reviewRequestedAt: string | null
  reviewRequestedByEmployeeId: string | null
  batchId: string | null
  summary: {
    rowCount: number
    createCount: number
    updateCount: number
    skipCount: number
    errorCount: number
    warningCount: number
    blockerCount: number
  }
  blockers: ConnectorApplyReadinessBlocker[]
  checks: ConnectorApplyReadinessCheck[]
}

export type ConnectorControlledApplyPlanStatus =
  | 'not_available'
  | 'needs_preview'
  | 'needs_review'
  | 'design_ready'
  | 'approval_recorded'
  | 'blocked'

export type ConnectorControlledApplyGateId =
  | 'preview_ready'
  | 'human_review'
  | 'source_checksum'
  | 'approval_policy'
  | 'batch_lock'
  | 'rollback_strategy'
  | 'audit_trail'
  | 'notification_plan'
  | 'runtime_credentials'
  | 'execution_boundary'

export type ConnectorControlledApplyGate = {
  id: ConnectorControlledApplyGateId
  labelKey: string
  descriptionKey: string
  status: ConnectorReadinessStatus
  valueKey: string
}

export type ConnectorControlledApplyPlan = {
  status: ConnectorControlledApplyPlanStatus
  readiness: ConnectorReadinessStatus
  statusLabelKey: string
  descriptionKey: string
  executionOpen: false
  applyRpcExposed: false
  batchId: string | null
  sourceChecksum: string | null
  gates: ConnectorControlledApplyGate[]
  summary: {
    readyCount: number
    partialCount: number
    blockedCount: number
  }
}

export type ConnectorApplyExecutionContractStatus =
  | 'not_available'
  | 'needs_approval'
  | 'contract_ready'
  | 'blocked'

export type ConnectorApplyExecutionControlId =
  | 'dry_run_only'
  | 'idempotency_key'
  | 'admin_approval'
  | 'batch_lock'
  | 'rollback_plan'
  | 'notification_plan'
  | 'execution_boundary'

export type ConnectorApplyExecutionControl = {
  id: ConnectorApplyExecutionControlId
  labelKey: string
  descriptionKey: string
  status: ConnectorReadinessStatus
  valueKey: string
}

export type ConnectorApplyExecutionContract = {
  status: ConnectorApplyExecutionContractStatus
  readiness: ConnectorReadinessStatus
  statusLabelKey: string
  descriptionKey: string
  contractVersion: 'pr14.20-closed-apply-contract-v1'
  executionEnabled: false
  canonicalWriteEnabled: false
  sourceWritebackEnabled: false
  credentialReadbackEnabled: false
  applyRpcExposed: false
  safeToExecute: false
  executorMode: 'future_background_job'
  batchId: string | null
  sourceChecksum: string | null
  sourceNamespaceCode: string | null
  controls: ConnectorApplyExecutionControl[]
  summary: {
    readyCount: number
    partialCount: number
    blockedCount: number
  }
}

export type ConnectorApplyApprovalPolicyStatus =
  | 'not_available'
  | 'needs_review'
  | 'admin_only'
  | 'approval_recorded'
  | 'blocked'

export type ConnectorApplyApprovalPolicyAction =
  | 'none'
  | 'run_review_first'
  | 'record_admin_approval'
  | 'approval_recorded'
  | 'resolve_blockers'

export type ConnectorApplyApprovalPolicy = {
  status: ConnectorApplyApprovalPolicyStatus
  readiness: ConnectorReadinessStatus
  statusLabelKey: string
  descriptionKey: string
  action: ConnectorApplyApprovalPolicyAction
  actionLabelKey: string
  actionDescriptionKey: string
  approverRoleKey: string
  requestable: boolean
  safeToApply: false
  approvalRecordedAt: string | null
  approvalRecordedByEmployeeId: string | null
  batchId: string | null
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
  messageKey?: string
  detail?: string
  kind:
    | 'setup_lifecycle'
    | 'setup_preflight'
    | 'credential_handoff'
    | 'import_preview'
    | 'import_apply_review'
    | 'sync_batch'
}

export type ConnectorActivityEventKind =
  | 'setup_lifecycle'
  | 'setup_preflight'
  | 'credential_handoff'
  | 'import_preview'
  | 'import_apply_review'
  | 'sync_batch'

export type ConnectorActivityDetail = {
  labelKey: string
  value: string | number | boolean
}

export type ConnectorActivityEvent = {
  id: string
  at: string
  level: ConnectorSyncLogLevel
  kind: ConnectorActivityEventKind
  titleKey: string
  summaryKey: string
  detailItems: ConnectorActivityDetail[]
  safeErrorCode: string | null
  safeErrorSummaryKey: string | null
  nextActionKey: string
  actorLabelKey: string
  rawStatus: string
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
  lifecycle: ConnectorLifecycle
  setupSummary: ConnectorSetupSummary
  setupSteps: ConnectorSetupStep[]
  preflight: ConnectorPreflightResult
  credentialBoundary: ConnectorCredentialBoundary
  credentialHandoff: ConnectorCredentialHandoff
  importPreview: ConnectorImportPreview
  applyReadiness: ConnectorApplyReadiness
  applyApprovalPolicy: ConnectorApplyApprovalPolicy
  controlledApplyPlan: ConnectorControlledApplyPlan
  applyExecutionContract: ConnectorApplyExecutionContract
  capabilities: ConnectorSourceCapability[]
  domainOwnership: ConnectorDomainOwnership[]
  canonicalClasses: ConnectorCanonicalDataClass[]
  mappings: ConnectorFieldMapping[]
  namespaces: ConnectorNamespaceSummary[]
  transferModes: ConnectorTransferMode[]
  guardrails: ConnectorGuardrail[]
  providerOptions: ConnectorProviderOption[]
  syncLogs: ConnectorSyncLog[]
  activityTimeline: ConnectorActivityEvent[]
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
  connection_method?: string | null
  is_active?: boolean | null
  last_sync_at?: string | null
  last_status?: string | null
  setup_status?: ConnectorSetupStatus | null
  setup_step?: ConnectorSetupCurrentStep | null
  is_enabled?: boolean | null
  owned_domains?: string[] | null
  selected_at?: string | null
  setup_started_at?: string | null
  auth_mode?: ConnectorAuthMode | null
  credential_required?: boolean | null
  credential_state?: ConnectorCredentialState | null
  credential_last_verified_at?: string | null
  credential_last_failed_at?: string | null
  credential_error_code?: string | null
  credential_handoff_status?: ConnectorCredentialHandoffStatus | null
  credential_handoff_requested_at?: string | null
  credential_handoff_requested_by_employee_id?: string | null
  credential_handoff_updated_at?: string | null
  connection_key?: string | null
  created_at?: string | null
  updated_at?: string | null
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
  event_key?: string | null
  actor_employee_id?: string | null
  safe_error_code?: string | null
  safe_error_context?: Record<string, unknown> | null
  next_action_key?: string | null
  records_seen?: number | null
  records_inserted?: number | null
  records_updated?: number | null
  records_failed?: number | null
}

type SourceNamespaceRow = {
  id?: string | null
  code?: string | null
  name?: string | null
  source_type?: string | null
  connection_id?: string | null
}

type EntityIdentityRow = {
  source_namespace_id?: string | null
  canonical_table?: string | null
}

type ImportBatchRow = {
  id?: string | null
  source_namespace_id?: string | null
  status?: ConnectorImportPreviewBatchStatus | null
  mode?: 'dry_run' | 'apply' | null
  source_checksum?: string | null
  row_count?: number | null
  create_count?: number | null
  update_count?: number | null
  skip_count?: number | null
  error_count?: number | null
  violation_count?: number | null
  validated_at?: string | null
  previewed_at?: string | null
  created_at?: string | null
  updated_at?: string | null
}

type ImportPreviewRecordRow = {
  id?: string | null
  row_number?: number | null
  entity_type?: string | null
  external_id?: string | null
  status?: ConnectorImportPreviewRecordStatus | null
  error_codes?: string[] | null
  warning_codes?: string[] | null
  canonical_id?: string | null
  preview_action?: ConnectorImportPreviewRecordAction | null
  preview_skip_code?: string | null
  previewed_at?: string | null
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

export type RunConnectorPreflightResult = {
  connectionId: string
  status: ConnectorReadinessStatus
  passedCount: number
  warningCount: number
  blockedCount: number
}

export type RequestConnectorCredentialHandoffResult = {
  connectionId: string
  status: ConnectorCredentialHandoffStatus
  requestedAt: string | null
}

export type RunConnectorImportPreviewResult = {
  connectionId: string
  batchId: string
  status: ConnectorImportPreviewStatus
  rowCount: number
  createCount: number
  updateCount: number
  skipCount: number
  errorCount: number
}

export type RequestConnectorApplyReviewResult = {
  connectionId: string
  batchId: string
  status: ConnectorApplyReadinessStatus
  requestedAt: string | null
  safeToApply: false
}

export type RecordConnectorApplyApprovalResult = {
  connectionId: string
  batchId: string
  status: ConnectorApplyApprovalPolicyStatus
  approvalRecordedAt: string | null
  safeToApply: false
}

export type ConnectorSetupErrorMapping = {
  code:
    | 'missing_tenant'
    | 'admin_required'
    | 'provider_unavailable'
    | 'source_missing'
    | 'credential_handoff_blocked'
    | 'import_batch_missing'
    | 'import_preview_blocked'
    | 'apply_review_blocked'
    | 'apply_approval_blocked'
    | 'permission_denied'
    | 'domain_owned'
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
      authMode: ConnectorAuthMode
      credentialRequired: boolean
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
    authMode: 'custom_secret_ref',
    credentialRequired: true,
    connectionKey: 'canias-default',
    ownedDomains: ['employees', 'departments', 'positions', 'cost_centers'],
    sourceType: 'erp',
  },
  csv_import: {
    provider: 'csv',
    displayName: 'CSV / Excel',
    connectionMethod: 'manual_import',
    authMode: 'none',
    credentialRequired: false,
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
    if (error.code === 'PULS_CONNECTOR_SOURCE_REQUIRED') {
      return { code: 'source_missing', toastKey: 'erp.errors.sourceMissing' }
    }
    if (error.code === 'PULS_CONNECTOR_CREDENTIAL_HANDOFF_BLOCKED') {
      return {
        code: 'credential_handoff_blocked',
        toastKey: 'erp.errors.credentialHandoffBlocked',
      }
    }
    if (error.code === 'PULS_CONNECTOR_IMPORT_BATCH_REQUIRED') {
      return { code: 'import_batch_missing', toastKey: 'erp.errors.importBatchMissing' }
    }
    if (
      error.code === 'PULS_CONNECTOR_IMPORT_PREVIEW_BLOCKED' ||
      error.code === 'PULS_IMPORT_BATCH_STATE_INVALID'
    ) {
      return { code: 'import_preview_blocked', toastKey: 'erp.errors.importPreviewBlocked' }
    }
    if (error.code === 'PULS_CONNECTOR_APPLY_REVIEW_BLOCKED') {
      return { code: 'apply_review_blocked', toastKey: 'erp.errors.applyReviewBlocked' }
    }
    if (error.code === 'PULS_CONNECTOR_APPLY_APPROVAL_BLOCKED') {
      return { code: 'apply_approval_blocked', toastKey: 'erp.errors.applyApprovalBlocked' }
    }
    if (error.code === 'PULS_CONNECTOR_DOMAIN_OWNED') {
      return { code: 'domain_owned', toastKey: 'erp.errors.domainOwned' }
    }
    if (error.code === '42501') {
      return { code: 'permission_denied', toastKey: 'erp.errors.permissionDenied' }
    }
  }

  return { code: 'save_failed', toastKey: 'erp.errors.setupSaveFailed' }
}

function fromConnectorRpcError(
  error: { code?: string | null; message?: string },
  operation: string,
) {
  const message = error.message ?? 'Connector RPC failed'
  const code = parseRpcErrorCode(message) ?? error.code ?? 'PULS_CONNECTOR_RPC_FAILED'
  return new DataAdapterError({
    code,
    message,
    source: 'rpc',
    operation,
    schema: 'puls_integration',
    i18nKey:
      code === 'PULS_IMPORT_BATCH_STATE_INVALID'
        ? 'erp.errors.importPreviewBlocked'
        : 'erp.errors.setupSaveFailed',
  })
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
        id: 'credential_boundary',
        labelKey: 'erp.providerRequirements.credentialBoundary.label',
        descriptionKey: 'erp.providerRequirements.credentialBoundary.description',
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
        id: 'credential_boundary',
        labelKey: 'erp.providerRequirements.credentialBoundary.label',
        descriptionKey: 'erp.providerRequirements.credentialBoundary.description',
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
        id: 'credential_boundary',
        labelKey: 'erp.providerRequirements.credentialBoundary.label',
        descriptionKey: 'erp.providerRequirements.credentialBoundary.description',
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
        id: 'credential_boundary',
        labelKey: 'erp.providerRequirements.credentialBoundary.label',
        descriptionKey: 'erp.providerRequirements.credentialBoundary.description',
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

const SETUP_STATUS_RANK: Record<ConnectorSetupStatus, number> = {
  connected: 80,
  preflight_ready: 70,
  mapping_ready: 60,
  setup_in_progress: 50,
  draft: 40,
  error: 20,
  disabled: 10,
  archived: 0,
}

type ErpConnectionCandidate = Pick<
  ErpConnectionRow,
  | 'id'
  | 'provider'
  | 'display_name'
  | 'connection_method'
  | 'connection_key'
  | 'setup_status'
  | 'setup_step'
  | 'is_enabled'
  | 'owned_domains'
  | 'created_at'
  | 'updated_at'
>

function normalizeOwnedDomains(domains: string[] | null | undefined): string[] {
  return Array.isArray(domains) ? domains.map((domain) => domain.trim()).filter(Boolean) : []
}

function connectionUpdatedAt(connection: ErpConnectionCandidate): number {
  const timestamp = connection.updated_at ?? connection.created_at
  return timestamp ? new Date(timestamp).getTime() || 0 : 0
}

export function hasConnectorDomainOverlap(
  first: string[] | null | undefined,
  second: string[] | null | undefined,
): boolean {
  const firstDomains = normalizeOwnedDomains(first)
  const secondDomains = new Set(normalizeOwnedDomains(second))
  if (firstDomains.length === 0 || secondDomains.size === 0) return false
  return firstDomains.some((domain) => secondDomains.has(domain))
}

export function pickCurrentErpConnection<T extends ErpConnectionCandidate>(
  connections: T[],
): T | null {
  const candidates = connections.filter((connection) => connection.setup_status !== 'archived')
  if (candidates.length === 0) return null

  return [...candidates].sort((left, right) => {
    const leftEnabled = left.is_enabled === false ? 0 : 1
    const rightEnabled = right.is_enabled === false ? 0 : 1
    if (leftEnabled !== rightEnabled) return rightEnabled - leftEnabled

    const leftRank = SETUP_STATUS_RANK[left.setup_status ?? 'draft'] ?? 0
    const rightRank = SETUP_STATUS_RANK[right.setup_status ?? 'draft'] ?? 0
    if (leftRank !== rightRank) return rightRank - leftRank

    return connectionUpdatedAt(right) - connectionUpdatedAt(left)
  })[0]
}

function defaultAuthModeForMethod(method: string | null | undefined): ConnectorAuthMode {
  if (method === 'manual_import') return 'none'
  if (method === 'file_drop') return 'sftp_password'
  return 'custom_secret_ref'
}

function deriveCredentialStatus({
  hasConnection,
  required,
  state,
}: {
  hasConnection: boolean
  required: boolean
  state: ConnectorCredentialState
}): ConnectorReadinessStatus {
  if (!hasConnection) return 'blocked'
  if (!required || state === 'not_required' || state === 'verified') return 'ready'
  if (state === 'missing' || state === 'configured') return 'partial'
  return 'blocked'
}

function buildConnectorCredentialBoundary({
  hasConnection,
  connectionMethod,
  authMode,
  credentialRequired,
  credentialState,
  lastVerifiedAt,
  lastFailedAt,
  errorCode,
}: {
  hasConnection: boolean
  connectionMethod?: string | null
  authMode?: ConnectorAuthMode | null
  credentialRequired?: boolean | null
  credentialState?: ConnectorCredentialState | null
  lastVerifiedAt?: string | null
  lastFailedAt?: string | null
  errorCode?: string | null
}): ConnectorCredentialBoundary {
  const resolvedAuthMode = hasConnection
    ? (authMode ?? defaultAuthModeForMethod(connectionMethod))
    : 'none'
  const required = hasConnection ? (credentialRequired ?? resolvedAuthMode !== 'none') : false
  const state: ConnectorCredentialState = !hasConnection
    ? 'missing'
    : (credentialState ?? (required ? 'missing' : 'not_required'))
  const status = deriveCredentialStatus({ hasConnection, required, state })

  return {
    authMode: resolvedAuthMode,
    required,
    state,
    status,
    statusLabelKey: `erp.credentialBoundary.states.${state}`,
    descriptionKey: `erp.credentialBoundary.descriptions.${state}`,
    lastVerifiedAt: lastVerifiedAt ?? null,
    lastFailedAt: lastFailedAt ?? null,
    errorCode: errorCode ?? null,
  }
}

function deriveCredentialHandoffStatus({
  credentialBoundary,
  handoffStatus,
}: {
  credentialBoundary: ConnectorCredentialBoundary
  handoffStatus?: ConnectorCredentialHandoffStatus | null
}): ConnectorCredentialHandoffStatus {
  if (!credentialBoundary.required || credentialBoundary.state === 'not_required') {
    return 'not_required'
  }
  if (credentialBoundary.state === 'verified') return 'verified'
  if (credentialBoundary.state === 'configured') return 'ready_for_verification'
  if (credentialBoundary.state === 'failed') return 'failed'
  if (credentialBoundary.state === 'revoked') return 'revoked'
  return handoffStatus ?? 'not_started'
}

function buildConnectorCredentialHandoff({
  connectorState,
  credentialBoundary,
  mappedFields,
  totalFields,
  namespaceCount,
  identityCount,
  handoffStatus,
  requestedAt,
  requestedByEmployeeId,
  updatedAt,
}: {
  connectorState: ConnectorLifecycleState
  credentialBoundary: ConnectorCredentialBoundary
  mappedFields: number
  totalFields: number
  namespaceCount: number
  identityCount: number
  handoffStatus?: ConnectorCredentialHandoffStatus | null
  requestedAt?: string | null
  requestedByEmployeeId?: string | null
  updatedAt?: string | null
}): ConnectorCredentialHandoff {
  const status = deriveCredentialHandoffStatus({ credentialBoundary, handoffStatus })
  const hasConnection = connectorState === 'connector_selected'
  const mappingReady = hasConnection && totalFields > 0 && mappedFields >= totalFields
  const namespaceReady = namespaceCount > 0
  const identityReady = identityCount > 0

  const handoff = (
    action: ConnectorCredentialHandoffAction,
    readiness: ConnectorReadinessStatus,
    blockedBy: ConnectorCredentialHandoff['blockedBy'],
    requestable = false,
  ): ConnectorCredentialHandoff => ({
    status,
    action,
    readiness,
    requestable,
    blockedBy,
    statusLabelKey: `erp.credentialHandoff.status.${status}`,
    descriptionKey: `erp.credentialHandoff.descriptions.${status}`,
    actionLabelKey: `erp.credentialHandoff.actions.${action}.label`,
    actionDescriptionKey: `erp.credentialHandoff.actions.${action}.description`,
    requestedAt: requestedAt ?? null,
    requestedByEmployeeId: requestedByEmployeeId ?? null,
    updatedAt: updatedAt ?? null,
    captureBoundary: 'server_side_write_only',
  })

  if (!hasConnection) return handoff('complete_setup_first', 'blocked', 'mapping')
  if (status === 'not_required') return handoff('none', 'ready', 'not_required')
  if (status === 'verified') return handoff('none', 'ready', 'verified')
  if (!mappingReady) return handoff('complete_setup_first', 'blocked', 'mapping')
  if (!namespaceReady) return handoff('complete_setup_first', 'blocked', 'namespace')
  if (!identityReady) return handoff('complete_setup_first', 'blocked', 'identity')
  if (status === 'requested') return handoff('handoff_requested', 'partial', 'none')
  if (status === 'reference_pending') return handoff('await_reference', 'partial', 'none')
  if (status === 'ready_for_verification') return handoff('verify_reference', 'partial', 'none')
  if (status === 'failed') return handoff('review_failure', 'blocked', 'none')
  if (status === 'revoked') return handoff('restore_access', 'blocked', 'none')
  return handoff('request_secure_reference', 'partial', 'none', true)
}

function emptyConnectorImportPreview(
  connectorState: ConnectorLifecycleState,
): ConnectorImportPreview {
  const status: ConnectorImportPreviewStatus =
    connectorState === 'connector_selected' ? 'no_batch' : 'not_available'
  const action: ConnectorImportPreviewAction =
    connectorState === 'connector_selected' ? 'none' : 'complete_setup_first'
  const readiness: ConnectorReadinessStatus =
    connectorState === 'connector_selected' ? 'partial' : 'blocked'

  return {
    status,
    readiness,
    statusLabelKey: `erp.importPreview.status.${status}`,
    descriptionKey: `erp.importPreview.descriptions.${status}`,
    action,
    actionLabelKey: `erp.importPreview.actions.${action}.label`,
    actionDescriptionKey: `erp.importPreview.actions.${action}.description`,
    batch: null,
    records: [],
    summary: {
      rowCount: 0,
      createCount: 0,
      updateCount: 0,
      skipCount: 0,
      errorCount: 0,
      warningCount: 0,
    },
    safeToApply: false,
  }
}

function buildConnectorImportPreview({
  connectorState,
  batch,
  records,
  namespaceCodeById,
}: {
  connectorState: ConnectorLifecycleState
  batch: ImportBatchRow | null
  records: ImportPreviewRecordRow[]
  namespaceCodeById: Record<string, string>
}): ConnectorImportPreview {
  if (!batch?.id || !batch.source_namespace_id) {
    return emptyConnectorImportPreview(connectorState)
  }

  const normalizedRecords: ConnectorImportPreviewRecord[] = records.map((row, index) => ({
    id: row.id ?? `preview-record-${index}`,
    rowNumber: Number(row.row_number ?? index + 1),
    entityType: row.entity_type ?? 'unknown',
    externalId: row.external_id ?? '—',
    status: row.status ?? 'pending',
    action: row.preview_action ?? null,
    skipCode: row.preview_skip_code ?? null,
    errorCodes: Array.isArray(row.error_codes) ? row.error_codes : [],
    warningCodes: Array.isArray(row.warning_codes) ? row.warning_codes : [],
    canonicalId: row.canonical_id ?? null,
    previewedAt: row.previewed_at ?? null,
  }))

  const errorCount = Math.max(
    Number(batch.error_count ?? 0),
    normalizedRecords.filter((record) => record.status === 'error').length,
  )
  const warningCount = normalizedRecords.filter((record) => record.warningCodes.length > 0).length
  const status: ConnectorImportPreviewStatus =
    errorCount > 0
      ? 'blocked'
      : batch.status === 'previewed'
        ? 'preview_ready'
        : batch.status === 'uploaded' ||
            batch.status === 'normalized' ||
            batch.status === 'validated'
          ? 'ready_to_preview'
          : 'blocked'
  const action: ConnectorImportPreviewAction =
    status === 'ready_to_preview'
      ? 'run_dry_run_preview'
      : status === 'blocked'
        ? 'review_errors'
        : status === 'preview_ready'
          ? 'review_preview'
          : 'none'
  const readiness: ConnectorReadinessStatus =
    status === 'preview_ready' ? 'ready' : status === 'blocked' ? 'blocked' : 'partial'

  return {
    status,
    readiness,
    statusLabelKey: `erp.importPreview.status.${status}`,
    descriptionKey: `erp.importPreview.descriptions.${status}`,
    action,
    actionLabelKey: `erp.importPreview.actions.${action}.label`,
    actionDescriptionKey: `erp.importPreview.actions.${action}.description`,
    batch: {
      id: batch.id,
      sourceNamespaceId: batch.source_namespace_id,
      sourceNamespaceCode: namespaceCodeById[batch.source_namespace_id] ?? '—',
      status: batch.status ?? 'uploaded',
      mode: batch.mode ?? 'dry_run',
      rowCount: Number(batch.row_count ?? normalizedRecords.length),
      createCount: Number(batch.create_count ?? 0),
      updateCount: Number(batch.update_count ?? 0),
      skipCount: Number(batch.skip_count ?? 0),
      errorCount: Number(batch.error_count ?? 0),
      violationCount: Number(batch.violation_count ?? 0),
      sourceChecksum: batch.source_checksum ?? null,
      validatedAt: batch.validated_at ?? null,
      previewedAt: batch.previewed_at ?? null,
      createdAt: batch.created_at ?? null,
      updatedAt: batch.updated_at ?? null,
    },
    records: normalizedRecords,
    summary: {
      rowCount: Number(batch.row_count ?? normalizedRecords.length),
      createCount: Number(batch.create_count ?? 0),
      updateCount: Number(batch.update_count ?? 0),
      skipCount: Number(batch.skip_count ?? 0),
      errorCount,
      warningCount,
    },
    safeToApply: false,
  }
}

function eventIsAtOrAfter(value: string | null | undefined, baseline: string | null | undefined) {
  if (!value || !baseline) return false
  const eventTime = Date.parse(value)
  const baselineTime = Date.parse(baseline)
  return Number.isFinite(eventTime) && Number.isFinite(baselineTime) && eventTime >= baselineTime
}

function buildConnectorApplyReadiness({
  connectorState,
  importPreview,
  credentialBoundary,
  reviewEvent,
}: {
  connectorState: ConnectorLifecycleState
  importPreview: ConnectorImportPreview
  credentialBoundary: ConnectorCredentialBoundary
  reviewEvent: ErpSyncBatchRow | null
}): ConnectorApplyReadiness {
  const batch = importPreview.batch
  const previewReady = Boolean(batch?.id && importPreview.status === 'preview_ready')
  const freshReviewEvent =
    previewReady && eventIsAtOrAfter(reviewEvent?.created_at, batch?.previewedAt)
      ? reviewEvent
      : null
  const credentialReady =
    !credentialBoundary.required ||
    credentialBoundary.state === 'verified' ||
    credentialBoundary.state === 'not_required'
  const blockers: ConnectorApplyReadinessBlockerId[] = []

  if (connectorState !== 'connector_selected') {
    blockers.push('no_connector')
  } else if (!batch?.id) {
    blockers.push('no_batch')
  } else if (!previewReady) {
    blockers.push(importPreview.summary.errorCount > 0 ? 'row_errors' : 'preview_required')
  }

  if (importPreview.summary.errorCount > 0 && !blockers.includes('row_errors')) {
    blockers.push('row_errors')
  }
  if (previewReady && !credentialReady) blockers.push('credential_not_verified')
  if (batch?.mode === 'dry_run') blockers.push('dry_run_only')
  if (previewReady) blockers.push('apply_execution_closed')

  const status: ConnectorApplyReadinessStatus =
    connectorState !== 'connector_selected'
      ? 'not_available'
      : !batch?.id
        ? 'not_available'
        : importPreview.summary.errorCount > 0
          ? 'blocked'
          : !previewReady
            ? 'needs_preview'
            : freshReviewEvent
              ? 'review_requested'
              : 'review_ready'
  const readiness: ConnectorReadinessStatus =
    status === 'blocked'
      ? 'blocked'
      : status === 'not_available' || status === 'needs_preview'
        ? 'partial'
        : 'partial'
  const action: ConnectorApplyReadinessAction =
    status === 'needs_preview'
      ? 'run_preview_first'
      : status === 'blocked'
        ? 'resolve_blockers'
        : status === 'review_ready'
          ? 'request_human_review'
          : status === 'review_requested'
            ? 'review_requested'
            : 'none'

  const check = (
    id: ConnectorApplyReadinessCheckId,
    statusValue: ConnectorReadinessStatus,
    valueKey: string,
  ): ConnectorApplyReadinessCheck => ({
    id,
    labelKey: `erp.applyReadiness.checks.${id}.label`,
    descriptionKey: `erp.applyReadiness.checks.${id}.description`,
    status: statusValue,
    valueKey,
  })

  return {
    status,
    readiness,
    statusLabelKey: `erp.applyReadiness.status.${status}`,
    descriptionKey: `erp.applyReadiness.descriptions.${status}`,
    action,
    actionLabelKey: `erp.applyReadiness.actions.${action}.label`,
    actionDescriptionKey: `erp.applyReadiness.actions.${action}.description`,
    requestable: status === 'review_ready',
    safeToApply: false,
    reviewRequestedAt: freshReviewEvent?.created_at ?? null,
    reviewRequestedByEmployeeId: freshReviewEvent?.actor_employee_id ?? null,
    batchId: batch?.id ?? null,
    summary: {
      rowCount: importPreview.summary.rowCount,
      createCount: importPreview.summary.createCount,
      updateCount: importPreview.summary.updateCount,
      skipCount: importPreview.summary.skipCount,
      errorCount: importPreview.summary.errorCount,
      warningCount: importPreview.summary.warningCount,
      blockerCount: blockers.length,
    },
    blockers: blockers.map((id) => ({
      id,
      labelKey: `erp.applyReadiness.blockers.${id}.label`,
      descriptionKey: `erp.applyReadiness.blockers.${id}.description`,
    })),
    checks: [
      check(
        'preview_classification',
        previewReady ? 'ready' : 'partial',
        previewReady
          ? 'erp.applyReadiness.values.previewReady'
          : 'erp.applyReadiness.values.pending',
      ),
      check(
        'row_findings',
        importPreview.summary.errorCount > 0 ? 'blocked' : 'ready',
        importPreview.summary.errorCount > 0
          ? 'erp.applyReadiness.values.hasErrors'
          : 'erp.applyReadiness.values.clean',
      ),
      check(
        'credential_reference',
        credentialReady ? 'ready' : 'partial',
        credentialReady
          ? 'erp.applyReadiness.values.credentialReady'
          : 'erp.applyReadiness.values.credentialPending',
      ),
      check(
        'human_review',
        freshReviewEvent ? 'ready' : previewReady ? 'partial' : 'blocked',
        freshReviewEvent
          ? 'erp.applyReadiness.values.reviewRecorded'
          : 'erp.applyReadiness.values.reviewPending',
      ),
      check('execution_boundary', 'blocked', 'erp.applyReadiness.values.executionClosed'),
    ],
  }
}

function buildConnectorApplyApprovalPolicy({
  connectorState,
  importPreview,
  applyReadiness,
  approvalEvent,
}: {
  connectorState: ConnectorLifecycleState
  importPreview: ConnectorImportPreview
  applyReadiness: ConnectorApplyReadiness
  approvalEvent: ErpSyncBatchRow | null
}): ConnectorApplyApprovalPolicy {
  const batch = importPreview.batch
  const previewReady = Boolean(batch?.id && importPreview.status === 'preview_ready')
  const reviewRecorded = Boolean(applyReadiness.reviewRequestedAt)
  const approvalRecorded =
    previewReady &&
    reviewRecorded &&
    eventIsAtOrAfter(approvalEvent?.created_at, applyReadiness.reviewRequestedAt)
      ? approvalEvent
      : null
  const hasRowErrors = importPreview.summary.errorCount > 0

  const status: ConnectorApplyApprovalPolicyStatus =
    connectorState !== 'connector_selected' || !batch?.id
      ? 'not_available'
      : hasRowErrors || importPreview.status === 'blocked'
        ? 'blocked'
        : !previewReady || !reviewRecorded
          ? 'needs_review'
          : approvalRecorded
            ? 'approval_recorded'
            : 'admin_only'

  const readiness: ConnectorReadinessStatus =
    status === 'approval_recorded' || status === 'admin_only'
      ? 'ready'
      : status === 'blocked'
        ? 'blocked'
        : 'partial'
  const action: ConnectorApplyApprovalPolicyAction =
    status === 'approval_recorded'
      ? 'approval_recorded'
      : status === 'admin_only'
        ? 'record_admin_approval'
        : status === 'blocked'
          ? 'resolve_blockers'
          : status === 'needs_review'
            ? 'run_review_first'
            : 'none'

  return {
    status,
    readiness,
    statusLabelKey: `erp.applyApprovalPolicy.status.${status}`,
    descriptionKey: `erp.applyApprovalPolicy.descriptions.${status}`,
    action,
    actionLabelKey: `erp.applyApprovalPolicy.actions.${action}.label`,
    actionDescriptionKey: `erp.applyApprovalPolicy.actions.${action}.description`,
    approverRoleKey: 'erp.applyApprovalPolicy.approverRoles.admin',
    requestable: status === 'admin_only',
    safeToApply: false,
    approvalRecordedAt: approvalRecorded?.created_at ?? null,
    approvalRecordedByEmployeeId: approvalRecorded?.actor_employee_id ?? null,
    batchId: batch?.id ?? null,
  }
}

function buildConnectorControlledApplyPlan({
  connectorState,
  importPreview,
  credentialBoundary,
  applyReadiness,
  applyApprovalPolicy,
}: {
  connectorState: ConnectorLifecycleState
  importPreview: ConnectorImportPreview
  credentialBoundary: ConnectorCredentialBoundary
  applyReadiness: ConnectorApplyReadiness
  applyApprovalPolicy: ConnectorApplyApprovalPolicy
}): ConnectorControlledApplyPlan {
  const batch = importPreview.batch
  const previewReady = Boolean(batch?.id && importPreview.status === 'preview_ready')
  const hasRowErrors = importPreview.summary.errorCount > 0
  const reviewRecorded = Boolean(applyReadiness.reviewRequestedAt)
  const approvalPolicyReady =
    applyApprovalPolicy.status === 'admin_only' ||
    applyApprovalPolicy.status === 'approval_recorded'
  const approvalRecorded = applyApprovalPolicy.status === 'approval_recorded'
  const credentialReady =
    !credentialBoundary.required ||
    credentialBoundary.state === 'verified' ||
    credentialBoundary.state === 'not_required'
  const hasChecksum = Boolean(batch?.sourceChecksum)

  const status: ConnectorControlledApplyPlanStatus =
    connectorState !== 'connector_selected' || !batch?.id
      ? 'not_available'
      : hasRowErrors
        ? 'blocked'
        : !previewReady
          ? 'needs_preview'
          : approvalRecorded
            ? 'approval_recorded'
            : reviewRecorded
              ? 'design_ready'
              : 'needs_review'

  const gate = (
    id: ConnectorControlledApplyGateId,
    statusValue: ConnectorReadinessStatus,
    valueKey: string,
  ): ConnectorControlledApplyGate => ({
    id,
    labelKey: `erp.controlledApply.gates.${id}.label`,
    descriptionKey: `erp.controlledApply.gates.${id}.description`,
    status: statusValue,
    valueKey,
  })

  const gates: ConnectorControlledApplyGate[] = [
    gate(
      'preview_ready',
      previewReady ? 'ready' : hasRowErrors ? 'blocked' : 'partial',
      previewReady
        ? 'erp.controlledApply.values.previewReady'
        : hasRowErrors
          ? 'erp.controlledApply.values.previewBlocked'
          : 'erp.controlledApply.values.previewPending',
    ),
    gate(
      'human_review',
      reviewRecorded ? 'ready' : previewReady ? 'partial' : 'blocked',
      reviewRecorded
        ? 'erp.controlledApply.values.reviewRecorded'
        : 'erp.controlledApply.values.reviewRequired',
    ),
    gate(
      'source_checksum',
      hasChecksum ? 'ready' : 'partial',
      hasChecksum
        ? 'erp.controlledApply.values.checksumReady'
        : 'erp.controlledApply.values.checksumMissing',
    ),
    gate(
      'approval_policy',
      approvalPolicyReady ? 'ready' : previewReady ? 'partial' : 'blocked',
      approvalRecorded
        ? 'erp.controlledApply.values.policyApproved'
        : approvalPolicyReady
          ? 'erp.controlledApply.values.policyAdminOnly'
          : 'erp.controlledApply.values.policyNeeded',
    ),
    gate('batch_lock', batch?.id ? 'partial' : 'blocked', 'erp.controlledApply.values.lockNeeded'),
    gate('rollback_strategy', 'blocked', 'erp.controlledApply.values.rollbackNeeded'),
    gate(
      'audit_trail',
      reviewRecorded ? 'ready' : previewReady ? 'partial' : 'blocked',
      reviewRecorded
        ? 'erp.controlledApply.values.auditReady'
        : 'erp.controlledApply.values.auditPending',
    ),
    gate('notification_plan', 'blocked', 'erp.controlledApply.values.notificationNeeded'),
    gate(
      'runtime_credentials',
      credentialReady ? 'partial' : 'blocked',
      credentialReady
        ? 'erp.controlledApply.values.credentialBoundaryReady'
        : 'erp.controlledApply.values.credentialBoundaryPending',
    ),
    gate('execution_boundary', 'blocked', 'erp.controlledApply.values.executionClosed'),
  ]

  return {
    status,
    readiness: status === 'blocked' ? 'blocked' : 'partial',
    statusLabelKey: `erp.controlledApply.status.${status}`,
    descriptionKey: `erp.controlledApply.descriptions.${status}`,
    executionOpen: false,
    applyRpcExposed: false,
    batchId: batch?.id ?? null,
    sourceChecksum: batch?.sourceChecksum ?? null,
    gates,
    summary: {
      readyCount: gates.filter((item) => item.status === 'ready').length,
      partialCount: gates.filter((item) => item.status === 'partial').length,
      blockedCount: gates.filter((item) => item.status === 'blocked').length,
    },
  }
}

function buildConnectorApplyExecutionContract({
  connectorState,
  importPreview,
  applyApprovalPolicy,
  controlledApplyPlan,
}: {
  connectorState: ConnectorLifecycleState
  importPreview: ConnectorImportPreview
  applyApprovalPolicy: ConnectorApplyApprovalPolicy
  controlledApplyPlan: ConnectorControlledApplyPlan
}): ConnectorApplyExecutionContract {
  const batch = importPreview.batch
  const previewReady = Boolean(batch?.id && importPreview.status === 'preview_ready')
  const approvalRecorded = applyApprovalPolicy.status === 'approval_recorded'
  const hasChecksum = Boolean(batch?.sourceChecksum)
  const hasRowErrors = importPreview.summary.errorCount > 0

  const status: ConnectorApplyExecutionContractStatus =
    connectorState !== 'connector_selected' || !batch?.id
      ? 'not_available'
      : hasRowErrors ||
          !hasChecksum ||
          importPreview.status === 'blocked' ||
          controlledApplyPlan.status === 'blocked'
        ? 'blocked'
        : !previewReady || !approvalRecorded
          ? 'needs_approval'
          : 'contract_ready'

  const control = (
    id: ConnectorApplyExecutionControlId,
    statusValue: ConnectorReadinessStatus,
    valueKey: string,
  ): ConnectorApplyExecutionControl => ({
    id,
    labelKey: `erp.applyExecutionContract.controls.${id}.label`,
    descriptionKey: `erp.applyExecutionContract.controls.${id}.description`,
    status: statusValue,
    valueKey,
  })

  const controls: ConnectorApplyExecutionControl[] = [
    control(
      'dry_run_only',
      batch?.mode === 'dry_run' ? 'ready' : 'blocked',
      batch?.mode === 'dry_run'
        ? 'erp.applyExecutionContract.values.dryRunOnly'
        : 'erp.applyExecutionContract.values.notDryRun',
    ),
    control(
      'idempotency_key',
      hasChecksum ? 'ready' : 'blocked',
      hasChecksum
        ? 'erp.applyExecutionContract.values.checksumReady'
        : 'erp.applyExecutionContract.values.checksumMissing',
    ),
    control(
      'admin_approval',
      approvalRecorded ? 'ready' : previewReady ? 'partial' : 'blocked',
      approvalRecorded
        ? 'erp.applyExecutionContract.values.approvalRecorded'
        : 'erp.applyExecutionContract.values.approvalMissing',
    ),
    control('batch_lock', 'blocked', 'erp.applyExecutionContract.values.lockClosed'),
    control('rollback_plan', 'blocked', 'erp.applyExecutionContract.values.rollbackClosed'),
    control('notification_plan', 'blocked', 'erp.applyExecutionContract.values.notificationClosed'),
    control('execution_boundary', 'blocked', 'erp.applyExecutionContract.values.executionClosed'),
  ]

  return {
    status,
    readiness: status === 'blocked' ? 'blocked' : 'partial',
    statusLabelKey: `erp.applyExecutionContract.status.${status}`,
    descriptionKey: `erp.applyExecutionContract.descriptions.${status}`,
    contractVersion: 'pr14.20-closed-apply-contract-v1',
    executionEnabled: false,
    canonicalWriteEnabled: false,
    sourceWritebackEnabled: false,
    credentialReadbackEnabled: false,
    applyRpcExposed: false,
    safeToExecute: false,
    executorMode: 'future_background_job',
    batchId: batch?.id ?? null,
    sourceChecksum: batch?.sourceChecksum ?? null,
    sourceNamespaceCode: batch?.sourceNamespaceCode ?? null,
    controls,
    summary: {
      readyCount: controls.filter((item) => item.status === 'ready').length,
      partialCount: controls.filter((item) => item.status === 'partial').length,
      blockedCount: controls.filter((item) => item.status === 'blocked').length,
    },
  }
}

function emptyErpOverview(connectorState: ConnectorLifecycleState = 'no_tenant'): ErpOverview {
  const credentialBoundary = buildConnectorCredentialBoundary({
    hasConnection: false,
  })
  const checks = buildReadinessChecks({
    hasConnection: false,
    isActive: false,
    credentialBoundary,
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
    activityTimeline: [],
    credentialBoundary,
    applyReadiness: buildConnectorApplyReadiness({
      connectorState,
      importPreview: emptyConnectorImportPreview(connectorState),
      credentialBoundary,
      reviewEvent: null,
    }),
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
      return 'error'
    case 'partial':
    case 'partial_success':
      return 'warning'
    default:
      return 'info'
  }
}

function mapActivityKind(syncType: string | null | undefined): ConnectorActivityEventKind {
  if (syncType === 'setup_lifecycle') return 'setup_lifecycle'
  if (syncType === 'setup_preflight') return 'setup_preflight'
  if (syncType === 'credential_handoff') return 'credential_handoff'
  if (syncType === 'import_preview') return 'import_preview'
  if (syncType === 'import_apply_review') return 'import_apply_review'
  return 'sync_batch'
}

function mapActivityTitleKey(row: ErpSyncBatchRow): string {
  if (row.event_key) return `erp.activityTimeline.events.${row.event_key}.title`
  if (row.sync_type === 'setup_preflight')
    return 'erp.activityTimeline.events.setup_preflight_completed.title'
  if (row.sync_type === 'credential_handoff') {
    return 'erp.activityTimeline.events.credential_handoff_requested.title'
  }
  return 'erp.activityTimeline.events.sync_batch_recorded.title'
}

function mapActivitySummaryKey(row: ErpSyncBatchRow): string {
  if (row.sync_type === 'setup_lifecycle') {
    if (row.event_key === 'setup_mapping_contract_ready') {
      return 'erp.activityTimeline.summaries.setupLifecycle.mappingReady'
    }
    return 'erp.activityTimeline.summaries.setupLifecycle.started'
  }

  if (row.sync_type === 'credential_handoff') {
    if (row.status === 'failed') return 'erp.activityTimeline.summaries.credentialHandoff.failed'
    if (row.status === 'success') return 'erp.activityTimeline.summaries.credentialHandoff.success'
    return 'erp.activityTimeline.summaries.credentialHandoff.partial'
  }

  if (row.sync_type === 'import_preview') {
    if (row.status === 'failed') return 'erp.activityTimeline.summaries.importPreview.failed'
    if (row.status === 'success') return 'erp.activityTimeline.summaries.importPreview.success'
    return 'erp.activityTimeline.summaries.importPreview.partial'
  }

  if (row.sync_type === 'import_apply_review') {
    if (row.status === 'failed') return 'erp.activityTimeline.summaries.importApplyReview.failed'
    if (row.status === 'success') return 'erp.activityTimeline.summaries.importApplyReview.success'
    return 'erp.activityTimeline.summaries.importApplyReview.partial'
  }

  if (row.sync_type === 'setup_preflight') {
    if (row.status === 'success') return 'erp.activityTimeline.summaries.setupPreflight.success'
    if (row.status === 'failed') return 'erp.activityTimeline.summaries.setupPreflight.failed'
    return 'erp.activityTimeline.summaries.setupPreflight.partial'
  }

  if (row.status === 'failed') return 'erp.activityTimeline.summaries.syncBatch.failed'
  if (row.status === 'success') return 'erp.activityTimeline.summaries.syncBatch.success'
  return 'erp.activityTimeline.summaries.syncBatch.pending'
}

function mapActivityNextActionKey(row: ErpSyncBatchRow): string {
  const key = row.next_action_key?.trim()
  if (key) return `erp.activityTimeline.nextActions.${key}`

  if (row.sync_type === 'setup_lifecycle') {
    return row.event_key === 'setup_mapping_contract_ready'
      ? 'erp.activityTimeline.nextActions.review_identity_scope'
      : 'erp.activityTimeline.nextActions.complete_field_mapping'
  }
  if (row.sync_type === 'credential_handoff') {
    return 'erp.activityTimeline.nextActions.wait_for_secure_reference'
  }
  if (row.sync_type === 'import_apply_review') {
    return 'erp.activityTimeline.nextActions.hold_for_apply_design'
  }
  if (row.sync_type === 'import_preview') {
    return row.status === 'success'
      ? 'erp.activityTimeline.nextActions.review_import_preview'
      : 'erp.activityTimeline.nextActions.review_import_errors'
  }
  if (row.sync_type === 'setup_preflight') {
    return row.status === 'success'
      ? 'erp.activityTimeline.nextActions.runtime_still_closed'
      : 'erp.activityTimeline.nextActions.review_setup_findings'
  }
  return 'erp.activityTimeline.nextActions.review_activity'
}

function buildActivityDetails(row: ErpSyncBatchRow): ConnectorActivityDetail[] {
  if (row.sync_type === 'setup_lifecycle') {
    return [
      {
        labelKey: 'erp.activityTimeline.details.ownedDomains',
        value: row.records_seen ?? 0,
      },
      {
        labelKey: 'erp.activityTimeline.details.mappingRows',
        value: row.records_inserted ?? 0,
      },
    ]
  }

  if (row.sync_type === 'credential_handoff') {
    return [
      {
        labelKey: 'erp.activityTimeline.details.updatedRecords',
        value: row.records_updated ?? 0,
      },
      {
        labelKey: 'erp.activityTimeline.details.referenceAvailable',
        value: false,
      },
    ]
  }

  if (row.sync_type === 'setup_preflight') {
    return [
      {
        labelKey: 'erp.activityTimeline.details.totalChecks',
        value: row.records_seen ?? 0,
      },
      {
        labelKey: 'erp.activityTimeline.details.passedChecks',
        value: row.records_inserted ?? 0,
      },
      {
        labelKey: 'erp.activityTimeline.details.warningChecks',
        value: row.records_updated ?? 0,
      },
      {
        labelKey: 'erp.activityTimeline.details.blockedChecks',
        value: row.records_failed ?? 0,
      },
    ]
  }

  if (row.sync_type === 'import_preview') {
    return [
      {
        labelKey: 'erp.activityTimeline.details.recordsSeen',
        value: row.records_seen ?? 0,
      },
      {
        labelKey: 'erp.activityTimeline.details.createdRecords',
        value: row.records_inserted ?? 0,
      },
      {
        labelKey: 'erp.activityTimeline.details.updatedRecords',
        value: row.records_updated ?? 0,
      },
      {
        labelKey: 'erp.activityTimeline.details.skippedRecords',
        value: Number(row.safe_error_context?.skip_count ?? 0),
      },
      {
        labelKey: 'erp.activityTimeline.details.recordsFailed',
        value: row.records_failed ?? 0,
      },
    ]
  }

  if (row.sync_type === 'import_apply_review') {
    return [
      {
        labelKey: 'erp.activityTimeline.details.recordsSeen',
        value: row.records_seen ?? 0,
      },
      {
        labelKey: 'erp.activityTimeline.details.createdRecords',
        value: row.records_inserted ?? 0,
      },
      {
        labelKey: 'erp.activityTimeline.details.updatedRecords',
        value: row.records_updated ?? 0,
      },
      {
        labelKey: 'erp.activityTimeline.details.skippedRecords',
        value: Number(row.safe_error_context?.skip_count ?? 0),
      },
    ]
  }

  return [
    {
      labelKey: 'erp.activityTimeline.details.recordsSeen',
      value: row.records_seen ?? 0,
    },
    {
      labelKey: 'erp.activityTimeline.details.recordsFailed',
      value: row.records_failed ?? 0,
    },
  ]
}

function buildConnectorActivityEvent(row: ErpSyncBatchRow, index: number): ConnectorActivityEvent {
  const safeErrorCode = row.safe_error_code?.trim() || null

  return {
    id: row.id ?? `activity-${index}`,
    at: formatSyncTimestamp(row.created_at),
    level: mapSyncLevel(row.status),
    kind: mapActivityKind(row.sync_type),
    titleKey: mapActivityTitleKey(row),
    summaryKey: mapActivitySummaryKey(row),
    detailItems: buildActivityDetails(row),
    safeErrorCode,
    safeErrorSummaryKey: safeErrorCode ? `erp.activityTimeline.safeErrors.${safeErrorCode}` : null,
    nextActionKey: mapActivityNextActionKey(row),
    actorLabelKey: row.actor_employee_id
      ? 'erp.activityTimeline.actors.admin'
      : 'erp.activityTimeline.actors.system',
    rawStatus: row.status ?? 'pending',
  }
}

function mapPreflightStatusToSyncStatus(status: ConnectorReadinessStatus) {
  if (status === 'ready') return 'success'
  if (status === 'partial') return 'partial_success'
  return 'failed'
}

function mapSyncLogMessageKey(row: ErpSyncBatchRow): string | undefined {
  if (row.sync_type === 'setup_lifecycle') {
    if (row.event_key === 'setup_mapping_contract_ready') {
      return 'erp.syncLogMessages.setupLifecycle.mappingReady'
    }
    return 'erp.syncLogMessages.setupLifecycle.started'
  }

  if (row.sync_type === 'credential_handoff') {
    if (row.status === 'success') return 'erp.syncLogMessages.credentialHandoff.success'
    if (row.status === 'partial_success') return 'erp.syncLogMessages.credentialHandoff.partial'
    if (row.status === 'failed') return 'erp.syncLogMessages.credentialHandoff.failed'
    return 'erp.syncLogMessages.credentialHandoff.pending'
  }
  if (row.sync_type === 'import_preview') {
    if (row.status === 'success') return 'erp.syncLogMessages.importPreview.success'
    if (row.status === 'partial_success') return 'erp.syncLogMessages.importPreview.partial'
    if (row.status === 'failed') return 'erp.syncLogMessages.importPreview.failed'
    return 'erp.syncLogMessages.importPreview.pending'
  }
  if (row.sync_type === 'import_apply_review') {
    if (row.status === 'success') return 'erp.syncLogMessages.importApplyReview.success'
    if (row.status === 'failed') return 'erp.syncLogMessages.importApplyReview.failed'
    return 'erp.syncLogMessages.importApplyReview.pending'
  }
  if (row.sync_type !== 'setup_preflight') return undefined
  if (row.status === 'success') return 'erp.syncLogMessages.setupPreflight.success'
  if (row.status === 'partial_success') return 'erp.syncLogMessages.setupPreflight.partial'
  if (row.status === 'failed') return 'erp.syncLogMessages.setupPreflight.failed'
  return 'erp.syncLogMessages.setupPreflight.pending'
}

function buildReadinessChecks({
  hasConnection,
  isActive,
  credentialBoundary,
  mappedFields,
  totalFields,
  namespaceCount,
  identityCount,
  setupReadinessPct,
}: {
  hasConnection: boolean
  isActive: boolean
  credentialBoundary: ConnectorCredentialBoundary
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
      id: 'credential_boundary',
      labelKey: 'erp.readinessChecks.credentialBoundary',
      status: credentialBoundary.status,
      value: credentialBoundary.state,
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

function mappingKey(
  mapping: Pick<ConnectorFieldMapping, 'targetSchema' | 'targetTable' | 'targetField'>,
) {
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
      mappedFields.has(`${definition.targetSchema}.${definition.targetTable}.${field.targetField}`),
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
  credentialBoundary,
  canonicalClasses,
  namespaceCount,
  identityCount,
}: {
  connectorState: ConnectorLifecycleState
  isActive: boolean
  isEnabled: boolean
  credentialBoundary: ConnectorCredentialBoundary
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
      status: hasConnection ? credentialBoundary.status : 'blocked',
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
  credentialBoundary,
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
  credentialBoundary: ConnectorCredentialBoundary
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

  if (credentialBoundary.status !== 'ready') {
    return summary(
      'erp.setupSummary.values.credentialPending',
      'erp.setupSummary.hints.credentialPending',
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

function lifecycle(
  stage: ConnectorLifecycleStage,
  status: ConnectorReadinessStatus,
): ConnectorLifecycle {
  return {
    stage,
    status,
    labelKey: `erp.lifecycleStages.${stage}.label`,
    descriptionKey: `erp.lifecycleStages.${stage}.description`,
    nextActionKey: `erp.lifecycleStages.${stage}.nextAction`,
    runtimeEligible: false,
  }
}

function buildConnectorLifecycle({
  connectorState,
  setupStatus,
  isActive,
  isEnabled,
  credentialBoundary,
  mappedFields,
  totalFields,
  namespaceCount,
  identityCount,
  preflightStatus,
}: {
  connectorState: ConnectorLifecycleState
  setupStatus: ConnectorSetupStatus | null
  isActive: boolean
  isEnabled: boolean
  credentialBoundary: ConnectorCredentialBoundary
  mappedFields: number
  totalFields: number
  namespaceCount: number
  identityCount: number
  preflightStatus: ConnectorReadinessStatus
}): ConnectorLifecycle {
  if (connectorState === 'no_tenant') return lifecycle('source_selection', 'blocked')
  if (connectorState === 'no_connector') return lifecycle('source_selection', 'partial')
  if (!isEnabled || setupStatus === 'disabled' || setupStatus === 'archived') {
    return lifecycle('disabled', 'blocked')
  }
  if (setupStatus === 'error') return lifecycle('error', 'blocked')
  if (isActive || setupStatus === 'connected') return lifecycle('connected', 'ready')
  if (mappedFields === 0 || (totalFields > 0 && mappedFields < totalFields)) {
    return lifecycle('mapping', mappedFields > 0 ? 'partial' : 'blocked')
  }
  if (namespaceCount === 0 || identityCount === 0) return lifecycle('namespace', 'partial')
  if (credentialBoundary.status !== 'ready') {
    return lifecycle('credential', credentialBoundary.status)
  }
  if (preflightStatus === 'ready') return lifecycle('runtime_closed', 'ready')
  return lifecycle('preflight', preflightStatus)
}

function buildConnectorSourceCapabilities({
  connectorState,
  connectionMethod,
  credentialBoundary,
  canonicalClasses,
  namespaceCount,
  identityCount,
  ownedDomains,
  isActive,
}: {
  connectorState: ConnectorLifecycleState
  connectionMethod?: string | null
  credentialBoundary: ConnectorCredentialBoundary
  canonicalClasses: ConnectorCanonicalDataClass[]
  namespaceCount: number
  identityCount: number
  ownedDomains: string[]
  isActive: boolean
}): ConnectorSourceCapability[] {
  const hasConnection = connectorState === 'connector_selected'
  const inactiveTenantStatus: ConnectorReadinessStatus =
    connectorState === 'no_connector' ? 'partial' : 'blocked'
  const namespaceStatus: ConnectorReadinessStatus = !hasConnection
    ? inactiveTenantStatus
    : namespaceCount > 0 && identityCount > 0
      ? 'ready'
      : namespaceCount > 0
        ? 'partial'
        : 'blocked'

  return [
    {
      id: 'source_profile',
      labelKey: 'erp.capabilities.sourceProfile.label',
      descriptionKey: 'erp.capabilities.sourceProfile.description',
      status: hasConnection ? 'ready' : inactiveTenantStatus,
    },
    {
      id: 'domain_ownership',
      labelKey: 'erp.capabilities.domainOwnership.label',
      descriptionKey: 'erp.capabilities.domainOwnership.description',
      status: !hasConnection ? inactiveTenantStatus : ownedDomains.length > 0 ? 'ready' : 'partial',
    },
    {
      id: 'canonical_mapping',
      labelKey: 'erp.capabilities.canonicalMapping.label',
      descriptionKey: 'erp.capabilities.canonicalMapping.description',
      status: hasConnection ? deriveRequiredMappingStatus(canonicalClasses) : inactiveTenantStatus,
    },
    {
      id: 'identity_namespace',
      labelKey: 'erp.capabilities.identityNamespace.label',
      descriptionKey: 'erp.capabilities.identityNamespace.description',
      status: namespaceStatus,
    },
    {
      id: 'credential_reference',
      labelKey: 'erp.capabilities.credentialReference.label',
      descriptionKey: 'erp.capabilities.credentialReference.description',
      status: hasConnection ? credentialBoundary.status : 'blocked',
    },
    {
      id: 'transfer_method',
      labelKey: 'erp.capabilities.transferMethod.label',
      descriptionKey: 'erp.capabilities.transferMethod.description',
      status: !hasConnection
        ? inactiveTenantStatus
        : connectionMethod === 'manual_import'
          ? 'ready'
          : 'partial',
    },
    {
      id: 'api_runtime',
      labelKey: 'erp.capabilities.apiRuntime.label',
      descriptionKey: 'erp.capabilities.apiRuntime.description',
      status: isActive ? 'partial' : 'blocked',
    },
    {
      id: 'writeback',
      labelKey: 'erp.capabilities.writeback.label',
      descriptionKey: 'erp.capabilities.writeback.description',
      status: 'blocked',
    },
  ]
}

function buildConnectorDomainOwnership({
  connectorState,
  currentConnectionId,
  connections,
  canonicalClasses,
}: {
  connectorState: ConnectorLifecycleState
  currentConnectionId: string | null
  connections: ErpConnectionCandidate[]
  canonicalClasses: ConnectorCanonicalDataClass[]
}): ConnectorDomainOwnership[] {
  const activeConnections = connections.filter(
    (connection) => connection.setup_status !== 'archived' && connection.is_enabled !== false,
  )

  return CANONICAL_DATA_CLASSES.map((definition) => {
    const owner = pickCurrentErpConnection(
      activeConnections.filter((connection) =>
        normalizeOwnedDomains(connection.owned_domains).includes(definition.id),
      ),
    )
    const canonicalClass = canonicalClasses.find((row) => row.id === definition.id)
    const status: ConnectorDomainOwnershipStatus =
      !owner || connectorState === 'no_connector'
        ? 'available'
        : owner.id === currentConnectionId
          ? 'owned_by_current'
          : 'owned_by_other'

    return {
      id: definition.id,
      labelKey: definition.labelKey,
      pulsTarget: definition.pulsTarget,
      status,
      ownerProviderCode: owner?.provider?.trim().toLowerCase() || null,
      ownerProviderLabel: owner ? mapProviderLabel(owner.provider, owner.display_name) : null,
      ownerConnectionId: owner?.id ?? null,
      mappedFields: canonicalClass?.mappedFields ?? 0,
      totalFields: canonicalClass?.totalFields ?? definition.fields.length,
    }
  })
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
  activityTimeline,
  credentialBoundary,
  importPreview,
  applyReadiness,
  applyApprovalPolicy,
  credentialHandoffStatus,
  credentialHandoffRequestedAt,
  credentialHandoffRequestedByEmployeeId,
  credentialHandoffUpdatedAt,
  connections,
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
  activityTimeline: ConnectorActivityEvent[]
  credentialBoundary: ConnectorCredentialBoundary
  importPreview?: ConnectorImportPreview
  applyReadiness?: ConnectorApplyReadiness
  applyApprovalPolicy?: ConnectorApplyApprovalPolicy
  credentialHandoffStatus?: ConnectorCredentialHandoffStatus | null
  credentialHandoffRequestedAt?: string | null
  credentialHandoffRequestedByEmployeeId?: string | null
  credentialHandoffUpdatedAt?: string | null
  connections?: ErpConnectionCandidate[]
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
    credentialBoundary,
    canonicalClasses,
    namespaceCount: namespaces.length,
    identityCount,
  })
  const lifecycleState = buildConnectorLifecycle({
    connectorState,
    setupStatus,
    isActive,
    isEnabled,
    credentialBoundary,
    mappedFields,
    totalFields,
    namespaceCount: namespaces.length,
    identityCount,
    preflightStatus: preflight.status,
  })
  const capabilities = buildConnectorSourceCapabilities({
    connectorState,
    connectionMethod: connections?.find((row) => row.id === connectionId)?.connection_method,
    credentialBoundary,
    canonicalClasses,
    namespaceCount: namespaces.length,
    identityCount,
    ownedDomains,
    isActive,
  })
  const domainOwnership = buildConnectorDomainOwnership({
    connectorState,
    currentConnectionId: connectionId,
    connections: connections ?? [],
    canonicalClasses,
  })
  const credentialHandoff = buildConnectorCredentialHandoff({
    connectorState,
    credentialBoundary,
    mappedFields,
    totalFields,
    namespaceCount: namespaces.length,
    identityCount,
    handoffStatus: credentialHandoffStatus,
    requestedAt: credentialHandoffRequestedAt,
    requestedByEmployeeId: credentialHandoffRequestedByEmployeeId,
    updatedAt: credentialHandoffUpdatedAt,
  })
  const resolvedImportPreview = importPreview ?? emptyConnectorImportPreview(connectorState)
  const resolvedApplyReadiness =
    applyReadiness ??
    buildConnectorApplyReadiness({
      connectorState,
      importPreview: resolvedImportPreview,
      credentialBoundary,
      reviewEvent: null,
    })
  const resolvedApplyApprovalPolicy =
    applyApprovalPolicy ??
    buildConnectorApplyApprovalPolicy({
      connectorState,
      importPreview: resolvedImportPreview,
      applyReadiness: resolvedApplyReadiness,
      approvalEvent: null,
    })
  const controlledApplyPlan = buildConnectorControlledApplyPlan({
    connectorState,
    importPreview: resolvedImportPreview,
    credentialBoundary,
    applyReadiness: resolvedApplyReadiness,
    applyApprovalPolicy: resolvedApplyApprovalPolicy,
  })
  const applyExecutionContract = buildConnectorApplyExecutionContract({
    connectorState,
    importPreview: resolvedImportPreview,
    applyApprovalPolicy: resolvedApplyApprovalPolicy,
    controlledApplyPlan,
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
    lifecycle: lifecycleState,
    setupSummary: buildConnectorSetupSummary({
      connectorState,
      setupStatus,
      isActive,
      isEnabled,
      credentialBoundary,
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
    credentialBoundary,
    credentialHandoff,
    importPreview: resolvedImportPreview,
    applyReadiness: resolvedApplyReadiness,
    applyApprovalPolicy: resolvedApplyApprovalPolicy,
    controlledApplyPlan,
    applyExecutionContract,
    capabilities,
    domainOwnership,
    canonicalClasses,
    mappings,
    namespaces,
    transferModes: TRANSFER_MODES,
    guardrails: CONNECTOR_GUARDRAILS,
    providerOptions: CONNECTOR_PROVIDER_OPTIONS,
    syncLogs,
    activityTimeline,
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
  const credentialBoundary = buildConnectorCredentialBoundary({
    hasConnection: true,
    connectionMethod: 'rest_api',
    authMode: 'custom_secret_ref',
    credentialRequired: true,
    credentialState: 'missing',
  })
  const checks = buildReadinessChecks({
    hasConnection: true,
    isActive: false,
    credentialBoundary,
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
    syncLogs: demo.syncLogs.map((log) => ({
      ...log,
      kind: 'sync_batch' as const,
    })),
    activityTimeline: demo.syncLogs.map((log, index) => ({
      id: log.id ?? `demo-activity-${index}`,
      at: log.at,
      level: log.level,
      kind: 'sync_batch' as const,
      titleKey: 'erp.activityTimeline.events.sync_batch_recorded.title',
      summaryKey: 'erp.activityTimeline.summaries.syncBatch.pending',
      detailItems: [],
      safeErrorCode: null,
      safeErrorSummaryKey: null,
      nextActionKey: 'erp.activityTimeline.nextActions.review_activity',
      actorLabelKey: 'erp.activityTimeline.actors.system',
      rawStatus: log.level,
    })),
    credentialBoundary,
    importPreview: emptyConnectorImportPreview('connector_selected'),
    connections: [
      {
        id: 'demo-canias',
        provider: 'canias',
        display_name: demo.status.system,
        connection_method: 'rest_api',
        connection_key: 'demo-canias',
        setup_status: 'preflight_ready',
        setup_step: 'preflight',
        is_enabled: true,
        owned_domains: ['employees', 'departments', 'positions', 'cost_centers'],
        created_at: null,
        updated_at: null,
      },
    ],
  })
}

async function fetchRealErpOverview(userId: string): Promise<ErpOverview> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) return emptyErpOverview('no_tenant')

  const [connectionsRow, readinessRow, namespacesRow, identitiesRow] = await Promise.all([
    pulsIntegration()
      .from('erp_connections')
      .select(
        [
          'id',
          'provider',
          'display_name',
          'connection_method',
          'connection_key',
          'is_active',
          'last_sync_at',
          'last_status',
          'setup_status',
          'setup_step',
          'is_enabled',
          'owned_domains',
          'selected_at',
          'setup_started_at',
          'auth_mode',
          'credential_required',
          'credential_state',
          'credential_last_verified_at',
          'credential_last_failed_at',
          'credential_error_code',
          'credential_handoff_status',
          'credential_handoff_requested_at',
          'credential_handoff_requested_by_employee_id',
          'credential_handoff_updated_at',
          'created_at',
          'updated_at',
        ].join(', '),
      )
      .eq('tenant_id', ctx.tenantId)
      .order('created_at', { ascending: false })
      .limit(10),
    pulsCalc()
      .from('setup_readiness_summary')
      .select('integration_setup_pct')
      .eq('tenant_id', ctx.tenantId)
      .maybeSingle(),
    pulsIntegration()
      .from('source_namespaces')
      .select('id, code, name, source_type, connection_id')
      .eq('tenant_id', ctx.tenantId)
      .eq('is_active', true)
      .order('priority_rank', { ascending: true }),
    pulsIntegration()
      .from('entity_identity_map')
      .select('source_namespace_id, canonical_table')
      .eq('tenant_id', ctx.tenantId)
      .eq('is_active', true),
  ])

  if (connectionsRow.error) {
    throw fromSupabaseError(
      connectionsRow.error,
      'fetchErpOverview',
      'puls_integration',
      'erp_connections',
    )
  }

  const connections = (connectionsRow.data ?? []) as ErpConnectionRow[]
  const connection = pickCurrentErpConnection(connections)
  const [mappingsRow, batchesRow] = connection?.id
    ? await Promise.all([
        pulsIntegration()
          .from('erp_field_mappings')
          .select(
            'source_entity, source_field, target_schema, target_table, target_field, is_required, is_sensitive, is_active',
          )
          .eq('tenant_id', ctx.tenantId)
          .eq('connection_id', connection.id)
          .order('source_entity', { ascending: true })
          .order('source_field', { ascending: true }),
        pulsIntegration()
          .from('erp_sync_batches')
          .select(
            'id, created_at, status, error_summary, sync_type, event_key, actor_employee_id, safe_error_code, safe_error_context, next_action_key, records_seen, records_inserted, records_updated, records_failed',
          )
          .eq('tenant_id', ctx.tenantId)
          .eq('connection_id', connection.id)
          .order('created_at', { ascending: false })
          .limit(10),
      ])
    : [
        { data: [], error: null },
        { data: [], error: null },
      ]
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
      const canonicalField = [targetSchema, targetTable, targetField].join('.')

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
  const credentialBoundary = buildConnectorCredentialBoundary({
    hasConnection: Boolean(connection),
    connectionMethod: connection?.connection_method ?? null,
    authMode: connection?.auth_mode ?? null,
    credentialRequired: connection?.credential_required ?? null,
    credentialState: connection?.credential_state ?? null,
    lastVerifiedAt: connection?.credential_last_verified_at ?? null,
    lastFailedAt: connection?.credential_last_failed_at ?? null,
    errorCode: connection?.credential_error_code ?? null,
  })
  const checks = buildReadinessChecks({
    hasConnection: Boolean(connection),
    isActive: connection?.is_active === true,
    credentialBoundary,
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
  const connectorNamespaceRows =
    connection?.id == null
      ? []
      : rawNamespaces.filter(
          (row) =>
            row.connection_id === connection.id ||
            (row.connection_id == null && rawNamespaces.length === 1),
        )
  const connectorNamespaceIds = connectorNamespaceRows
    .map((row) => row.id)
    .filter((id): id is string => Boolean(id))
  const namespaceCodeById = rawNamespaces.reduce<Record<string, string>>((codes, row) => {
    if (row.id) codes[row.id] = row.code ?? '—'
    return codes
  }, {})
  let importBatch: ImportBatchRow | null = null
  let importPreviewRecords: ImportPreviewRecordRow[] = []

  if (connectorNamespaceIds.length > 0) {
    const importBatchRow = await pulsIntegration()
      .from('import_batches')
      .select(
        [
          'id',
          'source_namespace_id',
          'status',
          'mode',
          'source_checksum',
          'row_count',
          'create_count',
          'update_count',
          'skip_count',
          'error_count',
          'violation_count',
          'validated_at',
          'previewed_at',
          'created_at',
          'updated_at',
        ].join(', '),
      )
      .eq('tenant_id', ctx.tenantId)
      .eq('mode', 'dry_run')
      .in('source_namespace_id', connectorNamespaceIds)
      .order('updated_at', { ascending: false })
      .limit(1)

    if (!importBatchRow.error) {
      importBatch = ((importBatchRow.data ?? []) as ImportBatchRow[])[0] ?? null
    }

    if (importBatch?.id) {
      const previewRecordsRow = await pulsIntegration().rpc(
        'list_connector_import_preview_records',
        {
          p_batch_id: importBatch.id,
        },
      )

      if (!previewRecordsRow.error) {
        importPreviewRecords = (previewRecordsRow.data ?? []) as ImportPreviewRecordRow[]
      }
    }
  }
  const importPreview = buildConnectorImportPreview({
    connectorState: connection ? 'connector_selected' : 'no_connector',
    batch: importBatch,
    records: importPreviewRecords,
    namespaceCodeById,
  })
  const latestApplyReviewEvent =
    batches.find(
      (row) =>
        row.sync_type === 'import_apply_review' &&
        row.event_key === 'import_apply_review_requested',
    ) ?? null
  const latestApplyApprovalEvent =
    batches.find(
      (row) =>
        row.sync_type === 'import_apply_review' &&
        row.event_key === 'import_apply_approval_recorded',
    ) ?? null
  const applyReadiness = buildConnectorApplyReadiness({
    connectorState: connection ? 'connector_selected' : 'no_connector',
    importPreview,
    credentialBoundary,
    reviewEvent: latestApplyReviewEvent,
  })
  const applyApprovalPolicy = buildConnectorApplyApprovalPolicy({
    connectorState: connection ? 'connector_selected' : 'no_connector',
    importPreview,
    applyReadiness,
    approvalEvent: latestApplyApprovalEvent,
  })

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
      message: `${row.sync_type ?? 'check'} · ${row.status ?? 'pending'}`,
      messageKey: mapSyncLogMessageKey(row),
      detail:
        row.sync_type === 'setup_preflight'
          ? `${row.records_inserted ?? 0}/${row.records_updated ?? 0}/${row.records_failed ?? 0}`
          : undefined,
      kind:
        row.sync_type === 'setup_lifecycle'
          ? 'setup_lifecycle'
          : row.sync_type === 'setup_preflight'
            ? 'setup_preflight'
            : row.sync_type === 'credential_handoff'
              ? 'credential_handoff'
              : row.sync_type === 'import_preview'
                ? 'import_preview'
                : row.sync_type === 'import_apply_review'
                  ? 'import_apply_review'
                  : 'sync_batch',
    })),
    activityTimeline: batches.map((row, index) => buildConnectorActivityEvent(row, index)),
    credentialBoundary,
    importPreview,
    applyReadiness,
    applyApprovalPolicy,
    credentialHandoffStatus: connection?.credential_handoff_status ?? null,
    credentialHandoffRequestedAt: connection?.credential_handoff_requested_at ?? null,
    credentialHandoffRequestedByEmployeeId:
      connection?.credential_handoff_requested_by_employee_id ?? null,
    credentialHandoffUpdatedAt: connection?.credential_handoff_updated_at ?? null,
    connections,
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
    .select(
      'id, provider, connection_key, setup_status, setup_step, is_enabled, owned_domains, created_at, updated_at',
    )
    .eq('tenant_id', ctx.tenantId)
    .order('updated_at', { ascending: false })

  if (existing.error) {
    throw fromSupabaseError(
      existing.error,
      'startConnectorSetup',
      'puls_integration',
      'erp_connections',
    )
  }

  const existingConnections = ((existing.data ?? []) as ErpConnectionRow[]).filter(
    (connection) => connection.setup_status !== 'archived',
  )
  const existingConnection = pickCurrentErpConnection(
    existingConnections.filter(
      (connection) =>
        connection.connection_key === config.connectionKey ||
        connection.provider === config.provider,
    ),
  )
  const conflictingOwner = pickCurrentErpConnection(
    existingConnections.filter(
      (connection) =>
        connection.id !== existingConnection?.id &&
        connection.is_enabled !== false &&
        connection.provider !== config.provider &&
        hasConnectorDomainOverlap(connection.owned_domains, config.ownedDomains),
    ),
  )

  if (conflictingOwner?.id) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_DOMAIN_OWNED',
      message: 'Connector domain ownership already belongs to another source',
      source: 'adapter',
      operation: 'startConnectorSetup',
      i18nKey: 'erp.errors.domainOwned',
    })
  }

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
    auth_mode: config.authMode,
    credential_required: config.credentialRequired,
    credential_state: config.credentialRequired ? 'missing' : 'not_required',
    credential_last_verified_at: null,
    credential_last_failed_at: null,
    credential_error_code: null,
    credential_handoff_status: config.credentialRequired ? 'not_started' : 'not_required',
    credential_handoff_requested_at: null,
    credential_handoff_requested_by_employee_id: null,
    credential_handoff_updated_at: now,
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
      credential_boundary: 'reference_only',
      secret_readback: 'disabled',
      runtime_secret_resolution: 'server_side_future',
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

  const history = await pulsIntegration()
    .from('erp_sync_batches')
    .insert({
      tenant_id: ctx.tenantId,
      connection_id: connectionId,
      sync_type: 'setup_lifecycle',
      event_key: hasMappingContract ? 'setup_mapping_contract_ready' : 'setup_started',
      actor_employee_id: ctx.employeeId,
      status: 'success',
      started_at: now,
      finished_at: now,
      records_seen: config.ownedDomains.length,
      records_inserted: hasMappingContract
        ? buildDefaultConnectorFieldMappings(input.providerId).length
        : 0,
      records_updated: 1,
      records_failed: 0,
      error_summary: null,
      safe_error_code: null,
      safe_error_context: {
        source_profile: config.provider,
        connection_key: config.connectionKey,
        owned_domain_count: config.ownedDomains.length,
        mapping_contract_ready: hasMappingContract,
      },
      next_action_key: hasMappingContract ? 'review_identity_scope' : 'complete_field_mapping',
    })
    .select('id')
    .single()

  if (history.error) {
    throw fromSupabaseError(
      history.error,
      'startConnectorSetup',
      'puls_integration',
      'erp_sync_batches',
    )
  }

  return {
    connectionId,
    providerId: input.providerId,
    setupStatus: hasMappingContract ? 'mapping_ready' : 'draft',
    currentStep: hasMappingContract ? 'namespace' : 'mapping',
  }
}

export async function requestConnectorCredentialHandoff(
  userId: string,
): Promise<RequestConnectorCredentialHandoffResult> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_TENANT_REQUIRED',
      message: 'Connector credential handoff requires tenant context',
      source: 'adapter',
      operation: 'requestConnectorCredentialHandoff',
      i18nKey: 'erp.errors.tenantMissing',
    })
  }
  if (ctx.personaRole !== 'hr_admin' && ctx.personaRole !== 'superadmin') {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_ADMIN_REQUIRED',
      message: 'Connector credential handoff requires admin permission',
      source: 'adapter',
      operation: 'requestConnectorCredentialHandoff',
      i18nKey: 'erp.errors.adminRequired',
    })
  }

  const overview = await fetchRealErpOverview(userId)
  const connectionId = overview.provider.id
  if (!connectionId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_SOURCE_REQUIRED',
      message: 'Connector credential handoff requires a selected source',
      source: 'adapter',
      operation: 'requestConnectorCredentialHandoff',
      i18nKey: 'erp.errors.sourceMissing',
    })
  }

  if (overview.credentialHandoff.status === 'requested') {
    return {
      connectionId,
      status: 'requested',
      requestedAt: overview.credentialHandoff.requestedAt,
    }
  }

  if (!overview.credentialHandoff.requestable) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_CREDENTIAL_HANDOFF_BLOCKED',
      message: 'Connector credential handoff is not available for the current setup state',
      source: 'adapter',
      operation: 'requestConnectorCredentialHandoff',
      i18nKey: 'erp.errors.credentialHandoffBlocked',
    })
  }

  const now = new Date().toISOString()
  const update = await pulsIntegration()
    .from('erp_connections')
    .update({
      credential_handoff_status: 'requested',
      credential_handoff_requested_at: now,
      credential_handoff_requested_by_employee_id: ctx.employeeId,
      credential_handoff_updated_at: now,
      updated_by_employee_id: ctx.employeeId,
    })
    .eq('id', connectionId)
    .eq('tenant_id', ctx.tenantId)
    .select('id')
    .single()

  if (update.error) {
    throw fromSupabaseError(
      update.error,
      'requestConnectorCredentialHandoff',
      'puls_integration',
      'erp_connections',
    )
  }

  const write = await pulsIntegration()
    .from('erp_sync_batches')
    .insert({
      tenant_id: ctx.tenantId,
      connection_id: connectionId,
      sync_type: 'credential_handoff',
      event_key: 'credential_handoff_requested',
      actor_employee_id: ctx.employeeId,
      status: 'partial_success',
      started_at: now,
      finished_at: now,
      records_seen: 1,
      records_inserted: 0,
      records_updated: 1,
      records_failed: 0,
      error_summary: null,
      safe_error_code: null,
      safe_error_context: {
        handoff_request_recorded: true,
        reference_available: false,
      },
      next_action_key: 'wait_for_secure_reference',
    })
    .select('id')
    .single()

  if (write.error) {
    throw fromSupabaseError(
      write.error,
      'requestConnectorCredentialHandoff',
      'puls_integration',
      'erp_sync_batches',
    )
  }

  return {
    connectionId,
    status: 'requested',
    requestedAt: now,
  }
}

export async function runConnectorImportPreview(
  userId: string,
): Promise<RunConnectorImportPreviewResult> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_TENANT_REQUIRED',
      message: 'Connector import preview requires tenant context',
      source: 'adapter',
      operation: 'runConnectorImportPreview',
      i18nKey: 'erp.errors.tenantMissing',
    })
  }
  if (ctx.personaRole !== 'hr_admin' && ctx.personaRole !== 'superadmin') {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_ADMIN_REQUIRED',
      message: 'Connector import preview requires admin permission',
      source: 'adapter',
      operation: 'runConnectorImportPreview',
      i18nKey: 'erp.errors.adminRequired',
    })
  }

  const overview = await fetchRealErpOverview(userId)
  const connectionId = overview.provider.id
  const batch = overview.importPreview.batch
  if (!connectionId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_SOURCE_REQUIRED',
      message: 'Connector import preview requires a selected source',
      source: 'adapter',
      operation: 'runConnectorImportPreview',
      i18nKey: 'erp.errors.sourceMissing',
    })
  }
  if (!batch) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_IMPORT_BATCH_REQUIRED',
      message: 'Connector import preview requires a dry-run import batch',
      source: 'adapter',
      operation: 'runConnectorImportPreview',
      i18nKey: 'erp.errors.importBatchMissing',
    })
  }
  if (batch.mode !== 'dry_run') {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_IMPORT_PREVIEW_BLOCKED',
      message: 'Connector import preview only supports dry-run batches',
      source: 'adapter',
      operation: 'runConnectorImportPreview',
      i18nKey: 'erp.errors.importPreviewBlocked',
    })
  }

  if (batch.status === 'previewed') {
    return {
      connectionId,
      batchId: batch.id,
      status: 'preview_ready',
      rowCount: batch.rowCount,
      createCount: batch.createCount,
      updateCount: batch.updateCount,
      skipCount: batch.skipCount,
      errorCount: batch.errorCount,
    }
  }

  let rowCount = batch.rowCount
  let errorCount = batch.errorCount
  const now = new Date().toISOString()

  if (batch.status !== 'validated') {
    const validation = await pulsIntegration().rpc('validate_import_batch', {
      p_batch_id: batch.id,
    })
    if (validation.error) {
      throw fromConnectorRpcError(validation.error, 'runConnectorImportPreview')
    }

    const validationData = (validation.data ?? {}) as {
      row_count?: number
      error_count?: number
    }
    rowCount = Number(validationData.row_count ?? rowCount)
    errorCount = Number(validationData.error_count ?? errorCount)
  }

  if (errorCount > 0) {
    const writeBlocked = await pulsIntegration()
      .from('erp_sync_batches')
      .insert({
        tenant_id: ctx.tenantId,
        connection_id: connectionId,
        sync_type: 'import_preview',
        event_key: 'import_preview_blocked',
        actor_employee_id: ctx.employeeId,
        status: 'partial_success',
        started_at: now,
        finished_at: now,
        records_seen: rowCount,
        records_inserted: 0,
        records_updated: 0,
        records_failed: errorCount,
        error_summary: null,
        safe_error_code: 'import_preview_has_errors',
        safe_error_context: {
          mode: 'dry_run',
          source_namespace_code: batch.sourceNamespaceCode,
          row_count: rowCount,
          error_count: errorCount,
        },
        next_action_key: 'review_import_errors',
      })
      .select('id')
      .single()

    if (writeBlocked.error) {
      throw fromSupabaseError(
        writeBlocked.error,
        'runConnectorImportPreview',
        'puls_integration',
        'erp_sync_batches',
      )
    }

    return {
      connectionId,
      batchId: batch.id,
      status: 'blocked',
      rowCount,
      createCount: 0,
      updateCount: 0,
      skipCount: 0,
      errorCount,
    }
  }

  const preview = await pulsIntegration().rpc('preview_import_diff', {
    p_batch_id: batch.id,
  })
  if (preview.error) {
    throw fromConnectorRpcError(preview.error, 'runConnectorImportPreview')
  }

  const previewData = (preview.data ?? {}) as {
    create_count?: number
    update_count?: number
    skip_count?: number
  }
  const createCount = Number(previewData.create_count ?? 0)
  const updateCount = Number(previewData.update_count ?? 0)
  const skipCount = Number(previewData.skip_count ?? 0)

  const write = await pulsIntegration()
    .from('erp_sync_batches')
    .insert({
      tenant_id: ctx.tenantId,
      connection_id: connectionId,
      sync_type: 'import_preview',
      event_key: 'import_preview_generated',
      actor_employee_id: ctx.employeeId,
      status: 'success',
      started_at: now,
      finished_at: now,
      records_seen: rowCount,
      records_inserted: createCount,
      records_updated: updateCount,
      records_failed: 0,
      error_summary: null,
      safe_error_code: null,
      safe_error_context: {
        mode: 'dry_run',
        source_namespace_code: batch.sourceNamespaceCode,
        row_count: rowCount,
        create_count: createCount,
        update_count: updateCount,
        skip_count: skipCount,
      },
      next_action_key: 'review_import_preview',
    })
    .select('id')
    .single()

  if (write.error) {
    throw fromSupabaseError(
      write.error,
      'runConnectorImportPreview',
      'puls_integration',
      'erp_sync_batches',
    )
  }

  return {
    connectionId,
    batchId: batch.id,
    status: 'preview_ready',
    rowCount,
    createCount,
    updateCount,
    skipCount,
    errorCount: 0,
  }
}

export async function requestConnectorApplyReview(
  userId: string,
): Promise<RequestConnectorApplyReviewResult> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_TENANT_REQUIRED',
      message: 'Connector apply review requires tenant context',
      source: 'adapter',
      operation: 'requestConnectorApplyReview',
      i18nKey: 'erp.errors.tenantMissing',
    })
  }
  if (ctx.personaRole !== 'hr_admin' && ctx.personaRole !== 'superadmin') {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_ADMIN_REQUIRED',
      message: 'Connector apply review requires admin permission',
      source: 'adapter',
      operation: 'requestConnectorApplyReview',
      i18nKey: 'erp.errors.adminRequired',
    })
  }

  const overview = await fetchRealErpOverview(userId)
  const connectionId = overview.provider.id
  const batch = overview.importPreview.batch
  if (!connectionId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_SOURCE_REQUIRED',
      message: 'Connector apply review requires a selected source',
      source: 'adapter',
      operation: 'requestConnectorApplyReview',
      i18nKey: 'erp.errors.sourceMissing',
    })
  }
  if (!batch) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_IMPORT_BATCH_REQUIRED',
      message: 'Connector apply review requires a preview batch',
      source: 'adapter',
      operation: 'requestConnectorApplyReview',
      i18nKey: 'erp.errors.importBatchMissing',
    })
  }
  if (overview.applyReadiness.status === 'review_requested') {
    return {
      connectionId,
      batchId: batch.id,
      status: 'review_requested',
      requestedAt: overview.applyReadiness.reviewRequestedAt,
      safeToApply: false,
    }
  }
  if (!overview.applyReadiness.requestable) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_APPLY_REVIEW_BLOCKED',
      message: 'Connector apply review is blocked until preview is ready',
      source: 'adapter',
      operation: 'requestConnectorApplyReview',
      i18nKey: 'erp.errors.applyReviewBlocked',
    })
  }

  const now = new Date().toISOString()
  const write = await pulsIntegration()
    .from('erp_sync_batches')
    .insert({
      tenant_id: ctx.tenantId,
      connection_id: connectionId,
      sync_type: 'import_apply_review',
      event_key: 'import_apply_review_requested',
      actor_employee_id: ctx.employeeId,
      status: 'success',
      started_at: now,
      finished_at: now,
      records_seen: overview.applyReadiness.summary.rowCount,
      records_inserted: overview.applyReadiness.summary.createCount,
      records_updated: overview.applyReadiness.summary.updateCount,
      records_failed: 0,
      error_summary: null,
      safe_error_code: null,
      safe_error_context: {
        mode: batch.mode,
        source_namespace_code: batch.sourceNamespaceCode,
        row_count: overview.applyReadiness.summary.rowCount,
        create_count: overview.applyReadiness.summary.createCount,
        update_count: overview.applyReadiness.summary.updateCount,
        skip_count: overview.applyReadiness.summary.skipCount,
        blocker_count: overview.applyReadiness.summary.blockerCount,
        safe_to_apply: false,
        apply_execution_open: false,
        human_review_recorded: true,
      },
      next_action_key: 'hold_for_apply_design',
    })
    .select('id')
    .single()

  if (write.error) {
    throw fromSupabaseError(
      write.error,
      'requestConnectorApplyReview',
      'puls_integration',
      'erp_sync_batches',
    )
  }

  return {
    connectionId,
    batchId: batch.id,
    status: 'review_requested',
    requestedAt: now,
    safeToApply: false,
  }
}

export async function recordConnectorApplyApproval(
  userId: string,
): Promise<RecordConnectorApplyApprovalResult> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_TENANT_REQUIRED',
      message: 'Connector apply approval requires tenant context',
      source: 'adapter',
      operation: 'recordConnectorApplyApproval',
      i18nKey: 'erp.errors.tenantMissing',
    })
  }
  if (ctx.personaRole !== 'hr_admin' && ctx.personaRole !== 'superadmin') {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_ADMIN_REQUIRED',
      message: 'Connector apply approval requires admin permission',
      source: 'adapter',
      operation: 'recordConnectorApplyApproval',
      i18nKey: 'erp.errors.adminRequired',
    })
  }

  const overview = await fetchRealErpOverview(userId)
  const connectionId = overview.provider.id
  const batch = overview.importPreview.batch
  if (!connectionId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_SOURCE_REQUIRED',
      message: 'Connector apply approval requires a selected source',
      source: 'adapter',
      operation: 'recordConnectorApplyApproval',
      i18nKey: 'erp.errors.sourceMissing',
    })
  }
  if (!batch) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_IMPORT_BATCH_REQUIRED',
      message: 'Connector apply approval requires a preview batch',
      source: 'adapter',
      operation: 'recordConnectorApplyApproval',
      i18nKey: 'erp.errors.importBatchMissing',
    })
  }
  if (overview.applyApprovalPolicy.status === 'approval_recorded') {
    return {
      connectionId,
      batchId: batch.id,
      status: 'approval_recorded',
      approvalRecordedAt: overview.applyApprovalPolicy.approvalRecordedAt,
      safeToApply: false,
    }
  }
  if (!overview.applyApprovalPolicy.requestable) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_APPLY_APPROVAL_BLOCKED',
      message: 'Connector apply approval is blocked until preview review is recorded',
      source: 'adapter',
      operation: 'recordConnectorApplyApproval',
      i18nKey: 'erp.errors.applyApprovalBlocked',
    })
  }

  const now = new Date().toISOString()
  const write = await pulsIntegration()
    .from('erp_sync_batches')
    .insert({
      tenant_id: ctx.tenantId,
      connection_id: connectionId,
      sync_type: 'import_apply_review',
      event_key: 'import_apply_approval_recorded',
      actor_employee_id: ctx.employeeId,
      status: 'success',
      started_at: now,
      finished_at: now,
      records_seen: overview.importPreview.summary.rowCount,
      records_inserted: overview.importPreview.summary.createCount,
      records_updated: overview.importPreview.summary.updateCount,
      records_failed: 0,
      error_summary: null,
      safe_error_code: null,
      safe_error_context: {
        mode: batch.mode,
        source_namespace_code: batch.sourceNamespaceCode,
        row_count: overview.importPreview.summary.rowCount,
        create_count: overview.importPreview.summary.createCount,
        update_count: overview.importPreview.summary.updateCount,
        skip_count: overview.importPreview.summary.skipCount,
        approval_policy: 'admin_only',
        approval_recorded: true,
        approver_role: ctx.personaRole,
        safe_to_apply: false,
        apply_execution_open: false,
        canonical_write_open: false,
      },
      next_action_key: 'hold_for_apply_execution_design',
    })
    .select('id')
    .single()

  if (write.error) {
    throw fromSupabaseError(
      write.error,
      'recordConnectorApplyApproval',
      'puls_integration',
      'erp_sync_batches',
    )
  }

  return {
    connectionId,
    batchId: batch.id,
    status: 'approval_recorded',
    approvalRecordedAt: now,
    safeToApply: false,
  }
}

export async function runConnectorPreflight(userId: string): Promise<RunConnectorPreflightResult> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_TENANT_REQUIRED',
      message: 'Connector setup check requires tenant context',
      source: 'adapter',
      operation: 'runConnectorPreflight',
      i18nKey: 'erp.errors.tenantMissing',
    })
  }
  if (ctx.personaRole !== 'hr_admin' && ctx.personaRole !== 'superadmin') {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_ADMIN_REQUIRED',
      message: 'Connector setup check requires admin permission',
      source: 'adapter',
      operation: 'runConnectorPreflight',
      i18nKey: 'erp.errors.adminRequired',
    })
  }

  const overview = await fetchRealErpOverview(userId)
  const connectionId = overview.provider.id
  if (!connectionId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_SOURCE_REQUIRED',
      message: 'Connector setup check requires a selected source',
      source: 'adapter',
      operation: 'runConnectorPreflight',
      i18nKey: 'erp.errors.sourceMissing',
    })
  }

  const status = overview.preflight.status
  const connectionUpdate =
    status === 'ready'
      ? {
          setup_status: 'preflight_ready',
          setup_step: 'preflight',
          updated_by_employee_id: ctx.employeeId,
        }
      : overview.setup.status === 'preflight_ready'
        ? {
            setup_status: 'mapping_ready',
            setup_step: 'preflight',
            updated_by_employee_id: ctx.employeeId,
          }
        : null

  if (connectionUpdate) {
    const update = await pulsIntegration()
      .from('erp_connections')
      .update(connectionUpdate)
      .eq('id', connectionId)
      .eq('tenant_id', ctx.tenantId)
      .select('id')
      .single()

    if (update.error) {
      throw fromSupabaseError(
        update.error,
        'runConnectorPreflight',
        'puls_integration',
        'erp_connections',
      )
    }
  }

  const now = new Date().toISOString()
  const safeErrorCode =
    overview.preflight.blockedCount > 0
      ? 'setup_preflight_blocked'
      : overview.preflight.warningCount > 0
        ? 'setup_preflight_has_warnings'
        : null
  const write = await pulsIntegration()
    .from('erp_sync_batches')
    .insert({
      tenant_id: ctx.tenantId,
      connection_id: connectionId,
      sync_type: 'setup_preflight',
      event_key: 'setup_preflight_completed',
      actor_employee_id: ctx.employeeId,
      status: mapPreflightStatusToSyncStatus(status),
      started_at: now,
      finished_at: now,
      records_seen: overview.preflight.checks.length,
      records_inserted: overview.preflight.passedCount,
      records_updated: overview.preflight.warningCount,
      records_failed: overview.preflight.blockedCount,
      error_summary: null,
      safe_error_code: safeErrorCode,
      safe_error_context: {
        checks_total: overview.preflight.checks.length,
        passed_count: overview.preflight.passedCount,
        warning_count: overview.preflight.warningCount,
        blocked_count: overview.preflight.blockedCount,
        blocked_checks: overview.preflight.checks
          .filter((check) => check.status === 'blocked')
          .map((check) => check.id),
        warning_checks: overview.preflight.checks
          .filter((check) => check.status === 'partial')
          .map((check) => check.id),
      },
      next_action_key: safeErrorCode ? 'review_setup_findings' : 'runtime_still_closed',
    })
    .select('id')
    .single()

  if (write.error) {
    throw fromSupabaseError(
      write.error,
      'runConnectorPreflight',
      'puls_integration',
      'erp_sync_batches',
    )
  }

  return {
    connectionId,
    status,
    passedCount: overview.preflight.passedCount,
    warningCount: overview.preflight.warningCount,
    blockedCount: overview.preflight.blockedCount,
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
