import { ClipboardCheck, Database, ShieldCheck } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { SectionHeader } from '#/components/puls/SectionHeader'
import { StatusPill } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { cn } from '#/lib/utils'

import { formatDateTime, readinessTone } from './dataSourceUi'
import type { DataSourceTechnicalTabPanelProps } from './DataSourceTechnicalDetailsTypes'

export function ControlledApplySection(props: DataSourceTechnicalTabPanelProps) {
  const { data, permissions, mutations } = props
  const { t, i18n } = useTranslation()

  return (
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
              <StatusPill tone="neutral">{t('erp.controlledApply.executionClosed')}</StatusPill>
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
              disabled={
                !permissions.canRecordApplyApproval || mutations.recordApplyApproval.isPending
              }
              onClick={() => void mutations.recordApplyApproval.mutateAsync()}
            >
              <ShieldCheck
                className={cn(
                  'h-4 w-4',
                  mutations.recordApplyApproval.isPending ? 'animate-pulse' : null,
                )}
              />
              {permissions.canRecordApplyApproval
                ? mutations.recordApplyApproval.isPending
                  ? t('erp.applyApprovalPolicy.recording')
                  : t(data.applyApprovalPolicy.actionLabelKey)
                : !permissions.canManageConnectors &&
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
                          data.applyExecutionContract.executorMode === 'worker_guarded_update_job'
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
                variant={permissions.canRequestApplyExecutionJob ? 'default' : 'outline'}
                className="touch-target w-full"
                disabled={
                  !permissions.canRequestApplyExecutionJob ||
                  permissions.requestApplyExecutionPending
                }
                onClick={() => {
                  if (permissions.canRequestGuardedUpdateApplyJob) {
                    void mutations.requestGuardedUpdateApplyJob.mutateAsync()
                    return
                  }
                  void mutations.requestCreateOnlyApplyJob.mutateAsync()
                }}
              >
                <Database
                  className={cn(
                    'h-4 w-4',
                    permissions.requestApplyExecutionPending ? 'animate-pulse' : null,
                  )}
                />
                {permissions.canRequestApplyExecutionJob
                  ? permissions.requestApplyExecutionPending
                    ? t(
                        permissions.canRequestGuardedUpdateApplyJob
                          ? 'erp.applyExecutionContract.actions.enqueueGuardedUpdate.queuing'
                          : 'erp.applyExecutionContract.actions.enqueueCreateOnly.queuing',
                      )
                    : t(
                        permissions.canRequestGuardedUpdateApplyJob
                          ? 'erp.applyExecutionContract.actions.enqueueGuardedUpdate.label'
                          : 'erp.applyExecutionContract.actions.enqueueCreateOnly.label',
                      )
                  : !permissions.canManageConnectors
                    ? t(
                        data.applyExecutionContract.executorMode === 'worker_guarded_update_job'
                          ? 'erp.applyExecutionContract.actions.enqueueGuardedUpdate.adminRequired'
                          : 'erp.applyExecutionContract.actions.enqueueCreateOnly.adminRequired',
                      )
                    : t(
                        data.applyExecutionContract.executorMode === 'worker_guarded_update_job'
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
                        : data.applyExecutionContract.executorMode === 'worker_guarded_update_job'
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
  )
}
