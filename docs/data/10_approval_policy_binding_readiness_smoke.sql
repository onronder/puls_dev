-- 10 PR10.10 Approval Policy Binding Readiness — executable smoke (single transaction; rolls back)
-- Asserts binding status CASE order matches computeApprovalPolicyBindingStatus (incl. policy_unavailable before inactive_policy).

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_expense_policy_ready UUID;
  v_expense_policy_inactive UUID;
  v_expense_policy_no_steps UUID;
  v_leave_policy_ready UUID;
  v_leave_policy_mismatch UUID;
  v_category_ready UUID;
  v_category_unbound UUID;
  v_category_inactive UUID;
  v_category_no_steps UUID;
  v_category_mismatch UUID;
  v_leave_ready UUID;
  v_leave_unbound UUID;
  v_status TEXT;
  v_required_step_count INTEGER;
BEGIN
  PERFORM set_config('request.jwt.claim.role', 'service_role', true);

  SELECT id INTO v_tenant_id
  FROM puls_core.tenants
  WHERE legacy_public_tenant_id = '11111111-1111-1111-1111-111111111111'
     OR name ILIKE '%Mert Teknik%'
  LIMIT 1;

  IF v_tenant_id IS NULL THEN
    RAISE NOTICE 'SKIP: demo tenant not found';
    RETURN;
  END IF;

  DELETE FROM puls_workflow.expense_categories
  WHERE tenant_id = v_tenant_id
    AND code LIKE 'demo_policy_binding_%';

  DELETE FROM puls_workflow.leave_types
  WHERE tenant_id = v_tenant_id
    AND code LIKE 'demo_policy_binding_%';

  DELETE FROM puls_workflow.approval_policy_steps s
  USING puls_workflow.approval_policies p
  WHERE s.policy_id = p.id
    AND p.tenant_id = v_tenant_id
    AND p.code LIKE 'demo_policy_binding_%';

  DELETE FROM puls_workflow.approval_policies
  WHERE tenant_id = v_tenant_id
    AND code LIKE 'demo_policy_binding_%';

  -- Policies
  INSERT INTO puls_workflow.approval_policies (tenant_id, code, name, module, is_active)
  VALUES (v_tenant_id, 'demo_policy_binding_expense_ready', 'Demo Expense Ready', 'expense', TRUE)
  RETURNING id INTO v_expense_policy_ready;

  INSERT INTO puls_workflow.approval_policies (tenant_id, code, name, module, is_active)
  VALUES (v_tenant_id, 'demo_policy_binding_expense_inactive', 'Demo Expense Inactive', 'expense', FALSE)
  RETURNING id INTO v_expense_policy_inactive;

  INSERT INTO puls_workflow.approval_policies (tenant_id, code, name, module, is_active)
  VALUES (v_tenant_id, 'demo_policy_binding_expense_no_steps', 'Demo Expense No Steps', 'expense', TRUE)
  RETURNING id INTO v_expense_policy_no_steps;

  INSERT INTO puls_workflow.approval_policies (tenant_id, code, name, module, is_active)
  VALUES (v_tenant_id, 'demo_policy_binding_leave_ready', 'Demo Leave Ready', 'leave', TRUE)
  RETURNING id INTO v_leave_policy_ready;

  INSERT INTO puls_workflow.approval_policies (tenant_id, code, name, module, is_active)
  VALUES (v_tenant_id, 'demo_policy_binding_leave_mismatch', 'Demo Leave Mismatch', 'leave', TRUE)
  RETURNING id INTO v_leave_policy_mismatch;

  INSERT INTO puls_workflow.approval_policy_steps (tenant_id, policy_id, step_order, approver_type, is_required)
  VALUES
    (v_tenant_id, v_expense_policy_ready, 1, 'manager', TRUE),
    (v_tenant_id, v_expense_policy_inactive, 1, 'manager', TRUE),
    (v_tenant_id, v_expense_policy_no_steps, 1, 'manager', FALSE),
    (v_tenant_id, v_leave_policy_ready, 1, 'manager', TRUE),
    (v_tenant_id, v_leave_policy_mismatch, 1, 'manager', TRUE);

  -- Expense categories (5 cases)
  INSERT INTO puls_workflow.expense_categories (
    tenant_id, code, name, monthly_limit, receipt_required_over, approval_policy_id
  ) VALUES
    (v_tenant_id, 'demo_policy_binding_expense_ready', 'Demo Binding Ready', 1000, 0, v_expense_policy_ready),
    (v_tenant_id, 'demo_policy_binding_expense_unbound', 'Demo Binding Unbound', 1000, 0, NULL),
    (v_tenant_id, 'demo_policy_binding_expense_inactive', 'Demo Binding Inactive', 1000, 0, v_expense_policy_inactive),
    (v_tenant_id, 'demo_policy_binding_expense_no_steps', 'Demo Binding No Steps', 1000, 0, v_expense_policy_no_steps),
    (v_tenant_id, 'demo_policy_binding_expense_mismatch', 'Demo Binding Mismatch', 1000, 0, v_leave_policy_mismatch);

  SELECT id INTO v_category_ready
  FROM puls_workflow.expense_categories
  WHERE tenant_id = v_tenant_id AND code = 'demo_policy_binding_expense_ready';

  SELECT id INTO v_category_unbound
  FROM puls_workflow.expense_categories
  WHERE tenant_id = v_tenant_id AND code = 'demo_policy_binding_expense_unbound';

  SELECT id INTO v_category_inactive
  FROM puls_workflow.expense_categories
  WHERE tenant_id = v_tenant_id AND code = 'demo_policy_binding_expense_inactive';

  SELECT id INTO v_category_no_steps
  FROM puls_workflow.expense_categories
  WHERE tenant_id = v_tenant_id AND code = 'demo_policy_binding_expense_no_steps';

  SELECT id INTO v_category_mismatch
  FROM puls_workflow.expense_categories
  WHERE tenant_id = v_tenant_id AND code = 'demo_policy_binding_expense_mismatch';

  -- Leave types (ready + unbound)
  INSERT INTO puls_workflow.leave_types (
    tenant_id, code, name, is_paid, default_entitlement_days, requires_document, approval_policy_id
  ) VALUES
    (v_tenant_id, 'demo_policy_binding_leave_ready', 'Demo Leave Ready', TRUE, 5, FALSE, v_leave_policy_ready),
    (v_tenant_id, 'demo_policy_binding_leave_unbound', 'Demo Leave Unbound', TRUE, 5, FALSE, NULL);

  SELECT id INTO v_leave_ready
  FROM puls_workflow.leave_types
  WHERE tenant_id = v_tenant_id AND code = 'demo_policy_binding_leave_ready';

  SELECT id INTO v_leave_unbound
  FROM puls_workflow.leave_types
  WHERE tenant_id = v_tenant_id AND code = 'demo_policy_binding_leave_unbound';

  -- ---------------------------------------------------------------------------
  -- Expense case: ready
  -- ---------------------------------------------------------------------------
  SELECT
    CASE
      WHEN ec.approval_policy_id IS NULL THEN 'unbound'
      WHEN ap.id IS NULL THEN 'policy_unavailable'
      WHEN ap.is_active IS DISTINCT FROM TRUE THEN 'inactive_policy'
      WHEN ap.module <> 'expense' THEN 'module_mismatch'
      WHEN COALESCE(steps.required_step_count, 0) < 1 THEN 'missing_required_steps'
      ELSE 'ready'
    END,
    COALESCE(steps.required_step_count, 0)
  INTO v_status, v_required_step_count
  FROM puls_workflow.expense_categories ec
  LEFT JOIN puls_workflow.approval_policies ap
    ON ap.id = ec.approval_policy_id AND ap.tenant_id = ec.tenant_id
  LEFT JOIN LATERAL (
    SELECT COUNT(*)::INTEGER AS required_step_count
    FROM puls_workflow.approval_policy_steps s
    WHERE s.policy_id = ec.approval_policy_id
      AND s.tenant_id = ec.tenant_id
      AND s.is_required = TRUE
  ) steps ON TRUE
  WHERE ec.id = v_category_ready;

  IF v_status <> 'ready' OR v_required_step_count < 1 THEN
    RAISE EXCEPTION 'SMOKE_FAIL expense ready: expected ready with required steps, got % (count=%)', v_status, v_required_step_count;
  END IF;

  -- ---------------------------------------------------------------------------
  -- Expense case: unbound
  -- ---------------------------------------------------------------------------
  SELECT
    CASE
      WHEN ec.approval_policy_id IS NULL THEN 'unbound'
      WHEN ap.id IS NULL THEN 'policy_unavailable'
      WHEN ap.is_active IS DISTINCT FROM TRUE THEN 'inactive_policy'
      WHEN ap.module <> 'expense' THEN 'module_mismatch'
      WHEN COALESCE(steps.required_step_count, 0) < 1 THEN 'missing_required_steps'
      ELSE 'ready'
    END
  INTO v_status
  FROM puls_workflow.expense_categories ec
  LEFT JOIN puls_workflow.approval_policies ap
    ON ap.id = ec.approval_policy_id AND ap.tenant_id = ec.tenant_id
  LEFT JOIN LATERAL (
    SELECT COUNT(*)::INTEGER AS required_step_count
    FROM puls_workflow.approval_policy_steps s
    WHERE s.policy_id = ec.approval_policy_id
      AND s.tenant_id = ec.tenant_id
      AND s.is_required = TRUE
  ) steps ON TRUE
  WHERE ec.id = v_category_unbound;

  IF v_status <> 'unbound' THEN
    RAISE EXCEPTION 'SMOKE_FAIL expense unbound: expected unbound, got %', v_status;
  END IF;

  -- ---------------------------------------------------------------------------
  -- Expense case: inactive_policy (readable metadata)
  -- ---------------------------------------------------------------------------
  SELECT
    CASE
      WHEN ec.approval_policy_id IS NULL THEN 'unbound'
      WHEN ap.id IS NULL THEN 'policy_unavailable'
      WHEN ap.is_active IS DISTINCT FROM TRUE THEN 'inactive_policy'
      WHEN ap.module <> 'expense' THEN 'module_mismatch'
      WHEN COALESCE(steps.required_step_count, 0) < 1 THEN 'missing_required_steps'
      ELSE 'ready'
    END
  INTO v_status
  FROM puls_workflow.expense_categories ec
  LEFT JOIN puls_workflow.approval_policies ap
    ON ap.id = ec.approval_policy_id AND ap.tenant_id = ec.tenant_id
  LEFT JOIN LATERAL (
    SELECT COUNT(*)::INTEGER AS required_step_count
    FROM puls_workflow.approval_policy_steps s
    WHERE s.policy_id = ec.approval_policy_id
      AND s.tenant_id = ec.tenant_id
      AND s.is_required = TRUE
  ) steps ON TRUE
  WHERE ec.id = v_category_inactive;

  IF v_status <> 'inactive_policy' THEN
    RAISE EXCEPTION 'SMOKE_FAIL expense inactive_policy: expected inactive_policy, got %', v_status;
  END IF;

  -- ---------------------------------------------------------------------------
  -- Expense case: missing_required_steps
  -- ---------------------------------------------------------------------------
  SELECT
    CASE
      WHEN ec.approval_policy_id IS NULL THEN 'unbound'
      WHEN ap.id IS NULL THEN 'policy_unavailable'
      WHEN ap.is_active IS DISTINCT FROM TRUE THEN 'inactive_policy'
      WHEN ap.module <> 'expense' THEN 'module_mismatch'
      WHEN COALESCE(steps.required_step_count, 0) < 1 THEN 'missing_required_steps'
      ELSE 'ready'
    END
  INTO v_status
  FROM puls_workflow.expense_categories ec
  LEFT JOIN puls_workflow.approval_policies ap
    ON ap.id = ec.approval_policy_id AND ap.tenant_id = ec.tenant_id
  LEFT JOIN LATERAL (
    SELECT COUNT(*)::INTEGER AS required_step_count
    FROM puls_workflow.approval_policy_steps s
    WHERE s.policy_id = ec.approval_policy_id
      AND s.tenant_id = ec.tenant_id
      AND s.is_required = TRUE
  ) steps ON TRUE
  WHERE ec.id = v_category_no_steps;

  IF v_status <> 'missing_required_steps' THEN
    RAISE EXCEPTION 'SMOKE_FAIL expense missing_required_steps: expected missing_required_steps, got %', v_status;
  END IF;

  -- ---------------------------------------------------------------------------
  -- Expense case: module_mismatch
  -- ---------------------------------------------------------------------------
  SELECT
    CASE
      WHEN ec.approval_policy_id IS NULL THEN 'unbound'
      WHEN ap.id IS NULL THEN 'policy_unavailable'
      WHEN ap.is_active IS DISTINCT FROM TRUE THEN 'inactive_policy'
      WHEN ap.module <> 'expense' THEN 'module_mismatch'
      WHEN COALESCE(steps.required_step_count, 0) < 1 THEN 'missing_required_steps'
      ELSE 'ready'
    END
  INTO v_status
  FROM puls_workflow.expense_categories ec
  LEFT JOIN puls_workflow.approval_policies ap
    ON ap.id = ec.approval_policy_id AND ap.tenant_id = ec.tenant_id
  LEFT JOIN LATERAL (
    SELECT COUNT(*)::INTEGER AS required_step_count
    FROM puls_workflow.approval_policy_steps s
    WHERE s.policy_id = ec.approval_policy_id
      AND s.tenant_id = ec.tenant_id
      AND s.is_required = TRUE
  ) steps ON TRUE
  WHERE ec.id = v_category_mismatch;

  IF v_status <> 'module_mismatch' THEN
    RAISE EXCEPTION 'SMOKE_FAIL expense module_mismatch: expected module_mismatch, got %', v_status;
  END IF;

  -- ---------------------------------------------------------------------------
  -- Leave case: ready
  -- ---------------------------------------------------------------------------
  SELECT
    CASE
      WHEN lt.approval_policy_id IS NULL THEN 'unbound'
      WHEN ap.id IS NULL THEN 'policy_unavailable'
      WHEN ap.is_active IS DISTINCT FROM TRUE THEN 'inactive_policy'
      WHEN ap.module <> 'leave' THEN 'module_mismatch'
      WHEN COALESCE(steps.required_step_count, 0) < 1 THEN 'missing_required_steps'
      ELSE 'ready'
    END
  INTO v_status
  FROM puls_workflow.leave_types lt
  LEFT JOIN puls_workflow.approval_policies ap
    ON ap.id = lt.approval_policy_id AND ap.tenant_id = lt.tenant_id
  LEFT JOIN LATERAL (
    SELECT COUNT(*)::INTEGER AS required_step_count
    FROM puls_workflow.approval_policy_steps s
    WHERE s.policy_id = lt.approval_policy_id
      AND s.tenant_id = lt.tenant_id
      AND s.is_required = TRUE
  ) steps ON TRUE
  WHERE lt.id = v_leave_ready;

  IF v_status <> 'ready' THEN
    RAISE EXCEPTION 'SMOKE_FAIL leave ready: expected ready, got %', v_status;
  END IF;

  -- ---------------------------------------------------------------------------
  -- Leave case: unbound
  -- ---------------------------------------------------------------------------
  SELECT
    CASE
      WHEN lt.approval_policy_id IS NULL THEN 'unbound'
      WHEN ap.id IS NULL THEN 'policy_unavailable'
      WHEN ap.is_active IS DISTINCT FROM TRUE THEN 'inactive_policy'
      WHEN ap.module <> 'leave' THEN 'module_mismatch'
      WHEN COALESCE(steps.required_step_count, 0) < 1 THEN 'missing_required_steps'
      ELSE 'ready'
    END
  INTO v_status
  FROM puls_workflow.leave_types lt
  LEFT JOIN puls_workflow.approval_policies ap
    ON ap.id = lt.approval_policy_id AND ap.tenant_id = lt.tenant_id
  LEFT JOIN LATERAL (
    SELECT COUNT(*)::INTEGER AS required_step_count
    FROM puls_workflow.approval_policy_steps s
    WHERE s.policy_id = lt.approval_policy_id
      AND s.tenant_id = lt.tenant_id
      AND s.is_required = TRUE
  ) steps ON TRUE
  WHERE lt.id = v_leave_unbound;

  IF v_status <> 'unbound' THEN
    RAISE EXCEPTION 'SMOKE_FAIL leave unbound: expected unbound, got %', v_status;
  END IF;

  RAISE NOTICE 'OK: PR10.10 approval policy binding readiness smoke passed';
END $$;

ROLLBACK;
