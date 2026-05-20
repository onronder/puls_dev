import type { PersonaRole } from '#/lib/supabase'
import { supabase } from '#/lib/supabase'

const MANAGER_LIKE_ROLES: PersonaRole[] = ['manager', 'hr_admin', 'superadmin']

export function mapPersonaRole(role: PersonaRole | null | undefined): PersonaRole {
  return role ?? 'employee'
}

export function isDualPersonaRole(role: PersonaRole | null | undefined): boolean {
  return role === 'manager' || role === 'hr_admin'
}

/** Resolve persona from Puls employees row, else Lovable user_roles. */
export async function resolvePersonaForUser(userId: string): Promise<{
  personaRole: PersonaRole
  tenantId: string | null
}> {
  const { data: employee } = await supabase
    .from('employees')
    .select('persona_role, tenant_id')
    .eq('user_id', userId)
    .maybeSingle()

  if (employee?.persona_role) {
    return {
      personaRole: mapPersonaRole(employee.persona_role as PersonaRole),
      tenantId: employee.tenant_id ?? null,
    }
  }

  const { data: membership } = await supabase
    .from('user_tenants')
    .select('tenant_id, is_default')
    .eq('user_id', userId)
    .order('is_default', { ascending: false })
    .limit(1)
    .maybeSingle()

  const tenantId = membership?.tenant_id ?? null

  if (tenantId) {
    const { data: roleRow } = await supabase
      .from('user_roles')
      .select('role')
      .eq('user_id', userId)
      .eq('tenant_id', tenantId)
      .maybeSingle()

    const mapped = mapLovableRole(roleRow?.role as string | undefined)
    return { personaRole: mapped, tenantId }
  }

  return { personaRole: 'employee', tenantId: null }
}

function mapLovableRole(role: string | undefined): PersonaRole {
  switch (role) {
    case 'superadmin':
      return 'superadmin'
    case 'owner':
    case 'admin':
    case 'hr_admin':
    case 'hr':
      return 'hr_admin'
    case 'manager':
      return 'manager'
    default:
      return 'employee'
  }
}

export async function logPersonaSwitch(params: {
  userId: string
  tenantId: string | null
  persona: string
}): Promise<void> {
  const { userId, tenantId, persona } = params

  const auditPayload = {
    tenant_id: tenantId,
    actor_id: userId,
    action: 'persona_switch',
    target_object: { persona },
    request_metadata: { source: 'PersonaTogglePill' },
  }

  const { error: pulsAuditError } = await supabase
    .schema('puls_audit')
    .from('audit_logs')
    .insert(auditPayload)

  if (!pulsAuditError) return

  const { error: legacyAuditError } = await supabase
    .schema('audit')
    .from('audit_logs')
    .insert(auditPayload)

  if (!legacyAuditError) return

  await supabase.from('audit_log').insert({
    tenant_id: tenantId,
    actor_user_id: userId,
    action: 'persona_switch',
    resource_type: 'persona',
    resource_id: userId,
    metadata: { persona, source: 'PersonaTogglePill' },
  })
}

export { MANAGER_LIKE_ROLES }
