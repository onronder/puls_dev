import { Plug, SearchCheck } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { SectionHeader } from '#/components/puls/SectionHeader'
import { StatusPill } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { cn } from '#/lib/utils'

import {
  DataSourceActionIcon,
  ProviderOptionIcon,
  dataSourceDisplayName,
  formatDataSourceScope,
  formatDateTime,
  readinessTone,
  type ConnectorJourneyStep,
  type DataSourceSummary,
  type ErpWorkbenchTab,
} from './dataSourceUi'

type DataSourceManagerSectionProps = {
  dataSources: DataSourceSummary[]
  selectedDataSource: DataSourceSummary | null
  currentConnectionId: string | null
  activeJourneyStep: ConnectorJourneyStep | undefined
  canManageConnectors: boolean
  canAddSource: boolean
  onAddSource: () => void
  onSelectSource: (sourceId: string) => void
  onPrimaryAction: (source: DataSourceSummary) => void
  onOpenTechnicalDetails: (tab: ErpWorkbenchTab, targetId: string) => void
}

export function DataSourceManagerSection({
  dataSources,
  selectedDataSource,
  currentConnectionId,
  activeJourneyStep,
  canManageConnectors,
  canAddSource,
  onAddSource,
  onSelectSource,
  onPrimaryAction,
  onOpenTechnicalDetails,
}: DataSourceManagerSectionProps) {
  const { t, i18n } = useTranslation()

  return (
    <section id="data-source-manager" className="mt-6 scroll-mt-6">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <SectionHeader
          title={t('erp.dataSources.title')}
          description={t('erp.dataSources.description')}
        />
        <Button
          type="button"
          className="touch-target w-full sm:w-auto"
          disabled={!canManageConnectors || !canAddSource}
          aria-disabled={!canManageConnectors || !canAddSource}
          onClick={onAddSource}
        >
          <Plug className="h-4 w-4" />
          {t('erp.dataSources.addSource')}
        </Button>
      </div>

      <div className="mt-4 grid gap-4 lg:grid-cols-[minmax(0,1fr)_minmax(320px,0.78fr)]">
        <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-3">
          <div className="flex items-center justify-between gap-3 px-1 pb-3">
            <div>
              <h2 className="text-sm font-semibold text-[var(--color-text-primary)]">
                {t('erp.dataSources.inventoryTitle')}
              </h2>
              <p className="mt-1 text-xs text-[var(--color-text-muted)]">
                {t('erp.dataSources.inventoryDescription')}
              </p>
            </div>
            <StatusPill
              tone={
                dataSources.some((source) => source.sourceKind === 'connection')
                  ? 'success'
                  : 'warning'
              }
            >
              {t('erp.dataSources.inventoryCount', {
                count: dataSources.filter((source) => source.sourceKind === 'connection').length,
              })}
            </StatusPill>
          </div>

          {dataSources.length > 0 ? (
            <div className="space-y-2">
              {dataSources.map((source) => {
                const isSelected = selectedDataSource?.id === source.id
                const displayName = dataSourceDisplayName(source, t)
                const isUnavailableCatalog =
                  source.sourceKind === 'catalog' && !source.setupAvailable

                return (
                  <button
                    key={source.id}
                    type="button"
                    aria-pressed={isSelected}
                    aria-disabled={isUnavailableCatalog}
                    disabled={isUnavailableCatalog}
                    onClick={() => {
                      if (!isUnavailableCatalog) onSelectSource(source.id)
                    }}
                    className={cn(
                      'touch-target w-full rounded-lg border p-3 text-left transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--color-primary)]',
                      isUnavailableCatalog
                        ? 'cursor-not-allowed border-[var(--color-border)] bg-[var(--color-bg-surface)] opacity-55'
                        : isSelected
                          ? 'border-[color-mix(in_srgb,var(--color-primary)_55%,transparent)] bg-[var(--color-primary-soft)]'
                          : 'border-[var(--color-border)] bg-[var(--color-bg-surface)] hover:border-[color-mix(in_srgb,var(--color-primary)_28%,transparent)]',
                    )}
                  >
                    <div className="flex items-start gap-3">
                      <span
                        className={cn(
                          'flex h-10 w-10 shrink-0 items-center justify-center rounded-lg',
                          isSelected
                            ? 'bg-[var(--color-bg-card)] text-[var(--color-primary)]'
                            : 'bg-[var(--color-bg-elevated)] text-[var(--color-text-secondary)]',
                        )}
                      >
                        <ProviderOptionIcon id={source.providerId} />
                      </span>
                      <div className="min-w-0 flex-1">
                        <div className="flex flex-wrap items-center gap-2">
                          <p className="truncate text-sm font-semibold text-[var(--color-text-primary)]">
                            {displayName}
                          </p>
                          <StatusPill tone={readinessTone(source.readiness)}>
                            {isUnavailableCatalog
                              ? t('erp.dataSources.nextActions.futureProvider')
                              : t(`erp.dataSources.status.${source.status}`)}
                          </StatusPill>
                          {source.sourceKind === 'connection' ? (
                            <StatusPill tone={source.active ? 'success' : 'neutral'}>
                              {source.active
                                ? t('erp.dataSources.values.active')
                                : t('erp.dataSources.values.passive')}
                            </StatusPill>
                          ) : null}
                        </div>
                        <p className="mt-1 line-clamp-1 text-xs text-[var(--color-text-muted)]">
                          {t(source.typeLabelKey)} · {t(source.methodLabelKey)}
                        </p>
                        <div className="mt-3 grid gap-2 sm:grid-cols-2">
                          <div className="min-w-0">
                            <p className="text-[11px] font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                              {t('erp.dataSources.scope')}
                            </p>
                            <p className="mt-0.5 truncate text-xs font-medium text-[var(--color-text-secondary)]">
                              {formatDataSourceScope(source, t)}
                            </p>
                          </div>
                          <div className="min-w-0">
                            <p className="text-[11px] font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                              {t('erp.dataSources.nextAction')}
                            </p>
                            <p className="mt-0.5 truncate text-xs font-medium text-[var(--color-text-secondary)]">
                              {t(source.nextActionLabelKey)}
                            </p>
                          </div>
                        </div>
                      </div>
                      <DataSourceActionIcon
                        action={source.primaryAction}
                        className="mt-1 h-4 w-4 shrink-0 text-[var(--color-text-muted)]"
                      />
                    </div>
                  </button>
                )
              })}
            </div>
          ) : (
            <div className="rounded-lg border border-dashed border-[var(--color-border)] bg-[var(--color-bg-surface)] p-6">
              <Plug className="h-8 w-8 text-[var(--color-text-secondary)]" aria-hidden />
              <h2 className="mt-4 text-lg font-semibold text-[var(--color-text-primary)]">
                {t('erp.dataSources.emptyTitle')}
              </h2>
              <p className="mt-2 text-sm leading-relaxed text-[var(--color-text-muted)]">
                {t('erp.dataSources.emptyDescription')}
              </p>
            </div>
          )}
        </div>

        <aside className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
          {selectedDataSource ? (
            <div>
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                  <p className="text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                    {t('erp.dataSources.detailTitle')}
                  </p>
                  <h2 className="mt-2 truncate text-xl font-semibold text-[var(--color-text-primary)]">
                    {dataSourceDisplayName(selectedDataSource, t)}
                  </h2>
                  <p className="mt-1 text-sm text-[var(--color-text-muted)]">
                    {t(selectedDataSource.providerLabelKey)}
                  </p>
                </div>
                <StatusPill tone={readinessTone(selectedDataSource.readiness)}>
                  {t(`erp.dataSources.status.${selectedDataSource.status}`)}
                </StatusPill>
              </div>

              <dl className="mt-5 grid gap-3">
                <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-3 py-2">
                  <dt className="text-[11px] font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                    {t('erp.dataSources.method')}
                  </dt>
                  <dd className="mt-1 text-sm font-medium text-[var(--color-text-primary)]">
                    {t(selectedDataSource.methodLabelKey)}
                  </dd>
                </div>
                <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-3 py-2">
                  <dt className="text-[11px] font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                    {t('erp.dataSources.scope')}
                  </dt>
                  <dd className="mt-1 text-sm font-medium text-[var(--color-text-primary)]">
                    {formatDataSourceScope(selectedDataSource, t)}
                  </dd>
                </div>
                <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-3 py-2">
                  <dt className="text-[11px] font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                    {t('erp.dataSources.lastRun')}
                  </dt>
                  <dd className="mt-1 text-sm font-medium text-[var(--color-text-primary)]">
                    {formatDateTime(
                      selectedDataSource.lastRunAt,
                      i18n.language,
                      t('erp.dataSources.values.noLastRun'),
                    )}
                  </dd>
                </div>
                <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-3 py-2">
                  <dt className="text-[11px] font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                    {t('erp.dataSources.nextAction')}
                  </dt>
                  <dd className="mt-1 text-sm font-medium text-[var(--color-text-primary)]">
                    {t(selectedDataSource.nextActionLabelKey)}
                  </dd>
                </div>
              </dl>

              <div className="mt-5 flex flex-col gap-2">
                <Button
                  type="button"
                  className="touch-target w-full"
                  disabled={
                    selectedDataSource.primaryAction === 'none' ||
                    (selectedDataSource.sourceKind === 'catalog' && !canManageConnectors)
                  }
                  aria-disabled={
                    selectedDataSource.primaryAction === 'none' ||
                    (selectedDataSource.sourceKind === 'catalog' && !canManageConnectors)
                  }
                  onClick={() => onPrimaryAction(selectedDataSource)}
                >
                  <DataSourceActionIcon
                    action={selectedDataSource.primaryAction}
                    className="h-4 w-4"
                  />
                  {t(`erp.dataSources.actions.${selectedDataSource.primaryAction}`)}
                </Button>
                {selectedDataSource.sourceKind === 'connection' &&
                selectedDataSource.connectionId === currentConnectionId &&
                activeJourneyStep ? (
                  <Button
                    type="button"
                    variant="outline"
                    className="touch-target w-full"
                    onClick={() =>
                      onOpenTechnicalDetails(
                        activeJourneyStep.detailTab,
                        activeJourneyStep.detailTargetId,
                      )
                    }
                  >
                    <SearchCheck className="h-4 w-4" />
                    {t('erp.dataSources.actions.advancedAudit')}
                  </Button>
                ) : null}
              </div>

              {!canManageConnectors && selectedDataSource.sourceKind === 'catalog' ? (
                <p className="mt-3 rounded-lg border border-[color-mix(in_srgb,var(--color-warning)_28%,transparent)] bg-[var(--color-warning-soft)] px-3 py-2 text-xs leading-relaxed text-[var(--color-text-secondary)]">
                  {t('erp.onboarding.adminRequired')}
                </p>
              ) : null}
            </div>
          ) : (
            <div className="flex min-h-[280px] flex-col justify-center">
              <Plug className="h-8 w-8 text-[var(--color-text-secondary)]" aria-hidden />
              <h2 className="mt-4 text-lg font-semibold text-[var(--color-text-primary)]">
                {t('erp.dataSources.emptyTitle')}
              </h2>
              <p className="mt-2 text-sm leading-relaxed text-[var(--color-text-muted)]">
                {t('erp.dataSources.emptyDescription')}
              </p>
            </div>
          )}
        </aside>
      </div>
    </section>
  )
}
