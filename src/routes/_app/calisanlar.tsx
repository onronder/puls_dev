import { Link, createFileRoute } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import {
  Briefcase,
  Building2,
  CalendarDays,
  Mail,
  Search,
  UserCheck,
  Users,
} from 'lucide-react'
import type { LucideIcon } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { EmptyState } from '#/components/puls/EmptyState'
import { SectionHeader } from '#/components/puls/SectionHeader'
import { SheetShell } from '#/components/puls/SheetShell'
import { StatusPill, type StatusTone } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { Input } from '#/components/ui/input'
import { Progress } from '#/components/ui/progress'
import { Skeleton } from '#/components/ui/skeleton'
import i18n from '#/i18n'
import { useAuth } from '#/lib/auth'
import {
  fetchEmployeeList,
  fetchEmployeeListStats,
  fetchEmployeesOverview,
  type DemoEmployeeStatus,
  type EmployeeListItem,
  type EmployeesOverview,
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
  'lg:grid-cols-[minmax(0,1.5fr)_minmax(0,1fr)_minmax(0,1fr)_minmax(0,120px)]'

type EnrichedEmployee = EmployeeListItem & {
  initials: string
  department: string
  position: string
  status: DemoEmployeeStatus
  manager: string
  joinedLabel: string
  leaveUsed: number
  leaveTotal: number
  performanceScopeKey: string
}

function getInitials(fullName: string): string {
  return (fullName || '?')
    .split(' ')
    .filter(Boolean)
    .map((part) => part[0])
    .join('')
    .slice(0, 2)
    .toUpperCase()
}

function formatHireDate(isoDate: string, locale: string): string {
  return new Intl.DateTimeFormat(locale, {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  }).format(new Date(`${isoDate}T12:00:00`))
}

function enrichEmployee(
  employee: EmployeeListItem,
  demo: EmployeesOverview,
  locale: string,
): EnrichedEmployee {
  const emailKey = employee.email?.toLowerCase() ?? ''
  const fallback = demo.byEmail[emailKey]

  const department = employee.departmentName ?? '—'
  const position = employee.positionName ?? employee.jobTitle ?? '—'
  const status = fallback?.status ?? demo.defaultStatus
  const manager = fallback?.manager ?? demo.defaultManager
  const leaveUsed = fallback?.leaveUsed ?? demo.defaultLeave.used
  const leaveTotal = fallback?.leaveTotal ?? demo.defaultLeave.total
  const joinedLabel = employee.hireDate
    ? formatHireDate(employee.hireDate, locale)
    : (fallback?.joinedLabel ?? '—')

  return {
    ...employee,
    initials: getInitials(employee.fullName),
    department,
    position,
    status,
    manager,
    joinedLabel,
    leaveUsed,
    leaveTotal,
    performanceScopeKey: demo.performanceScopePendingKey,
  }
}

function statusTone(status: DemoEmployeeStatus): StatusTone {
  if (status === 'active') return 'success'
  if (status === 'onleave') return 'warning'
  return 'neutral'
}

type FilterOption = string | { value: string; label: string }

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

function CalisanlarPage() {
  const { t, i18n: i18nInstance } = useTranslation()
  const { user, activePersona } = useAuth()

  const [departmentFilter, setDepartmentFilter] = useState('')
  const [positionFilter, setPositionFilter] = useState('')
  const [statusFilter, setStatusFilter] = useState('')
  const [searchQuery, setSearchQuery] = useState('')
  const [selectedEmployeeId, setSelectedEmployeeId] = useState<string | null>(null)

  const { data: stats, isLoading: statsLoading } = useQuery({
    queryKey: ['employee-list-stats', user?.id],
    queryFn: () => fetchEmployeeListStats(user!.id),
    enabled: Boolean(user?.id) && activePersona === 'manager',
  })

  const { data: employees, isLoading, isError, refetch } = useQuery({
    queryKey: ['employee-list', user?.id],
    queryFn: () => fetchEmployeeList(user!.id),
    enabled: Boolean(user?.id) && activePersona === 'manager',
  })

  const { data: demoOverview } = useQuery({
    queryKey: ['employees-overview', user?.id],
    queryFn: () => fetchEmployeesOverview(user!.id),
    enabled: Boolean(user?.id) && activePersona === 'manager',
  })

  const enrichedEmployees = useMemo(() => {
    if (!employees || !demoOverview) return []
    return employees.map((employee) =>
      enrichEmployee(employee, demoOverview, i18nInstance.language),
    )
  }, [employees, demoOverview, i18nInstance.language])

  const departmentOptions = useMemo(
    () =>
      [...new Set(enrichedEmployees.map((employee) => employee.department).filter(Boolean))].sort(),
    [enrichedEmployees],
  )

  const positionOptions = useMemo(
    () =>
      [...new Set(enrichedEmployees.map((employee) => employee.position).filter(Boolean))].sort(),
    [enrichedEmployees],
  )

  const filteredEmployees = useMemo(() => {
    const query = searchQuery.trim().toLowerCase()
    return enrichedEmployees.filter((employee) => {
      if (departmentFilter && employee.department !== departmentFilter) return false
      if (positionFilter && employee.position !== positionFilter) return false
      if (statusFilter && employee.status !== statusFilter) return false
      if (query) {
        const haystack = `${employee.fullName} ${employee.email ?? ''}`.toLowerCase()
        if (!haystack.includes(query)) return false
      }
      return true
    })
  }, [enrichedEmployees, departmentFilter, positionFilter, statusFilter, searchQuery])

  const selectedEmployee = useMemo(
    () => enrichedEmployees.find((employee) => employee.id === selectedEmployeeId) ?? null,
    [enrichedEmployees, selectedEmployeeId],
  )

  const resetFilters = () => {
    setDepartmentFilter('')
    setPositionFilter('')
    setStatusFilter('')
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
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="text-xs font-medium uppercase tracking-wide text-[var(--color-text-muted)]">
            {t('employeesSetup.eyebrow')}
          </p>
          <h1 className="mt-1 text-[26px] font-semibold tracking-tight text-[var(--color-text-primary)] sm:text-3xl">
            {t('employees.title')}
          </h1>
          {statsLoading ? (
            <Skeleton className="mt-2 h-5 w-56 max-w-full" />
          ) : (
            <p className="mt-1 text-sm text-[var(--color-text-muted)]">
              {t('employeesSetup.summary', {
                employees: stats?.employeeCount ?? enrichedEmployees.length,
                departments: stats?.departmentCount ?? departmentOptions.length,
              })}
            </p>
          )}
        </div>
        <StatusPill tone="info">{t('employees.managerOnly')}</StatusPill>
      </div>

      <div className="mt-5 rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-3">
        <div className="grid grid-cols-1 gap-2 sm:grid-cols-2 lg:grid-cols-[minmax(0,1fr)_minmax(0,160px)_minmax(0,160px)_minmax(0,140px)]">
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
          <FilterSelect
            label={t('employeesSetup.filters.status')}
            value={statusFilter}
            onChange={setStatusFilter}
            options={[
              { value: 'active', label: t('employees.status.active') },
              { value: 'onleave', label: t('employees.status.onleave') },
              { value: 'inactive', label: t('employees.status.inactive') },
            ]}
            allLabel={t('employeesSetup.filters.all', {
              label: t('employeesSetup.filters.status'),
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
        ) : enrichedEmployees.length === 0 ? (
          <div className="mt-3 rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
            <EmptyState
              icon={Users}
              title={t('employees.empty.title')}
              description={t('employees.empty.description')}
            />
          </div>
        ) : filteredEmployees.length === 0 ? (
          <div className="mt-3 rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
            <EmptyState
              icon={Users}
              title={t('employeesSetup.emptyFilter.title')}
              description={t('employeesSetup.emptyFilter.description')}
              action={
                <Button type="button" variant="outline" className="touch-target" onClick={resetFilters}>
                  {t('employeesSetup.emptyFilter.reset')}
                </Button>
              }
            />
          </div>
        ) : (
          <div className="mt-3 overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
            <div
              className={cn(
                'hidden gap-3 border-b border-[var(--color-border)] bg-[var(--color-bg-elevated)] px-4 py-2.5 text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)] lg:grid',
                EMPLOYEE_TABLE_GRID_COLS,
              )}
            >
              <div>{t('employeesSetup.columns.employee')}</div>
              <div>{t('employeesSetup.columns.department')}</div>
              <div>{t('employeesSetup.columns.position')}</div>
              <div className="text-right">{t('employeesSetup.columns.status')}</div>
            </div>
            <ul className="divide-y divide-[var(--color-border)]">
              {filteredEmployees.map((employee) => (
                <li key={employee.id}>
                  <button
                    type="button"
                    onClick={() => setSelectedEmployeeId(employee.id)}
                    className={cn(
                      'grid w-full min-h-[64px] min-w-0 grid-cols-[auto_minmax(0,1fr)_auto] items-center gap-3 p-4 text-left transition-colors hover:bg-[var(--color-bg-elevated)] lg:grid',
                      EMPLOYEE_TABLE_GRID_COLS,
                    )}
                  >
                    <div className="flex min-w-0 items-center gap-3 lg:col-span-1">
                      <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-[var(--color-primary-soft)] text-xs font-semibold text-[var(--color-primary)]">
                        {employee.initials}
                      </span>
                      <div className="min-w-0">
                        <div className="truncate text-sm font-medium text-[var(--color-text-primary)]">
                          {employee.fullName}
                        </div>
                        <div className="truncate text-xs text-[var(--color-text-muted)] lg:hidden">
                          {employee.department} · {employee.position}
                        </div>
                        <div className="hidden truncate text-xs text-[var(--color-text-muted)] lg:block">
                          {employee.email ?? '—'}
                        </div>
                      </div>
                    </div>
                    <div className="hidden truncate text-sm text-[var(--color-text-primary)] lg:block">
                      {employee.department}
                    </div>
                    <div className="hidden truncate text-sm text-[var(--color-text-primary)] lg:block">
                      {employee.position}
                    </div>
                    <div className="justify-self-end lg:text-right">
                      <StatusPill tone={statusTone(employee.status)}>
                        {t(`employees.status.${employee.status}`)}
                      </StatusPill>
                    </div>
                  </button>
                </li>
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
        title={selectedEmployee?.fullName ?? ''}
        description={selectedEmployee?.email ?? t('employeesSetup.detail.description')}
      >
        {selectedEmployee ? (
          <div className="space-y-5">
            <div className="flex items-center gap-3">
              <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-[var(--color-primary-soft)] text-sm font-semibold text-[var(--color-primary)]">
                {selectedEmployee.initials}
              </span>
              <div className="min-w-0">
                <StatusPill tone={statusTone(selectedEmployee.status)}>
                  {t(`employees.status.${selectedEmployee.status}`)}
                </StatusPill>
              </div>
            </div>

            <DetailRow
              icon={Building2}
              label={t('employeesSetup.detail.department')}
              value={selectedEmployee.department}
            />
            <DetailRow
              icon={Briefcase}
              label={t('employeesSetup.detail.position')}
              value={selectedEmployee.position}
            />
            <DetailRow
              icon={UserCheck}
              label={t('employeesSetup.detail.manager')}
              value={selectedEmployee.manager}
            />
            <DetailRow
              icon={Mail}
              label={t('employeesSetup.detail.email')}
              value={selectedEmployee.email ?? '—'}
            />
            <DetailRow
              icon={CalendarDays}
              label={t('employeesSetup.detail.joined')}
              value={selectedEmployee.joinedLabel}
            />

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
                      remaining: selectedEmployee.leaveTotal - selectedEmployee.leaveUsed,
                      total: selectedEmployee.leaveTotal,
                    })}
                  </div>
                </div>
                <Progress
                  className="mt-2 h-1.5"
                  value={
                    selectedEmployee.leaveTotal > 0
                      ? (selectedEmployee.leaveUsed / selectedEmployee.leaveTotal) * 100
                      : 0
                  }
                />
              </div>
            </div>

            <div>
              <div className="text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                {t('employeesSetup.detail.performanceScope')}
              </div>
              <div className="mt-2 rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-elevated)] p-3 text-sm text-[var(--color-text-muted)]">
                {t(selectedEmployee.performanceScopeKey)}
              </div>
            </div>

            <div>
              <div className="text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                {t('employeesSetup.detail.recentActivity')}
              </div>
              <p className="mt-2 text-sm text-[var(--color-text-muted)]">
                {t('employeesSetup.detail.noActivity')}
              </p>
            </div>
          </div>
        ) : null}
      </SheetShell>
    </div>
  )
}
