import { createFileRoute } from '@tanstack/react-router'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  AlertTriangle,
  CalendarDays,
  CalendarPlus,
  Check,
  CheckCircle2,
  FileUp,
  Inbox,
  Info,
  Loader2,
  Plus,
  X,
} from 'lucide-react'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { RequestCreationReadinessBanners } from '#/components/puls/RequestCreationReadinessBanners'
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
  buildLeaveCreationReadiness,
  createLeaveRequest,
  decideApprovalRequest,
  fetchLeaveOverviewWithMeta,
  fetchRequestCreationReadiness,
  isDataAdapterError,
  type LeaveOverview,
  type LeaveStatus,
} from '#/lib/data'
import { countBusinessDays } from '#/lib/format'
import { cn } from '#/lib/utils'

export const Route = createFileRoute('/_app/izin')({
  head: () => ({
    meta: [
      { title: i18n.t('leave.title') + ' — PULS' },
      { name: 'description', content: i18n.t('leaveSetup.subtitle') },
    ],
  }),
  component: IzinPage,
})

type LeaveTab = 'mine' | 'approvals' | 'calendar'

type FormErrors = {
  startDate?: string
  endDate?: string
  halfDay?: string
}

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

function invalidateLeaveQueries(queryClient: ReturnType<typeof useQueryClient>, userId: string) {
  void queryClient.invalidateQueries({ queryKey: ['leave-overview', userId] })
  void queryClient.invalidateQueries({ queryKey: ['dashboard-overview', userId] })
}

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
  const startLabel = fmt.format(new Date(`${start}T12:00:00`))
  if (start === end) return startLabel
  const endLabel = fmt.format(new Date(`${end}T12:00:00`))
  return `${startLabel} – ${endLabel}`
}

function formatUpcomingBadge(isoDate: string, locale: string): { month: string; day: string } {
  const date = new Date(`${isoDate}T12:00:00`)
  const month = new Intl.DateTimeFormat(locale, { month: 'short' }).format(date).toUpperCase()
  const day = new Intl.DateTimeFormat(locale, { day: '2-digit' }).format(date)
  return { month, day }
}

function LeaveTypeLine({
  typeLabel,
  typeIsActive,
  suffix,
  t,
}: {
  typeLabel: string
  typeIsActive: boolean
  suffix?: string
  t: ReturnType<typeof useTranslation>['t']
}) {
  return (
    <div className="flex flex-wrap items-center gap-1.5">
      <span className="truncate text-[14px] font-medium text-foreground">
        {typeLabel}
        {suffix ? ` · ${suffix}` : null}
      </span>
      {typeIsActive === false ? (
        <StatusPill tone="neutral" className="text-[10px]">
          {t('leaveSetup.typeLifecycle.inactiveTypeBadge')}
        </StatusPill>
      ) : null}
    </div>
  )
}

function computeRequestedDays(startDate: string, endDate: string, halfDay: boolean): number {
  if (!startDate || !endDate || endDate < startDate) return 0
  if (halfDay) {
    if (startDate !== endDate) return 0
    return 0.5
  }
  return countBusinessDays(startDate, endDate)
}

function yearFromIsoDate(isoDate: string): number {
  return Number(isoDate.slice(0, 4))
}

function validateLeaveForm(
  startDate: string,
  endDate: string,
  halfDay: boolean,
  t: ReturnType<typeof useTranslation>['t'],
): FormErrors {
  const errors: FormErrors = {}
  if (!startDate) {
    errors.startDate = t('leaveSetup.form.startRequired')
  }
  if (!endDate) {
    errors.endDate = t('leaveSetup.form.endRequired')
  } else if (startDate && endDate < startDate) {
    errors.endDate = t('leaveSetup.form.endBeforeStart')
  } else if (startDate && endDate && yearFromIsoDate(startDate) !== yearFromIsoDate(endDate)) {
    errors.endDate = t('leave.error.crossYear')
  } else if (halfDay && startDate && endDate && startDate !== endDate) {
    errors.halfDay = t('leave.error.halfDayInvalid')
  }
  return errors
}

function IzinPage() {
  const { t, i18n } = useTranslation()
  const { user, activePersona } = useAuth()
  const queryClient = useQueryClient()
  const [tab, setTab] = useState<LeaveTab>('mine')
  const [sheetOpen, setSheetOpen] = useState(false)

  const { data: leaveOverviewResult, isLoading, isError, refetch } = useQuery({
    queryKey: ['leave-overview', user?.id],
    queryFn: () => fetchLeaveOverviewWithMeta(user!.id),
    enabled: Boolean(user?.id),
  })

  const data = leaveOverviewResult?.data

  const historyCount = data?.requests.length ?? 0
  const showApprovals = activePersona === 'manager'
  const approvalCount = showApprovals ? (data?.pendingApprovals.length ?? 0) : 0
  const activeTab: LeaveTab = showApprovals || tab !== 'approvals' ? tab : 'mine'

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="text-[12px] font-medium uppercase tracking-[0.04em] text-muted-foreground">
            {t('leaveSetup.eyebrow')}
          </div>
          <h1 className="mt-1 text-[26px] font-semibold tracking-tight text-foreground sm:text-3xl">
            {t('leave.title')}
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">{t('leaveSetup.subtitle')}</p>
        </div>
        <Button type="button" className="touch-target shrink-0" onClick={() => setSheetOpen(true)}>
          <Plus className="h-4 w-4" />
          {t('leave.actions.new')}
        </Button>
      </div>

      {leaveOverviewResult?.source === 'demo' ? (
        <div className="mt-4 flex flex-wrap gap-2">
          <StatusPill tone="neutral">{t('orgSetupReadiness.source.demo')}</StatusPill>
        </div>
      ) : null}

      {isLoading ? (
        <div className="mt-5 grid grid-cols-2 gap-3 sm:grid-cols-4">
          {Array.from({ length: 4 }).map((_, index) => (
            <Skeleton key={index} className="h-[120px] rounded-lg" />
          ))}
        </div>
      ) : isError ? (
        <div className="mt-5 rounded-lg border border-border bg-card">
          <EmptyState
            icon={CalendarDays}
            title={t('common.error')}
            description={t('leaveSetup.error.loadFailed')}
            action={
              <Button type="button" variant="outline" onClick={() => void refetch()}>
                {t('common.retry')}
              </Button>
            }
          />
        </div>
      ) : data ? (
        <>
          <section
            className="mt-5 grid grid-cols-2 gap-3 sm:grid-cols-4"
            aria-label={t('leave.form.balanceAfter')}
          >
            {data.balances.map((balance) => (
              <BalanceCard
                key={balance.typeCode}
                label={t(balance.labelKey)}
                used={balance.usedDays}
                total={balance.totalDays}
                usedLabel={t('leaveSetup.metrics.used', { count: balance.usedDays })}
                daysUnit={t('common.days')}
              />
            ))}
            <MetricCard
              compact
              className="min-w-0 sm:col-span-1"
              label={t('leave.metrics.pending')}
              value={String(data.pendingCount)}
              hint={t('leaveSetup.metrics.pendingHint')}
            />
          </section>

          <div className="mt-6">
            <Segmented
              ariaLabel={t('leaveSetup.tabs.ariaLabel')}
              value={activeTab}
              onChange={setTab}
              options={[
                {
                  value: 'mine',
                  label: `${t('leaveSetup.tabs.mine')} (${historyCount})`,
                },
                ...(showApprovals
                  ? [
                      {
                        value: 'approvals' as const,
                        label: `${t('leaveSetup.tabs.approvals')} (${approvalCount})`,
                      },
                    ]
                  : []),
                { value: 'calendar', label: t('leaveSetup.tabs.calendar') },
              ]}
            />
          </div>

          {activeTab === 'mine' ? (
            <MineTab upcoming={data.upcoming} requests={data.requests} locale={i18n.language} t={t} />
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

          {activeTab === 'calendar' ? (
            <section className="mt-6 rounded-lg border border-border bg-card">
              <EmptyState
                icon={Inbox}
                title={t('leaveSetup.calendar.title')}
                description={t('leaveSetup.calendar.description')}
              />
            </section>
          ) : null}
        </>
      ) : null}

      <LeaveFormSheet
        open={sheetOpen}
        onOpenChange={setSheetOpen}
        data={data}
        isOverviewLoading={isLoading}
        userId={user?.id}
        queryClient={queryClient}
        t={t}
      />
    </div>
  )
}

type MineTabProps = {
  upcoming: LeaveOverview['upcoming']
  requests: LeaveOverview['requests']
  locale: string
  t: ReturnType<typeof useTranslation>['t']
}

function MineTab({ upcoming, requests, locale, t }: MineTabProps) {
  return (
    <>
      <section className="mt-6">
        <SectionHeader
          title={t('leaveSetup.sections.upcoming')}
          description={t('leaveSetup.sections.upcomingDesc')}
        />
        {upcoming.length === 0 ? (
          <div className="mt-3 rounded-lg border border-border bg-card">
            <EmptyState icon={CalendarDays} title={t('leaveSetup.empty.upcoming')} />
          </div>
        ) : (
          <ul className="mt-3 divide-y divide-border overflow-hidden rounded-lg border border-border bg-card">
            {upcoming.map((item) => {
              const badge = formatUpcomingBadge(item.startDate, locale)
              return (
                <li key={item.id} className="flex min-h-16 items-center gap-3 p-4">
                  <div className="flex h-12 w-12 shrink-0 flex-col items-center justify-center rounded-md border border-border bg-surface-2 text-center">
                    <span className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
                      {badge.month}
                    </span>
                    <span className="text-[14px] font-semibold tabular text-foreground">
                      {badge.day}
                    </span>
                  </div>
                  <div className="min-w-0 flex-1">
                    <LeaveTypeLine
                      typeLabel={`${item.whoName} · ${item.typeLabel}`}
                      typeIsActive={item.typeIsActive}
                      t={t}
                    />
                    <div className="text-[12px] text-muted-foreground">
                      {formatDateRange(item.startDate, item.endDate, locale)} · {item.businessDays}{' '}
                      {t('common.days')}
                    </div>
                  </div>
                  <StatusPill tone={leaveStatusTone(item.status)}>
                    {t(`leave.status.${item.status}`)}
                  </StatusPill>
                </li>
              )
            })}
          </ul>
        )}
      </section>

      <section className="mt-8">
        <SectionHeader title={t('leaveSetup.sections.history')} />
        {requests.length === 0 ? (
          <div className="mt-3 rounded-lg border border-border bg-card">
            <EmptyState icon={CalendarDays} title={t('leaveSetup.empty.history')} />
          </div>
        ) : (
          <ul className="mt-3 divide-y divide-border overflow-hidden rounded-lg border border-border bg-card">
            {requests.map((request) => (
              <li key={request.id} className="flex min-h-16 items-center gap-3 p-4">
                <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-md bg-secondary text-secondary-foreground">
                  <CalendarDays className="h-4 w-4" />
                </span>
                <div className="min-w-0 flex-1">
                  <LeaveTypeLine
                    typeLabel={request.typeLabel}
                    typeIsActive={request.typeIsActive}
                    suffix={`${request.businessDays} ${t('common.days')}`}
                    t={t}
                  />
                  <div className="text-[12px] text-muted-foreground">
                    {formatDateRange(request.startDate, request.endDate, locale)}
                    {request.typeIsActive === false ? (
                      <span className="mt-0.5 block text-[11px] text-muted-foreground/80">
                        {t('leaveSetup.typeLifecycle.inactiveTypeHint')}
                      </span>
                    ) : null}
                  </div>
                </div>
                <StatusPill tone={leaveStatusTone(request.status)}>
                  {t(`leave.status.${request.status}`)}
                </StatusPill>
              </li>
            ))}
          </ul>
        )}
      </section>
    </>
  )
}

type ApprovalsTabProps = {
  approvals: LeaveOverview['pendingApprovals']
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
      if (userId) invalidateLeaveQueries(queryClient, userId)
      const approval = approvals.find((item) => item.id === variables.approvalRequestId)
      const name = approval?.employeeName ?? '—'
      if (variables.decision === 'approved') {
        if (result.final) {
          toast.success(t('leaveSetup.approval.approvedTitle'), {
            description: t('leaveSetup.approval.approvedDesc', { name }),
          })
        } else {
          toast.success(t('approval.toast.stepApproved'), {
            description: t('approval.toast.forwarded', {
              step: result.currentStepOrder ?? '—',
            }),
          })
        }
      } else {
        toast.success(t('leaveSetup.approval.rejectedTitle'), {
          description: t('leaveSetup.approval.rejectedDesc', { name }),
        })
      }
    },
    onError: (error) => {
      toastAdapterError(error, t, 'approval.error.forbidden')
    },
  })

  return (
    <section className="mt-6">
      <SectionHeader
        title={t('leaveSetup.sections.approvals')}
        description={t('leaveSetup.sections.approvalsDesc', { count: approvals.length })}
      />
      {approvals.length === 0 ? (
        <div className="mt-3 rounded-lg border border-border bg-card">
          <EmptyState icon={Inbox} title={t('leaveSetup.empty.approvals')} />
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
                <LeaveTypeLine
                  typeLabel={`${approval.employeeName} · ${approval.typeLabel}`}
                  typeIsActive={approval.typeIsActive}
                  t={t}
                />
                <div className="text-[12px] text-muted-foreground">
                  {formatDateRange(approval.startDate, approval.endDate, locale)} ·{' '}
                  <span className="tabular">
                    {approval.businessDays} {t('common.days')}
                  </span>
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
                  {t('leaveSetup.approval.reject')}
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
                  {t('leaveSetup.approval.approve')}
                </Button>
              </div>
            </li>
          ))}
        </ul>
      )}
    </section>
  )
}

type BalanceCardProps = {
  label: string
  used: number
  total: number
  usedLabel: string
  daysUnit: string
}

function BalanceCard({ label, used, total, usedLabel, daysUnit }: BalanceCardProps) {
  const remaining = total - used
  const pct = total > 0 ? Math.round((used / total) * 100) : 0

  return (
    <div className="min-w-0 rounded-lg border border-border bg-card p-4">
      <div className="text-[12px] font-medium uppercase tracking-[0.04em] text-muted-foreground">
        {label}
      </div>
      <div className="mt-2 flex items-baseline gap-1.5">
        <span className="text-[26px] font-semibold leading-none tabular text-foreground">
          {remaining}
        </span>
        <span className="text-[12px] text-muted-foreground">
          / {total} {daysUnit}
        </span>
      </div>
      <Progress value={pct} className="mt-3 h-1.5" />
      <div className="mt-1.5 text-[11px] text-muted-foreground">{usedLabel}</div>
    </div>
  )
}

type LeaveFormSheetProps = {
  open: boolean
  onOpenChange: (open: boolean) => void
  data: LeaveOverview | undefined
  isOverviewLoading: boolean
  userId: string | undefined
  queryClient: ReturnType<typeof useQueryClient>
  t: ReturnType<typeof useTranslation>['t']
}

function LeaveFormSheet({
  open,
  onOpenChange,
  data,
  isOverviewLoading,
  userId,
  queryClient,
  t,
}: LeaveFormSheetProps) {
  const defaultLeaveTypeId = data?.leaveTypes[0]?.id ?? ''
  const [leaveTypeId, setLeaveTypeId] = useState(defaultLeaveTypeId)
  const [startDate, setStartDate] = useState('')
  const [endDate, setEndDate] = useState('')
  const [halfDay, setHalfDay] = useState(false)
  const [delegate, setDelegate] = useState('')
  const [description, setDescription] = useState('')
  const [errors, setErrors] = useState<FormErrors>({})

  const { data: creationContext } = useQuery({
    queryKey: ['request-creation-readiness', 'leave', userId],
    queryFn: () => fetchRequestCreationReadiness(userId!, 'leave'),
    enabled: Boolean(userId) && open,
  })

  const readiness = useMemo(() => {
    if (!creationContext) return null
    return buildLeaveCreationReadiness({
      activeLeaveTypeCount: creationContext.activeTargetCount,
      assignment: creationContext.assignment,
      policyTargets: creationContext.policyTargets,
      selectedLeaveTypeId: leaveTypeId || null,
    })
  }, [creationContext, leaveTypeId])

  const resolvedLeaveType =
    data?.leaveTypes.find((item) => item.id === leaveTypeId) ??
    data?.leaveTypes.find((item) => item.id === defaultLeaveTypeId) ??
    data?.leaveTypes[0]

  const createMutation = useMutation({
    mutationFn: (payload: Parameters<typeof createLeaveRequest>[1]) => {
      if (!userId) throw new Error('missing user')
      return createLeaveRequest(userId, payload)
    },
    onSuccess: () => {
      if (userId) invalidateLeaveQueries(queryClient, userId)
      toast.success(t('leave.toast.submitted'))
      handleOpenChange(false)
    },
    onError: (error) => {
      toastAdapterError(error, t, 'leave.error.submitFailed')
    },
  })

  const requestedDays = computeRequestedDays(startDate, endDate, halfDay)
  const halfDayBlocked = halfDay && !!startDate && !!endDate && startDate !== endDate
  const annualRemaining = data?.heroRemainingAnnual ?? 0
  const isAnnualType = resolvedLeaveType?.code === 'annual'
  const balanceAfter = isAnnualType ? annualRemaining - requestedDays : annualRemaining
  const requiresDocument = resolvedLeaveType?.requiresDocument ?? false
  const hasActiveLeaveTypes = (data?.leaveTypes.length ?? 0) > 0
  const selectedTypeLabel = resolvedLeaveType?.label ?? t('leave.types.annual')
  const balanceIsNegative = isAnnualType && balanceAfter < 0

  function resetForm() {
    setLeaveTypeId(data?.leaveTypes[0]?.id ?? '')
    setStartDate('')
    setEndDate('')
    setHalfDay(false)
    setDelegate('')
    setDescription('')
    setErrors({})
  }

  function handleOpenChange(nextOpen: boolean) {
    if (nextOpen && data?.leaveTypes[0]?.id) {
      setLeaveTypeId(data.leaveTypes[0].id)
    }
    if (!nextOpen) resetForm()
    onOpenChange(nextOpen)
  }

  function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!resolvedLeaveType || requiresDocument) return

    const nextErrors = validateLeaveForm(startDate, endDate, halfDay, t)
    setErrors(nextErrors)
    if (Object.keys(nextErrors).length > 0) return

    const businessDays = computeRequestedDays(startDate, endDate, halfDay)
    if (businessDays <= 0) {
      toast.error(t('leave.form.dateError'))
      return
    }

    createMutation.mutate({
      leaveTypeId: resolvedLeaveType.id,
      startDate,
      endDate,
      halfDay,
      delegateEmployeeId: delegate || null,
      description: description.trim() || null,
    })
  }

  const isSubmitting = createMutation.isPending
  const canCreate = readiness?.canCreate ?? false

  return (
    <SheetShell
      open={open}
      onOpenChange={handleOpenChange}
      title={t('leave.sheet.title')}
      description={t('leave.sheet.description')}
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
            form="new-leave-form"
            className="min-h-11 flex-1"
            disabled={
              isSubmitting ||
              isOverviewLoading ||
              creationContext === undefined ||
              !hasActiveLeaveTypes ||
              !resolvedLeaveType ||
              requiresDocument ||
              halfDayBlocked ||
              !canCreate
            }
          >
            {isSubmitting ? (
              <>
                <Loader2 className="h-4 w-4 animate-spin" />
                {t('leave.actions.submitting')}
              </>
            ) : (
              <>
                <CalendarPlus className="h-4 w-4" />
                {t('leave.actions.submit')}
              </>
            )}
          </Button>
        </div>
      }
    >
      <form id="new-leave-form" className="space-y-5" onSubmit={handleSubmit}>
        {readiness ? <RequestCreationReadinessBanners readiness={readiness} t={t} /> : null}

        <FormField label={t('leave.form.type')} required>
          <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
            {(data?.leaveTypes ?? []).map((type) => (
              <button
                key={type.id}
                type="button"
                onClick={() => setLeaveTypeId(type.id)}
                aria-pressed={leaveTypeId === type.id}
                disabled={type.requiresDocument}
                className={cn(
                  'min-h-11 rounded-md border text-[13px] font-medium transition-colors',
                  leaveTypeId === type.id
                    ? 'border-primary bg-primary/10 text-primary'
                    : 'border-border bg-card text-foreground hover:bg-accent',
                  type.requiresDocument && 'cursor-not-allowed opacity-50',
                )}
              >
                {type.label}
              </button>
            ))}
          </div>
          {!hasActiveLeaveTypes ? (
            <p className="mt-2 text-[12px] leading-relaxed text-muted-foreground">
              {t('requestCreationReadiness.leave.noActiveLeaveTypes')}
            </p>
          ) : null}
        </FormField>

        {requiresDocument ? (
          <div className="flex items-start gap-2 rounded-md border border-warning/30 bg-warning-soft p-3 text-[13px] text-warning">
            <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
            <div className="text-[12px]">{t('leave.form.documentRequiredHint')}</div>
          </div>
        ) : null}

        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <FormField
            label={t('leave.form.startDate')}
            htmlFor="leave-start-date"
            required
            error={errors.startDate}
          >
            <Input
              id="leave-start-date"
              type="date"
              className="text-base"
              value={startDate}
              onChange={(event) => setStartDate(event.target.value)}
            />
          </FormField>
          <FormField
            label={t('leave.form.endDate')}
            htmlFor="leave-end-date"
            required
            error={errors.endDate}
          >
            <Input
              id="leave-end-date"
              type="date"
              className="text-base"
              value={endDate}
              onChange={(event) => setEndDate(event.target.value)}
            />
          </FormField>
        </div>

        <div className="flex flex-wrap items-center justify-between gap-3 rounded-md border border-border bg-surface-2 px-4 py-3">
          <div className="min-w-0">
            <div className="text-[14px] font-medium">
              {t('leaveSetup.form.totalDays', { count: requestedDays || 0 })}
            </div>
            <div className="text-[12px] text-muted-foreground">
              {t('leaveSetup.form.totalDaysHint')}
            </div>
            {errors.halfDay ? (
              <div className="mt-1 text-[12px] text-[var(--color-danger)]">{errors.halfDay}</div>
            ) : halfDayBlocked ? (
              <div className="mt-1 text-[12px] text-muted-foreground">
                {t('leaveSetup.form.halfDaySameDayHint')}
              </div>
            ) : null}
          </div>
          <label
            className={cn(
              'flex min-h-11 items-center gap-2 text-[13px]',
              halfDayBlocked ? 'cursor-not-allowed opacity-60' : 'cursor-pointer',
            )}
          >
            <input
              type="checkbox"
              checked={halfDay}
              disabled={halfDayBlocked}
              onChange={(event) => setHalfDay(event.target.checked)}
              className="h-4 w-4 rounded border-border accent-[color:var(--primary)]"
            />
            {t('leaveSetup.form.halfDay')}
          </label>
        </div>

        <FormField label={t('leave.form.delegate')} hint={t('leaveSetup.form.delegateHint')}>
          <select
            value={delegate}
            onChange={(event) => setDelegate(event.target.value)}
            className="flex h-11 w-full rounded-md border border-border bg-card px-3 text-base outline-none focus:border-ring"
          >
            <option value="">{t('leave.form.delegatePlaceholder')}</option>
            {(data?.delegates ?? []).map((item) => (
              <option key={item.id} value={item.id}>
                {item.name}
              </option>
            ))}
          </select>
        </FormField>

        <div className="flex items-start gap-2 rounded-md border border-border bg-surface-2 p-3 text-[13px] text-muted-foreground">
          <Info className="mt-0.5 h-4 w-4 shrink-0" />
          <div className="text-[12px]">{t('leave.form.approverAuto')}</div>
        </div>

        <FormField label={t('leave.form.description')} htmlFor="leave-description">
          <Textarea
            id="leave-description"
            rows={3}
            value={description}
            onChange={(event) => setDescription(event.target.value)}
            placeholder={t('leave.form.descriptionPlaceholder')}
            className="min-h-[88px] text-base"
          />
        </FormField>

        <FormField label={t('leaveSetup.form.document')} hint={t('leaveSetup.form.documentHint')}>
          <button
            type="button"
            disabled
            className="flex min-h-[80px] w-full items-center justify-center gap-2 rounded-md border border-dashed border-border bg-surface-2 px-4 py-4 text-[13px] text-muted-foreground opacity-70"
          >
            <FileUp className="h-4 w-4" />
            {t('leaveSetup.form.documentTeaser')}
          </button>
        </FormField>

        {isAnnualType && startDate && endDate ? (
          <div
            className={cn(
              'flex items-start gap-2 rounded-md border p-3 text-[13px]',
              balanceIsNegative
                ? 'border-danger/20 bg-danger-soft text-danger'
                : 'border-info/20 bg-info-soft text-info',
            )}
          >
            {balanceIsNegative ? (
              <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
            ) : (
              <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0" />
            )}
            <div className="min-w-0 flex-1">
              <div className="font-medium">{t('leaveSetup.form.summaryTitle')}</div>
              <div className="text-[12px] opacity-90">
                {balanceIsNegative
                  ? t('leaveSetup.form.summaryNegative')
                  : t('leaveSetup.form.summaryBody', {
                      days: requestedDays || 0,
                      type: selectedTypeLabel,
                      balance: balanceAfter,
                    })}
              </div>
            </div>
          </div>
        ) : null}
      </form>
    </SheetShell>
  )
}
