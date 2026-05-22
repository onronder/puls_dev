import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useQuery } from '@tanstack/react-query'
import {
  Briefcase,
  Building2,
  CalendarDays,
  GraduationCap,
  FileText,
  GitBranch,
  LayoutDashboard,
  ListChecks,
  LogOut,
  Receipt,
  Scale,
  Settings,
  SlidersHorizontal,
  Sparkles,
  User,
  Users,
  Wallet,
  Waypoints,
  BarChart3,
} from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { DataList } from '#/components/puls/DataList'
import { PageHeader } from '#/components/puls/PageHeader'
import { StatusPill } from '#/components/puls/StatusPill'
import { Avatar, AvatarFallback } from '#/components/ui/avatar'
import { Button } from '#/components/ui/button'
import { Card, CardContent } from '#/components/ui/card'
import { useAuth } from '#/lib/auth'
import { fetchDashboardStats } from '#/lib/queries/dashboard'

export const Route = createFileRoute('/_app/menu')({
  component: MenuPage,
})

type MenuLink = {
  id: string
  to: string
  labelKey: string
  icon: React.ComponentType<{ className?: string }>
  audience?: 'manager'
  soon?: boolean
}

const menuLinks: MenuLink[] = [
  { id: 'dashboard', to: '/dashboard', labelKey: 'nav.dashboard', icon: LayoutDashboard },
  { id: 'profil', to: '/profil', labelKey: 'nav.profil', icon: User },
  { id: 'performans', to: '/performans', labelKey: 'nav.performans', icon: BarChart3 },
  { id: 'izin', to: '/izin', labelKey: 'nav.tatil', icon: CalendarDays },
  { id: 'masraf', to: '/masraf', labelKey: 'nav.cuzdan', icon: Wallet },
  { id: 'sozlesmeler', to: '/sozlesmeler', labelKey: 'nav.sozlesmeler', icon: FileText },
  { id: 'calisanlar', to: '/calisanlar', labelKey: 'nav.calisanlar', icon: Users, audience: 'manager' },
  { id: 'kariyer', to: '/kariyer', labelKey: 'nav.kariyer', icon: Waypoints },
  { id: 'egitim', to: '/egitim', labelKey: 'nav.egitim', icon: GraduationCap },
  { id: 'is-degerleme', to: '/is-degerleme', labelKey: 'nav.isDegerleme', icon: Scale },
  { id: 'koc', to: '/ai-koc', labelKey: 'nav.koc', icon: Sparkles },
  { id: 'erp', to: '/erp', labelKey: 'nav.erp', icon: Waypoints },
  { id: 'sirket-kurulum', to: '/sirket-kurulum', labelKey: 'nav.sirketKurulum', icon: Building2 },
  { id: 'departmanlar', to: '/departmanlar', labelKey: 'nav.departmanlar', icon: GitBranch },
  { id: 'pozisyonlar', to: '/pozisyonlar', labelKey: 'nav.pozisyonlar', icon: Briefcase },
  { id: 'izin-tanimlari', to: '/izin-tanimlari', labelKey: 'nav.izinTanimlari', icon: ListChecks },
  { id: 'masraf-kategorileri', to: '/masraf-kategorileri', labelKey: 'nav.masrafKategorileri', icon: Receipt },
  {
    id: 'performans-parametreleri',
    to: '/performans-parametreleri',
    labelKey: 'nav.performansParametreleri',
    icon: SlidersHorizontal,
  },
  { id: 'settings', to: '/ayarlar', labelKey: 'nav.settings', icon: Settings },
]

function MenuPage() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const { user, activePersona, signOut } = useAuth()

  const { data: stats } = useQuery({
    queryKey: ['dashboard-stats', user?.id],
    queryFn: () => fetchDashboardStats(user!.id),
    enabled: Boolean(user?.id),
  })

  const visibleLinks = menuLinks.filter((link) => {
    if (link.audience === 'manager' && activePersona !== 'manager') {
      return false
    }
    return true
  })

  const initials =
    stats?.displayName
      ?.split(' ')
      .map((part) => part[0])
      .join('')
      .slice(0, 2)
      .toUpperCase() ?? 'PU'

  return (
    <div className="mx-auto max-w-5xl overflow-x-hidden p-4 md:p-8">
      <PageHeader title={t('menu.title')} subtitle={t('menu.subtitle')} />

      <Card className="mb-6">
        <CardContent className="flex items-center gap-4 p-4">
          <Avatar className="h-14 w-14">
            <AvatarFallback className="text-base">{initials}</AvatarFallback>
          </Avatar>
          <div className="min-w-0 flex-1">
            <p className="truncate text-lg font-semibold">{stats?.displayName ?? t('menu.profileFallback')}</p>
            <p className="truncate text-sm text-[var(--color-text-muted)]">
              {stats?.tenantName ?? t('dashboard.noTenant')}
            </p>
            <StatusPill tone="neutral" className="mt-2">
              {activePersona === 'manager' ? t('persona.manager') : t('persona.employee')}
            </StatusPill>
          </div>
        </CardContent>
      </Card>

      <DataList
        items={visibleLinks.map((link) => {
          const Icon = link.icon
          return {
            id: link.id,
            title: t(link.labelKey),
            leading: <Icon className="h-4 w-4 text-[var(--color-primary)]" />,
            trailing: link.soon ? <StatusPill tone="neutral">{t('common.soon')}</StatusPill> : undefined,
            onClick: link.soon ? undefined : () => navigate({ to: link.to }),
          }
        })}
      />

      <div className="mt-6 space-y-3">
        <Card className="border-[rgba(124,58,237,0.25)] bg-[rgba(124,58,237,0.06)]">
          <CardContent className="p-4">
            <div className="flex items-center gap-2">
              <Sparkles className="h-4 w-4 text-[var(--color-ai)]" />
              <p className="font-semibold">{t('ai.teaser.title')}</p>
            </div>
            <p className="mt-2 text-sm text-[var(--color-text-muted)]">{t('ai.teaser.description')}</p>
            <StatusPill tone="ai" className="mt-3">
              {t('ai.teaser.badge')}
            </StatusPill>
          </CardContent>
        </Card>

        <Button type="button" variant="outline" className="w-full touch-target" onClick={() => void signOut()}>
          <LogOut className="h-4 w-4" />
          {t('menu.signOut')}
        </Button>
      </div>
    </div>
  )
}
