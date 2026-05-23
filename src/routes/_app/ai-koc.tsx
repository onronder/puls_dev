import { createFileRoute, Link } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import {
  ArrowLeft,
  Bell,
  CalendarDays,
  Check,
  Clock,
  GraduationCap,
  Receipt,
  Shield,
  Sparkles,
  Target,
} from 'lucide-react'
import type { LucideIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { PageHeader } from '#/components/puls/PageHeader'
import { SectionHeader } from '#/components/puls/SectionHeader'
import { StatusPill } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { Skeleton } from '#/components/ui/skeleton'
import i18n from '#/i18n'
import { useAuth } from '#/lib/auth'
import { fetchAiCoachOverview, type AiCoachOverview } from '#/lib/data'
import { cn } from '#/lib/utils'

export const Route = createFileRoute('/_app/ai-koc')({
  head: () => ({
    meta: [
      { title: i18n.t('aiCoachSetup.meta.title') },
      {
        name: 'description',
        content: i18n.t('aiCoachSetup.meta.description'),
      },
    ],
  }),
  component: AiKocPage,
})

const CAPABILITY_ICONS: Record<string, LucideIcon> = {
  a1: CalendarDays,
  a2: Receipt,
  a3: Target,
  a4: GraduationCap,
}

function CapabilityIcon({ capability }: { capability: AiCoachOverview['capabilities'][number] }) {
  const Icon = CAPABILITY_ICONS[capability.id] ?? Sparkles

  return (
    <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-[var(--color-ai-soft)] text-[var(--color-ai)]">
      <Icon className="h-4 w-4" />
    </span>
  )
}

function ReadinessStatus({
  status,
  label,
}: {
  status: AiCoachOverview['readiness'][number]['status']
  label: string
}) {
  const isDone = status === 'done'

  return (
    <span className="flex shrink-0 items-center gap-2">
      <span
        className={cn(
          'flex h-7 w-7 items-center justify-center rounded-full',
          isDone
            ? 'bg-[var(--color-success-soft)] text-[var(--color-success)]'
            : 'bg-[var(--color-warning-soft)] text-[var(--color-warning)]',
        )}
        aria-hidden
      >
        {isDone ? <Check className="h-4 w-4" /> : <Clock className="h-4 w-4" />}
      </span>
      <span className="text-xs font-medium text-[var(--color-text-secondary)]">{label}</span>
    </span>
  )
}

function AiKocPage() {
  const { t } = useTranslation()
  const { user } = useAuth()

  const { data, isLoading } = useQuery({
    queryKey: ['ai-coach-overview', user?.id],
    queryFn: () => fetchAiCoachOverview(user!.id),
    enabled: Boolean(user?.id),
  })

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <p className="text-xs font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
        {t('aiCoachSetup.eyebrow')}
      </p>
      <PageHeader
        className="mt-1"
        title={t('aiCoachSetup.title')}
        subtitle={t('aiCoachSetup.description')}
      />

      <div className="mb-6 overflow-hidden rounded-xl border border-[color-mix(in_srgb,var(--color-ai)_25%,transparent)] bg-[var(--color-ai-soft)] p-5">
        <div className="flex items-start gap-3">
          <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-lg bg-[color-mix(in_srgb,var(--color-ai)_15%,transparent)] text-[var(--color-ai)]">
            <Sparkles className="h-5 w-5" />
          </span>
          <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-center gap-2">
              <h2 className="text-base font-semibold text-[var(--color-ai)]">
                {t('aiCoachSetup.hero.title')}
              </h2>
              <StatusPill tone="ai">{t('common.soon')}</StatusPill>
              <StatusPill tone="neutral">{t('ai.teaser.badge')}</StatusPill>
            </div>
            <p className="mt-2 text-sm leading-relaxed text-[var(--color-text-muted)]">
              {t('aiCoachSetup.hero.description')}
            </p>
          </div>
        </div>
      </div>

      <section className="mb-6">
        <SectionHeader title={t('aiCoachSetup.sections.capabilities')} />
        <ul className="mt-3 grid gap-3 sm:grid-cols-2">
          {isLoading
            ? Array.from({ length: 4 }, (_, index) => (
                <Skeleton key={index} className="h-24 rounded-xl" />
              ))
            : (data?.capabilities ?? []).map((capability) => (
                <li
                  key={capability.id}
                  className="min-w-0 rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4"
                >
                  <div className="flex items-start gap-3">
                    <CapabilityIcon capability={capability} />
                    <div className="min-w-0">
                      <div className="text-sm font-semibold">{t(capability.titleKey)}</div>
                      <p className="mt-1 text-xs leading-relaxed text-[var(--color-text-muted)]">
                        {t(capability.descKey)}
                      </p>
                    </div>
                  </div>
                </li>
              ))}
        </ul>
      </section>

      <section className="mb-6">
        <SectionHeader title={t('aiCoachSetup.sections.privacy')} />
        <div className="mt-3 flex items-start gap-3 rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)] p-4">
          <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-[var(--color-primary-soft)] text-[var(--color-primary)]">
            <Shield className="h-[18px] w-[18px]" />
          </span>
          <p className="text-sm leading-relaxed text-[var(--color-text-primary)]">
            {t('aiCoachSetup.privacy.body')}
          </p>
        </div>
      </section>

      <section className="mb-6">
        <SectionHeader title={t('aiCoachSetup.sections.readiness')} />
        <ul className="mt-3 divide-y divide-[var(--color-border)] overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
          {isLoading
            ? Array.from({ length: 3 }, (_, index) => (
                <li key={index} className="flex items-center gap-3 p-4">
                  <Skeleton className="h-7 w-7 rounded-full" />
                  <Skeleton className="h-4 w-48" />
                </li>
              ))
            : (data?.readiness ?? []).map((item) => {
                const statusLabel =
                  item.status === 'done'
                    ? t('aiCoachSetup.readiness.done')
                    : t('aiCoachSetup.readiness.pending')

                return (
                  <li
                    key={item.id}
                    className="flex min-h-[52px] flex-col gap-3 p-4 sm:flex-row sm:items-center sm:justify-between"
                  >
                    <span className="text-sm font-medium">{t(item.labelKey)}</span>
                    <ReadinessStatus status={item.status} label={statusLabel} />
                  </li>
                )
              })}
        </ul>
      </section>

      <div className="flex flex-col gap-2 sm:flex-row">
        <Button
          type="button"
          variant="ai"
          className="touch-target h-11 flex-1"
          onClick={() =>
            toast.info(t('aiCoachSetup.notifyToast.title'), {
              description: t('aiCoachSetup.notifyToast.description'),
            })
          }
        >
          <Bell className="h-4 w-4" />
          {t('aiCoachSetup.actions.notifyMe')}
        </Button>
        <Button type="button" variant="outline" className="touch-target h-11 flex-1" asChild>
          <Link to="/dashboard">
            <ArrowLeft className="h-4 w-4" />
            {t('aiCoachSetup.actions.backToDashboard')}
          </Link>
        </Button>
      </div>
    </div>
  )
}
