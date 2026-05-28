import { describe, expect, it } from 'vitest'

import {
  mapProfileEmployeeFields,
  resolveProfileDisplayName,
  resolveProfileStatusKey,
} from '#/lib/data/profile/mapping'

describe('resolveProfileDisplayName', () => {
  it('prefers full name over email', () => {
    expect(resolveProfileDisplayName('Ayşe Kaya', 'ayse@example.com')).toBe('Ayşe Kaya')
  })

  it('falls back to email when name is empty', () => {
    expect(resolveProfileDisplayName('', 'ayse@example.com')).toBe('ayse@example.com')
  })

  it('returns em dash when both are missing', () => {
    expect(resolveProfileDisplayName(null, null)).toBe('—')
  })
})

describe('mapProfileEmployeeFields', () => {
  it('maps employee row fields', () => {
    expect(
      mapProfileEmployeeFields({
        email: 'test@example.com',
        department_id: 'd1',
        position_id: 'p1',
        employment_status: 'active',
        persona_role: 'manager',
      }),
    ).toEqual({
      email: 'test@example.com',
      departmentId: 'd1',
      positionId: 'p1',
      employmentStatus: 'active',
      personaRole: 'manager',
    })
  })

  it('returns nulls for missing row', () => {
    expect(mapProfileEmployeeFields(null)).toEqual({
      email: null,
      departmentId: null,
      positionId: null,
      employmentStatus: null,
      personaRole: null,
    })
  })
})

describe('resolveProfileStatusKey', () => {
  it('maps active employment status', () => {
    expect(resolveProfileStatusKey('active')).toBe('profileSetup.status.active')
  })

  it('maps non-active employment status', () => {
    expect(resolveProfileStatusKey('terminated')).toBe('profileSetup.status.inactive')
    expect(resolveProfileStatusKey(null)).toBe('profileSetup.status.inactive')
  })
})
