-- PR17.2G2A — Expense receipt OCR DB contract smoke.
--
-- Runs inside BEGIN ... ROLLBACK. It does not call an OCR provider, does not
-- create production enqueue triggers, and does not persist OCR jobs/results.
-- It creates its own minimal tenant/employee/category/claim/receipt fixture
-- inside the rollback transaction.
--
-- Usage:
--   psql "$DATABASE_URL" \
--     -v tenant_id='<optional tenant uuid>' \
--     -f docs/data/17_2_g2a_expense_receipt_ocr_db_contract_smoke.sql

\set ON_ERROR_STOP on

\if :{?tenant_id}
\else
\set tenant_id '00000000-0000-0000-0000-000000000000'
\endif

CREATE TEMP TABLE IF NOT EXISTS pr17_2g2a_psql_vars (
  key TEXT PRIMARY KEY,
  raw_value TEXT NOT NULL
);

TRUNCATE pr17_2g2a_psql_vars;

INSERT INTO pr17_2g2a_psql_vars (key, raw_value) VALUES
  ('tenant_id', :'tenant_id');

BEGIN;

DO $$
DECLARE
  v_zero UUID := '00000000-0000-0000-0000-000000000000';
  v_raw TEXT;
  v_requested_tenant_id UUID;
  v_tenant_id UUID;
  v_receipt_id UUID;
  v_claim_id UUID;
  v_category_id UUID;
  v_uploader_id UUID;
  v_job_id UUID;
  v_duplicate_job_id UUID;
  v_claimed RECORD;
  v_result_id UUID;
  v_duplicate_receipt_id UUID;
  v_duplicate_result_id UUID;
  v_worker_id TEXT := 'pr17-2g2a-smoke-worker';
  v_server_sha256 TEXT := 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  v_active_job_count INTEGER;
BEGIN
  SELECT raw_value INTO v_raw FROM pr17_2g2a_psql_vars WHERE key = 'tenant_id';
  v_requested_tenant_id := NULLIF(NULLIF(BTRIM(COALESCE(v_raw, '')), ''), v_zero::TEXT)::UUID;

  PERFORM set_config('request.jwt.claim.role', 'service_role', TRUE);
  PERFORM set_config('request.jwt.claim.sub', '', TRUE);

  IF v_requested_tenant_id IS NOT NULL THEN
    INSERT INTO puls_core.tenants (id, name, legal_name)
    VALUES (v_requested_tenant_id, 'PR17.2G2A Smoke Tenant', 'PR17.2G2A Smoke Tenant')
    ON CONFLICT (id) DO NOTHING;
    v_tenant_id := v_requested_tenant_id;
  ELSE
    INSERT INTO puls_core.tenants (name, legal_name)
    VALUES ('PR17.2G2A Smoke Tenant', 'PR17.2G2A Smoke Tenant')
    RETURNING id INTO v_tenant_id;
  END IF;

  INSERT INTO puls_core.employees (
    tenant_id,
    full_name,
    employee_code,
    persona_role,
    employment_status
  )
  VALUES (
    v_tenant_id,
    'PR17.2G2A Smoke Employee',
    'pr17_2g2a',
    'employee'::puls_core.persona_role,
    'active'::puls_core.employment_status
  )
  RETURNING id INTO v_uploader_id;

  INSERT INTO puls_workflow.expense_categories (
    tenant_id,
    code,
    name,
    receipt_required_over,
    is_active
  )
  VALUES (
    v_tenant_id,
    'pr17_2g2a',
    'PR17.2G2A Smoke Category',
    0,
    TRUE
  )
  RETURNING id INTO v_category_id;

  INSERT INTO puls_workflow.expense_claims (
    tenant_id,
    employee_id,
    category_id,
    amount,
    currency,
    vat_rate,
    vat_included,
    expense_date,
    title,
    description,
    status
  )
  VALUES (
    v_tenant_id,
    v_uploader_id,
    v_category_id,
    123.45,
    'TRY',
    20,
    TRUE,
    CURRENT_DATE,
    'PR17.2G2A Smoke Expense',
    'Rollback-only OCR DB contract smoke',
    'pending'::puls_workflow.expense_claim_status
  )
  RETURNING id INTO v_claim_id;

  INSERT INTO puls_workflow.expense_receipts (
    tenant_id,
    expense_claim_id,
    uploaded_by_employee_id,
    file_ref,
    file_name,
    mime_type,
    file_size_bytes,
    ocr_status,
    status
  )
  VALUES (
    v_tenant_id,
    v_claim_id,
    v_uploader_id,
    'pr17-2g2a-smoke/original.pdf',
    'original.pdf',
    'application/pdf',
    1234,
    'not_requested',
    'pending'::puls_workflow.document_status
  )
  RETURNING id INTO v_receipt_id;

  v_job_id := puls_workflow.enqueue_expense_receipt_ocr_job(
    v_receipt_id,
    NULL,
    'mock'::puls_workflow.expense_receipt_ocr_provider_class,
    10,
    NOW(),
    3,
    jsonb_build_object('smoke', 'pr17.2g2a'),
    'review_expense_receipt_ocr_status'
  );

  v_duplicate_job_id := puls_workflow.enqueue_expense_receipt_ocr_job(
    v_receipt_id,
    NULL,
    'mock'::puls_workflow.expense_receipt_ocr_provider_class,
    10,
    NOW(),
    3,
    jsonb_build_object('smoke', 'pr17.2g2a_idempotent'),
    'review_expense_receipt_ocr_status'
  );

  IF v_duplicate_job_id IS DISTINCT FROM v_job_id THEN
    RAISE EXCEPTION 'PR17_2G2A_SMOKE_FAIL: idempotent enqueue returned %, expected %', v_duplicate_job_id, v_job_id;
  END IF;

  SELECT COUNT(*)
  INTO v_active_job_count
  FROM puls_workflow.expense_receipt_ocr_jobs job
  WHERE job.tenant_id = v_tenant_id
    AND job.expense_receipt_id = v_receipt_id
    AND job.status IN (
      'queued'::puls_workflow.expense_receipt_ocr_job_status,
      'processing'::puls_workflow.expense_receipt_ocr_job_status,
      'retrying'::puls_workflow.expense_receipt_ocr_job_status
    );

  IF v_active_job_count <> 1 THEN
    RAISE EXCEPTION 'PR17_2G2A_SMOKE_FAIL: expected one active OCR job, got %', v_active_job_count;
  END IF;

  SELECT *
  INTO v_claimed
  FROM puls_workflow.claim_next_expense_receipt_ocr_job(v_worker_id, 1, 300);

  IF v_claimed.job_id IS DISTINCT FROM v_job_id
     OR v_claimed.status <> 'processing'
     OR v_claimed.attempt_count <> 1 THEN
    RAISE EXCEPTION 'PR17_2G2A_SMOKE_FAIL: claim result mismatch: %', row_to_json(v_claimed);
  END IF;

  IF (SELECT receipt.ocr_status FROM puls_workflow.expense_receipts receipt WHERE receipt.id = v_receipt_id) <> 'processing' THEN
    RAISE EXCEPTION 'PR17_2G2A_SMOKE_FAIL: receipt projection was not set to processing.';
  END IF;

  PERFORM puls_workflow.heartbeat_expense_receipt_ocr_job(v_job_id, v_worker_id, 300, '{}'::JSONB);

  v_result_id := puls_workflow.complete_expense_receipt_ocr_job(
    v_job_id,
    v_worker_id,
    'completed'::puls_workflow.expense_receipt_ocr_job_status,
    v_server_sha256,
    jsonb_build_object(
      'vendor', 'Smoke Market',
      'receipt_date', CURRENT_DATE::TEXT,
      'total_amount', '123.45',
      'currency', 'TRY'
    ),
    jsonb_build_object('vendor', 0.95, 'total_amount', 0.99),
    0.98,
    '[]'::JSONB,
    'mock'::puls_workflow.expense_receipt_ocr_provider_class,
    'pr17-smoke',
    'g2a',
    'mock-reference',
    jsonb_build_object('estimated_cost_minor', 0),
    NULL,
    '{}'::JSONB,
    'human_review_required',
    NULL
  );

  IF NOT EXISTS (
    SELECT 1
    FROM puls_workflow.expense_receipt_ocr_results result
    WHERE result.id = v_result_id
      AND result.job_id = v_job_id
      AND result.server_sha256 = v_server_sha256
      AND result.review_status = 'pending_review'::puls_workflow.expense_receipt_ocr_review_status
  ) THEN
    RAISE EXCEPTION 'PR17_2G2A_SMOKE_FAIL: completed OCR result was not written.';
  END IF;

  IF (SELECT receipt.ocr_status FROM puls_workflow.expense_receipts receipt WHERE receipt.id = v_receipt_id) <> 'completed' THEN
    RAISE EXCEPTION 'PR17_2G2A_SMOKE_FAIL: receipt projection was not set to completed.';
  END IF;

  INSERT INTO puls_workflow.expense_receipts (
    tenant_id,
    expense_claim_id,
    uploaded_by_employee_id,
    file_ref,
    file_name,
    mime_type,
    file_size_bytes,
    ocr_status,
    status
  )
  VALUES (
    v_tenant_id,
    v_claim_id,
    v_uploader_id,
    'pr17-2g2a-smoke/duplicate.pdf',
    'duplicate.pdf',
    'application/pdf',
    1234,
    'not_requested',
    'pending'::puls_workflow.document_status
  )
  RETURNING id INTO v_duplicate_receipt_id;

  v_duplicate_job_id := puls_workflow.enqueue_expense_receipt_ocr_job(v_duplicate_receipt_id);

  SELECT *
  INTO v_claimed
  FROM puls_workflow.claim_next_expense_receipt_ocr_job(v_worker_id, 1, 300);

  IF v_claimed.job_id IS DISTINCT FROM v_duplicate_job_id THEN
    RAISE EXCEPTION 'PR17_2G2A_SMOKE_FAIL: duplicate receipt job was not claimed.';
  END IF;

  v_duplicate_result_id := puls_workflow.complete_expense_receipt_ocr_job(
    v_duplicate_job_id,
    v_worker_id,
    'completed'::puls_workflow.expense_receipt_ocr_job_status,
    v_server_sha256,
    '{}'::JSONB,
    '{}'::JSONB,
    0.80,
    '[]'::JSONB,
    'mock'::puls_workflow.expense_receipt_ocr_provider_class,
    'pr17-smoke',
    'g2a',
    NULL,
    '{}'::JSONB,
    NULL,
    '{}'::JSONB,
    NULL,
    NULL
  );

  IF NOT EXISTS (
    SELECT 1
    FROM puls_workflow.expense_receipt_ocr_results result
    WHERE result.id = v_duplicate_result_id
      AND result.duplicate_of_result_id = v_result_id
      AND result.mismatch_flags ? 'duplicate_suspected'
  ) THEN
    RAISE EXCEPTION 'PR17_2G2A_SMOKE_FAIL: duplicate suspicion was not recorded.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM puls_workflow.expense_receipt_ocr_job_events event
    WHERE event.tenant_id = v_tenant_id
      AND event.job_id IN (v_job_id, v_duplicate_job_id)
      AND event.event_key IN (
        'expense_receipt_ocr.job_queued',
        'expense_receipt_ocr.job_claimed',
        'expense_receipt_ocr.job_completed'
      )
  ) THEN
    RAISE EXCEPTION 'PR17_2G2A_SMOKE_FAIL: OCR job events were not recorded.';
  END IF;
END;
$$;

ROLLBACK;
