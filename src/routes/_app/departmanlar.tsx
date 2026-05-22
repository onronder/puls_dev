import { createFileRoute } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import { Building2, Plus, UserCheck, UserMinus, Users } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { DataList } from '#/components/puls/DataList'
import { FormField } from '#/components/puls/FormField'
import { MetricCard } from '#/components/puls/MetricCard'
import { PageHeader } from '#/components/puls/PageHeader'
import { SectionHeader } from '#/components/puls/SectionHeader'
import { SheetShell } from '#/components/puls/SheetShell'
import { StatusPill } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { Input } from '#/components/ui/input'
import { Skeleton } from '#/components/ui/skeleton'
import i18n from '#/i18n'
import { fetchDemoDepartmentsOverview } from '#/lib/demo/puls-demo-data'
import { requireSetupAdminRoute } from '#/lib/setup-access'
import { cn } from '#/lib/utils'

export const Route = createFileRoute('/_app/departmanlar')({
  beforeLoad: async () => {
    await requireSetupAdminRoute()
  },
  head: () => ({
    meta: [
      { title: i18n.t('departments.meta.title') },
      {
        name: 'description',
        content: i18n.t('departments.meta.description'),
      },
    ],
  }),
  component: DepartmanlarPage,
})

const DEPARTMENT_SKELETON_COUNT = 3
const DEPARTMENT_TABLE_GRID_COLS = 'grid-cols-[1fr_1fr_100px_100px]'

function DepartmanlarPage() {
  const { t } = useTranslation()
  const [sheetOpen, setSheetOpen] = useState(false)

  const { data, isLoading } = useQuery({
    queryKey: ['demo-departments-overview'],
    queryFn: fetchDemoDepartmentsOverview,
  })

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <p className="text-xs font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
        {t('departments.eyebrow')}
      </p>
      <PageHeader
        className="mt-1"
        title={t('departments.title')}
        subtitle={t('departments.description')}
        actions={
          <Button type="button" className="touch-target w-full sm:w-auto" onClick={() => setSheetOpen(true)}>
            <Plus className="h-4 w-4" />
            {t('departments.actions.add')}
          </Button>
        }
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
        <div className="mt-3 md:hidden">
          {isLoading ? (
            <div className="space-y-2">
              {Array.from({ length: DEPARTMENT_SKELETON_COUNT }, (_, index) => (
                <Skeleton key={index} className="h-16 w-full rounded-xl" />
              ))}
            </div>
          ) : (
            <DataList
              items={(data?.departments ?? []).map((department) => ({
                id: department.id,
                title: department.name,
                subtitle: department.manager,
                meta: t('departments.employeeCount', { count: department.count }),
                trailing: (
                  <StatusPill tone="success">{t('departments.status.active')}</StatusPill>
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
                    <Skeleton className="h-4 w-28" />
                    <Skeleton className="ml-auto h-4 w-8" />
                    <Skeleton className="ml-auto h-7 w-16 rounded-full" />
                  </li>
                ))
              : (data?.departments ?? []).map((department) => (
                  <li
                    key={department.id}
                    className={cn(
                      'grid items-center gap-3 px-4 py-3',
                      DEPARTMENT_TABLE_GRID_COLS,
                    )}
                  >
                    <div className="text-sm font-medium">{department.name}</div>
                    <div className="text-sm text-[var(--color-text-secondary)]">{department.manager}</div>
                    <div className="text-right text-sm tabular-nums">{department.count}</div>
                    <div className="flex justify-end">
                      <StatusPill tone="success">{t('departments.status.active')}</StatusPill>
                    </div>
                  </li>
                ))}
          </ul>
        </div>
      </section>

      <SheetShell
        open={sheetOpen}
        onOpenChange={setSheetOpen}
        title={t('departments.sheet.title')}
        description={t('departments.sheet.description')}
        footer={
          <div className="flex w-full flex-col gap-3">
            <StatusPill tone="neutral" className="self-start">
              {t('common.soon')}
            </StatusPill>
            <Button type="button" className="touch-target w-full" disabled>
              {t('departments.sheet.submit')}
            </Button>
          </div>
        }
      >
        <div className="space-y-4">
          <FormField label={t('departments.sheet.fields.name')} htmlFor="department-name">
            <Input
              id="department-name"
              className="text-base"
              placeholder={t('departments.sheet.placeholders.name')}
              disabled
            />
          </FormField>
          <FormField label={t('departments.sheet.fields.manager')} htmlFor="department-manager">
            <Input
              id="department-manager"
              className="text-base"
              placeholder={t('departments.sheet.placeholders.manager')}
              disabled
            />
          </FormField>
        </div>
      </SheetShell>
    </div>
  )
}
