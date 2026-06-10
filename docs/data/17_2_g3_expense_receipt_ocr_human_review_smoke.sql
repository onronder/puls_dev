-- PR17.2G3 — Expense receipt OCR human review smoke.
--
-- Runs inside BEGIN ... ROLLBACK. It proves that an assigned approver can
-- record a human review decision for an OCR result without mutating canonical
-- expense claim fields, storing raw OCR text in audit metadata, or reopening
-- the result for repeated decisions.
--
-- Usage:
--   psql "$DATABASE_URL" \
--     -v tenant_id='<optional tenant uuid>' \
--     -f docs/data/17_2_g3_expense_receipt_ocr_human_review_smoke.sql

\set ON_ERROR_STOP on

\if :{?tenant_id}
\else
\set tenant_id '00000000-0000-0000-0000-000000000000'
\endif

CREATE TEMP TABLE IF NOT EXISTS pr17_2g3_psql_vars (
  key TEXT PRIMARY KEY,
  raw_value TEXT NOT NULL
);

TRUNCATE pr17_2g3_psql_vars;

INSERT INTO pr17_2g3_psql_vars (key, raw_value) VALUES
  ('tenant_id', :'tenant_id');

BEGIN;

DO $$
DECLARE
  v_zero UUID := '00000000-0000-0000-0000-000000000000';
  v_raw TEXT;
  v_requested_tenant_id UUID;
  v_tenant_id UUID;
  v_requester_user_id UUID := gen_random_uuid();
  v_reviewer_user_id UUID := gen_random_uuid();
  v_unauthorized_user_id UUID := gen_random_uuid();
  v_requester_id UUID;
  v_reviewer_id UUID;
  v_category_id UUID;
  v_claim_id UUID;
  v_receipt_id UUID;
  v_approval_id UUID;
  v_job_id UUID;
  v_claimed RECORD;
  v_result_id UUID;
  v_review JSONB;
  v_worker_id TEXT := 'pr17-2g3-smoke-worker';
  v_amount_before NUMERIC;
  v_status_before TEXT;
BEGIN
  SELECT raw_value INTO v_raw FROM pr17_2g3_psql_vars WHERE key = 'tenant_id';
  v_requested_tenant_id := NULLIF(NULLIF(BTRIM(COALESCE(v_raw, '')), ''), v_zero::TEXT)::UUID;

  PERFORM set_config('request.jwt.claim.role', 'service_role', TRUE);
  PERFORM set_config('request.jwt.claim.sub', '', TRUE);

  INSERT INTO auth.users (
    id,
    instance_id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    created_at,
    updated_at
  )
  VALUES (
    v_requester_user_id,
    v_zero,
    'authenticated',
    'authenticated',
    'pr17.2g3.requester@example.invalid',
    'not-used',
    NOW(),
    NOW(),
    NOW()
  ),
  (
    v_reviewer_user_id,
    v_zero,
    'authenticated',
    'authenticated',
    'pr17.2g3.reviewer@example.invalid',
    'not-used',
    NOW(),
    NOW(),
    NOW()
  ),
  (
    v_unauthorized_user_id,
    v_zero,
    'authenticated',
    'authenticated',
    'pr17.2g3.unauthorized@example.invalid',
    'not-used',
    NOW(),
    NOW(),
    NOW()
  );

  IF v_requested_tenant_id IS NOT NULL THEN
    INSERT INTO puls_core.tenants (id, name, legal_name)
    VALUES (v_requested_tenant_id, 'PR17.2G3 Smoke Tenant', 'PR17.2G3 Smoke Tenant')
    ON CONFLICT (id) DO NOTHING;
    v_tenant_id := v_requested_tenant_id;
  ELSE
    INSERT INTO puls_core.tenants (name, legal_name)
    VALUES ('PR17.2G3 Smoke Tenant', 'PR17.2G3 Smoke Tenant')
    RETURNING id INTO v_tenant_id;
  END IF;

  INSERT INTO puls_core.employees (
    tenant_id,
    user_id,
    full_name,
    employee_code,
    persona_role,
    employment_status
  )
  VALUES (
    v_tenant_id,
    v_requester_user_id,
    'PR17.2G3 Smoke Requester',
    'pr17_2g3_requester',
    'employee'::puls_core.persona_role,
    'active'::puls_core.employment_status
  )
  RETURNING id INTO v_requester_id;

  INSERT INTO puls_core.employees (
    tenant_id,
    user_id,
    full_name,
    employee_code,
    persona_role,
    employment_status
  )
  VALUES (
    v_tenant_id,
    v_reviewer_user_id,
    'PR17.2G3 Smoke Reviewer',
    'pr17_2g3_reviewer',
    'manager'::puls_core.persona_role,
    'active'::puls_core.employment_status
  )
  RETURNING id INTO v_reviewer_id;

  INSERT INTO puls_core.employees (
    tenant_id,
    user_id,
    full_name,
    employee_code,
    persona_role,
    employment_status
  )
  VALUES (
    v_tenant_id,
    v_unauthorized_user_id,
    'PR17.2G3 Smoke Unassigned Reviewer',
    'pr17_2g3_unassigned',
    'manager'::puls_core.persona_role,
    'active'::puls_core.employment_status
  );

  INSERT INTO puls_workflow.expense_categories (
    tenant_id,
    code,
    name,
    receipt_required_over,
    is_active
  )
  VALUES (
    v_tenant_id,
    'pr17_2g3',
    'PR17.2G3 Smoke Category',
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
    v_requester_id,
    v_category_id,
    123.45,
    'TRY',
    20,
    TRUE,
    CURRENT_DATE,
    'PR17.2G3 Smoke Expense',
    'Rollback-only OCR human review smoke',
    'pending'::puls_workflow.expense_claim_status
  )
  RETURNING id, amount, status::TEXT INTO v_claim_id, v_amount_before, v_status_before;

  INSERT INTO puls_workflow.approval_requests (
    tenant_id,
    module,
    expense_claim_id,
    requester_employee_id,
    approver_employee_id,
    step_order,
    status
  )
  VALUES (
    v_tenant_id,
    'expense'::puls_workflow.approval_module,
    v_claim_id,
    v_requester_id,
    v_reviewer_id,
    1,
    'pending'::puls_workflow.approval_status
  )
  RETURNING id INTO v_approval_id;

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
    v_requester_id,
    'pr17-2g3-smoke/original.pdf',
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
    jsonb_build_object('smoke', 'pr17.2g3'),
    'review_expense_receipt_ocr_status'
  );

  SELECT *
  INTO v_claimed
  FROM puls_workflow.claim_next_expense_receipt_ocr_job(v_worker_id, 1, 300);

  IF v_claimed.job_id IS DISTINCT FROM v_job_id THEN
    RAISE EXCEPTION 'PR17_2G3_SMOKE_FAIL: OCR job was not claimed.';
  END IF;

  v_result_id := puls_workflow.complete_expense_receipt_ocr_job(
    v_job_id,
    v_worker_id,
    'completed'::puls_workflow.expense_receipt_ocr_job_status,
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    jsonb_build_object(
      'merchant_name', 'Smoke Market',
      'expense_date', CURRENT_DATE::TEXT,
      'amount', '123.45',
      'currency', 'TRY'
    ),
    jsonb_build_object('merchant_name', 0.95, 'amount', 0.99),
    0.98,
    '["human_review_required"]'::JSONB,
    'mock'::puls_workflow.expense_receipt_ocr_provider_class,
    'pr17-smoke',
    'g3',
    'mock-reference',
    jsonb_build_object('estimated_cost_minor', 0),
    NULL,
    '{}'::JSONB,
    'human_review_required',
    NULL
  );

  PERFORM set_config('request.jwt.claim.role', 'authenticated', TRUE);
  PERFORM set_config('request.jwt.claim.sub', v_unauthorized_user_id::TEXT, TRUE);

  BEGIN
    PERFORM puls_workflow.record_expense_receipt_ocr_review(
      v_result_id,
      'accepted'::puls_workflow.expense_receipt_ocr_review_status,
      NULL,
      '{}'::JSONB
    );
    RAISE EXCEPTION 'PR17_2G3_SMOKE_FAIL: unassigned reviewer should not be allowed.';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%PULS_OCR_REVIEW_FORBIDDEN%' THEN
      RAISE;
    END IF;
  END;

  PERFORM set_config('request.jwt.claim.sub', v_requester_user_id::TEXT, TRUE);

  BEGIN
    PERFORM puls_workflow.record_expense_receipt_ocr_review(
      v_result_id,
      'accepted'::puls_workflow.expense_receipt_ocr_review_status,
      NULL,
      '{}'::JSONB
    );
    RAISE EXCEPTION 'PR17_2G3_SMOKE_FAIL: requester self-review should not be allowed.';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%PULS_OCR_REVIEW_FORBIDDEN%' THEN
      RAISE;
    END IF;
  END;

  PERFORM set_config('request.jwt.claim.role', 'authenticated', TRUE);
  PERFORM set_config('request.jwt.claim.sub', v_reviewer_user_id::TEXT, TRUE);

  v_review := puls_workflow.record_expense_receipt_ocr_review(
    v_result_id,
    'corrected'::puls_workflow.expense_receipt_ocr_review_status,
    'Tutar insan incelemesiyle teyit edildi.',
    jsonb_build_object('amount', '123.45', 'currency', 'TRY')
  );

  IF v_review ->> 'review_status' <> 'corrected' THEN
    RAISE EXCEPTION 'PR17_2G3_SMOKE_FAIL: review RPC returned unexpected payload: %', v_review;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM puls_workflow.expense_receipt_ocr_results result
    WHERE result.id = v_result_id
      AND result.review_status = 'corrected'::puls_workflow.expense_receipt_ocr_review_status
      AND result.reviewed_by_employee_id = v_reviewer_id
      AND result.reviewed_at IS NOT NULL
      AND result.corrected_fields = jsonb_build_object('amount', '123.45', 'currency', 'TRY')
      AND result.review_note IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'PR17_2G3_SMOKE_FAIL: OCR review decision was not persisted.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM puls_audit.audit_logs audit
    WHERE audit.tenant_id = v_tenant_id
      AND audit.action = 'expense_receipt_ocr.review_recorded'
      AND (
        audit.metadata ? 'review_note'
        OR audit.metadata ? 'raw_ocr_text'
        OR audit.metadata ? 'provider_payload'
      )
  ) THEN
    RAISE EXCEPTION 'PR17_2G3_SMOKE_FAIL: unsafe review metadata leaked to audit.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM puls_workflow.expense_receipt_ocr_job_events event
    WHERE event.tenant_id = v_tenant_id
      AND event.job_id = v_job_id
      AND event.event_key = 'expense_receipt_ocr.review_recorded'
      AND event.safe_error_context ->> 'canonical_write' = 'false'
  ) THEN
    RAISE EXCEPTION 'PR17_2G3_SMOKE_FAIL: OCR review event was not recorded safely.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM puls_workflow.expense_claims claim
    WHERE claim.id = v_claim_id
      AND (claim.amount IS DISTINCT FROM v_amount_before OR claim.status::TEXT IS DISTINCT FROM v_status_before)
  ) THEN
    RAISE EXCEPTION 'PR17_2G3_SMOKE_FAIL: canonical expense claim changed during OCR review.';
  END IF;

  BEGIN
    PERFORM puls_workflow.record_expense_receipt_ocr_review(
      v_result_id,
      'accepted'::puls_workflow.expense_receipt_ocr_review_status,
      NULL,
      '{}'::JSONB
    );
    RAISE EXCEPTION 'PR17_2G3_SMOKE_FAIL: repeated OCR review should not be allowed.';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%PULS_OCR_REVIEW_ALREADY_RECORDED%' THEN
      RAISE;
    END IF;
  END;
END;
$$;

ROLLBACK;
