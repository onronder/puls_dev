import type { LucideIcon } from 'lucide-react'
import {
  BarChart3,
  Briefcase,
  Building2,
  CalendarDays,
  FileText,
  GitBranch,
  LayoutDashboard,
  Menu,
  Settings,
  Sparkles,
  Users,
  Wallet,
  Waypoints,
} from 'lucide-react'

import type { ActivePersona } from '#/lib/auth'

export type NavAudience = 'all' | 'manager'

export type NavItem = {
  to: string
  labelKey: string
  icon: LucideIcon
  audience?: NavAudience
  soon?: boolean
}

export type NavGroup = {
  titleKey: string
  items: NavItem[]
}

export const mobileBottomTabs: NavItem[] = [
  { to: '/dashboard', labelKey: 'nav.dashboard', icon: LayoutDashboard, audience: 'all' },
  { to: '/performans', labelKey: 'nav.performans', icon: BarChart3, audience: 'all' },
  { to: '/izin', labelKey: 'nav.tatil', icon: CalendarDays, audience: 'all' },
  { to: '/masraf', labelKey: 'nav.cuzdan', icon: Wallet, audience: 'all' },
  { to: '/menu', labelKey: 'nav.menu', icon: Menu, audience: 'all' },
]

export const sidebarGroups: NavGroup[] = [
  {
    titleKey: 'nav.group.main',
    items: [{ to: '/dashboard', labelKey: 'nav.dashboard', icon: LayoutDashboard }],
  },
  {
    titleKey: 'nav.hrManagement',
    items: [
      { to: '/performans', labelKey: 'nav.performans', icon: BarChart3 },
      { to: '/calisanlar', labelKey: 'nav.calisanlar', icon: Users, audience: 'manager' },
      { to: '/dashboard', labelKey: 'nav.kariyer', icon: Waypoints, soon: true },
      { to: '/dashboard', labelKey: 'nav.kpi', icon: Briefcase, soon: true },
      { to: '/dashboard', labelKey: 'nav.kale', icon: FileText, soon: true },
    ],
  },
  {
    titleKey: 'nav.employeeProcesses',
    items: [
      { to: '/izin', labelKey: 'nav.tatil', icon: CalendarDays },
      { to: '/masraf', labelKey: 'nav.cuzdan', icon: Wallet },
      { to: '/dashboard', labelKey: 'nav.belge', icon: FileText, soon: true },
    ],
  },
  {
    titleKey: 'nav.ai',
    items: [{ to: '/menu', labelKey: 'nav.koc', icon: Sparkles, soon: true }],
  },
  {
    titleKey: 'nav.setup',
    items: [
      { to: '/erp', labelKey: 'nav.erp', icon: Waypoints },
      { to: '/sirket-kurulum', labelKey: 'nav.sirketKurulum', icon: Building2 },
      { to: '/departmanlar', labelKey: 'nav.departmanlar', icon: GitBranch },
      { to: '/menu', labelKey: 'nav.settings', icon: Settings, soon: true },
    ],
  },
]

export function filterNavItem(item: NavItem, activePersona: ActivePersona): boolean {
  if (item.audience === 'manager' && activePersona !== 'manager') {
    return false
  }
  return true
}

export function filterSidebarGroups(
  groups: NavGroup[],
  activePersona: ActivePersona,
): NavGroup[] {
  return groups
    .map((group) => ({
      ...group,
      items: group.items.filter((item) => filterNavItem(item, activePersona)),
    }))
    .filter((group) => group.items.length > 0)
}

export function filterBottomTabs(tabs: NavItem[], activePersona: ActivePersona): NavItem[] {
  return tabs.filter((item) => filterNavItem(item, activePersona))
}

export function isNavItemActive(pathname: string, to: string): boolean {
  if (to === '/dashboard') {
    return pathname === '/dashboard' || pathname === '/'
  }
  return pathname === to || pathname.startsWith(`${to}/`)
}
