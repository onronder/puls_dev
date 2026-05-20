import { Link, useRouterState } from '@tanstack/react-router'
import {
  BarChart3,
  Bot,
  CalendarDays,
  CheckSquare,
  LayoutDashboard,
  User,
} from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { useAuth } from '#/lib/auth'
import { cn } from '#/lib/utils'

type TabItem = {
  to: string
  labelKey: string
  icon: React.ComponentType<{ className?: string }>
}

export function BottomTabNav() {
  const { t } = useTranslation()
  const { activePersona } = useAuth()
  const pathname = useRouterState({ select: (s) => s.location.pathname })

  const employeeTabs: TabItem[] = [
    { to: '/dashboard', labelKey: 'nav.dashboard', icon: LayoutDashboard },
    { to: '/performans', labelKey: 'nav.performans', icon: BarChart3 },
    { to: '/dashboard', labelKey: 'nav.koc', icon: Bot },
    { to: '/dashboard', labelKey: 'nav.tatil', icon: CalendarDays },
    { to: '/dashboard', labelKey: 'nav.profil', icon: User },
  ]

  const managerTabs: TabItem[] = [
    { to: '/dashboard', labelKey: 'nav.dashboard', icon: LayoutDashboard },
    { to: '/performans', labelKey: 'nav.performans', icon: BarChart3 },
    { to: '/dashboard', labelKey: 'nav.approvals', icon: CheckSquare },
    { to: '/dashboard', labelKey: 'nav.koc', icon: Bot },
  ]

  const tabs = activePersona === 'manager' ? managerTabs : employeeTabs

  return (
    <nav className="fixed inset-x-0 bottom-0 z-40 border-t border-[var(--color-border)] bg-[var(--color-bg-surface)] md:hidden">
      <ul className="mx-auto flex max-w-lg items-stretch justify-around px-2 pb-[env(safe-area-inset-bottom)]">
        {tabs.map((tab) => {
          const Icon = tab.icon
          const active = pathname.startsWith(tab.to)
          return (
            <li key={tab.labelKey}>
              <Link
                to={tab.to}
                className={cn(
                  'flex touch-target flex-col items-center justify-center gap-1 px-2 py-2 text-[10px] font-medium',
                  active
                    ? 'text-[var(--color-primary)]'
                    : 'text-[var(--color-text-muted)]',
                )}
              >
                <Icon className="h-5 w-5" />
                <span>{t(tab.labelKey)}</span>
              </Link>
            </li>
          )
        })}
      </ul>
    </nav>
  )
}
