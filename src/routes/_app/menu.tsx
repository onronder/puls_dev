import { Link, createFileRoute } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import { ChevronRight, LogOut, Sparkles, X } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { SheetShell } from '#/components/puls/SheetShell'
import { StatusPill } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { Skeleton } from '#/components/ui/skeleton'
import i18n from '#/i18n'
import { useAuth } from '#/lib/auth'
import { fetchDemoMenuTenantFallback } from '#/lib/demo/puls-demo-data'
import {
  filterSidebarGroups,
  sidebarGroups,
  type NavItem,
} from '#/lib/navigation'
import { fetchDashboardStats } from '#/lib/queries/dashboard'
import { fetchEmployeeListStats } from '#/lib/queries/employees'

export const Route = createFileRoute('/_app/menu')({
  head: () => ({
    meta: [
      { title: i18n.t('menu.title') + ' — PULS' },
      { name: 'description', content: i18n.t('menuSetup.subtitle') },
    ],
  }),
  component: MenuPage,
})

function getInitials(name: string | null | undefined): string {
  return (
    name
      ?.split(' ')
      .filter(Boolean)
      .map((part) => part[0])
      .join('')
      .slice(0, 2)
      .toUpperCase() ?? 'PU'
  )
}

type TenantStatProps = {
  label: string
  value: number
}

function TenantStat({ label, value }: TenantStatProps) {
  return (
    <div className="px-3 py-3">
      <div className="tabular text-base font-semibold text-foreground">{value}</div>
      <div className="text-[11px] uppercase tracking-wider text-muted-foreground">{label}</div>
    </div>
  )
}

type MenuNavRowProps = {
  item: NavItem
  label: string
  soonLabel: string
}

function MenuNavRow({ item, label, soonLabel }: MenuNavRowProps) {
  const Icon = item.icon
  const inner = (
    <>
      <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-secondary text-secondary-foreground">
        <Icon className="h-[18px] w-[18px]" />
      </span>
      <div className="min-w-0 flex-1">
        <div className="truncate text-[15px] font-medium text-foreground">{label}</div>
      </div>
      {item.soon ? (
        <StatusPill tone="neutral">{soonLabel}</StatusPill>
      ) : (
        <ChevronRight className="h-4 w-4 shrink-0 text-muted-foreground" />
      )}
    </>
  )

  if (item.soon) {
    return (
      <div className="flex min-h-14 cursor-not-allowed items-center gap-3 p-3.5 opacity-80">{inner}</div>
    )
  }

  return (
    <Link
      to={item.to}
      className="flex min-h-14 items-center gap-3 p-3.5 transition-colors hover:bg-accent/40"
    >
      {inner}
    </Link>
  )
}

function MenuPage() {
  const { t } = useTranslation()
  const { user, activePersona, signOut } = useAuth()
  const [logoutOpen, setLogoutOpen] = useState(false)

  const { data: dashboardStats, isLoading: dashboardLoading } = useQuery({
    queryKey: ['dashboard-stats', user?.id],
    queryFn: () => fetchDashboardStats(user!.id),
    enabled: Boolean(user?.id),
  })

  const { data: tenantStats, isLoading: statsLoading } = useQuery({
    queryKey: ['employee-list-stats', user?.id],
    queryFn: () => fetchEmployeeListStats(user!.id),
    enabled: Boolean(user?.id),
  })

  const { data: demoFallback } = useQuery({
    queryKey: ['demo-menu-tenant-fallback'],
    queryFn: fetchDemoMenuTenantFallback,
  })

  const menuGroups = useMemo(
    () =>
      filterSidebarGroups(sidebarGroups, activePersona)
        .map((group) => ({
          ...group,
          items: group.items.filter((item) => item.to !== '/menu'),
        }))
        .filter((group) => group.items.length > 0),
    [activePersona],
  )

  const resolvedStats = useMemo(() => {
    const employees = tenantStats?.employeeCount ?? dashboardStats?.employeeCount ?? 0
    const departments = tenantStats?.departmentCount ?? dashboardStats?.departmentCount ?? 0
    const positions = tenantStats?.positionCount ?? 0

    if (employees === 0 && departments === 0 && positions === 0 && demoFallback) {
      return demoFallback
    }

    return { employeeCount: employees, departmentCount: departments, positionCount: positions }
  }, [tenantStats, dashboardStats, demoFallback])

  const displayName = dashboardStats?.displayName ?? t('menu.profileFallback')
  const tenantName = dashboardStats?.tenantName ?? t('dashboard.noTenant')
  const initials = getInitials(dashboardStats?.displayName)
  const statsReady = !dashboardLoading && !statsLoading

  function handleLogout() {
    setLogoutOpen(false)
    void signOut()
  }

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 pb-24 md:p-8 md:pb-8">
      <div className="mb-5">
        <div className="text-[12px] font-medium uppercase tracking-[0.04em] text-muted-foreground">
          {t('menuSetup.eyebrow')}
        </div>
        <h1 className="mt-1 text-[26px] font-semibold tracking-tight text-foreground sm:text-3xl">
          {t('menu.title')}
        </h1>
        <p className="mt-1 text-sm text-muted-foreground">{t('menuSetup.subtitle')}</p>
      </div>

      <div className="overflow-hidden rounded-2xl border border-border bg-card">
        <div className="flex items-center gap-4 p-5">
          {dashboardLoading ? (
            <Skeleton className="h-14 w-14 shrink-0 rounded-full" />
          ) : (
            <span className="flex h-14 w-14 shrink-0 items-center justify-center rounded-full bg-primary/10 text-lg font-semibold text-primary">
              {initials}
            </span>
          )}
          <div className="min-w-0 flex-1">
            {dashboardLoading ? (
              <>
                <Skeleton className="mb-2 h-5 w-40" />
                <Skeleton className="h-4 w-32" />
              </>
            ) : (
              <>
                <div className="truncate text-base font-semibold">{displayName}</div>
                <div className="truncate text-sm text-muted-foreground">{tenantName}</div>
                <div className="mt-1.5">
                  <StatusPill tone="success">{t('menuSetup.statusActive')}</StatusPill>
                </div>
              </>
            )}
          </div>
        </div>
        <div className="grid grid-cols-3 divide-x divide-border border-t border-border bg-surface-2 text-center">
          {statsReady ? (
            <>
              <TenantStat label={t('menuSetup.stats.employees')} value={resolvedStats.employeeCount} />
              <TenantStat
                label={t('menuSetup.stats.departments')}
                value={resolvedStats.departmentCount}
              />
              <TenantStat label={t('menuSetup.stats.positions')} value={resolvedStats.positionCount} />
            </>
          ) : (
            <>
              <Skeleton className="m-3 h-10 rounded-md" />
              <Skeleton className="m-3 h-10 rounded-md" />
              <Skeleton className="m-3 h-10 rounded-md" />
            </>
          )}
        </div>
      </div>

      <div className="mt-5 flex items-start gap-3 rounded-xl border border-ai/20 bg-ai-soft p-4">
        <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-ai/15 text-ai">
          <Sparkles className="h-[18px] w-[18px]" />
        </span>
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <div className="text-sm font-semibold text-ai">{t('ai.floatingLabel')}</div>
            <span className="rounded-full bg-ai/15 px-1.5 py-0.5 text-[10px] font-semibold uppercase text-ai">
              {t('common.soon')}
            </span>
          </div>
          <p className="mt-0.5 text-xs text-ai/90">{t('ai.teaser.description')}</p>
        </div>
      </div>

      <div className="mt-6 space-y-6">
        {menuGroups.map((group) => (
          <section key={group.titleKey}>
            <div className="mb-2 px-1 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
              {t(group.titleKey)}
            </div>
            <ul className="divide-y divide-border overflow-hidden rounded-xl border border-border bg-card">
              {group.items.map((item) => (
                <li key={`${group.titleKey}-${item.to}`}>
                  <MenuNavRow item={item} label={t(item.labelKey)} soonLabel={t('common.soon')} />
                </li>
              ))}
            </ul>
          </section>
        ))}
      </div>

      <Button
        type="button"
        variant="outline"
        className="mt-8 min-h-11 w-full border-border text-[var(--color-danger)] hover:bg-danger-soft"
        onClick={() => setLogoutOpen(true)}
      >
        <LogOut className="h-4 w-4" />
        {t('menu.signOut')}
      </Button>

      <SheetShell
        open={logoutOpen}
        onOpenChange={setLogoutOpen}
        title={t('profileSetup.logoutSheet.title')}
        description={t('profileSetup.logoutSheet.description')}
        footer={
          <div className="flex w-full gap-2">
            <Button
              type="button"
              variant="outline"
              className="min-h-11 flex-1"
              onClick={() => setLogoutOpen(false)}
            >
              <X className="h-4 w-4" />
              {t('common.cancel')}
            </Button>
            <Button
              type="button"
              className="min-h-11 flex-1 bg-[var(--color-danger)] text-[#071006] hover:bg-[var(--color-danger)]/90"
              onClick={handleLogout}
            >
              <LogOut className="h-4 w-4" />
              {t('profileSetup.logoutSheet.confirm')}
            </Button>
          </div>
        }
      >
        <p className="text-sm text-muted-foreground">{t('profileSetup.logoutSheet.body')}</p>
      </SheetShell>

      <p className="mt-6 text-center text-xs text-muted-foreground">{t('menuSetup.versionFooter')}</p>
    </div>
  )
}
