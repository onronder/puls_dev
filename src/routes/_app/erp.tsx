import { createFileRoute } from '@tanstack/react-router'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  AlertTriangle,
  Braces,
  Check,
  CheckCircle2,
  ChevronRight,
  Circle,
  ClipboardCheck,
  Database,
  FileSpreadsheet,
  Globe2,
  Info,
  KeyRound,
  Link2,
  Plug,
  RefreshCw,
  SearchCheck,
  ShieldCheck,
} from 'lucide-react'
import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { z } from 'zod'

import { SetupRouteGuard } from '#/components/auth/SetupRouteGuard'
import { DemoSourcePill } from '#/components/puls/DemoSourcePill'
import { MetricCard } from '#/components/puls/MetricCard'
import { PageHeader } from '#/components/puls/PageHeader'
import { SectionHeader } from '#/components/puls/SectionHeader'
import { SheetShell } from '#/components/puls/SheetShell'
import { StatusPill, type StatusTone } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { Progress } from '#/components/ui/progress'
import { Skeleton } from '#/components/ui/skeleton'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '#/components/ui/tabs'
import { useAuth } from '#/lib/auth'
import {
  fetchErpOverviewWithMeta,
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
  type ErpOverview,
} from '#/lib/data'
import { captureAppError } from '#/lib/observability/sentry'
import { canShowSetupHub } from '#/lib/setup-access'
import { cn } from '#/lib/utils'

const ERP_WORKBENCH_TABS = [
  'setup',
  'fields',
  'check',
  'credentials',
  'previewApply',
  'activity',
] as const

type ErpWorkbenchTab = (typeof ERP_WORKBENCH_TABS)[number]

const erpSearchSchema = z.object({
  tab: z.enum(ERP_WORKBENCH_TABS).optional(),
  focus: z
    .string()
    .regex(/^erp-[a-z0-9-]+$/)
    .optional(),
})

export const Route = createFileRoute('/_app/erp')({
  head: () => ({
    meta: [{ title: 'Data Connections — PULS' }],
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

type ConnectorStatus = ErpOverview['readiness']['status']
type ConnectorActivityEvent = ErpOverview['activityTimeline'][number]
type ConnectorSyncLevel = ConnectorActivityEvent['level']
type ConnectorProviderOption = ErpOverview['providerOptions'][number]
type ConnectorDomainOwnership = ErpOverview['domainOwnership'][number]

function readinessTone(status: ConnectorStatus): StatusTone {
  if (status === 'ready') return 'success'
  if (status === 'partial') return 'warning'
  return 'neutral'
}

function syncLogTone(level: ConnectorSyncLevel): string {
  switch (level) {
    case 'success':
      return 'bg-[var(--color-success-soft)] text-[var(--color-success)]'
    case 'warning':
      return 'bg-[var(--color-warning-soft)] text-[var(--color-warning)]'
    case 'error':
      return 'bg-[var(--color-danger-soft)] text-[var(--color-danger)]'
    default:
      return 'bg-[var(--color-primary-soft)] text-[var(--color-info)]'
  }
}

function runtimeJobStatusTone(level: ConnectorSyncLevel): StatusTone {
  if (level === 'success') return 'success'
  if (level === 'error') return 'danger'
  if (level === 'warning') return 'warning'
  return 'info'
}

function applyChangeSetRiskTone(
  riskClass: ErpOverview['applyChangeSet']['sampleItems'][number]['riskClass'],
  blocked: boolean,
): StatusTone {
  if (riskClass === 'create_only') return 'success'
  if (riskClass === 'no_change_skip') return 'neutral'
  if (riskClass === 'destructive_equivalent' || riskClass === 'stale_preview') return 'danger'
  if (blocked) return 'warning'
  return 'info'
}

function guardedUpdateFieldTone(
  fieldClass: ErpOverview['guardedUpdateEvidence']['sampleFieldDiffs'][number]['fieldClass'],
  staleBlocked: boolean,
): StatusTone {
  if (staleBlocked || fieldClass === 'destructive_equivalent') return 'danger'
  if (fieldClass === 'sensitive') return 'warning'
  return 'success'
}

function domainOwnershipTone(status: ConnectorDomainOwnership['status']): StatusTone {
  if (status === 'owned_by_current') return 'success'
  if (status === 'owned_by_other') return 'warning'
  return 'neutral'
}

function SyncLogIcon({ level }: { level: ConnectorSyncLevel }) {
  const className = 'h-4 w-4'
  if (level === 'success') return <CheckCircle2 className={className} aria-hidden />
  if (level === 'warning') return <AlertTriangle className={className} aria-hidden />
  if (level === 'error') return <AlertTriangle className={className} aria-hidden />
  return <Info className={className} aria-hidden />
}

function formatActivityDetailValue(
  value: ConnectorActivityEvent['detailItems'][number]['value'],
  translate: (key: string) => string,
  labelKey?: string,
) {
  if (typeof value === 'boolean') {
    return translate(value ? 'erp.activityTimeline.values.yes' : 'erp.activityTimeline.values.no')
  }
  if (labelKey === 'erp.activityTimeline.details.authMode') {
    return translate(`erp.authModes.${value}`)
  }
  if (labelKey === 'erp.activityTimeline.details.credentialState') {
    return translate(`erp.credentialBoundary.states.${value}`)
  }
  return String(value)
}

function formatDateTime(value: string | null, locale: string, fallback: string): string {
  if (!value) return fallback
  try {
    return new Intl.DateTimeFormat(locale, {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    }).format(new Date(value))
  } catch {
    return fallback
  }
}

function ProviderOptionIcon({ id }: { id: ConnectorProviderOption['id'] }) {
  const className = 'h-5 w-5'
  if (id === 'csv_import') return <FileSpreadsheet className={className} aria-hidden />
  if (id === 'custom_api') return <Braces className={className} aria-hidden />
  if (id === 'logo') return <Globe2 className={className} aria-hidden />
  return <Plug className={className} aria-hidden />
}

function SetupStepIcon({ status }: { status: ConnectorStatus }) {
  if (status === 'ready') return <Check className="h-4 w-4" aria-hidden />
  if (status === 'partial') return <Circle className="h-3 w-3 fill-current" aria-hidden />
  return <Circle className="h-3 w-3" aria-hidden />
}

function ErpPage() {
  const routeSearch = Route.useSearch()
  const { t, i18n } = useTranslation()
  const { user, personaRole, activePersona } = useAuth()
  const queryClient = useQueryClient()
  const [selectedProviderId, setSelectedProviderId] = useState<
    ConnectorProviderOption['id'] | null
  >(null)
  const [draftSheetOpen, setDraftSheetOpen] = useState(false)
  const [credentialSheetOpen, setCredentialSheetOpen] = useState(false)
  const [activeWorkbenchTab, setActiveWorkbenchTab] = useState<ErpWorkbenchTab>('setup')
  const showWorkbenchTab = (tab: ErpWorkbenchTab, targetId?: string) => {
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
        route: '/erp',
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
        route: '/erp',
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
        route: '/erp',
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
        route: '/erp',
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
        route: '/erp',
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
        route: '/erp',
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
        route: '/erp',
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
        route: '/erp',
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
        route: '/erp',
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
        route: '/erp',
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
        route: '/erp',
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
        route: '/erp',
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
        route: '/erp',
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
        route: '/erp',
      })
      toast.error(t(mapped.toastKey))
    },
  })

  const data = erpResult?.data
  const hasSelectedConnector = data?.connectorState === 'connector_selected'
  const hasNoConnector = data?.connectorState === 'no_connector'
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
  const pageTitle = data && hasNoConnector ? t('erp.noConnector.title') : t('erp.title')
  const pageSubtitle = data && hasNoConnector ? t('erp.noConnector.subtitle') : t('erp.subtitle')
  const accessNextAction = data?.accessReadiness.nextActionKey
  const accessAction =
    accessNextAction === 'erp.accessReadiness.nextActions.request_secure_reference' &&
    canRequestCredentialHandoff
      ? {
          label: t('erp.accessReadiness.actions.requestSecureReference'),
          icon: ShieldCheck,
          onClick: () => setCredentialSheetOpen(true),
        }
      : accessNextAction === 'erp.accessReadiness.nextActions.complete_metadata'
        ? {
            label: t('erp.accessReadiness.actions.reviewMetadata'),
            icon: Database,
            onClick: () => showWorkbenchTab('fields', 'erp-mapping-discovery'),
          }
        : accessNextAction === 'erp.accessReadiness.nextActions.prepare_preview' &&
            canRunImportPreview
          ? {
              label: t('erp.accessReadiness.actions.openPreview'),
              icon: SearchCheck,
              onClick: () => showWorkbenchTab('previewApply', 'erp-import-preview'),
            }
          : null
  const AccessActionIcon = accessAction?.icon

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

      <DemoSourcePill visible={erpResult?.source === 'demo'} />

      {data ? (
        <section className="mt-6">
          <SectionHeader
            title={
              data && hasNoConnector ? t('erp.noConnector.stepsTitle') : t('erp.workbench.title')
            }
            description={
              data && hasNoConnector
                ? t('erp.noConnector.stepsDescription')
                : t('erp.workbench.description')
            }
          />
          <ol className="grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
            {data.setupSteps.map((step, index) => (
              <li
                key={step.id}
                className="min-h-[148px] rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-3"
              >
                <div className="flex items-center justify-between gap-3">
                  <span
                    className={cn(
                      'flex h-8 w-8 shrink-0 items-center justify-center rounded-full border text-xs font-semibold',
                      step.status === 'ready'
                        ? 'border-[color-mix(in_srgb,var(--color-success)_30%,transparent)] bg-[var(--color-success-soft)] text-[var(--color-success)]'
                        : step.status === 'partial'
                          ? 'border-[color-mix(in_srgb,var(--color-warning)_30%,transparent)] bg-[var(--color-warning-soft)] text-[var(--color-warning)]'
                          : 'border-[var(--color-border)] bg-[var(--color-bg-surface)] text-[var(--color-text-muted)]',
                    )}
                  >
                    <SetupStepIcon status={step.status} />
                  </span>
                  <span className="font-mono text-xs text-[var(--color-text-muted)]">
                    {String(index + 1).padStart(2, '0')}
                  </span>
                </div>
                <p className="mt-3 text-sm font-semibold text-[var(--color-text-primary)]">
                  {t(step.labelKey)}
                </p>
                <p className="mt-1 text-xs leading-relaxed text-[var(--color-text-muted)]">
                  {t(step.descriptionKey)}
                </p>
              </li>
            ))}
          </ol>
        </section>
      ) : null}

      {isLoading ? (
        <div className="mt-6 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
          <Skeleton className="h-28 rounded-xl" />
          <Skeleton className="h-28 rounded-xl" />
          <Skeleton className="h-28 rounded-xl" />
          <Skeleton className="h-28 rounded-xl" />
        </div>
      ) : data && hasSelectedConnector ? (
        <div className="mt-6 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
          <MetricCard
            compact
            label={t('erp.metrics.provider')}
            value={data.provider.label}
            hint={t(data.provider.statusLabelKey)}
            icon={Plug}
          />
          <div>
            <MetricCard
              compact
              label={t(data.setupSummary.labelKey)}
              value={t(data.setupSummary.valueKey)}
              hint={t(data.setupSummary.hintKey)}
            />
            {data.setupSummary.progress === null ? null : (
              <Progress className="mt-2 h-1.5" value={data.setupSummary.progress} />
            )}
          </div>
          <MetricCard
            compact
            label={t('erp.metrics.fieldMapping')}
            value={`${data.status.mappedFields} / ${data.status.totalFields}`}
            hint={t('erp.metrics.fieldMappingHint')}
          />
          <MetricCard
            compact
            label={t('erp.metrics.namespaces')}
            value={`${data.namespaces.length}`}
            hint={t('erp.metrics.namespacesHint')}
            icon={Database}
          />
        </div>
      ) : null}

      {data && hasSelectedConnector ? (
        <section id="erp-access-readiness" className="mt-8 scroll-mt-6">
          <SectionHeader
            title={t('erp.accessReadiness.title')}
            description={t('erp.accessReadiness.description')}
          />
          <div className="grid gap-4 rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4 lg:grid-cols-[0.9fr_1.1fr]">
            <div className="min-w-0">
              <div className="flex flex-wrap items-center gap-2">
                <span className="flex h-10 w-10 items-center justify-center rounded-lg bg-[var(--color-primary-soft)] text-[var(--color-primary)]">
                  <ClipboardCheck className="h-5 w-5" aria-hidden />
                </span>
                <StatusPill tone={readinessTone(data.accessReadiness.status)}>
                  {t(`erp.readinessStatus.${data.accessReadiness.status}`)}
                </StatusPill>
              </div>
              <h2 className="mt-4 text-xl font-semibold text-[var(--color-text-primary)]">
                {t(data.accessReadiness.titleKey)}
              </h2>
              <p className="mt-2 text-sm leading-relaxed text-[var(--color-text-muted)]">
                {t(data.accessReadiness.summaryKey)}
              </p>
              <div className="mt-4 rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-3">
                <div className="flex items-center justify-between gap-3">
                  <span className="text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                    {t('erp.accessReadiness.score')}
                  </span>
                  <span className="font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                    {data.accessReadiness.score}%
                  </span>
                </div>
                <Progress className="mt-2 h-1.5" value={data.accessReadiness.score} />
              </div>
              <div className="mt-4 space-y-2 text-xs leading-relaxed text-[var(--color-text-muted)]">
                <p>{t(data.accessReadiness.nextActionKey)}</p>
                <p>{t('erp.accessReadiness.boundaryNote')}</p>
              </div>
              {accessAction ? (
                <Button
                  type="button"
                  className="touch-target mt-4 w-full sm:w-auto"
                  onClick={accessAction.onClick}
                >
                  {AccessActionIcon ? <AccessActionIcon className="h-4 w-4" /> : null}
                  {accessAction.label}
                </Button>
              ) : null}
            </div>
            <ul className="grid gap-2 sm:grid-cols-2">
              {data.accessReadiness.requirements.map((requirement) => (
                <li
                  key={requirement.id}
                  className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-3"
                >
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                        {t(requirement.labelKey)}
                      </p>
                      <p className="mt-1 text-xs leading-relaxed text-[var(--color-text-muted)]">
                        {t(requirement.descriptionKey)}
                      </p>
                    </div>
                    <StatusPill tone={readinessTone(requirement.status)}>
                      {t(`erp.readinessStatus.${requirement.status}`)}
                    </StatusPill>
                  </div>
                  <p className="mt-3 text-xs font-medium text-[var(--color-text-secondary)]">
                    {t(requirement.valueKey)}
                  </p>
                </li>
              ))}
            </ul>
          </div>
        </section>
      ) : null}

      {data && hasNoConnector ? (
        <section className="mt-8">
          <SectionHeader
            title={t('erp.noConnector.sourceStepTitle')}
            description={t('erp.noConnector.sourceStepDescription')}
          />
          <div className="grid gap-4 lg:grid-cols-[1.15fr_0.85fr]">
            <div className="grid gap-3 md:grid-cols-2">
              {data.providerOptions.map((option) => {
                const isSelected = selectedProvider?.id === option.id

                return (
                  <button
                    key={option.id}
                    type="button"
                    aria-pressed={isSelected}
                    onClick={() => {
                      setSelectedProviderId(option.id)
                      setDraftSheetOpen(false)
                    }}
                    className={cn(
                      'touch-target rounded-xl border bg-[var(--color-bg-card)] p-4 text-left transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--color-primary)]',
                      isSelected
                        ? 'border-[color-mix(in_srgb,var(--color-primary)_55%,transparent)] shadow-[0_0_0_1px_color-mix(in_srgb,var(--color-primary)_30%,transparent)]'
                        : 'border-[var(--color-border)] hover:border-[color-mix(in_srgb,var(--color-primary)_28%,transparent)] hover:bg-[var(--color-bg-elevated)]',
                    )}
                  >
                    <div className="flex items-start gap-3">
                      <span
                        className={cn(
                          'flex h-10 w-10 shrink-0 items-center justify-center rounded-lg',
                          isSelected
                            ? 'bg-[var(--color-primary-soft)] text-[var(--color-primary)]'
                            : 'bg-[var(--color-bg-elevated)] text-[var(--color-text-secondary)]',
                        )}
                      >
                        <ProviderOptionIcon id={option.id} />
                      </span>
                      <div className="min-w-0">
                        <div className="flex items-center gap-2">
                          <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                            {t(option.labelKey)}
                          </p>
                          {isSelected ? (
                            <CheckCircle2
                              className="h-4 w-4 text-[var(--color-success)]"
                              aria-hidden
                            />
                          ) : null}
                        </div>
                        <p className="mt-1 text-xs leading-relaxed text-[var(--color-text-muted)]">
                          {t(option.descriptionKey)}
                        </p>
                        <p className="mt-3 text-xs font-medium text-[var(--color-text-secondary)]">
                          {t(option.readinessLabelKey)}
                        </p>
                        <dl className="mt-3 grid gap-2 text-xs sm:grid-cols-2">
                          <div className="min-w-0">
                            <dt className="text-[var(--color-text-muted)]">
                              {t('erp.providerCatalog.labels.category')}
                            </dt>
                            <dd className="truncate font-medium text-[var(--color-text-primary)]">
                              {t(option.categoryKey)}
                            </dd>
                          </div>
                          <div className="min-w-0">
                            <dt className="text-[var(--color-text-muted)]">
                              {t('erp.providerCatalog.labels.method')}
                            </dt>
                            <dd className="truncate font-medium text-[var(--color-text-primary)]">
                              {t(option.transferMethodKey)}
                            </dd>
                          </div>
                        </dl>
                      </div>
                    </div>
                    <div className="mt-4 flex items-center justify-between gap-3">
                      <StatusPill tone={readinessTone(option.status)}>
                        {t(`erp.readinessStatus.${option.status}`)}
                      </StatusPill>
                      <ChevronRight
                        className="h-4 w-4 text-[var(--color-text-muted)]"
                        aria-hidden
                      />
                    </div>
                  </button>
                )
              })}
            </div>

            {selectedProvider ? (
              <aside className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <p className="text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                      {t('erp.providerPreview.eyebrow')}
                    </p>
                    <h2 className="mt-2 text-lg font-semibold text-[var(--color-text-primary)]">
                      {t(selectedProvider.labelKey)}
                    </h2>
                    <p className="mt-1 text-sm leading-relaxed text-[var(--color-text-muted)]">
                      {t('erp.providerPreview.description')}
                    </p>
                  </div>
                  <StatusPill tone={readinessTone(selectedProvider.status)}>
                    {t(`erp.readinessStatus.${selectedProvider.status}`)}
                  </StatusPill>
                </div>

                <div className="mt-4 space-y-3">
                  <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                    {t('erp.providerPreview.requirements')}
                  </p>
                  <ul className="divide-y divide-[var(--color-border)] border-y border-[var(--color-border)]">
                    <li className="py-3">
                      <dl className="grid gap-3 sm:grid-cols-2">
                        <div>
                          <dt className="text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                            {t('erp.providerCatalog.labels.method')}
                          </dt>
                          <dd className="mt-1 text-sm text-[var(--color-text-primary)]">
                            {t(selectedProvider.transferMethodKey)}
                          </dd>
                        </div>
                        <div>
                          <dt className="text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                            {t('erp.providerCatalog.labels.availability')}
                          </dt>
                          <dd className="mt-1 text-sm text-[var(--color-text-primary)]">
                            {t(selectedProvider.availabilityKey)}
                          </dd>
                        </div>
                      </dl>
                      <p className="mt-3 text-xs leading-relaxed text-[var(--color-text-secondary)]">
                        {t(selectedProvider.recommendedUseKey)}
                      </p>
                    </li>
                    {selectedProvider.requirements.map((requirement) => (
                      <li key={requirement.id} className="py-3">
                        <div className="flex items-start justify-between gap-3">
                          <div className="min-w-0">
                            <p className="text-sm font-medium text-[var(--color-text-primary)]">
                              {t(requirement.labelKey)}
                            </p>
                            <p className="mt-1 text-xs leading-relaxed text-[var(--color-text-muted)]">
                              {t(requirement.descriptionKey)}
                            </p>
                          </div>
                          <StatusPill tone={readinessTone(requirement.status)}>
                            {t(`erp.readinessStatus.${requirement.status}`)}
                          </StatusPill>
                        </div>
                      </li>
                    ))}
                  </ul>
                </div>
              </aside>
            ) : (
              <aside className="rounded-xl border border-dashed border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
                <div className="flex h-full min-h-[240px] flex-col justify-center">
                  <span className="flex h-11 w-11 items-center justify-center rounded-lg bg-[var(--color-bg-elevated)] text-[var(--color-text-secondary)]">
                    <Plug className="h-5 w-5" aria-hidden />
                  </span>
                  <p className="mt-4 text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                    {t('erp.providerPreview.eyebrow')}
                  </p>
                  <h2 className="mt-2 text-lg font-semibold text-[var(--color-text-primary)]">
                    {t('erp.providerPreview.emptyTitle')}
                  </h2>
                  <p className="mt-2 text-sm leading-relaxed text-[var(--color-text-muted)]">
                    {t('erp.providerPreview.emptyDescription')}
                  </p>
                </div>
              </aside>
            )}
          </div>

          <div className="mt-4 flex flex-col gap-2 sm:flex-row">
            <Button
              type="button"
              variant="outline"
              className="touch-target w-full sm:w-auto"
              disabled={!selectedProvider}
              onClick={() => {
                if (selectedProvider) setDraftSheetOpen(true)
              }}
            >
              <Plug className="h-4 w-4" />
              {selectedProvider
                ? t('erp.onboarding.reviewDraft')
                : t('erp.onboarding.selectProvider')}
            </Button>
            <Button
              type="button"
              variant="outline"
              className="touch-target w-full sm:w-auto"
              disabled
            >
              <Link2 className="h-4 w-4" />
              {t('erp.onboarding.importMapping')}
            </Button>
          </div>
          <p className="mt-3 text-xs leading-relaxed text-[var(--color-text-muted)]">
            {t('erp.onboarding.guardrail')}
          </p>
          {!canManageConnectors ? (
            <p className="mt-2 rounded-lg border border-[color-mix(in_srgb,var(--color-warning)_28%,transparent)] bg-[var(--color-warning-soft)] px-3 py-2 text-xs leading-relaxed text-[var(--color-text-secondary)]">
              {t('erp.onboarding.adminRequired')}
            </p>
          ) : null}

          {selectedProvider ? (
            <SheetShell
              open={draftSheetOpen}
              onOpenChange={setDraftSheetOpen}
              title={t('erp.draftSheet.title', { provider: t(selectedProvider.labelKey) })}
              description={t('erp.draftSheet.description')}
              footer={
                <div className="flex w-full flex-col gap-2 sm:flex-row sm:justify-end">
                  <Button
                    type="button"
                    variant="outline"
                    className="touch-target w-full sm:w-auto"
                    onClick={() => setDraftSheetOpen(false)}
                  >
                    {t('erp.draftSheet.close')}
                  </Button>
                  <Button
                    type="button"
                    className="touch-target w-full sm:w-auto"
                    disabled={
                      !canManageConnectors ||
                      !selectedProviderCanStart ||
                      startSetupMutation.isPending
                    }
                    onClick={() => {
                      if (selectedProviderCanStart) {
                        void startSetupMutation.mutateAsync(selectedProvider.id)
                      }
                    }}
                  >
                    {startSetupMutation.isPending
                      ? t('erp.draftSheet.creating')
                      : !canManageConnectors
                        ? t('erp.draftSheet.adminRequiredAction')
                        : selectedProviderCanStart
                          ? t('erp.draftSheet.startSetup')
                          : t('erp.draftSheet.futureProvider')}
                  </Button>
                </div>
              }
            >
              <div className="space-y-5">
                <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <p className="text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                        {t('erp.draftSheet.summary')}
                      </p>
                      <h3 className="mt-2 text-lg font-semibold text-[var(--color-text-primary)]">
                        {t(selectedProvider.labelKey)}
                      </h3>
                      <p className="mt-1 text-sm leading-relaxed text-[var(--color-text-muted)]">
                        {t(selectedProvider.readinessLabelKey)}
                      </p>
                      <p className="mt-3 text-xs leading-relaxed text-[var(--color-text-secondary)]">
                        {selectedProvider.setupAvailable
                          ? t('erp.draftSheet.persistedSetupHint')
                          : t('erp.draftSheet.futureProviderHint')}
                      </p>
                      <dl className="mt-4 grid gap-3 text-xs sm:grid-cols-2">
                        <div>
                          <dt className="font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                            {t('erp.providerCatalog.labels.category')}
                          </dt>
                          <dd className="mt-1 text-[var(--color-text-primary)]">
                            {t(selectedProvider.categoryKey)}
                          </dd>
                        </div>
                        <div>
                          <dt className="font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                            {t('erp.providerCatalog.labels.availability')}
                          </dt>
                          <dd className="mt-1 text-[var(--color-text-primary)]">
                            {t(selectedProvider.availabilityKey)}
                          </dd>
                        </div>
                      </dl>
                    </div>
                    <StatusPill tone={readinessTone(selectedProvider.status)}>
                      {t(`erp.readinessStatus.${selectedProvider.status}`)}
                    </StatusPill>
                  </div>
                </div>

                <div>
                  <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                    {t('erp.draftSheet.requirements')}
                  </p>
                  <ul className="mt-2 divide-y divide-[var(--color-border)] rounded-xl border border-[var(--color-border)]">
                    {selectedProvider.requirements.map((requirement) => (
                      <li key={requirement.id} className="p-3">
                        <div className="flex items-start justify-between gap-3">
                          <div className="min-w-0">
                            <p className="text-sm font-medium text-[var(--color-text-primary)]">
                              {t(requirement.labelKey)}
                            </p>
                            <p className="mt-1 text-xs leading-relaxed text-[var(--color-text-muted)]">
                              {t(requirement.descriptionKey)}
                            </p>
                          </div>
                          <StatusPill tone={readinessTone(requirement.status)}>
                            {t(`erp.readinessStatus.${requirement.status}`)}
                          </StatusPill>
                        </div>
                      </li>
                    ))}
                  </ul>
                </div>

                <div className="rounded-xl border border-[color-mix(in_srgb,var(--color-warning)_25%,transparent)] bg-[var(--color-warning-soft)] p-4">
                  <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                    {t('erp.draftSheet.guardrailTitle')}
                  </p>
                  <p className="mt-1 text-sm leading-relaxed text-[var(--color-text-secondary)]">
                    {t('erp.draftSheet.guardrailBody')}
                  </p>
                </div>
              </div>
            </SheetShell>
          ) : null}
        </section>
      ) : null}

      {data && hasSelectedConnector ? (
        <Tabs
          value={activeWorkbenchTab}
          onValueChange={(value) => setActiveWorkbenchTab(value as ErpWorkbenchTab)}
          className="mt-8"
        >
          <div className="-mx-4 overflow-x-auto px-4 pb-1 sm:mx-0 sm:px-0">
            <TabsList
              aria-label={t('erp.tabs.label')}
              className="h-auto w-max min-w-full gap-1 rounded-xl p-1 sm:w-full"
            >
              {ERP_WORKBENCH_TABS.map((tab) => (
                <TabsTrigger
                  key={tab}
                  value={tab}
                  className="min-w-[132px] flex-none whitespace-nowrap px-3 py-2 sm:min-w-0 sm:flex-1"
                >
                  {t(`erp.tabs.${tab}`)}
                </TabsTrigger>
              ))}
            </TabsList>
          </div>

          <TabsContent value="setup" className="mt-6">
            <section className="grid gap-4 lg:grid-cols-[0.9fr_1.1fr]">
              <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
                <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                  <div className="min-w-0">
                    <p className="text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                      {t('erp.sections.lifecycle')}
                    </p>
                    <h2 className="mt-2 text-lg font-semibold text-[var(--color-text-primary)]">
                      {t(data.lifecycle.labelKey)}
                    </h2>
                    <p className="mt-2 text-sm leading-relaxed text-[var(--color-text-muted)]">
                      {t(data.lifecycle.descriptionKey)}
                    </p>
                    <p className="mt-3 text-xs leading-relaxed text-[var(--color-text-secondary)]">
                      {t(data.lifecycle.nextActionKey)}
                    </p>
                  </div>
                  <StatusPill tone={readinessTone(data.lifecycle.status)}>
                    {t(`erp.readinessStatus.${data.lifecycle.status}`)}
                  </StatusPill>
                </div>
              </div>

              <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
                <div className="flex flex-col gap-1 sm:flex-row sm:items-start sm:justify-between">
                  <div>
                    <p className="text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                      {t('erp.sections.capabilities')}
                    </p>
                    <h2 className="mt-2 text-lg font-semibold text-[var(--color-text-primary)]">
                      {t('erp.capabilities.title')}
                    </h2>
                  </div>
                  <p className="text-xs leading-relaxed text-[var(--color-text-muted)] sm:max-w-[260px] sm:text-right">
                    {t('erp.capabilities.description')}
                  </p>
                </div>
                <ul className="mt-4 grid gap-2 sm:grid-cols-2">
                  {data.capabilities.map((capability) => (
                    <li
                      key={capability.id}
                      className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-3"
                    >
                      <div className="flex items-start justify-between gap-3">
                        <div className="min-w-0">
                          <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                            {t(capability.labelKey)}
                          </p>
                          <p className="mt-1 text-xs leading-relaxed text-[var(--color-text-muted)]">
                            {t(capability.descriptionKey)}
                          </p>
                        </div>
                        <StatusPill tone={readinessTone(capability.status)}>
                          {t(`erp.readinessStatus.${capability.status}`)}
                        </StatusPill>
                      </div>
                    </li>
                  ))}
                </ul>
              </div>
            </section>

            <div className="mt-6 flex flex-col gap-2 sm:flex-row sm:flex-wrap">
              <Button
                type="button"
                variant="outline"
                className="touch-target w-full sm:w-auto"
                onClick={() => showWorkbenchTab('fields', 'erp-mapping-discovery')}
              >
                <Link2 className="h-4 w-4" />
                {t('erp.actions.reviewMapping')}
              </Button>
              <Button
                type="button"
                variant="outline"
                className="touch-target w-full sm:w-auto"
                disabled={!canManageConnectors || runPreflightMutation.isPending}
                onClick={() => void runPreflightMutation.mutateAsync()}
              >
                <RefreshCw
                  className={cn('h-4 w-4', runPreflightMutation.isPending ? 'animate-spin' : null)}
                />
                {canManageConnectors
                  ? runPreflightMutation.isPending
                    ? t('erp.actions.runningPreflight')
                    : t('erp.actions.runPreflight')
                  : t('erp.actions.adminPreflightRequired')}
              </Button>
            </div>
            <p className="mt-2 text-xs text-[var(--color-text-muted)]">{t('erp.preflightNote')}</p>
          </TabsContent>

          <TabsContent value="check" className="mt-6">
            <section id="erp-preflight-result" className="scroll-mt-6">
              <SectionHeader
                title={t('erp.sections.preflight')}
                description={t('erp.sections.preflightDescription')}
              />
              <div className="mb-3 rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
                <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <h2 className="text-lg font-semibold text-[var(--color-text-primary)]">
                        {t(data.preflight.summaryKey)}
                      </h2>
                      <StatusPill tone={readinessTone(data.preflight.status)}>
                        {t(data.preflight.statusLabelKey)}
                      </StatusPill>
                    </div>
                    <p className="mt-2 text-sm leading-relaxed text-[var(--color-text-muted)]">
                      {t(data.preflight.nextStepKey)}
                    </p>
                    <p className="mt-3 text-xs leading-relaxed text-[var(--color-text-secondary)]">
                      {data.syncLogs.some((log) => log.kind === 'setup_preflight')
                        ? t('erp.preflightResult.persistedRun')
                        : t('erp.preflightResult.computedFromSetup')}
                    </p>
                  </div>
                  <div className="grid min-w-[220px] grid-cols-3 gap-2 text-center">
                    <div className="rounded-lg bg-[var(--color-bg-surface)] px-3 py-2">
                      <p className="font-mono text-lg font-semibold text-[var(--color-success)]">
                        {data.preflight.passedCount}
                      </p>
                      <p className="mt-1 text-[11px] font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                        {t('erp.preflightResult.passed')}
                      </p>
                    </div>
                    <div className="rounded-lg bg-[var(--color-bg-surface)] px-3 py-2">
                      <p className="font-mono text-lg font-semibold text-[var(--color-warning)]">
                        {data.preflight.warningCount}
                      </p>
                      <p className="mt-1 text-[11px] font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                        {t('erp.preflightResult.warning')}
                      </p>
                    </div>
                    <div className="rounded-lg bg-[var(--color-bg-surface)] px-3 py-2">
                      <p className="font-mono text-lg font-semibold text-[var(--color-danger)]">
                        {data.preflight.blockedCount}
                      </p>
                      <p className="mt-1 text-[11px] font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                        {t('erp.preflightResult.blocked')}
                      </p>
                    </div>
                  </div>
                </div>
              </div>
              <ul className="grid gap-3 sm:grid-cols-2">
                {data.preflight.checks.map((check) => (
                  <li
                    key={check.id}
                    className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4"
                  >
                    <div className="flex items-start justify-between gap-3">
                      <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                        {t(check.labelKey)}
                      </p>
                      <StatusPill tone={readinessTone(check.status)}>
                        {t(`erp.readinessStatus.${check.status}`)}
                      </StatusPill>
                    </div>
                    <p className="mt-2 text-sm leading-relaxed text-[var(--color-text-muted)]">
                      {t(check.descriptionKey)}
                    </p>
                  </li>
                ))}
              </ul>
            </section>
          </TabsContent>

          <TabsContent value="previewApply" className="mt-6">
            <section id="erp-import-preview" className="scroll-mt-6">
              <SectionHeader
                title={t('erp.sections.importPreview')}
                description={t('erp.sections.importPreviewDescription')}
              />
              <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
                <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <h2 className="text-lg font-semibold text-[var(--color-text-primary)]">
                        {t(data.importPreview.statusLabelKey)}
                      </h2>
                      <StatusPill tone={readinessTone(data.importPreview.readiness)}>
                        {t(`erp.readinessStatus.${data.importPreview.readiness}`)}
                      </StatusPill>
                    </div>
                    <p className="mt-2 max-w-2xl text-sm leading-relaxed text-[var(--color-text-muted)]">
                      {t(data.importPreview.descriptionKey)}
                    </p>
                    <p className="mt-3 text-xs leading-relaxed text-[var(--color-text-secondary)]">
                      {t(data.importPreview.actionDescriptionKey)}
                    </p>
                  </div>
                  <Button
                    type="button"
                    variant="outline"
                    className="touch-target w-full lg:w-auto"
                    disabled={!canRunImportPreview || runImportPreviewMutation.isPending}
                    onClick={() => void runImportPreviewMutation.mutateAsync()}
                  >
                    <SearchCheck
                      className={cn(
                        'h-4 w-4',
                        runImportPreviewMutation.isPending ? 'animate-pulse' : null,
                      )}
                    />
                    {canRunImportPreview
                      ? runImportPreviewMutation.isPending
                        ? t('erp.importPreview.running')
                        : t(data.importPreview.actionLabelKey)
                      : !canManageConnectors && data.importPreview.action === 'run_dry_run_preview'
                        ? t('erp.importPreview.adminRequired')
                        : t(data.importPreview.actionLabelKey)}
                  </Button>
                </div>

                <div className="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
                  <div className="rounded-lg bg-[var(--color-bg-surface)] px-4 py-3">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.importPreview.metrics.batch')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {data.importPreview.batch
                        ? t(`erp.importPreview.batchStatus.${data.importPreview.batch.status}`)
                        : t('erp.importPreview.values.none')}
                    </p>
                    <p className="mt-1 truncate text-xs text-[var(--color-text-muted)]">
                      {data.importPreview.batch?.sourceNamespaceCode ??
                        t('erp.importPreview.values.noNamespace')}
                    </p>
                  </div>
                  <div className="rounded-lg bg-[var(--color-bg-surface)] px-4 py-3">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.importPreview.metrics.rows')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {data.importPreview.summary.rowCount}
                    </p>
                    <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                      {t('erp.importPreview.values.dryRunOnly')}
                    </p>
                  </div>
                  <div className="rounded-lg bg-[var(--color-bg-surface)] px-4 py-3">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.importPreview.metrics.preview')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {data.importPreview.summary.createCount} /{' '}
                      {data.importPreview.summary.updateCount} /{' '}
                      {data.importPreview.summary.skipCount}
                    </p>
                    <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                      {t('erp.importPreview.values.createUpdateSkip')}
                    </p>
                  </div>
                  <div className="rounded-lg bg-[var(--color-bg-surface)] px-4 py-3">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.importPreview.metrics.findings')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {data.importPreview.summary.errorCount} /{' '}
                      {data.importPreview.summary.warningCount}
                    </p>
                    <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                      {t('erp.importPreview.values.errorWarning')}
                    </p>
                  </div>
                </div>

                <div className="mt-4 overflow-hidden rounded-lg border border-[var(--color-border)]">
                  <div className="hidden border-b border-[var(--color-border)] bg-[var(--color-bg-surface)] px-4 py-2.5 text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)] md:grid md:grid-cols-[80px_1fr_1fr_130px] md:gap-3">
                    <div>{t('erp.importPreview.columns.row')}</div>
                    <div>{t('erp.importPreview.columns.entity')}</div>
                    <div>{t('erp.importPreview.columns.externalId')}</div>
                    <div className="text-right">{t('erp.importPreview.columns.result')}</div>
                  </div>
                  <ul className="divide-y divide-[var(--color-border)]">
                    {data.importPreview.records.length > 0 ? (
                      data.importPreview.records.slice(0, 8).map((record) => (
                        <li
                          key={record.id}
                          className="grid gap-2 px-4 py-3 md:grid-cols-[80px_1fr_1fr_130px] md:items-center md:gap-3"
                        >
                          <div className="font-mono text-sm text-[var(--color-text-muted)]">
                            #{record.rowNumber}
                          </div>
                          <div className="min-w-0">
                            <p className="truncate font-mono text-sm font-semibold text-[var(--color-text-primary)]">
                              {record.entityType}
                            </p>
                            <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                              {t(`erp.importPreview.recordStatus.${record.status}`)}
                            </p>
                          </div>
                          <div className="min-w-0 truncate font-mono text-sm text-[var(--color-text-secondary)]">
                            {record.externalId}
                          </div>
                          <div className="md:justify-self-end">
                            <StatusPill
                              tone={
                                record.status === 'error'
                                  ? 'danger'
                                  : record.action === 'skip'
                                    ? 'neutral'
                                    : record.action
                                      ? 'success'
                                      : 'warning'
                              }
                            >
                              {record.action
                                ? t(`erp.importPreview.recordActions.${record.action}`)
                                : t(`erp.importPreview.recordStatus.${record.status}`)}
                            </StatusPill>
                          </div>
                          {record.errorCodes.length > 0 || record.warningCodes.length > 0 ? (
                            <div className="md:col-span-4">
                              <p className="rounded-md bg-[var(--color-bg-muted)] px-3 py-2 text-xs text-[var(--color-text-muted)]">
                                {[...record.errorCodes, ...record.warningCodes].join(', ')}
                              </p>
                            </div>
                          ) : null}
                        </li>
                      ))
                    ) : (
                      <li className="p-4 text-sm text-[var(--color-text-muted)]">
                        {t('erp.empty.importPreview')}
                      </li>
                    )}
                  </ul>
                </div>
                {data.importPreview.records.length > 8 ? (
                  <p className="mt-3 text-xs text-[var(--color-text-muted)]">
                    {t('erp.importPreview.moreRecords', {
                      count: data.importPreview.records.length - 8,
                    })}
                  </p>
                ) : null}
              </div>
            </section>

            <section id="erp-apply-readiness" className="mt-8 scroll-mt-6">
              <SectionHeader
                title={t('erp.sections.applyReadiness')}
                description={t('erp.sections.applyReadinessDescription')}
              />
              <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
                <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <h2 className="text-lg font-semibold text-[var(--color-text-primary)]">
                        {t(data.applyReadiness.statusLabelKey)}
                      </h2>
                      <StatusPill tone={readinessTone(data.applyReadiness.readiness)}>
                        {t(`erp.readinessStatus.${data.applyReadiness.readiness}`)}
                      </StatusPill>
                      <StatusPill tone="neutral">
                        {t('erp.applyReadiness.safeToApplyFalse')}
                      </StatusPill>
                    </div>
                    <p className="mt-2 max-w-2xl text-sm leading-relaxed text-[var(--color-text-muted)]">
                      {t(data.applyReadiness.descriptionKey)}
                    </p>
                    <p className="mt-3 text-xs leading-relaxed text-[var(--color-text-secondary)]">
                      {t(data.applyReadiness.actionDescriptionKey)}
                    </p>
                    {data.applyReadiness.reviewRequestedAt ? (
                      <p className="mt-2 text-xs text-[var(--color-text-muted)]">
                        {t('erp.applyReadiness.reviewRequestedAt', {
                          value: formatDateTime(
                            data.applyReadiness.reviewRequestedAt,
                            i18n.language,
                            t('erp.credentialBoundary.notRecorded'),
                          ),
                        })}
                      </p>
                    ) : null}
                  </div>
                  <Button
                    type="button"
                    variant="outline"
                    className="touch-target w-full lg:w-auto"
                    disabled={!canRequestApplyReview || requestApplyReviewMutation.isPending}
                    onClick={() => void requestApplyReviewMutation.mutateAsync()}
                  >
                    <ClipboardCheck
                      className={cn(
                        'h-4 w-4',
                        requestApplyReviewMutation.isPending ? 'animate-pulse' : null,
                      )}
                    />
                    {canRequestApplyReview
                      ? requestApplyReviewMutation.isPending
                        ? t('erp.applyReadiness.requesting')
                        : t(data.applyReadiness.actionLabelKey)
                      : !canManageConnectors &&
                          data.applyReadiness.action === 'request_human_review'
                        ? t('erp.applyReadiness.adminRequired')
                        : t(data.applyReadiness.actionLabelKey)}
                  </Button>
                </div>

                <div className="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
                  <div className="rounded-lg bg-[var(--color-bg-surface)] px-4 py-3">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.applyReadiness.metrics.preview')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {data.applyReadiness.summary.createCount} /{' '}
                      {data.applyReadiness.summary.updateCount} /{' '}
                      {data.applyReadiness.summary.skipCount}
                    </p>
                    <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                      {t('erp.applyReadiness.values.createUpdateSkip')}
                    </p>
                  </div>
                  <div className="rounded-lg bg-[var(--color-bg-surface)] px-4 py-3">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.applyReadiness.metrics.findings')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {data.applyReadiness.summary.errorCount} /{' '}
                      {data.applyReadiness.summary.warningCount}
                    </p>
                    <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                      {t('erp.applyReadiness.values.errorWarning')}
                    </p>
                  </div>
                  <div className="rounded-lg bg-[var(--color-bg-surface)] px-4 py-3">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.applyReadiness.metrics.blockers')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {data.applyReadiness.summary.blockerCount}
                    </p>
                    <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                      {t('erp.applyReadiness.values.blockers')}
                    </p>
                  </div>
                  <div className="rounded-lg bg-[var(--color-bg-surface)] px-4 py-3">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.applyReadiness.metrics.execution')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {t('erp.applyReadiness.values.closed')}
                    </p>
                    <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                      {t('erp.applyReadiness.values.noApply')}
                    </p>
                  </div>
                </div>

                <div className="mt-4 grid gap-3 lg:grid-cols-[1fr_0.9fr]">
                  <ul className="divide-y divide-[var(--color-border)] overflow-hidden rounded-lg border border-[var(--color-border)]">
                    {data.applyReadiness.checks.map((check) => (
                      <li key={check.id} className="flex items-start justify-between gap-3 p-3">
                        <div className="min-w-0">
                          <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                            {t(check.labelKey)}
                          </p>
                          <p className="mt-1 text-xs leading-relaxed text-[var(--color-text-muted)]">
                            {t(check.descriptionKey)}
                          </p>
                        </div>
                        <div className="shrink-0 text-right">
                          <StatusPill tone={readinessTone(check.status)}>
                            {t(`erp.readinessStatus.${check.status}`)}
                          </StatusPill>
                          <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                            {t(check.valueKey)}
                          </p>
                        </div>
                      </li>
                    ))}
                  </ul>

                  <div className="rounded-lg border border-[var(--color-border)] p-3">
                    <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                      {t('erp.applyReadiness.blockersTitle')}
                    </p>
                    {data.applyReadiness.blockers.length > 0 ? (
                      <ul className="mt-3 space-y-2">
                        {data.applyReadiness.blockers.map((blocker) => (
                          <li
                            key={blocker.id}
                            className="rounded-md bg-[var(--color-bg-surface)] px-3 py-2"
                          >
                            <p className="text-xs font-semibold text-[var(--color-text-primary)]">
                              {t(blocker.labelKey)}
                            </p>
                            <p className="mt-1 text-xs leading-relaxed text-[var(--color-text-muted)]">
                              {t(blocker.descriptionKey)}
                            </p>
                          </li>
                        ))}
                      </ul>
                    ) : (
                      <p className="mt-3 text-xs leading-relaxed text-[var(--color-text-muted)]">
                        {t('erp.applyReadiness.noBlockers')}
                      </p>
                    )}
                  </div>
                </div>
              </div>
            </section>

            <section id="erp-apply-change-set" className="mt-8 scroll-mt-6">
              <SectionHeader
                title={t('erp.sections.applyChangeSet')}
                description={t('erp.sections.applyChangeSetDescription')}
              />
              <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
                <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <h2 className="text-lg font-semibold text-[var(--color-text-primary)]">
                        {t(data.applyChangeSet.statusLabelKey)}
                      </h2>
                      <StatusPill tone={readinessTone(data.applyChangeSet.readiness)}>
                        {t(`erp.readinessStatus.${data.applyChangeSet.readiness}`)}
                      </StatusPill>
                      <StatusPill tone="neutral">
                        {t('erp.applyChangeSet.executionClosed')}
                      </StatusPill>
                    </div>
                    <p className="mt-2 max-w-2xl text-sm leading-relaxed text-[var(--color-text-muted)]">
                      {t(data.applyChangeSet.descriptionKey)}
                    </p>
                    <p className="mt-3 text-xs leading-relaxed text-[var(--color-text-secondary)]">
                      {t(data.applyChangeSet.actionDescriptionKey)}
                    </p>
                    {data.applyChangeSet.createdAt ? (
                      <p className="mt-2 text-xs text-[var(--color-text-muted)]">
                        {t('erp.applyChangeSet.generatedAt', {
                          value: formatDateTime(
                            data.applyChangeSet.createdAt,
                            i18n.language,
                            t('erp.credentialBoundary.notRecorded'),
                          ),
                        })}
                      </p>
                    ) : null}
                  </div>
                  <Button
                    type="button"
                    variant="outline"
                    className="touch-target w-full lg:w-auto"
                    disabled={!canRequestApplyChangeSet || requestApplyChangeSetMutation.isPending}
                    onClick={() => void requestApplyChangeSetMutation.mutateAsync()}
                  >
                    <Braces
                      className={cn(
                        'h-4 w-4',
                        requestApplyChangeSetMutation.isPending ? 'animate-pulse' : null,
                      )}
                    />
                    {canRequestApplyChangeSet
                      ? requestApplyChangeSetMutation.isPending
                        ? t('erp.applyChangeSet.generating')
                        : t(data.applyChangeSet.actionLabelKey)
                      : !canManageConnectors && data.applyChangeSet.action === 'generate_change_set'
                        ? t('erp.applyChangeSet.adminRequired')
                        : t(data.applyChangeSet.actionLabelKey)}
                  </Button>
                </div>

                <div className="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
                  <div className="rounded-lg bg-[var(--color-bg-surface)] px-4 py-3">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.applyChangeSet.metrics.intent')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {data.applyChangeSet.summary.createCount} /{' '}
                      {data.applyChangeSet.summary.updateCount} /{' '}
                      {data.applyChangeSet.summary.skipCount}
                    </p>
                    <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                      {t('erp.applyChangeSet.values.createUpdateSkip')}
                    </p>
                  </div>
                  <div className="rounded-lg bg-[var(--color-bg-surface)] px-4 py-3">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.applyChangeSet.metrics.blockers')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {data.applyChangeSet.summary.blockedCount}
                    </p>
                    <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                      {t('erp.applyChangeSet.values.blockedRows')}
                    </p>
                  </div>
                  <div className="rounded-lg bg-[var(--color-bg-surface)] px-4 py-3">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.applyChangeSet.metrics.risk')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {data.applyChangeSet.summary.guardedUpdateCount} /{' '}
                      {data.applyChangeSet.summary.destructiveCount}
                    </p>
                    <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                      {t('erp.applyChangeSet.values.guardedDestructive')}
                    </p>
                  </div>
                  <div className="rounded-lg bg-[var(--color-bg-surface)] px-4 py-3">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.applyChangeSet.metrics.drift')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {data.applyChangeSet.summary.staleCount} /{' '}
                      {data.applyChangeSet.summary.sourceConflictCount}
                    </p>
                    <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                      {t('erp.applyChangeSet.values.staleConflict')}
                    </p>
                  </div>
                </div>

                <div className="mt-4 overflow-hidden rounded-lg border border-[var(--color-border)]">
                  <div className="grid gap-2 border-b border-[var(--color-border)] bg-[var(--color-bg-surface)] px-4 py-3 text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)] md:grid-cols-[72px_1fr_1fr_150px]">
                    <span>{t('erp.applyChangeSet.columns.row')}</span>
                    <span>{t('erp.applyChangeSet.columns.target')}</span>
                    <span>{t('erp.applyChangeSet.columns.evidence')}</span>
                    <span className="md:text-right">{t('erp.applyChangeSet.columns.risk')}</span>
                  </div>
                  <ul className="divide-y divide-[var(--color-border)]">
                    {data.applyChangeSet.sampleItems.length > 0 ? (
                      data.applyChangeSet.sampleItems.map((item) => (
                        <li
                          key={item.id}
                          className="grid gap-2 px-4 py-3 md:grid-cols-[72px_1fr_1fr_150px] md:items-center"
                        >
                          <div className="font-mono text-sm text-[var(--color-text-muted)]">
                            #{item.rowNumber}
                          </div>
                          <div className="min-w-0">
                            <p className="truncate font-mono text-sm font-semibold text-[var(--color-text-primary)]">
                              {item.entityType}
                            </p>
                            <p className="mt-1 truncate text-xs text-[var(--color-text-muted)]">
                              {item.targetTable} · {item.externalId}
                            </p>
                          </div>
                          <div className="min-w-0">
                            <p className="truncate text-xs font-medium text-[var(--color-text-secondary)]">
                              {item.safeFieldNames.length > 0
                                ? item.safeFieldNames.join(', ')
                                : t('erp.applyChangeSet.values.noFieldDiff')}
                            </p>
                            <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                              {item.rollbackSnapshotRequired
                                ? t('erp.applyChangeSet.values.rollbackSnapshot')
                                : t(`erp.applyChangeSet.retention.${item.retentionBucket}`)}
                            </p>
                          </div>
                          <div className="md:justify-self-end">
                            <StatusPill tone={applyChangeSetRiskTone(item.riskClass, item.blocked)}>
                              {t(`erp.applyChangeSet.riskClasses.${item.riskClass}`)}
                            </StatusPill>
                          </div>
                        </li>
                      ))
                    ) : (
                      <li className="p-4 text-sm text-[var(--color-text-muted)]">
                        {t('erp.applyChangeSet.empty')}
                      </li>
                    )}
                  </ul>
                </div>

                <div className="mt-4 flex items-start gap-3 rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-4 py-3">
                  <Info
                    className="mt-0.5 h-4 w-4 shrink-0 text-[var(--color-primary)]"
                    aria-hidden
                  />
                  <p className="text-xs leading-relaxed text-[var(--color-text-muted)]">
                    {t('erp.applyChangeSet.boundaryNote')}
                  </p>
                </div>
              </div>
            </section>

            <section id="erp-guarded-update-evidence" className="mt-8 scroll-mt-6">
              <SectionHeader
                title={t('erp.sections.guardedUpdateEvidence')}
                description={t('erp.sections.guardedUpdateEvidenceDescription')}
              />
              <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
                <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <h2 className="text-lg font-semibold text-[var(--color-text-primary)]">
                        {t(data.guardedUpdateEvidence.statusLabelKey)}
                      </h2>
                      <StatusPill tone={readinessTone(data.guardedUpdateEvidence.readiness)}>
                        {t(`erp.readinessStatus.${data.guardedUpdateEvidence.readiness}`)}
                      </StatusPill>
                      <StatusPill tone="neutral">
                        {t('erp.guardedUpdateEvidence.executionClosed')}
                      </StatusPill>
                    </div>
                    <p className="mt-2 max-w-2xl text-sm leading-relaxed text-[var(--color-text-muted)]">
                      {t(data.guardedUpdateEvidence.descriptionKey)}
                    </p>
                    <p className="mt-3 text-xs leading-relaxed text-[var(--color-text-secondary)]">
                      {t(data.guardedUpdateEvidence.actionDescriptionKey)}
                    </p>
                    {data.guardedUpdateEvidence.generatedAt ? (
                      <p className="mt-2 text-xs text-[var(--color-text-muted)]">
                        {t('erp.guardedUpdateEvidence.generatedAt', {
                          value: formatDateTime(
                            data.guardedUpdateEvidence.generatedAt,
                            i18n.language,
                            t('erp.credentialBoundary.notRecorded'),
                          ),
                        })}
                      </p>
                    ) : null}
                  </div>
                  <Button
                    type="button"
                    variant="outline"
                    className="touch-target w-full lg:w-auto"
                    disabled={
                      !canRequestGuardedUpdateEvidence ||
                      requestGuardedUpdateEvidenceMutation.isPending
                    }
                    onClick={() => void requestGuardedUpdateEvidenceMutation.mutateAsync()}
                  >
                    <ShieldCheck
                      className={cn(
                        'h-4 w-4',
                        requestGuardedUpdateEvidenceMutation.isPending ? 'animate-pulse' : null,
                      )}
                    />
                    {canRequestGuardedUpdateEvidence
                      ? requestGuardedUpdateEvidenceMutation.isPending
                        ? t('erp.guardedUpdateEvidence.generating')
                        : t(data.guardedUpdateEvidence.actionLabelKey)
                      : !canManageConnectors &&
                          data.guardedUpdateEvidence.action === 'generate_evidence'
                        ? t('erp.guardedUpdateEvidence.adminRequired')
                        : t(data.guardedUpdateEvidence.actionLabelKey)}
                  </Button>
                </div>

                <div className="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
                  <div className="rounded-lg bg-[var(--color-bg-surface)] px-4 py-3">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateEvidence.metrics.guardedRows')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {data.guardedUpdateEvidence.summary.guardedUpdateCount}
                    </p>
                    <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateEvidence.values.updateRows')}
                    </p>
                  </div>
                  <div className="rounded-lg bg-[var(--color-bg-surface)] px-4 py-3">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateEvidence.metrics.fieldDiffs')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {data.guardedUpdateEvidence.summary.fieldDiffCount}
                    </p>
                    <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateEvidence.values.hashOnly')}
                    </p>
                  </div>
                  <div className="rounded-lg bg-[var(--color-bg-surface)] px-4 py-3">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateEvidence.metrics.snapshots')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {data.guardedUpdateEvidence.summary.rollbackSnapshotCount}
                    </p>
                    <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateEvidence.values.rollbackReady')}
                    </p>
                  </div>
                  <div className="rounded-lg bg-[var(--color-bg-surface)] px-4 py-3">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateEvidence.metrics.retention')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {data.guardedUpdateEvidence.summary.hotRetentionDays}
                    </p>
                    <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateEvidence.values.days')}
                    </p>
                  </div>
                </div>

                <div className="mt-4 overflow-hidden rounded-lg border border-[var(--color-border)]">
                  <div className="grid gap-2 border-b border-[var(--color-border)] bg-[var(--color-bg-surface)] px-4 py-3 text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)] md:grid-cols-[72px_1fr_1fr_140px]">
                    <span>{t('erp.guardedUpdateEvidence.columns.row')}</span>
                    <span>{t('erp.guardedUpdateEvidence.columns.target')}</span>
                    <span>{t('erp.guardedUpdateEvidence.columns.evidence')}</span>
                    <span className="md:text-right">
                      {t('erp.guardedUpdateEvidence.columns.class')}
                    </span>
                  </div>
                  <ul className="divide-y divide-[var(--color-border)]">
                    {data.guardedUpdateEvidence.sampleFieldDiffs.length > 0 ? (
                      data.guardedUpdateEvidence.sampleFieldDiffs.map((field) => (
                        <li
                          key={field.id}
                          className="grid gap-2 px-4 py-3 md:grid-cols-[72px_1fr_1fr_140px] md:items-center"
                        >
                          <div className="font-mono text-sm text-[var(--color-text-muted)]">
                            #{field.rowNumber}
                          </div>
                          <div className="min-w-0">
                            <p className="truncate font-mono text-sm font-semibold text-[var(--color-text-primary)]">
                              {field.entityType}
                            </p>
                            <p className="mt-1 truncate text-xs text-[var(--color-text-muted)]">
                              {field.targetTable} · {field.externalId}
                            </p>
                          </div>
                          <div className="min-w-0">
                            <p className="truncate text-xs font-medium text-[var(--color-text-secondary)]">
                              {field.fieldName} ·{' '}
                              {t(`erp.guardedUpdateEvidence.operations.${field.operation}`)}
                            </p>
                            <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                              {field.beforeValueHashAvailable && field.afterValueHashAvailable
                                ? t('erp.guardedUpdateEvidence.values.hashPairReady')
                                : t('erp.guardedUpdateEvidence.values.hashPairMissing')}
                            </p>
                          </div>
                          <div className="md:justify-self-end">
                            <StatusPill
                              tone={guardedUpdateFieldTone(field.fieldClass, field.staleBlocked)}
                            >
                              {t(`erp.guardedUpdateEvidence.fieldClasses.${field.fieldClass}`)}
                            </StatusPill>
                          </div>
                        </li>
                      ))
                    ) : (
                      <li className="p-4 text-sm text-[var(--color-text-muted)]">
                        {t('erp.guardedUpdateEvidence.empty')}
                      </li>
                    )}
                  </ul>
                </div>

                <div className="mt-4 flex items-start gap-3 rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-4 py-3">
                  <Info
                    className="mt-0.5 h-4 w-4 shrink-0 text-[var(--color-primary)]"
                    aria-hidden
                  />
                  <p className="text-xs leading-relaxed text-[var(--color-text-muted)]">
                    {t('erp.guardedUpdateEvidence.boundaryNote')}
                  </p>
                </div>
              </div>
            </section>

            <section id="erp-guarded-update-recovery" className="mt-8 scroll-mt-6">
              <SectionHeader
                title={t('erp.sections.guardedUpdateRecovery')}
                description={t('erp.sections.guardedUpdateRecoveryDescription')}
              />
              <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
                <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <h2 className="text-lg font-semibold text-[var(--color-text-primary)]">
                        {t(data.guardedUpdateRecovery.statusLabelKey)}
                      </h2>
                      <StatusPill tone={readinessTone(data.guardedUpdateRecovery.readiness)}>
                        {t(`erp.readinessStatus.${data.guardedUpdateRecovery.readiness}`)}
                      </StatusPill>
                      <StatusPill tone="neutral">
                        {t('erp.guardedUpdateRecovery.rollbackExecutionClosed')}
                      </StatusPill>
                    </div>
                    <p className="mt-2 max-w-2xl text-sm leading-relaxed text-[var(--color-text-muted)]">
                      {t(data.guardedUpdateRecovery.descriptionKey)}
                    </p>
                    <p className="mt-3 text-xs leading-relaxed text-[var(--color-text-secondary)]">
                      {t(data.guardedUpdateRecovery.actionDescriptionKey)}
                    </p>
                    {data.guardedUpdateRecovery.appliedAt ? (
                      <p className="mt-2 text-xs text-[var(--color-text-muted)]">
                        {t('erp.guardedUpdateRecovery.appliedAt', {
                          value: formatDateTime(
                            data.guardedUpdateRecovery.appliedAt,
                            i18n.language,
                            t('erp.credentialBoundary.notRecorded'),
                          ),
                        })}
                      </p>
                    ) : null}
                  </div>
                  <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-4 py-3 text-xs text-[var(--color-text-muted)] lg:max-w-sm">
                    {t('erp.guardedUpdateRecovery.nextAction', {
                      value:
                        data.guardedUpdateRecovery.nextActionKey ??
                        t('erp.guardedUpdateRecovery.values.noAction'),
                    })}
                  </div>
                </div>

                <div className="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
                  <div className="rounded-lg bg-[var(--color-bg-surface)] px-4 py-3">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateRecovery.metrics.updates')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {data.guardedUpdateRecovery.summary.updateCount}
                    </p>
                    <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateRecovery.values.appliedRows')}
                    </p>
                  </div>
                  <div className="rounded-lg bg-[var(--color-bg-surface)] px-4 py-3">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateRecovery.metrics.objectEvents')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {data.guardedUpdateRecovery.summary.objectEventCount}
                    </p>
                    <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateRecovery.values.auditLinked')}
                    </p>
                  </div>
                  <div className="rounded-lg bg-[var(--color-bg-surface)] px-4 py-3">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateRecovery.metrics.rollbackReady')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {data.guardedUpdateRecovery.summary.rollbackReadyCount}
                    </p>
                    <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateRecovery.values.snapshotWindow')}
                    </p>
                  </div>
                  <div className="rounded-lg bg-[var(--color-bg-surface)] px-4 py-3">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateRecovery.metrics.retention')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {data.guardedUpdateRecovery.summary.recoveryWindowHotRetentionDays}
                    </p>
                    <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateRecovery.values.days')}
                    </p>
                  </div>
                </div>

                <div className="mt-4 overflow-hidden rounded-lg border border-[var(--color-border)]">
                  <div className="grid gap-2 border-b border-[var(--color-border)] bg-[var(--color-bg-surface)] px-4 py-3 text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)] md:grid-cols-[72px_1fr_1fr_160px]">
                    <span>{t('erp.guardedUpdateRecovery.columns.row')}</span>
                    <span>{t('erp.guardedUpdateRecovery.columns.target')}</span>
                    <span>{t('erp.guardedUpdateRecovery.columns.evidence')}</span>
                    <span className="md:text-right">
                      {t('erp.guardedUpdateRecovery.columns.boundary')}
                    </span>
                  </div>
                  <ul className="divide-y divide-[var(--color-border)]">
                    {data.guardedUpdateRecovery.sampleEvents.length > 0 ? (
                      data.guardedUpdateRecovery.sampleEvents.map((event) => (
                        <li
                          key={event.id}
                          className="grid gap-2 px-4 py-3 md:grid-cols-[72px_1fr_1fr_160px] md:items-center"
                        >
                          <div className="font-mono text-sm text-[var(--color-text-muted)]">
                            #{event.rowNumber}
                          </div>
                          <div className="min-w-0">
                            <p className="truncate font-mono text-sm font-semibold text-[var(--color-text-primary)]">
                              {event.entityType}
                            </p>
                            <p className="mt-1 truncate text-xs text-[var(--color-text-muted)]">
                              {event.targetTable} · {event.externalId}
                            </p>
                          </div>
                          <div className="min-w-0">
                            <p className="truncate text-xs font-medium text-[var(--color-text-secondary)]">
                              {event.safeFieldNames.join(', ') ||
                                t('erp.guardedUpdateRecovery.values.noFields')}
                            </p>
                            <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                              {t('erp.guardedUpdateRecovery.values.diffAndSnapshot', {
                                diff: event.fieldDiffCount,
                                snapshot: event.rollbackSnapshotRequired
                                  ? t('erp.guardedUpdateRecovery.values.yes')
                                  : t('erp.guardedUpdateRecovery.values.no'),
                              })}
                            </p>
                          </div>
                          <div className="md:justify-self-end">
                            <StatusPill tone={event.canonicalWrite ? 'success' : 'neutral'}>
                              {event.canonicalWrite
                                ? t('erp.guardedUpdateRecovery.values.canonicalWrite')
                                : t('erp.guardedUpdateRecovery.values.noWrite')}
                            </StatusPill>
                          </div>
                        </li>
                      ))
                    ) : (
                      <li className="p-4 text-sm text-[var(--color-text-muted)]">
                        {t('erp.guardedUpdateRecovery.empty')}
                      </li>
                    )}
                  </ul>
                </div>

                <div className="mt-4 flex items-start gap-3 rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-4 py-3">
                  <Info
                    className="mt-0.5 h-4 w-4 shrink-0 text-[var(--color-primary)]"
                    aria-hidden
                  />
                  <p className="text-xs leading-relaxed text-[var(--color-text-muted)]">
                    {t('erp.guardedUpdateRecovery.boundaryNote')}
                  </p>
                </div>
              </div>
            </section>

            <section id="erp-guarded-update-recovery-runbook" className="mt-8 scroll-mt-6">
              <SectionHeader
                title={t('erp.sections.guardedUpdateRecoveryRunbook')}
                description={t('erp.sections.guardedUpdateRecoveryRunbookDescription')}
              />
              <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
                <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <h2 className="text-lg font-semibold text-[var(--color-text-primary)]">
                        {t(data.guardedUpdateRecoveryRunbook.statusLabelKey)}
                      </h2>
                      <StatusPill tone={readinessTone(data.guardedUpdateRecoveryRunbook.readiness)}>
                        {t(`erp.readinessStatus.${data.guardedUpdateRecoveryRunbook.readiness}`)}
                      </StatusPill>
                      <StatusPill tone="neutral">
                        {t('erp.guardedUpdateRecoveryRunbook.previewClosed')}
                      </StatusPill>
                      <StatusPill tone="neutral">
                        {t('erp.guardedUpdateRecoveryRunbook.executionClosed')}
                      </StatusPill>
                    </div>
                    <p className="mt-2 max-w-2xl text-sm leading-relaxed text-[var(--color-text-muted)]">
                      {t(data.guardedUpdateRecoveryRunbook.descriptionKey)}
                    </p>
                    <p className="mt-3 text-xs leading-relaxed text-[var(--color-text-secondary)]">
                      {t(data.guardedUpdateRecoveryRunbook.actionDescriptionKey)}
                    </p>
                  </div>
                  <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-4 py-3 text-xs text-[var(--color-text-muted)] lg:max-w-sm">
                    {t('erp.guardedUpdateRecoveryRunbook.nextAction', {
                      value:
                        data.guardedUpdateRecoveryRunbook.nextActionKey ??
                        t('erp.guardedUpdateRecoveryRunbook.values.noAction'),
                    })}
                  </div>
                </div>

                <div className="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
                  <div className="rounded-lg bg-[var(--color-bg-surface)] px-4 py-3">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateRecoveryRunbook.metrics.candidate')}
                    </p>
                    <p className="mt-2 text-sm font-semibold text-[var(--color-text-primary)]">
                      {data.guardedUpdateRecoveryRunbook.rollbackPreviewCandidate
                        ? t('erp.guardedUpdateRecoveryRunbook.values.yes')
                        : t('erp.guardedUpdateRecoveryRunbook.values.no')}
                    </p>
                    <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateRecoveryRunbook.values.previewStillClosed')}
                    </p>
                  </div>
                  <div className="rounded-lg bg-[var(--color-bg-surface)] px-4 py-3">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateRecoveryRunbook.metrics.blockers')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {data.guardedUpdateRecoveryRunbook.blockerCodes.length}
                    </p>
                    <p className="mt-1 truncate text-xs text-[var(--color-text-muted)]">
                      {data.guardedUpdateRecoveryRunbook.blockerCodes.join(', ') ||
                        t('erp.guardedUpdateRecoveryRunbook.values.noBlockers')}
                    </p>
                  </div>
                  <div className="rounded-lg bg-[var(--color-bg-surface)] px-4 py-3">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateRecoveryRunbook.metrics.evidence')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {data.guardedUpdateRecoveryRunbook.summary.objectEventCount}/
                      {data.guardedUpdateRecoveryRunbook.summary.fieldDiffCount}/
                      {data.guardedUpdateRecoveryRunbook.summary.rollbackReadyCount}
                    </p>
                    <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateRecoveryRunbook.values.eventDiffSnapshot')}
                    </p>
                  </div>
                  <div className="rounded-lg bg-[var(--color-bg-surface)] px-4 py-3">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateRecoveryRunbook.metrics.approval')}
                    </p>
                    <p className="mt-2 text-sm font-semibold text-[var(--color-text-primary)]">
                      {data.guardedUpdateRecoveryRunbook.approvalRequired
                        ? t('erp.guardedUpdateRecoveryRunbook.values.required')
                        : t('erp.guardedUpdateRecoveryRunbook.values.notRequired')}
                    </p>
                    <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateRecoveryRunbook.values.operatorReviewRequired')}
                    </p>
                  </div>
                </div>

                <div className="mt-4 overflow-hidden rounded-lg border border-[var(--color-border)]">
                  <div className="grid gap-2 border-b border-[var(--color-border)] bg-[var(--color-bg-surface)] px-4 py-3 text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)] md:grid-cols-[1fr_120px_120px_1fr]">
                    <span>{t('erp.guardedUpdateRecoveryRunbook.columns.step')}</span>
                    <span>{t('erp.guardedUpdateRecoveryRunbook.columns.status')}</span>
                    <span>{t('erp.guardedUpdateRecoveryRunbook.columns.evidence')}</span>
                    <span>{t('erp.guardedUpdateRecoveryRunbook.columns.nextAction')}</span>
                  </div>
                  <ul className="divide-y divide-[var(--color-border)]">
                    {data.guardedUpdateRecoveryRunbook.safeSteps.length > 0 ? (
                      data.guardedUpdateRecoveryRunbook.safeSteps.map((step) => (
                        <li
                          key={step.stepKey}
                          className="grid gap-2 px-4 py-3 md:grid-cols-[1fr_120px_120px_1fr] md:items-center"
                        >
                          <div className="min-w-0">
                            <p className="truncate text-sm font-semibold text-[var(--color-text-primary)]">
                              {t(step.labelKey)}
                            </p>
                            {step.blockerCode ? (
                              <p className="mt-1 truncate text-xs text-[var(--color-text-muted)]">
                                {step.blockerCode}
                              </p>
                            ) : null}
                          </div>
                          <div>
                            <StatusPill
                              tone={
                                step.stepStatus === 'verified' || step.stepStatus === 'candidate'
                                  ? 'success'
                                  : step.stepStatus === 'blocked'
                                    ? 'danger'
                                    : 'neutral'
                              }
                            >
                              {t(step.statusLabelKey)}
                            </StatusPill>
                          </div>
                          <div className="font-mono text-sm text-[var(--color-text-muted)]">
                            {step.evidenceCount}/{step.requiredCount}
                          </div>
                          <div className="truncate text-xs text-[var(--color-text-muted)]">
                            {step.nextActionKey ??
                              t('erp.guardedUpdateRecoveryRunbook.values.noAction')}
                          </div>
                        </li>
                      ))
                    ) : (
                      <li className="p-4 text-sm text-[var(--color-text-muted)]">
                        {t('erp.guardedUpdateRecoveryRunbook.empty')}
                      </li>
                    )}
                  </ul>
                </div>

                <div className="mt-4 flex items-start gap-3 rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-4 py-3">
                  <Info
                    className="mt-0.5 h-4 w-4 shrink-0 text-[var(--color-primary)]"
                    aria-hidden
                  />
                  <p className="text-xs leading-relaxed text-[var(--color-text-muted)]">
                    {t('erp.guardedUpdateRecoveryRunbook.boundaryNote')}
                  </p>
                </div>
              </div>
            </section>

            <section id="erp-guarded-update-rollback-preview" className="mt-8 scroll-mt-6">
              <SectionHeader
                title={t('erp.sections.guardedUpdateRollbackPreview')}
                description={t('erp.sections.guardedUpdateRollbackPreviewDescription')}
              />
              <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
                <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <h2 className="text-lg font-semibold text-[var(--color-text-primary)]">
                        {t(data.guardedUpdateRollbackPreview.statusLabelKey)}
                      </h2>
                      <StatusPill tone={readinessTone(data.guardedUpdateRollbackPreview.readiness)}>
                        {t(`erp.readinessStatus.${data.guardedUpdateRollbackPreview.readiness}`)}
                      </StatusPill>
                      <StatusPill tone="success">
                        {t('erp.guardedUpdateRollbackPreview.previewOpen')}
                      </StatusPill>
                      <StatusPill tone="neutral">
                        {t('erp.guardedUpdateRollbackPreview.executionClosed')}
                      </StatusPill>
                    </div>
                    <p className="mt-2 max-w-2xl text-sm leading-relaxed text-[var(--color-text-muted)]">
                      {t(data.guardedUpdateRollbackPreview.descriptionKey)}
                    </p>
                    <p className="mt-3 text-xs leading-relaxed text-[var(--color-text-secondary)]">
                      {t(data.guardedUpdateRollbackPreview.actionDescriptionKey)}
                    </p>
                  </div>
                  <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-4 py-3 text-xs text-[var(--color-text-muted)] lg:max-w-sm">
                    {t('erp.guardedUpdateRollbackPreview.nextAction', {
                      value:
                        data.guardedUpdateRollbackPreview.nextActionKey ??
                        t('erp.guardedUpdateRollbackPreview.values.noAction'),
                    })}
                  </div>
                </div>

                <div className="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
                  <div className="rounded-lg bg-[var(--color-bg-surface)] px-4 py-3">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateRollbackPreview.metrics.rows')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {data.guardedUpdateRollbackPreview.summary.rollbackCount}/
                      {data.guardedUpdateRollbackPreview.summary.rowCount}
                    </p>
                    <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateRollbackPreview.values.rollbackRows')}
                    </p>
                  </div>
                  <div className="rounded-lg bg-[var(--color-bg-surface)] px-4 py-3">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateRollbackPreview.metrics.blockers')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {data.guardedUpdateRollbackPreview.summary.blockedCount}
                    </p>
                    <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                      {data.guardedUpdateRollbackPreview.summary.staleBlockedCount > 0
                        ? t('erp.guardedUpdateRollbackPreview.values.driftDetected')
                        : t('erp.guardedUpdateRollbackPreview.values.noDrift')}
                    </p>
                  </div>
                  <div className="rounded-lg bg-[var(--color-bg-surface)] px-4 py-3">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateRollbackPreview.metrics.evidence')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {data.guardedUpdateRollbackPreview.summary.fieldDiffCount}/
                      {data.guardedUpdateRollbackPreview.summary.rollbackSnapshotCount}
                    </p>
                    <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateRollbackPreview.values.diffSnapshot')}
                    </p>
                  </div>
                  <div className="rounded-lg bg-[var(--color-bg-surface)] px-4 py-3">
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateRollbackPreview.metrics.approval')}
                    </p>
                    <p className="mt-2 text-sm font-semibold text-[var(--color-text-primary)]">
                      {data.guardedUpdateRollbackPreview.approvalRequired
                        ? t('erp.guardedUpdateRollbackPreview.values.required')
                        : t('erp.guardedUpdateRollbackPreview.values.notRequired')}
                    </p>
                    <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateRollbackPreview.values.operatorReviewRequired')}
                    </p>
                  </div>
                </div>

                <div className="mt-4 overflow-hidden rounded-lg border border-[var(--color-border)]">
                  <div className="grid gap-2 border-b border-[var(--color-border)] bg-[var(--color-bg-surface)] px-4 py-3 text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)] md:grid-cols-[1fr_120px_140px_1fr]">
                    <span>{t('erp.guardedUpdateRollbackPreview.columns.target')}</span>
                    <span>{t('erp.guardedUpdateRollbackPreview.columns.status')}</span>
                    <span>{t('erp.guardedUpdateRollbackPreview.columns.evidence')}</span>
                    <span>{t('erp.guardedUpdateRollbackPreview.columns.blockers')}</span>
                  </div>
                  <ul className="divide-y divide-[var(--color-border)]">
                    {data.guardedUpdateRollbackPreview.sampleItems.length > 0 ? (
                      data.guardedUpdateRollbackPreview.sampleItems.map((item) => (
                        <li
                          key={item.id}
                          className="grid gap-2 px-4 py-3 md:grid-cols-[1fr_120px_140px_1fr] md:items-center"
                        >
                          <div className="min-w-0">
                            <p className="truncate text-sm font-semibold text-[var(--color-text-primary)]">
                              {item.entityType} · {item.externalId}
                            </p>
                            <p className="mt-1 truncate text-xs text-[var(--color-text-muted)]">
                              {item.targetTable} ·{' '}
                              {item.rollbackFieldNames.join(', ') ||
                                t('erp.guardedUpdateRollbackPreview.values.noFields')}
                            </p>
                          </div>
                          <div>
                            <StatusPill tone={item.itemStatus === 'ready' ? 'success' : 'danger'}>
                              {t(`erp.guardedUpdateRollbackPreview.itemStatus.${item.itemStatus}`)}
                            </StatusPill>
                          </div>
                          <div className="text-xs text-[var(--color-text-muted)]">
                            <p className="font-mono">
                              {item.fieldDiffCount}/
                              {item.rollbackSnapshotAvailable
                                ? t('erp.guardedUpdateRollbackPreview.values.yes')
                                : t('erp.guardedUpdateRollbackPreview.values.no')}
                            </p>
                            <p className="mt-1">
                              {item.currentStateMatchesApply
                                ? t('erp.guardedUpdateRollbackPreview.values.currentMatch')
                                : t('erp.guardedUpdateRollbackPreview.values.currentMismatch')}
                            </p>
                          </div>
                          <div className="truncate text-xs text-[var(--color-text-muted)]">
                            {item.blockerCodes.join(', ') ||
                              t('erp.guardedUpdateRollbackPreview.values.noBlockers')}
                          </div>
                        </li>
                      ))
                    ) : (
                      <li className="p-4 text-sm text-[var(--color-text-muted)]">
                        {t('erp.guardedUpdateRollbackPreview.empty')}
                      </li>
                    )}
                  </ul>
                </div>

                <div className="mt-4 flex items-start gap-3 rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-4 py-3">
                  <Info
                    className="mt-0.5 h-4 w-4 shrink-0 text-[var(--color-primary)]"
                    aria-hidden
                  />
                  <p className="text-xs leading-relaxed text-[var(--color-text-muted)]">
                    {t('erp.guardedUpdateRollbackPreview.boundaryNote')}
                  </p>
                </div>

                <div
                  id="erp-guarded-update-rollback-approval"
                  className="mt-4 rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-4"
                >
                  <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                    <div className="flex items-start gap-3">
                      <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-[var(--color-primary-soft)] text-[var(--color-primary)]">
                        <ShieldCheck className="h-5 w-5" aria-hidden />
                      </span>
                      <div className="min-w-0">
                        <div className="flex flex-wrap items-center gap-2">
                          <h3 className="text-base font-semibold text-[var(--color-text-primary)]">
                            {t(data.guardedUpdateRollbackApproval.statusLabelKey)}
                          </h3>
                          <StatusPill
                            tone={readinessTone(data.guardedUpdateRollbackApproval.readiness)}
                          >
                            {t(
                              `erp.readinessStatus.${data.guardedUpdateRollbackApproval.readiness}`,
                            )}
                          </StatusPill>
                          <StatusPill tone="neutral">
                            {t('erp.guardedUpdateRollbackApproval.executionClosed')}
                          </StatusPill>
                        </div>
                        <p className="mt-2 max-w-2xl text-sm leading-relaxed text-[var(--color-text-muted)]">
                          {t(data.guardedUpdateRollbackApproval.descriptionKey)}
                        </p>
                        <p className="mt-2 text-xs leading-relaxed text-[var(--color-text-secondary)]">
                          {t(data.guardedUpdateRollbackApproval.actionDescriptionKey)}
                        </p>
                        {data.guardedUpdateRollbackApproval.approvedAt ? (
                          <p className="mt-2 text-xs text-[var(--color-text-muted)]">
                            {t('erp.guardedUpdateRollbackApproval.approvedAt', {
                              value: formatDateTime(
                                data.guardedUpdateRollbackApproval.approvedAt,
                                i18n.language,
                                t('erp.credentialBoundary.notRecorded'),
                              ),
                            })}
                          </p>
                        ) : null}
                      </div>
                    </div>
                    <Button
                      type="button"
                      variant="outline"
                      className="touch-target w-full lg:w-auto"
                      disabled={
                        !canRecordRollbackApproval || recordRollbackApprovalMutation.isPending
                      }
                      onClick={() => void recordRollbackApprovalMutation.mutateAsync()}
                    >
                      <ShieldCheck
                        className={cn(
                          'h-4 w-4',
                          recordRollbackApprovalMutation.isPending ? 'animate-pulse' : null,
                        )}
                      />
                      {canRecordRollbackApproval
                        ? recordRollbackApprovalMutation.isPending
                          ? t('erp.guardedUpdateRollbackApproval.recording')
                          : t(data.guardedUpdateRollbackApproval.actionLabelKey)
                        : !canManageConnectors &&
                            data.guardedUpdateRollbackApproval.action === 'record_admin_approval'
                          ? t('erp.guardedUpdateRollbackApproval.adminRequired')
                          : t(data.guardedUpdateRollbackApproval.actionLabelKey)}
                    </Button>
                  </div>

                  <div className="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
                    <div>
                      <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                        {t('erp.guardedUpdateRollbackApproval.metrics.rows')}
                      </p>
                      <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                        {data.guardedUpdateRollbackApproval.summary.rollbackCount}/
                        {data.guardedUpdateRollbackApproval.summary.rowCount}
                      </p>
                    </div>
                    <div>
                      <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                        {t('erp.guardedUpdateRollbackApproval.metrics.blockers')}
                      </p>
                      <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                        {data.guardedUpdateRollbackApproval.summary.blockedCount}
                      </p>
                    </div>
                    <div>
                      <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                        {t('erp.guardedUpdateRollbackApproval.metrics.evidence')}
                      </p>
                      <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                        {data.guardedUpdateRollbackApproval.summary.fieldDiffCount}/
                        {data.guardedUpdateRollbackApproval.summary.rollbackSnapshotCount}
                      </p>
                    </div>
                    <div>
                      <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                        {t('erp.guardedUpdateRollbackApproval.metrics.next')}
                      </p>
                      <p className="mt-2 truncate text-xs font-medium text-[var(--color-text-primary)]">
                        {data.guardedUpdateRollbackApproval.nextActionKey ??
                          t('erp.guardedUpdateRollbackApproval.values.noAction')}
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </section>

            <section id="erp-guarded-update-rollback-worker-readiness" className="mt-8 scroll-mt-6">
              <SectionHeader
                title={t('erp.sections.guardedUpdateRollbackWorkerReadiness')}
                description={t('erp.sections.guardedUpdateRollbackWorkerReadinessDescription')}
              />
              <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
                <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                  <div className="min-w-0">
                    <div className="flex items-start gap-3">
                      <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-[var(--color-primary-soft)] text-[var(--color-primary)]">
                        <ClipboardCheck className="h-5 w-5" aria-hidden />
                      </span>
                      <div className="min-w-0">
                        <div className="flex flex-wrap items-center gap-2">
                          <h2 className="text-lg font-semibold text-[var(--color-text-primary)]">
                            {t(data.guardedUpdateRollbackWorkerReadiness.statusLabelKey)}
                          </h2>
                          <StatusPill
                            tone={readinessTone(
                              data.guardedUpdateRollbackWorkerReadiness.readiness,
                            )}
                          >
                            {t(
                              `erp.readinessStatus.${data.guardedUpdateRollbackWorkerReadiness.readiness}`,
                            )}
                          </StatusPill>
                          <StatusPill tone="neutral">
                            {t('erp.guardedUpdateRollbackWorkerReadiness.rollbackJobClosed')}
                          </StatusPill>
                          <StatusPill tone="neutral">
                            {t('erp.guardedUpdateRollbackWorkerReadiness.executionClosed')}
                          </StatusPill>
                        </div>
                        <p className="mt-2 max-w-2xl text-sm leading-relaxed text-[var(--color-text-muted)]">
                          {t(data.guardedUpdateRollbackWorkerReadiness.descriptionKey)}
                        </p>
                        <p className="mt-2 text-xs leading-relaxed text-[var(--color-text-secondary)]">
                          {t(data.guardedUpdateRollbackWorkerReadiness.actionDescriptionKey)}
                        </p>
                        {data.guardedUpdateRollbackWorkerReadiness.createdAt ? (
                          <p className="mt-2 text-xs text-[var(--color-text-muted)]">
                            {t('erp.guardedUpdateRollbackWorkerReadiness.createdAt', {
                              value: formatDateTime(
                                data.guardedUpdateRollbackWorkerReadiness.createdAt,
                                i18n.language,
                                t('erp.credentialBoundary.notRecorded'),
                              ),
                            })}
                          </p>
                        ) : null}
                      </div>
                    </div>
                  </div>
                  <Button
                    type="button"
                    variant="outline"
                    className="touch-target w-full lg:w-auto"
                    disabled={
                      !canRequestRollbackWorkerReadiness ||
                      requestRollbackWorkerReadinessMutation.isPending
                    }
                    onClick={() => void requestRollbackWorkerReadinessMutation.mutateAsync()}
                  >
                    <ClipboardCheck
                      className={cn(
                        'h-4 w-4',
                        requestRollbackWorkerReadinessMutation.isPending ? 'animate-pulse' : null,
                      )}
                    />
                    {canRequestRollbackWorkerReadiness
                      ? requestRollbackWorkerReadinessMutation.isPending
                        ? t('erp.guardedUpdateRollbackWorkerReadiness.generating')
                        : t(data.guardedUpdateRollbackWorkerReadiness.actionLabelKey)
                      : !canManageConnectors &&
                          data.guardedUpdateRollbackWorkerReadiness.action === 'generate_readiness'
                        ? t('erp.guardedUpdateRollbackWorkerReadiness.adminRequired')
                        : t(data.guardedUpdateRollbackWorkerReadiness.actionLabelKey)}
                  </Button>
                </div>

                <div className="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
                  <div>
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateRollbackWorkerReadiness.metrics.rows')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {data.guardedUpdateRollbackWorkerReadiness.summary.rollbackCount}/
                      {data.guardedUpdateRollbackWorkerReadiness.summary.rowCount}
                    </p>
                  </div>
                  <div>
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateRollbackWorkerReadiness.metrics.currentState')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {data.guardedUpdateRollbackWorkerReadiness.summary.currentStateVerifiedCount}
                    </p>
                  </div>
                  <div>
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateRollbackWorkerReadiness.metrics.evidence')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {data.guardedUpdateRollbackWorkerReadiness.summary.fieldDiffCount}/
                      {data.guardedUpdateRollbackWorkerReadiness.summary.rollbackSnapshotCount}
                    </p>
                  </div>
                  <div>
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateRollbackWorkerReadiness.metrics.next')}
                    </p>
                    <p className="mt-2 truncate text-xs font-medium text-[var(--color-text-primary)]">
                      {data.guardedUpdateRollbackWorkerReadiness.nextActionKey ??
                        t('erp.guardedUpdateRollbackWorkerReadiness.values.noAction')}
                    </p>
                  </div>
                </div>

                <div className="mt-4 overflow-hidden rounded-lg border border-[var(--color-border)]">
                  <div className="grid gap-2 border-b border-[var(--color-border)] bg-[var(--color-bg-surface)] px-4 py-3 text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)] md:grid-cols-[72px_1fr_1fr_150px]">
                    <span>{t('erp.guardedUpdateRollbackWorkerReadiness.columns.row')}</span>
                    <span>{t('erp.guardedUpdateRollbackWorkerReadiness.columns.target')}</span>
                    <span>{t('erp.guardedUpdateRollbackWorkerReadiness.columns.evidence')}</span>
                    <span className="md:text-right">
                      {t('erp.guardedUpdateRollbackWorkerReadiness.columns.boundary')}
                    </span>
                  </div>
                  <ul className="divide-y divide-[var(--color-border)]">
                    {data.guardedUpdateRollbackWorkerReadiness.sampleItems.length > 0 ? (
                      data.guardedUpdateRollbackWorkerReadiness.sampleItems.map((item) => (
                        <li
                          key={`${item.rowNumber}-${item.externalId}`}
                          className="grid gap-2 px-4 py-3 md:grid-cols-[72px_1fr_1fr_150px] md:items-center"
                        >
                          <div className="font-mono text-sm text-[var(--color-text-muted)]">
                            #{item.rowNumber}
                          </div>
                          <div className="min-w-0">
                            <p className="truncate font-mono text-sm font-semibold text-[var(--color-text-primary)]">
                              {item.entityType}
                            </p>
                            <p className="mt-1 truncate text-xs text-[var(--color-text-muted)]">
                              {item.targetTable} · {item.externalId}
                            </p>
                          </div>
                          <div className="min-w-0">
                            <p className="truncate text-xs font-medium text-[var(--color-text-secondary)]">
                              {item.rollbackFieldNames.join(', ') ||
                                t('erp.guardedUpdateRollbackWorkerReadiness.values.noFields')}
                            </p>
                            <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                              {t('erp.guardedUpdateRollbackWorkerReadiness.values.itemEvidence', {
                                event: item.originalApplyEventCount,
                                diff: item.fieldDiffCount,
                              })}
                            </p>
                          </div>
                          <div className="md:justify-self-end">
                            <StatusPill
                              tone={
                                item.currentStateMatchesApply &&
                                item.rollbackSnapshotAvailable &&
                                !item.rollbackExecution
                                  ? 'success'
                                  : 'danger'
                              }
                            >
                              {item.currentStateMatchesApply && item.rollbackSnapshotAvailable
                                ? t('erp.guardedUpdateRollbackWorkerReadiness.values.ready')
                                : t('erp.guardedUpdateRollbackWorkerReadiness.values.blocked')}
                            </StatusPill>
                          </div>
                        </li>
                      ))
                    ) : (
                      <li className="p-4 text-sm text-[var(--color-text-muted)]">
                        {t('erp.guardedUpdateRollbackWorkerReadiness.empty')}
                      </li>
                    )}
                  </ul>
                </div>
              </div>
            </section>

            <section id="erp-guarded-update-rollback-worker-apply" className="mt-8 scroll-mt-6">
              <SectionHeader
                title={t('erp.sections.guardedUpdateRollbackWorkerApply')}
                description={t('erp.sections.guardedUpdateRollbackWorkerApplyDescription')}
              />
              <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
                <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                  <div className="min-w-0">
                    <div className="flex items-start gap-3">
                      <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-[var(--color-primary-soft)] text-[var(--color-primary)]">
                        <RefreshCw className="h-5 w-5" aria-hidden />
                      </span>
                      <div className="min-w-0">
                        <div className="flex flex-wrap items-center gap-2">
                          <h2 className="text-lg font-semibold text-[var(--color-text-primary)]">
                            {data.guardedUpdateRollbackWorkerReadiness.workerHandoffReady
                              ? t('erp.guardedUpdateRollbackWorkerApply.status.ready')
                              : t('erp.guardedUpdateRollbackWorkerApply.status.waiting')}
                          </h2>
                          <StatusPill
                            tone={
                              data.guardedUpdateRollbackWorkerReadiness.workerHandoffReady
                                ? 'success'
                                : 'neutral'
                            }
                          >
                            {data.guardedUpdateRollbackWorkerReadiness.workerHandoffReady
                              ? t('erp.guardedUpdateRollbackWorkerApply.values.workerReady')
                              : t('erp.guardedUpdateRollbackWorkerApply.values.workerWaiting')}
                          </StatusPill>
                          <StatusPill tone="success">
                            {t('erp.guardedUpdateRollbackWorkerApply.values.workerOnly')}
                          </StatusPill>
                          <StatusPill tone="neutral">
                            {t('erp.guardedUpdateRollbackWorkerApply.values.sourceClosed')}
                          </StatusPill>
                        </div>
                        <p className="mt-2 max-w-2xl text-sm leading-relaxed text-[var(--color-text-muted)]">
                          {data.guardedUpdateRollbackWorkerReadiness.workerHandoffReady
                            ? t('erp.guardedUpdateRollbackWorkerApply.descriptions.ready')
                            : t('erp.guardedUpdateRollbackWorkerApply.descriptions.waiting')}
                        </p>
                        <p className="mt-2 text-xs leading-relaxed text-[var(--color-text-secondary)]">
                          {t('erp.guardedUpdateRollbackWorkerApply.description')}
                        </p>
                      </div>
                    </div>
                  </div>
                  <Button
                    type="button"
                    variant="outline"
                    className="touch-target w-full lg:w-auto"
                    disabled={!canRequestRollbackApplyJob || requestRollbackApplyPending}
                    onClick={() => void requestRollbackApplyJobMutation.mutateAsync()}
                  >
                    <RefreshCw
                      className={cn('h-4 w-4', requestRollbackApplyPending ? 'animate-spin' : null)}
                    />
                    {canRequestRollbackApplyJob
                      ? requestRollbackApplyPending
                        ? t('erp.guardedUpdateRollbackWorkerApply.queueing')
                        : t('erp.guardedUpdateRollbackWorkerApply.actions.queue')
                      : !canManageConnectors &&
                          data.guardedUpdateRollbackWorkerReadiness.workerHandoffReady
                        ? t('erp.guardedUpdateRollbackWorkerApply.adminRequired')
                        : t('erp.guardedUpdateRollbackWorkerApply.actions.wait')}
                  </Button>
                </div>

                <div className="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
                  <div>
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateRollbackWorkerApply.metrics.rows')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {data.guardedUpdateRollbackWorkerReadiness.summary.rollbackCount}/
                      {data.guardedUpdateRollbackWorkerReadiness.summary.rowCount}
                    </p>
                  </div>
                  <div>
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateRollbackWorkerApply.metrics.currentState')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {data.guardedUpdateRollbackWorkerReadiness.summary.currentStateVerifiedCount}
                    </p>
                  </div>
                  <div>
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateRollbackWorkerApply.metrics.snapshots')}
                    </p>
                    <p className="mt-2 font-mono text-lg font-semibold text-[var(--color-text-primary)]">
                      {data.guardedUpdateRollbackWorkerReadiness.summary.rollbackSnapshotCount}
                    </p>
                  </div>
                  <div>
                    <p className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                      {t('erp.guardedUpdateRollbackWorkerApply.metrics.next')}
                    </p>
                    <p className="mt-2 truncate text-xs font-medium text-[var(--color-text-primary)]">
                      {data.guardedUpdateRollbackWorkerReadiness.workerHandoffReady
                        ? 'wait_for_guarded_update_rollback_worker_apply'
                        : (data.guardedUpdateRollbackWorkerReadiness.nextActionKey ??
                          t('erp.guardedUpdateRollbackWorkerApply.values.noAction'))}
                    </p>
                  </div>
                </div>
              </div>
            </section>

            <section id="erp-controlled-apply" className="mt-8 scroll-mt-6">
              <SectionHeader
                title={t('erp.sections.controlledApply')}
                description={t('erp.sections.controlledApplyDescription')}
              />
              <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
                <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <h2 className="text-lg font-semibold text-[var(--color-text-primary)]">
                        {t(data.controlledApplyPlan.statusLabelKey)}
                      </h2>
                      <StatusPill tone={readinessTone(data.controlledApplyPlan.readiness)}>
                        {t(`erp.readinessStatus.${data.controlledApplyPlan.readiness}`)}
                      </StatusPill>
                      <StatusPill tone="neutral">
                        {t('erp.controlledApply.executionClosed')}
                      </StatusPill>
                    </div>
                    <p className="mt-2 max-w-2xl text-sm leading-relaxed text-[var(--color-text-muted)]">
                      {t(data.controlledApplyPlan.descriptionKey)}
                    </p>
                  </div>
                  <div className="grid grid-cols-3 gap-2 text-center sm:min-w-72">
                    <div className="rounded-lg bg-[var(--color-bg-surface)] px-3 py-2">
                      <p className="font-mono text-lg font-semibold text-[var(--color-success)]">
                        {data.controlledApplyPlan.summary.readyCount}
                      </p>
                      <p className="text-[10px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                        {t('erp.controlledApply.metrics.ready')}
                      </p>
                    </div>
                    <div className="rounded-lg bg-[var(--color-bg-surface)] px-3 py-2">
                      <p className="font-mono text-lg font-semibold text-[var(--color-warning)]">
                        {data.controlledApplyPlan.summary.partialCount}
                      </p>
                      <p className="text-[10px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                        {t('erp.controlledApply.metrics.partial')}
                      </p>
                    </div>
                    <div className="rounded-lg bg-[var(--color-bg-surface)] px-3 py-2">
                      <p className="font-mono text-lg font-semibold text-[var(--color-danger)]">
                        {data.controlledApplyPlan.summary.blockedCount}
                      </p>
                      <p className="text-[10px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                        {t('erp.controlledApply.metrics.blocked')}
                      </p>
                    </div>
                  </div>
                </div>

                <div className="mt-4 rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-4">
                  <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                    <div className="flex items-start gap-3">
                      <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-[var(--color-primary-soft)] text-[var(--color-primary)]">
                        <ShieldCheck className="h-5 w-5" aria-hidden />
                      </span>
                      <div className="min-w-0">
                        <div className="flex flex-wrap items-center gap-2">
                          <h3 className="text-base font-semibold text-[var(--color-text-primary)]">
                            {t(data.applyApprovalPolicy.statusLabelKey)}
                          </h3>
                          <StatusPill tone={readinessTone(data.applyApprovalPolicy.readiness)}>
                            {t(`erp.readinessStatus.${data.applyApprovalPolicy.readiness}`)}
                          </StatusPill>
                          <StatusPill tone="neutral">
                            {t(data.applyApprovalPolicy.approverRoleKey)}
                          </StatusPill>
                        </div>
                        <p className="mt-2 max-w-2xl text-sm leading-relaxed text-[var(--color-text-muted)]">
                          {t(data.applyApprovalPolicy.descriptionKey)}
                        </p>
                        <p className="mt-2 text-xs leading-relaxed text-[var(--color-text-secondary)]">
                          {t(data.applyApprovalPolicy.actionDescriptionKey)}
                        </p>
                        {data.applyApprovalPolicy.approvalRecordedAt ? (
                          <p className="mt-2 text-xs text-[var(--color-text-muted)]">
                            {t('erp.applyApprovalPolicy.approvalRecordedAt', {
                              value: formatDateTime(
                                data.applyApprovalPolicy.approvalRecordedAt,
                                i18n.language,
                                t('erp.credentialBoundary.notRecorded'),
                              ),
                            })}
                          </p>
                        ) : null}
                      </div>
                    </div>
                    <Button
                      type="button"
                      variant="outline"
                      className="touch-target w-full lg:w-auto"
                      disabled={!canRecordApplyApproval || recordApplyApprovalMutation.isPending}
                      onClick={() => void recordApplyApprovalMutation.mutateAsync()}
                    >
                      <ShieldCheck
                        className={cn(
                          'h-4 w-4',
                          recordApplyApprovalMutation.isPending ? 'animate-pulse' : null,
                        )}
                      />
                      {canRecordApplyApproval
                        ? recordApplyApprovalMutation.isPending
                          ? t('erp.applyApprovalPolicy.recording')
                          : t(data.applyApprovalPolicy.actionLabelKey)
                        : !canManageConnectors &&
                            data.applyApprovalPolicy.action === 'record_admin_approval'
                          ? t('erp.applyApprovalPolicy.adminRequired')
                          : t(data.applyApprovalPolicy.actionLabelKey)}
                    </Button>
                  </div>
                </div>

                <div className="mt-4 rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-4">
                  <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                    <div className="flex items-start gap-3">
                      <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-[var(--color-primary-soft)] text-[var(--color-primary)]">
                        <ClipboardCheck className="h-5 w-5" aria-hidden />
                      </span>
                      <div className="min-w-0">
                        <div className="flex flex-wrap items-center gap-2">
                          <h3 className="text-base font-semibold text-[var(--color-text-primary)]">
                            {t(data.applyExecutionContract.statusLabelKey)}
                          </h3>
                          <StatusPill tone={readinessTone(data.applyExecutionContract.readiness)}>
                            {t(`erp.readinessStatus.${data.applyExecutionContract.readiness}`)}
                          </StatusPill>
                          <StatusPill
                            tone={data.applyExecutionContract.safeToExecute ? 'success' : 'neutral'}
                          >
                            {data.applyExecutionContract.safeToExecute
                              ? t(
                                  data.applyExecutionContract.executorMode ===
                                    'worker_guarded_update_job'
                                    ? 'erp.applyExecutionContract.guardedUpdateWorkerReady'
                                    : 'erp.applyExecutionContract.createOnlyWorkerReady',
                                )
                              : t('erp.applyExecutionContract.executionDisabled')}
                          </StatusPill>
                        </div>
                        <p className="mt-2 max-w-2xl text-sm leading-relaxed text-[var(--color-text-muted)]">
                          {t(data.applyExecutionContract.descriptionKey)}
                        </p>
                      </div>
                    </div>
                    <div className="flex flex-col gap-3 sm:min-w-80">
                      <Button
                        type="button"
                        variant={canRequestApplyExecutionJob ? 'default' : 'outline'}
                        className="touch-target w-full"
                        disabled={!canRequestApplyExecutionJob || requestApplyExecutionPending}
                        onClick={() => {
                          if (canRequestGuardedUpdateApplyJob) {
                            void requestGuardedUpdateApplyJobMutation.mutateAsync()
                            return
                          }
                          void requestCreateOnlyApplyJobMutation.mutateAsync()
                        }}
                      >
                        <Database
                          className={cn(
                            'h-4 w-4',
                            requestApplyExecutionPending ? 'animate-pulse' : null,
                          )}
                        />
                        {canRequestApplyExecutionJob
                          ? requestApplyExecutionPending
                            ? t(
                                canRequestGuardedUpdateApplyJob
                                  ? 'erp.applyExecutionContract.actions.enqueueGuardedUpdate.queuing'
                                  : 'erp.applyExecutionContract.actions.enqueueCreateOnly.queuing',
                              )
                            : t(
                                canRequestGuardedUpdateApplyJob
                                  ? 'erp.applyExecutionContract.actions.enqueueGuardedUpdate.label'
                                  : 'erp.applyExecutionContract.actions.enqueueCreateOnly.label',
                              )
                          : !canManageConnectors
                            ? t(
                                data.applyExecutionContract.executorMode ===
                                  'worker_guarded_update_job'
                                  ? 'erp.applyExecutionContract.actions.enqueueGuardedUpdate.adminRequired'
                                  : 'erp.applyExecutionContract.actions.enqueueCreateOnly.adminRequired',
                              )
                            : t(
                                data.applyExecutionContract.executorMode ===
                                  'worker_guarded_update_job'
                                  ? 'erp.applyExecutionContract.actions.enqueueGuardedUpdate.blocked'
                                  : 'erp.applyExecutionContract.actions.enqueueCreateOnly.blocked',
                              )}
                      </Button>
                      <div className="grid grid-cols-2 gap-2 text-left">
                        <div className="rounded-md bg-[var(--color-bg-card)] px-3 py-2">
                          <p className="text-[10px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                            {t('erp.applyExecutionContract.metrics.executor')}
                          </p>
                          <p className="mt-1 text-xs font-semibold text-[var(--color-text-primary)]">
                            {t(
                              data.applyExecutionContract.executorMode === 'worker_create_only_job'
                                ? 'erp.applyExecutionContract.values.workerCreateOnlyJob'
                                : data.applyExecutionContract.executorMode ===
                                    'worker_guarded_update_job'
                                  ? 'erp.applyExecutionContract.values.workerGuardedUpdateJob'
                                  : 'erp.applyExecutionContract.values.futureJob',
                            )}
                          </p>
                        </div>
                        <div className="rounded-md bg-[var(--color-bg-card)] px-3 py-2">
                          <p className="text-[10px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                            {t('erp.applyExecutionContract.metrics.applyRpc')}
                          </p>
                          <p className="mt-1 text-xs font-semibold text-[var(--color-text-primary)]">
                            {t(
                              data.applyExecutionContract.applyRpcExposed
                                ? 'erp.applyExecutionContract.values.rpcExposed'
                                : 'erp.applyExecutionContract.values.closed',
                            )}
                          </p>
                        </div>
                        <div className="rounded-md bg-[var(--color-bg-card)] px-3 py-2">
                          <p className="text-[10px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                            {t('erp.applyExecutionContract.metrics.canonicalWrites')}
                          </p>
                          <p className="mt-1 text-xs font-semibold text-[var(--color-text-primary)]">
                            {t(
                              data.applyExecutionContract.canonicalWriteEnabled
                                ? 'erp.applyExecutionContract.values.enabled'
                                : 'erp.applyExecutionContract.values.disabled',
                            )}
                          </p>
                        </div>
                        <div className="rounded-md bg-[var(--color-bg-card)] px-3 py-2">
                          <p className="text-[10px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                            {t('erp.applyExecutionContract.metrics.sourceWriteback')}
                          </p>
                          <p className="mt-1 text-xs font-semibold text-[var(--color-text-primary)]">
                            {t('erp.applyExecutionContract.values.disabled')}
                          </p>
                        </div>
                      </div>
                    </div>
                  </div>
                  <div className="mt-4 grid gap-2 md:grid-cols-2">
                    {data.applyExecutionContract.controls.map((control) => (
                      <div
                        key={control.id}
                        className="flex items-start justify-between gap-3 rounded-md bg-[var(--color-bg-card)] px-3 py-2"
                      >
                        <div className="min-w-0">
                          <p className="text-xs font-semibold text-[var(--color-text-primary)]">
                            {t(control.labelKey)}
                          </p>
                          <p className="mt-1 text-xs leading-relaxed text-[var(--color-text-muted)]">
                            {t(control.descriptionKey)}
                          </p>
                          <p className="mt-1 text-xs font-medium text-[var(--color-text-secondary)]">
                            {t(control.valueKey)}
                          </p>
                        </div>
                        <StatusPill tone={readinessTone(control.status)}>
                          {t(`erp.readinessStatus.${control.status}`)}
                        </StatusPill>
                      </div>
                    ))}
                  </div>
                </div>

                <div className="mt-4 grid gap-3 md:grid-cols-2">
                  {data.controlledApplyPlan.gates.map((gate) => (
                    <div
                      key={gate.id}
                      className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-3"
                    >
                      <div className="flex items-start justify-between gap-3">
                        <div className="min-w-0">
                          <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                            {t(gate.labelKey)}
                          </p>
                          <p className="mt-1 text-xs leading-relaxed text-[var(--color-text-muted)]">
                            {t(gate.descriptionKey)}
                          </p>
                        </div>
                        <StatusPill tone={readinessTone(gate.status)}>
                          {t(`erp.readinessStatus.${gate.status}`)}
                        </StatusPill>
                      </div>
                      <p className="mt-3 text-xs font-medium text-[var(--color-text-secondary)]">
                        {t(gate.valueKey)}
                      </p>
                    </div>
                  ))}
                </div>

                <div className="mt-4 flex items-start gap-3 rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-4 py-3">
                  <ShieldCheck
                    className="mt-0.5 h-4 w-4 shrink-0 text-[var(--color-primary)]"
                    aria-hidden
                  />
                  <p className="text-xs leading-relaxed text-[var(--color-text-muted)]">
                    {t('erp.controlledApply.boundaryNote')}
                  </p>
                </div>
              </div>
            </section>
          </TabsContent>

          <TabsContent value="credentials" className="mt-6">
            <section>
              <SectionHeader
                title={t('erp.sections.credentialBoundary')}
                description={t('erp.sections.credentialBoundaryDescription')}
              />
              <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
                <div className="flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
                  <div className="flex items-start gap-3">
                    <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-lg bg-[var(--color-bg-elevated)] text-[var(--color-primary)]">
                      <KeyRound className="h-5 w-5" aria-hidden />
                    </span>
                    <div className="min-w-0">
                      <div className="flex flex-wrap items-center gap-2">
                        <h2 className="text-lg font-semibold text-[var(--color-text-primary)]">
                          {t(data.credentialBoundary.statusLabelKey)}
                        </h2>
                        <StatusPill tone={readinessTone(data.credentialBoundary.status)}>
                          {t(`erp.readinessStatus.${data.credentialBoundary.status}`)}
                        </StatusPill>
                      </div>
                      <p className="mt-2 text-sm leading-relaxed text-[var(--color-text-muted)]">
                        {t(data.credentialBoundary.descriptionKey)}
                      </p>
                      <p className="mt-3 text-xs leading-relaxed text-[var(--color-text-secondary)]">
                        {t('erp.credentialBoundary.noReadback')}
                      </p>
                    </div>
                  </div>

                  <div className="grid gap-2 text-sm md:min-w-[260px]">
                    <div className="flex items-center justify-between gap-3 rounded-lg bg-[var(--color-bg-surface)] px-3 py-2">
                      <span className="text-[var(--color-text-muted)]">
                        {t('erp.credentialBoundary.authMode')}
                      </span>
                      <span className="text-right font-medium text-[var(--color-text-primary)]">
                        {t(`erp.authModes.${data.credentialBoundary.authMode}`)}
                      </span>
                    </div>
                    <div className="flex items-center justify-between gap-3 rounded-lg bg-[var(--color-bg-surface)] px-3 py-2">
                      <span className="text-[var(--color-text-muted)]">
                        {t('erp.credentialBoundary.required')}
                      </span>
                      <span className="text-right font-medium text-[var(--color-text-primary)]">
                        {t(
                          data.credentialBoundary.required
                            ? 'erp.credentialBoundary.requiredValues.yes'
                            : 'erp.credentialBoundary.requiredValues.no',
                        )}
                      </span>
                    </div>
                    <div className="flex items-center justify-between gap-3 rounded-lg bg-[var(--color-bg-surface)] px-3 py-2">
                      <span className="text-[var(--color-text-muted)]">
                        {t('erp.credentialBoundary.lastVerified')}
                      </span>
                      <span className="text-right font-medium text-[var(--color-text-primary)]">
                        {formatDateTime(
                          data.credentialBoundary.lastVerifiedAt,
                          i18n.language,
                          t('erp.credentialBoundary.notRecorded'),
                        )}
                      </span>
                    </div>
                  </div>
                </div>
                <div className="mt-4 rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-3">
                  <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                    <div className="min-w-0">
                      <div className="flex flex-wrap items-center gap-2">
                        <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                          {t(data.credentialHandoff.statusLabelKey)}
                        </p>
                        <StatusPill tone={readinessTone(data.credentialHandoff.readiness)}>
                          {t(`erp.readinessStatus.${data.credentialHandoff.readiness}`)}
                        </StatusPill>
                      </div>
                      <p className="mt-1 text-xs leading-relaxed text-[var(--color-text-muted)]">
                        {t(data.credentialHandoff.descriptionKey)}
                      </p>
                      <p className="mt-2 text-xs leading-relaxed text-[var(--color-text-secondary)]">
                        {t(data.credentialHandoff.actionDescriptionKey)}
                      </p>
                      {data.credentialHandoff.requestedAt ? (
                        <p className="mt-2 text-xs text-[var(--color-text-muted)]">
                          {t('erp.credentialHandoff.requestedAt', {
                            value: formatDateTime(
                              data.credentialHandoff.requestedAt,
                              i18n.language,
                              t('erp.credentialBoundary.notRecorded'),
                            ),
                          })}
                        </p>
                      ) : null}
                    </div>
                    <Button
                      type="button"
                      variant="outline"
                      className="touch-target w-full sm:w-auto"
                      disabled={
                        !data.credentialHandoff.requestable ||
                        !canManageConnectors ||
                        requestCredentialHandoffMutation.isPending
                      }
                      onClick={() => setCredentialSheetOpen(true)}
                    >
                      <ShieldCheck className="h-4 w-4" />
                      {canRequestCredentialHandoff
                        ? t('erp.credentialHandoff.openSheet')
                        : !canManageConnectors && data.credentialHandoff.requestable
                          ? t('erp.credentialHandoff.adminRequired')
                          : t(data.credentialHandoff.actionLabelKey)}
                    </Button>
                  </div>
                </div>
              </div>
              <SheetShell
                open={credentialSheetOpen}
                onOpenChange={setCredentialSheetOpen}
                title={t('erp.credentialHandoff.sheet.title', { source: data.provider.label })}
                description={t('erp.credentialHandoff.sheet.description')}
                footer={
                  <div className="flex w-full flex-col gap-2 sm:flex-row sm:justify-end">
                    <Button
                      type="button"
                      variant="outline"
                      className="touch-target w-full sm:w-auto"
                      onClick={() => setCredentialSheetOpen(false)}
                    >
                      {t('erp.credentialHandoff.sheet.close')}
                    </Button>
                    <Button
                      type="button"
                      className="touch-target w-full sm:w-auto"
                      disabled={
                        !canRequestCredentialHandoff || requestCredentialHandoffMutation.isPending
                      }
                      onClick={() => void requestCredentialHandoffMutation.mutateAsync()}
                    >
                      {requestCredentialHandoffMutation.isPending
                        ? t('erp.credentialHandoff.sheet.requesting')
                        : t('erp.credentialHandoff.sheet.request')}
                    </Button>
                  </div>
                }
              >
                <div className="space-y-4">
                  <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
                    <p className="text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                      {t('erp.credentialHandoff.sheet.authMode')}
                    </p>
                    <p className="mt-2 text-lg font-semibold text-[var(--color-text-primary)]">
                      {t(`erp.authModes.${data.credentialBoundary.authMode}`)}
                    </p>
                    <p className="mt-2 text-sm leading-relaxed text-[var(--color-text-muted)]">
                      {t('erp.credentialHandoff.sheet.authModeDescription')}
                    </p>
                  </div>
                  <ul className="divide-y divide-[var(--color-border)] rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
                    {['writeOnly', 'opaqueReference', 'noReadback', 'runtimeVerification'].map(
                      (item) => (
                        <li key={item} className="flex items-start gap-3 p-3">
                          <span className="mt-0.5 flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-[var(--color-primary-soft)] text-[var(--color-primary)]">
                            <Check className="h-3.5 w-3.5" aria-hidden />
                          </span>
                          <div>
                            <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                              {t(`erp.credentialHandoff.sheet.steps.${item}.label`)}
                            </p>
                            <p className="mt-1 text-xs leading-relaxed text-[var(--color-text-muted)]">
                              {t(`erp.credentialHandoff.sheet.steps.${item}.description`)}
                            </p>
                          </div>
                        </li>
                      ),
                    )}
                  </ul>
                  <div className="rounded-xl border border-[color-mix(in_srgb,var(--color-warning)_25%,transparent)] bg-[var(--color-warning-soft)] p-4">
                    <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                      {t('erp.credentialHandoff.sheet.guardrailTitle')}
                    </p>
                    <p className="mt-1 text-sm leading-relaxed text-[var(--color-text-secondary)]">
                      {t('erp.credentialHandoff.sheet.guardrailBody')}
                    </p>
                  </div>
                </div>
              </SheetShell>
            </section>
          </TabsContent>

          <TabsContent value="fields" className="mt-6">
            <section>
              <SectionHeader
                title={t('erp.sections.namespaces')}
                description={t('erp.sections.namespacesDescription')}
              />
              <ul className="divide-y divide-[var(--color-border)] overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
                {data.namespaces.length > 0 ? (
                  data.namespaces.map((namespace) => (
                    <li key={namespace.id} className="flex items-center justify-between gap-3 p-4">
                      <div className="min-w-0">
                        <p className="font-mono text-sm font-semibold text-[var(--color-text-primary)]">
                          {namespace.code}
                        </p>
                        <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                          {namespace.name} · {namespace.sourceType}
                        </p>
                      </div>
                      <StatusPill tone={namespace.identityCount > 0 ? 'success' : 'warning'}>
                        {t('erp.identityCount', { count: namespace.identityCount })}
                      </StatusPill>
                    </li>
                  ))
                ) : (
                  <li className="p-4 text-sm text-[var(--color-text-muted)]">
                    {t('erp.empty.namespaces')}
                  </li>
                )}
              </ul>
            </section>

            <section id="erp-mapping-discovery" className="mt-8 scroll-mt-6">
              <SectionHeader
                title={t('erp.sections.domainOwnership')}
                description={t('erp.sections.domainOwnershipDescription')}
              />
              <ul className="mb-8 grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
                {data.domainOwnership.map((domain) => (
                  <li
                    key={domain.id}
                    className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4"
                  >
                    <div className="flex items-start justify-between gap-3">
                      <div className="min-w-0">
                        <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                          {t(domain.labelKey)}
                        </p>
                        <p className="mt-1 font-mono text-xs text-[var(--color-text-muted)]">
                          {domain.pulsTarget}
                        </p>
                      </div>
                      <StatusPill tone={domainOwnershipTone(domain.status)}>
                        {t(`erp.domainOwnership.status.${domain.status}`)}
                      </StatusPill>
                    </div>
                    <p className="mt-3 text-xs text-[var(--color-text-secondary)]">
                      {domain.ownerProviderLabel
                        ? t('erp.domainOwnership.owner', { source: domain.ownerProviderLabel })
                        : t('erp.domainOwnership.available')}
                    </p>
                    <p className="mt-2 font-mono text-xs text-[var(--color-text-muted)]">
                      {domain.mappedFields} / {domain.totalFields}
                    </p>
                  </li>
                ))}
              </ul>

              <SectionHeader
                title={t('erp.sections.canonicalClasses')}
                description={t('erp.sections.canonicalClassesDescription')}
              />
              <ul className="grid gap-3 sm:grid-cols-2">
                {data.canonicalClasses.map((canonicalClass) => (
                  <li
                    key={canonicalClass.id}
                    className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4"
                  >
                    <div className="flex items-start justify-between gap-3">
                      <div className="min-w-0">
                        <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                          {t(canonicalClass.labelKey)}
                        </p>
                        <p className="mt-1 text-xs leading-relaxed text-[var(--color-text-muted)]">
                          {t(canonicalClass.descriptionKey)}
                        </p>
                      </div>
                      <StatusPill tone={readinessTone(canonicalClass.status)}>
                        {t(`erp.readinessStatus.${canonicalClass.status}`)}
                      </StatusPill>
                    </div>
                    <p className="mt-3 font-mono text-xs text-[var(--color-text-muted)]">
                      {canonicalClass.pulsTarget}
                    </p>
                    <div className="mt-4 grid grid-cols-2 gap-3 text-xs">
                      <div>
                        <p className="font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                          {t('erp.canonicalClasses.mappedFields')}
                        </p>
                        <p className="mt-1 font-mono text-base text-[var(--color-text-primary)]">
                          {canonicalClass.mappedFields} / {canonicalClass.totalFields}
                        </p>
                      </div>
                      <div>
                        <p className="font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                          {t('erp.canonicalClasses.requiredFields')}
                        </p>
                        <p className="mt-1 font-mono text-base text-[var(--color-text-primary)]">
                          {canonicalClass.mappedRequiredFields} / {canonicalClass.requiredFields}
                        </p>
                      </div>
                    </div>
                  </li>
                ))}
              </ul>
            </section>

            <section className="mt-8">
              <SectionHeader
                title={t('erp.sections.mapping')}
                description={t('erp.sections.mappingDescription')}
              />
              <div className="overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
                <div className="hidden border-b border-[var(--color-border)] bg-[var(--color-bg-surface)] px-4 py-2.5 text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)] sm:grid sm:grid-cols-[1.2fr_1fr_120px] sm:gap-3">
                  <div>{t('erp.columns.canonicalField')}</div>
                  <div>{t('erp.columns.sourceField')}</div>
                  <div className="text-right">{t('erp.columns.status')}</div>
                </div>
                <ul className="divide-y divide-[var(--color-border)]">
                  {data.mappings.length > 0 ? (
                    data.mappings.map((mapping) => (
                      <li
                        key={`${mapping.sourceEntity}-${mapping.canonicalField}-${mapping.sourceField}`}
                        className="grid grid-cols-1 gap-2 px-4 py-3 sm:grid-cols-[1.2fr_1fr_120px] sm:items-center sm:gap-3"
                      >
                        <div>
                          <p className="font-mono text-sm font-medium">{mapping.canonicalField}</p>
                          <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                            {mapping.sourceEntity} ·{' '}
                            {mapping.required
                              ? t('erp.mapping.required')
                              : t('erp.mapping.optional')}
                          </p>
                        </div>
                        <div className="font-mono text-sm text-[var(--color-text-muted)] sm:text-[var(--color-text-secondary)]">
                          {mapping.sourceField}
                        </div>
                        <div className="sm:justify-self-end">
                          <StatusPill tone={mapping.status === 'mapped' ? 'success' : 'warning'}>
                            {t(`erp.status.${mapping.status}`)}
                          </StatusPill>
                        </div>
                      </li>
                    ))
                  ) : (
                    <li className="p-4 text-sm text-[var(--color-text-muted)]">
                      {t('erp.empty.mappings')}
                    </li>
                  )}
                </ul>
              </div>
            </section>

            <section className="mt-8 grid gap-4 lg:grid-cols-[1fr_1fr]">
              <div>
                <SectionHeader
                  title={t('erp.sections.transferModes')}
                  description={t('erp.sections.transferModesDescription')}
                />
                <ul className="space-y-2 rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-3">
                  {data.transferModes.map((mode) => (
                    <li key={mode.id} className="flex items-center justify-between gap-3 p-2">
                      <span className="text-sm text-[var(--color-text-secondary)]">
                        {t(mode.labelKey)}
                      </span>
                      <StatusPill tone={readinessTone(mode.status)}>
                        {t(`erp.readinessStatus.${mode.status}`)}
                      </StatusPill>
                    </li>
                  ))}
                </ul>
              </div>

              <div>
                <SectionHeader
                  title={t('erp.sections.guardrails')}
                  description={t('erp.sections.guardrailsDescription')}
                />
                <ul className="space-y-2 rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-3">
                  {data.guardrails.map((guardrail) => (
                    <li key={guardrail.id} className="flex items-start gap-3 p-2">
                      <ShieldCheck
                        className="mt-0.5 h-4 w-4 shrink-0 text-[var(--color-primary)]"
                        aria-hidden
                      />
                      <span className="text-sm text-[var(--color-text-secondary)]">
                        {t(guardrail.labelKey)}
                      </span>
                    </li>
                  ))}
                </ul>
              </div>
            </section>
          </TabsContent>

          <TabsContent value="activity" className="mt-6">
            <section id="erp-runtime-queue" className="space-y-6">
              <SectionHeader
                title={t('erp.sections.runtimeQueue')}
                description={t('erp.sections.runtimeQueueDescription')}
              />
              <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
                <div className="flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
                  <div className="flex min-w-0 items-start gap-3">
                    <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-[var(--color-bg-elevated)] text-[var(--color-primary)]">
                      <SearchCheck className="h-5 w-5" aria-hidden />
                    </span>
                    <div className="min-w-0">
                      <div className="flex flex-wrap items-center gap-2">
                        <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                          {t('erp.runtimePreflight.title')}
                        </p>
                        <StatusPill tone={canRequestRuntimePreflight ? 'success' : 'warning'}>
                          {canRequestRuntimePreflight
                            ? t('erp.runtimePreflight.status.ready')
                            : t('erp.runtimePreflight.status.blocked')}
                        </StatusPill>
                      </div>
                      <p className="mt-2 text-sm leading-relaxed text-[var(--color-text-secondary)]">
                        {t('erp.runtimePreflight.description')}
                      </p>
                      <p className="mt-2 text-xs leading-relaxed text-[var(--color-text-muted)]">
                        {runtimePreflightCredentialReady
                          ? runtimePreflightWorkerReady
                            ? t('erp.runtimePreflight.hints.ready')
                            : t('erp.runtimePreflight.hints.workerRequired')
                          : t('erp.runtimePreflight.hints.credentialRequired')}
                      </p>
                    </div>
                  </div>
                  <Button
                    type="button"
                    variant="outline"
                    className="touch-target w-full md:w-auto"
                    disabled={
                      !canRequestRuntimePreflight || requestRuntimePreflightMutation.isPending
                    }
                    onClick={() => void requestRuntimePreflightMutation.mutateAsync()}
                  >
                    <SearchCheck className="h-4 w-4" />
                    {!canManageConnectors
                      ? t('erp.runtimePreflight.actions.adminRequired')
                      : requestRuntimePreflightMutation.isPending
                        ? t('erp.runtimePreflight.actions.requesting')
                        : canRequestRuntimePreflight
                          ? t('erp.runtimePreflight.actions.request')
                          : t('erp.runtimePreflight.actions.blocked')}
                  </Button>
                </div>
              </div>
              <div className="grid gap-3 md:grid-cols-3">
                <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
                  <div className="flex items-center justify-between gap-3">
                    <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                      {t('erp.runtimeQueue.cards.contract')}
                    </p>
                    <StatusPill tone={readinessTone(data.runtimeQueue.readiness)}>
                      {t(data.runtimeQueue.statusLabelKey)}
                    </StatusPill>
                  </div>
                  <p className="mt-3 text-sm leading-relaxed text-[var(--color-text-secondary)]">
                    {t(data.runtimeQueue.descriptionKey)}
                  </p>
                </div>
                <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
                  <div className="flex items-center justify-between gap-3">
                    <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                      {t('erp.runtimeQueue.cards.worker')}
                    </p>
                    <StatusPill tone={readinessTone(data.runtimeQueue.worker.readiness)}>
                      {t(data.runtimeQueue.worker.statusLabelKey)}
                    </StatusPill>
                  </div>
                  <p className="mt-3 text-sm leading-relaxed text-[var(--color-text-secondary)]">
                    {t(data.runtimeQueue.worker.descriptionKey)}
                  </p>
                  <p className="mt-2 text-xs text-[var(--color-text-muted)]">
                    {t('erp.runtimeQueue.labels.workerLastSeen')}:{' '}
                    {formatDateTime(
                      data.runtimeQueue.worker.lastSeenAt,
                      i18n.language,
                      t('erp.runtimeQueue.values.noTimestamp'),
                    )}
                  </p>
                </div>
                <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
                  <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                    {t('erp.runtimeQueue.cards.jobs')}
                  </p>
                  <p className="mt-3 font-mono text-2xl font-semibold text-[var(--color-text-primary)]">
                    {data.runtimeQueue.summary.total}
                  </p>
                  <p className="mt-1 text-sm text-[var(--color-text-muted)]">
                    {t('erp.runtimeQueue.values.queueSummary', {
                      queued: data.runtimeQueue.summary.queued,
                      running: data.runtimeQueue.summary.running,
                      retrying: data.runtimeQueue.summary.retrying,
                    })}
                  </p>
                  {data.runtimeQueue.summary.operatorReviewRequired > 0 ? (
                    <p className="mt-2 text-xs font-semibold text-[var(--color-warning)]">
                      {t('erp.runtimeQueue.values.operatorReviewSummary', {
                        count: data.runtimeQueue.summary.operatorReviewRequired,
                      })}
                    </p>
                  ) : null}
                </div>
              </div>
              <ul className="divide-y divide-[var(--color-border)] overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
                {data.runtimeQueue.jobs.length > 0 ? (
                  data.runtimeQueue.jobs.map((job) => (
                    <li key={job.id} className="grid gap-3 p-4 sm:grid-cols-[auto_1fr_auto]">
                      <span
                        className={cn(
                          'flex h-9 w-9 shrink-0 items-center justify-center rounded-md',
                          syncLogTone(job.level),
                        )}
                      >
                        <RefreshCw className="h-4 w-4" aria-hidden />
                      </span>
                      <div className="min-w-0">
                        <div className="flex flex-wrap items-center gap-2">
                          <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                            {t(job.titleKey)}
                          </p>
                          <StatusPill tone={runtimeJobStatusTone(job.level)}>
                            {t(job.statusLabelKey)}
                          </StatusPill>
                        </div>
                        <p className="mt-1 text-sm leading-relaxed text-[var(--color-text-secondary)]">
                          {t(job.summaryKey)}
                        </p>
                        <p className="mt-2 text-xs text-[var(--color-text-muted)]">
                          {t('erp.runtimeQueue.labels.attempts', {
                            attempt: job.attemptCount,
                            max: job.maxAttempts,
                          })}
                        </p>
                        {job.failureClass !== 'none' ? (
                          <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                            {t('erp.runtimeQueue.labels.failureClass')}:{' '}
                            <span className="font-semibold">{t(job.failureClassLabelKey)}</span>
                          </p>
                        ) : null}
                        <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                          {t('erp.runtimeQueue.labels.lease')}:{' '}
                          <span className="font-semibold">{t(job.leaseStatusLabelKey)}</span>
                          {job.leaseExpiresAt
                            ? ` · ${formatDateTime(job.leaseExpiresAt, i18n.language, t('erp.runtimeQueue.values.noTimestamp'))}`
                            : ''}
                        </p>
                        {job.retryAfterSeconds > 0 || job.nextRetryAt ? (
                          <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                            {t('erp.runtimeQueue.labels.retryWindow')}:{' '}
                            <span className="font-semibold">
                              {job.nextRetryAt
                                ? formatDateTime(
                                    job.nextRetryAt,
                                    i18n.language,
                                    t('erp.runtimeQueue.values.noTimestamp'),
                                  )
                                : t('erp.runtimeQueue.values.retryAfterSeconds', {
                                    seconds: job.retryAfterSeconds,
                                  })}
                            </span>
                          </p>
                        ) : null}
                        {job.operatorReviewRequired ? (
                          <div className="mt-3 rounded-lg border border-[color-mix(in_srgb,var(--color-warning)_30%,transparent)] bg-[var(--color-warning-soft)] px-3 py-2 text-xs leading-relaxed text-[var(--color-text-secondary)]">
                            <span className="font-semibold text-[var(--color-warning)]">
                              {t('erp.runtimeQueue.labels.operatorReview')}:
                            </span>{' '}
                            {t('erp.runtimeQueue.values.operatorReviewRequired')}
                          </div>
                        ) : null}
                        {job.safeErrorSummaryKey ? (
                          <div className="mt-3 rounded-lg border border-[color-mix(in_srgb,var(--color-warning)_30%,transparent)] bg-[var(--color-warning-soft)] px-3 py-2 text-xs leading-relaxed text-[var(--color-text-secondary)]">
                            <span className="font-semibold text-[var(--color-warning)]">
                              {t('erp.activityTimeline.labels.safeDetails')}
                            </span>{' '}
                            {t(job.safeErrorSummaryKey)}
                          </div>
                        ) : null}
                        <p className="mt-3 text-xs text-[var(--color-text-muted)]">
                          <span className="font-semibold">
                            {t('erp.activityTimeline.labels.nextAction')}:
                          </span>{' '}
                          {t(job.nextActionKey)}
                        </p>
                      </div>
                      <time className="text-xs text-[var(--color-text-muted)] sm:text-right">
                        {formatDateTime(
                          job.updatedAt ?? job.createdAt,
                          i18n.language,
                          t('erp.runtimeQueue.values.noTimestamp'),
                        )}
                      </time>
                    </li>
                  ))
                ) : (
                  <li className="p-4 text-sm text-[var(--color-text-muted)]">
                    {t('erp.empty.runtimeQueue')}
                  </li>
                )}
              </ul>
            </section>

            <section className="mt-8">
              <SectionHeader
                title={t('erp.sections.activityTimeline')}
                description={t('erp.sections.activityTimelineDescription')}
              />
              <ul className="divide-y divide-[var(--color-border)] overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
                {data.activityTimeline.length > 0 ? (
                  data.activityTimeline.map((event) => (
                    <li key={event.id} className="grid gap-3 p-4 sm:grid-cols-[auto_1fr_auto]">
                      <span
                        className={cn(
                          'flex h-9 w-9 shrink-0 items-center justify-center rounded-md',
                          syncLogTone(event.level),
                        )}
                      >
                        <SyncLogIcon level={event.level} />
                      </span>
                      <div className="min-w-0 flex-1">
                        <div className="flex flex-wrap items-center gap-2">
                          <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                            {t(event.titleKey)}
                          </p>
                          <span className="rounded-full bg-[var(--color-bg-muted)] px-2 py-1 text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                            {t(event.actorLabelKey)}
                          </span>
                        </div>
                        <p className="mt-1 text-sm leading-relaxed text-[var(--color-text-secondary)]">
                          {t(event.summaryKey)}
                        </p>
                        {event.detailItems.length > 0 ? (
                          <dl className="mt-3 grid gap-2 sm:grid-cols-2">
                            {event.detailItems.map((item) => (
                              <div
                                key={item.labelKey}
                                className="rounded-lg bg-[var(--color-bg-muted)] px-3 py-2"
                              >
                                <dt className="text-[11px] font-semibold uppercase tracking-[0.08em] text-[var(--color-text-muted)]">
                                  {t(item.labelKey)}
                                </dt>
                                <dd className="mt-1 font-mono text-sm text-[var(--color-text-primary)]">
                                  {formatActivityDetailValue(item.value, t, item.labelKey)}
                                </dd>
                              </div>
                            ))}
                          </dl>
                        ) : null}
                        {event.safeErrorSummaryKey ? (
                          <div className="mt-3 rounded-lg border border-[color-mix(in_srgb,var(--color-warning)_30%,transparent)] bg-[var(--color-warning-soft)] px-3 py-2 text-xs leading-relaxed text-[var(--color-text-secondary)]">
                            <span className="font-semibold text-[var(--color-warning)]">
                              {t('erp.activityTimeline.labels.safeDetails')}
                            </span>{' '}
                            {t(event.safeErrorSummaryKey)}
                          </div>
                        ) : null}
                        <p className="mt-3 text-xs text-[var(--color-text-muted)]">
                          <span className="font-semibold">
                            {t('erp.activityTimeline.labels.nextAction')}:
                          </span>{' '}
                          {t(event.nextActionKey)}
                        </p>
                      </div>
                      <time className="text-xs text-[var(--color-text-muted)] sm:text-right">
                        {event.at}
                      </time>
                    </li>
                  ))
                ) : (
                  <li className="p-4 text-sm text-[var(--color-text-muted)]">
                    {t('erp.empty.activityTimeline')}
                  </li>
                )}
              </ul>
            </section>
          </TabsContent>
        </Tabs>
      ) : null}
    </div>
  )
}
