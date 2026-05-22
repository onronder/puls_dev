import { createFileRoute } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import {
  ArrowRight,
  BookOpen,
  Check,
  GraduationCap,
  Sparkles,
  Target,
  TrendingUp,
} from 'lucide-react'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { MetricCard } from '#/components/puls/MetricCard'
import { PageHeader } from '#/components/puls/PageHeader'
import { SectionHeader } from '#/components/puls/SectionHeader'
import { Segmented } from '#/components/puls/Segmented'
import { SheetShell } from '#/components/puls/SheetShell'
import { StatusPill } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { Progress } from '#/components/ui/progress'
import { Skeleton } from '#/components/ui/skeleton'
import i18n from '#/i18n'
import {
  fetchDemoCareerOverview,
  type DemoDevelopmentPlanHorizon,
} from '#/lib/demo/puls-demo-data'
import { cn } from '#/lib/utils'

export const Route = createFileRoute('/_app/kariyer')({
  head: () => ({
    meta: [
      { title: i18n.t('careerSetup.meta.title') },
      {
        name: 'description',
        content: i18n.t('careerSetup.meta.description'),
      },
    ],
  }),
  component: KariyerPage,
})

const PLAN_HORIZONS: DemoDevelopmentPlanHorizon[] = ['d30', 'd90', 'd180']

function KariyerPage() {
  const { t } = useTranslation()
  const [planTab, setPlanTab] = useState<DemoDevelopmentPlanHorizon>('d30')
  const [sheetOpen, setSheetOpen] = useState(false)

  const { data, isLoading } = useQuery({
    queryKey: ['demo-career-overview'],
    queryFn: fetchDemoCareerOverview,
  })

  const planTabOptions = useMemo(
    () =>
      PLAN_HORIZONS.map((horizon) => ({
        value: horizon,
        label: t(`careerSetup.plan.tabs.${horizon}`),
      })),
    [t],
  )

  const readinessValue = data
    ? t('careerSetup.metrics.readinessValue', { percent: data.readinessPercent })
    : ''

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <p className="text-xs font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
        {t('careerSetup.eyebrow')}
      </p>
      <PageHeader
        className="mt-1"
        title={t('careerSetup.title')}
        subtitle={t('careerSetup.description')}
      />

      {isLoading ? (
        <Skeleton className="mb-5 h-24 w-full rounded-xl" />
      ) : data ? (
        <div className="mb-5 flex flex-col gap-3 rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex min-w-0 items-center gap-3">
            <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-[var(--color-primary-soft)] text-base font-semibold text-[var(--color-primary)]">
              {data.employee.initials}
            </span>
            <div className="min-w-0">
              <div className="truncate text-[15px] font-semibold">{data.employee.name}</div>
              <div className="truncate text-xs text-[var(--color-text-muted)]">
                {t(data.employee.positionKey)} · {t(data.employee.departmentKey)}
              </div>
            </div>
          </div>
          <StatusPill tone="info" className="self-start sm:self-center">
            {t('careerSetup.targetRolePill', { role: t(data.targetRoleKey) })}
          </StatusPill>
        </div>
      ) : null}

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
            label={t('careerSetup.metrics.readiness')}
            value={readinessValue}
            icon={TrendingUp}
            hint={t('careerSetup.metrics.readinessHint')}
          />
          <MetricCard
            compact
            label={t('careerSetup.metrics.targetRole')}
            value={t(data.targetRoleKey)}
            icon={Target}
          />
          <MetricCard
            compact
            label={t('careerSetup.metrics.missingCompetencies')}
            value={String(data.missingCompetencyCount)}
            icon={GraduationCap}
          />
          <MetricCard
            compact
            label={t('careerSetup.metrics.recommendedTraining')}
            value={String(data.recommendedTrainingCount)}
            icon={BookOpen}
          />
        </div>
      ) : null}

      <section className="mb-6">
        <SectionHeader
          title={t('careerSetup.sections.ladder')}
          description={data ? t(data.ladderSubtitleKey) : undefined}
        />
        <div className="mt-3 overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
          <ol className="divide-y divide-[var(--color-border)]">
            {isLoading
              ? Array.from({ length: 4 }, (_, index) => (
                  <li key={index} className="flex items-center gap-3 p-4">
                    <Skeleton className="h-8 w-8 rounded-full" />
                    <div className="min-w-0 flex-1 space-y-2">
                      <Skeleton className="h-4 w-40" />
                      <Skeleton className="h-3 w-28" />
                    </div>
                  </li>
                ))
              : (data?.careerLadder ?? []).map((step) => {
                  const statusLabel = step.achieved
                    ? t('careerSetup.ladder.statusAchieved')
                    : step.current
                      ? t('careerSetup.ladder.statusCurrent')
                      : step.target
                        ? t('careerSetup.ladder.statusTarget')
                        : t('careerSetup.ladder.statusNext')

                  return (
                    <li
                      key={step.level}
                      className={cn(
                        'flex min-h-[52px] items-center gap-3 p-4',
                        step.current && 'bg-[var(--color-primary-soft)]',
                      )}
                    >
                      <span
                        className={cn(
                          'flex h-8 w-8 shrink-0 items-center justify-center rounded-full border text-xs font-semibold tabular-nums',
                          step.achieved &&
                            'border-[color-mix(in_srgb,var(--color-success)_35%,transparent)] bg-[var(--color-success-soft)] text-[var(--color-success)]',
                          step.current &&
                            'border-[var(--color-primary)] bg-[var(--color-primary)] text-[var(--color-primary-foreground)]',
                          !step.achieved &&
                            !step.current &&
                            'border-[var(--color-border)] bg-[var(--color-bg-surface)] text-[var(--color-text-muted)]',
                        )}
                        aria-hidden
                      >
                        {step.achieved ? <Check className="h-4 w-4" /> : step.level}
                      </span>
                      <div className="min-w-0 flex-1">
                        <div className="truncate text-sm font-medium">{t(step.titleKey)}</div>
                        <div className="text-xs text-[var(--color-text-muted)]">{statusLabel}</div>
                      </div>
                      {step.target ? (
                        <StatusPill tone="info" className="shrink-0">
                          {t('careerSetup.ladder.pillTarget')}
                        </StatusPill>
                      ) : null}
                      {step.current ? (
                        <StatusPill tone="success" className="shrink-0">
                          {t('careerSetup.ladder.pillYou')}
                        </StatusPill>
                      ) : null}
                    </li>
                  )
                })}
          </ol>
        </div>
      </section>

      <section className="mb-6">
        <SectionHeader
          title={t('careerSetup.sections.gaps')}
          description={t('careerSetup.sections.gapsHint')}
        />
        <div className="mt-3 grid gap-3 sm:grid-cols-3">
          {isLoading
            ? Array.from({ length: 3 }, (_, index) => (
                <Skeleton key={index} className="h-28 rounded-xl" />
              ))
            : (data?.careerGaps ?? []).map((gap) => {
                const gapName = t(gap.nameKey)
                const progressValue = Math.round((gap.current / gap.target) * 100)

                return (
                  <div
                    key={gap.id}
                    className="min-w-0 rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4"
                  >
                    <div className="flex items-baseline justify-between gap-2">
                      <div className="truncate text-sm font-medium">{gapName}</div>
                      <div className="shrink-0 text-xs tabular-nums text-[var(--color-text-muted)]">
                        {gap.current}/{gap.target}
                      </div>
                    </div>
                    <div
                      className="mt-3 min-w-0"
                      role="img"
                      aria-label={t('careerSetup.gaps.progressAria', {
                        name: gapName,
                        current: gap.current,
                        target: gap.target,
                      })}
                    >
                      <Progress value={progressValue} className="h-1.5" />
                    </div>
                    <div className="mt-2 text-xs text-[var(--color-text-muted)]">
                      {t('careerSetup.gaps.developmentArea')} · {progressValue}%
                    </div>
                  </div>
                )
              })}
        </div>
      </section>

      <section className="mb-6">
        <SectionHeader
          title={t('careerSetup.sections.plan')}
          description={t('careerSetup.sections.planHint')}
        />
        <div className="mt-3 overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
          <div className="border-b border-[var(--color-border)] p-3">
            <Segmented
              options={planTabOptions}
              value={planTab}
              onChange={setPlanTab}
              ariaLabel={t('careerSetup.plan.tabsAria')}
            />
          </div>
          <ul className="divide-y divide-[var(--color-border)]">
            {isLoading
              ? Array.from({ length: 2 }, (_, index) => (
                  <li key={index} className="flex items-center gap-3 px-4 py-3">
                    <Skeleton className="h-6 w-6 rounded-full" />
                    <Skeleton className="h-4 w-full max-w-xs" />
                  </li>
                ))
              : (data?.developmentPlan[planTab] ?? []).map((item) => (
                  <li key={item.id} className="flex min-h-[52px] items-center gap-3 px-4 py-3 text-sm">
                    <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-[var(--color-primary-soft)] text-[var(--color-primary)]">
                      <ArrowRight className="h-3.5 w-3.5" />
                    </span>
                    <span className="min-w-0 text-[var(--color-text-primary)]">{t(item.labelKey)}</span>
                  </li>
                ))}
          </ul>
        </div>
      </section>

      <div className="flex flex-col gap-2 sm:flex-row">
        <Button
          type="button"
          className="touch-target h-11 flex-1"
          onClick={() => setSheetOpen(true)}
        >
          {t('careerSetup.actions.createPlan')}
        </Button>
        <Button type="button" variant="outline" className="touch-target h-11 flex-1" disabled>
          {t('careerSetup.actions.viewTraining')}
        </Button>
        <Button
          type="button"
          variant="outline"
          className="touch-target h-11 flex-1 border-[color-mix(in_srgb,var(--color-ai)_30%,transparent)] bg-[var(--color-ai-soft)] text-[var(--color-ai)] opacity-90"
          disabled
        >
          <Sparkles className="h-4 w-4" />
          {t('careerSetup.actions.aiCoach')}
        </Button>
      </div>

      <SheetShell
        open={sheetOpen}
        onOpenChange={setSheetOpen}
        title={t('careerSetup.sheet.title')}
        description={t('careerSetup.sheet.description')}
        footer={
          <div className="flex w-full flex-col gap-3">
            <StatusPill tone="neutral" className="self-start">
              {t('careerSetup.sheet.mvpBadge')}
            </StatusPill>
            <Button type="button" className="touch-target w-full" disabled>
              {t('careerSetup.sheet.submit')}
            </Button>
          </div>
        }
      >
        <div className="space-y-4">
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-4">
            <p className="text-sm font-medium">{t('careerSetup.sheet.previewTitle')}</p>
            <p className="mt-2 text-sm text-[var(--color-text-muted)]">
              {t('careerSetup.sheet.previewHorizon')}
            </p>
            <ul className="mt-3 space-y-2 text-sm text-[var(--color-text-secondary)]">
              {PLAN_HORIZONS.flatMap((horizon) =>
                (data?.developmentPlan[horizon] ?? []).map((item) => (
                  <li key={`${horizon}-${item.id}`} className="flex gap-2">
                    <span className="shrink-0 text-[var(--color-text-muted)]">
                      {t(`careerSetup.plan.tabs.${horizon}`)}:
                    </span>
                    <span>{t(item.labelKey)}</span>
                  </li>
                )),
              )}
            </ul>
          </div>
          <p className="text-xs text-[var(--color-text-muted)]">{t('careerSetup.sheet.previewNote')}</p>
        </div>
      </SheetShell>
    </div>
  )
}
