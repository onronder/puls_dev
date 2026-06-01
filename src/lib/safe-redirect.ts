const DEFAULT_REDIRECT = '/dashboard'

/** Accept only same-app internal paths; block open redirects. */
export function resolveSafeRedirect(
  input: string | undefined,
  fallback = DEFAULT_REDIRECT,
): string {
  if (!input?.trim()) {
    return fallback
  }

  let path = input.trim()

  if (path.includes('\\') || path.startsWith('//')) {
    return fallback
  }

  if (path.includes('://')) {
    if (typeof window === 'undefined') {
      return fallback
    }

    try {
      const url = new URL(path)
      if (url.origin !== window.location.origin) {
        return fallback
      }
      path = `${url.pathname}${url.search}`
    } catch {
      return fallback
    }
  }

  if (!path.startsWith('/')) {
    return fallback
  }

  if (path === '/login' || path.startsWith('/login?')) {
    return fallback
  }

  return path
}

export function buildRedirectPath(pathname: string, searchStr?: string): string {
  return resolveSafeRedirect(searchStr ? `${pathname}${searchStr}` : pathname)
}

export function parseRedirectForNavigate(
  input: string | undefined,
  fallback = DEFAULT_REDIRECT,
): { to: string; search?: Record<string, string> } {
  const path = resolveSafeRedirect(input, fallback)
  const queryIndex = path.indexOf('?')

  if (queryIndex === -1) {
    return { to: path }
  }

  const to = path.slice(0, queryIndex)
  const search = Object.fromEntries(new URLSearchParams(path.slice(queryIndex + 1)))
  return { to, search }
}
