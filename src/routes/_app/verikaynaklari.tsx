import { createFileRoute } from '@tanstack/react-router'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ClipboardCheck,
  Database,
  Plug,
  RefreshCw,
  SearchCheck,
  ShieldCheck,
  type LucideIcon,
} from 'lucide-react'
import { useEffect, useState, type ChangeEvent } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { z } from 'zod'

import { SetupRouteGuard } from '#/components/auth/SetupRouteGuard'
import { DataSourceManagerSection } from '#/components/data-sources/DataSourceManagerSection'
import { DataSourceTechnicalDetailsSheet } from '#/components/data-sources/DataSourceTechnicalDetailsSheet'
import { FileImportSheet } from '#/components/data-sources/FileImportSheet'
import { ProviderDraftSheet } from '#/components/data-sources/ProviderDraftSheet'
import {
  ERP_WORKBENCH_TABS,
  connectorJourneyStepFromTarget,
  dataSourceDisplayName,
  readinessTone,
  type ConnectorJourneyAction,
  type ConnectorJourneyStep,
  type ConnectorJourneyStepId,
  type ConnectorProviderOption,
  type ConnectorStatus,
  type DataSourceSummary,
  type ErpWorkbenchTab,
} from '#/components/data-sources/dataSourceUi'
import { DemoSourcePill } from '#/components/puls/DemoSourcePill'
import { PageHeader } from '#/components/puls/PageHeader'
import { StatusPill } from '#/components/puls/StatusPill'
import { Skeleton } from '#/components/ui/skeleton'
import { useAuth } from '#/lib/auth'
import {
  fetchErpOverviewWithMeta,
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
} from '#/lib/data'
import {
  buildFileImportCsvTemplate,
  buildFileImportExpectedFileName,
  fileImportScopeOptions,
  parseFileImportPackage,
  type FileImportPackageResult,
  type FileImportScopeId,
} from '#/lib/data/setup/file-import-contract'
import { captureAppError } from '#/lib/observability/sentry'
import { canShowSetupHub } from '#/lib/setup-access'

const erpSearchSchema = z.object({
  tab: z.enum(ERP_WORKBENCH_TABS).optional(),
  focus: z
    .string()
    .regex(/^erp-[a-z0-9-]+$/)
    .optional(),
})

export const Route = createFileRoute('/_app/verikaynaklari')({
  head: () => ({
    meta: [{ title: 'Veri Kaynakları — PULS' }],
  }),
  validateSearch: erpSearchSchema,
  component: ErpRoute,
})

function ErpRoute() {
  return (
    <SetupRouteGuard allowConnectorReadOnly>
      <ErpPage />
    </SetupRouteGuard>
  )
}

const FILE_IMPORT_SCOPES = fileImportScopeOptions()

function downloadFileImportTemplate(scope: FileImportScopeId) {
  const csv = buildFileImportCsvTemplate(scope)
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = buildFileImportExpectedFileName(scope, new Date(), 'csv')
  document.body.appendChild(link)
  link.click()
  link.remove()
  URL.revokeObjectURL(url)
}

function downloadAllFileImportTemplates(scopes: FileImportScopeId[]) {
  scopes.forEach((scope, index) => {
    window.setTimeout(() => downloadFileImportTemplate(scope), index * 120)
  })
}

function ErpPage() {
  const routeSearch = Route.useSearch()
  const { t } = useTranslation()
  const { user, personaRole, activePersona } = useAuth()
  const queryClient = useQueryClient()
  const [selectedProviderId, setSelectedProviderId] = useState<
    ConnectorProviderOption['id'] | null
  >(null)
  const [selectedDataSourceId, setSelectedDataSourceId] = useState<string | null>(null)
  const [fileImportSheetOpen, setFileImportSheetOpen] = useState(false)
  const [fileImportSourceId, setFileImportSourceId] = useState<string | null>(null)
  const [fileImportConnectionId, setFileImportConnectionId] = useState<string | null>(null)
  const [fileImportScope, setFileImportScope] = useState<FileImportScopeId>('employees')
  const [fileImportPackageResult, setFileImportPackageResult] =
    useState<FileImportPackageResult | null>(null)
  const [fileImportStagedBatchIds, setFileImportStagedBatchIds] = useState<string[]>([])
  const [fileImportParsing, setFileImportParsing] = useState(false)
  const [draftSheetOpen, setDraftSheetOpen] = useState(false)
  const [credentialSheetOpen, setCredentialSheetOpen] = useState(false)
  const [activeWorkbenchTab, setActiveWorkbenchTab] = useState<ErpWorkbenchTab>('setup')
  const [technicalDetailsOpen, setTechnicalDetailsOpen] = useState(false)
  const [selectedJourneyStepId, setSelectedJourneyStepId] = useState<ConnectorJourneyStepId | null>(
    null,
  )
  const showWorkbenchTab = (tab: ErpWorkbenchTab, targetId?: string) => {
    const stepId = connectorJourneyStepFromTarget(tab, targetId)
    if (stepId) setSelectedJourneyStepId(stepId)
    setTechnicalDetailsOpen(true)
    setActiveWorkbenchTab(tab)
    if (!targetId) return
    window.setTimeout(() => {
      document.getElementById(targetId)?.scrollIntoView({ behavior: 'smooth', block: 'start' })
    }, 80)
  }
  useEffect(() => {
    const tab = routeSearch.tab
    const focus = routeSearch.focus
    if (!tab) return

    const tabTimer = window.setTimeout(() => {
      const stepId = connectorJourneyStepFromTarget(tab, focus)
      if (stepId) setSelectedJourneyStepId(stepId)
      setTechnicalDetailsOpen(true)
      setActiveWorkbenchTab(tab)
    }, 0)

    const scrollTimer = focus
      ? window.setTimeout(() => {
          document.getElementById(focus)?.scrollIntoView({
            behavior: 'smooth',
            block: 'start',
          })
        }, 120)
      : undefined

    return () => {
      window.clearTimeout(tabTimer)
      if (scrollTimer !== undefined) {
        window.clearTimeout(scrollTimer)
      }
    }
  }, [routeSearch.focus, routeSearch.tab])

  const canManageConnectors = canShowSetupHub(personaRole, activePersona)
  const { data: erpResult, isLoading } = useQuery({
    queryKey: ['erp-overview', user?.id],
    queryFn: () => fetchErpOverviewWithMeta(user!.id),
    enabled: Boolean(user?.id),
  })
  const startSetupMutation = useMutation({
    mutationFn: (providerId: ConnectorProviderOption['id']) =>
      startConnectorSetup(user!.id, { providerId }),
    onSuccess: () => {
      toast.success(t('erp.toast.setupCreated'))
      setDraftSheetOpen(false)
      setSelectedProviderId(null)
      void queryClient.invalidateQueries({ queryKey: ['erp-overview', user?.id] })
      void queryClient.invalidateQueries({ queryKey: ['dashboard-overview', user?.id] })
    },
    onError: (error) => {
      const mapped = mapConnectorSetupError(error)
      captureAppError(error, {
        area: 'connector_setup',
        operation: 'startConnectorSetup',
        providerId: selectedProviderId,
        route: '/verikaynaklari',
      })
      toast.error(t(mapped.toastKey))
    },
  })
  const prepareFileImportSourceMutation = useMutation({
    mutationFn: () => startConnectorSetup(user!.id, { providerId: 'csv_import' }),
    onSuccess: (result) => {
      setFileImportConnectionId(result.connectionId)
      toast.success(t('erp.fileImport.toast.sourceReady'))
      void queryClient.invalidateQueries({ queryKey: ['erp-overview', user?.id] })
      void queryClient.invalidateQueries({ queryKey: ['dashboard-overview', user?.id] })
    },
    onError: (error) => {
      const mapped = mapConnectorSetupError(error)
      captureAppError(error, {
        area: 'connector_setup',
        operation: 'prepareFileImportSource',
        providerId: 'csv_import',
        route: '/verikaynaklari',
      })
      toast.error(t(mapped.toastKey))
    },
  })
  const ingestFileImportMutation = useMutation({
    mutationFn: ({
      packageResult,
      connectionId,
    }: {
      packageResult: FileImportPackageResult
      connectionId: string
    }) =>
      ingestFileImportPackage(user!.id, {
        connectionId,
        packageId: packageResult.packageId,
        files: packageResult.files,
      }),
    onSuccess: (result) => {
      setFileImportStagedBatchIds(result.items.map((item) => item.batchId).filter(Boolean))
      toast.success(
        t('erp.fileImport.toast.staged', { count: result.rowCount, files: result.fileCount }),
      )
      void queryClient.invalidateQueries({ queryKey: ['erp-overview', user?.id] })
      void queryClient.invalidateQueries({ queryKey: ['dashboard-overview', user?.id] })
    },
    onError: (error) => {
      const mapped = mapConnectorSetupError(error)
      captureAppError(error, {
        area: 'connector_setup',
        operation: 'ingestFileImportPackage',
        providerId: 'csv_import',
        route: '/verikaynaklari',
      })
      toast.error(t(mapped.toastKey))
    },
  })
  const runPreflightMutation = useMutation({
    mutationFn: () => runConnectorPreflight(user!.id),
    onSuccess: (result) => {
      toast.success(t(`erp.toast.preflight.${result.status}`))
      void queryClient.invalidateQueries({ queryKey: ['erp-overview', user?.id] })
      void queryClient.invalidateQueries({ queryKey: ['dashboard-overview', user?.id] })
      showWorkbenchTab('check', 'erp-preflight-result')
    },
    onError: (error) => {
      const mapped = mapConnectorSetupError(error)
      captureAppError(error, {
        area: 'connector_setup',
        operation: 'runConnectorPreflight',
        providerId: data?.provider.code,
        route: '/verikaynaklari',
      })
      toast.error(t(mapped.toastKey))
    },
  })
  const requestCredentialHandoffMutation = useMutation({
    mutationFn: () => requestConnectorCredentialHandoff(user!.id),
    onSuccess: () => {
      toast.success(t('erp.toast.credentialHandoff.requested'))
      setCredentialSheetOpen(false)
      void queryClient.invalidateQueries({ queryKey: ['erp-overview', user?.id] })
      void queryClient.invalidateQueries({ queryKey: ['dashboard-overview', user?.id] })
    },
    onError: (error) => {
      const mapped = mapConnectorSetupError(error)
      captureAppError(error, {
        area: 'connector_setup',
        operation: 'requestConnectorCredentialHandoff',
        providerId: data?.provider.code,
        route: '/verikaynaklari',
      })
      toast.error(t(mapped.toastKey))
    },
  })
  const runImportPreviewMutation = useMutation({
    mutationFn: () => runConnectorImportPreview(user!.id),
    onSuccess: (result) => {
      toast.success(t(`erp.toast.importPreview.${result.status}`))
      void queryClient.invalidateQueries({ queryKey: ['erp-overview', user?.id] })
      void queryClient.invalidateQueries({ queryKey: ['dashboard-overview', user?.id] })
      showWorkbenchTab('previewApply', 'erp-import-preview')
    },
    onError: (error) => {
      const mapped = mapConnectorSetupError(error)
      captureAppError(error, {
        area: 'connector_setup',
        operation: 'runConnectorImportPreview',
        providerId: data?.provider.code,
        route: '/verikaynaklari',
      })
      toast.error(t(mapped.toastKey))
    },
  })
  const requestApplyReviewMutation = useMutation({
    mutationFn: () => requestConnectorApplyReview(user!.id),
    onSuccess: () => {
      toast.success(t('erp.toast.applyReadiness.reviewRequested'))
      void queryClient.invalidateQueries({ queryKey: ['erp-overview', user?.id] })
      void queryClient.invalidateQueries({ queryKey: ['dashboard-overview', user?.id] })
      showWorkbenchTab('previewApply', 'erp-apply-readiness')
    },
    onError: (error) => {
      const mapped = mapConnectorSetupError(error)
      captureAppError(error, {
        area: 'connector_setup',
        operation: 'requestConnectorApplyReview',
        providerId: data?.provider.code,
        route: '/verikaynaklari',
      })
      toast.error(t(mapped.toastKey))
    },
  })
  const requestApplyChangeSetMutation = useMutation({
    mutationFn: () => requestConnectorApplyChangeSet(user!.id),
    onSuccess: () => {
      toast.success(t('erp.toast.applyChangeSet.generated'))
      void queryClient.invalidateQueries({ queryKey: ['erp-overview', user?.id] })
      void queryClient.invalidateQueries({ queryKey: ['dashboard-overview', user?.id] })
      showWorkbenchTab('previewApply', 'erp-apply-change-set')
    },
    onError: (error) => {
      const mapped = mapConnectorSetupError(error)
      captureAppError(error, {
        area: 'connector_setup',
        operation: 'requestConnectorApplyChangeSet',
        providerId: data?.provider.code,
        route: '/verikaynaklari',
      })
      toast.error(t(mapped.toastKey))
    },
  })
  const requestGuardedUpdateEvidenceMutation = useMutation({
    mutationFn: () => requestConnectorGuardedUpdateEvidence(user!.id),
    onSuccess: () => {
      toast.success(t('erp.toast.guardedUpdateEvidence.generated'))
      void queryClient.invalidateQueries({ queryKey: ['erp-overview', user?.id] })
      void queryClient.invalidateQueries({ queryKey: ['dashboard-overview', user?.id] })
      showWorkbenchTab('previewApply', 'erp-guarded-update-evidence')
    },
    onError: (error) => {
      const mapped = mapConnectorSetupError(error)
      captureAppError(error, {
        area: 'connector_setup',
        operation: 'requestConnectorGuardedUpdateEvidence',
        providerId: data?.provider.code,
        route: '/verikaynaklari',
      })
      toast.error(t(mapped.toastKey))
    },
  })
  const recordApplyApprovalMutation = useMutation({
    mutationFn: () => recordConnectorApplyApproval(user!.id),
    onSuccess: () => {
      toast.success(t('erp.toast.applyApprovalPolicy.approvalRecorded'))
      void queryClient.invalidateQueries({ queryKey: ['erp-overview', user?.id] })
      void queryClient.invalidateQueries({ queryKey: ['dashboard-overview', user?.id] })
      showWorkbenchTab('previewApply', 'erp-controlled-apply')
    },
    onError: (error) => {
      const mapped = mapConnectorSetupError(error)
      captureAppError(error, {
        area: 'connector_setup',
        operation: 'recordConnectorApplyApproval',
        providerId: data?.provider.code,
        route: '/verikaynaklari',
      })
      toast.error(t(mapped.toastKey))
    },
  })
  const recordRollbackApprovalMutation = useMutation({
    mutationFn: () => recordConnectorGuardedUpdateRollbackApproval(user!.id),
    onSuccess: () => {
      toast.success(t('erp.toast.guardedUpdateRollbackApproval.approvalRecorded'))
      void queryClient.invalidateQueries({ queryKey: ['erp-overview', user?.id] })
      void queryClient.invalidateQueries({ queryKey: ['dashboard-overview', user?.id] })
      showWorkbenchTab('previewApply', 'erp-guarded-update-rollback-approval')
    },
    onError: (error) => {
      const mapped = mapConnectorSetupError(error)
      captureAppError(error, {
        area: 'connector_setup',
        operation: 'recordConnectorGuardedUpdateRollbackApproval',
        providerId: data?.provider.code,
        route: '/verikaynaklari',
      })
      toast.error(t(mapped.toastKey))
    },
  })
  const requestRollbackWorkerReadinessMutation = useMutation({
    mutationFn: () => requestConnectorGuardedUpdateRollbackWorkerReadiness(user!.id),
    onSuccess: () => {
      toast.success(t('erp.toast.guardedUpdateRollbackWorkerReadiness.generated'))
      void queryClient.invalidateQueries({ queryKey: ['erp-overview', user?.id] })
      void queryClient.invalidateQueries({ queryKey: ['dashboard-overview', user?.id] })
      showWorkbenchTab('previewApply', 'erp-guarded-update-rollback-worker-readiness')
    },
    onError: (error) => {
      const mapped = mapConnectorSetupError(error)
      captureAppError(error, {
        area: 'connector_setup',
        operation: 'requestConnectorGuardedUpdateRollbackWorkerReadiness',
        providerId: data?.provider.code,
        route: '/verikaynaklari',
      })
      toast.error(t(mapped.toastKey))
    },
  })
  const requestRollbackApplyJobMutation = useMutation({
    mutationFn: () => requestConnectorGuardedUpdateRollbackApplyJob(user!.id),
    onSuccess: () => {
      toast.success(t('erp.toast.guardedUpdateRollbackApplyJob.queued'))
      void queryClient.invalidateQueries({ queryKey: ['erp-overview', user?.id] })
      void queryClient.invalidateQueries({ queryKey: ['dashboard-overview', user?.id] })
      showWorkbenchTab('activity', 'erp-runtime-queue')
    },
    onError: (error) => {
      const mapped = mapConnectorSetupError(error)
      captureAppError(error, {
        area: 'connector_runtime',
        operation: 'requestConnectorGuardedUpdateRollbackApplyJob',
        providerId: data?.provider.code,
        route: '/verikaynaklari',
      })
      toast.error(t(mapped.toastKey))
    },
  })
  const requestCreateOnlyApplyJobMutation = useMutation({
    mutationFn: () => requestConnectorCreateOnlyApplyJob(user!.id),
    onSuccess: () => {
      toast.success(t('erp.toast.createOnlyApplyJob.queued'))
      void queryClient.invalidateQueries({ queryKey: ['erp-overview', user?.id] })
      void queryClient.invalidateQueries({ queryKey: ['dashboard-overview', user?.id] })
      showWorkbenchTab('activity', 'erp-runtime-queue')
    },
    onError: (error) => {
      const mapped = mapConnectorSetupError(error)
      captureAppError(error, {
        area: 'connector_runtime',
        operation: 'requestConnectorCreateOnlyApplyJob',
        providerId: data?.provider.code,
        route: '/verikaynaklari',
      })
      toast.error(t(mapped.toastKey))
    },
  })
  const requestGuardedUpdateApplyJobMutation = useMutation({
    mutationFn: () => requestConnectorGuardedUpdateApplyJob(user!.id),
    onSuccess: () => {
      toast.success(t('erp.toast.guardedUpdateApplyJob.queued'))
      void queryClient.invalidateQueries({ queryKey: ['erp-overview', user?.id] })
      void queryClient.invalidateQueries({ queryKey: ['dashboard-overview', user?.id] })
      showWorkbenchTab('activity', 'erp-runtime-queue')
    },
    onError: (error) => {
      const mapped = mapConnectorSetupError(error)
      captureAppError(error, {
        area: 'connector_runtime',
        operation: 'requestConnectorGuardedUpdateApplyJob',
        providerId: data?.provider.code,
        route: '/verikaynaklari',
      })
      toast.error(t(mapped.toastKey))
    },
  })
  const requestRuntimePreflightMutation = useMutation({
    mutationFn: () => requestConnectorRuntimePreflight(user!.id),
    onSuccess: () => {
      toast.success(t('erp.toast.runtimePreflight.queued'))
      void queryClient.invalidateQueries({ queryKey: ['erp-overview', user?.id] })
      void queryClient.invalidateQueries({ queryKey: ['dashboard-overview', user?.id] })
      showWorkbenchTab('activity', 'erp-runtime-queue')
    },
    onError: (error) => {
      const mapped = mapConnectorSetupError(error)
      captureAppError(error, {
        area: 'connector_runtime',
        operation: 'requestConnectorRuntimePreflight',
        providerId: data?.provider.code,
        route: '/verikaynaklari',
      })
      toast.error(t(mapped.toastKey))
    },
  })

  const data = erpResult?.data
  const hasSelectedConnector = data?.connectorState === 'connector_selected'
  const canRequestCredentialHandoff =
    data?.credentialHandoff.requestable === true && canManageConnectors
  const canRunImportPreview =
    data?.importPreview.action === 'run_dry_run_preview' && canManageConnectors
  const canRequestApplyReview = data?.applyReadiness.requestable === true && canManageConnectors
  const canRequestApplyChangeSet = data?.applyChangeSet.requestable === true && canManageConnectors
  const canRequestGuardedUpdateEvidence =
    data?.guardedUpdateEvidence.requestable === true && canManageConnectors
  const canRecordApplyApproval =
    data?.applyApprovalPolicy.requestable === true && canManageConnectors
  const canRecordRollbackApproval =
    data?.guardedUpdateRollbackApproval.requestable === true && canManageConnectors
  const canRequestRollbackWorkerReadiness =
    data?.guardedUpdateRollbackWorkerReadiness.requestable === true && canManageConnectors
  const canRequestRollbackApplyJob =
    data?.guardedUpdateRollbackWorkerReadiness.workerHandoffReady === true && canManageConnectors
  const canRequestCreateOnlyApplyJob =
    data?.applyExecutionContract.safeToExecute === true &&
    data.applyExecutionContract.executorMode === 'worker_create_only_job' &&
    canManageConnectors
  const canRequestGuardedUpdateApplyJob =
    data?.applyExecutionContract.safeToExecute === true &&
    data.applyExecutionContract.executorMode === 'worker_guarded_update_job' &&
    canManageConnectors
  const canRequestApplyExecutionJob =
    canRequestCreateOnlyApplyJob || canRequestGuardedUpdateApplyJob
  const requestApplyExecutionPending =
    requestCreateOnlyApplyJobMutation.isPending || requestGuardedUpdateApplyJobMutation.isPending
  const requestRollbackApplyPending = requestRollbackApplyJobMutation.isPending
  const runtimePreflightCredentialReady = data?.credentialBoundary.status === 'ready'
  const runtimePreflightWorkerReady =
    data?.runtimeQueue.worker.supportedJobTypes.includes('connector_runtime_preflight') === true &&
    (data.runtimeQueue.worker.status === 'idle' || data.runtimeQueue.worker.status === 'running')
  const canRequestRuntimePreflight =
    canManageConnectors && runtimePreflightCredentialReady === true && runtimePreflightWorkerReady
  const selectedProvider =
    selectedProviderId == null
      ? null
      : data?.providerOptions.find((option) => option.id === selectedProviderId)
  const selectedProviderCanStart = selectedProvider?.setupAvailable === true
  const pageTitle = t('erp.title')
  const pageSubtitle = t('erp.subtitle')
  const mappedFieldCount =
    data?.mappings.filter((mapping) => mapping.status === 'mapped').length ?? 0
  const totalFieldCount = data?.mappings.length ?? 0
  const previewReady = data?.importPreview.status === 'preview_ready'
  const reviewPrepared =
    data?.applyChangeSet.id != null || data?.applyReadiness.status === 'review_requested'
  const approvalReady =
    data?.applyExecutionContract.safeToExecute === true ||
    data?.applyApprovalPolicy.approvalRecordedAt != null ||
    data?.guardedUpdateRollbackWorkerReadiness.workerHandoffReady === true
  const currentProviderOption =
    data?.providerOptions.find((option) => option.id === data.provider.code) ?? null
  const sourceStatus: ConnectorStatus =
    data?.credentialBoundary.required === true && data.credentialBoundary.status !== 'ready'
      ? 'partial'
      : data && hasSelectedConnector
        ? 'ready'
        : 'blocked'
  const fieldsStatus: ConnectorStatus =
    totalFieldCount > 0 && mappedFieldCount === totalFieldCount
      ? 'ready'
      : mappedFieldCount > 0 || data?.namespaces.length
        ? 'partial'
        : 'blocked'
  const previewStatus: ConnectorStatus = previewReady
    ? 'ready'
    : data?.importPreview.action === 'run_dry_run_preview'
      ? 'partial'
      : 'blocked'
  const reviewStatus: ConnectorStatus = data?.applyChangeSet.id
    ? 'ready'
    : reviewPrepared || previewReady
      ? 'partial'
      : 'blocked'
  const approveStatus: ConnectorStatus = approvalReady
    ? 'ready'
    : data?.applyApprovalPolicy.requestable ||
        data?.guardedUpdateRollbackApproval.requestable ||
        data?.guardedUpdateRollbackWorkerReadiness.requestable
      ? 'partial'
      : 'blocked'
  const activityStatus: ConnectorStatus =
    (data?.runtimeQueue.summary.total ?? 0) > 0
      ? 'ready'
      : data?.runtimeQueue.worker.status === 'idle' ||
          data?.runtimeQueue.worker.status === 'running'
        ? 'partial'
        : 'blocked'
  const detailAction = (
    labelKey: string,
    tab: ErpWorkbenchTab,
    targetId: string,
    icon: LucideIcon = SearchCheck,
  ): ConnectorJourneyAction => ({
    label: t(labelKey),
    icon,
    variant: 'outline',
    onClick: () => showWorkbenchTab(tab, targetId),
  })
  const applyExecutionAction: ConnectorJourneyAction = canRequestGuardedUpdateApplyJob
    ? {
        label: requestApplyExecutionPending
          ? t('erp.applyExecutionContract.actions.enqueueGuardedUpdate.queuing')
          : t('erp.applyExecutionContract.actions.enqueueGuardedUpdate.label'),
        icon: Database,
        onClick: () => void requestGuardedUpdateApplyJobMutation.mutateAsync(),
      }
    : {
        label: requestApplyExecutionPending
          ? t('erp.applyExecutionContract.actions.enqueueCreateOnly.queuing')
          : t('erp.applyExecutionContract.actions.enqueueCreateOnly.label'),
        icon: Database,
        onClick: () => void requestCreateOnlyApplyJobMutation.mutateAsync(),
      }
  const rollbackExecutionAction: ConnectorJourneyAction = {
    label: requestRollbackApplyPending
      ? t('erp.guardedUpdateRollbackWorkerApply.queueing')
      : t('erp.guardedUpdateRollbackWorkerApply.actions.queue'),
    icon: RefreshCw,
    onClick: () => void requestRollbackApplyJobMutation.mutateAsync(),
  }
  const approvePrimaryAction: ConnectorJourneyAction = canRecordApplyApproval
    ? {
        label: recordApplyApprovalMutation.isPending
          ? t('erp.applyApprovalPolicy.recording')
          : t(data?.applyApprovalPolicy.actionLabelKey ?? 'erp.journey.actions.openDetails'),
        icon: ShieldCheck,
        onClick: () => void recordApplyApprovalMutation.mutateAsync(),
      }
    : canRequestApplyExecutionJob
      ? applyExecutionAction
      : canRecordRollbackApproval
        ? {
            label: recordRollbackApprovalMutation.isPending
              ? t('erp.guardedUpdateRollbackApproval.recording')
              : t(
                  data?.guardedUpdateRollbackApproval.actionLabelKey ??
                    'erp.journey.actions.openDetails',
                ),
            icon: ShieldCheck,
            onClick: () => void recordRollbackApprovalMutation.mutateAsync(),
          }
        : canRequestRollbackWorkerReadiness
          ? {
              label: requestRollbackWorkerReadinessMutation.isPending
                ? t('erp.guardedUpdateRollbackWorkerReadiness.generating')
                : t(
                    data?.guardedUpdateRollbackWorkerReadiness.actionLabelKey ??
                      'erp.journey.actions.openDetails',
                  ),
              icon: ClipboardCheck,
              onClick: () => void requestRollbackWorkerReadinessMutation.mutateAsync(),
            }
          : canRequestRollbackApplyJob
            ? rollbackExecutionAction
            : detailAction(
                'erp.journey.actions.openApprovalDetails',
                'previewApply',
                'erp-controlled-apply',
              )
  const journeySteps: ConnectorJourneyStep[] =
    data && hasSelectedConnector
      ? [
          {
            id: 'source',
            icon: Plug,
            status: sourceStatus,
            titleKey: 'erp.journey.steps.source.title',
            descriptionKey: 'erp.journey.steps.source.description',
            evidenceKey: 'erp.journey.steps.source.evidence',
            detailTab: canRequestCredentialHandoff ? 'credentials' : 'setup',
            detailTargetId: canRequestCredentialHandoff
              ? 'erp-credential-boundary'
              : 'erp-setup-details',
            primaryAction: canRequestCredentialHandoff
              ? {
                  label: t('erp.journey.actions.requestSecureAccess'),
                  icon: ShieldCheck,
                  onClick: () => setCredentialSheetOpen(true),
                }
              : detailAction(
                  'erp.journey.actions.openSourceDetails',
                  'setup',
                  'erp-setup-details',
                  Plug,
                ),
            metrics: [
              {
                labelKey: 'erp.journey.metrics.source',
                value: data.provider.label,
                hint: currentProviderOption
                  ? t(currentProviderOption.transferMethodKey)
                  : undefined,
              },
              {
                labelKey: 'erp.journey.metrics.access',
                value: t(data.credentialBoundary.statusLabelKey),
              },
            ],
          },
          {
            id: 'fields',
            icon: Database,
            status: fieldsStatus,
            titleKey: 'erp.journey.steps.fields.title',
            descriptionKey: 'erp.journey.steps.fields.description',
            evidenceKey: 'erp.journey.steps.fields.evidence',
            detailTab: 'fields',
            detailTargetId: 'erp-mapping-discovery',
            primaryAction: detailAction(
              'erp.journey.actions.openFields',
              'fields',
              'erp-mapping-discovery',
              Database,
            ),
            metrics: [
              {
                labelKey: 'erp.journey.metrics.fields',
                value: `${mappedFieldCount}/${totalFieldCount}`,
                hint: t('erp.journey.metrics.mappedFields'),
              },
              {
                labelKey: 'erp.journey.metrics.identities',
                value: String(data.namespaces.length),
                hint: t('erp.journey.metrics.namespaces'),
              },
            ],
          },
          {
            id: 'preview',
            icon: SearchCheck,
            status: previewStatus,
            titleKey: 'erp.journey.steps.preview.title',
            descriptionKey: 'erp.journey.steps.preview.description',
            evidenceKey: 'erp.journey.steps.preview.evidence',
            detailTab: 'previewApply',
            detailTargetId: 'erp-import-preview',
            primaryAction: canRunImportPreview
              ? {
                  label: runImportPreviewMutation.isPending
                    ? t('erp.importPreview.running')
                    : t(data.importPreview.actionLabelKey),
                  icon: SearchCheck,
                  onClick: () => void runImportPreviewMutation.mutateAsync(),
                }
              : detailAction(
                  'erp.journey.actions.openPreview',
                  'previewApply',
                  'erp-import-preview',
                  SearchCheck,
                ),
            metrics: [
              {
                labelKey: 'erp.journey.metrics.batch',
                value: data.importPreview.batch
                  ? t(`erp.importPreview.batchStatus.${data.importPreview.batch.status}`)
                  : t('erp.importPreview.values.none'),
              },
              {
                labelKey: 'erp.journey.metrics.rows',
                value: String(data.importPreview.summary.rowCount),
                hint: t('erp.importPreview.values.dryRunOnly'),
              },
            ],
          },
          {
            id: 'review',
            icon: ClipboardCheck,
            status: reviewStatus,
            titleKey: 'erp.journey.steps.review.title',
            descriptionKey: 'erp.journey.steps.review.description',
            evidenceKey: 'erp.journey.steps.review.evidence',
            detailTab: 'previewApply',
            detailTargetId: data.applyChangeSet.id ? 'erp-apply-change-set' : 'erp-apply-readiness',
            primaryAction: canRequestApplyReview
              ? {
                  label: requestApplyReviewMutation.isPending
                    ? t('erp.applyReadiness.requesting')
                    : t(data.applyReadiness.actionLabelKey),
                  icon: ClipboardCheck,
                  onClick: () => void requestApplyReviewMutation.mutateAsync(),
                }
              : canRequestApplyChangeSet
                ? {
                    label: requestApplyChangeSetMutation.isPending
                      ? t('erp.applyChangeSet.generating')
                      : t(data.applyChangeSet.actionLabelKey),
                    icon: ClipboardCheck,
                    onClick: () => void requestApplyChangeSetMutation.mutateAsync(),
                  }
                : canRequestGuardedUpdateEvidence
                  ? {
                      label: requestGuardedUpdateEvidenceMutation.isPending
                        ? t('erp.guardedUpdateEvidence.generating')
                        : t(data.guardedUpdateEvidence.actionLabelKey),
                      icon: ShieldCheck,
                      onClick: () => void requestGuardedUpdateEvidenceMutation.mutateAsync(),
                    }
                  : detailAction(
                      'erp.journey.actions.openReviewDetails',
                      'previewApply',
                      data.applyChangeSet.id ? 'erp-apply-change-set' : 'erp-apply-readiness',
                      ClipboardCheck,
                    ),
            metrics: [
              {
                labelKey: 'erp.journey.metrics.changes',
                value: `${data.applyReadiness.summary.createCount}/${data.applyReadiness.summary.updateCount}/${data.applyReadiness.summary.skipCount}`,
                hint: t('erp.importPreview.values.createUpdateSkip'),
              },
              {
                labelKey: 'erp.journey.metrics.blockers',
                value: String(data.applyReadiness.summary.blockerCount),
              },
            ],
          },
          {
            id: 'approve',
            icon: ShieldCheck,
            status: approveStatus,
            titleKey: 'erp.journey.steps.approve.title',
            descriptionKey: 'erp.journey.steps.approve.description',
            evidenceKey: 'erp.journey.steps.approve.evidence',
            detailTab: 'previewApply',
            detailTargetId: 'erp-controlled-apply',
            primaryAction: approvePrimaryAction,
            metrics: [
              {
                labelKey: 'erp.journey.metrics.executor',
                value: t(
                  data.applyExecutionContract.executorMode === 'worker_create_only_job'
                    ? 'erp.applyExecutionContract.values.workerCreateOnlyJob'
                    : data.applyExecutionContract.executorMode === 'worker_guarded_update_job'
                      ? 'erp.applyExecutionContract.values.workerGuardedUpdateJob'
                      : 'erp.applyExecutionContract.values.futureJob',
                ),
              },
              {
                labelKey: 'erp.journey.metrics.queue',
                value: data.applyExecutionContract.safeToExecute
                  ? t('erp.applyExecutionContract.values.enabled')
                  : t('erp.applyExecutionContract.values.closed'),
              },
            ],
          },
          {
            id: 'activity',
            icon: RefreshCw,
            status: activityStatus,
            titleKey: 'erp.journey.steps.activity.title',
            descriptionKey: 'erp.journey.steps.activity.description',
            evidenceKey: 'erp.journey.steps.activity.evidence',
            detailTab: 'activity',
            detailTargetId: 'erp-runtime-queue',
            primaryAction: canRequestRuntimePreflight
              ? {
                  label: requestRuntimePreflightMutation.isPending
                    ? t('erp.runtimePreflight.actions.requesting')
                    : t('erp.runtimePreflight.actions.request'),
                  icon: SearchCheck,
                  onClick: () => void requestRuntimePreflightMutation.mutateAsync(),
                }
              : detailAction(
                  'erp.journey.actions.openActivityDetails',
                  'activity',
                  'erp-runtime-queue',
                  RefreshCw,
                ),
            metrics: [
              {
                labelKey: 'erp.journey.metrics.jobs',
                value: String(data.runtimeQueue.summary.total),
                hint: t('erp.runtimeQueue.values.queueSummary', {
                  queued: data.runtimeQueue.summary.queued,
                  running: data.runtimeQueue.summary.running,
                  retrying: data.runtimeQueue.summary.retrying,
                }),
              },
              {
                labelKey: 'erp.journey.metrics.worker',
                value: t(data.runtimeQueue.worker.statusLabelKey),
              },
            ],
          },
        ]
      : []
  const defaultJourneyStep =
    journeySteps.find((step) => step.status !== 'ready') ?? journeySteps[journeySteps.length - 1]
  const activeJourneyStep =
    journeySteps.find((step) => step.id === selectedJourneyStepId) ?? defaultJourneyStep
  const dataSources = data?.dataSources ?? []
  const currentDataSource =
    dataSources.find((source) => source.connectionId === data?.provider.id) ??
    dataSources[0] ??
    null
  const selectedDataSource =
    dataSources.find((source) => source.id === selectedDataSourceId) ?? currentDataSource
  const fileImportSource = dataSources.find((source) => source.id === fileImportSourceId) ?? null
  const activeFileImportConnectionId = fileImportConnectionId ?? fileImportSource?.connectionId
  const fileImportSourceScopes = new Set(fileImportSource?.scope ?? [])
  const fileImportScopes = FILE_IMPORT_SCOPES.filter(
    (scope) => fileImportSourceScopes.size === 0 || fileImportSourceScopes.has(scope.id),
  )
  const fileImportPackageStaged = fileImportStagedBatchIds.length > 0
  const fileImportErrors =
    fileImportPackageResult?.issues.filter((issue) => issue.level === 'error') ?? []
  const fileImportWarnings =
    fileImportPackageResult?.issues.filter((issue) => issue.level === 'warning') ?? []
  const fileImportPrimaryDisabled =
    !canManageConnectors ||
    fileImportParsing ||
    prepareFileImportSourceMutation.isPending ||
    ingestFileImportMutation.isPending ||
    runImportPreviewMutation.isPending ||
    (Boolean(activeFileImportConnectionId) &&
      (!fileImportPackageResult || (!fileImportPackageResult.ok && !fileImportPackageStaged)))
  const fileImportPrimaryLabel = !activeFileImportConnectionId
    ? prepareFileImportSourceMutation.isPending
      ? t('erp.fileImport.actions.preparingSource')
      : t('erp.fileImport.actions.prepareSource')
    : fileImportPackageStaged
      ? runImportPreviewMutation.isPending
        ? t('erp.fileImport.actions.runningPreview')
        : t('erp.fileImport.actions.runPreview')
      : fileImportParsing
        ? t('erp.fileImport.actions.parsing')
        : ingestFileImportMutation.isPending
          ? t('erp.fileImport.actions.staging')
          : !fileImportPackageResult
            ? t('erp.fileImport.actions.waitingFile')
            : fileImportPackageResult.ok
              ? t('erp.fileImport.actions.stage')
              : t('erp.fileImport.actions.fixFile')
  const firstStartableProvider =
    data?.providerOptions.find(
      (option) =>
        option.setupAvailable &&
        !dataSources.some(
          (source) => source.sourceKind === 'connection' && source.providerId === option.id,
        ),
    ) ??
    data?.providerOptions.find((option) => option.setupAvailable) ??
    data?.providerOptions[0] ??
    null

  const openProviderDraft = (providerId: ConnectorProviderOption['id']) => {
    setSelectedProviderId(providerId)
    setDraftSheetOpen(true)
  }

  const openNewSourceDraft = () => {
    if (!firstStartableProvider) return
    openProviderDraft(firstStartableProvider.id)
  }

  const openFileImportWizard = (source: DataSourceSummary) => {
    const sourceScopeIds = new Set(source.scope)
    const initialScope =
      FILE_IMPORT_SCOPES.find((scope) => sourceScopeIds.size === 0 || sourceScopeIds.has(scope.id))
        ?.id ?? 'employees'
    setSelectedDataSourceId(source.id)
    setFileImportSourceId(source.id)
    setFileImportConnectionId(source.connectionId)
    setFileImportScope(initialScope)
    setFileImportPackageResult(null)
    setFileImportStagedBatchIds([])
    setFileImportSheetOpen(true)
  }

  const handleFileImportScopeChange = (scope: FileImportScopeId) => {
    setFileImportScope(scope)
    setFileImportPackageResult(null)
    setFileImportStagedBatchIds([])
  }

  const handleFileImportFileChange = async (event: ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(event.currentTarget.files ?? [])
    if (files.length === 0) return
    setFileImportParsing(true)
    setFileImportPackageResult(null)
    setFileImportStagedBatchIds([])
    try {
      const parsed = await parseFileImportPackage(
        files,
        fileImportScopes.map((scope) => scope.id),
      )
      setFileImportPackageResult(parsed)
      if (parsed.ok) {
        toast.success(
          t('erp.fileImport.toast.parsed', {
            count: parsed.rowCount,
            files: parsed.fileCount,
          }),
        )
      } else {
        toast.error(t('erp.fileImport.toast.parseBlocked'))
      }
    } catch (error) {
      captureAppError(error, {
        area: 'connector_setup',
        operation: 'parseFileImportPackage',
        providerId: 'csv_import',
        route: '/verikaynaklari',
      })
      toast.error(t('erp.fileImport.toast.parseFailed'))
    } finally {
      event.currentTarget.value = ''
      setFileImportParsing(false)
    }
  }

  const handleFileImportPrimaryAction = () => {
    if (!activeFileImportConnectionId) {
      void prepareFileImportSourceMutation.mutateAsync()
      return
    }
    if (fileImportPackageStaged) {
      void runImportPreviewMutation
        .mutateAsync()
        .then(() => setFileImportSheetOpen(false))
        .catch((error) => {
          console.warn('File import preview could not be started from the import sheet.', error)
        })
      return
    }
    if (!fileImportPackageResult?.ok) return
    void ingestFileImportMutation.mutateAsync({
      packageResult: fileImportPackageResult,
      connectionId: activeFileImportConnectionId,
    })
  }

  const handleDataSourcePrimaryAction = (source: DataSourceSummary) => {
    if (source.primaryAction === 'none') return
    if (source.providerId === 'csv_import' || source.canUploadFile) {
      openFileImportWizard(source)
      return
    }
    if (source.sourceKind === 'catalog') {
      openProviderDraft(source.providerId)
      return
    }
    if (source.connectionId === data?.provider.id && activeJourneyStep) {
      activeJourneyStep.primaryAction.onClick()
      return
    }
    setSelectedDataSourceId(source.id)
  }

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <p className="text-xs font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
        {t('erp.eyebrow')}
      </p>
      <PageHeader
        className="mt-1"
        title={pageTitle}
        subtitle={pageSubtitle}
        badge={
          <StatusPill tone={data ? readinessTone(data.readiness.status) : 'neutral'}>
            {data ? t(data.provider.statusLabelKey) : t('erp.badge')}
          </StatusPill>
        }
      />

      <DemoSourcePill
        visible={erpResult?.source === 'demo'}
        fallbackReason={erpResult?.fallbackReason}
      />

      {data ? (
        <DataSourceManagerSection
          dataSources={dataSources}
          selectedDataSource={selectedDataSource}
          currentConnectionId={data.provider.id}
          activeJourneyStep={activeJourneyStep}
          canManageConnectors={canManageConnectors}
          canAddSource={Boolean(firstStartableProvider)}
          onAddSource={openNewSourceDraft}
          onSelectSource={setSelectedDataSourceId}
          onPrimaryAction={handleDataSourcePrimaryAction}
          onOpenTechnicalDetails={showWorkbenchTab}
        />
      ) : null}

      {isLoading ? (
        <div className="mt-6 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
          <Skeleton className="h-28 rounded-xl" />
          <Skeleton className="h-28 rounded-xl" />
          <Skeleton className="h-28 rounded-xl" />
          <Skeleton className="h-28 rounded-xl" />
        </div>
      ) : null}

      {data && selectedProvider ? (
        <ProviderDraftSheet
          open={draftSheetOpen}
          onOpenChange={setDraftSheetOpen}
          onClose={() => setDraftSheetOpen(false)}
          provider={selectedProvider}
          canManage={canManageConnectors}
          canStart={selectedProviderCanStart}
          isPending={startSetupMutation.isPending}
          onStart={() => {
            if (selectedProviderCanStart) {
              void startSetupMutation.mutateAsync(selectedProvider.id)
            }
          }}
        />
      ) : null}

      {data ? (
        <FileImportSheet
          open={fileImportSheetOpen}
          onOpenChange={setFileImportSheetOpen}
          onClose={() => setFileImportSheetOpen(false)}
          sourceLabel={
            fileImportSource
              ? dataSourceDisplayName(fileImportSource, t)
              : t('erp.providerOptions.csv_import.label')
          }
          sourceReady={Boolean(activeFileImportConnectionId)}
          scopes={fileImportScopes}
          selectedScope={fileImportScope}
          onScopeChange={handleFileImportScopeChange}
          packageResult={fileImportPackageResult}
          errorCount={fileImportErrors.length}
          warningCount={fileImportWarnings.length}
          staged={fileImportPackageStaged}
          stagedBatchCount={fileImportStagedBatchIds.length}
          parsing={fileImportParsing}
          primaryDisabled={fileImportPrimaryDisabled}
          primaryLabel={fileImportPrimaryLabel}
          onPrimaryAction={handleFileImportPrimaryAction}
          onFileChange={handleFileImportFileChange}
          onDownloadTemplate={downloadFileImportTemplate}
          onDownloadAllTemplates={downloadAllFileImportTemplates}
        />
      ) : null}

      {data && hasSelectedConnector ? (
        <DataSourceTechnicalDetailsSheet
          data={data}
          technicalDetailsOpen={technicalDetailsOpen}
          setTechnicalDetailsOpen={setTechnicalDetailsOpen}
          activeWorkbenchTab={activeWorkbenchTab}
          setActiveWorkbenchTab={setActiveWorkbenchTab}
          showWorkbenchTab={showWorkbenchTab}
          credentialSheetOpen={credentialSheetOpen}
          setCredentialSheetOpen={setCredentialSheetOpen}
          permissions={{
            canManageConnectors,
            canRunImportPreview,
            canRequestApplyReview,
            canRequestApplyChangeSet,
            canRequestGuardedUpdateEvidence,
            canRecordRollbackApproval,
            canRequestRollbackWorkerReadiness,
            canRequestRollbackApplyJob,
            requestRollbackApplyPending,
            canRecordApplyApproval,
            canRequestApplyExecutionJob,
            requestApplyExecutionPending,
            canRequestGuardedUpdateApplyJob,
            canRequestCredentialHandoff,
            canRequestRuntimePreflight,
          }}
          mutations={{
            runPreflight: runPreflightMutation,
            runImportPreview: runImportPreviewMutation,
            requestApplyReview: requestApplyReviewMutation,
            requestApplyChangeSet: requestApplyChangeSetMutation,
            requestGuardedUpdateEvidence: requestGuardedUpdateEvidenceMutation,
            recordApplyApproval: recordApplyApprovalMutation,
            recordRollbackApproval: recordRollbackApprovalMutation,
            requestRollbackWorkerReadiness: requestRollbackWorkerReadinessMutation,
            requestRollbackApplyJob: requestRollbackApplyJobMutation,
            requestCreateOnlyApplyJob: requestCreateOnlyApplyJobMutation,
            requestGuardedUpdateApplyJob: requestGuardedUpdateApplyJobMutation,
            requestCredentialHandoff: requestCredentialHandoffMutation,
            requestRuntimePreflight: requestRuntimePreflightMutation,
          }}
        />
      ) : null}
    </div>
  )
}
