-- PR17.2G4A — Expense receipt OCR quota gate smoke.
--
-- Runs inside BEGIN ... ROLLBACK. It proves OCR enqueue remains closed by
-- default and opens only when tenant posture, quota, provider allowlist, and
-- spend caps explicitly allow it. It does not call an OCR provider and does not
-- persist jobs.
--
-- Usage:
--   psql "$DATABASE_URL" \
--     -v tenant_id='<optional tenant uuid>' \
--     -f docs/data/17_2_g4a_expense_receipt_ocr_quota_gate_smoke.sql

\set ON_ERROR_STOP on

\if :{?tenant_id}
\else
\set tenant_id '00000000-0000-0000-0000-000000000000'
\endif

CREATE TEMP TABLE IF NOT EXISTS pr17_2g4a_psql_vars (
  key TEXT PRIMARY KEY,
  raw_value TEXT NOT NULL
);

TRUNCATE pr17_2g4a_psql_vars;

INSERT INTO pr17_2g4a_psql_vars (key, raw_value) VALUES
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
  v_paid_receipt_id UUID;
  v_paid_job_id UUID;
BEGIN
  SELECT raw_value INTO v_raw FROM pr17_2g4a_psql_vars WHERE key = 'tenant_id';
  v_requested_tenant_id := NULLIF(NULLIF(BTRIM(COALESCE(v_raw, '')), ''), v_zero::TEXT)::UUID;

  PERFORM set_config('request.jwt.claim.role', 'service_role', TRUE);
  PERFORM set_config('request.jwt.claim.sub', '', TRUE);

  IF v_requested_tenant_id IS NOT NULL THEN
    INSERT INTO puls_core.tenants (id, name, legal_name)
    VALUES (v_requested_tenant_id, 'PR17.2G4A Smoke Tenant', 'PR17.2G4A Smoke Tenant')
    ON CONFLICT (id) DO NOTHING;
    v_tenant_id := v_requested_tenant_id;
  ELSE
    INSERT INTO puls_core.tenants (name, legal_name)
    VALUES ('PR17.2G4A Smoke Tenant', 'PR17.2G4A Smoke Tenant')
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
    'PR17.2G4A Smoke Employee',
    'pr17_2g4a',
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
    'pr17_2g4a',
    'PR17.2G4A Smoke Category',
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
    'PR17.2G4A Smoke Expense',
    'Rollback-only OCR quota gate smoke',
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
    'pr17-2g4a-smoke/original.pdf',
    'original.pdf',
    'application/pdf',
    1234,
    'not_requested',
    'pending'::puls_workflow.document_status
  )
  RETURNING id INTO v_receipt_id;

  BEGIN
    PERFORM puls_workflow.enqueue_expense_receipt_ocr_job(
      p_expense_receipt_id => v_receipt_id,
      p_provider_class => 'mock'::puls_workflow.expense_receipt_ocr_provider_class
    );
    RAISE EXCEPTION 'PR17_2G4A_SMOKE_FAIL: enqueue without tenant posture should fail.';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'PULS_OCR_TENANT_DISABLED:%' THEN
      RAISE;
    END IF;
  END;

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
    FALSE,
    10,
    0,
    ARRAY['mock'::puls_workflow.expense_receipt_ocr_provider_class],
    'test',
    'rollback_only'
  );

  BEGIN
    PERFORM puls_workflow.enqueue_expense_receipt_ocr_job(
      p_expense_receipt_id => v_receipt_id,
      p_provider_class => 'mock'::puls_workflow.expense_receipt_ocr_provider_class
    );
    RAISE EXCEPTION 'PR17_2G4A_SMOKE_FAIL: disabled tenant posture should fail.';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'PULS_OCR_TENANT_DISABLED:%' THEN
      RAISE;
    END IF;
  END;

  UPDATE puls_workflow.expense_receipt_ocr_tenant_posture
  SET
    enabled = TRUE,
    monthly_document_quota = 0,
    updated_at = NOW()
  WHERE tenant_id = v_tenant_id;

  BEGIN
    PERFORM puls_workflow.enqueue_expense_receipt_ocr_job(
      p_expense_receipt_id => v_receipt_id,
      p_provider_class => 'mock'::puls_workflow.expense_receipt_ocr_provider_class
    );
    RAISE EXCEPTION 'PR17_2G4A_SMOKE_FAIL: zero tenant quota should fail.';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'PULS_OCR_QUOTA_EXHAUSTED:%' THEN
      RAISE;
    END IF;
  END;

  UPDATE puls_workflow.expense_receipt_ocr_tenant_posture
  SET
    monthly_document_quota = 10,
    provider_class_allowlist = ARRAY['disabled'::puls_workflow.expense_receipt_ocr_provider_class],
    updated_at = NOW()
  WHERE tenant_id = v_tenant_id;

  BEGIN
    PERFORM puls_workflow.enqueue_expense_receipt_ocr_job(
      p_expense_receipt_id => v_receipt_id,
      p_provider_class => 'mock'::puls_workflow.expense_receipt_ocr_provider_class
    );
    RAISE EXCEPTION 'PR17_2G4A_SMOKE_FAIL: disallowed provider class should fail.';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'PULS_OCR_PROVIDER_CLASS_NOT_ALLOWED:%' THEN
      RAISE;
    END IF;
  END;

  UPDATE puls_workflow.expense_receipt_ocr_tenant_posture
  SET
    provider_class_allowlist = ARRAY['mock'::puls_workflow.expense_receipt_ocr_provider_class],
    monthly_spend_cap_minor = 0,
    updated_at = NOW()
  WHERE tenant_id = v_tenant_id;

  BEGIN
    PERFORM puls_workflow.enqueue_expense_receipt_ocr_job(
      p_expense_receipt_id => v_receipt_id,
      p_provider_class => 'mock'::puls_workflow.expense_receipt_ocr_provider_class,
      p_estimated_cost_minor => 1
    );
    RAISE EXCEPTION 'PR17_2G4A_SMOKE_FAIL: positive tenant spend with zero cap should fail.';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'PULS_OCR_SPEND_CAP_EXCEEDED:%' THEN
      RAISE;
    END IF;
  END;

  UPDATE puls_workflow.expense_receipt_ocr_tenant_posture
  SET
    monthly_spend_cap_minor = 100,
    updated_at = NOW()
  WHERE tenant_id = v_tenant_id;

  DELETE FROM puls_workflow.expense_receipt_ocr_global_posture WHERE singleton IS TRUE;

  BEGIN
    PERFORM puls_workflow.enqueue_expense_receipt_ocr_job(
      p_expense_receipt_id => v_receipt_id,
      p_provider_class => 'mock'::puls_workflow.expense_receipt_ocr_provider_class,
      p_estimated_cost_minor => 1
    );
    RAISE EXCEPTION 'PR17_2G4A_SMOKE_FAIL: positive global spend with absent zero cap should fail.';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'PULS_OCR_GLOBAL_SPEND_CAP_EXCEEDED:%' THEN
      RAISE;
    END IF;
  END;

  v_job_id := puls_workflow.enqueue_expense_receipt_ocr_job(
    p_expense_receipt_id => v_receipt_id,
    p_provider_class => 'mock'::puls_workflow.expense_receipt_ocr_provider_class,
    p_safe_error_context => jsonb_build_object('smoke', 'pr17.2g4a_zero_cost'),
    p_estimated_cost_minor => 0,
    p_document_page_count => 1
  );

  IF NOT EXISTS (
    SELECT 1
    FROM puls_workflow.expense_receipt_ocr_jobs job
    WHERE job.id = v_job_id
      AND job.tenant_id = v_tenant_id
      AND job.provider_class = 'mock'::puls_workflow.expense_receipt_ocr_provider_class
      AND job.estimated_cost_minor = 0
      AND job.document_page_count = 1
  ) THEN
    RAISE EXCEPTION 'PR17_2G4A_SMOKE_FAIL: zero-cost allowed enqueue did not create expected job.';
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
    'pr17-2g4a-smoke/paid.pdf',
    'paid.pdf',
    'application/pdf',
    1234,
    'not_requested',
    'pending'::puls_workflow.document_status
  )
  RETURNING id INTO v_paid_receipt_id;

  INSERT INTO puls_workflow.expense_receipt_ocr_global_posture (
    singleton,
    monthly_spend_cap_minor,
    spend_currency
  )
  VALUES (TRUE, 100, 'USD')
  ON CONFLICT (singleton) DO UPDATE
  SET
    monthly_spend_cap_minor = EXCLUDED.monthly_spend_cap_minor,
    spend_currency = EXCLUDED.spend_currency,
    updated_at = NOW();

  v_paid_job_id := puls_workflow.enqueue_expense_receipt_ocr_job(
    p_expense_receipt_id => v_paid_receipt_id,
    p_provider_class => 'mock'::puls_workflow.expense_receipt_ocr_provider_class,
    p_safe_error_context => jsonb_build_object('smoke', 'pr17.2g4a_paid_cap'),
    p_estimated_cost_minor => 1,
    p_document_page_count => 1
  );

  IF NOT EXISTS (
    SELECT 1
    FROM puls_workflow.expense_receipt_ocr_jobs job
    WHERE job.id = v_paid_job_id
      AND job.estimated_cost_minor = 1
      AND job.estimated_cost_currency = 'USD'
  ) THEN
    RAISE EXCEPTION 'PR17_2G4A_SMOKE_FAIL: positive-cost enqueue did not respect configured caps.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM puls_workflow.expense_receipt_ocr_job_events event
    WHERE event.tenant_id = v_tenant_id
      AND event.job_id IN (v_job_id, v_paid_job_id)
      AND event.safe_error_context ->> 'quota_gate_enforced' = 'true'
  ) THEN
    RAISE EXCEPTION 'PR17_2G4A_SMOKE_FAIL: quota-gated enqueue event was not recorded.';
  END IF;
END;
$$;

ROLLBACK;
