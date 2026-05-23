import { createFileRoute } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import { BookOpen, CheckCircle2, GraduationCap, Sparkles } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { DataList } from '#/components/puls/DataList'
import { MetricCard } from '#/components/puls/MetricCard'
import { PageHeader } from '#/components/puls/PageHeader'
import { SectionHeader } from '#/components/puls/SectionHeader'
import { StatusPill, type StatusTone } from '#/components/puls/StatusPill'
import { Skeleton } from '#/components/ui/skeleton'
import i18n from '#/i18n'
import { useAuth } from '#/lib/auth'
import { fetchTrainingOverview, type TrainingOverview } from '#/lib/data'
import { cn } from '#/lib/utils'

export const Route = createFileRoute('/_app/egitim')({
  head: () => ({
    meta: [
      { title: i18n.t('trainingSetup.meta.title') },
      {
        name: 'description',
        content: i18n.t('trainingSetup.meta.description'),
      },
    ],
  }),
  component: EgitimPage,
})

const TRAINING_SKELETON_COUNT = 5
const TRAINING_TABLE_GRID_COLS =
  'grid-cols-[minmax(0,1.2fr)_minmax(0,1fr)_minmax(0,1fr)_72px_minmax(0,96px)]'

function trainingStatusTone(status: TrainingOverview['trainings'][number]['status']): StatusTone {
  if (status === 'completed') return 'success'
  if (status === 'planned') return 'info'
  return 'warning'
}

function EgitimPage() {
  const { t } = useTranslation()
  const { user } = useAuth()

  const { data, isLoading } = useQuery({
    queryKey: ['training-overview', user?.id],
    queryFn: () => fetchTrainingOverview(user!.id),
    enabled: Boolean(user?.id),
  })

  const renderStatusPill = (status: TrainingOverview['trainings'][number]['status']) => (
    <StatusPill tone={trainingStatusTone(status)}>{t(`trainingSetup.status.${status}`)}</StatusPill>
  )

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <p className="text-xs font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
        {t('trainingSetup.eyebrow')}
      </p>
      <PageHeader
        className="mt-1"
        title={t('trainingSetup.title')}
        subtitle={t('trainingSetup.description')}
      />

      {isLoading ? (
        <div className="-mx-4 mb-6 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:grid-cols-2 md:overflow-visible md:px-0 lg:grid-cols-4">
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
        </div>
      ) : data ? (
        <div className="-mx-4 mb-5 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:grid-cols-2 md:overflow-visible md:px-0 lg:grid-cols-4">
          <MetricCard
            compact
            label={t('trainingSetup.metrics.openNeed')}
            value={String(data.openNeedCount)}
            icon={BookOpen}
          />
          <MetricCard
            compact
            label={t('trainingSetup.metrics.completed')}
            value={String(data.completedCount)}
            icon={CheckCircle2}
          />
          <MetricCard
            compact
            label={t('trainingSetup.metrics.suggested')}
            value={String(data.suggestedCount)}
            icon={Sparkles}
          />
          <MetricCard
            compact
            label={t('trainingSetup.metrics.averageCompletion')}
            value={t('trainingSetup.metrics.averageCompletionValue', {
              percent: data.averageCompletionPercent,
            })}
            icon={GraduationCap}
          />
        </div>
      ) : null}

      <section className="mb-6">
        <SectionHeader
          title={t('trainingSetup.sections.list')}
          description={t('trainingSetup.sections.listHint')}
        />
        <div className="mt-3 md:hidden">
          {isLoading ? (
            <div className="space-y-2">
              {Array.from({ length: TRAINING_SKELETON_COUNT }, (_, index) => (
                <Skeleton key={index} className="h-16 w-full rounded-xl" />
              ))}
            </div>
          ) : (
            <DataList
              items={(data?.trainings ?? []).map((training) => ({
                id: training.id,
                title: t(training.titleKey),
                subtitle: `${training.employeeName} · ${t(training.competencyKey)}`,
                meta: t('trainingSetup.durationHours', { hours: training.hours }),
                trailing: renderStatusPill(training.status),
              }))}
            />
          )}
        </div>

        <div className="mt-3 hidden overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] md:block">
          <div
            className={cn(
              'grid gap-3 border-b border-[var(--color-border)] bg-[var(--color-bg-surface)] px-4 py-2.5 text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]',
              TRAINING_TABLE_GRID_COLS,
            )}
          >
            <div>{t('trainingSetup.columns.title')}</div>
            <div>{t('trainingSetup.columns.employee')}</div>
            <div>{t('trainingSetup.columns.competency')}</div>
            <div>{t('trainingSetup.columns.duration')}</div>
            <div>{t('trainingSetup.columns.status')}</div>
          </div>
          <ul className="divide-y divide-[var(--color-border)]">
            {isLoading
              ? Array.from({ length: TRAINING_SKELETON_COUNT }, (_, index) => (
                  <li
                    key={index}
                    className={cn('grid items-center gap-3 px-4 py-3', TRAINING_TABLE_GRID_COLS)}
                  >
                    <Skeleton className="h-4 w-32" />
                    <Skeleton className="h-4 w-24" />
                    <Skeleton className="h-4 w-20" />
                    <Skeleton className="h-4 w-12" />
                    <Skeleton className="h-6 w-20 rounded-full" />
                  </li>
                ))
              : (data?.trainings ?? []).map((training) => (
                  <li
                    key={training.id}
                    className={cn('grid items-center gap-3 px-4 py-3', TRAINING_TABLE_GRID_COLS)}
                  >
                    <div className="truncate text-sm font-medium">{t(training.titleKey)}</div>
                    <div className="truncate text-sm text-[var(--color-text-secondary)]">
                      {training.employeeName}
                    </div>
                    <div className="truncate text-sm text-[var(--color-text-secondary)]">
                      {t(training.competencyKey)}
                    </div>
                    <div className="text-sm tabular-nums">
                      {t('trainingSetup.durationHours', { hours: training.hours })}
                    </div>
                    <div>{renderStatusPill(training.status)}</div>
                  </li>
                ))}
          </ul>
        </div>
      </section>

      <div className="rounded-xl border border-[color-mix(in_srgb,var(--color-ai)_25%,transparent)] bg-[var(--color-ai-soft)] p-4">
        <div className="flex items-start gap-3">
          <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-[color-mix(in_srgb,var(--color-ai)_15%,transparent)] text-[var(--color-ai)]">
            <Sparkles className="h-[18px] w-[18px]" />
          </span>
          <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-center gap-2">
              <p className="text-sm font-semibold text-[var(--color-ai)]">
                {t('trainingSetup.schoolTeaser.title')}
              </p>
              <StatusPill tone="ai">{t('common.soon')}</StatusPill>
            </div>
            <p className="mt-1 text-xs leading-relaxed text-[var(--color-text-muted)]">
              {t('trainingSetup.schoolTeaser.description')}
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}
