import { Link, useRouterState } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'

import { StatusPill } from '#/components/puls/StatusPill'
import { useAuth } from '#/lib/auth'
import {
  filterSidebarGroups,
  isNavItemActive,
  sidebarGroups,
} from '#/lib/navigation'
import { cn } from '#/lib/utils'

export function Sidebar() {
  const { t } = useTranslation()
  const { activePersona } = useAuth()
  const pathname = useRouterState({ select: (s) => s.location.pathname })
  const groups = filterSidebarGroups(sidebarGroups, activePersona)

  return (
    <aside className="hidden w-64 shrink-0 border-r border-[var(--color-border)] bg-[var(--color-bg-surface)] md:flex md:flex-col">
      <div className="flex-1 overflow-y-auto p-4">
        {groups.map((group) => (
          <div key={group.titleKey} className="mb-6">
            <p className="mb-2 px-2 text-xs font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
              {t(group.titleKey)}
            </p>
            <ul className="space-y-1">
              {group.items.map((item) => {
                const Icon = item.icon
                const active = isNavItemActive(pathname, item.to)
                const disabledSoon = item.soon

                return (
                  <li key={`${group.titleKey}-${item.labelKey}`}>
                    {disabledSoon ? (
                      <div
                        className={cn(
                          'flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-[var(--color-text-muted)] opacity-70',
                        )}
                      >
                        <Icon className="h-4 w-4 shrink-0" />
                        <span className="min-w-0 flex-1 truncate">{t(item.labelKey)}</span>
                        <StatusPill tone="neutral">{t('common.soon')}</StatusPill>
                      </div>
                    ) : (
                      <Link
                        to={item.to}
                        className={cn(
                          'flex touch-target items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors',
                          active
                            ? 'border-l-2 border-[var(--color-primary)] bg-[var(--color-bg-elevated)] text-[var(--color-text-primary)]'
                            : 'text-[var(--color-text-muted)] hover:bg-[var(--color-bg-elevated)] hover:text-[var(--color-text-primary)]',
                        )}
                      >
                        <Icon className="h-4 w-4 shrink-0" />
                        <span className="min-w-0 truncate">{t(item.labelKey)}</span>
                      </Link>
                    )}
                  </li>
                )
              })}
            </ul>
          </div>
        ))}
      </div>
    </aside>
  )
}
