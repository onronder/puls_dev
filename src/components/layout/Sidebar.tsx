import { Link, useRouterState } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'

import { useAuth } from '#/lib/auth'
import { cn } from '#/lib/utils'

type NavGroup = {
  titleKey: string
  items: { to: string; labelKey: string }[]
}

export function Sidebar() {
  const { t } = useTranslation()
  const { activePersona } = useAuth()
  const pathname = useRouterState({ select: (s) => s.location.pathname })

  const groups: NavGroup[] = [
    {
      titleKey: 'nav.hrManagement',
      items: [
        { to: '/dashboard', labelKey: 'nav.dashboard' },
        { to: '/dashboard', labelKey: 'nav.performans' },
        { to: '/dashboard', labelKey: 'nav.kariyer' },
        { to: '/dashboard', labelKey: 'nav.kpi' },
        { to: '/dashboard', labelKey: 'nav.kale' },
      ],
    },
    {
      titleKey: 'nav.employeeProcesses',
      items: [
        { to: '/dashboard', labelKey: 'nav.calisanlar' },
        { to: '/dashboard', labelKey: 'nav.belge' },
        { to: '/dashboard', labelKey: 'nav.tatil' },
        { to: '/dashboard', labelKey: 'nav.cuzdan' },
      ],
    },
    {
      titleKey: 'nav.ai',
      items: [{ to: '/dashboard', labelKey: 'nav.koc' }],
    },
    {
      titleKey: 'nav.setup',
      items: [
        { to: '/dashboard', labelKey: 'nav.erp' },
        { to: '/dashboard', labelKey: 'nav.settings' },
      ],
    },
  ]

  if (activePersona === 'employee') {
    groups.splice(1, 2)
  }

  return (
    <aside className="hidden w-60 shrink-0 border-r border-[var(--color-border)] bg-[var(--color-bg-surface)] md:flex md:flex-col">
      <div className="flex-1 overflow-y-auto p-4">
        {groups.map((group) => (
          <div key={group.titleKey} className="mb-6">
            <p className="mb-2 px-2 text-[11px] font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
              {t(group.titleKey)}
            </p>
            <ul className="space-y-1">
              {group.items.map((item) => {
                const active = pathname === item.to
                return (
                  <li key={item.labelKey}>
                    <Link
                      to={item.to}
                      className={cn(
                        'block rounded-lg px-3 py-2 text-sm font-medium transition-colors',
                        active
                          ? 'border-l-2 border-[var(--color-primary)] bg-[var(--color-bg-elevated)] text-[var(--color-text-primary)]'
                          : 'text-[var(--color-text-muted)] hover:bg-[var(--color-bg-elevated)] hover:text-[var(--color-text-primary)]',
                      )}
                    >
                      {t(item.labelKey)}
                    </Link>
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
