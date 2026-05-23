import { createFileRoute } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import {
  AlertTriangle,
  CheckCircle2,
  Info,
  Link2,
  Plug,
  RefreshCw,
} from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { SetupRouteGuard } from '#/components/auth/SetupRouteGuard'
import { MetricCard } from '#/components/puls/MetricCard'
import { PageHeader } from '#/components/puls/PageHeader'
import { SectionHeader } from '#/components/puls/SectionHeader'
import { StatusPill } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { Progress } from '#/components/ui/progress'
import { Skeleton } from '#/components/ui/skeleton'
import { useAuth } from '#/lib/auth'
import { fetchErpOverview, type ErpOverview } from '#/lib/data'
import { cn } from '#/lib/utils'

export const Route = createFileRoute('/_app/erp')({
  head: () => ({
    meta: [{ title: 'ERP Entegrasyon — PULS' }],
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

type DemoErpSyncLevel = ErpOverview['syncLogs'][number]['level']

function syncLogTone(level: DemoErpSyncLevel): string {
  switch (level) {
    case 'success':
      return 'bg-[var(--color-success-soft)] text-[var(--color-success)]'
    case 'warning':
      return 'bg-[var(--color-warning-soft)] text-[var(--color-warning)]'
    default:
      return 'bg-[var(--color-primary-soft)] text-[var(--color-info)]'
  }
}

function SyncLogIcon({ level }: { level: DemoErpSyncLevel }) {
  const className = 'h-4 w-4'
  if (level === 'success') return <CheckCircle2 className={className} aria-hidden />
  if (level === 'warning') return <AlertTriangle className={className} aria-hidden />
  return <Info className={className} aria-hidden />
}

function ErpPage() {
  const { t } = useTranslation()
  const { user } = useAuth()
  const { data, isLoading } = useQuery({
    queryKey: ['erp-overview', user?.id],
    queryFn: () => fetchErpOverview(user!.id),
    enabled: Boolean(user?.id),
  })

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <p className="text-xs font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
        {t('erp.eyebrow')}
      </p>
      <PageHeader
        className="mt-1"
        title={t('erp.title')}
        subtitle={t('erp.subtitle')}
        badge={<StatusPill tone="warning">{t('erp.badge')}</StatusPill>}
      />

      {isLoading ? (
        <div className="-mx-4 mt-6 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:grid-cols-2 md:overflow-visible md:px-0 lg:grid-cols-4">
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
        </div>
      ) : data ? (
        <div className="-mx-4 mt-6 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:grid-cols-2 md:overflow-visible md:px-0 lg:grid-cols-4">
          <MetricCard compact label={t('erp.metrics.system')} value={data.status.system} icon={Plug} />
          <div className="min-w-[140px] shrink-0">
            <MetricCard
              compact
              label={t('erp.metrics.dataReadiness')}
              value={`${data.status.readiness}%`}
            />
            <Progress className="mt-2 h-1.5" value={data.status.readiness} />
          </div>
          <MetricCard
            compact
            label={t('erp.metrics.fieldMapping')}
            value={`${data.status.mappedFields} / ${data.status.totalFields}`}
            hint={t('erp.metrics.fieldMappingHint')}
          />
          <MetricCard
            compact
            label={t('erp.metrics.lastAttempt')}
            value={data.status.lastAttempt}
            hint={t('erp.metrics.lastAttemptHint')}
          />
        </div>
      ) : null}

      <div className="mt-6 flex flex-col gap-2 sm:flex-row sm:flex-wrap">
        <Button type="button" className="touch-target w-full sm:w-auto" disabled>
          <Link2 className="h-4 w-4" />
          {t('erp.actions.mapFields')}
        </Button>
        <Button type="button" variant="outline" className="touch-target w-full sm:w-auto" disabled>
          <RefreshCw className="h-4 w-4" />
          {t('erp.actions.testConnection')}
        </Button>
      </div>
      <p className="mt-2 text-xs text-[var(--color-text-muted)]">{t('common.apiPending')}</p>

      <section className="mt-8">
        <SectionHeader
          title={t('erp.sections.mapping')}
          description={t('erp.sections.mappingDescription')}
        />
        <div className="overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
          <div className="hidden border-b border-[var(--color-border)] bg-[var(--color-bg-surface)] px-4 py-2.5 text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)] sm:grid sm:grid-cols-[1fr_1fr_120px] sm:gap-3">
            <div>{t('erp.columns.pulsField')}</div>
            <div>{t('erp.columns.erpField')}</div>
            <div className="text-right">{t('erp.columns.status')}</div>
          </div>
          <ul className="divide-y divide-[var(--color-border)]">
            {(data?.mappings ?? []).map((mapping) => (
              <li
                key={mapping.puls}
                className="grid grid-cols-1 gap-2 px-4 py-3 sm:grid-cols-[1fr_1fr_120px] sm:items-center sm:gap-3"
              >
                <div className="text-sm font-medium">{mapping.puls}</div>
                <div className="font-mono text-sm text-[var(--color-text-muted)] sm:text-[var(--color-text-secondary)]">
                  {mapping.erp}
                </div>
                <div className="sm:justify-self-end">
                  <StatusPill tone={mapping.status === 'mapped' ? 'success' : 'warning'}>
                    {t(`erp.status.${mapping.status}`)}
                  </StatusPill>
                </div>
              </li>
            ))}
          </ul>
        </div>
      </section>

      <section className="mt-8">
        <SectionHeader
          title={t('erp.sections.syncLogs')}
          description={t('erp.sections.syncLogsDescription')}
        />
        <ul className="divide-y divide-[var(--color-border)] overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
          {(data?.syncLogs ?? []).map((log) => (
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
          ))}
        </ul>
      </section>
    </div>
  )
}
