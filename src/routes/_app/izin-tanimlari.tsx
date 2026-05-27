import { createFileRoute } from '@tanstack/react-router'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { CalendarDays, Check, FileCheck2, Loader2, Plus, Save, Workflow, X } from 'lucide-react'
import { useMemo, useState, type FormEvent } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { SetupRouteGuard } from '#/components/auth/SetupRouteGuard'
import { ApprovalPolicyBindingSection } from '#/components/puls/ApprovalPolicyBindingSection'
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
import {
  buildApprovalPolicyBindingInfo,
  createLeaveType,
  fetchApprovalPoliciesOverview,
  fetchLeaveTypesOverview,
  isLeaveTypeFormDirty,
  mapLeaveTypeMutationError,
  normalizeLeaveTypeCode,
  updateLeaveType,
  validateLeaveTypeForm,
  type ApprovalPolicyBindingInfo,
  type ApprovalPolicyOverviewItem,
  type LeaveTypeFieldKey,
  type LeaveTypeFormFields,
  type LeaveTypesOverview,
} from '#/lib/data'
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

type LeaveTypeRule = LeaveTypesOverview['leaveTypes'][number]

const EMPTY_LEAVE_TYPE_FORM: LeaveTypeFormFields = {
  name: '',
  code: '',
  defaultEntitlementDays: '',
  requiresDocument: false,
  carryOverAllowed: false,
  maxCarryOverDays: '',
  approvalPolicyId: null,
}

function leaveTypeToForm(rule: LeaveTypeRule): LeaveTypeFormFields {
  return {
    name: rule.name,
    code: rule.code,
    defaultEntitlementDays:
      rule.defaultEntitlementDays === null ? '' : String(rule.defaultEntitlementDays),
    requiresDocument: rule.doc,
    carryOverAllowed: rule.carryOver,
    maxCarryOverDays:
      rule.maxCarryOverDays === null ? '' : String(rule.maxCarryOverDays),
    approvalPolicyId: rule.approvalPolicyId ?? null,
  }
}

function translateFieldError(
  t: (key: string, options?: Record<string, unknown>) => string,
  fieldErrors: Partial<Record<LeaveTypeFieldKey, string>>,
  field: LeaveTypeFieldKey,
): string | undefined {
  const key = fieldErrors[field]
  return key ? t(key) : undefined
}

type PolicySelectOption = {
  value: string
  label: string
  disabled?: boolean
}

function buildPolicySelectOptions(
  t: (key: string, options?: Record<string, unknown>) => string,
  policies: ApprovalPolicyOverviewItem[],
  editingRule: LeaveTypeRule | null,
): PolicySelectOption[] {
  const leavePolicies = policies.filter((policy) => policy.module === 'leave')
  const options: PolicySelectOption[] = [
    { value: '', label: t('leaveTypeSetup.sheet.policyUnbound') },
    ...leavePolicies.map((policy) => ({
      value: policy.id,
      label: policy.name,
    })),
  ]

  const currentPolicyId = editingRule?.approvalPolicyId ?? null
  if (currentPolicyId && !leavePolicies.some((policy) => policy.id === currentPolicyId)) {
    const binding = editingRule!.approvalPolicy
    const policyName =
      editingRule!.approvalPolicyName ?? binding.policyName ?? currentPolicyId
    const statusKey =
      binding.status === 'unbound' ? 'policy_unavailable' : binding.status
    options.splice(1, 0, {
      value: currentPolicyId,
      label: t(`leaveTypeSetup.sheet.policyCurrent.${statusKey}`, { name: policyName }),
      disabled: binding.status !== 'ready',
    })
  }

  return options
}

function resolveFormBinding(
  form: LeaveTypeFormFields,
  policies: ApprovalPolicyOverviewItem[],
  editingRule: LeaveTypeRule | null,
): ApprovalPolicyBindingInfo {
  const policyId = form.approvalPolicyId
  if (!policyId) {
    return buildApprovalPolicyBindingInfo({
      expectedModule: 'leave',
      policyId: null,
      policyName: null,
      policyModule: null,
      policyIsActive: null,
      requiredStepCount: 0,
    })
  }

  const activePolicy = policies.find((policy) => policy.id === policyId)
  if (activePolicy) {
    return buildApprovalPolicyBindingInfo({
      expectedModule: 'leave',
      policyId,
      policyName: activePolicy.name,
      policyModule: activePolicy.module,
      policyIsActive: true,
      requiredStepCount: activePolicy.requiredStepCount,
    })
  }

  if (editingRule?.approvalPolicyId === policyId) {
    return editingRule.approvalPolicy
  }

  return buildApprovalPolicyBindingInfo({
    expectedModule: 'leave',
    policyId,
    policyName: null,
    policyModule: null,
    policyIsActive: null,
    requiredStepCount: 0,
  })
}

type LeaveTypeCellsProps = {
  rule: LeaveTypeRule
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
  const queryClient = useQueryClient()
  const [sheetOpen, setSheetOpen] = useState(false)
  const [editingLeaveType, setEditingLeaveType] = useState<LeaveTypeRule | null>(null)
  const [leaveTypeForm, setLeaveTypeForm] = useState<LeaveTypeFormFields>(EMPTY_LEAVE_TYPE_FORM)
  const [formBaseline, setFormBaseline] = useState<LeaveTypeFormFields | null>(null)
  const [fieldErrors, setFieldErrors] = useState<Partial<Record<LeaveTypeFieldKey, string>>>({})

  const { data, isLoading } = useQuery({
    queryKey: ['leave-types-overview', user?.id],
    queryFn: () => fetchLeaveTypesOverview(user!.id),
    enabled: Boolean(user?.id),
  })

  const { data: policies = [] } = useQuery({
    queryKey: ['approval-policies-overview', user?.id],
    queryFn: () => fetchApprovalPoliciesOverview(user!.id),
    enabled: Boolean(user?.id),
  })

  const leaveTypeMutation = useMutation({
    mutationFn: (payload: LeaveTypeFormFields) => {
      const validation = validateLeaveTypeForm(payload)
      if (!validation.isValid) {
        throw new Error('validation')
      }

      const input = {
        name: validation.normalized.name,
        code: validation.normalized.code,
        defaultEntitlementDays: validation.normalized.defaultEntitlementDays,
        requiresDocument: validation.normalized.requiresDocument,
        carryOverAllowed: validation.normalized.carryOverAllowed,
        maxCarryOverDays: validation.normalized.maxCarryOverDays,
        approvalPolicyId: validation.normalized.approvalPolicyId,
      }

      if (editingLeaveType) {
        return updateLeaveType(user!.id, editingLeaveType.id, input)
      }

      return createLeaveType(user!.id, input)
    },
    onSuccess: () => {
      const wasEdit = Boolean(editingLeaveType)
      void queryClient.invalidateQueries({ queryKey: ['leave-types-overview', user?.id] })
      resetLeaveTypeSheetState()
      toast.success(
        t(wasEdit ? 'leaveTypeSetup.toast.updated' : 'leaveTypeSetup.toast.created'),
      )
    },
    onError: (error) => {
      if (error instanceof Error && error.message === 'validation') {
        return
      }

      const mapped = mapLeaveTypeMutationError(error)
      setFieldErrors((current) => ({ ...current, ...mapped.fieldErrors }))
      if (mapped.toastKey) {
        toast.error(t(mapped.toastKey))
      }
    },
  })

  const sheetMode = editingLeaveType ? 'edit' : 'create'
  const dirtyBaseline = formBaseline ?? EMPTY_LEAVE_TYPE_FORM
  const isLeaveTypeFormDirtyState = isLeaveTypeFormDirty(leaveTypeForm, dirtyBaseline)
  const isSaving = leaveTypeMutation.isPending
  const isSaveDisabled =
    isSaving || (sheetMode === 'edit' && !isLeaveTypeFormDirtyState)
  const normalizedCodePreview = normalizeLeaveTypeCode(leaveTypeForm.code)

  const policySelectOptions = useMemo(
    () => buildPolicySelectOptions(t, policies, editingLeaveType),
    [t, policies, editingLeaveType],
  )

  const formBinding = useMemo(
    () => resolveFormBinding(leaveTypeForm, policies, editingLeaveType),
    [leaveTypeForm, policies, editingLeaveType],
  )

  function resetLeaveTypeSheetState() {
    setSheetOpen(false)
    setEditingLeaveType(null)
    setLeaveTypeForm(EMPTY_LEAVE_TYPE_FORM)
    setFormBaseline(null)
    setFieldErrors({})
  }

  function openCreateLeaveTypeSheet() {
    setEditingLeaveType(null)
    setLeaveTypeForm(EMPTY_LEAVE_TYPE_FORM)
    setFormBaseline(EMPTY_LEAVE_TYPE_FORM)
    setFieldErrors({})
    setSheetOpen(true)
  }

  function openEditLeaveTypeSheet(rule: LeaveTypeRule) {
    const baseline = leaveTypeToForm(rule)
    setEditingLeaveType(rule)
    setLeaveTypeForm(baseline)
    setFormBaseline(baseline)
    setFieldErrors({})
    setSheetOpen(true)
  }

  function requestCloseLeaveTypeSheet() {
    if (
      isLeaveTypeFormDirtyState &&
      !window.confirm(t('leaveTypeSetup.validation.discardConfirm'))
    ) {
      return
    }

    resetLeaveTypeSheetState()
  }

  function handleLeaveTypeSheetOpenChange(open: boolean) {
    if (open) {
      setSheetOpen(true)
      return
    }

    requestCloseLeaveTypeSheet()
  }

  function updateLeaveTypeForm<K extends keyof LeaveTypeFormFields>(
    field: K,
    value: LeaveTypeFormFields[K],
  ) {
    setLeaveTypeForm((current) => {
      const next = { ...current, [field]: value }
      if (field === 'carryOverAllowed' && value === false) {
        next.maxCarryOverDays = ''
      }
      return next
    })
    setFieldErrors((current) => {
      const key = field as LeaveTypeFieldKey
      const shouldClearField = Boolean(current[key])
      const shouldClearCarryOverMax =
        field === 'carryOverAllowed' && value === false && Boolean(current.maxCarryOverDays)

      if (!shouldClearField && !shouldClearCarryOverMax) {
        return current
      }

      const next = { ...current }
      if (shouldClearField) {
        delete next[key]
      }
      if (shouldClearCarryOverMax) {
        delete next.maxCarryOverDays
      }
      return next
    })
  }

  function handleLeaveTypeSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()

    const validation = validateLeaveTypeForm(leaveTypeForm)
    setFieldErrors(validation.fieldErrors)

    if (!validation.isValid) {
      return
    }

    leaveTypeMutation.mutate(leaveTypeForm)
  }

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
          <Button
            type="button"
            className="touch-target w-full sm:w-auto"
            onClick={openCreateLeaveTypeSheet}
          >
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
            value={t('leaveTypeSetup.metrics.approvalFlowValue', {
              count: data.maxApprovalStepCount,
            })}
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
                title: rule.name,
                subtitle: [
                  t('leaveTypeSetup.dayCount', { count: rule.days }),
                  rule.carryOver ? t('leaveTypeSetup.carryOver.yes') : null,
                ]
                  .filter(Boolean)
                  .join(' · '),
                trailing: <MobileRuleTrailing rule={rule} />,
                onClick: () => openEditLeaveTypeSheet(rule),
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
                  <li key={rule.id}>
                    <button
                      type="button"
                      className={cn(
                        'grid w-full items-center gap-3 px-4 py-3 text-left hover:bg-[var(--color-bg-elevated)]',
                        LEAVE_TYPE_TABLE_GRID_COLS,
                      )}
                      onClick={() => openEditLeaveTypeSheet(rule)}
                    >
                      <div className="truncate text-sm font-medium">{rule.name}</div>
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
                    </button>
                  </li>
                ))}
          </ul>
        </div>
      </section>

      <SheetShell
        open={sheetOpen}
        onOpenChange={handleLeaveTypeSheetOpenChange}
        title={t(
          sheetMode === 'edit'
            ? 'leaveTypeSetup.sheet.edit.title'
            : 'leaveTypeSetup.sheet.create.title',
        )}
        description={t(
          sheetMode === 'edit'
            ? 'leaveTypeSetup.sheet.edit.description'
            : 'leaveTypeSetup.sheet.create.description',
        )}
        footer={
          <div className="flex w-full flex-col gap-3 sm:flex-row">
            <Button
              type="button"
              variant="outline"
              className="touch-target w-full sm:w-auto"
              onClick={requestCloseLeaveTypeSheet}
              disabled={isSaving}
            >
              <X className="h-4 w-4" />
              {t('common.cancel')}
            </Button>
            <Button
              type="submit"
              form="leave-type-form"
              className="touch-target w-full sm:flex-1"
              disabled={isSaveDisabled}
            >
              {isSaving ? (
                <Loader2 className="h-4 w-4 animate-spin" />
              ) : (
                <Save className="h-4 w-4" />
              )}
              {t('leaveTypeSetup.sheet.submit')}
            </Button>
          </div>
        }
      >
        <form id="leave-type-form" className="space-y-4" onSubmit={handleLeaveTypeSubmit}>
          <FormField
            label={t('leaveTypeSetup.sheet.fields.label')}
            htmlFor="leave-type-name"
            required
            error={translateFieldError(t, fieldErrors, 'name')}
          >
            <Input
              id="leave-type-name"
              className="text-base"
              placeholder={t('leaveTypeSetup.sheet.placeholders.label')}
              value={leaveTypeForm.name}
              onChange={(event) => updateLeaveTypeForm('name', event.target.value)}
              aria-invalid={Boolean(fieldErrors.name) || undefined}
            />
          </FormField>

          <FormField
            label={t('leaveTypeSetup.sheet.fields.code')}
            htmlFor="leave-type-code"
            required
            hint={
              leaveTypeForm.code.trim()
                ? t('leaveTypeSetup.validation.codePreviewHint', { code: normalizedCodePreview })
                : undefined
            }
            error={translateFieldError(t, fieldErrors, 'code')}
          >
            <Input
              id="leave-type-code"
              className="text-base font-mono"
              placeholder={t('leaveTypeSetup.sheet.placeholders.code')}
              value={leaveTypeForm.code}
              onChange={(event) => updateLeaveTypeForm('code', event.target.value)}
              aria-invalid={Boolean(fieldErrors.code) || undefined}
            />
          </FormField>

          <FormField
            label={t('leaveTypeSetup.sheet.fields.days')}
            htmlFor="leave-type-days"
            error={translateFieldError(t, fieldErrors, 'defaultEntitlementDays')}
          >
            <Input
              id="leave-type-days"
              className="text-base"
              inputMode="decimal"
              placeholder={t('leaveTypeSetup.sheet.placeholders.days')}
              value={leaveTypeForm.defaultEntitlementDays}
              onChange={(event) =>
                updateLeaveTypeForm('defaultEntitlementDays', event.target.value)
              }
              aria-invalid={Boolean(fieldErrors.defaultEntitlementDays) || undefined}
            />
          </FormField>

          <label className="flex min-h-11 cursor-pointer items-center justify-between gap-3 rounded-md border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-4 py-3">
            <span className="text-sm font-medium">{t('leaveTypeSetup.sheet.fields.requiresDocument')}</span>
            <input
              type="checkbox"
              checked={leaveTypeForm.requiresDocument}
              onChange={(event) =>
                updateLeaveTypeForm('requiresDocument', event.target.checked)
              }
              className="h-5 w-5 shrink-0 rounded border-[var(--color-border)] accent-[color:var(--color-primary)]"
            />
          </label>

          <label className="flex min-h-11 cursor-pointer items-center justify-between gap-3 rounded-md border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-4 py-3">
            <span className="text-sm font-medium">{t('leaveTypeSetup.sheet.fields.carryOverAllowed')}</span>
            <input
              type="checkbox"
              checked={leaveTypeForm.carryOverAllowed}
              onChange={(event) =>
                updateLeaveTypeForm('carryOverAllowed', event.target.checked)
              }
              className="h-5 w-5 shrink-0 rounded border-[var(--color-border)] accent-[color:var(--color-primary)]"
            />
          </label>

          <FormField
            label={t('leaveTypeSetup.sheet.fields.maxCarryOverDays')}
            htmlFor="leave-type-max-carry-over"
            error={translateFieldError(t, fieldErrors, 'maxCarryOverDays')}
          >
            <Input
              id="leave-type-max-carry-over"
              className="text-base"
              inputMode="decimal"
              placeholder={t('leaveTypeSetup.sheet.placeholders.maxCarryOverDays')}
              value={leaveTypeForm.maxCarryOverDays}
              onChange={(event) => updateLeaveTypeForm('maxCarryOverDays', event.target.value)}
              disabled={!leaveTypeForm.carryOverAllowed}
              aria-invalid={Boolean(fieldErrors.maxCarryOverDays) || undefined}
            />
          </FormField>

          <FormField
            label={t('leaveTypeSetup.sheet.fields.approvalPolicy')}
            htmlFor="leave-type-policy"
            error={translateFieldError(t, fieldErrors, 'approvalPolicyId')}
          >
            <select
              id="leave-type-policy"
              value={leaveTypeForm.approvalPolicyId ?? ''}
              onChange={(event) =>
                updateLeaveTypeForm(
                  'approvalPolicyId',
                  event.target.value ? event.target.value : null,
                )
              }
              className="h-11 w-full rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-card)] px-3 text-base text-[var(--color-text-primary)] outline-none focus:border-[var(--color-primary)]"
              aria-invalid={Boolean(fieldErrors.approvalPolicyId) || undefined}
            >
              {policySelectOptions.map((option) => (
                <option key={option.value || '__unbound__'} value={option.value} disabled={option.disabled}>
                  {option.label}
                </option>
              ))}
            </select>
          </FormField>

          <ApprovalPolicyBindingSection binding={formBinding} />
        </form>
      </SheetShell>
    </div>
  )
}
