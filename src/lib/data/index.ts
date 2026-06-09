export {
  isPulsDemoModeEnabled,
  readPulsDemoModeConfig,
  type PulsDemoModeConfig,
} from '#/lib/data/demo-mode'

export {
  pulsAudit,
  pulsApp,
  pulsCalc,
  pulsCore,
  pulsIntegration,
  pulsPerformance,
  pulsWorkflow,
  requireEmployeeId,
  requireTenantId,
  resolveTenantContext,
  type TenantContext,
} from '#/lib/data/client'

export {
  dismissAppNotification,
  appNotificationRealtimeTopic,
  clearAppNotificationPreference,
  fetchAppNotificationPage,
  fetchAppNotificationPreferences,
  fetchAppNotificationScenarioContracts,
  fetchAppNotificationSummary,
  mapAppNotificationRealtimeSignal,
  markAllAppNotificationsRead,
  markAppNotificationRead,
  subscribeToAppNotificationSignals,
  upsertAppNotificationPreference,
  type AppNotification,
  type AppNotificationCursor,
  type AppNotificationPage,
  type AppNotificationPreference,
  type AppNotificationPreferenceInput,
  type AppNotificationRealtimeSignal,
  type AppNotificationRealtimeStatus,
  type AppNotificationScenarioContract,
  type AppNotificationSeverity,
  type AppNotificationSummary,
  type AppNotificationSignalSubscription,
  type ClearAppNotificationPreferenceResult,
  type NotificationCenterFilter,
  type NotificationReadState,
} from '#/lib/data/app/notifications'

export {
  DataAdapterError,
  adapterError,
  fromRpcError,
  fromSupabaseError,
  isDataAdapterError,
  mapRpcErrorToI18nKey,
  parseRpcErrorCode,
  type DataAdapterErrorFields,
} from '#/lib/data/errors'

export { invalidateOrgStructureQueries } from '#/lib/data/query-invalidation'

export {
  mapContractStatusTone,
  mapExpenseClaimStatusTone,
  mapLeaveRequestStatusTone,
  mapPerformanceCycleStatus,
  mapPerformanceStatusBandTone,
  type PerformanceStatusBand,
} from '#/lib/data/mappers'

export {
  resolveAdapterData,
  resolveAdapterDataWithMeta,
  type DataResult,
  type ResolveAdapterDataOptions,
} from '#/lib/data/result'

export {
  fetchEmployeesOverview,
  fetchEmployeeList,
  fetchEmployeeListStats,
  fetchEmployeesOverviewWithMeta,
  fetchEmployeeListWithMeta,
  fetchEmployeeListStatsWithMeta,
  buildEmployeeListStats,
  emptyEmployeeListStats,
  isActiveEmployeeStatus,
  mapEmployeeRow,
  type DemoEmployeeStatus,
  type EmployeeListItem,
  type EmployeeListStats,
  type EmployeeRowForList,
  type EmployeesOverview,
} from '#/lib/data/core/employees'

export {
  fetchDepartmentsOverview,
  fetchPositionsOverview,
  fetchDepartmentsOverviewWithMeta,
  fetchPositionsOverviewWithMeta,
  applyOrgEntityLifecycleFilter,
  createDepartment,
  deactivateDepartment,
  updateDepartment,
  restoreDepartment,
  createPosition,
  deactivatePosition,
  updatePosition,
  restorePosition,
  mapDepartmentLifecycleError,
  mapDepartmentMutationError,
  mapPositionLifecycleError,
  mapPositionMutationError,
  type DepartmentLifecycleResult,
  type DepartmentMutationInput,
  type DepartmentMutationErrorMapping,
  type OrgEntityLifecycleFilter,
  type OrgLifecycleErrorMapping,
  type PositionLifecycleResult,
  type PositionMutationInput,
  type PositionMutationErrorMapping,
  type DepartmentsOverview,
  type PositionsOverview,
} from '#/lib/data/core/organization'

export {
  buildDashboardErpStatus,
  buildDashboardPageDataFromDemo,
  buildDashboardQueue,
  fetchDashboardOverview,
  fetchDashboardOverviewWithMeta,
  isDashboardEmpty,
  type DashboardPageData,
  type DashboardStats,
} from '#/lib/data/dashboard/overview'

export { fetchMenuOverview, type MenuOverview } from '#/lib/data/menu/overview'

export {
  buildEmptyProfileOverview,
  buildProfileAccountLinkStatus,
  buildProfileOverviewFromDemo,
  fetchProfileOverview,
  fetchProfileOverviewWithMeta,
  isProfileOverviewEmpty,
  type ProfileEmployeeLinkStatus,
  type ProfileOverview,
} from '#/lib/data/profile/overview'

export {
  fetchSettingsOverview,
  fetchSettingsOverviewWithMeta,
  type SettingsOverview,
} from '#/lib/data/settings/overview'

export {
  fetchErpOverview,
  fetchErpOverviewWithMeta,
  buildDefaultConnectorFieldMappings,
  ingestFileImportBatch,
  ingestFileImportPackage,
  mapConnectorSetupError,
  recordConnectorApplyApproval,
  recordConnectorGuardedUpdateRollbackApproval,
  requestConnectorGuardedUpdateRollbackApplyJob,
  requestConnectorGuardedUpdateRollbackWorkerReadiness,
  requestConnectorApplyChangeSet,
  requestConnectorGuardedUpdateEvidence,
  requestConnectorGuardedUpdateApplyJob,
  requestConnectorCreateOnlyApplyJob,
  requestConnectorApplyReview,
  requestConnectorCredentialHandoff,
  requestConnectorRuntimePreflight,
  runConnectorImportPreview,
  runConnectorPreflight,
  startConnectorSetup,
  type ConnectorCanonicalDataClass,
  type ConnectorCanonicalDataClassId,
  type ConnectorActivityDetail,
  type ConnectorActivityEvent,
  type ConnectorActivityEventKind,
  type ConnectorApplyReadiness,
  type ConnectorApplyReadinessAction,
  type ConnectorApplyReadinessBlocker,
  type ConnectorApplyReadinessBlockerId,
  type ConnectorApplyReadinessCheck,
  type ConnectorApplyReadinessCheckId,
  type ConnectorApplyReadinessStatus,
  type ConnectorApplyApprovalPolicy,
  type ConnectorApplyApprovalPolicyAction,
  type ConnectorApplyApprovalPolicyStatus,
  type ConnectorApplyChangeSet,
  type ConnectorApplyChangeSetAction,
  type ConnectorApplyChangeSetItemSummary,
  type ConnectorApplyChangeSetStatus,
  type ConnectorGuardedUpdateEvidence,
  type ConnectorGuardedUpdateEvidenceAction,
  type ConnectorGuardedUpdateEvidenceStatus,
  type ConnectorGuardedUpdateFieldDiffSummary,
  type ConnectorGuardedUpdateRecoveryAction,
  type ConnectorGuardedUpdateRecoveryEventSummary,
  type ConnectorGuardedUpdateRecoveryReadiness,
  type ConnectorGuardedUpdateRecoveryRunbook,
  type ConnectorGuardedUpdateRecoveryRunbookAction,
  type ConnectorGuardedUpdateRecoveryRunbookStatus,
  type ConnectorGuardedUpdateRecoveryRunbookStep,
  type ConnectorGuardedUpdateRecoveryRunbookStepStatus,
  type ConnectorGuardedUpdateRecoveryStatus,
  type ConnectorGuardedUpdateRollbackPreview,
  type ConnectorGuardedUpdateRollbackPreviewAction,
  type ConnectorGuardedUpdateRollbackApproval,
  type ConnectorGuardedUpdateRollbackApprovalAction,
  type ConnectorGuardedUpdateRollbackApprovalStatus,
  type ConnectorGuardedUpdateRollbackWorkerReadiness,
  type ConnectorGuardedUpdateRollbackWorkerReadinessAction,
  type ConnectorGuardedUpdateRollbackWorkerReadinessItem,
  type ConnectorGuardedUpdateRollbackWorkerReadinessStatus,
  type ConnectorGuardedUpdateRollbackPreviewItem,
  type ConnectorGuardedUpdateRollbackPreviewStatus,
  type RecordConnectorGuardedUpdateRollbackApprovalResult,
  type RequestConnectorGuardedUpdateRollbackApplyJobResult,
  type RequestConnectorGuardedUpdateRollbackWorkerReadinessResult,
  type RequestConnectorGuardedUpdateApplyJobResult,
  type ConnectorApplyExecutionContract,
  type ConnectorApplyExecutionContractStatus,
  type ConnectorApplyExecutionControl,
  type ConnectorApplyExecutionControlId,
  type ConnectorApplyAuditTier,
  type ConnectorApplyOperation,
  type ConnectorApplySafetyContract,
  type ConnectorApplySafetyPolicyState,
  type ConnectorApplyRiskClass,
  type ConnectorControlledApplyGate,
  type ConnectorControlledApplyGateId,
  type ConnectorControlledApplyPlan,
  type ConnectorControlledApplyPlanStatus,
  type ConnectorAuthMode,
  type ConnectorCredentialBoundary,
  type ConnectorDefaultFieldMapping,
  type ConnectorCredentialHandoff,
  type ConnectorCredentialHandoffAction,
  type ConnectorCredentialHandoffStatus,
  type ConnectorCredentialState,
  type ConnectorImportPreview,
  type ConnectorImportPreviewAction,
  type ConnectorImportPreviewBatch,
  type ConnectorImportPreviewBatchStatus,
  type ConnectorImportPreviewRecord,
  type ConnectorImportPreviewRecordAction,
  type ConnectorImportPreviewRecordStatus,
  type ConnectorImportPreviewStatus,
  type ConnectorImportPreviewSummary,
  type ConnectorSetupErrorMapping,
  type ConnectorFieldMapping,
  type ConnectorGuardrail,
  type ConnectorLifecycleState,
  type ConnectorNamespaceSummary,
  type ConnectorPreflightCheck,
  type ConnectorPreflightCheckId,
  type ConnectorPreflightResult,
  type ConnectorProviderRequirement,
  type ConnectorProviderStatus,
  type ConnectorProviderOption,
  type ConnectorReadinessCheck,
  type ConnectorReadinessStatus,
  type ConnectorRuntimeJobStatus,
  type ConnectorRuntimeJobSummary,
  type ConnectorRuntimeJobType,
  type ConnectorRuntimeFailureClass,
  type ConnectorRuntimeLeaseStatus,
  type ConnectorRuntimeOperatorSeverity,
  type ConnectorRuntimeQueue,
  type ConnectorRuntimeQueueStatus,
  type ConnectorRuntimeWorker,
  type ConnectorRuntimeWorkerStatus,
  type ConnectorSetupStep,
  type ConnectorSetupStepId,
  type ConnectorSetupCurrentStep,
  type ConnectorSetupSummary,
  type ConnectorSetupStatus,
  type ConnectorSyncLog,
  type ConnectorSyncLogLevel,
  type ConnectorTransferMode,
  type ErpOverview,
  type IngestFileImportBatchInput,
  type IngestFileImportBatchResult,
  type RequestConnectorApplyChangeSetResult,
  type RequestConnectorGuardedUpdateEvidenceResult,
  type RequestConnectorCreateOnlyApplyJobResult,
  type RequestConnectorApplyReviewResult,
  type RecordConnectorApplyApprovalResult,
  type RequestConnectorCredentialHandoffResult,
  type RequestConnectorRuntimePreflightResult,
  type RunConnectorImportPreviewResult,
  type RunConnectorPreflightResult,
  type StartConnectorSetupInput,
  type StartConnectorSetupResult,
} from '#/lib/data/setup/erp'

export {
  fetchCompanySetupOverview,
  fetchCompanySetupOverviewWithMeta,
  type CompanySetupOverview,
} from '#/lib/data/setup/company'

export {
  fetchLeaveTypesOverview,
  fetchLeaveTypesOverviewWithMeta,
  createLeaveType,
  updateLeaveType,
  deactivateLeaveType,
  restoreLeaveType,
  fetchLeaveTypeLifecycleEvents,
  applyLeaveTypeLifecycleFilter,
  mapLeaveTypeLifecycleError,
  mapLeaveTypeLifecycleEventRow,
  parseLeaveTypeLifecycleRpcResult,
  mapLeaveTypeMutationError,
  normalizeLeaveTypeCode,
  normalizeDeactivateLeaveTypeReason,
  isDeactivateLeaveTypeReasonTooLong,
  DEACTIVATE_LEAVE_TYPE_REASON_MAX_LENGTH,
  type LeaveTypeLifecycleErrorMapping,
  type LeaveTypeLifecycleEvent,
  type LeaveTypeLifecycleEventAction,
  type LeaveTypeLifecycleFilter,
  type LeaveTypeLifecycleResult,
  type LeaveTypeMutationErrorMapping,
  type LeaveTypeMutationInput,
  type LeaveTypesOverview,
} from '#/lib/data/setup/leave-types'

export {
  isLeaveTypeFormDirty,
  validateLeaveTypeForm,
  type LeaveTypeFieldKey,
  type LeaveTypeFormFields,
} from '#/lib/data/setup/leave-type-validation'

export {
  applyExpenseCategoryLifecycleFilter,
  createExpenseCategory,
  deactivateExpenseCategory,
  fetchExpenseCategoryLifecycleEvents,
  fetchExpenseCategoriesOverview,
  fetchExpenseCategoriesOverviewWithMeta,
  isDeactivateReasonTooLong,
  mapExpenseCategoryLifecycleEventRow,
  mapExpenseCategoryLifecycleError,
  mapExpenseCategoryMutationError,
  normalizeCategoryCode,
  normalizeDeactivateReason,
  parseExpenseCategoryLifecycleRpcResult,
  restoreExpenseCategory,
  updateExpenseCategory,
  DEACTIVATE_REASON_MAX_LENGTH,
  type ExpenseCategoryLifecycleErrorMapping,
  type ExpenseCategoryLifecycleEvent,
  type ExpenseCategoryLifecycleEventAction,
  type ExpenseCategoryLifecycleFilter,
  type ExpenseCategoryLifecycleResult,
  type ExpenseCategoryMutationErrorMapping,
  type ExpenseCategoryMutationInput,
  type ExpenseCategoriesOverview,
} from '#/lib/data/setup/expense-categories'

export {
  isExpenseCategoryFormDirty,
  validateExpenseCategoryForm,
  type ExpenseCategoryFieldKey,
  type ExpenseCategoryFormFields,
} from '#/lib/data/setup/expense-category-validation'

export {
  fetchCostCenterReadinessOverview,
  fetchCostCenterReadinessOverviewWithMeta,
  type CostCenterReadinessItem,
  type CostCenterReadinessOverview,
  type CostCenterReadinessStatus,
  type ExpenseRoutingReadinessWarning,
  type ExportSourceType,
} from '#/lib/data/setup/cost-center-readiness'

export {
  buildOrgSetupReadinessSummary,
  computeCostCenterReadinessSummaryStatus,
  computeDepartmentReadinessStatus,
  computePositionReadinessStatus,
  fetchOrgSetupReadiness,
  type OrgSetupReadinessDomainSummary,
  type OrgSetupReadinessOverview,
  type OrgSetupReadinessStatus,
  type OrgSetupReadinessSummary,
} from '#/lib/data/setup/org-setup-readiness'

export {
  mapOrgEntitySource,
  isOrgEntityEditable,
  type OrgSetupEntitySource,
} from '#/lib/data/setup/org-entity-source'

export {
  isDepartmentFormDirty,
  isPositionFormDirty,
  normalizeOrgSetupCode,
  validateDepartmentForm,
  validatePositionForm,
  type DepartmentFieldKey,
  type DepartmentFormFields,
  type PositionFieldKey,
  type PositionFormFields,
} from '#/lib/data/setup/org-setup-validation'

export {
  applyEmployeeAssignmentReadinessFilter,
  buildEmployeeAssignmentReadinessFlags,
  buildEmployeeAssignmentReadinessSummary,
  computeEmployeeAssignmentReadiness,
  fetchCurrentEmployeeAssignmentReadiness,
  fetchCurrentEmployeeAssignmentReadinessWithMeta,
  fetchEmployeeAssignmentReadiness,
  fetchEmployeeAssignmentReadinessWithMeta,
  pickCurrentCostCenterAssignment,
  pickCurrentPrimaryManager,
  type EmployeeAssignmentEntityRef,
  type EmployeeAssignmentManagerRef,
  type EmployeeAssignmentReadinessEmployee,
  type EmployeeAssignmentReadinessFilter,
  type EmployeeAssignmentReadinessFlags,
  type EmployeeAssignmentReadinessOverview,
  type EmployeeAssignmentReadinessStatus,
  type EmployeeAssignmentReadinessSummary,
} from '#/lib/data/setup/employee-assignment-readiness'

export {
  buildApprovalPolicyReadinessSection,
  buildCostCenterReadinessSection,
  buildEmployeeAssignmentReadinessSection,
  buildExpenseReadinessSection,
  buildLeaveReadinessSection,
  buildOrgReadinessSection,
  buildRequestCreationReadinessSection,
  combineSetupReadinessSeverity,
  fetchSetupReadinessDashboard,
  rankSetupReadinessSeverity,
  type SetupReadinessActionTarget,
  type SetupReadinessDashboard,
  type SetupReadinessIssue,
  type SetupReadinessSection,
  type SetupReadinessSectionId,
  type SetupReadinessSeverity,
} from '#/lib/data/setup/setup-readiness-dashboard'

export {
  buildExpenseCreationReadiness,
  buildLeaveCreationReadiness,
  fetchRequestCreationReadiness,
  fetchRequestCreationReadinessWithMeta,
  getPrimaryRequestCreationBlocker,
  getRequestCreationBlockerI18nKey,
  getRequestCreationWarningI18nKey,
  mapPolicyStatusToWarning,
  type BuildExpenseCreationReadinessInput,
  type BuildLeaveCreationReadinessInput,
  type PolicyTarget,
  type RequestCreationBlocker,
  type RequestCreationDomain,
  type RequestCreationReadiness,
  type RequestCreationReadinessResult,
  type RequestCreationWarning,
} from '#/lib/data/setup/request-creation-readiness'

export {
  fetchPerformanceParametersOverview,
  fetchPerformanceParametersOverviewWithMeta,
  type PerformanceParametersOverview,
} from '#/lib/data/setup/performance-parameters'

export {
  fetchLeaveOverview,
  fetchLeaveOverviewWithMeta,
  type LeaveOverview,
  type LeaveStatus,
} from '#/lib/data/leave/overview'

export {
  createLeaveRequest,
  parseCreateLeaveRequestResult,
  type CreateLeaveRequestPayload,
  type CreateLeaveRequestResult,
} from '#/lib/data/leave/requests'

export {
  fetchExpenseOverview,
  fetchExpenseOverviewWithMeta,
  type ExpenseOverview,
} from '#/lib/data/expense/overview'

export {
  createExpenseClaim,
  type CreateExpenseClaimPayload,
  type CreateExpenseClaimResult,
} from '#/lib/data/expense/claims'

export {
  decideApprovalRequest,
  type ApprovalDecision,
  type DecideApprovalRequestPayload,
  type DecideApprovalRequestResult,
} from '#/lib/data/workflow/approvals'

export {
  buildApprovalPolicyBindingInfo,
  computeApprovalPolicyBindingStatus,
  parseApprovalPolicyJoin,
  type ApprovalPolicyBindingInfo,
  type ApprovalPolicyBindingInput,
  type ApprovalPolicyBindingStatus,
} from '#/lib/data/workflow/policy-binding-readiness'

export {
  fetchApprovalPoliciesOverview,
  fetchApprovalPolicyDetail,
  type ApprovalPolicyDetail,
  type ApprovalPolicyOverviewItem,
} from '#/lib/data/workflow/policies'

export {
  fetchPerformanceOverview,
  fetchPerformanceOverviewWithMeta,
  type PerformanceOverview,
} from '#/lib/data/performance/overview'

export {
  createPerformanceCycle,
  fetchCompetencyTemplates,
  fetchPerformanceCycles,
  fetchPerformanceCyclesWithMeta,
  normalizePerformanceCycleName,
  parsePerformanceCycleMutationResult,
  parsePerformanceCycleRow,
  updatePerformanceCycle,
  validatePerformanceCycleInput,
  type CompetencyTemplate,
  type CreateCycleInput,
  type PerformanceCycleValidationErrors,
  type PerformansCycle,
} from '#/lib/data/performance/cycles'

export {
  fetchCareerOverview,
  fetchCareerOverviewWithMeta,
  type CareerOverview,
} from '#/lib/data/career/overview'

export {
  fetchTrainingOverview,
  fetchTrainingOverviewWithMeta,
  type TrainingOverview,
} from '#/lib/data/training/overview'

export {
  fetchContractsOverview,
  fetchContractsOverviewWithMeta,
  getContractInitials,
  mapContractRiskStatus,
  mapContractRow,
  mapContractSignatureStatus,
  type ContractsOverview,
  type ContractRowInput,
  type MapContractRiskStatusInput,
  type MapContractRowOptions,
} from '#/lib/data/contracts/overview'

export {
  fetchJobEvaluationOverview,
  fetchJobEvaluationOverviewWithMeta,
  type JobEvaluationOverview,
} from '#/lib/data/job-evaluation/overview'

export {
  fetchAiCoachOverview,
  fetchAiCoachOverviewWithMeta,
  type AiCoachOverview,
  type AiCoachContextDomain,
} from '#/lib/data/ai-coach/overview'
