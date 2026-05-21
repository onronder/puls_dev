import { createFileRoute } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import { Building2, Sparkles, Target, Users } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { DataList } from '#/components/puls/DataList'
import { MetricCard } from '#/components/puls/MetricCard'
import { PageHeader } from '#/components/puls/PageHeader'
import { SectionHeader } from '#/components/puls/SectionHeader'
import { StatusPill } from '#/components/puls/StatusPill'
import { Card, CardContent } from '#/components/ui/card'
import { Progress } from '#/components/ui/progress'
import { Skeleton } from '#/components/ui/skeleton'
import { useAuth } from '#/lib/auth'
import { fetchDemoExpenseOverview, fetchDemoLeaveOverview } from '#/lib/demo/puls-demo-data'
import { fetchDashboardStats } from '#/lib/queries/dashboard'

export const Route = createFileRoute('/_app/dashboard')({
  component: DashboardPage,
})

function DashboardPage() {
  const { t } = useTranslation()
  const { user, activePersona } = useAuth()
  const isManagerView = activePersona === 'manager'

  const { data: stats, isLoading } = useQuery({
    queryKey: ['dashboard-stats', user?.id],
    queryFn: () => fetchDashboardStats(user!.id),
    enabled: Boolean(user?.id),
  })

  const { data: leaveDemo } = useQuery({
    queryKey: ['demo-leave-overview'],
    queryFn: fetchDemoLeaveOverview,
  })

  const { data: expenseDemo } = useQuery({
    queryKey: ['demo-expense-overview'],
    queryFn: fetchDemoExpenseOverview,
  })

  const baglaScore = stats ? Math.min(100, stats.employeeCount * 18) : 0
  const kpiProgress = stats ? Math.min(100, stats.competencyCount * 25) : 0
  const dataReadiness = stats?.employeeCount
    ? Math.min(100, 40 + stats.departmentCount * 10 + stats.competencyCount * 8)
    : 0

  const erpLabel = stats?.erpConnected
    ? t('dashboard.erpConnected', { provider: stats.erpProvider ?? 'Canias' })
    : t('dashboard.erpCaniasInactive')

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <PageHeader
        title={
          isLoading
            ? t('dashboard.title')
            : stats?.displayName
              ? t('dashboard.welcome', { name: stats.displayName })
              : t('dashboard.title')
        }
        subtitle={stats?.tenantName ?? t('dashboard.noTenant')}
        badge={
          <StatusPill tone={isManagerView ? 'info' : 'neutral'}>
            {isManagerView ? t('persona.manager') : t('persona.employee')}
          </StatusPill>
        }
      />

      {isManagerView ? (
        <>
          <div className="-mx-4 mb-6 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:grid-cols-2 md:overflow-visible md:px-0 lg:grid-cols-4">
            {isLoading ? (
              <>
                <Skeleton className="h-28 min-w-[140px] rounded-xl" />
                <Skeleton className="h-28 min-w-[140px] rounded-xl" />
                <Skeleton className="h-28 min-w-[140px] rounded-xl" />
                <Skeleton className="h-28 min-w-[140px] rounded-xl" />
              </>
            ) : (
              <>
                <MetricCard
                  compact
                  label={t('dashboard.stats.employees')}
                  value={String(stats?.employeeCount ?? 0)}
                  icon={Users}
                />
                <MetricCard
                  compact
                  label={t('dashboard.stats.departments')}
                  value={String(stats?.departmentCount ?? 0)}
                  icon={Building2}
                />
                <MetricCard
                  compact
                  label={t('dashboard.stats.competencies')}
                  value={String(stats?.competencyCount ?? 0)}
                  icon={Target}
                />
                <MetricCard
                  compact
                  label={t('dashboard.stats.dataReadiness')}
                  value={`${dataReadiness}%`}
                  hint={erpLabel}
                />
              </>
            )}
          </div>

          <SectionHeader title={t('dashboard.sections.setup')} />
          <DataList
            items={[
              {
                id: 'erp',
                title: t('dashboard.setup.erpTitle'),
                subtitle: erpLabel,
                trailing: <StatusPill tone="warning">{t('dashboard.setup.inactive')}</StatusPill>,
              },
              {
                id: 'approvals',
                title: t('dashboard.setup.approvalsTitle'),
                subtitle: t('dashboard.setup.approvalsHint'),
                meta: String((leaveDemo?.pendingCount ?? 0) + (expenseDemo?.pendingCount ?? 0)),
              },
            ]}
          />
        </>
      ) : (
        <div className="-mx-4 mb-6 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:grid-cols-2 md:overflow-visible md:px-0 lg:grid-cols-3">
          <MetricCard
            compact
            label={t('dashboard.employee.leaveBalance')}
            value={leaveDemo ? `${leaveDemo.heroRemainingAnnual} ${t('common.days')}` : '—'}
          />
          <MetricCard
            compact
            label={t('dashboard.employee.pendingExpense')}
            value={expenseDemo ? `₺${expenseDemo.pendingAmount.toLocaleString('tr-TR')}` : '—'}
          />
          <MetricCard
            compact
            label={t('dashboard.employee.performanceScore')}
            value="93,6"
            hint={t('dashboard.employee.performanceHint')}
          />
        </div>
      )}

      <SectionHeader title={t('dashboard.sections.overview')} className="mt-8" />
      <div className="grid gap-4 lg:grid-cols-3">
        <Card>
          <CardContent className="p-4">
            <p className="text-sm font-semibold">{t('dashboard.cards.bagla.title')}</p>
            <p className="mt-1 text-xs text-[var(--color-text-muted)]">
              {t('dashboard.cards.bagla.description')}
            </p>
            {isLoading ? (
              <Skeleton className="mt-4 h-9 w-16" />
            ) : (
              <p className="mt-4 font-mono text-3xl font-bold text-[var(--color-primary)]">
                {stats?.employeeCount ? `${baglaScore}%` : '—'}
              </p>
            )}
            <Progress className="mt-3" value={baglaScore} />
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4">
            <p className="text-sm font-semibold">{t('dashboard.cards.kpi.title')}</p>
            <p className="mt-1 text-xs text-[var(--color-text-muted)]">
              {isManagerView
                ? t('dashboard.cards.kpi.managerDescription')
                : t('dashboard.cards.kpi.employeeDescription')}
            </p>
            {isLoading ? (
              <Skeleton className="mt-4 h-9 w-16" />
            ) : (
              <p className="mt-4 font-mono text-3xl font-bold">
                {stats?.competencyCount ? `${kpiProgress}%` : '—'}
              </p>
            )}
            <Progress className="mt-3" value={kpiProgress} />
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-2">
              <Sparkles className="h-4 w-4 text-[var(--color-ai)]" />
              <p className="text-sm font-semibold">{t('dashboard.cards.ai.title')}</p>
            </div>
            <p className="mt-1 text-xs text-[var(--color-text-muted)]">
              {t('dashboard.cards.ai.description')}
            </p>
            <StatusPill tone="ai" className="mt-4">
              {t('ai.teaser.badge')}
            </StatusPill>
            <p className="mt-3 text-xs text-[var(--color-text-muted)]">{t('dashboard.cards.ai.hint')}</p>
          </CardContent>
        </Card>
      </div>

      {!isLoading && stats && stats.employeeCount === 0 ? (
        <Card className="mt-6 border-dashed border-[var(--color-border-strong)]">
          <CardContent className="p-6">
            <p className="font-semibold">{t('dashboard.emptySeed.title')}</p>
            <p className="mt-2 text-sm text-[var(--color-text-muted)]">
              {t('dashboard.emptySeed.description')}
            </p>
          </CardContent>
        </Card>
      ) : null}
    </div>
  )
}
