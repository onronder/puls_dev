import { LogOut } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { PersonaTogglePill } from '#/components/puls/PersonaTogglePill'
import { Button } from '#/components/ui/button'
import { useAuth } from '#/lib/auth'

export function AppHeader() {
  const { t } = useTranslation()
  const { signOut } = useAuth()

  return (
    <header className="sticky top-0 z-40 border-b border-[var(--color-border)] bg-[rgba(9,11,10,0.85)] backdrop-blur-xl">
      <div className="mx-auto flex h-12 max-w-7xl items-center justify-between gap-3 px-4 md:h-14 md:px-6">
        <div className="flex min-w-0 items-center gap-3">
          <div className="flex items-center gap-2">
            <span className="text-xl font-black tracking-wider">
              {t('app.name')}
              <span className="text-[var(--color-primary)]">.</span>
            </span>
            <span className="hidden h-2 w-2 rounded-full bg-[var(--color-primary)] md:inline-block" />
          </div>
          <PersonaTogglePill />
        </div>
        <Button variant="ghost" size="icon" onClick={() => void signOut()} aria-label="Sign out">
          <LogOut className="h-4 w-4" />
        </Button>
      </div>
    </header>
  )
}
