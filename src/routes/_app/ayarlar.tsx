import { Link, createFileRoute } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import { ChevronRight } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { DemoSourcePill } from '#/components/puls/DemoSourcePill'
import { PageHeader } from '#/components/puls/PageHeader'
import { SectionHeader } from '#/components/puls/SectionHeader'
import { SheetShell } from '#/components/puls/SheetShell'
import { StatusPill } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { Skeleton } from '#/components/ui/skeleton'
import { useAuth } from '#/lib/auth'
import {
  adminSetupNavItems,
  type NavItem,
} from '#/lib/navigation'
import { fetchSettingsOverviewWithMeta, type SettingsOverview } from '#/lib/data'
import { canShowSetupHub, filterSettingsSectionsForRole } from '#/lib/setup-access'
import i18n from '#/i18n'

export const Route = createFileRoute('/_app/ayarlar')({
  head: () => ({
    meta: [
      { title: i18n.t('settingsSetup.meta.title') },
      {
        name: 'description',
        content: i18n.t('settingsSetup.meta.description'),
      },
    ],
  }),
  component: AyarlarPage,
})

function translateSettingsValue(
  t: ReturnType<typeof useTranslation>['t'],
  value: SettingsOverview['sections'][number]['value'],
) {
  if (value.key) return t(value.key, value.params ?? undefined)
  return value.text ?? '—'
}

function SetupNavRow({
  item,
  label,
  state,
}: {
  item: NavItem
  label: string
  state?: SettingsOverview['setupHubItems'][number]
}) {
  const { t } = useTranslation()
  const Icon = item.icon
  return (
    <Link
      to={item.to}
      className="flex min-h-[76px] min-w-0 items-center gap-3 p-4 transition-colors hover:bg-[var(--color-bg-elevated)]"
    >
      <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-[var(--color-bg-elevated)] text-[var(--color-text-secondary)]">
        <Icon className="h-[18px] w-[18px]" />
      </span>
      <div className="min-w-0 flex-1">
        <div className="flex min-w-0 flex-wrap items-center gap-2">
          <span className="truncate text-[15px] font-medium text-[var(--color-text-primary)]">
            {label}
          </span>
          {state ? (
            <StatusPill tone={state.tone}>{t(state.statusLabelKey)}</StatusPill>
          ) : null}
        </div>
        {state ? (
          <p className="mt-1 truncate text-xs text-[var(--color-text-muted)]">
            {translateSettingsValue(t, state.value)} · {t(state.hintKey)}
          </p>
        ) : null}
      </div>
      <ChevronRight className="h-4 w-4 shrink-0 text-[var(--color-text-muted)]" />
    </Link>
  )
}

function AyarlarPage() {
  const { t } = useTranslation()
  const { user, personaRole, activePersona } = useAuth()
  const [selectedSectionId, setSelectedSectionId] = useState<string | null>(null)
  const showSetupHub = canShowSetupHub(personaRole, activePersona)

  const { data: settingsResult, isLoading } = useQuery({
    queryKey: ['settings-overview', user?.id],
    queryFn: () => fetchSettingsOverviewWithMeta(user!.id),
    enabled: Boolean(user?.id),
  })

  const data = settingsResult?.data

  const visibleSections = useMemo(
    () =>
      data ? filterSettingsSectionsForRole(data.sections, personaRole, activePersona) : [],
    [data, personaRole, activePersona],
  )

  const selectedSection = useMemo(
    () => visibleSections.find((section) => section.id === selectedSectionId),
    [visibleSections, selectedSectionId],
  )

  const setupStateByRoute = useMemo(() => {
    const entries = data?.setupHubItems.map((item) => [item.to, item] as const) ?? []
    return new Map(entries)
  }, [data?.setupHubItems])

  const openSectionSheet = (section: SettingsOverview['sections'][number]) => {
    setSelectedSectionId(section.id)
  }

  const closeSectionSheet = (open: boolean) => {
    if (!open) {
      setSelectedSectionId(null)
    }
  }

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <p className="text-xs font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
        {t(showSetupHub ? 'settingsSetup.eyebrow' : 'settingsSetup.eyebrowPersonal')}
      </p>
      <PageHeader
        className="mt-1"
        title={t('settingsSetup.title')}
        subtitle={t(
          showSetupHub ? 'settingsSetup.description' : 'settingsSetup.descriptionPersonal',
        )}
      />

      <DemoSourcePill
        visible={settingsResult?.source === 'demo'}
        fallbackReason={settingsResult?.fallbackReason}
      />

      {showSetupHub ? (
        <section className="mb-8">
          <SectionHeader
            title={t('settingsSetup.setupHub.title')}
            description={t('settingsSetup.setupHub.description')}
          />
          <ul className="divide-y divide-[var(--color-border)] overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
            {adminSetupNavItems.map((item) => (
              <li key={item.to}>
                <SetupNavRow
                  item={item}
                  label={t(item.labelKey)}
                  state={setupStateByRoute.get(item.to)}
                />
              </li>
            ))}
          </ul>
        </section>
      ) : null}

      <section className="mb-6">
        <SectionHeader
          title={t('settingsSetup.sectionsList')}
          description={t('settingsSetup.sectionsDescription')}
        />
        {isLoading ? (
          <Skeleton className="h-96 w-full rounded-xl" />
        ) : visibleSections.length > 0 ? (
          <ul className="divide-y divide-[var(--color-border)] overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
            {visibleSections.map((section) => (
              <li key={section.id}>
                <button
                  type="button"
                  onClick={() => openSectionSheet(section)}
                  className="flex w-full min-h-[82px] min-w-0 items-center gap-3 p-4 text-left transition-colors hover:bg-[var(--color-bg-elevated)]"
                >
                  <div className="min-w-0 flex-1">
                    <div className="flex min-w-0 flex-wrap items-center gap-2">
                      <span className="truncate text-[15px] font-medium text-[var(--color-text-primary)]">
                        {t(section.titleKey)}
                      </span>
                      <StatusPill tone={section.tone}>{t(section.statusLabelKey)}</StatusPill>
                    </div>
                    <p className="mt-1 truncate text-xs text-[var(--color-text-secondary)]">
                      {translateSettingsValue(t, section.value)}
                    </p>
                    <p className="mt-1 truncate text-xs text-[var(--color-text-muted)]">
                      {t(section.helperKey)}
                    </p>
                  </div>
                  <ChevronRight className="h-4 w-4 shrink-0 text-[var(--color-text-muted)]" />
                </button>
              </li>
            ))}
          </ul>
        ) : null}
      </section>

      {showSetupHub && data ? (
        <section className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
          <div className="flex flex-wrap items-center gap-2">
            <h2 className="text-sm font-medium text-[var(--color-text-primary)]">
              {t('settingsSetup.auditLog.title')}
            </h2>
            <StatusPill tone="neutral">{t('common.readOnly')}</StatusPill>
          </div>
          <p className="mt-2 text-xs leading-relaxed text-[var(--color-text-muted)]">
            {t('settingsSetup.auditLog.summary', {
              days: data.auditLogDays,
              count: data.auditLogSensitiveCount,
            })}
          </p>
          <p className="mt-1 text-xs leading-relaxed text-[var(--color-text-muted)]">
            {t('settingsSetup.auditLog.note')}
          </p>
        </section>
      ) : null}

      <SheetShell
        open={Boolean(selectedSection)}
        onOpenChange={closeSectionSheet}
        title={selectedSection ? t(selectedSection.titleKey) : ''}
        description={selectedSection ? t(selectedSection.sheetDescriptionKey) : undefined}
        footer={
          selectedSection ? (
            <Button type="button" variant="outline" className="touch-target w-full" disabled>
              {t('settingsSetup.sheet.actionUnavailable')}
            </Button>
          ) : undefined
        }
      >
        {selectedSection ? (
          <div className="space-y-4">
            <StatusPill tone="neutral" className="self-start">
              {t(selectedSection.statusLabelKey)}
            </StatusPill>
            <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-elevated)] p-4">
              <p className="text-xs font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
                {t('settingsSetup.sheet.currentState')}
              </p>
              <p className="mt-2 text-xl font-semibold text-[var(--color-text-primary)]">
                {translateSettingsValue(t, selectedSection.value)}
              </p>
              <p className="mt-2 text-sm leading-relaxed text-[var(--color-text-muted)]">
                {t(selectedSection.helperKey)}
              </p>
            </div>
            <div className="space-y-2">
              <p className="text-xs font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
                {t('settingsSetup.sheet.evidence')}
              </p>
              <dl className="divide-y divide-[var(--color-border)] overflow-hidden rounded-xl border border-[var(--color-border)]">
                {selectedSection.evidence.map((row) => (
                  <div
                    key={row.labelKey}
                    className="grid grid-cols-[minmax(0,1fr)_minmax(0,1fr)] gap-3 p-3"
                  >
                    <dt className="min-w-0 text-xs text-[var(--color-text-muted)]">
                      {t(row.labelKey)}
                    </dt>
                    <dd className="min-w-0 text-right text-xs font-medium text-[var(--color-text-primary)]">
                      {translateSettingsValue(t, row.value)}
                    </dd>
                  </div>
                ))}
              </dl>
            </div>
            <p className="text-sm leading-relaxed text-[var(--color-text-muted)]">
              {t(selectedSection.sheetBodyKey)}
            </p>
          </div>
        ) : null}
      </SheetShell>
    </div>
  )
}
