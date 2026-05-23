import { createFileRoute } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import { CalendarDays, Check, FileCheck2, Plus, Workflow } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { SetupRouteGuard } from '#/components/auth/SetupRouteGuard'
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
import { useAuth } from '#/lib/auth'
import { fetchLeaveTypesOverview, type LeaveTypesOverview } from '#/lib/data'
import { cn } from '#/lib/utils'

export const Route = createFileRoute('/_app/izin-tanimlari')({
  head: () => ({
    meta: [
      { title: i18n.t('leaveTypeSetup.meta.title') },
      {
        name: 'description',
        content: i18n.t('leaveTypeSetup.meta.description'),
      },
    ],
  }),
  component: IzinTanimlariRoute,
})

function IzinTanimlariRoute() {
  return (
    <SetupRouteGuard>
      <IzinTanimlariPage />
    </SetupRouteGuard>
  )
}

const LEAVE_TYPE_SKELETON_COUNT = 4
const LEAVE_TYPE_TABLE_GRID_COLS =
  'grid-cols-[minmax(0,1.1fr)_56px_minmax(0,88px)_minmax(0,88px)_72px]'

type LeaveTypeCellsProps = {
  rule: LeaveTypesOverview['leaveTypes'][number]
}

function PaidCell({ rule }: LeaveTypeCellsProps) {
  const { t } = useTranslation()
  return (
    <StatusPill tone={rule.paid ? 'success' : 'neutral'}>
      {t(rule.paid ? 'leaveTypeSetup.paid.yes' : 'leaveTypeSetup.paid.no')}
    </StatusPill>
  )
}

function DocCell({ rule }: LeaveTypeCellsProps) {
  const { t } = useTranslation()
  if (!rule.doc) {
    return <span className="text-sm text-[var(--color-text-muted)]">{t('leaveTypeSetup.doc.none')}</span>
  }
  return <StatusPill tone="warning">{t('leaveTypeSetup.doc.required')}</StatusPill>
}

function CarryOverCell({ rule }: LeaveTypeCellsProps) {
  const { t } = useTranslation()
  if (!rule.carryOver) {
    return <span className="text-sm text-[var(--color-text-muted)]">{t('leaveTypeSetup.carryOver.none')}</span>
  }
  return (
    <span className="inline-flex items-center gap-1 text-sm font-medium text-[var(--color-success)]">
      <Check className="h-3.5 w-3.5 shrink-0" aria-hidden />
      {t('leaveTypeSetup.carryOver.yes')}
    </span>
  )
}

function MobileRuleTrailing({ rule }: LeaveTypeCellsProps) {
  return (
    <div className="flex shrink-0 flex-col items-end gap-1">
      <PaidCell rule={rule} />
      {rule.doc ? <DocCell rule={rule} /> : null}
    </div>
  )
}

function IzinTanimlariPage() {
  const { t } = useTranslation()
  const { user } = useAuth()
  const [sheetOpen, setSheetOpen] = useState(false)

  const { data, isLoading } = useQuery({
    queryKey: ['leave-types-overview', user?.id],
    queryFn: () => fetchLeaveTypesOverview(user!.id),
    enabled: Boolean(user?.id),
  })

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <p className="text-xs font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
        {t('leaveTypeSetup.eyebrow')}
      </p>
      <PageHeader
        className="mt-1"
        title={t('leaveTypeSetup.title')}
        subtitle={t('leaveTypeSetup.description')}
        actions={
          <Button type="button" className="touch-target w-full sm:w-auto" onClick={() => setSheetOpen(true)}>
            <Plus className="h-4 w-4" />
            {t('leaveTypeSetup.actions.add')}
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
            label={t('leaveTypeSetup.metrics.typeCount')}
            value={String(data.typeCount)}
            icon={CalendarDays}
          />
          <MetricCard
            compact
            label={t('leaveTypeSetup.metrics.paidCount')}
            value={String(data.paidCount)}
            icon={Check}
          />
          <MetricCard
            compact
            label={t('leaveTypeSetup.metrics.docRequiredCount')}
            value={String(data.docRequiredCount)}
            icon={FileCheck2}
          />
          <MetricCard
            compact
            label={t('leaveTypeSetup.metrics.approvalFlow')}
            value={t('leaveTypeSetup.metrics.approvalFlowValue')}
            icon={Workflow}
          />
        </div>
      ) : null}

      <section>
        <SectionHeader title={t('leaveTypeSetup.sections.list')} />
        <div className="mt-3 md:hidden">
          {isLoading ? (
            <div className="space-y-2">
              {Array.from({ length: LEAVE_TYPE_SKELETON_COUNT }, (_, index) => (
                <Skeleton key={index} className="h-16 w-full rounded-xl" />
              ))}
            </div>
          ) : (
            <DataList
              items={(data?.leaveTypes ?? []).map((rule) => ({
                id: rule.id,
                title: t(rule.labelKey),
                subtitle: [
                  t('leaveTypeSetup.dayCount', { count: rule.days }),
                  rule.carryOver ? t('leaveTypeSetup.carryOver.yes') : null,
                ]
                  .filter(Boolean)
                  .join(' · '),
                trailing: <MobileRuleTrailing rule={rule} />,
              }))}
            />
          )}
        </div>

        <div className="mt-3 hidden overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] md:block">
          <div
            className={cn(
              'grid gap-3 border-b border-[var(--color-border)] bg-[var(--color-bg-surface)] px-4 py-2.5 text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]',
              LEAVE_TYPE_TABLE_GRID_COLS,
            )}
          >
            <div>{t('leaveTypeSetup.columns.label')}</div>
            <div className="text-right">{t('leaveTypeSetup.columns.days')}</div>
            <div>{t('leaveTypeSetup.columns.paid')}</div>
            <div>{t('leaveTypeSetup.columns.doc')}</div>
            <div>{t('leaveTypeSetup.columns.carryOver')}</div>
          </div>
          <ul className="divide-y divide-[var(--color-border)]">
            {isLoading
              ? Array.from({ length: LEAVE_TYPE_SKELETON_COUNT }, (_, index) => (
                  <li
                    key={index}
                    className={cn('grid items-center gap-3 px-4 py-3', LEAVE_TYPE_TABLE_GRID_COLS)}
                  >
                    <Skeleton className="h-4 w-28" />
                    <Skeleton className="ml-auto h-4 w-8" />
                    <Skeleton className="h-7 w-16 rounded-full" />
                    <Skeleton className="h-7 w-16 rounded-full" />
                    <Skeleton className="h-4 w-10" />
                  </li>
                ))
              : (data?.leaveTypes ?? []).map((rule) => (
                  <li
                    key={rule.id}
                    className={cn('grid items-center gap-3 px-4 py-3', LEAVE_TYPE_TABLE_GRID_COLS)}
                  >
                    <div className="truncate text-sm font-medium">{t(rule.labelKey)}</div>
                    <div className="text-right text-sm tabular-nums">{rule.days}</div>
                    <div>
                      <PaidCell rule={rule} />
                    </div>
                    <div>
                      <DocCell rule={rule} />
                    </div>
                    <div>
                      <CarryOverCell rule={rule} />
                    </div>
                  </li>
                ))}
          </ul>
        </div>
      </section>

      <SheetShell
        open={sheetOpen}
        onOpenChange={setSheetOpen}
        title={t('leaveTypeSetup.sheet.title')}
        description={t('leaveTypeSetup.sheet.description')}
        footer={
          <div className="flex w-full flex-col gap-3">
            <StatusPill tone="neutral" className="self-start">
              {t('common.soon')}
            </StatusPill>
            <Button type="button" className="touch-target w-full" disabled>
              {t('common.readOnlyAction')}
            </Button>
          </div>
        }
      >
        <div className="space-y-4">
          <FormField label={t('leaveTypeSetup.sheet.fields.label')} htmlFor="leave-type-label">
            <Input
              id="leave-type-label"
              className="text-base"
              placeholder={t('leaveTypeSetup.sheet.placeholders.label')}
              disabled
            />
          </FormField>
          <FormField label={t('leaveTypeSetup.sheet.fields.days')} htmlFor="leave-type-days">
            <Input
              id="leave-type-days"
              className="text-base"
              placeholder={t('leaveTypeSetup.sheet.placeholders.days')}
              disabled
            />
          </FormField>
        </div>
      </SheetShell>
    </div>
  )
}
