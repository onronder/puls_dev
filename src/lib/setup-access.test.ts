import { describe, expect, it } from 'vitest'

import {
  canAccessSetupRoute,
  canShowSetupHub,
  filterSettingsSectionsForRole,
  isSetupAdmin,
} from '#/lib/setup-access'

const ALL_SECTIONS = [
  { id: 'accountSecurity' },
  { id: 'tenant' },
  { id: 'notifications' },
  { id: 'locale' },
  { id: 'theme' },
  { id: 'roleAccess' },
]

describe('isSetupAdmin', () => {
  it('allows hr_admin and superadmin only', () => {
    expect(isSetupAdmin('hr_admin')).toBe(true)
    expect(isSetupAdmin('superadmin')).toBe(true)
    expect(isSetupAdmin('manager')).toBe(false)
    expect(isSetupAdmin('employee')).toBe(false)
    expect(isSetupAdmin(null)).toBe(false)
  })
})

describe('canShowSetupHub', () => {
  it('shows setup hub for admin roles in manager mode only', () => {
    expect(canShowSetupHub('hr_admin', 'manager')).toBe(true)
    expect(canShowSetupHub('superadmin', 'manager')).toBe(true)
  })

  it('hides setup hub for admin roles in employee mode', () => {
    expect(canShowSetupHub('hr_admin', 'employee')).toBe(false)
    expect(canShowSetupHub('superadmin', 'employee')).toBe(false)
  })

  it('hides setup hub for non-admin roles in either mode', () => {
    expect(canShowSetupHub('manager', 'manager')).toBe(false)
    expect(canShowSetupHub('manager', 'employee')).toBe(false)
    expect(canShowSetupHub('employee', 'employee')).toBe(false)
    expect(canShowSetupHub('employee', 'manager')).toBe(false)
  })
})

describe('canAccessSetupRoute', () => {
  it('allows setup routes only for admin in manager mode', () => {
    expect(canAccessSetupRoute('hr_admin', 'manager', '/erp')).toBe(true)
    expect(canAccessSetupRoute('hr_admin', 'employee', '/erp')).toBe(false)
    expect(canAccessSetupRoute('manager', 'manager', '/erp')).toBe(false)
  })

  it('allows non-setup paths for everyone', () => {
    expect(canAccessSetupRoute('employee', 'employee', '/izin')).toBe(true)
  })
})

describe('filterSettingsSectionsForRole', () => {
  it('returns personal sections when setup hub is hidden', () => {
    const sections = filterSettingsSectionsForRole(ALL_SECTIONS, 'hr_admin', 'employee')
    expect(sections.map((section) => section.id)).toEqual([
      'accountSecurity',
      'notifications',
      'locale',
      'theme',
    ])
  })

  it('returns all sections when setup hub is visible', () => {
    const sections = filterSettingsSectionsForRole(ALL_SECTIONS, 'hr_admin', 'manager')
    expect(sections).toEqual(ALL_SECTIONS)
  })

  it('filters admin sections for line managers', () => {
    const sections = filterSettingsSectionsForRole(ALL_SECTIONS, 'manager', 'manager')
    expect(sections.map((section) => section.id)).toEqual([
      'accountSecurity',
      'notifications',
      'locale',
      'theme',
    ])
  })
})
