import { createFileRoute } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import {
  AlertTriangle,
  CheckCircle2,
  Database,
  Info,
  Link2,
  Plug,
  RefreshCw,
  ShieldCheck,
} from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { SetupRouteGuard } from '#/components/auth/SetupRouteGuard'
import { DemoSourcePill } from '#/components/puls/DemoSourcePill'
import { MetricCard } from '#/components/puls/MetricCard'
import { PageHeader } from '#/components/puls/PageHeader'
import { SectionHeader } from '#/components/puls/SectionHeader'
import { StatusPill, type StatusTone } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { Progress } from '#/components/ui/progress'
import { Skeleton } from '#/components/ui/skeleton'
import { useAuth } from '#/lib/auth'
import { fetchErpOverviewWithMeta, type ErpOverview } from '#/lib/data'
import { cn } from '#/lib/utils'

export const Route = createFileRoute('/_app/erp')({
  head: () => ({
    meta: [{ title: 'Connector Preflight — PULS' }],
  }),
  component: ErpRoute,
})

function ErpRoute() {
  return (
    <SetupRouteGuard>
      <ErpPage />
    </SetupRouteGuard>
  )
}

type ConnectorStatus = ErpOverview['readiness']['status']
type ConnectorSyncLevel = ErpOverview['syncLogs'][number]['level']

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

function ErpPage() {
  const { t } = useTranslation()
  const { user } = useAuth()
  const { data: erpResult, isLoading } = useQuery({
    queryKey: ['erp-overview', user?.id],
    queryFn: () => fetchErpOverviewWithMeta(user!.id),
    enabled: Boolean(user?.id),
  })

  const data = erpResult?.data
  const hasSelectedConnector = data?.connectorState === 'connector_selected'
  const hasNoConnector = data?.connectorState === 'no_connector'

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <p className="text-xs font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
        {t('erp.eyebrow')}
      </p>
      <PageHeader
        className="mt-1"
        title={t('erp.title')}
        subtitle={t('erp.subtitle')}
        badge={
          <StatusPill tone={data ? readinessTone(data.readiness.status) : 'neutral'}>
            {data ? t(data.provider.statusLabelKey) : t('erp.badge')}
          </StatusPill>
        }
      />

      <DemoSourcePill visible={erpResult?.source === 'demo'} />

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
              label={t('erp.metrics.preflight')}
              value={`${data.readiness.score}%`}
              hint={t(`erp.readinessStatus.${data.readiness.status}`)}
            />
            <Progress className="mt-2 h-1.5" value={data.readiness.score} />
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
            title={t('erp.onboarding.title')}
            description={t('erp.onboarding.description')}
          />
          <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
            <div className="grid gap-3 md:grid-cols-2">
              {data.providerOptions.map((option) => (
                <div
                  key={option.id}
                  className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-4"
                >
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <p className="text-sm font-semibold text-[var(--color-text-primary)]">
                        {t(option.labelKey)}
                      </p>
                      <p className="mt-1 text-xs leading-relaxed text-[var(--color-text-muted)]">
                        {t(option.descriptionKey)}
                      </p>
                    </div>
                    <StatusPill tone={readinessTone(option.status)}>
                      {t(`erp.readinessStatus.${option.status}`)}
                    </StatusPill>
                  </div>
                </div>
              ))}
            </div>
            <div className="mt-4 flex flex-col gap-2 sm:flex-row">
              <Button type="button" variant="outline" className="touch-target w-full sm:w-auto" disabled>
                <Plug className="h-4 w-4" />
                {t('erp.onboarding.selectProvider')}
              </Button>
              <Button type="button" variant="outline" className="touch-target w-full sm:w-auto" disabled>
                <Link2 className="h-4 w-4" />
                {t('erp.onboarding.importMapping')}
              </Button>
            </div>
            <p className="mt-3 text-xs leading-relaxed text-[var(--color-text-muted)]">
              {t('erp.onboarding.guardrail')}
            </p>
          </div>
        </section>
      ) : null}

      {data && hasSelectedConnector ? (
        <div className="mt-6 flex flex-col gap-2 sm:flex-row sm:flex-wrap">
          <Button type="button" variant="outline" className="touch-target w-full sm:w-auto" disabled>
          <Link2 className="h-4 w-4" />
          {t('erp.actions.mapFields')}
          </Button>
          <Button type="button" variant="outline" className="touch-target w-full sm:w-auto" disabled>
            <RefreshCw className="h-4 w-4" />
            {t('erp.actions.testConnection')}
          </Button>
        </div>
      ) : null}
      {data ? (
        <p className="mt-2 text-xs text-[var(--color-text-muted)]">{t('erp.preflightNote')}</p>
      ) : null}

      {data && hasSelectedConnector ? (
        <>
          <section className="mt-8">
            <SectionHeader
              title={t('erp.sections.preflight')}
              description={t('erp.sections.preflightDescription')}
            />
            <ul className="grid gap-3 sm:grid-cols-2">
              {data.readiness.checks.map((check) => (
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
                  <p className="mt-2 font-mono text-sm text-[var(--color-text-muted)]">
                    {String(check.value)}
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
                          {mapping.sourceEntity}
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

      <section className="mt-8">
        <SectionHeader
          title={t('erp.sections.syncLogs')}
          description={t('erp.sections.syncLogsDescription')}
        />
        <ul className="divide-y divide-[var(--color-border)] overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
          {(data?.syncLogs ?? []).length > 0 ? (
            (data?.syncLogs ?? []).map((log) => (
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
    </div>
  )
}
