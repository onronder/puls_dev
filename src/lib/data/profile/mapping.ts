export type ProfileEmployeeFields = {
  email: string | null
  departmentId: string | null
  positionId: string | null
  employmentStatus: string | null
  personaRole: string | null
}

export type ProfileEmployeeRow = {
  email?: string | null
  department_id?: string | null
  position_id?: string | null
  employment_status?: string | null
  persona_role?: string | null
}

export function resolveProfileDisplayName(
  fullName: string | null | undefined,
  email: string | null | undefined,
): string {
  const trimmedName = fullName?.trim()
  if (trimmedName) return trimmedName
  const trimmedEmail = email?.trim()
  if (trimmedEmail) return trimmedEmail
  return '—'
}

export function mapProfileEmployeeFields(row: ProfileEmployeeRow | null | undefined): ProfileEmployeeFields {
  return {
    email: (row?.email as string | null | undefined) ?? null,
    departmentId: (row?.department_id as string | null | undefined) ?? null,
    positionId: (row?.position_id as string | null | undefined) ?? null,
    employmentStatus: (row?.employment_status as string | null | undefined) ?? null,
    personaRole: (row?.persona_role as string | null | undefined) ?? null,
  }
}

export function resolveProfileStatusKey(employmentStatus: string | null | undefined): string {
  return employmentStatus === 'active'
    ? 'profileSetup.status.active'
    : 'profileSetup.status.inactive'
}
