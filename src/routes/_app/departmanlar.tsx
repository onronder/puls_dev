import { createFileRoute } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import { Building2, UserCheck, UserMinus, Users } from 'lucide-react'
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
import { fetchDepartmentsOverview, type OrgSetupEntitySource } from '#/lib/data'
import { cn } from '#/lib/utils'

export const Route = createFileRoute('/_app/departmanlar')({
  head: () => ({
    meta: [
      { title: i18n.t('departments.meta.title') },
      {
        name: 'description',
        content: i18n.t('departments.meta.description'),
      },
    ],
  }),
  component: DepartmanlarRoute,
})

function DepartmanlarRoute() {
  return (
    <SetupRouteGuard>
      <DepartmanlarPage />
    </SetupRouteGuard>
  )
}

const DEPARTMENT_SKELETON_COUNT = 3
const DEPARTMENT_TABLE_GRID_COLS =
  'grid-cols-[minmax(0,1fr)_88px_minmax(0,1fr)_72px_120px]'

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
      {t(isActive ? 'departments.status.active' : 'departments.status.inactive')}
    </StatusPill>
  )
}

function DepartmanlarPage() {
  const { t } = useTranslation()
  const { user } = useAuth()

  const { data, isLoading } = useQuery({
    queryKey: ['departments-overview', user?.id],
    queryFn: () => fetchDepartmentsOverview(user!.id),
    enabled: Boolean(user?.id),
  })

  const departments = data?.departments ?? []
  const isEmpty = !isLoading && departments.length === 0

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <p className="text-xs font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
        {t('departments.eyebrow')}
      </p>
      <PageHeader
        className="mt-1"
        title={t('departments.title')}
        subtitle={t('departments.description')}
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
            label={t('departments.metrics.departments')}
            value={String(data.departmentCount)}
            icon={Building2}
          />
          <MetricCard
            compact
            label={t('departments.metrics.activeEmployees')}
            value={String(data.activeEmployees)}
            icon={Users}
          />
          <MetricCard
            compact
            label={t('departments.metrics.assignedManagers')}
            value={String(data.assignedManagers)}
            icon={UserCheck}
          />
          <MetricCard
            compact
            label={t('departments.metrics.emptyManagers')}
            value={String(data.emptyManagers)}
            icon={UserMinus}
          />
        </div>
      ) : null}

      <section>
        <SectionHeader title={t('departments.sections.list')} />
        {isEmpty ? (
          <EmptyState
            className="mt-3"
            icon={Building2}
            title={t('orgSetupReadiness.empty.departmentsTitle')}
            description={t('orgSetupReadiness.empty.departments')}
          />
        ) : (
          <>
            <div className="mt-3 md:hidden">
              {isLoading ? (
                <div className="space-y-2">
                  {Array.from({ length: DEPARTMENT_SKELETON_COUNT }, (_, index) => (
                    <Skeleton key={index} className="h-16 w-full rounded-xl" />
                  ))}
                </div>
              ) : (
                <DataList
                  items={departments.map((department) => ({
                    id: department.id,
                    title: department.name,
                    subtitle: [
                      department.code ?? '—',
                      department.manager,
                      t('departments.employeeCount', { count: department.count }),
                    ].join(' · '),
                    trailing: (
                      <div className="flex flex-col items-end gap-1">
                        <ActiveStatusPill isActive={department.isActive} />
                        <OrgEntitySourcePill source={department.source} />
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
                  DEPARTMENT_TABLE_GRID_COLS,
                )}
              >
                <div>{t('departments.columns.name')}</div>
                <div>{t('departments.columns.code')}</div>
                <div>{t('departments.columns.manager')}</div>
                <div className="text-right">{t('departments.columns.count')}</div>
                <div className="text-right">{t('departments.columns.status')}</div>
              </div>
              <ul className="divide-y divide-[var(--color-border)]">
                {isLoading
                  ? Array.from({ length: DEPARTMENT_SKELETON_COUNT }, (_, index) => (
                      <li
                        key={index}
                        className={cn(
                          'grid items-center gap-3 px-4 py-3',
                          DEPARTMENT_TABLE_GRID_COLS,
                        )}
                      >
                        <Skeleton className="h-4 w-32" />
                        <Skeleton className="h-4 w-16" />
                        <Skeleton className="h-4 w-28" />
                        <Skeleton className="ml-auto h-4 w-8" />
                        <Skeleton className="ml-auto h-7 w-24 rounded-full" />
                      </li>
                    ))
                  : departments.map((department) => (
                      <li
                        key={department.id}
                        className={cn(
                          'grid items-center gap-3 px-4 py-3',
                          DEPARTMENT_TABLE_GRID_COLS,
                          !department.isActive && 'opacity-70',
                        )}
                      >
                        <div className="text-sm font-medium">{department.name}</div>
                        <div className="font-mono text-xs text-[var(--color-text-secondary)]">
                          {department.code ?? '—'}
                        </div>
                        <div className="text-sm text-[var(--color-text-secondary)]">{department.manager}</div>
                        <div className="text-right text-sm tabular-nums">{department.count}</div>
                        <div className="flex justify-end gap-1">
                          <ActiveStatusPill isActive={department.isActive} />
                          <OrgEntitySourcePill source={department.source} />
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
