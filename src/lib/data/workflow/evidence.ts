import { supabase } from '#/lib/supabase'
import { DataAdapterError, fromRpcError } from '#/lib/data/errors'
import { pulsWorkflow, resolveTenantContext } from '#/lib/data/client'

export type WorkflowEvidenceDomain = 'leave' | 'expense' | 'contract'

export type WorkflowEvidenceUpload = {
  evidenceUploadId: string
  storageBucket: string
  storagePath: string
  fileName: string
  mimeType: string
  fileSizeBytes: number
  sha256Client: string
  scanStatus: string
}

export type WorkflowEvidenceFilePolicy = {
  accept: string
  maxBytes: number
  mimeTypes: readonly string[]
}

export type UploadWorkflowEvidenceInput = {
  domain: WorkflowEvidenceDomain
  file: File
  subjectId?: string | null
}

const TEN_MB = 10 * 1024 * 1024
const FIFTEEN_MB = 15 * 1024 * 1024

const WORKFLOW_EVIDENCE_POLICIES: Record<WorkflowEvidenceDomain, WorkflowEvidenceFilePolicy> = {
  leave: {
    accept: 'application/pdf,image/png,image/jpeg',
    maxBytes: TEN_MB,
    mimeTypes: ['application/pdf', 'image/png', 'image/jpeg'],
  },
  expense: {
    accept: 'application/pdf,image/png,image/jpeg',
    maxBytes: TEN_MB,
    mimeTypes: ['application/pdf', 'image/png', 'image/jpeg'],
  },
  contract: {
    accept: 'application/pdf',
    maxBytes: FIFTEEN_MB,
    mimeTypes: ['application/pdf'],
  },
}

function invalidEvidenceResult(operation: string, message: string): DataAdapterError {
  return new DataAdapterError({
    code: 'invalid_rpc_result',
    message,
    source: 'adapter',
    operation,
    i18nKey: 'workflowEvidence.error.uploadFailed',
  })
}

function requireResultString(
  row: Record<string, unknown>,
  field: string,
  operation: string,
): string {
  const value = row[field]
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw invalidEvidenceResult(operation, `Missing or invalid ${field}`)
  }
  return value
}

function parseEvidenceRpcResult(
  data: unknown,
  operation: string,
): Pick<
  WorkflowEvidenceUpload,
  'evidenceUploadId' | 'storageBucket' | 'storagePath' | 'scanStatus'
> {
  if (data === null || typeof data !== 'object' || Array.isArray(data)) {
    throw invalidEvidenceResult(operation, 'Evidence RPC result is not an object')
  }

  const row = data as Record<string, unknown>
  return {
    evidenceUploadId: requireResultString(row, 'evidence_upload_id', operation),
    storageBucket: requireResultString(row, 'storage_bucket', operation),
    storagePath: requireResultString(row, 'storage_path', operation),
    scanStatus: requireResultString(row, 'scan_status', operation),
  }
}

export function getWorkflowEvidenceFilePolicy(
  domain: WorkflowEvidenceDomain,
): WorkflowEvidenceFilePolicy {
  return WORKFLOW_EVIDENCE_POLICIES[domain]
}

export function validateWorkflowEvidenceFile(
  domain: WorkflowEvidenceDomain,
  file: File,
): 'type' | 'size' | null {
  const policy = getWorkflowEvidenceFilePolicy(domain)
  if (!policy.mimeTypes.includes(file.type)) return 'type'
  if (file.size <= 0 || file.size > policy.maxBytes) return 'size'
  return null
}

export async function computeWorkflowEvidenceSha256(file: File): Promise<string> {
  const buffer = await file.arrayBuffer()
  const digest = await crypto.subtle.digest('SHA-256', buffer)
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('')
}

export async function uploadWorkflowEvidenceFile(
  userId: string,
  input: UploadWorkflowEvidenceInput,
): Promise<WorkflowEvidenceUpload> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.employeeId) {
    throw new DataAdapterError({
      code: 'PULS_AUTH_REQUIRED',
      message: 'workflowEvidence.error.authRequired',
      source: 'adapter',
      operation: 'uploadWorkflowEvidenceFile',
      i18nKey: 'workflowEvidence.error.authRequired',
    })
  }

  const validation = validateWorkflowEvidenceFile(input.domain, input.file)
  if (validation) {
    throw new DataAdapterError({
      code:
        validation === 'type'
          ? 'PULS_EVIDENCE_MIME_TYPE_INVALID'
          : 'PULS_EVIDENCE_FILE_SIZE_INVALID',
      message:
        validation === 'type'
          ? 'workflowEvidence.error.fileType'
          : 'workflowEvidence.error.fileSize',
      source: 'adapter',
      operation: 'uploadWorkflowEvidenceFile',
      i18nKey:
        validation === 'type'
          ? 'workflowEvidence.error.fileType'
          : 'workflowEvidence.error.fileSize',
    })
  }

  const sha256Client = await computeWorkflowEvidenceSha256(input.file)
  const intent = await pulsWorkflow().rpc('create_workflow_evidence_upload_intent', {
    p_domain: input.domain,
    p_original_file_name: input.file.name,
    p_mime_type: input.file.type,
    p_file_size_bytes: input.file.size,
    p_sha256_client: sha256Client,
    p_subject_id: input.subjectId ?? null,
  })

  if (intent.error) {
    throw fromRpcError(
      intent.error,
      'uploadWorkflowEvidenceFile',
      'workflowEvidence.error.uploadFailed',
    )
  }

  const parsedIntent = parseEvidenceRpcResult(intent.data, 'uploadWorkflowEvidenceFile')
  const { error: uploadError } = await supabase.storage
    .from(parsedIntent.storageBucket)
    .upload(parsedIntent.storagePath, input.file, {
      contentType: input.file.type,
      upsert: false,
    })

  if (uploadError) {
    throw new DataAdapterError({
      code: 'storage_upload_failed',
      message: uploadError.message,
      source: 'supabase',
      operation: 'uploadWorkflowEvidenceFile',
      schema: 'storage',
      table: parsedIntent.storageBucket,
      i18nKey: 'workflowEvidence.error.uploadFailed',
    })
  }

  const finalized = await pulsWorkflow().rpc('finalize_workflow_evidence_upload', {
    p_evidence_upload_id: parsedIntent.evidenceUploadId,
    p_file_size_bytes: input.file.size,
    p_mime_type: input.file.type,
    p_sha256_client: sha256Client,
  })

  if (finalized.error) {
    throw fromRpcError(
      finalized.error,
      'uploadWorkflowEvidenceFile',
      'workflowEvidence.error.uploadFailed',
    )
  }

  const parsedFinalized = parseEvidenceRpcResult(finalized.data, 'uploadWorkflowEvidenceFile')
  return {
    ...parsedFinalized,
    fileName: input.file.name,
    mimeType: input.file.type,
    fileSizeBytes: input.file.size,
    sha256Client,
  }
}

export async function attachContractFileEvidence(
  userId: string,
  contractId: string,
  evidenceUploadId: string,
): Promise<{ contractFileId: string; evidenceUploadId: string; status: string }> {
  const ctx = await resolveTenantContext(userId)
  if (ctx.personaRole !== 'hr_admin' && ctx.personaRole !== 'superadmin') {
    throw new DataAdapterError({
      code: 'PULS_ADMIN_REQUIRED',
      message: 'workflowEvidence.error.adminRequired',
      source: 'adapter',
      operation: 'attachContractFileEvidence',
      i18nKey: 'workflowEvidence.error.adminRequired',
    })
  }

  const { data, error } = await pulsWorkflow().rpc('attach_contract_file_evidence', {
    p_evidence_upload_id: evidenceUploadId,
    p_contract_id: contractId,
  })

  if (error) {
    throw fromRpcError(error, 'attachContractFileEvidence', 'workflowEvidence.error.attachFailed')
  }

  if (data === null || typeof data !== 'object' || Array.isArray(data)) {
    throw invalidEvidenceResult('attachContractFileEvidence', 'Attach RPC result is not an object')
  }

  const row = data as Record<string, unknown>
  return {
    contractFileId: requireResultString(row, 'contract_file_id', 'attachContractFileEvidence'),
    evidenceUploadId: requireResultString(row, 'evidence_upload_id', 'attachContractFileEvidence'),
    status: requireResultString(row, 'status', 'attachContractFileEvidence'),
  }
}
