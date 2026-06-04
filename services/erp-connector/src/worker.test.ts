import { describe, expect, it } from 'vitest'

import {
  buildSafeWorkerFailureObservation,
  buildConnectorJobCompletion,
  buildHealthPayload,
  parseSupportedJobTypes,
  resolveWorkerConfig,
  runWorkerOnce,
  type ClaimedConnectorJob,
} from './worker.ts'

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
