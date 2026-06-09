import { ClipboardCheck, Info, RefreshCw, ShieldCheck } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { SectionHeader } from '#/components/puls/SectionHeader'
import { StatusPill } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { cn } from '#/lib/utils'

import { formatDateTime, readinessTone } from './dataSourceUi'
import type { DataSourceTechnicalTabPanelProps } from './DataSourceTechnicalDetailsTypes'

export function GuardedUpdateRollbackPreviewSection(props: DataSourceTechnicalTabPanelProps) {
  const { data, permissions, mutations } = props
  const { t, i18n } = useTranslation()

  return (
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
          <Info className="mt-0.5 h-4 w-4 shrink-0 text-[var(--color-primary)]" aria-hidden />
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
                  <StatusPill tone={readinessTone(data.guardedUpdateRollbackApproval.readiness)}>
                    {t(`erp.readinessStatus.${data.guardedUpdateRollbackApproval.readiness}`)}
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
                !permissions.canRecordRollbackApproval || mutations.recordRollbackApproval.isPending
              }
              onClick={() => void mutations.recordRollbackApproval.mutateAsync()}
            >
              <ShieldCheck
                className={cn(
                  'h-4 w-4',
                  mutations.recordRollbackApproval.isPending ? 'animate-pulse' : null,
                )}
              />
              {permissions.canRecordRollbackApproval
                ? mutations.recordRollbackApproval.isPending
                  ? t('erp.guardedUpdateRollbackApproval.recording')
                  : t(data.guardedUpdateRollbackApproval.actionLabelKey)
                : !permissions.canManageConnectors &&
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
  )
}

export function GuardedUpdateRollbackWorkerReadinessSection(
  props: DataSourceTechnicalTabPanelProps,
) {
  const { data, permissions, mutations } = props
  const { t, i18n } = useTranslation()

  return (
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
                    tone={readinessTone(data.guardedUpdateRollbackWorkerReadiness.readiness)}
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
              !permissions.canRequestRollbackWorkerReadiness ||
              mutations.requestRollbackWorkerReadiness.isPending
            }
            onClick={() => void mutations.requestRollbackWorkerReadiness.mutateAsync()}
          >
            <ClipboardCheck
              className={cn(
                'h-4 w-4',
                mutations.requestRollbackWorkerReadiness.isPending ? 'animate-pulse' : null,
              )}
            />
            {permissions.canRequestRollbackWorkerReadiness
              ? mutations.requestRollbackWorkerReadiness.isPending
                ? t('erp.guardedUpdateRollbackWorkerReadiness.generating')
                : t(data.guardedUpdateRollbackWorkerReadiness.actionLabelKey)
              : !permissions.canManageConnectors &&
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
  )
}

export function GuardedUpdateRollbackWorkerApplySection(props: DataSourceTechnicalTabPanelProps) {
  const { data, permissions, mutations } = props
  const { t } = useTranslation()

  return (
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
            disabled={
              !permissions.canRequestRollbackApplyJob || permissions.requestRollbackApplyPending
            }
            onClick={() => void mutations.requestRollbackApplyJob.mutateAsync()}
          >
            <RefreshCw
              className={cn(
                'h-4 w-4',
                permissions.requestRollbackApplyPending ? 'animate-spin' : null,
              )}
            />
            {permissions.canRequestRollbackApplyJob
              ? permissions.requestRollbackApplyPending
                ? t('erp.guardedUpdateRollbackWorkerApply.queueing')
                : t('erp.guardedUpdateRollbackWorkerApply.actions.queue')
              : !permissions.canManageConnectors &&
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
  )
}
