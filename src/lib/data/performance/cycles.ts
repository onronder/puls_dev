import { fromSupabaseError, DataAdapterError, adapterError } from '#/lib/data/errors'
import { pulsPerformance, resolveTenantContext } from '#/lib/data/client'
import { resolveAdapterData, resolveAdapterDataWithMeta } from '#/lib/data/result'

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

export type PerformanceCycleValidationErrors = {
  name?: string
  starts_at?: string
  ends_at?: string
  status?: string
}

const CYCLE_STATUSES: PerformansCycle['status'][] = ['draft', 'active', 'closed']
const PERFORMANCE_CYCLE_STATUS_TRANSITIONS: Record<
  PerformansCycle['status'],
  PerformansCycle['status'][]
> = {
  draft: ['active'],
  active: ['closed'],
  closed: [],
}

function isIsoDateString(value: string): boolean {
  return /^\d{4}-\d{2}-\d{2}$/.test(value)
}

export function normalizePerformanceCycleName(value: string): string {
  return value.trim()
}

export function validatePerformanceCycleInput(
  input: CreateCycleInput,
): { ok: true; value: CreateCycleInput } | { ok: false; errors: PerformanceCycleValidationErrors } {
  const errors: PerformanceCycleValidationErrors = {}
  const name = normalizePerformanceCycleName(input.name)

  if (!name) {
    errors.name = 'name_required'
  }

  if (!input.starts_at) {
    errors.starts_at = 'starts_at_required'
  } else if (!isIsoDateString(input.starts_at)) {
    errors.starts_at = 'starts_at_invalid'
  }

  if (!input.ends_at) {
    errors.ends_at = 'ends_at_required'
  } else if (!isIsoDateString(input.ends_at)) {
    errors.ends_at = 'ends_at_invalid'
  } else if (input.starts_at && input.ends_at <= input.starts_at) {
    errors.ends_at = 'ends_at_before_start'
  }

  const status = input.status ?? 'draft'
  if (!CYCLE_STATUSES.includes(status)) {
    errors.status = 'status_invalid'
  }

  if (Object.keys(errors).length > 0) {
    return { ok: false, errors }
  }

  return {
    ok: true,
    value: {
      name,
      starts_at: input.starts_at,
      ends_at: input.ends_at,
      status,
    },
  }
}

export function canTransitionPerformanceCycleStatus(
  currentStatus: PerformansCycle['status'],
  nextStatus: PerformansCycle['status'],
): boolean {
  if (currentStatus === nextStatus) return true
  return PERFORMANCE_CYCLE_STATUS_TRANSITIONS[currentStatus]?.includes(nextStatus) ?? false
}

function invalidCycleRow(message: string): DataAdapterError {
  return new DataAdapterError({
    code: 'invalid_row',
    message,
    source: 'adapter',
    operation: 'parsePerformanceCycleRow',
  })
}

export function parsePerformanceCycleRow(row: unknown): PerformansCycle {
  if (row === null || typeof row !== 'object' || Array.isArray(row)) {
    throw invalidCycleRow('performance cycle row is not an object')
  }

  const data = row as Record<string, unknown>
  const status = data.status as PerformansCycle['status']

  if (!CYCLE_STATUSES.includes(status)) {
    throw invalidCycleRow('performance cycle row has invalid status')
  }

  for (const field of ['id', 'name', 'starts_at', 'ends_at', 'created_at'] as const) {
    if (typeof data[field] !== 'string' || (data[field] as string).trim().length === 0) {
      throw invalidCycleRow(`performance cycle row missing ${field}`)
    }
  }

  return {
    id: data.id as string,
    name: data.name as string,
    status,
    starts_at: data.starts_at as string,
    ends_at: data.ends_at as string,
    created_at: data.created_at as string,
  }
}

export function parsePerformanceCycleMutationResult(data: unknown): PerformansCycle {
  return parsePerformanceCycleRow(data)
}

function mutationError(error: unknown, operation: string): string {
  if (error instanceof DataAdapterError) {
    return error.toUserMessage()
  }
  return adapterError(operation).toUserMessage()
}

function validationErrorMessage(): string {
  return adapterError('createPerformanceCycle', 'invalid_input').toUserMessage()
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
    throw fromSupabaseError(
      error,
      'fetchPerformanceCycles',
      'puls_performance',
      'performance_cycles',
    )
  }

  return (data ?? []).map((row) => parsePerformanceCycleRow(row))
}

export function fetchPerformanceCyclesWithMeta(userId: string) {
  return resolveAdapterDataWithMeta({
    operation: 'fetchPerformanceCycles',
    fetchReal: () => fetchRealPerformanceCycles(userId),
    fetchDemo: async () => [],
    isEmpty: (cycles) => cycles.length === 0,
  })
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
    const validated = validatePerformanceCycleInput(input)
    if (!validated.ok) {
      return { data: null, error: validationErrorMessage() }
    }

    const ctx = await resolveTenantContext(userId)
    if (!ctx.tenantId) {
      return {
        data: null,
        error: adapterError('createPerformanceCycle', 'no_tenant').toUserMessage(),
      }
    }

    const { data, error } = await pulsPerformance()
      .from('performance_cycles')
      .insert({
        tenant_id: ctx.tenantId,
        name: validated.value.name,
        starts_at: validated.value.starts_at,
        ends_at: validated.value.ends_at,
        status: validated.value.status ?? 'draft',
      })
      .select('id, name, status, starts_at, ends_at, created_at')
      .single()

    if (error) {
      throw fromSupabaseError(
        error,
        'createPerformanceCycle',
        'puls_performance',
        'performance_cycles',
      )
    }

    return { data: parsePerformanceCycleMutationResult(data), error: null }
  } catch (error) {
    return { data: null, error: mutationError(error, 'createPerformanceCycle') }
  }
}

export async function updatePerformanceCycle(
  userId: string,
  cycleId: string,
  patch: Partial<Pick<PerformansCycle, 'status' | 'name' | 'starts_at' | 'ends_at'>>,
): Promise<{ data: PerformansCycle | null; error: string | null }> {
  try {
    const ctx = await resolveTenantContext(userId)
    if (!ctx.tenantId) {
      return {
        data: null,
        error: adapterError('updatePerformanceCycle', 'no_tenant').toUserMessage(),
      }
    }

    const payload: Record<string, unknown> = {}
    if (patch.status != null) payload.status = patch.status
    if (patch.name != null) payload.name = patch.name.trim()
    if (patch.starts_at != null) payload.starts_at = patch.starts_at
    if (patch.ends_at != null) payload.ends_at = patch.ends_at

    if (Object.keys(payload).length === 0) {
      return {
        data: null,
        error: adapterError('updatePerformanceCycle', 'empty_patch').toUserMessage(),
      }
    }

    if (
      payload.status != null &&
      !CYCLE_STATUSES.includes(payload.status as PerformansCycle['status'])
    ) {
      return { data: null, error: validationErrorMessage() }
    }

    if (payload.name != null && !normalizePerformanceCycleName(String(payload.name))) {
      return { data: null, error: validationErrorMessage() }
    }

    if (payload.starts_at != null && !isIsoDateString(String(payload.starts_at))) {
      return { data: null, error: validationErrorMessage() }
    }

    if (payload.ends_at != null && !isIsoDateString(String(payload.ends_at))) {
      return { data: null, error: validationErrorMessage() }
    }

    if (
      payload.starts_at != null &&
      payload.ends_at != null &&
      String(payload.ends_at) <= String(payload.starts_at)
    ) {
      return { data: null, error: validationErrorMessage() }
    }

    if (payload.status != null) {
      const { data: currentRow, error: currentError } = await pulsPerformance()
        .from('performance_cycles')
        .select('status')
        .eq('tenant_id', ctx.tenantId)
        .eq('id', cycleId)
        .single()

      if (currentError) {
        throw fromSupabaseError(
          currentError,
          'updatePerformanceCycle',
          'puls_performance',
          'performance_cycles',
        )
      }

      const currentStatus = currentRow.status as PerformansCycle['status']
      const nextStatus = payload.status as PerformansCycle['status']
      if (!canTransitionPerformanceCycleStatus(currentStatus, nextStatus)) {
        return {
          data: null,
          error: adapterError(
            'updatePerformanceCycle',
            'invalid_status_transition',
          ).toUserMessage(),
        }
      }
    }

    const { data, error } = await pulsPerformance()
      .from('performance_cycles')
      .update(payload)
      .eq('tenant_id', ctx.tenantId)
      .eq('id', cycleId)
      .select('id, name, status, starts_at, ends_at, created_at')
      .single()

    if (error) {
      throw fromSupabaseError(
        error,
        'updatePerformanceCycle',
        'puls_performance',
        'performance_cycles',
      )
    }

    return { data: parsePerformanceCycleMutationResult(data), error: null }
  } catch (error) {
    return { data: null, error: mutationError(error, 'updatePerformanceCycle') }
  }
}
