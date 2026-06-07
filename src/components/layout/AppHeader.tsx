import { LogOut } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { AppNotificationCenter } from '#/components/notifications/AppNotificationCenter'
import { PersonaTogglePill } from '#/components/puls/PersonaTogglePill'
import { Button } from '#/components/ui/button'
import { useAuth } from '#/lib/auth'

export function AppHeader() {
  const { t } = useTranslation()
  const { signOut } = useAuth()

  return (
    <header className="sticky top-0 z-40 border-b border-[var(--color-border)] bg-[color-mix(in_srgb,var(--color-bg-base)_88%,transparent)] backdrop-blur-xl">
      <div className="mx-auto flex h-12 max-w-7xl items-center justify-between gap-3 px-4 md:h-14 md:px-6">
        <div className="flex min-w-0 items-center gap-3">
          <div className="flex items-center gap-2">
            <span className="text-xl font-bold tracking-tight text-[var(--color-text-primary)]">
              {t('app.name')}
              <span className="text-[var(--color-primary)]">.</span>
            </span>
          </div>
          <PersonaTogglePill />
        </div>
        <div className="flex shrink-0 items-center gap-1">
          <AppNotificationCenter />
          <Button
            variant="ghost"
            size="icon"
            onClick={() => void signOut()}
            aria-label={t('auth.signOut')}
          >
            <LogOut className="h-4 w-4" />
          </Button>
        </div>
      </div>
    </header>
  )
}
