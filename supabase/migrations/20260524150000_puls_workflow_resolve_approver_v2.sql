-- 07 PR3 — resolve_approver V2 (policy-first) + RPC wiring

CREATE OR REPLACE FUNCTION puls_workflow.resolve_org_primary_manager(
  p_tenant_id UUID,
  p_requester_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core
AS $$
DECLARE
  v_manager_id UUID;
BEGIN
  SELECT rl.manager_employee_id
  INTO v_manager_id
  FROM puls_core.employee_reporting_lines rl
  WHERE rl.tenant_id = p_tenant_id
    AND rl.employee_id = p_requester_id
    AND rl.is_active = TRUE
    AND rl.relationship_type = 'primary_manager'::puls_core.reporting_relationship_type
  ORDER BY rl.starts_on DESC, rl.created_at DESC
  LIMIT 1;

  IF v_manager_id IS NULL THEN
    SELECT e.manager_employee_id
    INTO v_manager_id
    FROM puls_core.employees e
    WHERE e.id = p_requester_id
      AND e.tenant_id = p_tenant_id;
  END IF;

  IF v_manager_id IS NOT NULL
     AND v_manager_id <> p_requester_id
     AND EXISTS (
       SELECT 1
       FROM puls_core.employees m
       WHERE m.id = v_manager_id
         AND m.tenant_id = p_tenant_id
         AND m.employment_status = 'active'::puls_core.employment_status
     ) THEN
    RETURN v_manager_id;
  END IF;

  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION puls_workflow.resolve_dept_manager(
  p_tenant_id UUID,
  p_requester_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core
AS $$
DECLARE
  v_manager_id UUID;
BEGIN
  SELECT d.manager_employee_id
  INTO v_manager_id
  FROM puls_core.employees e
  JOIN puls_core.departments d ON d.id = e.department_id
  WHERE e.id = p_requester_id
    AND e.tenant_id = p_tenant_id
    AND d.tenant_id = p_tenant_id;

  IF v_manager_id IS NOT NULL
     AND v_manager_id <> p_requester_id
     AND EXISTS (
       SELECT 1
       FROM puls_core.employees m
       WHERE m.id = v_manager_id
         AND m.tenant_id = p_tenant_id
         AND m.employment_status = 'active'::puls_core.employment_status
     ) THEN
    RETURN v_manager_id;
  END IF;

  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION puls_workflow.resolve_hr_admin_approver(
  p_tenant_id UUID,
  p_requester_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core
AS $$
DECLARE
  v_approver_id UUID;
BEGIN
  SELECT e.id
  INTO v_approver_id
  FROM puls_core.employees e
  WHERE e.tenant_id = p_tenant_id
    AND e.employment_status = 'active'::puls_core.employment_status
    AND e.persona_role = 'hr_admin'::puls_core.persona_role
    AND e.id <> p_requester_id
  ORDER BY e.created_at ASC NULLS LAST
  LIMIT 1;

  RETURN v_approver_id;
END;
$$;

DROP FUNCTION IF EXISTS puls_workflow.resolve_approver(UUID, UUID);

CREATE OR REPLACE FUNCTION puls_workflow.resolve_approver(
  p_tenant_id UUID,
  p_requester_id UUID,
  p_module TEXT DEFAULT NULL,
  p_approval_policy_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core, puls_audit
AS $$
DECLARE
  v_step RECORD;
  v_approver_id UUID;
BEGIN
  IF p_approval_policy_id IS NOT NULL THEN
    SELECT s.approver_type, s.specific_employee_id
    INTO v_step
    FROM puls_workflow.approval_policy_steps s
    JOIN puls_workflow.approval_policies p ON p.id = s.policy_id
    WHERE s.policy_id = p_approval_policy_id
      AND s.tenant_id = p_tenant_id
      AND s.step_order = 1
      AND p.is_active = TRUE;

    IF FOUND THEN
      IF v_step.approver_type = 'manager'::puls_workflow.approver_type THEN
        v_approver_id := puls_workflow.resolve_org_primary_manager(p_tenant_id, p_requester_id);
        IF v_approver_id IS NULL THEN
          v_approver_id := puls_workflow.resolve_dept_manager(p_tenant_id, p_requester_id);
        END IF;
      ELSIF v_step.approver_type = 'hr_admin'::puls_workflow.approver_type THEN
        v_approver_id := puls_workflow.resolve_hr_admin_approver(p_tenant_id, p_requester_id);
      ELSIF v_step.approver_type = 'specific_employee'::puls_workflow.approver_type THEN
        IF v_step.specific_employee_id IS NOT NULL
           AND v_step.specific_employee_id <> p_requester_id
           AND EXISTS (
             SELECT 1
             FROM puls_core.employees e
             WHERE e.id = v_step.specific_employee_id
               AND e.tenant_id = p_tenant_id
               AND e.employment_status = 'active'::puls_core.employment_status
           ) THEN
          v_approver_id := v_step.specific_employee_id;
        END IF;
      END IF;

      IF v_approver_id IS NOT NULL THEN
        RETURN v_approver_id;
      END IF;
    END IF;
  END IF;

  v_approver_id := puls_workflow.resolve_org_primary_manager(p_tenant_id, p_requester_id);
  IF v_approver_id IS NOT NULL THEN
    RETURN v_approver_id;
  END IF;

  v_approver_id := puls_workflow.resolve_dept_manager(p_tenant_id, p_requester_id);
  IF v_approver_id IS NOT NULL THEN
    RETURN v_approver_id;
  END IF;

  RETURN puls_workflow.resolve_hr_admin_approver(p_tenant_id, p_requester_id);
END;
$$;

REVOKE ALL ON FUNCTION puls_workflow.resolve_org_primary_manager(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION puls_workflow.resolve_org_primary_manager(UUID, UUID) FROM authenticated;
REVOKE ALL ON FUNCTION puls_workflow.resolve_org_primary_manager(UUID, UUID) FROM anon;

REVOKE ALL ON FUNCTION puls_workflow.resolve_dept_manager(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION puls_workflow.resolve_dept_manager(UUID, UUID) FROM authenticated;
REVOKE ALL ON FUNCTION puls_workflow.resolve_dept_manager(UUID, UUID) FROM anon;

REVOKE ALL ON FUNCTION puls_workflow.resolve_hr_admin_approver(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION puls_workflow.resolve_hr_admin_approver(UUID, UUID) FROM authenticated;
REVOKE ALL ON FUNCTION puls_workflow.resolve_hr_admin_approver(UUID, UUID) FROM anon;

REVOKE ALL ON FUNCTION puls_workflow.resolve_approver(UUID, UUID, TEXT, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION puls_workflow.resolve_approver(UUID, UUID, TEXT, UUID) FROM authenticated;
REVOKE ALL ON FUNCTION puls_workflow.resolve_approver(UUID, UUID, TEXT, UUID) FROM anon;

-- Patch create_leave_request — pass leave type approval_policy_id
CREATE OR REPLACE FUNCTION puls_workflow.create_leave_request(
  p_leave_type_id uuid,
  p_start_date date,
  p_end_date date,
  p_half_day boolean DEFAULT false,
  p_delegate_employee_id uuid DEFAULT NULL,
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
  v_leave_type record;
  v_business_days numeric;
  v_approver_id uuid;
  v_approver_name text;
  v_request_id uuid;
  v_approval_id uuid;
  v_balance_id uuid;
  v_balance_checked boolean := false;
  v_period_year integer;
BEGIN
  v_tenant_id := puls_core.current_tenant_id();
  v_employee_id := puls_core.current_employee_id();
  v_period_year := EXTRACT(YEAR FROM p_start_date)::integer;

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
    AND lt.is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_INVALID_LEAVE_TYPE: Leave type not found or inactive.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_leave_type.requires_document THEN
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
    v_balance_checked := true;

    IF (
      SELECT lb.remaining_days
      FROM puls_workflow.leave_balances lb
      WHERE lb.id = v_balance_id
    ) < v_business_days THEN
      RAISE EXCEPTION 'PULS_INSUFFICIENT_BALANCE: Insufficient leave balance.'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  v_approver_id := puls_workflow.resolve_approver(
    v_tenant_id,
    v_employee_id,
    'leave',
    v_leave_type.approval_policy_id
  );

  IF v_approver_id IS NULL THEN
    RAISE EXCEPTION 'PULS_NO_APPROVER: No approver could be resolved for this request.'
      USING ERRCODE = 'P0001';
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
    current_approval_step
  )
  VALUES (
    v_tenant_id,
    v_employee_id,
    p_leave_type_id,
    p_start_date,
    p_end_date,
    v_business_days,
    COALESCE(p_half_day, false),
    p_delegate_employee_id,
    NULLIF(BTRIM(p_description), ''),
    'pending'::puls_workflow.leave_request_status,
    NOW(),
    1
  )
  RETURNING id INTO v_request_id;

  INSERT INTO puls_workflow.approval_requests (
    tenant_id,
    module,
    leave_request_id,
    requester_employee_id,
    approver_employee_id,
    step_order,
    status
  )
  VALUES (
    v_tenant_id,
    'leave'::puls_workflow.approval_module,
    v_request_id,
    v_employee_id,
    v_approver_id,
    1,
    'pending'::puls_workflow.approval_status
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
      'approval_request_id', v_approval_id
    )
  );

  RETURN jsonb_build_object(
    'leave_request_id', v_request_id,
    'approval_request_id', v_approval_id,
    'business_days', v_business_days,
    'status', 'pending',
    'approver_employee_id', v_approver_id,
    'approver_name', v_approver_name
  );
END;
$$;

-- Patch create_expense_claim — pass category approval_policy_id
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

  IF v_category.receipt_required_over IS NOT NULL
     AND v_category.receipt_required_over > 0
     AND p_amount > v_category.receipt_required_over THEN
    v_policy_status := 'warning'::puls_workflow.policy_status;
  END IF;

  v_approver_id := puls_workflow.resolve_approver(
    v_tenant_id,
    v_employee_id,
    'expense',
    v_category.approval_policy_id
  );

  IF v_approver_id IS NULL THEN
    RAISE EXCEPTION 'PULS_NO_APPROVER: No approver could be resolved for this claim.'
      USING ERRCODE = 'P0001';
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
    submitted_at
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
    NOW()
  )
  RETURNING id INTO v_claim_id;

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
    v_employee_id,
    v_approver_id,
    1,
    'pending'::puls_workflow.approval_status
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
      'approval_request_id', v_approval_id
    )
  );

  RETURN jsonb_build_object(
    'expense_claim_id', v_claim_id,
    'approval_request_id', v_approval_id,
    'status', 'pending',
    'policy_status', v_policy_status,
    'approver_employee_id', v_approver_id
  );
END;
$$;

REVOKE ALL ON FUNCTION puls_workflow.create_leave_request(uuid, date, date, boolean, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION puls_workflow.create_leave_request(uuid, date, date, boolean, uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION puls_workflow.create_leave_request(uuid, date, date, boolean, uuid, text) TO authenticated;

REVOKE ALL ON FUNCTION puls_workflow.create_expense_claim(uuid, text, numeric, text, numeric, boolean, date, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION puls_workflow.create_expense_claim(uuid, text, numeric, text, numeric, boolean, date, text) FROM anon;
GRANT EXECUTE ON FUNCTION puls_workflow.create_expense_claim(uuid, text, numeric, text, numeric, boolean, date, text) TO authenticated;
