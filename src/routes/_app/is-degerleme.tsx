import { createFileRoute } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import { AlertCircle, Award, BarChart3, Scale } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { MetricCard } from '#/components/puls/MetricCard'
import { PageHeader } from '#/components/puls/PageHeader'
import { SectionHeader } from '#/components/puls/SectionHeader'
import { StatusPill, type StatusTone } from '#/components/puls/StatusPill'
import { Progress } from '#/components/ui/progress'
import { Skeleton } from '#/components/ui/skeleton'
import i18n from '#/i18n'
import { fetchDemoJobEvaluationOverview } from '#/lib/demo/puls-demo-data'

export const Route = createFileRoute('/_app/is-degerleme')({
  head: () => ({
    meta: [
      { title: i18n.t('jobEvaluationSetup.meta.title') },
      {
        name: 'description',
        content: i18n.t('jobEvaluationSetup.meta.description'),
      },
    ],
  }),
  component: IsDegerlemePage,
})

const POSITION_SKELETON_COUNT = 3
const FACTOR_ROW_GRID =
  'grid grid-cols-[minmax(0,110px)_minmax(0,1fr)_3rem] items-center gap-3 sm:grid-cols-[minmax(0,160px)_minmax(0,1fr)_3.5rem]'

function IsDegerlemePage() {
  const { t } = useTranslation()

  const { data, isLoading } = useQuery({
    queryKey: ['demo-job-evaluation-overview'],
    queryFn: fetchDemoJobEvaluationOverview,
  })

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <p className="text-xs font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
        {t('jobEvaluationSetup.eyebrow')}
      </p>
      <PageHeader
        className="mt-1"
        title={t('jobEvaluationSetup.title')}
        subtitle={t('jobEvaluationSetup.description')}
      />

      {isLoading ? (
        <div className="-mx-4 mb-5 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:grid-cols-2 md:overflow-visible md:px-0 lg:grid-cols-4">
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
        </div>
      ) : data ? (
        <div className="-mx-4 mb-5 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:grid-cols-2 md:overflow-visible md:px-0 lg:grid-cols-4">
          <MetricCard
            compact
            label={t('jobEvaluationSetup.metrics.evaluatedPositions')}
            value={String(data.evaluatedPositionCount)}
            icon={Scale}
          />
          <MetricCard
            compact
            label={t('jobEvaluationSetup.metrics.averageScore')}
            value={String(data.averageScore)}
            hint={t('jobEvaluationSetup.metrics.averageScoreHint')}
            icon={BarChart3}
          />
          <MetricCard
            compact
            label={t('jobEvaluationSetup.metrics.highLevel')}
            value={String(data.highLevelCount)}
            icon={Award}
          />
          <MetricCard
            compact
            label={t('jobEvaluationSetup.metrics.missingEvaluation')}
            value={String(data.missingEvaluationCount)}
            icon={AlertCircle}
          />
        </div>
      ) : null}

      <section className="mb-6">
        <SectionHeader
          title={t('jobEvaluationSetup.sections.positionScores')}
          description={t('jobEvaluationSetup.sections.positionScoresHint')}
        />
        <div className="mt-3 space-y-3">
          {isLoading
            ? Array.from({ length: POSITION_SKELETON_COUNT }, (_, index) => (
                <Skeleton key={index} className="h-44 w-full rounded-xl" />
              ))
            : (data?.positions ?? []).map((position) => (
                <article
                  key={position.id}
                  className="min-w-0 rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4"
                >
                  <header className="mb-3 flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <div className="truncate text-[15px] font-semibold">
                        {t(position.positionKey)}
                      </div>
                      <StatusPill tone="info" className="mt-2">
                        {t(position.bandKey)}
                      </StatusPill>
                    </div>
                    <div className="shrink-0 text-right">
                      <div className="text-2xl font-semibold tabular-nums">{position.total}</div>
                      <div className="text-xs uppercase tracking-wider text-[var(--color-text-muted)]">
                        {t('jobEvaluationSetup.scoreOfMax', { max: data?.maxTotalScore ?? 1000 })}
                      </div>
                    </div>
                  </header>
                  <dl className="space-y-2">
                    {(data?.evaluationFactors ?? []).map((factor) => {
                      const score = position.factors[factor.key]
                      const factorLabel = t(factor.labelKey)
                      const progressValue = Math.round((score / factor.maxScore) * 100)

                      return (
                        <div key={factor.key} className={FACTOR_ROW_GRID}>
                          <dt className="truncate text-xs text-[var(--color-text-muted)]">
                            {factorLabel}
                          </dt>
                          <dd className="min-w-0">
                            <div
                              role="img"
                              aria-label={t('jobEvaluationSetup.factorScoreAria', {
                                factor: factorLabel,
                                score,
                                max: factor.maxScore,
                              })}
                            >
                              <Progress value={progressValue} className="h-1.5" />
                            </div>
                          </dd>
                          <dd className="text-right text-xs font-medium tabular-nums">{score}</dd>
                        </div>
                      )
                    })}
                  </dl>
                </article>
              ))}
        </div>
      </section>

      <section>
        <SectionHeader title={t('jobEvaluationSetup.sections.levelBands')} />
        <div className="mt-3 grid gap-2 sm:grid-cols-3">
          {isLoading
            ? Array.from({ length: 3 }, (_, index) => (
                <Skeleton key={index} className="h-24 rounded-xl" />
              ))
            : (data?.levelBands ?? []).map((band) => (
                <div
                  key={band.id}
                  className="min-w-0 rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4"
                >
                  <StatusPill tone={band.tone as StatusTone}>{t(band.levelKey)}</StatusPill>
                  <div className="mt-2 text-sm font-medium tabular-nums">{t(band.rangeKey)}</div>
                  <div className="text-xs text-[var(--color-text-muted)]">{t(band.noteKey)}</div>
                </div>
              ))}
        </div>
      </section>
    </div>
  )
}
