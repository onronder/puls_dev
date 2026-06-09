import { Info, ShieldCheck } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { SectionHeader } from '#/components/puls/SectionHeader'
import { StatusPill } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { cn } from '#/lib/utils'

import { formatDateTime, guardedUpdateFieldTone, readinessTone } from './dataSourceUi'
import type { DataSourceTechnicalTabPanelProps } from './DataSourceTechnicalDetailsTypes'

export function GuardedUpdateEvidenceSection(props: DataSourceTechnicalTabPanelProps) {
  const { data, permissions, mutations } = props
  const { t, i18n } = useTranslation()

  return (
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
              !permissions.canRequestGuardedUpdateEvidence ||
              mutations.requestGuardedUpdateEvidence.isPending
            }
            onClick={() => void mutations.requestGuardedUpdateEvidence.mutateAsync()}
          >
            <ShieldCheck
              className={cn(
                'h-4 w-4',
                mutations.requestGuardedUpdateEvidence.isPending ? 'animate-pulse' : null,
              )}
            />
            {permissions.canRequestGuardedUpdateEvidence
              ? mutations.requestGuardedUpdateEvidence.isPending
                ? t('erp.guardedUpdateEvidence.generating')
                : t(data.guardedUpdateEvidence.actionLabelKey)
              : !permissions.canManageConnectors &&
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
            <span className="md:text-right">{t('erp.guardedUpdateEvidence.columns.class')}</span>
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
                    <StatusPill tone={guardedUpdateFieldTone(field.fieldClass, field.staleBlocked)}>
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
          <Info className="mt-0.5 h-4 w-4 shrink-0 text-[var(--color-primary)]" aria-hidden />
          <p className="text-xs leading-relaxed text-[var(--color-text-muted)]">
            {t('erp.guardedUpdateEvidence.boundaryNote')}
          </p>
        </div>
      </div>
    </section>
  )
}

export function GuardedUpdateRecoverySection(props: DataSourceTechnicalTabPanelProps) {
  const { data } = props
  const { t, i18n } = useTranslation()

  return (
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
            <span className="md:text-right">{t('erp.guardedUpdateRecovery.columns.boundary')}</span>
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
          <Info className="mt-0.5 h-4 w-4 shrink-0 text-[var(--color-primary)]" aria-hidden />
          <p className="text-xs leading-relaxed text-[var(--color-text-muted)]">
            {t('erp.guardedUpdateRecovery.boundaryNote')}
          </p>
        </div>
      </div>
    </section>
  )
}

export function GuardedUpdateRecoveryRunbookSection(props: DataSourceTechnicalTabPanelProps) {
  const { data } = props
  const { t } = useTranslation()

  return (
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
                    {step.nextActionKey ?? t('erp.guardedUpdateRecoveryRunbook.values.noAction')}
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
          <Info className="mt-0.5 h-4 w-4 shrink-0 text-[var(--color-primary)]" aria-hidden />
          <p className="text-xs leading-relaxed text-[var(--color-text-muted)]">
            {t('erp.guardedUpdateRecoveryRunbook.boundaryNote')}
          </p>
        </div>
      </div>
    </section>
  )
}
