import { createFileRoute } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import { CalendarDays, Plus } from 'lucide-react'
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
  fetchDemoLeaveOverview,
  type DemoLeaveRequest,
  type LeaveStatus,
} from '#/lib/demo/puls-demo-data'
import { countBusinessDays } from '#/lib/format'

export const Route = createFileRoute('/_app/izin')({
  component: IzinPage,
})

function leaveStatusTone(status: LeaveStatus): StatusTone {
  switch (status) {
    case 'approved':
      return 'success'
    case 'pending':
      return 'warning'
    case 'rejected':
      return 'danger'
    default:
      return 'neutral'
  }
}

function formatDateRange(start: string, end: string, locale: string): string {
  const fmt = new Intl.DateTimeFormat(locale, { day: '2-digit', month: 'short' })
  return `${fmt.format(new Date(start))} – ${fmt.format(new Date(end))}`
}

function IzinPage() {
  const { t, i18n } = useTranslation()
  const [sheetOpen, setSheetOpen] = useState(false)
  const [localRequests, setLocalRequests] = useState<DemoLeaveRequest[]>([])
  const [leaveType, setLeaveType] = useState('annual')
  const [delegate, setDelegate] = useState('ozge')
  const [startDate, setStartDate] = useState('2026-07-14')
  const [endDate, setEndDate] = useState('2026-07-18')
  const [description, setDescription] = useState('')

  const { data, isLoading } = useQuery({
    queryKey: ['demo-leave-overview'],
    queryFn: fetchDemoLeaveOverview,
  })

  const allRequests = useMemo(
    () => [...localRequests, ...(data?.requests ?? [])],
    [localRequests, data?.requests],
  )

  const pendingCount = allRequests.filter((request) => request.status === 'pending').length
  const requestedDays = countBusinessDays(startDate, endDate)
  const balanceAfter = data
    ? Math.max(0, data.heroRemainingAnnual - (leaveType === 'annual' ? requestedDays : 0))
    : 0

  function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()

    const businessDays = countBusinessDays(startDate, endDate)
    if (businessDays <= 0) {
      toast.error(t('leave.form.dateError'))
      return
    }

    const typeLabel =
      data?.leaveTypes.find((item) => item.id === leaveType)?.label ?? t('leave.types.annual')
    const delegateName = data?.delegates.find((item) => item.id === delegate)?.name

    const newRequest: DemoLeaveRequest = {
      id: `local-${Date.now()}`,
      typeLabel,
      startDate,
      endDate,
      businessDays,
      delegateName,
      status: 'pending',
    }

    setLocalRequests((prev) => [newRequest, ...prev])
    setSheetOpen(false)
    toast.success(t('leave.toast.submitted'))
    setDescription('')
  }

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <PageHeader
        title={t('leave.title')}
        subtitle={t('leave.subtitle')}
        actions={
          <Button type="button" className="touch-target" onClick={() => setSheetOpen(true)}>
            <Plus className="h-4 w-4" />
            {t('leave.actions.new')}
          </Button>
        }
      />

      <MetricCard
        className="mb-6"
        label={t('leave.hero.remainingAnnual')}
        value={data ? `${data.heroRemainingAnnual} ${t('common.days')}` : '—'}
        hint={
          data
            ? t('leave.hero.summary', {
                used: data.heroUsedAnnual,
                total: data.heroTotalAnnual,
              })
            : undefined
        }
        icon={CalendarDays}
      />

      <div className="-mx-4 mb-6 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:grid-cols-4 md:overflow-visible md:px-0">
        {data?.balances.map((balance) => (
          <MetricCard
            key={balance.typeCode}
            compact
            label={t(balance.labelKey)}
            value={`${balance.remainingDays}/${balance.totalDays} ${t('common.days')}`}
          />
        ))}
        <MetricCard compact label={t('leave.metrics.pending')} value={String(pendingCount)} />
      </div>

      <SectionHeader title={t('leave.sections.history')} />
      <DataList
        items={allRequests.map((request) => ({
          id: request.id,
          title: request.typeLabel,
          subtitle: formatDateRange(request.startDate, request.endDate, i18n.language),
          meta: `${request.businessDays} ${t('common.days')}`,
          trailing: (
            <StatusPill tone={leaveStatusTone(request.status)}>
              {t(`leave.status.${request.status}`)}
            </StatusPill>
          ),
        }))}
        emptyLabel={isLoading ? t('common.loading') : t('leave.empty.history')}
      />

      <SheetShell
        open={sheetOpen}
        onOpenChange={setSheetOpen}
        title={t('leave.sheet.title')}
        description={t('leave.sheet.description')}
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
            <Button type="submit" form="new-leave-form" className="flex-1">
              {t('leave.actions.submit')}
            </Button>
          </div>
        }
      >
        <form id="new-leave-form" className="space-y-4" onSubmit={handleSubmit}>
          <FormField label={t('leave.form.type')} required>
            <Select value={leaveType} onValueChange={setLeaveType}>
              <SelectTrigger>
                <SelectValue placeholder={t('leave.form.typePlaceholder')} />
              </SelectTrigger>
              <SelectContent>
                {(data?.leaveTypes ?? []).map((type) => (
                  <SelectItem key={type.id} value={type.id}>
                    {type.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </FormField>

          <div className="grid gap-4 sm:grid-cols-2">
            <FormField label={t('leave.form.startDate')} htmlFor="startDate" required>
              <Input
                id="startDate"
                type="date"
                value={startDate}
                onChange={(event) => setStartDate(event.target.value)}
                required
              />
            </FormField>
            <FormField label={t('leave.form.endDate')} htmlFor="endDate" required>
              <Input
                id="endDate"
                type="date"
                value={endDate}
                onChange={(event) => setEndDate(event.target.value)}
                required
              />
            </FormField>
          </div>

          <FormField label={t('leave.form.delegate')}>
            <Select value={delegate} onValueChange={setDelegate}>
              <SelectTrigger>
                <SelectValue placeholder={t('leave.form.delegatePlaceholder')} />
              </SelectTrigger>
              <SelectContent>
                {(data?.delegates ?? []).map((item) => (
                  <SelectItem key={item.id} value={item.id}>
                    {item.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </FormField>

          <FormField label={t('leave.form.description')} htmlFor="description">
            <Textarea
              id="description"
              value={description}
              onChange={(event) => setDescription(event.target.value)}
              placeholder={t('leave.form.descriptionPlaceholder')}
            />
          </FormField>

          <FormField label={t('leave.form.balanceAfter')} hint={t('leave.form.balanceAfterHint')}>
            <Input
              readOnly
              value={`${balanceAfter} ${t('common.days')}${requestedDays > 0 ? ` (−${requestedDays})` : ''}`}
            />
          </FormField>
        </form>
      </SheetShell>
    </div>
  )
}
