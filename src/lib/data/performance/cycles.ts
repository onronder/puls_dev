import { fromSupabaseError, DataAdapterError, adapterError } from '#/lib/data/errors'
import { pulsPerformance, resolveTenantContext } from '#/lib/data/client'
import { resolveAdapterData } from '#/lib/data/result'

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

function mapCycle(row: Record<string, unknown>): PerformansCycle {
  return {
    id: row.id as string,
    name: row.name as string,
    status: row.status as PerformansCycle['status'],
    starts_at: row.starts_at as string,
    ends_at: row.ends_at as string,
    created_at: row.created_at as string,
  }
}

function mutationError(error: unknown, operation: string): string {
  if (error instanceof DataAdapterError) {
    return error.toUserMessage()
  }
  return adapterError(operation).toUserMessage()
}

async function fetchRealPerformanceCycles(userId: string): Promise<PerformansCycle[]> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) return []

  const { data, error } = await pulsPerformance()
    .from('performance_cycles')
    .select('id, name, status, starts_at, ends_at, created_at')
    .eq('tenant_id', ctx.tenantId)
    .order('starts_at', { ascending: false })

  if (error) {
    throw fromSupabaseError(error, 'fetchPerformanceCycles', 'puls_performance', 'performance_cycles')
  }

  return (data ?? []).map((row) => mapCycle(row as Record<string, unknown>))
}

export async function fetchPerformanceCycles(userId: string): Promise<PerformansCycle[]> {
  return resolveAdapterData({
    operation: 'fetchPerformanceCycles',
    fetchReal: () => fetchRealPerformanceCycles(userId),
    fetchDemo: async () => [],
    isEmpty: (cycles) => cycles.length === 0,
  })
}

export async function fetchCompetencyTemplates(userId: string): Promise<CompetencyTemplate[]> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) return []

  const { data, error } = await pulsPerformance()
    .from('competency_templates')
    .select('id, name, description, weight, sort_order')
    .eq('tenant_id', ctx.tenantId)
    .eq('is_active', true)
    .order('sort_order', { ascending: true })

  if (error) {
    throw fromSupabaseError(
      error,
      'fetchCompetencyTemplates',
      'puls_performance',
      'competency_templates',
    )
  }

  return (data ?? []).map((row) => ({
    id: row.id as string,
    name: row.name as string,
    description: (row.description as string | null) ?? null,
    weight: row.weight == null ? null : Number(row.weight),
    sort_order: row.sort_order == null ? null : Number(row.sort_order),
  }))
}

export async function createPerformanceCycle(
  userId: string,
  input: CreateCycleInput,
): Promise<{ data: PerformansCycle | null; error: string | null }> {
  try {
    const ctx = await resolveTenantContext(userId)
    if (!ctx.tenantId) {
      return { data: null, error: adapterError('createPerformanceCycle', 'no_tenant').toUserMessage() }
    }

    const { data, error } = await pulsPerformance()
      .from('performance_cycles')
      .insert({
        tenant_id: ctx.tenantId,
        name: input.name.trim(),
        starts_at: input.starts_at,
        ends_at: input.ends_at,
        status: input.status ?? 'draft',
      })
      .select('id, name, status, starts_at, ends_at, created_at')
      .single()

    if (error) {
      throw fromSupabaseError(error, 'createPerformanceCycle', 'puls_performance', 'performance_cycles')
    }

    return { data: mapCycle(data as Record<string, unknown>), error: null }
  } catch (error) {
    return { data: null, error: mutationError(error, 'createPerformanceCycle') }
  }
}

export async function updatePerformanceCycle(
  cycleId: string,
  patch: Partial<Pick<PerformansCycle, 'status' | 'name' | 'starts_at' | 'ends_at'>>,
): Promise<{ data: PerformansCycle | null; error: string | null }> {
  try {
    const payload: Record<string, unknown> = {}
    if (patch.status != null) payload.status = patch.status
    if (patch.name != null) payload.name = patch.name.trim()
    if (patch.starts_at != null) payload.starts_at = patch.starts_at
    if (patch.ends_at != null) payload.ends_at = patch.ends_at

    if (Object.keys(payload).length === 0) {
      return { data: null, error: adapterError('updatePerformanceCycle', 'empty_patch').toUserMessage() }
    }

    const { data, error } = await pulsPerformance()
      .from('performance_cycles')
      .update(payload)
      .eq('id', cycleId)
      .select('id, name, status, starts_at, ends_at, created_at')
      .single()

    if (error) {
      throw fromSupabaseError(error, 'updatePerformanceCycle', 'puls_performance', 'performance_cycles')
    }

    return { data: mapCycle(data as Record<string, unknown>), error: null }
  } catch (error) {
    return { data: null, error: mutationError(error, 'updatePerformanceCycle') }
  }
}
