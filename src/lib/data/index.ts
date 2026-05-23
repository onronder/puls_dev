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
  fromSupabaseError,
  isDataAdapterError,
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
  type LeaveTypesOverview,
} from '#/lib/data/setup/leave-types'

export {
  fetchExpenseCategoriesOverview,
  type ExpenseCategoriesOverview,
} from '#/lib/data/setup/expense-categories'

export {
  fetchPerformanceParametersOverview,
  type PerformanceParametersOverview,
} from '#/lib/data/setup/performance-parameters'

export {
  fetchLeaveOverview,
  type LeaveOverview,
  type LeaveStatus,
} from '#/lib/data/leave/overview'

export { fetchExpenseOverview, type ExpenseOverview } from '#/lib/data/expense/overview'

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
