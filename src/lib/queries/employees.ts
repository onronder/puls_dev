import { supabase } from '#/lib/supabase'
import { resolvePersonaForUser } from '#/lib/persona'

export type EmployeeListItem = {
  id: string
  fullName: string
  email: string | null
  jobTitle: string | null
  departmentName: string | null
  positionName: string | null
  personaRole: string | null
  hireDate: string | null
}

export type EmployeeListStats = {
  employeeCount: number
  departmentCount: number
  positionCount: number
}

async function resolveTenantId(userId: string): Promise<string | null> {
  const { tenantId } = await resolvePersonaForUser(userId)
  return tenantId
}

export async function fetchEmployeeList(userId: string): Promise<EmployeeListItem[]> {
  const tenantId = await resolveTenantId(userId)
  if (!tenantId) return []

  const { data, error } = await supabase
    .from('employees')
    .select(
      `
      anonymous_id,
      full_name,
      email,
      job_title,
      persona_role,
      hire_date,
      departments ( name ),
      positions ( name )
    `,
    )
    .eq('tenant_id', tenantId)
    .order('full_name', { ascending: true })

  if (error) {
    throw new Error(`fetchEmployeeList: ${error.message}`)
  }

  return (data ?? []).map((row) => {
    const department = row.departments as { name?: string } | null
    const position = row.positions as { name?: string } | null

    return {
      id: row.anonymous_id as string,
      fullName: (row.full_name as string | null) ?? '',
      email: (row.email as string | null) ?? null,
      jobTitle: (row.job_title as string | null) ?? null,
      departmentName: department?.name ?? null,
      positionName: position?.name ?? null,
      personaRole: (row.persona_role as string | null) ?? null,
      hireDate: (row.hire_date as string | null) ?? null,
    }
  })
}

export async function fetchEmployeeListStats(userId: string): Promise<EmployeeListStats> {
  const tenantId = await resolveTenantId(userId)
  if (!tenantId) {
    return { employeeCount: 0, departmentCount: 0, positionCount: 0 }
  }

  const [employees, departments, positions] = await Promise.all([
    supabase
      .from('employees')
      .select('anonymous_id', { count: 'exact', head: true })
      .eq('tenant_id', tenantId),
    supabase
      .from('departments')
      .select('id', { count: 'exact', head: true })
      .eq('tenant_id', tenantId)
      .eq('is_active', true),
    supabase
      .from('positions')
      .select('id', { count: 'exact', head: true })
      .eq('tenant_id', tenantId)
      .eq('is_active', true),
  ])

  return {
    employeeCount: employees.count ?? 0,
    departmentCount: departments.count ?? 0,
    positionCount: positions.count ?? 0,
  }
}
