import { Link2, RefreshCw } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { StatusPill } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { TabsContent } from '#/components/ui/tabs'
import { cn } from '#/lib/utils'

import { readinessTone, type ErpWorkbenchTab } from './dataSourceUi'
import type { DataSourceTechnicalTabPanelProps } from './DataSourceTechnicalDetailsTypes'

type DataSourceSetupTabPanelProps = DataSourceTechnicalTabPanelProps & {
  showWorkbenchTab: (tab: ErpWorkbenchTab, targetId?: string) => void
}

export function DataSourceSetupTabPanel({
  data,
  permissions,
  mutations,
  showWorkbenchTab,
}: DataSourceSetupTabPanelProps) {
  const { t } = useTranslation()
  return (
    <TabsContent id="erp-setup-details" value="setup" className="mt-6 scroll-mt-6">
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
          disabled={!permissions.canManageConnectors || mutations.runPreflight.isPending}
          onClick={() => void mutations.runPreflight.mutateAsync()}
        >
          <RefreshCw
            className={cn('h-4 w-4', mutations.runPreflight.isPending ? 'animate-spin' : null)}
          />
          {permissions.canManageConnectors
            ? mutations.runPreflight.isPending
              ? t('erp.actions.runningPreflight')
              : t('erp.actions.runPreflight')
            : t('erp.actions.adminPreflightRequired')}
        </Button>
      </div>
      <p className="mt-2 text-xs text-[var(--color-text-muted)]">{t('erp.preflightNote')}</p>
    </TabsContent>
  )
}
