import { supabase } from '#/lib/supabase'
import { resolvePersonaForUser } from '#/lib/persona'

export type CompetencyTemplate = {
  id: string
  name: string
  description: string | null
  weight: number | null
  sort_order: number | null
}

export type PerformansCycle = {
  id: string
  name: string
  status: 'draft' | 'active' | 'closed'
  starts_at: string
  ends_at: string
  created_at: string
}

export type CreateCycleInput = {
  name: string
  starts_at: string
  ends_at: string
  status?: PerformansCycle['status']
}

export async function fetchCompetencyTemplates(): Promise<CompetencyTemplate[]> {
  const { data, error } = await supabase
    .from('performans_competency_templates')
    .select('id, name, description, weight, sort_order')
    .eq('is_active', true)
    .order('sort_order', { ascending: true })

  if (error) {
    console.warn('fetchCompetencyTemplates:', error.message)
    return []
  }

  return (data ?? []) as CompetencyTemplate[]
}

export async function fetchPerformansCycles(): Promise<PerformansCycle[]> {
  const { data, error } = await supabase
    .from('performans_cycles')
    .select('id, name, status, starts_at, ends_at, created_at')
    .order('starts_at', { ascending: false })

  if (error) {
    console.warn('fetchPerformansCycles:', error.message)
    return []
  }

  return (data ?? []) as PerformansCycle[]
}

export async function createPerformansCycle(
  userId: string,
  input: CreateCycleInput,
): Promise<{ data: PerformansCycle | null; error: string | null }> {
  const { tenantId } = await resolvePersonaForUser(userId)
  if (!tenantId) {
    return { data: null, error: 'no_tenant' }
  }

  const { data, error } = await supabase
    .from('performans_cycles')
    .insert({
      tenant_id: tenantId,
      name: input.name.trim(),
      starts_at: input.starts_at,
      ends_at: input.ends_at,
      status: input.status ?? 'draft',
    })
    .select('id, name, status, starts_at, ends_at, created_at')
    .single()

  if (error) {
    return { data: null, error: error.message }
  }

  return { data: data as PerformansCycle, error: null }
}

export async function updateCycleStatus(
  cycleId: string,
  status: PerformansCycle['status'],
): Promise<{ error: string | null }> {
  const { error } = await supabase
    .from('performans_cycles')
    .update({ status })
    .eq('id', cycleId)

  return { error: error?.message ?? null }
}
