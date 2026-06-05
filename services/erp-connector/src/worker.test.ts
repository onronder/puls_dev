import { afterEach, describe, expect, it, vi } from 'vitest'

import {
  buildSafeWorkerFailureObservation,
  callSupabaseRpc,
  buildConnectorJobCompletion,
  buildHealthPayload,
  buildRuntimePreflightCompletionFromContext,
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
    expect(config.supportedJobTypes).toEqual(['noop_health', 'import_apply'])
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
