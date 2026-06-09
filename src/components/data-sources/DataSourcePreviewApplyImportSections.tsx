import { Braces, ClipboardCheck, Info, SearchCheck } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { SectionHeader } from '#/components/puls/SectionHeader'
import { StatusPill } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { cn } from '#/lib/utils'

import { applyChangeSetRiskTone, formatDateTime, readinessTone } from './dataSourceUi'
import type { DataSourceTechnicalTabPanelProps } from './DataSourceTechnicalDetailsTypes'

export function ImportPreviewSection(props: DataSourceTechnicalTabPanelProps) {
  const { data, permissions, mutations } = props
  const { t } = useTranslation()

  return (
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
            disabled={!permissions.canRunImportPreview || mutations.runImportPreview.isPending}
            onClick={() => void mutations.runImportPreview.mutateAsync()}
          >
            <SearchCheck
              className={cn(
                'h-4 w-4',
                mutations.runImportPreview.isPending ? 'animate-pulse' : null,
              )}
            />
            {permissions.canRunImportPreview
              ? mutations.runImportPreview.isPending
                ? t('erp.importPreview.running')
                : t(data.importPreview.actionLabelKey)
              : !permissions.canManageConnectors &&
                  data.importPreview.action === 'run_dry_run_preview'
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
              {data.importPreview.summary.createCount} / {data.importPreview.summary.updateCount} /{' '}
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
              {data.importPreview.summary.errorCount} / {data.importPreview.summary.warningCount}
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
  )
}

export function ApplyReadinessSection(props: DataSourceTechnicalTabPanelProps) {
  const { data, permissions, mutations } = props
  const { t, i18n } = useTranslation()

  return (
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
              <StatusPill tone="neutral">{t('erp.applyReadiness.safeToApplyFalse')}</StatusPill>
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
            disabled={!permissions.canRequestApplyReview || mutations.requestApplyReview.isPending}
            onClick={() => void mutations.requestApplyReview.mutateAsync()}
          >
            <ClipboardCheck
              className={cn(
                'h-4 w-4',
                mutations.requestApplyReview.isPending ? 'animate-pulse' : null,
              )}
            />
            {permissions.canRequestApplyReview
              ? mutations.requestApplyReview.isPending
                ? t('erp.applyReadiness.requesting')
                : t(data.applyReadiness.actionLabelKey)
              : !permissions.canManageConnectors &&
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
              {data.applyReadiness.summary.createCount} / {data.applyReadiness.summary.updateCount}{' '}
              / {data.applyReadiness.summary.skipCount}
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
              {data.applyReadiness.summary.errorCount} / {data.applyReadiness.summary.warningCount}
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
                  <p className="mt-1 text-xs text-[var(--color-text-muted)]">{t(check.valueKey)}</p>
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
  )
}

export function ApplyChangeSetSection(props: DataSourceTechnicalTabPanelProps) {
  const { data, permissions, mutations } = props
  const { t, i18n } = useTranslation()

  return (
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
              <StatusPill tone="neutral">{t('erp.applyChangeSet.executionClosed')}</StatusPill>
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
            disabled={
              !permissions.canRequestApplyChangeSet || mutations.requestApplyChangeSet.isPending
            }
            onClick={() => void mutations.requestApplyChangeSet.mutateAsync()}
          >
            <Braces
              className={cn(
                'h-4 w-4',
                mutations.requestApplyChangeSet.isPending ? 'animate-pulse' : null,
              )}
            />
            {permissions.canRequestApplyChangeSet
              ? mutations.requestApplyChangeSet.isPending
                ? t('erp.applyChangeSet.generating')
                : t(data.applyChangeSet.actionLabelKey)
              : !permissions.canManageConnectors &&
                  data.applyChangeSet.action === 'generate_change_set'
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
              {data.applyChangeSet.summary.createCount} / {data.applyChangeSet.summary.updateCount}{' '}
              / {data.applyChangeSet.summary.skipCount}
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
          <Info className="mt-0.5 h-4 w-4 shrink-0 text-[var(--color-primary)]" aria-hidden />
          <p className="text-xs leading-relaxed text-[var(--color-text-muted)]">
            {t('erp.applyChangeSet.boundaryNote')}
          </p>
        </div>
      </div>
    </section>
  )
}
