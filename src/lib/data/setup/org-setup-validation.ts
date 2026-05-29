export type DepartmentFormFields = {
  name: string
  code: string
}

export type PositionFormFields = {
  name: string
  code: string
  departmentId: string | null
  normHeadcount: string
}

export type DepartmentFieldKey = 'name' | 'code'
export type PositionFieldKey = 'name' | 'code' | 'departmentId' | 'normHeadcount'

export type NormalizedDepartmentForm = {
  name: string
  code: string
}

export type NormalizedPositionForm = {
  name: string
  code: string
  departmentId: string | null
  normHeadcount: number | null
}

export const ORG_SETUP_VALIDATION = {
  nameRequired: 'orgSetupCrud.validation.nameRequired',
  codeRequired: 'orgSetupCrud.validation.codeRequired',
  codeInvalid: 'orgSetupCrud.validation.codeInvalid',
  duplicateCode: 'orgSetupCrud.validation.duplicateCode',
  departmentInvalid: 'orgSetupCrud.validation.departmentInvalid',
  normInvalid: 'orgSetupCrud.validation.normInvalid',
  sourceReadOnly: 'orgSetupCrud.validation.sourceReadOnly',
  generic: 'orgSetupCrud.validation.generic',
} as const

const ORG_SETUP_CODE_SLUG_REGEX = /^[a-z][a-z0-9_]{1,63}$/

export function normalizeOrgSetupText(value: string): string {
  return value.trim()
}

export function normalizeOrgSetupCode(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/[\s-]+/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_+|_+$/g, '')
}

export function parseOrgSetupNormHeadcount(raw: string): number | null {
  const trimmed = raw.trim()
  if (trimmed === '') return null
  const parsed = Number(trimmed)
  if (!Number.isFinite(parsed)) return NaN
  return parsed
}

export function normalizeDepartmentFormInput(form: DepartmentFormFields): NormalizedDepartmentForm {
  return {
    name: normalizeOrgSetupText(form.name),
    code: normalizeOrgSetupCode(form.code),
  }
}

export function normalizePositionFormInput(form: PositionFormFields): NormalizedPositionForm {
  return {
    name: normalizeOrgSetupText(form.name),
    code: normalizeOrgSetupCode(form.code),
    departmentId: form.departmentId?.trim() ? form.departmentId.trim() : null,
    normHeadcount: parseOrgSetupNormHeadcount(form.normHeadcount),
  }
}

export function validateDepartmentForm(form: DepartmentFormFields): {
  fieldErrors: Partial<Record<DepartmentFieldKey, string>>
  isValid: boolean
  normalized: NormalizedDepartmentForm
} {
  const normalized = normalizeDepartmentFormInput(form)
  const fieldErrors: Partial<Record<DepartmentFieldKey, string>> = {}

  if (!normalized.name) {
    fieldErrors.name = ORG_SETUP_VALIDATION.nameRequired
  }
  if (!normalized.code) {
    fieldErrors.code = ORG_SETUP_VALIDATION.codeRequired
  } else if (!ORG_SETUP_CODE_SLUG_REGEX.test(normalized.code)) {
    fieldErrors.code = ORG_SETUP_VALIDATION.codeInvalid
  }

  return {
    fieldErrors,
    isValid: Object.keys(fieldErrors).length === 0,
    normalized,
  }
}

export function validatePositionForm(
  form: PositionFormFields,
  options?: { allowedDepartmentIds?: Set<string> },
): {
  fieldErrors: Partial<Record<PositionFieldKey, string>>
  isValid: boolean
  normalized: NormalizedPositionForm
} {
  const normalized = normalizePositionFormInput(form)
  const fieldErrors: Partial<Record<PositionFieldKey, string>> = {}

  if (!normalized.name) {
    fieldErrors.name = ORG_SETUP_VALIDATION.nameRequired
  }
  if (!normalized.code) {
    fieldErrors.code = ORG_SETUP_VALIDATION.codeRequired
  } else if (!ORG_SETUP_CODE_SLUG_REGEX.test(normalized.code)) {
    fieldErrors.code = ORG_SETUP_VALIDATION.codeInvalid
  }

  if (
    normalized.departmentId &&
    options?.allowedDepartmentIds &&
    !options.allowedDepartmentIds.has(normalized.departmentId)
  ) {
    fieldErrors.departmentId = ORG_SETUP_VALIDATION.departmentInvalid
  }

  if (normalized.normHeadcount !== null) {
    if (
      Number.isNaN(normalized.normHeadcount) ||
      normalized.normHeadcount < 0 ||
      normalized.normHeadcount > 100_000
    ) {
      fieldErrors.normHeadcount = ORG_SETUP_VALIDATION.normInvalid
    }
  }

  return {
    fieldErrors,
    isValid: Object.keys(fieldErrors).length === 0,
    normalized,
  }
}

export function isDepartmentFormDirty(
  current: DepartmentFormFields,
  baseline: DepartmentFormFields,
): boolean {
  const a = normalizeDepartmentFormInput(current)
  const b = normalizeDepartmentFormInput(baseline)
  return a.name !== b.name || a.code !== b.code
}

export function isPositionFormDirty(current: PositionFormFields, baseline: PositionFormFields): boolean {
  const a = normalizePositionFormInput(current)
  const b = normalizePositionFormInput(baseline)
  return (
    a.name !== b.name ||
    a.code !== b.code ||
    a.departmentId !== b.departmentId ||
    a.normHeadcount !== b.normHeadcount
  )
}
