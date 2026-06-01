import { describe, expect, it } from 'vitest'

import { buildRedirectPath, parseRedirectForNavigate, resolveSafeRedirect } from '#/lib/safe-redirect'

describe('resolveSafeRedirect', () => {
  it('returns fallback for empty or unsafe values', () => {
    expect(resolveSafeRedirect(undefined)).toBe('/dashboard')
    expect(resolveSafeRedirect('')).toBe('/dashboard')
    expect(resolveSafeRedirect('https://evil.com/phish')).toBe('/dashboard')
    expect(resolveSafeRedirect('//evil.com/path')).toBe('/dashboard')
    expect(resolveSafeRedirect('dashboard')).toBe('/dashboard')
    expect(resolveSafeRedirect('/login')).toBe('/dashboard')
    expect(resolveSafeRedirect('/login?redirect=/dashboard')).toBe('/dashboard')
  })

  it('allows internal paths', () => {
    expect(resolveSafeRedirect('/dashboard')).toBe('/dashboard')
    expect(resolveSafeRedirect('/izin')).toBe('/izin')
    expect(resolveSafeRedirect('/ayarlar')).toBe('/ayarlar')
    expect(resolveSafeRedirect('/izin?tab=mine')).toBe('/izin?tab=mine')
  })

  it('parses redirect for router navigation', () => {
    expect(parseRedirectForNavigate('/dashboard')).toEqual({ to: '/dashboard' })
    expect(parseRedirectForNavigate('/izin?tab=mine')).toEqual({
      to: '/izin',
      search: { tab: 'mine' },
    })
  })
})

describe('buildRedirectPath', () => {
  it('combines pathname and search', () => {
    expect(buildRedirectPath('/izin')).toBe('/izin')
    expect(buildRedirectPath('/izin', '?tab=mine')).toBe('/izin?tab=mine')
  })

  it('does not nest login redirects', () => {
    expect(buildRedirectPath('/login', '?redirect=/dashboard')).toBe('/dashboard')
    expect(buildRedirectPath('/login', '?redirect=/login?redirect=/dashboard')).toBe('/dashboard')
  })
})
