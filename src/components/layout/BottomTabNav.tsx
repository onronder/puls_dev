import { Link, useRouterState } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'

import { useAuth } from '#/lib/auth'
import {
  filterBottomTabs,
  isNavItemActive,
  mobileBottomTabs,
} from '#/lib/navigation'
import { cn } from '#/lib/utils'

export function BottomTabNav() {
  const { t } = useTranslation()
  const { activePersona } = useAuth()
  const pathname = useRouterState({ select: (s) => s.location.pathname })
  const tabs = filterBottomTabs(mobileBottomTabs, activePersona)

  return (
    <nav className="fixed inset-x-0 bottom-0 z-40 border-t border-[var(--color-border)] bg-[color-mix(in_srgb,var(--color-bg-surface)_96%,transparent)] backdrop-blur-xl md:hidden">
      <ul className="mx-auto flex max-w-lg items-stretch justify-around px-1 pb-[env(safe-area-inset-bottom)]">
        {tabs.map((tab) => {
          const Icon = tab.icon
          const active = isNavItemActive(pathname, tab.to)
          return (
            <li key={tab.to} className="min-w-0 flex-1">
              <Link
                to={tab.to}
                className={cn(
                  'mx-1 flex min-h-[52px] touch-target flex-col items-center justify-center gap-1 rounded-lg px-1 py-2 text-[11px] font-medium transition-colors',
                  active
                    ? 'bg-[var(--color-primary-soft)] text-[var(--color-primary)]'
                    : 'text-[var(--color-text-muted)]',
                )}
              >
                <Icon className="h-5 w-5 shrink-0" />
                <span className="max-w-full truncate">{t(tab.labelKey)}</span>
              </Link>
            </li>
          )
        })}
      </ul>
    </nav>
  )
}
