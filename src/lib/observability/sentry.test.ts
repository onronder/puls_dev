import { describe, expect, it } from 'vitest'

import {
  isObservabilityConfigured,
  redactSensitiveText,
  sanitizeSentryEvent,
  sanitizeUrl,
} from '#/lib/observability/sentry'

describe('observability sanitization', () => {
  it('keeps Sentry disabled until a DSN is configured', () => {
    expect(isObservabilityConfigured({})).toBe(false)
    expect(
      isObservabilityConfigured({ VITE_SENTRY_DSN: 'https://public@example.ingest.sentry.io/1' }),
    ).toBe(true)
  })

  it('redacts sensitive text without hiding safe product context', () => {
    const text =
      'admin@puls.demo failed with token=abc123 and tenant a0000001-0001-4001-8001-000000000001'

    expect(redactSensitiveText(text)).toBe('[email] failed with token=[Filtered] and tenant [uuid]')
  })

  it('sanitizes URL query values and removes fragments', () => {
    expect(sanitizeUrl('https://puls.app/erp?provider=canias&token=secret#frag')).toBe(
      'https://puls.app/erp?provider=canias&token=[Filtered]',
    )
  })

  it('removes user identity and request secrets from Sentry events', () => {
    const event = sanitizeSentryEvent({
      type: undefined,
      message: 'Error for calisan@puls.demo',
      user: { id: 'user-1', email: 'calisan@puls.demo' },
      request: {
        url: 'https://puls.app/erp?email=calisan%40puls.demo&provider=canias',
        headers: {
          Authorization: 'Bearer abc',
          safe_header: 'connector setup',
        },
      },
      exception: {
        values: [
          { type: 'Error', value: 'password=cleartext user b0000003-0000-4000-8000-000000000001' },
        ],
      },
      breadcrumbs: [{ message: 'clicked admin@puls.demo', data: { token: 'abc', route: '/erp' } }],
    })

    expect(event.user).toBeUndefined()
    expect(event.message).toBe('Error for [email]')
    expect(event.request?.url).toBe('https://puls.app/erp?email=[Filtered]&provider=canias')
    expect(event.request?.headers?.Authorization).toBe('[Filtered]')
    expect(event.request?.headers?.safe_header).toBe('connector setup')
    expect(event.exception?.values?.[0]?.value).toBe('password=[Filtered] user [uuid]')
    expect(event.breadcrumbs?.[0]?.message).toBe('clicked [email]')
    expect(event.breadcrumbs?.[0]?.data?.token).toBe('[Filtered]')
  })
})
