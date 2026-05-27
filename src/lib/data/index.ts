export { isPulsDemoModeEnabled } from '#/lib/data/demo-mode'

export {
  pulsAudit,
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
  DataAdapterError,
  adapterError,
  fromRpcError,
  fromSupabaseError,
  isDataAdapterError,
  mapRpcErrorToI18nKey,
  parseRpcErrorCode,
  type DataAdapterErrorFields,
} from '#/lib/data/errors'

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
  type DemoEmployeeStatus,
  type EmployeeListItem,
  type EmployeeListStats,
  type EmployeesOverview,
} from '#/lib/data/core/employees'

export {
  fetchDepartmentsOverview,
  fetchPositionsOverview,
  type DepartmentsOverview,
  type PositionsOverview,
} from '#/lib/data/core/organization'

export {
  fetchDashboardOverview,
  type DashboardPageData,
  type DashboardStats,
} from '#/lib/data/dashboard/overview'

export { fetchMenuOverview, type MenuOverview } from '#/lib/data/menu/overview'

export { fetchProfileOverview, type ProfileOverview } from '#/lib/data/profile/overview'

export { fetchSettingsOverview, type SettingsOverview } from '#/lib/data/settings/overview'

export { fetchErpOverview, type ErpOverview } from '#/lib/data/setup/erp'

export {
  fetchCompanySetupOverview,
  type CompanySetupOverview,
} from '#/lib/data/setup/company'

export {
  fetchLeaveTypesOverview,
  createLeaveType,
  updateLeaveType,
  deactivateLeaveType,
  restoreLeaveType,
  applyLeaveTypeLifecycleFilter,
  mapLeaveTypeLifecycleError,
  parseLeaveTypeLifecycleRpcResult,
  mapLeaveTypeMutationError,
  normalizeLeaveTypeCode,
  type LeaveTypeLifecycleErrorMapping,
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
  type CostCenterReadinessItem,
  type CostCenterReadinessOverview,
  type CostCenterReadinessStatus,
  type ExpenseRoutingReadinessWarning,
  type ExportSourceType,
} from '#/lib/data/setup/cost-center-readiness'

export {
  fetchPerformanceParametersOverview,
  type PerformanceParametersOverview,
} from '#/lib/data/setup/performance-parameters'

export {
  fetchLeaveOverview,
  type LeaveOverview,
  type LeaveStatus,
} from '#/lib/data/leave/overview'

export {
  createLeaveRequest,
  type CreateLeaveRequestPayload,
  type CreateLeaveRequestResult,
} from '#/lib/data/leave/requests'

export { fetchExpenseOverview, type ExpenseOverview } from '#/lib/data/expense/overview'

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
  type PerformanceOverview,
} from '#/lib/data/performance/overview'

export {
  createPerformanceCycle,
  fetchCompetencyTemplates,
  fetchPerformanceCycles,
  updatePerformanceCycle,
  type CompetencyTemplate,
  type CreateCycleInput,
  type PerformansCycle,
} from '#/lib/data/performance/cycles'

export { fetchCareerOverview, type CareerOverview } from '#/lib/data/career/overview'

export { fetchTrainingOverview, type TrainingOverview } from '#/lib/data/training/overview'

export {
  fetchContractsOverview,
  type ContractsOverview,
} from '#/lib/data/contracts/overview'

export {
  fetchJobEvaluationOverview,
  type JobEvaluationOverview,
} from '#/lib/data/job-evaluation/overview'

export { fetchAiCoachOverview, type AiCoachOverview } from '#/lib/data/ai-coach/overview'
