import { RefreshCw, SearchCheck } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { SectionHeader } from '#/components/puls/SectionHeader'
import { StatusPill } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { TabsContent } from '#/components/ui/tabs'
import { cn } from '#/lib/utils'

import {
  SyncLogIcon,
  formatActivityDetailValue,
  formatDateTime,
  readinessTone,
  runtimeJobStatusTone,
  syncLogTone,
} from './dataSourceUi'
import type { DataSourceTechnicalTabPanelProps } from './DataSourceTechnicalDetailsTypes'

export function DataSourceActivityTabPanel({
  data,
  permissions,
  mutations,
}: DataSourceTechnicalTabPanelProps) {
  const { t, i18n } = useTranslation()
  const runtimePreflightCredentialReady = data.credentialBoundary.status === 'ready'
  const runtimePreflightWorkerReady =
    data.runtimeQueue.worker.supportedJobTypes.includes('connector_runtime_preflight') &&
    (data.runtimeQueue.worker.status === 'idle' || data.runtimeQueue.worker.status === 'running')

  return (
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
                  <StatusPill tone={permissions.canRequestRuntimePreflight ? 'success' : 'warning'}>
                    {permissions.canRequestRuntimePreflight
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
                !permissions.canRequestRuntimePreflight ||
                mutations.requestRuntimePreflight.isPending
              }
              onClick={() => void mutations.requestRuntimePreflight.mutateAsync()}
            >
              <SearchCheck className="h-4 w-4" />
              {!permissions.canManageConnectors
                ? t('erp.runtimePreflight.actions.adminRequired')
                : mutations.requestRuntimePreflight.isPending
                  ? t('erp.runtimePreflight.actions.requesting')
                  : permissions.canRequestRuntimePreflight
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
  )
}
