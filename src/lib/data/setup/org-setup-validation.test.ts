import { describe, expect, it } from 'vitest'

import {
  isDepartmentFormDirty,
  isPositionFormDirty,
  normalizeOrgSetupCode,
  validateDepartmentForm,
  validatePositionForm,
} from '#/lib/data/setup/org-setup-validation'

describe('normalizeOrgSetupCode', () => {
  it('lowercases and slugifies code', () => {
    expect(normalizeOrgSetupCode('  HR Finance  ')).toBe('hr_finance')
    expect(normalizeOrgSetupCode('Field-Engineer')).toBe('field_engineer')
  })
})

describe('validateDepartmentForm', () => {
  it('accepts valid form', () => {
    const result = validateDepartmentForm({ name: 'Engineering', code: 'engineering' })
    expect(result.isValid).toBe(true)
    expect(result.normalized).toEqual({ name: 'Engineering', code: 'engineering' })
  })

  it('rejects blank fields and invalid code', () => {
    expect(validateDepartmentForm({ name: '', code: '' }).isValid).toBe(false)
    expect(validateDepartmentForm({ name: 'X', code: '9invalid' }).fieldErrors.code).toBeDefined()
  })
})

describe('validatePositionForm', () => {
  it('accepts valid form with optional department and norm', () => {
    const result = validatePositionForm(
      { name: 'Engineer', code: 'engineer', departmentId: null, normHeadcount: '2' },
      { allowedDepartmentIds: new Set(['d1']) },
    )
    expect(result.isValid).toBe(true)
    expect(result.normalized.normHeadcount).toBe(2)
  })

  it('rejects invalid department and norm bounds', () => {
    const invalidDept = validatePositionForm(
      { name: 'Engineer', code: 'engineer', departmentId: 'missing', normHeadcount: '' },
      { allowedDepartmentIds: new Set(['d1']) },
    )
    expect(invalidDept.fieldErrors.departmentId).toBeDefined()

    const invalidNorm = validatePositionForm({
      name: 'Engineer',
      code: 'engineer',
      departmentId: null,
      normHeadcount: '100001',
    })
    expect(invalidNorm.fieldErrors.normHeadcount).toBeDefined()
  })
})

describe('dirty helpers', () => {
  it('detects department form changes', () => {
    const baseline = { name: 'A', code: 'a' }
    expect(isDepartmentFormDirty({ name: 'A', code: 'a' }, baseline)).toBe(false)
    expect(isDepartmentFormDirty({ name: 'B', code: 'a' }, baseline)).toBe(true)
  })

  it('detects position form changes', () => {
    const baseline = {
      name: 'A',
      code: 'a',
      departmentId: null,
      normHeadcount: '1',
    }
    expect(
      isPositionFormDirty({ name: 'A', code: 'a', departmentId: null, normHeadcount: '2' }, baseline),
    ).toBe(true)
  })
})
