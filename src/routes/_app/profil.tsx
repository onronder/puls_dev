import { createFileRoute } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import { CalendarCheck, LogOut, Pencil, Shield, Target, Wallet } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { MetricCard } from '#/components/puls/MetricCard'
import { PageHeader } from '#/components/puls/PageHeader'
import { SectionHeader } from '#/components/puls/SectionHeader'
import { SheetShell } from '#/components/puls/SheetShell'
import { StatusPill } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { Skeleton } from '#/components/ui/skeleton'
import i18n from '#/i18n'
import { useAuth } from '#/lib/auth'
import { fetchProfileOverview, type ProfileOverview } from '#/lib/data'
import { formatCurrency } from '#/lib/format'

export const Route = createFileRoute('/_app/profil')({
  head: () => ({
    meta: [
      { title: i18n.t('profileSetup.meta.title') },
      {
        name: 'description',
        content: i18n.t('profileSetup.meta.description'),
      },
    ],
  }),
  component: ProfilPage,
})

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="grid grid-cols-[minmax(0,110px)_minmax(0,1fr)] items-center gap-3 px-4 py-3 sm:grid-cols-[minmax(0,160px)_minmax(0,1fr)]">
      <dt className="text-xs font-medium uppercase tracking-wider text-[var(--color-text-muted)]">
        {label}
      </dt>
      <dd className="min-w-0 break-words text-sm text-[var(--color-text-primary)]">{value}</dd>
    </div>
  )
}

function formatActivityWhat(
  activity: ProfileOverview['recentActivities'][number],
  t: ReturnType<typeof useTranslation>['t'],
  locale: string,
): string {
  if (activity.whatKey === 'profileSetup.activities.expenseReport' && activity.whatParams?.amount != null) {
    return t(activity.whatKey, {
      amount: formatCurrency(Number(activity.whatParams.amount), locale),
    })
  }

  return t(activity.whatKey, activity.whatParams)
}

function ProfilPage() {
  const { t, i18n: i18nInstance } = useTranslation()
  const { user, activePersona, signOut } = useAuth()
  const [logoutSheetOpen, setLogoutSheetOpen] = useState(false)

  const { data: profile, isLoading } = useQuery({
    queryKey: ['profile-overview', user?.id],
    queryFn: () => fetchProfileOverview(user!.id),
    enabled: Boolean(user?.id),
  })

  const displayName =
    (user?.user_metadata?.full_name as string | undefined) ?? t('menu.profileFallback')
  const tenantName = t('dashboard.noTenant')
  const email = user?.email ?? profile?.fallbackEmail ?? '—'
  const personaLabel =
    activePersona === 'manager' ? t('persona.manager') : t('persona.employee')

  const initials = useMemo(
    () =>
      displayName
        .split(' ')
        .map((part) => part[0])
        .join('')
        .slice(0, 2)
        .toUpperCase(),
    [displayName],
  )

  const handleLogout = () => {
    setLogoutSheetOpen(false)
    void signOut()
  }

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <p className="text-xs font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
        {t('profileSetup.eyebrow')}
      </p>
      <PageHeader
        className="mt-1"
        title={t('profileSetup.title')}
        subtitle={t('profileSetup.description')}
      />

      {isLoading ? (
        <Skeleton className="mb-6 h-28 w-full rounded-xl" />
      ) : profile ? (
        <>
          <div className="mb-6 flex flex-col gap-3 rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4 sm:flex-row sm:items-center sm:justify-between">
            <div className="flex min-w-0 items-center gap-4">
              <span className="flex h-14 w-14 shrink-0 items-center justify-center rounded-full bg-[var(--color-primary-soft)] text-lg font-semibold text-[var(--color-primary)]">
                {initials}
              </span>
              <div className="min-w-0">
                <div className="truncate text-base font-semibold">{displayName}</div>
                <div className="truncate text-sm text-[var(--color-text-muted)]">
                  {t(profile.roleKey)} · {tenantName}
                </div>
                <div className="mt-2">
                  <StatusPill tone="success">{t(profile.statusKey)}</StatusPill>
                </div>
              </div>
            </div>
            <Button
              type="button"
              variant="outline"
              className="touch-target h-11 shrink-0"
              disabled
              title={t('profileSetup.actions.editUnavailable')}
            >
              <Pencil className="h-4 w-4" />
              {t('profileSetup.actions.edit')}
            </Button>
          </div>

          <section className="mb-6">
            <SectionHeader title={t('profileSetup.sections.personalInfo')} />
            <dl className="divide-y divide-[var(--color-border)] overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
              <InfoRow label={t('profileSetup.fields.email')} value={email} />
              <InfoRow label={t('profileSetup.fields.department')} value={t(profile.departmentKey)} />
              <InfoRow label={t('profileSetup.fields.position')} value={t(profile.positionKey)} />
              <InfoRow label={t('profileSetup.fields.tenant')} value={tenantName} />
              <InfoRow label={t('profileSetup.fields.persona')} value={personaLabel} />
            </dl>
          </section>

          <section className="mb-6">
            <SectionHeader title={t('profileSetup.sections.selfHr')} />
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
              <MetricCard
                label={t('profileSetup.selfHr.leaveBalance')}
                value={t('profileSetup.selfHr.leaveValue', {
                  remaining: profile.leaveRemaining,
                  total: profile.leaveTotal,
                })}
                icon={CalendarCheck}
                hint={t(profile.leaveHintKey)}
              />
              <MetricCard
                label={t('profileSetup.selfHr.pendingExpense')}
                value={formatCurrency(profile.pendingExpenseAmount, i18nInstance.language)}
                icon={Wallet}
                hint={t('profileSetup.selfHr.pendingExpenseHint', {
                  count: profile.pendingExpenseCount,
                })}
              />
              <MetricCard
                label={t('profileSetup.selfHr.performance')}
                value={t(profile.performanceCycleKey)}
                icon={Target}
                hint={t(profile.performanceHintKey)}
              />
            </div>
          </section>

          <section className="mb-6">
            <SectionHeader title={t('profileSetup.sections.recentActivity')} />
            <ul className="divide-y divide-[var(--color-border)] overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
              {profile.recentActivities.slice(0, 4).map((activity) => (
                <li
                  key={activity.id}
                  className="flex items-center justify-between gap-3 p-3.5"
                >
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm text-[var(--color-text-primary)]">
                      <span className="font-medium">{activity.who}</span>{' '}
                      {formatActivityWhat(activity, t, i18nInstance.language)}
                    </p>
                  </div>
                  <span className="shrink-0 text-xs text-[var(--color-text-muted)]">
                    {t(activity.whenKey)}
                  </span>
                </li>
              ))}
            </ul>
          </section>
        </>
      ) : null}

      <div className="flex flex-col gap-2 sm:flex-row">
        <Button
          type="button"
          variant="outline"
          className="touch-target h-11 flex-1"
          disabled
          title={t('profileSetup.actions.securityUnavailable')}
        >
          <Shield className="h-4 w-4" />
          {t('profileSetup.actions.security')}
        </Button>
        <Button
          type="button"
          variant="outline"
          className="touch-target h-11 flex-1 text-[var(--color-danger)] hover:bg-[var(--color-danger-soft)]"
          onClick={() => setLogoutSheetOpen(true)}
        >
          <LogOut className="h-4 w-4" />
          {t('profileSetup.actions.logout')}
        </Button>
      </div>

      <SheetShell
        open={logoutSheetOpen}
        onOpenChange={setLogoutSheetOpen}
        title={t('profileSetup.logoutSheet.title')}
        description={t('profileSetup.logoutSheet.description')}
        footer={
          <div className="flex w-full gap-2">
            <Button
              type="button"
              variant="outline"
              className="touch-target h-11 flex-1"
              onClick={() => setLogoutSheetOpen(false)}
            >
              {t('common.cancel')}
            </Button>
            <Button
              type="button"
              className="touch-target h-11 flex-1"
              variant="destructive"
              onClick={handleLogout}
            >
              <LogOut className="h-4 w-4" />
              {t('profileSetup.logoutSheet.confirm')}
            </Button>
          </div>
        }
      >
        <p className="text-sm text-[var(--color-text-muted)]">{t('profileSetup.logoutSheet.body')}</p>
      </SheetShell>
    </div>
  )
}
