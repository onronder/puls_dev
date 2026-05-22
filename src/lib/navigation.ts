import type { LucideIcon } from 'lucide-react'
import {
  BarChart3,
  Briefcase,
  Building2,
  CalendarDays,
  FileText,
  GitBranch,
  GraduationCap,
  LayoutDashboard,
  ListChecks,
  Menu,
  Receipt,
  Scale,
  Settings,
  SlidersHorizontal,
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
      { to: '/kariyer', labelKey: 'nav.kariyer', icon: Waypoints },
      { to: '/egitim', labelKey: 'nav.egitim', icon: GraduationCap },
      { to: '/dashboard', labelKey: 'nav.kpi', icon: Briefcase, soon: true },
      { to: '/is-degerleme', labelKey: 'nav.isDegerleme', icon: Scale },
    ],
  },
  {
    titleKey: 'nav.employeeProcesses',
    items: [
      { to: '/izin', labelKey: 'nav.tatil', icon: CalendarDays },
      { to: '/masraf', labelKey: 'nav.cuzdan', icon: Wallet },
      { to: '/sozlesmeler', labelKey: 'nav.sozlesmeler', icon: FileText },
    ],
  },
  {
    titleKey: 'nav.ai',
    items: [{ to: '/ai-koc', labelKey: 'nav.koc', icon: Sparkles }],
  },
  {
    titleKey: 'nav.setup',
    items: [
      { to: '/erp', labelKey: 'nav.erp', icon: Waypoints },
      { to: '/sirket-kurulum', labelKey: 'nav.sirketKurulum', icon: Building2 },
      { to: '/departmanlar', labelKey: 'nav.departmanlar', icon: GitBranch },
      { to: '/pozisyonlar', labelKey: 'nav.pozisyonlar', icon: Briefcase },
      { to: '/izin-tanimlari', labelKey: 'nav.izinTanimlari', icon: ListChecks },
      { to: '/masraf-kategorileri', labelKey: 'nav.masrafKategorileri', icon: Receipt },
      {
        to: '/performans-parametreleri',
        labelKey: 'nav.performansParametreleri',
        icon: SlidersHorizontal,
      },
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
