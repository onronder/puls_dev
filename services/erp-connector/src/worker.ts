export type ConnectorJobStatus =
  | 'queued'
  | 'running'
  | 'succeeded'
  | 'failed'
  | 'retrying'
  | 'cancelled'
  | 'dead_letter'

export type ConnectorJobType =
  | 'setup_preflight'
  | 'credential_verification'
  | 'import_preview'
  | 'import_apply'
  | 'connector_runtime_preflight'
  | 'source_discovery'
  | 'noop_health'

export type ConnectorWorkerStatus =
  | 'idle'
  | 'claiming'
  | 'running'
  | 'recovering'
  | 'paused'
  | 'error'

export type ConnectorWorkerFailureClass =
  | 'none'
  | 'transient'
  | 'credential'
  | 'mapping'
  | 'provider_limit'
  | 'provider_unavailable'
  | 'worker'
  | 'unsupported'
  | 'unknown'

export type ConnectorWorkerOperatorSeverity = 'info' | 'warning' | 'error' | 'critical'

export type ConnectorWorkerFailureObservation = {
  failureClass: ConnectorWorkerFailureClass
  operatorSeverity: ConnectorWorkerOperatorSeverity
  operatorReviewRequired: boolean
  retryAfterSeconds: number
}

export type ConnectorWorkerConfig = {
  enabled: boolean
  configured: boolean
  port: number
  workerId: string
  runtimeVersion: string
  supabaseUrl: string | null
  serviceRoleKey: string | null
  pollMs: number
  leaseSeconds: number
  recoverStaleJobs: boolean
  recoveryLimit: number
  supportedJobTypes: ConnectorJobType[]
}

export type ConnectorWorkerHealth = {
  service: 'erp-connector'
  status: 'ok'
  runtime: 'worker-skeleton'
  version: string
  worker: {
    enabled: boolean
    configured: boolean
    workerId: string
    pollMs: number
    leaseSeconds: number
    recoverStaleJobs: boolean
    supportedJobTypes: ConnectorJobType[]
  }
  boundaries: {
    providerApiCalls: false
    credentialReadback: false
    canonicalWrites: false
    sourceWriteback: false
  }
}

export type ClaimedConnectorJob = {
  id: string
  connection_id?: string | null
  job_type: ConnectorJobType
  status: ConnectorJobStatus
  attempt_count: number
  max_attempts: number
  domain: string | null
}

export type ConnectorRuntimePreflightContext = {
  connection_id: string
  tenant_id: string
  provider: string | null
  display_name: string | null
  connection_method: string | null
  setup_status: string | null
  setup_step: string | null
  auth_mode: string | null
  credential_required: boolean | null
  credential_state: string | null
  reference_available: boolean | null
  credential_last_verified_at: string | null
  mapped_field_count: number | null
  active_namespace_count: number | null
  identity_count: number | null
  credential_ready: boolean | null
  provider_api_calls_enabled: boolean | null
  credential_readback_enabled: boolean | null
  canonical_writes_enabled: boolean | null
  source_writeback_enabled: boolean | null
  next_action_key: string | null
}

type CompleteConnectorJobArgs = {
  p_job_id: string
  p_worker_id: string
  p_status: ConnectorJobStatus
  p_safe_error_code: string | null
  p_safe_error_context: Record<string, string | number | boolean | null>
  p_next_action_key: string
  p_scheduled_at?: string | null
}

type ConnectorJobCompletion = Pick<
  CompleteConnectorJobArgs,
  'p_status' | 'p_safe_error_code' | 'p_safe_error_context' | 'p_next_action_key'
>

type ConnectorWorkerRpc = <T>(fn: string, args: Record<string, unknown>) => Promise<T>

type WorkerEnv = Record<string, string | undefined>

const CONNECTOR_JOB_TYPES: ConnectorJobType[] = [
  'setup_preflight',
  'credential_verification',
  'import_preview',
  'import_apply',
  'connector_runtime_preflight',
  'source_discovery',
  'noop_health',
]

const DEFAULT_SUPPORTED_JOB_TYPES: ConnectorJobType[] = ['noop_health']
const DEFAULT_RUNTIME_VERSION = '0.2.0-worker-skeleton'
const WORKER_CONTRACT_VERSION = 'pr15.2-worker-skeleton-v1'

export class ConnectorWorkerRpcError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
  ) {
    super(`Connector worker RPC failed: ${code}`)
  }
}

function clampNumber(value: number, min: number, max: number) {
  if (!Number.isFinite(value)) return min
  return Math.min(Math.max(Math.trunc(value), min), max)
}

function parseBoolean(value: string | undefined, fallback = false) {
  if (value === undefined) return fallback
  return ['1', 'true', 'yes', 'on'].includes(value.trim().toLowerCase())
}

function isConnectorJobType(value: string): value is ConnectorJobType {
  return CONNECTOR_JOB_TYPES.includes(value as ConnectorJobType)
}

export function buildSafeWorkerFailureObservation(
  safeErrorCode: string | null,
  nextActionKey: string,
): ConnectorWorkerFailureObservation {
  const code = (safeErrorCode ?? '').toLowerCase()
  const action = nextActionKey.toLowerCase()

  if (!code) {
    return {
      failureClass: 'none',
      operatorSeverity: 'info',
      operatorReviewRequired: false,
      retryAfterSeconds: 0,
    }
  }

  if (
    code.includes('unsupported') ||
    code.includes('not_supported') ||
    action.includes('provider_runtime_implementation')
  ) {
    return {
      failureClass: 'unsupported',
      operatorSeverity: 'error',
      operatorReviewRequired: true,
      retryAfterSeconds: 0,
    }
  }

  if (code.includes('worker') || code.includes('rpc') || code.includes('lease')) {
    return {
      failureClass: 'worker',
      operatorSeverity: 'warning',
      operatorReviewRequired: false,
      retryAfterSeconds: 120,
    }
  }

  if (code.includes('timeout') || code.includes('network') || code.includes('http_5')) {
    return {
      failureClass: 'provider_unavailable',
      operatorSeverity: 'warning',
      operatorReviewRequired: false,
      retryAfterSeconds: 120,
    }
  }

  if (code.includes('credential') || code.includes('secret') || code.includes('reference')) {
    return {
      failureClass: 'credential',
      operatorSeverity: 'error',
      operatorReviewRequired: true,
      retryAfterSeconds: 0,
    }
  }

  return {
    failureClass: 'unknown',
    operatorSeverity: 'error',
    operatorReviewRequired: true,
    retryAfterSeconds: 0,
  }
}

export function parseSupportedJobTypes(value: string | undefined): ConnectorJobType[] {
  if (!value?.trim()) return [...DEFAULT_SUPPORTED_JOB_TYPES]

  const parsed = value
    .split(',')
    .map((item) => item.trim())
    .filter(isConnectorJobType)

  return parsed.length > 0 ? parsed : [...DEFAULT_SUPPORTED_JOB_TYPES]
}

export function resolveWorkerConfig(env: WorkerEnv = process.env): ConnectorWorkerConfig {
  const supabaseUrl = (env.PULS_SUPABASE_URL ?? env.SUPABASE_URL ?? '').trim().replace(/\/+$/, '')
  const serviceRoleKey = (
    env.PULS_SUPABASE_SERVICE_ROLE_KEY ??
    env.SUPABASE_SERVICE_ROLE_KEY ??
    ''
  ).trim()

  return {
    enabled: parseBoolean(env.PULS_CONNECTOR_WORKER_ENABLED, false),
    configured: supabaseUrl !== '' && serviceRoleKey !== '',
    port: clampNumber(Number(env.PORT ?? 8081), 1, 65535),
    workerId: (env.PULS_CONNECTOR_WORKER_ID ?? 'erp-connector-worker').trim(),
    runtimeVersion: (env.PULS_CONNECTOR_WORKER_VERSION ?? DEFAULT_RUNTIME_VERSION).trim(),
    supabaseUrl: supabaseUrl || null,
    serviceRoleKey: serviceRoleKey || null,
    pollMs: clampNumber(Number(env.PULS_CONNECTOR_WORKER_POLL_MS ?? 5000), 1000, 60000),
    leaseSeconds: clampNumber(Number(env.PULS_CONNECTOR_WORKER_LEASE_SECONDS ?? 300), 30, 3600),
    recoverStaleJobs: parseBoolean(env.PULS_CONNECTOR_WORKER_RECOVER_STALE, true),
    recoveryLimit: clampNumber(Number(env.PULS_CONNECTOR_WORKER_RECOVERY_LIMIT ?? 25), 1, 100),
    supportedJobTypes: parseSupportedJobTypes(env.PULS_CONNECTOR_WORKER_JOB_TYPES),
  }
}

export function buildHealthPayload(config: ConnectorWorkerConfig): ConnectorWorkerHealth {
  return {
    service: 'erp-connector',
    status: 'ok',
    runtime: 'worker-skeleton',
    version: config.runtimeVersion,
    worker: {
      enabled: config.enabled,
      configured: config.configured,
      workerId: config.workerId,
      pollMs: config.pollMs,
      leaseSeconds: config.leaseSeconds,
      recoverStaleJobs: config.recoverStaleJobs,
      supportedJobTypes: config.supportedJobTypes,
    },
    boundaries: {
      providerApiCalls: false,
      credentialReadback: false,
      canonicalWrites: false,
      sourceWriteback: false,
    },
  }
}

export async function callSupabaseRpc<T>(
  config: ConnectorWorkerConfig,
  fn: string,
  args: Record<string, unknown>,
): Promise<T> {
  if (!config.supabaseUrl || !config.serviceRoleKey) {
    throw new ConnectorWorkerRpcError(0, 'connector_worker_not_configured')
  }

  const response = await fetch(`${config.supabaseUrl}/rest/v1/rpc/${fn}`, {
    method: 'POST',
    headers: {
      apikey: config.serviceRoleKey,
      Authorization: `Bearer ${config.serviceRoleKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(args),
  })

  const payload = (await response.json().catch(() => null)) as {
    code?: string
    message?: string
  } | null

  if (!response.ok) {
    throw new ConnectorWorkerRpcError(
      response.status,
      payload?.code ?? `http_${response.status}`,
    )
  }

  return payload as T
}

export function buildConnectorJobCompletion(job: ClaimedConnectorJob): ConnectorJobCompletion {
  if (job.job_type === 'noop_health') {
    return {
      p_status: 'succeeded',
      p_safe_error_code: null,
      p_safe_error_context: {
        worker_contract: WORKER_CONTRACT_VERSION,
        external_call: false,
        credential_read: false,
        canonical_write: false,
      },
      p_next_action_key: 'worker_contract_ready',
    }
  }

  const observation = buildSafeWorkerFailureObservation(
    'connector_job_type_not_supported_by_worker_skeleton',
    'wait_for_provider_runtime_implementation',
  )

  return {
    p_status: 'failed',
    p_safe_error_code: 'connector_job_type_not_supported_by_worker_skeleton',
    p_safe_error_context: {
      worker_contract: WORKER_CONTRACT_VERSION,
      job_type: job.job_type,
      failure_class: observation.failureClass,
      operator_severity: observation.operatorSeverity,
      operator_review_required: observation.operatorReviewRequired,
      retry_after_seconds: observation.retryAfterSeconds,
      external_call: false,
      credential_read: false,
      canonical_write: false,
    },
    p_next_action_key: 'wait_for_provider_runtime_implementation',
  }
}

export function buildRuntimePreflightCompletionFromContext(
  job: ClaimedConnectorJob,
  context: ConnectorRuntimePreflightContext | null,
): ConnectorJobCompletion {
  if (!context) {
    return {
      p_status: 'failed',
      p_safe_error_code: 'runtime_preflight_context_missing',
      p_safe_error_context: {
        worker_contract: WORKER_CONTRACT_VERSION,
        job_type: job.job_type,
        external_call: false,
        credential_read: false,
        canonical_write: false,
        source_writeback: false,
      },
      p_next_action_key: 'review_runtime_preflight_context',
    }
  }

  const safeContext = {
    worker_contract: WORKER_CONTRACT_VERSION,
    preflight_scope: 'credential_reference_and_setup_state',
    provider: context.provider,
    connection_method: context.connection_method,
    setup_status: context.setup_status,
    setup_step: context.setup_step,
    auth_mode: context.auth_mode,
    credential_required: context.credential_required === true,
    credential_state: context.credential_state,
    reference_available: context.reference_available === true,
    credential_last_verified_at: context.credential_last_verified_at,
    mapped_field_count: Number(context.mapped_field_count ?? 0),
    active_namespace_count: Number(context.active_namespace_count ?? 0),
    identity_count: Number(context.identity_count ?? 0),
    provider_api_calls: false,
    provider_api_calls_enabled: false,
    credential_read: false,
    credential_readback: false,
    credential_readback_enabled: false,
    canonical_write: false,
    canonical_writes_enabled: false,
    source_writeback: false,
    source_writeback_enabled: false,
  }

  if (context.credential_ready !== true) {
    return {
      p_status: 'failed',
      p_safe_error_code: 'runtime_preflight_credential_not_verified',
      p_safe_error_context: safeContext,
      p_next_action_key: context.next_action_key ?? 'run_credential_verification',
    }
  }

  return {
    p_status: 'succeeded',
    p_safe_error_code: null,
    p_safe_error_context: safeContext,
    p_next_action_key: 'provider_runtime_implementation_required',
  }
}

async function resolveConnectorJobCompletion(
  job: ClaimedConnectorJob,
  rpc: ConnectorWorkerRpc,
): Promise<ConnectorJobCompletion> {
  if (job.job_type !== 'connector_runtime_preflight') {
    return buildConnectorJobCompletion(job)
  }

  const contextRows = await rpc<ConnectorRuntimePreflightContext[]>(
    'get_connector_runtime_preflight_context',
    {
      p_connection_id: job.connection_id ?? null,
    },
  )

  return buildRuntimePreflightCompletionFromContext(job, contextRows[0] ?? null)
}

async function upsertWorkerHeartbeat(
  config: ConnectorWorkerConfig,
  rpc: ConnectorWorkerRpc,
  status: ConnectorWorkerStatus,
  lastClaimedJobId: string | null,
  safeErrorCode: string | null = null,
) {
  await rpc<string>('upsert_connector_worker_heartbeat', {
    p_worker_id: config.workerId,
    p_status: status,
    p_runtime_version: config.runtimeVersion,
    p_supported_job_types: config.supportedJobTypes,
    p_last_claimed_job_id: lastClaimedJobId,
    p_safe_error_code: safeErrorCode,
    p_safe_context: {
      worker_contract: WORKER_CONTRACT_VERSION,
      provider_api_calls: false,
      credential_readback: false,
      canonical_writes: false,
      source_writeback: false,
    },
  })
}

export async function runWorkerOnce(
  config: ConnectorWorkerConfig,
  rpc: ConnectorWorkerRpc = (fn, args) => callSupabaseRpc(config, fn, args),
) {
  if (!config.enabled || !config.configured) {
    return { claimed: false, reason: 'worker_disabled_or_unconfigured' as const }
  }

  await upsertWorkerHeartbeat(config, rpc, 'claiming', null)

  if (config.recoverStaleJobs) {
    await rpc('recover_stale_connector_jobs', {
      p_worker_id: config.workerId,
      p_limit: config.recoveryLimit,
    })
  }

  const jobs = await rpc<ClaimedConnectorJob[]>('claim_next_connector_job', {
    p_worker_id: config.workerId,
    p_job_types: config.supportedJobTypes,
  })
  const job = jobs[0]

  if (!job) {
    await upsertWorkerHeartbeat(config, rpc, 'idle', null)
    return { claimed: false, reason: 'queue_empty' as const }
  }

  await upsertWorkerHeartbeat(config, rpc, 'running', job.id)
  await rpc('heartbeat_connector_job', {
    p_job_id: job.id,
    p_worker_id: config.workerId,
    p_lease_seconds: config.leaseSeconds,
    p_safe_context: {
      worker_contract: WORKER_CONTRACT_VERSION,
      job_type: job.job_type,
    },
  })

  const completion = await resolveConnectorJobCompletion(job, rpc)
  const completeArgs: CompleteConnectorJobArgs = {
    p_job_id: job.id,
    p_worker_id: config.workerId,
    ...completion,
  }

  await rpc<string>('complete_connector_job', completeArgs)
  await upsertWorkerHeartbeat(config, rpc, 'idle', job.id, completion.p_safe_error_code)

  return { claimed: true, jobId: job.id, status: completion.p_status }
}

export function startConnectorWorkerLoop(
  config: ConnectorWorkerConfig,
  rpc: ConnectorWorkerRpc = (fn, args) => callSupabaseRpc(config, fn, args),
) {
  let running = false
  let stopped = false

  const tick = async () => {
    if (running || stopped) return
    running = true
    try {
      await runWorkerOnce(config, rpc)
    } catch (error) {
      const code =
        error instanceof ConnectorWorkerRpcError
          ? error.code
          : 'connector_worker_loop_failed'
      await upsertWorkerHeartbeat(config, rpc, 'error', null, code).catch(() => undefined)
      console.warn(`erp-connector worker loop recorded safe error: ${code}`)
    } finally {
      running = false
    }
  }

  const interval = setInterval(tick, config.pollMs)
  void tick()

  return () => {
    stopped = true
    clearInterval(interval)
  }
}
