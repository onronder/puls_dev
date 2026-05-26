import { describe, expect, it } from 'vitest'

import {
  EXPENSE_CATEGORY_VALIDATION,
  isExpenseCategoryFormDirty,
  normalizeCategoryCode,
  normalizeExpenseCategoryFormInput,
  parseExpenseCategoryAmount,
  validateExpenseCategoryForm,
  type ExpenseCategoryFormFields,
} from '#/lib/data/setup/expense-category-validation'

const EMPTY_FORM: ExpenseCategoryFormFields = {
  name: '',
  code: '',
  monthlyLimit: '',
  receiptRequiredOver: '0',
  erpAccountCode: '',
}

const VALID_FORM: ExpenseCategoryFormFields = {
  name: 'Seyahat',
  code: 'travel',
  monthlyLimit: '15000',
  receiptRequiredOver: '500',
  erpAccountCode: '770.01',
}

describe('normalizeCategoryCode', () => {
  it('lowercases, trims, and replaces spaces with underscores', () => {
    expect(normalizeCategoryCode(' Orn Seyahat ')).toBe('orn_seyahat')
  })
})

describe('parseExpenseCategoryAmount', () => {
  it('parses TR dot thousands without corrupting value', () => {
    expect(parseExpenseCategoryAmount('15.000')).toBe(15000)
    expect(parseExpenseCategoryAmount('1.500')).toBe(1500)
  })

  it('parses plain EN numbers', () => {
    expect(parseExpenseCategoryAmount('15000')).toBe(15000)
  })

  it('rejects EN comma thousands to avoid silent 15,000 → 15', () => {
    expect(parseExpenseCategoryAmount('15,000')).toBeNaN()
  })

  it('still allows decimal comma amounts', () => {
    expect(parseExpenseCategoryAmount('15,50')).toBe(15.5)
  })
})

describe('normalizeExpenseCategoryFormInput', () => {
  it('normalizes empty receipt threshold to 0', () => {
    const normalized = normalizeExpenseCategoryFormInput({
      ...VALID_FORM,
      receiptRequiredOver: '',
    })
    expect(normalized.receiptRequiredOver).toBe(0)
  })

  it('returns null erp account code when blank', () => {
    const normalized = normalizeExpenseCategoryFormInput({
      ...VALID_FORM,
      erpAccountCode: '  ',
    })
    expect(normalized.erpAccountCode).toBeNull()
  })

  it('parses Turkish thousands separator for monthly limit', () => {
    const normalized = normalizeExpenseCategoryFormInput({
      ...VALID_FORM,
      monthlyLimit: '15.000',
    })
    expect(normalized.monthlyLimit).toBe(15000)
  })

  it('parses Turkish thousands separator for receipt threshold', () => {
    const normalized = normalizeExpenseCategoryFormInput({
      ...VALID_FORM,
      receiptRequiredOver: '1.500',
    })
    expect(normalized.receiptRequiredOver).toBe(1500)
  })

  it('parses plain monthly limit without separators', () => {
    const normalized = normalizeExpenseCategoryFormInput({
      ...VALID_FORM,
      monthlyLimit: '15000',
    })
    expect(normalized.monthlyLimit).toBe(15000)
  })

  it('does not silently normalize EN comma thousands', () => {
    const normalized = normalizeExpenseCategoryFormInput({
      ...VALID_FORM,
      monthlyLimit: '15,000',
    })
    expect(normalized.monthlyLimit).toBeNaN()
  })
})

describe('validateExpenseCategoryForm', () => {
  it('returns i18n keys without requiring a translator', () => {
    const result = validateExpenseCategoryForm(EMPTY_FORM)
    expect(result.isValid).toBe(false)
    expect(result.fieldErrors.name).toBe(EXPENSE_CATEGORY_VALIDATION.nameRequired)
    expect(result.fieldErrors.code).toBe(EXPENSE_CATEGORY_VALIDATION.codeRequired)
    expect(result.fieldErrors.monthlyLimit).toBe(EXPENSE_CATEGORY_VALIDATION.monthlyLimitRequired)
  })

  it('treats empty monthly limit as invalid', () => {
    const result = validateExpenseCategoryForm({
      ...VALID_FORM,
      monthlyLimit: '',
    })
    expect(result.fieldErrors.monthlyLimit).toBe(EXPENSE_CATEGORY_VALIDATION.monthlyLimitRequired)
  })

  it('accepts empty receipt threshold as zero', () => {
    const result = validateExpenseCategoryForm({
      ...VALID_FORM,
      receiptRequiredOver: '',
    })
    expect(result.isValid).toBe(true)
    expect(result.normalized.receiptRequiredOver).toBe(0)
  })

  it('rejects negative receipt threshold', () => {
    const result = validateExpenseCategoryForm({
      ...VALID_FORM,
      receiptRequiredOver: '-1',
    })
    expect(result.fieldErrors.receiptRequiredOver).toBe(
      EXPENSE_CATEGORY_VALIDATION.receiptThresholdInvalid,
    )
  })

  it('rejects invalid slug codes', () => {
    const result = validateExpenseCategoryForm({
      ...VALID_FORM,
      code: '1invalid',
    })
    expect(result.fieldErrors.code).toBe(EXPENSE_CATEGORY_VALIDATION.codeInvalid)
  })

  it('rejects invalid erp account code format', () => {
    const result = validateExpenseCategoryForm({
      ...VALID_FORM,
      erpAccountCode: 'ABC',
    })
    expect(result.fieldErrors.erpAccountCode).toBe(
      EXPENSE_CATEGORY_VALIDATION.erpAccountCodeInvalid,
    )
  })

  it('passes a valid form', () => {
    const result = validateExpenseCategoryForm(VALID_FORM)
    expect(result.isValid).toBe(true)
    expect(result.fieldErrors).toEqual({})
    expect(result.normalized.monthlyLimit).toBe(15000)
  })

  it('accepts Turkish-formatted monthly limit input', () => {
    const result = validateExpenseCategoryForm({
      ...VALID_FORM,
      monthlyLimit: '15.000',
    })
    expect(result.isValid).toBe(true)
    expect(result.normalized.monthlyLimit).toBe(15000)
  })

  it('accepts plain monthly limit input', () => {
    const result = validateExpenseCategoryForm({
      ...VALID_FORM,
      monthlyLimit: '15000',
    })
    expect(result.isValid).toBe(true)
    expect(result.normalized.monthlyLimit).toBe(15000)
  })

  it('rejects EN comma thousands for monthly limit', () => {
    const result = validateExpenseCategoryForm({
      ...VALID_FORM,
      monthlyLimit: '15,000',
    })
    expect(result.isValid).toBe(false)
    expect(result.fieldErrors.monthlyLimit).toBe(EXPENSE_CATEGORY_VALIDATION.monthlyLimitInvalid)
    expect(result.normalized.monthlyLimit).toBeNaN()
  })

  it('rejects EN comma thousands for receipt threshold', () => {
    const result = validateExpenseCategoryForm({
      ...VALID_FORM,
      receiptRequiredOver: '1,500',
    })
    expect(result.isValid).toBe(false)
    expect(result.fieldErrors.receiptRequiredOver).toBe(
      EXPENSE_CATEGORY_VALIDATION.receiptThresholdInvalid,
    )
  })
})

describe('isExpenseCategoryFormDirty', () => {
  it('detects field changes against baseline', () => {
    expect(isExpenseCategoryFormDirty(VALID_FORM, VALID_FORM)).toBe(false)
    expect(
      isExpenseCategoryFormDirty({ ...VALID_FORM, monthlyLimit: '16000' }, VALID_FORM),
    ).toBe(true)
  })
})
