import { describe, expect, it } from 'vitest'

import {
  isLeaveTypeFormDirty,
  normalizeLeaveTypeCode,
  validateLeaveTypeForm,
  type LeaveTypeFormFields,
} from '#/lib/data/setup/leave-type-validation'

const VALID_FORM: LeaveTypeFormFields = {
  name: 'Annual leave',
  code: 'annual_extra',
  defaultEntitlementDays: '20',
  requiresDocument: false,
  carryOverAllowed: true,
  maxCarryOverDays: '5',
  approvalPolicyId: null,
}

describe('validateLeaveTypeForm', () => {
  it('accepts a valid form', () => {
    const result = validateLeaveTypeForm(VALID_FORM)
    expect(result.isValid).toBe(true)
    expect(result.fieldErrors).toEqual({})
    expect(result.normalized).toEqual({
      name: 'Annual leave',
      code: 'annual_extra',
      defaultEntitlementDays: 20,
      requiresDocument: false,
      carryOverAllowed: true,
      maxCarryOverDays: 5,
      approvalPolicyId: null,
    })
  })

  it('accepts half-day entitlement as plain decimal', () => {
    const result = validateLeaveTypeForm({
      ...VALID_FORM,
      defaultEntitlementDays: '1.5',
    })
    expect(result.isValid).toBe(true)
    expect(result.normalized.defaultEntitlementDays).toBe(1.5)
  })

  it('rejects comma decimal entitlement', () => {
    const result = validateLeaveTypeForm({
      ...VALID_FORM,
      defaultEntitlementDays: '1,5',
    })
    expect(result.isValid).toBe(false)
    expect(result.fieldErrors.defaultEntitlementDays).toBe(
      'leaveTypeSetup.validation.entitlementInvalid',
    )
  })

  it('requires name and code', () => {
    const result = validateLeaveTypeForm({
      ...VALID_FORM,
      name: '   ',
      code: '   ',
    })
    expect(result.isValid).toBe(false)
    expect(result.fieldErrors.name).toBe('leaveTypeSetup.validation.nameRequired')
    expect(result.fieldErrors.code).toBe('leaveTypeSetup.validation.codeRequired')
  })

  it('normalizes code slug on client', () => {
    expect(normalizeLeaveTypeCode(' Annual Extra ')).toBe('annual_extra')
    const result = validateLeaveTypeForm({
      ...VALID_FORM,
      code: ' Annual Extra ',
    })
    expect(result.normalized.code).toBe('annual_extra')
  })

  it('rejects invalid code slug', () => {
    const result = validateLeaveTypeForm({
      ...VALID_FORM,
      code: 'demo-bad',
    })
    expect(result.isValid).toBe(false)
    expect(result.fieldErrors.code).toBe('leaveTypeSetup.validation.codeInvalid')
  })

  it('rejects negative and over-limit entitlement', () => {
    expect(
      validateLeaveTypeForm({ ...VALID_FORM, defaultEntitlementDays: '-1' }).fieldErrors
        .defaultEntitlementDays,
    ).toBe('leaveTypeSetup.validation.entitlementInvalid')
    expect(
      validateLeaveTypeForm({ ...VALID_FORM, defaultEntitlementDays: '366' }).fieldErrors
        .defaultEntitlementDays,
    ).toBe('leaveTypeSetup.validation.entitlementInvalid')
  })

  it('rejects carry-over violations', () => {
    expect(
      validateLeaveTypeForm({ ...VALID_FORM, maxCarryOverDays: '-1' }).fieldErrors
        .maxCarryOverDays,
    ).toBe('leaveTypeSetup.validation.carryOverInvalid')

    expect(
      validateLeaveTypeForm({
        ...VALID_FORM,
        carryOverAllowed: false,
        maxCarryOverDays: '3',
      }).fieldErrors.maxCarryOverDays,
    ).toBe('leaveTypeSetup.validation.carryOverInvalid')
  })
})

describe('isLeaveTypeFormDirty', () => {
  it('detects field changes including approval policy', () => {
    expect(isLeaveTypeFormDirty(VALID_FORM, VALID_FORM)).toBe(false)
    expect(
      isLeaveTypeFormDirty({ ...VALID_FORM, name: 'Changed' }, VALID_FORM),
    ).toBe(true)
    expect(
      isLeaveTypeFormDirty(
        { ...VALID_FORM, approvalPolicyId: 'policy-1' },
        VALID_FORM,
      ),
    ).toBe(true)
  })
})
