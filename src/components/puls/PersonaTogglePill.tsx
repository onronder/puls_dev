import { useTranslation } from 'react-i18next'

import { useAuth } from '#/lib/auth'
import { cn } from '#/lib/utils'

export function PersonaTogglePill() {
  const { t } = useTranslation()
  const { hasDualPersona, activePersona, setActivePersona } = useAuth()

  if (!hasDualPersona) return null

  return (
    <div
      className="inline-flex rounded-full border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-1"
      role="group"
      aria-label="Persona mode"
    >
      {(['employee', 'manager'] as const).map((persona) => (
        <button
          key={persona}
          type="button"
          onClick={() => void setActivePersona(persona)}
          className={cn(
            'touch-target rounded-full px-3 py-1.5 text-[11px] font-semibold transition-colors md:text-sm',
            activePersona === persona
              ? 'bg-[var(--color-primary)] text-[var(--color-primary-foreground)]'
              : 'text-[var(--color-text-muted)] hover:text-[var(--color-text-primary)]',
          )}
        >
          {t(`persona.${persona}`)}
        </button>
      ))}
    </div>
  )
}
