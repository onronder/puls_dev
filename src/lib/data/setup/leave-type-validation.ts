export type LeaveTypeFormFields = {
  name: string
  code: string
  defaultEntitlementDays: string
  requiresDocument: boolean
  carryOverAllowed: boolean
  maxCarryOverDays: string
  approvalPolicyId: string | null
}

export type LeaveTypeFieldKey =
  | 'name'
  | 'code'
  | 'defaultEntitlementDays'
  | 'maxCarryOverDays'
  | 'approvalPolicyId'

export type NormalizedLeaveTypeForm = {
  name: string
  code: string
  defaultEntitlementDays: number | null
  requiresDocument: boolean
  carryOverAllowed: boolean
  maxCarryOverDays: number | null
  approvalPolicyId: string | null
}

export const LEAVE_TYPE_VALIDATION = {
  nameRequired: 'leaveTypeSetup.validation.nameRequired',
  codeRequired: 'leaveTypeSetup.validation.codeRequired',
  codeInvalid: 'leaveTypeSetup.validation.codeInvalid',
  entitlementInvalid: 'leaveTypeSetup.validation.entitlementInvalid',
  carryOverInvalid: 'leaveTypeSetup.validation.carryOverInvalid',
} as const

const LEAVE_TYPE_CODE_SLUG_REGEX = /^[a-z][a-z0-9_]{1,63}$/
const EN_COMMA_DECIMAL_REGEX = /^\d+,\d+$/

export function normalizeLeaveTypeCode(value: string): string {
  return value.trim().toLowerCase().replace(/\s+/g, '_')
}

export function normalizeLeaveTypeText(value: string): string {
  return value.trim()
}

export function parseLeaveTypeDayCount(raw: string): number {
  const trimmed = raw.trim()
  if (trimmed === '') return NaN
  if (EN_COMMA_DECIMAL_REGEX.test(trimmed)) return NaN
  if (trimmed.includes(',')) return NaN

  const parsed = Number(trimmed)
  return Number.isFinite(parsed) ? parsed : NaN
}

export function normalizeLeaveTypeFormInput(form: LeaveTypeFormFields): NormalizedLeaveTypeForm {
  const entitlementRaw = form.defaultEntitlementDays.trim()
  const carryOverRaw = form.maxCarryOverDays.trim()

  return {
    name: normalizeLeaveTypeText(form.name),
    code: normalizeLeaveTypeCode(form.code),
    defaultEntitlementDays:
      entitlementRaw === '' ? null : parseLeaveTypeDayCount(entitlementRaw),
    requiresDocument: form.requiresDocument,
    carryOverAllowed: form.carryOverAllowed,
    maxCarryOverDays: carryOverRaw === '' ? null : parseLeaveTypeDayCount(carryOverRaw),
    approvalPolicyId: form.approvalPolicyId?.trim() ? form.approvalPolicyId.trim() : null,
  }
}

function isDayCountInRange(value: number | null): boolean {
  if (value === null) return true
  return Number.isFinite(value) && value >= 0 && value <= 365
}

export function validateLeaveTypeForm(form: LeaveTypeFormFields): {
  fieldErrors: Partial<Record<LeaveTypeFieldKey, string>>
  isValid: boolean
  normalized: NormalizedLeaveTypeForm
} {
  const fieldErrors: Partial<Record<LeaveTypeFieldKey, string>> = {}
  const normalized = normalizeLeaveTypeFormInput(form)

  if (!normalized.name) {
    fieldErrors.name = LEAVE_TYPE_VALIDATION.nameRequired
  }

  if (!form.code.trim()) {
    fieldErrors.code = LEAVE_TYPE_VALIDATION.codeRequired
  } else if (!LEAVE_TYPE_CODE_SLUG_REGEX.test(normalized.code)) {
    fieldErrors.code = LEAVE_TYPE_VALIDATION.codeInvalid
  }

  const entitlementRaw = form.defaultEntitlementDays.trim()
  if (entitlementRaw !== '' && !isDayCountInRange(normalized.defaultEntitlementDays)) {
    fieldErrors.defaultEntitlementDays = LEAVE_TYPE_VALIDATION.entitlementInvalid
  }

  const carryOverRaw = form.maxCarryOverDays.trim()
  if (carryOverRaw !== '' && !isDayCountInRange(normalized.maxCarryOverDays)) {
    fieldErrors.maxCarryOverDays = LEAVE_TYPE_VALIDATION.carryOverInvalid
  }

  if (
    !form.carryOverAllowed &&
    normalized.maxCarryOverDays !== null &&
    normalized.maxCarryOverDays > 0
  ) {
    fieldErrors.maxCarryOverDays = LEAVE_TYPE_VALIDATION.carryOverInvalid
  }

  return {
    fieldErrors,
    isValid: Object.keys(fieldErrors).length === 0,
    normalized,
  }
}

export function isLeaveTypeFormDirty(
  current: LeaveTypeFormFields,
  baseline: LeaveTypeFormFields,
): boolean {
  return (
    current.name !== baseline.name ||
    current.code !== baseline.code ||
    current.defaultEntitlementDays !== baseline.defaultEntitlementDays ||
    current.requiresDocument !== baseline.requiresDocument ||
    current.carryOverAllowed !== baseline.carryOverAllowed ||
    current.maxCarryOverDays !== baseline.maxCarryOverDays ||
    (current.approvalPolicyId ?? null) !== (baseline.approvalPolicyId ?? null)
  )
}
