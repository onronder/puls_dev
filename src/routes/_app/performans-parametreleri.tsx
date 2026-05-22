import { createFileRoute } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import { AlertCircle, Layers, SlidersHorizontal, Target } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { MetricCard } from '#/components/puls/MetricCard'
import { PageHeader } from '#/components/puls/PageHeader'
import { SectionHeader } from '#/components/puls/SectionHeader'
import { StatusPill, type StatusTone } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { Progress } from '#/components/ui/progress'
import { Skeleton } from '#/components/ui/skeleton'
import i18n from '#/i18n'
import {
  fetchDemoPerformanceParametersOverview,
  type DemoPerformanceScoreBandTone,
} from '#/lib/demo/puls-demo-data'
import { requireSetupAdminRoute } from '#/lib/setup-access'

export const Route = createFileRoute('/_app/performans-parametreleri')({
  beforeLoad: async () => {
    await requireSetupAdminRoute()
  },
  head: () => ({
    meta: [
      { title: i18n.t('performanceParamsSetup.meta.title') },
      {
        name: 'description',
        content: i18n.t('performanceParamsSetup.meta.description'),
      },
    ],
  }),
  component: PerformansParametreleriPage,
})

const TEMPLATE_SKELETON_COUNT = 3
const SCORE_BAND_SKELETON_COUNT = 5

function toStatusTone(tone: DemoPerformanceScoreBandTone): StatusTone {
  return tone
}

function formatUpdatedDate(isoDate: string, locale: string): string {
  return new Intl.DateTimeFormat(locale, {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  }).format(new Date(`${isoDate}T12:00:00`))
}

function PerformansParametreleriPage() {
  const { t, i18n: i18nInstance } = useTranslation()

  const { data, isLoading } = useQuery({
    queryKey: ['demo-performance-parameters-overview'],
    queryFn: fetchDemoPerformanceParametersOverview,
  })

  const activeCycleLabel = data?.hasActiveCycle
    ? t('performanceParamsSetup.metrics.activeCycle')
    : t('performanceParamsSetup.metrics.noActiveCycle')

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <p className="text-xs font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
        {t('performanceParamsSetup.eyebrow')}
      </p>
      <PageHeader
        className="mt-1"
        title={t('performanceParamsSetup.title')}
        subtitle={t('performanceParamsSetup.description')}
      />

      {isLoading ? (
        <div className="-mx-4 mb-6 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:grid-cols-2 md:overflow-visible md:px-0 lg:grid-cols-4">
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
        </div>
      ) : data ? (
        <div className="-mx-4 mb-6 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:grid-cols-2 md:overflow-visible md:px-0 lg:grid-cols-4">
          <MetricCard
            compact
            label={t('performanceParamsSetup.metrics.competencyTemplates')}
            value={String(data.competencyTemplateCount)}
            icon={Layers}
          />
          <MetricCard
            compact
            label={t('performanceParamsSetup.metrics.kpiCategories')}
            value={String(data.kpiCategoryCount)}
            icon={Target}
          />
          <MetricCard
            compact
            label={t('performanceParamsSetup.metrics.scoreBands')}
            value={String(data.scoreBandCount)}
            icon={SlidersHorizontal}
          />
          <MetricCard
            compact
            label={t('performanceParamsSetup.metrics.activeCycle')}
            value={activeCycleLabel}
            icon={AlertCircle}
          />
        </div>
      ) : null}

      <section className="mb-6">
        <SectionHeader title={t('performanceParamsSetup.sections.competencyTemplates')} />
        <ul className="mt-3 divide-y divide-[var(--color-border)] overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
          {isLoading
            ? Array.from({ length: TEMPLATE_SKELETON_COUNT }, (_, index) => (
                <li key={index} className="flex min-h-[52px] items-center justify-between gap-3 p-4">
                  <div className="min-w-0 flex-1 space-y-2">
                    <Skeleton className="h-4 w-40" />
                    <Skeleton className="h-3 w-56" />
                  </div>
                  <Skeleton className="h-9 w-20 rounded-md" />
                </li>
              ))
            : (data?.competencyTemplates ?? []).map((template) => (
                <li
                  key={template.id}
                  className="flex min-h-[52px] flex-col gap-3 p-4 sm:flex-row sm:items-center sm:justify-between"
                >
                  <div className="min-w-0 flex-1">
                    <div className="text-sm font-medium">{t(template.nameKey)}</div>
                    <div className="mt-1 text-xs text-[var(--color-text-muted)]">
                      {t('performanceParamsSetup.templateMeta', {
                        areas: template.areas,
                        date: formatUpdatedDate(template.updatedAt, i18nInstance.language),
                      })}
                    </div>
                  </div>
                  <Button type="button" variant="outline" size="sm" className="touch-target shrink-0" disabled>
                    {t('performanceParamsSetup.actions.edit')}
                  </Button>
                </li>
              ))}
        </ul>
      </section>

      <section className="mb-6">
        <SectionHeader
          title={t('performanceParamsSetup.sections.kpiWeights')}
          description={t('performanceParamsSetup.sections.kpiWeightsHint')}
        />
        <div className="mt-3 space-y-3 rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
          {isLoading
            ? Array.from({ length: 4 }, (_, index) => (
                <div key={index} className="grid grid-cols-[minmax(0,1fr)_minmax(0,1fr)_3rem] items-center gap-3">
                  <Skeleton className="h-4 w-24" />
                  <Skeleton className="h-2 w-full rounded-full" />
                  <Skeleton className="ml-auto h-4 w-10" />
                </div>
              ))
            : (data?.kpiCategories ?? []).map((category) => {
                const categoryName = t(category.nameKey)
                return (
                  <div
                    key={category.id}
                    className="grid grid-cols-[minmax(0,1fr)_minmax(0,1fr)_3rem] items-center gap-3 sm:grid-cols-[minmax(0,180px)_minmax(0,1fr)_3.5rem]"
                  >
                    <div className="truncate text-sm">{categoryName}</div>
                    <div
                      className="min-w-0"
                      role="img"
                      aria-label={t('performanceParamsSetup.kpiWeightAria', {
                        name: categoryName,
                        weight: category.weight,
                      })}
                    >
                      <Progress value={category.weight} className="h-1.5" />
                    </div>
                    <div className="text-right text-sm font-medium tabular-nums">
                      {t('performanceParamsSetup.kpiWeightLabel', { weight: category.weight })}
                    </div>
                  </div>
                )
              })}
        </div>
      </section>

      <section>
        <SectionHeader title={t('performanceParamsSetup.sections.scoreBands')} />
        <ul className="mt-3 divide-y divide-[var(--color-border)] overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
          {isLoading
            ? Array.from({ length: SCORE_BAND_SKELETON_COUNT }, (_, index) => (
                <li key={index} className="flex min-h-[52px] items-center justify-between gap-3 p-4">
                  <Skeleton className="h-7 w-24 rounded-full" />
                  <Skeleton className="h-3 w-28" />
                </li>
              ))
            : (data?.scoreBands ?? []).map((band) => (
                <li
                  key={band.id}
                  className="flex min-h-[52px] flex-col gap-2 p-4 sm:flex-row sm:items-center sm:justify-between"
                >
                  <div className="flex min-w-0 flex-wrap items-center gap-3">
                    <StatusPill tone={toStatusTone(band.tone)}>{t(band.labelKey)}</StatusPill>
                    <span className="text-xs tabular-nums text-[var(--color-text-muted)]">
                      {t('performanceParamsSetup.scoreRange', { min: band.min, max: band.max })}
                    </span>
                  </div>
                  <div className="text-xs text-[var(--color-text-muted)]">
                    {t('performanceParamsSetup.premiumCoefficient')}
                  </div>
                </li>
              ))}
        </ul>
      </section>
    </div>
  )
}
