import { supabase, type PersonaRole } from '#/lib/supabase'
import { fromSupabaseError } from '#/lib/data/errors'

export const pulsCore = () => supabase.schema('puls_core')
export const pulsWorkflow = () => supabase.schema('puls_workflow')
export const pulsPerformance = () => supabase.schema('puls_performance')
export const pulsIntegration = () => supabase.schema('puls_integration')
export const pulsApp = () => supabase.schema('puls_app')
export const pulsCalc = () => supabase.schema('puls_calc')
export const pulsAudit = () => supabase.schema('puls_audit')

export type TenantContext = {
  tenantId: string | null
  tenantName: string | null
  employeeId: string | null
  employeeName: string | null
  personaRole: PersonaRole
}

function mapLovableRole(role: string | undefined): PersonaRole {
  switch (role) {
    case 'superadmin':
    case 'patron':
      return 'superadmin'
    case 'owner':
    case 'admin':
    case 'hr_admin':
    case 'hr':
    case 'ik_admin':
    case 'finans':
    case 'hukuk_uyum':
      return 'hr_admin'
    case 'manager':
    case 'yonetici':
      return 'manager'
    case 'calisan':
    case 'employee':
    case 'member':
      return 'employee'
    default:
      return 'employee'
  }
}

async function fetchTenantName(tenantId: string): Promise<string | null> {
  const { data, error } = await pulsCore()
    .from('tenants')
    .select('trade_name, name, legal_name')
    .eq('id', tenantId)
    .maybeSingle()

  if (error) {
    throw fromSupabaseError(error, 'fetchTenantName', 'puls_core', 'tenants')
  }

  if (!data) return null
  return data.trade_name ?? data.name ?? data.legal_name ?? null
}

async function resolveCoreTenantId(publicTenantId: string): Promise<string | null> {
  const { data, error } = await pulsCore()
    .from('tenants')
    .select('id')
    .eq('legacy_public_tenant_id', publicTenantId)
    .maybeSingle()

  if (error) {
    throw fromSupabaseError(error, 'resolveCoreTenantId', 'puls_core', 'tenants')
  }

  return (data?.id as string | undefined) ?? null
}

export async function resolveTenantContext(userId: string): Promise<TenantContext> {
  const empty: TenantContext = {
    tenantId: null,
    tenantName: null,
    employeeId: null,
    employeeName: null,
    personaRole: 'employee',
  }

  const { data: employee, error: employeeError } = await pulsCore()
    .from('employees')
    .select('id, tenant_id, full_name, persona_role')
    .eq('user_id', userId)
    .maybeSingle()

  if (employeeError) {
    throw fromSupabaseError(employeeError, 'resolveTenantContext', 'puls_core', 'employees')
  }

  if (employee) {
    const tenantId = employee.tenant_id as string | null
    return {
      tenantId,
      tenantName: tenantId ? await fetchTenantName(tenantId) : null,
      employeeId: employee.id as string,
      employeeName: (employee.full_name as string | null) ?? null,
      personaRole: (employee.persona_role as PersonaRole | null) ?? 'employee',
    }
  }

  const { data: membership, error: membershipError } = await supabase
    .from('user_tenants')
    .select('tenant_id, is_default')
    .eq('user_id', userId)
    .order('is_default', { ascending: false })
    .limit(1)
    .maybeSingle()

  if (membershipError) {
    throw fromSupabaseError(membershipError, 'resolveTenantContext', 'public', 'user_tenants')
  }

  const publicTenantId = (membership?.tenant_id as string | undefined) ?? null
  if (!publicTenantId) return empty

  const coreTenantId = await resolveCoreTenantId(publicTenantId)
  if (!coreTenantId) return empty

  const { data: roleRow, error: roleError } = await supabase
    .from('user_roles')
    .select('role')
    .eq('user_id', userId)
    .eq('tenant_id', publicTenantId)
    .maybeSingle()

  if (roleError) {
    throw fromSupabaseError(roleError, 'resolveTenantContext', 'public', 'user_roles')
  }

  return {
    tenantId: coreTenantId,
    tenantName: await fetchTenantName(coreTenantId),
    employeeId: null,
    employeeName: null,
    personaRole: mapLovableRole(roleRow?.role as string | undefined),
  }
}

export function requireTenantId(ctx: TenantContext): string | null {
  return ctx.tenantId
}

export function requireEmployeeId(ctx: TenantContext): string | null {
  return ctx.employeeId
}
