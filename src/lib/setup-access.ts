import type { ActivePersona } from '#/lib/auth'
import { adminSetupNavItems } from '#/lib/navigation'
import type { PersonaRole } from '#/lib/supabase'

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

/** UI visibility for Kurulum & Tanımlar — admin role plus Yönetici Modu only. */
export function canShowSetupHub(
  personaRole: PersonaRole | null | undefined,
  activePersona: ActivePersona,
): boolean {
  return isSetupAdmin(personaRole) && activePersona === 'manager'
}

export function isSetupRoutePath(pathname: string): boolean {
  return SETUP_ROUTE_PATHS.some(
    (path) => pathname === path || pathname.startsWith(`${path}/`),
  )
}

export function canAccessSetupRoute(
  personaRole: PersonaRole | null | undefined,
  activePersona: ActivePersona,
  pathname: string,
): boolean {
  if (!isSetupRoutePath(pathname)) {
    return true
  }
  return canShowSetupHub(personaRole, activePersona)
}

export function filterSettingsSectionsForRole<T extends { id: string }>(
  sections: T[],
  personaRole: PersonaRole | null | undefined,
  activePersona: ActivePersona,
): T[] {
  if (canShowSetupHub(personaRole, activePersona)) {
    return sections
  }
  return sections.filter((section) =>
    PERSONAL_SETTINGS_SECTION_IDS.includes(section.id as PersonalSettingsSectionId),
  )
}
