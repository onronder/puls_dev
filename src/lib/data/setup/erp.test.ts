import { afterEach, describe, expect, it, vi } from 'vitest'

import {
  buildDefaultConnectorFieldMappings,
  buildDemoErpOverview,
  fetchErpOverviewWithMeta,
  isErpOverviewEmpty,
  mapConnectorSetupError,
  mapProviderLabel,
  requestConnectorCredentialHandoff,
  runConnectorImportPreview,
  runConnectorPreflight,
  startConnectorSetup,
} from '#/lib/data/setup/erp'
import { DataAdapterError } from '#/lib/data/errors'

vi.mock('#/lib/data/demo-mode', () => ({
  isPulsDemoModeEnabled: vi.fn(),
}))

vi.mock('#/lib/data/client', () => ({
  pulsCalc: vi.fn(),
  pulsIntegration: vi.fn(),
  resolveTenantContext: vi.fn(),
}))

import { isPulsDemoModeEnabled } from '#/lib/data/demo-mode'
import { pulsCalc, pulsIntegration, resolveTenantContext } from '#/lib/data/client'

const demoEnabled = vi.mocked(isPulsDemoModeEnabled)
const resolveTenant = vi.mocked(resolveTenantContext)

function mockTenantContext() {
  return {
    tenantId: 'a0000001-0001-4001-8001-000000000001',
    tenantName: 'Puls Teknik',
    employeeId: 'a0000006-0006-4006-8006-000000000001',
    employeeName: 'Test User',
    personaRole: 'superadmin' as const,
  }
}

function mockTenantContextWithoutTenant() {
  return {
    tenantId: null,
    tenantName: null,
    employeeId: null,
    employeeName: null,
    personaRole: 'employee' as const,
  }
}

type QueryResult = {
  data?: unknown
  error?: unknown
  maybeSingleData?: unknown
  maybeSingleError?: unknown
  singleData?: unknown
  singleError?: unknown
}

type ClientCapture = {
  updates?: Array<{ table: string; payload: unknown }>
  inserts?: Array<{ table: string; payload: unknown }>
  rpcCalls?: Array<{ fn: string; args: unknown }>
}

function query(result: QueryResult, table = 'unknown', capture?: ClientCapture) {
  const builder = {
    select: vi.fn(() => builder),
    eq: vi.fn(() => builder),
    in: vi.fn(() => builder),
    order: vi.fn(() => builder),
    limit: vi.fn(() => builder),
    maybeSingle: vi.fn(async () => ({
      data: 'maybeSingleData' in result ? result.maybeSingleData : result.data,
      error: 'maybeSingleError' in result ? result.maybeSingleError : result.error,
    })),
    single: vi.fn(async () => ({
      data: 'singleData' in result ? result.singleData : result.data,
      error: 'singleError' in result ? result.singleError : result.error,
    })),
    insert: vi.fn((payload: unknown) => {
      capture?.inserts?.push({ table, payload })
      return builder
    }),
    update: vi.fn((payload: unknown) => {
      capture?.updates?.push({ table, payload })
      return builder
    }),
    then(onFulfilled: (value: QueryResult) => unknown, onRejected?: (reason: unknown) => unknown) {
      return Promise.resolve(result).then(onFulfilled, onRejected)
    },
  }
  return builder
}

function client(results: Record<string, QueryResult>, capture?: ClientCapture) {
  return {
    from: vi.fn((table: string) =>
      query(results[table] ?? { data: [], error: null }, table, capture),
    ),
    rpc: vi.fn((fn: string, args: unknown) => {
      capture?.rpcCalls?.push({ fn, args })
      return Promise.resolve(results[`rpc:${fn}`] ?? { data: null, error: null })
    }),
  }
}

function setupSeededMocks(
  overrides: Partial<Record<string, QueryResult>> = {},
  capture?: ClientCapture,
) {
  resolveTenant.mockResolvedValue(mockTenantContext())
  vi.mocked(pulsIntegration).mockImplementation(
    () =>
      client({
        erp_connections: {
          data: [
            {
              provider: 'canias',
              id: 'connection-1',
              display_name: 'Canias ERP (Pasif)',
              connection_method: 'rest_api',
              connection_key: 'canias-default',
              is_active: false,
              last_sync_at: null,
              last_status: null,
              setup_status: 'mapping_ready',
              setup_step: 'preflight',
              is_enabled: true,
              owned_domains: ['employees', 'departments', 'positions', 'cost_centers'],
              auth_mode: 'custom_secret_ref',
              credential_required: true,
              credential_state: 'missing',
              credential_last_verified_at: null,
              credential_last_failed_at: null,
              credential_error_code: null,
              credential_handoff_status: 'not_started',
              credential_handoff_requested_at: null,
              credential_handoff_requested_by_employee_id: null,
              credential_handoff_updated_at: null,
              created_at: '2026-06-01T00:00:00.000Z',
              updated_at: '2026-06-01T00:00:00.000Z',
            },
          ],
        },
        erp_field_mappings: {
          data: [
            ...buildDefaultConnectorFieldMappings('canias').map((mapping) => ({
              source_entity: mapping.sourceEntity,
              source_field: mapping.sourceField,
              target_schema: mapping.targetSchema,
              target_table: mapping.targetTable,
              target_field: mapping.targetField,
              is_required: mapping.required,
              is_sensitive: false,
              is_active: true,
            })),
            {
              source_entity: 'employee',
              source_field: 'REDACTED_FIELD',
              target_schema: 'puls_core',
              target_table: 'employees',
              target_field: 'private_marker',
              is_required: false,
              is_sensitive: true,
              is_active: true,
            },
          ],
        },
        erp_sync_batches: { data: [] },
        source_namespaces: {
          data: [
            {
              id: 'namespace-1',
              code: 'CANIAS',
              name: 'Canias ERP Kaynagi',
              source_type: 'erp',
              connection_id: 'connection-1',
            },
          ],
        },
        entity_identity_map: {
          data: [{ source_namespace_id: 'namespace-1', canonical_table: 'departments' }],
        },
        import_batches: { data: [] },
        ...overrides,
      }, capture) as never,
  )
  vi.mocked(pulsCalc).mockImplementation(
    () =>
      client({
        setup_readiness_summary: { data: { integration_setup_pct: 80 }, error: null },
      }) as never,
  )
}

describe('ERP connector overview helpers', () => {
  afterEach(() => {
    vi.clearAllMocks()
  })

  it('does not collapse unknown providers into Canias', () => {
    expect(mapProviderLabel('logo')).toBe('Logo')
    expect(mapProviderLabel('workday_custom')).toBe('Workday Custom')
    expect(mapProviderLabel(null)).toBe('External data source')
  })

  it('enriches the legacy demo ERP payload into connector overview shape', async () => {
    const overview = await buildDemoErpOverview()

    expect(overview.provider.code).toBe('canias')
    expect(overview.readiness.checks.length).toBeGreaterThan(0)
    expect(overview.setupSteps.map((step) => step.id)).toEqual([
      'source',
      'mapping',
      'namespace',
      'preflight',
      'runtime',
    ])
    expect(overview.guardrails.some((guardrail) => guardrail.id === 'no_erp_writes')).toBe(true)
    expect(isErpOverviewEmpty(overview)).toBe(false)
  })

  it('builds a seed-proven default Canias mapping contract without customer-specific fields', () => {
    const mappings = buildDefaultConnectorFieldMappings('canias')

    expect(mappings).toHaveLength(12)
    expect(mappings.filter((mapping) => mapping.required)).toHaveLength(8)
    expect(mappings).toContainEqual({
      sourceEntity: 'employee',
      sourceField: 'EMPLOYEE_CODE',
      targetSchema: 'puls_core',
      targetTable: 'employees',
      targetField: 'employee_code',
      required: true,
    })
    expect(mappings.some((mapping) => mapping.sourceField === 'TBD_FROM_CUSTOMER_DISCOVERY')).toBe(
      false,
    )
  })
})

describe('fetchErpOverviewWithMeta', () => {
  afterEach(() => {
    vi.clearAllMocks()
  })

  it('returns real connector preflight data and hides sensitive field mappings', async () => {
    demoEnabled.mockReturnValue(false)
    setupSeededMocks({
      erp_sync_batches: {
        data: [
          {
            id: 'batch-preflight',
            created_at: '2026-06-03T13:00:00.000Z',
            status: 'partial_success',
            sync_type: 'setup_preflight',
            event_key: 'setup_preflight_completed',
            actor_employee_id: 'a0000006-0006-4006-8006-000000000001',
            safe_error_code: 'setup_preflight_has_warnings',
            safe_error_context: { warning_count: 1 },
            next_action_key: 'review_setup_findings',
            records_seen: 7,
            records_inserted: 6,
            records_updated: 1,
            records_failed: 0,
          },
          {
            id: 'batch-setup',
            created_at: '2026-06-03T12:00:00.000Z',
            status: 'success',
            sync_type: 'setup_lifecycle',
            event_key: 'setup_mapping_contract_ready',
            actor_employee_id: 'a0000006-0006-4006-8006-000000000001',
            safe_error_code: null,
            safe_error_context: { mapping_contract_ready: true },
            next_action_key: 'review_identity_scope',
            records_seen: 4,
            records_inserted: 12,
            records_updated: 1,
            records_failed: 0,
          },
        ],
      },
    })

    const result = await fetchErpOverviewWithMeta('user-1')

    expect(result.source).toBe('real')
    expect(result.status).toBe('success')
    expect(result.data.provider.label).toBe('Canias ERP (Pasif)')
    expect(result.data.provider.status).toBe('mapping_ready')
    expect(result.data.setup.status).toBe('mapping_ready')
    expect(result.data.setupSummary).toEqual({
      labelKey: 'erp.metrics.setup',
      valueKey: 'erp.setupSummary.values.credentialPending',
      hintKey: 'erp.setupSummary.hints.credentialPending',
      progress: null,
    })
    expect(result.data.setupSteps.map((step) => step.status)).toEqual([
      'ready',
      'ready',
      'ready',
      'partial',
      'ready',
    ])
    expect(result.data.credentialBoundary).toMatchObject({
      authMode: 'custom_secret_ref',
      required: true,
      state: 'missing',
      status: 'partial',
    })
    expect(result.data.credentialHandoff).toMatchObject({
      status: 'not_started',
      action: 'request_secure_reference',
      requestable: true,
      blockedBy: 'none',
      captureBoundary: 'server_side_write_only',
    })
    expect(result.data.lifecycle).toMatchObject({
      stage: 'credential',
      status: 'partial',
      runtimeEligible: false,
    })
    expect(
      result.data.capabilities.find((capability) => capability.id === 'domain_ownership'),
    ).toMatchObject({
      status: 'ready',
    })
    expect(
      result.data.capabilities.find((capability) => capability.id === 'api_runtime'),
    ).toMatchObject({
      status: 'blocked',
    })
    expect(result.data.domainOwnership.find((domain) => domain.id === 'employees')).toMatchObject({
      status: 'owned_by_current',
      ownerProviderLabel: 'Canias ERP (Pasif)',
    })
    expect(result.data.domainOwnership.find((domain) => domain.id === 'locations')).toMatchObject({
      status: 'available',
      ownerProviderLabel: null,
    })
    expect(result.data.namespaces).toHaveLength(1)
    expect(result.data.canonicalClasses.find((row) => row.id === 'employees')).toMatchObject({
      mappedFields: 4,
      mappedRequiredFields: 2,
      requiredFields: 2,
      status: 'ready',
    })
    expect(result.data.preflight).toMatchObject({
      status: 'partial',
      passedCount: 6,
      warningCount: 1,
      blockedCount: 0,
      safeToRunRuntime: false,
      runtimeExecution: 'not_started',
    })
    expect(result.data.preflight.checks.map((check) => check.id)).toEqual([
      'source_profile',
      'required_mapping',
      'source_namespace',
      'identity_reconciliation',
      'credential_boundary',
      'runtime_boundary',
      'write_guardrail',
    ])
    expect(result.data.mappings).toHaveLength(12)
    expect(result.data.mappings[0].canonicalField).toBe('puls_core.employees.employee_code')
    expect(result.data.mappings.some((mapping) => mapping.sourceField === 'REDACTED_FIELD')).toBe(
      false,
    )
    expect(result.data.activityTimeline).toHaveLength(2)
    expect(result.data.activityTimeline[0]).toMatchObject({
      kind: 'setup_preflight',
      level: 'warning',
      titleKey: 'erp.activityTimeline.events.setup_preflight_completed.title',
      safeErrorCode: 'setup_preflight_has_warnings',
      safeErrorSummaryKey: 'erp.activityTimeline.safeErrors.setup_preflight_has_warnings',
      nextActionKey: 'erp.activityTimeline.nextActions.review_setup_findings',
      actorLabelKey: 'erp.activityTimeline.actors.admin',
    })
    expect(result.data.activityTimeline[1]).toMatchObject({
      kind: 'setup_lifecycle',
      titleKey: 'erp.activityTimeline.events.setup_mapping_contract_ready.title',
      nextActionKey: 'erp.activityTimeline.nextActions.review_identity_scope',
    })
    expect(JSON.stringify(result.data)).not.toContain('credentials_ref')
  })

  it('surfaces safe dry-run import preview records without payload readback', async () => {
    demoEnabled.mockReturnValue(false)
    setupSeededMocks({
      import_batches: {
        data: [
          {
            id: 'batch-import-preview',
            source_namespace_id: 'namespace-1',
            status: 'previewed',
            mode: 'dry_run',
            source_checksum: 'pr14_16_connector_preview_proof_v1',
            row_count: 3,
            create_count: 1,
            update_count: 1,
            skip_count: 1,
            error_count: 0,
            violation_count: 0,
            validated_at: '2026-06-03T14:00:00.000Z',
            previewed_at: '2026-06-03T14:01:00.000Z',
            created_at: '2026-06-03T13:59:00.000Z',
            updated_at: '2026-06-03T14:01:00.000Z',
          },
        ],
      },
      'rpc:list_connector_import_preview_records': {
        data: [
          {
            id: 'record-1',
            tenant_id: 'a0000001-0001-4001-8001-000000000001',
            batch_id: 'batch-import-preview',
            row_number: 1,
            entity_type: 'employee',
            external_id: 'EMP-1',
            status: 'validated',
            error_codes: [],
            warning_codes: ['NORMALIZED_EMAIL'],
            canonical_id: null,
            preview_action: 'create',
            preview_skip_code: null,
            created_at: '2026-06-03T13:59:00.000Z',
            updated_at: '2026-06-03T14:01:00.000Z',
            previewed_at: '2026-06-03T14:01:00.000Z',
            sanitized_payload: { email: 'secret-person@example.com' },
            normalized_payload: { employee_code: 'EMP-1' },
          },
          {
            id: 'record-2',
            tenant_id: 'a0000001-0001-4001-8001-000000000001',
            batch_id: 'batch-import-preview',
            row_number: 2,
            entity_type: 'department',
            external_id: 'DEPT-1',
            status: 'validated',
            error_codes: [],
            warning_codes: [],
            canonical_id: '11111111-1111-4111-8111-111111111111',
            preview_action: 'update',
            preview_skip_code: null,
            created_at: '2026-06-03T13:59:00.000Z',
            updated_at: '2026-06-03T14:01:00.000Z',
            previewed_at: '2026-06-03T14:01:00.000Z',
            raw_payload: { password: 'must-not-render' },
          },
          {
            id: 'record-3',
            tenant_id: 'a0000001-0001-4001-8001-000000000001',
            batch_id: 'batch-import-preview',
            row_number: 3,
            entity_type: 'cost_center',
            external_id: 'CC-1',
            status: 'validated',
            error_codes: [],
            warning_codes: [],
            canonical_id: '22222222-2222-4222-8222-222222222222',
            preview_action: 'skip',
            preview_skip_code: 'hash_unchanged',
            created_at: '2026-06-03T13:59:00.000Z',
            updated_at: '2026-06-03T14:01:00.000Z',
            previewed_at: '2026-06-03T14:01:00.000Z',
          },
        ],
      },
    })

    const result = await fetchErpOverviewWithMeta('user-1')

    expect(result.source).toBe('real')
    expect(result.data.importPreview).toMatchObject({
      status: 'preview_ready',
      readiness: 'ready',
      action: 'review_preview',
      safeToApply: false,
      summary: {
        rowCount: 3,
        createCount: 1,
        updateCount: 1,
        skipCount: 1,
        errorCount: 0,
        warningCount: 1,
      },
    })
    expect(result.data.importPreview.records.map((record) => record.action)).toEqual([
      'create',
      'update',
      'skip',
    ])
    const serialized = JSON.stringify(result.data.importPreview)
    expect(serialized).not.toContain('raw_payload')
    expect(serialized).not.toContain('sanitized_payload')
    expect(serialized).not.toContain('normalized_payload')
    expect(serialized).not.toContain('secret-person@example.com')
    expect(serialized).not.toContain('must-not-render')
  })

  it('returns real empty when tenant is missing and demo mode is off', async () => {
    demoEnabled.mockReturnValue(false)
    resolveTenant.mockResolvedValue(mockTenantContextWithoutTenant())

    const result = await fetchErpOverviewWithMeta('user-1')

    expect(result.source).toBe('real')
    expect(result.status).toBe('empty')
    expect(result.data.readiness.status).toBe('blocked')
    expect(result.data.setupSteps.every((step) => step.status === 'blocked')).toBe(true)
  })

  it('returns real no-connector onboarding state without demo fallback', async () => {
    demoEnabled.mockReturnValue(true)
    setupSeededMocks({
      erp_connections: { data: null, error: null },
      erp_field_mappings: { data: [], error: null },
      erp_sync_batches: { data: [], error: null },
      source_namespaces: { data: [], error: null },
      entity_identity_map: { data: [], error: null },
    })

    const result = await fetchErpOverviewWithMeta('user-1')

    expect(result.source).toBe('real')
    expect(result.status).toBe('success')
    expect(result.data.connectorState).toBe('no_connector')
    expect(result.data.preflight.status).toBe('blocked')
    expect(result.data.lifecycle).toMatchObject({
      stage: 'source_selection',
      status: 'partial',
    })
    expect(result.data.domainOwnership.every((domain) => domain.status === 'available')).toBe(true)
    expect(result.data.setupSteps.map((step) => step.status)).toEqual([
      'partial',
      'blocked',
      'blocked',
      'blocked',
      'blocked',
    ])
    expect(result.data.providerOptions.map((option) => option.id)).toEqual([
      'canias',
      'logo',
      'csv_import',
      'custom_api',
    ])
    expect(result.data.providerOptions.every((option) => option.requirements.length > 0)).toBe(true)
    expect(result.data.providerOptions[0].readinessLabelKey).toBe(
      'erp.providerOptions.canias.readiness',
    )
    expect(isErpOverviewEmpty(result.data)).toBe(false)
  })

  it('shows mapping-ready setup summary without implying preflight readiness', async () => {
    demoEnabled.mockReturnValue(false)
    setupSeededMocks({
      erp_connections: {
        data: [
          {
            provider: 'canias',
            id: 'connection-draft',
            display_name: 'Canias',
            connection_method: 'rest_api',
            is_active: false,
            last_sync_at: null,
            last_status: null,
            setup_status: 'draft',
            setup_step: 'mapping',
            is_enabled: true,
            owned_domains: [],
            auth_mode: 'custom_secret_ref',
            credential_required: true,
            credential_state: 'missing',
            created_at: '2026-06-01T00:00:00.000Z',
            updated_at: '2026-06-01T00:00:00.000Z',
          },
        ],
      },
      erp_field_mappings: {
        data: [
          {
            source_entity: 'employee',
            source_field: 'EMPLOYEE_CODE',
            target_schema: 'puls_core',
            target_table: 'employees',
            target_field: 'employee_code',
            is_required: true,
            is_sensitive: false,
            is_active: true,
          },
          {
            source_entity: 'employee',
            source_field: 'FULL_NAME',
            target_schema: 'puls_core',
            target_table: 'employees',
            target_field: 'full_name',
            is_required: true,
            is_sensitive: false,
            is_active: true,
          },
          {
            source_entity: 'location',
            source_field: 'LOC_CODE',
            target_schema: 'puls_core',
            target_table: 'locations',
            target_field: 'code',
            is_required: false,
            is_sensitive: false,
            is_active: true,
          },
        ],
        error: null,
      },
      source_namespaces: { data: [], error: null },
      entity_identity_map: { data: [], error: null },
    })

    const result = await fetchErpOverviewWithMeta('user-1')

    expect(result.source).toBe('real')
    expect(result.data.provider.status).toBe('mapping_ready')
    expect(result.data.readiness.score).toBeGreaterThan(0)
    expect(result.data.setupSummary).toEqual({
      labelKey: 'erp.metrics.setup',
      valueKey: 'erp.setupSummary.values.mappingReady',
      hintKey: 'erp.setupSummary.hints.namespacePending',
      progress: null,
    })
    expect(result.data.canonicalClasses.find((row) => row.id === 'locations')).toMatchObject({
      mappedFields: 1,
      totalFields: 1,
      mappedRequiredFields: 0,
      requiredFields: 0,
      status: 'ready',
    })
    expect(result.data.preflight).toMatchObject({
      status: 'blocked',
      blockedCount: 1,
      safeToRunRuntime: false,
      runtimeExecution: 'not_started',
    })
    expect(result.data.credentialHandoff).toMatchObject({
      action: 'complete_setup_first',
      requestable: false,
      blockedBy: 'namespace',
    })
  })

  it('uses enriched demo fallback only when demo mode is enabled', async () => {
    demoEnabled.mockReturnValue(true)
    resolveTenant.mockResolvedValue(mockTenantContextWithoutTenant())

    const result = await fetchErpOverviewWithMeta('user-1')

    expect(result.source).toBe('demo')
    expect(result.status).toBe('success')
    expect(result.fallbackReason).toBe('empty')
    expect(result.data.provider.code).toBe('canias')
    expect(result.data.guardrails.length).toBeGreaterThan(0)
  })

  it('keeps provider labels source-neutral for non-Canias providers', async () => {
    demoEnabled.mockReturnValue(false)
    setupSeededMocks({
      erp_connections: {
        data: [
          {
            provider: 'logo',
            id: 'connection-2',
            display_name: null,
            connection_method: 'rest_api',
            is_active: false,
            last_sync_at: null,
            last_status: null,
            setup_status: 'draft',
            setup_step: 'mapping',
            is_enabled: true,
            owned_domains: [],
            auth_mode: 'custom_secret_ref',
            credential_required: true,
            credential_state: 'missing',
            created_at: '2026-06-01T00:00:00.000Z',
            updated_at: '2026-06-01T00:00:00.000Z',
          },
        ],
      },
    })

    const result = await fetchErpOverviewWithMeta('user-1')

    expect(result.source).toBe('real')
    expect(result.data.provider.label).toBe('Logo')
    expect(result.data.status.system).toBe('Logo')
  })

  it('treats CSV / Excel setup as credential-not-required without leaking secret refs', async () => {
    demoEnabled.mockReturnValue(false)
    setupSeededMocks({
      erp_connections: {
        data: [
          {
            provider: 'csv',
            id: 'connection-csv',
            display_name: 'CSV / Excel',
            connection_method: 'manual_import',
            is_active: false,
            last_sync_at: null,
            last_status: null,
            setup_status: 'mapping_ready',
            setup_step: 'namespace',
            is_enabled: true,
            owned_domains: ['employees'],
            auth_mode: 'none',
            credential_required: false,
            credential_state: 'not_required',
            credentials_ref: 'secret://must-not-leak',
            created_at: '2026-06-01T00:00:00.000Z',
            updated_at: '2026-06-01T00:00:00.000Z',
          },
        ],
      },
    })

    const result = await fetchErpOverviewWithMeta('user-1')

    expect(result.source).toBe('real')
    expect(result.data.credentialBoundary).toMatchObject({
      authMode: 'none',
      required: false,
      state: 'not_required',
      status: 'ready',
    })
    expect(result.data.credentialHandoff).toMatchObject({
      status: 'not_required',
      action: 'none',
      requestable: false,
      blockedBy: 'not_required',
    })
    expect(
      result.data.capabilities.find((capability) => capability.id === 'transfer_method'),
    ).toMatchObject({
      status: 'ready',
    })
    expect(result.data.domainOwnership.find((domain) => domain.id === 'employees')).toMatchObject({
      status: 'owned_by_current',
      ownerProviderLabel: 'CSV / Excel',
    })
    expect(
      result.data.preflight.checks.find((check) => check.id === 'credential_boundary'),
    ).toMatchObject({
      status: 'ready',
    })
    expect(JSON.stringify(result.data)).not.toContain('secret://must-not-leak')
  })

  it('creates an admin-scoped Canias setup draft', async () => {
    resolveTenant.mockResolvedValue(mockTenantContext())
    const capture: ClientCapture = { inserts: [] }
    const integrationClient = client({
      erp_connections: {
        maybeSingleData: null,
        error: null,
        singleData: { id: 'connection-new' },
      },
      erp_field_mappings: { data: [], error: null },
    }, capture)
    vi.mocked(pulsIntegration).mockReturnValue(integrationClient as never)

    const result = await startConnectorSetup('user-1', { providerId: 'canias' })

    expect(result).toEqual({
      connectionId: 'connection-new',
      providerId: 'canias',
      setupStatus: 'mapping_ready',
      currentStep: 'namespace',
    })
    expect(integrationClient.from).toHaveBeenCalledWith('erp_connections')
    expect(integrationClient.from).toHaveBeenCalledWith('erp_field_mappings')
    expect(capture.inserts).toContainEqual({
      table: 'erp_sync_batches',
      payload: expect.objectContaining({
        sync_type: 'setup_lifecycle',
        event_key: 'setup_mapping_contract_ready',
        actor_employee_id: 'a0000006-0006-4006-8006-000000000001',
        safe_error_code: null,
        safe_error_context: expect.objectContaining({
          source_profile: 'canias',
          mapping_contract_ready: true,
        }),
        next_action_key: 'review_identity_scope',
      }),
    })
    expect(JSON.stringify(capture.inserts)).not.toContain('secret://')
  })

  it('keeps existing connector setup posture instead of downgrading to draft', async () => {
    resolveTenant.mockResolvedValue(mockTenantContext())
    const integrationClient = client({
      erp_connections: {
        data: [
          {
            id: 'connection-existing',
            provider: 'canias',
            connection_key: 'canias-default',
            setup_status: 'preflight_ready',
            setup_step: 'preflight',
            is_enabled: true,
            owned_domains: ['employees'],
            created_at: '2026-06-01T00:00:00.000Z',
            updated_at: '2026-06-01T00:00:00.000Z',
          },
        ],
        error: null,
      },
    })
    vi.mocked(pulsIntegration).mockReturnValue(integrationClient as never)

    const result = await startConnectorSetup('user-1', { providerId: 'canias' })

    expect(result).toEqual({
      connectionId: 'connection-existing',
      providerId: 'canias',
      setupStatus: 'preflight_ready',
      currentStep: 'preflight',
    })
    expect(integrationClient.from).toHaveBeenCalledTimes(1)
  })

  it('picks the strongest existing connector instead of a newer duplicate draft', async () => {
    demoEnabled.mockReturnValue(false)
    setupSeededMocks({
      erp_connections: {
        data: [
          {
            provider: 'canias',
            id: 'connection-draft',
            display_name: 'Canias',
            connection_method: 'rest_api',
            connection_key: 'canias-default',
            is_active: false,
            setup_status: 'draft',
            setup_step: 'mapping',
            is_enabled: true,
            owned_domains: ['employees', 'departments'],
            auth_mode: 'custom_secret_ref',
            credential_required: true,
            credential_state: 'missing',
            created_at: '2026-06-03T00:00:00.000Z',
            updated_at: '2026-06-03T00:00:00.000Z',
          },
          {
            provider: 'canias',
            id: 'connection-current',
            display_name: 'Canias ERP (Pasif)',
            connection_method: 'rest_api',
            connection_key: 'canias-default',
            is_active: false,
            setup_status: 'mapping_ready',
            setup_step: 'preflight',
            is_enabled: true,
            owned_domains: ['employees', 'departments', 'positions', 'cost_centers'],
            auth_mode: 'custom_secret_ref',
            credential_required: true,
            credential_state: 'missing',
            created_at: '2026-06-01T00:00:00.000Z',
            updated_at: '2026-06-01T00:00:00.000Z',
          },
        ],
      },
    })

    const result = await fetchErpOverviewWithMeta('user-1')

    expect(result.data.provider.id).toBe('connection-current')
    expect(result.data.setup.status).toBe('mapping_ready')
  })

  it('blocks a second source from owning an already mapped canonical domain', async () => {
    resolveTenant.mockResolvedValue(mockTenantContext())
    const integrationClient = client({
      erp_connections: {
        data: [
          {
            id: 'connection-canias',
            provider: 'canias',
            connection_key: 'canias-default',
            setup_status: 'mapping_ready',
            setup_step: 'preflight',
            is_enabled: true,
            owned_domains: ['employees', 'departments'],
            created_at: '2026-06-01T00:00:00.000Z',
            updated_at: '2026-06-01T00:00:00.000Z',
          },
        ],
        error: null,
      },
    })
    vi.mocked(pulsIntegration).mockReturnValue(integrationClient as never)

    await expect(startConnectorSetup('user-1', { providerId: 'csv_import' })).rejects.toMatchObject(
      {
        code: 'PULS_CONNECTOR_DOMAIN_OWNED',
        i18nKey: 'erp.errors.domainOwned',
      },
    )
  })

  it('persists a dry-run preflight record without enabling runtime', async () => {
    resolveTenant.mockResolvedValue(mockTenantContext())
    const capture: ClientCapture = { updates: [], inserts: [] }
    setupSeededMocks({}, capture)

    const result = await runConnectorPreflight('user-1')

    expect(result).toEqual({
      connectionId: 'connection-1',
      status: 'partial',
      passedCount: 6,
      warningCount: 1,
      blockedCount: 0,
    })
    expect(capture.inserts).toContainEqual({
      table: 'erp_sync_batches',
      payload: expect.objectContaining({
        sync_type: 'setup_preflight',
        event_key: 'setup_preflight_completed',
        status: 'partial_success',
        safe_error_code: 'setup_preflight_has_warnings',
        safe_error_context: expect.objectContaining({
          checks_total: 7,
          warning_count: 1,
          blocked_count: 0,
        }),
        next_action_key: 'review_setup_findings',
      }),
    })
  })

  it('persists credential handoff request without configuring credentials', async () => {
    resolveTenant.mockResolvedValue(mockTenantContext())
    const capture: ClientCapture = { updates: [], inserts: [] }
    vi.mocked(pulsIntegration).mockImplementation(
      () =>
        client(
          {
            erp_connections: {
              data: [
                {
                  provider: 'canias',
                  id: 'connection-1',
                  display_name: 'Canias ERP (Pasif)',
                  connection_method: 'rest_api',
                  connection_key: 'canias-default',
                  is_active: false,
                  last_sync_at: null,
                  last_status: null,
                  setup_status: 'mapping_ready',
                  setup_step: 'preflight',
                  is_enabled: true,
                  owned_domains: ['employees', 'departments', 'positions', 'cost_centers'],
                  auth_mode: 'custom_secret_ref',
                  credential_required: true,
                  credential_state: 'missing',
                  credential_last_verified_at: null,
                  credential_last_failed_at: null,
                  credential_error_code: null,
                  credential_handoff_status: 'not_started',
                  credential_handoff_requested_at: null,
                  credential_handoff_requested_by_employee_id: null,
                  credential_handoff_updated_at: null,
                  created_at: '2026-06-01T00:00:00.000Z',
                  updated_at: '2026-06-01T00:00:00.000Z',
                },
              ],
              singleData: { id: 'connection-1' },
            },
            erp_field_mappings: {
              data: buildDefaultConnectorFieldMappings('canias').map((mapping) => ({
                source_entity: mapping.sourceEntity,
                source_field: mapping.sourceField,
                target_schema: mapping.targetSchema,
                target_table: mapping.targetTable,
                target_field: mapping.targetField,
                is_required: mapping.required,
                is_sensitive: false,
                is_active: true,
              })),
            },
            erp_sync_batches: { data: [], singleData: { id: 'handoff-log-1' } },
            source_namespaces: {
              data: [
                {
                  id: 'namespace-1',
                  code: 'CANIAS',
                  name: 'Canias ERP Kaynagi',
                  source_type: 'erp',
                  connection_id: 'connection-1',
                },
              ],
            },
            entity_identity_map: {
              data: [{ source_namespace_id: 'namespace-1', canonical_table: 'departments' }],
            },
          },
          capture,
        ) as never,
    )
    vi.mocked(pulsCalc).mockImplementation(
      () =>
        client({
          setup_readiness_summary: { data: { integration_setup_pct: 80 }, error: null },
        }) as never,
    )

    const result = await requestConnectorCredentialHandoff('user-1')

    expect(result.status).toBe('requested')
    expect(capture.updates).toContainEqual({
      table: 'erp_connections',
      payload: expect.objectContaining({
        credential_handoff_status: 'requested',
        credential_handoff_requested_by_employee_id: 'a0000006-0006-4006-8006-000000000001',
      }),
    })
    expect(JSON.stringify(capture.updates)).not.toContain('credential_state')
    expect(JSON.stringify(capture.updates)).not.toContain('configured')
    expect(capture.inserts).toContainEqual({
      table: 'erp_sync_batches',
      payload: expect.objectContaining({
        sync_type: 'credential_handoff',
        event_key: 'credential_handoff_requested',
        actor_employee_id: 'a0000006-0006-4006-8006-000000000001',
        status: 'partial_success',
        safe_error_code: null,
        safe_error_context: expect.objectContaining({
          handoff_request_recorded: true,
          reference_available: false,
        }),
        next_action_key: 'wait_for_secure_reference',
      }),
    })
  })

  it('runs connector import preview as validate plus diff without applying records', async () => {
    resolveTenant.mockResolvedValue(mockTenantContext())
    demoEnabled.mockReturnValue(false)
    const capture: ClientCapture = { inserts: [], rpcCalls: [] }
    setupSeededMocks(
      {
        import_batches: {
          data: [
            {
              id: 'batch-import-preview',
              source_namespace_id: 'namespace-1',
              status: 'uploaded',
              mode: 'dry_run',
              source_checksum: 'pr14_16_connector_preview_proof_v1',
              row_count: 2,
              create_count: 0,
              update_count: 0,
              skip_count: 0,
              error_count: 0,
              violation_count: 0,
              validated_at: null,
              previewed_at: null,
              created_at: '2026-06-03T13:59:00.000Z',
              updated_at: '2026-06-03T13:59:00.000Z',
            },
          ],
        },
        'rpc:list_connector_import_preview_records': { data: [] },
        'rpc:validate_import_batch': {
          data: {
            row_count: 2,
            error_count: 0,
          },
          error: null,
        },
        'rpc:preview_import_diff': {
          data: {
            create_count: 1,
            update_count: 1,
            skip_count: 0,
          },
          error: null,
        },
      },
      capture,
    )

    const result = await runConnectorImportPreview('user-1')

    expect(result).toMatchObject({
      connectionId: 'connection-1',
      batchId: 'batch-import-preview',
      status: 'preview_ready',
      rowCount: 2,
      createCount: 1,
      updateCount: 1,
      skipCount: 0,
      errorCount: 0,
    })
    expect(capture.rpcCalls?.map((call) => call.fn)).toEqual([
      'list_connector_import_preview_records',
      'validate_import_batch',
      'preview_import_diff',
    ])
    expect(capture.rpcCalls?.some((call) => call.fn === 'apply_import_batch')).toBe(false)
    expect(capture.inserts).toContainEqual({
      table: 'erp_sync_batches',
      payload: expect.objectContaining({
        sync_type: 'import_preview',
        event_key: 'import_preview_generated',
        status: 'success',
        safe_error_code: null,
        safe_error_context: expect.objectContaining({
          mode: 'dry_run',
          source_namespace_code: 'CANIAS',
          row_count: 2,
          create_count: 1,
          update_count: 1,
          skip_count: 0,
        }),
        next_action_key: 'review_import_preview',
      }),
    })
    expect(JSON.stringify(capture.inserts)).not.toContain('raw_payload')
    expect(JSON.stringify(capture.inserts)).not.toContain('credentials_ref')
  })

  it('blocks connector import preview on validation errors and records safe activity only', async () => {
    resolveTenant.mockResolvedValue(mockTenantContext())
    demoEnabled.mockReturnValue(false)
    const capture: ClientCapture = { inserts: [], rpcCalls: [] }
    setupSeededMocks(
      {
        import_batches: {
          data: [
            {
              id: 'batch-import-preview',
              source_namespace_id: 'namespace-1',
              status: 'uploaded',
              mode: 'dry_run',
              source_checksum: 'pr14_16_connector_preview_proof_v1',
              row_count: 4,
              create_count: 0,
              update_count: 0,
              skip_count: 0,
              error_count: 0,
              violation_count: 0,
              validated_at: null,
              previewed_at: null,
              created_at: '2026-06-03T13:59:00.000Z',
              updated_at: '2026-06-03T13:59:00.000Z',
            },
          ],
        },
        'rpc:list_connector_import_preview_records': { data: [] },
        'rpc:validate_import_batch': {
          data: {
            row_count: 4,
            error_count: 2,
          },
          error: null,
        },
      },
      capture,
    )

    const result = await runConnectorImportPreview('user-1')

    expect(result).toMatchObject({
      connectionId: 'connection-1',
      batchId: 'batch-import-preview',
      status: 'blocked',
      rowCount: 4,
      createCount: 0,
      updateCount: 0,
      skipCount: 0,
      errorCount: 2,
    })
    expect(capture.rpcCalls?.map((call) => call.fn)).toEqual([
      'list_connector_import_preview_records',
      'validate_import_batch',
    ])
    expect(capture.rpcCalls?.some((call) => call.fn === 'preview_import_diff')).toBe(false)
    expect(capture.inserts).toContainEqual({
      table: 'erp_sync_batches',
      payload: expect.objectContaining({
        sync_type: 'import_preview',
        event_key: 'import_preview_blocked',
        status: 'partial_success',
        safe_error_code: 'import_preview_has_errors',
        safe_error_context: expect.objectContaining({
          mode: 'dry_run',
          source_namespace_code: 'CANIAS',
          row_count: 4,
          error_count: 2,
        }),
        next_action_key: 'review_import_errors',
      }),
    })
    expect(JSON.stringify(capture.inserts)).not.toContain('sanitized_payload')
    expect(JSON.stringify(capture.inserts)).not.toContain('provider_response')
  })

  it('rejects connector import preview when persona is not admin scoped', async () => {
    resolveTenant.mockResolvedValue({
      ...mockTenantContext(),
      personaRole: 'employee',
    })

    await expect(runConnectorImportPreview('user-1')).rejects.toMatchObject({
      code: 'PULS_CONNECTOR_ADMIN_REQUIRED',
      i18nKey: 'erp.errors.adminRequired',
    })
  })

  it('rejects setup when tenant context is missing', async () => {
    resolveTenant.mockResolvedValue(mockTenantContextWithoutTenant())

    await expect(startConnectorSetup('user-1', { providerId: 'canias' })).rejects.toMatchObject({
      code: 'PULS_CONNECTOR_TENANT_REQUIRED',
      i18nKey: 'erp.errors.tenantMissing',
    })
  })

  it('rejects setup when persona is not admin scoped', async () => {
    resolveTenant.mockResolvedValue({
      ...mockTenantContext(),
      personaRole: 'employee',
    })

    await expect(startConnectorSetup('user-1', { providerId: 'canias' })).rejects.toMatchObject({
      code: 'PULS_CONNECTOR_ADMIN_REQUIRED',
      i18nKey: 'erp.errors.adminRequired',
    })
  })

  it('rejects unsupported provider setup before writing', async () => {
    resolveTenant.mockResolvedValue(mockTenantContext())
    const integrationClient = client({
      erp_connections: { data: null, error: null },
    })
    vi.mocked(pulsIntegration).mockReturnValue(integrationClient as never)

    await expect(startConnectorSetup('user-1', { providerId: 'logo' })).rejects.toThrow(
      'Connector provider setup is not available',
    )
  })

  it('maps connector setup errors to safe user messages', () => {
    expect(
      mapConnectorSetupError(
        new DataAdapterError({
          code: 'PULS_CONNECTOR_ADMIN_REQUIRED',
          message: 'Connector setup requires admin permission',
          source: 'adapter',
          operation: 'startConnectorSetup',
        }),
      ),
    ).toEqual({ code: 'admin_required', toastKey: 'erp.errors.adminRequired' })

    expect(
      mapConnectorSetupError(
        new DataAdapterError({
          code: 'PULS_CONNECTOR_DOMAIN_OWNED',
          message: 'Connector domain ownership already belongs to another source',
          source: 'adapter',
          operation: 'startConnectorSetup',
        }),
      ),
    ).toEqual({ code: 'domain_owned', toastKey: 'erp.errors.domainOwned' })

    expect(
      mapConnectorSetupError(
        new DataAdapterError({
          code: '42501',
          message: 'permission denied for table erp_connections',
          source: 'supabase',
          operation: 'startConnectorSetup',
          schema: 'puls_integration',
          table: 'erp_connections',
        }),
      ),
    ).toEqual({ code: 'permission_denied', toastKey: 'erp.errors.permissionDenied' })

    expect(mapConnectorSetupError(new Error('raw db failure'))).toEqual({
      code: 'save_failed',
      toastKey: 'erp.errors.setupSaveFailed',
    })
  })
})
