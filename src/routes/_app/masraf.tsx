import { createFileRoute } from '@tanstack/react-router'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  AlertTriangle,
  Check,
  CheckCircle2,
  FileUp,
  Info,
  Loader2,
  Plus,
  Receipt,
  Sparkles,
  X,
} from 'lucide-react'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { RequestCreationReadinessBanners } from '#/components/puls/RequestCreationReadinessBanners'
import { DemoSourcePill } from '#/components/puls/DemoSourcePill'
import { EmptyState } from '#/components/puls/EmptyState'
import { FormField } from '#/components/puls/FormField'
import { MetricCard } from '#/components/puls/MetricCard'
import { SectionHeader } from '#/components/puls/SectionHeader'
import { Segmented } from '#/components/puls/Segmented'
import { SheetShell } from '#/components/puls/SheetShell'
import { StatusPill, type StatusTone } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { Input } from '#/components/ui/input'
import { Progress } from '#/components/ui/progress'
import { Skeleton } from '#/components/ui/skeleton'
import { Textarea } from '#/components/ui/textarea'
import i18n from '#/i18n'
import { useAuth } from '#/lib/auth'
import {
  buildExpenseCreationReadiness,
  createExpenseClaim,
  decideApprovalRequest,
  fetchExpenseOverviewWithMeta,
  fetchRequestCreationReadiness,
  isDataAdapterError,
  type ExpenseOverview,
} from '#/lib/data'
import { formatCurrency, parseDecimalAmount } from '#/lib/format'
import { cn } from '#/lib/utils'

function formatTry(amount: number, locale = 'tr-TR'): string {
  return formatCurrency(amount, locale)
}

export const Route = createFileRoute('/_app/masraf')({
  head: () => ({
    meta: [
      { title: i18n.t('expense.title') + ' — PULS' },
      { name: 'description', content: i18n.t('expenseSetup.subtitle') },
    ],
  }),
  component: MasrafPage,
})

type ExpenseTab = 'mine' | 'approvals' | 'cats'

type ExpenseStatus = ExpenseOverview['claims'][number]['status']

type FormErrors = {
  category?: string
  amount?: string
  date?: string
}

const POLICY_RECEIPT_THRESHOLD = 2000

function toastAdapterError(
  error: unknown,
  t: ReturnType<typeof useTranslation>['t'],
  fallbackKey: string,
) {
  if (isDataAdapterError(error) && error.i18nKey) {
    toast.error(t(error.i18nKey))
    return
  }
  toast.error(t(fallbackKey))
}

function invalidateExpenseQueries(queryClient: ReturnType<typeof useQueryClient>, userId: string) {
  void queryClient.invalidateQueries({ queryKey: ['expense-overview', userId] })
  void queryClient.invalidateQueries({ queryKey: ['dashboard-overview', userId] })
}

function expenseStatusTone(status: ExpenseStatus): StatusTone {
  switch (status) {
    case 'approved':
    case 'paid':
    case 'exported':
      return 'success'
    case 'pending':
      return 'warning'
    case 'rejected':
      return 'danger'
    default:
      return 'neutral'
  }
}

function formatClaimAmount(amount: number, locale: string, currency = 'TRY'): string {
  return formatCurrency(amount, locale, currency)
}

function formatExpenseDate(isoDate: string, locale: string): string {
  return new Intl.DateTimeFormat(locale, { day: '2-digit', month: 'short' }).format(
    new Date(`${isoDate}T12:00:00`),
  )
}

function ClaimCategoryLine({
  category,
  categoryIsActive,
  expenseDate,
  locale,
  t,
}: {
  category: string
  categoryIsActive: boolean
  expenseDate: string
  locale: string
  t: ReturnType<typeof useTranslation>['t']
}) {
  return (
    <div className="flex flex-wrap items-center gap-1.5 text-[12px] text-muted-foreground">
      <span>
        {category} · {formatExpenseDate(expenseDate, locale)}
      </span>
      {categoryIsActive === false ? (
        <StatusPill tone="neutral" className="text-[10px]">
          {t('expenseSetup.categoryLifecycle.inactiveCategoryBadge')}
        </StatusPill>
      ) : null}
    </div>
  )
}

function validateExpenseForm(
  category: string,
  amount: string,
  expenseDate: string,
  t: ReturnType<typeof useTranslation>['t'],
): FormErrors {
  const errors: FormErrors = {}
  const parsedAmount = parseDecimalAmount(amount)

  if (!category) {
    errors.category = t('expenseSetup.form.categoryRequired')
  }
  if (!amount.trim()) {
    errors.amount = t('expenseSetup.form.amountRequired')
  } else if (!Number.isFinite(parsedAmount) || parsedAmount <= 0) {
    errors.amount = t('expenseSetup.form.amountPositive')
  }
  if (!expenseDate) {
    errors.date = t('expenseSetup.form.dateRequired')
  }

  return errors
}

function MasrafPage() {
  const { t, i18n } = useTranslation()
  const { user, activePersona } = useAuth()
  const queryClient = useQueryClient()
  const [tab, setTab] = useState<ExpenseTab>('mine')
  const [sheetOpen, setSheetOpen] = useState(false)

  const { data: expenseResult, isLoading, isError, refetch } = useQuery({
    queryKey: ['expense-overview', user?.id],
    queryFn: () => fetchExpenseOverviewWithMeta(user!.id),
    enabled: Boolean(user?.id),
  })

  const data = expenseResult?.data
  const showApprovals = activePersona === 'manager'
  const activeTab: ExpenseTab = showApprovals || tab !== 'approvals' ? tab : 'mine'

  const usedPct =
    data && data.monthlyLimit > 0
      ? Math.round((data.approvedThisMonth / data.monthlyLimit) * 100)
      : 0

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="text-[12px] font-medium uppercase tracking-[0.04em] text-muted-foreground">
            {t('expenseSetup.eyebrow')}
          </div>
          <h1 className="mt-1 text-[26px] font-semibold tracking-tight text-foreground sm:text-3xl">
            {t('expense.title')}
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">{t('expenseSetup.subtitle')}</p>
        </div>
        <Button type="button" className="touch-target shrink-0" onClick={() => setSheetOpen(true)}>
          <Plus className="h-4 w-4" />
          {t('expense.actions.new')}
        </Button>
      </div>

      <DemoSourcePill visible={expenseResult?.source === 'demo'} />

      {isLoading ? (
        <div className="mt-5 space-y-3">
          <Skeleton className="h-[120px] w-full rounded-lg" />
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
            {Array.from({ length: 4 }).map((_, index) => (
              <Skeleton key={index} className="h-[88px] rounded-lg" />
            ))}
          </div>
        </div>
      ) : isError ? (
        <div className="mt-5 rounded-lg border border-border bg-card">
          <EmptyState
            icon={Receipt}
            title={t('common.error')}
            description={t('expenseSetup.error.loadFailed')}
            action={
              <Button type="button" variant="outline" onClick={() => void refetch()}>
                {t('common.retry')}
              </Button>
            }
          />
        </div>
      ) : data ? (
        <>
          <LimitCard
            approved={data.approvedThisMonth}
            limit={data.monthlyLimit}
            usedPct={usedPct}
            locale={i18n.language}
            t={t}
          />

          <section
            className="mt-5 grid grid-cols-2 gap-3 sm:grid-cols-4"
            aria-label={t('expense.subtitle')}
          >
            <MetricCard
              compact
              className="min-w-0"
              label={t('expense.metrics.pending')}
              value={formatTry(data.pendingAmount, i18n.language)}
              hint={t('expenseSetup.metrics.pendingHint', { count: data.pendingCount })}
            />
            <MetricCard
              compact
              className="min-w-0"
              label={t('expense.metrics.yearTotal')}
              value={formatTry(data.yearTotal, i18n.language)}
              hint={t('expenseSetup.metrics.yearHint')}
            />
            <MetricCard
              compact
              className="min-w-0"
              label={t('expense.metrics.topCategory')}
              value={data.topCategory.name}
              hint={t('expenseSetup.metrics.topCategoryHint', { pct: data.topCategory.pct })}
            />
            <MetricCard
              compact
              className="min-w-0"
              label={t('expense.metrics.monthlyAverage')}
              value={formatTry(data.monthlyAverage, i18n.language)}
              hint={t('expenseSetup.metrics.monthlyAvgHint')}
            />
          </section>

          <div className="mt-6">
            <Segmented
              ariaLabel={t('expenseSetup.tabs.ariaLabel')}
              value={activeTab}
              onChange={setTab}
              options={[
                {
                  value: 'mine',
                  label: `${t('expenseSetup.tabs.mine')} (${data.claims.length})`,
                },
                ...(showApprovals
                  ? [
                      {
                        value: 'approvals' as const,
                        label: `${t('expenseSetup.tabs.approvals')} (${data.pendingApprovals.length})`,
                      },
                    ]
                  : []),
                { value: 'cats', label: t('expenseSetup.tabs.categories') },
              ]}
            />
          </div>

          {activeTab === 'mine' ? (
            <RecentTab claims={data.claims} locale={i18n.language} t={t} />
          ) : null}

          {activeTab === 'approvals' ? (
            <ApprovalsTab
              approvals={data.pendingApprovals}
              locale={i18n.language}
              t={t}
              userId={user?.id}
              queryClient={queryClient}
            />
          ) : null}

          {activeTab === 'cats' ? (
            <CategoriesTab limits={data.categoryLimits} locale={i18n.language} t={t} />
          ) : null}
        </>
      ) : null}

      <ExpenseFormSheet
        open={sheetOpen}
        onOpenChange={setSheetOpen}
        data={data}
        locale={i18n.language}
        userId={user?.id}
        queryClient={queryClient}
        t={t}
      />
    </div>
  )
}

type LimitCardProps = {
  approved: number
  limit: number
  usedPct: number
  locale: string
  t: ReturnType<typeof useTranslation>['t']
}

function LimitCard({ approved, limit, usedPct, locale, t }: LimitCardProps) {
  const overThreshold = usedPct > 80

  return (
    <div className="mt-5 rounded-lg border border-border bg-card p-5">
      <div className="flex flex-wrap items-baseline justify-between gap-3">
        <div className="min-w-0">
          <div className="text-[12px] font-medium uppercase tracking-[0.04em] text-muted-foreground">
            {t('expense.hero.approvedThisMonth')}
          </div>
          <div className="mt-1 flex flex-wrap items-baseline gap-2">
            <span className="text-[30px] font-semibold tracking-tight tabular text-foreground sm:text-[34px]">
              {formatTry(approved, locale)}
            </span>
            <span className="text-[14px] text-muted-foreground">/ {formatTry(limit, locale)}</span>
          </div>
        </div>
        <StatusPill tone={overThreshold ? 'warning' : 'success'}>
          {t('expenseSetup.limitUsed', { pct: usedPct })}
        </StatusPill>
      </div>
      <Progress
        value={usedPct}
        className={cn('mt-3 h-2', overThreshold && '[&>div]:bg-warning')}
      />
    </div>
  )
}

type RecentTabProps = {
  claims: ExpenseOverview['claims']
  locale: string
  t: ReturnType<typeof useTranslation>['t']
}

function RecentTab({ claims, locale, t }: RecentTabProps) {
  return (
    <section className="mt-6">
      <SectionHeader title={t('expenseSetup.sections.recent')} />
      {claims.length === 0 ? (
        <div className="mt-3 rounded-lg border border-border bg-card">
          <EmptyState icon={Receipt} title={t('expenseSetup.empty.recent')} />
        </div>
      ) : (
        <ul className="mt-3 divide-y divide-border overflow-hidden rounded-lg border border-border bg-card">
          {claims.map((claim) => (
            <li key={claim.id} className="flex min-h-16 items-center gap-3 p-4">
              <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-md bg-secondary text-secondary-foreground">
                <Receipt className="h-[18px] w-[18px]" />
              </span>
              <div className="min-w-0 flex-1">
                <div className="truncate text-[14px] font-medium text-foreground">{claim.title}</div>
                <ClaimCategoryLine
                  category={claim.category}
                  categoryIsActive={claim.categoryIsActive}
                  expenseDate={claim.expenseDate}
                  locale={locale}
                  t={t}
                />
              </div>
              <div className="flex w-[110px] shrink-0 flex-col items-end gap-1">
                <div className="text-[14px] font-semibold tabular text-foreground">
                  {formatClaimAmount(claim.amount, locale, claim.currency)}
                </div>
                <StatusPill tone={expenseStatusTone(claim.status)}>
                  {t(`expense.status.${claim.status}`)}
                </StatusPill>
              </div>
            </li>
          ))}
        </ul>
      )}
    </section>
  )
}

type ApprovalsTabProps = {
  approvals: ExpenseOverview['pendingApprovals']
  locale: string
  t: ReturnType<typeof useTranslation>['t']
  userId: string | undefined
  queryClient: ReturnType<typeof useQueryClient>
}

function ApprovalsTab({ approvals, locale, t, userId, queryClient }: ApprovalsTabProps) {
  const decideMutation = useMutation({
    mutationFn: (payload: { approvalRequestId: string; decision: 'approved' | 'rejected' }) => {
      if (!userId) throw new Error('missing user')
      return decideApprovalRequest(userId, payload)
    },
    onSuccess: (result, variables) => {
      if (userId) invalidateExpenseQueries(queryClient, userId)
      const approval = approvals.find((item) => item.id === variables.approvalRequestId)
      const title = approval?.title ?? '—'
      if (variables.decision === 'approved') {
        if (result.final) {
          toast.success(t('expenseSetup.approval.approvedTitle'), {
            description: t('expenseSetup.approval.approvedDesc', { title }),
          })
        } else {
          toast.success(t('approval.toast.stepApproved'), {
            description: t('approval.toast.forwarded', {
              step: result.currentStepOrder ?? '—',
            }),
          })
        }
      } else {
        toast.success(t('expenseSetup.approval.rejectedTitle'), {
          description: t('expenseSetup.approval.rejectedDesc', { title }),
        })
      }
    },
    onError: (error) => {
      toastAdapterError(error, t, 'approval.error.forbidden')
    },
  })

  return (
    <section className="mt-6">
      <SectionHeader title={t('expenseSetup.sections.approvals')} />
      {approvals.length === 0 ? (
        <div className="mt-3 rounded-lg border border-border bg-card">
          <EmptyState icon={Receipt} title={t('expenseSetup.empty.approvals')} />
        </div>
      ) : (
        <ul className="mt-3 divide-y divide-border overflow-hidden rounded-lg border border-border bg-card">
          {approvals.map((approval) => (
            <li
              key={approval.id}
              className="flex flex-wrap items-center gap-3 p-4 sm:flex-nowrap"
            >
              <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-secondary text-[12px] font-semibold text-secondary-foreground">
                {approval.initials}
              </span>
              <div className="min-w-0 flex-1">
                <div className="truncate text-[14px] font-medium text-foreground">
                  {approval.employeeName} · {approval.title}
                </div>
                {/* Defensive display only: inactive category + open approval is not a supported production state. */}
                <ClaimCategoryLine
                  category={approval.category}
                  categoryIsActive={approval.categoryIsActive}
                  expenseDate={approval.expenseDate}
                  locale={locale}
                  t={t}
                />
              </div>
              <div className="shrink-0 text-right">
                <div className="text-[14px] font-semibold tabular text-foreground">
                  {formatClaimAmount(approval.amount, locale, approval.currency ?? 'TRY')}
                </div>
              </div>
              <div className="flex w-full shrink-0 items-center gap-2 sm:w-auto">
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  className="min-h-11 flex-1 sm:flex-none"
                  disabled={decideMutation.isPending}
                  onClick={() =>
                    decideMutation.mutate({
                      approvalRequestId: approval.id,
                      decision: 'rejected',
                    })
                  }
                >
                  <X className="h-3.5 w-3.5" />
                  {t('expenseSetup.approval.reject')}
                </Button>
                <Button
                  type="button"
                  size="sm"
                  className="min-h-11 flex-1 sm:flex-none"
                  disabled={decideMutation.isPending}
                  onClick={() =>
                    decideMutation.mutate({
                      approvalRequestId: approval.id,
                      decision: 'approved',
                    })
                  }
                >
                  <Check className="h-3.5 w-3.5" />
                  {t('expenseSetup.approval.approve')}
                </Button>
              </div>
            </li>
          ))}
        </ul>
      )}
    </section>
  )
}

type CategoriesTabProps = {
  limits: ExpenseOverview['categoryLimits']
  locale: string
  t: ReturnType<typeof useTranslation>['t']
}

function CategoriesTab({ limits, locale, t }: CategoriesTabProps) {
  return (
    <section className="mt-6">
      <SectionHeader
        title={t('expenseSetup.sections.categoryLimits')}
        description={t('expenseSetup.sections.categoryLimitsDesc')}
      />
      <ul className="mt-3 divide-y divide-border overflow-hidden rounded-lg border border-border bg-card">
        {limits.map((category) => {
          const pct = category.limit
            ? Math.round((category.monthSpent / category.limit) * 100)
            : 0
          const overThreshold = pct > 80

          return (
            <li key={category.id} className="p-4">
              <div className="flex flex-wrap items-baseline justify-between gap-3">
                <div className="text-[14px] font-medium text-foreground">{category.name}</div>
                <div className="text-[13px] tabular text-muted-foreground">
                  <span className="font-semibold text-foreground">
                    {formatTry(category.monthSpent, locale)}
                  </span>{' '}
                  / {formatTry(category.limit, locale)}
                </div>
              </div>
              <Progress
                value={pct}
                className={cn('mt-2 h-1.5', overThreshold && '[&>div]:bg-warning')}
              />
            </li>
          )
        })}
      </ul>
    </section>
  )
}

type ExpenseFormSheetProps = {
  open: boolean
  onOpenChange: (open: boolean) => void
  data: ExpenseOverview | undefined
  locale: string
  userId: string | undefined
  queryClient: ReturnType<typeof useQueryClient>
  t: ReturnType<typeof useTranslation>['t']
}

function ExpenseFormSheet({
  open,
  onOpenChange,
  data,
  locale,
  userId,
  queryClient,
  t,
}: ExpenseFormSheetProps) {
  const [category, setCategory] = useState('')
  const [amount, setAmount] = useState('')
  const [currency, setCurrency] = useState('TRY')
  const [vatIncluded, setVatIncluded] = useState(true)
  const [expenseDate, setExpenseDate] = useState('')
  const [note, setNote] = useState('')
  const [errors, setErrors] = useState<FormErrors>({})

  const { data: creationContext } = useQuery({
    queryKey: ['request-creation-readiness', 'expense', userId],
    queryFn: () => fetchRequestCreationReadiness(userId!, 'expense'),
    enabled: Boolean(userId) && open,
  })

  const readiness = useMemo(() => {
    if (!creationContext) return null
    return buildExpenseCreationReadiness({
      activeCategoryCount: creationContext.activeTargetCount,
      assignment: creationContext.assignment,
      policyTargets: creationContext.policyTargets,
      selectedCategoryId: category || null,
    })
  }, [creationContext, category])

  const createMutation = useMutation({
    mutationFn: (payload: Parameters<typeof createExpenseClaim>[1]) => {
      if (!userId) throw new Error('missing user')
      return createExpenseClaim(userId, payload)
    },
    onSuccess: () => {
      if (userId) invalidateExpenseQueries(queryClient, userId)
      toast.success(t('expense.toast.submitted'))
      handleOpenChange(false)
    },
    onError: (error) => {
      toastAdapterError(error, t, 'expense.error.submitFailed')
    },
  })

  const amountNum = parseDecimalAmount(amount)
  const overPolicy = Number.isFinite(amountNum) && amountNum > POLICY_RECEIPT_THRESHOLD
  const requiredOk = !!category && Number.isFinite(amountNum) && amountNum > 0 && !!expenseDate

  const categoryLabel =
    data?.categoryLimits.find((item) => item.id === category)?.name ??
    data?.categories.find((item) => item.id === category)?.label ??
    category

  function resetForm() {
    setCategory('')
    setAmount('')
    setCurrency('TRY')
    setVatIncluded(true)
    setExpenseDate('')
    setNote('')
    setErrors({})
  }

  function handleOpenChange(nextOpen: boolean) {
    if (!nextOpen) resetForm()
    onOpenChange(nextOpen)
  }

  function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const nextErrors = validateExpenseForm(category, amount, expenseDate, t)
    setErrors(nextErrors)
    if (Object.keys(nextErrors).length > 0) return

    const parsedAmount = parseDecimalAmount(amount)
    if (!Number.isFinite(parsedAmount) || parsedAmount <= 0) {
      toast.error(t('expense.form.amountError'))
      return
    }

    createMutation.mutate({
      categoryId: category,
      title: note.trim() || null,
      amount: parsedAmount,
      currency,
      vatIncluded,
      expenseDate,
      description: note.trim() || null,
    })
  }

  const isSubmitting = createMutation.isPending
  const hasActiveCategories = (data?.categoryLimits.length ?? 0) > 0
  const canCreate = readiness?.canCreate ?? false

  return (
    <SheetShell
      open={open}
      onOpenChange={handleOpenChange}
      title={t('expense.sheet.title')}
      description={t('expense.sheet.description')}
      footer={
        <div className="flex w-full gap-2">
          <Button
            type="button"
            variant="outline"
            className="min-h-11 flex-1"
            onClick={() => handleOpenChange(false)}
          >
            <X className="h-4 w-4" />
            {t('common.cancel')}
          </Button>
          <Button
            type="submit"
            form="new-expense-form"
            className="min-h-11 flex-1"
            disabled={isSubmitting || !data || !hasActiveCategories || !canCreate}
          >
            {isSubmitting ? (
              <>
                <Loader2 className="h-4 w-4 animate-spin" />
                {t('expense.actions.submitting')}
              </>
            ) : (
              <>
                <Receipt className="h-4 w-4" />
                {t('expense.actions.submit')}
              </>
            )}
          </Button>
        </div>
      }
    >
      <form id="new-expense-form" className="space-y-5" onSubmit={handleSubmit}>
        {readiness ? <RequestCreationReadinessBanners readiness={readiness} t={t} /> : null}

        <div className="rounded-md border border-ai/20 bg-ai-soft p-3 opacity-90">
          <div className="flex items-start gap-2">
            <span className="flex h-7 w-7 items-center justify-center rounded-md bg-ai/15 text-ai">
              <Sparkles className="h-3.5 w-3.5" />
            </span>
            <div className="min-w-0 flex-1">
              <div className="flex flex-wrap items-center gap-1.5 text-[13.5px] font-medium text-ai">
                {t('expenseSetup.form.ocrTitle')}
                <span className="rounded-full bg-ai/15 px-1.5 py-0.5 text-[11px] font-semibold uppercase">
                  {t('expenseSetup.form.ocrSoon')}
                </span>
              </div>
              <p className="mt-0.5 text-[12px] text-ai/80">{t('expenseSetup.form.ocrDesc')}</p>
            </div>
          </div>
        </div>

        <FormField label={t('expense.form.category')} required error={errors.category}>
          <select
            value={category}
            onChange={(event) => setCategory(event.target.value)}
            className={cn(
              'flex h-11 w-full rounded-md border border-border bg-card px-3 text-base outline-none focus:border-ring',
              errors.category && 'border-[var(--color-danger)]',
            )}
          >
            <option value="">{t('expense.form.categoryPlaceholder')}</option>
            {(data?.categoryLimits ?? []).map((item) => (
              <option key={item.id} value={item.id}>
                {item.name}
              </option>
            ))}
          </select>
          {!hasActiveCategories ? (
            <p className="mt-2 text-[12px] leading-relaxed text-muted-foreground">
              {t('requestCreationReadiness.expense.noActiveCategories')}
            </p>
          ) : null}
        </FormField>

        <div className="grid grid-cols-1 gap-3 sm:grid-cols-[1fr_110px]">
          <FormField label={t('expense.form.amount')} htmlFor="expense-amount" required error={errors.amount}>
            <Input
              id="expense-amount"
              inputMode="decimal"
              value={amount}
              onChange={(event) => setAmount(event.target.value)}
              placeholder="0,00"
              className="text-base tabular"
            />
          </FormField>
          <FormField label={t('expenseSetup.form.currency')}>
            <select
              value={currency}
              onChange={(event) => setCurrency(event.target.value)}
              className="flex h-11 w-full rounded-md border border-border bg-card px-3 text-base outline-none focus:border-ring"
            >
              <option value="TRY">TRY</option>
              <option value="USD">USD</option>
              <option value="EUR">EUR</option>
            </select>
          </FormField>
        </div>

        <label className="flex min-h-11 cursor-pointer items-center justify-between gap-3 rounded-md border border-border bg-surface-2 px-4 py-3">
          <div className="min-w-0">
            <div className="text-[14px] font-medium">{t('expenseSetup.form.vatIncluded')}</div>
            <div className="text-[12px] text-muted-foreground">
              {t('expenseSetup.form.vatIncludedHint')}
            </div>
          </div>
          <input
            type="checkbox"
            checked={vatIncluded}
            onChange={(event) => setVatIncluded(event.target.checked)}
            className="h-5 w-5 shrink-0 rounded border-border accent-[color:var(--primary)]"
          />
        </label>

        <FormField
          label={t('expense.form.date')}
          htmlFor="expense-date"
          required
          error={errors.date}
        >
          <Input
            id="expense-date"
            type="date"
            value={expenseDate}
            onChange={(event) => setExpenseDate(event.target.value)}
            className="text-base"
          />
        </FormField>

        <FormField label={t('expense.form.description')} htmlFor="expense-note">
          <Textarea
            id="expense-note"
            rows={2}
            value={note}
            onChange={(event) => setNote(event.target.value)}
            placeholder={t('expense.form.descriptionPlaceholder')}
            className="min-h-[72px] text-base"
          />
        </FormField>

        <FormField label={t('expenseSetup.form.document')} hint={t('expenseSetup.form.documentHint')}>
          <button
            type="button"
            disabled
            className="flex min-h-[80px] w-full items-center justify-center gap-2 rounded-md border border-dashed border-border bg-surface-2 px-4 py-4 text-[13px] text-muted-foreground opacity-70"
          >
            <FileUp className="h-4 w-4" />
            {t('expenseSetup.form.documentTeaser')}
          </button>
        </FormField>

        {requiredOk ? (
          <div className="rounded-md border border-border bg-surface-2 p-3">
            <div className="text-[12px] font-semibold uppercase tracking-[0.04em] text-muted-foreground">
              {t('expenseSetup.form.policyTitle')}
            </div>
            <ul className="mt-2 space-y-1.5 text-[13px]">
              <PolicyLine
                ok={!overPolicy}
                label={t('expenseSetup.form.policyCategoryLimit', { category: categoryLabel })}
              />
              <PolicyLine ok={!overPolicy} label={t('expenseSetup.form.policyReceiptRequired')} />
              <PolicyLine ok={currency === 'TRY'} label={t('expenseSetup.form.policyCurrency')} />
              <PolicyLine
                ok
                label={t('expenseSetup.form.policyDate', {
                  date: formatExpenseDate(expenseDate, locale),
                })}
              />
            </ul>
          </div>
        ) : (
          <div className="flex items-start gap-2 rounded-md border border-border bg-surface-2 p-3 text-[13px] text-muted-foreground">
            <Info className="mt-0.5 h-4 w-4 shrink-0" />
            <div className="text-[12px]">{t('expenseSetup.form.policyPending')}</div>
          </div>
        )}

        {requiredOk ? (
          overPolicy ? (
            <div className="flex items-start gap-2 rounded-md border border-warning/30 bg-warning-soft p-3 text-[13px] text-warning">
              <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
              <div>
                <div className="font-medium">{t('expenseSetup.form.policyWarningTitle')}</div>
                <div className="text-[12px] opacity-90">
                  {t('expenseSetup.form.policyWarningDesc')}
                </div>
              </div>
            </div>
          ) : (
            <div className="flex items-start gap-2 rounded-md border border-info/20 bg-info-soft p-3 text-[13px] text-info">
              <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0" />
              <div className="text-[12px]">{t('expenseSetup.form.policyOk')}</div>
            </div>
          )
        ) : null}
      </form>
    </SheetShell>
  )
}

function PolicyLine({ ok, label }: { ok: boolean; label: string }) {
  return (
    <li className="flex items-center gap-2 text-foreground">
      {ok ? (
        <CheckCircle2 className="h-3.5 w-3.5 text-success" aria-hidden />
      ) : (
        <AlertTriangle className="h-3.5 w-3.5 text-warning" aria-hidden />
      )}
      <span className={ok ? 'text-foreground' : 'text-warning'}>{label}</span>
    </li>
  )
}
