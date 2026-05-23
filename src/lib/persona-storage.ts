import type { ActivePersona } from '#/lib/auth'
import { isDualPersonaRole } from '#/lib/persona'
import type { PersonaRole } from '#/lib/supabase'

const STORAGE_PREFIX = 'puls:activePersona:'

function storageKey(userId: string): string {
  return `${STORAGE_PREFIX}${userId}`
}

function isActivePersona(value: unknown): value is ActivePersona {
  return value === 'employee' || value === 'manager'
}

export function readActivePersona(
  userId: string,
  personaRole: PersonaRole | null | undefined,
): ActivePersona {
  if (!isDualPersonaRole(personaRole)) {
    return 'employee'
  }

  if (typeof window === 'undefined') {
    return 'manager'
  }

  try {
    const stored = localStorage.getItem(storageKey(userId))
    if (isActivePersona(stored)) {
      return stored
    }
  } catch {
    // ignore storage errors
  }

  return 'manager'
}

export function writeActivePersona(userId: string, persona: ActivePersona): void {
  if (typeof window === 'undefined') {
    return
  }

  try {
    localStorage.setItem(storageKey(userId), persona)
  } catch {
    // ignore storage errors
  }
}

export function readActivePersonaFromStorage(userId: string): ActivePersona | null {
  if (typeof window === 'undefined') {
    return null
  }

  try {
    const stored = localStorage.getItem(storageKey(userId))
    return isActivePersona(stored) ? stored : null
  } catch {
    return null
  }
}
