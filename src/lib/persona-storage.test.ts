import { beforeEach, describe, expect, it } from 'vitest'

import { readActivePersona, writeActivePersona } from '#/lib/persona-storage'

const USER_ID = 'user-123'

describe('readActivePersona', () => {
  beforeEach(() => {
    localStorage.clear()
  })

  it('returns employee for non-dual roles regardless of storage', () => {
    writeActivePersona(USER_ID, 'manager')
    expect(readActivePersona(USER_ID, 'employee')).toBe('employee')
  })

  it('defaults dual role users to manager when nothing stored', () => {
    expect(readActivePersona(USER_ID, 'hr_admin')).toBe('manager')
    expect(readActivePersona(USER_ID, 'superadmin')).toBe('manager')
  })

  it('restores persisted persona for dual role users', () => {
    writeActivePersona(USER_ID, 'employee')
    expect(readActivePersona(USER_ID, 'hr_admin')).toBe('employee')
    expect(readActivePersona(USER_ID, 'superadmin')).toBe('employee')

    writeActivePersona(USER_ID, 'manager')
    expect(readActivePersona(USER_ID, 'hr_admin')).toBe('manager')
    expect(readActivePersona(USER_ID, 'superadmin')).toBe('manager')
  })
})

describe('writeActivePersona', () => {
  beforeEach(() => {
    localStorage.clear()
  })

  it('scopes storage by user id', () => {
    writeActivePersona('user-a', 'employee')
    writeActivePersona('user-b', 'manager')

    expect(readActivePersona('user-a', 'hr_admin')).toBe('employee')
    expect(readActivePersona('user-b', 'hr_admin')).toBe('manager')
  })
})
