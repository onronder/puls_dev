-- PR16.10.14 workflow audit and policy hardening.
-- Adds safe row-level audit triggers for core workflow records and moves the
-- receipt-required expense guard into the SECURITY DEFINER RPC. This does not
-- change approval execution, connector runtime, source writeback, notification
-- delivery, or external provider behavior.

CREATE OR REPLACE FUNCTION puls_workflow._workflow_audit_transition_metadata(
  p_old JSONB,
  p_new JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SET search_path = pg_catalog
AS $$
DECLARE
  v_metadata JSONB := '{}'::JSONB;
  v_old_status TEXT := NULLIF(p_old ->> 'status', '');
  v_new_status TEXT := NULLIF(p_new ->> 'status', '');
  v_old_step TEXT := NULLIF(p_old ->> 'current_approval_step', '');
  v_new_step TEXT := NULLIF(p_new ->> 'current_approval_step', '');
  v_old_approval_status TEXT := NULLIF(p_old ->> 'status', '');
  v_new_approval_status TEXT := NULLIF(p_new ->> 'status', '');
BEGIN
  IF p_old ? 'status' OR p_new ? 'status' THEN
    v_metadata := v_metadata || jsonb_build_object(
      'status_before', v_old_status,
      'status_after', v_new_status
    );
  END IF;

  IF p_old ? 'current_approval_step' OR p_new ? 'current_approval_step' THEN
    v_metadata := v_metadata || jsonb_build_object(
      'current_approval_step_before', v_old_step,
      'current_approval_step_after', v_new_step
    );
  END IF;

  IF p_old ? 'approval_policy_id' OR p_new ? 'approval_policy_id' THEN
    v_metadata := v_metadata || jsonb_build_object(
      'approval_policy_id', COALESCE(NULLIF(p_new ->> 'approval_policy_id', ''), NULLIF(p_old ->> 'approval_policy_id', ''))
    );
  END IF;

  IF p_old ? 'leave_request_id' OR p_new ? 'leave_request_id' THEN
    v_metadata := v_metadata || jsonb_build_object(
      'leave_request_id', COALESCE(NULLIF(p_new ->> 'leave_request_id', ''), NULLIF(p_old ->> 'leave_request_id', ''))
    );
  END IF;

  IF p_old ? 'expense_claim_id' OR p_new ? 'expense_claim_id' THEN
    v_metadata := v_metadata || jsonb_build_object(
      'expense_claim_id', COALESCE(NULLIF(p_new ->> 'expense_claim_id', ''), NULLIF(p_old ->> 'expense_claim_id', ''))
    );
  END IF;

  IF p_old ? 'requester_employee_id' OR p_new ? 'requester_employee_id' THEN
    v_metadata := v_metadata || jsonb_build_object(
      'requester_employee_id', COALESCE(NULLIF(p_new ->> 'requester_employee_id', ''), NULLIF(p_old ->> 'requester_employee_id', ''))
    );
  END IF;

  IF p_old ? 'approver_employee_id' OR p_new ? 'approver_employee_id' THEN
    v_metadata := v_metadata || jsonb_build_object(
      'approver_employee_id', COALESCE(NULLIF(p_new ->> 'approver_employee_id', ''), NULLIF(p_old ->> 'approver_employee_id', ''))
    );
  END IF;

  IF p_old ? 'step_order' OR p_new ? 'step_order' THEN
    v_metadata := v_metadata || jsonb_build_object(
      'step_order', COALESCE(NULLIF(p_new ->> 'step_order', ''), NULLIF(p_old ->> 'step_order', ''))
    );
  END IF;

  IF v_old_approval_status IS DISTINCT FROM v_new_approval_status THEN
    v_metadata := v_metadata || jsonb_build_object('status_changed', TRUE);
  END IF;

  RETURN jsonb_strip_nulls(v_metadata);
END;
$$;

CREATE OR REPLACE FUNCTION puls_workflow.write_workflow_row_audit_log()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core, puls_audit
AS $$
DECLARE
  v_old JSONB := CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE '{}'::JSONB END;
  v_new JSONB := CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) ELSE '{}'::JSONB END;
  v_row JSONB := CASE WHEN TG_OP = 'DELETE' THEN v_old ELSE v_new END;
  v_tenant_id UUID := NULLIF(v_row ->> 'tenant_id', '')::UUID;
  v_target_id UUID := NULLIF(v_row ->> 'id', '')::UUID;
  v_actor_employee_id UUID;
  v_metadata JSONB;
BEGIN
  IF v_tenant_id IS NULL OR v_target_id IS NULL THEN
    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    END IF;
    RETURN NEW;
  END IF;

  v_actor_employee_id := puls_core.current_employee_id();
  v_metadata := puls_workflow._workflow_audit_transition_metadata(v_old, v_new)
    || jsonb_build_object(
      'operation', LOWER(TG_OP),
      'safe_row_audit', TRUE
    );

  INSERT INTO puls_audit.audit_logs (
    tenant_id,
    actor_user_id,
    actor_employee_id,
    action,
    target_schema,
    target_table,
    target_id,
    metadata,
    source
  )
  VALUES (
    v_tenant_id,
    auth.uid(),
    v_actor_employee_id,
    concat('workflow.', TG_TABLE_NAME, '.', LOWER(TG_OP)),
    TG_TABLE_SCHEMA,
    TG_TABLE_NAME,
    v_target_id,
    jsonb_strip_nulls(v_metadata),
    'trigger'
  );

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS puls_workflow_leave_requests_audit_row
  ON puls_workflow.leave_requests;
CREATE TRIGGER puls_workflow_leave_requests_audit_row
  AFTER INSERT OR UPDATE OR DELETE
  ON puls_workflow.leave_requests
  FOR EACH ROW
  EXECUTE FUNCTION puls_workflow.write_workflow_row_audit_log();

DROP TRIGGER IF EXISTS puls_workflow_expense_claims_audit_row
  ON puls_workflow.expense_claims;
CREATE TRIGGER puls_workflow_expense_claims_audit_row
  AFTER INSERT OR UPDATE OR DELETE
  ON puls_workflow.expense_claims
  FOR EACH ROW
  EXECUTE FUNCTION puls_workflow.write_workflow_row_audit_log();

DROP TRIGGER IF EXISTS puls_workflow_approval_requests_audit_row
  ON puls_workflow.approval_requests;
CREATE TRIGGER puls_workflow_approval_requests_audit_row
  AFTER INSERT OR UPDATE OR DELETE
  ON puls_workflow.approval_requests
  FOR EACH ROW
  EXECUTE FUNCTION puls_workflow.write_workflow_row_audit_log();

-- Re-declare the public expense creation RPC so receipt-required policy is
-- enforced by the server, not inferred from a browser-side constant.
CREATE OR REPLACE FUNCTION puls_workflow.create_expense_claim(
  p_category_id uuid,
  p_title text,
  p_amount numeric,
  p_currency text DEFAULT 'TRY',
  p_vat_rate numeric DEFAULT NULL,
  p_vat_included boolean DEFAULT true,
  p_expense_date date DEFAULT NULL,
  p_description text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core, puls_audit
AS $$
DECLARE
  v_tenant_id uuid;
  v_employee_id uuid;
  v_category record;
  v_approver_id uuid;
  v_claim_id uuid;
  v_approval_id uuid;
  v_title text;
  v_policy_status puls_workflow.policy_status := 'compliant'::puls_workflow.policy_status;
  v_month_start date;
  v_month_spent numeric;
  v_month_pending numeric;
  v_currency text;
  v_policy_id uuid;
  v_first_step integer;
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
    AND ec.is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_INVALID_EXPENSE_CATEGORY: Expense category not found or inactive.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_category.receipt_required_over IS NOT NULL
     AND v_category.receipt_required_over > 0
     AND p_amount > v_category.receipt_required_over THEN
    RAISE EXCEPTION 'PULS_RECEIPT_REQUIRED: This expense category requires a receipt for the requested amount.'
      USING ERRCODE = 'P0001';
  END IF;

  v_title := NULLIF(BTRIM(p_title), '');
  IF v_title IS NULL THEN
    v_title := v_category.name || ' — ' || to_char(p_expense_date, 'YYYY-MM-DD');
  END IF;

  v_month_start := date_trunc('month', p_expense_date)::date;

  IF v_category.monthly_limit IS NOT NULL THEN
    SELECT COALESCE(SUM(ec.amount), 0)
    INTO v_month_spent
    FROM puls_workflow.expense_claims ec
    WHERE ec.tenant_id = v_tenant_id
      AND ec.employee_id = v_employee_id
      AND ec.category_id = p_category_id
      AND ec.status = 'approved'::puls_workflow.expense_claim_status
      AND ec.expense_date >= v_month_start
      AND ec.expense_date < (v_month_start + INTERVAL '1 month')::date;

    SELECT COALESCE(SUM(ec.amount), 0)
    INTO v_month_pending
    FROM puls_workflow.expense_claims ec
    WHERE ec.tenant_id = v_tenant_id
      AND ec.employee_id = v_employee_id
      AND ec.category_id = p_category_id
      AND ec.status = 'pending'::puls_workflow.expense_claim_status
      AND ec.expense_date >= v_month_start
      AND ec.expense_date < (v_month_start + INTERVAL '1 month')::date;

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
    COALESCE(p_vat_included, true),
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
      'approver_employee_id', v_approver_id
    )
  );

  RETURN jsonb_build_object(
    'expense_claim_id', v_claim_id,
    'approval_request_id', v_approval_id,
    'status', 'pending',
    'policy_status', v_policy_status,
    'approver_employee_id', v_approver_id,
    'title', v_title
  );
END;
$$;

REVOKE ALL ON FUNCTION puls_workflow._workflow_audit_transition_metadata(JSONB, JSONB) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_workflow.write_workflow_row_audit_log() FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_workflow._workflow_audit_transition_metadata(JSONB, JSONB) TO service_role;
GRANT EXECUTE ON FUNCTION puls_workflow.write_workflow_row_audit_log() TO service_role;

REVOKE ALL ON FUNCTION puls_workflow.create_expense_claim(uuid, text, numeric, text, numeric, boolean, date, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION puls_workflow.create_expense_claim(uuid, text, numeric, text, numeric, boolean, date, text) FROM anon;
GRANT EXECUTE ON FUNCTION puls_workflow.create_expense_claim(uuid, text, numeric, text, numeric, boolean, date, text) TO authenticated;

COMMENT ON FUNCTION puls_workflow.write_workflow_row_audit_log()
  IS 'PR16.10.14 safe workflow row audit trigger: tenant-bound and metadata-only, with no description, receipt, payload, or free-text readback.';

COMMENT ON FUNCTION puls_workflow.create_expense_claim(uuid, text, numeric, text, numeric, boolean, date, text)
  IS 'Creates expense claims through the server approval contract and blocks receipt-required categories until receipt upload support is available.';
