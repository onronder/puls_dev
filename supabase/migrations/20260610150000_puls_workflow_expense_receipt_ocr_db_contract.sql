-- PR17.2G2A: expense receipt OCR/extraction database contract.
--
-- This slice defines the workflow-owned processing queue and result ledger for
-- expense receipt evidence. It deliberately does not enqueue from browser
-- workflows, does not add triggers on expense_receipts, does not deploy a
-- worker, and does not call an OCR provider.

DO $$
BEGIN
  CREATE TYPE puls_workflow.expense_receipt_ocr_job_status AS ENUM (
    'queued',
    'processing',
    'completed',
    'failed',
    'retrying',
    'cancelled',
    'dead_letter'
  );
EXCEPTION WHEN duplicate_object THEN
  NULL;
END;
$$;

DO $$
BEGIN
  CREATE TYPE puls_workflow.expense_receipt_ocr_provider_class AS ENUM (
    'disabled',
    'mock',
    'structured',
    'pdf_text',
    'image_ocr',
    'manual',
    'external'
  );
EXCEPTION WHEN duplicate_object THEN
  NULL;
END;
$$;

DO $$
BEGIN
  CREATE TYPE puls_workflow.expense_receipt_ocr_review_status AS ENUM (
    'not_ready',
    'pending_review',
    'accepted',
    'corrected',
    'rejected',
    'needs_new_document'
  );
EXCEPTION WHEN duplicate_object THEN
  NULL;
END;
$$;

CREATE OR REPLACE FUNCTION puls_workflow.expense_receipt_ocr_safe_context_has_blocked_key(
  p_context JSONB
)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
SET search_path = pg_catalog
AS $$
DECLARE
  v_key TEXT;
  v_value JSONB;
BEGIN
  IF p_context IS NULL THEN
    RETURN FALSE;
  END IF;

  IF jsonb_typeof(p_context) = 'object' THEN
    FOR v_key, v_value IN
      SELECT key, value
      FROM jsonb_each(p_context)
    LOOP
      IF lower(v_key) IN (
        'api_key',
        'apikey',
        'authorization',
        'bearer',
        'credential',
        'credentials_ref',
        'connection_string',
        'private_key',
        'client_secret',
        'refresh_token',
        'access_token',
        'raw_payload',
        'provider_payload',
        'request_body',
        'response_body',
        'ocr_text',
        'raw_ocr_text',
        'raw_text',
        'full_text',
        'document_text',
        'storage_path',
        'file_ref',
        'signed_url',
        'public_url',
        'download_url',
        'document_bytes',
        'file_bytes',
        'base64',
        'iban',
        'bank_account',
        'card_number'
      )
      OR lower(v_key) LIKE '%password%'
      OR lower(v_key) LIKE '%passwd%'
      OR lower(v_key) LIKE '%secret%'
      OR lower(v_key) LIKE '%token%' THEN
        RETURN TRUE;
      END IF;

      IF puls_workflow.expense_receipt_ocr_safe_context_has_blocked_key(v_value) THEN
        RETURN TRUE;
      END IF;
    END LOOP;
  ELSIF jsonb_typeof(p_context) = 'array' THEN
    FOR v_value IN
      SELECT value
      FROM jsonb_array_elements(p_context)
    LOOP
      IF puls_workflow.expense_receipt_ocr_safe_context_has_blocked_key(v_value) THEN
        RETURN TRUE;
      END IF;
    END LOOP;
  END IF;

  RETURN FALSE;
END;
$$;

CREATE TABLE IF NOT EXISTS puls_workflow.expense_receipt_ocr_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  expense_receipt_id UUID NOT NULL REFERENCES puls_workflow.expense_receipts(id) ON DELETE CASCADE,
  expense_claim_id UUID NOT NULL REFERENCES puls_workflow.expense_claims(id) ON DELETE CASCADE,
  status puls_workflow.expense_receipt_ocr_job_status NOT NULL DEFAULT 'queued',
  provider_class puls_workflow.expense_receipt_ocr_provider_class NOT NULL DEFAULT 'disabled',
  provider_name TEXT NULL,
  provider_version TEXT NULL,
  idempotency_key TEXT NOT NULL,
  concurrency_key TEXT NOT NULL,
  priority INTEGER NOT NULL DEFAULT 100,
  attempt_count INTEGER NOT NULL DEFAULT 0,
  max_attempts INTEGER NOT NULL DEFAULT 3,
  scheduled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  started_at TIMESTAMPTZ NULL,
  finished_at TIMESTAMPTZ NULL,
  locked_by TEXT NULL,
  locked_at TIMESTAMPTZ NULL,
  worker_heartbeat_at TIMESTAMPTZ NULL,
  lease_expires_at TIMESTAMPTZ NULL,
  safe_error_code TEXT NULL,
  safe_error_context JSONB NOT NULL DEFAULT '{}'::JSONB,
  next_action_key TEXT NULL,
  created_by_employee_id UUID NULL REFERENCES puls_core.employees(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, idempotency_key),
  CHECK (idempotency_key = BTRIM(idempotency_key) AND idempotency_key <> ''),
  CHECK (concurrency_key = BTRIM(concurrency_key) AND concurrency_key <> ''),
  CHECK (priority >= 0),
  CHECK (attempt_count >= 0),
  CHECK (max_attempts BETWEEN 1 AND 10),
  CHECK (attempt_count <= max_attempts),
  CHECK (safe_error_context IS NOT NULL AND jsonb_typeof(safe_error_context) = 'object'),
  CHECK (NOT puls_workflow.expense_receipt_ocr_safe_context_has_blocked_key(safe_error_context)),
  CHECK (provider_name IS NULL OR (provider_name = BTRIM(provider_name) AND provider_name <> '')),
  CHECK (provider_version IS NULL OR (provider_version = BTRIM(provider_version) AND provider_version <> '')),
  CHECK (
    status <> 'processing'::puls_workflow.expense_receipt_ocr_job_status
    OR (locked_by IS NOT NULL AND locked_at IS NOT NULL AND lease_expires_at IS NOT NULL)
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS expense_receipt_ocr_jobs_active_concurrency_idx
  ON puls_workflow.expense_receipt_ocr_jobs (tenant_id, concurrency_key)
  WHERE status IN (
    'queued'::puls_workflow.expense_receipt_ocr_job_status,
    'processing'::puls_workflow.expense_receipt_ocr_job_status,
    'retrying'::puls_workflow.expense_receipt_ocr_job_status
  );

CREATE INDEX IF NOT EXISTS expense_receipt_ocr_jobs_claim_idx
  ON puls_workflow.expense_receipt_ocr_jobs (tenant_id, priority, scheduled_at, created_at)
  WHERE status IN (
    'queued'::puls_workflow.expense_receipt_ocr_job_status,
    'retrying'::puls_workflow.expense_receipt_ocr_job_status
  );

CREATE INDEX IF NOT EXISTS expense_receipt_ocr_jobs_receipt_idx
  ON puls_workflow.expense_receipt_ocr_jobs (tenant_id, expense_receipt_id, created_at DESC);

CREATE TABLE IF NOT EXISTS puls_workflow.expense_receipt_ocr_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  expense_receipt_id UUID NOT NULL REFERENCES puls_workflow.expense_receipts(id) ON DELETE CASCADE,
  expense_claim_id UUID NOT NULL REFERENCES puls_workflow.expense_claims(id) ON DELETE CASCADE,
  job_id UUID NOT NULL REFERENCES puls_workflow.expense_receipt_ocr_jobs(id) ON DELETE RESTRICT,
  server_sha256 TEXT NULL,
  duplicate_of_result_id UUID NULL REFERENCES puls_workflow.expense_receipt_ocr_results(id) ON DELETE SET NULL,
  extracted_fields JSONB NOT NULL DEFAULT '{}'::JSONB,
  field_confidence JSONB NOT NULL DEFAULT '{}'::JSONB,
  document_confidence NUMERIC(5, 4) NULL,
  mismatch_flags JSONB NOT NULL DEFAULT '[]'::JSONB,
  provider_class puls_workflow.expense_receipt_ocr_provider_class NOT NULL DEFAULT 'disabled',
  provider_name TEXT NULL,
  provider_version TEXT NULL,
  provider_reference TEXT NULL,
  cost_metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
  review_status puls_workflow.expense_receipt_ocr_review_status NOT NULL DEFAULT 'pending_review',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (job_id),
  CHECK (server_sha256 IS NULL OR server_sha256 ~ '^[a-f0-9]{64}$'),
  CHECK (duplicate_of_result_id IS NULL OR duplicate_of_result_id <> id),
  CHECK (extracted_fields IS NOT NULL AND jsonb_typeof(extracted_fields) = 'object'),
  CHECK (field_confidence IS NOT NULL AND jsonb_typeof(field_confidence) = 'object'),
  CHECK (mismatch_flags IS NOT NULL AND jsonb_typeof(mismatch_flags) = 'array'),
  CHECK (cost_metadata IS NOT NULL AND jsonb_typeof(cost_metadata) = 'object'),
  CHECK (NOT puls_workflow.expense_receipt_ocr_safe_context_has_blocked_key(extracted_fields)),
  CHECK (NOT puls_workflow.expense_receipt_ocr_safe_context_has_blocked_key(field_confidence)),
  CHECK (NOT puls_workflow.expense_receipt_ocr_safe_context_has_blocked_key(cost_metadata)),
  CHECK (document_confidence IS NULL OR (document_confidence >= 0 AND document_confidence <= 1)),
  CHECK (provider_name IS NULL OR (provider_name = BTRIM(provider_name) AND provider_name <> '')),
  CHECK (provider_version IS NULL OR (provider_version = BTRIM(provider_version) AND provider_version <> '')),
  CHECK (provider_reference IS NULL OR (provider_reference = BTRIM(provider_reference) AND provider_reference <> ''))
);

CREATE INDEX IF NOT EXISTS expense_receipt_ocr_results_receipt_idx
  ON puls_workflow.expense_receipt_ocr_results (tenant_id, expense_receipt_id, created_at DESC);

CREATE INDEX IF NOT EXISTS expense_receipt_ocr_results_server_sha256_idx
  ON puls_workflow.expense_receipt_ocr_results (tenant_id, server_sha256)
  WHERE server_sha256 IS NOT NULL;

CREATE TABLE IF NOT EXISTS puls_workflow.expense_receipt_ocr_job_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  expense_receipt_id UUID NOT NULL REFERENCES puls_workflow.expense_receipts(id) ON DELETE CASCADE,
  expense_claim_id UUID NOT NULL REFERENCES puls_workflow.expense_claims(id) ON DELETE CASCADE,
  job_id UUID NULL REFERENCES puls_workflow.expense_receipt_ocr_jobs(id) ON DELETE SET NULL,
  event_key TEXT NOT NULL,
  status puls_workflow.expense_receipt_ocr_job_status NULL,
  worker_id TEXT NULL,
  safe_error_code TEXT NULL,
  safe_error_context JSONB NOT NULL DEFAULT '{}'::JSONB,
  retry_after_seconds INTEGER NULL,
  operator_review_required BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (event_key = BTRIM(event_key) AND event_key <> ''),
  CHECK (safe_error_context IS NOT NULL AND jsonb_typeof(safe_error_context) = 'object'),
  CHECK (NOT puls_workflow.expense_receipt_ocr_safe_context_has_blocked_key(safe_error_context)),
  CHECK (retry_after_seconds IS NULL OR retry_after_seconds BETWEEN 0 AND 86400)
);

CREATE INDEX IF NOT EXISTS expense_receipt_ocr_job_events_job_idx
  ON puls_workflow.expense_receipt_ocr_job_events (tenant_id, job_id, created_at DESC)
  WHERE job_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS expense_receipt_ocr_job_events_receipt_idx
  ON puls_workflow.expense_receipt_ocr_job_events (tenant_id, expense_receipt_id, created_at DESC);

DROP TRIGGER IF EXISTS expense_receipt_ocr_jobs_set_updated_at ON puls_workflow.expense_receipt_ocr_jobs;
CREATE TRIGGER expense_receipt_ocr_jobs_set_updated_at
  BEFORE UPDATE ON puls_workflow.expense_receipt_ocr_jobs
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS expense_receipt_ocr_results_set_updated_at ON puls_workflow.expense_receipt_ocr_results;
CREATE TRIGGER expense_receipt_ocr_results_set_updated_at
  BEFORE UPDATE ON puls_workflow.expense_receipt_ocr_results
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

ALTER TABLE puls_workflow.expense_receipt_ocr_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_workflow.expense_receipt_ocr_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_workflow.expense_receipt_ocr_job_events ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION puls_workflow.can_read_expense_receipt_ocr(
  p_expense_receipt_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM puls_workflow.expense_receipts receipt
    JOIN puls_workflow.expense_claims claim
      ON claim.id = receipt.expense_claim_id
     AND claim.tenant_id = receipt.tenant_id
    WHERE receipt.id = p_expense_receipt_id
      AND receipt.tenant_id = puls_core.current_tenant_id()
      AND (
        puls_core.is_admin()
        OR receipt.uploaded_by_employee_id = puls_core.current_employee_id()
        OR claim.employee_id = puls_core.current_employee_id()
        OR EXISTS (
          SELECT 1
          FROM puls_core.employees e
          WHERE e.id = claim.employee_id
            AND e.manager_employee_id = puls_core.current_employee_id()
        )
        OR puls_workflow._workflow_evidence_is_assigned_approver(
          'expense'::puls_workflow.evidence_upload_domain,
          claim.id,
          puls_core.current_employee_id()
        )
      )
  );
$$;

DROP POLICY IF EXISTS expense_receipt_ocr_jobs_select ON puls_workflow.expense_receipt_ocr_jobs;
CREATE POLICY expense_receipt_ocr_jobs_select
  ON puls_workflow.expense_receipt_ocr_jobs
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND puls_workflow.can_read_expense_receipt_ocr(expense_receipt_id)
  );

DROP POLICY IF EXISTS expense_receipt_ocr_results_select ON puls_workflow.expense_receipt_ocr_results;
CREATE POLICY expense_receipt_ocr_results_select
  ON puls_workflow.expense_receipt_ocr_results
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND puls_workflow.can_read_expense_receipt_ocr(expense_receipt_id)
  );

DROP POLICY IF EXISTS expense_receipt_ocr_job_events_select ON puls_workflow.expense_receipt_ocr_job_events;
CREATE POLICY expense_receipt_ocr_job_events_select
  ON puls_workflow.expense_receipt_ocr_job_events
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND puls_workflow.can_read_expense_receipt_ocr(expense_receipt_id)
  );

DROP POLICY IF EXISTS expense_receipt_ocr_jobs_service_role ON puls_workflow.expense_receipt_ocr_jobs;
CREATE POLICY expense_receipt_ocr_jobs_service_role
  ON puls_workflow.expense_receipt_ocr_jobs
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS expense_receipt_ocr_results_service_role ON puls_workflow.expense_receipt_ocr_results;
CREATE POLICY expense_receipt_ocr_results_service_role
  ON puls_workflow.expense_receipt_ocr_results
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS expense_receipt_ocr_job_events_service_role ON puls_workflow.expense_receipt_ocr_job_events;
CREATE POLICY expense_receipt_ocr_job_events_service_role
  ON puls_workflow.expense_receipt_ocr_job_events
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

CREATE OR REPLACE FUNCTION puls_workflow._record_expense_receipt_ocr_job_event(
  p_job puls_workflow.expense_receipt_ocr_jobs,
  p_event_key TEXT,
  p_worker_id TEXT DEFAULT NULL,
  p_safe_error_code TEXT DEFAULT NULL,
  p_safe_error_context JSONB DEFAULT '{}'::JSONB,
  p_retry_after_seconds INTEGER DEFAULT NULL,
  p_operator_review_required BOOLEAN DEFAULT FALSE
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow
AS $$
DECLARE
  v_event_id UUID;
  v_context JSONB := COALESCE(p_safe_error_context, '{}'::JSONB);
BEGIN
  IF jsonb_typeof(v_context) <> 'object'
     OR puls_workflow.expense_receipt_ocr_safe_context_has_blocked_key(v_context) THEN
    RAISE EXCEPTION 'PULS_OCR_SAFE_CONTEXT_INVALID: OCR event context contains unsafe keys.'
      USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO puls_workflow.expense_receipt_ocr_job_events (
    tenant_id,
    expense_receipt_id,
    expense_claim_id,
    job_id,
    event_key,
    status,
    worker_id,
    safe_error_code,
    safe_error_context,
    retry_after_seconds,
    operator_review_required
  )
  VALUES (
    p_job.tenant_id,
    p_job.expense_receipt_id,
    p_job.expense_claim_id,
    p_job.id,
    p_event_key,
    p_job.status,
    NULLIF(BTRIM(COALESCE(p_worker_id, '')), ''),
    NULLIF(BTRIM(COALESCE(p_safe_error_code, '')), ''),
    v_context,
    p_retry_after_seconds,
    p_operator_review_required
  )
  RETURNING id INTO v_event_id;

  RETURN v_event_id;
END;
$$;

CREATE OR REPLACE FUNCTION puls_workflow.enqueue_expense_receipt_ocr_job(
  p_expense_receipt_id UUID,
  p_idempotency_key TEXT DEFAULT NULL,
  p_provider_class puls_workflow.expense_receipt_ocr_provider_class DEFAULT 'disabled'::puls_workflow.expense_receipt_ocr_provider_class,
  p_priority INTEGER DEFAULT 100,
  p_scheduled_at TIMESTAMPTZ DEFAULT NOW(),
  p_max_attempts INTEGER DEFAULT 3,
  p_safe_error_context JSONB DEFAULT '{}'::JSONB,
  p_next_action_key TEXT DEFAULT 'review_expense_receipt_ocr_status'
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
  v_idempotency_key TEXT;
  v_concurrency_key TEXT;
  v_context JSONB := COALESCE(p_safe_error_context, '{}'::JSONB);
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

  INSERT INTO puls_workflow.expense_receipt_ocr_jobs (
    tenant_id,
    expense_receipt_id,
    expense_claim_id,
    status,
    provider_class,
    idempotency_key,
    concurrency_key,
    priority,
    attempt_count,
    max_attempts,
    scheduled_at,
    safe_error_context,
    next_action_key,
    created_by_employee_id
  )
  VALUES (
    v_receipt.tenant_id,
    v_receipt.id,
    v_claim.id,
    'queued'::puls_workflow.expense_receipt_ocr_job_status,
    COALESCE(p_provider_class, 'disabled'::puls_workflow.expense_receipt_ocr_provider_class),
    v_idempotency_key,
    v_concurrency_key,
    p_priority,
    0,
    p_max_attempts,
    COALESCE(p_scheduled_at, NOW()),
    v_context,
    NULLIF(BTRIM(COALESCE(p_next_action_key, '')), ''),
    v_receipt.uploaded_by_employee_id
  )
  ON CONFLICT (tenant_id, idempotency_key) DO UPDATE
  SET idempotency_key = EXCLUDED.idempotency_key
  RETURNING * INTO v_job;

  UPDATE puls_workflow.expense_receipts
  SET ocr_status = 'queued'
  WHERE id = v_receipt.id
    AND v_job.status IN (
      'queued'::puls_workflow.expense_receipt_ocr_job_status,
      'retrying'::puls_workflow.expense_receipt_ocr_job_status
    )
    AND ocr_status IS DISTINCT FROM 'queued';

  PERFORM puls_workflow._record_expense_receipt_ocr_job_event(
    v_job,
    CASE
      WHEN v_job.status IN (
        'queued'::puls_workflow.expense_receipt_ocr_job_status,
        'retrying'::puls_workflow.expense_receipt_ocr_job_status
      )
      THEN 'expense_receipt_ocr.job_queued'
      ELSE 'expense_receipt_ocr.job_enqueue_idempotent_hit'
    END,
    NULL,
    NULL,
    jsonb_build_object(
      'provider_class', v_job.provider_class::TEXT,
      'production_enqueue_disabled', TRUE
    ),
    NULL,
    FALSE
  );

  RETURN v_job.id;
END;
$$;

CREATE OR REPLACE FUNCTION puls_workflow.claim_next_expense_receipt_ocr_job(
  p_worker_id TEXT,
  p_limit INTEGER DEFAULT 1,
  p_lease_seconds INTEGER DEFAULT 300
)
RETURNS TABLE (
  job_id UUID,
  tenant_id UUID,
  expense_receipt_id UUID,
  expense_claim_id UUID,
  status TEXT,
  provider_class TEXT,
  attempt_count INTEGER,
  max_attempts INTEGER,
  safe_error_context JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow
AS $$
DECLARE
  v_worker_id TEXT := NULLIF(BTRIM(COALESCE(p_worker_id, '')), '');
  v_limit INTEGER := LEAST(GREATEST(COALESCE(p_limit, 1), 1), 25);
  v_lease_seconds INTEGER := LEAST(GREATEST(COALESCE(p_lease_seconds, 300), 30), 3600);
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'PULS_SERVICE_ROLE_REQUIRED: Service role is required to claim expense receipt OCR jobs.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_worker_id IS NULL THEN
    RAISE EXCEPTION 'PULS_OCR_WORKER_ID_REQUIRED: Worker id is required.'
      USING ERRCODE = 'P0001';
  END IF;

  RETURN QUERY
  WITH candidates AS (
    SELECT job.id
    FROM puls_workflow.expense_receipt_ocr_jobs job
    WHERE job.status IN (
        'queued'::puls_workflow.expense_receipt_ocr_job_status,
        'retrying'::puls_workflow.expense_receipt_ocr_job_status
      )
      AND job.scheduled_at <= NOW()
      AND job.attempt_count < job.max_attempts
    ORDER BY job.priority ASC, job.scheduled_at ASC, job.created_at ASC
    LIMIT v_limit
    FOR UPDATE SKIP LOCKED
  ),
  updated AS (
    UPDATE puls_workflow.expense_receipt_ocr_jobs job
    SET
      status = 'processing'::puls_workflow.expense_receipt_ocr_job_status,
      locked_by = v_worker_id,
      locked_at = NOW(),
      worker_heartbeat_at = NOW(),
      lease_expires_at = NOW() + make_interval(secs => v_lease_seconds),
      started_at = COALESCE(job.started_at, NOW()),
      attempt_count = job.attempt_count + 1,
      safe_error_code = NULL
    FROM candidates c
    WHERE job.id = c.id
    RETURNING
      job.id,
      job.tenant_id,
      job.expense_receipt_id,
      job.expense_claim_id,
      job.status,
      job.provider_class,
      job.attempt_count,
      job.max_attempts,
      job.safe_error_context
  ),
  projection AS (
    UPDATE puls_workflow.expense_receipts receipt
    SET ocr_status = 'processing'
    FROM updated
    WHERE receipt.id = updated.expense_receipt_id
    RETURNING receipt.id
  ),
  events AS (
    INSERT INTO puls_workflow.expense_receipt_ocr_job_events (
      tenant_id,
      expense_receipt_id,
      expense_claim_id,
      job_id,
      event_key,
      status,
      worker_id,
      safe_error_context
    )
    SELECT
      updated.tenant_id,
      updated.expense_receipt_id,
      updated.expense_claim_id,
      updated.id,
      'expense_receipt_ocr.job_claimed',
      updated.status,
      v_worker_id,
      '{}'::JSONB
    FROM updated
    RETURNING id
  )
  SELECT
    updated.id,
    updated.tenant_id,
    updated.expense_receipt_id,
    updated.expense_claim_id,
    updated.status::TEXT,
    updated.provider_class::TEXT,
    updated.attempt_count,
    updated.max_attempts,
    updated.safe_error_context
  FROM updated;
END;
$$;

CREATE OR REPLACE FUNCTION puls_workflow.heartbeat_expense_receipt_ocr_job(
  p_job_id UUID,
  p_worker_id TEXT,
  p_lease_seconds INTEGER DEFAULT 300,
  p_safe_error_context JSONB DEFAULT '{}'::JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow
AS $$
DECLARE
  v_worker_id TEXT := NULLIF(BTRIM(COALESCE(p_worker_id, '')), '');
  v_lease_seconds INTEGER := LEAST(GREATEST(COALESCE(p_lease_seconds, 300), 30), 3600);
  v_context JSONB := COALESCE(p_safe_error_context, '{}'::JSONB);
  v_job puls_workflow.expense_receipt_ocr_jobs%ROWTYPE;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'PULS_SERVICE_ROLE_REQUIRED: Service role is required to heartbeat expense receipt OCR jobs.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_worker_id IS NULL THEN
    RAISE EXCEPTION 'PULS_OCR_WORKER_ID_REQUIRED: Worker id is required.'
      USING ERRCODE = 'P0001';
  END IF;

  IF jsonb_typeof(v_context) <> 'object'
     OR puls_workflow.expense_receipt_ocr_safe_context_has_blocked_key(v_context) THEN
    RAISE EXCEPTION 'PULS_OCR_SAFE_CONTEXT_INVALID: OCR heartbeat context contains unsafe keys.'
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE puls_workflow.expense_receipt_ocr_jobs job
  SET
    worker_heartbeat_at = NOW(),
    lease_expires_at = NOW() + make_interval(secs => v_lease_seconds),
    safe_error_context = CASE
      WHEN v_context = '{}'::JSONB THEN job.safe_error_context
      ELSE v_context
    END
  WHERE job.id = p_job_id
    AND job.status = 'processing'::puls_workflow.expense_receipt_ocr_job_status
    AND job.locked_by = v_worker_id
    AND job.lease_expires_at > NOW()
  RETURNING * INTO v_job;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_OCR_JOB_LEASE_INVALID: OCR job lease is not active for this worker.'
      USING ERRCODE = 'P0001';
  END IF;

  PERFORM puls_workflow._record_expense_receipt_ocr_job_event(
    v_job,
    'expense_receipt_ocr.job_heartbeat',
    v_worker_id,
    NULL,
    '{}'::JSONB,
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
    provider_name = NULLIF(BTRIM(COALESCE(p_provider_name, '')), ''),
    provider_version = NULLIF(BTRIM(COALESCE(p_provider_version, '')), ''),
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

CREATE OR REPLACE FUNCTION puls_workflow.recover_stale_expense_receipt_ocr_jobs(
  p_worker_id TEXT,
  p_limit INTEGER DEFAULT 25
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow
AS $$
DECLARE
  v_worker_id TEXT := NULLIF(BTRIM(COALESCE(p_worker_id, '')), '');
  v_limit INTEGER := LEAST(GREATEST(COALESCE(p_limit, 25), 1), 100);
  v_count INTEGER;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'PULS_SERVICE_ROLE_REQUIRED: Service role is required to recover stale expense receipt OCR jobs.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_worker_id IS NULL THEN
    RAISE EXCEPTION 'PULS_OCR_WORKER_ID_REQUIRED: Worker id is required.'
      USING ERRCODE = 'P0001';
  END IF;

  WITH stale AS (
    SELECT job.*
    FROM puls_workflow.expense_receipt_ocr_jobs job
    WHERE job.status = 'processing'::puls_workflow.expense_receipt_ocr_job_status
      AND job.lease_expires_at <= NOW()
    ORDER BY job.lease_expires_at ASC, job.created_at ASC
    LIMIT v_limit
    FOR UPDATE SKIP LOCKED
  ),
  updated AS (
    UPDATE puls_workflow.expense_receipt_ocr_jobs job
    SET
      status = CASE
        WHEN job.attempt_count >= job.max_attempts THEN 'dead_letter'::puls_workflow.expense_receipt_ocr_job_status
        ELSE 'retrying'::puls_workflow.expense_receipt_ocr_job_status
      END,
      locked_by = NULL,
      locked_at = NULL,
      worker_heartbeat_at = NULL,
      lease_expires_at = NULL,
      scheduled_at = CASE
        WHEN job.attempt_count >= job.max_attempts THEN job.scheduled_at
        ELSE NOW() + INTERVAL '120 seconds'
      END,
      safe_error_code = 'OCR_LEASE_EXPIRED',
      safe_error_context = jsonb_build_object('recovered_by', v_worker_id)
    FROM stale
    WHERE job.id = stale.id
    RETURNING
      job.id,
      job.tenant_id,
      job.expense_receipt_id,
      job.expense_claim_id,
      job.status
  ),
  receipt_projection AS (
    UPDATE puls_workflow.expense_receipts receipt
    SET ocr_status = CASE
      WHEN updated.status = 'dead_letter'::puls_workflow.expense_receipt_ocr_job_status THEN 'failed'
      ELSE 'queued'
    END
    FROM updated
    WHERE receipt.id = updated.expense_receipt_id
    RETURNING receipt.id
  ),
  events AS (
    INSERT INTO puls_workflow.expense_receipt_ocr_job_events (
      tenant_id,
      expense_receipt_id,
      expense_claim_id,
      job_id,
      event_key,
      status,
      worker_id,
      safe_error_code,
      safe_error_context,
      retry_after_seconds,
      operator_review_required
    )
    SELECT
      updated.tenant_id,
      updated.expense_receipt_id,
      updated.expense_claim_id,
      updated.id,
      CASE
        WHEN updated.status = 'dead_letter'::puls_workflow.expense_receipt_ocr_job_status
        THEN 'expense_receipt_ocr.job_dead_lettered'
        ELSE 'expense_receipt_ocr.job_recovered'
      END,
      updated.status,
      v_worker_id,
      'OCR_LEASE_EXPIRED',
      jsonb_build_object('recovered_by', v_worker_id),
      CASE
        WHEN updated.status = 'dead_letter'::puls_workflow.expense_receipt_ocr_job_status THEN NULL
        ELSE 120
      END,
      updated.status = 'dead_letter'::puls_workflow.expense_receipt_ocr_job_status
    FROM updated
    RETURNING id
  )
  SELECT COUNT(*) INTO v_count FROM updated;

  RETURN v_count;
END;
$$;

COMMENT ON TABLE puls_workflow.expense_receipt_ocr_jobs
  IS 'PR17.2G2A provider-agnostic expense receipt processing queue. No trigger or browser path enqueues production jobs in this slice.';

COMMENT ON TABLE puls_workflow.expense_receipt_ocr_results
  IS 'Safe OCR/extraction suggestions for expense receipts. Raw OCR text and provider payloads are intentionally excluded.';

COMMENT ON TABLE puls_workflow.expense_receipt_ocr_job_events
  IS 'Immutable event ledger for expense receipt OCR job lifecycle. Safe context only.';

COMMENT ON COLUMN puls_workflow.expense_receipt_ocr_results.server_sha256
  IS 'Server-computed content hash populated by a future worker path. sha256_client remains informational only.';

REVOKE ALL ON TABLE puls_workflow.expense_receipt_ocr_jobs FROM anon, authenticated;
REVOKE ALL ON TABLE puls_workflow.expense_receipt_ocr_results FROM anon, authenticated;
REVOKE ALL ON TABLE puls_workflow.expense_receipt_ocr_job_events FROM anon, authenticated;
GRANT SELECT ON TABLE puls_workflow.expense_receipt_ocr_jobs TO authenticated;
GRANT SELECT ON TABLE puls_workflow.expense_receipt_ocr_results TO authenticated;
GRANT SELECT ON TABLE puls_workflow.expense_receipt_ocr_job_events TO authenticated;
GRANT ALL ON TABLE puls_workflow.expense_receipt_ocr_jobs TO service_role;
GRANT ALL ON TABLE puls_workflow.expense_receipt_ocr_results TO service_role;
GRANT ALL ON TABLE puls_workflow.expense_receipt_ocr_job_events TO service_role;

REVOKE ALL ON FUNCTION puls_workflow.expense_receipt_ocr_safe_context_has_blocked_key(JSONB) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION puls_workflow.can_read_expense_receipt_ocr(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION puls_workflow._record_expense_receipt_ocr_job_event(puls_workflow.expense_receipt_ocr_jobs, TEXT, TEXT, TEXT, JSONB, INTEGER, BOOLEAN) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION puls_workflow.enqueue_expense_receipt_ocr_job(UUID, TEXT, puls_workflow.expense_receipt_ocr_provider_class, INTEGER, TIMESTAMPTZ, INTEGER, JSONB, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION puls_workflow.claim_next_expense_receipt_ocr_job(TEXT, INTEGER, INTEGER) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION puls_workflow.heartbeat_expense_receipt_ocr_job(UUID, TEXT, INTEGER, JSONB) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION puls_workflow.complete_expense_receipt_ocr_job(UUID, TEXT, puls_workflow.expense_receipt_ocr_job_status, TEXT, JSONB, JSONB, NUMERIC, JSONB, puls_workflow.expense_receipt_ocr_provider_class, TEXT, TEXT, TEXT, JSONB, TEXT, JSONB, TEXT, INTEGER) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION puls_workflow.recover_stale_expense_receipt_ocr_jobs(TEXT, INTEGER) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION puls_workflow.can_read_expense_receipt_ocr(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION puls_workflow.enqueue_expense_receipt_ocr_job(UUID, TEXT, puls_workflow.expense_receipt_ocr_provider_class, INTEGER, TIMESTAMPTZ, INTEGER, JSONB, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION puls_workflow.claim_next_expense_receipt_ocr_job(TEXT, INTEGER, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION puls_workflow.heartbeat_expense_receipt_ocr_job(UUID, TEXT, INTEGER, JSONB) TO service_role;
GRANT EXECUTE ON FUNCTION puls_workflow.complete_expense_receipt_ocr_job(UUID, TEXT, puls_workflow.expense_receipt_ocr_job_status, TEXT, JSONB, JSONB, NUMERIC, JSONB, puls_workflow.expense_receipt_ocr_provider_class, TEXT, TEXT, TEXT, JSONB, TEXT, JSONB, TEXT, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION puls_workflow.recover_stale_expense_receipt_ocr_jobs(TEXT, INTEGER) TO service_role;
