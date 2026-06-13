import { createHash } from 'node:crypto'

import { extractReceiptFieldsFromPdfTextLayer } from './local-extraction.ts'

export type ExpenseReceiptOcrJobStatus =
  | 'queued'
  | 'processing'
  | 'completed'
  | 'failed'
  | 'retrying'
  | 'cancelled'
  | 'dead_letter'

export type ExpenseReceiptOcrProviderClass = 'disabled' | 'mock' | 'pdf_text'

export type WorkflowEvidenceWorkerConfig = {
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
  providerClass: ExpenseReceiptOcrProviderClass
}

export type WorkflowEvidenceWorkerHealth = {
  service: 'workflow-evidence-worker'
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
    providerClass: ExpenseReceiptOcrProviderClass
  }
  boundaries: {
    externalProviderCalls: false
    browserEnqueue: false
    erpConnectorCoupling: false
    canonicalExpenseWrites: false
    rawOcrTextStorage: false
    serverSideContentHash: boolean
  }
}

export type ClaimedExpenseReceiptOcrJob = {
  job_id: string
  tenant_id: string
  expense_receipt_id: string
  expense_claim_id: string
  status: 'processing'
  provider_class: ExpenseReceiptOcrProviderClass | string
  attempt_count: number
  max_attempts: number
  safe_error_context: Record<string, unknown>
}

export type ExpenseReceiptMetadata = {
  id: string
  tenant_id: string
  expense_claim_id: string
  file_ref: string
  file_name: string | null
  mime_type: string | null
  file_size_bytes: number | null
}

export type ExpenseReceiptExtractionResult = {
  extractedFields: Record<string, string | number | boolean | null>
  fieldConfidence: Record<string, number>
  documentConfidence: number | null
  mismatchFlags: string[]
  providerClass: ExpenseReceiptOcrProviderClass
  providerName: string
  providerVersion: string
  providerReference: string | null
  costMetadata: Record<string, string | number | boolean | null>
}

export type WorkflowEvidenceWorkerRunResult =
  | { status: 'not_configured'; claimed: false }
  | { status: 'idle'; claimed: false }
  | { status: 'completed'; claimed: true; jobId: string; resultId: string; serverSha256: string }
  | { status: 'retrying'; claimed: true; jobId: string; safeErrorCode: string }
  | { status: 'failed'; claimed: true; jobId: string; safeErrorCode: string }

type WorkerEnv = Record<string, string | undefined>
type RpcSchema = 'puls_workflow'

export type WorkflowEvidenceWorkerRpc = <T>(
  fn: string,
  args: Record<string, unknown>,
  schema?: RpcSchema,
) => Promise<T>

type FetchImpl = typeof fetch

const DEFAULT_RUNTIME_VERSION = 'pr17.2g2b-workflow-evidence-worker-v1'
const WORKFLOW_EVIDENCE_BUCKET = 'workflow-evidence'
const DEFAULT_RPC_SCHEMA: RpcSchema = 'puls_workflow'

export class WorkflowEvidenceWorkerRpcError extends Error {
  readonly status: number
  readonly code: string

  constructor(status: number, code: string) {
    super(`Workflow evidence worker RPC failed: ${code}`)
    this.status = status
    this.code = code
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

function normalizeOptionalText(value: string | undefined) {
  const normalized = value?.trim()
  return normalized ? normalized : null
}

function resolveProviderClass(value: string | undefined): ExpenseReceiptOcrProviderClass {
  const normalized = value?.trim().toLowerCase()
  if (normalized === 'pdf_text') return 'pdf_text'
  return normalized === 'mock' ? 'mock' : 'disabled'
}

function isKnownProviderClass(value: string): value is ExpenseReceiptOcrProviderClass {
  return value === 'disabled' || value === 'mock' || value === 'pdf_text'
}

function normalizeRpcSafeErrorCode(
  payload: { code?: string; message?: string } | null,
  status: number,
) {
  const messageCode = payload?.message?.match(/^(PULS_[A-Z0-9_]+)/)?.[1]
  return messageCode?.toLowerCase() ?? payload?.code ?? `http_${status}`
}

export function calculateWorkerLoopDelayMs(
  pollMs: number,
  retryAfterSeconds = 0,
  random: () => number = Math.random,
) {
  const retryDelayMs = Math.max(0, Math.trunc(retryAfterSeconds)) * 1000
  const baseDelayMs = retryDelayMs > 0 ? Math.max(pollMs, retryDelayMs) : pollMs
  const jitterFactor = 0.85 + Math.min(Math.max(random(), 0), 1) * 0.3
  return clampNumber(baseDelayMs * jitterFactor, 1000, 300000)
}

export function resolveWorkflowEvidenceWorkerConfig(
  env: WorkerEnv = process.env,
): WorkflowEvidenceWorkerConfig {
  const supabaseUrl = (env.PULS_SUPABASE_URL ?? env.SUPABASE_URL ?? '').trim().replace(/\/+$/, '')
  const serviceRoleKey = (
    env.PULS_SUPABASE_SERVICE_ROLE_KEY ??
    env.SUPABASE_SERVICE_ROLE_KEY ??
    ''
  ).trim()

  return {
    enabled: parseBoolean(env.PULS_WORKFLOW_EVIDENCE_WORKER_ENABLED, false),
    configured: supabaseUrl !== '' && serviceRoleKey !== '',
    port: clampNumber(Number(env.PORT ?? 8082), 1, 65535),
    workerId: (
      normalizeOptionalText(env.PULS_WORKFLOW_EVIDENCE_WORKER_ID) ?? 'workflow-evidence-worker'
    ).trim(),
    runtimeVersion: (
      normalizeOptionalText(env.PULS_WORKFLOW_EVIDENCE_WORKER_VERSION) ?? DEFAULT_RUNTIME_VERSION
    ).trim(),
    supabaseUrl: supabaseUrl || null,
    serviceRoleKey: serviceRoleKey || null,
    pollMs: clampNumber(Number(env.PULS_WORKFLOW_EVIDENCE_WORKER_POLL_MS ?? 5000), 1000, 60000),
    leaseSeconds: clampNumber(
      Number(env.PULS_WORKFLOW_EVIDENCE_WORKER_LEASE_SECONDS ?? 300),
      30,
      3600,
    ),
    recoverStaleJobs: parseBoolean(env.PULS_WORKFLOW_EVIDENCE_WORKER_RECOVER_STALE, true),
    recoveryLimit: clampNumber(
      Number(env.PULS_WORKFLOW_EVIDENCE_WORKER_RECOVERY_LIMIT ?? 25),
      1,
      100,
    ),
    providerClass: resolveProviderClass(env.PULS_WORKFLOW_EVIDENCE_PROVIDER_CLASS),
  }
}

export function buildHealthPayload(
  config: WorkflowEvidenceWorkerConfig,
): WorkflowEvidenceWorkerHealth {
  return {
    service: 'workflow-evidence-worker',
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
      providerClass: config.providerClass,
    },
    boundaries: {
      externalProviderCalls: false,
      browserEnqueue: false,
      erpConnectorCoupling: false,
      canonicalExpenseWrites: false,
      rawOcrTextStorage: false,
      serverSideContentHash: true,
    },
  }
}

export function buildSupabaseRpcHeaders(
  serviceRoleKey: string,
  schema: RpcSchema = DEFAULT_RPC_SCHEMA,
): Record<string, string> {
  return {
    apikey: serviceRoleKey,
    Authorization: `Bearer ${serviceRoleKey}`,
    'Accept-Profile': schema,
    'Content-Type': 'application/json',
    'Content-Profile': schema,
  }
}

export function buildSupabaseStorageHeaders(serviceRoleKey: string): Record<string, string> {
  return {
    apikey: serviceRoleKey,
    Authorization: `Bearer ${serviceRoleKey}`,
  }
}

export function redactWorkflowEvidenceWorkerHeaders(
  headers: Record<string, string>,
): Record<string, string> {
  return Object.fromEntries(
    Object.entries(headers).map(([key, value]) => {
      const normalizedKey = key.toLowerCase()
      if (normalizedKey === 'apikey' || normalizedKey === 'authorization') {
        return [key, '[REDACTED]']
      }
      return [key, value]
    }),
  )
}

export async function callSupabaseRpc<T>(
  config: WorkflowEvidenceWorkerConfig,
  fn: string,
  args: Record<string, unknown>,
  schema: RpcSchema = DEFAULT_RPC_SCHEMA,
): Promise<T> {
  if (!config.supabaseUrl || !config.serviceRoleKey) {
    throw new WorkflowEvidenceWorkerRpcError(0, 'workflow_evidence_worker_not_configured')
  }

  const response = await fetch(`${config.supabaseUrl}/rest/v1/rpc/${fn}`, {
    method: 'POST',
    headers: buildSupabaseRpcHeaders(config.serviceRoleKey, schema),
    body: JSON.stringify(args),
  })

  const payload = (await response.json().catch(() => null)) as {
    code?: string
    message?: string
  } | null

  if (!response.ok) {
    throw new WorkflowEvidenceWorkerRpcError(
      response.status,
      normalizeRpcSafeErrorCode(payload, response.status),
    )
  }

  return payload as T
}

function encodeStoragePath(storagePath: string) {
  return storagePath.split('/').map(encodeURIComponent).join('/')
}

export function buildWorkflowEvidenceObjectUrl(
  supabaseUrl: string,
  bucket: string,
  storagePath: string,
) {
  return `${supabaseUrl}/storage/v1/object/${encodeURIComponent(bucket)}/${encodeStoragePath(storagePath)}`
}

export async function fetchExpenseReceiptMetadata(
  config: WorkflowEvidenceWorkerConfig,
  receiptId: string,
  fetchImpl: FetchImpl = fetch,
): Promise<ExpenseReceiptMetadata> {
  if (!config.supabaseUrl || !config.serviceRoleKey) {
    throw new WorkflowEvidenceWorkerRpcError(0, 'workflow_evidence_worker_not_configured')
  }

  const query = new URLSearchParams({
    id: `eq.${receiptId}`,
    select: 'id,tenant_id,expense_claim_id,file_ref,file_name,mime_type,file_size_bytes',
  })
  const response = await fetchImpl(`${config.supabaseUrl}/rest/v1/expense_receipts?${query}`, {
    method: 'GET',
    headers: buildSupabaseRpcHeaders(config.serviceRoleKey),
  })

  const payload = (await response.json().catch(() => null)) as ExpenseReceiptMetadata[] | null
  if (!response.ok) {
    throw new WorkflowEvidenceWorkerRpcError(
      response.status,
      'expense_receipt_metadata_fetch_failed',
    )
  }

  const receipt = payload?.[0]
  if (!receipt?.file_ref) {
    throw new WorkflowEvidenceWorkerRpcError(404, 'expense_receipt_metadata_missing')
  }

  return receipt
}

export async function downloadWorkflowEvidenceObject(
  config: WorkflowEvidenceWorkerConfig,
  storagePath: string,
  fetchImpl: FetchImpl = fetch,
): Promise<Uint8Array> {
  if (!config.supabaseUrl || !config.serviceRoleKey) {
    throw new WorkflowEvidenceWorkerRpcError(0, 'workflow_evidence_worker_not_configured')
  }

  const response = await fetchImpl(
    buildWorkflowEvidenceObjectUrl(config.supabaseUrl, WORKFLOW_EVIDENCE_BUCKET, storagePath),
    {
      method: 'GET',
      headers: buildSupabaseStorageHeaders(config.serviceRoleKey),
    },
  )

  if (!response.ok) {
    throw new WorkflowEvidenceWorkerRpcError(
      response.status,
      'workflow_evidence_object_download_failed',
    )
  }

  return new Uint8Array(await response.arrayBuffer())
}

export function computeSha256Hex(bytes: Uint8Array) {
  return createHash('sha256').update(bytes).digest('hex')
}

export function buildDisabledProviderExtraction(
  config: WorkflowEvidenceWorkerConfig,
): ExpenseReceiptExtractionResult {
  const providerClass = config.providerClass
  return {
    extractedFields: {},
    fieldConfidence: {},
    documentConfidence: null,
    mismatchFlags:
      providerClass === 'mock'
        ? ['mock_provider', 'human_review_required']
        : ['provider_disabled', 'human_review_required'],
    providerClass,
    providerName:
      providerClass === 'mock' ? 'puls-workflow-evidence-mock' : 'puls-workflow-evidence-disabled',
    providerVersion: config.runtimeVersion,
    providerReference: null,
    costMetadata: {
      external_call: false,
      estimated_cost_minor: 0,
      provider_enabled: providerClass === 'mock',
    },
  }
}

export function buildLocalProviderExtraction(
  config: WorkflowEvidenceWorkerConfig,
  bytes: Uint8Array,
  receipt: Pick<ExpenseReceiptMetadata, 'mime_type'>,
): ExpenseReceiptExtractionResult {
  if (config.providerClass !== 'pdf_text') {
    return buildDisabledProviderExtraction(config)
  }

  const extraction = extractReceiptFieldsFromPdfTextLayer(bytes, receipt.mime_type)
  return {
    extractedFields: extraction.fields,
    fieldConfidence: extraction.fieldConfidence,
    documentConfidence: extraction.documentConfidence,
    mismatchFlags: ['local_pdf_text', ...extraction.warnings],
    providerClass: 'pdf_text',
    providerName: 'puls-workflow-evidence-pdf-text',
    providerVersion: config.runtimeVersion,
    providerReference: null,
    costMetadata: {
      external_call: false,
      estimated_cost_minor: 0,
      route_used: extraction.routeUsed,
      text_payload_stored: false,
      benchmark_candidate: true,
    },
  }
}

export function buildCompletionArgs(
  job: ClaimedExpenseReceiptOcrJob,
  workerId: string,
  serverSha256: string,
  extraction: ExpenseReceiptExtractionResult,
) {
  return {
    p_job_id: job.job_id,
    p_worker_id: workerId,
    p_status: 'completed',
    p_server_sha256: serverSha256,
    p_extracted_fields: extraction.extractedFields,
    p_field_confidence: extraction.fieldConfidence,
    p_document_confidence: extraction.documentConfidence,
    p_mismatch_flags: extraction.mismatchFlags,
    p_provider_class: extraction.providerClass,
    p_provider_name: extraction.providerName,
    p_provider_version: extraction.providerVersion,
    p_provider_reference: extraction.providerReference,
    p_cost_metadata: extraction.costMetadata,
    p_safe_error_code: null,
    p_safe_error_context: {
      worker_contract: DEFAULT_RUNTIME_VERSION,
      external_call: false,
      text_payload_stored: false,
      canonical_write: false,
      server_side_content_hash: true,
    },
    p_next_action_key: 'review_expense_receipt_ocr_result',
    p_retry_after_seconds: null,
  } satisfies Record<string, unknown>
}

function buildFailureCompletionArgs(
  job: ClaimedExpenseReceiptOcrJob,
  workerId: string,
  safeErrorCode: string,
  status: 'failed' | 'retrying' = 'failed',
  retryAfterSeconds: number | null = null,
) {
  return {
    p_job_id: job.job_id,
    p_worker_id: workerId,
    p_status: status,
    p_server_sha256: null,
    p_extracted_fields: {},
    p_field_confidence: {},
    p_document_confidence: null,
    p_mismatch_flags: ['worker_processing_failed'],
    p_provider_class: 'disabled',
    p_provider_name: 'puls-workflow-evidence-worker',
    p_provider_version: DEFAULT_RUNTIME_VERSION,
    p_provider_reference: null,
    p_cost_metadata: {
      external_call: false,
      estimated_cost_minor: 0,
    },
    p_safe_error_code: safeErrorCode,
    p_safe_error_context: {
      worker_contract: DEFAULT_RUNTIME_VERSION,
      failure_class: 'worker',
      external_call: false,
      text_payload_stored: false,
      canonical_write: false,
      transient: status === 'retrying',
    },
    p_next_action_key: 'review_expense_receipt_ocr_worker_failure',
    p_retry_after_seconds: retryAfterSeconds,
  } satisfies Record<string, unknown>
}

function normalizeErrorCode(error: unknown) {
  if (error instanceof WorkflowEvidenceWorkerRpcError) return error.code
  if (error instanceof Error && error.message) {
    return error.message
      .toLowerCase()
      .replace(/[^a-z0-9_]+/g, '_')
      .slice(0, 80)
  }
  return 'workflow_evidence_worker_unknown_error'
}

function isTransientWorkerError(error: unknown) {
  if (error instanceof WorkflowEvidenceWorkerRpcError) {
    return error.status === 0 || error.status === 408 || error.status === 429 || error.status >= 500
  }

  return error instanceof TypeError
}

function resolveFailureStatus(error: unknown): {
  status: 'failed' | 'retrying'
  retryAfterSeconds: number | null
} {
  return isTransientWorkerError(error)
    ? { status: 'retrying', retryAfterSeconds: 120 }
    : { status: 'failed', retryAfterSeconds: null }
}

function assertProviderClassMatchesJob(
  config: WorkflowEvidenceWorkerConfig,
  job: ClaimedExpenseReceiptOcrJob,
) {
  if (!isKnownProviderClass(job.provider_class)) {
    throw new WorkflowEvidenceWorkerRpcError(422, 'ocr_provider_class_unknown')
  }

  if (job.provider_class !== config.providerClass) {
    throw new WorkflowEvidenceWorkerRpcError(422, 'ocr_provider_class_mismatch')
  }
}

async function withLeaseHeartbeat<T>(
  config: WorkflowEvidenceWorkerConfig,
  job: ClaimedExpenseReceiptOcrJob,
  rpc: WorkflowEvidenceWorkerRpc,
  operation: () => Promise<T>,
): Promise<T> {
  const heartbeat = () =>
    rpc<string>('heartbeat_expense_receipt_ocr_job', {
      p_job_id: job.job_id,
      p_worker_id: config.workerId,
      p_lease_seconds: config.leaseSeconds,
      p_safe_error_context: {},
    })

  await heartbeat()

  const heartbeatEveryMs = clampNumber((config.leaseSeconds * 1000) / 3, 5000, 30000)
  const interval = setInterval(() => {
    void heartbeat().catch(() => undefined)
  }, heartbeatEveryMs)

  try {
    return await operation()
  } finally {
    clearInterval(interval)
  }
}

export async function runWorkerOnce(
  config: WorkflowEvidenceWorkerConfig,
  options: {
    rpc?: WorkflowEvidenceWorkerRpc
    fetchImpl?: FetchImpl
  } = {},
): Promise<WorkflowEvidenceWorkerRunResult> {
  if (!config.configured) {
    return { status: 'not_configured', claimed: false }
  }

  const rpc = options.rpc ?? ((fn, args, schema) => callSupabaseRpc(config, fn, args, schema))
  const fetchImpl = options.fetchImpl ?? fetch

  if (config.recoverStaleJobs) {
    await rpc<number>('recover_stale_expense_receipt_ocr_jobs', {
      p_worker_id: config.workerId,
      p_limit: config.recoveryLimit,
    })
  }

  const claimedJobs = await rpc<ClaimedExpenseReceiptOcrJob[]>(
    'claim_next_expense_receipt_ocr_job',
    {
      p_worker_id: config.workerId,
      p_limit: 1,
      p_lease_seconds: config.leaseSeconds,
    },
  )
  const job = claimedJobs[0]

  if (!job) {
    return { status: 'idle', claimed: false }
  }

  try {
    assertProviderClassMatchesJob(config, job)

    const receipt = await withLeaseHeartbeat(config, job, rpc, () =>
      fetchExpenseReceiptMetadata(config, job.expense_receipt_id, fetchImpl),
    )
    const bytes = await withLeaseHeartbeat(config, job, rpc, () =>
      downloadWorkflowEvidenceObject(config, receipt.file_ref, fetchImpl),
    )

    if (receipt.file_size_bytes !== null && bytes.byteLength !== receipt.file_size_bytes) {
      throw new WorkflowEvidenceWorkerRpcError(422, 'workflow_evidence_object_size_mismatch')
    }

    const serverSha256 = computeSha256Hex(bytes)
    const extraction = await withLeaseHeartbeat(config, job, rpc, async () =>
      buildLocalProviderExtraction(config, bytes, receipt),
    )
    const completionArgs = {
      ...buildCompletionArgs(job, config.workerId, serverSha256, extraction),
      p_safe_error_context: {
        worker_contract: config.runtimeVersion,
        external_call: false,
        text_payload_stored: false,
        canonical_write: false,
        server_side_content_hash: true,
        downloaded_bytes: bytes.byteLength,
        mime_type: receipt.mime_type,
      },
    }
    const resultId = await withLeaseHeartbeat(config, job, rpc, () =>
      rpc<string>('complete_expense_receipt_ocr_job', completionArgs),
    )

    return {
      status: 'completed',
      claimed: true,
      jobId: job.job_id,
      resultId,
      serverSha256,
    }
  } catch (error) {
    const safeErrorCode = normalizeErrorCode(error)
    const failure = resolveFailureStatus(error)
    await rpc<string>(
      'complete_expense_receipt_ocr_job',
      buildFailureCompletionArgs(
        job,
        config.workerId,
        safeErrorCode,
        failure.status,
        failure.retryAfterSeconds,
      ),
    )

    return {
      status: failure.status,
      claimed: true,
      jobId: job.job_id,
      safeErrorCode,
    }
  }
}

export function startWorkflowEvidenceWorkerLoop(
  config: WorkflowEvidenceWorkerConfig,
  options: {
    rpc?: WorkflowEvidenceWorkerRpc
    fetchImpl?: FetchImpl
    random?: () => number
  } = {},
) {
  let stopped = false
  let timeout: ReturnType<typeof setTimeout> | null = null

  const scheduleNextTick = (retryAfterSeconds = 0) => {
    if (stopped) return
    timeout = setTimeout(
      tick,
      calculateWorkerLoopDelayMs(config.pollMs, retryAfterSeconds, options.random),
    )
  }

  const tick = async () => {
    if (stopped) return
    try {
      await runWorkerOnce(config, { rpc: options.rpc, fetchImpl: options.fetchImpl })
      scheduleNextTick(0)
    } catch {
      scheduleNextTick(120)
    }
  }

  scheduleNextTick(0)

  return () => {
    stopped = true
    if (timeout) clearTimeout(timeout)
  }
}
