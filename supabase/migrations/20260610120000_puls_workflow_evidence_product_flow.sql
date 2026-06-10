-- PR17.2F2: workflow evidence product flow.
-- Adds submit-with-evidence RPCs for leave and expense while preserving the
-- existing no-evidence RPC contracts used by PR17.2E smoke tests.

CREATE OR REPLACE FUNCTION puls_workflow._attach_leave_document_evidence(
  p_evidence_upload_id UUID,
  p_leave_request_id UUID,
  p_tenant_id UUID,
  p_employee_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core, puls_audit
AS $$
DECLARE
  v_upload puls_workflow.evidence_uploads%ROWTYPE;
  v_document_id UUID;
BEGIN
  SELECT *
  INTO v_upload
  FROM puls_workflow.evidence_uploads
  WHERE id = p_evidence_upload_id
    AND tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_EVIDENCE_UPLOAD_NOT_FOUND: Evidence upload was not found.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_upload.domain <> 'leave'::puls_workflow.evidence_upload_domain THEN
    RAISE EXCEPTION 'PULS_EVIDENCE_DOMAIN_INVALID: Evidence upload domain is invalid for leave.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_upload.owner_employee_id <> p_employee_id THEN
    RAISE EXCEPTION 'PULS_EVIDENCE_UPLOAD_FORBIDDEN: Evidence upload does not belong to this employee.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_upload.status <> 'uploaded'::puls_workflow.evidence_upload_status THEN
    RAISE EXCEPTION 'PULS_EVIDENCE_UPLOAD_STATUS_INVALID: Evidence upload must be finalized before submit.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_upload.expires_at <= NOW() THEN
    UPDATE puls_workflow.evidence_uploads
    SET status = 'expired'::puls_workflow.evidence_upload_status
    WHERE id = v_upload.id;

    RAISE EXCEPTION 'PULS_EVIDENCE_UPLOAD_EXPIRED: Evidence upload intent has expired.'
      USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO puls_workflow.leave_documents (
    tenant_id,
    leave_request_id,
    uploaded_by_employee_id,
    file_ref,
    file_name,
    mime_type,
    file_size_bytes,
    status
  )
  VALUES (
    p_tenant_id,
    p_leave_request_id,
    p_employee_id,
    v_upload.storage_path,
    v_upload.original_file_name,
    v_upload.mime_type,
    v_upload.file_size_bytes,
    'pending'::puls_workflow.document_status
  )
  RETURNING id INTO v_document_id;

  UPDATE puls_workflow.evidence_uploads
  SET
    status = 'attached'::puls_workflow.evidence_upload_status,
    subject_table = 'puls_workflow.leave_requests',
    subject_id = p_leave_request_id,
    attached_table = 'puls_workflow.leave_documents',
    attached_id = v_document_id,
    attached_at = NOW()
  WHERE id = v_upload.id;

  PERFORM puls_workflow.write_audit_log(
    p_tenant_id,
    p_employee_id,
    'workflow_evidence.leave_document_attached',
    'leave_documents',
    v_document_id,
    jsonb_build_object(
      'evidence_upload_id', v_upload.id,
      'leave_request_id', p_leave_request_id,
      'mime_type', v_upload.mime_type,
      'file_extension', v_upload.file_extension,
      'file_size_bytes', v_upload.file_size_bytes,
      'sha256_client_present', v_upload.sha256_client IS NOT NULL,
      'scan_status', v_upload.scan_status::TEXT
    )
  );

  RETURN v_document_id;
END;
$$;

CREATE OR REPLACE FUNCTION puls_workflow._attach_expense_receipt_evidence(
  p_evidence_upload_id UUID,
  p_expense_claim_id UUID,
  p_tenant_id UUID,
  p_employee_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core, puls_audit
AS $$
DECLARE
  v_upload puls_workflow.evidence_uploads%ROWTYPE;
  v_receipt_id UUID;
BEGIN
  SELECT *
  INTO v_upload
  FROM puls_workflow.evidence_uploads
  WHERE id = p_evidence_upload_id
    AND tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_EVIDENCE_UPLOAD_NOT_FOUND: Evidence upload was not found.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_upload.domain <> 'expense'::puls_workflow.evidence_upload_domain THEN
    RAISE EXCEPTION 'PULS_EVIDENCE_DOMAIN_INVALID: Evidence upload domain is invalid for expense.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_upload.owner_employee_id <> p_employee_id THEN
    RAISE EXCEPTION 'PULS_EVIDENCE_UPLOAD_FORBIDDEN: Evidence upload does not belong to this employee.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_upload.status <> 'uploaded'::puls_workflow.evidence_upload_status THEN
    RAISE EXCEPTION 'PULS_EVIDENCE_UPLOAD_STATUS_INVALID: Evidence upload must be finalized before submit.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_upload.expires_at <= NOW() THEN
    UPDATE puls_workflow.evidence_uploads
    SET status = 'expired'::puls_workflow.evidence_upload_status
    WHERE id = v_upload.id;

    RAISE EXCEPTION 'PULS_EVIDENCE_UPLOAD_EXPIRED: Evidence upload intent has expired.'
      USING ERRCODE = 'P0001';
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
    p_tenant_id,
    p_expense_claim_id,
    p_employee_id,
    v_upload.storage_path,
    v_upload.original_file_name,
    v_upload.mime_type,
    v_upload.file_size_bytes,
    'not_requested',
    'pending'::puls_workflow.document_status
  )
  RETURNING id INTO v_receipt_id;

  UPDATE puls_workflow.evidence_uploads
  SET
    status = 'attached'::puls_workflow.evidence_upload_status,
    subject_table = 'puls_workflow.expense_claims',
    subject_id = p_expense_claim_id,
    attached_table = 'puls_workflow.expense_receipts',
    attached_id = v_receipt_id,
    attached_at = NOW()
  WHERE id = v_upload.id;

  PERFORM puls_workflow.write_audit_log(
    p_tenant_id,
    p_employee_id,
    'workflow_evidence.expense_receipt_attached',
    'expense_receipts',
    v_receipt_id,
    jsonb_build_object(
      'evidence_upload_id', v_upload.id,
      'expense_claim_id', p_expense_claim_id,
      'mime_type', v_upload.mime_type,
      'file_extension', v_upload.file_extension,
      'file_size_bytes', v_upload.file_size_bytes,
      'sha256_client_present', v_upload.sha256_client IS NOT NULL,
      'scan_status', v_upload.scan_status::TEXT,
      'ocr_status', 'not_requested'
    )
  );

  RETURN v_receipt_id;
END;
$$;

CREATE OR REPLACE FUNCTION puls_workflow.create_leave_request_with_evidence(
  p_leave_type_id UUID,
  p_start_date DATE,
  p_end_date DATE,
  p_half_day BOOLEAN DEFAULT FALSE,
  p_delegate_employee_id UUID DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_evidence_upload_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core, puls_audit
AS $$
DECLARE
  v_tenant_id UUID;
  v_employee_id UUID;
  v_leave_type RECORD;
  v_business_days NUMERIC;
  v_approver_id UUID;
  v_approver_name TEXT;
  v_request_id UUID;
  v_approval_id UUID;
  v_balance_id UUID;
  v_balance_checked BOOLEAN := FALSE;
  v_period_year INTEGER;
  v_policy_id UUID;
  v_first_step INTEGER;
  v_document_id UUID := NULL;
BEGIN
  v_tenant_id := puls_core.current_tenant_id();
  v_employee_id := puls_core.current_employee_id();
  v_period_year := EXTRACT(YEAR FROM p_start_date)::INTEGER;

  IF auth.uid() IS NULL OR v_tenant_id IS NULL OR v_employee_id IS NULL THEN
    RAISE EXCEPTION 'PULS_AUTH_REQUIRED: Authentication required.'
      USING ERRCODE = 'P0001';
  END IF;

  IF p_start_date IS NULL OR p_end_date IS NULL THEN
    RAISE EXCEPTION 'PULS_INVALID_DATES: Start and end dates are required.'
      USING ERRCODE = 'P0001';
  END IF;

  IF p_end_date < p_start_date THEN
    RAISE EXCEPTION 'PULS_INVALID_DATES: End date must be on or after start date.'
      USING ERRCODE = 'P0001';
  END IF;

  IF EXTRACT(YEAR FROM p_start_date) <> EXTRACT(YEAR FROM p_end_date) THEN
    RAISE EXCEPTION 'PULS_CROSS_YEAR_LEAVE: Leave request must fall within a single calendar year.'
      USING ERRCODE = 'P0001';
  END IF;

  IF p_half_day AND p_start_date <> p_end_date THEN
    RAISE EXCEPTION 'PULS_HALF_DAY_INVALID: Half-day leave requires the same start and end date.'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT lt.id, lt.requires_document, lt.is_active, lt.tenant_id, lt.approval_policy_id
  INTO v_leave_type
  FROM puls_workflow.leave_types lt
  WHERE lt.id = p_leave_type_id
    AND lt.tenant_id = v_tenant_id
    AND lt.is_active = TRUE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_INVALID_LEAVE_TYPE: Leave type not found or inactive.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_leave_type.requires_document AND p_evidence_upload_id IS NULL THEN
    RAISE EXCEPTION 'PULS_DOCUMENT_REQUIRED: This leave type requires a document upload.'
      USING ERRCODE = 'P0001';
  END IF;

  IF p_delegate_employee_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM puls_core.employees d
      WHERE d.id = p_delegate_employee_id
        AND d.tenant_id = v_tenant_id
        AND d.employment_status = 'active'
    ) THEN
      RAISE EXCEPTION 'PULS_INVALID_DELEGATE: Delegate employee not found.'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  IF p_half_day THEN
    v_business_days := 0.5;
  ELSE
    v_business_days := puls_workflow.count_business_days(p_start_date, p_end_date);
  END IF;

  IF v_business_days <= 0 THEN
    RAISE EXCEPTION 'PULS_INVALID_DATES: Selected range has no business days.'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT lb.id
  INTO v_balance_id
  FROM puls_workflow.leave_balances lb
  WHERE lb.tenant_id = v_tenant_id
    AND lb.employee_id = v_employee_id
    AND lb.leave_type_id = p_leave_type_id
    AND lb.period_year = v_period_year
  FOR UPDATE;

  IF v_balance_id IS NOT NULL THEN
    v_balance_checked := TRUE;

    IF (
      SELECT lb.remaining_days
      FROM puls_workflow.leave_balances lb
      WHERE lb.id = v_balance_id
    ) < v_business_days THEN
      RAISE EXCEPTION 'PULS_INSUFFICIENT_BALANCE: Insufficient leave balance.'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  v_policy_id := v_leave_type.approval_policy_id;

  IF v_policy_id IS NOT NULL THEN
    v_first_step := puls_workflow.find_first_required_policy_step(v_tenant_id, v_policy_id, 'leave');
    v_approver_id := puls_workflow.resolve_policy_step_approver(
      v_tenant_id,
      v_employee_id,
      'leave',
      v_policy_id,
      v_first_step
    );

    IF v_approver_id IS NULL THEN
      RAISE EXCEPTION 'PULS_POLICY_STEP_UNRESOLVED: No approver could be resolved for policy step.'
        USING ERRCODE = 'P0001';
    END IF;
  ELSE
    v_first_step := 1;
    v_approver_id := puls_workflow.resolve_approver(v_tenant_id, v_employee_id, 'leave', NULL);

    IF v_approver_id IS NULL THEN
      RAISE EXCEPTION 'PULS_NO_APPROVER: No approver could be resolved for this request.'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  SELECT e.full_name
  INTO v_approver_name
  FROM puls_core.employees e
  WHERE e.id = v_approver_id;

  INSERT INTO puls_workflow.leave_requests (
    tenant_id,
    employee_id,
    leave_type_id,
    start_date,
    end_date,
    business_days,
    half_day,
    delegate_employee_id,
    description,
    status,
    submitted_at,
    current_approval_step,
    approval_policy_id
  )
  VALUES (
    v_tenant_id,
    v_employee_id,
    p_leave_type_id,
    p_start_date,
    p_end_date,
    v_business_days,
    COALESCE(p_half_day, FALSE),
    p_delegate_employee_id,
    NULLIF(BTRIM(p_description), ''),
    'pending'::puls_workflow.leave_request_status,
    NOW(),
    v_first_step,
    v_policy_id
  )
  RETURNING id INTO v_request_id;

  IF p_evidence_upload_id IS NOT NULL THEN
    v_document_id := puls_workflow._attach_leave_document_evidence(
      p_evidence_upload_id,
      v_request_id,
      v_tenant_id,
      v_employee_id
    );
  END IF;

  INSERT INTO puls_workflow.approval_requests (
    tenant_id,
    module,
    leave_request_id,
    requester_employee_id,
    approver_employee_id,
    step_order,
    status,
    approval_policy_id
  )
  VALUES (
    v_tenant_id,
    'leave'::puls_workflow.approval_module,
    v_request_id,
    v_employee_id,
    v_approver_id,
    v_first_step,
    'pending'::puls_workflow.approval_status,
    v_policy_id
  )
  RETURNING id INTO v_approval_id;

  IF v_balance_id IS NOT NULL THEN
    UPDATE puls_workflow.leave_balances lb
    SET pending_days = lb.pending_days + v_business_days,
        updated_at = NOW()
    WHERE lb.id = v_balance_id;
  END IF;

  PERFORM puls_workflow.write_audit_log(
    v_tenant_id,
    v_employee_id,
    'leave_request.created',
    'leave_requests',
    v_request_id,
    jsonb_build_object(
      'business_days', v_business_days,
      'balance_checked', v_balance_checked,
      'approval_request_id', v_approval_id,
      'approval_policy_id', v_policy_id,
      'current_step_order', v_first_step,
      'approver_employee_id', v_approver_id,
      'evidence_attached', v_document_id IS NOT NULL,
      'leave_document_id', v_document_id
    )
  );

  RETURN jsonb_build_object(
    'leave_request_id', v_request_id,
    'approval_request_id', v_approval_id,
    'business_days', v_business_days,
    'status', 'pending',
    'approver_employee_id', v_approver_id,
    'approver_name', v_approver_name,
    'evidence_attached', v_document_id IS NOT NULL,
    'leave_document_id', v_document_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION puls_workflow.create_expense_claim_with_evidence(
  p_category_id UUID,
  p_title TEXT,
  p_amount NUMERIC,
  p_currency TEXT DEFAULT 'TRY',
  p_vat_rate NUMERIC DEFAULT NULL,
  p_vat_included BOOLEAN DEFAULT TRUE,
  p_expense_date DATE DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_evidence_upload_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core, puls_audit
AS $$
DECLARE
  v_tenant_id UUID;
  v_employee_id UUID;
  v_category RECORD;
  v_approver_id UUID;
  v_claim_id UUID;
  v_approval_id UUID;
  v_title TEXT;
  v_policy_status puls_workflow.policy_status := 'compliant'::puls_workflow.policy_status;
  v_month_start DATE;
  v_month_spent NUMERIC;
  v_month_pending NUMERIC;
  v_currency TEXT;
  v_policy_id UUID;
  v_first_step INTEGER;
  v_receipt_id UUID := NULL;
BEGIN
  v_tenant_id := puls_core.current_tenant_id();
  v_employee_id := puls_core.current_employee_id();
  v_currency := UPPER(COALESCE(NULLIF(BTRIM(p_currency), ''), 'TRY'));

  IF auth.uid() IS NULL OR v_tenant_id IS NULL OR v_employee_id IS NULL THEN
    RAISE EXCEPTION 'PULS_AUTH_REQUIRED: Authentication required.'
      USING ERRCODE = 'P0001';
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'PULS_INVALID_AMOUNT: Amount must be greater than zero.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_currency NOT IN ('TRY', 'USD', 'EUR') THEN
    RAISE EXCEPTION 'PULS_INVALID_CURRENCY: Currency must be TRY, USD, or EUR.'
      USING ERRCODE = 'P0001';
  END IF;

  IF p_expense_date IS NULL THEN
    RAISE EXCEPTION 'PULS_FUTURE_EXPENSE_DATE: Expense date is required.'
      USING ERRCODE = 'P0001';
  END IF;

  IF p_expense_date > CURRENT_DATE THEN
    RAISE EXCEPTION 'PULS_FUTURE_EXPENSE_DATE: Expense date cannot be in the future.'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT ec.id, ec.name, ec.monthly_limit, ec.receipt_required_over, ec.is_active, ec.tenant_id, ec.approval_policy_id
  INTO v_category
  FROM puls_workflow.expense_categories ec
  WHERE ec.id = p_category_id
    AND ec.tenant_id = v_tenant_id
    AND ec.is_active = TRUE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_INVALID_EXPENSE_CATEGORY: Expense category not found or inactive.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_category.receipt_required_over IS NOT NULL
     AND v_category.receipt_required_over > 0
     AND p_amount > v_category.receipt_required_over
     AND p_evidence_upload_id IS NULL THEN
    RAISE EXCEPTION 'PULS_RECEIPT_REQUIRED: This expense category requires a receipt for the requested amount.'
      USING ERRCODE = 'P0001';
  END IF;

  v_title := NULLIF(BTRIM(p_title), '');
  IF v_title IS NULL THEN
    v_title := v_category.name || ' — ' || to_char(p_expense_date, 'YYYY-MM-DD');
  END IF;

  v_month_start := date_trunc('month', p_expense_date)::DATE;

  IF v_category.monthly_limit IS NOT NULL THEN
    SELECT COALESCE(SUM(ec.amount), 0)
    INTO v_month_spent
    FROM puls_workflow.expense_claims ec
    WHERE ec.tenant_id = v_tenant_id
      AND ec.employee_id = v_employee_id
      AND ec.category_id = p_category_id
      AND ec.status = 'approved'::puls_workflow.expense_claim_status
      AND ec.expense_date >= v_month_start
      AND ec.expense_date < (v_month_start + INTERVAL '1 month')::DATE;

    SELECT COALESCE(SUM(ec.amount), 0)
    INTO v_month_pending
    FROM puls_workflow.expense_claims ec
    WHERE ec.tenant_id = v_tenant_id
      AND ec.employee_id = v_employee_id
      AND ec.category_id = p_category_id
      AND ec.status = 'pending'::puls_workflow.expense_claim_status
      AND ec.expense_date >= v_month_start
      AND ec.expense_date < (v_month_start + INTERVAL '1 month')::DATE;

    IF (v_month_spent + v_month_pending + p_amount) > v_category.monthly_limit THEN
      v_policy_status := 'warning'::puls_workflow.policy_status;
    END IF;
  END IF;

  v_policy_id := v_category.approval_policy_id;

  IF v_policy_id IS NOT NULL THEN
    v_first_step := puls_workflow.find_first_required_policy_step(v_tenant_id, v_policy_id, 'expense');
    v_approver_id := puls_workflow.resolve_policy_step_approver(
      v_tenant_id,
      v_employee_id,
      'expense',
      v_policy_id,
      v_first_step
    );

    IF v_approver_id IS NULL THEN
      RAISE EXCEPTION 'PULS_POLICY_STEP_UNRESOLVED: No approver could be resolved for policy step.'
        USING ERRCODE = 'P0001';
    END IF;
  ELSE
    v_first_step := 1;
    v_approver_id := puls_workflow.resolve_approver(v_tenant_id, v_employee_id, 'expense', NULL);

    IF v_approver_id IS NULL THEN
      RAISE EXCEPTION 'PULS_NO_APPROVER: No approver could be resolved for this claim.'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

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
    policy_status,
    status,
    submitted_at,
    current_approval_step,
    approval_policy_id
  )
  VALUES (
    v_tenant_id,
    v_employee_id,
    p_category_id,
    p_amount,
    v_currency,
    p_vat_rate,
    COALESCE(p_vat_included, TRUE),
    p_expense_date,
    v_title,
    NULLIF(BTRIM(p_description), ''),
    v_policy_status,
    'pending'::puls_workflow.expense_claim_status,
    NOW(),
    v_first_step,
    v_policy_id
  )
  RETURNING id INTO v_claim_id;

  IF p_evidence_upload_id IS NOT NULL THEN
    v_receipt_id := puls_workflow._attach_expense_receipt_evidence(
      p_evidence_upload_id,
      v_claim_id,
      v_tenant_id,
      v_employee_id
    );
  END IF;

  INSERT INTO puls_workflow.approval_requests (
    tenant_id,
    module,
    expense_claim_id,
    requester_employee_id,
    approver_employee_id,
    step_order,
    status,
    approval_policy_id
  )
  VALUES (
    v_tenant_id,
    'expense'::puls_workflow.approval_module,
    v_claim_id,
    v_employee_id,
    v_approver_id,
    v_first_step,
    'pending'::puls_workflow.approval_status,
    v_policy_id
  )
  RETURNING id INTO v_approval_id;

  PERFORM puls_workflow.write_audit_log(
    v_tenant_id,
    v_employee_id,
    'expense_claim.created',
    'expense_claims',
    v_claim_id,
    jsonb_build_object(
      'amount', p_amount,
      'currency', v_currency,
      'policy_status', v_policy_status,
      'approval_request_id', v_approval_id,
      'approval_policy_id', v_policy_id,
      'current_step_order', v_first_step,
      'approver_employee_id', v_approver_id,
      'evidence_attached', v_receipt_id IS NOT NULL,
      'expense_receipt_id', v_receipt_id
    )
  );

  RETURN jsonb_build_object(
    'expense_claim_id', v_claim_id,
    'approval_request_id', v_approval_id,
    'status', 'pending',
    'policy_status', v_policy_status,
    'approver_employee_id', v_approver_id,
    'title', v_title,
    'evidence_attached', v_receipt_id IS NOT NULL,
    'expense_receipt_id', v_receipt_id
  );
END;
$$;

REVOKE ALL ON FUNCTION puls_workflow._attach_leave_document_evidence(UUID, UUID, UUID, UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION puls_workflow._attach_expense_receipt_evidence(UUID, UUID, UUID, UUID) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION puls_workflow.create_leave_request_with_evidence(UUID, DATE, DATE, BOOLEAN, UUID, TEXT, UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION puls_workflow.create_expense_claim_with_evidence(UUID, TEXT, NUMERIC, TEXT, NUMERIC, BOOLEAN, DATE, TEXT, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION puls_workflow.create_leave_request_with_evidence(UUID, DATE, DATE, BOOLEAN, UUID, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION puls_workflow.create_expense_claim_with_evidence(UUID, TEXT, NUMERIC, TEXT, NUMERIC, BOOLEAN, DATE, TEXT, UUID) TO authenticated;
