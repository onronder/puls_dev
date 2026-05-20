import { supabase } from '#/lib/supabase'

export type DashboardStats = {
  tenantName: string | null
  employeeCount: number
  departmentCount: number
  competencyCount: number
  erpConnected: boolean
  erpProvider: string | null
  displayName: string | null
}

async function fetchTenantName(tenantId: string): Promise<string | null> {
  const { data } = await supabase
    .from('tenants')
    .select('trade_name, name, legal_name')
    .eq('id', tenantId)
    .maybeSingle()

  if (!data) return null
  return data.trade_name ?? data.name ?? data.legal_name ?? null
}

export async function fetchDashboardStats(userId: string): Promise<DashboardStats> {
  const empty: DashboardStats = {
    tenantName: null,
    employeeCount: 0,
    departmentCount: 0,
    competencyCount: 0,
    erpConnected: false,
    erpProvider: null,
    displayName: null,
  }

  const { data: employee } = await supabase
    .from('employees')
    .select('full_name, tenant_id')
    .eq('user_id', userId)
    .maybeSingle()

  let tenantId = employee?.tenant_id as string | undefined

  if (employee) {
    empty.displayName = employee.full_name
  }

  if (!tenantId) {
    const { data: membership } = await supabase
      .from('user_tenants')
      .select('tenant_id')
      .eq('user_id', userId)
      .order('is_default', { ascending: false })
      .limit(1)
      .maybeSingle()

    tenantId = membership?.tenant_id
  }

  if (!tenantId) return empty

  empty.tenantName = await fetchTenantName(tenantId)

  const [employees, departments, competencies, erp] = await Promise.all([
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
      .from('performans_competency_templates')
      .select('id', { count: 'exact', head: true })
      .eq('tenant_id', tenantId)
      .eq('is_active', true),
    supabase
      .from('erp_connections')
      .select('provider, is_active')
      .eq('tenant_id', tenantId)
      .eq('is_active', true)
      .limit(1)
      .maybeSingle(),
  ])

  return {
    tenantName: empty.tenantName,
    displayName: empty.displayName,
    employeeCount: employees.count ?? 0,
    departmentCount: departments.count ?? 0,
    competencyCount: competencies.count ?? 0,
    erpConnected: Boolean(erp.data?.is_active),
    erpProvider: (erp.data?.provider as string | null) ?? null,
  }
}
