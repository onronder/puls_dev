import { createFileRoute } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import { Plus, Wallet } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { DataList } from '#/components/puls/DataList'
import { FormField } from '#/components/puls/FormField'
import { MetricCard } from '#/components/puls/MetricCard'
import { PageHeader } from '#/components/puls/PageHeader'
import { SectionHeader } from '#/components/puls/SectionHeader'
import { SheetShell } from '#/components/puls/SheetShell'
import { StatusPill, type StatusTone } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { Input } from '#/components/ui/input'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '#/components/ui/select'
import { Textarea } from '#/components/ui/textarea'
import {
  fetchDemoExpenseOverview,
  formatTry,
  type DemoExpenseClaim,
} from '#/lib/demo/puls-demo-data'

export const Route = createFileRoute('/_app/masraf')({
  component: MasrafPage,
})

type ExpenseStatus = DemoExpenseClaim['status']

function expenseStatusTone(status: ExpenseStatus): StatusTone {
  switch (status) {
    case 'approved':
    case 'paid':
      return 'success'
    case 'pending':
      return 'warning'
    case 'rejected':
      return 'danger'
    default:
      return 'neutral'
  }
}

function MasrafPage() {
  const { t } = useTranslation()
  const [sheetOpen, setSheetOpen] = useState(false)
  const [localClaims, setLocalClaims] = useState<DemoExpenseClaim[]>([])
  const [category, setCategory] = useState('travel')
  const [amount, setAmount] = useState('')
  const [expenseDate, setExpenseDate] = useState('2026-05-10')
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')

  const { data, isLoading } = useQuery({
    queryKey: ['demo-expense-overview'],
    queryFn: fetchDemoExpenseOverview,
  })

  const allClaims = useMemo(() => [...localClaims, ...(data?.claims ?? [])], [localClaims, data?.claims])

  const pendingAmount = allClaims
    .filter((claim) => claim.status === 'pending')
    .reduce((sum, claim) => sum + claim.amount, 0)

  const limitUsage = data ? Math.round((data.approvedThisMonth / data.monthlyLimit) * 100) : 0

  function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const parsedAmount = Number(amount)
    if (!parsedAmount || parsedAmount <= 0) {
      toast.error(t('expense.form.amountError'))
      return
    }

    const categoryLabel =
      data?.categories.find((item) => item.id === category)?.label ?? t('expense.categories.travel')

    const newClaim: DemoExpenseClaim = {
      id: `local-${Date.now()}`,
      title: title || t('expense.form.defaultTitle'),
      category: categoryLabel,
      amount: parsedAmount,
      currency: 'TRY',
      expenseDate,
      status: 'pending',
    }

    setLocalClaims((prev) => [newClaim, ...prev])
    setSheetOpen(false)
    toast.success(t('expense.toast.submitted'))
    setAmount('')
    setTitle('')
    setDescription('')
  }

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <PageHeader
        title={t('expense.title')}
        subtitle={t('expense.subtitle')}
        actions={
          <Button type="button" className="touch-target" onClick={() => setSheetOpen(true)}>
            <Plus className="h-4 w-4" />
            {t('expense.actions.new')}
          </Button>
        }
      />

      <MetricCard
        className="mb-6"
        label={t('expense.hero.approvedThisMonth')}
        value={data ? formatTry(data.approvedThisMonth) : '—'}
        hint={
          data
            ? t('expense.hero.limitUsage', {
                limit: formatTry(data.monthlyLimit),
                usage: limitUsage,
              })
            : undefined
        }
        icon={Wallet}
      />

      <div className="-mx-4 mb-6 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:grid-cols-4 md:overflow-visible md:px-0">
        <MetricCard compact label={t('expense.metrics.pending')} value={formatTry(pendingAmount)} />
        <MetricCard compact label={t('expense.metrics.yearTotal')} value={data ? formatTry(data.yearTotal) : '—'} />
        <MetricCard compact label={t('expense.metrics.topCategory')} value={data?.topCategoryShare ?? '—'} />
        <MetricCard
          compact
          label={t('expense.metrics.monthlyAverage')}
          value={data ? formatTry(data.monthlyAverage) : '—'}
        />
      </div>

      <SectionHeader title={t('expense.sections.recent')} />
      <DataList
        items={allClaims.map((claim) => ({
          id: claim.id,
          title: claim.title,
          subtitle: `${claim.category} · ${new Intl.DateTimeFormat('tr-TR').format(new Date(claim.expenseDate))}`,
          meta: formatTry(claim.amount),
          trailing: (
            <StatusPill tone={expenseStatusTone(claim.status)}>
              {t(`expense.status.${claim.status}`)}
            </StatusPill>
          ),
        }))}
        emptyLabel={isLoading ? t('common.loading') : t('expense.empty.list')}
      />

      <SheetShell
        open={sheetOpen}
        onOpenChange={setSheetOpen}
        title={t('expense.sheet.title')}
        description={t('expense.sheet.description')}
        footer={
          <div className="flex w-full gap-2">
            <Button
              type="button"
              variant="outline"
              className="flex-1"
              onClick={() => setSheetOpen(false)}
            >
              {t('common.cancel')}
            </Button>
            <Button type="submit" form="new-expense-form" className="flex-1">
              {t('expense.actions.submit')}
            </Button>
          </div>
        }
      >
        <form id="new-expense-form" className="space-y-4" onSubmit={handleSubmit}>
          <FormField label={t('expense.form.category')} required>
            <Select value={category} onValueChange={setCategory}>
              <SelectTrigger>
                <SelectValue placeholder={t('expense.form.categoryPlaceholder')} />
              </SelectTrigger>
              <SelectContent>
                {(data?.categories ?? []).map((item) => (
                  <SelectItem key={item.id} value={item.id}>
                    {item.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </FormField>

          <FormField label={t('expense.form.title')} htmlFor="expenseTitle">
            <Input
              id="expenseTitle"
              value={title}
              onChange={(event) => setTitle(event.target.value)}
              placeholder={t('expense.form.titlePlaceholder')}
            />
          </FormField>

          <div className="grid gap-4 sm:grid-cols-2">
            <FormField label={t('expense.form.amount')} htmlFor="amount" required>
              <Input
                id="amount"
                inputMode="decimal"
                value={amount}
                onChange={(event) => setAmount(event.target.value)}
                placeholder="0"
                required
              />
            </FormField>
            <FormField label={t('expense.form.date')} htmlFor="expenseDate" required>
              <Input
                id="expenseDate"
                type="date"
                value={expenseDate}
                onChange={(event) => setExpenseDate(event.target.value)}
                required
              />
            </FormField>
          </div>

          <FormField label={t('expense.form.description')} htmlFor="expenseDescription">
            <Textarea
              id="expenseDescription"
              value={description}
              onChange={(event) => setDescription(event.target.value)}
              placeholder={t('expense.form.descriptionPlaceholder')}
            />
          </FormField>

          <FormField label={t('expense.form.receipt')} hint={t('expense.form.receiptHint')}>
            <div className="flex min-h-[88px] items-center justify-center rounded-lg border border-dashed border-[var(--color-border)] bg-[var(--color-bg-surface)] px-4 text-sm text-[var(--color-text-muted)]">
              {t('expense.form.receiptPlaceholder')}
            </div>
          </FormField>
        </form>
      </SheetShell>
    </div>
  )
}
