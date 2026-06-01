import { Link, createFileRoute } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import {
  AlertCircle,
  Briefcase,
  Building2,
  Mail,
  Search,
  UserCheck,
  Users,
  Wallet,
} from 'lucide-react'
import type { LucideIcon } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { EmptyState } from '#/components/puls/EmptyState'
import { MetricCard } from '#/components/puls/MetricCard'
import { SectionHeader } from '#/components/puls/SectionHeader'
import { Segmented } from '#/components/puls/Segmented'
import { SheetShell } from '#/components/puls/SheetShell'
import { StatusPill, type StatusTone } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { Input } from '#/components/ui/input'
import { Progress } from '#/components/ui/progress'
import { Skeleton } from '#/components/ui/skeleton'
import i18n from '#/i18n'
import { useAuth } from '#/lib/auth'
import {
  applyEmployeeAssignmentReadinessFilter,
  fetchEmployeeAssignmentReadiness,
  fetchEmployeesOverview,
  type EmployeeAssignmentEntityRef,
  type EmployeeAssignmentManagerRef,
  type EmployeeAssignmentReadinessEmployee,
  type EmployeeAssignmentReadinessFilter,
  type EmployeeAssignmentReadinessStatus,
} from '#/lib/data'
import { cn } from '#/lib/utils'

export const Route = createFileRoute('/_app/calisanlar')({
  head: () => ({
    meta: [
      { title: i18n.t('employees.title') + ' — PULS' },
      {
        name: 'description',
        content: i18n.t('employees.subtitle'),
      },
    ],
  }),
  component: CalisanlarPage,
})

const EMPLOYEE_TABLE_GRID_COLS =
  'xl:grid-cols-[minmax(0,1.3fr)_minmax(0,0.85fr)_minmax(0,0.85fr)_minmax(0,0.85fr)_minmax(0,0.85fr)_120px]'

type FilterOption = string | { value: string; label: string }

function getInitials(fullName: string): string {
  return (fullName || '?')
    .split(' ')
    .filter(Boolean)
    .map((part) => part[0])
    .join('')
    .slice(0, 2)
    .toUpperCase()
}

function readinessPillTone(status: EmployeeAssignmentReadinessStatus): StatusTone {
  switch (status) {
    case 'ready':
      return 'success'
    case 'inactive_reference':
    case 'missing_department':
    case 'missing_position':
    case 'missing_cost_center':
    case 'missing_manager':
      return 'warning'
    case 'partial':
      return 'neutral'
    default:
      return 'neutral'
  }
}

function entityLabel(ref: EmployeeAssignmentEntityRef | null, missingKey: string, t: (key: string) => string) {
  if (!ref) {
    return (
      <StatusPill tone="neutral" className="max-w-full truncate">
        {t(missingKey)}
      </StatusPill>
    )
  }
  if (!ref.isActive) {
    return (
      <StatusPill tone="warning" className="max-w-full truncate">
        {ref.name}
      </StatusPill>
    )
  }
  return <span className="truncate text-sm">{ref.name}</span>
}

function managerLabel(
  ref: EmployeeAssignmentManagerRef | null,
  t: (key: string) => string,
) {
  if (!ref) {
    return (
      <StatusPill tone="neutral" className="max-w-full truncate">
        {t('employeeAssignmentReadiness.labels.managerMissing')}
      </StatusPill>
    )
  }
  if (!ref.isActive) {
    return (
      <StatusPill tone="warning" className="max-w-full truncate">
        {ref.displayName}
      </StatusPill>
    )
  }
  return <span className="truncate text-sm">{ref.displayName}</span>
}

function FilterSelect({
  label,
  value,
  onChange,
  options,
  allLabel,
}: {
  label: string
  value: string
  onChange: (value: string) => void
  options: FilterOption[]
  allLabel: string
}) {
  return (
    <label className="block min-w-0">
      <span className="sr-only">{label}</span>
      <select
        aria-label={label}
        value={value}
        onChange={(event) => onChange(event.target.value)}
        className="h-11 w-full min-w-0 rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-card)] px-3 text-base text-[var(--color-text-primary)] outline-none focus:border-[var(--color-primary)]"
      >
        <option value="">{allLabel}</option>
        {options.map((option) => {
          const optionValue = typeof option === 'string' ? option : option.value
          const optionLabel = typeof option === 'string' ? option : option.label
          return (
            <option key={optionValue} value={optionValue}>
              {optionLabel}
            </option>
          )
        })}
      </select>
    </label>
  )
}

function DetailRow({
  icon: Icon,
  label,
  value,
}: {
  icon: LucideIcon
  label: string
  value: string
}) {
  return (
    <div className="flex items-start gap-3">
      <span className="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-md bg-[var(--color-bg-elevated)] text-[var(--color-text-muted)]">
        <Icon className="h-4 w-4" aria-hidden />
      </span>
      <div className="min-w-0 flex-1">
        <div className="text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
          {label}
        </div>
        <div className="break-words text-sm text-[var(--color-text-primary)]">{value}</div>
      </div>
    </div>
  )
}

function assignmentDetailValue(
  ref: EmployeeAssignmentEntityRef | EmployeeAssignmentManagerRef | null,
  missingLabel: string,
  nameKey: 'name' | 'displayName' = 'name',
): string {
  if (!ref) return missingLabel
  const label = nameKey === 'displayName' ? (ref as EmployeeAssignmentManagerRef).displayName : (ref as EmployeeAssignmentEntityRef).name
  if (!ref.isActive) return `${label} (${missingLabel})`
  return label
}

function CalisanlarPage() {
  const { t } = useTranslation()
  const { user, activePersona } = useAuth()

  const [readinessFilter, setReadinessFilter] = useState<EmployeeAssignmentReadinessFilter>('all')
  const [departmentFilter, setDepartmentFilter] = useState('')
  const [positionFilter, setPositionFilter] = useState('')
  const [searchQuery, setSearchQuery] = useState('')
  const [selectedEmployeeId, setSelectedEmployeeId] = useState<string | null>(null)

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: ['employee-assignment-readiness', user?.id],
    queryFn: () => fetchEmployeeAssignmentReadiness(user!.id),
    enabled: Boolean(user?.id) && activePersona === 'manager',
  })

  const { data: leaveOverview } = useQuery({
    queryKey: ['employees-overview-leave', user?.id],
    queryFn: () => fetchEmployeesOverview(user!.id),
    enabled: Boolean(user?.id) && activePersona === 'manager',
  })

  const employees = useMemo(() => data?.employees ?? [], [data?.employees])
  const summary = data?.summary

  const readinessFiltered = useMemo(
    () => applyEmployeeAssignmentReadinessFilter(employees, readinessFilter),
    [employees, readinessFilter],
  )

  const departmentOptions = useMemo(
    () =>
      [
        ...new Set(
          employees.map((employee) => employee.department?.name).filter(Boolean) as string[],
        ),
      ].sort(),
    [employees],
  )

  const positionOptions = useMemo(
    () =>
      [
        ...new Set(
          employees.map((employee) => employee.position?.name).filter(Boolean) as string[],
        ),
      ].sort(),
    [employees],
  )

  const filteredEmployees = useMemo(() => {
    const query = searchQuery.trim().toLowerCase()
    return readinessFiltered.filter((employee) => {
      if (departmentFilter && employee.department?.name !== departmentFilter) return false
      if (positionFilter && employee.position?.name !== positionFilter) return false
      if (query) {
        const haystack =
          `${employee.displayName} ${employee.email ?? ''} ${employee.employeeNumber ?? ''}`.toLowerCase()
        if (!haystack.includes(query)) return false
      }
      return true
    })
  }, [readinessFiltered, departmentFilter, positionFilter, searchQuery])

  const selectedEmployee = useMemo(
    () => employees.find((employee) => employee.id === selectedEmployeeId) ?? null,
    [employees, selectedEmployeeId],
  )

  const selectedLeave = useMemo(() => {
    if (!selectedEmployee?.email || !leaveOverview) return null
    return leaveOverview.byEmail[selectedEmployee.email.toLowerCase()] ?? null
  }, [selectedEmployee, leaveOverview])

  const resetFilters = () => {
    setReadinessFilter('all')
    setDepartmentFilter('')
    setPositionFilter('')
    setSearchQuery('')
  }

  if (activePersona !== 'manager') {
    return (
      <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
        <EmptyState
          icon={Users}
          title={t('employees.restricted.title')}
          description={t('employees.restricted.description')}
          action={
            <Link to="/dashboard" className="text-sm font-semibold text-[var(--color-primary)]">
              {t('employees.restricted.back')}
            </Link>
          }
        />
      </div>
    )
  }

  return (
    <div className="mx-auto max-w-6xl overflow-x-hidden p-4 md:p-8">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="text-xs font-medium uppercase tracking-wide text-[var(--color-text-muted)]">
            {t('employeesSetup.eyebrow')}
          </p>
          <h1 className="mt-1 text-[26px] font-semibold tracking-tight text-[var(--color-text-primary)] sm:text-3xl">
            {t('employees.title')}
          </h1>
          <p className="mt-1 text-sm text-[var(--color-text-muted)]">
            {t('employeeAssignmentReadiness.boundary.readOnly')}
          </p>
        </div>
        <StatusPill tone="info">{t('employees.managerOnly')}</StatusPill>
        {data?.source === 'demo' ? (
          <StatusPill tone="neutral">{t('orgSetupReadiness.source.demo')}</StatusPill>
        ) : null}
      </div>

      {isLoading ? (
        <div className="-mx-4 mb-6 mt-5 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:grid-cols-3 md:overflow-visible md:px-0 lg:grid-cols-6">
          {Array.from({ length: 6 }, (_, index) => (
            <Skeleton key={index} className="h-28 min-w-[140px] rounded-xl" />
          ))}
        </div>
      ) : summary ? (
        <div className="-mx-4 mb-6 mt-5 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:grid-cols-3 md:overflow-visible md:px-0 lg:grid-cols-6">
          <MetricCard
            compact
            label={t('employeeAssignmentReadiness.metrics.activeEmployees')}
            value={String(summary.active)}
            icon={Users}
          />
          <MetricCard
            compact
            label={t('employeeAssignmentReadiness.metrics.readyAssignments')}
            value={String(summary.ready)}
            icon={UserCheck}
          />
          <MetricCard
            compact
            label={t('employeeAssignmentReadiness.metrics.missingDepartment')}
            value={String(summary.missingDepartment)}
            icon={Building2}
          />
          <MetricCard
            compact
            label={t('employeeAssignmentReadiness.metrics.missingPosition')}
            value={String(summary.missingPosition)}
            icon={Briefcase}
          />
          <MetricCard
            compact
            label={t('employeeAssignmentReadiness.metrics.missingCostCenter')}
            value={String(summary.missingCostCenter)}
            icon={Wallet}
          />
          <MetricCard
            compact
            label={t('employeeAssignmentReadiness.metrics.missingManager')}
            value={String(summary.missingManager)}
            icon={AlertCircle}
          />
        </div>
      ) : null}

      <div className="mt-3 max-w-3xl">
        <Segmented
          ariaLabel={t('employeeAssignmentReadiness.filters.ariaLabel')}
          value={readinessFilter}
          onChange={(value) => setReadinessFilter(value as EmployeeAssignmentReadinessFilter)}
          options={[
            { value: 'all', label: t('employeeAssignmentReadiness.filters.all') },
            { value: 'ready', label: t('employeeAssignmentReadiness.filters.ready') },
            {
              value: 'missing_department',
              label: t('employeeAssignmentReadiness.filters.missingDepartment'),
            },
            {
              value: 'missing_position',
              label: t('employeeAssignmentReadiness.filters.missingPosition'),
            },
            {
              value: 'missing_cost_center',
              label: t('employeeAssignmentReadiness.filters.missingCostCenter'),
            },
            {
              value: 'missing_manager',
              label: t('employeeAssignmentReadiness.filters.missingManager'),
            },
          ]}
        />
      </div>

      <div className="mt-4 rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-3">
        <div className="grid grid-cols-1 gap-2 sm:grid-cols-2 lg:grid-cols-[minmax(0,1fr)_minmax(0,160px)_minmax(0,160px)]">
          <div className="relative min-w-0">
            <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--color-text-muted)]" />
            <label className="sr-only" htmlFor="employee-search">
              {t('employeesSetup.searchLabel')}
            </label>
            <Input
              id="employee-search"
              value={searchQuery}
              onChange={(event) => setSearchQuery(event.target.value)}
              placeholder={t('employeesSetup.searchPlaceholder')}
              className="h-11 pl-9 text-base"
            />
          </div>
          <FilterSelect
            label={t('employeesSetup.filters.department')}
            value={departmentFilter}
            onChange={setDepartmentFilter}
            options={departmentOptions}
            allLabel={t('employeesSetup.filters.all', {
              label: t('employeesSetup.filters.department'),
            })}
          />
          <FilterSelect
            label={t('employeesSetup.filters.position')}
            value={positionFilter}
            onChange={setPositionFilter}
            options={positionOptions}
            allLabel={t('employeesSetup.filters.all', {
              label: t('employeesSetup.filters.position'),
            })}
          />
        </div>
      </div>

      <section className="mt-6">
        <SectionHeader title={t('employees.sections.list')} />
        {isError ? (
          <EmptyState
            icon={Users}
            title={t('common.error')}
            description={t('employees.error.loadFailed')}
            action={
              <Button type="button" variant="outline" className="touch-target" onClick={() => void refetch()}>
                {t('common.retry')}
              </Button>
            }
          />
        ) : isLoading ? (
          <div className="mt-3 space-y-2">
            <Skeleton className="h-16 w-full rounded-xl" />
            <Skeleton className="h-16 w-full rounded-xl" />
          </div>
        ) : employees.length === 0 ? (
          <EmptyState
            className="mt-3"
            icon={Users}
            title={t('employees.empty.title')}
            description={t('employeeAssignmentReadiness.empty.employees')}
          />
        ) : filteredEmployees.length === 0 ? (
          <EmptyState
            className="mt-3"
            icon={Users}
            title={t('employeesSetup.emptyFilter.title')}
            description={t('employeeAssignmentReadiness.empty.filtered')}
            action={
              <Button type="button" variant="outline" className="touch-target" onClick={resetFilters}>
                {t('employeesSetup.emptyFilter.reset')}
              </Button>
            }
          />
        ) : (
          <div className="mt-3 overflow-x-auto rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
            <div
              className={cn(
                'hidden min-w-[960px] gap-3 border-b border-[var(--color-border)] bg-[var(--color-bg-elevated)] px-4 py-2.5 text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)] xl:grid',
                EMPLOYEE_TABLE_GRID_COLS,
              )}
            >
              <div>{t('employeesSetup.columns.employee')}</div>
              <div>{t('employeeAssignmentReadiness.labels.department')}</div>
              <div>{t('employeeAssignmentReadiness.labels.position')}</div>
              <div>{t('employeeAssignmentReadiness.labels.costCenter')}</div>
              <div>{t('employeeAssignmentReadiness.labels.manager')}</div>
              <div className="text-right">{t('employeeAssignmentReadiness.labels.readiness')}</div>
            </div>
            <ul className="min-w-[960px] divide-y divide-[var(--color-border)] xl:min-w-0">
              {filteredEmployees.map((employee) => (
                <EmployeeRow
                  key={employee.id}
                  employee={employee}
                  onSelect={() => setSelectedEmployeeId(employee.id)}
                />
              ))}
            </ul>
          </div>
        )}
      </section>

      <SheetShell
        open={Boolean(selectedEmployee)}
        onOpenChange={(open) => {
          if (!open) setSelectedEmployeeId(null)
        }}
        title={selectedEmployee?.displayName ?? ''}
        description={selectedEmployee?.email ?? t('employeesSetup.detail.description')}
      >
        {selectedEmployee ? (
          <div className="space-y-5">
            <div className="flex items-center gap-3">
              <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-[var(--color-primary-soft)] text-sm font-semibold text-[var(--color-primary)]">
                {getInitials(selectedEmployee.displayName)}
              </span>
              <StatusPill tone={readinessPillTone(selectedEmployee.readiness.status)}>
                {t(`employeeAssignmentReadiness.status.${selectedEmployee.readiness.status}`)}
              </StatusPill>
            </div>

            <DetailRow
              icon={Building2}
              label={t('employeeAssignmentReadiness.labels.department')}
              value={assignmentDetailValue(
                selectedEmployee.department,
                t('employeeAssignmentReadiness.labels.departmentMissing'),
              )}
            />
            <DetailRow
              icon={Briefcase}
              label={t('employeeAssignmentReadiness.labels.position')}
              value={assignmentDetailValue(
                selectedEmployee.position,
                t('employeeAssignmentReadiness.labels.positionMissing'),
              )}
            />
            <DetailRow
              icon={Wallet}
              label={t('employeeAssignmentReadiness.labels.costCenter')}
              value={assignmentDetailValue(
                selectedEmployee.costCenter,
                t('employeeAssignmentReadiness.labels.costCenterMissing'),
              )}
            />
            <DetailRow
              icon={UserCheck}
              label={t('employeeAssignmentReadiness.labels.manager')}
              value={assignmentDetailValue(
                selectedEmployee.manager,
                t('employeeAssignmentReadiness.labels.managerMissing'),
                'displayName',
              )}
            />
            <DetailRow
              icon={Mail}
              label={t('employeesSetup.detail.email')}
              value={selectedEmployee.email ?? '—'}
            />

            {selectedLeave ? (
              <div>
                <div className="text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                  {t('employeesSetup.detail.leaveBalance')}
                </div>
                <div className="mt-2 rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-elevated)] p-3">
                  <div className="flex items-baseline justify-between gap-3">
                    <div className="text-sm font-medium text-[var(--color-text-primary)]">
                      {t('employeesSetup.detail.leaveAnnual')}
                    </div>
                    <div className="text-xs tabular-nums text-[var(--color-text-muted)]">
                      {t('employeesSetup.detail.leaveValue', {
                        remaining:
                          (selectedLeave.leaveTotal ?? 0) - (selectedLeave.leaveUsed ?? 0),
                        total: selectedLeave.leaveTotal ?? 0,
                      })}
                    </div>
                  </div>
                  <Progress
                    className="mt-2 h-1.5"
                    value={
                      (selectedLeave.leaveTotal ?? 0) > 0
                        ? ((selectedLeave.leaveUsed ?? 0) / (selectedLeave.leaveTotal ?? 1)) * 100
                        : 0
                    }
                  />
                </div>
              </div>
            ) : null}

            <p className="text-xs text-[var(--color-text-muted)]">
              {t('employeeAssignmentReadiness.boundary.erpNoWrite')}
            </p>
          </div>
        ) : null}
      </SheetShell>
    </div>
  )
}

function EmployeeRow({
  employee,
  onSelect,
}: {
  employee: EmployeeAssignmentReadinessEmployee
  onSelect: () => void
}) {
  const { t } = useTranslation()

  return (
    <li>
      <button
        type="button"
        onClick={onSelect}
        className={cn(
          'grid w-full min-h-[64px] min-w-0 grid-cols-[auto_minmax(0,1fr)_auto] items-center gap-3 p-4 text-left transition-colors hover:bg-[var(--color-bg-elevated)] xl:grid',
          EMPLOYEE_TABLE_GRID_COLS,
          !employee.isActive && 'opacity-70',
        )}
      >
        <div className="flex min-w-0 items-center gap-3 xl:col-span-1">
          <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-[var(--color-primary-soft)] text-xs font-semibold text-[var(--color-primary)]">
            {getInitials(employee.displayName)}
          </span>
          <div className="min-w-0">
            <div className="truncate text-sm font-medium text-[var(--color-text-primary)]">
              {employee.displayName}
            </div>
            <div className="truncate text-xs text-[var(--color-text-muted)] xl:hidden">
              {employee.department?.name ?? t('employeeAssignmentReadiness.labels.departmentMissing')} ·{' '}
              {employee.position?.name ?? t('employeeAssignmentReadiness.labels.positionMissing')}
            </div>
            <div className="hidden truncate text-xs text-[var(--color-text-muted)] xl:block">
              {[employee.email, employee.employeeNumber].filter(Boolean).join(' · ') || '—'}
            </div>
          </div>
        </div>
        <div className="hidden min-w-0 xl:block">
          {entityLabel(
            employee.department,
            'employeeAssignmentReadiness.labels.departmentMissing',
            t,
          )}
        </div>
        <div className="hidden min-w-0 xl:block">
          {entityLabel(
            employee.position,
            'employeeAssignmentReadiness.labels.positionMissing',
            t,
          )}
        </div>
        <div className="hidden min-w-0 xl:block">
          {entityLabel(
            employee.costCenter,
            'employeeAssignmentReadiness.labels.costCenterMissing',
            t,
          )}
        </div>
        <div className="hidden min-w-0 xl:block">{managerLabel(employee.manager, t)}</div>
        <div className="justify-self-end xl:text-right">
          <StatusPill tone={readinessPillTone(employee.readiness.status)}>
            {t(`employeeAssignmentReadiness.status.${employee.readiness.status}`)}
          </StatusPill>
        </div>
      </button>
    </li>
  )
}
