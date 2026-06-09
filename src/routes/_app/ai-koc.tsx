import { createFileRoute, Link } from '@tanstack/react-router'
import { ArrowLeft, Send, Sparkles } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { PageHeader } from '#/components/puls/PageHeader'
import { StatusPill } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'
import { Textarea } from '#/components/ui/textarea'
import i18n from '#/i18n'

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

const PROMPT_KEYS = [
  'aiCoachSetup.chat.prompts.today',
  'aiCoachSetup.chat.prompts.leave',
  'aiCoachSetup.chat.prompts.expense',
  'aiCoachSetup.chat.prompts.performance',
] as const

function AiKocPage() {
  const { t } = useTranslation()

  return (
    <main className="mx-auto flex min-h-[calc(100vh-8rem)] max-w-4xl flex-col p-4 md:p-8">
      <p className="text-xs font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
        {t('aiCoachSetup.eyebrow')}
      </p>
      <PageHeader
        className="mt-1"
        title={t('aiCoachSetup.title')}
        subtitle={t('aiCoachSetup.description')}
      />

      <section className="mt-4 flex min-h-[520px] flex-1 flex-col rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-card)]">
        <div className="flex items-center justify-between gap-3 border-b border-[var(--color-border)] px-4 py-3">
          <div className="flex min-w-0 items-center gap-3">
            <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-[var(--color-ai-soft)] text-[var(--color-ai)]">
              <Sparkles className="h-5 w-5" aria-hidden />
            </span>
            <div className="min-w-0">
              <h2 className="truncate text-sm font-semibold text-[var(--color-text-primary)]">
                {t('aiCoachSetup.chat.title')}
              </h2>
              <p className="truncate text-xs text-[var(--color-text-muted)]">
                {t('aiCoachSetup.chat.status')}
              </p>
            </div>
          </div>
          <StatusPill tone="ai">{t('common.soon')}</StatusPill>
        </div>

        <div className="flex flex-1 flex-col justify-end gap-5 p-4 md:p-6">
          <div className="max-w-[88%] rounded-xl rounded-bl-sm border border-[var(--color-border)] bg-[var(--color-bg-elevated)] px-4 py-3 text-sm leading-relaxed text-[var(--color-text-primary)]">
            {t('aiCoachSetup.chat.assistantMessage')}
          </div>

          <div className="flex flex-wrap gap-2" aria-label={t('aiCoachSetup.chat.promptGroup')}>
            {PROMPT_KEYS.map((promptKey) => (
              <button
                key={promptKey}
                type="button"
                disabled
                className="touch-target rounded-full border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-3 py-2 text-left text-xs font-medium text-[var(--color-text-secondary)] disabled:opacity-70"
              >
                {t(promptKey)}
              </button>
            ))}
          </div>

          <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-3">
            <Textarea
              disabled
              rows={2}
              aria-label={t('aiCoachSetup.chat.inputLabel')}
              placeholder={t('aiCoachSetup.chat.inputPlaceholder')}
              className="min-h-[76px] resize-none border-0 bg-transparent px-0 py-0 focus-visible:ring-0"
            />
            <div className="mt-3 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <p className="text-xs text-[var(--color-text-muted)]">
                {t('aiCoachSetup.chat.disabledHint')}
              </p>
              <Button type="button" variant="ai" disabled className="h-10 sm:w-28">
                <Send className="h-4 w-4" aria-hidden />
                {t('aiCoachSetup.chat.send')}
              </Button>
            </div>
          </div>
        </div>
      </section>

      <div className="mt-4">
        <Button type="button" variant="outline" className="touch-target h-11" asChild>
          <Link to="/dashboard">
            <ArrowLeft className="h-4 w-4" />
            {t('aiCoachSetup.actions.backToDashboard')}
          </Link>
        </Button>
      </div>
    </main>
  )
}
