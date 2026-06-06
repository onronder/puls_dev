import { afterEach, describe, expect, it, vi } from 'vitest'

import {
  buildSafeWorkerFailureObservation,
  callSupabaseRpc,
  buildConnectorJobCompletion,
  buildCreateOnlyApplyCompletionFromResult,
  buildCreateOnlyApplyFailureCompletion,
  buildGuardedUpdateApplyCompletionFromResult,
  buildGuardedUpdateApplyFailureCompletion,
  buildGuardedUpdateRollbackApplyCompletionFromResult,
  buildGuardedUpdateRollbackApplyFailureCompletion,
  buildHealthPayload,
  buildRuntimePreflightCompletionFromContext,
  ConnectorWorkerRpcError,
  parseSupportedJobTypes,
  resolveWorkerConfig,
  runWorkerOnce,
  type ClaimedConnectorJob,
} from './worker.ts'

afterEach(() => {
  vi.unstubAllGlobals()
})

function noopJob(overrides: Partial<ClaimedConnectorJob> = {}): ClaimedConnectorJob {
  return {
    id: 'job-1',
    job_type: 'noop_health',
    status: 'running',
    attempt_count: 1,
    max_attempts: 3,
    domain: 'runtime',
    ...overrides,
  }
}

describe('erp-connector worker config', () => {
  it('defaults to a disabled safe health-only posture', () => {
    const config = resolveWorkerConfig({})
    const health = buildHealthPayload(config)

    expect(config.enabled).toBe(false)
    expect(config.configured).toBe(false)
    expect(config.supportedJobTypes).toEqual(['noop_health'])
    expect(health).toMatchObject({
      service: 'erp-connector',
      runtime: 'worker-skeleton',
      boundaries: {
        providerApiCalls: false,
        credentialReadback: false,
        canonicalWrites: false,
        sourceWriteback: false,
      },
    })
  })

  it('does not expose service-role keys in health payloads', () => {
    const config = resolveWorkerConfig({
      PULS_SUPABASE_URL: 'https://example.supabase.co/',
      PULS_SUPABASE_SERVICE_ROLE_KEY: 'service-role-secret-value',
      PULS_CONNECTOR_WORKER_ENABLED: 'true',
      PULS_CONNECTOR_WORKER_JOB_TYPES: 'noop_health,import_apply,unknown',
    })

    const serialized = JSON.stringify(buildHealthPayload(config))

    expect(config.configured).toBe(true)
    expect(config.supportedJobTypes).toEqual(['noop_health'])
    expect(serialized).not.toContain('service-role-secret-value')
    expect(serialized).not.toContain('SERVICE_ROLE')
  })

  it('calls Supabase RPC endpoints through the puls_integration schema profile', async () => {
    const config = resolveWorkerConfig({
      PULS_SUPABASE_URL: 'https://example.supabase.co/',
      PULS_SUPABASE_SERVICE_ROLE_KEY: 'service-role-secret-value',
      PULS_CONNECTOR_WORKER_ENABLED: 'true',
    })
    const fetchMock = vi.fn(
      async (_url: Parameters<typeof fetch>[0], _init?: Parameters<typeof fetch>[1]) => {
        return new Response(JSON.stringify({ ok: true }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        })
      },
    )
    vi.stubGlobal('fetch', fetchMock)

    await expect(
      callSupabaseRpc(config, 'upsert_connector_worker_heartbeat', {
        p_worker_id: 'worker-a',
      }),
    ).resolves.toEqual({ ok: true })

    expect(fetchMock).toHaveBeenCalledTimes(1)
    const firstCall = fetchMock.mock.calls[0]
    if (!firstCall) throw new Error('expected Supabase RPC fetch call')
    const [url, init] = firstCall
    if (!init) throw new Error('expected Supabase RPC fetch options')
    const headers = init.headers as Record<string, string>

    expect(String(url)).toBe('https://example.supabase.co/rest/v1/rpc/upsert_connector_worker_heartbeat')
    expect(init.method).toBe('POST')
    expect(headers.apikey).toBe('service-role-secret-value')
    expect(headers.Authorization).toBe('Bearer service-role-secret-value')
    expect(headers['Accept-Profile']).toBe('puls_integration')
    expect(headers['Content-Profile']).toBe('puls_integration')
    expect(headers['Content-Type']).toBe('application/json')
    expect(init.body).toBe(JSON.stringify({ p_worker_id: 'worker-a' }))
  })

  it('falls back to noop_health when job type config is empty or invalid', () => {
    expect(parseSupportedJobTypes('')).toEqual(['noop_health'])
    expect(parseSupportedJobTypes('unknown,still_unknown')).toEqual(['noop_health'])
  })

  it('keeps Railway non-production worker loops disabled unless explicitly allowed', () => {
    const config = resolveWorkerConfig({
      RAILWAY_ENVIRONMENT_NAME: 'preview',
      PULS_SUPABASE_URL: 'https://example.supabase.co/',
      PULS_SUPABASE_SERVICE_ROLE_KEY: 'service-role-secret-value',
      PULS_CONNECTOR_WORKER_ENABLED: 'true',
    })
    const allowedConfig = resolveWorkerConfig({
      RAILWAY_ENVIRONMENT_NAME: 'preview',
      PULS_CONNECTOR_WORKER_ALLOW_NON_PRODUCTION: 'true',
      PULS_SUPABASE_URL: 'https://example.supabase.co/',
      PULS_SUPABASE_SERVICE_ROLE_KEY: 'service-role-secret-value',
      PULS_CONNECTOR_WORKER_ENABLED: 'true',
    })

    expect(config.configured).toBe(true)
    expect(config.enabled).toBe(false)
    expect(config.railwayEnvironmentName).toBe('preview')
    expect(config.nonProductionWorkerAllowed).toBe(false)
    expect(allowedConfig.enabled).toBe(true)
    expect(allowedConfig.nonProductionWorkerAllowed).toBe(true)
  })

  it('requires an explicit PR16 gate before claiming import_apply jobs', () => {
    expect(parseSupportedJobTypes('import_apply,noop_health')).toEqual(['noop_health'])
    expect(
      parseSupportedJobTypes('import_apply', {
        importApplyEnabled: true,
      }),
    ).toEqual(['import_apply'])

    const config = resolveWorkerConfig({
      PULS_CONNECTOR_WORKER_IMPORT_APPLY_ENABLED: 'true',
      PULS_CONNECTOR_WORKER_JOB_TYPES: 'import_apply,noop_health',
    })
    const health = buildHealthPayload(config)

    expect(config.importApplyEnabled).toBe(true)
    expect(config.supportedJobTypes).toEqual(['import_apply', 'noop_health'])
    expect(health.worker.importApplyEnabled).toBe(true)
    expect(health.boundaries.canonicalWrites).toBe(true)
    expect(health.boundaries.providerApiCalls).toBe(false)
    expect(health.boundaries.credentialReadback).toBe(false)
    expect(health.boundaries.sourceWriteback).toBe(false)
  })

  it('normalizes safe PULS SQL error messages for worker completion', async () => {
    const config = resolveWorkerConfig({
      PULS_SUPABASE_URL: 'https://example.supabase.co/',
      PULS_SUPABASE_SERVICE_ROLE_KEY: 'service-role-secret-value',
      PULS_CONNECTOR_WORKER_ENABLED: 'true',
    })
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => {
        return new Response(
          JSON.stringify({
            code: 'P0001',
            message:
              'PULS_CONNECTOR_CREATE_ONLY_APPROVAL_REQUIRED: admin approval is required before enqueue.',
          }),
          {
            status: 400,
            headers: { 'Content-Type': 'application/json' },
          },
        )
      }),
    )

    await expect(callSupabaseRpc(config, 'execute_connector_create_only_apply_job', {})).rejects
      .toMatchObject({
        code: 'puls_connector_create_only_approval_required',
      })
  })
})

describe('erp-connector worker job handling', () => {
  it('completes noop health jobs with safe context only', async () => {
    const config = resolveWorkerConfig({
      PULS_SUPABASE_URL: 'https://example.supabase.co',
      PULS_SUPABASE_SERVICE_ROLE_KEY: 'service-role-secret-value',
      PULS_CONNECTOR_WORKER_ENABLED: 'true',
      PULS_CONNECTOR_WORKER_ID: 'worker-a',
    })
    const calls: Array<{ fn: string; args: Record<string, unknown> }> = []
    const rpc = async <T>(fn: string, args: Record<string, unknown>): Promise<T> => {
      calls.push({ fn, args })
      if (fn === 'claim_next_connector_job') return [noopJob()] as T
      if (fn === 'complete_connector_job') return 'job-1' as T
      if (fn === 'upsert_connector_worker_heartbeat') return 'worker-a' as T
      if (fn === 'heartbeat_connector_job') return 'job-1' as T
      return [] as T
    }

    const result = await runWorkerOnce(config, rpc)

    expect(result).toEqual({ claimed: true, jobId: 'job-1', status: 'succeeded' })
    expect(calls.find((call) => call.fn === 'claim_next_connector_job')?.args).toMatchObject({
      p_worker_id: 'worker-a',
      p_job_types: ['noop_health'],
    })
    const completeCall = calls.find((call) => call.fn === 'complete_connector_job')
    expect(completeCall?.args).toMatchObject({
      p_job_id: 'job-1',
      p_worker_id: 'worker-a',
      p_status: 'succeeded',
      p_safe_error_code: null,
      p_next_action_key: 'worker_contract_ready',
    })

    const serialized = JSON.stringify(calls)
    expect(serialized).toContain('"external_call":false')
    expect(serialized).not.toContain('service-role-secret-value')
    expect(serialized).not.toContain('credentials_ref')
    expect(serialized).not.toContain('raw_payload')
  })

  it('does not claim jobs when worker runtime is disabled or unconfigured', async () => {
    let callCount = 0
    const rpc = async <T>(): Promise<T> => {
      callCount += 1
      return [] as T
    }

    const result = await runWorkerOnce(resolveWorkerConfig({}), rpc)

    expect(result).toEqual({ claimed: false, reason: 'worker_disabled_or_unconfigured' })
    expect(callCount).toBe(0)
  })

  it('marks explicitly claimed unsupported job types as unsupported instead of pretending runtime exists', () => {
    expect(buildConnectorJobCompletion(noopJob({ job_type: 'import_apply' }))).toMatchObject({
      p_status: 'failed',
      p_safe_error_code: 'connector_job_type_not_supported_by_worker_skeleton',
      p_safe_error_context: expect.objectContaining({
        failure_class: 'unsupported',
        operator_severity: 'error',
        operator_review_required: true,
        retry_after_seconds: 0,
      }),
      p_next_action_key: 'wait_for_provider_runtime_implementation',
    })
  })

  it('executes import_apply only through the PR16 create-only worker RPC when explicitly enabled', async () => {
    const config = resolveWorkerConfig({
      PULS_SUPABASE_URL: 'https://example.supabase.co',
      PULS_SUPABASE_SERVICE_ROLE_KEY: 'service-role-secret-value',
      PULS_CONNECTOR_WORKER_ENABLED: 'true',
      PULS_CONNECTOR_WORKER_IMPORT_APPLY_ENABLED: 'true',
      PULS_CONNECTOR_WORKER_JOB_TYPES: 'import_apply',
      PULS_CONNECTOR_WORKER_ID: 'worker-a',
    })
    const calls: Array<{ fn: string; args: Record<string, unknown> }> = []
    const rpc = async <T>(fn: string, args: Record<string, unknown>): Promise<T> => {
      calls.push({ fn, args })
      if (fn === 'claim_next_connector_job') {
        return [
          noopJob({
            id: 'apply-job-1',
            job_type: 'import_apply',
          }),
        ] as T
      }
      if (fn === 'execute_connector_create_only_apply_job') {
        return [
          {
            change_set_id: 'change-set-1',
            import_batch_id: 'batch-1',
            status: 'applied_create_only',
            row_count: 2,
            create_count: 2,
            object_event_count: 2,
            execution_enabled: true,
            canonical_write_enabled: true,
            source_writeback_enabled: false,
            credential_readback_enabled: false,
            next_action_key: 'review_created_canonical_records',
          },
        ] as T
      }
      if (fn === 'complete_connector_job') return 'apply-job-1' as T
      if (fn === 'upsert_connector_worker_heartbeat') return 'worker-a' as T
      if (fn === 'heartbeat_connector_job') return 'apply-job-1' as T
      return [] as T
    }

    const result = await runWorkerOnce(config, rpc)

    expect(result).toEqual({ claimed: true, jobId: 'apply-job-1', status: 'succeeded' })
    expect(calls.find((call) => call.fn === 'claim_next_connector_job')?.args).toMatchObject({
      p_job_types: ['import_apply'],
    })
    expect(
      calls.find((call) => call.fn === 'execute_connector_create_only_apply_job')?.args,
    ).toMatchObject({
      p_job_id: 'apply-job-1',
      p_worker_id: 'worker-a',
    })
    expect(calls.find((call) => call.fn === 'heartbeat_connector_job')?.args).toMatchObject({
      p_job_id: 'apply-job-1',
      p_worker_id: 'worker-a',
      p_safe_context: {},
    })
    expect(calls.find((call) => call.fn === 'complete_connector_job')?.args).toMatchObject({
      p_job_id: 'apply-job-1',
      p_status: 'succeeded',
      p_safe_error_code: null,
      p_next_action_key: 'review_created_canonical_records',
      p_safe_error_context: expect.objectContaining({
        apply_contract: 'pr16.3-create-only-worker-apply-v1',
        apply_mode: 'create_only',
        canonical_write: true,
        source_writeback: false,
        credential_readback: false,
        external_call: false,
      }),
    })

    const serialized = JSON.stringify(calls)
    expect(serialized).not.toContain('apply_import_batch')
    expect(serialized).not.toContain('service-role-secret-value')
    expect(serialized).not.toContain('"raw_payload":')
    expect(serialized).not.toContain('provider_response')
  })

  it('does not overwrite queued job safe context during lease heartbeat', async () => {
    const config = resolveWorkerConfig({
      PULS_SUPABASE_URL: 'https://example.supabase.co',
      PULS_SUPABASE_SERVICE_ROLE_KEY: 'service-role-secret-value',
      PULS_CONNECTOR_WORKER_ENABLED: 'true',
      PULS_CONNECTOR_WORKER_IMPORT_APPLY_ENABLED: 'true',
      PULS_CONNECTOR_WORKER_JOB_TYPES: 'import_apply',
      PULS_CONNECTOR_WORKER_ID: 'worker-a',
    })
    const calls: Array<{ fn: string; args: Record<string, unknown> }> = []
    const rpc = async <T>(fn: string, args: Record<string, unknown>): Promise<T> => {
      calls.push({ fn, args })
      if (fn === 'claim_next_connector_job') {
        return [
          noopJob({
            id: 'apply-job-1',
            job_type: 'import_apply',
          }),
        ] as T
      }
      if (fn === 'execute_connector_create_only_apply_job') return [] as T
      if (fn === 'complete_connector_job') return 'apply-job-1' as T
      if (fn === 'upsert_connector_worker_heartbeat') return 'worker-a' as T
      if (fn === 'heartbeat_connector_job') return 'apply-job-1' as T
      return [] as T
    }

    await runWorkerOnce(config, rpc)

    expect(calls.find((call) => call.fn === 'heartbeat_connector_job')?.args).toMatchObject({
      p_safe_context: {},
    })
  })

  it('routes guarded update import_apply jobs through the PR16.4.2 worker RPC', async () => {
    const config = resolveWorkerConfig({
      PULS_SUPABASE_URL: 'https://example.supabase.co',
      PULS_SUPABASE_SERVICE_ROLE_KEY: 'service-role-secret-value',
      PULS_CONNECTOR_WORKER_ENABLED: 'true',
      PULS_CONNECTOR_WORKER_IMPORT_APPLY_ENABLED: 'true',
      PULS_CONNECTOR_WORKER_JOB_TYPES: 'import_apply',
      PULS_CONNECTOR_WORKER_ID: 'worker-a',
    })
    const calls: Array<{ fn: string; args: Record<string, unknown> }> = []
    const rpc = async <T>(fn: string, args: Record<string, unknown>): Promise<T> => {
      calls.push({ fn, args })
      if (fn === 'claim_next_connector_job') {
        return [
          noopJob({
            id: 'guarded-job-1',
            job_type: 'import_apply',
            domain: 'import_apply_guarded_update',
            safe_error_context: {
              contract_version: 'pr16.4.2-guarded-update-worker-apply-v1',
              apply_mode: 'guarded_update',
            },
          }),
        ] as T
      }
      if (fn === 'execute_connector_guarded_update_apply_job') {
        return [
          {
            change_set_id: 'change-set-1',
            import_batch_id: 'batch-1',
            status: 'applied_guarded_update',
            row_count: 1,
            update_count: 1,
            field_diff_count: 1,
            rollback_snapshot_count: 1,
            object_event_count: 1,
            execution_enabled: true,
            canonical_write_enabled: true,
            source_writeback_enabled: false,
            credential_readback_enabled: false,
            next_action_key: 'review_guarded_update_object_events',
          },
        ] as T
      }
      if (fn === 'complete_connector_job') return 'guarded-job-1' as T
      if (fn === 'upsert_connector_worker_heartbeat') return 'worker-a' as T
      if (fn === 'heartbeat_connector_job') return 'guarded-job-1' as T
      return [] as T
    }

    const result = await runWorkerOnce(config, rpc)

    expect(result).toEqual({ claimed: true, jobId: 'guarded-job-1', status: 'succeeded' })
    expect(calls.some((call) => call.fn === 'execute_connector_create_only_apply_job')).toBe(false)
    expect(
      calls.find((call) => call.fn === 'execute_connector_guarded_update_apply_job')?.args,
    ).toMatchObject({
      p_job_id: 'guarded-job-1',
      p_worker_id: 'worker-a',
    })
    expect(calls.find((call) => call.fn === 'complete_connector_job')?.args).toMatchObject({
      p_job_id: 'guarded-job-1',
      p_status: 'succeeded',
      p_safe_error_code: null,
      p_next_action_key: 'review_guarded_update_object_events',
      p_safe_error_context: expect.objectContaining({
        apply_contract: 'pr16.4.2-guarded-update-worker-apply-v1',
        apply_mode: 'guarded_update',
        update_count: 1,
        field_diff_count: 1,
        rollback_snapshot_count: 1,
        canonical_write: true,
        source_writeback: false,
        credential_readback: false,
        raw_payload_readback: false,
        field_value_readback: false,
      }),
    })

    const serialized = JSON.stringify(calls)
    expect(serialized).not.toContain('service-role-secret-value')
    expect(serialized).not.toContain('"raw_payload":')
    expect(serialized).not.toContain('provider_response')
  })

  it('routes guarded update rollback import_apply jobs through the PR16.8 worker RPC', async () => {
    const config = resolveWorkerConfig({
      PULS_SUPABASE_URL: 'https://example.supabase.co',
      PULS_SUPABASE_SERVICE_ROLE_KEY: 'service-role-secret-value',
      PULS_CONNECTOR_WORKER_ENABLED: 'true',
      PULS_CONNECTOR_WORKER_IMPORT_APPLY_ENABLED: 'true',
      PULS_CONNECTOR_WORKER_JOB_TYPES: 'import_apply',
      PULS_CONNECTOR_WORKER_ID: 'worker-a',
    })
    const calls: Array<{ fn: string; args: Record<string, unknown> }> = []
    const rpc = async <T>(fn: string, args: Record<string, unknown>): Promise<T> => {
      calls.push({ fn, args })
      if (fn === 'claim_next_connector_job') {
        return [
          noopJob({
            id: 'rollback-job-1',
            job_type: 'import_apply',
            domain: 'import_apply_guarded_update_rollback',
            safe_error_context: {
              contract_version: 'pr16.8-guarded-update-rollback-worker-apply-v1',
              apply_mode: 'guarded_update_rollback',
            },
          }),
        ] as T
      }
      if (fn === 'execute_connector_guarded_update_rollback_apply_job') {
        return [
          {
            rollback_worker_readiness_id: 'readiness-1',
            rollback_approval_id: 'approval-1',
            rollback_preview_id: 'preview-1',
            change_set_id: 'change-set-1',
            import_batch_id: 'batch-1',
            status: 'applied_guarded_update_rollback',
            row_count: 1,
            rollback_count: 1,
            field_diff_count: 1,
            rollback_snapshot_count: 1,
            object_event_count: 1,
            execution_enabled: true,
            canonical_write_enabled: true,
            rollback_execution_enabled: true,
            source_writeback_enabled: false,
            credential_readback_enabled: false,
            provider_api_calls_enabled: false,
            next_action_key: 'review_guarded_update_rollback_object_events',
          },
        ] as T
      }
      if (fn === 'complete_connector_job') return 'rollback-job-1' as T
      if (fn === 'upsert_connector_worker_heartbeat') return 'worker-a' as T
      if (fn === 'heartbeat_connector_job') return 'rollback-job-1' as T
      return [] as T
    }

    const result = await runWorkerOnce(config, rpc)

    expect(result).toEqual({ claimed: true, jobId: 'rollback-job-1', status: 'succeeded' })
    expect(calls.some((call) => call.fn === 'execute_connector_create_only_apply_job')).toBe(false)
    expect(calls.some((call) => call.fn === 'execute_connector_guarded_update_apply_job')).toBe(
      false,
    )
    expect(
      calls.find((call) => call.fn === 'execute_connector_guarded_update_rollback_apply_job')
        ?.args,
    ).toMatchObject({
      p_job_id: 'rollback-job-1',
      p_worker_id: 'worker-a',
    })
    expect(calls.find((call) => call.fn === 'complete_connector_job')?.args).toMatchObject({
      p_job_id: 'rollback-job-1',
      p_status: 'succeeded',
      p_safe_error_code: null,
      p_next_action_key: 'review_guarded_update_rollback_object_events',
      p_safe_error_context: expect.objectContaining({
        apply_contract: 'pr16.8-guarded-update-rollback-worker-apply-v1',
        apply_mode: 'guarded_update_rollback',
        rollback_worker_readiness_id: 'readiness-1',
        rollback_approval_id: 'approval-1',
        rollback_preview_id: 'preview-1',
        rollback_count: 1,
        field_diff_count: 1,
        rollback_snapshot_count: 1,
        canonical_write: true,
        rollback_execution: true,
        source_writeback: false,
        credential_readback: false,
        provider_api_calls: false,
        raw_payload_readback: false,
        field_value_readback: false,
        snapshot_payload_readback: false,
        compensating_execution: false,
      }),
    })

    const serialized = JSON.stringify(calls)
    expect(serialized).not.toContain('service-role-secret-value')
    expect(serialized).not.toContain('"raw_payload":')
    expect(serialized).not.toContain('"snapshot_payload":')
    expect(serialized).not.toContain('provider_response')
  })

  it('fails import_apply safely when the create-only RPC rejects the job', async () => {
    const failure = buildCreateOnlyApplyFailureCompletion(
      noopJob({ job_type: 'import_apply' }),
      new ConnectorWorkerRpcError(400, 'puls_connector_create_only_target_exists'),
    )

    expect(failure).toMatchObject({
      p_status: 'failed',
      p_safe_error_code: 'puls_connector_create_only_target_exists',
      p_next_action_key: 'review_create_only_apply_failure',
      p_safe_error_context: expect.objectContaining({
        apply_contract: 'pr16.3-create-only-worker-apply-v1',
        canonical_write: false,
        source_writeback: false,
        credential_readback: false,
        provider_api_calls: false,
      }),
    })
    expect(JSON.stringify(failure)).not.toContain('"raw_payload":')
    expect(JSON.stringify(failure)).not.toContain('credentials_ref')
  })

  it('fails guarded update import_apply safely when the PR16.4.2 RPC rejects the job', () => {
    const failure = buildGuardedUpdateApplyFailureCompletion(
      noopJob({
        job_type: 'import_apply',
        safe_error_context: {
          contract_version: 'pr16.4.2-guarded-update-worker-apply-v1',
          apply_mode: 'guarded_update',
        },
      }),
      new ConnectorWorkerRpcError(400, 'puls_connector_guarded_update_stale_target'),
    )

    expect(failure).toMatchObject({
      p_status: 'failed',
      p_safe_error_code: 'puls_connector_guarded_update_stale_target',
      p_next_action_key: 'review_guarded_update_apply_failure',
      p_safe_error_context: expect.objectContaining({
        apply_contract: 'pr16.4.2-guarded-update-worker-apply-v1',
        apply_mode: 'guarded_update',
        canonical_write: false,
        source_writeback: false,
        credential_readback: false,
        provider_api_calls: false,
        rollback_execution: false,
      }),
    })
    expect(JSON.stringify(failure)).not.toContain('"raw_payload":')
    expect(JSON.stringify(failure)).not.toContain('credentials_ref')
  })

  it('fails guarded update rollback import_apply safely when the PR16.8 RPC rejects the job', () => {
    const failure = buildGuardedUpdateRollbackApplyFailureCompletion(
      noopJob({
        job_type: 'import_apply',
        domain: 'import_apply_guarded_update_rollback',
        safe_error_context: {
          contract_version: 'pr16.8-guarded-update-rollback-worker-apply-v1',
          apply_mode: 'guarded_update_rollback',
        },
      }),
      new ConnectorWorkerRpcError(400, 'puls_connector_rollback_worker_stale_target'),
    )

    expect(failure).toMatchObject({
      p_status: 'failed',
      p_safe_error_code: 'puls_connector_rollback_worker_stale_target',
      p_next_action_key: 'review_guarded_update_rollback_apply_failure',
      p_safe_error_context: expect.objectContaining({
        apply_contract: 'pr16.8-guarded-update-rollback-worker-apply-v1',
        apply_mode: 'guarded_update_rollback',
        canonical_write: false,
        rollback_execution: false,
        source_writeback: false,
        credential_readback: false,
        provider_api_calls: false,
        raw_payload_readback: false,
        field_value_readback: false,
        snapshot_payload_readback: false,
        compensating_execution: false,
      }),
    })
    expect(JSON.stringify(failure)).not.toContain('"raw_payload":')
    expect(JSON.stringify(failure)).not.toContain('snapshot_payload"')
    expect(JSON.stringify(failure)).not.toContain('credentials_ref')
  })

  it('does not mark create-only apply successful when the RPC result is missing', () => {
    expect(buildCreateOnlyApplyCompletionFromResult(null)).toMatchObject({
      p_status: 'failed',
      p_safe_error_code: 'create_only_apply_result_missing',
      p_next_action_key: 'review_create_only_apply_result',
      p_safe_error_context: expect.objectContaining({
        canonical_write: false,
      }),
    })
  })

  it('does not mark guarded update apply successful when the RPC result is missing', () => {
    expect(buildGuardedUpdateApplyCompletionFromResult(null)).toMatchObject({
      p_status: 'failed',
      p_safe_error_code: 'guarded_update_apply_result_missing',
      p_next_action_key: 'review_guarded_update_apply_result',
      p_safe_error_context: expect.objectContaining({
        canonical_write: false,
        rollback_execution: false,
      }),
    })
  })

  it('does not mark guarded update rollback apply successful when the RPC result is missing', () => {
    expect(buildGuardedUpdateRollbackApplyCompletionFromResult(null)).toMatchObject({
      p_status: 'failed',
      p_safe_error_code: 'guarded_update_rollback_apply_result_missing',
      p_next_action_key: 'review_guarded_update_rollback_apply_result',
      p_safe_error_context: expect.objectContaining({
        canonical_write: false,
        rollback_execution: false,
        source_writeback: false,
        snapshot_payload_readback: false,
      }),
    })
  })

  it('completes runtime preflight with safe credential-reference context only', async () => {
    const config = resolveWorkerConfig({
      PULS_SUPABASE_URL: 'https://example.supabase.co',
      PULS_SUPABASE_SERVICE_ROLE_KEY: 'service-role-secret-value',
      PULS_CONNECTOR_WORKER_ENABLED: 'true',
      PULS_CONNECTOR_WORKER_ID: 'worker-a',
      PULS_CONNECTOR_WORKER_JOB_TYPES: 'connector_runtime_preflight',
    })
    const calls: Array<{ fn: string; args: Record<string, unknown> }> = []
    const rpc = async <T>(fn: string, args: Record<string, unknown>): Promise<T> => {
      calls.push({ fn, args })
      if (fn === 'claim_next_connector_job') {
        return [
          noopJob({
            id: 'runtime-job-1',
            connection_id: 'connection-1',
            job_type: 'connector_runtime_preflight',
          }),
        ] as T
      }
      if (fn === 'get_connector_runtime_preflight_context') {
        return [
          {
            connection_id: 'connection-1',
            tenant_id: 'tenant-1',
            provider: 'canias',
            display_name: 'Canias',
            connection_method: 'rest_api',
            setup_status: 'mapping_ready',
            setup_step: 'preflight',
            auth_mode: 'custom_secret_ref',
            credential_required: true,
            credential_state: 'verified',
            reference_available: true,
            credential_last_verified_at: '2026-06-04T12:00:00.000Z',
            mapped_field_count: 12,
            active_namespace_count: 1,
            identity_count: 13,
            credential_ready: true,
            provider_api_calls_enabled: false,
            credential_readback_enabled: false,
            canonical_writes_enabled: false,
            source_writeback_enabled: false,
            next_action_key: 'review_runtime_preflight_result',
          },
        ] as T
      }
      if (fn === 'complete_connector_job') return 'runtime-job-1' as T
      if (fn === 'upsert_connector_worker_heartbeat') return 'worker-a' as T
      if (fn === 'heartbeat_connector_job') return 'runtime-job-1' as T
      return [] as T
    }

    const result = await runWorkerOnce(config, rpc)

    expect(result).toEqual({ claimed: true, jobId: 'runtime-job-1', status: 'succeeded' })
    expect(calls.find((call) => call.fn === 'claim_next_connector_job')?.args).toMatchObject({
      p_worker_id: 'worker-a',
      p_job_types: ['connector_runtime_preflight'],
    })
    expect(calls.find((call) => call.fn === 'get_connector_runtime_preflight_context')?.args)
      .toMatchObject({
        p_connection_id: 'connection-1',
      })
    expect(calls.find((call) => call.fn === 'complete_connector_job')?.args).toMatchObject({
      p_job_id: 'runtime-job-1',
      p_status: 'succeeded',
      p_safe_error_code: null,
      p_next_action_key: 'provider_runtime_implementation_required',
      p_safe_error_context: expect.objectContaining({
        preflight_scope: 'credential_reference_and_setup_state',
        provider_api_calls: false,
        credential_readback: false,
        canonical_write: false,
        source_writeback: false,
      }),
    })

    const serialized = JSON.stringify(calls)
    expect(serialized).not.toContain('service-role-secret-value')
    expect(serialized).not.toContain('credentials_ref')
    expect(serialized).not.toContain('raw_payload')
    expect(serialized).not.toContain('response_body')
  })

  it('fails runtime preflight safely when credential context is not verified', () => {
    expect(
      buildRuntimePreflightCompletionFromContext(
        noopJob({ job_type: 'connector_runtime_preflight' }),
        {
          connection_id: 'connection-1',
          tenant_id: 'tenant-1',
          provider: 'canias',
          display_name: 'Canias',
          connection_method: 'rest_api',
          setup_status: 'mapping_ready',
          setup_step: 'preflight',
          auth_mode: 'custom_secret_ref',
          credential_required: true,
          credential_state: 'configured',
          reference_available: true,
          credential_last_verified_at: null,
          mapped_field_count: 12,
          active_namespace_count: 1,
          identity_count: 13,
          credential_ready: false,
          provider_api_calls_enabled: false,
          credential_readback_enabled: false,
          canonical_writes_enabled: false,
          source_writeback_enabled: false,
          next_action_key: 'run_credential_verification',
        },
      ),
    ).toMatchObject({
      p_status: 'failed',
      p_safe_error_code: 'runtime_preflight_credential_not_verified',
      p_next_action_key: 'run_credential_verification',
      p_safe_error_context: expect.objectContaining({
        credential_state: 'configured',
        reference_available: true,
        provider_api_calls: false,
        credential_readback: false,
      }),
    })
  })

  it('classifies safe worker failures without raw provider detail', () => {
    expect(
      buildSafeWorkerFailureObservation('connector_job_type_not_supported_by_worker_skeleton', ''),
    ).toEqual({
      failureClass: 'unsupported',
      operatorSeverity: 'error',
      operatorReviewRequired: true,
      retryAfterSeconds: 0,
    })
    expect(buildSafeWorkerFailureObservation('connector_worker_loop_failed', '')).toEqual({
      failureClass: 'worker',
      operatorSeverity: 'warning',
      operatorReviewRequired: false,
      retryAfterSeconds: 120,
    })

    const serialized = JSON.stringify(
      buildSafeWorkerFailureObservation('provider_timeout', 'wait_for_retry_window'),
    )
    expect(serialized).not.toContain('password')
    expect(serialized).not.toContain('credentials_ref')
    expect(serialized).not.toContain('raw_payload')
  })
})
