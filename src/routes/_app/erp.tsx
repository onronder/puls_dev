import { createFileRoute } from '@tanstack/react-router'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  AlertTriangle,
  Braces,
  Check,
  CheckCircle2,
  ChevronRight,
  Circle,
  Database,
  FileSpreadsheet,
  Globe2,
  Info,
  Link2,
  Plug,
  RefreshCw,
  ShieldCheck,
} from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

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
import { useAuth } from '#/lib/auth'
import {
  fetchErpOverviewWithMeta,
  mapConnectorSetupError,
  startConnectorSetup,
  type ErpOverview,
} from '#/lib/data'
import { captureAppError } from '#/lib/observability/sentry'
import { canShowSetupHub } from '#/lib/setup-access'
import { cn } from '#/lib/utils'

export const Route = createFileRoute('/_app/erp')({
  head: () => ({
    meta: [{ title: 'Data Connections — PULS' }],
  }),
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
type ConnectorSyncLevel = ErpOverview['syncLogs'][number]['level']
type ConnectorProviderOption = ErpOverview['providerOptions'][number]

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
    default:
      return 'bg-[var(--color-primary-soft)] text-[var(--color-info)]'
  }
}

function SyncLogIcon({ level }: { level: ConnectorSyncLevel }) {
  const className = 'h-4 w-4'
  if (level === 'success') return <CheckCircle2 className={className} aria-hidden />
  if (level === 'warning') return <AlertTriangle className={className} aria-hidden />
  return <Info className={className} aria-hidden />
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
  const { t } = useTranslation()
  const { user, personaRole, activePersona } = useAuth()
  const queryClient = useQueryClient()
  const [selectedProviderId, setSelectedProviderId] = useState<
    ConnectorProviderOption['id'] | null
  >(null)
  const [draftSheetOpen, setDraftSheetOpen] = useState(false)
  const [preflightHasRun, setPreflightHasRun] = useState(false)
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
    mutationFn: async () => {
      await queryClient.refetchQueries({ queryKey: ['erp-overview', user?.id] })
      return data?.preflight.status ?? 'blocked'
    },
    onSuccess: (status) => {
      setPreflightHasRun(true)
      toast.success(t(`erp.toast.preflight.${status}`))
      window.setTimeout(() => {
        document
          .getElementById('erp-preflight-result')
          ?.scrollIntoView({ behavior: 'smooth', block: 'start' })
      }, 80)
    },
  })

  const data = erpResult?.data
  const hasSelectedConnector = data?.connectorState === 'connector_selected'
  const hasNoConnector = data?.connectorState === 'no_connector'
  const selectedProvider =
    selectedProviderId == null
      ? null
      : data?.providerOptions.find((option) => option.id === selectedProviderId)
  const selectedProviderCanStart = selectedProvider?.setupAvailable === true
  const pageTitle = data && hasNoConnector ? t('erp.noConnector.title') : t('erp.title')
  const pageSubtitle = data && hasNoConnector ? t('erp.noConnector.subtitle') : t('erp.subtitle')

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
          <ol className="-mx-4 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:grid-cols-5 md:overflow-visible md:px-0">
            {data.setupSteps.map((step, index) => (
              <li
                key={step.id}
                className="min-w-[176px] rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-3"
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
        <div className="-mx-4 mt-6 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:grid-cols-2 md:overflow-visible md:px-0 lg:grid-cols-4">
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
        </div>
      ) : data && hasSelectedConnector ? (
        <div className="-mx-4 mt-6 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:grid-cols-2 md:overflow-visible md:px-0 lg:grid-cols-4">
          <MetricCard
            compact
            label={t('erp.metrics.provider')}
            value={data.provider.label}
            hint={t(data.provider.statusLabelKey)}
            icon={Plug}
          />
          <div className="min-w-[140px] shrink-0">
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
        <div className="mt-6 flex flex-col gap-2 sm:flex-row sm:flex-wrap">
          <Button
            type="button"
            variant="outline"
            className="touch-target w-full sm:w-auto"
            onClick={() => {
              document
                .getElementById('erp-mapping-discovery')
                ?.scrollIntoView({ behavior: 'smooth', block: 'start' })
            }}
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
      ) : null}
      {data && hasSelectedConnector ? (
        <p className="mt-2 text-xs text-[var(--color-text-muted)]">{t('erp.preflightNote')}</p>
      ) : null}

      {data && hasSelectedConnector ? (
        <>
          <section id="erp-preflight-result" className="mt-8 scroll-mt-6">
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
                    {preflightHasRun
                      ? t('erp.preflightResult.sessionRun')
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

          <section className="mt-8">
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
                          {mapping.required ? t('erp.mapping.required') : t('erp.mapping.optional')}
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
        </>
      ) : null}

      {data && hasSelectedConnector ? (
        <section className="mt-8">
          <SectionHeader
            title={t('erp.sections.syncLogs')}
            description={t('erp.sections.syncLogsDescription')}
          />
          <ul className="divide-y divide-[var(--color-border)] overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
            {data.syncLogs.length > 0 ? (
              data.syncLogs.map((log) => (
                <li key={log.id} className="flex items-start gap-3 p-4">
                  <span
                    className={cn(
                      'flex h-9 w-9 shrink-0 items-center justify-center rounded-md',
                      syncLogTone(log.level),
                    )}
                  >
                    <SyncLogIcon level={log.level} />
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="text-sm text-[var(--color-text-primary)]">{log.message}</p>
                    <p className="mt-1 text-xs text-[var(--color-text-muted)]">{log.at}</p>
                  </div>
                </li>
              ))
            ) : (
              <li className="p-4 text-sm text-[var(--color-text-muted)]">
                {t('erp.empty.syncLogs')}
              </li>
            )}
          </ul>
        </section>
      ) : null}
    </div>
  )
}
