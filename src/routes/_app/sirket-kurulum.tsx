import { Link, createFileRoute } from '@tanstack/react-router'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { AlertCircle, Building2, CheckCircle2, Clock, Loader2, Plug } from 'lucide-react'
import { useState, type FormEvent } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { SetupRouteGuard } from '#/components/auth/SetupRouteGuard'
import { DemoSourcePill } from '#/components/puls/DemoSourcePill'
import { MetricCard } from '#/components/puls/MetricCard'
import { PageHeader } from '#/components/puls/PageHeader'
import { SectionHeader } from '#/components/puls/SectionHeader'
import { StatusPill, type StatusTone } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { Input } from '#/components/ui/input'
import { Skeleton } from '#/components/ui/skeleton'
import i18n from '#/i18n'
import { useAuth } from '#/lib/auth'
import {
  COMPANY_PROFILE_INDUSTRY_MAX_LENGTH,
  COMPANY_PROFILE_LOCALE_OPTIONS,
  COMPANY_PROFILE_NAME_MAX_LENGTH,
  COMPANY_PROFILE_TIMEZONE_OPTIONS,
  fetchCompanySetupOverviewWithMeta,
  fetchSetupReadinessDashboard,
  isCompanyProfileFormDirty,
  mapCompanyProfileMutationError,
  normalizeCompanyProfileInput,
  updateCompanyProfile,
  type CompanySetupOverview,
  type CompanyProfileMutationInput,
  type SetupReadinessIssue,
  type SetupReadinessSection,
  type SetupReadinessSeverity,
} from '#/lib/data'
import { isSetupAdmin } from '#/lib/setup-access'
import { cn } from '#/lib/utils'

export const Route = createFileRoute('/_app/sirket-kurulum')({
  head: () => ({
    meta: [
      { title: i18n.t('companySetup.meta.title') },
      {
        name: 'description',
        content: i18n.t('companySetup.meta.description'),
      },
    ],
  }),
  component: SirketKurulumRoute,
})

function SirketKurulumRoute() {
  return (
    <SetupRouteGuard>
      <SirketKurulumPage />
    </SetupRouteGuard>
  )
}

type DemoCompanySetupChecklistStatus = CompanySetupOverview['checklist'][number]['status']

type InfoRowProps = {
  label: string
  value: string
}

function InfoRow({ label, value }: InfoRowProps) {
  return (
    <div className="grid grid-cols-1 gap-1 px-4 py-3 sm:grid-cols-[200px_1fr] sm:items-center sm:gap-3">
      <dt className="text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
        {label}
      </dt>
      <dd className="text-sm text-[var(--color-text-primary)]">{value}</dd>
    </div>
  )
}

function checklistIconTone(status: DemoCompanySetupChecklistStatus): string {
  return status === 'done'
    ? 'bg-[color-mix(in_srgb,var(--color-success)_12%,transparent)] text-[var(--color-success)]'
    : 'bg-[color-mix(in_srgb,var(--color-warning)_12%,transparent)] text-[var(--color-warning)]'
}

function formatLocaleLanguage(code: string, uiLocale: string): string {
  const languageTag = code.split('-')[0]
  try {
    return new Intl.DisplayNames([uiLocale], { type: 'language' }).of(languageTag) ?? code
  } catch {
    return code
  }
}

function setupSeverityTone(severity: SetupReadinessSeverity): StatusTone {
  switch (severity) {
    case 'ready':
      return 'success'
    case 'warning':
      return 'warning'
    case 'blocking':
      return 'danger'
    case 'unknown':
      return 'neutral'
    default:
      return 'neutral'
  }
}

function issueTextTone(severity: SetupReadinessSeverity): string {
  switch (severity) {
    case 'blocking':
      return 'text-[var(--color-danger)]'
    case 'warning':
      return 'text-[var(--color-warning)]'
    case 'unknown':
      return 'text-[var(--color-text-muted)]'
    default:
      return 'text-[var(--color-text-secondary)]'
  }
}

function formatGeneratedAt(value: string, locale: string): string {
  try {
    return new Intl.DateTimeFormat(locale, {
      dateStyle: 'medium',
      timeStyle: 'short',
    }).format(new Date(value))
  } catch {
    return value
  }
}

function overviewToCompanyProfileForm(data: CompanySetupOverview): CompanyProfileMutationInput {
  return {
    displayName: data.name === '—' ? '' : data.name,
    industry: data.sector === '—' ? null : data.sector,
    locale: data.language,
    timezone: data.timezone,
  }
}

const COMPANY_FIELD_COUNT = 7
const CHECKLIST_SKELETON_COUNT = 4
const DASHBOARD_SECTION_SKELETON_COUNT = 7
const MAX_VISIBLE_ISSUES = 4

function SetupReadinessIssueRow({ issue }: { issue: SetupReadinessIssue }) {
  const { t } = useTranslation()

  return (
    <div className={cn('text-xs leading-relaxed', issueTextTone(issue.severity))}>
      <span className="font-medium">{t(issue.titleKey)}</span>
      {issue.count != null ? (
        <span className="ml-1 text-[var(--color-text-muted)]">({issue.count})</span>
      ) : null}
    </div>
  )
}

function SetupReadinessSectionRow({ section }: { section: SetupReadinessSection }) {
  const { t } = useTranslation()
  const visibleIssues = section.issues.slice(0, MAX_VISIBLE_ISSUES)
  const countLabel =
    section.totalCount === 0
      ? t('setupReadinessDashboard.counts.noneActive')
      : t('setupReadinessDashboard.counts.readyRatio', {
          ready: section.readyCount,
          total: section.totalCount,
        })

  return (
    <li className="flex min-h-[52px] flex-col gap-3 p-4 sm:flex-row sm:items-start sm:justify-between">
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center gap-2">
          <div className="text-sm font-medium">{t(section.titleKey)}</div>
          <StatusPill tone={setupSeverityTone(section.severity)}>
            {t(`setupReadinessDashboard.severity.${section.severity}`)}
          </StatusPill>
        </div>
        <div className="mt-1 text-xs text-[var(--color-text-muted)]">{countLabel}</div>
        {visibleIssues.length > 0 ? (
          <div className="mt-2 space-y-1">
            {visibleIssues.map((issue) => (
              <SetupReadinessIssueRow key={issue.id} issue={issue} />
            ))}
          </div>
        ) : null}
      </div>
      <Button asChild variant="outline" size="sm" className="shrink-0 self-start">
        <Link to={section.target}>{t('setupReadinessDashboard.actions.open')}</Link>
      </Button>
    </li>
  )
}

function SirketKurulumPage() {
  const { t, i18n } = useTranslation()
  const queryClient = useQueryClient()
  const { user, personaRole, activePersona } = useAuth()
  const [profileEditing, setProfileEditing] = useState(false)
  const [profileForm, setProfileForm] = useState<CompanyProfileMutationInput | null>(null)
  const [profileBaseline, setProfileBaseline] = useState<CompanyProfileMutationInput | null>(null)

  const { data: companySetupResult, isLoading } = useQuery({
    queryKey: ['company-setup-overview', user?.id],
    queryFn: () => fetchCompanySetupOverviewWithMeta(user!.id),
    enabled: Boolean(user?.id),
  })

  const data = companySetupResult?.data

  const { data: setupDashboard, isLoading: setupDashboardLoading } = useQuery({
    queryKey: ['setup-readiness-dashboard', user?.id],
    queryFn: () => fetchSetupReadinessDashboard(user!.id),
    enabled: Boolean(user?.id),
  })

  const companyProfileMutation = useMutation({
    mutationFn: async (form: CompanyProfileMutationInput) =>
      updateCompanyProfile(user!.id, normalizeCompanyProfileInput(form)),
    onSuccess: (result) => {
      void queryClient.invalidateQueries({ queryKey: ['company-setup-overview', user?.id] })
      void queryClient.invalidateQueries({ queryKey: ['setup-readiness-dashboard', user?.id] })
      void queryClient.invalidateQueries({ queryKey: ['settings-overview', user?.id] })
      setProfileEditing(false)
      setProfileForm(null)
      setProfileBaseline(null)
      toast.success(
        t(
          result.status === 'unchanged'
            ? 'companySetup.edit.toast.unchanged'
            : 'companySetup.edit.toast.saved',
        ),
      )
    },
    onError: (error) => {
      const mapped = mapCompanyProfileMutationError(error)
      toast.error(t(mapped.toastKey))
    },
  })

  const languageLabel = data ? formatLocaleLanguage(data.language, i18n.language) : ''
  const canEditCompanyProfile =
    Boolean(data) &&
    companySetupResult?.source !== 'demo' &&
    activePersona === 'manager' &&
    isSetupAdmin(personaRole)
  const canSubmitCompanyProfile =
    Boolean(profileForm) &&
    Boolean(profileBaseline) &&
    isCompanyProfileFormDirty(profileBaseline!, profileForm!) &&
    normalizeCompanyProfileInput(profileForm!).displayName.length >= 2 &&
    normalizeCompanyProfileInput(profileForm!).displayName.length <= COMPANY_PROFILE_NAME_MAX_LENGTH &&
    (normalizeCompanyProfileInput(profileForm!).industry?.length ?? 0) <= COMPANY_PROFILE_INDUSTRY_MAX_LENGTH &&
    !companyProfileMutation.isPending

  const companyFields = data
    ? [
        { label: t('companySetup.fields.name'), value: data.name },
        { label: t('companySetup.fields.vkn'), value: data.vkn },
        { label: t('companySetup.fields.sector'), value: data.sector },
        { label: t('companySetup.fields.band'), value: data.band },
        { label: t('companySetup.fields.language'), value: languageLabel },
        { label: t('companySetup.fields.timezone'), value: data.timezone },
        { label: t('companySetup.fields.package'), value: data.package },
      ]
    : []

  function startProfileEdit() {
    if (!data) return
    const form = overviewToCompanyProfileForm(data)
    setProfileForm(form)
    setProfileBaseline(form)
    setProfileEditing(true)
  }

  function cancelProfileEdit() {
    setProfileEditing(false)
    setProfileForm(null)
    setProfileBaseline(null)
  }

  function updateProfileForm(fields: Partial<CompanyProfileMutationInput>) {
    setProfileForm((current) => (current ? { ...current, ...fields } : current))
  }

  function handleCompanyProfileSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!profileForm) return

    const normalized = normalizeCompanyProfileInput(profileForm)
    if (
      normalized.displayName.length < 2 ||
      normalized.displayName.length > COMPANY_PROFILE_NAME_MAX_LENGTH
    ) {
      toast.error(t('companySetup.edit.errors.invalidName'))
      return
    }

    if ((normalized.industry?.length ?? 0) > COMPANY_PROFILE_INDUSTRY_MAX_LENGTH) {
      toast.error(t('companySetup.edit.errors.invalidIndustry'))
      return
    }

    companyProfileMutation.mutate(normalized)
  }

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <p className="text-xs font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
        {t('companySetup.eyebrow')}
      </p>
      <PageHeader
        className="mt-1"
        title={t('companySetup.title')}
        subtitle={t('companySetup.description')}
      />

      <DemoSourcePill
        visible={companySetupResult?.source === 'demo'}
        fallbackReason={companySetupResult?.fallbackReason}
      />

      {isLoading ? (
        <div className="mb-6 grid grid-cols-2 gap-3 lg:grid-cols-4">
          <Skeleton className="h-28 rounded-xl" />
          <Skeleton className="h-28 rounded-xl" />
          <Skeleton className="h-28 rounded-xl" />
          <Skeleton className="h-28 rounded-xl" />
        </div>
      ) : data ? (
        <div className="-mx-4 mb-6 flex gap-3 overflow-x-auto px-4 pb-1 md:mx-0 md:grid md:grid-cols-2 md:overflow-visible md:px-0 lg:grid-cols-4">
          <MetricCard
            compact
            label={t('companySetup.metrics.completion')}
            value={`${data.completion}%`}
            icon={CheckCircle2}
          />
          <MetricCard
            compact
            label={t('companySetup.metrics.missing')}
            value={String(data.missing)}
            icon={AlertCircle}
          />
          <MetricCard
            compact
            label={t('companySetup.metrics.erpReadiness')}
            value={data.erpReadiness}
            icon={Plug}
          />
          <MetricCard
            compact
            label={t('companySetup.metrics.language')}
            value={languageLabel}
            icon={Building2}
          />
        </div>
      ) : null}

      <section className="mb-6">
        <SectionHeader
          title={t('companySetup.sections.companyInfo')}
          action={
            canEditCompanyProfile && !profileEditing ? (
              <Button type="button" variant="outline" size="sm" onClick={startProfileEdit}>
                {t('companySetup.edit.open')}
              </Button>
            ) : undefined
          }
        />
        {profileEditing && profileForm ? (
          <form
            id="company-profile-form"
            className="mt-3 rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4"
            onSubmit={handleCompanyProfileSubmit}
          >
            <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
              <label className="block min-w-0">
                <span className="mb-1 block text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                  {t('companySetup.fields.name')}
                </span>
                <Input
                  value={profileForm.displayName}
                  maxLength={COMPANY_PROFILE_NAME_MAX_LENGTH}
                  disabled={companyProfileMutation.isPending}
                  onChange={(event) => updateProfileForm({ displayName: event.target.value })}
                />
              </label>
              <label className="block min-w-0">
                <span className="mb-1 block text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                  {t('companySetup.fields.sector')}
                </span>
                <Input
                  value={profileForm.industry ?? ''}
                  maxLength={COMPANY_PROFILE_INDUSTRY_MAX_LENGTH}
                  disabled={companyProfileMutation.isPending}
                  onChange={(event) => updateProfileForm({ industry: event.target.value })}
                />
              </label>
              <label className="block min-w-0">
                <span className="mb-1 block text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                  {t('companySetup.fields.language')}
                </span>
                <select
                  value={profileForm.locale}
                  disabled={companyProfileMutation.isPending}
                  onChange={(event) => updateProfileForm({ locale: event.target.value })}
                  className="h-11 w-full rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-3 text-base text-[var(--color-text-primary)] outline-none focus:ring-2 focus:ring-[var(--color-primary)] disabled:opacity-50"
                >
                  {COMPANY_PROFILE_LOCALE_OPTIONS.map((option) => (
                    <option key={option.value} value={option.value}>
                      {t(option.labelKey)}
                    </option>
                  ))}
                </select>
              </label>
              <label className="block min-w-0">
                <span className="mb-1 block text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
                  {t('companySetup.fields.timezone')}
                </span>
                <select
                  value={profileForm.timezone}
                  disabled={companyProfileMutation.isPending}
                  onChange={(event) => updateProfileForm({ timezone: event.target.value })}
                  className="h-11 w-full rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-3 text-base text-[var(--color-text-primary)] outline-none focus:ring-2 focus:ring-[var(--color-primary)] disabled:opacity-50"
                >
                  {COMPANY_PROFILE_TIMEZONE_OPTIONS.map((option) => (
                    <option key={option.value} value={option.value}>
                      {t(option.labelKey)}
                    </option>
                  ))}
                </select>
              </label>
            </div>
            <div className="mt-4 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
              <Button
                type="button"
                variant="outline"
                disabled={companyProfileMutation.isPending}
                onClick={cancelProfileEdit}
              >
                {t('common.cancel')}
              </Button>
              <Button type="submit" disabled={!canSubmitCompanyProfile}>
                {companyProfileMutation.isPending ? (
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" aria-hidden />
                ) : null}
                {t('companySetup.edit.save')}
              </Button>
            </div>
          </form>
        ) : (
          <dl className="mt-3 divide-y divide-[var(--color-border)] overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
            {isLoading
              ? Array.from({ length: COMPANY_FIELD_COUNT }, (_, index) => (
                  <div
                    key={index}
                    className="grid grid-cols-1 gap-1 px-4 py-3 sm:grid-cols-[200px_1fr] sm:items-center sm:gap-3"
                  >
                    <Skeleton className="h-3 w-24" />
                    <Skeleton className="h-4 w-full max-w-xs" />
                  </div>
                ))
              : companyFields.map((field) => (
                  <InfoRow key={field.label} label={field.label} value={field.value} />
                ))}
          </dl>
        )}
      </section>

      <section className="mb-6">
        <SectionHeader
          title={t('setupReadinessDashboard.title')}
          description={t('setupReadinessDashboard.subtitle')}
        />
        <p className="mt-2 text-sm text-[var(--color-text-muted)]">
          {t('setupReadinessDashboard.boundary.erpNoWrite')}
        </p>
        {setupDashboard ? (
          <div className="mt-3 flex flex-wrap items-center gap-2">
            <span className="text-xs font-semibold uppercase tracking-wide text-[var(--color-text-muted)]">
              {t('setupReadinessDashboard.overall')}
            </span>
            <StatusPill tone={setupSeverityTone(setupDashboard.severity)}>
              {t(`setupReadinessDashboard.severity.${setupDashboard.severity}`)}
            </StatusPill>
            <span className="text-xs text-[var(--color-text-muted)]">
              {t('setupReadinessDashboard.generatedAt', {
                time: formatGeneratedAt(setupDashboard.generatedAt, i18n.language),
              })}
            </span>
          </div>
        ) : null}
        <ul className="mt-3 divide-y divide-[var(--color-border)] overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
          {setupDashboardLoading ? (
            Array.from({ length: DASHBOARD_SECTION_SKELETON_COUNT }, (_, index) => (
              <li key={index} className="flex min-h-[52px] items-center gap-3 p-4">
                <Skeleton className="h-4 min-w-0 flex-1" />
                <Skeleton className="h-7 w-20 shrink-0 rounded-full" />
              </li>
            ))
          ) : setupDashboard ? (
            setupDashboard.severity === 'ready' && setupDashboard.sections.every((s) => s.issues.length === 0) ? (
              <li className="p-4 text-sm text-[var(--color-text-muted)]">
                {t('setupReadinessDashboard.empty.ready')}
              </li>
            ) : (
              setupDashboard.sections.map((section) => (
                <SetupReadinessSectionRow key={section.id} section={section} />
              ))
            )
          ) : null}
        </ul>
      </section>

      <section>
        <SectionHeader title={t('companySetup.sections.checklist')} />
        <ul className="mt-3 divide-y divide-[var(--color-border)] overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
          {isLoading
            ? Array.from({ length: CHECKLIST_SKELETON_COUNT }, (_, index) => (
                <li key={index} className="flex min-h-[52px] items-center gap-3 p-4">
                  <Skeleton className="h-7 w-7 shrink-0 rounded-full" />
                  <Skeleton className="h-4 min-w-0 flex-1" />
                  <Skeleton className="h-7 w-16 shrink-0 rounded-full" />
                </li>
              ))
            : (data?.checklist ?? []).map((item) => (
                <li key={item.id} className="flex min-h-[52px] items-center gap-3 p-4">
                  <span
                    className={cn(
                      'flex h-7 w-7 shrink-0 items-center justify-center rounded-full',
                      checklistIconTone(item.status),
                    )}
                  >
                    {item.status === 'done' ? (
                      <CheckCircle2 className="h-4 w-4" aria-hidden />
                    ) : (
                      <Clock className="h-4 w-4" aria-hidden />
                    )}
                  </span>
                  <div className="min-w-0 flex-1 text-sm">{t(item.labelKey)}</div>
                  <StatusPill tone={item.status === 'done' ? 'success' : 'warning'}>
                    {t(`companySetup.status.${item.status}`)}
                  </StatusPill>
                </li>
              ))}
        </ul>
      </section>
    </div>
  )
}
