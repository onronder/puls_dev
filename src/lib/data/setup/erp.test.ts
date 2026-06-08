import { afterEach, describe, expect, it, vi } from 'vitest'

import {
  buildDefaultConnectorFieldMappings,
  buildDemoErpOverview,
  fetchErpOverviewWithMeta,
  ingestFileImportBatch,
  ingestFileImportPackage,
  isErpOverviewEmpty,
  mapConnectorSetupError,
  mapProviderLabel,
  recordConnectorApplyApproval,
  recordConnectorGuardedUpdateRollbackApproval,
  requestConnectorApplyChangeSet,
  requestConnectorCreateOnlyApplyJob,
  requestConnectorGuardedUpdateRollbackApplyJob,
  requestConnectorGuardedUpdateRollbackWorkerReadiness,
  requestConnectorGuardedUpdateApplyJob,
  requestConnectorApplyReview,
  requestConnectorCredentialHandoff,
  requestConnectorGuardedUpdateEvidence,
  requestConnectorRuntimePreflight,
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
          connector_jobs: { data: [] },
          ...overrides,
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
    expect(result.data.dataSources[0]).toMatchObject({
      sourceKind: 'connection',
      providerId: 'canias',
      displayName: 'Canias ERP (Pasif)',
      status: 'setup_incomplete',
      active: false,
      enabled: true,
      primaryAction: 'continue_setup',
    })
    expect(
      result.data.dataSources.find((source) => source.providerId === 'csv_import'),
    ).toMatchObject({
      sourceKind: 'catalog',
      status: 'not_configured',
      setupAvailable: true,
      primaryAction: 'upload_file',
    })
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
    expect(result.data.accessReadiness).toMatchObject({
      status: 'partial',
      score: 75,
      liveProviderCallsEnabled: false,
      credentialReadbackEnabled: false,
      sourceWritebackEnabled: false,
      canProceedWithoutLiveApi: true,
      nextActionKey: 'erp.accessReadiness.nextActions.request_secure_reference',
    })
    expect(
      result.data.accessReadiness.requirements.find(
        (requirement) => requirement.id === 'customer_api_access',
      ),
    ).toMatchObject({
      status: 'partial',
      valueKey: 'erp.accessReadiness.values.customerApiPartial',
    })
    expect(result.data.customerHandoff).toMatchObject({
      status: 'partial',
      score: 83,
      liveProviderCallsEnabled: false,
      credentialReadbackEnabled: false,
      sourceWritebackEnabled: false,
      shareableWithCustomer: true,
      nextActionKey: 'erp.customerHandoff.nextActions.request_secure_reference',
    })
    expect(result.data.customerHandoff.items.map((item) => item.id)).toEqual([
      'source_identity',
      'transfer_method',
      'scope_package',
      'field_contract',
      'secure_access',
      'preview_path',
    ])
    expect(
      result.data.customerHandoff.items.find((item) => item.id === 'secure_access'),
    ).toMatchObject({
      status: 'partial',
      valueKey: 'erp.customerHandoff.values.secureAccessPartial',
    })
    expect(result.data.goLivePlan).toMatchObject({
      status: 'partial',
      score: 83,
      liveProviderCallsEnabled: false,
      credentialReadbackEnabled: false,
      sourceWritebackEnabled: false,
      canStartCustomerPilot: true,
      nextActionKey: 'erp.goLivePlan.nextActions.request_secure_access',
    })
    expect(result.data.goLivePlan.gaps.map((gap) => gap.id)).toEqual([
      'source_and_method',
      'data_ownership',
      'field_contract',
      'secure_access',
      'preview_validation',
      'customer_review',
    ])
    expect(result.data.goLivePlan.gaps.find((gap) => gap.id === 'secure_access')).toMatchObject({
      owner: 'customer',
      status: 'partial',
      evidenceKey: 'erp.goLivePlan.evidence.secureAccessPartial',
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
    expect(result.data.runtimeQueue).toMatchObject({
      contractVersion: 'pr15.2-worker-skeleton-v1',
      status: 'contract_ready',
      readiness: 'ready',
      workerEnabled: false,
      executionEnabled: false,
      worker: {
        status: 'not_configured',
        readiness: 'blocked',
        statusLabelKey: 'erp.runtimeQueue.workerStatus.not_configured',
      },
      summary: {
        total: 0,
        queued: 0,
        running: 0,
        retrying: 0,
        succeeded: 0,
        failed: 0,
        deadLetter: 0,
      },
    })
    expect(JSON.stringify(result.data)).not.toContain('credentials_ref')
  })

  it('surfaces safe connector job queue and worker summaries without payload or secret readback', async () => {
    demoEnabled.mockReturnValue(false)
    setupSeededMocks({
      connector_worker_heartbeats: {
        data: [
          {
            worker_id: 'worker-a',
            status: 'idle',
            runtime_version: '0.2.0-worker-skeleton',
            supported_job_types: ['noop_health'],
            last_seen_at: new Date().toISOString(),
            last_claimed_job_id: 'job-running',
            safe_error_code: null,
            safe_context: {
              provider_api_calls: false,
              raw_payload: 'must-not-render',
            },
            created_at: '2026-06-04T08:00:00.000Z',
            updated_at: '2026-06-04T08:03:00.000Z',
          },
        ],
      },
      connector_jobs: {
        data: [
          {
            id: 'job-running',
            job_type: 'import_preview',
            status: 'running',
            domain: 'employees',
            priority: 20,
            attempt_count: 1,
            max_attempts: 3,
            scheduled_at: '2026-06-04T08:00:00.000Z',
            started_at: '2026-06-04T08:01:00.000Z',
            finished_at: null,
            locked_at: '2026-06-04T08:01:00.000Z',
            locked_by: 'worker-a',
            worker_heartbeat_at: '2026-06-04T08:02:00.000Z',
            lease_expires_at: '2999-06-04T08:06:00.000Z',
            safe_error_code: null,
            safe_error_context: { records_seen: 5 },
            next_action_key: 'wait_for_worker_runtime',
            failure_class: 'none',
            operator_severity: 'info',
            retry_after_seconds: 0,
            last_failure_at: null,
            dead_lettered_at: null,
            operator_review_required: false,
            connection_id: 'connection-1',
            source_namespace_id: 'namespace-1',
            import_batch_id: 'batch-1',
            created_at: '2026-06-04T08:00:00.000Z',
            updated_at: '2026-06-04T08:01:00.000Z',
            raw_payload: { password: 'must-not-render' },
          },
          {
            id: 'job-failed',
            job_type: 'credential_verification',
            status: 'failed',
            domain: 'credentials',
            priority: 10,
            attempt_count: 3,
            max_attempts: 3,
            scheduled_at: '2026-06-04T07:00:00.000Z',
            started_at: '2026-06-04T07:01:00.000Z',
            finished_at: '2026-06-04T07:02:00.000Z',
            locked_at: null,
            locked_by: null,
            worker_heartbeat_at: null,
            lease_expires_at: null,
            safe_error_code: 'connector_job_failed',
            safe_error_context: { reference_available: false },
            next_action_key: 'review_safe_error',
            failure_class: 'credential',
            operator_severity: 'error',
            retry_after_seconds: 0,
            last_failure_at: '2026-06-04T07:02:00.000Z',
            dead_lettered_at: null,
            operator_review_required: true,
            connection_id: 'connection-1',
            source_namespace_id: null,
            import_batch_id: null,
            created_at: '2026-06-04T07:00:00.000Z',
            updated_at: '2026-06-04T07:02:00.000Z',
            credentials_ref: 'secret://must-not-render',
          },
        ],
      },
      'rpc:list_connector_job_events': {
        data: [
          {
            id: 'job-event-1',
            tenant_id: 'a0000001-0001-4001-8001-000000000001',
            connection_id: 'connection-1',
            job_id: 'job-failed',
            job_type: 'credential_verification',
            status: 'failed',
            event_key: 'connector_job_failed',
            level: 'error',
            failure_class: 'credential',
            safe_error_code: 'connector_job_failed',
            safe_error_context: { reference_available: false },
            next_action_key: 'review_safe_error',
            retry_after_seconds: 0,
            operator_review_required: true,
            worker_id: 'worker-a',
            created_at: '2026-06-04T07:02:00.000Z',
            raw_payload: { password: 'must-not-render' },
          },
        ],
      },
    })

    const result = await fetchErpOverviewWithMeta('user-1')

    expect(result.data.runtimeQueue).toMatchObject({
      status: 'blocked',
      readiness: 'partial',
      workerEnabled: true,
      executionEnabled: false,
      worker: {
        status: 'idle',
        readiness: 'ready',
        workerId: 'worker-a',
        runtimeVersion: '0.2.0-worker-skeleton',
        supportedJobTypes: ['noop_health'],
      },
      summary: {
        total: 2,
        queued: 0,
        running: 1,
        retrying: 0,
        succeeded: 0,
        failed: 1,
        deadLetter: 0,
        operatorReviewRequired: 1,
      },
    })
    expect(result.data.runtimeQueue.jobs.map((job) => job.jobType)).toEqual([
      'import_preview',
      'credential_verification',
    ])
    expect(result.data.runtimeQueue.jobs[0]).toMatchObject({
      status: 'running',
      level: 'info',
      titleKey: 'erp.runtimeQueue.jobTypes.import_preview',
      nextActionKey: 'erp.runtimeQueue.nextActions.wait_for_worker_runtime',
      failureClass: 'none',
      operatorSeverity: 'info',
      retryAfterSeconds: 0,
      operatorReviewRequired: false,
      leaseStatus: 'active',
      leaseStatusLabelKey: 'erp.runtimeQueue.leaseStatus.active',
    })
    expect(result.data.runtimeQueue.jobs[1]).toMatchObject({
      status: 'failed',
      level: 'error',
      safeErrorSummaryKey: 'erp.runtimeQueue.safeErrors.connector_job_failed',
      nextActionKey: 'erp.runtimeQueue.nextActions.review_safe_error',
      failureClass: 'credential',
      failureClassLabelKey: 'erp.runtimeQueue.failureClasses.credential',
      operatorSeverity: 'error',
      operatorSeverityLabelKey: 'erp.runtimeQueue.operatorSeverity.error',
      lastFailureAt: '2026-06-04T07:02:00.000Z',
      operatorReviewRequired: true,
      leaseStatus: 'released',
    })
    expect(result.data.activityTimeline[0]).toMatchObject({
      kind: 'connector_job',
      level: 'error',
      titleKey: 'erp.activityTimeline.events.connector_job_failed.title',
      summaryKey: 'erp.activityTimeline.summaries.connectorJob.failed',
      safeErrorSummaryKey: 'erp.activityTimeline.safeErrors.connector_job_failed',
      nextActionKey: 'erp.activityTimeline.nextActions.review_safe_error',
      actorLabelKey: 'erp.activityTimeline.actors.worker',
    })
    expect(result.data.activityTimeline[0].detailItems).toEqual(
      expect.arrayContaining([
        { labelKey: 'erp.activityTimeline.details.jobType', value: 'credential_verification' },
        { labelKey: 'erp.activityTimeline.details.failureClass', value: 'credential' },
        { labelKey: 'erp.activityTimeline.details.operatorReview', value: true },
      ]),
    )

    const serialized = JSON.stringify(result.data.runtimeQueue)
    expect(serialized).not.toContain('raw_payload')
    expect(serialized).not.toContain('credentials_ref')
    expect(serialized).not.toContain('secret://')
    expect(serialized).not.toContain('must-not-render')
  })

  it('surfaces safe credential reference events without reference readback', async () => {
    demoEnabled.mockReturnValue(false)
    setupSeededMocks({
      'rpc:list_connector_credential_events': {
        data: [
          {
            id: 'credential-event-1',
            tenant_id: 'a0000001-0001-4001-8001-000000000001',
            connection_id: 'connection-1',
            event_key: 'reference_configured',
            auth_mode: 'custom_secret_ref',
            credential_state: 'configured',
            actor_employee_id: 'a0000006-0006-4006-8006-000000000001',
            safe_error_code: null,
            safe_context: { reference_available: true },
            next_action_key: 'run_credential_verification',
            created_at: '2026-06-04T10:30:00.000Z',
            credentials_ref: 'pulsref://must-not-render-reference',
          },
        ],
      },
    })

    const result = await fetchErpOverviewWithMeta('user-1')

    expect(result.data.activityTimeline[0]).toMatchObject({
      id: 'credential-event-1',
      kind: 'credential_reference',
      level: 'info',
      titleKey: 'erp.activityTimeline.events.credential_reference_configured.title',
      summaryKey: 'erp.activityTimeline.summaries.credentialReference.reference_configured',
      nextActionKey: 'erp.activityTimeline.nextActions.run_credential_verification',
      actorLabelKey: 'erp.activityTimeline.actors.operator',
      rawStatus: 'configured',
    })
    expect(result.data.activityTimeline[0].detailItems).toEqual(
      expect.arrayContaining([
        { labelKey: 'erp.activityTimeline.details.authMode', value: 'custom_secret_ref' },
        { labelKey: 'erp.activityTimeline.details.credentialState', value: 'configured' },
        { labelKey: 'erp.activityTimeline.details.referenceAvailable', value: true },
      ]),
    )

    const serialized = JSON.stringify(result.data)
    expect(serialized).not.toContain('credentials_ref')
    expect(serialized).not.toContain('pulsref://')
    expect(serialized).not.toContain('must-not-render')
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

  it('derives apply readiness from a previewed dry-run batch without opening apply', async () => {
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
            row_count: 5,
            create_count: 5,
            update_count: 0,
            skip_count: 0,
            error_count: 0,
            violation_count: 0,
            validated_at: '2026-06-03T14:00:00.000Z',
            previewed_at: '2026-06-03T14:01:00.000Z',
            created_at: '2026-06-03T13:59:00.000Z',
            updated_at: '2026-06-03T14:01:00.000Z',
          },
        ],
      },
      'rpc:list_connector_import_preview_records': { data: [] },
    })

    const result = await fetchErpOverviewWithMeta('user-1')

    expect(result.data.applyReadiness).toMatchObject({
      status: 'review_ready',
      action: 'request_human_review',
      requestable: true,
      safeToApply: false,
      batchId: 'batch-import-preview',
      summary: {
        rowCount: 5,
        createCount: 5,
        updateCount: 0,
        skipCount: 0,
        errorCount: 0,
      },
    })
    expect(result.data.applyReadiness.blockers.map((blocker) => blocker.id)).toEqual([
      'credential_not_verified',
      'dry_run_only',
      'apply_execution_closed',
    ])
    expect(result.data.applyChangeSet).toMatchObject({
      status: 'needs_generation',
      action: 'generate_change_set',
      requestable: true,
      safeToApply: false,
      batchId: 'batch-import-preview',
      summary: {
        rowCount: 5,
        createCount: 0,
        updateCount: 0,
        skipCount: 0,
        blockedCount: 0,
      },
    })
    expect(result.data.applySafetyContract).toMatchObject({
      contractVersion: 'pr16.1-apply-safety-contract-v1',
      authenticatedApplyRpcExposed: false,
      workerImportApplyEnqueueEnabled: false,
      workerImportApplyClaimEnabled: false,
      fieldDiffHotRetentionDays: 90,
      rollbackSnapshotHotRetentionDays: 90,
      purgeArchiveRequired: true,
    })
    expect(result.data.applySafetyContract.auditTiers).toEqual([
      'object_event',
      'field_diff',
      'rollback_snapshot',
      'archive_summary',
    ])
    expect(result.data.controlledApplyPlan).toMatchObject({
      status: 'needs_review',
      executionOpen: false,
      applyRpcExposed: false,
      batchId: 'batch-import-preview',
      sourceChecksum: 'pr14_16_connector_preview_proof_v1',
    })
    expect(result.data.controlledApplyPlan.gates.map((gate) => gate.id)).toEqual([
      'preview_ready',
      'human_review',
      'source_checksum',
      'approval_policy',
      'batch_lock',
      'rollback_strategy',
      'audit_trail',
      'notification_plan',
      'runtime_credentials',
      'execution_boundary',
    ])
    expect(
      result.data.controlledApplyPlan.gates.find((gate) => gate.id === 'human_review'),
    ).toMatchObject({ status: 'partial' })
    expect(
      result.data.controlledApplyPlan.gates.find((gate) => gate.id === 'rollback_strategy'),
    ).toMatchObject({ status: 'blocked' })
    expect(JSON.stringify(result.data.applyReadiness)).not.toContain('apply_import_batch')
    expect(JSON.stringify(result.data.applyChangeSet)).not.toContain('apply_import_batch')
    expect(JSON.stringify(result.data.applySafetyContract)).not.toContain('apply_import_batch')
    expect(JSON.stringify(result.data.controlledApplyPlan)).not.toContain('apply_import_batch')
    expect(JSON.stringify(result.data.controlledApplyPlan)).not.toContain('credentials_ref')
  })

  it('exposes safe apply change-set risk evidence without raw payloads', async () => {
    demoEnabled.mockReturnValue(false)
    setupSeededMocks({
      import_batches: {
        data: [
          {
            id: 'batch-import-preview',
            source_namespace_id: 'namespace-1',
            status: 'previewed',
            mode: 'dry_run',
            source_checksum: 'pr16_2_change_set_v1',
            row_count: 3,
            create_count: 1,
            update_count: 1,
            skip_count: 1,
            error_count: 0,
            violation_count: 0,
            validated_at: '2026-06-05T10:00:00.000Z',
            previewed_at: '2026-06-05T10:01:00.000Z',
            created_at: '2026-06-05T09:59:00.000Z',
            updated_at: '2026-06-05T10:01:00.000Z',
          },
        ],
      },
      'rpc:list_connector_import_preview_records': { data: [] },
      'rpc:list_connector_apply_change_set_summaries': {
        data: [
          {
            id: 'change-set-1',
            import_batch_id: 'batch-import-preview',
            status: 'blocked',
            source_checksum: 'pr16_2_change_set_v1',
            change_set_checksum: 'safe-change-set-hash',
            previewed_at: '2026-06-05T10:01:00.000Z',
            row_count: 3,
            create_count: 1,
            update_count: 1,
            skip_count: 1,
            blocked_count: 1,
            stale_count: 0,
            destructive_count: 0,
            source_conflict_count: 0,
            guarded_update_count: 1,
            no_change_count: 1,
            approval_required: true,
            sample_items: [
              {
                id: 'change-set-item-1',
                row_number: 2,
                entity_type: 'department',
                external_id: 'DEPT-1',
                target_table: 'departments',
                operation: 'update',
                risk_class: 'guarded_overwrite',
                blocked: true,
                risk_reasons: ['blocked_update_requires_policy'],
                audit_tiers: ['object_event', 'field_diff', 'rollback_snapshot'],
                retention_bucket: 'field_diff',
                expected_current_hash_available: true,
                safe_field_names: ['name', 'parent_department_id'],
                destructive_field_names: [],
                rollback_snapshot_required: true,
              },
            ],
            created_at: '2026-06-05T10:02:00.000Z',
          },
        ],
      },
    })

    const result = await fetchErpOverviewWithMeta('user-1')

    expect(result.data.applyChangeSet).toMatchObject({
      id: 'change-set-1',
      status: 'blocked',
      action: 'resolve_blockers',
      requestable: false,
      safeToApply: false,
      changeSetChecksum: 'safe-change-set-hash',
      summary: {
        rowCount: 3,
        createCount: 1,
        updateCount: 1,
        skipCount: 1,
        blockedCount: 1,
        guardedUpdateCount: 1,
        noChangeCount: 1,
      },
    })
    expect(result.data.applyChangeSet.sampleItems[0]).toMatchObject({
      riskClass: 'guarded_overwrite',
      blocked: true,
      retentionBucket: 'field_diff',
      expectedCurrentHashAvailable: true,
      safeFieldNames: ['name', 'parent_department_id'],
    })
    expect(JSON.stringify(result.data.applyChangeSet)).not.toContain('raw_payload')
    expect(JSON.stringify(result.data.applyChangeSet)).not.toContain('sanitized_payload')
    expect(JSON.stringify(result.data.applyChangeSet)).not.toContain('normalized_payload')
    expect(JSON.stringify(result.data.applyChangeSet)).not.toContain('credentials_ref')
  })

  it('exposes guarded update evidence without values or execution flags', async () => {
    demoEnabled.mockReturnValue(false)
    setupSeededMocks({
      import_batches: {
        data: [
          {
            id: 'batch-guarded-update',
            source_namespace_id: 'namespace-1',
            status: 'previewed',
            mode: 'dry_run',
            source_checksum: 'pr16_4_guarded_update_v1',
            row_count: 1,
            create_count: 0,
            update_count: 1,
            skip_count: 0,
            error_count: 0,
            violation_count: 0,
            validated_at: '2026-06-05T13:00:00.000Z',
            previewed_at: '2026-06-05T13:01:00.000Z',
            created_at: '2026-06-05T12:59:00.000Z',
            updated_at: '2026-06-05T13:01:00.000Z',
          },
        ],
      },
      'rpc:list_connector_import_preview_records': { data: [] },
      'rpc:list_connector_apply_change_set_summaries': {
        data: [
          {
            id: 'change-set-guarded-update',
            import_batch_id: 'batch-guarded-update',
            status: 'blocked',
            source_checksum: 'pr16_4_guarded_update_v1',
            change_set_checksum: 'safe-guarded-update-change-set-hash',
            previewed_at: '2026-06-05T13:01:00.000Z',
            row_count: 1,
            create_count: 0,
            update_count: 1,
            skip_count: 0,
            blocked_count: 0,
            stale_count: 0,
            destructive_count: 0,
            source_conflict_count: 0,
            guarded_update_count: 1,
            no_change_count: 0,
            approval_required: true,
            sample_items: [
              {
                id: 'change-set-item-guarded-update',
                row_number: 1,
                entity_type: 'department',
                external_id: 'DEPT-1',
                target_table: 'departments',
                operation: 'update',
                risk_class: 'guarded_overwrite',
                blocked: false,
                risk_reasons: ['guarded_update_evidence_required'],
                audit_tiers: ['object_event', 'field_diff', 'rollback_snapshot'],
                retention_bucket: 'field_diff',
                expected_current_hash_available: true,
                safe_field_names: ['code', 'name'],
                destructive_field_names: [],
                rollback_snapshot_required: true,
              },
            ],
            created_at: '2026-06-05T13:02:00.000Z',
          },
        ],
      },
      'rpc:list_connector_guarded_update_evidence': {
        data: [
          {
            change_set_id: 'change-set-guarded-update',
            tenant_id: 'a0000001-0001-4001-8001-000000000001',
            connection_id: 'connection-1',
            source_namespace_id: 'namespace-1',
            import_batch_id: 'batch-guarded-update',
            status: 'evidence_ready',
            guarded_update_count: 1,
            field_diff_count: 1,
            rollback_snapshot_count: 1,
            stale_blocked_count: 0,
            execution_enabled: false,
            canonical_write_enabled: false,
            source_writeback_enabled: false,
            credential_readback_enabled: false,
            value_readback_enabled: false,
            hot_retention_days: 90,
            next_action_key: 'review_guarded_update_evidence',
            sample_field_diffs: [
              {
                id: 'field-diff-1',
                row_number: 1,
                entity_type: 'department',
                external_id: 'DEPT-1',
                target_table: 'departments',
                field_name: 'name',
                field_class: 'safe',
                operation: 'set',
                before_value_hash_available: true,
                after_value_hash_available: true,
                before_value_present: true,
                after_value_present: true,
                expected_current_hash_available: true,
                current_hash_available: true,
                stale_blocked: false,
                rollback_snapshot_required: true,
                retention_bucket: 'field_diff',
                hot_retention_expires_at: '2026-09-03T13:02:00.000Z',
              },
            ],
            created_at: '2026-06-05T13:02:30.000Z',
          },
        ],
      },
    })

    const result = await fetchErpOverviewWithMeta('user-1')

    expect(result.data.guardedUpdateEvidence).toMatchObject({
      changeSetId: 'change-set-guarded-update',
      status: 'evidence_ready',
      action: 'review_evidence',
      requestable: false,
      safeToApply: false,
      safeToExecute: false,
      executionEnabled: false,
      canonicalWriteEnabled: false,
      sourceWritebackEnabled: false,
      credentialReadbackEnabled: false,
      valueReadbackEnabled: false,
      summary: {
        guardedUpdateCount: 1,
        fieldDiffCount: 1,
        rollbackSnapshotCount: 1,
        staleBlockedCount: 0,
        hotRetentionDays: 90,
      },
    })
    expect(result.data.guardedUpdateEvidence.sampleFieldDiffs[0]).toMatchObject({
      fieldName: 'name',
      fieldClass: 'safe',
      operation: 'set',
      beforeValueHashAvailable: true,
      afterValueHashAvailable: true,
      rollbackSnapshotRequired: true,
    })
    expect(JSON.stringify(result.data.guardedUpdateEvidence)).not.toContain('snapshot_payload')
    expect(JSON.stringify(result.data.guardedUpdateEvidence)).not.toContain('normalized_payload')
    expect(JSON.stringify(result.data.guardedUpdateEvidence)).not.toContain('credentials_ref')
    expect(JSON.stringify(result.data.guardedUpdateEvidence)).not.toContain('"raw_payload":')
  })

  it('shows review requested only when the audit event is newer than the preview', async () => {
    demoEnabled.mockReturnValue(false)
    setupSeededMocks({
      erp_sync_batches: {
        data: [
          {
            id: 'review-event',
            created_at: '2026-06-03T14:02:00.000Z',
            status: 'success',
            sync_type: 'import_apply_review',
            event_key: 'import_apply_review_requested',
            actor_employee_id: 'a0000006-0006-4006-8006-000000000001',
            safe_error_code: null,
            safe_error_context: {
              safe_to_apply: false,
              apply_execution_open: false,
              human_review_recorded: true,
            },
            next_action_key: 'hold_for_apply_design',
            records_seen: 5,
            records_inserted: 5,
            records_updated: 0,
            records_failed: 0,
          },
        ],
      },
      import_batches: {
        data: [
          {
            id: 'batch-import-preview',
            source_namespace_id: 'namespace-1',
            status: 'previewed',
            mode: 'dry_run',
            source_checksum: 'pr14_16_connector_preview_proof_v1',
            row_count: 5,
            create_count: 5,
            update_count: 0,
            skip_count: 0,
            error_count: 0,
            violation_count: 0,
            validated_at: '2026-06-03T14:00:00.000Z',
            previewed_at: '2026-06-03T14:01:00.000Z',
            created_at: '2026-06-03T13:59:00.000Z',
            updated_at: '2026-06-03T14:01:00.000Z',
          },
        ],
      },
      'rpc:list_connector_import_preview_records': { data: [] },
    })

    const result = await fetchErpOverviewWithMeta('user-1')

    expect(result.data.applyReadiness).toMatchObject({
      status: 'review_requested',
      action: 'review_requested',
      requestable: false,
      safeToApply: false,
      reviewRequestedAt: '2026-06-03T14:02:00.000Z',
    })
    expect(result.data.controlledApplyPlan).toMatchObject({
      status: 'design_ready',
      executionOpen: false,
      applyRpcExposed: false,
      summary: {
        blockedCount: expect.any(Number),
      },
    })
    expect(result.data.applyApprovalPolicy).toMatchObject({
      status: 'admin_only',
      action: 'record_admin_approval',
      requestable: true,
      safeToApply: false,
      batchId: 'batch-import-preview',
    })
    expect(result.data.applyExecutionContract).toMatchObject({
      status: 'needs_approval',
      readiness: 'partial',
      contractVersion: 'pr16.1-apply-safety-contract-v1',
      executionEnabled: false,
      canonicalWriteEnabled: false,
      sourceWritebackEnabled: false,
      credentialReadbackEnabled: false,
      applyRpcExposed: false,
      authenticatedApplyRpcExposed: false,
      workerImportApplyEnqueueEnabled: false,
      workerImportApplyClaimEnabled: false,
      safeToExecute: false,
      executorMode: 'future_background_job',
      batchId: 'batch-import-preview',
      sourceChecksum: 'pr14_16_connector_preview_proof_v1',
      sourceNamespaceCode: 'CANIAS',
    })
    expect(
      result.data.applyExecutionContract.controls.find(
        (control) => control.id === 'admin_approval',
      ),
    ).toMatchObject({
      status: 'partial',
      valueKey: 'erp.applyExecutionContract.values.approvalMissing',
    })
    expect(
      result.data.applyExecutionContract.controls.find(
        (control) => control.id === 'direct_rpc_permission',
      ),
    ).toMatchObject({
      status: 'ready',
      valueKey: 'erp.applyExecutionContract.values.serviceRoleOnly',
    })
    expect(
      result.data.applyExecutionContract.controls.find(
        (control) => control.id === 'worker_apply_gate',
      ),
    ).toMatchObject({
      status: 'ready',
      valueKey: 'erp.applyExecutionContract.values.importApplyClosed',
    })
    expect(
      result.data.applyExecutionContract.controls.find(
        (control) => control.id === 'execution_boundary',
      ),
    ).toMatchObject({ status: 'blocked' })
    expect(
      result.data.controlledApplyPlan.gates.find((gate) => gate.id === 'human_review'),
    ).toMatchObject({ status: 'ready' })
    expect(
      result.data.controlledApplyPlan.gates.find((gate) => gate.id === 'approval_policy'),
    ).toMatchObject({
      status: 'ready',
      valueKey: 'erp.controlledApply.values.policyAdminOnly',
    })
    expect(
      result.data.controlledApplyPlan.gates.find((gate) => gate.id === 'execution_boundary'),
    ).toMatchObject({ status: 'blocked' })
    expect(result.data.activityTimeline[0]).toMatchObject({
      kind: 'import_apply_review',
      titleKey: 'erp.activityTimeline.events.import_apply_review_requested.title',
      nextActionKey: 'erp.activityTimeline.nextActions.hold_for_apply_design',
    })
  })

  it('surfaces recorded admin apply approval as audit without opening execution', async () => {
    demoEnabled.mockReturnValue(false)
    setupSeededMocks({
      erp_sync_batches: {
        data: [
          {
            id: 'approval-event',
            created_at: '2026-06-03T14:03:00.000Z',
            status: 'success',
            sync_type: 'import_apply_review',
            event_key: 'import_apply_approval_recorded',
            actor_employee_id: 'a0000006-0006-4006-8006-000000000001',
            safe_error_code: null,
            safe_error_context: {
              approval_policy: 'admin_only',
              approval_recorded: true,
              safe_to_apply: false,
              apply_execution_open: false,
            },
            next_action_key: 'hold_for_apply_execution_design',
            records_seen: 5,
            records_inserted: 5,
            records_updated: 0,
            records_failed: 0,
          },
          {
            id: 'review-event',
            created_at: '2026-06-03T14:02:00.000Z',
            status: 'success',
            sync_type: 'import_apply_review',
            event_key: 'import_apply_review_requested',
            actor_employee_id: 'a0000006-0006-4006-8006-000000000001',
            safe_error_code: null,
            safe_error_context: {
              safe_to_apply: false,
              apply_execution_open: false,
              human_review_recorded: true,
            },
            next_action_key: 'hold_for_apply_design',
            records_seen: 5,
            records_inserted: 5,
            records_updated: 0,
            records_failed: 0,
          },
        ],
      },
      import_batches: {
        data: [
          {
            id: 'batch-import-preview',
            source_namespace_id: 'namespace-1',
            status: 'previewed',
            mode: 'dry_run',
            source_checksum: 'pr14_16_connector_preview_proof_v1',
            row_count: 5,
            create_count: 5,
            update_count: 0,
            skip_count: 0,
            error_count: 0,
            violation_count: 0,
            validated_at: '2026-06-03T14:00:00.000Z',
            previewed_at: '2026-06-03T14:01:00.000Z',
            created_at: '2026-06-03T13:59:00.000Z',
            updated_at: '2026-06-03T14:01:00.000Z',
          },
        ],
      },
      'rpc:list_connector_import_preview_records': { data: [] },
    })

    const result = await fetchErpOverviewWithMeta('user-1')

    expect(result.data.applyApprovalPolicy).toMatchObject({
      status: 'approval_recorded',
      action: 'approval_recorded',
      requestable: false,
      safeToApply: false,
      approvalRecordedAt: '2026-06-03T14:03:00.000Z',
      approvalRecordedByEmployeeId: 'a0000006-0006-4006-8006-000000000001',
    })
    expect(result.data.controlledApplyPlan).toMatchObject({
      status: 'approval_recorded',
      executionOpen: false,
      applyRpcExposed: false,
    })
    expect(result.data.applyExecutionContract).toMatchObject({
      status: 'contract_ready',
      readiness: 'partial',
      executionEnabled: false,
      canonicalWriteEnabled: false,
      sourceWritebackEnabled: false,
      credentialReadbackEnabled: false,
      applyRpcExposed: false,
      browserDirectApplyEnabled: false,
      authenticatedApplyRpcExposed: false,
      workerImportApplyEnqueueEnabled: false,
      workerImportApplyClaimEnabled: false,
      safeToExecute: false,
      executorMode: 'future_background_job',
      batchId: 'batch-import-preview',
      sourceChecksum: 'pr14_16_connector_preview_proof_v1',
      sourceNamespaceCode: 'CANIAS',
    })
    expect(
      result.data.applyExecutionContract.controls.find(
        (control) => control.id === 'admin_approval',
      ),
    ).toMatchObject({
      status: 'ready',
      valueKey: 'erp.applyExecutionContract.values.approvalRecorded',
    })
    expect(
      result.data.applyExecutionContract.controls.find(
        (control) => control.id === 'idempotency_key',
      ),
    ).toMatchObject({
      status: 'ready',
      valueKey: 'erp.applyExecutionContract.values.checksumReady',
    })
    expect(
      result.data.applyExecutionContract.controls.find((control) => control.id === 'batch_lock'),
    ).toMatchObject({ status: 'blocked' })
    expect(
      result.data.applyExecutionContract.controls.find(
        (control) => control.id === 'retention_policy',
      ),
    ).toMatchObject({
      status: 'ready',
      valueKey: 'erp.applyExecutionContract.values.ninetyDayHotRetention',
    })
    expect(
      result.data.controlledApplyPlan.gates.find((gate) => gate.id === 'approval_policy'),
    ).toMatchObject({
      status: 'ready',
      valueKey: 'erp.controlledApply.values.policyApproved',
    })
    expect(result.data.activityTimeline[0]).toMatchObject({
      kind: 'import_apply_review',
      titleKey: 'erp.activityTimeline.events.import_apply_approval_recorded.title',
      nextActionKey: 'erp.activityTimeline.nextActions.hold_for_apply_execution_design',
    })
    expect(JSON.stringify(result.data)).not.toContain('apply_import_batch')
  })

  it('queues create-only apply only when approval, change-set, and worker gates are ready', async () => {
    resolveTenant.mockResolvedValue(mockTenantContext())
    demoEnabled.mockReturnValue(false)
    const capture: ClientCapture = { inserts: [], rpcCalls: [] }
    setupSeededMocks(
      {
        erp_sync_batches: {
          data: [
            {
              id: 'approval-event',
              created_at: '2026-06-05T10:03:00.000Z',
              status: 'success',
              sync_type: 'import_apply_review',
              event_key: 'import_apply_approval_recorded',
              actor_employee_id: 'a0000006-0006-4006-8006-000000000001',
              safe_error_code: null,
              safe_error_context: {
                approval_policy: 'admin_only',
                approval_recorded: true,
                safe_to_apply: false,
                apply_execution_open: false,
              },
              next_action_key: 'hold_for_apply_execution_design',
              records_seen: 2,
              records_inserted: 2,
              records_updated: 0,
              records_failed: 0,
            },
            {
              id: 'review-event',
              created_at: '2026-06-05T10:02:00.000Z',
              status: 'success',
              sync_type: 'import_apply_review',
              event_key: 'import_apply_review_requested',
              actor_employee_id: 'a0000006-0006-4006-8006-000000000001',
              safe_error_code: null,
              safe_error_context: {
                safe_to_apply: false,
                apply_execution_open: false,
                human_review_recorded: true,
              },
              next_action_key: 'hold_for_apply_design',
              records_seen: 2,
              records_inserted: 2,
              records_updated: 0,
              records_failed: 0,
            },
          ],
        },
        import_batches: {
          data: [
            {
              id: 'batch-create-only',
              source_namespace_id: 'namespace-1',
              status: 'previewed',
              mode: 'dry_run',
              source_checksum: 'pr16_3_create_only_reference_v1',
              row_count: 2,
              create_count: 2,
              update_count: 0,
              skip_count: 0,
              error_count: 0,
              violation_count: 0,
              validated_at: '2026-06-05T10:00:00.000Z',
              previewed_at: '2026-06-05T10:01:00.000Z',
              created_at: '2026-06-05T09:59:00.000Z',
              updated_at: '2026-06-05T10:01:00.000Z',
            },
          ],
        },
        'rpc:list_connector_import_preview_records': { data: [] },
        'rpc:list_connector_apply_safety_contracts': {
          data: [
            {
              contract_version: 'pr16.3-create-only-worker-apply-v1',
              browser_direct_apply_enabled: false,
              authenticated_apply_rpc_exposed: false,
              worker_import_apply_enqueue_enabled: true,
              worker_import_apply_claim_enabled: true,
              execution_enabled: true,
              canonical_write_enabled: true,
              source_writeback_enabled: false,
              credential_readback_enabled: false,
              audit_tiers: ['object_event', 'field_diff', 'rollback_snapshot', 'archive_summary'],
              field_diff_hot_retention_days: 90,
              rollback_snapshot_hot_retention_days: 90,
              object_event_retention_months: 24,
              purge_archive_required: true,
              safe_error_code: 'create_only_worker_apply_open_pr16_3',
              next_action_key: 'queue_create_only_worker_apply',
            },
          ],
          error: null,
        },
        'rpc:list_connector_apply_change_set_summaries': {
          data: [
            {
              id: 'change-set-create-only',
              import_batch_id: 'batch-create-only',
              status: 'ready_for_create_only_review',
              source_checksum: 'pr16_3_create_only_reference_v1',
              change_set_checksum: 'safe-create-only-change-set-hash',
              previewed_at: '2026-06-05T10:01:00.000Z',
              row_count: 2,
              create_count: 2,
              update_count: 0,
              skip_count: 0,
              blocked_count: 0,
              stale_count: 0,
              destructive_count: 0,
              source_conflict_count: 0,
              guarded_update_count: 0,
              no_change_count: 0,
              approval_required: true,
              sample_items: [],
              created_at: '2026-06-05T10:02:30.000Z',
            },
          ],
          error: null,
        },
        'rpc:enqueue_connector_create_only_apply_job': {
          data: [
            {
              job_id: 'create-only-job-1',
              status: 'queued',
              change_set_id: 'change-set-create-only',
              import_batch_id: 'batch-create-only',
              create_count: 2,
              next_action_key: 'wait_for_create_only_worker_apply',
            },
          ],
          error: null,
        },
      },
      capture,
    )

    const overview = await fetchErpOverviewWithMeta('user-1')

    expect(overview.data.applyExecutionContract).toMatchObject({
      status: 'contract_ready',
      readiness: 'ready',
      executionEnabled: true,
      canonicalWriteEnabled: true,
      sourceWritebackEnabled: false,
      credentialReadbackEnabled: false,
      applyRpcExposed: false,
      browserDirectApplyEnabled: false,
      authenticatedApplyRpcExposed: false,
      workerImportApplyEnqueueEnabled: true,
      workerImportApplyClaimEnabled: true,
      safeToExecute: true,
      executorMode: 'worker_create_only_job',
      batchId: 'batch-create-only',
      sourceChecksum: 'pr16_3_create_only_reference_v1',
      sourceNamespaceCode: 'CANIAS',
    })
    expect(
      overview.data.applyExecutionContract.controls.find(
        (control) => control.id === 'worker_apply_gate',
      ),
    ).toMatchObject({
      status: 'ready',
      valueKey: 'erp.applyExecutionContract.values.createOnlyWorkerOpen',
    })
    expect(
      overview.data.applyExecutionContract.controls.find(
        (control) => control.id === 'execution_boundary',
      ),
    ).toMatchObject({
      status: 'ready',
      valueKey: 'erp.applyExecutionContract.values.createOnlyExecutionReady',
    })

    const result = await requestConnectorCreateOnlyApplyJob('user-1')

    expect(result).toEqual({
      connectionId: 'connection-1',
      batchId: 'batch-create-only',
      changeSetId: 'change-set-create-only',
      jobId: 'create-only-job-1',
      status: 'queued',
      nextActionKey: 'wait_for_create_only_worker_apply',
      safeToApply: false,
    })
    expect(capture.rpcCalls).toContainEqual({
      fn: 'enqueue_connector_create_only_apply_job',
      args: { p_change_set_id: 'change-set-create-only' },
    })
    expect(capture.rpcCalls?.some((call) => call.fn === 'apply_import_batch')).toBe(false)
    expect(capture.inserts).toContainEqual({
      table: 'erp_sync_batches',
      payload: expect.objectContaining({
        sync_type: 'import_apply_review',
        event_key: 'import_apply_create_only_queued',
        status: 'pending',
        safe_error_code: null,
        safe_error_context: expect.objectContaining({
          job_id: 'create-only-job-1',
          change_set_id: 'change-set-create-only',
          import_batch_id: 'batch-create-only',
          contract_version: 'pr16.3-create-only-worker-apply-v1',
          worker_queue: true,
          apply_execution_open: true,
          canonical_write_open: true,
          browser_direct_apply_open: false,
          authenticated_apply_rpc_open: false,
          source_writeback_open: false,
          credential_readback_open: false,
          field_value_readback: false,
          raw_payload_readback: false,
          safe_to_apply: false,
        }),
        next_action_key: 'wait_for_create_only_worker_apply',
      }),
    })
    expect(JSON.stringify(capture)).not.toContain('apply_import_batch')
    expect(JSON.stringify(capture)).not.toContain('credentials_ref')
    expect(JSON.stringify(capture)).not.toContain('"raw_payload":')
    expect(JSON.stringify(capture)).not.toContain('provider_response')
  })

  it('blocks create-only apply before queue RPC when the safety contract is not ready', async () => {
    resolveTenant.mockResolvedValue(mockTenantContext())
    const capture: ClientCapture = { rpcCalls: [] }
    setupSeededMocks(
      {
        import_batches: {
          data: [
            {
              id: 'batch-create-only-blocked',
              source_namespace_id: 'namespace-1',
              status: 'previewed',
              mode: 'dry_run',
              source_checksum: 'pr16_3_create_only_reference_v1',
              row_count: 2,
              create_count: 2,
              update_count: 0,
              skip_count: 0,
              error_count: 0,
              violation_count: 0,
              validated_at: '2026-06-05T10:00:00.000Z',
              previewed_at: '2026-06-05T10:01:00.000Z',
              created_at: '2026-06-05T09:59:00.000Z',
              updated_at: '2026-06-05T10:01:00.000Z',
            },
          ],
        },
        'rpc:list_connector_import_preview_records': { data: [] },
      },
      capture,
    )

    await expect(requestConnectorCreateOnlyApplyJob('user-1')).rejects.toMatchObject({
      code: 'PULS_CONNECTOR_CREATE_ONLY_APPLY_BLOCKED',
      i18nKey: 'erp.errors.createOnlyApplyBlocked',
    })
    expect(
      capture.rpcCalls?.some((call) => call.fn === 'enqueue_connector_create_only_apply_job'),
    ).toBe(false)
  })

  it('queues guarded update apply only when evidence, approval, and worker gates are ready', async () => {
    resolveTenant.mockResolvedValue(mockTenantContext())
    const capture: ClientCapture = { inserts: [], rpcCalls: [] }
    setupSeededMocks(
      {
        erp_sync_batches: {
          data: [
            {
              id: 'approval-event',
              created_at: '2026-06-05T14:03:00.000Z',
              status: 'success',
              sync_type: 'import_apply_review',
              event_key: 'import_apply_approval_recorded',
              actor_employee_id: 'a0000006-0006-4006-8006-000000000001',
              safe_error_code: null,
              safe_error_context: {
                approval_policy: 'admin_only',
                approval_recorded: true,
                safe_to_apply: false,
                apply_execution_open: false,
              },
              next_action_key: 'hold_for_apply_execution_design',
              records_seen: 1,
              records_inserted: 0,
              records_updated: 1,
              records_failed: 0,
            },
            {
              id: 'review-event',
              created_at: '2026-06-05T14:02:00.000Z',
              status: 'success',
              sync_type: 'import_apply_review',
              event_key: 'import_apply_review_requested',
              actor_employee_id: 'a0000006-0006-4006-8006-000000000001',
              safe_error_code: null,
              safe_error_context: {
                safe_to_apply: false,
                apply_execution_open: false,
                human_review_recorded: true,
              },
              next_action_key: 'hold_for_apply_design',
              records_seen: 1,
              records_inserted: 0,
              records_updated: 1,
              records_failed: 0,
            },
          ],
        },
        import_batches: {
          data: [
            {
              id: 'batch-guarded-update',
              source_namespace_id: 'namespace-1',
              status: 'previewed',
              mode: 'dry_run',
              source_checksum: 'pr16_4_guarded_update_v1',
              row_count: 1,
              create_count: 0,
              update_count: 1,
              skip_count: 0,
              error_count: 0,
              violation_count: 0,
              validated_at: '2026-06-05T13:00:00.000Z',
              previewed_at: '2026-06-05T13:01:00.000Z',
              created_at: '2026-06-05T12:59:00.000Z',
              updated_at: '2026-06-05T13:01:00.000Z',
            },
          ],
        },
        'rpc:list_connector_import_preview_records': { data: [] },
        'rpc:list_connector_apply_safety_contracts': {
          data: [
            {
              contract_version: 'pr16.4.2-guarded-update-worker-apply-v1',
              browser_direct_apply_enabled: false,
              authenticated_apply_rpc_exposed: false,
              worker_import_apply_enqueue_enabled: true,
              worker_import_apply_claim_enabled: true,
              execution_enabled: true,
              canonical_write_enabled: true,
              source_writeback_enabled: false,
              credential_readback_enabled: false,
              audit_tiers: ['object_event', 'field_diff', 'rollback_snapshot', 'archive_summary'],
              field_diff_hot_retention_days: 90,
              rollback_snapshot_hot_retention_days: 90,
              object_event_retention_months: 24,
              purge_archive_required: true,
              safe_error_code: 'guarded_update_worker_apply_open',
              next_action_key: 'enqueue_guarded_update_apply_after_review',
            },
          ],
          error: null,
        },
        'rpc:list_connector_apply_change_set_summaries': {
          data: [
            {
              id: 'change-set-guarded-update',
              import_batch_id: 'batch-guarded-update',
              status: 'blocked',
              source_checksum: 'pr16_4_guarded_update_v1',
              change_set_checksum: 'safe-guarded-update-change-set-hash',
              previewed_at: '2026-06-05T13:01:00.000Z',
              row_count: 1,
              create_count: 0,
              update_count: 1,
              skip_count: 0,
              blocked_count: 1,
              stale_count: 0,
              destructive_count: 0,
              source_conflict_count: 0,
              guarded_update_count: 1,
              no_change_count: 0,
              approval_required: true,
              sample_items: [],
              created_at: '2026-06-05T13:02:00.000Z',
            },
          ],
          error: null,
        },
        'rpc:list_connector_guarded_update_evidence': {
          data: [
            {
              change_set_id: 'change-set-guarded-update',
              tenant_id: 'a0000001-0001-4001-8001-000000000001',
              connection_id: 'connection-1',
              source_namespace_id: 'namespace-1',
              import_batch_id: 'batch-guarded-update',
              status: 'evidence_ready',
              guarded_update_count: 1,
              field_diff_count: 1,
              rollback_snapshot_count: 1,
              stale_blocked_count: 0,
              execution_enabled: false,
              canonical_write_enabled: false,
              source_writeback_enabled: false,
              credential_readback_enabled: false,
              value_readback_enabled: false,
              hot_retention_days: 90,
              next_action_key: 'review_guarded_update_evidence',
              sample_field_diffs: [],
              created_at: '2026-06-05T13:02:30.000Z',
            },
          ],
          error: null,
        },
        'rpc:enqueue_connector_guarded_update_apply_job': {
          data: [
            {
              job_id: 'guarded-update-job-1',
              status: 'queued',
              change_set_id: 'change-set-guarded-update',
              import_batch_id: 'batch-guarded-update',
              update_count: 1,
              field_diff_count: 1,
              rollback_snapshot_count: 1,
              next_action_key: 'wait_for_guarded_update_worker_apply',
            },
          ],
          error: null,
        },
      },
      capture,
    )

    const overview = await fetchErpOverviewWithMeta('user-1')

    expect(overview.data.applyExecutionContract).toMatchObject({
      status: 'contract_ready',
      readiness: 'ready',
      contractVersion: 'pr16.4.2-guarded-update-worker-apply-v1',
      executionEnabled: true,
      canonicalWriteEnabled: true,
      sourceWritebackEnabled: false,
      credentialReadbackEnabled: false,
      applyRpcExposed: false,
      safeToExecute: true,
      executorMode: 'worker_guarded_update_job',
      batchId: 'batch-guarded-update',
      sourceChecksum: 'pr16_4_guarded_update_v1',
    })
    expect(
      overview.data.applyExecutionContract.controls.find(
        (control) => control.id === 'worker_apply_gate',
      ),
    ).toMatchObject({
      status: 'ready',
      valueKey: 'erp.applyExecutionContract.values.guardedUpdateWorkerOpen',
    })
    expect(
      overview.data.applyExecutionContract.controls.find(
        (control) => control.id === 'execution_boundary',
      ),
    ).toMatchObject({
      status: 'ready',
      valueKey: 'erp.applyExecutionContract.values.guardedUpdateExecutionReady',
    })

    await expect(requestConnectorCreateOnlyApplyJob('user-1')).rejects.toMatchObject({
      code: 'PULS_CONNECTOR_CREATE_ONLY_APPLY_BLOCKED',
      i18nKey: 'erp.errors.createOnlyApplyBlocked',
    })
    expect(
      capture.rpcCalls?.some((call) => call.fn === 'enqueue_connector_create_only_apply_job'),
    ).toBe(false)

    const result = await requestConnectorGuardedUpdateApplyJob('user-1')

    expect(result).toEqual({
      connectionId: 'connection-1',
      batchId: 'batch-guarded-update',
      changeSetId: 'change-set-guarded-update',
      jobId: 'guarded-update-job-1',
      status: 'queued',
      nextActionKey: 'wait_for_guarded_update_worker_apply',
      safeToApply: false,
    })
    expect(capture.rpcCalls).toContainEqual({
      fn: 'enqueue_connector_guarded_update_apply_job',
      args: { p_change_set_id: 'change-set-guarded-update' },
    })
    expect(capture.rpcCalls?.some((call) => call.fn === 'apply_import_batch')).toBe(false)
    expect(capture.inserts).toContainEqual({
      table: 'erp_sync_batches',
      payload: expect.objectContaining({
        sync_type: 'import_apply_review',
        event_key: 'import_apply_guarded_update_queued',
        status: 'pending',
        safe_error_code: null,
        safe_error_context: expect.objectContaining({
          job_id: 'guarded-update-job-1',
          change_set_id: 'change-set-guarded-update',
          import_batch_id: 'batch-guarded-update',
          contract_version: 'pr16.4.2-guarded-update-worker-apply-v1',
          update_count: 1,
          guarded_update_count: 1,
          field_diff_count: 1,
          rollback_snapshot_count: 1,
          worker_queue: true,
          apply_execution_open: true,
          canonical_write_open: true,
          browser_direct_apply_open: false,
          authenticated_apply_rpc_open: false,
          source_writeback_open: false,
          credential_readback_open: false,
          provider_api_calls: false,
          field_value_readback: false,
          raw_payload_readback: false,
          rollback_execution: false,
          safe_to_apply: false,
        }),
        next_action_key: 'wait_for_guarded_update_worker_apply',
      }),
    })
    expect(JSON.stringify(capture)).not.toContain('apply_import_batch')
    expect(JSON.stringify(capture)).not.toContain('credentials_ref')
    expect(JSON.stringify(capture)).not.toContain('"raw_payload":')
    expect(JSON.stringify(capture)).not.toContain('provider_response')
  })

  it('blocks guarded update apply before queue RPC when evidence is not ready', async () => {
    resolveTenant.mockResolvedValue(mockTenantContext())
    const capture: ClientCapture = { rpcCalls: [] }
    setupSeededMocks(
      {
        erp_sync_batches: {
          data: [
            {
              id: 'approval-event',
              created_at: '2026-06-05T14:03:00.000Z',
              status: 'success',
              sync_type: 'import_apply_review',
              event_key: 'import_apply_approval_recorded',
              actor_employee_id: 'a0000006-0006-4006-8006-000000000001',
              safe_error_code: null,
              safe_error_context: { approval_recorded: true, apply_execution_open: false },
              next_action_key: 'hold_for_apply_execution_design',
              records_seen: 1,
              records_inserted: 0,
              records_updated: 1,
              records_failed: 0,
            },
            {
              id: 'review-event',
              created_at: '2026-06-05T14:02:00.000Z',
              status: 'success',
              sync_type: 'import_apply_review',
              event_key: 'import_apply_review_requested',
              actor_employee_id: 'a0000006-0006-4006-8006-000000000001',
              safe_error_code: null,
              safe_error_context: {
                safe_to_apply: false,
                apply_execution_open: false,
                human_review_recorded: true,
              },
              next_action_key: 'hold_for_apply_design',
              records_seen: 1,
              records_inserted: 0,
              records_updated: 1,
              records_failed: 0,
            },
          ],
        },
        import_batches: {
          data: [
            {
              id: 'batch-guarded-update-blocked',
              source_namespace_id: 'namespace-1',
              status: 'previewed',
              mode: 'dry_run',
              source_checksum: 'pr16_4_guarded_update_v1',
              row_count: 1,
              create_count: 0,
              update_count: 1,
              skip_count: 0,
              error_count: 0,
              violation_count: 0,
              validated_at: '2026-06-05T13:00:00.000Z',
              previewed_at: '2026-06-05T13:01:00.000Z',
              created_at: '2026-06-05T12:59:00.000Z',
              updated_at: '2026-06-05T13:01:00.000Z',
            },
          ],
        },
        'rpc:list_connector_import_preview_records': { data: [] },
        'rpc:list_connector_apply_safety_contracts': {
          data: [
            {
              contract_version: 'pr16.4.2-guarded-update-worker-apply-v1',
              browser_direct_apply_enabled: false,
              authenticated_apply_rpc_exposed: false,
              worker_import_apply_enqueue_enabled: true,
              worker_import_apply_claim_enabled: true,
              execution_enabled: true,
              canonical_write_enabled: true,
              source_writeback_enabled: false,
              credential_readback_enabled: false,
              audit_tiers: ['object_event', 'field_diff', 'rollback_snapshot', 'archive_summary'],
              field_diff_hot_retention_days: 90,
              rollback_snapshot_hot_retention_days: 90,
              object_event_retention_months: 24,
              purge_archive_required: true,
            },
          ],
          error: null,
        },
        'rpc:list_connector_apply_change_set_summaries': {
          data: [
            {
              id: 'change-set-guarded-update-blocked',
              import_batch_id: 'batch-guarded-update-blocked',
              status: 'blocked',
              source_checksum: 'pr16_4_guarded_update_v1',
              change_set_checksum: 'safe-guarded-update-change-set-hash',
              previewed_at: '2026-06-05T13:01:00.000Z',
              row_count: 1,
              create_count: 0,
              update_count: 1,
              skip_count: 0,
              blocked_count: 1,
              stale_count: 0,
              destructive_count: 0,
              source_conflict_count: 0,
              guarded_update_count: 1,
              no_change_count: 0,
              approval_required: true,
              sample_items: [],
              created_at: '2026-06-05T13:02:00.000Z',
            },
          ],
          error: null,
        },
        'rpc:list_connector_guarded_update_evidence': { data: [] },
      },
      capture,
    )

    await expect(requestConnectorGuardedUpdateApplyJob('user-1')).rejects.toMatchObject({
      code: 'PULS_CONNECTOR_GUARDED_UPDATE_APPLY_BLOCKED',
      i18nKey: 'erp.errors.guardedUpdateApplyBlocked',
    })
    expect(
      capture.rpcCalls?.some((call) => call.fn === 'enqueue_connector_guarded_update_apply_job'),
    ).toBe(false)
  })

  it('exposes guarded update recovery readiness without rollback execution or value readback', async () => {
    resolveTenant.mockResolvedValue(mockTenantContext())
    const capture: ClientCapture = { rpcCalls: [] }
    setupSeededMocks(
      {
        erp_sync_batches: {
          data: [
            {
              id: 'approval-event',
              created_at: '2026-06-05T14:03:00.000Z',
              status: 'success',
              sync_type: 'import_apply_review',
              event_key: 'import_apply_approval_recorded',
              actor_employee_id: 'a0000006-0006-4006-8006-000000000001',
              safe_error_code: null,
              safe_error_context: { approval_recorded: true, safe_to_apply: false },
              next_action_key: 'enqueue_guarded_update_apply_after_review',
              records_seen: 1,
              records_inserted: 0,
              records_updated: 1,
              records_failed: 0,
            },
            {
              id: 'review-event',
              created_at: '2026-06-05T14:02:00.000Z',
              status: 'success',
              sync_type: 'import_apply_review',
              event_key: 'import_apply_review_requested',
              actor_employee_id: 'a0000006-0006-4006-8006-000000000001',
              safe_error_code: null,
              safe_error_context: {
                safe_to_apply: false,
                human_review_recorded: true,
              },
              next_action_key: 'hold_for_apply_design',
              records_seen: 1,
              records_inserted: 0,
              records_updated: 1,
              records_failed: 0,
            },
          ],
        },
        import_batches: {
          data: [
            {
              id: 'batch-guarded-update-applied',
              source_namespace_id: 'namespace-1',
              status: 'previewed',
              mode: 'dry_run',
              source_checksum: 'pr16_4_3_guarded_update_recovery_v1',
              row_count: 1,
              create_count: 0,
              update_count: 1,
              skip_count: 0,
              error_count: 0,
              violation_count: 0,
              validated_at: '2026-06-05T13:00:00.000Z',
              previewed_at: '2026-06-05T13:01:00.000Z',
              created_at: '2026-06-05T12:59:00.000Z',
              updated_at: '2026-06-05T13:01:00.000Z',
            },
          ],
        },
        'rpc:list_connector_import_preview_records': { data: [] },
        'rpc:list_connector_apply_safety_contracts': {
          data: [
            {
              contract_version: 'pr16.7-guarded-update-rollback-worker-readiness-v1',
              browser_direct_apply_enabled: false,
              authenticated_apply_rpc_exposed: false,
              worker_import_apply_enqueue_enabled: true,
              worker_import_apply_claim_enabled: true,
              execution_enabled: true,
              canonical_write_enabled: true,
              source_writeback_enabled: false,
              credential_readback_enabled: false,
              audit_tiers: ['object_event', 'field_diff', 'rollback_snapshot', 'archive_summary'],
              field_diff_hot_retention_days: 90,
              rollback_snapshot_hot_retention_days: 90,
              object_event_retention_months: 24,
              purge_archive_required: true,
              safe_error_code: 'guarded_update_rollback_worker_readiness_open',
              next_action_key: 'review_guarded_update_rollback_worker_readiness',
            },
          ],
          error: null,
        },
        'rpc:list_connector_apply_change_set_summaries': {
          data: [
            {
              id: 'change-set-guarded-update-applied',
              import_batch_id: 'batch-guarded-update-applied',
              status: 'blocked',
              source_checksum: 'pr16_4_3_guarded_update_recovery_v1',
              change_set_checksum: 'safe-guarded-update-recovery-change-set-hash',
              previewed_at: '2026-06-05T13:01:00.000Z',
              row_count: 1,
              create_count: 0,
              update_count: 1,
              skip_count: 0,
              blocked_count: 1,
              stale_count: 0,
              destructive_count: 0,
              source_conflict_count: 0,
              guarded_update_count: 1,
              no_change_count: 0,
              approval_required: true,
              sample_items: [],
              created_at: '2026-06-05T13:02:00.000Z',
            },
          ],
          error: null,
        },
        'rpc:list_connector_guarded_update_evidence': {
          data: [
            {
              change_set_id: 'change-set-guarded-update-applied',
              import_batch_id: 'batch-guarded-update-applied',
              status: 'evidence_ready',
              guarded_update_count: 1,
              field_diff_count: 1,
              rollback_snapshot_count: 1,
              stale_blocked_count: 0,
              execution_enabled: false,
              canonical_write_enabled: false,
              source_writeback_enabled: false,
              credential_readback_enabled: false,
              value_readback_enabled: false,
              hot_retention_days: 90,
              next_action_key: 'review_guarded_update_evidence',
              sample_field_diffs: [],
              created_at: '2026-06-05T13:02:30.000Z',
            },
          ],
          error: null,
        },
        'rpc:list_connector_guarded_update_recovery_readiness': {
          data: [
            {
              change_set_id: 'change-set-guarded-update-applied',
              import_batch_id: 'batch-guarded-update-applied',
              status: 'recovery_ready',
              applied_at: '2026-06-05T14:10:00.000Z',
              update_count: 1,
              object_event_count: 1,
              field_diff_count: 1,
              rollback_snapshot_count: 1,
              rollback_ready_count: 1,
              stale_recheck_verified_count: 1,
              rollback_execution_enabled: false,
              compensating_preview_enabled: false,
              source_writeback_enabled: false,
              credential_readback_enabled: false,
              value_readback_enabled: false,
              recovery_window_hot_retention_days: 90,
              hot_retention_expires_at: '2026-09-03T14:10:00.000Z',
              purge_after_at: '2028-06-05T14:10:00.000Z',
              purge_archive_required: true,
              next_action_key: 'prepare_rollback_preview_pr16_5',
              sample_events: [
                {
                  id: 'object-event-1',
                  row_number: 1,
                  operation: 'update',
                  entity_type: 'department',
                  external_id: 'DEPT-1',
                  target_table: 'departments',
                  canonical_id: 'department-1',
                  connector_job_id: 'job-1',
                  created_by_worker_id: 'railway-erp-connector-production-1',
                  created_at: '2026-06-05T14:10:00.000Z',
                  safe_field_names: ['name'],
                  field_diff_count: 1,
                  rollback_snapshot_required: true,
                  canonical_write: true,
                  source_writeback: false,
                  provider_api_calls: false,
                  credential_readback: false,
                  field_value_readback: false,
                  raw_payload_readback: false,
                  rollback_execution: false,
                },
              ],
              created_at: '2026-06-05T14:10:00.000Z',
            },
          ],
          error: null,
        },
        'rpc:list_connector_guarded_update_recovery_runbooks': {
          data: [
            {
              change_set_id: 'change-set-guarded-update-applied',
              import_batch_id: 'batch-guarded-update-applied',
              status: 'ready_for_rollback_preview',
              recommended_action: 'prepare_rollback_preview',
              readiness_status: 'ready',
              applied_at: '2026-06-05T14:10:00.000Z',
              update_count: 1,
              object_event_count: 1,
              field_diff_count: 1,
              rollback_snapshot_count: 1,
              rollback_ready_count: 1,
              stale_recheck_verified_count: 1,
              blocker_codes: [],
              operator_review_required: true,
              approval_required: true,
              rollback_preview_candidate: true,
              rollback_preview_enabled: false,
              rollback_execution_enabled: false,
              compensating_execution_enabled: false,
              source_writeback_enabled: false,
              credential_readback_enabled: false,
              value_readback_enabled: false,
              hot_retention_expires_at: '2026-09-03T14:10:00.000Z',
              purge_after_at: '2028-06-05T14:10:00.000Z',
              next_action_key: 'prepare_rollback_preview_pr16_5',
              safe_steps: [
                {
                  step_key: 'verify_original_apply_event',
                  step_status: 'verified',
                  evidence_count: 1,
                  required_count: 1,
                  blocker_code: null,
                  next_action_key: null,
                },
                {
                  step_key: 'verify_hash_only_field_diffs',
                  step_status: 'verified',
                  evidence_count: 1,
                  required_count: 1,
                  blocker_code: null,
                  next_action_key: null,
                },
                {
                  step_key: 'verify_rollback_snapshot_window',
                  step_status: 'verified',
                  evidence_count: 1,
                  required_count: 1,
                  blocker_code: null,
                  next_action_key: null,
                },
                {
                  step_key: 'prepare_pr16_5_preview_gate',
                  step_status: 'candidate',
                  evidence_count: 1,
                  required_count: 1,
                  blocker_code: null,
                  next_action_key: 'prepare_rollback_preview_pr16_5',
                },
              ],
              created_at: '2026-06-05T14:10:00.000Z',
            },
          ],
          error: null,
        },
        'rpc:list_connector_guarded_update_rollback_previews': {
          data: [
            {
              rollback_preview_id: 'rollback-preview-1',
              change_set_id: 'change-set-guarded-update-applied',
              import_batch_id: 'batch-guarded-update-applied',
              status: 'ready_for_rollback_review',
              preview_kind: 'rollback',
              rollback_preview_checksum: 'safe-rollback-preview-hash',
              row_count: 1,
              rollback_count: 1,
              blocked_count: 0,
              stale_blocked_count: 0,
              field_diff_count: 1,
              rollback_snapshot_count: 1,
              rollback_preview_enabled: true,
              rollback_execution_enabled: false,
              compensating_execution_enabled: false,
              source_writeback_enabled: false,
              credential_readback_enabled: false,
              value_readback_enabled: false,
              approval_required: true,
              operator_review_required: true,
              next_action_key: 'review_rollback_preview_before_execution',
              sample_items: [
                {
                  id: 'rollback-preview-item-1',
                  row_number: 1,
                  entity_type: 'department',
                  external_id: 'DEPT-1',
                  target_table: 'departments',
                  canonical_id: 'department-1',
                  operation: 'rollback',
                  item_status: 'ready',
                  risk_class: 'rollback_preview_required',
                  blocker_codes: [],
                  safe_field_names: ['name'],
                  rollback_field_names: ['name'],
                  field_diff_count: 1,
                  rollback_snapshot_available: true,
                  snapshot_state: 'available',
                  snapshot_hash_available: true,
                  expected_post_apply_hash_available: true,
                  current_hash_available: true,
                  current_state_matches_apply: true,
                  stale_blocked: false,
                  retention_bucket: 'rollback_snapshot',
                  hot_retention_expires_at: '2026-09-03T14:10:00.000Z',
                  purge_after_at: '2028-06-05T14:10:00.000Z',
                },
              ],
              created_at: '2026-06-05T14:20:00.000Z',
            },
          ],
          error: null,
        },
        'rpc:list_connector_guarded_update_rollback_approvals': {
          data: [
            {
              rollback_approval_id: 'rollback-approval-1',
              rollback_preview_id: 'rollback-preview-1',
              change_set_id: 'change-set-guarded-update-applied',
              import_batch_id: 'batch-guarded-update-applied',
              approval_status: 'approval_recorded',
              approval_policy: 'admin_only',
              rollback_preview_checksum: 'safe-rollback-preview-hash',
              row_count: 1,
              rollback_count: 1,
              blocked_count: 0,
              stale_blocked_count: 0,
              field_diff_count: 1,
              rollback_snapshot_count: 1,
              rollback_approval_enabled: true,
              rollback_execution_enabled: false,
              compensating_execution_enabled: false,
              source_writeback_enabled: false,
              credential_readback_enabled: false,
              value_readback_enabled: false,
              approval_required: true,
              operator_review_required: true,
              next_action_key: 'prepare_guarded_update_rollback_worker_pr16_7',
              approved_by_employee_id: 'employee-1',
              approved_at: '2026-06-05T14:25:00.000Z',
            },
          ],
          error: null,
        },
        'rpc:list_connector_guarded_update_rollback_worker_readiness': {
          data: [
            {
              rollback_worker_readiness_id: 'rollback-worker-readiness-1',
              rollback_approval_id: 'rollback-approval-1',
              rollback_preview_id: 'rollback-preview-1',
              change_set_id: 'change-set-guarded-update-applied',
              import_batch_id: 'batch-guarded-update-applied',
              readiness_status: 'ready_for_worker_handoff',
              readiness_policy: 'approval_checksum_current_state_retention',
              worker_contract: 'pr16.7-rollback-worker-readiness-v1',
              expected_job_type: 'import_apply',
              expected_job_domain: 'import_apply_guarded_update_rollback',
              rollback_preview_checksum: 'safe-rollback-preview-hash',
              row_count: 1,
              rollback_count: 1,
              blocker_count: 0,
              stale_blocked_count: 0,
              drift_blocked_count: 0,
              expired_snapshot_count: 0,
              field_diff_count: 1,
              rollback_snapshot_count: 1,
              original_apply_event_count: 1,
              current_state_verified_count: 1,
              retention_verified_count: 1,
              approval_verified: true,
              approval_checksum_verified: true,
              worker_handoff_ready: true,
              rollback_job_enqueue_enabled: false,
              rollback_execution_enabled: false,
              canonical_write_enabled: false,
              compensating_execution_enabled: false,
              source_writeback_enabled: false,
              credential_readback_enabled: false,
              value_readback_enabled: false,
              provider_api_calls_enabled: false,
              approval_required: true,
              operator_review_required: true,
              next_action_key: 'implement_guarded_update_rollback_worker_pr16_8',
              sample_items: [
                {
                  row_number: 1,
                  operation: 'rollback',
                  entity_type: 'department',
                  external_id: 'DEPT-1',
                  target_table: 'departments',
                  canonical_id: 'department-1',
                  safe_field_names: ['name'],
                  rollback_field_names: ['name'],
                  field_diff_count: 1,
                  rollback_snapshot_available: true,
                  current_hash_available: true,
                  current_state_matches_apply: true,
                  original_apply_event_count: 1,
                  rollback_execution: false,
                  canonical_write: false,
                  source_writeback: false,
                  provider_api_calls: false,
                  credential_readback: false,
                  field_value_readback: false,
                  raw_payload_readback: false,
                  snapshot_payload_readback: false,
                },
              ],
              created_at: '2026-06-05T14:30:00.000Z',
            },
          ],
          error: null,
        },
      },
      capture,
    )

    const overview = await fetchErpOverviewWithMeta('user-1')

    expect(overview.data.applySafetyContract).toMatchObject({
      contractVersion: 'pr16.7-guarded-update-rollback-worker-readiness-v1',
      executionEnabled: true,
      canonicalWriteEnabled: true,
      sourceWritebackEnabled: false,
      credentialReadbackEnabled: false,
      safeErrorCode: 'guarded_update_rollback_worker_readiness_open',
      nextActionKey: 'review_guarded_update_rollback_worker_readiness',
    })
    expect(overview.data.applyExecutionContract).toMatchObject({
      safeToExecute: true,
      executorMode: 'worker_guarded_update_job',
    })
    expect(overview.data.guardedUpdateRecovery).toMatchObject({
      changeSetId: 'change-set-guarded-update-applied',
      status: 'recovery_ready',
      readiness: 'ready',
      rollbackExecutionEnabled: false,
      compensatingPreviewEnabled: false,
      sourceWritebackEnabled: false,
      credentialReadbackEnabled: false,
      valueReadbackEnabled: false,
      batchId: 'batch-guarded-update-applied',
      nextActionKey: 'prepare_rollback_preview_pr16_5',
      summary: {
        updateCount: 1,
        objectEventCount: 1,
        fieldDiffCount: 1,
        rollbackSnapshotCount: 1,
        rollbackReadyCount: 1,
        staleRecheckVerifiedCount: 1,
        recoveryWindowHotRetentionDays: 90,
      },
    })
    expect(overview.data.guardedUpdateRecovery.sampleEvents[0]).toMatchObject({
      operation: 'update',
      safeFieldNames: ['name'],
      fieldDiffCount: 1,
      rollbackSnapshotRequired: true,
      canonicalWrite: true,
      sourceWriteback: false,
      providerApiCalls: false,
      credentialReadback: false,
      fieldValueReadback: false,
      rawPayloadReadback: false,
      rollbackExecution: false,
    })
    expect(capture.rpcCalls).toContainEqual({
      fn: 'list_connector_guarded_update_recovery_readiness',
      args: { p_change_set_id: 'change-set-guarded-update-applied', p_limit: 8 },
    })
    expect(overview.data.guardedUpdateRecoveryRunbook).toMatchObject({
      changeSetId: 'change-set-guarded-update-applied',
      status: 'ready_for_rollback_preview',
      readiness: 'ready',
      recommendedAction: 'prepare_rollback_preview',
      rollbackPreviewCandidate: true,
      rollbackPreviewEnabled: false,
      rollbackExecutionEnabled: false,
      compensatingExecutionEnabled: false,
      sourceWritebackEnabled: false,
      credentialReadbackEnabled: false,
      valueReadbackEnabled: false,
      operatorReviewRequired: true,
      approvalRequired: true,
      blockerCodes: [],
      nextActionKey: 'prepare_rollback_preview_pr16_5',
      summary: {
        updateCount: 1,
        objectEventCount: 1,
        fieldDiffCount: 1,
        rollbackSnapshotCount: 1,
        rollbackReadyCount: 1,
        staleRecheckVerifiedCount: 1,
      },
    })
    expect(overview.data.guardedUpdateRecoveryRunbook.safeSteps).toHaveLength(4)
    expect(overview.data.guardedUpdateRecoveryRunbook.safeSteps[3]).toMatchObject({
      stepKey: 'prepare_pr16_5_preview_gate',
      stepStatus: 'candidate',
      nextActionKey: 'prepare_rollback_preview_pr16_5',
    })
    expect(capture.rpcCalls).toContainEqual({
      fn: 'list_connector_guarded_update_recovery_runbooks',
      args: { p_change_set_id: 'change-set-guarded-update-applied', p_limit: 8 },
    })
    expect(overview.data.guardedUpdateRollbackPreview).toMatchObject({
      rollbackPreviewId: 'rollback-preview-1',
      changeSetId: 'change-set-guarded-update-applied',
      status: 'ready_for_rollback_review',
      readiness: 'ready',
      action: 'review_preview',
      rollbackPreviewEnabled: true,
      rollbackExecutionEnabled: false,
      compensatingExecutionEnabled: false,
      sourceWritebackEnabled: false,
      credentialReadbackEnabled: false,
      valueReadbackEnabled: false,
      approvalRequired: true,
      operatorReviewRequired: true,
      nextActionKey: 'review_rollback_preview_before_execution',
      summary: {
        rowCount: 1,
        rollbackCount: 1,
        blockedCount: 0,
        staleBlockedCount: 0,
        fieldDiffCount: 1,
        rollbackSnapshotCount: 1,
      },
    })
    expect(overview.data.guardedUpdateRollbackPreview.sampleItems[0]).toMatchObject({
      operation: 'rollback',
      itemStatus: 'ready',
      riskClass: 'rollback_preview_required',
      blockerCodes: [],
      rollbackFieldNames: ['name'],
      fieldDiffCount: 1,
      rollbackSnapshotAvailable: true,
      snapshotHashAvailable: true,
      expectedPostApplyHashAvailable: true,
      currentHashAvailable: true,
      currentStateMatchesApply: true,
      staleBlocked: false,
    })
    expect(overview.data.guardedUpdateRollbackApproval).toMatchObject({
      rollbackApprovalId: 'rollback-approval-1',
      rollbackPreviewId: 'rollback-preview-1',
      changeSetId: 'change-set-guarded-update-applied',
      status: 'approval_recorded',
      readiness: 'ready',
      action: 'approval_recorded',
      requestable: false,
      rollbackApprovalEnabled: true,
      rollbackExecutionEnabled: false,
      compensatingExecutionEnabled: false,
      sourceWritebackEnabled: false,
      credentialReadbackEnabled: false,
      valueReadbackEnabled: false,
      approvalRequired: true,
      operatorReviewRequired: true,
      rollbackPreviewChecksum: 'safe-rollback-preview-hash',
      approvedAt: '2026-06-05T14:25:00.000Z',
      nextActionKey: 'prepare_guarded_update_rollback_worker_pr16_7',
      summary: {
        rowCount: 1,
        rollbackCount: 1,
        blockedCount: 0,
        staleBlockedCount: 0,
        fieldDiffCount: 1,
        rollbackSnapshotCount: 1,
      },
    })
    expect(capture.rpcCalls).toContainEqual({
      fn: 'list_connector_guarded_update_rollback_previews',
      args: { p_change_set_id: 'change-set-guarded-update-applied', p_limit: 8 },
    })
    expect(capture.rpcCalls).toContainEqual({
      fn: 'list_connector_guarded_update_rollback_approvals',
      args: { p_change_set_id: 'change-set-guarded-update-applied', p_limit: 8 },
    })
    expect(overview.data.guardedUpdateRollbackWorkerReadiness).toMatchObject({
      rollbackWorkerReadinessId: 'rollback-worker-readiness-1',
      rollbackApprovalId: 'rollback-approval-1',
      rollbackPreviewId: 'rollback-preview-1',
      changeSetId: 'change-set-guarded-update-applied',
      status: 'ready_for_worker_handoff',
      readiness: 'ready',
      action: 'review_readiness',
      requestable: false,
      workerHandoffReady: true,
      rollbackJobEnqueueEnabled: false,
      rollbackExecutionEnabled: false,
      canonicalWriteEnabled: false,
      compensatingExecutionEnabled: false,
      sourceWritebackEnabled: false,
      credentialReadbackEnabled: false,
      valueReadbackEnabled: false,
      providerApiCallsEnabled: false,
      workerContract: 'pr16.7-rollback-worker-readiness-v1',
      expectedJobType: 'import_apply',
      expectedJobDomain: 'import_apply_guarded_update_rollback',
      rollbackPreviewChecksum: 'safe-rollback-preview-hash',
      nextActionKey: 'implement_guarded_update_rollback_worker_pr16_8',
      summary: {
        rowCount: 1,
        rollbackCount: 1,
        blockerCount: 0,
        staleBlockedCount: 0,
        driftBlockedCount: 0,
        expiredSnapshotCount: 0,
        fieldDiffCount: 1,
        rollbackSnapshotCount: 1,
        originalApplyEventCount: 1,
        currentStateVerifiedCount: 1,
        retentionVerifiedCount: 1,
      },
    })
    expect(overview.data.guardedUpdateRollbackWorkerReadiness.sampleItems[0]).toMatchObject({
      operation: 'rollback',
      rollbackFieldNames: ['name'],
      fieldDiffCount: 1,
      rollbackSnapshotAvailable: true,
      currentHashAvailable: true,
      currentStateMatchesApply: true,
      originalApplyEventCount: 1,
      rollbackExecution: false,
      canonicalWrite: false,
      sourceWriteback: false,
      providerApiCalls: false,
      credentialReadback: false,
      fieldValueReadback: false,
      rawPayloadReadback: false,
      snapshotPayloadReadback: false,
    })
    expect(capture.rpcCalls).toContainEqual({
      fn: 'list_connector_guarded_update_rollback_worker_readiness',
      args: { p_change_set_id: 'change-set-guarded-update-applied', p_limit: 8 },
    })
    expect(JSON.stringify(overview.data.guardedUpdateRecovery)).not.toContain('snapshot_payload')
    expect(JSON.stringify(overview.data.guardedUpdateRecovery)).not.toContain('before_value')
    expect(JSON.stringify(overview.data.guardedUpdateRecovery)).not.toContain('after_value')
    expect(JSON.stringify(overview.data.guardedUpdateRecovery)).not.toContain('"raw_payload":')
    expect(JSON.stringify(overview.data.guardedUpdateRecovery)).not.toContain('credentials_ref')
    expect(JSON.stringify(overview.data.guardedUpdateRecoveryRunbook)).not.toContain(
      'snapshot_payload',
    )
    expect(JSON.stringify(overview.data.guardedUpdateRecoveryRunbook)).not.toContain('before_value')
    expect(JSON.stringify(overview.data.guardedUpdateRecoveryRunbook)).not.toContain('after_value')
    expect(JSON.stringify(overview.data.guardedUpdateRecoveryRunbook)).not.toContain(
      '"raw_payload":',
    )
    expect(JSON.stringify(overview.data.guardedUpdateRecoveryRunbook)).not.toContain(
      'credentials_ref',
    )
    expect(JSON.stringify(overview.data.guardedUpdateRollbackPreview)).not.toContain(
      'snapshot_payload',
    )
    expect(JSON.stringify(overview.data.guardedUpdateRollbackPreview)).not.toContain('before_value')
    expect(JSON.stringify(overview.data.guardedUpdateRollbackPreview)).not.toContain('after_value')
    expect(JSON.stringify(overview.data.guardedUpdateRollbackPreview)).not.toContain(
      '"raw_payload":',
    )
    expect(JSON.stringify(overview.data.guardedUpdateRollbackPreview)).not.toContain(
      'credentials_ref',
    )
    expect(JSON.stringify(overview.data.guardedUpdateRollbackApproval)).not.toContain(
      'snapshot_payload',
    )
    expect(JSON.stringify(overview.data.guardedUpdateRollbackApproval)).not.toContain(
      'before_value',
    )
    expect(JSON.stringify(overview.data.guardedUpdateRollbackApproval)).not.toContain('after_value')
    expect(JSON.stringify(overview.data.guardedUpdateRollbackApproval)).not.toContain(
      '"raw_payload":',
    )
    expect(JSON.stringify(overview.data.guardedUpdateRollbackApproval)).not.toContain(
      'credentials_ref',
    )
    expect(JSON.stringify(overview.data.guardedUpdateRollbackWorkerReadiness)).not.toContain(
      'snapshot_payload',
    )
    expect(JSON.stringify(overview.data.guardedUpdateRollbackWorkerReadiness)).not.toContain(
      'before_value',
    )
    expect(JSON.stringify(overview.data.guardedUpdateRollbackWorkerReadiness)).not.toContain(
      'after_value',
    )
    expect(JSON.stringify(overview.data.guardedUpdateRollbackWorkerReadiness)).not.toContain(
      '"raw_payload":',
    )
    expect(JSON.stringify(overview.data.guardedUpdateRollbackWorkerReadiness)).not.toContain(
      'credentials_ref',
    )
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
    expect(result.data.applyExecutionContract).toMatchObject({
      status: 'not_available',
      executionEnabled: false,
      canonicalWriteEnabled: false,
      sourceWritebackEnabled: false,
      credentialReadbackEnabled: false,
      applyRpcExposed: false,
      authenticatedApplyRpcExposed: false,
      workerImportApplyEnqueueEnabled: false,
      workerImportApplyClaimEnabled: false,
      safeToExecute: false,
      batchId: null,
      sourceChecksum: null,
      sourceNamespaceCode: null,
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
    expect(result.data.dataSources.map((source) => source.providerId)).toEqual([
      'canias',
      'logo',
      'csv_import',
      'custom_api',
    ])
    expect(result.data.dataSources.every((source) => source.sourceKind === 'catalog')).toBe(true)
    expect(result.data.dataSources[0]).toMatchObject({
      status: 'not_configured',
      primaryAction: 'start_setup',
    })
    expect(result.data.dataSources[1]).toMatchObject({
      providerId: 'logo',
      status: 'not_configured',
      primaryAction: 'none',
      setupAvailable: false,
    })
    expect(result.data.dataSources[2]).toMatchObject({
      providerId: 'csv_import',
      status: 'not_configured',
      primaryAction: 'upload_file',
    })
    expect(result.data.dataSources[3]).toMatchObject({
      providerId: 'custom_api',
      status: 'not_configured',
      primaryAction: 'none',
      setupAvailable: false,
    })
    expect(result.data.providerOptions.every((option) => option.requirements.length > 0)).toBe(true)
    expect(
      result.data.providerOptions.every(
        (option) =>
          option.categoryKey.startsWith('erp.providerCatalog.categories.') &&
          option.transferMethodKey.startsWith('erp.providerCatalog.methods.') &&
          option.availabilityKey.startsWith('erp.providerCatalog.availability.') &&
          option.recommendedUseKey.startsWith('erp.providerCatalog.recommendedUse.'),
      ),
    ).toBe(true)
    expect(result.data.providerOptions[0].readinessLabelKey).toBe(
      'erp.providerOptions.canias.readiness',
    )
    expect(result.data.providerOptions[0]).toMatchObject({
      categoryKey: 'erp.providerCatalog.categories.erp',
      transferMethodKey: 'erp.providerCatalog.methods.restApi',
      availabilityKey: 'erp.providerCatalog.availability.setupDraftAvailable',
      recommendedUseKey: 'erp.providerCatalog.recommendedUse.canias',
    })
    expect(result.data.providerOptions[2]).toMatchObject({
      categoryKey: 'erp.providerCatalog.categories.file',
      transferMethodKey: 'erp.providerCatalog.methods.fileOrManual',
      availabilityKey: 'erp.providerCatalog.availability.setupDraftAvailable',
      recommendedUseKey: 'erp.providerCatalog.recommendedUse.csv_import',
    })
    expect(result.data.accessReadiness).toMatchObject({
      status: 'blocked',
      score: 0,
      nextActionKey: 'erp.accessReadiness.nextActions.select_source',
      liveProviderCallsEnabled: false,
      credentialReadbackEnabled: false,
      sourceWritebackEnabled: false,
      canProceedWithoutLiveApi: false,
    })
    expect(result.data.customerHandoff).toMatchObject({
      status: 'blocked',
      score: 0,
      shareableWithCustomer: false,
      nextActionKey: 'erp.customerHandoff.nextActions.select_source',
    })
    expect(result.data.customerHandoff.items.every((row) => row.status === 'blocked')).toBe(true)
    expect(result.data.goLivePlan).toMatchObject({
      status: 'blocked',
      score: 0,
      canStartCustomerPilot: false,
      nextActionKey: 'erp.goLivePlan.nextActions.select_source',
    })
    expect(result.data.goLivePlan.gaps.every((gap) => gap.status === 'blocked')).toBe(true)
    expect(result.data.accessReadiness.requirements.every((row) => row.status === 'blocked')).toBe(
      true,
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
      result.data.customerHandoff.items.find((item) => item.id === 'secure_access'),
    ).toMatchObject({
      status: 'ready',
      valueKey: 'erp.customerHandoff.values.secureAccessReady',
    })
    expect(result.data.goLivePlan.gaps.find((gap) => gap.id === 'secure_access')).toMatchObject({
      status: 'ready',
      evidenceKey: 'erp.goLivePlan.evidence.secureAccessReady',
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
    const integrationClient = client(
      {
        erp_connections: {
          maybeSingleData: null,
          error: null,
          singleData: { id: 'connection-new' },
        },
        erp_field_mappings: { data: [], error: null },
      },
      capture,
    )
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

  it('blocks a second source from owning an active canonical domain', async () => {
    resolveTenant.mockResolvedValue(mockTenantContext())
    const integrationClient = client({
      erp_connections: {
        data: [
          {
            id: 'connection-canias',
            provider: 'canias',
            connection_key: 'canias-default',
            setup_status: 'connected',
            setup_step: 'runtime',
            is_enabled: true,
            is_active: true,
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

  it('allows CSV setup while Canias is still a non-runtime setup source', async () => {
    resolveTenant.mockResolvedValue(mockTenantContext())
    const capture: ClientCapture = { inserts: [], updates: [] }
    const integrationClient = client(
      {
        erp_connections: {
          data: [
            {
              id: 'connection-canias',
              provider: 'canias',
              connection_key: 'canias-default',
              setup_status: 'mapping_ready',
              setup_step: 'preflight',
              is_enabled: true,
              is_active: false,
              owned_domains: ['employees', 'departments'],
              created_at: '2026-06-01T00:00:00.000Z',
              updated_at: '2026-06-01T00:00:00.000Z',
            },
          ],
          error: null,
          singleData: { id: 'connection-csv' },
        },
        erp_field_mappings: { data: [], error: null },
        erp_sync_batches: { data: { id: 'history-1' }, error: null },
      },
      capture,
    )
    vi.mocked(pulsIntegration).mockReturnValue(integrationClient as never)

    const result = await startConnectorSetup('user-1', { providerId: 'csv_import' })

    expect(result).toMatchObject({
      connectionId: 'connection-csv',
      providerId: 'csv_import',
      setupStatus: 'mapping_ready',
      currentStep: 'namespace',
    })
    expect(capture.inserts).toContainEqual({
      table: 'erp_connections',
      payload: expect.objectContaining({
        provider: 'csv',
        connection_method: 'manual_import',
        connection_key: 'csv-excel-default',
      }),
    })
  })

  it('stages parsed CSV/Excel rows through the file import package RPC only', async () => {
    resolveTenant.mockResolvedValue(mockTenantContext())
    const capture: ClientCapture = { rpcCalls: [] }
    const integrationClient = client(
      {
        'rpc:ingest_file_import_package': {
          data: {
            connection_id: 'connection-csv',
            package_id: 'package-1',
            file_count: 1,
            row_count: 1,
            status: 'uploaded',
            mode: 'dry_run',
            next_action_key: 'run_file_import_preview',
            items: [
              {
                connection_id: 'connection-csv',
                source_namespace_id: 'namespace-csv',
                manifest_id: 'manifest-1',
                import_batch_id: 'batch-1',
                scope_key: 'employees',
                row_count: 1,
                status: 'uploaded',
                mode: 'dry_run',
                next_action_key: 'run_file_import_preview',
              },
            ],
          },
          error: null,
        },
      },
      capture,
    )
    vi.mocked(pulsIntegration).mockReturnValue(integrationClient as never)

    const result = await ingestFileImportBatch('user-1', {
      connectionId: 'connection-csv',
      scope: 'employees',
      fileName: 'puls_employees_v1_20260608.csv',
      fileExtension: 'csv',
      fileSizeBytes: 128,
      fileChecksum: 'a'.repeat(64),
      businessDate: '20260608',
      delimiter: ';',
      rowCount: 1,
      rows: [
        {
          rowNumber: 2,
          entityType: 'employee',
          externalId: 'E-001',
          payload: {
            employee_code: 'E-001',
            full_name: 'Ayşe Öz',
            email: 'ayse@example.com',
          },
        },
      ],
    })

    expect(result).toMatchObject({
      connectionId: 'connection-csv',
      sourceNamespaceId: 'namespace-csv',
      manifestId: 'manifest-1',
      batchId: 'batch-1',
      scope: 'employees',
      rowCount: 1,
      status: 'uploaded',
      mode: 'dry_run',
    })
    expect(capture.rpcCalls).toContainEqual({
      fn: 'ingest_file_import_package',
      args: expect.objectContaining({
        p_connection_id: 'connection-csv',
        p_package: expect.objectContaining({
          items: [
            expect.objectContaining({
              scope: 'employees',
              manifest: expect.objectContaining({
                file_name: 'puls_employees_v1_20260608.csv',
                file_checksum: 'a'.repeat(64),
                business_date: '20260608',
                row_count: 1,
              }),
              rows: [
                expect.objectContaining({
                  row_number: 2,
                  entity_type: 'employee',
                  external_id: 'E-001',
                }),
              ],
            }),
          ],
        }),
      }),
    })
    expect(JSON.stringify(capture.rpcCalls)).not.toContain('raw_payload')
    expect(JSON.stringify(capture.rpcCalls)).not.toContain('credential')
  })

  it('stages multiple parsed files through one atomic file import package RPC', async () => {
    resolveTenant.mockResolvedValue(mockTenantContext())
    const capture: ClientCapture = { rpcCalls: [] }
    setupSeededMocks(
      {
        'rpc:ingest_file_import_package': {
          data: {
            connection_id: 'connection-csv',
            package_id: 'package-1',
            file_count: 2,
            row_count: 2,
            status: 'uploaded',
            mode: 'dry_run',
            next_action_key: 'run_file_import_preview',
            items: [
              {
                connection_id: 'connection-csv',
                source_namespace_id: 'namespace-csv',
                manifest_id: 'manifest-legal',
                import_batch_id: 'batch-legal',
                scope_key: 'legal_entities',
                row_count: 1,
                status: 'uploaded',
                mode: 'dry_run',
                next_action_key: 'run_file_import_preview',
              },
              {
                connection_id: 'connection-csv',
                source_namespace_id: 'namespace-csv',
                manifest_id: 'manifest-employee',
                import_batch_id: 'batch-employee',
                scope_key: 'employees',
                row_count: 1,
                status: 'uploaded',
                mode: 'dry_run',
                next_action_key: 'run_file_import_preview',
              },
            ],
          },
          error: null,
        },
      },
      capture,
    )

    const result = await ingestFileImportPackage('user-1', {
      connectionId: 'connection-csv',
      packageId: 'package-1',
      files: [
        {
          scope: 'legal_entities',
          fileName: 'puls_legal_entities_v1_20260608.csv',
          parseResult: {
            ok: true,
            scope: 'legal_entities',
            fileName: 'puls_legal_entities_v1_20260608.csv',
            fileExtension: 'csv',
            fileSizeBytes: 64,
            fileChecksum: 'b'.repeat(64),
            templateVersion: 'v1',
            businessDate: '20260608',
            delimiter: ',',
            rowCount: 1,
            rows: [
              {
                rowNumber: 2,
                entityType: 'legal_entity',
                externalId: 'LE-001',
                payload: { code: 'LE-001', name: 'PULS Demo' },
              },
            ],
            mappedColumns: [],
            ignoredHeaders: [],
            issues: [],
          },
        },
        {
          scope: 'employees',
          fileName: 'puls_employees_v1_20260608.csv',
          parseResult: {
            ok: true,
            scope: 'employees',
            fileName: 'puls_employees_v1_20260608.csv',
            fileExtension: 'csv',
            fileSizeBytes: 64,
            fileChecksum: 'c'.repeat(64),
            templateVersion: 'v1',
            businessDate: '20260608',
            delimiter: ',',
            rowCount: 1,
            rows: [
              {
                rowNumber: 2,
                entityType: 'employee',
                externalId: 'E-001',
                payload: { employee_code: 'E-001', full_name: 'Ayşe Öz' },
              },
            ],
            mappedColumns: [],
            ignoredHeaders: [],
            issues: [],
          },
        },
      ],
    })

    expect(result).toMatchObject({
      connectionId: 'connection-csv',
      packageId: 'package-1',
      fileCount: 2,
      rowCount: 2,
      status: 'uploaded',
      mode: 'dry_run',
    })
    expect(result.items.map((item) => item.scope)).toEqual(['legal_entities', 'employees'])
    expect(capture.rpcCalls).toContainEqual({
      fn: 'ingest_file_import_package',
      args: expect.objectContaining({
        p_connection_id: 'connection-csv',
        p_package: expect.objectContaining({
          package_id: 'package-1',
          items: expect.arrayContaining([
            expect.objectContaining({ scope: 'legal_entities' }),
            expect.objectContaining({ scope: 'employees' }),
          ]),
        }),
      }),
    })
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

  it('queues runtime preflight through the safe RPC when credentials are verified', async () => {
    resolveTenant.mockResolvedValue(mockTenantContext())
    const capture: ClientCapture = { inserts: [], updates: [], rpcCalls: [] }
    setupSeededMocks(
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
              credential_state: 'verified',
              credential_last_verified_at: '2026-06-04T12:00:00.000Z',
              credential_last_failed_at: null,
              credential_error_code: null,
              credential_handoff_status: 'verified',
              credential_handoff_requested_at: null,
              credential_handoff_requested_by_employee_id: null,
              credential_handoff_updated_at: '2026-06-04T12:00:00.000Z',
              created_at: '2026-06-01T00:00:00.000Z',
              updated_at: '2026-06-04T12:00:00.000Z',
            },
          ],
        },
        'rpc:request_connector_runtime_preflight': {
          data: [
            {
              job_id: 'runtime-job-1',
              status: 'queued',
              credential_state: 'verified',
              next_action_key: 'wait_for_worker_runtime_preflight',
            },
          ],
          error: null,
        },
      },
      capture,
    )

    const result = await requestConnectorRuntimePreflight('user-1')

    expect(result).toEqual({
      connectionId: 'connection-1',
      jobId: 'runtime-job-1',
      status: 'queued',
      credentialState: 'verified',
      nextActionKey: 'wait_for_worker_runtime_preflight',
    })
    expect(capture.rpcCalls).toContainEqual({
      fn: 'request_connector_runtime_preflight',
      args: {
        p_connection_id: 'connection-1',
        p_actor_employee_id: 'a0000006-0006-4006-8006-000000000001',
      },
    })
    expect(capture.inserts).toEqual([])
    expect(capture.updates).toEqual([])
    expect(JSON.stringify(capture.rpcCalls)).not.toContain('credentials_ref')
    expect(JSON.stringify(capture.rpcCalls)).not.toContain('secret')
  })

  it('blocks runtime preflight before calling RPC when credentials are not verified', async () => {
    resolveTenant.mockResolvedValue(mockTenantContext())
    const capture: ClientCapture = { rpcCalls: [] }
    setupSeededMocks({}, capture)

    await expect(requestConnectorRuntimePreflight('user-1')).rejects.toMatchObject({
      code: 'PULS_CONNECTOR_RUNTIME_PREFLIGHT_CREDENTIAL_NOT_VERIFIED',
      i18nKey: 'erp.errors.runtimePreflightBlocked',
    })
    expect(
      capture.rpcCalls?.some((call) => call.fn === 'request_connector_runtime_preflight'),
    ).toBe(false)
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
      'list_connector_job_events',
      'list_connector_credential_events',
      'list_connector_import_preview_records',
      'list_connector_apply_safety_contracts',
      'list_connector_apply_change_set_summaries',
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
    expect(JSON.stringify(capture.inserts)).not.toContain('"raw_payload":')
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
      'list_connector_job_events',
      'list_connector_credential_events',
      'list_connector_import_preview_records',
      'list_connector_apply_safety_contracts',
      'list_connector_apply_change_set_summaries',
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

  it('records connector apply review intent without calling apply import', async () => {
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
              status: 'previewed',
              mode: 'dry_run',
              source_checksum: 'pr14_16_connector_preview_proof_v1',
              row_count: 5,
              create_count: 5,
              update_count: 0,
              skip_count: 0,
              error_count: 0,
              violation_count: 0,
              validated_at: '2026-06-03T14:00:00.000Z',
              previewed_at: '2026-06-03T14:01:00.000Z',
              created_at: '2026-06-03T13:59:00.000Z',
              updated_at: '2026-06-03T14:01:00.000Z',
            },
          ],
        },
        'rpc:list_connector_import_preview_records': { data: [] },
      },
      capture,
    )

    const result = await requestConnectorApplyReview('user-1')

    expect(result).toMatchObject({
      connectionId: 'connection-1',
      batchId: 'batch-import-preview',
      status: 'review_requested',
      safeToApply: false,
    })
    expect(capture.rpcCalls?.some((call) => call.fn === 'apply_import_batch')).toBe(false)
    expect(capture.inserts).toContainEqual({
      table: 'erp_sync_batches',
      payload: expect.objectContaining({
        sync_type: 'import_apply_review',
        event_key: 'import_apply_review_requested',
        status: 'success',
        safe_error_code: null,
        safe_error_context: expect.objectContaining({
          mode: 'dry_run',
          source_namespace_code: 'CANIAS',
          row_count: 5,
          create_count: 5,
          update_count: 0,
          skip_count: 0,
          safe_to_apply: false,
          apply_execution_open: false,
          human_review_recorded: true,
        }),
        next_action_key: 'hold_for_apply_design',
      }),
    })
    expect(JSON.stringify(capture.inserts)).not.toContain('"raw_payload":')
    expect(JSON.stringify(capture.inserts)).not.toContain('credentials_ref')
    expect(JSON.stringify(capture.inserts)).not.toContain('provider_response')
  })

  it('generates connector apply change-set evidence without calling apply import', async () => {
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
              status: 'previewed',
              mode: 'dry_run',
              source_checksum: 'pr16_2_change_set_v1',
              row_count: 3,
              create_count: 2,
              update_count: 1,
              skip_count: 0,
              error_count: 0,
              violation_count: 0,
              validated_at: '2026-06-05T10:00:00.000Z',
              previewed_at: '2026-06-05T10:01:00.000Z',
              created_at: '2026-06-05T09:59:00.000Z',
              updated_at: '2026-06-05T10:01:00.000Z',
            },
          ],
        },
        'rpc:list_connector_import_preview_records': { data: [] },
        'rpc:create_connector_apply_change_set': {
          data: [
            {
              id: 'change-set-1',
              import_batch_id: 'batch-import-preview',
              status: 'blocked',
              source_checksum: 'pr16_2_change_set_v1',
              change_set_checksum: 'safe-change-set-hash',
              previewed_at: '2026-06-05T10:01:00.000Z',
              row_count: 3,
              create_count: 2,
              update_count: 1,
              skip_count: 0,
              blocked_count: 1,
              stale_count: 0,
              destructive_count: 0,
              source_conflict_count: 0,
              guarded_update_count: 1,
              no_change_count: 0,
              approval_required: true,
              sample_items: [],
              created_at: '2026-06-05T10:02:00.000Z',
            },
          ],
          error: null,
        },
      },
      capture,
    )

    const result = await requestConnectorApplyChangeSet('user-1')

    expect(result).toMatchObject({
      connectionId: 'connection-1',
      batchId: 'batch-import-preview',
      changeSetId: 'change-set-1',
      status: 'blocked',
      blockedCount: 1,
      safeToApply: false,
    })
    expect(capture.rpcCalls?.some((call) => call.fn === 'create_connector_apply_change_set')).toBe(
      true,
    )
    expect(capture.rpcCalls?.some((call) => call.fn === 'apply_import_batch')).toBe(false)
    expect(capture.inserts).toContainEqual({
      table: 'erp_sync_batches',
      payload: expect.objectContaining({
        sync_type: 'import_apply_review',
        event_key: 'import_apply_change_set_generated',
        status: 'partial_success',
        safe_error_code: 'apply_change_set_has_blockers',
        safe_error_context: expect.objectContaining({
          change_set_id: 'change-set-1',
          contract_version: 'pr16.2-apply-change-set-v1',
          source_namespace_code: 'CANIAS',
          source_checksum_available: true,
          row_count: 3,
          create_count: 2,
          update_count: 1,
          blocked_count: 1,
          guarded_update_count: 1,
          field_value_readback: false,
          raw_payload_readback: false,
          safe_to_apply: false,
          apply_execution_open: false,
          canonical_write_open: false,
        }),
        next_action_key: 'resolve_change_set_blockers',
      }),
    })
    expect(JSON.stringify(capture.inserts)).not.toContain('"raw_payload":')
    expect(JSON.stringify(capture.inserts)).not.toContain('normalized_payload')
    expect(JSON.stringify(capture.inserts)).not.toContain('credentials_ref')
    expect(JSON.stringify(capture.inserts)).not.toContain('provider_response')
  })

  it('generates guarded update evidence without queueing execution or exposing values', async () => {
    resolveTenant.mockResolvedValue(mockTenantContext())
    demoEnabled.mockReturnValue(false)
    const capture: ClientCapture = { inserts: [], rpcCalls: [] }
    setupSeededMocks(
      {
        import_batches: {
          data: [
            {
              id: 'batch-guarded-update',
              source_namespace_id: 'namespace-1',
              status: 'previewed',
              mode: 'dry_run',
              source_checksum: 'pr16_4_guarded_update_v1',
              row_count: 1,
              create_count: 0,
              update_count: 1,
              skip_count: 0,
              error_count: 0,
              violation_count: 0,
              validated_at: '2026-06-05T13:00:00.000Z',
              previewed_at: '2026-06-05T13:01:00.000Z',
              created_at: '2026-06-05T12:59:00.000Z',
              updated_at: '2026-06-05T13:01:00.000Z',
            },
          ],
        },
        'rpc:list_connector_import_preview_records': { data: [] },
        'rpc:list_connector_apply_change_set_summaries': {
          data: [
            {
              id: 'change-set-guarded-update',
              import_batch_id: 'batch-guarded-update',
              status: 'blocked',
              source_checksum: 'pr16_4_guarded_update_v1',
              change_set_checksum: 'safe-guarded-update-change-set-hash',
              previewed_at: '2026-06-05T13:01:00.000Z',
              row_count: 1,
              create_count: 0,
              update_count: 1,
              skip_count: 0,
              blocked_count: 0,
              stale_count: 0,
              destructive_count: 0,
              source_conflict_count: 0,
              guarded_update_count: 1,
              no_change_count: 0,
              approval_required: true,
              sample_items: [],
              created_at: '2026-06-05T13:02:00.000Z',
            },
          ],
        },
        'rpc:list_connector_guarded_update_evidence': { data: [] },
        'rpc:generate_connector_guarded_update_evidence': {
          data: [
            {
              change_set_id: 'change-set-guarded-update',
              tenant_id: 'a0000001-0001-4001-8001-000000000001',
              connection_id: 'connection-1',
              source_namespace_id: 'namespace-1',
              import_batch_id: 'batch-guarded-update',
              status: 'evidence_ready',
              guarded_update_count: 1,
              field_diff_count: 1,
              rollback_snapshot_count: 1,
              stale_blocked_count: 0,
              execution_enabled: false,
              canonical_write_enabled: false,
              source_writeback_enabled: false,
              credential_readback_enabled: false,
              value_readback_enabled: false,
              hot_retention_days: 90,
              next_action_key: 'review_guarded_update_evidence',
              sample_field_diffs: [
                {
                  id: 'field-diff-1',
                  row_number: 1,
                  entity_type: 'department',
                  external_id: 'DEPT-1',
                  target_table: 'departments',
                  field_name: 'name',
                  field_class: 'safe',
                  operation: 'set',
                  before_value_hash_available: true,
                  after_value_hash_available: true,
                  before_value_present: true,
                  after_value_present: true,
                  expected_current_hash_available: true,
                  current_hash_available: true,
                  stale_blocked: false,
                  rollback_snapshot_required: true,
                  retention_bucket: 'field_diff',
                  hot_retention_expires_at: '2026-09-03T13:02:00.000Z',
                },
              ],
              created_at: '2026-06-05T13:02:30.000Z',
            },
          ],
        },
      },
      capture,
    )

    const result = await requestConnectorGuardedUpdateEvidence('user-1')

    expect(result).toEqual({
      connectionId: 'connection-1',
      batchId: 'batch-guarded-update',
      changeSetId: 'change-set-guarded-update',
      status: 'evidence_ready',
      fieldDiffCount: 1,
      rollbackSnapshotCount: 1,
      safeToApply: false,
    })
    expect(capture.rpcCalls).toContainEqual({
      fn: 'generate_connector_guarded_update_evidence',
      args: { p_change_set_id: 'change-set-guarded-update' },
    })
    expect(capture.rpcCalls?.some((call) => call.fn === 'apply_import_batch')).toBe(false)
    expect(capture.rpcCalls?.some((call) => call.fn.includes('apply_job'))).toBe(false)
    expect(capture.inserts).toContainEqual({
      table: 'erp_sync_batches',
      payload: expect.objectContaining({
        sync_type: 'import_apply_review',
        event_key: 'import_apply_guarded_update_evidence_generated',
        status: 'success',
        safe_error_code: null,
        safe_error_context: expect.objectContaining({
          change_set_id: 'change-set-guarded-update',
          contract_version: 'pr16.4.1-guarded-update-evidence-v1',
          source_namespace_code: 'CANIAS',
          field_diff_count: 1,
          rollback_snapshot_count: 1,
          guarded_update_count: 1,
          stale_blocked_count: 0,
          hot_retention_days: 90,
          field_value_readback: false,
          raw_payload_readback: false,
          safe_to_apply: false,
          apply_execution_open: false,
          canonical_write_open: false,
          source_writeback_open: false,
          credential_readback_open: false,
        }),
        next_action_key: 'review_guarded_update_evidence',
      }),
    })
    expect(JSON.stringify(capture)).not.toContain('apply_import_batch')
    expect(JSON.stringify(capture)).not.toContain('credentials_ref')
    expect(JSON.stringify(capture)).not.toContain('snapshot_payload')
    expect(JSON.stringify(capture)).not.toContain('"raw_payload":')
    expect(JSON.stringify(capture)).not.toContain('provider_response')
  })

  it('records admin apply approval as audit without calling apply import', async () => {
    resolveTenant.mockResolvedValue(mockTenantContext())
    demoEnabled.mockReturnValue(false)
    const capture: ClientCapture = { inserts: [], rpcCalls: [] }
    setupSeededMocks(
      {
        erp_sync_batches: {
          data: [
            {
              id: 'review-event',
              created_at: '2026-06-03T14:02:00.000Z',
              status: 'success',
              sync_type: 'import_apply_review',
              event_key: 'import_apply_review_requested',
              actor_employee_id: 'a0000006-0006-4006-8006-000000000001',
              safe_error_code: null,
              safe_error_context: {
                safe_to_apply: false,
                apply_execution_open: false,
                human_review_recorded: true,
              },
              next_action_key: 'hold_for_apply_design',
              records_seen: 5,
              records_inserted: 5,
              records_updated: 0,
              records_failed: 0,
            },
          ],
        },
        import_batches: {
          data: [
            {
              id: 'batch-import-preview',
              source_namespace_id: 'namespace-1',
              status: 'previewed',
              mode: 'dry_run',
              source_checksum: 'pr14_16_connector_preview_proof_v1',
              row_count: 5,
              create_count: 5,
              update_count: 0,
              skip_count: 0,
              error_count: 0,
              violation_count: 0,
              validated_at: '2026-06-03T14:00:00.000Z',
              previewed_at: '2026-06-03T14:01:00.000Z',
              created_at: '2026-06-03T13:59:00.000Z',
              updated_at: '2026-06-03T14:01:00.000Z',
            },
          ],
        },
        'rpc:list_connector_import_preview_records': { data: [] },
      },
      capture,
    )

    const result = await recordConnectorApplyApproval('user-1')

    expect(result).toMatchObject({
      connectionId: 'connection-1',
      batchId: 'batch-import-preview',
      status: 'approval_recorded',
      safeToApply: false,
    })
    expect(capture.rpcCalls?.some((call) => call.fn === 'apply_import_batch')).toBe(false)
    expect(capture.inserts).toContainEqual({
      table: 'erp_sync_batches',
      payload: expect.objectContaining({
        sync_type: 'import_apply_review',
        event_key: 'import_apply_approval_recorded',
        status: 'success',
        safe_error_code: null,
        safe_error_context: expect.objectContaining({
          mode: 'dry_run',
          source_namespace_code: 'CANIAS',
          row_count: 5,
          create_count: 5,
          update_count: 0,
          skip_count: 0,
          approval_policy: 'admin_only',
          approval_recorded: true,
          approver_role: 'superadmin',
          safe_to_apply: false,
          apply_execution_open: false,
          canonical_write_open: false,
        }),
        next_action_key: 'hold_for_apply_execution_design',
      }),
    })
    expect(JSON.stringify(capture.inserts)).not.toContain('raw_payload')
    expect(JSON.stringify(capture.inserts)).not.toContain('credentials_ref')
    expect(JSON.stringify(capture.inserts)).not.toContain('provider_response')
  })

  it('records rollback approval against preview checksum without opening rollback execution', async () => {
    resolveTenant.mockResolvedValue(mockTenantContext())
    demoEnabled.mockReturnValue(false)
    const capture: ClientCapture = { inserts: [], rpcCalls: [] }
    setupSeededMocks(
      {
        import_batches: {
          data: [
            {
              id: 'batch-guarded-update-applied',
              source_namespace_id: 'namespace-1',
              status: 'applied',
              mode: 'dry_run',
              source_checksum: 'guarded-update-checksum',
              row_count: 1,
              create_count: 0,
              update_count: 1,
              skip_count: 0,
              error_count: 0,
              violation_count: 0,
              validated_at: '2026-06-05T13:00:00.000Z',
              previewed_at: '2026-06-05T13:01:00.000Z',
              applied_at: '2026-06-05T14:00:00.000Z',
              created_at: '2026-06-05T12:59:00.000Z',
              updated_at: '2026-06-05T14:00:00.000Z',
            },
          ],
        },
        'rpc:list_connector_import_preview_records': { data: [] },
        'rpc:list_connector_apply_change_set_summaries': {
          data: [
            {
              id: 'change-set-guarded-update-applied',
              import_batch_id: 'batch-guarded-update-applied',
              status: 'blocked',
              source_checksum: 'guarded-update-checksum',
              change_set_checksum: 'change-set-checksum',
              row_count: 1,
              create_count: 0,
              update_count: 1,
              skip_count: 0,
              blocked_count: 1,
              stale_count: 0,
              destructive_count: 0,
              source_conflict_count: 0,
              guarded_update_count: 1,
              no_change_count: 0,
              approval_required: true,
              created_at: '2026-06-05T13:02:00.000Z',
            },
          ],
          error: null,
        },
        'rpc:list_connector_guarded_update_rollback_previews': {
          data: [
            {
              rollback_preview_id: 'rollback-preview-1',
              change_set_id: 'change-set-guarded-update-applied',
              import_batch_id: 'batch-guarded-update-applied',
              status: 'ready_for_rollback_review',
              preview_kind: 'rollback',
              rollback_preview_checksum: 'safe-rollback-preview-hash',
              row_count: 1,
              rollback_count: 1,
              blocked_count: 0,
              stale_blocked_count: 0,
              field_diff_count: 1,
              rollback_snapshot_count: 1,
              rollback_preview_enabled: true,
              rollback_execution_enabled: false,
              compensating_execution_enabled: false,
              source_writeback_enabled: false,
              credential_readback_enabled: false,
              value_readback_enabled: false,
              approval_required: true,
              operator_review_required: true,
              next_action_key: 'review_rollback_preview_before_execution',
              sample_items: [],
              created_at: '2026-06-05T14:20:00.000Z',
            },
          ],
          error: null,
        },
        'rpc:list_connector_guarded_update_rollback_approvals': { data: [], error: null },
        'rpc:record_connector_guarded_update_rollback_approval': {
          data: [
            {
              rollback_approval_id: 'rollback-approval-1',
              rollback_preview_id: 'rollback-preview-1',
              change_set_id: 'change-set-guarded-update-applied',
              import_batch_id: 'batch-guarded-update-applied',
              approval_status: 'approval_recorded',
              approval_policy: 'admin_only',
              rollback_preview_checksum: 'safe-rollback-preview-hash',
              row_count: 1,
              rollback_count: 1,
              blocked_count: 0,
              stale_blocked_count: 0,
              field_diff_count: 1,
              rollback_snapshot_count: 1,
              rollback_approval_enabled: true,
              rollback_execution_enabled: false,
              compensating_execution_enabled: false,
              source_writeback_enabled: false,
              credential_readback_enabled: false,
              value_readback_enabled: false,
              approval_required: true,
              operator_review_required: true,
              next_action_key: 'prepare_guarded_update_rollback_worker_pr16_7',
              approved_by_employee_id: 'a0000006-0006-4006-8006-000000000001',
              approved_at: '2026-06-05T14:25:00.000Z',
            },
          ],
          error: null,
        },
      },
      capture,
    )

    const result = await recordConnectorGuardedUpdateRollbackApproval('user-1')

    expect(result).toEqual({
      connectionId: 'connection-1',
      batchId: 'batch-guarded-update-applied',
      changeSetId: 'change-set-guarded-update-applied',
      rollbackPreviewId: 'rollback-preview-1',
      rollbackApprovalId: 'rollback-approval-1',
      status: 'approval_recorded',
      approvedAt: '2026-06-05T14:25:00.000Z',
      nextActionKey: 'prepare_guarded_update_rollback_worker_pr16_7',
      safeToRollback: false,
    })
    expect(capture.rpcCalls).toContainEqual({
      fn: 'record_connector_guarded_update_rollback_approval',
      args: { p_rollback_preview_id: 'rollback-preview-1' },
    })
    expect(capture.inserts).toContainEqual({
      table: 'erp_sync_batches',
      payload: expect.objectContaining({
        sync_type: 'import_apply_review',
        event_key: 'import_apply_rollback_approval_recorded',
        status: 'success',
        safe_error_context: expect.objectContaining({
          contract_version: 'pr16.6-guarded-update-rollback-approval-v1',
          rollback_approval_id: 'rollback-approval-1',
          rollback_preview_id: 'rollback-preview-1',
          rollback_preview_checksum: 'safe-rollback-preview-hash',
          approval_recorded: true,
          safe_to_rollback: false,
          rollback_approval_enabled: true,
          rollback_execution_open: false,
          compensating_execution_open: false,
          source_writeback_open: false,
          credential_readback_open: false,
          field_value_readback: false,
          raw_payload_readback: false,
          snapshot_payload_readback: false,
        }),
        next_action_key: 'prepare_guarded_update_rollback_worker_pr16_7',
      }),
    })
    expect(capture.rpcCalls?.some((call) => call.fn.includes('rollback_job'))).toBe(false)
    expect(capture.rpcCalls?.some((call) => call.fn.includes('execute'))).toBe(false)
    expect(JSON.stringify(capture)).not.toContain('snapshot_payload"')
    expect(JSON.stringify(capture)).not.toContain('before_value')
    expect(JSON.stringify(capture)).not.toContain('after_value')
    expect(JSON.stringify(capture)).not.toContain('"raw_payload":')
    expect(JSON.stringify(capture)).not.toContain('credentials_ref')
  })

  it('requests rollback worker readiness without enqueueing rollback execution', async () => {
    resolveTenant.mockResolvedValue(mockTenantContext())
    demoEnabled.mockReturnValue(false)
    const capture: ClientCapture = { inserts: [], rpcCalls: [] }
    setupSeededMocks(
      {
        import_batches: {
          data: [
            {
              id: 'batch-guarded-update-applied',
              source_namespace_id: 'namespace-1',
              status: 'applied',
              mode: 'dry_run',
              source_checksum: 'guarded-update-checksum',
              row_count: 1,
              create_count: 0,
              update_count: 1,
              skip_count: 0,
              error_count: 0,
              violation_count: 0,
              validated_at: '2026-06-05T13:00:00.000Z',
              previewed_at: '2026-06-05T13:01:00.000Z',
              applied_at: '2026-06-05T14:00:00.000Z',
              created_at: '2026-06-05T12:59:00.000Z',
              updated_at: '2026-06-05T14:00:00.000Z',
            },
          ],
        },
        'rpc:list_connector_import_preview_records': { data: [] },
        'rpc:list_connector_apply_change_set_summaries': {
          data: [
            {
              id: 'change-set-guarded-update-applied',
              import_batch_id: 'batch-guarded-update-applied',
              status: 'blocked',
              source_checksum: 'guarded-update-checksum',
              change_set_checksum: 'change-set-checksum',
              row_count: 1,
              create_count: 0,
              update_count: 1,
              skip_count: 0,
              blocked_count: 1,
              stale_count: 0,
              destructive_count: 0,
              source_conflict_count: 0,
              guarded_update_count: 1,
              no_change_count: 0,
              approval_required: true,
              created_at: '2026-06-05T13:02:00.000Z',
            },
          ],
          error: null,
        },
        'rpc:list_connector_guarded_update_rollback_previews': {
          data: [
            {
              rollback_preview_id: 'rollback-preview-1',
              change_set_id: 'change-set-guarded-update-applied',
              import_batch_id: 'batch-guarded-update-applied',
              status: 'ready_for_rollback_review',
              preview_kind: 'rollback',
              rollback_preview_checksum: 'safe-rollback-preview-hash',
              row_count: 1,
              rollback_count: 1,
              blocked_count: 0,
              stale_blocked_count: 0,
              field_diff_count: 1,
              rollback_snapshot_count: 1,
              rollback_preview_enabled: true,
              rollback_execution_enabled: false,
              compensating_execution_enabled: false,
              source_writeback_enabled: false,
              credential_readback_enabled: false,
              value_readback_enabled: false,
              approval_required: true,
              operator_review_required: true,
              next_action_key: 'review_rollback_preview_before_execution',
              sample_items: [],
              created_at: '2026-06-05T14:20:00.000Z',
            },
          ],
          error: null,
        },
        'rpc:list_connector_guarded_update_rollback_approvals': {
          data: [
            {
              rollback_approval_id: 'rollback-approval-1',
              rollback_preview_id: 'rollback-preview-1',
              change_set_id: 'change-set-guarded-update-applied',
              import_batch_id: 'batch-guarded-update-applied',
              approval_status: 'approval_recorded',
              approval_policy: 'admin_only',
              rollback_preview_checksum: 'safe-rollback-preview-hash',
              row_count: 1,
              rollback_count: 1,
              blocked_count: 0,
              stale_blocked_count: 0,
              field_diff_count: 1,
              rollback_snapshot_count: 1,
              rollback_approval_enabled: true,
              rollback_execution_enabled: false,
              compensating_execution_enabled: false,
              source_writeback_enabled: false,
              credential_readback_enabled: false,
              value_readback_enabled: false,
              approval_required: true,
              operator_review_required: true,
              next_action_key: 'prepare_guarded_update_rollback_worker_pr16_7',
              approved_by_employee_id: 'a0000006-0006-4006-8006-000000000001',
              approved_at: '2026-06-05T14:25:00.000Z',
            },
          ],
          error: null,
        },
        'rpc:list_connector_guarded_update_rollback_worker_readiness': { data: [], error: null },
        'rpc:generate_connector_guarded_update_rollback_worker_readiness': {
          data: [
            {
              rollback_worker_readiness_id: 'rollback-worker-readiness-1',
              rollback_approval_id: 'rollback-approval-1',
              rollback_preview_id: 'rollback-preview-1',
              change_set_id: 'change-set-guarded-update-applied',
              import_batch_id: 'batch-guarded-update-applied',
              readiness_status: 'ready_for_worker_handoff',
              readiness_policy: 'approval_checksum_current_state_retention',
              worker_contract: 'pr16.7-rollback-worker-readiness-v1',
              expected_job_type: 'import_apply',
              expected_job_domain: 'import_apply_guarded_update_rollback',
              rollback_preview_checksum: 'safe-rollback-preview-hash',
              row_count: 1,
              rollback_count: 1,
              blocker_count: 0,
              stale_blocked_count: 0,
              drift_blocked_count: 0,
              expired_snapshot_count: 0,
              field_diff_count: 1,
              rollback_snapshot_count: 1,
              original_apply_event_count: 1,
              current_state_verified_count: 1,
              retention_verified_count: 1,
              approval_verified: true,
              approval_checksum_verified: true,
              worker_handoff_ready: true,
              rollback_job_enqueue_enabled: false,
              rollback_execution_enabled: false,
              canonical_write_enabled: false,
              compensating_execution_enabled: false,
              source_writeback_enabled: false,
              credential_readback_enabled: false,
              value_readback_enabled: false,
              provider_api_calls_enabled: false,
              approval_required: true,
              operator_review_required: true,
              next_action_key: 'implement_guarded_update_rollback_worker_pr16_8',
              sample_items: [],
              created_at: '2026-06-05T14:30:00.000Z',
            },
          ],
          error: null,
        },
      },
      capture,
    )

    const result = await requestConnectorGuardedUpdateRollbackWorkerReadiness('user-1')

    expect(result).toEqual({
      connectionId: 'connection-1',
      batchId: 'batch-guarded-update-applied',
      changeSetId: 'change-set-guarded-update-applied',
      rollbackPreviewId: 'rollback-preview-1',
      rollbackApprovalId: 'rollback-approval-1',
      rollbackWorkerReadinessId: 'rollback-worker-readiness-1',
      status: 'ready_for_worker_handoff',
      workerContract: 'pr16.7-rollback-worker-readiness-v1',
      expectedJobType: 'import_apply',
      expectedJobDomain: 'import_apply_guarded_update_rollback',
      nextActionKey: 'implement_guarded_update_rollback_worker_pr16_8',
      safeToRollback: false,
    })
    expect(capture.rpcCalls).toContainEqual({
      fn: 'generate_connector_guarded_update_rollback_worker_readiness',
      args: { p_rollback_approval_id: 'rollback-approval-1' },
    })
    expect(capture.inserts).toContainEqual({
      table: 'erp_sync_batches',
      payload: expect.objectContaining({
        sync_type: 'import_apply_review',
        event_key: 'import_apply_rollback_worker_readiness_generated',
        status: 'success',
        safe_error_context: expect.objectContaining({
          contract_version: 'pr16.7-guarded-update-rollback-worker-readiness-v1',
          worker_contract: 'pr16.7-rollback-worker-readiness-v1',
          rollback_worker_readiness_id: 'rollback-worker-readiness-1',
          rollback_approval_id: 'rollback-approval-1',
          rollback_preview_id: 'rollback-preview-1',
          rollback_preview_checksum: 'safe-rollback-preview-hash',
          worker_handoff_ready: true,
          safe_to_rollback: false,
          rollback_job_enqueue_open: false,
          rollback_execution_open: false,
          canonical_write_open: false,
          compensating_execution_open: false,
          source_writeback_open: false,
          credential_readback_open: false,
          provider_api_calls: false,
          field_value_readback: false,
          raw_payload_readback: false,
          snapshot_payload_readback: false,
        }),
        next_action_key: 'implement_guarded_update_rollback_worker_pr16_8',
      }),
    })
    expect(capture.rpcCalls?.some((call) => call.fn.includes('enqueue'))).toBe(false)
    expect(capture.rpcCalls?.some((call) => call.fn.includes('execute'))).toBe(false)
    expect(JSON.stringify(capture)).not.toContain('snapshot_payload"')
    expect(JSON.stringify(capture)).not.toContain('before_value')
    expect(JSON.stringify(capture)).not.toContain('after_value')
    expect(JSON.stringify(capture)).not.toContain('"raw_payload":')
    expect(JSON.stringify(capture)).not.toContain('credentials_ref')
  })

  it('queues guarded update rollback apply only after worker readiness handoff is ready', async () => {
    resolveTenant.mockResolvedValue(mockTenantContext())
    demoEnabled.mockReturnValue(false)
    const capture: ClientCapture = { inserts: [], rpcCalls: [] }
    setupSeededMocks(
      {
        import_batches: {
          data: [
            {
              id: 'batch-guarded-update-applied',
              source_namespace_id: 'namespace-1',
              status: 'applied',
              mode: 'dry_run',
              source_checksum: 'guarded-update-checksum',
              row_count: 1,
              create_count: 0,
              update_count: 1,
              skip_count: 0,
              error_count: 0,
              violation_count: 0,
              validated_at: '2026-06-05T13:00:00.000Z',
              previewed_at: '2026-06-05T13:01:00.000Z',
              applied_at: '2026-06-05T14:00:00.000Z',
              created_at: '2026-06-05T12:59:00.000Z',
              updated_at: '2026-06-05T14:00:00.000Z',
            },
          ],
        },
        'rpc:list_connector_import_preview_records': { data: [] },
        'rpc:list_connector_apply_change_set_summaries': {
          data: [
            {
              id: 'change-set-guarded-update-applied',
              import_batch_id: 'batch-guarded-update-applied',
              status: 'blocked',
              source_checksum: 'guarded-update-checksum',
              change_set_checksum: 'change-set-checksum',
              row_count: 1,
              create_count: 0,
              update_count: 1,
              skip_count: 0,
              blocked_count: 1,
              stale_count: 0,
              destructive_count: 0,
              source_conflict_count: 0,
              guarded_update_count: 1,
              no_change_count: 0,
              approval_required: true,
              created_at: '2026-06-05T13:02:00.000Z',
            },
          ],
          error: null,
        },
        'rpc:list_connector_guarded_update_rollback_previews': {
          data: [
            {
              rollback_preview_id: 'rollback-preview-1',
              change_set_id: 'change-set-guarded-update-applied',
              import_batch_id: 'batch-guarded-update-applied',
              status: 'ready_for_rollback_review',
              preview_kind: 'rollback',
              rollback_preview_checksum: 'safe-rollback-preview-hash',
              row_count: 1,
              rollback_count: 1,
              blocked_count: 0,
              stale_blocked_count: 0,
              field_diff_count: 1,
              rollback_snapshot_count: 1,
              rollback_preview_enabled: true,
              rollback_execution_enabled: false,
              compensating_execution_enabled: false,
              source_writeback_enabled: false,
              credential_readback_enabled: false,
              value_readback_enabled: false,
              approval_required: true,
              operator_review_required: true,
              next_action_key: 'review_rollback_preview_before_execution',
              sample_items: [],
              created_at: '2026-06-05T14:20:00.000Z',
            },
          ],
          error: null,
        },
        'rpc:list_connector_guarded_update_rollback_approvals': {
          data: [
            {
              rollback_approval_id: 'rollback-approval-1',
              rollback_preview_id: 'rollback-preview-1',
              change_set_id: 'change-set-guarded-update-applied',
              import_batch_id: 'batch-guarded-update-applied',
              approval_status: 'approval_recorded',
              approval_policy: 'admin_only',
              rollback_preview_checksum: 'safe-rollback-preview-hash',
              row_count: 1,
              rollback_count: 1,
              blocked_count: 0,
              stale_blocked_count: 0,
              field_diff_count: 1,
              rollback_snapshot_count: 1,
              rollback_approval_enabled: true,
              rollback_execution_enabled: false,
              compensating_execution_enabled: false,
              source_writeback_enabled: false,
              credential_readback_enabled: false,
              value_readback_enabled: false,
              approval_required: true,
              operator_review_required: true,
              next_action_key: 'prepare_guarded_update_rollback_worker_pr16_7',
              approved_by_employee_id: 'a0000006-0006-4006-8006-000000000001',
              approved_at: '2026-06-05T14:25:00.000Z',
            },
          ],
          error: null,
        },
        'rpc:list_connector_guarded_update_rollback_worker_readiness': {
          data: [
            {
              rollback_worker_readiness_id: 'rollback-worker-readiness-1',
              rollback_approval_id: 'rollback-approval-1',
              rollback_preview_id: 'rollback-preview-1',
              change_set_id: 'change-set-guarded-update-applied',
              import_batch_id: 'batch-guarded-update-applied',
              readiness_status: 'ready_for_worker_handoff',
              readiness_policy: 'approval_checksum_current_state_retention',
              worker_contract: 'pr16.7-rollback-worker-readiness-v1',
              expected_job_type: 'import_apply',
              expected_job_domain: 'import_apply_guarded_update_rollback',
              rollback_preview_checksum: 'safe-rollback-preview-hash',
              row_count: 1,
              rollback_count: 1,
              blocker_count: 0,
              stale_blocked_count: 0,
              drift_blocked_count: 0,
              expired_snapshot_count: 0,
              field_diff_count: 1,
              rollback_snapshot_count: 1,
              original_apply_event_count: 1,
              current_state_verified_count: 1,
              retention_verified_count: 1,
              approval_verified: true,
              approval_checksum_verified: true,
              worker_handoff_ready: true,
              rollback_job_enqueue_enabled: false,
              rollback_execution_enabled: false,
              canonical_write_enabled: false,
              compensating_execution_enabled: false,
              source_writeback_enabled: false,
              credential_readback_enabled: false,
              value_readback_enabled: false,
              provider_api_calls_enabled: false,
              approval_required: true,
              operator_review_required: true,
              next_action_key: 'implement_guarded_update_rollback_worker_pr16_8',
              sample_items: [],
              created_at: '2026-06-05T14:30:00.000Z',
            },
          ],
          error: null,
        },
        'rpc:enqueue_connector_guarded_update_rollback_apply_job': {
          data: [
            {
              job_id: 'rollback-job-1',
              status: 'queued',
              rollback_worker_readiness_id: 'rollback-worker-readiness-1',
              rollback_approval_id: 'rollback-approval-1',
              rollback_preview_id: 'rollback-preview-1',
              change_set_id: 'change-set-guarded-update-applied',
              import_batch_id: 'batch-guarded-update-applied',
              rollback_count: 1,
              field_diff_count: 1,
              rollback_snapshot_count: 1,
              next_action_key: 'wait_for_guarded_update_rollback_worker_apply',
            },
          ],
          error: null,
        },
      },
      capture,
    )

    const result = await requestConnectorGuardedUpdateRollbackApplyJob('user-1')

    expect(result).toEqual({
      connectionId: 'connection-1',
      batchId: 'batch-guarded-update-applied',
      changeSetId: 'change-set-guarded-update-applied',
      rollbackPreviewId: 'rollback-preview-1',
      rollbackApprovalId: 'rollback-approval-1',
      rollbackWorkerReadinessId: 'rollback-worker-readiness-1',
      jobId: 'rollback-job-1',
      status: 'queued',
      nextActionKey: 'wait_for_guarded_update_rollback_worker_apply',
      safeToRollback: false,
    })
    expect(capture.rpcCalls).toContainEqual({
      fn: 'enqueue_connector_guarded_update_rollback_apply_job',
      args: { p_rollback_worker_readiness_id: 'rollback-worker-readiness-1' },
    })
    expect(capture.rpcCalls?.some((call) => call.fn.includes('execute'))).toBe(false)
    expect(capture.inserts).toContainEqual({
      table: 'erp_sync_batches',
      payload: expect.objectContaining({
        sync_type: 'import_apply_review',
        event_key: 'import_apply_guarded_update_rollback_queued',
        status: 'pending',
        safe_error_context: expect.objectContaining({
          job_id: 'rollback-job-1',
          contract_version: 'pr16.8-guarded-update-rollback-worker-apply-v1',
          rollback_worker_readiness_id: 'rollback-worker-readiness-1',
          rollback_approval_id: 'rollback-approval-1',
          rollback_preview_id: 'rollback-preview-1',
          rollback_preview_checksum: 'safe-rollback-preview-hash',
          worker_queue: true,
          safe_to_rollback: false,
          rollback_job_enqueue_open: true,
          rollback_execution_open: true,
          canonical_write_open: true,
          browser_direct_apply_open: false,
          authenticated_apply_rpc_open: false,
          compensating_execution_open: false,
          source_writeback_open: false,
          credential_readback_open: false,
          provider_api_calls: false,
          field_value_readback: false,
          raw_payload_readback: false,
          snapshot_payload_readback: false,
        }),
        next_action_key: 'wait_for_guarded_update_rollback_worker_apply',
      }),
    })
    expect(JSON.stringify(capture)).not.toContain('apply_import_batch')
    expect(JSON.stringify(capture)).not.toContain('credentials_ref')
    expect(JSON.stringify(capture)).not.toContain('"raw_payload":')
    expect(JSON.stringify(capture)).not.toContain('"snapshot_payload":')
    expect(JSON.stringify(capture)).not.toContain('provider_response')
  })

  it('rejects connector apply approval before review is recorded', async () => {
    resolveTenant.mockResolvedValue(mockTenantContext())
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
            row_count: 5,
            create_count: 5,
            update_count: 0,
            skip_count: 0,
            error_count: 0,
            violation_count: 0,
            validated_at: '2026-06-03T14:00:00.000Z',
            previewed_at: '2026-06-03T14:01:00.000Z',
            created_at: '2026-06-03T13:59:00.000Z',
            updated_at: '2026-06-03T14:01:00.000Z',
          },
        ],
      },
      'rpc:list_connector_import_preview_records': { data: [] },
    })

    await expect(recordConnectorApplyApproval('user-1')).rejects.toMatchObject({
      code: 'PULS_CONNECTOR_APPLY_APPROVAL_BLOCKED',
      i18nKey: 'erp.errors.applyApprovalBlocked',
    })
  })

  it('rejects connector apply review when persona is not admin scoped', async () => {
    resolveTenant.mockResolvedValue({
      ...mockTenantContext(),
      personaRole: 'employee',
    })

    await expect(requestConnectorApplyReview('user-1')).rejects.toMatchObject({
      code: 'PULS_CONNECTOR_ADMIN_REQUIRED',
      i18nKey: 'erp.errors.adminRequired',
    })
  })

  it('rejects connector apply approval when persona is not admin scoped', async () => {
    resolveTenant.mockResolvedValue({
      ...mockTenantContext(),
      personaRole: 'employee',
    })

    await expect(recordConnectorApplyApproval('user-1')).rejects.toMatchObject({
      code: 'PULS_CONNECTOR_ADMIN_REQUIRED',
      i18nKey: 'erp.errors.adminRequired',
    })
  })

  it('rejects guarded update evidence when persona is not admin scoped', async () => {
    resolveTenant.mockResolvedValue({
      ...mockTenantContext(),
      personaRole: 'employee',
    })

    await expect(requestConnectorGuardedUpdateEvidence('user-1')).rejects.toMatchObject({
      code: 'PULS_CONNECTOR_ADMIN_REQUIRED',
      i18nKey: 'erp.errors.adminRequired',
    })
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

    expect(
      mapConnectorSetupError(
        new DataAdapterError({
          code: 'PULS_CONNECTOR_APPLY_REVIEW_BLOCKED',
          message: 'Connector apply review is blocked until preview is ready',
          source: 'adapter',
          operation: 'requestConnectorApplyReview',
        }),
      ),
    ).toEqual({ code: 'apply_review_blocked', toastKey: 'erp.errors.applyReviewBlocked' })

    expect(
      mapConnectorSetupError(
        new DataAdapterError({
          code: 'PULS_CONNECTOR_APPLY_APPROVAL_BLOCKED',
          message: 'Connector apply approval is blocked until review is recorded',
          source: 'adapter',
          operation: 'recordConnectorApplyApproval',
        }),
      ),
    ).toEqual({
      code: 'apply_approval_blocked',
      toastKey: 'erp.errors.applyApprovalBlocked',
    })

    expect(
      mapConnectorSetupError(
        new DataAdapterError({
          code: 'PULS_CONNECTOR_APPLY_CHANGE_SET_PREVIEW_REQUIRED',
          message: 'Connector apply change-set requires preview',
          source: 'adapter',
          operation: 'requestConnectorApplyChangeSet',
        }),
      ),
    ).toEqual({
      code: 'apply_change_set_blocked',
      toastKey: 'erp.errors.applyChangeSetBlocked',
    })

    expect(
      mapConnectorSetupError(
        new DataAdapterError({
          code: 'PULS_CONNECTOR_CREATE_ONLY_TARGET_EXISTS',
          message: 'Connector create-only apply target already exists',
          source: 'adapter',
          operation: 'requestConnectorCreateOnlyApplyJob',
        }),
      ),
    ).toEqual({
      code: 'create_only_apply_blocked',
      toastKey: 'erp.errors.createOnlyApplyBlocked',
    })

    expect(
      mapConnectorSetupError(
        new DataAdapterError({
          code: 'PULS_CONNECTOR_RUNTIME_PREFLIGHT_CREDENTIAL_NOT_VERIFIED',
          message: 'Runtime preflight requires verified credential state',
          source: 'adapter',
          operation: 'requestConnectorRuntimePreflight',
        }),
      ),
    ).toEqual({
      code: 'runtime_preflight_blocked',
      toastKey: 'erp.errors.runtimePreflightBlocked',
    })

    expect(mapConnectorSetupError(new Error('raw db failure'))).toEqual({
      code: 'save_failed',
      toastKey: 'erp.errors.setupSaveFailed',
    })
  })
})
