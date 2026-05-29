import { createFileRoute } from '@tanstack/react-router'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Briefcase, ClipboardList, Loader2, Lock, Plus, Save } from 'lucide-react'
import { useMemo, useState, type FormEvent } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { SetupRouteGuard } from '#/components/auth/SetupRouteGuard'
import { DataList } from '#/components/puls/DataList'
import { EmptyState } from '#/components/puls/EmptyState'
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
  createPosition,
  fetchDepartmentsOverview,
  fetchPositionsOverview,
  isPositionFormDirty,
  mapPositionMutationError,
  normalizeOrgSetupCode,
  updatePosition,
  validatePositionForm,
  type OrgSetupEntitySource,
  type PositionFieldKey,
  type PositionFormFields,
  type PositionsOverview,
} from '#/lib/data'
import { cn } from '#/lib/utils'

export const Route = createFileRoute('/_app/pozisyonlar')({
  head: () => ({
    meta: [
      { title: i18n.t('positions.meta.title') },
      {
        name: 'description',
        content: i18n.t('positions.meta.description'),
      },
    ],
  }),
  component: PozisyonlarRoute,
})

function PozisyonlarRoute() {
  return (
    <SetupRouteGuard>
      <PozisyonlarPage />
    </SetupRouteGuard>
  )
}

const POSITION_SKELETON_COUNT = 3
const POSITION_TABLE_GRID_COLS =
  'grid-cols-[minmax(0,1.2fr)_88px_minmax(0,1fr)_72px_120px]'

type PositionRow = PositionsOverview['positions'][number]
type SheetMode = 'create' | 'edit' | 'readonly'

const EMPTY_POSITION_FORM: PositionFormFields = {
  name: '',
  code: '',
  departmentId: null,
  normHeadcount: '1',
}

function positionToForm(position: PositionRow): PositionFormFields {
  return {
    name: position.name,
    code: position.code ?? '',
    departmentId: position.departmentId ?? null,
    normHeadcount: String(position.normHeadcount ?? 1),
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
      {t(isActive ? 'positions.status.active' : 'positions.status.inactive')}
    </StatusPill>
  )
}

function PozisyonlarPage() {
  const { t } = useTranslation()
  const { user } = useAuth()
  const queryClient = useQueryClient()

  const [sheetOpen, setSheetOpen] = useState(false)
  const [sheetMode, setSheetMode] = useState<SheetMode>('create')
  const [editingPosition, setEditingPosition] = useState<PositionRow | null>(null)
  const [positionForm, setPositionForm] = useState<PositionFormFields>(EMPTY_POSITION_FORM)
  const [formBaseline, setFormBaseline] = useState<PositionFormFields | null>(null)
  const [fieldErrors, setFieldErrors] = useState<Partial<Record<PositionFieldKey, string>>>({})

  const { data, isLoading } = useQuery({
    queryKey: ['positions-overview', user?.id],
    queryFn: () => fetchPositionsOverview(user!.id),
    enabled: Boolean(user?.id),
  })

  const { data: departmentsOverview } = useQuery({
    queryKey: ['departments-overview', user?.id],
    queryFn: () => fetchDepartmentsOverview(user!.id),
    enabled: Boolean(user?.id),
  })

  const departmentOptions = useMemo(() => {
    const departments = departmentsOverview?.departments ?? []
    const active = departments.filter((department) => department.isActive)
    const allowedIds = new Set(departments.map((department) => department.id))

    const options = active.map((department) => ({
      value: department.id,
      label: department.name,
      disabled: false,
    }))

    const currentDepartmentId = editingPosition?.departmentId ?? null
    if (
      currentDepartmentId &&
      allowedIds.has(currentDepartmentId) &&
      !active.some((department) => department.id === currentDepartmentId)
    ) {
      const inactive = departments.find((department) => department.id === currentDepartmentId)
      if (inactive) {
        options.unshift({
          value: inactive.id,
          label: `${inactive.name} (${t('positions.status.inactive')})`,
          disabled: true,
        })
      }
    }

    return { options, allowedIds }
  }, [departmentsOverview, editingPosition, t])

  const saveMutation = useMutation({
    mutationFn: async (form: PositionFormFields) => {
      const validation = validatePositionForm(form, {
        allowedDepartmentIds: departmentOptions.allowedIds,
      })
      if (!validation.isValid) {
        setFieldErrors(validation.fieldErrors)
        throw new Error('validation')
      }

      const input = {
        name: validation.normalized.name,
        code: validation.normalized.code,
        departmentId: validation.normalized.departmentId,
        normHeadcount: validation.normalized.normHeadcount,
      }

      if (sheetMode === 'edit' && editingPosition) {
        await updatePosition(user!.id, editingPosition.id, input)
        return
      }

      await createPosition(user!.id, input)
    },
    onSuccess: () => {
      const wasEdit = sheetMode === 'edit'
      void queryClient.invalidateQueries({ queryKey: ['positions-overview', user?.id] })
      void queryClient.invalidateQueries({ queryKey: ['setup-readiness-dashboard', user?.id] })
      resetSheet()
      toast.success(t(wasEdit ? 'orgSetupCrud.position.updated' : 'orgSetupCrud.position.created'))
    },
    onError: (error) => {
      if (error instanceof Error && error.message === 'validation') return
      const mapped = mapPositionMutationError(error)
      setFieldErrors((current) => ({ ...current, ...mapped.fieldErrors }))
      if (mapped.toastKey) toast.error(t(mapped.toastKey))
    },
  })

  const positions = data?.positions ?? []
  const isEmpty = !isLoading && positions.length === 0
  const isReadOnly = sheetMode === 'readonly'
  const isDirty = formBaseline ? isPositionFormDirty(positionForm, formBaseline) : false
  const showTemplateMetrics = data?.showsTemplateMetrics ?? false

  function resetSheet() {
    setSheetOpen(false)
    setSheetMode('create')
    setEditingPosition(null)
    setPositionForm(EMPTY_POSITION_FORM)
    setFormBaseline(null)
    setFieldErrors({})
  }

  function openCreateSheet() {
    setSheetMode('create')
    setEditingPosition(null)
    setPositionForm(EMPTY_POSITION_FORM)
    setFormBaseline(EMPTY_POSITION_FORM)
    setFieldErrors({})
    setSheetOpen(true)
  }

  function openPositionSheet(position: PositionRow) {
    const form = positionToForm(position)
    setEditingPosition(position)
    setPositionForm(form)
    setFormBaseline(form)
    setFieldErrors({})
    setSheetMode(position.isEditable ? 'edit' : 'readonly')
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
    saveMutation.mutate(positionForm)
  }

  function translateFieldError(field: PositionFieldKey): string | undefined {
    const key = fieldErrors[field]
    return key ? t(key) : undefined
  }

  const sheetTitle =
    sheetMode === 'create'
      ? t('orgSetupCrud.position.createTitle')
      : sheetMode === 'edit'
        ? t('orgSetupCrud.position.editTitle')
        : t('orgSetupCrud.position.readOnlyTitle')

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <p className="text-xs font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
        {t('positions.eyebrow')}
      </p>
      <div className="mt-1 flex flex-wrap items-start justify-between gap-3">
        <PageHeader className="mt-0" title={t('positions.title')} subtitle={t('positions.description')} />
        <Button type="button" onClick={openCreateSheet}>
          <Plus className="mr-2 h-4 w-4" aria-hidden />
          {t('orgSetupCrud.actions.createPosition')}
        </Button>
      </div>

      {isLoading ? (
        <div className="-mx-4 mb-6 mt-5 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:grid-cols-2 md:overflow-visible md:px-0 lg:grid-cols-4">
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
          <Skeleton className="h-28 min-w-[140px] rounded-xl" />
        </div>
      ) : data ? (
        <div
          className={cn(
            '-mx-4 mb-6 mt-5 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:overflow-visible md:px-0',
            showTemplateMetrics ? 'md:grid-cols-2 lg:grid-cols-4' : 'md:grid-cols-2',
          )}
        >
          <MetricCard compact label={t('positions.metrics.positions')} value={String(data.positionCount)} icon={Briefcase} />
          <MetricCard compact label={t('positions.metrics.openPositions')} value={String(data.openPositions)} icon={ClipboardList} />
        </div>
      ) : null}

      <section>
        <SectionHeader title={t('positions.sections.list')} />
        {isEmpty ? (
          <EmptyState
            className="mt-3"
            icon={Briefcase}
            title={t('orgSetupReadiness.empty.positionsTitle')}
            description={t('orgSetupReadiness.empty.positions')}
          />
        ) : (
          <>
            <div className="mt-3 md:hidden">
              {isLoading ? (
                <div className="space-y-2">
                  {Array.from({ length: POSITION_SKELETON_COUNT }, (_, index) => (
                    <Skeleton key={index} className="h-16 w-full rounded-xl" />
                  ))}
                </div>
              ) : (
                <DataList
                  items={positions.map((position) => ({
                    id: position.id,
                    title: position.name,
                    subtitle: [position.code ?? '—', position.department].join(' · '),
                    meta: position.open > 0 ? t('positions.openCount', { count: position.open }) : undefined,
                    onClick: () => openPositionSheet(position),
                    trailing: (
                      <div className="flex flex-col items-end gap-1">
                        {!position.isEditable ? <Lock className="h-3.5 w-3.5 text-[var(--color-text-muted)]" aria-hidden /> : null}
                        <ActiveStatusPill isActive={position.isActive} />
                        <OrgEntitySourcePill source={position.source} />
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
                  POSITION_TABLE_GRID_COLS,
                )}
              >
                <div>{t('positions.columns.name')}</div>
                <div>{t('positions.columns.code')}</div>
                <div>{t('positions.columns.department')}</div>
                <div className="text-right">{t('positions.columns.open')}</div>
                <div className="text-right">{t('positions.columns.status')}</div>
              </div>
              <ul className="divide-y divide-[var(--color-border)]">
                {isLoading
                  ? Array.from({ length: POSITION_SKELETON_COUNT }, (_, index) => (
                      <li key={index} className={cn('grid items-center gap-3 px-4 py-3', POSITION_TABLE_GRID_COLS)}>
                        <Skeleton className="h-4 w-32" />
                        <Skeleton className="h-4 w-16" />
                        <Skeleton className="h-4 w-28" />
                        <Skeleton className="ml-auto h-4 w-8" />
                        <Skeleton className="ml-auto h-7 w-24 rounded-full" />
                      </li>
                    ))
                  : positions.map((position) => (
                      <li key={position.id}>
                        <button
                          type="button"
                          onClick={() => openPositionSheet(position)}
                          className={cn(
                            'grid w-full items-center gap-3 px-4 py-3 text-left transition hover:bg-[var(--color-bg-surface)]',
                            POSITION_TABLE_GRID_COLS,
                            !position.isActive && 'opacity-70',
                          )}
                        >
                          <div className="flex items-center gap-2 truncate text-sm font-medium">
                            {!position.isEditable ? <Lock className="h-3.5 w-3.5 shrink-0 text-[var(--color-text-muted)]" aria-hidden /> : null}
                            {position.name}
                          </div>
                          <div className="font-mono text-xs text-[var(--color-text-secondary)]">{position.code ?? '—'}</div>
                          <div className="truncate text-sm text-[var(--color-text-secondary)]">{position.department}</div>
                          <div className="text-right text-sm tabular-nums">{position.open}</div>
                          <div className="flex justify-end gap-1">
                            <ActiveStatusPill isActive={position.isActive} />
                            <OrgEntitySourcePill source={position.source} />
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
              value={positionForm.name}
              readOnly={isReadOnly}
              onChange={(event) => setPositionForm((current) => ({ ...current, name: event.target.value }))}
            />
          </FormField>

          <FormField
            label={t('orgSetupCrud.fields.code')}
            hint={t('orgSetupCrud.fields.codeHint')}
            error={translateFieldError('code')}
          >
            <Input
              value={positionForm.code}
              readOnly={isReadOnly}
              onChange={(event) => setPositionForm((current) => ({ ...current, code: event.target.value }))}
            />
            {!isReadOnly && positionForm.code.trim() ? (
              <p className="mt-1 font-mono text-xs text-[var(--color-text-muted)]">
                {normalizeOrgSetupCode(positionForm.code)}
              </p>
            ) : null}
          </FormField>

          <FormField label={t('orgSetupCrud.fields.department')} error={translateFieldError('departmentId')}>
            <select
              className="flex h-10 w-full rounded-md border border-[var(--color-border)] bg-[var(--color-bg-card)] px-3 text-sm"
              value={positionForm.departmentId ?? ''}
              disabled={isReadOnly}
              onChange={(event) =>
                setPositionForm((current) => ({
                  ...current,
                  departmentId: event.target.value ? event.target.value : null,
                }))
              }
            >
              <option value="">{t('orgSetupCrud.fields.departmentUnassigned')}</option>
              {departmentOptions.options.map((option) => (
                <option key={option.value} value={option.value} disabled={option.disabled}>
                  {option.label}
                </option>
              ))}
            </select>
          </FormField>

          <FormField label={t('orgSetupCrud.fields.normHeadcount')} error={translateFieldError('normHeadcount')}>
            <Input
              type="number"
              min={0}
              max={100000}
              value={positionForm.normHeadcount}
              readOnly={isReadOnly}
              onChange={(event) =>
                setPositionForm((current) => ({ ...current, normHeadcount: event.target.value }))
              }
            />
          </FormField>

          {editingPosition ? (
            <div className="flex items-center gap-2">
              <OrgEntitySourcePill source={editingPosition.source} />
              <ActiveStatusPill isActive={editingPosition.isActive} />
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
