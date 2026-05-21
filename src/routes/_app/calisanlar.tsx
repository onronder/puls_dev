import { Link, createFileRoute } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import { Users } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { DataList } from '#/components/puls/DataList'
import { EmptyState } from '#/components/puls/EmptyState'
import { MetricCard } from '#/components/puls/MetricCard'
import { PageHeader } from '#/components/puls/PageHeader'
import { SectionHeader } from '#/components/puls/SectionHeader'
import { StatusPill } from '#/components/puls/StatusPill'
import { Avatar, AvatarFallback } from '#/components/ui/avatar'
import { Button } from '#/components/ui/button'
import { Skeleton } from '#/components/ui/skeleton'
import { useAuth } from '#/lib/auth'
import { fetchEmployeeList, fetchEmployeeListStats } from '#/lib/queries/employees'

export const Route = createFileRoute('/_app/calisanlar')({
  component: CalisanlarPage,
})

function CalisanlarPage() {
  const { t } = useTranslation()
  const { user, activePersona } = useAuth()

  const { data: stats, isLoading: statsLoading } = useQuery({
    queryKey: ['employee-list-stats', user?.id],
    queryFn: () => fetchEmployeeListStats(user!.id),
    enabled: Boolean(user?.id) && activePersona === 'manager',
  })

  const { data: employees, isLoading, isError, refetch } = useQuery({
    queryKey: ['employee-list', user?.id],
    queryFn: () => fetchEmployeeList(user!.id),
    enabled: Boolean(user?.id) && activePersona === 'manager',
  })

  if (activePersona !== 'manager') {
    return (
      <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
        <EmptyState
          icon={Users}
          title={t('employees.restricted.title')}
          description={t('employees.restricted.description')}
          action={
            <Link to="/dashboard" className="text-sm font-semibold text-[var(--color-primary)]">
              {t('employees.restricted.back')}
            </Link>
          }
        />
      </div>
    )
  }

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <PageHeader
        title={t('employees.title')}
        subtitle={t('employees.subtitle')}
        badge={<StatusPill tone="info">{t('employees.managerOnly')}</StatusPill>}
      />

      <div className="-mx-4 mb-6 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:grid-cols-3 md:overflow-visible md:px-0">
        {statsLoading ? (
          <>
            <Skeleton className="h-28 min-w-[140px] rounded-xl" />
            <Skeleton className="h-28 min-w-[140px] rounded-xl" />
            <Skeleton className="h-28 min-w-[140px] rounded-xl" />
          </>
        ) : (
          <>
            <MetricCard
              compact
              label={t('employees.metrics.active')}
              value={String(stats?.employeeCount ?? 0)}
              icon={Users}
            />
            <MetricCard
              compact
              label={t('employees.metrics.departments')}
              value={String(stats?.departmentCount ?? 0)}
            />
            <MetricCard
              compact
              label={t('employees.metrics.positions')}
              value={String(stats?.positionCount ?? 0)}
            />
          </>
        )}
      </div>

      <SectionHeader title={t('employees.sections.list')} />
      {isError ? (
        <EmptyState
          icon={Users}
          title={t('common.error')}
          description={t('employees.error.loadFailed')}
          action={
            <Button type="button" variant="outline" onClick={() => void refetch()}>
              {t('common.retry')}
            </Button>
          }
        />
      ) : isLoading ? (
        <div className="space-y-2">
          <Skeleton className="h-16 w-full rounded-xl" />
          <Skeleton className="h-16 w-full rounded-xl" />
        </div>
      ) : employees && employees.length > 0 ? (
        <DataList
          items={employees.map((employee) => ({
            id: employee.id,
            title: employee.fullName,
            subtitle: [employee.jobTitle, employee.departmentName].filter(Boolean).join(' · '),
            meta: employee.positionName ?? undefined,
            leading: (
              <Avatar className="h-9 w-9">
                <AvatarFallback className="bg-[var(--color-bg-elevated)] text-xs">
                  {(employee.fullName || '?')
                    .split(' ')
                    .filter(Boolean)
                    .map((part) => part[0])
                    .join('')
                    .slice(0, 2)
                    .toUpperCase()}
                </AvatarFallback>
              </Avatar>
            ),
            trailing: employee.personaRole ? (
              <StatusPill tone="neutral">{employee.personaRole}</StatusPill>
            ) : undefined,
          }))}
        />
      ) : (
        <EmptyState
          icon={Users}
          title={t('employees.empty.title')}
          description={t('employees.empty.description')}
        />
      )}
    </div>
  )
}
