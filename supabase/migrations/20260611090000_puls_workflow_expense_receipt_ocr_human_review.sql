-- PR17.2G3: expense receipt OCR human review boundary.
--
-- This slice lets an authorized human reviewer record a decision for an
-- existing OCR/extraction result. It does not mutate canonical expense claims,
-- does not enqueue OCR work, and does not call any provider.

ALTER TABLE puls_workflow.expense_receipt_ocr_results
  ADD COLUMN IF NOT EXISTS reviewed_by_employee_id UUID NULL REFERENCES puls_core.employees(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS review_note TEXT NULL,
  ADD COLUMN IF NOT EXISTS corrected_fields JSONB NOT NULL DEFAULT '{}'::JSONB;

CREATE INDEX IF NOT EXISTS expense_receipt_ocr_results_review_idx
  ON puls_workflow.expense_receipt_ocr_results (tenant_id, review_status, created_at DESC);

CREATE INDEX IF NOT EXISTS expense_receipt_ocr_results_reviewer_idx
  ON puls_workflow.expense_receipt_ocr_results (tenant_id, reviewed_by_employee_id, reviewed_at DESC)
  WHERE reviewed_by_employee_id IS NOT NULL;

CREATE OR REPLACE FUNCTION puls_workflow.expense_receipt_ocr_review_fields_are_allowed(
  p_fields JSONB
)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
SET search_path = pg_catalog
AS $$
DECLARE
  v_key TEXT;
BEGIN
  IF p_fields IS NULL THEN
    RETURN TRUE;
  END IF;

  IF jsonb_typeof(p_fields) <> 'object' THEN
    RETURN FALSE;
  END IF;

  FOR v_key IN
    SELECT key
    FROM jsonb_object_keys(p_fields) AS keys(key)
  LOOP
    IF v_key NOT IN (
      'amount',
      'currency',
      'expense_date',
      'category_label',
      'merchant_name',
      'vat_included'
    ) THEN
      RETURN FALSE;
    END IF;
  END LOOP;

  RETURN TRUE;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'expense_receipt_ocr_results_corrected_fields_safe'
      AND conrelid = 'puls_workflow.expense_receipt_ocr_results'::regclass
  ) THEN
    ALTER TABLE puls_workflow.expense_receipt_ocr_results
      ADD CONSTRAINT expense_receipt_ocr_results_corrected_fields_safe
      CHECK (
        corrected_fields IS NOT NULL
        AND jsonb_typeof(corrected_fields) = 'object'
        AND puls_workflow.expense_receipt_ocr_review_fields_are_allowed(corrected_fields)
        AND NOT puls_workflow.expense_receipt_ocr_safe_context_has_blocked_key(corrected_fields)
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'expense_receipt_ocr_results_review_note_length'
      AND conrelid = 'puls_workflow.expense_receipt_ocr_results'::regclass
  ) THEN
    ALTER TABLE puls_workflow.expense_receipt_ocr_results
      ADD CONSTRAINT expense_receipt_ocr_results_review_note_length
      CHECK (review_note IS NULL OR char_length(review_note) <= 1000);
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION puls_workflow.can_review_expense_receipt_ocr(
  p_result_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM puls_workflow.expense_receipt_ocr_results result
    WHERE result.id = p_result_id
      AND result.tenant_id = puls_core.current_tenant_id()
      AND (
        puls_core.is_admin()
        OR puls_workflow._workflow_evidence_is_assigned_approver(
          'expense'::puls_workflow.evidence_upload_domain,
          result.expense_claim_id,
          puls_core.current_employee_id()
        )
      )
  );
$$;

CREATE OR REPLACE FUNCTION puls_workflow.record_expense_receipt_ocr_review(
  p_result_id UUID,
  p_review_status puls_workflow.expense_receipt_ocr_review_status,
  p_review_note TEXT DEFAULT NULL,
  p_corrected_fields JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core
AS $$
DECLARE
  v_tenant_id UUID := puls_core.current_tenant_id();
  v_employee_id UUID := puls_core.current_employee_id();
  v_result puls_workflow.expense_receipt_ocr_results%ROWTYPE;
  v_updated puls_workflow.expense_receipt_ocr_results%ROWTYPE;
  v_job puls_workflow.expense_receipt_ocr_jobs%ROWTYPE;
  v_note TEXT := NULLIF(BTRIM(COALESCE(p_review_note, '')), '');
  v_corrected_fields JSONB := COALESCE(p_corrected_fields, '{}'::JSONB);
  v_corrected_field_count INTEGER := 0;
BEGIN
  IF v_tenant_id IS NULL OR v_employee_id IS NULL THEN
    RAISE EXCEPTION 'PULS_AUTH_REQUIRED: Employee context is required to review OCR results.'
      USING ERRCODE = 'P0001';
  END IF;

  IF p_result_id IS NULL THEN
    RAISE EXCEPTION 'PULS_OCR_REVIEW_RESULT_REQUIRED: OCR result id is required.'
      USING ERRCODE = 'P0001';
  END IF;

  IF p_review_status NOT IN (
    'accepted'::puls_workflow.expense_receipt_ocr_review_status,
    'corrected'::puls_workflow.expense_receipt_ocr_review_status,
    'rejected'::puls_workflow.expense_receipt_ocr_review_status,
    'needs_new_document'::puls_workflow.expense_receipt_ocr_review_status
  ) THEN
    RAISE EXCEPTION 'PULS_OCR_REVIEW_STATUS_INVALID: OCR review status is invalid.'
      USING ERRCODE = 'P0001';
  END IF;

  IF jsonb_typeof(v_corrected_fields) <> 'object'
     OR NOT puls_workflow.expense_receipt_ocr_review_fields_are_allowed(v_corrected_fields)
     OR puls_workflow.expense_receipt_ocr_safe_context_has_blocked_key(v_corrected_fields) THEN
    RAISE EXCEPTION 'PULS_OCR_REVIEW_FIELDS_INVALID: Corrected fields are not allowed.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_note IS NOT NULL AND char_length(v_note) > 1000 THEN
    RAISE EXCEPTION 'PULS_OCR_REVIEW_NOTE_TOO_LONG: OCR review note is too long.'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT COUNT(*)
  INTO v_corrected_field_count
  FROM jsonb_object_keys(v_corrected_fields);

  IF p_review_status = 'accepted'::puls_workflow.expense_receipt_ocr_review_status
     AND v_corrected_field_count > 0 THEN
    RAISE EXCEPTION 'PULS_OCR_REVIEW_FIELDS_NOT_ALLOWED: Accepted OCR results cannot include corrected fields.'
      USING ERRCODE = 'P0001';
  END IF;

  IF p_review_status = 'corrected'::puls_workflow.expense_receipt_ocr_review_status
     AND v_corrected_field_count = 0
     AND v_note IS NULL THEN
    RAISE EXCEPTION 'PULS_OCR_REVIEW_CORRECTION_REQUIRED: Corrected OCR reviews require a note or corrected fields.'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT *
  INTO v_result
  FROM puls_workflow.expense_receipt_ocr_results
  WHERE id = p_result_id
    AND tenant_id = v_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_OCR_REVIEW_RESULT_NOT_FOUND: OCR result was not found.'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT puls_workflow.can_review_expense_receipt_ocr(v_result.id) THEN
    RAISE EXCEPTION 'PULS_OCR_REVIEW_FORBIDDEN: You cannot review this OCR result.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_result.review_status <> 'pending_review'::puls_workflow.expense_receipt_ocr_review_status THEN
    RAISE EXCEPTION 'PULS_OCR_REVIEW_ALREADY_RECORDED: OCR result review was already recorded.'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT *
  INTO v_job
  FROM puls_workflow.expense_receipt_ocr_jobs
  WHERE id = v_result.job_id
    AND tenant_id = v_result.tenant_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_OCR_JOB_NOT_FOUND: OCR job was not found for review.'
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE puls_workflow.expense_receipt_ocr_results result
  SET
    review_status = p_review_status,
    reviewed_by_employee_id = v_employee_id,
    reviewed_at = NOW(),
    review_note = v_note,
    corrected_fields = CASE
      WHEN p_review_status = 'accepted'::puls_workflow.expense_receipt_ocr_review_status
      THEN '{}'::JSONB
      ELSE v_corrected_fields
    END
  WHERE result.id = v_result.id
  RETURNING * INTO v_updated;

  PERFORM puls_workflow._record_expense_receipt_ocr_job_event(
    v_job,
    'expense_receipt_ocr.review_recorded',
    NULL,
    NULL,
    jsonb_build_object(
      'review_status', p_review_status::TEXT,
      'reviewed_by_employee_id', v_employee_id,
      'corrected_field_count', v_corrected_field_count,
      'review_note_present', v_note IS NOT NULL,
      'canonical_write', FALSE
    ),
    NULL,
    FALSE
  );

  PERFORM puls_workflow.write_audit_log(
    v_updated.tenant_id,
    v_employee_id,
    'expense_receipt_ocr.review_recorded',
    'expense_receipt_ocr_results',
    v_updated.id,
    jsonb_build_object(
      'expense_receipt_id', v_updated.expense_receipt_id,
      'expense_claim_id', v_updated.expense_claim_id,
      'job_id', v_updated.job_id,
      'review_status', v_updated.review_status::TEXT,
      'corrected_field_count', v_corrected_field_count,
      'review_note_present', v_note IS NOT NULL,
      'canonical_write', FALSE
    )
  );

  RETURN jsonb_build_object(
    'ocr_result_id', v_updated.id,
    'expense_receipt_id', v_updated.expense_receipt_id,
    'expense_claim_id', v_updated.expense_claim_id,
    'review_status', v_updated.review_status::TEXT,
    'reviewed_at', v_updated.reviewed_at
  );
END;
$$;

COMMENT ON FUNCTION puls_workflow.record_expense_receipt_ocr_review(
  UUID,
  puls_workflow.expense_receipt_ocr_review_status,
  TEXT,
  JSONB
) IS 'Records a human review decision for an expense receipt OCR result. Does not write canonical expense claim fields.';

REVOKE ALL ON FUNCTION puls_workflow.expense_receipt_ocr_review_fields_are_allowed(JSONB) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION puls_workflow.can_review_expense_receipt_ocr(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION puls_workflow.record_expense_receipt_ocr_review(UUID, puls_workflow.expense_receipt_ocr_review_status, TEXT, JSONB) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION puls_workflow.can_review_expense_receipt_ocr(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION puls_workflow.record_expense_receipt_ocr_review(UUID, puls_workflow.expense_receipt_ocr_review_status, TEXT, JSONB) TO authenticated;
