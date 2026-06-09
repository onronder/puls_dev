import type { ErrorEvent } from '@sentry/react'

import { DataAdapterError, isDataAdapterError } from '#/lib/data/errors'

type ObservabilityEnv = {
  MODE?: string
  VITE_APP_ENV?: string
  VITE_SENTRY_DSN?: string
  VITE_SENTRY_ENVIRONMENT?: string
  VITE_SENTRY_ALLOW_TEST_EVENT?: string
  VITE_SENTRY_RELEASE?: string
  VITE_SENTRY_TRACES_SAMPLE_RATE?: string
}

export type AppErrorContext = {
  operation: string
  area?:
    | 'app_route'
    | 'connector_setup'
    | 'connector_runtime'
    | 'route'
    | 'data_adapter'
    | 'auth'
    | 'unknown'
  route?: string
  providerId?: string | null
  source?: 'real' | 'demo'
}

const EMAIL_RE = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi
const UUID_RE = /\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b/gi
const JWT_RE = /\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b/g
const SECRET_ASSIGNMENT_RE =
  /\b(password|passwd|pwd|token|secret|api[_-]?key|apikey|authorization|bearer|database_url|dsn)=([^&\s]+)/gi

const SENSITIVE_QUERY_KEYS = new Set([
  'access_token',
  'apikey',
  'api_key',
  'authorization',
  'code',
  'database_url',
  'dsn',
  'email',
  'jwt',
  'key',
  'password',
  'refresh_token',
  'secret',
  'token',
])

let sentryStarted = false
let sentryModulePromise: Promise<typeof import('@sentry/react')> | null = null
const SENTRY_SETUP_CHECK_KEY = 'puls:sentry-setup-check'

function currentEnv(): ObservabilityEnv {
  return import.meta.env as ObservabilityEnv
}

function envName(env: ObservabilityEnv): string {
  return env.VITE_SENTRY_ENVIRONMENT ?? env.VITE_APP_ENV ?? env.MODE ?? 'development'
}

function traceSampleRate(env: ObservabilityEnv): number {
  const raw = env.VITE_SENTRY_TRACES_SAMPLE_RATE
  if (!raw) return 0

  const parsed = Number(raw)
  if (!Number.isFinite(parsed)) return 0
  return Math.min(Math.max(parsed, 0), 1)
}

export function isObservabilityConfigured(env: ObservabilityEnv = currentEnv()): boolean {
  return Boolean(env.VITE_SENTRY_DSN?.trim())
}

function loadBrowserSentry(): Promise<typeof import('@sentry/react')> {
  if (import.meta.env.SSR) {
    return Promise.reject(new Error('Sentry browser SDK is not available during SSR'))
  }

  sentryModulePromise ??= import('@sentry/react')
  return sentryModulePromise
}

export function isSentrySetupCheckRequested(env: ObservabilityEnv, rawUrl: string): boolean {
  if (env.VITE_SENTRY_ALLOW_TEST_EVENT !== 'true') {
    return false
  }

  try {
    const url = new URL(rawUrl)
    return url.searchParams.get('sentry_setup_check') === '1'
  } catch {
    return false
  }
}

function captureSetupCheckOnce(Sentry: typeof import('@sentry/react'), env: ObservabilityEnv): void {
  if (
    typeof window === 'undefined' ||
    !isSentrySetupCheckRequested(env, window.location.href) ||
    sessionStorage.getItem(SENTRY_SETUP_CHECK_KEY) === 'sent'
  ) {
    return
  }

  sessionStorage.setItem(SENTRY_SETUP_CHECK_KEY, 'sent')
  Sentry.withScope((scope) => {
    scope.setTag('operation', 'sentry_setup_check')
    scope.setTag('area', 'route')
    scope.setTag('route', window.location.pathname)
    Sentry.captureException(new Error('PULS Sentry setup check'))
  })
}

export function redactSensitiveText(value: string): string {
  return value
    .replace(EMAIL_RE, '[email]')
    .replace(UUID_RE, '[uuid]')
    .replace(JWT_RE, '[token]')
    .replace(SECRET_ASSIGNMENT_RE, '$1=[Filtered]')
}

export function sanitizeUrl(rawUrl: string): string {
  try {
    const url = new URL(
      rawUrl,
      typeof window === 'undefined' ? 'https://puls.local' : window.location.origin,
    )
    for (const key of [...url.searchParams.keys()]) {
      if (SENSITIVE_QUERY_KEYS.has(key.toLowerCase())) {
        url.searchParams.set(key, '[Filtered]')
      } else {
        url.searchParams.set(key, redactSensitiveText(url.searchParams.get(key) ?? ''))
      }
    }
    url.hash = ''
    return redactSensitiveText(url.toString()).replaceAll('%5BFiltered%5D', '[Filtered]')
  } catch {
    return redactSensitiveText(rawUrl)
  }
}

function sanitizeRecord(
  record: Record<string, unknown> | undefined,
): Record<string, string> | undefined {
  if (!record) return record

  const next: Record<string, string> = {}
  for (const [key, value] of Object.entries(record)) {
    const lower = key.toLowerCase()
    if (SENSITIVE_QUERY_KEYS.has(lower) || lower.includes('password') || lower.includes('token')) {
      next[key] = '[Filtered]'
    } else if (typeof value === 'string') {
      next[key] = redactSensitiveText(value)
    } else {
      next[key] = redactSensitiveText(String(value))
    }
  }
  return next
}

export function sanitizeSentryEvent(event: ErrorEvent): ErrorEvent {
  const next: ErrorEvent = {
    ...event,
    message: typeof event.message === 'string' ? redactSensitiveText(event.message) : event.message,
    tags: sanitizeRecord(event.tags),
    type: undefined,
    user: undefined,
  }

  if (event.request) {
    next.request = {
      ...event.request,
      cookies: undefined,
      headers: sanitizeRecord(event.request.headers),
      query_string:
        typeof event.request.query_string === 'string'
          ? redactSensitiveText(event.request.query_string)
          : event.request.query_string,
      url: event.request.url ? sanitizeUrl(event.request.url) : event.request.url,
    }
  }

  if (event.exception?.values) {
    next.exception = {
      ...event.exception,
      values: event.exception.values.map((value) => ({
        ...value,
        value: typeof value.value === 'string' ? redactSensitiveText(value.value) : value.value,
      })),
    }
  }

  if (event.breadcrumbs) {
    next.breadcrumbs = event.breadcrumbs.map((breadcrumb) => ({
      ...breadcrumb,
      message:
        typeof breadcrumb.message === 'string'
          ? redactSensitiveText(breadcrumb.message)
          : breadcrumb.message,
      data: sanitizeRecord(breadcrumb.data),
    }))
  }

  return next
}

export function initObservability(env: ObservabilityEnv = currentEnv()): boolean {
  if (
    import.meta.env.SSR ||
    sentryStarted ||
    typeof window === 'undefined' ||
    !isObservabilityConfigured(env)
  ) {
    return false
  }

  sentryStarted = true
  void loadBrowserSentry()
    .then((Sentry) => {
      Sentry.init({
        dsn: env.VITE_SENTRY_DSN,
        environment: envName(env),
        release: env.VITE_SENTRY_RELEASE,
        sendDefaultPii: false,
        tracesSampleRate: traceSampleRate(env),
        beforeSend: (event) => sanitizeSentryEvent(event),
      })
      captureSetupCheckOnce(Sentry, env)
    })
    .catch(() => {
      sentryStarted = false
    })

  return true
}

export function normalizeCapturedError(error: unknown, operation: string): Error {
  if (error instanceof Error) return error
  if (isDataAdapterError(error)) return error

  return new DataAdapterError({
    code: 'unknown',
    message: 'Unknown application error',
    source: 'adapter',
    operation,
  })
}

export function captureAppError(error: unknown, context: AppErrorContext): void {
  if (import.meta.env.SSR || typeof window === 'undefined' || !isObservabilityConfigured()) {
    return
  }

  const normalized = normalizeCapturedError(error, context.operation)
  const adapter = isDataAdapterError(normalized) ? normalized : null

  void loadBrowserSentry().then((Sentry) => {
    Sentry.withScope((scope) => {
      scope.setTag('operation', context.operation)
      scope.setTag('area', context.area ?? 'unknown')
      if (context.route) scope.setTag('route', context.route)
      if (context.providerId) scope.setTag('provider', context.providerId)
      if (context.source) scope.setTag('source', context.source)
      if (adapter) {
        scope.setTag('adapter_source', adapter.source)
        scope.setTag('adapter_code', adapter.code)
        if (adapter.schema) scope.setTag('schema', adapter.schema)
        if (adapter.table) scope.setTag('table', adapter.table)
      }

      Sentry.captureException(normalized)
    })
  })
}
