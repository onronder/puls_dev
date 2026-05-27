import { createFileRoute } from '@tanstack/react-router'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  AlertTriangle,
  Archive,
  FileCheck2,
  Loader2,
  Plus,
  Receipt,
  RotateCcw,
  Save,
  Wallet,
  Workflow,
  X,
} from 'lucide-react'
import { useState, type FormEvent } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { SetupRouteGuard } from '#/components/auth/SetupRouteGuard'
import { DataList } from '#/components/puls/DataList'
import { FormField } from '#/components/puls/FormField'
import { MetricCard } from '#/components/puls/MetricCard'
import { PageHeader } from '#/components/puls/PageHeader'
import { SectionHeader } from '#/components/puls/SectionHeader'
import { Segmented } from '#/components/puls/Segmented'
import { SheetShell } from '#/components/puls/SheetShell'
import { StatusPill } from '#/components/puls/StatusPill'
import type { StatusTone } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { Input } from '#/components/ui/input'
import { Skeleton } from '#/components/ui/skeleton'
import i18n from '#/i18n'
import { useAuth } from '#/lib/auth'
import {
  applyExpenseCategoryLifecycleFilter,
  createExpenseCategory,
  deactivateExpenseCategory,
  fetchCostCenterReadinessOverview,
  fetchExpenseCategoriesOverview,
  isExpenseCategoryFormDirty,
  mapExpenseCategoryLifecycleError,
  mapExpenseCategoryMutationError,
  normalizeCategoryCode,
  restoreExpenseCategory,
  updateExpenseCategory,
  validateExpenseCategoryForm,
  type CostCenterReadinessItem,
  type CostCenterReadinessStatus,
  type ExpenseCategoriesOverview,
  type ExpenseCategoryFieldKey,
  type ExpenseCategoryFormFields,
  type ExpenseCategoryLifecycleFilter,
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
  'grid-cols-[minmax(0,1fr)_minmax(0,112px)_minmax(0,112px)_88px_96px]'
const COST_CENTER_TABLE_GRID_COLS =
  'grid-cols-[minmax(0,1fr)_minmax(0,96px)_minmax(0,120px)_120px]'

type ExpenseCategoryRule = ExpenseCategoriesOverview['categories'][number]

type ExpenseCategoryFormState = ExpenseCategoryFormFields

const EMPTY_CATEGORY_FORM: ExpenseCategoryFormState = {
  name: '',
  code: '',
  monthlyLimit: '',
  receiptRequiredOver: '0',
  erpAccountCode: '',
}

function categoryToForm(category: ExpenseCategoryRule): ExpenseCategoryFormState {
  return {
    name: category.name,
    code: category.categoryCode,
    monthlyLimit: String(category.monthly),
    receiptRequiredOver: String(category.docThreshold),
    erpAccountCode: category.accountingCode ?? '',
  }
}

function translateFieldError(
  t: (key: string) => string,
  fieldErrors: Partial<Record<ExpenseCategoryFieldKey, string>>,
  field: ExpenseCategoryFieldKey,
): string | undefined {
  const key = fieldErrors[field]
  return key ? t(key) : undefined
}

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

function ExpenseCategoryStatusPill({ isActive }: { isActive: boolean }) {
  const { t } = useTranslation()
  return (
    <StatusPill tone={isActive ? 'success' : 'neutral'}>
      {t(
        isActive
          ? 'expenseCategorySetup.lifecycle.status.active'
          : 'expenseCategorySetup.lifecycle.status.inactive',
      )}
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
  const queryClient = useQueryClient()
  const [categorySheetOpen, setCategorySheetOpen] = useState(false)
  const [editingCategory, setEditingCategory] = useState<ExpenseCategoryRule | null>(null)
  const [categoryForm, setCategoryForm] =
    useState<ExpenseCategoryFormState>(EMPTY_CATEGORY_FORM)
  const [formBaseline, setFormBaseline] = useState<ExpenseCategoryFormState | null>(null)
  const [fieldErrors, setFieldErrors] = useState<
    Partial<Record<ExpenseCategoryFieldKey, string>>
  >({})
  const [selectedCostCenter, setSelectedCostCenter] = useState<CostCenterReadinessItem | null>(
    null,
  )
  const [lifecycleFilter, setLifecycleFilter] = useState<ExpenseCategoryLifecycleFilter>('active')

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

  const categoryMutation = useMutation({
    mutationFn: (payload: {
      name: string
      code: string
      monthlyLimit: number
      receiptRequiredOver: number
      erpAccountCode: string | null
    }) => {
      if (!user?.id) {
        throw new Error('Missing user')
      }

      if (editingCategory) {
        return updateExpenseCategory(user.id, editingCategory.id, payload)
      }
      return createExpenseCategory(user.id, payload)
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['expense-categories-overview', user?.id] })
      resetCategorySheetState()
      toast.success(
        t(
          editingCategory
            ? 'expenseCategorySetup.toast.updated'
            : 'expenseCategorySetup.toast.created',
        ),
      )
    },
    onError: (error) => {
      const mapped = mapExpenseCategoryMutationError(error)
      if (Object.keys(mapped.fieldErrors).length > 0) {
        setFieldErrors((current) => ({ ...current, ...mapped.fieldErrors }))
      }
      if (mapped.toastKey) {
        toast.error(t(mapped.toastKey))
      }
    },
  })

  const deactivateMutation = useMutation({
    mutationFn: (categoryId: string) => {
      if (!user?.id) {
        throw new Error('Missing user')
      }
      return deactivateExpenseCategory(user.id, categoryId)
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['expense-categories-overview', user?.id] })
      resetCategorySheetState()
      toast.success(t('expenseCategorySetup.lifecycle.toast.deactivated'))
    },
    onError: (error) => {
      const mapped = mapExpenseCategoryLifecycleError(error)
      toast.error(t(mapped.toastKey))
    },
  })

  const restoreMutation = useMutation({
    mutationFn: (categoryId: string) => {
      if (!user?.id) {
        throw new Error('Missing user')
      }
      return restoreExpenseCategory(user.id, categoryId)
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['expense-categories-overview', user?.id] })
      resetCategorySheetState()
      toast.success(t('expenseCategorySetup.lifecycle.toast.restored'))
    },
    onError: (error) => {
      const mapped = mapExpenseCategoryLifecycleError(error)
      toast.error(t(mapped.toastKey))
    },
  })

  function formatDocThreshold(amount: number): string {
    return t('expenseCategorySetup.docThresholdAbove', {
      amount: formatCurrency(amount, 'tr-TR'),
    })
  }

  function resetCategorySheetState() {
    setCategorySheetOpen(false)
    setEditingCategory(null)
    setCategoryForm(EMPTY_CATEGORY_FORM)
    setFormBaseline(null)
    setFieldErrors({})
  }

  function openCreateCategorySheet() {
    setEditingCategory(null)
    setCategoryForm(EMPTY_CATEGORY_FORM)
    setFormBaseline(EMPTY_CATEGORY_FORM)
    setFieldErrors({})
    setCategorySheetOpen(true)
  }

  function openEditCategorySheet(category: ExpenseCategoryRule) {
    const baseline = categoryToForm(category)
    setEditingCategory(category)
    setCategoryForm(baseline)
    setFormBaseline(baseline)
    setFieldErrors({})
    setCategorySheetOpen(true)
  }

  function requestCloseCategorySheet() {
    const baseline = formBaseline ?? EMPTY_CATEGORY_FORM
    const dirty = isExpenseCategoryFormDirty(categoryForm, baseline)

    if (dirty && !window.confirm(t('expenseCategorySetup.validation.discardConfirm'))) {
      return
    }

    resetCategorySheetState()
  }

  function handleCategorySheetOpenChange(open: boolean) {
    if (open) {
      setCategorySheetOpen(true)
      return
    }

    requestCloseCategorySheet()
  }

  function updateCategoryForm(field: keyof ExpenseCategoryFormState, value: string) {
    setCategoryForm((current) => ({ ...current, [field]: value }))
    setFieldErrors((current) => {
      if (!current[field]) return current
      const next = { ...current }
      delete next[field]
      return next
    })
  }

  function handleCategorySubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()

    if (isInactiveCategorySheet) {
      return
    }

    const validation = validateExpenseCategoryForm(categoryForm)
    setFieldErrors(validation.fieldErrors)

    if (!validation.isValid) {
      return
    }

    categoryMutation.mutate({
      name: validation.normalized.name,
      code: validation.normalized.code,
      monthlyLimit: validation.normalized.monthlyLimit,
      receiptRequiredOver: validation.normalized.receiptRequiredOver,
      erpAccountCode: validation.normalized.erpAccountCode,
    })
  }

  function handleDeactivateCategory() {
    if (!editingCategory) return
    if (!window.confirm(t('expenseCategorySetup.lifecycle.confirm.deactivate'))) {
      return
    }
    deactivateMutation.mutate(editingCategory.id)
  }

  function handleRestoreCategory() {
    if (!editingCategory) return
    if (!window.confirm(t('expenseCategorySetup.lifecycle.confirm.restore'))) {
      return
    }
    restoreMutation.mutate(editingCategory.id)
  }

  function openCostCenterDetail(item: CostCenterReadinessItem) {
    setSelectedCostCenter(item)
  }

  const categoryRowClassName =
    'cursor-pointer transition-colors hover:bg-[var(--color-bg-elevated)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--color-border)]'
  const costCenterRowClassName =
    'cursor-pointer transition-colors hover:bg-[var(--color-bg-elevated)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--color-border)]'
  const categorySheetMode = editingCategory ? 'edit' : 'create'
  const isInactiveCategorySheet = Boolean(editingCategory && !editingCategory.isActive)
  const isSavingCategory = categoryMutation.isPending
  const isDeactivatingCategory = deactivateMutation.isPending
  const isRestoringCategory = restoreMutation.isPending
  const isLifecyclePending = isDeactivatingCategory || isRestoringCategory
  const filteredCategories = applyExpenseCategoryLifecycleFilter(
    data?.categories ?? [],
    lifecycleFilter,
  )
  const metricsHint =
    lifecycleFilter === 'active'
      ? undefined
      : t('expenseCategorySetup.metrics.activeOnlyHint')
  const dirtyBaseline = formBaseline ?? EMPTY_CATEGORY_FORM
  const isCategoryFormDirty = isExpenseCategoryFormDirty(categoryForm, dirtyBaseline)
  const normalizedCodePreview = normalizeCategoryCode(categoryForm.code)
  const isSaveDisabled =
    isSavingCategory ||
    isLifecyclePending ||
    (categorySheetMode === 'edit' && !isCategoryFormDirty)
  const isFormReadOnly = isSavingCategory || isLifecyclePending || isInactiveCategorySheet

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
          <Button type="button" className="touch-target w-full sm:w-auto" onClick={openCreateCategorySheet}>
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
            label={t('expenseCategorySetup.metrics.activeCategoryCount')}
            value={String(data.categoryCount)}
            hint={metricsHint}
            icon={Receipt}
          />
          <MetricCard
            compact
            label={t('expenseCategorySetup.metrics.activeTotalMonthlyLimit')}
            value={formatCurrency(data.totalMonthlyLimit, 'tr-TR')}
            hint={metricsHint}
            icon={Wallet}
          />
          <MetricCard
            compact
            label={t('expenseCategorySetup.metrics.docThreshold')}
            value={formatCurrency(data.docThresholdMetric, 'tr-TR')}
            hint={metricsHint}
            icon={FileCheck2}
          />
          <MetricCard
            compact
            label={t('expenseCategorySetup.metrics.approvalLevels')}
            value={t('expenseCategorySetup.metrics.approvalLevelsValue', {
              count: data.maxApprovalStepCount,
            })}
            hint={metricsHint}
            icon={Workflow}
          />
        </div>
      ) : null}

      <section>
        <SectionHeader title={t('expenseCategorySetup.sections.list')} />
        <div className="mt-3 max-w-md">
          <Segmented
            ariaLabel={t('expenseCategorySetup.lifecycle.filter.ariaLabel')}
            value={lifecycleFilter}
            onChange={setLifecycleFilter}
            options={[
              { value: 'active', label: t('expenseCategorySetup.lifecycle.filter.active') },
              { value: 'inactive', label: t('expenseCategorySetup.lifecycle.filter.inactive') },
              { value: 'all', label: t('expenseCategorySetup.lifecycle.filter.all') },
            ]}
          />
        </div>
        <div className="mt-3 md:hidden">
          {isLoading ? (
            <div className="space-y-2">
              {Array.from({ length: CATEGORY_SKELETON_COUNT }, (_, index) => (
                <Skeleton key={index} className="h-16 w-full rounded-xl" />
              ))}
            </div>
          ) : (
            <DataList
              items={filteredCategories.map((category) => ({
                id: category.id,
                title: t(category.nameKey),
                subtitle: formatCurrency(category.monthly, 'tr-TR'),
                meta: category.code,
                onClick: () => openEditCategorySheet(category),
                trailing: (
                  <div className="flex flex-col items-end gap-1">
                    <ExpenseCategoryStatusPill isActive={category.isActive} />
                    <span className="text-xs tabular-nums text-[var(--color-text-muted)]">
                      {formatDocThreshold(category.docThreshold)}
                    </span>
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
              CATEGORY_TABLE_GRID_COLS,
            )}
          >
            <div>{t('expenseCategorySetup.columns.name')}</div>
            <div className="text-right">{t('expenseCategorySetup.columns.monthlyLimit')}</div>
            <div className="text-right">{t('expenseCategorySetup.columns.docThreshold')}</div>
            <div className="text-right">{t('expenseCategorySetup.columns.accountingCode')}</div>
            <div className="text-right">{t('expenseCategorySetup.columns.status')}</div>
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
                    <Skeleton className="ml-auto h-6 w-16" />
                  </li>
                ))
              : filteredCategories.map((category) => (
                  <li
                    key={category.id}
                  >
                    <button
                      type="button"
                      className={cn(
                        'grid w-full items-center gap-3 px-4 py-3 text-left',
                        CATEGORY_TABLE_GRID_COLS,
                        categoryRowClassName,
                      )}
                      onClick={() => openEditCategorySheet(category)}
                    >
                      <div className="truncate text-sm font-medium">{t(category.nameKey)}</div>
                      <div className="text-right text-sm tabular-nums">{formatCurrency(category.monthly, 'tr-TR')}</div>
                      <div className="text-right text-sm tabular-nums">
                        {formatDocThreshold(category.docThreshold)}
                      </div>
                      <div className="text-right font-mono text-sm tabular-nums">{category.code}</div>
                      <div className="flex justify-end">
                        <ExpenseCategoryStatusPill isActive={category.isActive} />
                      </div>
                    </button>
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
        open={categorySheetOpen}
        onOpenChange={handleCategorySheetOpenChange}
        title={
          isInactiveCategorySheet
            ? t('expenseCategorySetup.sheet.inactive.title')
            : t(`expenseCategorySetup.sheet.${categorySheetMode}.title`)
        }
        description={
          isInactiveCategorySheet
            ? t('expenseCategorySetup.sheet.inactive.description')
            : t(`expenseCategorySetup.sheet.${categorySheetMode}.description`)
        }
        footer={
          isInactiveCategorySheet ? (
            <div className="flex w-full gap-2">
              <Button
                type="button"
                variant="outline"
                className="min-h-11 flex-1"
                onClick={requestCloseCategorySheet}
                disabled={isRestoringCategory}
              >
                <X className="h-4 w-4" />
                {t('common.cancel')}
              </Button>
              <Button
                type="button"
                className="min-h-11 flex-1"
                onClick={handleRestoreCategory}
                disabled={isRestoringCategory}
              >
                {isRestoringCategory ? (
                  <>
                    <Loader2 className="h-4 w-4 animate-spin" />
                    {t('expenseCategorySetup.lifecycle.actions.restoring')}
                  </>
                ) : (
                  <>
                    <RotateCcw className="h-4 w-4" />
                    {t('expenseCategorySetup.lifecycle.actions.restore')}
                  </>
                )}
              </Button>
            </div>
          ) : categorySheetMode === 'edit' ? (
            <div className="flex w-full gap-2">
              <Button
                type="button"
                variant="outline"
                className="min-h-11 flex-1 border-[var(--color-danger)]/40 text-[var(--color-danger)] hover:bg-[color-mix(in_srgb,var(--color-danger)_8%,transparent)]"
                onClick={handleDeactivateCategory}
                disabled={isDeactivatingCategory || isSavingCategory}
              >
                {isDeactivatingCategory ? (
                  <>
                    <Loader2 className="h-4 w-4 animate-spin" />
                    {t('expenseCategorySetup.lifecycle.actions.deactivate')}
                  </>
                ) : (
                  <>
                    <Archive className="h-4 w-4" />
                    {t('expenseCategorySetup.lifecycle.actions.deactivate')}
                  </>
                )}
              </Button>
              <Button
                type="submit"
                form="expense-category-form"
                className="min-h-11 flex-1"
                disabled={isSaveDisabled}
              >
                {isSavingCategory ? (
                  <>
                    <Loader2 className="h-4 w-4 animate-spin" />
                    {t('expenseCategorySetup.actions.saving')}
                  </>
                ) : (
                  <>
                    <Save className="h-4 w-4" />
                    {t('expenseCategorySetup.actions.save')}
                  </>
                )}
              </Button>
            </div>
          ) : (
            <div className="flex w-full gap-2">
              <Button
                type="button"
                variant="outline"
                className="min-h-11 flex-1"
                onClick={requestCloseCategorySheet}
                disabled={isSavingCategory}
              >
                <X className="h-4 w-4" />
                {t('common.cancel')}
              </Button>
              <Button
                type="submit"
                form="expense-category-form"
                className="min-h-11 flex-1"
                disabled={isSaveDisabled}
              >
                {isSavingCategory ? (
                  <>
                    <Loader2 className="h-4 w-4 animate-spin" />
                    {t('expenseCategorySetup.actions.saving')}
                  </>
                ) : (
                  <>
                    <Save className="h-4 w-4" />
                    {t('expenseCategorySetup.actions.save')}
                  </>
                )}
              </Button>
            </div>
          )
        }
      >
        {isInactiveCategorySheet && editingCategory?.approvalPolicyName ? (
          <p className="mb-4 rounded-md border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-3 py-2 text-sm text-[var(--color-text-secondary)]">
            {t('expenseCategorySetup.sheet.policyBound', {
              policy: editingCategory.approvalPolicyName,
            })}
          </p>
        ) : null}
        <form id="expense-category-form" className="space-y-4" onSubmit={handleCategorySubmit}>
          <FormField
            label={t('expenseCategorySetup.sheet.fields.name')}
            htmlFor="expense-category-name"
            required
            error={translateFieldError(t, fieldErrors, 'name')}
          >
            <Input
              id="expense-category-name"
              className="text-base"
              placeholder={t('expenseCategorySetup.sheet.placeholders.name')}
              value={categoryForm.name}
              onChange={(event) => updateCategoryForm('name', event.target.value)}
              disabled={isFormReadOnly}
              autoComplete="off"
              aria-invalid={Boolean(fieldErrors.name) || undefined}
              aria-describedby={fieldErrors.name ? 'expense-category-name-error' : undefined}
            />
          </FormField>
          <FormField
            label={t('expenseCategorySetup.sheet.fields.code')}
            htmlFor="expense-category-code"
            required
            error={translateFieldError(t, fieldErrors, 'code')}
            hint={
              categoryForm.code.trim()
                ? t('expenseCategorySetup.validation.codePreviewHint', {
                    code: normalizedCodePreview,
                  })
                : undefined
            }
          >
            <Input
              id="expense-category-code"
              className="font-mono text-base"
              placeholder={t('expenseCategorySetup.sheet.placeholders.code')}
              value={categoryForm.code}
              onChange={(event) => updateCategoryForm('code', event.target.value)}
              disabled={isFormReadOnly}
              autoComplete="off"
              aria-invalid={Boolean(fieldErrors.code) || undefined}
              aria-describedby={
                fieldErrors.code
                  ? 'expense-category-code-error'
                  : categoryForm.code.trim()
                    ? 'expense-category-code-hint'
                    : undefined
              }
            />
          </FormField>
          <FormField
            label={t('expenseCategorySetup.sheet.fields.monthlyLimit')}
            htmlFor="expense-category-limit"
            required
            hint={t('expenseCategorySetup.validation.amountInputHint')}
            error={translateFieldError(t, fieldErrors, 'monthlyLimit')}
          >
            <Input
              id="expense-category-limit"
              className="text-base"
              placeholder={t('expenseCategorySetup.sheet.placeholders.monthlyLimit')}
              type="text"
              inputMode="decimal"
              value={categoryForm.monthlyLimit}
              onChange={(event) => updateCategoryForm('monthlyLimit', event.target.value)}
              disabled={isFormReadOnly}
              aria-invalid={Boolean(fieldErrors.monthlyLimit) || undefined}
              aria-describedby={
                fieldErrors.monthlyLimit
                  ? 'expense-category-limit-error'
                  : 'expense-category-limit-hint'
              }
            />
          </FormField>
          <FormField
            label={t('expenseCategorySetup.sheet.fields.docThreshold')}
            htmlFor="expense-category-doc-threshold"
            hint={t('expenseCategorySetup.validation.amountInputHint')}
            error={translateFieldError(t, fieldErrors, 'receiptRequiredOver')}
          >
            <Input
              id="expense-category-doc-threshold"
              className="text-base"
              placeholder={t('expenseCategorySetup.sheet.placeholders.docThreshold')}
              type="text"
              inputMode="decimal"
              value={categoryForm.receiptRequiredOver}
              onChange={(event) => updateCategoryForm('receiptRequiredOver', event.target.value)}
              disabled={isFormReadOnly}
              aria-invalid={Boolean(fieldErrors.receiptRequiredOver) || undefined}
              aria-describedby={
                fieldErrors.receiptRequiredOver
                  ? 'expense-category-doc-threshold-error'
                  : 'expense-category-doc-threshold-hint'
              }
            />
          </FormField>
          <FormField
            label={t('expenseCategorySetup.sheet.fields.accountingCode')}
            htmlFor="expense-category-accounting-code"
            error={translateFieldError(t, fieldErrors, 'erpAccountCode')}
          >
            <Input
              id="expense-category-accounting-code"
              className="text-base"
              placeholder={t('expenseCategorySetup.sheet.placeholders.accountingCode')}
              value={categoryForm.erpAccountCode}
              onChange={(event) => updateCategoryForm('erpAccountCode', event.target.value)}
              disabled={isFormReadOnly}
              autoComplete="off"
              aria-invalid={Boolean(fieldErrors.erpAccountCode) || undefined}
              aria-describedby={
                fieldErrors.erpAccountCode ? 'expense-category-accounting-code-error' : undefined
              }
            />
          </FormField>
          <p className="text-xs leading-relaxed text-[var(--color-text-muted)]">
            {t('expenseCategorySetup.sheet.boundaryNote')}
          </p>
        </form>
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
