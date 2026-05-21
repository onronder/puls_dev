import { Bot } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { SheetShell } from '#/components/puls/SheetShell'
import { StatusPill } from '#/components/puls/StatusPill'
import { Button } from '#/components/ui/button'

export function FloatingAIButton() {
  const { t } = useTranslation()
  const [open, setOpen] = useState(false)

  return (
    <>
      <div className="fixed bottom-[calc(4.5rem+env(safe-area-inset-bottom))] right-4 z-50 md:bottom-6 md:right-6">
        <Button
          type="button"
          variant="ai"
          size="lg"
          className="h-14 min-w-[56px] rounded-full px-5 shadow-[0_12px_35px_rgba(124,58,237,0.28)]"
          aria-label={t('ai.floatingLabel')}
          onClick={() => setOpen(true)}
        >
          <Bot className="h-5 w-5" />
          <span className="hidden sm:inline">{t('ai.floatingLabel')}</span>
        </Button>
      </div>

      <SheetShell
        open={open}
        onOpenChange={setOpen}
        title={t('ai.teaser.title')}
        description={t('ai.teaser.description')}
        footer={
          <Button type="button" variant="outline" className="w-full" onClick={() => setOpen(false)}>
            {t('common.close')}
          </Button>
        }
      >
        <div className="space-y-4">
          <StatusPill tone="ai">{t('ai.teaser.badge')}</StatusPill>
          <ul className="space-y-2 text-sm text-[var(--color-text-secondary)]">
            <li>{t('ai.teaser.featureLeave')}</li>
            <li>{t('ai.teaser.featureExpense')}</li>
            <li>{t('ai.teaser.featureCareer')}</li>
            <li>{t('ai.teaser.featurePerformance')}</li>
          </ul>
          <p className="text-xs leading-relaxed text-[var(--color-text-muted)]">
            {t('ai.teaser.privacy')}
          </p>
        </div>
      </SheetShell>
    </>
  )
}
