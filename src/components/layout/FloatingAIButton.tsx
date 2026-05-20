import { Bot } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { Button } from '#/components/ui/button'

export function FloatingAIButton() {
  const { t } = useTranslation()

  return (
    <div className="fixed bottom-20 right-4 z-50 md:bottom-6 md:right-6">
      <Button
        type="button"
        variant="default"
        size="lg"
        className="h-14 rounded-full px-5 shadow-[0_12px_35px_rgba(91,209,31,0.22)]"
        aria-label={t('ai.floatingLabel')}
        onClick={() => {
          /* Sprint-2: open AI Koç panel */
        }}
      >
        <Bot className="h-5 w-5" />
        <span className="hidden sm:inline">{t('ai.floatingLabel')}</span>
      </Button>
    </div>
  )
}
