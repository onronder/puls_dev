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

export type ConnectorApplyChangeSetStatus =
  | 'not_available'
  | 'needs_preview'
  | 'needs_generation'
  | 'ready_for_create_only_review'
  | 'blocked'

export type ConnectorApplyChangeSetAction =
  | 'none'
  | 'run_preview_first'
  | 'generate_change_set'
  | 'review_change_set'
  | 'resolve_blockers'

export type ConnectorApplyRiskClass =
  | 'create_only'
  | 'no_change_skip'
  | 'safe_additive_update'
  | 'guarded_overwrite'
  | 'destructive_equivalent'
  | 'source_conflict'
  | 'stale_preview'
  | 'rollback_required'

export type ConnectorApplyChangeSetItemSummary = {
  id: string
  rowNumber: number
  entityType: string
  externalId: string
  targetTable: string
  operation: ConnectorApplyOperation | null
  riskClass: ConnectorApplyRiskClass
  blocked: boolean
  riskReasons: string[]
  auditTiers: ConnectorApplyAuditTier[]
  retentionBucket: 'object_event' | 'field_diff' | 'rollback_snapshot'
  expectedCurrentHashAvailable: boolean
  safeFieldNames: string[]
  destructiveFieldNames: string[]
  rollbackSnapshotRequired: boolean
}

export type ConnectorApplyChangeSet = {
  id: string | null
  status: ConnectorApplyChangeSetStatus
  readiness: ConnectorReadinessStatus
  statusLabelKey: string
  descriptionKey: string
  action: ConnectorApplyChangeSetAction
  actionLabelKey: string
  actionDescriptionKey: string
  requestable: boolean
  safeToApply: false
  executionEnabled: false
  canonicalWriteEnabled: false
  sourceWritebackEnabled: false
  credentialReadbackEnabled: false
  approvalRequired: boolean
  batchId: string | null
  sourceChecksum: string | null
  changeSetChecksum: string | null
  previewedAt: string | null
  createdAt: string | null
  summary: {
    rowCount: number
    createCount: number
    updateCount: number
    skipCount: number
    blockedCount: number
    staleCount: number
    destructiveCount: number
    sourceConflictCount: number
    guardedUpdateCount: number
    noChangeCount: number
  }
  sampleItems: ConnectorApplyChangeSetItemSummary[]
}

export type ConnectorGuardedUpdateEvidenceStatus =
  | 'not_available'
  | 'needs_change_set'
  | 'needs_evidence'
  | 'evidence_ready'
  | 'blocked'

export type ConnectorGuardedUpdateEvidenceAction =
  | 'none'
  | 'generate_evidence'
  | 'review_evidence'
  | 'resolve_blockers'

export type ConnectorGuardedUpdateFieldDiffSummary = {
  id: string
  rowNumber: number
  entityType: string
  externalId: string
  targetTable: string
  fieldName: string
  fieldClass: 'safe' | 'sensitive' | 'destructive_equivalent'
  operation: 'set' | 'clear'
  beforeValueHashAvailable: boolean
  afterValueHashAvailable: boolean
  beforeValuePresent: boolean
  afterValuePresent: boolean
  expectedCurrentHashAvailable: boolean
  currentHashAvailable: boolean
  staleBlocked: boolean
  rollbackSnapshotRequired: boolean
  retentionBucket: 'field_diff'
  hotRetentionExpiresAt: string | null
}

export type ConnectorGuardedUpdateEvidence = {
  changeSetId: string | null
  status: ConnectorGuardedUpdateEvidenceStatus
  readiness: ConnectorReadinessStatus
  statusLabelKey: string
  descriptionKey: string
  action: ConnectorGuardedUpdateEvidenceAction
  actionLabelKey: string
  actionDescriptionKey: string
  requestable: boolean
  safeToApply: false
  safeToExecute: false
  executionEnabled: false
  canonicalWriteEnabled: false
  sourceWritebackEnabled: false
  credentialReadbackEnabled: false
  valueReadbackEnabled: false
  batchId: string | null
  generatedAt: string | null
  summary: {
    guardedUpdateCount: number
    fieldDiffCount: number
    rollbackSnapshotCount: number
    staleBlockedCount: number
    hotRetentionDays: number
  }
  sampleFieldDiffs: ConnectorGuardedUpdateFieldDiffSummary[]
}

export type ConnectorGuardedUpdateRecoveryStatus =
  | 'not_available'
  | 'needs_apply'
  | 'recovery_ready'
  | 'object_event_incomplete'
  | 'field_diff_incomplete'
  | 'rollback_snapshot_incomplete'
  | 'hot_retention_expired'

export type ConnectorGuardedUpdateRecoveryAction =
  | 'none'
  | 'wait_for_apply'
  | 'review_recovery'
  | 'review_gap'
  | 'prepare_compensating_review'

export type ConnectorGuardedUpdateRecoveryEventSummary = {
  id: string
  rowNumber: number
  operation: 'update'
  entityType: string
  externalId: string
  targetTable: string
  canonicalId: string | null
  connectorJobId: string | null
  createdByWorkerId: string | null
  createdAt: string | null
  safeFieldNames: string[]
  fieldDiffCount: number
  rollbackSnapshotRequired: boolean
  canonicalWrite: boolean
  sourceWriteback: boolean
  providerApiCalls: boolean
  credentialReadback: boolean
  fieldValueReadback: boolean
  rawPayloadReadback: boolean
  rollbackExecution: boolean
}

export type ConnectorGuardedUpdateRecoveryReadiness = {
  changeSetId: string | null
  status: ConnectorGuardedUpdateRecoveryStatus
  readiness: ConnectorReadinessStatus
  statusLabelKey: string
  descriptionKey: string
  action: ConnectorGuardedUpdateRecoveryAction
  actionLabelKey: string
  actionDescriptionKey: string
  rollbackExecutionEnabled: false
  compensatingPreviewEnabled: false
  sourceWritebackEnabled: false
  credentialReadbackEnabled: false
  valueReadbackEnabled: false
  batchId: string | null
  appliedAt: string | null
  hotRetentionExpiresAt: string | null
  purgeAfterAt: string | null
  purgeArchiveRequired: boolean
  nextActionKey: string | null
  summary: {
    updateCount: number
    objectEventCount: number
    fieldDiffCount: number
    rollbackSnapshotCount: number
    rollbackReadyCount: number
    staleRecheckVerifiedCount: number
    recoveryWindowHotRetentionDays: number
  }
  sampleEvents: ConnectorGuardedUpdateRecoveryEventSummary[]
}

export type ConnectorGuardedUpdateRecoveryRunbookStatus =
  | 'not_available'
  | 'needs_apply'
  | 'ready_for_rollback_preview'
  | 'evidence_gap'
  | 'compensating_review_required'

export type ConnectorGuardedUpdateRecoveryRunbookAction =
  | 'none'
  | 'wait_for_apply'
  | 'prepare_rollback_preview'
  | 'repair_evidence_gap'
  | 'prepare_compensating_review'

export type ConnectorGuardedUpdateRecoveryRunbookStepStatus =
  | 'pending'
  | 'verified'
  | 'blocked'
  | 'candidate'

export type ConnectorGuardedUpdateRecoveryRunbookStep = {
  stepKey: string
  stepStatus: ConnectorGuardedUpdateRecoveryRunbookStepStatus
  evidenceCount: number
  requiredCount: number
  blockerCode: string | null
  nextActionKey: string | null
  labelKey: string
  statusLabelKey: string
}

export type ConnectorGuardedUpdateRecoveryRunbook = {
  changeSetId: string | null
  status: ConnectorGuardedUpdateRecoveryRunbookStatus
  readiness: ConnectorReadinessStatus
  statusLabelKey: string
  descriptionKey: string
  recommendedAction: ConnectorGuardedUpdateRecoveryRunbookAction
  actionLabelKey: string
  actionDescriptionKey: string
  rollbackPreviewCandidate: boolean
  rollbackPreviewEnabled: false
  rollbackExecutionEnabled: false
  compensatingExecutionEnabled: false
  sourceWritebackEnabled: false
  credentialReadbackEnabled: false
  valueReadbackEnabled: false
  operatorReviewRequired: boolean
  approvalRequired: boolean
  batchId: string | null
  appliedAt: string | null
  hotRetentionExpiresAt: string | null
  purgeAfterAt: string | null
  blockerCodes: string[]
  nextActionKey: string | null
  summary: {
    updateCount: number
    objectEventCount: number
    fieldDiffCount: number
    rollbackSnapshotCount: number
    rollbackReadyCount: number
    staleRecheckVerifiedCount: number
  }
  safeSteps: ConnectorGuardedUpdateRecoveryRunbookStep[]
}

export type ConnectorGuardedUpdateRollbackPreviewStatus =
  | 'not_available'
  | 'needs_generation'
  | 'ready_for_rollback_review'
  | 'blocked'

export type ConnectorGuardedUpdateRollbackPreviewAction =
  | 'none'
  | 'generate_preview'
  | 'review_preview'
  | 'resolve_blockers'

export type ConnectorGuardedUpdateRollbackPreviewItem = {
  id: string
  rowNumber: number
  entityType: string
  externalId: string
  targetTable: string
  canonicalId: string | null
  operation: 'rollback'
  itemStatus: 'ready' | 'blocked'
  riskClass: 'rollback_preview_required'
  blockerCodes: string[]
  safeFieldNames: string[]
  rollbackFieldNames: string[]
  fieldDiffCount: number
  rollbackSnapshotAvailable: boolean
  snapshotState: string
  snapshotHashAvailable: boolean
  expectedPostApplyHashAvailable: boolean
  currentHashAvailable: boolean
  currentStateMatchesApply: boolean
  staleBlocked: boolean
  retentionBucket: 'rollback_snapshot'
  hotRetentionExpiresAt: string | null
  purgeAfterAt: string | null
}

export type ConnectorGuardedUpdateRollbackPreview = {
  rollbackPreviewId: string | null
  changeSetId: string | null
  status: ConnectorGuardedUpdateRollbackPreviewStatus
  readiness: ConnectorReadinessStatus
  statusLabelKey: string
  descriptionKey: string
  action: ConnectorGuardedUpdateRollbackPreviewAction
  actionLabelKey: string
  actionDescriptionKey: string
  rollbackPreviewEnabled: boolean
  rollbackExecutionEnabled: false
  compensatingExecutionEnabled: false
  sourceWritebackEnabled: false
  credentialReadbackEnabled: false
  valueReadbackEnabled: false
  approvalRequired: boolean
  operatorReviewRequired: boolean
  batchId: string | null
  nextActionKey: string | null
  createdAt: string | null
  summary: {
    rowCount: number
    rollbackCount: number
    blockedCount: number
    staleBlockedCount: number
    fieldDiffCount: number
    rollbackSnapshotCount: number
  }
  sampleItems: ConnectorGuardedUpdateRollbackPreviewItem[]
}

export type ConnectorGuardedUpdateRollbackApprovalStatus =
  | 'not_available'
  | 'needs_preview'
  | 'needs_approval'
  | 'approval_recorded'
  | 'blocked'

export type ConnectorGuardedUpdateRollbackApprovalAction =
  | 'none'
  | 'generate_preview_first'
  | 'record_admin_approval'
  | 'approval_recorded'
  | 'resolve_blockers'

export type ConnectorGuardedUpdateRollbackApproval = {
  rollbackApprovalId: string | null
  rollbackPreviewId: string | null
  changeSetId: string | null
  status: ConnectorGuardedUpdateRollbackApprovalStatus
  readiness: ConnectorReadinessStatus
  statusLabelKey: string
  descriptionKey: string
  action: ConnectorGuardedUpdateRollbackApprovalAction
  actionLabelKey: string
  actionDescriptionKey: string
  requestable: boolean
  rollbackApprovalEnabled: boolean
  rollbackExecutionEnabled: false
  compensatingExecutionEnabled: false
  sourceWritebackEnabled: false
  credentialReadbackEnabled: false
  valueReadbackEnabled: false
  approvalRequired: boolean
  operatorReviewRequired: boolean
  batchId: string | null
  rollbackPreviewChecksum: string | null
  approvedAt: string | null
  approvedByEmployeeId: string | null
  nextActionKey: string | null
  summary: {
    rowCount: number
    rollbackCount: number
    blockedCount: number
    staleBlockedCount: number
    fieldDiffCount: number
    rollbackSnapshotCount: number
  }
}

export type ConnectorGuardedUpdateRollbackWorkerReadinessStatus =
  | 'not_available'
  | 'needs_approval'
  | 'needs_generation'
  | 'ready_for_worker_handoff'
  | 'blocked'

export type ConnectorGuardedUpdateRollbackWorkerReadinessAction =
  | 'none'
  | 'record_approval_first'
  | 'generate_readiness'
  | 'review_readiness'
  | 'resolve_blockers'

export type ConnectorGuardedUpdateRollbackWorkerReadinessItem = {
  id: string
  rowNumber: number
  operation: 'rollback'
  entityType: string
  externalId: string
  targetTable: string
  canonicalId: string | null
  safeFieldNames: string[]
  rollbackFieldNames: string[]
  fieldDiffCount: number
  rollbackSnapshotAvailable: boolean
  currentHashAvailable: boolean
  currentStateMatchesApply: boolean
  originalApplyEventCount: number
  rollbackExecution: boolean
  canonicalWrite: boolean
  sourceWriteback: boolean
  providerApiCalls: boolean
  credentialReadback: boolean
  fieldValueReadback: boolean
  rawPayloadReadback: boolean
  snapshotPayloadReadback: boolean
}

export type ConnectorGuardedUpdateRollbackWorkerReadiness = {
  rollbackWorkerReadinessId: string | null
  rollbackApprovalId: string | null
  rollbackPreviewId: string | null
  changeSetId: string | null
  status: ConnectorGuardedUpdateRollbackWorkerReadinessStatus
  readiness: ConnectorReadinessStatus
  statusLabelKey: string
  descriptionKey: string
  action: ConnectorGuardedUpdateRollbackWorkerReadinessAction
  actionLabelKey: string
  actionDescriptionKey: string
  requestable: boolean
  workerHandoffReady: boolean
  rollbackJobEnqueueEnabled: false
  rollbackExecutionEnabled: false
  canonicalWriteEnabled: false
  compensatingExecutionEnabled: false
  sourceWritebackEnabled: false
  credentialReadbackEnabled: false
  valueReadbackEnabled: false
  providerApiCallsEnabled: false
  approvalRequired: boolean
  operatorReviewRequired: boolean
  batchId: string | null
  workerContract: string | null
  expectedJobType: string | null
  expectedJobDomain: string | null
  rollbackPreviewChecksum: string | null
  nextActionKey: string | null
  createdAt: string | null
  summary: {
    rowCount: number
    rollbackCount: number
    blockerCount: number
    staleBlockedCount: number
    driftBlockedCount: number
    expiredSnapshotCount: number
    fieldDiffCount: number
    rollbackSnapshotCount: number
    originalApplyEventCount: number
    currentStateVerifiedCount: number
    retentionVerifiedCount: number
  }
  sampleItems: ConnectorGuardedUpdateRollbackWorkerReadinessItem[]
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
  | 'direct_rpc_permission'
  | 'worker_apply_gate'
  | 'crud_audit_policy'
  | 'retention_policy'
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
  contractVersion: ConnectorApplySafetyContract['contractVersion']
  executionEnabled: boolean
  canonicalWriteEnabled: boolean
  sourceWritebackEnabled: boolean
  credentialReadbackEnabled: boolean
  applyRpcExposed: boolean
  browserDirectApplyEnabled: boolean
  authenticatedApplyRpcExposed: boolean
  workerImportApplyEnqueueEnabled: boolean
  workerImportApplyClaimEnabled: boolean
  safeToExecute: boolean
  executorMode: 'future_background_job' | 'worker_create_only_job' | 'worker_guarded_update_job'
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

export type ConnectorApplySafetyPolicyState =
  | 'create_only'
  | 'guarded_update'
  | 'blocked_destructive'
  | 'rollback_preview_required'

export type ConnectorApplyOperation =
  | 'insert'
  | 'update'
  | 'soft_delete'
  | 'restore'
  | 'rollback'
  | 'compensating_update'

export type ConnectorApplyAuditTier =
  | 'object_event'
  | 'field_diff'
  | 'rollback_snapshot'
  | 'archive_summary'

export type ConnectorApplySafetyContract = {
  contractVersion: string
  browserDirectApplyEnabled: boolean
  authenticatedApplyRpcExposed: boolean
  workerImportApplyEnqueueEnabled: boolean
  workerImportApplyClaimEnabled: boolean
  executionEnabled: boolean
  canonicalWriteEnabled: boolean
  sourceWritebackEnabled: boolean
  credentialReadbackEnabled: boolean
  policyStates: ConnectorApplySafetyPolicyState[]
  coveredOperations: ConnectorApplyOperation[]
  auditTiers: ConnectorApplyAuditTier[]
  destructiveFieldClasses: string[]
  fieldDiffHotRetentionDays: number
  rollbackSnapshotHotRetentionDays: number
  objectEventRetentionMonths: number
  purgeArchiveRequired: boolean
  safeErrorCode: string
  nextActionKey: string
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
    | 'import_apply_execution'
    | 'sync_batch'
}

export type ConnectorActivityEventKind =
  | 'setup_lifecycle'
  | 'setup_preflight'
  | 'credential_handoff'
  | 'credential_reference'
  | 'import_preview'
  | 'import_apply_review'
  | 'import_apply_execution'
  | 'connector_job'
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

export type ConnectorRuntimeJobStatus =
  | 'queued'
  | 'running'
  | 'succeeded'
  | 'failed'
  | 'retrying'
  | 'cancelled'
  | 'dead_letter'

export type ConnectorRuntimeJobType =
  | 'setup_preflight'
  | 'credential_verification'
  | 'import_preview'
  | 'import_apply'
  | 'connector_runtime_preflight'
  | 'source_discovery'
  | 'noop_health'

export type ConnectorRuntimeQueueStatus = 'not_available' | 'contract_ready' | 'active' | 'blocked'

export type ConnectorRuntimeWorkerStatus = 'not_configured' | 'idle' | 'running' | 'stale' | 'error'

export type ConnectorRuntimeLeaseStatus = 'not_started' | 'active' | 'expired' | 'released'

export type ConnectorRuntimeFailureClass =
  | 'none'
  | 'transient'
  | 'credential'
  | 'mapping'
  | 'provider_limit'
  | 'provider_unavailable'
  | 'worker'
  | 'unsupported'
  | 'unknown'

export type ConnectorRuntimeOperatorSeverity = 'info' | 'warning' | 'error' | 'critical'

export type ConnectorRuntimeWorker = {
  status: ConnectorRuntimeWorkerStatus
  readiness: ConnectorReadinessStatus
  statusLabelKey: string
  descriptionKey: string
  workerId: string | null
  runtimeVersion: string | null
  supportedJobTypes: ConnectorRuntimeJobType[]
  lastSeenAt: string | null
  lastClaimedJobId: string | null
  safeErrorCode: string | null
  safeErrorSummaryKey: string | null
}

export type ConnectorRuntimeJobSummary = {
  id: string
  jobType: ConnectorRuntimeJobType
  status: ConnectorRuntimeJobStatus
  level: ConnectorSyncLogLevel
  domain: string | null
  statusLabelKey: string
  titleKey: string
  summaryKey: string
  safeErrorCode: string | null
  safeErrorSummaryKey: string | null
  nextActionKey: string
  failureClass: ConnectorRuntimeFailureClass
  failureClassLabelKey: string
  operatorSeverity: ConnectorRuntimeOperatorSeverity
  operatorSeverityLabelKey: string
  retryAfterSeconds: number
  nextRetryAt: string | null
  lastFailureAt: string | null
  deadLetteredAt: string | null
  operatorReviewRequired: boolean
  attemptCount: number
  maxAttempts: number
  priority: number
  scheduledAt: string | null
  startedAt: string | null
  finishedAt: string | null
  lockedAt: string | null
  lockedBy: string | null
  workerHeartbeatAt: string | null
  leaseExpiresAt: string | null
  leaseStatus: ConnectorRuntimeLeaseStatus
  leaseStatusLabelKey: string
  sourceNamespaceId: string | null
  importBatchId: string | null
  createdAt: string | null
  updatedAt: string | null
}

export type ConnectorRuntimeQueue = {
  contractVersion: 'pr15.2-worker-skeleton-v1'
  status: ConnectorRuntimeQueueStatus
  readiness: ConnectorReadinessStatus
  statusLabelKey: string
  descriptionKey: string
  workerEnabled: boolean
  executionEnabled: false
  worker: ConnectorRuntimeWorker
  jobs: ConnectorRuntimeJobSummary[]
  summary: {
    total: number
    queued: number
    running: number
    retrying: number
    succeeded: number
    failed: number
    deadLetter: number
    operatorReviewRequired: number
  }
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
  applyChangeSet: ConnectorApplyChangeSet
  guardedUpdateEvidence: ConnectorGuardedUpdateEvidence
  guardedUpdateRecovery: ConnectorGuardedUpdateRecoveryReadiness
  guardedUpdateRecoveryRunbook: ConnectorGuardedUpdateRecoveryRunbook
  guardedUpdateRollbackPreview: ConnectorGuardedUpdateRollbackPreview
  guardedUpdateRollbackApproval: ConnectorGuardedUpdateRollbackApproval
  guardedUpdateRollbackWorkerReadiness: ConnectorGuardedUpdateRollbackWorkerReadiness
  applySafetyContract: ConnectorApplySafetyContract
  controlledApplyPlan: ConnectorControlledApplyPlan
  applyExecutionContract: ConnectorApplyExecutionContract
  runtimeQueue: ConnectorRuntimeQueue
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

type ConnectorJobRow = {
  id?: string | null
  job_type?: ConnectorRuntimeJobType | null
  status?: ConnectorRuntimeJobStatus | null
  domain?: string | null
  priority?: number | null
  attempt_count?: number | null
  max_attempts?: number | null
  scheduled_at?: string | null
  started_at?: string | null
  finished_at?: string | null
  locked_at?: string | null
  locked_by?: string | null
  worker_heartbeat_at?: string | null
  lease_expires_at?: string | null
  safe_error_code?: string | null
  safe_error_context?: Record<string, unknown> | null
  next_action_key?: string | null
  failure_class?: ConnectorRuntimeFailureClass | null
  operator_severity?: ConnectorRuntimeOperatorSeverity | null
  retry_after_seconds?: number | null
  last_failure_at?: string | null
  dead_lettered_at?: string | null
  operator_review_required?: boolean | null
  connection_id?: string | null
  source_namespace_id?: string | null
  import_batch_id?: string | null
  created_at?: string | null
  updated_at?: string | null
}

type ConnectorJobEventRow = {
  id?: string | null
  tenant_id?: string | null
  connection_id?: string | null
  job_id?: string | null
  job_type?: ConnectorRuntimeJobType | null
  status?: ConnectorRuntimeJobStatus | null
  event_key?: string | null
  level?: ConnectorRuntimeOperatorSeverity | null
  failure_class?: ConnectorRuntimeFailureClass | null
  safe_error_code?: string | null
  safe_error_context?: Record<string, unknown> | null
  next_action_key?: string | null
  retry_after_seconds?: number | null
  operator_review_required?: boolean | null
  worker_id?: string | null
  created_at?: string | null
}

type ConnectorApplySafetyContractRow = {
  connection_id?: string | null
  tenant_id?: string | null
  contract_version?: string | null
  browser_direct_apply_enabled?: boolean | null
  authenticated_apply_rpc_exposed?: boolean | null
  worker_import_apply_enqueue_enabled?: boolean | null
  worker_import_apply_claim_enabled?: boolean | null
  execution_enabled?: boolean | null
  canonical_write_enabled?: boolean | null
  source_writeback_enabled?: boolean | null
  credential_readback_enabled?: boolean | null
  policy_states?: ConnectorApplySafetyPolicyState[] | null
  covered_operations?: ConnectorApplyOperation[] | null
  audit_tiers?: ConnectorApplyAuditTier[] | null
  destructive_field_classes?: string[] | null
  field_diff_hot_retention_days?: number | null
  rollback_snapshot_hot_retention_days?: number | null
  object_event_retention_months?: number | null
  purge_archive_required?: boolean | null
  safe_error_code?: string | null
  next_action_key?: string | null
}

type ConnectorApplyChangeSetRow = {
  id?: string | null
  tenant_id?: string | null
  connection_id?: string | null
  source_namespace_id?: string | null
  import_batch_id?: string | null
  status?: 'ready_for_create_only_review' | 'blocked' | null
  source_checksum?: string | null
  change_set_checksum?: string | null
  previewed_at?: string | null
  row_count?: number | null
  create_count?: number | null
  update_count?: number | null
  skip_count?: number | null
  blocked_count?: number | null
  stale_count?: number | null
  destructive_count?: number | null
  source_conflict_count?: number | null
  guarded_update_count?: number | null
  no_change_count?: number | null
  execution_enabled?: boolean | null
  canonical_write_enabled?: boolean | null
  source_writeback_enabled?: boolean | null
  credential_readback_enabled?: boolean | null
  approval_required?: boolean | null
  safe_summary?: Record<string, unknown> | null
  sample_items?: unknown
  created_at?: string | null
}

type ConnectorGuardedUpdateEvidenceRow = {
  change_set_id?: string | null
  tenant_id?: string | null
  connection_id?: string | null
  source_namespace_id?: string | null
  import_batch_id?: string | null
  status?: 'needs_evidence' | 'evidence_ready' | null
  guarded_update_count?: number | null
  field_diff_count?: number | null
  rollback_snapshot_count?: number | null
  stale_blocked_count?: number | null
  execution_enabled?: boolean | null
  canonical_write_enabled?: boolean | null
  source_writeback_enabled?: boolean | null
  credential_readback_enabled?: boolean | null
  value_readback_enabled?: boolean | null
  hot_retention_days?: number | null
  next_action_key?: string | null
  sample_field_diffs?: unknown
  created_at?: string | null
}

type ConnectorGuardedUpdateRecoveryReadinessRow = {
  change_set_id?: string | null
  tenant_id?: string | null
  connection_id?: string | null
  source_namespace_id?: string | null
  import_batch_id?: string | null
  status?:
    | 'needs_apply'
    | 'recovery_ready'
    | 'object_event_incomplete'
    | 'field_diff_incomplete'
    | 'rollback_snapshot_incomplete'
    | 'hot_retention_expired'
    | null
  applied_at?: string | null
  update_count?: number | null
  object_event_count?: number | null
  field_diff_count?: number | null
  rollback_snapshot_count?: number | null
  rollback_ready_count?: number | null
  stale_recheck_verified_count?: number | null
  rollback_execution_enabled?: boolean | null
  compensating_preview_enabled?: boolean | null
  source_writeback_enabled?: boolean | null
  credential_readback_enabled?: boolean | null
  value_readback_enabled?: boolean | null
  recovery_window_hot_retention_days?: number | null
  hot_retention_expires_at?: string | null
  purge_after_at?: string | null
  purge_archive_required?: boolean | null
  next_action_key?: string | null
  sample_events?: unknown
  created_at?: string | null
}

type ConnectorGuardedUpdateRecoveryRunbookRow = {
  change_set_id?: string | null
  tenant_id?: string | null
  connection_id?: string | null
  source_namespace_id?: string | null
  import_batch_id?: string | null
  status?:
    | 'needs_apply'
    | 'ready_for_rollback_preview'
    | 'evidence_gap'
    | 'compensating_review_required'
    | null
  recommended_action?:
    | 'wait_for_apply'
    | 'prepare_rollback_preview'
    | 'repair_evidence_gap'
    | 'prepare_compensating_review'
    | null
  readiness_status?: ConnectorReadinessStatus | null
  applied_at?: string | null
  update_count?: number | null
  object_event_count?: number | null
  field_diff_count?: number | null
  rollback_snapshot_count?: number | null
  rollback_ready_count?: number | null
  stale_recheck_verified_count?: number | null
  blocker_codes?: unknown
  operator_review_required?: boolean | null
  approval_required?: boolean | null
  rollback_preview_candidate?: boolean | null
  rollback_preview_enabled?: boolean | null
  rollback_execution_enabled?: boolean | null
  compensating_execution_enabled?: boolean | null
  source_writeback_enabled?: boolean | null
  credential_readback_enabled?: boolean | null
  value_readback_enabled?: boolean | null
  hot_retention_expires_at?: string | null
  purge_after_at?: string | null
  next_action_key?: string | null
  safe_steps?: unknown
  created_at?: string | null
}

type ConnectorGuardedUpdateRollbackPreviewRow = {
  rollback_preview_id?: string | null
  change_set_id?: string | null
  tenant_id?: string | null
  connection_id?: string | null
  source_namespace_id?: string | null
  import_batch_id?: string | null
  status?: 'ready_for_rollback_review' | 'blocked' | null
  preview_kind?: 'rollback' | null
  rollback_preview_checksum?: string | null
  row_count?: number | null
  rollback_count?: number | null
  blocked_count?: number | null
  stale_blocked_count?: number | null
  field_diff_count?: number | null
  rollback_snapshot_count?: number | null
  rollback_preview_enabled?: boolean | null
  rollback_execution_enabled?: boolean | null
  compensating_execution_enabled?: boolean | null
  source_writeback_enabled?: boolean | null
  credential_readback_enabled?: boolean | null
  value_readback_enabled?: boolean | null
  approval_required?: boolean | null
  operator_review_required?: boolean | null
  next_action_key?: string | null
  sample_items?: unknown
  created_at?: string | null
}

type ConnectorGuardedUpdateRollbackApprovalRow = {
  rollback_approval_id?: string | null
  rollback_preview_id?: string | null
  change_set_id?: string | null
  tenant_id?: string | null
  connection_id?: string | null
  source_namespace_id?: string | null
  import_batch_id?: string | null
  approval_status?: 'approval_recorded' | null
  approval_policy?: 'admin_only' | null
  rollback_preview_checksum?: string | null
  row_count?: number | null
  rollback_count?: number | null
  blocked_count?: number | null
  stale_blocked_count?: number | null
  field_diff_count?: number | null
  rollback_snapshot_count?: number | null
  rollback_approval_enabled?: boolean | null
  rollback_execution_enabled?: boolean | null
  compensating_execution_enabled?: boolean | null
  source_writeback_enabled?: boolean | null
  credential_readback_enabled?: boolean | null
  value_readback_enabled?: boolean | null
  approval_required?: boolean | null
  operator_review_required?: boolean | null
  next_action_key?: string | null
  approved_by_employee_id?: string | null
  approved_at?: string | null
  safe_summary?: Record<string, unknown> | null
}

type ConnectorGuardedUpdateRollbackWorkerReadinessRow = {
  rollback_worker_readiness_id?: string | null
  rollback_approval_id?: string | null
  rollback_preview_id?: string | null
  change_set_id?: string | null
  tenant_id?: string | null
  connection_id?: string | null
  source_namespace_id?: string | null
  import_batch_id?: string | null
  readiness_status?: 'ready_for_worker_handoff' | null
  readiness_policy?: 'approval_checksum_current_state_retention' | null
  worker_contract?: 'pr16.7-rollback-worker-readiness-v1' | null
  expected_job_type?: 'import_apply' | null
  expected_job_domain?: 'import_apply_guarded_update_rollback' | null
  rollback_preview_checksum?: string | null
  row_count?: number | null
  rollback_count?: number | null
  blocker_count?: number | null
  stale_blocked_count?: number | null
  drift_blocked_count?: number | null
  expired_snapshot_count?: number | null
  field_diff_count?: number | null
  rollback_snapshot_count?: number | null
  original_apply_event_count?: number | null
  current_state_verified_count?: number | null
  retention_verified_count?: number | null
  approval_verified?: boolean | null
  approval_checksum_verified?: boolean | null
  worker_handoff_ready?: boolean | null
  rollback_job_enqueue_enabled?: boolean | null
  rollback_execution_enabled?: boolean | null
  canonical_write_enabled?: boolean | null
  compensating_execution_enabled?: boolean | null
  source_writeback_enabled?: boolean | null
  credential_readback_enabled?: boolean | null
  value_readback_enabled?: boolean | null
  provider_api_calls_enabled?: boolean | null
  approval_required?: boolean | null
  operator_review_required?: boolean | null
  next_action_key?: string | null
  safe_summary?: Record<string, unknown> | null
  sample_items?: unknown
  created_at?: string | null
}

type ConnectorCreateOnlyApplyJobRow = {
  job_id?: string | null
  status?: ConnectorRuntimeJobStatus | null
  change_set_id?: string | null
  import_batch_id?: string | null
  create_count?: number | null
  next_action_key?: string | null
}

type ConnectorGuardedUpdateApplyJobRow = {
  job_id?: string | null
  status?: ConnectorRuntimeJobStatus | null
  change_set_id?: string | null
  import_batch_id?: string | null
  update_count?: number | null
  field_diff_count?: number | null
  rollback_snapshot_count?: number | null
  next_action_key?: string | null
}

type ConnectorGuardedUpdateRollbackApplyJobRow = {
  job_id?: string | null
  status?: ConnectorRuntimeJobStatus | null
  rollback_worker_readiness_id?: string | null
  rollback_approval_id?: string | null
  rollback_preview_id?: string | null
  change_set_id?: string | null
  import_batch_id?: string | null
  rollback_count?: number | null
  field_diff_count?: number | null
  rollback_snapshot_count?: number | null
  next_action_key?: string | null
}

type ConnectorCredentialEventRow = {
  id?: string | null
  tenant_id?: string | null
  connection_id?: string | null
  event_key?:
    | 'reference_configured'
    | 'reference_updated'
    | 'reference_revoked'
    | 'verification_succeeded'
    | 'verification_failed'
    | null
  auth_mode?: ConnectorAuthMode | null
  credential_state?: ConnectorCredentialState | null
  actor_employee_id?: string | null
  safe_error_code?: string | null
  safe_context?: Record<string, unknown> | null
  next_action_key?: string | null
  created_at?: string | null
}

type ConnectorWorkerHeartbeatRow = {
  worker_id?: string | null
  status?: 'idle' | 'claiming' | 'running' | 'recovering' | 'paused' | 'error' | null
  runtime_version?: string | null
  supported_job_types?: ConnectorRuntimeJobType[] | null
  last_seen_at?: string | null
  last_claimed_job_id?: string | null
  safe_error_code?: string | null
  safe_context?: Record<string, unknown> | null
  created_at?: string | null
  updated_at?: string | null
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

export type RequestConnectorApplyChangeSetResult = {
  connectionId: string
  batchId: string
  changeSetId: string | null
  status: ConnectorApplyChangeSetStatus
  blockedCount: number
  safeToApply: false
}

export type RequestConnectorGuardedUpdateEvidenceResult = {
  connectionId: string
  batchId: string
  changeSetId: string
  status: ConnectorGuardedUpdateEvidenceStatus
  fieldDiffCount: number
  rollbackSnapshotCount: number
  safeToApply: false
}

export type RequestConnectorCreateOnlyApplyJobResult = {
  connectionId: string
  batchId: string
  changeSetId: string
  jobId: string | null
  status: ConnectorRuntimeJobStatus
  nextActionKey: string
  safeToApply: false
}

export type RequestConnectorGuardedUpdateApplyJobResult = {
  connectionId: string
  batchId: string
  changeSetId: string
  jobId: string | null
  status: ConnectorRuntimeJobStatus
  nextActionKey: string
  safeToApply: false
}

export type RecordConnectorGuardedUpdateRollbackApprovalResult = {
  connectionId: string
  batchId: string
  changeSetId: string
  rollbackPreviewId: string
  rollbackApprovalId: string | null
  status: ConnectorGuardedUpdateRollbackApprovalStatus
  approvedAt: string | null
  nextActionKey: string | null
  safeToRollback: false
}

export type RequestConnectorGuardedUpdateRollbackWorkerReadinessResult = {
  connectionId: string
  batchId: string
  changeSetId: string
  rollbackPreviewId: string
  rollbackApprovalId: string
  rollbackWorkerReadinessId: string | null
  status: ConnectorGuardedUpdateRollbackWorkerReadinessStatus
  workerContract: string | null
  expectedJobType: string | null
  expectedJobDomain: string | null
  nextActionKey: string | null
  safeToRollback: false
}

export type RequestConnectorGuardedUpdateRollbackApplyJobResult = {
  connectionId: string
  batchId: string
  changeSetId: string
  rollbackPreviewId: string
  rollbackApprovalId: string
  rollbackWorkerReadinessId: string
  jobId: string | null
  status: ConnectorRuntimeJobStatus
  nextActionKey: string
  safeToRollback: false
}

export type RequestConnectorRuntimePreflightResult = {
  connectionId: string
  jobId: string | null
  status: ConnectorRuntimeJobStatus
  credentialState: ConnectorCredentialState
  nextActionKey: string
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
    | 'apply_change_set_blocked'
    | 'create_only_apply_blocked'
    | 'guarded_update_apply_blocked'
    | 'rollback_approval_blocked'
    | 'rollback_worker_readiness_blocked'
    | 'rollback_apply_blocked'
    | 'runtime_preflight_blocked'
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
    if (
      error.code === 'PULS_CONNECTOR_APPLY_CHANGE_SET_BLOCKED' ||
      error.code === 'PULS_CONNECTOR_APPLY_CHANGE_SET_PREVIEW_REQUIRED' ||
      error.code === 'PULS_CONNECTOR_APPLY_CHANGE_SET_ROW_ERRORS' ||
      error.code === 'PULS_CONNECTOR_APPLY_CHANGE_SET_CHECKSUM_REQUIRED' ||
      error.code === 'PULS_CONNECTOR_APPLY_CHANGE_SET_DRY_RUN_REQUIRED'
    ) {
      return {
        code: 'apply_change_set_blocked',
        toastKey: 'erp.errors.applyChangeSetBlocked',
      }
    }
    if (error.code.startsWith('PULS_CONNECTOR_CREATE_ONLY_')) {
      return {
        code: 'create_only_apply_blocked',
        toastKey: 'erp.errors.createOnlyApplyBlocked',
      }
    }
    if (error.code.startsWith('PULS_CONNECTOR_ROLLBACK_APPROVAL_')) {
      return {
        code: 'rollback_approval_blocked',
        toastKey: 'erp.errors.rollbackApprovalBlocked',
      }
    }
    if (error.code.startsWith('PULS_CONNECTOR_ROLLBACK_WORKER_READINESS_')) {
      return {
        code: 'rollback_worker_readiness_blocked',
        toastKey: 'erp.errors.rollbackWorkerReadinessBlocked',
      }
    }
    if (error.code.startsWith('PULS_CONNECTOR_ROLLBACK_WORKER_')) {
      return {
        code: 'rollback_apply_blocked',
        toastKey: 'erp.errors.rollbackApplyBlocked',
      }
    }
    if (error.code.startsWith('PULS_CONNECTOR_GUARDED_UPDATE_')) {
      return {
        code: 'guarded_update_apply_blocked',
        toastKey: 'erp.errors.guardedUpdateApplyBlocked',
      }
    }
    if (
      error.code === 'PULS_CONNECTOR_RUNTIME_PREFLIGHT_CREDENTIAL_NOT_VERIFIED' ||
      error.code === 'PULS_CONNECTOR_JOB_CREDENTIAL_NOT_VERIFIED'
    ) {
      return {
        code: 'runtime_preflight_blocked',
        toastKey: 'erp.errors.runtimePreflightBlocked',
      }
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
        : code.startsWith('PULS_CONNECTOR_APPLY_CHANGE_SET_')
          ? 'erp.errors.applyChangeSetBlocked'
          : code.startsWith('PULS_CONNECTOR_CREATE_ONLY_')
            ? 'erp.errors.createOnlyApplyBlocked'
            : code.startsWith('PULS_CONNECTOR_GUARDED_UPDATE_')
              ? 'erp.errors.guardedUpdateApplyBlocked'
              : code === 'PULS_CONNECTOR_RUNTIME_PREFLIGHT_CREDENTIAL_NOT_VERIFIED' ||
                  code === 'PULS_CONNECTOR_JOB_CREDENTIAL_NOT_VERIFIED'
                ? 'erp.errors.runtimePreflightBlocked'
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

function normalizeStringArray(value: unknown): string[] {
  return Array.isArray(value)
    ? value.filter((item): item is string => typeof item === 'string')
    : []
}

function normalizeAuditTierArray(value: unknown): ConnectorApplyAuditTier[] {
  const allowed = new Set<ConnectorApplyAuditTier>([
    'object_event',
    'field_diff',
    'rollback_snapshot',
    'archive_summary',
  ])
  return normalizeStringArray(value).filter((item): item is ConnectorApplyAuditTier =>
    allowed.has(item as ConnectorApplyAuditTier),
  )
}

function normalizeApplyOperation(value: unknown): ConnectorApplyOperation | null {
  const allowed = new Set<ConnectorApplyOperation>([
    'insert',
    'update',
    'soft_delete',
    'restore',
    'rollback',
    'compensating_update',
  ])
  return typeof value === 'string' && allowed.has(value as ConnectorApplyOperation)
    ? (value as ConnectorApplyOperation)
    : null
}

function normalizeApplyRiskClass(value: unknown): ConnectorApplyRiskClass {
  const allowed = new Set<ConnectorApplyRiskClass>([
    'create_only',
    'no_change_skip',
    'safe_additive_update',
    'guarded_overwrite',
    'destructive_equivalent',
    'source_conflict',
    'stale_preview',
    'rollback_required',
  ])
  return typeof value === 'string' && allowed.has(value as ConnectorApplyRiskClass)
    ? (value as ConnectorApplyRiskClass)
    : 'stale_preview'
}

function normalizeRetentionBucket(
  value: unknown,
): ConnectorApplyChangeSetItemSummary['retentionBucket'] {
  return value === 'field_diff' || value === 'rollback_snapshot' ? value : 'object_event'
}

function normalizeApplyChangeSetItems(value: unknown): ConnectorApplyChangeSetItemSummary[] {
  if (!Array.isArray(value)) return []

  return value
    .filter((item): item is Record<string, unknown> => item != null && typeof item === 'object')
    .map((item, index) => ({
      id: typeof item.id === 'string' ? item.id : `change-set-item-${index}`,
      rowNumber: Number(item.row_number ?? index + 1),
      entityType: typeof item.entity_type === 'string' ? item.entity_type : 'unknown',
      externalId: typeof item.external_id === 'string' ? item.external_id : '—',
      targetTable: typeof item.target_table === 'string' ? item.target_table : 'unknown',
      operation: normalizeApplyOperation(item.operation),
      riskClass: normalizeApplyRiskClass(item.risk_class),
      blocked: item.blocked === true,
      riskReasons: normalizeStringArray(item.risk_reasons),
      auditTiers: normalizeAuditTierArray(item.audit_tiers),
      retentionBucket: normalizeRetentionBucket(item.retention_bucket),
      expectedCurrentHashAvailable: item.expected_current_hash_available === true,
      safeFieldNames: normalizeStringArray(item.safe_field_names),
      destructiveFieldNames: normalizeStringArray(item.destructive_field_names),
      rollbackSnapshotRequired: item.rollback_snapshot_required === true,
    }))
}

function normalizeGuardedUpdateFieldClass(
  value: unknown,
): ConnectorGuardedUpdateFieldDiffSummary['fieldClass'] {
  return value === 'sensitive' || value === 'destructive_equivalent' ? value : 'safe'
}

function normalizeGuardedUpdateFieldOperation(
  value: unknown,
): ConnectorGuardedUpdateFieldDiffSummary['operation'] {
  return value === 'clear' ? 'clear' : 'set'
}

function normalizeGuardedUpdateFieldDiffs(
  value: unknown,
): ConnectorGuardedUpdateFieldDiffSummary[] {
  if (!Array.isArray(value)) return []

  return value
    .filter((item): item is Record<string, unknown> => item != null && typeof item === 'object')
    .map((item, index) => ({
      id: typeof item.id === 'string' ? item.id : `guarded-update-field-${index}`,
      rowNumber: Number(item.row_number ?? index + 1),
      entityType: typeof item.entity_type === 'string' ? item.entity_type : 'unknown',
      externalId: typeof item.external_id === 'string' ? item.external_id : '—',
      targetTable: typeof item.target_table === 'string' ? item.target_table : 'unknown',
      fieldName: typeof item.field_name === 'string' ? item.field_name : 'unknown',
      fieldClass: normalizeGuardedUpdateFieldClass(item.field_class),
      operation: normalizeGuardedUpdateFieldOperation(item.operation),
      beforeValueHashAvailable: item.before_value_hash_available === true,
      afterValueHashAvailable: item.after_value_hash_available === true,
      beforeValuePresent: item.before_value_present === true,
      afterValuePresent: item.after_value_present === true,
      expectedCurrentHashAvailable: item.expected_current_hash_available === true,
      currentHashAvailable: item.current_hash_available === true,
      staleBlocked: item.stale_blocked === true,
      rollbackSnapshotRequired: item.rollback_snapshot_required === true,
      retentionBucket: 'field_diff',
      hotRetentionExpiresAt:
        typeof item.hot_retention_expires_at === 'string' ? item.hot_retention_expires_at : null,
    }))
}

function normalizeGuardedUpdateRecoveryEvents(
  value: unknown,
): ConnectorGuardedUpdateRecoveryEventSummary[] {
  if (!Array.isArray(value)) return []

  return value
    .filter((item): item is Record<string, unknown> => item != null && typeof item === 'object')
    .map((item, index) => ({
      id: typeof item.id === 'string' ? item.id : `guarded-update-recovery-event-${index}`,
      rowNumber: Number(item.row_number ?? index + 1),
      operation: 'update',
      entityType: typeof item.entity_type === 'string' ? item.entity_type : 'unknown',
      externalId: typeof item.external_id === 'string' ? item.external_id : '—',
      targetTable: typeof item.target_table === 'string' ? item.target_table : 'unknown',
      canonicalId: typeof item.canonical_id === 'string' ? item.canonical_id : null,
      connectorJobId: typeof item.connector_job_id === 'string' ? item.connector_job_id : null,
      createdByWorkerId:
        typeof item.created_by_worker_id === 'string' ? item.created_by_worker_id : null,
      createdAt: typeof item.created_at === 'string' ? item.created_at : null,
      safeFieldNames: normalizeStringArray(item.safe_field_names),
      fieldDiffCount: Number(item.field_diff_count ?? 0),
      rollbackSnapshotRequired: item.rollback_snapshot_required === true,
      canonicalWrite: item.canonical_write === true,
      sourceWriteback: item.source_writeback === true,
      providerApiCalls: item.provider_api_calls === true,
      credentialReadback: item.credential_readback === true,
      fieldValueReadback: item.field_value_readback === true,
      rawPayloadReadback: item.raw_payload_readback === true,
      rollbackExecution: item.rollback_execution === true,
    }))
}

function normalizeGuardedUpdateRecoveryRunbookSteps(
  value: unknown,
): ConnectorGuardedUpdateRecoveryRunbookStep[] {
  if (!Array.isArray(value)) return []

  const allowedStatuses = new Set<ConnectorGuardedUpdateRecoveryRunbookStepStatus>([
    'pending',
    'verified',
    'blocked',
    'candidate',
  ])

  return value
    .filter((item): item is Record<string, unknown> => item != null && typeof item === 'object')
    .map((item, index) => {
      const stepKey =
        typeof item.step_key === 'string' && item.step_key.trim()
          ? item.step_key
          : `step_${index + 1}`
      const rawStatus = item.step_status
      const stepStatus =
        typeof rawStatus === 'string' &&
        allowedStatuses.has(rawStatus as ConnectorGuardedUpdateRecoveryRunbookStepStatus)
          ? (rawStatus as ConnectorGuardedUpdateRecoveryRunbookStepStatus)
          : 'pending'

      return {
        stepKey,
        stepStatus,
        evidenceCount: Number(item.evidence_count ?? 0),
        requiredCount: Number(item.required_count ?? 0),
        blockerCode: typeof item.blocker_code === 'string' ? item.blocker_code : null,
        nextActionKey: typeof item.next_action_key === 'string' ? item.next_action_key : null,
        labelKey: `erp.guardedUpdateRecoveryRunbook.steps.${stepKey}.label`,
        statusLabelKey: `erp.guardedUpdateRecoveryRunbook.stepStatus.${stepStatus}`,
      }
    })
}

function normalizeGuardedUpdateRollbackPreviewItems(
  value: unknown,
): ConnectorGuardedUpdateRollbackPreviewItem[] {
  if (!Array.isArray(value)) return []

  return value
    .filter((item): item is Record<string, unknown> => item != null && typeof item === 'object')
    .map((item, index) => ({
      id: typeof item.id === 'string' ? item.id : `rollback-preview-item-${index}`,
      rowNumber: Number(item.row_number ?? index + 1),
      entityType: typeof item.entity_type === 'string' ? item.entity_type : 'unknown',
      externalId: typeof item.external_id === 'string' ? item.external_id : '—',
      targetTable: typeof item.target_table === 'string' ? item.target_table : 'unknown',
      canonicalId: typeof item.canonical_id === 'string' ? item.canonical_id : null,
      operation: 'rollback',
      itemStatus: item.item_status === 'ready' ? 'ready' : 'blocked',
      riskClass: 'rollback_preview_required',
      blockerCodes: normalizeStringArray(item.blocker_codes),
      safeFieldNames: normalizeStringArray(item.safe_field_names),
      rollbackFieldNames: normalizeStringArray(item.rollback_field_names),
      fieldDiffCount: Number(item.field_diff_count ?? 0),
      rollbackSnapshotAvailable: item.rollback_snapshot_available === true,
      snapshotState: typeof item.snapshot_state === 'string' ? item.snapshot_state : 'missing',
      snapshotHashAvailable: item.snapshot_hash_available === true,
      expectedPostApplyHashAvailable: item.expected_post_apply_hash_available === true,
      currentHashAvailable: item.current_hash_available === true,
      currentStateMatchesApply: item.current_state_matches_apply === true,
      staleBlocked: item.stale_blocked === true,
      retentionBucket: 'rollback_snapshot',
      hotRetentionExpiresAt:
        typeof item.hot_retention_expires_at === 'string' ? item.hot_retention_expires_at : null,
      purgeAfterAt: typeof item.purge_after_at === 'string' ? item.purge_after_at : null,
    }))
}

function normalizeGuardedUpdateRollbackWorkerReadinessItems(
  value: unknown,
): ConnectorGuardedUpdateRollbackWorkerReadinessItem[] {
  if (!Array.isArray(value)) return []

  return value
    .filter((item): item is Record<string, unknown> => item != null && typeof item === 'object')
    .map((item, index) => ({
      id: `rollback-worker-readiness-item-${index}`,
      rowNumber: Number(item.row_number ?? index + 1),
      operation: 'rollback',
      entityType: typeof item.entity_type === 'string' ? item.entity_type : 'unknown',
      externalId: typeof item.external_id === 'string' ? item.external_id : '—',
      targetTable: typeof item.target_table === 'string' ? item.target_table : 'unknown',
      canonicalId: typeof item.canonical_id === 'string' ? item.canonical_id : null,
      safeFieldNames: normalizeStringArray(item.safe_field_names),
      rollbackFieldNames: normalizeStringArray(item.rollback_field_names),
      fieldDiffCount: Number(item.field_diff_count ?? 0),
      rollbackSnapshotAvailable: item.rollback_snapshot_available === true,
      currentHashAvailable: item.current_hash_available === true,
      currentStateMatchesApply: item.current_state_matches_apply === true,
      originalApplyEventCount: Number(item.original_apply_event_count ?? 0),
      rollbackExecution: item.rollback_execution === true,
      canonicalWrite: item.canonical_write === true,
      sourceWriteback: item.source_writeback === true,
      providerApiCalls: item.provider_api_calls === true,
      credentialReadback: item.credential_readback === true,
      fieldValueReadback: item.field_value_readback === true,
      rawPayloadReadback: item.raw_payload_readback === true,
      snapshotPayloadReadback: item.snapshot_payload_readback === true,
    }))
}

function emptyConnectorApplyChangeSet(
  connectorState: ConnectorLifecycleState,
  importPreview: ConnectorImportPreview,
): ConnectorApplyChangeSet {
  const batch = importPreview.batch
  const previewReady = Boolean(batch?.id && importPreview.status === 'preview_ready')
  const status: ConnectorApplyChangeSetStatus =
    connectorState !== 'connector_selected' || !batch?.id
      ? 'not_available'
      : previewReady
        ? 'needs_generation'
        : 'needs_preview'
  const action: ConnectorApplyChangeSetAction =
    status === 'needs_generation'
      ? 'generate_change_set'
      : status === 'needs_preview'
        ? 'run_preview_first'
        : 'none'
  const readiness: ConnectorReadinessStatus =
    status === 'not_available' ? 'blocked' : status === 'needs_generation' ? 'partial' : 'partial'

  return {
    id: null,
    status,
    readiness,
    statusLabelKey: `erp.applyChangeSet.status.${status}`,
    descriptionKey: `erp.applyChangeSet.descriptions.${status}`,
    action,
    actionLabelKey: `erp.applyChangeSet.actions.${action}.label`,
    actionDescriptionKey: `erp.applyChangeSet.actions.${action}.description`,
    requestable: status === 'needs_generation',
    safeToApply: false,
    executionEnabled: false,
    canonicalWriteEnabled: false,
    sourceWritebackEnabled: false,
    credentialReadbackEnabled: false,
    approvalRequired: true,
    batchId: batch?.id ?? null,
    sourceChecksum: batch?.sourceChecksum ?? null,
    changeSetChecksum: null,
    previewedAt: batch?.previewedAt ?? null,
    createdAt: null,
    summary: {
      rowCount: importPreview.summary.rowCount,
      createCount: 0,
      updateCount: 0,
      skipCount: 0,
      blockedCount: 0,
      staleCount: 0,
      destructiveCount: 0,
      sourceConflictCount: 0,
      guardedUpdateCount: 0,
      noChangeCount: 0,
    },
    sampleItems: [],
  }
}

function buildConnectorApplyChangeSet({
  connectorState,
  importPreview,
  row,
}: {
  connectorState: ConnectorLifecycleState
  importPreview: ConnectorImportPreview
  row: ConnectorApplyChangeSetRow | null
}): ConnectorApplyChangeSet {
  if (!row?.id) {
    return emptyConnectorApplyChangeSet(connectorState, importPreview)
  }

  const blockedCount = Number(row.blocked_count ?? 0)
  const status: ConnectorApplyChangeSetStatus =
    row.status === 'ready_for_create_only_review' && blockedCount === 0
      ? 'ready_for_create_only_review'
      : 'blocked'
  const action: ConnectorApplyChangeSetAction =
    status === 'ready_for_create_only_review' ? 'review_change_set' : 'resolve_blockers'

  return {
    id: row.id,
    status,
    readiness: status === 'ready_for_create_only_review' ? 'ready' : 'blocked',
    statusLabelKey: `erp.applyChangeSet.status.${status}`,
    descriptionKey: `erp.applyChangeSet.descriptions.${status}`,
    action,
    actionLabelKey: `erp.applyChangeSet.actions.${action}.label`,
    actionDescriptionKey: `erp.applyChangeSet.actions.${action}.description`,
    requestable: false,
    safeToApply: false,
    executionEnabled: false,
    canonicalWriteEnabled: false,
    sourceWritebackEnabled: false,
    credentialReadbackEnabled: false,
    approvalRequired: row.approval_required !== false,
    batchId: row.import_batch_id ?? importPreview.batch?.id ?? null,
    sourceChecksum: row.source_checksum ?? importPreview.batch?.sourceChecksum ?? null,
    changeSetChecksum: row.change_set_checksum ?? null,
    previewedAt: row.previewed_at ?? importPreview.batch?.previewedAt ?? null,
    createdAt: row.created_at ?? null,
    summary: {
      rowCount: Number(row.row_count ?? 0),
      createCount: Number(row.create_count ?? 0),
      updateCount: Number(row.update_count ?? 0),
      skipCount: Number(row.skip_count ?? 0),
      blockedCount,
      staleCount: Number(row.stale_count ?? 0),
      destructiveCount: Number(row.destructive_count ?? 0),
      sourceConflictCount: Number(row.source_conflict_count ?? 0),
      guardedUpdateCount: Number(row.guarded_update_count ?? 0),
      noChangeCount: Number(row.no_change_count ?? 0),
    },
    sampleItems: normalizeApplyChangeSetItems(row.sample_items),
  }
}

function buildConnectorGuardedUpdateEvidence({
  connectorState,
  applyChangeSet,
  row,
}: {
  connectorState: ConnectorLifecycleState
  applyChangeSet: ConnectorApplyChangeSet
  row: ConnectorGuardedUpdateEvidenceRow | null
}): ConnectorGuardedUpdateEvidence {
  const hasChangeSet = Boolean(applyChangeSet.id)
  const hasGuardedUpdates = applyChangeSet.summary.guardedUpdateCount > 0
  const hasEvidence = Boolean(row?.change_set_id)
  const hasBlockers =
    applyChangeSet.summary.staleCount > 0 ||
    applyChangeSet.summary.destructiveCount > 0 ||
    applyChangeSet.summary.sourceConflictCount > 0

  const status: ConnectorGuardedUpdateEvidenceStatus =
    connectorState !== 'connector_selected'
      ? 'not_available'
      : !hasChangeSet
        ? 'needs_change_set'
        : !hasGuardedUpdates
          ? 'not_available'
          : hasBlockers
            ? 'blocked'
            : row?.status === 'evidence_ready'
              ? 'evidence_ready'
              : 'needs_evidence'
  const action: ConnectorGuardedUpdateEvidenceAction =
    status === 'needs_evidence'
      ? 'generate_evidence'
      : status === 'evidence_ready'
        ? 'review_evidence'
        : status === 'blocked'
          ? 'resolve_blockers'
          : 'none'
  const readiness: ConnectorReadinessStatus =
    status === 'evidence_ready'
      ? 'ready'
      : status === 'needs_evidence'
        ? 'partial'
        : status === 'blocked'
          ? 'blocked'
          : 'partial'
  const guardedUpdateCount = Number(
    row?.guarded_update_count ?? applyChangeSet.summary.guardedUpdateCount,
  )
  const fieldDiffCount = Number(row?.field_diff_count ?? 0)
  const rollbackSnapshotCount = Number(row?.rollback_snapshot_count ?? 0)
  const requestable =
    status === 'needs_evidence' && hasChangeSet && hasGuardedUpdates && !hasBlockers

  return {
    changeSetId: row?.change_set_id ?? applyChangeSet.id,
    status,
    readiness,
    statusLabelKey: `erp.guardedUpdateEvidence.status.${status}`,
    descriptionKey: `erp.guardedUpdateEvidence.descriptions.${status}`,
    action,
    actionLabelKey: `erp.guardedUpdateEvidence.actions.${action}.label`,
    actionDescriptionKey: `erp.guardedUpdateEvidence.actions.${action}.description`,
    requestable,
    safeToApply: false,
    safeToExecute: false,
    executionEnabled: false,
    canonicalWriteEnabled: false,
    sourceWritebackEnabled: false,
    credentialReadbackEnabled: false,
    valueReadbackEnabled: false,
    batchId: row?.import_batch_id ?? applyChangeSet.batchId,
    generatedAt: hasEvidence ? (row?.created_at ?? null) : null,
    summary: {
      guardedUpdateCount,
      fieldDiffCount,
      rollbackSnapshotCount,
      staleBlockedCount: Number(row?.stale_blocked_count ?? 0),
      hotRetentionDays: Number(row?.hot_retention_days ?? 90),
    },
    sampleFieldDiffs: normalizeGuardedUpdateFieldDiffs(row?.sample_field_diffs),
  }
}

function buildConnectorGuardedUpdateRecoveryReadiness({
  connectorState,
  applyChangeSet,
  row,
}: {
  connectorState: ConnectorLifecycleState
  applyChangeSet: ConnectorApplyChangeSet
  row: ConnectorGuardedUpdateRecoveryReadinessRow | null
}): ConnectorGuardedUpdateRecoveryReadiness {
  const hasGuardedUpdates = applyChangeSet.summary.guardedUpdateCount > 0
  const rowStatus = row?.status ?? null
  const status: ConnectorGuardedUpdateRecoveryStatus =
    connectorState !== 'connector_selected' || !applyChangeSet.id || !hasGuardedUpdates
      ? 'not_available'
      : rowStatus === 'recovery_ready' ||
          rowStatus === 'object_event_incomplete' ||
          rowStatus === 'field_diff_incomplete' ||
          rowStatus === 'rollback_snapshot_incomplete' ||
          rowStatus === 'hot_retention_expired' ||
          rowStatus === 'needs_apply'
        ? rowStatus
        : 'needs_apply'

  const readiness: ConnectorReadinessStatus =
    status === 'recovery_ready'
      ? 'ready'
      : status === 'object_event_incomplete' ||
          status === 'field_diff_incomplete' ||
          status === 'rollback_snapshot_incomplete' ||
          status === 'hot_retention_expired'
        ? 'blocked'
        : 'partial'
  const action: ConnectorGuardedUpdateRecoveryAction =
    status === 'recovery_ready'
      ? 'review_recovery'
      : status === 'needs_apply'
        ? 'wait_for_apply'
        : status === 'hot_retention_expired'
          ? 'prepare_compensating_review'
          : status === 'not_available'
            ? 'none'
            : 'review_gap'

  return {
    changeSetId: row?.change_set_id ?? applyChangeSet.id,
    status,
    readiness,
    statusLabelKey: `erp.guardedUpdateRecovery.status.${status}`,
    descriptionKey: `erp.guardedUpdateRecovery.descriptions.${status}`,
    action,
    actionLabelKey: `erp.guardedUpdateRecovery.actions.${action}.label`,
    actionDescriptionKey: `erp.guardedUpdateRecovery.actions.${action}.description`,
    rollbackExecutionEnabled: false,
    compensatingPreviewEnabled: false,
    sourceWritebackEnabled: false,
    credentialReadbackEnabled: false,
    valueReadbackEnabled: false,
    batchId: row?.import_batch_id ?? applyChangeSet.batchId,
    appliedAt: row?.applied_at ?? null,
    hotRetentionExpiresAt: row?.hot_retention_expires_at ?? null,
    purgeAfterAt: row?.purge_after_at ?? null,
    purgeArchiveRequired: row?.purge_archive_required !== false,
    nextActionKey: row?.next_action_key ?? null,
    summary: {
      updateCount: Number(row?.update_count ?? applyChangeSet.summary.updateCount),
      objectEventCount: Number(row?.object_event_count ?? 0),
      fieldDiffCount: Number(row?.field_diff_count ?? 0),
      rollbackSnapshotCount: Number(row?.rollback_snapshot_count ?? 0),
      rollbackReadyCount: Number(row?.rollback_ready_count ?? 0),
      staleRecheckVerifiedCount: Number(row?.stale_recheck_verified_count ?? 0),
      recoveryWindowHotRetentionDays: Number(row?.recovery_window_hot_retention_days ?? 90),
    },
    sampleEvents: normalizeGuardedUpdateRecoveryEvents(row?.sample_events),
  }
}

function buildConnectorGuardedUpdateRecoveryRunbook({
  connectorState,
  applyChangeSet,
  recovery,
  row,
}: {
  connectorState: ConnectorLifecycleState
  applyChangeSet: ConnectorApplyChangeSet
  recovery: ConnectorGuardedUpdateRecoveryReadiness
  row: ConnectorGuardedUpdateRecoveryRunbookRow | null
}): ConnectorGuardedUpdateRecoveryRunbook {
  const hasGuardedUpdates = applyChangeSet.summary.guardedUpdateCount > 0
  const rowStatus = row?.status ?? null
  const status: ConnectorGuardedUpdateRecoveryRunbookStatus =
    connectorState !== 'connector_selected' || !applyChangeSet.id || !hasGuardedUpdates
      ? 'not_available'
      : rowStatus === 'ready_for_rollback_preview' ||
          rowStatus === 'evidence_gap' ||
          rowStatus === 'compensating_review_required' ||
          rowStatus === 'needs_apply'
        ? rowStatus
        : recovery.status === 'recovery_ready'
          ? 'ready_for_rollback_preview'
          : recovery.status === 'hot_retention_expired'
            ? 'compensating_review_required'
            : recovery.status === 'needs_apply'
              ? 'needs_apply'
              : 'evidence_gap'

  const readiness: ConnectorReadinessStatus =
    status === 'ready_for_rollback_preview'
      ? 'ready'
      : status === 'evidence_gap' || status === 'compensating_review_required'
        ? 'blocked'
        : 'partial'
  const recommendedAction: ConnectorGuardedUpdateRecoveryRunbookAction =
    status === 'ready_for_rollback_preview'
      ? 'prepare_rollback_preview'
      : status === 'evidence_gap'
        ? 'repair_evidence_gap'
        : status === 'compensating_review_required'
          ? 'prepare_compensating_review'
          : status === 'needs_apply'
            ? 'wait_for_apply'
            : 'none'

  return {
    changeSetId: row?.change_set_id ?? applyChangeSet.id,
    status,
    readiness,
    statusLabelKey: `erp.guardedUpdateRecoveryRunbook.status.${status}`,
    descriptionKey: `erp.guardedUpdateRecoveryRunbook.descriptions.${status}`,
    recommendedAction,
    actionLabelKey: `erp.guardedUpdateRecoveryRunbook.actions.${recommendedAction}.label`,
    actionDescriptionKey: `erp.guardedUpdateRecoveryRunbook.actions.${recommendedAction}.description`,
    rollbackPreviewCandidate:
      row?.rollback_preview_candidate === true || status === 'ready_for_rollback_preview',
    rollbackPreviewEnabled: false,
    rollbackExecutionEnabled: false,
    compensatingExecutionEnabled: false,
    sourceWritebackEnabled: false,
    credentialReadbackEnabled: false,
    valueReadbackEnabled: false,
    operatorReviewRequired: row?.operator_review_required !== false && status !== 'not_available',
    approvalRequired: row?.approval_required !== false && status !== 'not_available',
    batchId: row?.import_batch_id ?? recovery.batchId,
    appliedAt: row?.applied_at ?? recovery.appliedAt,
    hotRetentionExpiresAt: row?.hot_retention_expires_at ?? recovery.hotRetentionExpiresAt,
    purgeAfterAt: row?.purge_after_at ?? recovery.purgeAfterAt,
    blockerCodes: normalizeStringArray(row?.blocker_codes),
    nextActionKey: row?.next_action_key ?? recovery.nextActionKey,
    summary: {
      updateCount: Number(row?.update_count ?? recovery.summary.updateCount),
      objectEventCount: Number(row?.object_event_count ?? recovery.summary.objectEventCount),
      fieldDiffCount: Number(row?.field_diff_count ?? recovery.summary.fieldDiffCount),
      rollbackSnapshotCount: Number(
        row?.rollback_snapshot_count ?? recovery.summary.rollbackSnapshotCount,
      ),
      rollbackReadyCount: Number(row?.rollback_ready_count ?? recovery.summary.rollbackReadyCount),
      staleRecheckVerifiedCount: Number(
        row?.stale_recheck_verified_count ?? recovery.summary.staleRecheckVerifiedCount,
      ),
    },
    safeSteps: normalizeGuardedUpdateRecoveryRunbookSteps(row?.safe_steps),
  }
}

function buildConnectorGuardedUpdateRollbackPreview({
  connectorState,
  applyChangeSet,
  runbook,
  row,
}: {
  connectorState: ConnectorLifecycleState
  applyChangeSet: ConnectorApplyChangeSet
  runbook: ConnectorGuardedUpdateRecoveryRunbook
  row: ConnectorGuardedUpdateRollbackPreviewRow | null
}): ConnectorGuardedUpdateRollbackPreview {
  const hasGuardedUpdates = applyChangeSet.summary.guardedUpdateCount > 0
  const rowStatus = row?.status ?? null
  const status: ConnectorGuardedUpdateRollbackPreviewStatus =
    connectorState !== 'connector_selected' || !applyChangeSet.id || !hasGuardedUpdates
      ? 'not_available'
      : rowStatus === 'ready_for_rollback_review' || rowStatus === 'blocked'
        ? rowStatus
        : runbook.status === 'ready_for_rollback_preview'
          ? 'needs_generation'
          : 'blocked'

  const readiness: ConnectorReadinessStatus =
    status === 'ready_for_rollback_review'
      ? 'ready'
      : status === 'blocked'
        ? 'blocked'
        : status === 'needs_generation'
          ? 'partial'
          : 'blocked'
  const action: ConnectorGuardedUpdateRollbackPreviewAction =
    status === 'ready_for_rollback_review'
      ? 'review_preview'
      : status === 'needs_generation'
        ? 'generate_preview'
        : status === 'blocked'
          ? 'resolve_blockers'
          : 'none'

  return {
    rollbackPreviewId: row?.rollback_preview_id ?? null,
    changeSetId: row?.change_set_id ?? applyChangeSet.id,
    status,
    readiness,
    statusLabelKey: `erp.guardedUpdateRollbackPreview.status.${status}`,
    descriptionKey: `erp.guardedUpdateRollbackPreview.descriptions.${status}`,
    action,
    actionLabelKey: `erp.guardedUpdateRollbackPreview.actions.${action}.label`,
    actionDescriptionKey: `erp.guardedUpdateRollbackPreview.actions.${action}.description`,
    rollbackPreviewEnabled: status !== 'not_available',
    rollbackExecutionEnabled: false,
    compensatingExecutionEnabled: false,
    sourceWritebackEnabled: false,
    credentialReadbackEnabled: false,
    valueReadbackEnabled: false,
    approvalRequired: row?.approval_required !== false && status !== 'not_available',
    operatorReviewRequired: row?.operator_review_required !== false && status !== 'not_available',
    batchId: row?.import_batch_id ?? runbook.batchId,
    nextActionKey:
      row?.next_action_key ??
      (status === 'needs_generation'
        ? 'generate_guarded_update_rollback_preview'
        : runbook.nextActionKey),
    createdAt: row?.created_at ?? null,
    summary: {
      rowCount: Number(row?.row_count ?? runbook.summary.updateCount),
      rollbackCount: Number(row?.rollback_count ?? 0),
      blockedCount: Number(
        row?.blocked_count ??
          (status === 'blocked' ? Math.max(runbook.summary.updateCount, 1) : 0),
      ),
      staleBlockedCount: Number(row?.stale_blocked_count ?? 0),
      fieldDiffCount: Number(row?.field_diff_count ?? runbook.summary.fieldDiffCount),
      rollbackSnapshotCount: Number(
        row?.rollback_snapshot_count ?? runbook.summary.rollbackSnapshotCount,
      ),
    },
    sampleItems: normalizeGuardedUpdateRollbackPreviewItems(row?.sample_items),
  }
}

function buildConnectorGuardedUpdateRollbackApproval({
  connectorState,
  rollbackPreview,
  row,
}: {
  connectorState: ConnectorLifecycleState
  rollbackPreview: ConnectorGuardedUpdateRollbackPreview
  row: ConnectorGuardedUpdateRollbackApprovalRow | null
}): ConnectorGuardedUpdateRollbackApproval {
  const previewReady =
    connectorState === 'connector_selected' &&
    rollbackPreview.status === 'ready_for_rollback_review' &&
    rollbackPreview.rollbackPreviewId != null &&
    rollbackPreview.summary.rollbackCount === rollbackPreview.summary.rowCount &&
    rollbackPreview.summary.blockedCount === 0 &&
    rollbackPreview.summary.staleBlockedCount === 0 &&
    rollbackPreview.summary.fieldDiffCount > 0 &&
    rollbackPreview.summary.rollbackSnapshotCount >= rollbackPreview.summary.rowCount &&
    rollbackPreview.rollbackExecutionEnabled === false &&
    rollbackPreview.compensatingExecutionEnabled === false &&
    rollbackPreview.sourceWritebackEnabled === false &&
    rollbackPreview.credentialReadbackEnabled === false &&
    rollbackPreview.valueReadbackEnabled === false
  const approvalRecorded = row?.approval_status === 'approval_recorded'
  const status: ConnectorGuardedUpdateRollbackApprovalStatus =
    connectorState !== 'connector_selected'
      ? 'not_available'
      : approvalRecorded
        ? 'approval_recorded'
        : rollbackPreview.status === 'not_available' || rollbackPreview.status === 'needs_generation'
          ? 'needs_preview'
          : previewReady
            ? 'needs_approval'
            : 'blocked'
  const readiness: ConnectorReadinessStatus =
    status === 'approval_recorded' ? 'ready' : status === 'blocked' ? 'blocked' : 'partial'
  const action: ConnectorGuardedUpdateRollbackApprovalAction =
    status === 'approval_recorded'
      ? 'approval_recorded'
      : status === 'needs_preview'
        ? 'generate_preview_first'
        : status === 'needs_approval'
          ? 'record_admin_approval'
          : status === 'blocked'
            ? 'resolve_blockers'
            : 'none'

  return {
    rollbackApprovalId: row?.rollback_approval_id ?? null,
    rollbackPreviewId: row?.rollback_preview_id ?? rollbackPreview.rollbackPreviewId,
    changeSetId: row?.change_set_id ?? rollbackPreview.changeSetId,
    status,
    readiness,
    statusLabelKey: `erp.guardedUpdateRollbackApproval.status.${status}`,
    descriptionKey: `erp.guardedUpdateRollbackApproval.descriptions.${status}`,
    action,
    actionLabelKey: `erp.guardedUpdateRollbackApproval.actions.${action}.label`,
    actionDescriptionKey: `erp.guardedUpdateRollbackApproval.actions.${action}.description`,
    requestable: status === 'needs_approval',
    rollbackApprovalEnabled: previewReady || approvalRecorded,
    rollbackExecutionEnabled: false,
    compensatingExecutionEnabled: false,
    sourceWritebackEnabled: false,
    credentialReadbackEnabled: false,
    valueReadbackEnabled: false,
    approvalRequired: row?.approval_required !== false && status !== 'not_available',
    operatorReviewRequired: row?.operator_review_required !== false && status !== 'not_available',
    batchId: row?.import_batch_id ?? rollbackPreview.batchId,
    rollbackPreviewChecksum: row?.rollback_preview_checksum ?? null,
    approvedAt: row?.approved_at ?? null,
    approvedByEmployeeId: row?.approved_by_employee_id ?? null,
    nextActionKey:
      row?.next_action_key ??
      (status === 'needs_approval'
        ? 'record_guarded_update_rollback_approval'
        : rollbackPreview.nextActionKey),
    summary: {
      rowCount: Number(row?.row_count ?? rollbackPreview.summary.rowCount),
      rollbackCount: Number(row?.rollback_count ?? rollbackPreview.summary.rollbackCount),
      blockedCount: Number(row?.blocked_count ?? rollbackPreview.summary.blockedCount),
      staleBlockedCount: Number(
        row?.stale_blocked_count ?? rollbackPreview.summary.staleBlockedCount,
      ),
      fieldDiffCount: Number(row?.field_diff_count ?? rollbackPreview.summary.fieldDiffCount),
      rollbackSnapshotCount: Number(
        row?.rollback_snapshot_count ?? rollbackPreview.summary.rollbackSnapshotCount,
      ),
    },
  }
}

function buildConnectorGuardedUpdateRollbackWorkerReadiness({
  connectorState,
  rollbackApproval,
  row,
}: {
  connectorState: ConnectorLifecycleState
  rollbackApproval: ConnectorGuardedUpdateRollbackApproval
  row: ConnectorGuardedUpdateRollbackWorkerReadinessRow | null
}): ConnectorGuardedUpdateRollbackWorkerReadiness {
  const approvalRecorded =
    connectorState === 'connector_selected' &&
    rollbackApproval.status === 'approval_recorded' &&
    rollbackApproval.rollbackApprovalId != null &&
    rollbackApproval.rollbackPreviewId != null &&
    rollbackApproval.rollbackPreviewChecksum != null &&
    rollbackApproval.summary.rollbackCount === rollbackApproval.summary.rowCount &&
    rollbackApproval.summary.blockedCount === 0 &&
    rollbackApproval.summary.staleBlockedCount === 0 &&
    rollbackApproval.summary.fieldDiffCount > 0 &&
    rollbackApproval.summary.rollbackSnapshotCount >= rollbackApproval.summary.rowCount &&
    rollbackApproval.rollbackExecutionEnabled === false &&
    rollbackApproval.compensatingExecutionEnabled === false &&
    rollbackApproval.sourceWritebackEnabled === false &&
    rollbackApproval.credentialReadbackEnabled === false &&
    rollbackApproval.valueReadbackEnabled === false
  const readinessRecorded = row?.readiness_status === 'ready_for_worker_handoff'
  const hasReadinessBlockers =
    Number(row?.blocker_count ?? 0) > 0 ||
    Number(row?.stale_blocked_count ?? 0) > 0 ||
    Number(row?.drift_blocked_count ?? 0) > 0 ||
    Number(row?.expired_snapshot_count ?? 0) > 0
  const status: ConnectorGuardedUpdateRollbackWorkerReadinessStatus =
    connectorState !== 'connector_selected'
      ? 'not_available'
      : readinessRecorded && !hasReadinessBlockers
        ? 'ready_for_worker_handoff'
        : rollbackApproval.status === 'not_available' ||
            rollbackApproval.status === 'needs_preview' ||
            rollbackApproval.status === 'needs_approval'
          ? 'needs_approval'
          : approvalRecorded
            ? 'needs_generation'
            : 'blocked'
  const readiness: ConnectorReadinessStatus =
    status === 'ready_for_worker_handoff' ? 'ready' : status === 'blocked' ? 'blocked' : 'partial'
  const action: ConnectorGuardedUpdateRollbackWorkerReadinessAction =
    status === 'ready_for_worker_handoff'
      ? 'review_readiness'
      : status === 'needs_generation'
        ? 'generate_readiness'
        : status === 'needs_approval'
          ? 'record_approval_first'
          : status === 'blocked'
            ? 'resolve_blockers'
            : 'none'

  return {
    rollbackWorkerReadinessId: row?.rollback_worker_readiness_id ?? null,
    rollbackApprovalId: row?.rollback_approval_id ?? rollbackApproval.rollbackApprovalId,
    rollbackPreviewId: row?.rollback_preview_id ?? rollbackApproval.rollbackPreviewId,
    changeSetId: row?.change_set_id ?? rollbackApproval.changeSetId,
    status,
    readiness,
    statusLabelKey: `erp.guardedUpdateRollbackWorkerReadiness.status.${status}`,
    descriptionKey: `erp.guardedUpdateRollbackWorkerReadiness.descriptions.${status}`,
    action,
    actionLabelKey: `erp.guardedUpdateRollbackWorkerReadiness.actions.${action}.label`,
    actionDescriptionKey: `erp.guardedUpdateRollbackWorkerReadiness.actions.${action}.description`,
    requestable: status === 'needs_generation',
    workerHandoffReady: row?.worker_handoff_ready === true && status === 'ready_for_worker_handoff',
    rollbackJobEnqueueEnabled: false,
    rollbackExecutionEnabled: false,
    canonicalWriteEnabled: false,
    compensatingExecutionEnabled: false,
    sourceWritebackEnabled: false,
    credentialReadbackEnabled: false,
    valueReadbackEnabled: false,
    providerApiCallsEnabled: false,
    approvalRequired: row?.approval_required !== false && status !== 'not_available',
    operatorReviewRequired: row?.operator_review_required !== false && status !== 'not_available',
    batchId: row?.import_batch_id ?? rollbackApproval.batchId,
    workerContract: row?.worker_contract ?? null,
    expectedJobType: row?.expected_job_type ?? null,
    expectedJobDomain: row?.expected_job_domain ?? null,
    rollbackPreviewChecksum: row?.rollback_preview_checksum ?? rollbackApproval.rollbackPreviewChecksum,
    nextActionKey:
      row?.next_action_key ??
      (status === 'needs_generation'
        ? 'generate_guarded_update_rollback_worker_readiness'
        : rollbackApproval.nextActionKey),
    createdAt: row?.created_at ?? null,
    summary: {
      rowCount: Number(row?.row_count ?? rollbackApproval.summary.rowCount),
      rollbackCount: Number(row?.rollback_count ?? rollbackApproval.summary.rollbackCount),
      blockerCount: Number(row?.blocker_count ?? rollbackApproval.summary.blockedCount),
      staleBlockedCount: Number(
        row?.stale_blocked_count ?? rollbackApproval.summary.staleBlockedCount,
      ),
      driftBlockedCount: Number(row?.drift_blocked_count ?? 0),
      expiredSnapshotCount: Number(row?.expired_snapshot_count ?? 0),
      fieldDiffCount: Number(row?.field_diff_count ?? rollbackApproval.summary.fieldDiffCount),
      rollbackSnapshotCount: Number(
        row?.rollback_snapshot_count ?? rollbackApproval.summary.rollbackSnapshotCount,
      ),
      originalApplyEventCount: Number(row?.original_apply_event_count ?? 0),
      currentStateVerifiedCount: Number(row?.current_state_verified_count ?? 0),
      retentionVerifiedCount: Number(row?.retention_verified_count ?? 0),
    },
    sampleItems: normalizeGuardedUpdateRollbackWorkerReadinessItems(row?.sample_items),
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

function buildConnectorApplySafetyContract(
  row: ConnectorApplySafetyContractRow | null,
): ConnectorApplySafetyContract {
  return {
    contractVersion: row?.contract_version ?? 'pr16.1-apply-safety-contract-v1',
    browserDirectApplyEnabled: row?.browser_direct_apply_enabled === true,
    authenticatedApplyRpcExposed: row?.authenticated_apply_rpc_exposed === true,
    workerImportApplyEnqueueEnabled: row?.worker_import_apply_enqueue_enabled === true,
    workerImportApplyClaimEnabled: row?.worker_import_apply_claim_enabled === true,
    executionEnabled: row?.execution_enabled === true,
    canonicalWriteEnabled: row?.canonical_write_enabled === true,
    sourceWritebackEnabled: row?.source_writeback_enabled === true,
    credentialReadbackEnabled: row?.credential_readback_enabled === true,
    policyStates:
      row?.policy_states && row.policy_states.length > 0
        ? row.policy_states
        : ['create_only', 'guarded_update', 'blocked_destructive', 'rollback_preview_required'],
    coveredOperations:
      row?.covered_operations && row.covered_operations.length > 0
        ? row.covered_operations
        : ['insert', 'update', 'soft_delete', 'restore', 'rollback', 'compensating_update'],
    auditTiers:
      row?.audit_tiers && row.audit_tiers.length > 0
        ? row.audit_tiers
        : ['object_event', 'field_diff', 'rollback_snapshot', 'archive_summary'],
    destructiveFieldClasses:
      row?.destructive_field_classes && row.destructive_field_classes.length > 0
        ? row.destructive_field_classes
        : [
            'employment_status',
            'is_active',
            'assignment_close',
            'manager_reporting_line',
            'explicit_clear',
          ],
    fieldDiffHotRetentionDays: row?.field_diff_hot_retention_days ?? 90,
    rollbackSnapshotHotRetentionDays: row?.rollback_snapshot_hot_retention_days ?? 90,
    objectEventRetentionMonths: row?.object_event_retention_months ?? 24,
    purgeArchiveRequired: row?.purge_archive_required !== false,
    safeErrorCode: row?.safe_error_code ?? 'apply_execution_closed_pr16_1',
    nextActionKey: row?.next_action_key ?? 'implement_create_only_apply_change_set',
  }
}

function buildConnectorApplyExecutionContract({
  connectorState,
  importPreview,
  applyApprovalPolicy,
  controlledApplyPlan,
  applySafetyContract,
  applyChangeSet,
  guardedUpdateEvidence,
}: {
  connectorState: ConnectorLifecycleState
  importPreview: ConnectorImportPreview
  applyApprovalPolicy: ConnectorApplyApprovalPolicy
  controlledApplyPlan: ConnectorControlledApplyPlan
  applySafetyContract: ConnectorApplySafetyContract
  applyChangeSet: ConnectorApplyChangeSet
  guardedUpdateEvidence: ConnectorGuardedUpdateEvidence
}): ConnectorApplyExecutionContract {
  const batch = importPreview.batch
  const previewReady = Boolean(batch?.id && importPreview.status === 'preview_ready')
  const approvalRecorded = applyApprovalPolicy.status === 'approval_recorded'
  const hasChecksum = Boolean(batch?.sourceChecksum)
  const hasRowErrors = importPreview.summary.errorCount > 0
  const changeSetSummary = applyChangeSet.summary
  const createOnlyChangeSetReady =
    Boolean(applyChangeSet.id) &&
    applyChangeSet.status === 'ready_for_create_only_review' &&
    changeSetSummary.rowCount > 0 &&
    changeSetSummary.createCount === changeSetSummary.rowCount &&
    changeSetSummary.updateCount === 0 &&
    changeSetSummary.skipCount === 0 &&
    changeSetSummary.blockedCount === 0 &&
    changeSetSummary.staleCount === 0 &&
    changeSetSummary.destructiveCount === 0 &&
    changeSetSummary.sourceConflictCount === 0 &&
    changeSetSummary.guardedUpdateCount === 0 &&
    changeSetSummary.noChangeCount === 0
  const guardedUpdateEvidenceReady =
    guardedUpdateEvidence.status === 'evidence_ready' &&
    guardedUpdateEvidence.summary.fieldDiffCount > 0 &&
    guardedUpdateEvidence.summary.rollbackSnapshotCount ===
      guardedUpdateEvidence.summary.guardedUpdateCount
  const guardedUpdateChangeSetReady =
    Boolean(applyChangeSet.id) &&
    applyChangeSet.status === 'blocked' &&
    changeSetSummary.rowCount > 0 &&
    changeSetSummary.updateCount === changeSetSummary.rowCount &&
    changeSetSummary.guardedUpdateCount === changeSetSummary.rowCount &&
    changeSetSummary.createCount === 0 &&
    changeSetSummary.skipCount === 0 &&
    changeSetSummary.blockedCount === changeSetSummary.guardedUpdateCount &&
    changeSetSummary.staleCount === 0 &&
    changeSetSummary.destructiveCount === 0 &&
    changeSetSummary.sourceConflictCount === 0 &&
    changeSetSummary.noChangeCount === 0 &&
    guardedUpdateEvidenceReady
  const workerApplyBoundaryOpen =
    applySafetyContract.executionEnabled &&
    applySafetyContract.canonicalWriteEnabled &&
    applySafetyContract.workerImportApplyEnqueueEnabled &&
    applySafetyContract.workerImportApplyClaimEnabled &&
    !applySafetyContract.browserDirectApplyEnabled &&
    !applySafetyContract.authenticatedApplyRpcExposed &&
    !applySafetyContract.sourceWritebackEnabled &&
    !applySafetyContract.credentialReadbackEnabled
  const workerCreateOnlyOpen =
    workerApplyBoundaryOpen &&
    (applySafetyContract.contractVersion === 'pr16.3-create-only-worker-apply-v1' ||
      applySafetyContract.contractVersion === 'pr16.4.2-guarded-update-worker-apply-v1' ||
      applySafetyContract.contractVersion === 'pr16.4.3-guarded-update-recovery-readiness-v1' ||
      applySafetyContract.contractVersion === 'pr16.4.4-guarded-update-recovery-runbook-v1' ||
      applySafetyContract.contractVersion === 'pr16.5-guarded-update-rollback-preview-v1' ||
      applySafetyContract.contractVersion === 'pr16.6-guarded-update-rollback-approval-v1' ||
      applySafetyContract.contractVersion ===
        'pr16.7-guarded-update-rollback-worker-readiness-v1')
  const workerGuardedUpdateOpen =
    workerApplyBoundaryOpen &&
    (applySafetyContract.contractVersion === 'pr16.4.2-guarded-update-worker-apply-v1' ||
      applySafetyContract.contractVersion === 'pr16.4.3-guarded-update-recovery-readiness-v1' ||
      applySafetyContract.contractVersion === 'pr16.4.4-guarded-update-recovery-runbook-v1' ||
      applySafetyContract.contractVersion === 'pr16.5-guarded-update-rollback-preview-v1' ||
      applySafetyContract.contractVersion === 'pr16.6-guarded-update-rollback-approval-v1' ||
      applySafetyContract.contractVersion ===
        'pr16.7-guarded-update-rollback-worker-readiness-v1')
  const createOnlySafeToExecute =
    previewReady &&
    approvalRecorded &&
    hasChecksum &&
    !hasRowErrors &&
    createOnlyChangeSetReady &&
    workerCreateOnlyOpen
  const guardedUpdateSafeToExecute =
    previewReady &&
    approvalRecorded &&
    hasChecksum &&
    !hasRowErrors &&
    guardedUpdateChangeSetReady &&
    workerGuardedUpdateOpen
  const safeToExecute = createOnlySafeToExecute || guardedUpdateSafeToExecute
  const executorMode: ConnectorApplyExecutionContract['executorMode'] = createOnlySafeToExecute
    ? 'worker_create_only_job'
    : guardedUpdateSafeToExecute
      ? 'worker_guarded_update_job'
      : 'future_background_job'
  const executionReadyValueKey = guardedUpdateSafeToExecute
    ? 'erp.applyExecutionContract.values.guardedUpdateExecutionReady'
    : 'erp.applyExecutionContract.values.createOnlyExecutionReady'

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
  const readiness: ConnectorReadinessStatus = safeToExecute
    ? 'ready'
    : status === 'blocked'
      ? 'blocked'
      : 'partial'

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
    control(
      'direct_rpc_permission',
      applySafetyContract.authenticatedApplyRpcExposed ? 'blocked' : 'ready',
      applySafetyContract.authenticatedApplyRpcExposed
        ? 'erp.applyExecutionContract.values.rpcExposed'
        : 'erp.applyExecutionContract.values.serviceRoleOnly',
    ),
    control(
      'worker_apply_gate',
      workerCreateOnlyOpen || workerGuardedUpdateOpen
        ? 'ready'
        : applySafetyContract.workerImportApplyEnqueueEnabled ||
            applySafetyContract.workerImportApplyClaimEnabled
          ? 'blocked'
          : 'ready',
      workerGuardedUpdateOpen && guardedUpdateChangeSetReady
        ? 'erp.applyExecutionContract.values.guardedUpdateWorkerOpen'
        : workerCreateOnlyOpen
          ? 'erp.applyExecutionContract.values.createOnlyWorkerOpen'
          : applySafetyContract.workerImportApplyEnqueueEnabled ||
              applySafetyContract.workerImportApplyClaimEnabled
            ? 'erp.applyExecutionContract.values.importApplyUnsafe'
            : 'erp.applyExecutionContract.values.importApplyClosed',
    ),
    control(
      'crud_audit_policy',
      applySafetyContract.auditTiers.includes('object_event') &&
        applySafetyContract.auditTiers.includes('field_diff')
        ? 'ready'
        : 'blocked',
      applySafetyContract.auditTiers.includes('object_event') &&
        applySafetyContract.auditTiers.includes('field_diff')
        ? 'erp.applyExecutionContract.values.objectAndFieldAudit'
        : 'erp.applyExecutionContract.values.auditPolicyMissing',
    ),
    control(
      'retention_policy',
      applySafetyContract.fieldDiffHotRetentionDays === 90 &&
        applySafetyContract.rollbackSnapshotHotRetentionDays === 90 &&
        applySafetyContract.purgeArchiveRequired
        ? 'ready'
        : 'blocked',
      applySafetyContract.fieldDiffHotRetentionDays === 90 &&
        applySafetyContract.rollbackSnapshotHotRetentionDays === 90 &&
        applySafetyContract.purgeArchiveRequired
        ? 'erp.applyExecutionContract.values.ninetyDayHotRetention'
        : 'erp.applyExecutionContract.values.retentionPolicyMissing',
    ),
    control(
      'batch_lock',
      workerCreateOnlyOpen || workerGuardedUpdateOpen ? 'ready' : 'blocked',
      workerCreateOnlyOpen || workerGuardedUpdateOpen
        ? 'erp.applyExecutionContract.values.batchLockReady'
        : 'erp.applyExecutionContract.values.lockClosed',
    ),
    control(
      'rollback_plan',
      guardedUpdateSafeToExecute ? 'ready' : workerCreateOnlyOpen ? 'partial' : 'blocked',
      guardedUpdateSafeToExecute
        ? 'erp.applyExecutionContract.values.rollbackSnapshotReady'
        : workerCreateOnlyOpen
          ? 'erp.applyExecutionContract.values.createOnlyCompensationReady'
          : 'erp.applyExecutionContract.values.rollbackClosed',
    ),
    control(
      'notification_plan',
      workerCreateOnlyOpen || workerGuardedUpdateOpen ? 'partial' : 'blocked',
      workerCreateOnlyOpen || workerGuardedUpdateOpen
        ? 'erp.applyExecutionContract.values.activityAuditReady'
        : 'erp.applyExecutionContract.values.notificationClosed',
    ),
    control(
      'execution_boundary',
      safeToExecute ? 'ready' : 'blocked',
      safeToExecute ? executionReadyValueKey : 'erp.applyExecutionContract.values.executionClosed',
    ),
  ]

  return {
    status,
    readiness,
    statusLabelKey: `erp.applyExecutionContract.status.${status}`,
    descriptionKey: createOnlySafeToExecute
      ? 'erp.applyExecutionContract.descriptions.create_only_worker_ready'
      : guardedUpdateSafeToExecute
        ? 'erp.applyExecutionContract.descriptions.guarded_update_worker_ready'
        : `erp.applyExecutionContract.descriptions.${status}`,
    contractVersion: applySafetyContract.contractVersion,
    executionEnabled: safeToExecute,
    canonicalWriteEnabled: safeToExecute,
    sourceWritebackEnabled: false,
    credentialReadbackEnabled: false,
    applyRpcExposed:
      applySafetyContract.browserDirectApplyEnabled ||
      applySafetyContract.authenticatedApplyRpcExposed,
    browserDirectApplyEnabled: applySafetyContract.browserDirectApplyEnabled,
    authenticatedApplyRpcExposed: applySafetyContract.authenticatedApplyRpcExposed,
    workerImportApplyEnqueueEnabled: applySafetyContract.workerImportApplyEnqueueEnabled,
    workerImportApplyClaimEnabled: applySafetyContract.workerImportApplyClaimEnabled,
    safeToExecute,
    executorMode,
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
  if (syncType === 'import_apply_execution') return 'import_apply_execution'
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

  if (row.sync_type === 'import_apply_execution') {
    if (row.status === 'failed') return 'erp.activityTimeline.summaries.importApplyExecution.failed'
    if (row.status === 'success')
      return 'erp.activityTimeline.summaries.importApplyExecution.success'
    return 'erp.activityTimeline.summaries.importApplyExecution.pending'
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
  if (row.sync_type === 'import_apply_execution') {
    return 'erp.activityTimeline.nextActions.review_create_only_apply_result'
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

  if (row.sync_type === 'import_apply_review' || row.sync_type === 'import_apply_execution') {
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

function mapConnectorJobActivitySummaryKey(status: ConnectorRuntimeJobStatus): string {
  return `erp.activityTimeline.summaries.connectorJob.${status}`
}

function buildConnectorJobActivityDetails(row: ConnectorJobEventRow): ConnectorActivityDetail[] {
  const details: ConnectorActivityDetail[] = [
    {
      labelKey: 'erp.activityTimeline.details.jobType',
      value: row.job_type ?? 'noop_health',
    },
  ]

  if (row.failure_class && row.failure_class !== 'none') {
    details.push({
      labelKey: 'erp.activityTimeline.details.failureClass',
      value: row.failure_class,
    })
  }

  const retryAfterSeconds = Number(row.retry_after_seconds ?? 0)
  if (retryAfterSeconds > 0) {
    details.push({
      labelKey: 'erp.activityTimeline.details.retryAfterSeconds',
      value: retryAfterSeconds,
    })
  }

  if (row.operator_review_required === true) {
    details.push({
      labelKey: 'erp.activityTimeline.details.operatorReview',
      value: true,
    })
  }

  return details
}

function buildConnectorJobActivityEvent(
  row: ConnectorJobEventRow,
  index: number,
): ConnectorActivityEvent {
  const status = row.status ?? 'queued'
  const safeErrorCode = row.safe_error_code?.trim() || null
  const eventKey = row.event_key?.trim() || 'connector_job_recorded'
  const nextAction = row.next_action_key?.trim() || 'review_job_status'
  const severity = row.level ?? mapOperatorSeverity(status, row.failure_class ?? 'none')

  return {
    id: row.id ?? `connector-job-event-${index}`,
    at: formatSyncTimestamp(row.created_at),
    level: mapOperatorSeverityLevel(severity, status),
    kind: 'connector_job',
    titleKey: `erp.activityTimeline.events.${eventKey}.title`,
    summaryKey: mapConnectorJobActivitySummaryKey(status),
    detailItems: buildConnectorJobActivityDetails(row),
    safeErrorCode,
    safeErrorSummaryKey: safeErrorCode ? `erp.activityTimeline.safeErrors.${safeErrorCode}` : null,
    nextActionKey: `erp.activityTimeline.nextActions.${nextAction}`,
    actorLabelKey: row.worker_id
      ? 'erp.activityTimeline.actors.worker'
      : 'erp.activityTimeline.actors.system',
    rawStatus: status,
  }
}

function mapCredentialEventSummaryKey(row: ConnectorCredentialEventRow): string {
  const eventKey = row.event_key ?? 'reference_configured'
  return `erp.activityTimeline.summaries.credentialReference.${eventKey}`
}

function mapCredentialEventNextActionKey(row: ConnectorCredentialEventRow): string {
  const key = row.next_action_key?.trim()
  if (key) return `erp.activityTimeline.nextActions.${key}`

  switch (row.event_key) {
    case 'reference_configured':
    case 'reference_updated':
      return 'erp.activityTimeline.nextActions.run_credential_verification'
    case 'reference_revoked':
      return 'erp.activityTimeline.nextActions.restore_secure_reference'
    case 'verification_succeeded':
      return 'erp.activityTimeline.nextActions.run_runtime_preflight'
    case 'verification_failed':
      return 'erp.activityTimeline.nextActions.review_secure_reference'
    default:
      return 'erp.activityTimeline.nextActions.review_activity'
  }
}

function buildCredentialEventActivityDetails(
  row: ConnectorCredentialEventRow,
): ConnectorActivityDetail[] {
  return [
    {
      labelKey: 'erp.activityTimeline.details.authMode',
      value: row.auth_mode ?? 'custom_secret_ref',
    },
    {
      labelKey: 'erp.activityTimeline.details.credentialState',
      value: row.credential_state ?? 'missing',
    },
    {
      labelKey: 'erp.activityTimeline.details.referenceAvailable',
      value: row.credential_state !== 'missing' && row.credential_state !== 'revoked',
    },
  ]
}

function buildCredentialEventActivityEvent(
  row: ConnectorCredentialEventRow,
  index: number,
): ConnectorActivityEvent {
  const eventKey = row.event_key?.trim() || 'reference_configured'
  const safeErrorCode = row.safe_error_code?.trim() || null
  const level: ConnectorSyncLogLevel =
    row.credential_state === 'failed' || row.credential_state === 'revoked'
      ? 'warning'
      : row.credential_state === 'verified'
        ? 'success'
        : 'info'

  return {
    id: row.id ?? `credential-event-${index}`,
    at: formatSyncTimestamp(row.created_at),
    level,
    kind: 'credential_reference',
    titleKey: `erp.activityTimeline.events.credential_${eventKey}.title`,
    summaryKey: mapCredentialEventSummaryKey(row),
    detailItems: buildCredentialEventActivityDetails(row),
    safeErrorCode,
    safeErrorSummaryKey: safeErrorCode ? `erp.activityTimeline.safeErrors.${safeErrorCode}` : null,
    nextActionKey: mapCredentialEventNextActionKey(row),
    actorLabelKey: row.actor_employee_id
      ? 'erp.activityTimeline.actors.operator'
      : 'erp.activityTimeline.actors.system',
    rawStatus: row.credential_state ?? 'missing',
  }
}

function mapOperatorSeverityLevel(
  severity: ConnectorRuntimeOperatorSeverity | null | undefined,
  status?: ConnectorRuntimeJobStatus | null,
): ConnectorSyncLogLevel {
  if (severity === 'critical' || severity === 'error') return 'error'
  if (severity === 'warning') return 'warning'
  if (status === 'succeeded') return 'success'
  return 'info'
}

function mapFailureClass(
  row: Pick<ConnectorJobRow, 'failure_class' | 'safe_error_code'>,
): ConnectorRuntimeFailureClass {
  if (row.failure_class) return row.failure_class
  return row.safe_error_code ? 'unknown' : 'none'
}

function mapOperatorSeverity(
  status: ConnectorRuntimeJobStatus,
  failureClass: ConnectorRuntimeFailureClass,
  rowSeverity?: ConnectorRuntimeOperatorSeverity | null,
): ConnectorRuntimeOperatorSeverity {
  if (rowSeverity) return rowSeverity
  if (status === 'dead_letter') return 'critical'
  if (status === 'failed') return 'error'
  if (status === 'retrying') return 'warning'
  if (failureClass !== 'none') return 'warning'
  return 'info'
}

function parseTimestampMs(value: string | null | undefined) {
  if (!value) return null
  const parsed = Date.parse(value)
  return Number.isFinite(parsed) ? parsed : null
}

function isTimestampOlderThan(value: string | null | undefined, ageMs: number) {
  const parsed = parseTimestampMs(value)
  if (parsed === null) return false
  return Date.now() - parsed > ageMs
}

function isTimestampPast(value: string | null | undefined) {
  const parsed = parseTimestampMs(value)
  if (parsed === null) return false
  return parsed < Date.now()
}

function mapRuntimeLeaseStatus(row: ConnectorJobRow): ConnectorRuntimeLeaseStatus {
  if (row.status !== 'running') return row.started_at ? 'released' : 'not_started'
  if (isTimestampPast(row.lease_expires_at)) return 'expired'
  return 'active'
}

function mapRuntimeWorkerStatus(
  row: ConnectorWorkerHeartbeatRow | null,
): ConnectorRuntimeWorkerStatus {
  if (!row) return 'not_configured'
  if (row.status === 'error' || row.safe_error_code) return 'error'
  if (isTimestampOlderThan(row.last_seen_at, 10 * 60 * 1000)) return 'stale'
  if (row.status === 'running' || row.status === 'claiming' || row.status === 'recovering') {
    return 'running'
  }
  return 'idle'
}

function mapRuntimeWorkerReadiness(status: ConnectorRuntimeWorkerStatus): ConnectorReadinessStatus {
  if (status === 'idle' || status === 'running') return 'ready'
  if (status === 'stale' || status === 'error') return 'partial'
  return 'blocked'
}

function mapConnectorRuntimeWorker(rows: ConnectorWorkerHeartbeatRow[]): ConnectorRuntimeWorker {
  const row = rows[0] ?? null
  const status = mapRuntimeWorkerStatus(row)
  const safeErrorCode = row?.safe_error_code?.trim() || null

  return {
    status,
    readiness: mapRuntimeWorkerReadiness(status),
    statusLabelKey: `erp.runtimeQueue.workerStatus.${status}`,
    descriptionKey: `erp.runtimeQueue.workerDescriptions.${status}`,
    workerId: row?.worker_id ?? null,
    runtimeVersion: row?.runtime_version ?? null,
    supportedJobTypes: row?.supported_job_types ?? [],
    lastSeenAt: row?.last_seen_at ?? null,
    lastClaimedJobId: row?.last_claimed_job_id ?? null,
    safeErrorCode,
    safeErrorSummaryKey: safeErrorCode ? `erp.runtimeQueue.safeErrors.${safeErrorCode}` : null,
  }
}

function mapRuntimeQueueStatus(
  connectorState: ConnectorLifecycleState,
  jobs: ConnectorRuntimeJobSummary[],
  worker: ConnectorRuntimeWorker,
): ConnectorRuntimeQueueStatus {
  if (connectorState !== 'connector_selected') return 'not_available'
  if (jobs.some((job) => job.status === 'failed' || job.status === 'dead_letter')) return 'blocked'
  if (worker.status === 'stale' || worker.status === 'error') return 'blocked'
  if (
    jobs.some(
      (job) => job.status === 'queued' || job.status === 'running' || job.status === 'retrying',
    )
  ) {
    return 'active'
  }
  return 'contract_ready'
}

function mapRuntimeQueueReadiness(status: ConnectorRuntimeQueueStatus): ConnectorReadinessStatus {
  if (status === 'contract_ready') return 'ready'
  if (status === 'active') return 'partial'
  if (status === 'blocked') return 'partial'
  return 'blocked'
}

function mapConnectorRuntimeJob(row: ConnectorJobRow, index: number): ConnectorRuntimeJobSummary {
  const status = row.status ?? 'queued'
  const jobType = row.job_type ?? 'noop_health'
  const safeErrorCode = row.safe_error_code?.trim() || null
  const nextAction = row.next_action_key?.trim() || 'review_job_status'
  const leaseStatus = mapRuntimeLeaseStatus(row)
  const failureClass = mapFailureClass(row)
  const operatorSeverity = mapOperatorSeverity(status, failureClass, row.operator_severity)
  const retryAfterSeconds = Number(row.retry_after_seconds ?? 0)
  const nextRetryAt = status === 'retrying' ? (row.scheduled_at ?? null) : null

  return {
    id: row.id ?? `connector-job-${index}`,
    jobType,
    status,
    level: mapOperatorSeverityLevel(operatorSeverity, status),
    domain: row.domain ?? null,
    statusLabelKey: `erp.runtimeQueue.jobStatus.${status}`,
    titleKey: `erp.runtimeQueue.jobTypes.${jobType}`,
    summaryKey: `erp.runtimeQueue.jobSummaries.${status}`,
    safeErrorCode,
    safeErrorSummaryKey: safeErrorCode ? `erp.runtimeQueue.safeErrors.${safeErrorCode}` : null,
    nextActionKey: `erp.runtimeQueue.nextActions.${nextAction}`,
    failureClass,
    failureClassLabelKey: `erp.runtimeQueue.failureClasses.${failureClass}`,
    operatorSeverity,
    operatorSeverityLabelKey: `erp.runtimeQueue.operatorSeverity.${operatorSeverity}`,
    retryAfterSeconds,
    nextRetryAt,
    lastFailureAt: row.last_failure_at ?? null,
    deadLetteredAt: row.dead_lettered_at ?? null,
    operatorReviewRequired: row.operator_review_required === true,
    attemptCount: Number(row.attempt_count ?? 0),
    maxAttempts: Number(row.max_attempts ?? 0),
    priority: Number(row.priority ?? 100),
    scheduledAt: row.scheduled_at ?? null,
    startedAt: row.started_at ?? null,
    finishedAt: row.finished_at ?? null,
    lockedAt: row.locked_at ?? null,
    lockedBy: row.locked_by ?? null,
    workerHeartbeatAt: row.worker_heartbeat_at ?? null,
    leaseExpiresAt: row.lease_expires_at ?? null,
    leaseStatus,
    leaseStatusLabelKey: `erp.runtimeQueue.leaseStatus.${leaseStatus}`,
    sourceNamespaceId: row.source_namespace_id ?? null,
    importBatchId: row.import_batch_id ?? null,
    createdAt: row.created_at ?? null,
    updatedAt: row.updated_at ?? null,
  }
}

function buildConnectorRuntimeQueue({
  connectorState,
  jobs,
  worker,
}: {
  connectorState: ConnectorLifecycleState
  jobs: ConnectorRuntimeJobSummary[]
  worker: ConnectorRuntimeWorker
}): ConnectorRuntimeQueue {
  const status = mapRuntimeQueueStatus(connectorState, jobs, worker)

  return {
    contractVersion: 'pr15.2-worker-skeleton-v1',
    status,
    readiness: mapRuntimeQueueReadiness(status),
    statusLabelKey: `erp.runtimeQueue.status.${status}`,
    descriptionKey: `erp.runtimeQueue.descriptions.${status}`,
    workerEnabled: worker.status === 'idle' || worker.status === 'running',
    executionEnabled: false,
    worker,
    jobs,
    summary: {
      total: jobs.length,
      queued: jobs.filter((job) => job.status === 'queued').length,
      running: jobs.filter((job) => job.status === 'running').length,
      retrying: jobs.filter((job) => job.status === 'retrying').length,
      succeeded: jobs.filter((job) => job.status === 'succeeded').length,
      failed: jobs.filter((job) => job.status === 'failed').length,
      deadLetter: jobs.filter((job) => job.status === 'dead_letter').length,
      operatorReviewRequired: jobs.filter((job) => job.operatorReviewRequired).length,
    },
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
    if (row.status === 'partial_success') return 'erp.syncLogMessages.importApplyReview.partial'
    if (row.status === 'failed') return 'erp.syncLogMessages.importApplyReview.failed'
    return 'erp.syncLogMessages.importApplyReview.pending'
  }
  if (row.sync_type === 'import_apply_execution') {
    if (row.status === 'success') return 'erp.syncLogMessages.importApplyExecution.success'
    if (row.status === 'partial_success') return 'erp.syncLogMessages.importApplyExecution.partial'
    if (row.status === 'failed') return 'erp.syncLogMessages.importApplyExecution.failed'
    return 'erp.syncLogMessages.importApplyExecution.pending'
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
  runtimeJobs,
  runtimeWorker,
  credentialBoundary,
  importPreview,
  applyReadiness,
  applyApprovalPolicy,
  applyChangeSet,
  guardedUpdateEvidence,
  guardedUpdateRecovery,
  guardedUpdateRecoveryRunbook,
  guardedUpdateRollbackPreview,
  guardedUpdateRollbackApproval,
  guardedUpdateRollbackWorkerReadiness,
  applySafetyContract,
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
  runtimeJobs?: ConnectorRuntimeJobSummary[]
  runtimeWorker?: ConnectorRuntimeWorker
  credentialBoundary: ConnectorCredentialBoundary
  importPreview?: ConnectorImportPreview
  applyReadiness?: ConnectorApplyReadiness
  applyApprovalPolicy?: ConnectorApplyApprovalPolicy
  applyChangeSet?: ConnectorApplyChangeSet
  guardedUpdateEvidence?: ConnectorGuardedUpdateEvidence
  guardedUpdateRecovery?: ConnectorGuardedUpdateRecoveryReadiness
  guardedUpdateRecoveryRunbook?: ConnectorGuardedUpdateRecoveryRunbook
  guardedUpdateRollbackPreview?: ConnectorGuardedUpdateRollbackPreview
  guardedUpdateRollbackApproval?: ConnectorGuardedUpdateRollbackApproval
  guardedUpdateRollbackWorkerReadiness?: ConnectorGuardedUpdateRollbackWorkerReadiness
  applySafetyContract?: ConnectorApplySafetyContract
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
  const resolvedApplySafetyContract = applySafetyContract ?? buildConnectorApplySafetyContract(null)
  const resolvedApplyChangeSet =
    applyChangeSet ?? emptyConnectorApplyChangeSet(connectorState, resolvedImportPreview)
  const resolvedGuardedUpdateEvidence =
    guardedUpdateEvidence ??
    buildConnectorGuardedUpdateEvidence({
      connectorState,
      applyChangeSet: resolvedApplyChangeSet,
      row: null,
    })
  const resolvedGuardedUpdateRecovery =
    guardedUpdateRecovery ??
    buildConnectorGuardedUpdateRecoveryReadiness({
      connectorState,
      applyChangeSet: resolvedApplyChangeSet,
      row: null,
    })
  const resolvedGuardedUpdateRecoveryRunbook =
    guardedUpdateRecoveryRunbook ??
    buildConnectorGuardedUpdateRecoveryRunbook({
      connectorState,
      applyChangeSet: resolvedApplyChangeSet,
      recovery: resolvedGuardedUpdateRecovery,
      row: null,
    })
  const resolvedGuardedUpdateRollbackPreview =
    guardedUpdateRollbackPreview ??
    buildConnectorGuardedUpdateRollbackPreview({
      connectorState,
      applyChangeSet: resolvedApplyChangeSet,
      runbook: resolvedGuardedUpdateRecoveryRunbook,
      row: null,
    })
  const resolvedGuardedUpdateRollbackApproval =
    guardedUpdateRollbackApproval ??
    buildConnectorGuardedUpdateRollbackApproval({
      connectorState,
      rollbackPreview: resolvedGuardedUpdateRollbackPreview,
      row: null,
    })
  const resolvedGuardedUpdateRollbackWorkerReadiness =
    guardedUpdateRollbackWorkerReadiness ??
    buildConnectorGuardedUpdateRollbackWorkerReadiness({
      connectorState,
      rollbackApproval: resolvedGuardedUpdateRollbackApproval,
      row: null,
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
    applySafetyContract: resolvedApplySafetyContract,
    applyChangeSet: resolvedApplyChangeSet,
    guardedUpdateEvidence: resolvedGuardedUpdateEvidence,
  })
  const runtimeQueue = buildConnectorRuntimeQueue({
    connectorState,
    jobs: runtimeJobs ?? [],
    worker: runtimeWorker ?? mapConnectorRuntimeWorker([]),
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
    applyChangeSet: resolvedApplyChangeSet,
    guardedUpdateEvidence: resolvedGuardedUpdateEvidence,
    guardedUpdateRecovery: resolvedGuardedUpdateRecovery,
    guardedUpdateRecoveryRunbook: resolvedGuardedUpdateRecoveryRunbook,
    guardedUpdateRollbackPreview: resolvedGuardedUpdateRollbackPreview,
    guardedUpdateRollbackApproval: resolvedGuardedUpdateRollbackApproval,
    guardedUpdateRollbackWorkerReadiness: resolvedGuardedUpdateRollbackWorkerReadiness,
    applySafetyContract: resolvedApplySafetyContract,
    controlledApplyPlan,
    applyExecutionContract,
    runtimeQueue,
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

  const [connectionsRow, readinessRow, namespacesRow, identitiesRow, workerHeartbeatsRow] =
    await Promise.all([
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
      pulsIntegration()
        .from('connector_worker_heartbeats')
        .select(
          'worker_id, status, runtime_version, supported_job_types, last_seen_at, last_claimed_job_id, safe_error_code, safe_context, created_at, updated_at',
        )
        .order('last_seen_at', { ascending: false })
        .limit(5),
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
  const [mappingsRow, batchesRow, jobsRow, jobEventsRow, credentialEventsRow] = connection?.id
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
        pulsIntegration()
          .from('connector_jobs')
          .select(
            [
              'id',
              'job_type',
              'status',
              'domain',
              'priority',
              'attempt_count',
              'max_attempts',
              'scheduled_at',
              'started_at',
              'finished_at',
              'locked_at',
              'locked_by',
              'worker_heartbeat_at',
              'lease_expires_at',
              'safe_error_code',
              'safe_error_context',
              'next_action_key',
              'failure_class',
              'operator_severity',
              'retry_after_seconds',
              'last_failure_at',
              'dead_lettered_at',
              'operator_review_required',
              'connection_id',
              'source_namespace_id',
              'import_batch_id',
              'created_at',
              'updated_at',
            ].join(', '),
          )
          .eq('tenant_id', ctx.tenantId)
          .eq('connection_id', connection.id)
          .order('updated_at', { ascending: false })
          .limit(10),
        pulsIntegration().rpc('list_connector_job_events', {
          p_connection_id: connection.id,
          p_limit: 10,
        }),
        pulsIntegration().rpc('list_connector_credential_events', {
          p_connection_id: connection.id,
          p_limit: 10,
        }),
      ])
    : [
        { data: [], error: null },
        { data: [], error: null },
        { data: [], error: null },
        { data: [], error: null },
        { data: [], error: null },
      ]
  const rawMappings = mappingsRow.error ? [] : ((mappingsRow.data ?? []) as ErpFieldMappingRow[])
  const batches = batchesRow.error ? [] : ((batchesRow.data ?? []) as ErpSyncBatchRow[])
  const runtimeJobs = jobsRow.error
    ? []
    : ((jobsRow.data ?? []) as ConnectorJobRow[]).map((row, index) =>
        mapConnectorRuntimeJob(row, index),
      )
  const readiness = readinessRow.error ? null : (readinessRow.data as SetupReadinessRow | null)
  const rawNamespaces = namespacesRow.error
    ? []
    : ((namespacesRow.data ?? []) as SourceNamespaceRow[])
  const identities = identitiesRow.error ? [] : ((identitiesRow.data ?? []) as EntityIdentityRow[])
  const runtimeWorker = mapConnectorRuntimeWorker(
    workerHeartbeatsRow.error
      ? []
      : ((workerHeartbeatsRow.data ?? []) as ConnectorWorkerHeartbeatRow[]),
  )
  const jobEvents = jobEventsRow.error ? [] : ((jobEventsRow.data ?? []) as ConnectorJobEventRow[])
  const credentialEvents = credentialEventsRow.error
    ? []
    : ((credentialEventsRow.data ?? []) as ConnectorCredentialEventRow[])

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
  let applySafetyContractRow: ConnectorApplySafetyContractRow | null = null
  let applyChangeSetRow: ConnectorApplyChangeSetRow | null = null
  let guardedUpdateEvidenceRow: ConnectorGuardedUpdateEvidenceRow | null = null
  let guardedUpdateRecoveryRow: ConnectorGuardedUpdateRecoveryReadinessRow | null = null
  let guardedUpdateRecoveryRunbookRow: ConnectorGuardedUpdateRecoveryRunbookRow | null = null
  let guardedUpdateRollbackPreviewRow: ConnectorGuardedUpdateRollbackPreviewRow | null = null
  let guardedUpdateRollbackApprovalRow: ConnectorGuardedUpdateRollbackApprovalRow | null = null
  let guardedUpdateRollbackWorkerReadinessRow: ConnectorGuardedUpdateRollbackWorkerReadinessRow | null =
    null

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

  if (connection?.id) {
    const applySafetyContractResult = await pulsIntegration().rpc(
      'list_connector_apply_safety_contracts',
      {
        p_connection_id: connection.id,
      },
    )

    if (!applySafetyContractResult.error) {
      applySafetyContractRow =
        ((applySafetyContractResult.data ?? []) as ConnectorApplySafetyContractRow[])[0] ?? null
    }

    if (importBatch?.id) {
      const applyChangeSetResult = await pulsIntegration().rpc(
        'list_connector_apply_change_set_summaries',
        {
          p_batch_id: importBatch.id,
          p_connection_id: connection.id,
        },
      )

      if (!applyChangeSetResult.error) {
        applyChangeSetRow =
          ((applyChangeSetResult.data ?? []) as ConnectorApplyChangeSetRow[])[0] ?? null
      }

      if (applyChangeSetRow?.id) {
        const guardedUpdateEvidenceResult = await pulsIntegration().rpc(
          'list_connector_guarded_update_evidence',
          {
            p_change_set_id: applyChangeSetRow.id,
            p_limit: 8,
          },
        )

        if (!guardedUpdateEvidenceResult.error) {
          guardedUpdateEvidenceRow =
            ((guardedUpdateEvidenceResult.data ?? []) as ConnectorGuardedUpdateEvidenceRow[])[0] ??
            null
        }

        const guardedUpdateRecoveryResult = await pulsIntegration().rpc(
          'list_connector_guarded_update_recovery_readiness',
          {
            p_change_set_id: applyChangeSetRow.id,
            p_limit: 8,
          },
        )

        if (!guardedUpdateRecoveryResult.error) {
          guardedUpdateRecoveryRow =
            (
              (guardedUpdateRecoveryResult.data ??
                []) as ConnectorGuardedUpdateRecoveryReadinessRow[]
            )[0] ?? null
        }

        const guardedUpdateRecoveryRunbookResult = await pulsIntegration().rpc(
          'list_connector_guarded_update_recovery_runbooks',
          {
            p_change_set_id: applyChangeSetRow.id,
            p_limit: 8,
          },
        )

        if (!guardedUpdateRecoveryRunbookResult.error) {
          guardedUpdateRecoveryRunbookRow =
            (
              (guardedUpdateRecoveryRunbookResult.data ??
                []) as ConnectorGuardedUpdateRecoveryRunbookRow[]
            )[0] ?? null
        }

        const guardedUpdateRollbackPreviewResult = await pulsIntegration().rpc(
          'list_connector_guarded_update_rollback_previews',
          {
            p_change_set_id: applyChangeSetRow.id,
            p_limit: 8,
          },
        )

        if (!guardedUpdateRollbackPreviewResult.error) {
          guardedUpdateRollbackPreviewRow =
            (
              (guardedUpdateRollbackPreviewResult.data ??
                []) as ConnectorGuardedUpdateRollbackPreviewRow[]
            )[0] ?? null
        }

        const guardedUpdateRollbackApprovalResult = await pulsIntegration().rpc(
          'list_connector_guarded_update_rollback_approvals',
          {
            p_change_set_id: applyChangeSetRow.id,
            p_limit: 8,
          },
        )

        if (!guardedUpdateRollbackApprovalResult.error) {
          guardedUpdateRollbackApprovalRow =
            (
              (guardedUpdateRollbackApprovalResult.data ??
                []) as ConnectorGuardedUpdateRollbackApprovalRow[]
            )[0] ?? null
        }

        const guardedUpdateRollbackWorkerReadinessResult = await pulsIntegration().rpc(
          'list_connector_guarded_update_rollback_worker_readiness',
          {
            p_change_set_id: applyChangeSetRow.id,
            p_limit: 8,
          },
        )

        if (!guardedUpdateRollbackWorkerReadinessResult.error) {
          guardedUpdateRollbackWorkerReadinessRow =
            (
              (guardedUpdateRollbackWorkerReadinessResult.data ??
                []) as ConnectorGuardedUpdateRollbackWorkerReadinessRow[]
            )[0] ?? null
        }
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
  const applySafetyContract = buildConnectorApplySafetyContract(applySafetyContractRow)
  const applyChangeSet = buildConnectorApplyChangeSet({
    connectorState: connection ? 'connector_selected' : 'no_connector',
    importPreview,
    row: applyChangeSetRow,
  })
  const guardedUpdateEvidence = buildConnectorGuardedUpdateEvidence({
    connectorState: connection ? 'connector_selected' : 'no_connector',
    applyChangeSet,
    row: guardedUpdateEvidenceRow,
  })
  const guardedUpdateRecovery = buildConnectorGuardedUpdateRecoveryReadiness({
    connectorState: connection ? 'connector_selected' : 'no_connector',
    applyChangeSet,
    row: guardedUpdateRecoveryRow,
  })
  const guardedUpdateRecoveryRunbook = buildConnectorGuardedUpdateRecoveryRunbook({
    connectorState: connection ? 'connector_selected' : 'no_connector',
    applyChangeSet,
    recovery: guardedUpdateRecovery,
    row: guardedUpdateRecoveryRunbookRow,
  })
  const guardedUpdateRollbackPreview = buildConnectorGuardedUpdateRollbackPreview({
    connectorState: connection ? 'connector_selected' : 'no_connector',
    applyChangeSet,
    runbook: guardedUpdateRecoveryRunbook,
    row: guardedUpdateRollbackPreviewRow,
  })
  const guardedUpdateRollbackApproval = buildConnectorGuardedUpdateRollbackApproval({
    connectorState: connection ? 'connector_selected' : 'no_connector',
    rollbackPreview: guardedUpdateRollbackPreview,
    row: guardedUpdateRollbackApprovalRow,
  })
  const guardedUpdateRollbackWorkerReadiness =
    buildConnectorGuardedUpdateRollbackWorkerReadiness({
      connectorState: connection ? 'connector_selected' : 'no_connector',
      rollbackApproval: guardedUpdateRollbackApproval,
      row: guardedUpdateRollbackWorkerReadinessRow,
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
                  : row.sync_type === 'import_apply_execution'
                    ? 'import_apply_execution'
                    : 'sync_batch',
    })),
    activityTimeline: [
      ...jobEvents.map((row, index) => buildConnectorJobActivityEvent(row, index)),
      ...credentialEvents.map((row, index) => buildCredentialEventActivityEvent(row, index)),
      ...batches.map((row, index) => buildConnectorActivityEvent(row, index)),
    ].slice(0, 12),
    runtimeJobs,
    runtimeWorker,
    credentialBoundary,
    importPreview,
    applyReadiness,
    applyApprovalPolicy,
    applyChangeSet,
    guardedUpdateEvidence,
    guardedUpdateRecovery,
    guardedUpdateRecoveryRunbook,
    guardedUpdateRollbackPreview,
    guardedUpdateRollbackApproval,
    guardedUpdateRollbackWorkerReadiness,
    applySafetyContract,
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

export async function requestConnectorRuntimePreflight(
  userId: string,
): Promise<RequestConnectorRuntimePreflightResult> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_TENANT_REQUIRED',
      message: 'Connector runtime preflight requires tenant context',
      source: 'adapter',
      operation: 'requestConnectorRuntimePreflight',
      i18nKey: 'erp.errors.tenantMissing',
    })
  }
  if (ctx.personaRole !== 'hr_admin' && ctx.personaRole !== 'superadmin') {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_ADMIN_REQUIRED',
      message: 'Connector runtime preflight requires admin permission',
      source: 'adapter',
      operation: 'requestConnectorRuntimePreflight',
      i18nKey: 'erp.errors.adminRequired',
    })
  }

  const overview = await fetchRealErpOverview(userId)
  const connectionId = overview.provider.id
  if (!connectionId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_SOURCE_REQUIRED',
      message: 'Connector runtime preflight requires a selected source',
      source: 'adapter',
      operation: 'requestConnectorRuntimePreflight',
      i18nKey: 'erp.errors.sourceMissing',
    })
  }

  if (overview.credentialBoundary.required && overview.credentialBoundary.state !== 'verified') {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_RUNTIME_PREFLIGHT_CREDENTIAL_NOT_VERIFIED',
      message: 'Connector runtime preflight requires verified credential state',
      source: 'adapter',
      operation: 'requestConnectorRuntimePreflight',
      i18nKey: 'erp.errors.runtimePreflightBlocked',
    })
  }

  const request = await pulsIntegration().rpc('request_connector_runtime_preflight', {
    p_connection_id: connectionId,
    p_actor_employee_id: ctx.employeeId,
  })

  if (request.error) {
    throw fromConnectorRpcError(request.error, 'requestConnectorRuntimePreflight')
  }

  const row = Array.isArray(request.data) ? request.data[0] : request.data
  const result = (row ?? {}) as {
    job_id?: string | null
    status?: ConnectorRuntimeJobStatus | null
    credential_state?: ConnectorCredentialState | null
    next_action_key?: string | null
  }

  return {
    connectionId,
    jobId: result.job_id ?? null,
    status: result.status ?? 'queued',
    credentialState: result.credential_state ?? overview.credentialBoundary.state,
    nextActionKey: result.next_action_key ?? 'wait_for_worker_runtime_preflight',
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

export async function requestConnectorApplyChangeSet(
  userId: string,
): Promise<RequestConnectorApplyChangeSetResult> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_TENANT_REQUIRED',
      message: 'Connector apply change-set requires tenant context',
      source: 'adapter',
      operation: 'requestConnectorApplyChangeSet',
      i18nKey: 'erp.errors.tenantMissing',
    })
  }
  if (ctx.personaRole !== 'hr_admin' && ctx.personaRole !== 'superadmin') {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_ADMIN_REQUIRED',
      message: 'Connector apply change-set requires admin permission',
      source: 'adapter',
      operation: 'requestConnectorApplyChangeSet',
      i18nKey: 'erp.errors.adminRequired',
    })
  }

  const overview = await fetchRealErpOverview(userId)
  const connectionId = overview.provider.id
  const batch = overview.importPreview.batch
  if (!connectionId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_SOURCE_REQUIRED',
      message: 'Connector apply change-set requires a selected source',
      source: 'adapter',
      operation: 'requestConnectorApplyChangeSet',
      i18nKey: 'erp.errors.sourceMissing',
    })
  }
  if (!batch) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_IMPORT_BATCH_REQUIRED',
      message: 'Connector apply change-set requires a preview batch',
      source: 'adapter',
      operation: 'requestConnectorApplyChangeSet',
      i18nKey: 'erp.errors.importBatchMissing',
    })
  }
  if (overview.applyChangeSet.id) {
    return {
      connectionId,
      batchId: batch.id,
      changeSetId: overview.applyChangeSet.id,
      status: overview.applyChangeSet.status,
      blockedCount: overview.applyChangeSet.summary.blockedCount,
      safeToApply: false,
    }
  }
  if (!overview.applyChangeSet.requestable) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_APPLY_CHANGE_SET_BLOCKED',
      message: 'Connector apply change-set is blocked until preview is ready',
      source: 'adapter',
      operation: 'requestConnectorApplyChangeSet',
      i18nKey: 'erp.errors.applyChangeSetBlocked',
    })
  }

  const generated = await pulsIntegration().rpc('create_connector_apply_change_set', {
    p_batch_id: batch.id,
  })

  if (generated.error) {
    throw fromConnectorRpcError(generated.error, 'requestConnectorApplyChangeSet')
  }

  const row = ((generated.data ?? []) as ConnectorApplyChangeSetRow[])[0] ?? null
  const changeSet = buildConnectorApplyChangeSet({
    connectorState: 'connector_selected',
    importPreview: overview.importPreview,
    row,
  })
  if (!changeSet.id) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_APPLY_CHANGE_SET_BLOCKED',
      message: 'Connector apply change-set RPC returned no change-set evidence',
      source: 'adapter',
      operation: 'requestConnectorApplyChangeSet',
      i18nKey: 'erp.errors.applyChangeSetBlocked',
    })
  }
  const now = new Date().toISOString()
  const write = await pulsIntegration()
    .from('erp_sync_batches')
    .insert({
      tenant_id: ctx.tenantId,
      connection_id: connectionId,
      sync_type: 'import_apply_review',
      event_key: 'import_apply_change_set_generated',
      actor_employee_id: ctx.employeeId,
      status: changeSet.summary.blockedCount > 0 ? 'partial_success' : 'success',
      started_at: now,
      finished_at: now,
      records_seen: changeSet.summary.rowCount,
      records_inserted: changeSet.summary.createCount,
      records_updated: changeSet.summary.updateCount,
      records_failed: changeSet.summary.blockedCount,
      error_summary: null,
      safe_error_code: changeSet.summary.blockedCount > 0 ? 'apply_change_set_has_blockers' : null,
      safe_error_context: {
        change_set_id: changeSet.id,
        contract_version: 'pr16.2-apply-change-set-v1',
        source_namespace_code: batch.sourceNamespaceCode,
        source_checksum_available: Boolean(changeSet.sourceChecksum),
        row_count: changeSet.summary.rowCount,
        create_count: changeSet.summary.createCount,
        update_count: changeSet.summary.updateCount,
        skip_count: changeSet.summary.skipCount,
        blocked_count: changeSet.summary.blockedCount,
        stale_count: changeSet.summary.staleCount,
        destructive_count: changeSet.summary.destructiveCount,
        source_conflict_count: changeSet.summary.sourceConflictCount,
        guarded_update_count: changeSet.summary.guardedUpdateCount,
        no_change_count: changeSet.summary.noChangeCount,
        field_value_readback: false,
        raw_payload_readback: false,
        safe_to_apply: false,
        apply_execution_open: false,
        canonical_write_open: false,
        source_writeback_open: false,
        credential_readback_open: false,
      },
      next_action_key:
        changeSet.summary.blockedCount > 0
          ? 'resolve_change_set_blockers'
          : 'review_create_only_change_set',
    })
    .select('id')
    .single()

  if (write.error) {
    throw fromSupabaseError(
      write.error,
      'requestConnectorApplyChangeSet',
      'puls_integration',
      'erp_sync_batches',
    )
  }

  return {
    connectionId,
    batchId: batch.id,
    changeSetId: changeSet.id,
    status: changeSet.status,
    blockedCount: changeSet.summary.blockedCount,
    safeToApply: false,
  }
}

export async function requestConnectorGuardedUpdateEvidence(
  userId: string,
): Promise<RequestConnectorGuardedUpdateEvidenceResult> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_TENANT_REQUIRED',
      message: 'Connector guarded update evidence requires tenant context',
      source: 'adapter',
      operation: 'requestConnectorGuardedUpdateEvidence',
      i18nKey: 'erp.errors.tenantMissing',
    })
  }
  if (ctx.personaRole !== 'hr_admin' && ctx.personaRole !== 'superadmin') {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_ADMIN_REQUIRED',
      message: 'Connector guarded update evidence requires admin permission',
      source: 'adapter',
      operation: 'requestConnectorGuardedUpdateEvidence',
      i18nKey: 'erp.errors.adminRequired',
    })
  }

  const overview = await fetchRealErpOverview(userId)
  const connectionId = overview.provider.id
  const batch = overview.importPreview.batch
  const changeSetId = overview.applyChangeSet.id
  if (!connectionId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_SOURCE_REQUIRED',
      message: 'Connector guarded update evidence requires a selected source',
      source: 'adapter',
      operation: 'requestConnectorGuardedUpdateEvidence',
      i18nKey: 'erp.errors.sourceMissing',
    })
  }
  if (!batch) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_IMPORT_BATCH_REQUIRED',
      message: 'Connector guarded update evidence requires a preview batch',
      source: 'adapter',
      operation: 'requestConnectorGuardedUpdateEvidence',
      i18nKey: 'erp.errors.importBatchMissing',
    })
  }
  if (!changeSetId || !overview.guardedUpdateEvidence.requestable) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_GUARDED_UPDATE_EVIDENCE_BLOCKED',
      message:
        'Connector guarded update evidence is blocked until a guarded update change-set is ready',
      source: 'adapter',
      operation: 'requestConnectorGuardedUpdateEvidence',
      i18nKey: 'erp.errors.guardedUpdateEvidenceBlocked',
    })
  }

  const generated = await pulsIntegration().rpc('generate_connector_guarded_update_evidence', {
    p_change_set_id: changeSetId,
  })

  if (generated.error) {
    throw fromConnectorRpcError(generated.error, 'requestConnectorGuardedUpdateEvidence')
  }

  const row = ((generated.data ?? []) as ConnectorGuardedUpdateEvidenceRow[])[0] ?? null
  const evidence = buildConnectorGuardedUpdateEvidence({
    connectorState: 'connector_selected',
    applyChangeSet: overview.applyChangeSet,
    row,
  })
  if (evidence.status !== 'evidence_ready') {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_GUARDED_UPDATE_EVIDENCE_BLOCKED',
      message: 'Connector guarded update evidence RPC did not return ready evidence',
      source: 'adapter',
      operation: 'requestConnectorGuardedUpdateEvidence',
      i18nKey: 'erp.errors.guardedUpdateEvidenceBlocked',
    })
  }

  const now = new Date().toISOString()
  const write = await pulsIntegration()
    .from('erp_sync_batches')
    .insert({
      tenant_id: ctx.tenantId,
      connection_id: connectionId,
      sync_type: 'import_apply_review',
      event_key: 'import_apply_guarded_update_evidence_generated',
      actor_employee_id: ctx.employeeId,
      status: 'success',
      started_at: now,
      finished_at: now,
      records_seen: overview.applyChangeSet.summary.rowCount,
      records_inserted: 0,
      records_updated: evidence.summary.guardedUpdateCount,
      records_failed: 0,
      error_summary: null,
      safe_error_code: null,
      safe_error_context: {
        change_set_id: changeSetId,
        contract_version: 'pr16.4.1-guarded-update-evidence-v1',
        source_namespace_code: batch.sourceNamespaceCode,
        field_diff_count: evidence.summary.fieldDiffCount,
        rollback_snapshot_count: evidence.summary.rollbackSnapshotCount,
        guarded_update_count: evidence.summary.guardedUpdateCount,
        stale_blocked_count: evidence.summary.staleBlockedCount,
        hot_retention_days: evidence.summary.hotRetentionDays,
        field_value_readback: false,
        raw_payload_readback: false,
        safe_to_apply: false,
        apply_execution_open: false,
        canonical_write_open: false,
        source_writeback_open: false,
        credential_readback_open: false,
      },
      next_action_key: 'review_guarded_update_evidence',
    })
    .select('id')
    .single()

  if (write.error) {
    throw fromSupabaseError(
      write.error,
      'requestConnectorGuardedUpdateEvidence',
      'puls_integration',
      'erp_sync_batches',
    )
  }

  return {
    connectionId,
    batchId: batch.id,
    changeSetId,
    status: evidence.status,
    fieldDiffCount: evidence.summary.fieldDiffCount,
    rollbackSnapshotCount: evidence.summary.rollbackSnapshotCount,
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

export async function recordConnectorGuardedUpdateRollbackApproval(
  userId: string,
): Promise<RecordConnectorGuardedUpdateRollbackApprovalResult> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_TENANT_REQUIRED',
      message: 'Connector rollback approval requires tenant context',
      source: 'adapter',
      operation: 'recordConnectorGuardedUpdateRollbackApproval',
      i18nKey: 'erp.errors.tenantMissing',
    })
  }
  if (ctx.personaRole !== 'hr_admin' && ctx.personaRole !== 'superadmin') {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_ADMIN_REQUIRED',
      message: 'Connector rollback approval requires admin permission',
      source: 'adapter',
      operation: 'recordConnectorGuardedUpdateRollbackApproval',
      i18nKey: 'erp.errors.adminRequired',
    })
  }

  const overview = await fetchRealErpOverview(userId)
  const connectionId = overview.provider.id
  const batch = overview.guardedUpdateRollbackPreview.batchId
  const changeSetId = overview.guardedUpdateRollbackPreview.changeSetId
  const rollbackPreviewId = overview.guardedUpdateRollbackPreview.rollbackPreviewId
  if (!connectionId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_SOURCE_REQUIRED',
      message: 'Connector rollback approval requires a selected source',
      source: 'adapter',
      operation: 'recordConnectorGuardedUpdateRollbackApproval',
      i18nKey: 'erp.errors.sourceMissing',
    })
  }
  if (!batch) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_IMPORT_BATCH_REQUIRED',
      message: 'Connector rollback approval requires an applied batch',
      source: 'adapter',
      operation: 'recordConnectorGuardedUpdateRollbackApproval',
      i18nKey: 'erp.errors.importBatchMissing',
    })
  }
  if (!changeSetId || !rollbackPreviewId || !overview.guardedUpdateRollbackApproval.requestable) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_ROLLBACK_APPROVAL_BLOCKED',
      message: 'Connector rollback approval is blocked until rollback preview is ready',
      source: 'adapter',
      operation: 'recordConnectorGuardedUpdateRollbackApproval',
      i18nKey: 'erp.errors.rollbackApprovalBlocked',
    })
  }

  const recorded = await pulsIntegration().rpc(
    'record_connector_guarded_update_rollback_approval',
    {
      p_rollback_preview_id: rollbackPreviewId,
    },
  )

  if (recorded.error) {
    throw fromConnectorRpcError(recorded.error, 'recordConnectorGuardedUpdateRollbackApproval')
  }

  const row = ((recorded.data ?? []) as ConnectorGuardedUpdateRollbackApprovalRow[])[0] ?? null
  const now = new Date().toISOString()
  const write = await pulsIntegration()
    .from('erp_sync_batches')
    .insert({
      tenant_id: ctx.tenantId,
      connection_id: connectionId,
      sync_type: 'import_apply_review',
      event_key: 'import_apply_rollback_approval_recorded',
      actor_employee_id: ctx.employeeId,
      status: 'success',
      started_at: now,
      finished_at: now,
      records_seen: overview.guardedUpdateRollbackPreview.summary.rowCount,
      records_inserted: 0,
      records_updated: overview.guardedUpdateRollbackPreview.summary.rollbackCount,
      records_failed: 0,
      error_summary: null,
      safe_error_code: null,
      safe_error_context: {
        contract_version: 'pr16.6-guarded-update-rollback-approval-v1',
        rollback_approval_id: row?.rollback_approval_id ?? null,
        rollback_preview_id: rollbackPreviewId,
        change_set_id: changeSetId,
        import_batch_id: batch,
        rollback_preview_checksum: row?.rollback_preview_checksum ?? null,
        row_count: overview.guardedUpdateRollbackPreview.summary.rowCount,
        rollback_count: overview.guardedUpdateRollbackPreview.summary.rollbackCount,
        blocked_count: overview.guardedUpdateRollbackPreview.summary.blockedCount,
        stale_blocked_count: overview.guardedUpdateRollbackPreview.summary.staleBlockedCount,
        field_diff_count: overview.guardedUpdateRollbackPreview.summary.fieldDiffCount,
        rollback_snapshot_count: overview.guardedUpdateRollbackPreview.summary.rollbackSnapshotCount,
        approval_policy: 'admin_only',
        approval_recorded: true,
        approver_role: ctx.personaRole,
        safe_to_rollback: false,
        rollback_approval_enabled: true,
        rollback_execution_open: false,
        compensating_execution_open: false,
        source_writeback_open: false,
        credential_readback_open: false,
        provider_api_calls: false,
        field_value_readback: false,
        raw_payload_readback: false,
        snapshot_payload_readback: false,
      },
      next_action_key: row?.next_action_key ?? 'prepare_guarded_update_rollback_worker_pr16_7',
    })
    .select('id')
    .single()

  if (write.error) {
    throw fromSupabaseError(
      write.error,
      'recordConnectorGuardedUpdateRollbackApproval',
      'puls_integration',
      'erp_sync_batches',
    )
  }

  return {
    connectionId,
    batchId: batch,
    changeSetId,
    rollbackPreviewId,
    rollbackApprovalId: row?.rollback_approval_id ?? null,
    status: row?.approval_status === 'approval_recorded' ? 'approval_recorded' : 'needs_approval',
    approvedAt: row?.approved_at ?? now,
    nextActionKey: row?.next_action_key ?? 'prepare_guarded_update_rollback_worker_pr16_7',
    safeToRollback: false,
  }
}

export async function requestConnectorGuardedUpdateRollbackWorkerReadiness(
  userId: string,
): Promise<RequestConnectorGuardedUpdateRollbackWorkerReadinessResult> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_TENANT_REQUIRED',
      message: 'Connector rollback worker readiness requires tenant context',
      source: 'adapter',
      operation: 'requestConnectorGuardedUpdateRollbackWorkerReadiness',
      i18nKey: 'erp.errors.tenantMissing',
    })
  }
  if (ctx.personaRole !== 'hr_admin' && ctx.personaRole !== 'superadmin') {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_ADMIN_REQUIRED',
      message: 'Connector rollback worker readiness requires admin permission',
      source: 'adapter',
      operation: 'requestConnectorGuardedUpdateRollbackWorkerReadiness',
      i18nKey: 'erp.errors.adminRequired',
    })
  }

  const overview = await fetchRealErpOverview(userId)
  const connectionId = overview.provider.id
  const batch = overview.guardedUpdateRollbackApproval.batchId
  const changeSetId = overview.guardedUpdateRollbackApproval.changeSetId
  const rollbackPreviewId = overview.guardedUpdateRollbackApproval.rollbackPreviewId
  const rollbackApprovalId = overview.guardedUpdateRollbackApproval.rollbackApprovalId
  if (!connectionId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_SOURCE_REQUIRED',
      message: 'Connector rollback worker readiness requires a selected source',
      source: 'adapter',
      operation: 'requestConnectorGuardedUpdateRollbackWorkerReadiness',
      i18nKey: 'erp.errors.sourceMissing',
    })
  }
  if (!batch) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_IMPORT_BATCH_REQUIRED',
      message: 'Connector rollback worker readiness requires an applied batch',
      source: 'adapter',
      operation: 'requestConnectorGuardedUpdateRollbackWorkerReadiness',
      i18nKey: 'erp.errors.importBatchMissing',
    })
  }
  if (
    !changeSetId ||
    !rollbackPreviewId ||
    !rollbackApprovalId ||
    !overview.guardedUpdateRollbackWorkerReadiness.requestable
  ) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_ROLLBACK_WORKER_READINESS_BLOCKED',
      message: 'Connector rollback worker readiness is blocked until rollback approval is ready',
      source: 'adapter',
      operation: 'requestConnectorGuardedUpdateRollbackWorkerReadiness',
      i18nKey: 'erp.errors.rollbackWorkerReadinessBlocked',
    })
  }

  const generated = await pulsIntegration().rpc(
    'generate_connector_guarded_update_rollback_worker_readiness',
    {
      p_rollback_approval_id: rollbackApprovalId,
    },
  )

  if (generated.error) {
    throw fromConnectorRpcError(
      generated.error,
      'requestConnectorGuardedUpdateRollbackWorkerReadiness',
    )
  }

  const row =
    ((generated.data ?? []) as ConnectorGuardedUpdateRollbackWorkerReadinessRow[])[0] ?? null
  const readiness = buildConnectorGuardedUpdateRollbackWorkerReadiness({
    connectorState: 'connector_selected',
    rollbackApproval: overview.guardedUpdateRollbackApproval,
    row,
  })
  if (readiness.status !== 'ready_for_worker_handoff') {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_ROLLBACK_WORKER_READINESS_BLOCKED',
      message: 'Connector rollback worker readiness RPC did not return ready handoff',
      source: 'adapter',
      operation: 'requestConnectorGuardedUpdateRollbackWorkerReadiness',
      i18nKey: 'erp.errors.rollbackWorkerReadinessBlocked',
    })
  }

  const now = new Date().toISOString()
  const write = await pulsIntegration()
    .from('erp_sync_batches')
    .insert({
      tenant_id: ctx.tenantId,
      connection_id: connectionId,
      sync_type: 'import_apply_review',
      event_key: 'import_apply_rollback_worker_readiness_generated',
      actor_employee_id: ctx.employeeId,
      status: 'success',
      started_at: now,
      finished_at: now,
      records_seen: readiness.summary.rowCount,
      records_inserted: 0,
      records_updated: readiness.summary.rollbackCount,
      records_failed: 0,
      error_summary: null,
      safe_error_code: null,
      safe_error_context: {
        contract_version: 'pr16.7-guarded-update-rollback-worker-readiness-v1',
        worker_contract: readiness.workerContract,
        rollback_worker_readiness_id: readiness.rollbackWorkerReadinessId,
        rollback_approval_id: rollbackApprovalId,
        rollback_preview_id: rollbackPreviewId,
        change_set_id: changeSetId,
        import_batch_id: batch,
        rollback_preview_checksum: readiness.rollbackPreviewChecksum,
        expected_job_type: readiness.expectedJobType,
        expected_job_domain: readiness.expectedJobDomain,
        row_count: readiness.summary.rowCount,
        rollback_count: readiness.summary.rollbackCount,
        field_diff_count: readiness.summary.fieldDiffCount,
        rollback_snapshot_count: readiness.summary.rollbackSnapshotCount,
        original_apply_event_count: readiness.summary.originalApplyEventCount,
        current_state_verified_count: readiness.summary.currentStateVerifiedCount,
        retention_verified_count: readiness.summary.retentionVerifiedCount,
        worker_handoff_ready: true,
        safe_to_rollback: false,
        rollback_job_enqueue_open: false,
        rollback_execution_open: false,
        canonical_write_open: false,
        compensating_execution_open: false,
        source_writeback_open: false,
        credential_readback_open: false,
        provider_api_calls: false,
        field_value_readback: false,
        raw_payload_readback: false,
        snapshot_payload_readback: false,
      },
      next_action_key: readiness.nextActionKey ?? 'implement_guarded_update_rollback_worker_pr16_8',
    })
    .select('id')
    .single()

  if (write.error) {
    throw fromSupabaseError(
      write.error,
      'requestConnectorGuardedUpdateRollbackWorkerReadiness',
      'puls_integration',
      'erp_sync_batches',
    )
  }

  return {
    connectionId,
    batchId: batch,
    changeSetId,
    rollbackPreviewId,
    rollbackApprovalId,
    rollbackWorkerReadinessId: readiness.rollbackWorkerReadinessId,
    status: readiness.status,
    workerContract: readiness.workerContract,
    expectedJobType: readiness.expectedJobType,
    expectedJobDomain: readiness.expectedJobDomain,
    nextActionKey: readiness.nextActionKey,
    safeToRollback: false,
  }
}

export async function requestConnectorGuardedUpdateRollbackApplyJob(
  userId: string,
): Promise<RequestConnectorGuardedUpdateRollbackApplyJobResult> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_TENANT_REQUIRED',
      message: 'Connector guarded update rollback apply requires tenant context',
      source: 'adapter',
      operation: 'requestConnectorGuardedUpdateRollbackApplyJob',
      i18nKey: 'erp.errors.tenantMissing',
    })
  }
  if (ctx.personaRole !== 'hr_admin' && ctx.personaRole !== 'superadmin') {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_ADMIN_REQUIRED',
      message: 'Connector guarded update rollback apply requires admin permission',
      source: 'adapter',
      operation: 'requestConnectorGuardedUpdateRollbackApplyJob',
      i18nKey: 'erp.errors.adminRequired',
    })
  }

  const overview = await fetchRealErpOverview(userId)
  const connectionId = overview.provider.id
  const readiness = overview.guardedUpdateRollbackWorkerReadiness
  const rollbackWorkerReadinessId = readiness.rollbackWorkerReadinessId
  const rollbackApprovalId = readiness.rollbackApprovalId
  const rollbackPreviewId = readiness.rollbackPreviewId
  const changeSetId = readiness.changeSetId
  const batchId = readiness.batchId

  if (!connectionId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_SOURCE_REQUIRED',
      message: 'Connector guarded update rollback apply requires a selected source',
      source: 'adapter',
      operation: 'requestConnectorGuardedUpdateRollbackApplyJob',
      i18nKey: 'erp.errors.sourceMissing',
    })
  }
  if (!batchId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_IMPORT_BATCH_REQUIRED',
      message: 'Connector guarded update rollback apply requires an applied batch',
      source: 'adapter',
      operation: 'requestConnectorGuardedUpdateRollbackApplyJob',
      i18nKey: 'erp.errors.importBatchMissing',
    })
  }
  if (
    !rollbackWorkerReadinessId ||
    !rollbackApprovalId ||
    !rollbackPreviewId ||
    !changeSetId ||
    readiness.workerHandoffReady !== true ||
    readiness.summary.rollbackCount <= 0 ||
    readiness.summary.blockerCount > 0 ||
    readiness.summary.driftBlockedCount > 0 ||
    readiness.summary.expiredSnapshotCount > 0 ||
    readiness.rollbackJobEnqueueEnabled !== false ||
    readiness.rollbackExecutionEnabled !== false ||
    readiness.canonicalWriteEnabled !== false ||
    readiness.sourceWritebackEnabled !== false ||
    readiness.credentialReadbackEnabled !== false ||
    readiness.valueReadbackEnabled !== false ||
    readiness.providerApiCallsEnabled !== false
  ) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_ROLLBACK_WORKER_APPLY_BLOCKED',
      message: 'Connector guarded update rollback worker apply is blocked by readiness evidence',
      source: 'adapter',
      operation: 'requestConnectorGuardedUpdateRollbackApplyJob',
      i18nKey: 'erp.errors.rollbackApplyBlocked',
    })
  }

  const queued = await pulsIntegration().rpc(
    'enqueue_connector_guarded_update_rollback_apply_job',
    {
      p_rollback_worker_readiness_id: rollbackWorkerReadinessId,
    },
  )

  if (queued.error) {
    throw fromConnectorRpcError(queued.error, 'requestConnectorGuardedUpdateRollbackApplyJob')
  }

  const row = ((queued.data ?? []) as ConnectorGuardedUpdateRollbackApplyJobRow[])[0] ?? null
  const jobId = row?.job_id ?? null
  if (!jobId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_ROLLBACK_WORKER_APPLY_BLOCKED',
      message: 'Connector guarded update rollback apply queue RPC returned no job evidence',
      source: 'adapter',
      operation: 'requestConnectorGuardedUpdateRollbackApplyJob',
      i18nKey: 'erp.errors.rollbackApplyBlocked',
    })
  }

  const now = new Date().toISOString()
  const write = await pulsIntegration()
    .from('erp_sync_batches')
    .insert({
      tenant_id: ctx.tenantId,
      connection_id: connectionId,
      sync_type: 'import_apply_review',
      event_key: 'import_apply_guarded_update_rollback_queued',
      actor_employee_id: ctx.employeeId,
      status: 'pending',
      started_at: now,
      records_seen: readiness.summary.rowCount,
      records_inserted: 0,
      records_updated: readiness.summary.rollbackCount,
      records_failed: 0,
      error_summary: null,
      safe_error_code: null,
      safe_error_context: {
        job_id: jobId,
        rollback_worker_readiness_id: rollbackWorkerReadinessId,
        rollback_approval_id: rollbackApprovalId,
        rollback_preview_id: rollbackPreviewId,
        change_set_id: changeSetId,
        import_batch_id: batchId,
        contract_version: 'pr16.8-guarded-update-rollback-worker-apply-v1',
        worker_contract: readiness.workerContract,
        expected_job_type: readiness.expectedJobType,
        expected_job_domain: readiness.expectedJobDomain,
        rollback_preview_checksum: readiness.rollbackPreviewChecksum,
        row_count: readiness.summary.rowCount,
        rollback_count: row?.rollback_count ?? readiness.summary.rollbackCount,
        field_diff_count: row?.field_diff_count ?? readiness.summary.fieldDiffCount,
        rollback_snapshot_count:
          row?.rollback_snapshot_count ?? readiness.summary.rollbackSnapshotCount,
        original_apply_event_count: readiness.summary.originalApplyEventCount,
        current_state_verified_count: readiness.summary.currentStateVerifiedCount,
        retention_verified_count: readiness.summary.retentionVerifiedCount,
        worker_queue: true,
        safe_to_rollback: false,
        rollback_job_enqueue_open: true,
        rollback_execution_open: true,
        canonical_write_open: true,
        browser_direct_apply_open: false,
        authenticated_apply_rpc_open: false,
        compensating_execution_open: false,
        source_writeback_open: false,
        credential_readback_open: false,
        provider_api_calls: false,
        field_value_readback: false,
        raw_payload_readback: false,
        snapshot_payload_readback: false,
      },
      next_action_key: row?.next_action_key ?? 'wait_for_guarded_update_rollback_worker_apply',
    })
    .select('id')
    .single()

  if (write.error) {
    throw fromSupabaseError(
      write.error,
      'requestConnectorGuardedUpdateRollbackApplyJob',
      'puls_integration',
      'erp_sync_batches',
    )
  }

  return {
    connectionId,
    batchId,
    changeSetId,
    rollbackPreviewId,
    rollbackApprovalId,
    rollbackWorkerReadinessId,
    jobId,
    status: row?.status ?? 'queued',
    nextActionKey: row?.next_action_key ?? 'wait_for_guarded_update_rollback_worker_apply',
    safeToRollback: false,
  }
}

export async function requestConnectorCreateOnlyApplyJob(
  userId: string,
): Promise<RequestConnectorCreateOnlyApplyJobResult> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_TENANT_REQUIRED',
      message: 'Connector create-only apply requires tenant context',
      source: 'adapter',
      operation: 'requestConnectorCreateOnlyApplyJob',
      i18nKey: 'erp.errors.tenantMissing',
    })
  }
  if (ctx.personaRole !== 'hr_admin' && ctx.personaRole !== 'superadmin') {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_ADMIN_REQUIRED',
      message: 'Connector create-only apply requires admin permission',
      source: 'adapter',
      operation: 'requestConnectorCreateOnlyApplyJob',
      i18nKey: 'erp.errors.adminRequired',
    })
  }

  const overview = await fetchRealErpOverview(userId)
  const connectionId = overview.provider.id
  const batch = overview.importPreview.batch
  const changeSetId = overview.applyChangeSet.id
  if (!connectionId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_SOURCE_REQUIRED',
      message: 'Connector create-only apply requires a selected source',
      source: 'adapter',
      operation: 'requestConnectorCreateOnlyApplyJob',
      i18nKey: 'erp.errors.sourceMissing',
    })
  }
  if (!batch) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_IMPORT_BATCH_REQUIRED',
      message: 'Connector create-only apply requires a preview batch',
      source: 'adapter',
      operation: 'requestConnectorCreateOnlyApplyJob',
      i18nKey: 'erp.errors.importBatchMissing',
    })
  }
  if (
    !changeSetId ||
    !overview.applyExecutionContract.safeToExecute ||
    overview.applyExecutionContract.executorMode !== 'worker_create_only_job'
  ) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_CREATE_ONLY_APPLY_BLOCKED',
      message: 'Connector create-only worker apply is blocked by the current safety contract',
      source: 'adapter',
      operation: 'requestConnectorCreateOnlyApplyJob',
      i18nKey: 'erp.errors.createOnlyApplyBlocked',
    })
  }

  const queued = await pulsIntegration().rpc('enqueue_connector_create_only_apply_job', {
    p_change_set_id: changeSetId,
  })

  if (queued.error) {
    throw fromConnectorRpcError(queued.error, 'requestConnectorCreateOnlyApplyJob')
  }

  const row = ((queued.data ?? []) as ConnectorCreateOnlyApplyJobRow[])[0] ?? null
  const jobId = row?.job_id ?? null
  if (!jobId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_CREATE_ONLY_APPLY_BLOCKED',
      message: 'Connector create-only apply queue RPC returned no job evidence',
      source: 'adapter',
      operation: 'requestConnectorCreateOnlyApplyJob',
      i18nKey: 'erp.errors.createOnlyApplyBlocked',
    })
  }

  const now = new Date().toISOString()
  const write = await pulsIntegration()
    .from('erp_sync_batches')
    .insert({
      tenant_id: ctx.tenantId,
      connection_id: connectionId,
      sync_type: 'import_apply_review',
      event_key: 'import_apply_create_only_queued',
      actor_employee_id: ctx.employeeId,
      status: 'pending',
      started_at: now,
      records_seen: overview.applyChangeSet.summary.rowCount,
      records_inserted: overview.applyChangeSet.summary.createCount,
      records_updated: 0,
      records_failed: 0,
      error_summary: null,
      safe_error_code: null,
      safe_error_context: {
        job_id: jobId,
        change_set_id: changeSetId,
        import_batch_id: batch.id,
        contract_version: overview.applyExecutionContract.contractVersion,
        source_namespace_code: batch.sourceNamespaceCode,
        row_count: overview.applyChangeSet.summary.rowCount,
        create_count: overview.applyChangeSet.summary.createCount,
        update_count: 0,
        skip_count: 0,
        blocked_count: 0,
        worker_queue: true,
        safe_to_apply: false,
        apply_execution_open: true,
        canonical_write_open: true,
        browser_direct_apply_open: false,
        authenticated_apply_rpc_open: false,
        source_writeback_open: false,
        credential_readback_open: false,
        field_value_readback: false,
        raw_payload_readback: false,
      },
      next_action_key: row?.next_action_key ?? 'wait_for_create_only_worker_apply',
    })
    .select('id')
    .single()

  if (write.error) {
    throw fromSupabaseError(
      write.error,
      'requestConnectorCreateOnlyApplyJob',
      'puls_integration',
      'erp_sync_batches',
    )
  }

  return {
    connectionId,
    batchId: batch.id,
    changeSetId,
    jobId,
    status: row?.status ?? 'queued',
    nextActionKey: row?.next_action_key ?? 'wait_for_create_only_worker_apply',
    safeToApply: false,
  }
}

export async function requestConnectorGuardedUpdateApplyJob(
  userId: string,
): Promise<RequestConnectorGuardedUpdateApplyJobResult> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_TENANT_REQUIRED',
      message: 'Connector guarded update apply requires tenant context',
      source: 'adapter',
      operation: 'requestConnectorGuardedUpdateApplyJob',
      i18nKey: 'erp.errors.tenantMissing',
    })
  }
  if (ctx.personaRole !== 'hr_admin' && ctx.personaRole !== 'superadmin') {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_ADMIN_REQUIRED',
      message: 'Connector guarded update apply requires admin permission',
      source: 'adapter',
      operation: 'requestConnectorGuardedUpdateApplyJob',
      i18nKey: 'erp.errors.adminRequired',
    })
  }

  const overview = await fetchRealErpOverview(userId)
  const connectionId = overview.provider.id
  const batch = overview.importPreview.batch
  const changeSetId = overview.applyChangeSet.id
  if (!connectionId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_SOURCE_REQUIRED',
      message: 'Connector guarded update apply requires a selected source',
      source: 'adapter',
      operation: 'requestConnectorGuardedUpdateApplyJob',
      i18nKey: 'erp.errors.sourceMissing',
    })
  }
  if (!batch) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_IMPORT_BATCH_REQUIRED',
      message: 'Connector guarded update apply requires a preview batch',
      source: 'adapter',
      operation: 'requestConnectorGuardedUpdateApplyJob',
      i18nKey: 'erp.errors.importBatchMissing',
    })
  }
  if (
    !changeSetId ||
    !overview.applyExecutionContract.safeToExecute ||
    overview.applyExecutionContract.executorMode !== 'worker_guarded_update_job'
  ) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_GUARDED_UPDATE_APPLY_BLOCKED',
      message: 'Connector guarded update worker apply is blocked by the current safety contract',
      source: 'adapter',
      operation: 'requestConnectorGuardedUpdateApplyJob',
      i18nKey: 'erp.errors.guardedUpdateApplyBlocked',
    })
  }

  const queued = await pulsIntegration().rpc('enqueue_connector_guarded_update_apply_job', {
    p_change_set_id: changeSetId,
  })

  if (queued.error) {
    throw fromConnectorRpcError(queued.error, 'requestConnectorGuardedUpdateApplyJob')
  }

  const row = ((queued.data ?? []) as ConnectorGuardedUpdateApplyJobRow[])[0] ?? null
  const jobId = row?.job_id ?? null
  if (!jobId) {
    throw new DataAdapterError({
      code: 'PULS_CONNECTOR_GUARDED_UPDATE_APPLY_BLOCKED',
      message: 'Connector guarded update apply queue RPC returned no job evidence',
      source: 'adapter',
      operation: 'requestConnectorGuardedUpdateApplyJob',
      i18nKey: 'erp.errors.guardedUpdateApplyBlocked',
    })
  }

  const now = new Date().toISOString()
  const write = await pulsIntegration()
    .from('erp_sync_batches')
    .insert({
      tenant_id: ctx.tenantId,
      connection_id: connectionId,
      sync_type: 'import_apply_review',
      event_key: 'import_apply_guarded_update_queued',
      actor_employee_id: ctx.employeeId,
      status: 'pending',
      started_at: now,
      records_seen: overview.applyChangeSet.summary.rowCount,
      records_inserted: 0,
      records_updated: overview.applyChangeSet.summary.updateCount,
      records_failed: 0,
      error_summary: null,
      safe_error_code: null,
      safe_error_context: {
        job_id: jobId,
        change_set_id: changeSetId,
        import_batch_id: batch.id,
        contract_version: overview.applyExecutionContract.contractVersion,
        source_namespace_code: batch.sourceNamespaceCode,
        row_count: overview.applyChangeSet.summary.rowCount,
        create_count: 0,
        update_count: overview.applyChangeSet.summary.updateCount,
        guarded_update_count: overview.applyChangeSet.summary.guardedUpdateCount,
        field_diff_count: overview.guardedUpdateEvidence.summary.fieldDiffCount,
        rollback_snapshot_count: overview.guardedUpdateEvidence.summary.rollbackSnapshotCount,
        skip_count: 0,
        blocked_count: overview.applyChangeSet.summary.blockedCount,
        worker_queue: true,
        safe_to_apply: false,
        apply_execution_open: true,
        canonical_write_open: true,
        browser_direct_apply_open: false,
        authenticated_apply_rpc_open: false,
        source_writeback_open: false,
        credential_readback_open: false,
        provider_api_calls: false,
        field_value_readback: false,
        raw_payload_readback: false,
        rollback_execution: false,
      },
      next_action_key: row?.next_action_key ?? 'wait_for_guarded_update_worker_apply',
    })
    .select('id')
    .single()

  if (write.error) {
    throw fromSupabaseError(
      write.error,
      'requestConnectorGuardedUpdateApplyJob',
      'puls_integration',
      'erp_sync_batches',
    )
  }

  return {
    connectionId,
    batchId: batch.id,
    changeSetId,
    jobId,
    status: row?.status ?? 'queued',
    nextActionKey: row?.next_action_key ?? 'wait_for_guarded_update_worker_apply',
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
