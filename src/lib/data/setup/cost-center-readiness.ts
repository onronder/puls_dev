import { fetchDemoCostCenterReadinessOverview } from '#/lib/demo/puls-demo-data'
import type { DemoCostCenterReadinessOverview } from '#/lib/demo/puls-demo-data'
import { fromSupabaseError } from '#/lib/data/errors'
import { pulsCore, pulsIntegration, pulsWorkflow, resolveTenantContext } from '#/lib/data/client'
import { resolveAdapterData } from '#/lib/data/result'

export type CostCenterReadinessStatus = 'export_ready' | 'needs_mapping' | 'puls_only' | 'inactive'

export type ExportSourceType = 'erp' | 'excel_csv'

export type CostCenterReadinessItem = {
  id: string
  code: string
  name: string
  sourceName: string | null
  sourceCode: string | null
  sourceType: string | null
  externalId: string | null
  status: CostCenterReadinessStatus
  exportSourceType: ExportSourceType | null
}

export type ExpenseRoutingReadinessWarning = {
  policyId: string
  policyName: string
  categoryNames: string[]
  strategy: 'explicit' | 'requester_cost_center'
  costCenterCode?: string
  costCenterStatus?: CostCenterReadinessStatus
}

export type CostCenterReadinessOverview = DemoCostCenterReadinessOverview

export const EXPORT_CAPABLE_SOURCE_TYPES = new Set<ExportSourceType>(['erp', 'excel_csv'])

export type IdentityMapSnapshot = {
  isActive: boolean
  sourceNamespaceId: string
  externalId: string
  canonicalId: string
  canonicalSchema: string
  canonicalTable: string
  entityType: string
}

export type NamespaceSnapshot = {
  id: string
  isActive: boolean
  sourceType: string
  name: string
  code: string
}

export type CostCenterReadinessInput = {
  costCenterId: string
  isActive: boolean
  sourceNamespaceId: string | null
  externalId: string | null
  namespace: NamespaceSnapshot | null
  identityMaps: IdentityMapSnapshot[]
}

function isNonEmpty(value: string | null | undefined): value is string {
  return typeof value === 'string' && value.length > 0
}

function findMatchingIdentityMap(input: CostCenterReadinessInput): IdentityMapSnapshot | null {
  for (const map of input.identityMaps) {
    if (
      map.canonicalId === input.costCenterId &&
      map.canonicalSchema === 'puls_core' &&
      map.canonicalTable === 'cost_centers' &&
      map.entityType === 'cost_center'
    ) {
      return map
    }
  }
  return null
}

export function hasCoherentExportMapping(input: CostCenterReadinessInput): ExportSourceType | null {
  const identityMap = findMatchingIdentityMap(input)
  if (!identityMap?.isActive) return null
  if (!input.namespace?.isActive) return null
  if (!isNonEmpty(input.externalId) || !isNonEmpty(identityMap.externalId)) return null
  if (!isNonEmpty(input.sourceNamespaceId)) return null
  if (input.sourceNamespaceId !== identityMap.sourceNamespaceId) return null
  if (input.externalId !== identityMap.externalId) return null
  if (!EXPORT_CAPABLE_SOURCE_TYPES.has(input.namespace.sourceType as ExportSourceType)) return null
  return input.namespace.sourceType as ExportSourceType
}

export function hasAnyMappingSignal(input: CostCenterReadinessInput): boolean {
  if (isNonEmpty(input.sourceNamespaceId) || isNonEmpty(input.externalId)) return true
  if (input.identityMaps.length > 0) return true
  if (input.namespace && !input.namespace.isActive) return true

  const identityMap = findMatchingIdentityMap(input)
  if (identityMap) {
    if (!input.namespace?.isActive) return true
    if (!isNonEmpty(input.externalId) || !isNonEmpty(identityMap.externalId)) return true
    if (input.sourceNamespaceId !== identityMap.sourceNamespaceId) return true
    if (input.externalId !== identityMap.externalId) return true
    if (
      input.namespace &&
      !EXPORT_CAPABLE_SOURCE_TYPES.has(input.namespace.sourceType as ExportSourceType)
    ) {
      return true
    }
  }

  return false
}

export function computeCostCenterReadinessResult(
  input: CostCenterReadinessInput,
): { status: CostCenterReadinessStatus; exportSourceType: ExportSourceType | null } {
  if (!input.isActive) {
    return { status: 'inactive', exportSourceType: null }
  }

  const exportSourceType = hasCoherentExportMapping(input)
  if (exportSourceType) {
    return { status: 'export_ready', exportSourceType }
  }

  if (hasAnyMappingSignal(input)) {
    return { status: 'needs_mapping', exportSourceType: null }
  }

  return { status: 'puls_only', exportSourceType: null }
}

export function computeCostCenterReadinessStatus(input: CostCenterReadinessInput): CostCenterReadinessStatus {
  return computeCostCenterReadinessResult(input).status
}

function emptyCostCenterReadinessOverview(): CostCenterReadinessOverview {
  return {
    items: [],
    exportReadyCount: 0,
    needsMappingCount: 0,
    routingWarnings: [],
  }
}

function isCostCenterReadinessEmpty(data: CostCenterReadinessOverview): boolean {
  return data.items.length === 0 && data.routingWarnings.length === 0
}

type StepResolverConfig = {
  scope_strategy?: string
  scope_id?: string
  scope_code?: string
}

function parseStepResolverConfig(raw: unknown): StepResolverConfig {
  if (!raw || typeof raw !== 'object') return {}
  const config = raw as Record<string, unknown>
  return {
    scope_strategy:
      typeof config.scope_strategy === 'string' ? config.scope_strategy.toLowerCase() : undefined,
    scope_id: typeof config.scope_id === 'string' ? config.scope_id : undefined,
    scope_code: typeof config.scope_code === 'string' ? config.scope_code.trim() : undefined,
  }
}

export function buildRoutingWarnings(
  items: CostCenterReadinessItem[],
  categories: Array<{ approvalPolicyId: string | null; name: string }>,
  policies: Array<{ id: string; name: string }>,
  steps: Array<{
    policyId: string
    approverType: string
    stepResolverConfig: unknown
  }>,
): ExpenseRoutingReadinessWarning[] {
  const statusById = new Map(items.map((item) => [item.id, item]))
  const statusByCode = new Map(items.map((item) => [item.code, item]))
  const hasNonExportReadyCostCenter = items.some((item) => item.status !== 'export_ready')
  const categoriesByPolicy = new Map<string, string[]>()

  for (const category of categories) {
    if (!category.approvalPolicyId) continue
    const list = categoriesByPolicy.get(category.approvalPolicyId) ?? []
    list.push(category.name)
    categoriesByPolicy.set(category.approvalPolicyId, list)
  }

  const policyNameById = new Map(policies.map((policy) => [policy.id, policy.name]))
  const warnings: ExpenseRoutingReadinessWarning[] = []
  const seen = new Set<string>()

  for (const step of steps) {
    if (step.approverType !== 'cost_center_owner') continue

    const config = parseStepResolverConfig(step.stepResolverConfig)
    const strategy = config.scope_strategy

    if (strategy === 'explicit' && (config.scope_id || config.scope_code)) {
      const target = config.scope_id
        ? statusById.get(config.scope_id)
        : statusByCode.get(config.scope_code ?? '')
      if (!target || target.status === 'export_ready') continue

      const targetKey = config.scope_id ?? `code:${config.scope_code}`
      const key = `explicit:${step.policyId}:${targetKey}`
      if (seen.has(key)) continue
      seen.add(key)

      warnings.push({
        policyId: step.policyId,
        policyName: policyNameById.get(step.policyId) ?? step.policyId,
        categoryNames: categoriesByPolicy.get(step.policyId) ?? [],
        strategy: 'explicit',
        costCenterCode: target.code,
        costCenterStatus: target.status,
      })
      continue
    }

    if (strategy === 'requester_cost_center' && hasNonExportReadyCostCenter) {
      const key = `requester:${step.policyId}`
      if (seen.has(key)) continue
      seen.add(key)

      warnings.push({
        policyId: step.policyId,
        policyName: policyNameById.get(step.policyId) ?? step.policyId,
        categoryNames: categoriesByPolicy.get(step.policyId) ?? [],
        strategy: 'requester_cost_center',
      })
    }
  }

  return warnings
}

async function fetchRealCostCenterReadinessOverview(
  userId: string,
): Promise<CostCenterReadinessOverview> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.tenantId) return emptyCostCenterReadinessOverview()

  const tenantId = ctx.tenantId

  const { data: costCenterRows, error: costCenterError } = await pulsCore()
    .from('cost_centers')
    .select('id, code, name, is_active, source_namespace_id, external_id')
    .eq('tenant_id', tenantId)
    .order('name', { ascending: true })

  if (costCenterError) {
    throw fromSupabaseError(
      costCenterError,
      'fetchCostCenterReadinessOverview',
      'puls_core',
      'cost_centers',
    )
  }

  const costCenterIds = (costCenterRows ?? []).map((row) => row.id as string)

  const namespacesPromise = pulsIntegration()
    .from('source_namespaces')
    .select('id, code, name, source_type, is_active')
    .eq('tenant_id', tenantId)

  const identityMapsPromise =
    costCenterIds.length > 0
      ? pulsIntegration()
          .from('entity_identity_map')
          .select(
            'canonical_id, external_id, is_active, source_namespace_id, canonical_schema, canonical_table, entity_type',
          )
          .eq('tenant_id', tenantId)
          .eq('entity_type', 'cost_center')
          .eq('canonical_schema', 'puls_core')
          .eq('canonical_table', 'cost_centers')
          .in('canonical_id', costCenterIds)
      : Promise.resolve({ data: [], error: null })

  const [namespacesResult, identityMapsResult] = await Promise.all([
    namespacesPromise,
    identityMapsPromise,
  ])

  if (namespacesResult.error) {
    throw fromSupabaseError(
      namespacesResult.error,
      'fetchCostCenterReadinessOverview',
      'puls_integration',
      'source_namespaces',
    )
  }

  if (identityMapsResult.error) {
    throw fromSupabaseError(
      identityMapsResult.error,
      'fetchCostCenterReadinessOverview',
      'puls_integration',
      'entity_identity_map',
    )
  }

  const namespaceById = new Map<string, NamespaceSnapshot>()
  for (const row of namespacesResult.data ?? []) {
    namespaceById.set(row.id as string, {
      id: row.id as string,
      isActive: Boolean(row.is_active),
      sourceType: row.source_type as string,
      name: row.name as string,
      code: row.code as string,
    })
  }

  const identityMapsByCostCenterId = new Map<string, IdentityMapSnapshot[]>()
  for (const row of identityMapsResult.data ?? []) {
    const canonicalId = row.canonical_id as string
    const snapshot: IdentityMapSnapshot = {
      isActive: Boolean(row.is_active),
      sourceNamespaceId: row.source_namespace_id as string,
      externalId: row.external_id as string,
      canonicalId,
      canonicalSchema: row.canonical_schema as string,
      canonicalTable: row.canonical_table as string,
      entityType: row.entity_type as string,
    }
    const list = identityMapsByCostCenterId.get(canonicalId) ?? []
    list.push(snapshot)
    identityMapsByCostCenterId.set(canonicalId, list)
  }

  const items: CostCenterReadinessItem[] = (costCenterRows ?? []).map((row) => {
    const id = row.id as string
    const sourceNamespaceId = (row.source_namespace_id as string | null) ?? null
    const namespace = sourceNamespaceId ? (namespaceById.get(sourceNamespaceId) ?? null) : null
    const input: CostCenterReadinessInput = {
      costCenterId: id,
      isActive: Boolean(row.is_active),
      sourceNamespaceId,
      externalId: (row.external_id as string | null) ?? null,
      namespace,
      identityMaps: identityMapsByCostCenterId.get(id) ?? [],
    }
    const { status, exportSourceType } = computeCostCenterReadinessResult(input)

    return {
      id,
      code: row.code as string,
      name: row.name as string,
      sourceName: namespace?.name ?? null,
      sourceCode: namespace?.code ?? null,
      sourceType: namespace?.sourceType ?? null,
      externalId: (row.external_id as string | null) ?? null,
      status,
      exportSourceType,
    }
  })

  const exportReadyCount = items.filter((item) => item.status === 'export_ready').length
  const needsMappingCount = items.filter((item) => item.status === 'needs_mapping').length

  const { data: categoryRows, error: categoryError } = await pulsWorkflow()
    .from('expense_categories')
    .select('name, approval_policy_id')
    .eq('tenant_id', tenantId)
    .eq('is_active', true)

  if (categoryError) {
    throw fromSupabaseError(
      categoryError,
      'fetchCostCenterReadinessOverview',
      'puls_workflow',
      'expense_categories',
    )
  }

  const policyIds = [
    ...new Set(
      (categoryRows ?? [])
        .map((row) => row.approval_policy_id as string | null)
        .filter((id): id is string => Boolean(id)),
    ),
  ]

  let routingWarnings: ExpenseRoutingReadinessWarning[] = []

  if (policyIds.length > 0) {
    const [policiesResult, stepsResult] = await Promise.all([
      pulsWorkflow()
        .from('approval_policies')
        .select('id, name')
        .eq('tenant_id', tenantId)
        .eq('module', 'expense')
        .eq('is_active', true)
        .in('id', policyIds),
      pulsWorkflow()
        .from('approval_policy_steps')
        .select('policy_id, approver_type, step_resolver_config')
        .eq('tenant_id', tenantId)
        .in('policy_id', policyIds),
    ])

    if (policiesResult.error) {
      throw fromSupabaseError(
        policiesResult.error,
        'fetchCostCenterReadinessOverview',
        'puls_workflow',
        'approval_policies',
      )
    }

    if (stepsResult.error) {
      throw fromSupabaseError(
        stepsResult.error,
        'fetchCostCenterReadinessOverview',
        'puls_workflow',
        'approval_policy_steps',
      )
    }

    routingWarnings = buildRoutingWarnings(
      items,
      (categoryRows ?? []).map((row) => ({
        approvalPolicyId: (row.approval_policy_id as string | null) ?? null,
        name: row.name as string,
      })),
      (policiesResult.data ?? []).map((row) => ({
        id: row.id as string,
        name: row.name as string,
      })),
      (stepsResult.data ?? []).map((row) => ({
        policyId: row.policy_id as string,
        approverType: row.approver_type as string,
        stepResolverConfig: row.step_resolver_config,
      })),
    )
  }

  return {
    items,
    exportReadyCount,
    needsMappingCount,
    routingWarnings,
  }
}

export async function fetchCostCenterReadinessOverview(
  userId: string,
): Promise<CostCenterReadinessOverview> {
  return resolveAdapterData({
    operation: 'fetchCostCenterReadinessOverview',
    fetchReal: () => fetchRealCostCenterReadinessOverview(userId),
    fetchDemo: fetchDemoCostCenterReadinessOverview,
    isEmpty: isCostCenterReadinessEmpty,
  })
}
