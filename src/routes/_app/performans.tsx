import { createFileRoute } from '@tanstack/react-router'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  Calendar,
  CheckCircle2,
  ChevronRight,
  Loader2,
  Play,
  Save,
  Target,
  Users,
} from 'lucide-react'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { EmptyState } from '#/components/puls/EmptyState'
import { FormField } from '#/components/puls/FormField'
import { MetricCard } from '#/components/puls/MetricCard'
import { SectionHeader } from '#/components/puls/SectionHeader'
import { SheetShell } from '#/components/puls/SheetShell'
import { StatusPill } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { Input } from '#/components/ui/input'
import { Skeleton } from '#/components/ui/skeleton'
import i18n from '#/i18n'
import { useAuth } from '#/lib/auth'
import {
  createPerformanceCycle,
  fetchCompetencyTemplates,
  fetchPerformanceCyclesWithMeta,
  fetchPerformanceOverviewWithMeta,
  updatePerformanceCycle,
  type CompetencyTemplate,
  type CreateCycleInput,
  type PerformansCycle,
} from '#/lib/data'
import { cn } from '#/lib/utils'

export const Route = createFileRoute('/_app/performans')({
  head: () => ({
    meta: [
      { title: i18n.t('performans.title') + ' — PULS' },
      {
        name: 'description',
        content: i18n.t('performans.subtitle'),
      },
    ],
  }),
  component: PerformansPage,
})

type PeriodFormValues = {
  name: string
  startsAt: string
  endsAt: string
  templateId: string
  scope: string
  methods: string[]
  reminders: string[]
}

type PeriodFormErrors = {
  name?: string
  startsAt?: string
  endsAt?: string
}

function formatCycleDate(isoDate: string, locale: string): string {
  return new Intl.DateTimeFormat(locale, {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  }).format(new Date(`${isoDate}T12:00:00`))
}

function toggleListValue(list: string[], value: string): string[] {
  return list.includes(value) ? list.filter((item) => item !== value) : [...list, value]
}

function validatePeriodForm(
  values: PeriodFormValues,
  t: ReturnType<typeof useTranslation>['t'],
): PeriodFormErrors {
  const errors: PeriodFormErrors = {}

  if (!values.name.trim()) {
    errors.name = t('performans.validation.nameRequired')
  }
  if (!values.startsAt) {
    errors.startsAt = t('performans.validation.startRequired')
  }
  if (!values.endsAt) {
    errors.endsAt = t('performans.validation.endRequired')
  } else if (values.startsAt && values.endsAt <= values.startsAt) {
    errors.endsAt = t('performans.validation.endAfterStart')
  }

  return errors
}

type PeriodSheetProps = {
  open: boolean
  onOpenChange: (open: boolean) => void
  templates: CompetencyTemplate[]
  defaultCycleName: string
  employeeScopeCount: number
  evaluatorCount: number
  isSubmitting: boolean
  submitMode: 'draft' | 'launch' | null
  formError: string | null
  onSaveDraft: (values: PeriodFormValues) => void
  onLaunch: (values: PeriodFormValues) => void
}

function PeriodSheet({
  open,
  onOpenChange,
  templates,
  defaultCycleName,
  employeeScopeCount,
  evaluatorCount,
  isSubmitting,
  submitMode,
  formError,
  onSaveDraft,
  onLaunch,
}: PeriodSheetProps) {
  const { t } = useTranslation()
  const [name, setName] = useState(defaultCycleName)
  const [startsAt, setStartsAt] = useState('')
  const [endsAt, setEndsAt] = useState('')
  const [templateId, setTemplateId] = useState(templates[0]?.id ?? '')
  const [scope, setScope] = useState('all')
  const [methods, setMethods] = useState<string[]>(['manager'])
  const [reminders, setReminders] = useState<string[]>(['start', 'lastThree', 'lastDay'])
  const [errors, setErrors] = useState<PeriodFormErrors>({})

  const selectedTemplate = templates.find((item) => item.id === templateId) ?? templates[0]

  const formValues: PeriodFormValues = {
    name,
    startsAt,
    endsAt,
    templateId: selectedTemplate?.id ?? '',
    scope,
    methods,
    reminders,
  }

  const handleValidateAndSubmit = (mode: 'draft' | 'launch') => {
    const nextErrors = validatePeriodForm(formValues, t)
    setErrors(nextErrors)
    if (Object.keys(nextErrors).length > 0) return

    if (mode === 'draft') {
      onSaveDraft(formValues)
    } else {
      onLaunch(formValues)
    }
  }

  return (
    <SheetShell
      open={open}
      onOpenChange={onOpenChange}
      title={t('performanceSetup.sheet.title')}
      description={t('performanceSetup.sheet.description')}
      footer={
        <div className="flex w-full flex-col gap-2 sm:flex-row">
          <Button
            type="button"
            variant="outline"
            className="touch-target h-11 flex-1"
            disabled={isSubmitting}
            onClick={() => onOpenChange(false)}
          >
            {t('performanceSetup.actions.cancel')}
          </Button>
          <Button
            type="button"
            variant="outline"
            className="touch-target h-11 flex-1"
            disabled={isSubmitting}
            onClick={() => handleValidateAndSubmit('draft')}
          >
            {isSubmitting && submitMode === 'draft' ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <Save className="h-4 w-4" />
            )}
            {t('performanceSetup.actions.saveDraft')}
          </Button>
          <Button
            type="button"
            className="touch-target h-11 flex-1"
            disabled={isSubmitting}
            onClick={() => handleValidateAndSubmit('launch')}
          >
            {isSubmitting && submitMode === 'launch' ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <Play className="h-4 w-4" />
            )}
            {t('performanceSetup.actions.launch')}
          </Button>
        </div>
      }
    >
      <form
        id="period-form"
        className="space-y-5"
        onSubmit={(event) => {
          event.preventDefault()
          handleValidateAndSubmit('launch')
        }}
      >
        <FormField
          label={t('performans.form.cycleName')}
          htmlFor="period-name"
          required
          error={errors.name}
        >
          <Input
            id="period-name"
            className="text-base"
            value={name}
            onChange={(event) => setName(event.target.value)}
            placeholder={defaultCycleName}
          />
        </FormField>

        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <FormField
            label={t('performans.form.startsAt')}
            htmlFor="period-start"
            required
            error={errors.startsAt}
          >
            <Input
              id="period-start"
              type="date"
              className="text-base"
              value={startsAt}
              onChange={(event) => setStartsAt(event.target.value)}
            />
          </FormField>
          <FormField
            label={t('performans.form.endsAt')}
            htmlFor="period-end"
            required
            error={errors.endsAt}
          >
            <Input
              id="period-end"
              type="date"
              className="text-base"
              value={endsAt}
              onChange={(event) => setEndsAt(event.target.value)}
            />
          </FormField>
        </div>

        <FormField label={t('performanceSetup.sheet.template')} htmlFor="period-template" required>
          <select
            id="period-template"
            className="flex h-11 w-full rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-card)] px-3 text-base text-[var(--color-text-primary)]"
            value={templateId || selectedTemplate?.id || ''}
            onChange={(event) => setTemplateId(event.target.value)}
          >
            {templates.map((template) => (
              <option key={template.id} value={template.id}>
                {template.name}
              </option>
            ))}
          </select>
        </FormField>

        <FormField label={t('performanceSetup.sheet.scope')}>
          <div className="grid grid-cols-1 gap-2 sm:grid-cols-3">
            {(
              [
                { id: 'all', labelKey: 'performanceSetup.scope.all' },
                { id: 'department', labelKey: 'performanceSetup.scope.department' },
                { id: 'position', labelKey: 'performanceSetup.scope.position' },
              ] as const
            ).map((option) => (
              <button
                key={option.id}
                type="button"
                aria-pressed={scope === option.id}
                onClick={() => setScope(option.id)}
                className={cn(
                  'touch-target h-11 rounded-lg border text-[13px] font-medium transition-colors',
                  scope === option.id
                    ? 'border-[var(--color-primary)] bg-[var(--color-primary-soft)] text-[var(--color-primary)]'
                    : 'border-[var(--color-border)] bg-[var(--color-bg-card)] text-[var(--color-text-primary)] hover:bg-[var(--color-bg-elevated)]',
                )}
              >
                {t(option.labelKey)}
              </button>
            ))}
          </div>
        </FormField>

        <FormField
          label={t('performanceSetup.sheet.method')}
          hint={t('performanceSetup.sheet.methodHint')}
        >
          <div className="space-y-2">
            {(
              [
                { id: 'manager', labelKey: 'performanceSetup.methods.manager' },
                { id: 'self', labelKey: 'performanceSetup.methods.self' },
                { id: 'calibration', labelKey: 'performanceSetup.methods.calibration' },
              ] as const
            ).map((option) => {
              const checked = methods.includes(option.id)
              return (
                <label
                  key={option.id}
                  className="flex min-h-[44px] cursor-pointer items-center justify-between rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-card)] px-3 py-2.5 text-sm hover:bg-[var(--color-bg-elevated)]"
                >
                  <span>{t(option.labelKey)}</span>
                  <input
                    type="checkbox"
                    checked={checked}
                    onChange={() => setMethods((current) => toggleListValue(current, option.id))}
                    className="h-4 w-4 rounded border-[var(--color-border)] accent-[var(--color-primary)]"
                  />
                </label>
              )
            })}
          </div>
        </FormField>

        <FormField label={t('performanceSetup.sheet.reminders')}>
          <div className="grid grid-cols-1 gap-2 sm:grid-cols-3">
            {(
              [
                { id: 'start', labelKey: 'performanceSetup.reminders.start' },
                { id: 'lastThree', labelKey: 'performanceSetup.reminders.lastThree' },
                { id: 'lastDay', labelKey: 'performanceSetup.reminders.lastDay' },
              ] as const
            ).map((option) => {
              const checked = reminders.includes(option.id)
              return (
                <button
                  key={option.id}
                  type="button"
                  aria-pressed={checked}
                  onClick={() => setReminders((current) => toggleListValue(current, option.id))}
                  className={cn(
                    'touch-target h-10 rounded-lg border text-[13px] font-medium transition-colors',
                    checked
                      ? 'border-[var(--color-primary)] bg-[var(--color-primary-soft)] text-[var(--color-primary)]'
                      : 'border-[var(--color-border)] bg-[var(--color-bg-card)] text-[var(--color-text-primary)] hover:bg-[var(--color-bg-elevated)]',
                  )}
                >
                  {t(option.labelKey)}
                </button>
              )
            })}
          </div>
        </FormField>

        <div className="rounded-lg border border-[var(--color-border-strong)] bg-[var(--color-primary-soft)] p-3 text-[13px] text-[var(--color-primary)]">
          <div className="flex items-start gap-2">
            <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0" />
            <div>
              <div className="font-medium">{t('performanceSetup.sheet.previewTitle')}</div>
              <div className="opacity-90">
                {t('performanceSetup.sheet.previewBody', {
                  employees: employeeScopeCount,
                  evaluators: evaluatorCount,
                  template: selectedTemplate?.name ?? '—',
                })}
              </div>
            </div>
          </div>
        </div>

        {formError ? <p className="text-sm text-[var(--color-danger)]">{formError}</p> : null}
      </form>
    </SheetShell>
  )
}

function PerformansPage() {
  const { t, i18n: i18nInstance } = useTranslation()
  const { user, activePersona } = useAuth()
  const queryClient = useQueryClient()
  const isManagerView = activePersona === 'manager'

  const [sheetOpen, setSheetOpen] = useState(false)
  const [sheetSessionKey, setSheetSessionKey] = useState(0)
  const [formError, setFormError] = useState<string | null>(null)
  const [submitMode, setSubmitMode] = useState<'draft' | 'launch' | null>(null)

  const { data: templates, isLoading: templatesLoading } = useQuery({
    queryKey: ['performance-competencies', user?.id],
    queryFn: () => fetchCompetencyTemplates(user!.id),
    enabled: Boolean(user?.id),
  })

  const { data: cyclesResult, isLoading: cyclesLoading } = useQuery({
    queryKey: ['performance-cycles', user?.id],
    queryFn: () => fetchPerformanceCyclesWithMeta(user!.id),
    enabled: Boolean(user?.id),
  })

  const { data: performanceOverviewResult } = useQuery({
    queryKey: ['performance-overview', user?.id],
    queryFn: () => fetchPerformanceOverviewWithMeta(user!.id),
    enabled: Boolean(user?.id),
  })

  const cycles = cyclesResult?.data
  const overviewData = performanceOverviewResult?.data
  const visibleEmployeeScopeCount = isManagerView ? (overviewData?.employeeScopeCount ?? 0) : 1
  const visiblePendingReviews = isManagerView ? (overviewData?.pendingReviews ?? 0) : 0
  const visibleOverdueCount = isManagerView ? (overviewData?.overdueCount ?? 0) : 0
  const showDemoSourcePill =
    performanceOverviewResult?.source === 'demo' || cyclesResult?.source === 'demo'

  const activeCycle = useMemo(
    () => cycles?.find((cycle) => cycle.status === 'active') ?? null,
    [cycles],
  )

  const draftCycles = useMemo(
    () => cycles?.filter((cycle) => cycle.status === 'draft') ?? [],
    [cycles],
  )

  const createMutation = useMutation({
    mutationFn: (input: CreateCycleInput) => createPerformanceCycle(user!.id, input),
    onSuccess: (result) => {
      setSubmitMode(null)
      if (result.error) {
        setFormError(result.error)
        return
      }
      setFormError(null)
      setSheetOpen(false)
      void queryClient.invalidateQueries({ queryKey: ['performance-cycles'] })
    },
    onError: () => {
      setSubmitMode(null)
    },
  })

  const statusMutation = useMutation({
    mutationFn: ({ id, status }: { id: string; status: PerformansCycle['status'] }) =>
      updatePerformanceCycle(user!.id, id, { status }),
    onSuccess: (result) => {
      if (result.error) return
      void queryClient.invalidateQueries({ queryKey: ['performance-cycles'] })
    },
  })

  const handleCreateCycle = (values: PeriodFormValues, status: PerformansCycle['status']) => {
    setFormError(null)
    setSubmitMode(status === 'draft' ? 'draft' : 'launch')
    void createMutation.mutateAsync({
      name: values.name,
      starts_at: values.startsAt,
      ends_at: values.endsAt,
      status,
    })
  }

  const openPeriodSheet = () => {
    setSheetSessionKey((key) => key + 1)
    setSheetOpen(true)
  }

  const isLoading = templatesLoading || cyclesLoading

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0 flex-1">
          <p className="text-xs font-medium uppercase tracking-wide text-[var(--color-text-muted)]">
            {t('performans.header.eyebrow')}
          </p>
          {isLoading ? (
            <Skeleton className="mt-2 h-9 w-64 max-w-full" />
          ) : (
            <h1 className="mt-1 text-[26px] font-semibold tracking-tight text-[var(--color-text-primary)] sm:text-3xl">
              {activeCycle
                ? t('performans.header.activeCycle', { name: activeCycle.name })
                : t('performans.title')}
            </h1>
          )}
          <p className="mt-1 text-sm text-[var(--color-text-muted)]">
            {activeCycle
              ? t('performanceSetup.cycleRange', {
                  start: formatCycleDate(activeCycle.starts_at, i18nInstance.language),
                  end: formatCycleDate(activeCycle.ends_at, i18nInstance.language),
                })
              : t('performanceSetup.noPeriodSubtitle')}
          </p>
        </div>
        <div className="flex shrink-0 flex-wrap items-center gap-2">
          {activeCycle ? (
            <StatusPill tone="success">{t('performans.status.active')}</StatusPill>
          ) : (
            <StatusPill tone="warning">{t('performans.status.noPeriod')}</StatusPill>
          )}
          {isManagerView && activeCycle ? (
            <Button
              type="button"
              variant="outline"
              className="touch-target h-11"
              onClick={openPeriodSheet}
            >
              <Play className="h-4 w-4" />
              {t('performanceSetup.actions.newCycle')}
            </Button>
          ) : null}
        </div>
      </div>

      {showDemoSourcePill ? (
        <div className="mt-4 flex flex-wrap gap-2">
          <StatusPill tone="neutral">{t('orgSetupReadiness.source.demo')}</StatusPill>
        </div>
      ) : null}

      {isLoading ? (
        <div className="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-4">
          {Array.from({ length: 4 }).map((_, index) => (
            <Skeleton key={index} className="h-28 w-full rounded-xl" />
          ))}
        </div>
      ) : activeCycle && overviewData ? (
        <section className="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-4">
          <MetricCard
            label={t('performanceSetup.metrics.scope')}
            value={String(visibleEmployeeScopeCount)}
            hint={t('performanceSetup.metrics.scopeHint')}
            icon={Users}
          />
          <MetricCard
            label={t('performanceSetup.metrics.pending')}
            value={String(visiblePendingReviews)}
            hint={t('performanceSetup.metrics.pendingHint')}
          />
          <MetricCard
            label={t('performanceSetup.metrics.completed')}
            value={String(overviewData.completedThisWeek)}
            hint={t('performanceSetup.metrics.completedHint')}
          />
          <MetricCard
            label={t('performanceSetup.metrics.overdue')}
            value={String(visibleOverdueCount)}
            hint={t('performanceSetup.metrics.overdueHint')}
          />
        </section>
      ) : overviewData ? (
        <section className="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-4">
          <MetricCard
            label={t('performanceSetup.metrics.noActiveCycle')}
            value="—"
            hint={t('performanceSetup.metrics.noActiveCycleHint')}
            icon={Calendar}
          />
          <MetricCard
            label={t('performanceSetup.metrics.templates')}
            value={String(templates?.length ?? 0)}
            hint={t('performanceSetup.metrics.templatesHint')}
            icon={Target}
          />
          <MetricCard
            label={t('performanceSetup.metrics.evaluators')}
            value={String(overviewData.evaluatorCount)}
            hint={t('performanceSetup.metrics.evaluatorsHint')}
          />
          <MetricCard
            label={t('performanceSetup.metrics.scope')}
            value={String(visibleEmployeeScopeCount)}
            hint={t('performanceSetup.metrics.scopeHint')}
            icon={Users}
          />
        </section>
      ) : null}

      {!activeCycle && isManagerView ? (
        <div className="mt-8 rounded-xl border border-dashed border-[var(--color-border)] bg-[var(--color-bg-card)] p-8 text-center">
          <span className="inline-flex h-12 w-12 items-center justify-center rounded-full bg-[var(--color-primary-soft)] text-[var(--color-primary)]">
            <Target className="h-6 w-6" aria-hidden />
          </span>
          <h2 className="mt-3 text-base font-semibold text-[var(--color-text-primary)]">
            {t('performanceSetup.emptyPeriod.title')}
          </h2>
          <p className="mx-auto mt-1 max-w-md text-sm text-[var(--color-text-muted)]">
            {t('performanceSetup.emptyPeriod.description')}
          </p>
          <Button
            type="button"
            className="touch-target mt-4 h-11"
            onClick={openPeriodSheet}
          >
            <Play className="h-4 w-4" />
            {t('performanceSetup.emptyPeriod.configure')}
          </Button>
        </div>
      ) : null}

      {!activeCycle && !isManagerView ? (
        <p className="mt-8 rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4 text-sm text-[var(--color-text-muted)]">
          {t('performans.managerOnlyCreate')}
        </p>
      ) : null}

      {isManagerView && draftCycles.length > 0 ? (
        <section className="mt-8">
          <SectionHeader title={t('performanceSetup.draftCycles')} />
          <ul className="mt-3 divide-y divide-[var(--color-border)] overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
            {draftCycles.map((cycle) => (
              <li
                key={cycle.id}
                className="flex min-h-[64px] flex-wrap items-center justify-between gap-3 p-4"
              >
                <div className="min-w-0">
                  <p className="truncate text-sm font-medium text-[var(--color-text-primary)]">
                    {cycle.name}
                  </p>
                  <p className="truncate text-xs text-[var(--color-text-muted)]">
                    {t('performanceSetup.cycleRange', {
                      start: formatCycleDate(cycle.starts_at, i18nInstance.language),
                      end: formatCycleDate(cycle.ends_at, i18nInstance.language),
                    })}
                  </p>
                </div>
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  className="touch-target shrink-0"
                  disabled={statusMutation.isPending}
                  onClick={() =>
                    void statusMutation.mutateAsync({ id: cycle.id, status: 'active' })
                  }
                >
                  {t('performans.actions.activate')}
                </Button>
              </li>
            ))}
          </ul>
        </section>
      ) : null}

      <section className="mt-8">
        <SectionHeader
          title={t('performans.sections.competencies')}
          description={t('performans.sections.competenciesHint')}
        />
        {templatesLoading ? (
          <div className="mt-3 space-y-2">
            <Skeleton className="h-16 w-full rounded-xl" />
            <Skeleton className="h-16 w-full rounded-xl" />
          </div>
        ) : templates && templates.length > 0 ? (
          <ul className="mt-3 divide-y divide-[var(--color-border)] overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
            {templates.map((template, index) => {
              const displayMeta = overviewData?.templateDisplayByIndex[index]
              return (
                <li key={template.id} className="flex min-h-[64px] items-center gap-3 p-4">
                  <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-[var(--color-bg-elevated)] text-[var(--color-text-secondary)]">
                    <Target className="h-4 w-4" />
                  </span>
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-sm font-medium text-[var(--color-text-primary)]">
                      {template.name}
                    </div>
                    <div className="truncate text-xs text-[var(--color-text-muted)]">
                      {displayMeta
                        ? t('performanceSetup.templates.areas', {
                            count: displayMeta.areasCount,
                            updated: t(displayMeta.updatedKey),
                          })
                        : (template.description ?? '')}
                    </div>
                  </div>
                  <StatusPill tone="success">{t('performanceSetup.templates.ready')}</StatusPill>
                  <ChevronRight
                    className="h-4 w-4 shrink-0 text-[var(--color-text-muted)]"
                    aria-hidden
                  />
                </li>
              )
            })}
          </ul>
        ) : (
          <EmptyState title={t('performans.empty.competencies')} />
        )}
      </section>

      {isManagerView && templates && templates.length > 0 ? (
        <PeriodSheet
          key={sheetSessionKey}
          open={sheetOpen}
          onOpenChange={setSheetOpen}
          templates={templates}
          defaultCycleName={overviewData?.defaultCycleName ?? '2026 Q2'}
          employeeScopeCount={overviewData?.employeeScopeCount ?? 0}
          evaluatorCount={overviewData?.evaluatorCount ?? 0}
          isSubmitting={createMutation.isPending}
          submitMode={submitMode}
          formError={formError}
          onSaveDraft={(values) => handleCreateCycle(values, 'draft')}
          onLaunch={(values) => handleCreateCycle(values, 'active')}
        />
      ) : null}
    </div>
  )
}
