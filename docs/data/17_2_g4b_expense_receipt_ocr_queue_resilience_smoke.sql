-- PR17.2G4B — Expense receipt OCR queue resilience smoke.
--
-- Runs inside BEGIN ... ROLLBACK. It proves the OCR queue can recover stale
-- leases, retry a job, and dead-letter the job after max attempts while keeping
-- the expense_receipts.ocr_status projection consistent. It does not call an OCR
-- provider and does not persist jobs.
--
-- Usage:
--   psql "$DATABASE_URL" \
--     -v tenant_id='<optional tenant uuid>' \
--     -f docs/data/17_2_g4b_expense_receipt_ocr_queue_resilience_smoke.sql

\set ON_ERROR_STOP on

\if :{?tenant_id}
\else
\set tenant_id '00000000-0000-0000-0000-000000000000'
\endif

CREATE TEMP TABLE IF NOT EXISTS pr17_2g4b_psql_vars (
  key TEXT PRIMARY KEY,
  raw_value TEXT NOT NULL
);

TRUNCATE pr17_2g4b_psql_vars;

INSERT INTO pr17_2g4b_psql_vars (key, raw_value) VALUES
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
  v_claimed_job_id UUID;
  v_recovered_count INTEGER;
  v_worker_id TEXT := 'pr17_2g4b_smoke_worker';
BEGIN
  SELECT raw_value INTO v_raw FROM pr17_2g4b_psql_vars WHERE key = 'tenant_id';
  v_requested_tenant_id := NULLIF(NULLIF(BTRIM(COALESCE(v_raw, '')), ''), v_zero::TEXT)::UUID;

  PERFORM set_config('request.jwt.claim.role', 'service_role', TRUE);
  PERFORM set_config('request.jwt.claim.sub', '', TRUE);

  IF v_requested_tenant_id IS NOT NULL THEN
    INSERT INTO puls_core.tenants (id, name, legal_name)
    VALUES (v_requested_tenant_id, 'PR17.2G4B Smoke Tenant', 'PR17.2G4B Smoke Tenant')
    ON CONFLICT (id) DO NOTHING;
    v_tenant_id := v_requested_tenant_id;
  ELSE
    INSERT INTO puls_core.tenants (name, legal_name)
    VALUES ('PR17.2G4B Smoke Tenant', 'PR17.2G4B Smoke Tenant')
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
    'PR17.2G4B Smoke Employee',
    'pr17_2g4b',
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
    'pr17_2g4b',
    'PR17.2G4B Smoke Category',
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
    'PR17.2G4B Smoke Expense',
    'Rollback-only OCR queue resilience smoke',
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
    'pr17-2g4b-smoke/original.pdf',
    'original.pdf',
    'application/pdf',
    1234,
    'not_requested',
    'pending'::puls_workflow.document_status
  )
  RETURNING id INTO v_receipt_id;

  INSERT INTO puls_workflow.expense_receipt_ocr_tenant_posture (
    tenant_id,
    enabled,
    monthly_document_quota,
    monthly_spend_cap_minor,
    provider_class_allowlist,
    region_label,
    retention_policy_label
  )
  VALUES (
    v_tenant_id,
    TRUE,
    10,
    0,
    ARRAY['mock'::puls_workflow.expense_receipt_ocr_provider_class],
    'test',
    'rollback_only'
  );

  v_job_id := puls_workflow.enqueue_expense_receipt_ocr_job(
    p_expense_receipt_id => v_receipt_id,
    p_provider_class => 'mock'::puls_workflow.expense_receipt_ocr_provider_class,
    p_max_attempts => 2,
    p_safe_error_context => jsonb_build_object('smoke', 'pr17.2g4b_queue_resilience'),
    p_estimated_cost_minor => 0,
    p_document_page_count => 1
  );

  SELECT job_id
  INTO v_claimed_job_id
  FROM puls_workflow.claim_next_expense_receipt_ocr_job(v_worker_id, 1, 30);

  IF v_claimed_job_id IS DISTINCT FROM v_job_id THEN
    RAISE EXCEPTION 'PR17_2G4B_SMOKE_FAIL: first claim did not return the queued job.';
  END IF;

  PERFORM puls_workflow.heartbeat_expense_receipt_ocr_job(
    v_job_id,
    v_worker_id,
    30,
    jsonb_build_object('smoke', 'pr17.2g4b_heartbeat')
  );

  IF NOT EXISTS (
    SELECT 1
    FROM puls_workflow.expense_receipt_ocr_job_events event
    WHERE event.job_id = v_job_id
      AND event.event_key = 'expense_receipt_ocr.job_heartbeat'
      AND event.worker_id = v_worker_id
  ) THEN
    RAISE EXCEPTION 'PR17_2G4B_SMOKE_FAIL: heartbeat event was not recorded.';
  END IF;

  UPDATE puls_workflow.expense_receipt_ocr_jobs
  SET lease_expires_at = NOW() - INTERVAL '1 second'
  WHERE id = v_job_id;

  v_recovered_count := puls_workflow.recover_stale_expense_receipt_ocr_jobs(v_worker_id, 25);

  IF v_recovered_count <> 1 THEN
    RAISE EXCEPTION 'PR17_2G4B_SMOKE_FAIL: expected one recovered stale job, got %.', v_recovered_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM puls_workflow.expense_receipt_ocr_jobs job
    JOIN puls_workflow.expense_receipts receipt
      ON receipt.id = job.expense_receipt_id
    WHERE job.id = v_job_id
      AND job.status = 'retrying'::puls_workflow.expense_receipt_ocr_job_status
      AND job.attempt_count = 1
      AND job.locked_by IS NULL
      AND job.lease_expires_at IS NULL
      AND job.safe_error_code = 'OCR_LEASE_EXPIRED'
      AND receipt.ocr_status = 'queued'
  ) THEN
    RAISE EXCEPTION 'PR17_2G4B_SMOKE_FAIL: recovered job did not move to retrying with queued projection.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM puls_workflow.expense_receipt_ocr_job_events event
    WHERE event.job_id = v_job_id
      AND event.event_key = 'expense_receipt_ocr.job_recovered'
      AND event.safe_error_code = 'OCR_LEASE_EXPIRED'
      AND event.retry_after_seconds = 120
      AND event.operator_review_required IS FALSE
  ) THEN
    RAISE EXCEPTION 'PR17_2G4B_SMOKE_FAIL: recovery event was not recorded.';
  END IF;

  UPDATE puls_workflow.expense_receipt_ocr_jobs
  SET scheduled_at = NOW() - INTERVAL '1 second'
  WHERE id = v_job_id;

  SELECT job_id
  INTO v_claimed_job_id
  FROM puls_workflow.claim_next_expense_receipt_ocr_job(v_worker_id, 1, 30);

  IF v_claimed_job_id IS DISTINCT FROM v_job_id THEN
    RAISE EXCEPTION 'PR17_2G4B_SMOKE_FAIL: retry claim did not return the recovered job.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM puls_workflow.expense_receipt_ocr_jobs job
    JOIN puls_workflow.expense_receipts receipt
      ON receipt.id = job.expense_receipt_id
    WHERE job.id = v_job_id
      AND job.status = 'processing'::puls_workflow.expense_receipt_ocr_job_status
      AND job.attempt_count = 2
      AND receipt.ocr_status = 'processing'
  ) THEN
    RAISE EXCEPTION 'PR17_2G4B_SMOKE_FAIL: retry claim did not restore processing projection.';
  END IF;

  UPDATE puls_workflow.expense_receipt_ocr_jobs
  SET lease_expires_at = NOW() - INTERVAL '1 second'
  WHERE id = v_job_id;

  v_recovered_count := puls_workflow.recover_stale_expense_receipt_ocr_jobs(v_worker_id, 25);

  IF v_recovered_count <> 1 THEN
    RAISE EXCEPTION 'PR17_2G4B_SMOKE_FAIL: expected one dead-letter recovery, got %.', v_recovered_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM puls_workflow.expense_receipt_ocr_jobs job
    JOIN puls_workflow.expense_receipts receipt
      ON receipt.id = job.expense_receipt_id
    WHERE job.id = v_job_id
      AND job.status = 'dead_letter'::puls_workflow.expense_receipt_ocr_job_status
      AND job.attempt_count = 2
      AND job.locked_by IS NULL
      AND job.lease_expires_at IS NULL
      AND job.safe_error_code = 'OCR_LEASE_EXPIRED'
      AND receipt.ocr_status = 'failed'
  ) THEN
    RAISE EXCEPTION 'PR17_2G4B_SMOKE_FAIL: max-attempt stale job did not dead-letter with failed projection.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM puls_workflow.expense_receipt_ocr_job_events event
    WHERE event.job_id = v_job_id
      AND event.event_key = 'expense_receipt_ocr.job_dead_lettered'
      AND event.safe_error_code = 'OCR_LEASE_EXPIRED'
      AND event.retry_after_seconds IS NULL
      AND event.operator_review_required IS TRUE
  ) THEN
    RAISE EXCEPTION 'PR17_2G4B_SMOKE_FAIL: dead-letter event was not recorded.';
  END IF;
END;
$$;

ROLLBACK;
