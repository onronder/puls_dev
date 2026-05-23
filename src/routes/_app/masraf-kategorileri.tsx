import { createFileRoute } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import { FileCheck2, Plus, Receipt, Wallet, Workflow } from 'lucide-react'
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
import {
  fetchDemoExpenseCategoriesOverview,
  formatTry,
} from '#/lib/demo/puls-demo-data'
import { cn } from '#/lib/utils'

export const Route = createFileRoute('/_app/masraf-kategorileri')({
  head: () => ({
    meta: [
      { title: i18n.t('expenseCategorySetup.meta.title') },
      {
        name: 'description',
        content: i18n.t('expenseCategorySetup.meta.description'),
      },
    ],
  }),
  component: MasrafKategorileriRoute,
})

function MasrafKategorileriRoute() {
  return (
    <SetupRouteGuard>
      <MasrafKategorileriPage />
    </SetupRouteGuard>
  )
}

const CATEGORY_SKELETON_COUNT = 4
const CATEGORY_TABLE_GRID_COLS =
  'grid-cols-[minmax(0,1fr)_minmax(0,112px)_minmax(0,112px)_88px]'

function MasrafKategorileriPage() {
  const { t } = useTranslation()
  const [sheetOpen, setSheetOpen] = useState(false)

  const { data, isLoading } = useQuery({
    queryKey: ['demo-expense-categories-overview'],
    queryFn: fetchDemoExpenseCategoriesOverview,
  })

  function formatDocThreshold(amount: number): string {
    return t('expenseCategorySetup.docThresholdAbove', { amount: formatTry(amount) })
  }

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <p className="text-xs font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
        {t('expenseCategorySetup.eyebrow')}
      </p>
      <PageHeader
        className="mt-1"
        title={t('expenseCategorySetup.title')}
        subtitle={t('expenseCategorySetup.description')}
        actions={
          <Button type="button" className="touch-target w-full sm:w-auto" onClick={() => setSheetOpen(true)}>
            <Plus className="h-4 w-4" />
            {t('expenseCategorySetup.actions.add')}
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
            label={t('expenseCategorySetup.metrics.categoryCount')}
            value={String(data.categoryCount)}
            icon={Receipt}
          />
          <MetricCard
            compact
            label={t('expenseCategorySetup.metrics.totalMonthlyLimit')}
            value={formatTry(data.totalMonthlyLimit)}
            icon={Wallet}
          />
          <MetricCard
            compact
            label={t('expenseCategorySetup.metrics.docThreshold')}
            value={formatTry(data.docThresholdMetric)}
            icon={FileCheck2}
          />
          <MetricCard
            compact
            label={t('expenseCategorySetup.metrics.approvalLevels')}
            value={String(data.approvalLevels)}
            icon={Workflow}
          />
        </div>
      ) : null}

      <section>
        <SectionHeader title={t('expenseCategorySetup.sections.list')} />
        <div className="mt-3 md:hidden">
          {isLoading ? (
            <div className="space-y-2">
              {Array.from({ length: CATEGORY_SKELETON_COUNT }, (_, index) => (
                <Skeleton key={index} className="h-16 w-full rounded-xl" />
              ))}
            </div>
          ) : (
            <DataList
              items={(data?.categories ?? []).map((category) => ({
                id: category.id,
                title: t(category.nameKey),
                subtitle: formatTry(category.monthly),
                meta: category.code,
                trailing: (
                  <span className="text-xs tabular-nums text-[var(--color-text-muted)]">
                    {formatDocThreshold(category.docThreshold)}
                  </span>
                ),
              }))}
            />
          )}
        </div>

        <div className="mt-3 hidden overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] md:block">
          <div
            className={cn(
              'grid gap-3 border-b border-[var(--color-border)] bg-[var(--color-bg-surface)] px-4 py-2.5 text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]',
              CATEGORY_TABLE_GRID_COLS,
            )}
          >
            <div>{t('expenseCategorySetup.columns.name')}</div>
            <div className="text-right">{t('expenseCategorySetup.columns.monthlyLimit')}</div>
            <div className="text-right">{t('expenseCategorySetup.columns.docThreshold')}</div>
            <div className="text-right">{t('expenseCategorySetup.columns.accountingCode')}</div>
          </div>
          <ul className="divide-y divide-[var(--color-border)]">
            {isLoading
              ? Array.from({ length: CATEGORY_SKELETON_COUNT }, (_, index) => (
                  <li
                    key={index}
                    className={cn('grid items-center gap-3 px-4 py-3', CATEGORY_TABLE_GRID_COLS)}
                  >
                    <Skeleton className="h-4 w-24" />
                    <Skeleton className="ml-auto h-4 w-16" />
                    <Skeleton className="ml-auto h-4 w-20" />
                    <Skeleton className="ml-auto h-4 w-12" />
                  </li>
                ))
              : (data?.categories ?? []).map((category) => (
                  <li
                    key={category.id}
                    className={cn('grid items-center gap-3 px-4 py-3', CATEGORY_TABLE_GRID_COLS)}
                  >
                    <div className="truncate text-sm font-medium">{t(category.nameKey)}</div>
                    <div className="text-right text-sm tabular-nums">{formatTry(category.monthly)}</div>
                    <div className="text-right text-sm tabular-nums">
                      {formatDocThreshold(category.docThreshold)}
                    </div>
                    <div className="text-right font-mono text-sm tabular-nums">{category.code}</div>
                  </li>
                ))}
          </ul>
        </div>
      </section>

      <SheetShell
        open={sheetOpen}
        onOpenChange={setSheetOpen}
        title={t('expenseCategorySetup.sheet.title')}
        description={t('expenseCategorySetup.sheet.description')}
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
          <FormField label={t('expenseCategorySetup.sheet.fields.name')} htmlFor="expense-category-name">
            <Input
              id="expense-category-name"
              className="text-base"
              placeholder={t('expenseCategorySetup.sheet.placeholders.name')}
              disabled
            />
          </FormField>
          <FormField
            label={t('expenseCategorySetup.sheet.fields.monthlyLimit')}
            htmlFor="expense-category-limit"
          >
            <Input
              id="expense-category-limit"
              className="text-base"
              placeholder={t('expenseCategorySetup.sheet.placeholders.monthlyLimit')}
              disabled
            />
          </FormField>
          <FormField
            label={t('expenseCategorySetup.sheet.fields.accountingCode')}
            htmlFor="expense-category-code"
          >
            <Input
              id="expense-category-code"
              className="text-base"
              placeholder={t('expenseCategorySetup.sheet.placeholders.accountingCode')}
              disabled
            />
          </FormField>
        </div>
      </SheetShell>
    </div>
  )
}
