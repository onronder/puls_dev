import { redirect } from '@tanstack/react-router'

import { adminSetupNavItems } from '#/lib/navigation'
import { resolvePersonaForUser } from '#/lib/persona'
import { supabase, type PersonaRole } from '#/lib/supabase'

/** Platform setup screens — admin / İK admin / patron only. */
export const SETUP_ROUTE_PATHS = adminSetupNavItems.map((item) => item.to)

export const PERSONAL_SETTINGS_SECTION_IDS = [
  'accountSecurity',
  'notifications',
  'locale',
  'theme',
] as const

export const ADMIN_ONLY_SETTINGS_SECTION_IDS = ['tenant', 'roleAccess'] as const

export type PersonalSettingsSectionId = (typeof PERSONAL_SETTINGS_SECTION_IDS)[number]

/** Resolved backend roles that may access Kurulum & Tanımlar. Line managers excluded. */
export function isSetupAdmin(personaRole: PersonaRole | null | undefined): boolean {
  return personaRole === 'hr_admin' || personaRole === 'superadmin'
}

export function isSetupRoutePath(pathname: string): boolean {
  return SETUP_ROUTE_PATHS.some(
    (path) => pathname === path || pathname.startsWith(`${path}/`),
  )
}

export function canAccessSetupRoute(
  personaRole: PersonaRole | null | undefined,
  pathname: string,
): boolean {
  if (!isSetupRoutePath(pathname)) {
    return true
  }
  return isSetupAdmin(personaRole)
}

export function filterSettingsSectionsForRole<T extends { id: string }>(
  sections: T[],
  personaRole: PersonaRole | null | undefined,
): T[] {
  if (isSetupAdmin(personaRole)) {
    return sections
  }
  return sections.filter((section) =>
    PERSONAL_SETTINGS_SECTION_IDS.includes(section.id as PersonalSettingsSectionId),
  )
}

/** Route guard for setup screens — redirects unauthorized users to /ayarlar. */
export async function requireSetupAdminRoute(): Promise<void> {
  const { data } = await supabase.auth.getSession()
  const userId = data.session?.user?.id

  if (!userId) {
    throw redirect({ to: '/login' })
  }

  const { personaRole } = await resolvePersonaForUser(userId)

  if (!isSetupAdmin(personaRole)) {
    throw redirect({ to: '/ayarlar' })
  }
}
