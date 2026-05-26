import { createFileRoute } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import { AlertTriangle, FileCheck2, Plus, Receipt, Wallet, Workflow } from 'lucide-react'
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
import type { StatusTone } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { Input } from '#/components/ui/input'
import { Skeleton } from '#/components/ui/skeleton'
import i18n from '#/i18n'
import { useAuth } from '#/lib/auth'
import {
  fetchCostCenterReadinessOverview,
  fetchExpenseCategoriesOverview,
  type CostCenterReadinessItem,
  type CostCenterReadinessStatus,
  type ExpenseRoutingReadinessWarning,
} from '#/lib/data'
import { formatCurrency } from '#/lib/format'
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
const COST_CENTER_SKELETON_COUNT = 3
const CATEGORY_TABLE_GRID_COLS =
  'grid-cols-[minmax(0,1fr)_minmax(0,112px)_minmax(0,112px)_88px]'
const COST_CENTER_TABLE_GRID_COLS =
  'grid-cols-[minmax(0,1fr)_minmax(0,96px)_minmax(0,120px)_120px]'

function readinessStatusTone(status: CostCenterReadinessStatus): StatusTone {
  switch (status) {
    case 'export_ready':
      return 'success'
    case 'needs_mapping':
      return 'warning'
    case 'puls_only':
    case 'inactive':
    default:
      return 'neutral'
  }
}

function readinessStatusLabelKey(item: CostCenterReadinessItem): string {
  if (item.status === 'export_ready') {
    return item.exportSourceType === 'excel_csv'
      ? 'expenseCategorySetup.costCenterMappings.status.export_ready_external'
      : 'expenseCategorySetup.costCenterMappings.status.export_ready_erp'
  }
  return `expenseCategorySetup.costCenterMappings.status.${item.status}`
}

function formatSourceLabel(
  item: CostCenterReadinessItem,
  t: (key: string) => string,
): string {
  if (item.sourceName) return item.sourceName
  if (item.sourceCode) return item.sourceCode
  return t('expenseCategorySetup.costCenterMappings.sourcePuls')
}

function CostCenterReadinessPill({ item }: { item: CostCenterReadinessItem }) {
  const { t } = useTranslation()
  return (
    <StatusPill tone={readinessStatusTone(item.status)}>
      {t(readinessStatusLabelKey(item))}
    </StatusPill>
  )
}

function RoutingReadinessWarnings({
  warnings,
}: {
  warnings: ExpenseRoutingReadinessWarning[]
}) {
  const { t } = useTranslation()
  if (warnings.length === 0) return null

  return (
    <div className="mb-4 space-y-2">
      <div className="text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
        {t('expenseCategorySetup.costCenterMappings.routingWarning.title')}
      </div>
      {warnings.map((warning) => (
        <div
          key={`${warning.policyId}-${warning.strategy}-${warning.costCenterCode ?? 'requester'}`}
          className="flex items-start gap-2 rounded-md border border-warning/30 bg-warning-soft p-3 text-warning"
        >
          <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
          <div className="text-sm">
            {warning.strategy === 'explicit'
              ? t('expenseCategorySetup.costCenterMappings.routingWarning.explicit', {
                  policy: warning.policyName,
                  code: warning.costCenterCode ?? '—',
                })
              : t('expenseCategorySetup.costCenterMappings.routingWarning.requester')}
          </div>
        </div>
      ))}
    </div>
  )
}

function MasrafKategorileriPage() {
  const { t } = useTranslation()
  const { user } = useAuth()
  const [sheetOpen, setSheetOpen] = useState(false)
  const [selectedCostCenter, setSelectedCostCenter] = useState<CostCenterReadinessItem | null>(
    null,
  )

  const { data, isLoading } = useQuery({
    queryKey: ['expense-categories-overview', user?.id],
    queryFn: () => fetchExpenseCategoriesOverview(user!.id),
    enabled: Boolean(user?.id),
  })

  const { data: readinessData, isLoading: readinessLoading } = useQuery({
    queryKey: ['cost-center-readiness', user?.id],
    queryFn: () => fetchCostCenterReadinessOverview(user!.id),
    enabled: Boolean(user?.id),
  })

  function formatDocThreshold(amount: number): string {
    return t('expenseCategorySetup.docThresholdAbove', {
      amount: formatCurrency(amount, 'tr-TR'),
    })
  }

  function openCostCenterDetail(item: CostCenterReadinessItem) {
    setSelectedCostCenter(item)
  }

  const costCenterRowClassName =
    'cursor-pointer transition-colors hover:bg-[var(--color-bg-elevated)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--color-border)]'

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
            value={formatCurrency(data.totalMonthlyLimit, 'tr-TR')}
            icon={Wallet}
          />
          <MetricCard
            compact
            label={t('expenseCategorySetup.metrics.docThreshold')}
            value={formatCurrency(data.docThresholdMetric, 'tr-TR')}
            icon={FileCheck2}
          />
          <MetricCard
            compact
            label={t('expenseCategorySetup.metrics.approvalLevels')}
            value={t('expenseCategorySetup.metrics.approvalLevelsValue', {
              count: data.maxApprovalStepCount,
            })}
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
                subtitle: formatCurrency(category.monthly, 'tr-TR'),
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
                    <div className="text-right text-sm tabular-nums">{formatCurrency(category.monthly, 'tr-TR')}</div>
                    <div className="text-right text-sm tabular-nums">
                      {formatDocThreshold(category.docThreshold)}
                    </div>
                    <div className="text-right font-mono text-sm tabular-nums">{category.code}</div>
                  </li>
                ))}
          </ul>
        </div>
      </section>

      <section className="mt-8">
        <SectionHeader
          title={t('expenseCategorySetup.costCenterMappings.title')}
          description={t('expenseCategorySetup.costCenterMappings.description')}
        />
        <p className="mt-2 text-sm text-[var(--color-text-muted)]">
          {t('expenseCategorySetup.costCenterMappings.boundaryNote')}
        </p>
        {readinessData ? (
          <p className="mt-1 text-xs text-[var(--color-text-muted)]">
            {t('expenseCategorySetup.costCenterMappings.summary', {
              exportReady: readinessData.exportReadyCount,
              needsMapping: readinessData.needsMappingCount,
            })}
          </p>
        ) : null}

        {readinessData?.routingWarnings.length ? (
          <div className="mt-4">
            <RoutingReadinessWarnings warnings={readinessData.routingWarnings} />
          </div>
        ) : null}

        <div className="mt-3 md:hidden">
          {readinessLoading ? (
            <div className="space-y-2">
              {Array.from({ length: COST_CENTER_SKELETON_COUNT }, (_, index) => (
                <Skeleton key={index} className="h-16 w-full rounded-xl" />
              ))}
            </div>
          ) : (
            <DataList
              items={(readinessData?.items ?? []).map((item) => ({
                id: item.id,
                title: item.name,
                subtitle: `${item.code} · ${formatSourceLabel(item, t)}`,
                onClick: () => openCostCenterDetail(item),
                trailing: <CostCenterReadinessPill item={item} />,
              }))}
            />
          )}
        </div>

        <div className="mt-3 hidden overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] md:block">
          <div
            className={cn(
              'grid gap-3 border-b border-[var(--color-border)] bg-[var(--color-bg-surface)] px-4 py-2.5 text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]',
              COST_CENTER_TABLE_GRID_COLS,
            )}
          >
            <div>{t('expenseCategorySetup.costCenterMappings.columns.name')}</div>
            <div>{t('expenseCategorySetup.costCenterMappings.columns.code')}</div>
            <div>{t('expenseCategorySetup.costCenterMappings.columns.source')}</div>
            <div className="text-right">{t('expenseCategorySetup.costCenterMappings.columns.erpStatus')}</div>
          </div>
          <ul className="divide-y divide-[var(--color-border)]">
            {readinessLoading
              ? Array.from({ length: COST_CENTER_SKELETON_COUNT }, (_, index) => (
                  <li
                    key={index}
                    className={cn('grid items-center gap-3 px-4 py-3', COST_CENTER_TABLE_GRID_COLS)}
                  >
                    <Skeleton className="h-4 w-24" />
                    <Skeleton className="h-4 w-16" />
                    <Skeleton className="h-4 w-20" />
                    <Skeleton className="ml-auto h-6 w-24" />
                  </li>
                ))
              : (readinessData?.items ?? []).map((item) => (
                  <li key={item.id}>
                    <button
                      type="button"
                      className={cn(
                        'grid w-full items-center gap-3 px-4 py-3 text-left',
                        COST_CENTER_TABLE_GRID_COLS,
                        costCenterRowClassName,
                      )}
                      onClick={() => openCostCenterDetail(item)}
                    >
                      <div className="truncate text-sm font-medium">{item.name}</div>
                      <div className="font-mono text-sm tabular-nums">{item.code}</div>
                      <div className="truncate text-sm text-[var(--color-text-secondary)]">
                        {formatSourceLabel(item, t)}
                      </div>
                      <div className="flex justify-end">
                        <CostCenterReadinessPill item={item} />
                      </div>
                    </button>
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

      <SheetShell
        open={selectedCostCenter !== null}
        onOpenChange={(open) => {
          if (!open) setSelectedCostCenter(null)
        }}
        title={
          selectedCostCenter
            ? selectedCostCenter.name
            : t('expenseCategorySetup.costCenterMappings.sheet.title')
        }
        description={t('expenseCategorySetup.costCenterMappings.sheet.description')}
        footer={
          <div className="flex w-full flex-col gap-3">
            <StatusPill tone="neutral" className="self-start">
              {t('common.readOnly')}
            </StatusPill>
            <Button type="button" className="touch-target w-full" disabled>
              {t('common.readOnlyAction')}
            </Button>
          </div>
        }
      >
        {selectedCostCenter ? (
          <dl className="divide-y divide-[var(--color-border)] overflow-hidden rounded-xl border border-[var(--color-border)]">
            <div className="grid grid-cols-1 gap-1 px-4 py-3 sm:grid-cols-[140px_1fr] sm:items-center">
              <dt className="text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                {t('expenseCategorySetup.costCenterMappings.sheet.fields.code')}
              </dt>
              <dd className="font-mono text-sm">{selectedCostCenter.code}</dd>
            </div>
            <div className="grid grid-cols-1 gap-1 px-4 py-3 sm:grid-cols-[140px_1fr] sm:items-center">
              <dt className="text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                {t('expenseCategorySetup.costCenterMappings.sheet.fields.source')}
              </dt>
              <dd className="text-sm">{formatSourceLabel(selectedCostCenter, t)}</dd>
            </div>
            <div className="grid grid-cols-1 gap-1 px-4 py-3 sm:grid-cols-[140px_1fr] sm:items-center">
              <dt className="text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                {t('expenseCategorySetup.costCenterMappings.sheet.fields.externalId')}
              </dt>
              <dd className="font-mono text-sm">{selectedCostCenter.externalId ?? '—'}</dd>
            </div>
            <div className="grid grid-cols-1 gap-1 px-4 py-3 sm:grid-cols-[140px_1fr] sm:items-center">
              <dt className="text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                {t('expenseCategorySetup.costCenterMappings.sheet.fields.status')}
              </dt>
              <dd>
                <CostCenterReadinessPill item={selectedCostCenter} />
              </dd>
            </div>
          </dl>
        ) : null}
      </SheetShell>
    </div>
  )
}
