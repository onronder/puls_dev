export type ExpenseCategoryFormFields = {
  name: string
  code: string
  monthlyLimit: string
  receiptRequiredOver: string
  erpAccountCode: string
}

export type ExpenseCategoryFieldKey = keyof ExpenseCategoryFormFields

export type NormalizedExpenseCategoryForm = {
  name: string
  code: string
  monthlyLimit: number
  receiptRequiredOver: number
  erpAccountCode: string | null
}

export const EXPENSE_CATEGORY_VALIDATION = {
  nameRequired: 'expenseCategorySetup.validation.nameRequired',
  codeRequired: 'expenseCategorySetup.validation.codeRequired',
  codeInvalid: 'expenseCategorySetup.validation.codeInvalid',
  monthlyLimitRequired: 'expenseCategorySetup.validation.monthlyLimitRequired',
  monthlyLimitInvalid: 'expenseCategorySetup.validation.monthlyLimitInvalid',
  receiptThresholdInvalid: 'expenseCategorySetup.validation.receiptThresholdInvalid',
  erpAccountCodeInvalid: 'expenseCategorySetup.validation.erpAccountCodeInvalid',
} as const

const CATEGORY_CODE_SLUG_REGEX = /^[a-z][a-z0-9_]{1,63}$/
const ERP_ACCOUNT_CODE_REGEX = /^[0-9]{3}(\.[0-9]{2})?$/

export function normalizeCategoryCode(code: string): string {
  return code.trim().toLowerCase().replace(/\s+/g, '_')
}

function parseNonNegativeNumber(raw: string): number {
  const trimmed = raw.trim()
  if (trimmed === '') return NaN
  return Number(trimmed)
}

export function normalizeExpenseCategoryFormInput(
  form: ExpenseCategoryFormFields,
): NormalizedExpenseCategoryForm {
  const receiptRaw = form.receiptRequiredOver.trim()
  const monthlyRaw = form.monthlyLimit.trim()
  const erpAccountCodeRaw = form.erpAccountCode.trim()

  return {
    name: form.name.trim(),
    code: normalizeCategoryCode(form.code),
    monthlyLimit: parseNonNegativeNumber(monthlyRaw),
    receiptRequiredOver: receiptRaw === '' ? 0 : Number(receiptRaw),
    erpAccountCode: erpAccountCodeRaw ? erpAccountCodeRaw : null,
  }
}

export function validateExpenseCategoryForm(form: ExpenseCategoryFormFields): {
  fieldErrors: Partial<Record<ExpenseCategoryFieldKey, string>>
  isValid: boolean
  normalized: NormalizedExpenseCategoryForm
} {
  const fieldErrors: Partial<Record<ExpenseCategoryFieldKey, string>> = {}
  const normalized = normalizeExpenseCategoryFormInput(form)

  if (!normalized.name) {
    fieldErrors.name = EXPENSE_CATEGORY_VALIDATION.nameRequired
  }

  if (!form.code.trim()) {
    fieldErrors.code = EXPENSE_CATEGORY_VALIDATION.codeRequired
  } else if (!CATEGORY_CODE_SLUG_REGEX.test(normalized.code)) {
    fieldErrors.code = EXPENSE_CATEGORY_VALIDATION.codeInvalid
  }

  if (!form.monthlyLimit.trim()) {
    fieldErrors.monthlyLimit = EXPENSE_CATEGORY_VALIDATION.monthlyLimitRequired
  } else if (!Number.isFinite(normalized.monthlyLimit) || normalized.monthlyLimit < 0) {
    fieldErrors.monthlyLimit = EXPENSE_CATEGORY_VALIDATION.monthlyLimitInvalid
  }

  const receiptRaw = form.receiptRequiredOver.trim()
  if (
    receiptRaw !== '' &&
    (!Number.isFinite(normalized.receiptRequiredOver) || normalized.receiptRequiredOver < 0)
  ) {
    fieldErrors.receiptRequiredOver = EXPENSE_CATEGORY_VALIDATION.receiptThresholdInvalid
  }

  if (normalized.erpAccountCode && !ERP_ACCOUNT_CODE_REGEX.test(normalized.erpAccountCode)) {
    fieldErrors.erpAccountCode = EXPENSE_CATEGORY_VALIDATION.erpAccountCodeInvalid
  }

  return {
    fieldErrors,
    isValid: Object.keys(fieldErrors).length === 0,
    normalized,
  }
}

export function isExpenseCategoryFormDirty(
  current: ExpenseCategoryFormFields,
  baseline: ExpenseCategoryFormFields,
): boolean {
  return (
    current.name !== baseline.name ||
    current.code !== baseline.code ||
    current.monthlyLimit !== baseline.monthlyLimit ||
    current.receiptRequiredOver !== baseline.receiptRequiredOver ||
    current.erpAccountCode !== baseline.erpAccountCode
  )
}
