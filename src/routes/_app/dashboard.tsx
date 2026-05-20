import { createFileRoute } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'

import { Badge } from '#/components/ui/badge'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '#/components/ui/card'
import { Progress } from '#/components/ui/progress'
import { Separator } from '#/components/ui/separator'
import { Skeleton } from '#/components/ui/skeleton'
import { useAuth } from '#/lib/auth'
import { fetchDashboardStats } from '#/lib/queries/dashboard'

export const Route = createFileRoute('/_app/dashboard')({
  component: DashboardPage,
})

function DashboardPage() {
  const { t } = useTranslation()
  const { user, activePersona } = useAuth()

  const { data: stats, isLoading } = useQuery({
    queryKey: ['dashboard-stats', user?.id],
    queryFn: () => fetchDashboardStats(user!.id),
    enabled: Boolean(user?.id),
  })

  const isManagerView = activePersona === 'manager'
  const baglaScore = stats ? Math.min(100, stats.employeeCount * 18) : 0
  const kpiProgress = stats ? Math.min(100, stats.competencyCount * 25) : 0

  return (
    <div className="mx-auto max-w-5xl p-4 md:p-8">
      <div className="mb-6">
        {isLoading ? (
          <Skeleton className="h-8 w-48" />
        ) : (
          <h1 className="text-2xl font-bold md:text-3xl">
            {stats?.displayName
              ? t('dashboard.welcome', { name: stats.displayName })
              : t('dashboard.title')}
          </h1>
        )}
        <p className="mt-2 text-[var(--color-text-muted)]">
          {stats?.tenantName ?? t('dashboard.noTenant')}
        </p>
        {isManagerView ? (
          <Badge variant="secondary" className="mt-3">
            {t('persona.manager')}
          </Badge>
        ) : (
          <Badge variant="outline" className="mt-3">
            {t('persona.employee')}
          </Badge>
        )}
      </div>

      {isManagerView ? (
        <div className="mb-6 grid gap-3 sm:grid-cols-3">
          <StatChip label={t('dashboard.stats.employees')} value={stats?.employeeCount} loading={isLoading} />
          <StatChip label={t('dashboard.stats.departments')} value={stats?.departmentCount} loading={isLoading} />
          <StatChip label={t('dashboard.stats.competencies')} value={stats?.competencyCount} loading={isLoading} />
        </div>
      ) : null}

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <Card>
          <CardHeader>
            <CardTitle className="text-base">{t('dashboard.cards.bagla.title')}</CardTitle>
            <CardDescription>{t('dashboard.cards.bagla.description')}</CardDescription>
          </CardHeader>
          <CardContent>
            {isLoading ? (
              <Skeleton className="h-9 w-16" />
            ) : (
              <p className="font-mono text-3xl font-bold text-[var(--color-primary)]">
                {stats?.employeeCount ? `${baglaScore}%` : '—'}
              </p>
            )}
            <Progress className="mt-3" value={baglaScore} />
            <p className="mt-2 text-xs text-[var(--color-text-muted)]">
              {t('dashboard.cards.bagla.hint')}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">{t('dashboard.cards.kpi.title')}</CardTitle>
            <CardDescription>
              {isManagerView
                ? t('dashboard.cards.kpi.managerDescription')
                : t('dashboard.cards.kpi.employeeDescription')}
            </CardDescription>
          </CardHeader>
          <CardContent>
            {isLoading ? (
              <Skeleton className="h-9 w-16" />
            ) : (
              <p className="font-mono text-3xl font-bold">
                {stats?.competencyCount ? `${kpiProgress}%` : '—'}
              </p>
            )}
            <Progress className="mt-3" value={kpiProgress} />
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">{t('dashboard.cards.ai.title')}</CardTitle>
            <CardDescription>{t('dashboard.cards.ai.description')}</CardDescription>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-[var(--color-text-secondary)]">
              {t('dashboard.cards.ai.hint')}
            </p>
            <Separator className="my-3" />
            <p className="text-xs text-[var(--color-text-muted)]">
              ERP:{' '}
              {stats?.erpConnected
                ? t('dashboard.erpConnected', { provider: stats.erpProvider ?? '—' })
                : t('dashboard.erpDisconnected')}
            </p>
          </CardContent>
        </Card>
      </div>

      {!isLoading && stats && stats.employeeCount === 0 ? (
        <Card className="mt-6 border-dashed border-[var(--color-border-strong)]">
          <CardHeader>
            <CardTitle className="text-base">{t('dashboard.emptySeed.title')}</CardTitle>
            <CardDescription>{t('dashboard.emptySeed.description')}</CardDescription>
          </CardHeader>
        </Card>
      ) : null}
    </div>
  )
}

function StatChip({
  label,
  value,
  loading,
}: {
  label: string
  value?: number
  loading: boolean
}) {
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-4 py-3">
      <p className="text-xs text-[var(--color-text-muted)]">{label}</p>
      {loading ? (
        <Skeleton className="mt-2 h-7 w-10" />
      ) : (
        <p className="mt-1 font-mono text-2xl font-bold">{value ?? 0}</p>
      )}
    </div>
  )
}
