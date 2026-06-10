import { supabase } from '#/lib/supabase'
import type { PostgrestError } from '@supabase/supabase-js'
import { DataAdapterError, fromRpcError, fromSupabaseError } from '#/lib/data/errors'
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

export type WorkflowEvidenceAttachment = {
  id: string
  domain: WorkflowEvidenceDomain
  parentId: string
  storageBucket: string
  storagePath: string
  fileName: string
  mimeType: string | null
  fileSizeBytes: number | null
  uploadedByEmployeeId: string | null
  attachedAt: string | null
  scanStatus: string
}

export type ExpenseReceiptOcrReviewStatus =
  | 'not_ready'
  | 'pending_review'
  | 'accepted'
  | 'corrected'
  | 'rejected'
  | 'needs_new_document'

export type ExpenseReceiptOcrReviewDecision = Extract<
  ExpenseReceiptOcrReviewStatus,
  'accepted' | 'corrected' | 'rejected' | 'needs_new_document'
>

export type ExpenseReceiptOcrReview = {
  id: string
  expenseReceiptId: string
  expenseClaimId: string
  jobId: string
  serverSha256: string | null
  duplicateOfResultId: string | null
  extractedFields: Record<string, unknown>
  fieldConfidence: Record<string, number>
  documentConfidence: number | null
  mismatchFlags: string[]
  providerClass: string
  providerName: string | null
  providerVersion: string | null
  costMetadata: Record<string, unknown>
  reviewStatus: ExpenseReceiptOcrReviewStatus
  reviewedByEmployeeId: string | null
  reviewedAt: string | null
  reviewNote: string | null
  correctedFields: Record<string, unknown>
  createdAt: string | null
}

export type RecordExpenseReceiptOcrReviewInput = {
  resultId: string
  reviewStatus: ExpenseReceiptOcrReviewDecision
  reviewNote?: string | null
  correctedFields?: Record<string, unknown>
}

export type RecordExpenseReceiptOcrReviewResult = {
  ocrResultId: string
  expenseReceiptId: string
  expenseClaimId: string
  reviewStatus: ExpenseReceiptOcrReviewStatus
  reviewedAt: string | null
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

const WORKFLOW_EVIDENCE_TABLES: Record<
  WorkflowEvidenceDomain,
  { table: string; parentColumn: string; operation: string }
> = {
  leave: {
    table: 'leave_documents',
    parentColumn: 'leave_request_id',
    operation: 'fetchLeaveEvidenceAttachments',
  },
  expense: {
    table: 'expense_receipts',
    parentColumn: 'expense_claim_id',
    operation: 'fetchExpenseEvidenceAttachments',
  },
  contract: {
    table: 'contract_files',
    parentColumn: 'contract_id',
    operation: 'fetchContractEvidenceAttachments',
  },
}

type WorkflowEvidenceSelectResult = {
  data: Record<string, unknown>[] | null
  error: PostgrestError | null
}

type WorkflowEvidenceQuery = {
  select: (columns: string) => {
    in: (
      column: string,
      values: string[],
    ) => {
      order: (
        column: string,
        options: { ascending: boolean },
      ) => Promise<WorkflowEvidenceSelectResult>
    }
  }
}

type ExpenseReceiptOcrReviewQuery = {
  select: (columns: string) => {
    in: (
      column: string,
      values: string[],
    ) => {
      order: (
        column: string,
        options: { ascending: boolean },
      ) => Promise<WorkflowEvidenceSelectResult>
    }
  }
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

function toRecord(value: unknown): Record<string, unknown> {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) return {}
  return value as Record<string, unknown>
}

function toNumberRecord(value: unknown): Record<string, number> {
  const row = toRecord(value)
  const output: Record<string, number> = {}
  for (const [key, raw] of Object.entries(row)) {
    const numberValue = typeof raw === 'number' ? raw : Number(raw)
    if (Number.isFinite(numberValue)) output[key] = numberValue
  }
  return output
}

function toStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return []
  return value.filter((item): item is string => typeof item === 'string' && item.trim().length > 0)
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

function parseReviewRpcResult(data: unknown): RecordExpenseReceiptOcrReviewResult {
  const operation = 'recordExpenseReceiptOcrReview'
  if (data === null || typeof data !== 'object' || Array.isArray(data)) {
    throw invalidEvidenceResult(operation, 'Review RPC result is not an object')
  }

  const row = data as Record<string, unknown>
  return {
    ocrResultId: requireResultString(row, 'ocr_result_id', operation),
    expenseReceiptId: requireResultString(row, 'expense_receipt_id', operation),
    expenseClaimId: requireResultString(row, 'expense_claim_id', operation),
    reviewStatus: requireResultString(row, 'review_status', operation) as ExpenseReceiptOcrReviewStatus,
    reviewedAt: typeof row.reviewed_at === 'string' ? row.reviewed_at : null,
  }
}

export function getWorkflowEvidenceFilePolicy(
  domain: WorkflowEvidenceDomain,
): WorkflowEvidenceFilePolicy {
  return WORKFLOW_EVIDENCE_POLICIES[domain]
}

export function mapWorkflowEvidenceAttachmentRow(
  domain: WorkflowEvidenceDomain,
  row: Record<string, unknown>,
): WorkflowEvidenceAttachment {
  const parentField =
    domain === 'leave'
      ? 'leave_request_id'
      : domain === 'expense'
        ? 'expense_claim_id'
        : 'contract_id'

  return {
    id: String(row.id ?? ''),
    domain,
    parentId: String(row[parentField] ?? ''),
    storageBucket: 'workflow-evidence',
    storagePath: String(row.file_ref ?? ''),
    fileName: String(row.file_name ?? 'evidence'),
    mimeType: typeof row.mime_type === 'string' ? row.mime_type : null,
    fileSizeBytes:
      row.file_size_bytes === null || row.file_size_bytes === undefined
        ? null
        : Number(row.file_size_bytes),
    uploadedByEmployeeId:
      typeof row.uploaded_by_employee_id === 'string' ? row.uploaded_by_employee_id : null,
    attachedAt: typeof row.created_at === 'string' ? row.created_at : null,
    scanStatus: 'not_scanned',
  }
}

export function groupWorkflowEvidenceByParent(
  attachments: readonly WorkflowEvidenceAttachment[],
): Map<string, WorkflowEvidenceAttachment[]> {
  const grouped = new Map<string, WorkflowEvidenceAttachment[]>()
  for (const attachment of attachments) {
    const current = grouped.get(attachment.parentId) ?? []
    current.push(attachment)
    grouped.set(attachment.parentId, current)
  }
  return grouped
}

export function mapExpenseReceiptOcrReviewRow(
  row: Record<string, unknown>,
): ExpenseReceiptOcrReview {
  const documentConfidence = Number(row.document_confidence)

  return {
    id: String(row.id ?? ''),
    expenseReceiptId: String(row.expense_receipt_id ?? ''),
    expenseClaimId: String(row.expense_claim_id ?? ''),
    jobId: String(row.job_id ?? ''),
    serverSha256: typeof row.server_sha256 === 'string' ? row.server_sha256 : null,
    duplicateOfResultId:
      typeof row.duplicate_of_result_id === 'string' ? row.duplicate_of_result_id : null,
    extractedFields: toRecord(row.extracted_fields),
    fieldConfidence: toNumberRecord(row.field_confidence),
    documentConfidence: Number.isFinite(documentConfidence) ? documentConfidence : null,
    mismatchFlags: toStringArray(row.mismatch_flags),
    providerClass: typeof row.provider_class === 'string' ? row.provider_class : 'disabled',
    providerName: typeof row.provider_name === 'string' ? row.provider_name : null,
    providerVersion: typeof row.provider_version === 'string' ? row.provider_version : null,
    costMetadata: toRecord(row.cost_metadata),
    reviewStatus:
      typeof row.review_status === 'string'
        ? (row.review_status as ExpenseReceiptOcrReviewStatus)
        : 'not_ready',
    reviewedByEmployeeId:
      typeof row.reviewed_by_employee_id === 'string' ? row.reviewed_by_employee_id : null,
    reviewedAt: typeof row.reviewed_at === 'string' ? row.reviewed_at : null,
    reviewNote: typeof row.review_note === 'string' ? row.review_note : null,
    correctedFields: toRecord(row.corrected_fields),
    createdAt: typeof row.created_at === 'string' ? row.created_at : null,
  }
}

export function groupExpenseReceiptOcrReviewsByReceipt(
  reviews: readonly ExpenseReceiptOcrReview[],
): Map<string, ExpenseReceiptOcrReview[]> {
  const grouped = new Map<string, ExpenseReceiptOcrReview[]>()
  for (const review of reviews) {
    const current = grouped.get(review.expenseReceiptId) ?? []
    current.push(review)
    grouped.set(review.expenseReceiptId, current)
  }
  return grouped
}

export async function fetchWorkflowEvidenceAttachments(
  domain: WorkflowEvidenceDomain,
  parentIds: readonly string[],
): Promise<Map<string, WorkflowEvidenceAttachment[]>> {
  const ids = Array.from(new Set(parentIds.filter((id) => id.trim().length > 0)))
  if (ids.length === 0) return new Map()

  const config = WORKFLOW_EVIDENCE_TABLES[domain]
  const evidenceTable = pulsWorkflow().from(config.table as never) as unknown as WorkflowEvidenceQuery
  const { data, error } = await evidenceTable
    .select(
      `
      id,
      ${config.parentColumn},
      uploaded_by_employee_id,
      file_ref,
      file_name,
      mime_type,
      file_size_bytes,
      created_at
    `,
    )
    .in(config.parentColumn, ids)
    .order('created_at', { ascending: false })

  if (error) {
    throw fromSupabaseError(error, config.operation, 'puls_workflow', config.table)
  }

  return groupWorkflowEvidenceByParent(
    (data ?? []).map((row) => mapWorkflowEvidenceAttachmentRow(domain, row)),
  )
}

export async function fetchExpenseReceiptOcrReviews(
  expenseReceiptIds: readonly string[],
): Promise<Map<string, ExpenseReceiptOcrReview[]>> {
  const ids = Array.from(new Set(expenseReceiptIds.filter((id) => id.trim().length > 0)))
  if (ids.length === 0) return new Map()

  const reviewTable = pulsWorkflow().from(
    'expense_receipt_ocr_results' as never,
  ) as unknown as ExpenseReceiptOcrReviewQuery
  const { data, error } = await reviewTable
    .select(
      `
      id,
      expense_receipt_id,
      expense_claim_id,
      job_id,
      server_sha256,
      duplicate_of_result_id,
      extracted_fields,
      field_confidence,
      document_confidence,
      mismatch_flags,
      provider_class,
      provider_name,
      provider_version,
      cost_metadata,
      review_status,
      reviewed_by_employee_id,
      reviewed_at,
      review_note,
      corrected_fields,
      created_at
    `,
    )
    .in('expense_receipt_id', ids)
    .order('created_at', { ascending: false })

  if (error) {
    throw fromSupabaseError(
      error,
      'fetchExpenseReceiptOcrReviews',
      'puls_workflow',
      'expense_receipt_ocr_results',
    )
  }

  return groupExpenseReceiptOcrReviewsByReceipt(
    (data ?? []).map((row) => mapExpenseReceiptOcrReviewRow(row)),
  )
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

export async function createWorkflowEvidenceSignedUrl(
  attachment: WorkflowEvidenceAttachment,
  expiresInSeconds = 120,
): Promise<string> {
  const { data, error } = await supabase.storage
    .from(attachment.storageBucket)
    .createSignedUrl(attachment.storagePath, expiresInSeconds)

  if (error || !data?.signedUrl) {
    throw new DataAdapterError({
      code: 'storage_signed_url_failed',
      message: error?.message ?? 'Signed URL could not be created.',
      source: 'supabase',
      operation: 'createWorkflowEvidenceSignedUrl',
      schema: 'storage',
      table: attachment.storageBucket,
      i18nKey: 'workflowEvidence.error.viewFailed',
    })
  }

  return data.signedUrl
}

export async function recordExpenseReceiptOcrReview(
  userId: string,
  input: RecordExpenseReceiptOcrReviewInput,
): Promise<RecordExpenseReceiptOcrReviewResult> {
  const ctx = await resolveTenantContext(userId)
  if (!ctx.employeeId) {
    throw new DataAdapterError({
      code: 'PULS_AUTH_REQUIRED',
      message: 'workflowEvidence.ocr.error.reviewFailed',
      source: 'adapter',
      operation: 'recordExpenseReceiptOcrReview',
      i18nKey: 'workflowEvidence.ocr.error.reviewFailed',
    })
  }

  const { data, error } = await pulsWorkflow().rpc('record_expense_receipt_ocr_review', {
    p_result_id: input.resultId,
    p_review_status: input.reviewStatus,
    p_review_note: input.reviewNote ?? null,
    p_corrected_fields: input.correctedFields ?? {},
  })

  if (error) {
    throw fromRpcError(
      error,
      'recordExpenseReceiptOcrReview',
      'workflowEvidence.ocr.error.reviewFailed',
    )
  }

  return parseReviewRpcResult(data)
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
