import { useTranslation } from 'react-i18next'

import { SectionHeader } from '#/components/puls/SectionHeader'
import { StatusPill } from '#/components/puls/StatusPill'
import { TabsContent } from '#/components/ui/tabs'

import { readinessTone } from './dataSourceUi'
import type { DataSourceTechnicalTabPanelProps } from './DataSourceTechnicalDetailsTypes'

export function DataSourceCheckTabPanel({ data }: Pick<DataSourceTechnicalTabPanelProps, 'data'>) {
  const { t } = useTranslation()
  return (
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
  )
}
