import { describe, expect, it } from 'vitest'

import { DataAdapterError } from '#/lib/data/errors'
import {
  isCompanyProfileFormDirty,
  mapCompanyProfileMutationError,
  normalizeCompanyProfileInput,
  type CompanyProfileMutationInput,
} from '#/lib/data/setup/company'

const baseline: CompanyProfileMutationInput = {
  displayName: 'Puls Sanayi',
  industry: 'Üretim',
  locale: 'tr-TR',
  timezone: 'Europe/Istanbul',
}

describe('normalizeCompanyProfileInput', () => {
  it('trims display values and stores empty sector as null', () => {
    expect(
      normalizeCompanyProfileInput({
        displayName: '  Puls Sanayi  ',
        industry: '   ',
        locale: ' tr-TR ',
        timezone: ' Europe/Istanbul ',
      }),
    ).toEqual({
      displayName: 'Puls Sanayi',
      industry: null,
      locale: 'tr-TR',
      timezone: 'Europe/Istanbul',
    })
  })
})

describe('isCompanyProfileFormDirty', () => {
  it('ignores whitespace-only changes', () => {
    expect(
      isCompanyProfileFormDirty(baseline, {
        ...baseline,
        displayName: ' Puls Sanayi ',
        industry: ' Üretim ',
      }),
    ).toBe(false)
  })

  it('detects profile field changes', () => {
    expect(isCompanyProfileFormDirty(baseline, { ...baseline, timezone: 'UTC' })).toBe(true)
  })
})

describe('mapCompanyProfileMutationError', () => {
  it('maps server error codes to company setup toast keys', () => {
    const error = new DataAdapterError({
      code: 'PULS_COMPANY_PROFILE_INVALID_TIMEZONE',
      message: 'bad timezone',
      source: 'rpc',
      operation: 'updateCompanyProfile',
    })

    expect(mapCompanyProfileMutationError(error)).toEqual({
      code: 'PULS_COMPANY_PROFILE_INVALID_TIMEZONE',
      toastKey: 'companySetup.edit.errors.invalidTimezone',
    })
  })
})
