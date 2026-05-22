import { createFileRoute, Link } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import { ChevronRight } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { FormField } from '#/components/puls/FormField'
import { PageHeader } from '#/components/puls/PageHeader'
import { SectionHeader } from '#/components/puls/SectionHeader'
import { SheetShell } from '#/components/puls/SheetShell'
import { StatusPill } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { Input } from '#/components/ui/input'
import { Skeleton } from '#/components/ui/skeleton'
import i18n from '#/i18n'
import {
  fetchDemoSettingsOverview,
  type DemoSettingsSection,
} from '#/lib/demo/puls-demo-data'

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

function AyarlarPage() {
  const { t } = useTranslation()
  const [selectedSectionId, setSelectedSectionId] = useState<string | null>(null)

  const { data, isLoading } = useQuery({
    queryKey: ['demo-settings-overview'],
    queryFn: fetchDemoSettingsOverview,
  })

  const selectedSection = useMemo(
    () => data?.sections.find((section) => section.id === selectedSectionId),
    [data, selectedSectionId],
  )

  const openSectionSheet = (section: DemoSettingsSection) => {
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
        {t('settingsSetup.eyebrow')}
      </p>
      <PageHeader
        className="mt-1"
        title={t('settingsSetup.title')}
        subtitle={t('settingsSetup.description')}
      />

      <section className="mb-6">
        <SectionHeader title={t('settingsSetup.sectionsList')} />
        {isLoading ? (
          <Skeleton className="h-96 w-full rounded-xl" />
        ) : data ? (
          <ul className="divide-y divide-[var(--color-border)] overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
            {data.sections.map((section) => (
              <li key={section.id}>
                <button
                  type="button"
                  onClick={() => openSectionSheet(section)}
                  className="flex w-full min-h-[64px] min-w-0 items-center gap-3 p-4 text-left transition-colors hover:bg-[var(--color-bg-elevated)]"
                >
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-[15px] font-medium text-[var(--color-text-primary)]">
                      {t(section.titleKey)}
                    </div>
                    <div className="truncate text-xs text-[var(--color-text-muted)]">
                      {t(section.summaryKey)}
                    </div>
                  </div>
                  <span className="hidden shrink-0 text-xs font-medium text-[var(--color-primary)] sm:inline">
                    {t(section.actionKey)}
                  </span>
                  <ChevronRight className="h-4 w-4 shrink-0 text-[var(--color-text-muted)]" />
                </button>
              </li>
            ))}
          </ul>
        ) : null}
      </section>

      {data ? (
        <section className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
          <div className="flex flex-wrap items-center gap-2">
            <h2 className="text-sm font-medium text-[var(--color-text-primary)]">
              {t('settingsSetup.auditLog.title')}
            </h2>
            <StatusPill tone="neutral">{t('settingsSetup.sheet.mvpBadge')}</StatusPill>
          </div>
          <p className="mt-2 text-xs leading-relaxed text-[var(--color-text-muted)]">
            {t('settingsSetup.auditLog.summary', {
              days: data.auditLogDays,
              count: data.auditLogSensitiveCount,
            })}
          </p>
          <p className="mt-1 text-xs leading-relaxed text-[var(--color-text-muted)]">
            {t('settingsSetup.auditLog.mvpNote')}
          </p>
          <Button type="button" variant="outline" className="touch-target mt-4 h-10" asChild>
            <Link to="/menu">{t('settingsSetup.auditLog.backToMenu')}</Link>
          </Button>
        </section>
      ) : null}

      <SheetShell
        open={Boolean(selectedSection)}
        onOpenChange={closeSectionSheet}
        title={selectedSection ? t(selectedSection.titleKey) : ''}
        description={selectedSection ? t(selectedSection.sheetDescriptionKey) : undefined}
        footer={
          selectedSection ? (
            <div className="flex w-full flex-col gap-3">
              <StatusPill tone="neutral" className="self-start">
                {t('settingsSetup.sheet.mvpBadge')}
              </StatusPill>
              <Button type="button" className="touch-target w-full" disabled>
                {t('settingsSetup.sheet.submit')}
              </Button>
            </div>
          ) : undefined
        }
      >
        {selectedSection ? (
          <div className="space-y-4">
            <FormField
              label={t(selectedSection.titleKey)}
              htmlFor={`settings-${selectedSection.id}-summary`}
            >
              <Input
                id={`settings-${selectedSection.id}-summary`}
                className="text-base"
                value={t(selectedSection.summaryKey)}
                readOnly
                disabled
              />
            </FormField>
            <p className="text-sm leading-relaxed text-[var(--color-text-muted)]">
              {t(selectedSection.sheetBodyKey)}
            </p>
          </div>
        ) : null}
      </SheetShell>
    </div>
  )
}
