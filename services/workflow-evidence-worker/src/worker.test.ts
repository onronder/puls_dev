import { describe, expect, it, vi } from 'vitest'

import {
  buildCompletionArgs,
  buildDisabledProviderExtraction,
  buildHealthPayload,
  buildSupabaseRpcHeaders,
  buildSupabaseStorageHeaders,
  buildWorkflowEvidenceObjectUrl,
  computeSha256Hex,
  downloadWorkflowEvidenceObject,
  fetchExpenseReceiptMetadata,
  redactWorkflowEvidenceWorkerHeaders,
  resolveWorkflowEvidenceWorkerConfig,
  runWorkerOnce,
  type ClaimedExpenseReceiptOcrJob,
  type WorkflowEvidenceWorkerRpc,
} from './worker.ts'

const configuredEnv = {
  PULS_SUPABASE_URL: 'https://example.supabase.co/',
  PULS_SUPABASE_SERVICE_ROLE_KEY: 'service-role-secret-value',
}

function claimedJob(
  overrides: Partial<ClaimedExpenseReceiptOcrJob> = {},
): ClaimedExpenseReceiptOcrJob {
  return {
    job_id: 'job-1',
    tenant_id: 'tenant-1',
    expense_receipt_id: 'receipt-1',
    expense_claim_id: 'claim-1',
    status: 'processing',
    provider_class: 'disabled',
    attempt_count: 1,
    max_attempts: 3,
    safe_error_context: {},
    ...overrides,
  }
}

describe('workflow evidence worker config', () => {
  it('defaults to disabled and does not leak service-role keys in health', () => {
    const config = resolveWorkflowEvidenceWorkerConfig(configuredEnv)
    const health = buildHealthPayload(config)
    const serialized = JSON.stringify(health)

    expect(config.enabled).toBe(false)
    expect(config.configured).toBe(true)
    expect(health.boundaries).toMatchObject({
      externalProviderCalls: false,
      browserEnqueue: false,
      erpConnectorCoupling: false,
      canonicalExpenseWrites: false,
      rawOcrTextStorage: false,
      serverSideContentHash: true,
    })
    expect(serialized).not.toContain('service-role-secret-value')
    expect(serialized).not.toContain('SERVICE_ROLE')
  })

  it('redacts service-role headers for RPC and storage calls', () => {
    const rpcHeaders = buildSupabaseRpcHeaders('service-role-secret-value')
    const storageHeaders = buildSupabaseStorageHeaders('service-role-secret-value')

    expect(redactWorkflowEvidenceWorkerHeaders(rpcHeaders).apikey).toBe('[REDACTED]')
    expect(redactWorkflowEvidenceWorkerHeaders(rpcHeaders).Authorization).toBe('[REDACTED]')
    expect(redactWorkflowEvidenceWorkerHeaders(storageHeaders).apikey).toBe('[REDACTED]')
    expect(JSON.stringify(redactWorkflowEvidenceWorkerHeaders(storageHeaders))).not.toContain(
      'service-role-secret-value',
    )
  })
})

describe('workflow evidence worker storage helpers', () => {
  it('builds encoded private storage object URLs', () => {
    expect(
      buildWorkflowEvidenceObjectUrl(
        'https://example.supabase.co',
        'workflow-evidence',
        'tenant-1/expense receipt/evidence 1.pdf',
      ),
    ).toBe(
      'https://example.supabase.co/storage/v1/object/workflow-evidence/tenant-1/expense%20receipt/evidence%201.pdf',
    )
  })

  it('computes server-side SHA-256 hashes', () => {
    expect(computeSha256Hex(new TextEncoder().encode('receipt-bytes'))).toBe(
      'd6c0441a88ceb80ec9b25000d405a1c9357a51cf3fbedf27e32335f104194c1c',
    )
  })

  it('fetches receipt metadata through the puls_workflow profile', async () => {
    const config = resolveWorkflowEvidenceWorkerConfig(configuredEnv)
    const fetchMock = vi.fn(async (_input: Parameters<typeof fetch>[0], _init?: RequestInit) => {
      return new Response(
        JSON.stringify([
          {
            id: 'receipt-1',
            tenant_id: 'tenant-1',
            expense_claim_id: 'claim-1',
            file_ref: 'tenant-1/expense/evidence.pdf',
            file_name: 'evidence.pdf',
            mime_type: 'application/pdf',
            file_size_bytes: 13,
          },
        ]),
        {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        },
      )
    })

    await expect(
      fetchExpenseReceiptMetadata(config, 'receipt-1', fetchMock),
    ).resolves.toMatchObject({
      id: 'receipt-1',
      file_ref: 'tenant-1/expense/evidence.pdf',
    })

    const firstCall = fetchMock.mock.calls[0]
    if (!firstCall) throw new Error('expected metadata fetch call')
    const init = firstCall[1]
    if (!init) throw new Error('expected metadata fetch options')
    const headers = init.headers as Record<string, string>

    expect(String(firstCall[0])).toContain('/rest/v1/expense_receipts?')
    expect(headers['Accept-Profile']).toBe('puls_workflow')
    expect(headers.Authorization).toBe('Bearer service-role-secret-value')
  })

  it('downloads private evidence objects with service-role storage headers', async () => {
    const config = resolveWorkflowEvidenceWorkerConfig(configuredEnv)
    const fetchMock = vi.fn(async (_input: Parameters<typeof fetch>[0], _init?: RequestInit) => {
      return new Response(new TextEncoder().encode('receipt-bytes'), { status: 200 })
    })

    const bytes = await downloadWorkflowEvidenceObject(
      config,
      'tenant-1/expense/evidence.pdf',
      fetchMock,
    )
    expect(Array.from(bytes)).toEqual(Array.from(new TextEncoder().encode('receipt-bytes')))

    const firstCall = fetchMock.mock.calls[0]
    if (!firstCall) throw new Error('expected storage fetch call')
    const init = firstCall[1]
    if (!init) throw new Error('expected storage fetch options')
    const headers = init.headers as Record<string, string>

    expect(String(firstCall[0])).toBe(
      'https://example.supabase.co/storage/v1/object/workflow-evidence/tenant-1/expense/evidence.pdf',
    )
    expect(headers.Authorization).toBe('Bearer service-role-secret-value')
  })
})

describe('workflow evidence worker contract', () => {
  it('builds disabled provider completion without raw OCR text or external calls', () => {
    const config = resolveWorkflowEvidenceWorkerConfig(configuredEnv)
    const extraction = buildDisabledProviderExtraction(config)
    const args = buildCompletionArgs(
      claimedJob(),
      'workflow-evidence-worker',
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      extraction,
    )
    const serialized = JSON.stringify(args)

    expect(args.p_status).toBe('completed')
    expect(args.p_provider_class).toBe('disabled')
    expect(args.p_mismatch_flags).toContain('provider_disabled')
    expect(serialized).toContain('"external_call":false')
    expect(serialized).toContain('"server_side_content_hash":true')
    expect(serialized).not.toContain('raw_ocr_text')
    expect(serialized).not.toContain('storage_path')
    expect(serialized).not.toContain('signed_url')
  })

  it('runs one claimed job through metadata read, private download, hash, and complete RPC', async () => {
    const config = resolveWorkflowEvidenceWorkerConfig(configuredEnv)
    const rpcCalls: Array<{ fn: string; args: Record<string, unknown> }> = []
    const rpc: WorkflowEvidenceWorkerRpc = async <T>(
      fn: string,
      args: Record<string, unknown>,
    ): Promise<T> => {
      rpcCalls.push({ fn, args })
      if (fn === 'recover_stale_expense_receipt_ocr_jobs') return 0 as T
      if (fn === 'claim_next_expense_receipt_ocr_job') return [claimedJob()] as T
      if (fn === 'heartbeat_expense_receipt_ocr_job') return 'job-1' as T
      if (fn === 'complete_expense_receipt_ocr_job') return 'result-1' as T
      throw new Error(`unexpected rpc ${fn}`)
    }
    const fetchMock = vi.fn(async (url: Parameters<typeof fetch>[0]) => {
      if (String(url).includes('/rest/v1/expense_receipts?')) {
        return new Response(
          JSON.stringify([
            {
              id: 'receipt-1',
              tenant_id: 'tenant-1',
              expense_claim_id: 'claim-1',
              file_ref: 'tenant-1/expense/evidence.pdf',
              file_name: 'evidence.pdf',
              mime_type: 'application/pdf',
              file_size_bytes: 13,
            },
          ]),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        )
      }
      return new Response(new TextEncoder().encode('receipt-bytes'), { status: 200 })
    })

    await expect(runWorkerOnce(config, { rpc, fetchImpl: fetchMock })).resolves.toMatchObject({
      status: 'completed',
      claimed: true,
      jobId: 'job-1',
      resultId: 'result-1',
      serverSha256: 'd6c0441a88ceb80ec9b25000d405a1c9357a51cf3fbedf27e32335f104194c1c',
    })

    const heartbeat = rpcCalls.find((call) => call.fn === 'heartbeat_expense_receipt_ocr_job')
    expect(heartbeat?.args).toMatchObject({
      p_job_id: 'job-1',
      p_worker_id: 'workflow-evidence-worker',
      p_lease_seconds: 300,
      p_safe_error_context: {},
    })

    const completion = rpcCalls.find((call) => call.fn === 'complete_expense_receipt_ocr_job')
    expect(completion?.args).toMatchObject({
      p_job_id: 'job-1',
      p_worker_id: 'workflow-evidence-worker',
      p_status: 'completed',
      p_server_sha256: 'd6c0441a88ceb80ec9b25000d405a1c9357a51cf3fbedf27e32335f104194c1c',
      p_provider_class: 'disabled',
    })
    expect(JSON.stringify(completion?.args)).not.toContain('tenant-1/expense/evidence.pdf')
  })

  it('runs pdf_text extraction locally without external provider calls', async () => {
    const config = resolveWorkflowEvidenceWorkerConfig({
      ...configuredEnv,
      PULS_WORKFLOW_EVIDENCE_PROVIDER_CLASS: 'pdf_text',
    })
    const pdfBytes = new TextEncoder().encode(`%PDF-1.4
BT
(PULS MARKET A.S.) Tj
(FIS NO: ABC123) Tj
(13.06.2026) Tj
(TOPKDV 180,00) Tj
(TOPLAM 1.080,00 TL) Tj
ET
%%EOF`)
    const rpcCalls: Array<{ fn: string; args: Record<string, unknown> }> = []
    const rpc: WorkflowEvidenceWorkerRpc = async <T>(
      fn: string,
      args: Record<string, unknown>,
    ): Promise<T> => {
      rpcCalls.push({ fn, args })
      if (fn === 'recover_stale_expense_receipt_ocr_jobs') return 0 as T
      if (fn === 'claim_next_expense_receipt_ocr_job') {
        return [claimedJob({ provider_class: 'pdf_text' })] as T
      }
      if (fn === 'heartbeat_expense_receipt_ocr_job') return 'job-1' as T
      if (fn === 'complete_expense_receipt_ocr_job') return 'result-1' as T
      throw new Error(`unexpected rpc ${fn}`)
    }
    const fetchMock = vi.fn(async (url: Parameters<typeof fetch>[0]) => {
      if (String(url).includes('/rest/v1/expense_receipts?')) {
        return new Response(
          JSON.stringify([
            {
              id: 'receipt-1',
              tenant_id: 'tenant-1',
              expense_claim_id: 'claim-1',
              file_ref: 'tenant-1/expense/evidence.pdf',
              file_name: 'evidence.pdf',
              mime_type: 'application/pdf',
              file_size_bytes: pdfBytes.byteLength,
            },
          ]),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        )
      }
      return new Response(pdfBytes, { status: 200 })
    })

    await expect(runWorkerOnce(config, { rpc, fetchImpl: fetchMock })).resolves.toMatchObject({
      status: 'completed',
      claimed: true,
      jobId: 'job-1',
      resultId: 'result-1',
    })

    const completion = rpcCalls.find((call) => call.fn === 'complete_expense_receipt_ocr_job')
    expect(completion?.args).toMatchObject({
      p_provider_class: 'pdf_text',
      p_provider_name: 'puls-workflow-evidence-pdf-text',
      p_extracted_fields: {
        merchant_name: 'PULS MARKET A.S.',
        receipt_number: 'ABC123',
        receipt_date: '2026-06-13',
        total_amount: 1080,
        tax_amount: 180,
        currency: 'TRY',
      },
      p_cost_metadata: {
        external_call: false,
        estimated_cost_minor: 0,
        route_used: 'pdf_text',
        text_payload_stored: false,
      },
    })
    expect(JSON.stringify(completion?.args)).not.toContain('raw_ocr_text')
    expect(JSON.stringify(completion?.args)).not.toContain('PULS MARKET A.S.\\n')
  })

  it('fails safely when the claimed job provider class does not match worker config', async () => {
    const config = resolveWorkflowEvidenceWorkerConfig(configuredEnv)
    const rpcCalls: Array<{ fn: string; args: Record<string, unknown> }> = []
    const rpc: WorkflowEvidenceWorkerRpc = async <T>(
      fn: string,
      args: Record<string, unknown>,
    ): Promise<T> => {
      rpcCalls.push({ fn, args })
      if (fn === 'recover_stale_expense_receipt_ocr_jobs') return 0 as T
      if (fn === 'claim_next_expense_receipt_ocr_job') {
        return [claimedJob({ provider_class: 'pdf_text' })] as T
      }
      if (fn === 'complete_expense_receipt_ocr_job') return 'result-1' as T
      throw new Error(`unexpected rpc ${fn}`)
    }

    await expect(runWorkerOnce(config, { rpc })).resolves.toMatchObject({
      status: 'failed',
      claimed: true,
      jobId: 'job-1',
      safeErrorCode: 'ocr_provider_class_mismatch',
    })

    expect(rpcCalls.some((call) => call.fn === 'heartbeat_expense_receipt_ocr_job')).toBe(false)
    const completion = rpcCalls.find((call) => call.fn === 'complete_expense_receipt_ocr_job')
    expect(completion?.args).toMatchObject({
      p_status: 'failed',
      p_safe_error_code: 'ocr_provider_class_mismatch',
      p_retry_after_seconds: null,
    })
  })

  it('marks transient worker failures as retrying instead of final failed', async () => {
    const config = resolveWorkflowEvidenceWorkerConfig(configuredEnv)
    const rpcCalls: Array<{ fn: string; args: Record<string, unknown> }> = []
    const rpc: WorkflowEvidenceWorkerRpc = async <T>(
      fn: string,
      args: Record<string, unknown>,
    ): Promise<T> => {
      rpcCalls.push({ fn, args })
      if (fn === 'recover_stale_expense_receipt_ocr_jobs') return 0 as T
      if (fn === 'claim_next_expense_receipt_ocr_job') return [claimedJob()] as T
      if (fn === 'heartbeat_expense_receipt_ocr_job') return 'job-1' as T
      if (fn === 'complete_expense_receipt_ocr_job') return 'result-1' as T
      throw new Error(`unexpected rpc ${fn}`)
    }
    const fetchMock = vi.fn(async () => {
      return new Response(JSON.stringify({ code: 'temporary_failure' }), {
        status: 503,
        headers: { 'Content-Type': 'application/json' },
      })
    })

    await expect(runWorkerOnce(config, { rpc, fetchImpl: fetchMock })).resolves.toMatchObject({
      status: 'retrying',
      claimed: true,
      jobId: 'job-1',
      safeErrorCode: 'expense_receipt_metadata_fetch_failed',
    })

    const completion = rpcCalls.find((call) => call.fn === 'complete_expense_receipt_ocr_job')
    expect(completion?.args).toMatchObject({
      p_status: 'retrying',
      p_safe_error_code: 'expense_receipt_metadata_fetch_failed',
      p_retry_after_seconds: 120,
      p_safe_error_context: {
        transient: true,
        external_call: false,
        canonical_write: false,
      },
    })
  })

  it('keeps the lease alive across worker phases without overwriting job context', async () => {
    const config = resolveWorkflowEvidenceWorkerConfig(configuredEnv)
    const rpcCalls: Array<{ fn: string; args: Record<string, unknown> }> = []
    const rpc: WorkflowEvidenceWorkerRpc = async <T>(
      fn: string,
      args: Record<string, unknown>,
    ): Promise<T> => {
      rpcCalls.push({ fn, args })
      if (fn === 'recover_stale_expense_receipt_ocr_jobs') return 0 as T
      if (fn === 'claim_next_expense_receipt_ocr_job') return [claimedJob()] as T
      if (fn === 'heartbeat_expense_receipt_ocr_job') return 'job-1' as T
      if (fn === 'complete_expense_receipt_ocr_job') return 'result-1' as T
      throw new Error(`unexpected rpc ${fn}`)
    }
    const fetchMock = vi.fn(async (url: Parameters<typeof fetch>[0]) => {
      if (String(url).includes('/rest/v1/expense_receipts?')) {
        return new Response(
          JSON.stringify([
            {
              id: 'receipt-1',
              tenant_id: 'tenant-1',
              expense_claim_id: 'claim-1',
              file_ref: 'tenant-1/expense/evidence.pdf',
              file_name: 'evidence.pdf',
              mime_type: 'application/pdf',
              file_size_bytes: 13,
            },
          ]),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        )
      }
      return new Response(new TextEncoder().encode('receipt-bytes'), { status: 200 })
    })

    await runWorkerOnce(config, { rpc, fetchImpl: fetchMock })

    const heartbeats = rpcCalls.filter((call) => call.fn === 'heartbeat_expense_receipt_ocr_job')
    expect(heartbeats).toHaveLength(4)
    expect(
      heartbeats.every((call) => JSON.stringify(call.args.p_safe_error_context) === '{}'),
    ).toBe(true)
  })
})
