import type { ErpOverview } from '#/lib/data'

import type { ErpWorkbenchTab } from './dataSourceUi'

export type EmptyMutation = {
  isPending: boolean
  mutateAsync: () => Promise<unknown>
}

export type DataSourceTechnicalDetailsPermissions = {
  canManageConnectors: boolean
  canRunImportPreview: boolean
  canRequestApplyReview: boolean
  canRequestApplyChangeSet: boolean
  canRequestGuardedUpdateEvidence: boolean
  canRecordRollbackApproval: boolean
  canRequestRollbackWorkerReadiness: boolean
  canRequestRollbackApplyJob: boolean
  requestRollbackApplyPending: boolean
  canRecordApplyApproval: boolean
  canRequestApplyExecutionJob: boolean
  requestApplyExecutionPending: boolean
  canRequestGuardedUpdateApplyJob: boolean
  canRequestCredentialHandoff: boolean
  canRequestRuntimePreflight: boolean
}

export type DataSourceTechnicalDetailsMutations = {
  runPreflight: EmptyMutation
  runImportPreview: EmptyMutation
  requestApplyReview: EmptyMutation
  requestApplyChangeSet: EmptyMutation
  requestGuardedUpdateEvidence: EmptyMutation
  recordApplyApproval: EmptyMutation
  recordRollbackApproval: EmptyMutation
  requestRollbackWorkerReadiness: EmptyMutation
  requestRollbackApplyJob: EmptyMutation
  requestCreateOnlyApplyJob: EmptyMutation
  requestGuardedUpdateApplyJob: EmptyMutation
  requestCredentialHandoff: EmptyMutation
  requestRuntimePreflight: EmptyMutation
}

export type DataSourceTechnicalDetailsSheetProps = {
  data: ErpOverview
  technicalDetailsOpen: boolean
  setTechnicalDetailsOpen: (open: boolean) => void
  activeWorkbenchTab: ErpWorkbenchTab
  setActiveWorkbenchTab: (tab: ErpWorkbenchTab) => void
  showWorkbenchTab: (tab: ErpWorkbenchTab, targetId?: string) => void
  credentialSheetOpen: boolean
  setCredentialSheetOpen: (open: boolean) => void
  permissions: DataSourceTechnicalDetailsPermissions
  mutations: DataSourceTechnicalDetailsMutations
}

export type DataSourceTechnicalTabPanelProps = {
  data: ErpOverview
  permissions: DataSourceTechnicalDetailsPermissions
  mutations: DataSourceTechnicalDetailsMutations
}
