import { createFileRoute } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import { Briefcase, ClipboardList } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { SetupRouteGuard } from '#/components/auth/SetupRouteGuard'
import { DataList } from '#/components/puls/DataList'
import { EmptyState } from '#/components/puls/EmptyState'
import { MetricCard } from '#/components/puls/MetricCard'
import { PageHeader } from '#/components/puls/PageHeader'
import { SectionHeader } from '#/components/puls/SectionHeader'
import { StatusPill } from '#/components/puls/StatusPill'
import { Skeleton } from '#/components/ui/skeleton'
import i18n from '#/i18n'
import { useAuth } from '#/lib/auth'
import { fetchPositionsOverview, type OrgSetupEntitySource } from '#/lib/data'
import { cn } from '#/lib/utils'

export const Route = createFileRoute('/_app/pozisyonlar')({
  head: () => ({
    meta: [
      { title: i18n.t('positions.meta.title') },
      {
        name: 'description',
        content: i18n.t('positions.meta.description'),
      },
    ],
  }),
  component: PozisyonlarRoute,
})

function PozisyonlarRoute() {
  return (
    <SetupRouteGuard>
      <PozisyonlarPage />
    </SetupRouteGuard>
  )
}

const POSITION_SKELETON_COUNT = 3
const POSITION_TABLE_GRID_COLS =
  'grid-cols-[minmax(0,1.2fr)_88px_minmax(0,1fr)_72px_120px]'

function OrgEntitySourcePill({ source }: { source: OrgSetupEntitySource }) {
  const { t } = useTranslation()
  const tone =
    source === 'erp' ? 'warning' : source === 'demo' ? 'neutral' : source === 'puls' ? 'success' : 'neutral'
  return <StatusPill tone={tone}>{t(`orgSetupReadiness.source.${source}`)}</StatusPill>
}

function ActiveStatusPill({ isActive }: { isActive: boolean }) {
  const { t } = useTranslation()
  return (
    <StatusPill tone={isActive ? 'success' : 'neutral'}>
      {t(isActive ? 'positions.status.active' : 'positions.status.inactive')}
    </StatusPill>
  )
}

function PozisyonlarPage() {
  const { t } = useTranslation()
  const { user } = useAuth()

  const { data, isLoading } = useQuery({
    queryKey: ['positions-overview', user?.id],
    queryFn: () => fetchPositionsOverview(user!.id),
    enabled: Boolean(user?.id),
  })

  const positions = data?.positions ?? []
  const isEmpty = !isLoading && positions.length === 0
  const showTemplateMetrics = data?.showsTemplateMetrics ?? false

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <p className="text-xs font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
        {t('positions.eyebrow')}
      </p>
      <PageHeader className="mt-1" title={t('positions.title')} subtitle={t('positions.description')} />

      {isLoading ? (
        <div className="-mx-4 mb-6 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:grid-cols-2 md:overflow-visible md:px-0 lg:grid-cols-4">
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
        </div>
      ) : data ? (
        <div
          className={cn(
            '-mx-4 mb-6 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:overflow-visible md:px-0',
            showTemplateMetrics ? 'md:grid-cols-2 lg:grid-cols-4' : 'md:grid-cols-2',
          )}
        >
          <MetricCard
            compact
            label={t('positions.metrics.positions')}
            value={String(data.positionCount)}
            icon={Briefcase}
          />
          <MetricCard
            compact
            label={t('positions.metrics.openPositions')}
            value={String(data.openPositions)}
            icon={ClipboardList}
          />
          {showTemplateMetrics ? (
            <>
              <MetricCard
                compact
                label={t('positions.metrics.templateLinked')}
                value={String(data.templateLinked)}
                icon={Briefcase}
              />
              <MetricCard
                compact
                label={t('positions.metrics.evaluationComplete')}
                value={String(data.evaluationComplete)}
                icon={Briefcase}
              />
            </>
          ) : null}
        </div>
      ) : null}

      <section>
        <SectionHeader title={t('positions.sections.list')} />
        {isEmpty ? (
          <EmptyState
            className="mt-3"
            icon={Briefcase}
            title={t('orgSetupReadiness.empty.positionsTitle')}
            description={t('orgSetupReadiness.empty.positions')}
          />
        ) : (
          <>
            <div className="mt-3 md:hidden">
              {isLoading ? (
                <div className="space-y-2">
                  {Array.from({ length: POSITION_SKELETON_COUNT }, (_, index) => (
                    <Skeleton key={index} className="h-16 w-full rounded-xl" />
                  ))}
                </div>
              ) : (
                <DataList
                  items={positions.map((position) => ({
                    id: position.id,
                    title: position.name,
                    subtitle: [position.code ?? '—', position.department].join(' · '),
                    meta:
                      position.open > 0
                        ? t('positions.openCount', { count: position.open })
                        : undefined,
                    trailing: (
                      <div className="flex flex-col items-end gap-1">
                        <ActiveStatusPill isActive={position.isActive} />
                        <OrgEntitySourcePill source={position.source} />
                      </div>
                    ),
                  }))}
                />
              )}
            </div>

            <div className="mt-3 hidden overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] md:block">
              <div
                className={cn(
                  'grid gap-3 border-b border-[var(--color-border)] bg-[var(--color-bg-surface)] px-4 py-2.5 text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]',
                  POSITION_TABLE_GRID_COLS,
                )}
              >
                <div>{t('positions.columns.name')}</div>
                <div>{t('positions.columns.code')}</div>
                <div>{t('positions.columns.department')}</div>
                <div className="text-right">{t('positions.columns.open')}</div>
                <div className="text-right">{t('positions.columns.status')}</div>
              </div>
              <ul className="divide-y divide-[var(--color-border)]">
                {isLoading
                  ? Array.from({ length: POSITION_SKELETON_COUNT }, (_, index) => (
                      <li
                        key={index}
                        className={cn('grid items-center gap-3 px-4 py-3', POSITION_TABLE_GRID_COLS)}
                      >
                        <Skeleton className="h-4 w-32" />
                        <Skeleton className="h-4 w-16" />
                        <Skeleton className="h-4 w-28" />
                        <Skeleton className="ml-auto h-4 w-8" />
                        <Skeleton className="ml-auto h-7 w-24 rounded-full" />
                      </li>
                    ))
                  : positions.map((position) => (
                      <li
                        key={position.id}
                        className={cn(
                          'grid items-center gap-3 px-4 py-3',
                          POSITION_TABLE_GRID_COLS,
                          !position.isActive && 'opacity-70',
                        )}
                      >
                        <div className="truncate text-sm font-medium">{position.name}</div>
                        <div className="font-mono text-xs text-[var(--color-text-secondary)]">
                          {position.code ?? '—'}
                        </div>
                        <div className="truncate text-sm text-[var(--color-text-secondary)]">
                          {position.department}
                        </div>
                        <div className="text-right text-sm tabular-nums">{position.open}</div>
                        <div className="flex justify-end gap-1">
                          <ActiveStatusPill isActive={position.isActive} />
                          <OrgEntitySourcePill source={position.source} />
                        </div>
                      </li>
                    ))}
              </ul>
            </div>
          </>
        )}
      </section>
    </div>
  )
}
