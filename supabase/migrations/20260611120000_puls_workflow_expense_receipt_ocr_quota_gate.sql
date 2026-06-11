-- PR17.2G4A: expense receipt OCR tenant posture and quota gate.
--
-- This slice keeps production OCR closed by default. It adds server-side
-- tenant/global posture controls and hardens the service-role enqueue RPC so a
-- worker or operator cannot queue OCR work unless tenant flags, quotas, spend
-- caps, file/page limits, and provider allowlists explicitly allow it.

CREATE TABLE IF NOT EXISTS puls_workflow.expense_receipt_ocr_tenant_posture (
  tenant_id UUID PRIMARY KEY REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  enabled BOOLEAN NOT NULL DEFAULT FALSE,
  monthly_document_quota INTEGER NOT NULL DEFAULT 0,
  monthly_spend_cap_minor INTEGER NOT NULL DEFAULT 0,
  spend_currency TEXT NOT NULL DEFAULT 'USD',
  max_pages_per_document INTEGER NOT NULL DEFAULT 1,
  max_file_size_bytes BIGINT NOT NULL DEFAULT 10485760,
  max_normalized_image_pixels INTEGER NOT NULL DEFAULT 2000000,
  provider_class_allowlist puls_workflow.expense_receipt_ocr_provider_class[] NOT NULL DEFAULT ARRAY[]::puls_workflow.expense_receipt_ocr_provider_class[],
  provider_model_allowlist TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  region_label TEXT NOT NULL DEFAULT 'unset',
  retention_policy_label TEXT NOT NULL DEFAULT 'unset',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (monthly_document_quota >= 0),
  CHECK (monthly_spend_cap_minor >= 0),
  CHECK (spend_currency = UPPER(BTRIM(spend_currency)) AND spend_currency ~ '^[A-Z]{3}$'),
  CHECK (max_pages_per_document BETWEEN 1 AND 1000),
  CHECK (max_file_size_bytes BETWEEN 1 AND 52428800),
  CHECK (max_normalized_image_pixels BETWEEN 1 AND 50000000),
  CHECK (region_label = BTRIM(region_label) AND region_label <> ''),
  CHECK (retention_policy_label = BTRIM(retention_policy_label) AND retention_policy_label <> '')
);

CREATE TABLE IF NOT EXISTS puls_workflow.expense_receipt_ocr_global_posture (
  singleton BOOLEAN PRIMARY KEY DEFAULT TRUE,
  monthly_spend_cap_minor INTEGER NOT NULL DEFAULT 0,
  spend_currency TEXT NOT NULL DEFAULT 'USD',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (singleton),
  CHECK (monthly_spend_cap_minor >= 0),
  CHECK (spend_currency = UPPER(BTRIM(spend_currency)) AND spend_currency ~ '^[A-Z]{3}$')
);

ALTER TABLE puls_workflow.expense_receipt_ocr_jobs
  ADD COLUMN IF NOT EXISTS estimated_cost_minor INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS estimated_cost_currency TEXT NOT NULL DEFAULT 'USD',
  ADD COLUMN IF NOT EXISTS document_page_count INTEGER NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS normalized_image_pixels INTEGER NULL;

ALTER TABLE puls_workflow.expense_receipt_ocr_jobs
  ADD CONSTRAINT expense_receipt_ocr_jobs_estimated_cost_minor_check CHECK (estimated_cost_minor >= 0),
  ADD CONSTRAINT expense_receipt_ocr_jobs_estimated_cost_currency_check CHECK (
    estimated_cost_currency = UPPER(BTRIM(estimated_cost_currency))
    AND estimated_cost_currency ~ '^[A-Z]{3}$'
  ),
  ADD CONSTRAINT expense_receipt_ocr_jobs_document_page_count_check CHECK (document_page_count BETWEEN 1 AND 1000),
  ADD CONSTRAINT expense_receipt_ocr_jobs_normalized_image_pixels_check CHECK (
    normalized_image_pixels IS NULL
    OR normalized_image_pixels BETWEEN 1 AND 50000000
  );

ALTER TABLE puls_workflow.expense_receipt_ocr_results
  ADD COLUMN IF NOT EXISTS estimated_cost_minor INTEGER NULL,
  ADD COLUMN IF NOT EXISTS actual_cost_minor INTEGER NULL,
  ADD COLUMN IF NOT EXISTS cost_currency TEXT NULL;

ALTER TABLE puls_workflow.expense_receipt_ocr_results
  ADD CONSTRAINT expense_receipt_ocr_results_estimated_cost_minor_check CHECK (
    estimated_cost_minor IS NULL
    OR estimated_cost_minor >= 0
  ),
  ADD CONSTRAINT expense_receipt_ocr_results_actual_cost_minor_check CHECK (
    actual_cost_minor IS NULL
    OR actual_cost_minor >= 0
  ),
  ADD CONSTRAINT expense_receipt_ocr_results_cost_currency_check CHECK (
    cost_currency IS NULL
    OR (cost_currency = UPPER(BTRIM(cost_currency)) AND cost_currency ~ '^[A-Z]{3}$')
  );

DROP FUNCTION IF EXISTS puls_workflow.enqueue_expense_receipt_ocr_job(
  UUID,
  TEXT,
  puls_workflow.expense_receipt_ocr_provider_class,
  INTEGER,
  TIMESTAMPTZ,
  INTEGER,
  JSONB,
  TEXT
);

CREATE OR REPLACE FUNCTION puls_workflow.enqueue_expense_receipt_ocr_job(
  p_expense_receipt_id UUID,
  p_idempotency_key TEXT DEFAULT NULL,
  p_provider_class puls_workflow.expense_receipt_ocr_provider_class DEFAULT 'disabled'::puls_workflow.expense_receipt_ocr_provider_class,
  p_priority INTEGER DEFAULT 100,
  p_scheduled_at TIMESTAMPTZ DEFAULT NOW(),
  p_max_attempts INTEGER DEFAULT 3,
  p_safe_error_context JSONB DEFAULT '{}'::JSONB,
  p_next_action_key TEXT DEFAULT 'review_expense_receipt_ocr_status',
  p_estimated_cost_minor INTEGER DEFAULT 0,
  p_estimated_cost_currency TEXT DEFAULT 'USD',
  p_provider_name TEXT DEFAULT NULL,
  p_provider_version TEXT DEFAULT NULL,
  p_document_page_count INTEGER DEFAULT 1,
  p_normalized_image_pixels INTEGER DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core
AS $$
DECLARE
  v_receipt puls_workflow.expense_receipts%ROWTYPE;
  v_claim puls_workflow.expense_claims%ROWTYPE;
  v_job puls_workflow.expense_receipt_ocr_jobs%ROWTYPE;
  v_posture puls_workflow.expense_receipt_ocr_tenant_posture%ROWTYPE;
  v_global_posture puls_workflow.expense_receipt_ocr_global_posture%ROWTYPE;
  v_idempotency_key TEXT;
  v_concurrency_key TEXT;
  v_context JSONB := COALESCE(p_safe_error_context, '{}'::JSONB);
  v_provider_class puls_workflow.expense_receipt_ocr_provider_class :=
    COALESCE(p_provider_class, 'disabled'::puls_workflow.expense_receipt_ocr_provider_class);
  v_provider_name TEXT := NULLIF(BTRIM(COALESCE(p_provider_name, '')), '');
  v_provider_version TEXT := NULLIF(BTRIM(COALESCE(p_provider_version, '')), '');
  v_estimated_cost_minor INTEGER := COALESCE(p_estimated_cost_minor, 0);
  v_estimated_cost_currency TEXT := UPPER(BTRIM(COALESCE(p_estimated_cost_currency, 'USD')));
  v_document_page_count INTEGER := COALESCE(p_document_page_count, 1);
  v_normalized_image_pixels INTEGER := p_normalized_image_pixels;
  v_month_start TIMESTAMPTZ := date_trunc('month', NOW());
  v_month_document_count INTEGER;
  v_tenant_month_spend_minor BIGINT;
  v_global_month_spend_minor BIGINT;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'PULS_SERVICE_ROLE_REQUIRED: Service role is required to enqueue expense receipt OCR jobs.'
      USING ERRCODE = 'P0001';
  END IF;

  IF p_expense_receipt_id IS NULL THEN
    RAISE EXCEPTION 'PULS_OCR_RECEIPT_REQUIRED: Expense receipt id is required.'
      USING ERRCODE = 'P0001';
  END IF;

  IF jsonb_typeof(v_context) <> 'object'
     OR puls_workflow.expense_receipt_ocr_safe_context_has_blocked_key(v_context) THEN
    RAISE EXCEPTION 'PULS_OCR_SAFE_CONTEXT_INVALID: OCR job context contains unsafe keys.'
      USING ERRCODE = 'P0001';
  END IF;

  IF p_priority IS NULL OR p_priority < 0 THEN
    RAISE EXCEPTION 'PULS_OCR_PRIORITY_INVALID: OCR priority must be a non-negative integer.'
      USING ERRCODE = 'P0001';
  END IF;

  IF p_max_attempts IS NULL OR p_max_attempts < 1 OR p_max_attempts > 10 THEN
    RAISE EXCEPTION 'PULS_OCR_MAX_ATTEMPTS_INVALID: OCR max attempts must be between 1 and 10.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_estimated_cost_minor < 0 THEN
    RAISE EXCEPTION 'PULS_OCR_ESTIMATED_COST_INVALID: OCR estimated cost must be non-negative.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_estimated_cost_currency !~ '^[A-Z]{3}$' THEN
    RAISE EXCEPTION 'PULS_OCR_COST_CURRENCY_INVALID: OCR cost currency must be an ISO currency code.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_document_page_count < 1 OR v_document_page_count > 1000 THEN
    RAISE EXCEPTION 'PULS_OCR_PAGE_COUNT_INVALID: OCR document page count is out of range.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_normalized_image_pixels IS NOT NULL
     AND (v_normalized_image_pixels < 1 OR v_normalized_image_pixels > 50000000) THEN
    RAISE EXCEPTION 'PULS_OCR_IMAGE_PIXELS_INVALID: OCR normalized image pixels is out of range.'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT *
  INTO v_receipt
  FROM puls_workflow.expense_receipts
  WHERE id = p_expense_receipt_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_OCR_RECEIPT_NOT_FOUND: Expense receipt was not found.'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT *
  INTO v_claim
  FROM puls_workflow.expense_claims
  WHERE id = v_receipt.expense_claim_id
    AND tenant_id = v_receipt.tenant_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_OCR_CLAIM_NOT_FOUND: Expense claim was not found for receipt.'
      USING ERRCODE = 'P0001';
  END IF;

  v_idempotency_key := COALESCE(NULLIF(BTRIM(p_idempotency_key), ''), 'expense_receipt_ocr:v1:' || v_receipt.id::TEXT);
  v_concurrency_key := 'expense_receipt_ocr:' || v_receipt.id::TEXT;

  SELECT *
  INTO v_job
  FROM puls_workflow.expense_receipt_ocr_jobs
  WHERE tenant_id = v_receipt.tenant_id
    AND idempotency_key = v_idempotency_key;

  IF FOUND THEN
    PERFORM puls_workflow._record_expense_receipt_ocr_job_event(
      v_job,
      'expense_receipt_ocr.job_enqueue_idempotent_hit',
      NULL,
      NULL,
      jsonb_build_object(
        'provider_class', v_job.provider_class::TEXT,
        'quota_gate_enforced', TRUE,
        'idempotent_hit', TRUE
      ),
      NULL,
      FALSE
    );

    RETURN v_job.id;
  END IF;

  SELECT *
  INTO v_posture
  FROM puls_workflow.expense_receipt_ocr_tenant_posture posture
  WHERE posture.tenant_id = v_receipt.tenant_id
  FOR UPDATE;

  IF NOT FOUND OR NOT v_posture.enabled THEN
    RAISE EXCEPTION 'PULS_OCR_TENANT_DISABLED: Expense receipt OCR is disabled for this tenant.'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT *
  INTO v_global_posture
  FROM puls_workflow.expense_receipt_ocr_global_posture posture
  WHERE posture.singleton IS TRUE
  FOR UPDATE;

  IF NOT FOUND THEN
    v_global_posture.monthly_spend_cap_minor := 0;
    v_global_posture.spend_currency := v_posture.spend_currency;
  END IF;

  IF v_estimated_cost_currency IS DISTINCT FROM v_posture.spend_currency
     OR v_estimated_cost_currency IS DISTINCT FROM v_global_posture.spend_currency THEN
    RAISE EXCEPTION 'PULS_OCR_COST_CURRENCY_INVALID: OCR cost currency does not match configured spend currency.'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT (v_provider_class = ANY(v_posture.provider_class_allowlist)) THEN
    RAISE EXCEPTION 'PULS_OCR_PROVIDER_CLASS_NOT_ALLOWED: OCR provider class is not allowed for this tenant.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_provider_class = 'external'::puls_workflow.expense_receipt_ocr_provider_class
     AND v_provider_name IS NULL THEN
    RAISE EXCEPTION 'PULS_OCR_PROVIDER_NAME_REQUIRED: External OCR providers require a provider name.'
      USING ERRCODE = 'P0001';
  END IF;

  IF array_length(v_posture.provider_model_allowlist, 1) IS NOT NULL
     AND v_provider_name IS NOT NULL
     AND NOT (v_provider_name = ANY(v_posture.provider_model_allowlist)) THEN
    RAISE EXCEPTION 'PULS_OCR_PROVIDER_MODEL_NOT_ALLOWED: OCR provider model is not allowed for this tenant.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_receipt.file_size_bytes > v_posture.max_file_size_bytes THEN
    RAISE EXCEPTION 'PULS_OCR_FILE_TOO_LARGE: Expense receipt exceeds the tenant OCR file-size limit.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_document_page_count > v_posture.max_pages_per_document THEN
    RAISE EXCEPTION 'PULS_OCR_PAGE_LIMIT_EXCEEDED: Expense receipt exceeds the tenant OCR page limit.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_normalized_image_pixels IS NOT NULL
     AND v_normalized_image_pixels > v_posture.max_normalized_image_pixels THEN
    RAISE EXCEPTION 'PULS_OCR_IMAGE_LIMIT_EXCEEDED: Expense receipt exceeds the tenant OCR image-size limit.'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT COUNT(*)
  INTO v_month_document_count
  FROM puls_workflow.expense_receipt_ocr_jobs job
  WHERE job.tenant_id = v_receipt.tenant_id
    AND job.created_at >= v_month_start;

  IF v_posture.monthly_document_quota <= 0
     OR v_month_document_count >= v_posture.monthly_document_quota THEN
    RAISE EXCEPTION 'PULS_OCR_QUOTA_EXHAUSTED: Tenant monthly OCR document quota is exhausted.'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT COALESCE(SUM(job.estimated_cost_minor), 0)
  INTO v_tenant_month_spend_minor
  FROM puls_workflow.expense_receipt_ocr_jobs job
  WHERE job.tenant_id = v_receipt.tenant_id
    AND job.estimated_cost_currency = v_estimated_cost_currency
    AND job.created_at >= v_month_start;

  IF v_estimated_cost_minor > 0
     AND (
       v_posture.monthly_spend_cap_minor <= 0
       OR v_tenant_month_spend_minor + v_estimated_cost_minor > v_posture.monthly_spend_cap_minor
     ) THEN
    RAISE EXCEPTION 'PULS_OCR_SPEND_CAP_EXCEEDED: Tenant monthly OCR spend cap would be exceeded.'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT COALESCE(SUM(job.estimated_cost_minor), 0)
  INTO v_global_month_spend_minor
  FROM puls_workflow.expense_receipt_ocr_jobs job
  WHERE job.estimated_cost_currency = v_estimated_cost_currency
    AND job.created_at >= v_month_start;

  IF v_estimated_cost_minor > 0
     AND (
       v_global_posture.monthly_spend_cap_minor <= 0
       OR v_global_month_spend_minor + v_estimated_cost_minor > v_global_posture.monthly_spend_cap_minor
     ) THEN
    RAISE EXCEPTION 'PULS_OCR_GLOBAL_SPEND_CAP_EXCEEDED: Global monthly OCR spend cap would be exceeded.'
      USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO puls_workflow.expense_receipt_ocr_jobs (
    tenant_id,
    expense_receipt_id,
    expense_claim_id,
    status,
    provider_class,
    provider_name,
    provider_version,
    idempotency_key,
    concurrency_key,
    priority,
    attempt_count,
    max_attempts,
    scheduled_at,
    safe_error_context,
    next_action_key,
    created_by_employee_id,
    estimated_cost_minor,
    estimated_cost_currency,
    document_page_count,
    normalized_image_pixels
  )
  VALUES (
    v_receipt.tenant_id,
    v_receipt.id,
    v_claim.id,
    'queued'::puls_workflow.expense_receipt_ocr_job_status,
    v_provider_class,
    v_provider_name,
    v_provider_version,
    v_idempotency_key,
    v_concurrency_key,
    p_priority,
    0,
    p_max_attempts,
    COALESCE(p_scheduled_at, NOW()),
    v_context,
    NULLIF(BTRIM(COALESCE(p_next_action_key, '')), ''),
    v_receipt.uploaded_by_employee_id,
    v_estimated_cost_minor,
    v_estimated_cost_currency,
    v_document_page_count,
    v_normalized_image_pixels
  )
  RETURNING * INTO v_job;

  UPDATE puls_workflow.expense_receipts
  SET ocr_status = 'queued'
  WHERE id = v_receipt.id
    AND ocr_status IS DISTINCT FROM 'queued';

  PERFORM puls_workflow._record_expense_receipt_ocr_job_event(
    v_job,
    'expense_receipt_ocr.job_queued',
    NULL,
    NULL,
    jsonb_build_object(
      'provider_class', v_job.provider_class::TEXT,
      'quota_gate_enforced', TRUE,
      'production_enqueue_disabled', TRUE,
      'estimated_cost_minor', v_job.estimated_cost_minor,
      'estimated_cost_currency', v_job.estimated_cost_currency,
      'document_page_count', v_job.document_page_count
    ),
    NULL,
    FALSE
  );

  RETURN v_job.id;
END;
$$;

CREATE OR REPLACE FUNCTION puls_workflow.complete_expense_receipt_ocr_job(
  p_job_id UUID,
  p_worker_id TEXT,
  p_status puls_workflow.expense_receipt_ocr_job_status,
  p_server_sha256 TEXT DEFAULT NULL,
  p_extracted_fields JSONB DEFAULT '{}'::JSONB,
  p_field_confidence JSONB DEFAULT '{}'::JSONB,
  p_document_confidence NUMERIC DEFAULT NULL,
  p_mismatch_flags JSONB DEFAULT '[]'::JSONB,
  p_provider_class puls_workflow.expense_receipt_ocr_provider_class DEFAULT NULL,
  p_provider_name TEXT DEFAULT NULL,
  p_provider_version TEXT DEFAULT NULL,
  p_provider_reference TEXT DEFAULT NULL,
  p_cost_metadata JSONB DEFAULT '{}'::JSONB,
  p_safe_error_code TEXT DEFAULT NULL,
  p_safe_error_context JSONB DEFAULT '{}'::JSONB,
  p_next_action_key TEXT DEFAULT NULL,
  p_retry_after_seconds INTEGER DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow
AS $$
DECLARE
  v_worker_id TEXT := NULLIF(BTRIM(COALESCE(p_worker_id, '')), '');
  v_job puls_workflow.expense_receipt_ocr_jobs%ROWTYPE;
  v_completed_job puls_workflow.expense_receipt_ocr_jobs%ROWTYPE;
  v_result_id UUID;
  v_duplicate_result_id UUID;
  v_server_sha256 TEXT := LOWER(NULLIF(BTRIM(COALESCE(p_server_sha256, '')), ''));
  v_extracted_fields JSONB := COALESCE(p_extracted_fields, '{}'::JSONB);
  v_field_confidence JSONB := COALESCE(p_field_confidence, '{}'::JSONB);
  v_mismatch_flags JSONB := COALESCE(p_mismatch_flags, '[]'::JSONB);
  v_cost_metadata JSONB := COALESCE(p_cost_metadata, '{}'::JSONB);
  v_safe_error_context JSONB := COALESCE(p_safe_error_context, '{}'::JSONB);
  v_provider_class puls_workflow.expense_receipt_ocr_provider_class;
  v_receipt_status TEXT;
  v_event_key TEXT;
  v_retry_after_seconds INTEGER := p_retry_after_seconds;
  v_actual_cost_minor INTEGER;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'PULS_SERVICE_ROLE_REQUIRED: Service role is required to complete expense receipt OCR jobs.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_worker_id IS NULL THEN
    RAISE EXCEPTION 'PULS_OCR_WORKER_ID_REQUIRED: Worker id is required.'
      USING ERRCODE = 'P0001';
  END IF;

  IF p_status NOT IN (
    'completed'::puls_workflow.expense_receipt_ocr_job_status,
    'failed'::puls_workflow.expense_receipt_ocr_job_status,
    'retrying'::puls_workflow.expense_receipt_ocr_job_status,
    'cancelled'::puls_workflow.expense_receipt_ocr_job_status,
    'dead_letter'::puls_workflow.expense_receipt_ocr_job_status
  ) THEN
    RAISE EXCEPTION 'PULS_OCR_COMPLETION_STATUS_INVALID: Completion status is invalid.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_server_sha256 IS NOT NULL AND v_server_sha256 !~ '^[a-f0-9]{64}$' THEN
    RAISE EXCEPTION 'PULS_OCR_SERVER_SHA256_INVALID: Server hash must be a SHA-256 hex value.'
      USING ERRCODE = 'P0001';
  END IF;

  IF jsonb_typeof(v_extracted_fields) <> 'object'
     OR jsonb_typeof(v_field_confidence) <> 'object'
     OR jsonb_typeof(v_mismatch_flags) <> 'array'
     OR jsonb_typeof(v_cost_metadata) <> 'object'
     OR jsonb_typeof(v_safe_error_context) <> 'object'
     OR puls_workflow.expense_receipt_ocr_safe_context_has_blocked_key(v_extracted_fields)
     OR puls_workflow.expense_receipt_ocr_safe_context_has_blocked_key(v_field_confidence)
     OR puls_workflow.expense_receipt_ocr_safe_context_has_blocked_key(v_cost_metadata)
     OR puls_workflow.expense_receipt_ocr_safe_context_has_blocked_key(v_safe_error_context) THEN
    RAISE EXCEPTION 'PULS_OCR_SAFE_CONTEXT_INVALID: OCR completion payload contains unsafe keys.'
      USING ERRCODE = 'P0001';
  END IF;

  IF p_document_confidence IS NOT NULL AND (p_document_confidence < 0 OR p_document_confidence > 1) THEN
    RAISE EXCEPTION 'PULS_OCR_CONFIDENCE_INVALID: OCR confidence must be between 0 and 1.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_retry_after_seconds IS NOT NULL AND (v_retry_after_seconds < 0 OR v_retry_after_seconds > 86400) THEN
    RAISE EXCEPTION 'PULS_OCR_RETRY_AFTER_INVALID: Retry-after seconds are out of range.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_cost_metadata ? 'actual_cost_minor' THEN
    IF (v_cost_metadata ->> 'actual_cost_minor') !~ '^[0-9]+$' THEN
      RAISE EXCEPTION 'PULS_OCR_ACTUAL_COST_INVALID: OCR actual cost must be a non-negative integer.'
        USING ERRCODE = 'P0001';
    END IF;
    v_actual_cost_minor := (v_cost_metadata ->> 'actual_cost_minor')::INTEGER;
  END IF;

  SELECT *
  INTO v_job
  FROM puls_workflow.expense_receipt_ocr_jobs
  WHERE id = p_job_id
    AND status = 'processing'::puls_workflow.expense_receipt_ocr_job_status
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_OCR_JOB_NOT_FOUND: Active OCR job was not found.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_job.locked_by IS DISTINCT FROM v_worker_id
     OR v_job.lease_expires_at IS NULL
     OR v_job.lease_expires_at <= NOW() THEN
    RAISE EXCEPTION 'PULS_OCR_JOB_LEASE_INVALID: OCR job lease is not active for this worker.'
      USING ERRCODE = 'P0001';
  END IF;

  v_provider_class := COALESCE(p_provider_class, v_job.provider_class);

  IF p_status = 'completed'::puls_workflow.expense_receipt_ocr_job_status THEN
    IF v_server_sha256 IS NOT NULL THEN
      SELECT result.id
      INTO v_duplicate_result_id
      FROM puls_workflow.expense_receipt_ocr_results result
      WHERE result.tenant_id = v_job.tenant_id
        AND result.server_sha256 = v_server_sha256
        AND result.expense_receipt_id <> v_job.expense_receipt_id
      ORDER BY result.created_at ASC, result.id ASC
      LIMIT 1;

      IF v_duplicate_result_id IS NOT NULL
         AND NOT EXISTS (
           SELECT 1
           FROM jsonb_array_elements_text(v_mismatch_flags) flag
           WHERE flag = 'duplicate_suspected'
         ) THEN
        v_mismatch_flags := v_mismatch_flags || '["duplicate_suspected"]'::JSONB;
      END IF;
    END IF;

    INSERT INTO puls_workflow.expense_receipt_ocr_results (
      tenant_id,
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
      provider_reference,
      cost_metadata,
      estimated_cost_minor,
      actual_cost_minor,
      cost_currency,
      review_status
    )
    VALUES (
      v_job.tenant_id,
      v_job.expense_receipt_id,
      v_job.expense_claim_id,
      v_job.id,
      v_server_sha256,
      v_duplicate_result_id,
      v_extracted_fields,
      v_field_confidence,
      p_document_confidence,
      v_mismatch_flags,
      v_provider_class,
      NULLIF(BTRIM(COALESCE(p_provider_name, '')), ''),
      NULLIF(BTRIM(COALESCE(p_provider_version, '')), ''),
      NULLIF(BTRIM(COALESCE(p_provider_reference, '')), ''),
      v_cost_metadata,
      v_job.estimated_cost_minor,
      v_actual_cost_minor,
      v_job.estimated_cost_currency,
      'pending_review'::puls_workflow.expense_receipt_ocr_review_status
    )
    RETURNING id INTO v_result_id;

    v_receipt_status := 'completed';
    v_event_key := 'expense_receipt_ocr.job_completed';
  ELSIF p_status = 'retrying'::puls_workflow.expense_receipt_ocr_job_status THEN
    IF v_job.attempt_count >= v_job.max_attempts THEN
      p_status := 'dead_letter'::puls_workflow.expense_receipt_ocr_job_status;
      v_receipt_status := 'failed';
      v_event_key := 'expense_receipt_ocr.job_dead_lettered';
    ELSE
      v_receipt_status := 'queued';
      v_event_key := 'expense_receipt_ocr.job_retrying';
    END IF;
  ELSIF p_status = 'cancelled'::puls_workflow.expense_receipt_ocr_job_status THEN
    v_receipt_status := 'cancelled';
    v_event_key := 'expense_receipt_ocr.job_cancelled';
  ELSE
    v_receipt_status := 'failed';
    v_event_key := CASE
      WHEN p_status = 'dead_letter'::puls_workflow.expense_receipt_ocr_job_status THEN 'expense_receipt_ocr.job_dead_lettered'
      ELSE 'expense_receipt_ocr.job_failed'
    END;
  END IF;

  UPDATE puls_workflow.expense_receipt_ocr_jobs job
  SET
    status = p_status,
    provider_class = v_provider_class,
    provider_name = NULLIF(BTRIM(COALESCE(p_provider_name, job.provider_name, '')), ''),
    provider_version = NULLIF(BTRIM(COALESCE(p_provider_version, job.provider_version, '')), ''),
    finished_at = CASE
      WHEN p_status IN (
        'completed'::puls_workflow.expense_receipt_ocr_job_status,
        'failed'::puls_workflow.expense_receipt_ocr_job_status,
        'cancelled'::puls_workflow.expense_receipt_ocr_job_status,
        'dead_letter'::puls_workflow.expense_receipt_ocr_job_status
      ) THEN NOW()
      ELSE job.finished_at
    END,
    locked_by = NULL,
    locked_at = NULL,
    worker_heartbeat_at = NULL,
    lease_expires_at = NULL,
    scheduled_at = CASE
      WHEN p_status = 'retrying'::puls_workflow.expense_receipt_ocr_job_status
      THEN NOW() + make_interval(secs => COALESCE(v_retry_after_seconds, 120))
      ELSE job.scheduled_at
    END,
    safe_error_code = NULLIF(BTRIM(COALESCE(p_safe_error_code, '')), ''),
    safe_error_context = v_safe_error_context,
    next_action_key = NULLIF(BTRIM(COALESCE(p_next_action_key, job.next_action_key, '')), '')
  WHERE job.id = v_job.id
  RETURNING * INTO v_completed_job;

  UPDATE puls_workflow.expense_receipts
  SET ocr_status = v_receipt_status
  WHERE id = v_job.expense_receipt_id;

  PERFORM puls_workflow._record_expense_receipt_ocr_job_event(
    v_completed_job,
    v_event_key,
    v_worker_id,
    p_safe_error_code,
    v_safe_error_context,
    v_retry_after_seconds,
    p_status IN (
      'failed'::puls_workflow.expense_receipt_ocr_job_status,
      'dead_letter'::puls_workflow.expense_receipt_ocr_job_status
    )
  );

  RETURN COALESCE(v_result_id, v_completed_job.id);
END;
$$;

COMMENT ON TABLE puls_workflow.expense_receipt_ocr_tenant_posture
  IS 'PR17.2G4A tenant-level OCR posture. Defaults are closed: disabled, zero quota, zero spend cap, and no provider allowlist.';

COMMENT ON TABLE puls_workflow.expense_receipt_ocr_global_posture
  IS 'PR17.2G4A global OCR spend cap posture. Defaults to zero spend cap when absent.';

COMMENT ON COLUMN puls_workflow.expense_receipt_ocr_jobs.estimated_cost_minor
  IS 'Safe estimated OCR cost in minor units, recorded at enqueue for quota/spend gating.';

COMMENT ON COLUMN puls_workflow.expense_receipt_ocr_results.actual_cost_minor
  IS 'Safe actual OCR cost in minor units, populated from vetted cost metadata when a worker completes a job.';

ALTER TABLE puls_workflow.expense_receipt_ocr_tenant_posture ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_workflow.expense_receipt_ocr_global_posture ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE puls_workflow.expense_receipt_ocr_tenant_posture FROM anon, authenticated;
REVOKE ALL ON TABLE puls_workflow.expense_receipt_ocr_global_posture FROM anon, authenticated;
GRANT ALL ON TABLE puls_workflow.expense_receipt_ocr_tenant_posture TO service_role;
GRANT ALL ON TABLE puls_workflow.expense_receipt_ocr_global_posture TO service_role;

REVOKE ALL ON FUNCTION puls_workflow.enqueue_expense_receipt_ocr_job(
  UUID,
  TEXT,
  puls_workflow.expense_receipt_ocr_provider_class,
  INTEGER,
  TIMESTAMPTZ,
  INTEGER,
  JSONB,
  TEXT,
  INTEGER,
  TEXT,
  TEXT,
  TEXT,
  INTEGER,
  INTEGER
) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION puls_workflow.enqueue_expense_receipt_ocr_job(
  UUID,
  TEXT,
  puls_workflow.expense_receipt_ocr_provider_class,
  INTEGER,
  TIMESTAMPTZ,
  INTEGER,
  JSONB,
  TEXT,
  INTEGER,
  TEXT,
  TEXT,
  TEXT,
  INTEGER,
  INTEGER
) TO service_role;
