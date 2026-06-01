import { createFileRoute, Link } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import {
  ArrowRight,
  Briefcase,
  Building2,
  CalendarCheck,
  Gauge,
  Layers,
  Plug,
  Receipt,
  Sparkles,
  Target,
  Users,
} from 'lucide-react'
import type { LucideIcon } from 'lucide-react'
import { useMemo } from 'react'
import { useTranslation } from 'react-i18next'

import { EmptyState } from '#/components/puls/EmptyState'
import { MetricCard } from '#/components/puls/MetricCard'
import { SectionHeader } from '#/components/puls/SectionHeader'
import { StatusPill } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { Progress } from '#/components/ui/progress'
import { Skeleton } from '#/components/ui/skeleton'
import i18n from '#/i18n'
import { useAuth } from '#/lib/auth'
import { fetchDashboardOverviewWithMeta, isDashboardEmpty, type DashboardPageData } from '#/lib/data'
import { formatCurrency } from '#/lib/format'
import { cn } from '#/lib/utils'

type DemoDashboardActivity = DashboardPageData['overview']['recentActivities'][number]
type DemoDashboardQueueItem = DashboardPageData['overview']['queue'][number]
type DemoDashboardQueueIcon = DemoDashboardQueueItem['icon']

export const Route = createFileRoute('/_app/dashboard')({
  head: () => ({
    meta: [
      { title: i18n.t('dashboard.meta.title') },
      {
        name: 'description',
        content: i18n.t('dashboard.meta.description'),
      },
    ],
  }),
  component: DashboardPage,
})

const QUEUE_ICONS: Record<DemoDashboardQueueIcon, LucideIcon> = {
  target: Target,
  plug: Plug,
  calendarCheck: CalendarCheck,
  receipt: Receipt,
}

function formatActivityWhat(
  activity: DemoDashboardActivity,
  t: ReturnType<typeof useTranslation>['t'],
  locale: string,
): string {
  if (activity.whatKey === 'profileSetup.activities.expenseReport' && activity.whatParams?.amount != null) {
    return t(activity.whatKey, {
      amount: formatCurrency(Number(activity.whatParams.amount), locale),
    })
  }

  return t(activity.whatKey, activity.whatParams)
}

function formatQueueMeta(
  item: DemoDashboardQueueItem,
  t: ReturnType<typeof useTranslation>['t'],
  locale: string,
  erpMapped: number,
  erpTotal: number,
): string {
  if (item.id === 'q2') {
    return t(item.metaKey, { mapped: erpMapped, total: erpTotal })
  }

  if (item.id === 'q4') {
    return t(item.metaKey, { amount: formatCurrency(1740, locale) })
  }

  return t(item.metaKey)
}

function QueueIconBadge({
  tone,
  icon,
}: {
  tone: DemoDashboardQueueItem['tone']
  icon: DemoDashboardQueueIcon
}) {
  const Icon = QUEUE_ICONS[icon]

  return (
    <span
      className={cn(
        'flex h-9 w-9 shrink-0 items-center justify-center rounded-lg',
        tone === 'warning'
          ? 'bg-[var(--color-warning-soft)] text-[var(--color-warning)]'
          : 'bg-[var(--color-primary-soft)] text-[var(--color-primary)]',
      )}
    >
      <Icon className="h-[18px] w-[18px]" aria-hidden />
    </span>
  )
}

function ErpStat({ label, value }: { label: string; value: string }) {
  return (
    <div className="min-w-0">
      <dt className="text-xs font-medium uppercase tracking-wide text-[var(--color-text-muted)]">
        {label}
      </dt>
      <dd className="mt-1 text-[15px] font-semibold tabular-nums text-[var(--color-text-primary)]">
        {value}
      </dd>
    </div>
  )
}

function QuickActionCard({
  to,
  icon: Icon,
  title,
  hint,
  tone,
}: {
  to: '/izin' | '/masraf' | '/performans'
  icon: LucideIcon
  title: string
  hint: string
  tone: 'primary' | 'info' | 'neutral'
}) {
  const toneCls =
    tone === 'primary'
      ? 'bg-[var(--color-primary-soft)] text-[var(--color-primary)]'
      : tone === 'info'
        ? 'bg-[var(--color-primary-soft)] text-[var(--color-primary)]'
        : 'bg-[var(--color-bg-elevated)] text-[var(--color-text-secondary)]'

  return (
    <Link
      to={to}
      className="flex min-h-[64px] min-w-0 items-center justify-between rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4 transition-colors hover:bg-[var(--color-bg-elevated)]"
    >
      <div className="flex min-w-0 items-center gap-3">
        <span className={cn('flex h-10 w-10 shrink-0 items-center justify-center rounded-lg', toneCls)}>
          <Icon className="h-[18px] w-[18px]" aria-hidden />
        </span>
        <div className="min-w-0">
          <div className="truncate text-sm font-medium text-[var(--color-text-primary)]">{title}</div>
          <div className="truncate text-xs text-[var(--color-text-muted)]">{hint}</div>
        </div>
      </div>
      <ArrowRight className="h-4 w-4 shrink-0 text-[var(--color-text-muted)]" aria-hidden />
    </Link>
  )
}

function DashboardPage() {
  const { t, i18n: i18nInstance } = useTranslation()
  const { user, activePersona } = useAuth()

  const { data: dashboardResult, isLoading, isFetching, isError, refetch } = useQuery({
    queryKey: ['dashboard-overview', user?.id],
    queryFn: () => fetchDashboardOverviewWithMeta(user!.id),
    enabled: Boolean(user?.id),
  })

  const data = dashboardResult?.data
  const stats = data?.stats
  const overview = data?.overview
  const leaveSummary = data?.leaveSummary
  const expenseSummary = data?.expenseSummary
  const visibleQueue =
    activePersona === 'employee'
      ? (overview?.queue ?? []).filter((item) => item.id !== 'q3' && item.id !== 'q4')
      : (overview?.queue ?? [])
  const activeEmployeeCount =
    activePersona === 'employee' && stats?.displayName ? 1 : (stats?.employeeCount ?? 0)

  const dataReadiness = stats?.dataReadinessPct ?? overview?.erpStatus.readiness ?? 0
  const showLoading = isLoading || (isFetching && data ? isDashboardEmpty(data) : false)
  const isEmptyRealDashboard =
    !showLoading && dashboardResult?.source === 'real' && data ? isDashboardEmpty(data) : false

  const welcomeName = stats?.displayName?.split(' ')[0] ?? null

  const formattedDate = useMemo(
    () =>
      new Intl.DateTimeFormat(i18nInstance.language, {
        day: 'numeric',
        month: 'short',
        year: 'numeric',
      }).format(new Date()),
    [i18nInstance.language],
  )

  const erpProvider = stats?.erpProvider ?? t('dashboard.erpNoSourceValue')
  const erpHint = stats?.erpProvider
    ? stats.erpConnected
      ? t('dashboard.erpConnected', { provider: erpProvider })
      : t('dashboard.erpDisconnected')
    : t('dashboard.erpNoSourceHint')

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <div className="flex flex-col gap-1">
        <div className="flex min-w-0 flex-wrap items-center gap-2 text-xs font-medium text-[var(--color-text-muted)]">
          <Building2 className="h-3.5 w-3.5 shrink-0" />
          {showLoading ? (
            <Skeleton className="h-4 w-32 rounded" />
          ) : (
            <span className="truncate">{stats?.tenantName ?? t('dashboard.noTenant')}</span>
          )}
          <span aria-hidden>·</span>
          <span className="shrink-0">{formattedDate}</span>
        </div>
        {showLoading ? (
          <Skeleton className="mt-2 h-9 w-64 max-w-full" />
        ) : (
          <h1 className="text-[26px] font-semibold tracking-tight text-[var(--color-text-primary)] sm:text-3xl">
            {welcomeName ? t('dashboard.welcome', { name: welcomeName }) : t('dashboard.title')}
          </h1>
        )}
        <p className="text-sm text-[var(--color-text-muted)]">{t('dashboard.subtitle')}</p>
      </div>

      {dashboardResult?.source === 'demo' ? (
        <div className="mb-4 mt-4 flex flex-wrap gap-2">
          <StatusPill tone="neutral">{t('orgSetupReadiness.source.demo')}</StatusPill>
        </div>
      ) : null}

      {isError ? (
        <div className="mt-6 rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
          <EmptyState
            icon={Gauge}
            title={t('common.error')}
            description={t('dashboard.error.loadFailed', { defaultValue: t('common.error') })}
            action={
              <Button type="button" variant="outline" className="touch-target" onClick={() => void refetch()}>
                {t('common.retry')}
              </Button>
            }
          />
        </div>
      ) : null}

      {isEmptyRealDashboard ? (
        <section className="mt-6 rounded-xl border border-[color-mix(in_srgb,var(--color-primary)_24%,transparent)] bg-[var(--color-bg-card)] p-5">
          <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
            <div className="min-w-0">
              <div className="flex flex-wrap items-center gap-2">
                <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-[var(--color-primary-soft)] text-[var(--color-primary)]">
                  <Plug className="h-[18px] w-[18px]" aria-hidden />
                </span>
                <StatusPill tone="warning">{t('dashboard.emptyTenant.badge')}</StatusPill>
              </div>
              <h2 className="mt-3 text-lg font-semibold text-[var(--color-text-primary)]">
                {t('dashboard.emptyTenant.title')}
              </h2>
              <p className="mt-1 max-w-2xl text-sm leading-relaxed text-[var(--color-text-muted)]">
                {t('dashboard.emptyTenant.description')}
              </p>
              <ol className="mt-4 grid gap-2 text-xs text-[var(--color-text-secondary)] sm:grid-cols-3">
                {['source', 'mapping', 'team'].map((step) => (
                  <li key={step} className="rounded-lg bg-[var(--color-bg-elevated)] px-3 py-2">
                    {t(`dashboard.emptyTenant.steps.${step}`)}
                  </li>
                ))}
              </ol>
            </div>
            <div className="flex shrink-0 flex-col gap-2 sm:flex-row lg:flex-col xl:flex-row">
              <Button type="button" className="touch-target" asChild>
                <Link to="/erp">
                  {t('dashboard.emptyTenant.primaryAction')}
                  <ArrowRight className="h-3.5 w-3.5" />
                </Link>
              </Button>
              <Button type="button" variant="outline" className="touch-target" asChild>
                <Link to="/sirket-kurulum">{t('dashboard.emptyTenant.secondaryAction')}</Link>
              </Button>
            </div>
          </div>
        </section>
      ) : null}

      <section
        className="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6"
        aria-label={t('dashboard.stats.employees')}
      >
        {showLoading ? (
          Array.from({ length: 6 }).map((_, index) => (
            <Skeleton key={index} className="h-28 w-full rounded-xl" />
          ))
        ) : (
          <>
            <MetricCard
              label={t('dashboard.stats.employees')}
              value={String(activeEmployeeCount)}
              hint={t('dashboard.stats.employeesHint', {
                count: stats?.departmentCount ?? 0,
              })}
              icon={Users}
            />
            <MetricCard
              label={t('dashboard.stats.departments')}
              value={String(stats?.departmentCount ?? 0)}
              hint={t('dashboard.stats.departmentsHint')}
              icon={Building2}
            />
            <MetricCard
              label={t('dashboard.stats.positions')}
              value={String(stats?.positionCount ?? overview?.positionCount ?? 0)}
              hint={t('dashboard.stats.positionsHint')}
              icon={Briefcase}
            />
            <MetricCard
              label={t('dashboard.stats.competencies')}
              value={String(stats?.competencyCount ?? 0)}
              hint={t('dashboard.stats.competenciesHint')}
              icon={Layers}
            />
            <MetricCard
              label={t('dashboard.stats.erp')}
              value={erpProvider}
              hint={erpHint}
              icon={Plug}
            />
            <div className="min-w-0">
              <MetricCard
                label={t('dashboard.stats.dataReadiness')}
                value={`${dataReadiness}%`}
                icon={Gauge}
              />
              <Progress className="mt-2 h-1.5" value={dataReadiness} />
            </div>
          </>
        )}
      </section>

      {overview ? (
        <section className="mt-8 grid gap-5 lg:grid-cols-3">
          <div className="min-w-0 lg:col-span-2">
            <SectionHeader
              title={t('dashboard.sections.workQueue')}
              description={t('dashboard.workQueue.description')}
              action={
                <StatusPill tone="warning">
                  {t('dashboard.workQueue.itemCount', { count: visibleQueue.length })}
                </StatusPill>
              }
            />
            <ul className="mt-3 divide-y divide-[var(--color-border)] overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
              {visibleQueue.map((item) => (
                <li key={item.id}>
                  <Link
                    to={item.to}
                    className="flex min-h-[64px] w-full min-w-0 items-center gap-3 p-4 text-left transition-colors hover:bg-[var(--color-bg-elevated)]"
                  >
                    <QueueIconBadge tone={item.tone} icon={item.icon} />
                    <div className="min-w-0 flex-1">
                      <div className="truncate text-sm font-medium text-[var(--color-text-primary)]">
                        {t(item.titleKey)}
                      </div>
                      <div className="truncate text-xs text-[var(--color-text-muted)]">
                        {formatQueueMeta(
                          item,
                          t,
                          i18nInstance.language,
                          overview.erpStatus.mappedFields,
                          overview.erpStatus.totalFields,
                        )}
                      </div>
                    </div>
                    <ArrowRight
                      className="h-4 w-4 shrink-0 text-[var(--color-text-muted)]"
                      aria-hidden
                    />
                  </Link>
                </li>
              ))}
            </ul>

            <div className="mt-5 rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-5">
              <div className="flex items-start gap-3">
                <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-[var(--color-warning-soft)] text-[var(--color-warning)]">
                  <Plug className="h-[18px] w-[18px]" />
                </span>
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <h2 className="text-[15px] font-semibold text-[var(--color-text-primary)]">
                      {t('dashboardSetup.erpCard.title')}
                    </h2>
                    <StatusPill tone="warning">
                      {t(overview.erpStatus.statusLabelKey)}
                    </StatusPill>
                  </div>
                  <p className="mt-1 text-[13px] leading-relaxed text-[var(--color-text-muted)]">
                    {t(overview.erpStatus.descriptionKey)}
                  </p>
                  <dl className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-3 sm:gap-5">
                    <ErpStat
                      label={t('dashboardSetup.erpCard.fieldMapping')}
                      value={`${overview.erpStatus.mappedFields} / ${overview.erpStatus.totalFields}`}
                    />
                    <ErpStat
                      label={t('dashboardSetup.erpCard.dataReadiness')}
                      value={`%${overview.erpStatus.readiness}`}
                    />
                    <ErpStat
                      label={t('dashboardSetup.erpCard.lastAttempt')}
                      value={t(overview.erpStatus.lastAttemptKey)}
                    />
                  </dl>
                  <div className="mt-4 flex flex-wrap gap-2">
                    <Button type="button" className="touch-target h-10" asChild>
                      <Link to="/erp">
                        {t('dashboardSetup.erpCard.openMapping')}
                        <ArrowRight className="h-3.5 w-3.5" />
                      </Link>
                    </Button>
                    <Button type="button" variant="outline" className="touch-target h-10" asChild>
                      <Link to="/erp">{t('dashboardSetup.erpCard.viewSyncLogs')}</Link>
                    </Button>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div className="min-w-0">
            <SectionHeader
              title={t('dashboard.sections.recentActivity')}
              description={t('dashboardSetup.recentActivityDescription')}
            />
            <ul className="mt-3 divide-y divide-[var(--color-border)] overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
              {overview.recentActivities.map((activity) => (
                <li key={activity.id} className="flex items-start gap-3 p-3.5">
                  <span className="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-[var(--color-bg-elevated)] text-xs font-semibold text-[var(--color-text-secondary)]">
                    {activity.who.charAt(0)}
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="text-[13.5px] text-[var(--color-text-primary)]">
                      <span className="font-medium">{activity.who}</span>{' '}
                      <span className="text-[var(--color-text-muted)]">
                        {formatActivityWhat(activity, t, i18nInstance.language)}
                      </span>
                    </p>
                    <p className="mt-0.5 text-xs text-[var(--color-text-muted)]">
                      {t(activity.whenKey)}
                    </p>
                  </div>
                </li>
              ))}
            </ul>

            <Link
              to="/ai-koc"
              className="mt-5 flex min-w-0 items-start gap-3 rounded-xl border border-[color-mix(in_srgb,var(--color-ai)_25%,transparent)] bg-[var(--color-ai-soft)] p-4 transition-colors hover:bg-[var(--color-ai-soft)]"
            >
              <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-[color-mix(in_srgb,var(--color-ai)_15%,transparent)] text-[var(--color-ai)]">
                <Sparkles className="h-[18px] w-[18px]" aria-hidden />
              </span>
              <div className="min-w-0 flex-1">
                <div className="flex flex-wrap items-center gap-2">
                  <span className="text-[13.5px] font-semibold text-[var(--color-ai)]">
                    {t('dashboard.cards.ai.title')}
                  </span>
                  <StatusPill tone="ai">{t('ai.teaser.badge')}</StatusPill>
                </div>
                <p className="mt-0.5 text-xs leading-relaxed text-[var(--color-text-muted)]">
                  {t('ai.teaser.description')}
                </p>
              </div>
            </Link>
          </div>
        </section>
      ) : null}

      <section className="mt-8" aria-label={t('dashboard.sections.quickActions')}>
        <SectionHeader title={t('dashboard.sections.quickActions')} />
        <div className="mt-3 grid gap-3 sm:grid-cols-3">
          <QuickActionCard
            to="/izin"
            icon={CalendarCheck}
            title={t('dashboardSetup.quickActions.leaveTitle')}
            hint={t('dashboardSetup.quickActions.leaveHint', {
              days: leaveSummary?.heroRemainingAnnual ?? 14,
            })}
            tone="primary"
          />
          <QuickActionCard
            to="/masraf"
            icon={Receipt}
            title={t('dashboardSetup.quickActions.expenseTitle')}
            hint={t('dashboardSetup.quickActions.expenseHint', {
              amount: formatCurrency(expenseSummary?.monthlyLimit ?? 15000, i18nInstance.language),
            })}
            tone="info"
          />
          <QuickActionCard
            to="/performans"
            icon={Target}
            title={t('dashboardSetup.quickActions.performanceTitle')}
            hint={t('dashboardSetup.quickActions.performanceHint')}
            tone="neutral"
          />
        </div>
      </section>

    </div>
  )
}
