import { createFileRoute } from '@tanstack/react-router'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Building2, Loader2, Lock, Plus, Power, RotateCcw, Save, UserCheck, UserMinus, Users } from 'lucide-react'
import { useState, type FormEvent } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { SetupRouteGuard } from '#/components/auth/SetupRouteGuard'
import { DataList } from '#/components/puls/DataList'
import { DemoSourcePill } from '#/components/puls/DemoSourcePill'
import { EmptyState } from '#/components/puls/EmptyState'
import { FormField } from '#/components/puls/FormField'
import { MetricCard } from '#/components/puls/MetricCard'
import { PageHeader } from '#/components/puls/PageHeader'
import { SectionHeader } from '#/components/puls/SectionHeader'
import { Segmented } from '#/components/puls/Segmented'
import { SheetShell } from '#/components/puls/SheetShell'
import { StatusPill } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { Input } from '#/components/ui/input'
import { Skeleton } from '#/components/ui/skeleton'
import i18n from '#/i18n'
import { useAuth } from '#/lib/auth'
import {
  applyOrgEntityLifecycleFilter,
  createDepartment,
  deactivateDepartment,
  fetchDepartmentsOverviewWithMeta,
  invalidateOrgStructureQueries,
  isDepartmentFormDirty,
  mapDepartmentLifecycleError,
  mapDepartmentMutationError,
  normalizeOrgSetupCode,
  restoreDepartment,
  updateDepartment,
  validateDepartmentForm,
  type DepartmentFieldKey,
  type DepartmentFormFields,
  type DepartmentsOverview,
  type OrgEntityLifecycleFilter,
  type OrgSetupEntitySource,
} from '#/lib/data'
import { cn } from '#/lib/utils'

export const Route = createFileRoute('/_app/departmanlar')({
  head: () => ({
    meta: [
      { title: i18n.t('departments.meta.title') },
      {
        name: 'description',
        content: i18n.t('departments.meta.description'),
      },
    ],
  }),
  component: DepartmanlarRoute,
})

function DepartmanlarRoute() {
  return (
    <SetupRouteGuard>
      <DepartmanlarPage />
    </SetupRouteGuard>
  )
}

const DEPARTMENT_SKELETON_COUNT = 3
const DEPARTMENT_TABLE_GRID_COLS =
  'grid-cols-[minmax(0,1fr)_88px_minmax(0,1fr)_72px_120px]'

type DepartmentRow = DepartmentsOverview['departments'][number]
type SheetMode = 'create' | 'edit' | 'readonly'

const EMPTY_DEPARTMENT_FORM: DepartmentFormFields = {
  name: '',
  code: '',
}

function departmentToForm(department: DepartmentRow): DepartmentFormFields {
  return {
    name: department.name,
    code: department.code ?? '',
  }
}

function OrgEntitySourcePill({ source }: { source: OrgSetupEntitySource }) {
  const { t } = useTranslation()
  const tone =
    source === 'erp' ? 'warning' : source === 'demo' ? 'neutral' : source === 'puls' ? 'success' : 'neutral'
  return <StatusPill tone={tone}>{t(`orgSetupReadiness.source.${source}`)}</StatusPill>
}

function ActiveStatusPill({ isActive }: { isActive: boolean }) {
  const { t } = useTranslation()
  return (
    <StatusPill tone={isActive ? 'success' : 'neutral'}>
      {t(isActive ? 'departments.status.active' : 'departments.status.inactive')}
    </StatusPill>
  )
}

function DepartmanlarPage() {
  const { t } = useTranslation()
  const { user } = useAuth()
  const queryClient = useQueryClient()

  const [sheetOpen, setSheetOpen] = useState(false)
  const [sheetMode, setSheetMode] = useState<SheetMode>('create')
  const [editingDepartment, setEditingDepartment] = useState<DepartmentRow | null>(null)
  const [departmentForm, setDepartmentForm] = useState<DepartmentFormFields>(EMPTY_DEPARTMENT_FORM)
  const [formBaseline, setFormBaseline] = useState<DepartmentFormFields | null>(null)
  const [fieldErrors, setFieldErrors] = useState<Partial<Record<DepartmentFieldKey, string>>>({})
  const [lifecycleFilter, setLifecycleFilter] = useState<OrgEntityLifecycleFilter>('active')

  const { data: departmentsResult, isLoading } = useQuery({
    queryKey: ['departments-overview', user?.id],
    queryFn: () => fetchDepartmentsOverviewWithMeta(user!.id),
    enabled: Boolean(user?.id),
  })

  const data = departmentsResult?.data

  const saveMutation = useMutation({
    mutationFn: async (form: DepartmentFormFields) => {
      const validation = validateDepartmentForm(form)
      if (!validation.isValid) {
        setFieldErrors(validation.fieldErrors)
        throw new Error('validation')
      }

      const input = {
        name: validation.normalized.name,
        code: validation.normalized.code,
      }

      if (sheetMode === 'edit' && editingDepartment) {
        await updateDepartment(user!.id, editingDepartment.id, input)
        return
      }

      await createDepartment(user!.id, input)
    },
    onSuccess: () => {
      const wasEdit = sheetMode === 'edit'
      if (user?.id) invalidateOrgStructureQueries(queryClient, user.id)
      resetSheet()
      toast.success(t(wasEdit ? 'orgSetupCrud.department.updated' : 'orgSetupCrud.department.created'))
    },
    onError: (error) => {
      if (error instanceof Error && error.message === 'validation') return
      const mapped = mapDepartmentMutationError(error)
      setFieldErrors((current) => ({ ...current, ...mapped.fieldErrors }))
      if (mapped.toastKey) toast.error(t(mapped.toastKey))
    },
  })

  const departments = data?.departments ?? []
  const filteredDepartments = applyOrgEntityLifecycleFilter(departments, lifecycleFilter)
  const isEmpty = !isLoading && departments.length === 0
  const isFilterEmpty = !isLoading && departments.length > 0 && filteredDepartments.length === 0
  const isReadOnly = sheetMode === 'readonly'
  const isDirty = formBaseline ? isDepartmentFormDirty(departmentForm, formBaseline) : false

  const lifecycleMutation = useMutation({
    mutationFn: ({
      department,
      action,
    }: {
      department: DepartmentRow
      action: 'deactivate' | 'restore'
    }) => {
      if (!user?.id) throw new Error('Missing user context')
      return action === 'deactivate'
        ? deactivateDepartment(user.id, department.id)
        : restoreDepartment(user.id, department.id)
    },
    onSuccess: (_result, variables) => {
      if (user?.id) invalidateOrgStructureQueries(queryClient, user.id)
      resetSheet()
      toast.success(
        t(
          variables.action === 'deactivate'
            ? 'orgSetupCrud.department.deactivated'
            : 'orgSetupCrud.department.restored',
        ),
      )
    },
    onError: (error) => {
      const mapped = mapDepartmentLifecycleError(error)
      toast.error(t(mapped.toastKey))
    },
  })

  function resetSheet() {
    setSheetOpen(false)
    setSheetMode('create')
    setEditingDepartment(null)
    setDepartmentForm(EMPTY_DEPARTMENT_FORM)
    setFormBaseline(null)
    setFieldErrors({})
  }

  function openCreateSheet() {
    setSheetMode('create')
    setEditingDepartment(null)
    setDepartmentForm(EMPTY_DEPARTMENT_FORM)
    setFormBaseline(EMPTY_DEPARTMENT_FORM)
    setFieldErrors({})
    setSheetOpen(true)
  }

  function openDepartmentSheet(department: DepartmentRow) {
    const form = departmentToForm(department)
    setEditingDepartment(department)
    setDepartmentForm(form)
    setFormBaseline(form)
    setFieldErrors({})
    setSheetMode(department.isEditable ? 'edit' : 'readonly')
    setSheetOpen(true)
  }

  function handleSheetOpenChange(nextOpen: boolean) {
    if (!nextOpen && isDirty && !window.confirm(t('orgSetupCrud.discardConfirm'))) {
      return
    }
    if (!nextOpen) resetSheet()
    else setSheetOpen(true)
  }

  function handleSubmit(event: FormEvent) {
    event.preventDefault()
    if (isReadOnly) return
    saveMutation.mutate(departmentForm)
  }

  function handleDepartmentLifecycleAction() {
    if (!editingDepartment || isReadOnly || isDirty) return
    const action = editingDepartment.isActive ? 'deactivate' : 'restore'
    const confirmKey =
      action === 'deactivate'
        ? 'orgSetupCrud.lifecycle.confirm.deactivateDepartment'
        : 'orgSetupCrud.lifecycle.confirm.restoreDepartment'
    if (!window.confirm(t(confirmKey))) return
    lifecycleMutation.mutate({ department: editingDepartment, action })
  }

  function translateFieldError(field: DepartmentFieldKey): string | undefined {
    const key = fieldErrors[field]
    return key ? t(key) : undefined
  }

  const sheetTitle =
    sheetMode === 'create'
      ? t('orgSetupCrud.department.createTitle')
      : sheetMode === 'edit'
        ? t('orgSetupCrud.department.editTitle')
        : t('orgSetupCrud.department.readOnlyTitle')

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <p className="text-xs font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
        {t('departments.eyebrow')}
      </p>
      <div className="mt-1 flex flex-wrap items-start justify-between gap-3">
        <PageHeader title={t('departments.title')} subtitle={t('departments.description')} />
        <Button type="button" onClick={openCreateSheet}>
          <Plus className="mr-2 h-4 w-4" aria-hidden />
          {t('orgSetupCrud.actions.createDepartment')}
        </Button>
      </div>

      <DemoSourcePill
        visible={departmentsResult?.source === 'demo'}
        fallbackReason={departmentsResult?.fallbackReason}
      />

      {isLoading ? (
        <div className="-mx-4 mb-6 mt-5 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:grid-cols-2 md:overflow-visible md:px-0 lg:grid-cols-4">
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
        </div>
      ) : data ? (
        <div className="-mx-4 mb-6 mt-5 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:grid-cols-2 md:overflow-visible md:px-0 lg:grid-cols-4">
          <MetricCard compact label={t('departments.metrics.departments')} value={String(data.departmentCount)} icon={Building2} />
          <MetricCard compact label={t('departments.metrics.activeEmployees')} value={String(data.activeEmployees)} icon={Users} />
          <MetricCard
            compact
            label={t('departments.metrics.assignedManagers')}
            value={String(data.assignedManagers)}
            hint={t('departments.metrics.assignedManagersHint')}
            icon={UserCheck}
          />
          <MetricCard
            compact
            label={t('departments.metrics.emptyManagers')}
            value={String(data.emptyManagers)}
            hint={t('departments.metrics.emptyManagersHint')}
            icon={UserMinus}
          />
        </div>
      ) : null}

      <section>
        <SectionHeader title={t('departments.sections.list')} />
        <div className="mt-3 max-w-md">
          <Segmented
            ariaLabel={t('orgSetupCrud.lifecycle.filter.ariaLabel')}
            value={lifecycleFilter}
            onChange={setLifecycleFilter}
            options={[
              { value: 'active', label: t('orgSetupCrud.lifecycle.filter.active') },
              { value: 'inactive', label: t('orgSetupCrud.lifecycle.filter.inactive') },
              { value: 'all', label: t('orgSetupCrud.lifecycle.filter.all') },
            ]}
          />
        </div>
        {isEmpty ? (
          <EmptyState
            className="mt-3"
            icon={Building2}
            title={t('orgSetupReadiness.empty.departmentsTitle')}
            description={t('orgSetupReadiness.empty.departments')}
          />
        ) : isFilterEmpty ? (
          <EmptyState
            className="mt-3"
            icon={Building2}
            title={t('orgSetupCrud.lifecycle.emptyFilterTitle')}
            description={t('orgSetupCrud.lifecycle.emptyFilterDescription')}
          />
        ) : (
          <>
            <div className="mt-3 md:hidden">
              {isLoading ? (
                <div className="space-y-2">
                  {Array.from({ length: DEPARTMENT_SKELETON_COUNT }, (_, index) => (
                    <Skeleton key={index} className="h-16 w-full rounded-xl" />
                  ))}
                </div>
              ) : (
                <DataList
                  items={filteredDepartments.map((department) => ({
                    id: department.id,
                    title: department.name,
                    subtitle: [
                      department.code ?? '—',
                      department.manager,
                      t('departments.employeeCount', { count: department.count }),
                    ].join(' · '),
                    onClick: () => openDepartmentSheet(department),
                    trailing: (
                      <div className="flex flex-col items-end gap-1">
                        {!department.isEditable ? <Lock className="h-3.5 w-3.5 text-[var(--color-text-muted)]" aria-hidden /> : null}
                        <ActiveStatusPill isActive={department.isActive} />
                        <OrgEntitySourcePill source={department.source} />
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
                  DEPARTMENT_TABLE_GRID_COLS,
                )}
              >
                <div>{t('departments.columns.name')}</div>
                <div>{t('departments.columns.code')}</div>
                <div>{t('departments.columns.manager')}</div>
                <div className="text-right">{t('departments.columns.count')}</div>
                <div className="text-right">{t('departments.columns.status')}</div>
              </div>
              <ul className="divide-y divide-[var(--color-border)]">
                {isLoading
                  ? Array.from({ length: DEPARTMENT_SKELETON_COUNT }, (_, index) => (
                      <li key={index} className={cn('grid items-center gap-3 px-4 py-3', DEPARTMENT_TABLE_GRID_COLS)}>
                        <Skeleton className="h-4 w-32" />
                        <Skeleton className="h-4 w-16" />
                        <Skeleton className="h-4 w-28" />
                        <Skeleton className="ml-auto h-4 w-8" />
                        <Skeleton className="ml-auto h-7 w-24 rounded-full" />
                      </li>
                    ))
                  : filteredDepartments.map((department) => (
                      <li key={department.id}>
                        <button
                          type="button"
                          onClick={() => openDepartmentSheet(department)}
                          className={cn(
                            'grid w-full items-center gap-3 px-4 py-3 text-left transition hover:bg-[var(--color-bg-surface)]',
                            DEPARTMENT_TABLE_GRID_COLS,
                            !department.isActive && 'opacity-70',
                            !department.isEditable && 'cursor-default',
                          )}
                        >
                          <div className="flex items-center gap-2 text-sm font-medium">
                            {!department.isEditable ? <Lock className="h-3.5 w-3.5 shrink-0 text-[var(--color-text-muted)]" aria-hidden /> : null}
                            {department.name}
                          </div>
                          <div className="font-mono text-xs text-[var(--color-text-secondary)]">{department.code ?? '—'}</div>
                          <div className="text-sm text-[var(--color-text-secondary)]">{department.manager}</div>
                          <div className="text-right text-sm tabular-nums">{department.count}</div>
                          <div className="flex justify-end gap-1">
                            <ActiveStatusPill isActive={department.isActive} />
                            <OrgEntitySourcePill source={department.source} />
                          </div>
                        </button>
                      </li>
                    ))}
              </ul>
            </div>
          </>
        )}
      </section>

      <SheetShell open={sheetOpen} onOpenChange={handleSheetOpenChange} title={sheetTitle}>
        <form className="space-y-4" onSubmit={handleSubmit}>
          {isReadOnly ? (
            <p className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-3 py-2 text-sm text-[var(--color-text-secondary)]">
              {t('orgSetupCrud.boundary.sourceReadOnly')}
            </p>
          ) : null}

          <FormField label={t('orgSetupCrud.fields.name')} error={translateFieldError('name')}>
            <Input
              value={departmentForm.name}
              readOnly={isReadOnly}
              onChange={(event) => setDepartmentForm((current) => ({ ...current, name: event.target.value }))}
            />
          </FormField>

          <FormField
            label={t('orgSetupCrud.fields.code')}
            hint={t('orgSetupCrud.fields.codeHint')}
            error={translateFieldError('code')}
          >
            <Input
              value={departmentForm.code}
              readOnly={isReadOnly}
              onChange={(event) => setDepartmentForm((current) => ({ ...current, code: event.target.value }))}
            />
            {!isReadOnly && departmentForm.code.trim() ? (
              <p className="mt-1 font-mono text-xs text-[var(--color-text-muted)]">
                {normalizeOrgSetupCode(departmentForm.code)}
              </p>
            ) : null}
          </FormField>

          {editingDepartment ? (
            <div className="flex items-center gap-2">
              <OrgEntitySourcePill source={editingDepartment.source} />
              <ActiveStatusPill isActive={editingDepartment.isActive} />
            </div>
          ) : null}

          {editingDepartment && !isReadOnly ? (
            <div className="flex justify-start border-t border-[var(--color-border)] pt-4">
              <Button
                type="button"
                variant={editingDepartment.isActive ? 'outline' : 'default'}
                disabled={isDirty || saveMutation.isPending || lifecycleMutation.isPending}
                onClick={handleDepartmentLifecycleAction}
              >
                {lifecycleMutation.isPending ? (
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" aria-hidden />
                ) : editingDepartment.isActive ? (
                  <Power className="mr-2 h-4 w-4" aria-hidden />
                ) : (
                  <RotateCcw className="mr-2 h-4 w-4" aria-hidden />
                )}
                {t(
                  editingDepartment.isActive
                    ? 'orgSetupCrud.lifecycle.actions.deactivate'
                    : 'orgSetupCrud.lifecycle.actions.restore',
                )}
              </Button>
            </div>
          ) : null}

          {!isReadOnly ? (
            <div className="flex justify-end gap-2 pt-2">
              <Button type="button" variant="outline" onClick={() => handleSheetOpenChange(false)}>
                {t('orgSetupCrud.actions.cancel')}
              </Button>
              <Button type="submit" disabled={saveMutation.isPending}>
                {saveMutation.isPending ? <Loader2 className="mr-2 h-4 w-4 animate-spin" aria-hidden /> : <Save className="mr-2 h-4 w-4" aria-hidden />}
                {t('orgSetupCrud.actions.save')}
              </Button>
            </div>
          ) : null}
        </form>
      </SheetShell>
    </div>
  )
}
