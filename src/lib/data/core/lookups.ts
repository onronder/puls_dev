import { fromSupabaseError } from '#/lib/data/errors'
import { pulsCore } from '#/lib/data/client'

export type LookupTable = 'departments' | 'positions' | 'employees'

export function uniqueNonNullIds(values: (string | null | undefined)[]): string[] {
  return [...new Set(values.filter((value): value is string => Boolean(value)))]
}

export function buildNameMap(rows: { id: string; name: string }[]): Map<string, string> {
  return new Map(rows.map((row) => [row.id, row.name]))
}

export function countRowsById(rows: { id: string | null }[], idField: 'id' = 'id'): Map<string, number> {
  const counts = new Map<string, number>()
  for (const row of rows) {
    const id = row[idField] as string | null
    if (!id) continue
    counts.set(id, (counts.get(id) ?? 0) + 1)
  }
  return counts
}

export function computeOpenHeadcount(normHeadcount: number, filledCount: number): number {
  return Math.max(0, normHeadcount - filledCount)
}

async function fetchDepartmentNames(
  tenantId: string,
  ids: string[],
): Promise<Map<string, string>> {
  if (ids.length === 0) return new Map()

  const { data, error } = await pulsCore()
    .from('departments')
    .select('id, name')
    .eq('tenant_id', tenantId)
    .in('id', ids)

  if (error) {
    throw fromSupabaseError(error, 'fetchDepartmentNames', 'puls_core', 'departments')
  }

  return buildNameMap(
    (data ?? []).map((row) => ({
      id: row.id as string,
      name: row.name as string,
    })),
  )
}

async function fetchPositionNames(tenantId: string, ids: string[]): Promise<Map<string, string>> {
  if (ids.length === 0) return new Map()

  const { data, error } = await pulsCore()
    .from('positions')
    .select('id, name')
    .eq('tenant_id', tenantId)
    .in('id', ids)

  if (error) {
    throw fromSupabaseError(error, 'fetchPositionNames', 'puls_core', 'positions')
  }

  return buildNameMap(
    (data ?? []).map((row) => ({
      id: row.id as string,
      name: row.name as string,
    })),
  )
}

async function fetchEmployeeNames(tenantId: string, ids: string[]): Promise<Map<string, string>> {
  if (ids.length === 0) return new Map()

  const { data, error } = await pulsCore()
    .from('employees')
    .select('id, full_name')
    .eq('tenant_id', tenantId)
    .in('id', ids)

  if (error) {
    throw fromSupabaseError(error, 'fetchEmployeeNames', 'puls_core', 'employees')
  }

  return buildNameMap(
    (data ?? []).map((row) => ({
      id: row.id as string,
      name: (row.full_name as string | null) ?? '—',
    })),
  )
}

export async function fetchNamesByIds(
  table: LookupTable,
  tenantId: string,
  ids: string[],
): Promise<Map<string, string>> {
  const uniqueIds = uniqueNonNullIds(ids)

  switch (table) {
    case 'departments':
      return fetchDepartmentNames(tenantId, uniqueIds)
    case 'positions':
      return fetchPositionNames(tenantId, uniqueIds)
    case 'employees':
      return fetchEmployeeNames(tenantId, uniqueIds)
  }
}

export async function countActiveEmployeesByDepartment(
  tenantId: string,
): Promise<Map<string, number>> {
  const { data, error } = await pulsCore()
    .from('employees')
    .select('department_id')
    .eq('tenant_id', tenantId)
    .eq('employment_status', 'active')

  if (error) {
    throw fromSupabaseError(error, 'countActiveEmployeesByDepartment', 'puls_core', 'employees')
  }

  const counts = new Map<string, number>()
  for (const row of data ?? []) {
    const deptId = row.department_id as string | null
    if (!deptId) continue
    counts.set(deptId, (counts.get(deptId) ?? 0) + 1)
  }
  return counts
}

export async function countActiveEmployeesByPosition(
  tenantId: string,
): Promise<Map<string, number>> {
  const { data, error } = await pulsCore()
    .from('employees')
    .select('position_id')
    .eq('tenant_id', tenantId)
    .eq('employment_status', 'active')

  if (error) {
    throw fromSupabaseError(error, 'countActiveEmployeesByPosition', 'puls_core', 'employees')
  }

  const counts = new Map<string, number>()
  for (const row of data ?? []) {
    const positionId = row.position_id as string | null
    if (!positionId) continue
    counts.set(positionId, (counts.get(positionId) ?? 0) + 1)
  }
  return counts
}
