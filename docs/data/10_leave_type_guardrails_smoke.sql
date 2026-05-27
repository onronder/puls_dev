-- 10 PR10.11 Leave Type Guardrails — executable smoke (single transaction; rolls back)

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_leave_type_id UUID;
  v_leave_policy_id UUID;
  v_expense_policy_id UUID;
  v_stored_name TEXT;
  v_stored_code TEXT;
  v_stored_entitlement NUMERIC(8, 2);
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

  DELETE FROM puls_workflow.leave_types
  WHERE tenant_id = v_tenant_id
    AND code LIKE 'demo_leave_type_guardrails%';

  INSERT INTO puls_workflow.approval_policies (tenant_id, code, name, module, is_active)
  VALUES (v_tenant_id, 'demo_leave_type_guardrails_leave', 'Demo Leave Guardrails', 'leave', TRUE)
  ON CONFLICT (tenant_id, code) DO UPDATE SET is_active = TRUE, module = 'leave';

  INSERT INTO puls_workflow.approval_policies (tenant_id, code, name, module, is_active)
  VALUES (v_tenant_id, 'demo_leave_type_guardrails_expense', 'Demo Expense Guardrails', 'expense', TRUE)
  ON CONFLICT (tenant_id, code) DO UPDATE SET is_active = TRUE, module = 'expense';

  SELECT id INTO v_leave_policy_id
  FROM puls_workflow.approval_policies
  WHERE tenant_id = v_tenant_id AND code = 'demo_leave_type_guardrails_leave';

  SELECT id INTO v_expense_policy_id
  FROM puls_workflow.approval_policies
  WHERE tenant_id = v_tenant_id AND code = 'demo_leave_type_guardrails_expense';

  DELETE FROM puls_workflow.approval_policy_steps
  WHERE policy_id IN (v_leave_policy_id, v_expense_policy_id);

  INSERT INTO puls_workflow.approval_policy_steps (tenant_id, policy_id, step_order, approver_type, is_required)
  VALUES
    (v_tenant_id, v_leave_policy_id, 1, 'manager', TRUE),
    (v_tenant_id, v_expense_policy_id, 1, 'manager', TRUE);

  -- Valid insert
  INSERT INTO puls_workflow.leave_types (
    tenant_id, code, name, default_entitlement_days, requires_document,
    carry_over_allowed, max_carry_over_days, approval_policy_id
  ) VALUES (
    v_tenant_id, 'demo_leave_type_guardrails_valid', 'Demo Leave Valid', 20, FALSE,
    TRUE, 5, v_leave_policy_id
  )
  RETURNING id INTO v_leave_type_id;

  -- Valid update trims name/code
  UPDATE puls_workflow.leave_types
  SET name = '  Demo Leave Trimmed  ',
      code = '  demo_leave_type_guardrails_trim  '
  WHERE id = v_leave_type_id;

  SELECT name, code INTO v_stored_name, v_stored_code
  FROM puls_workflow.leave_types
  WHERE id = v_leave_type_id;

  IF v_stored_name <> 'Demo Leave Trimmed' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected trimmed name, got %', v_stored_name;
  END IF;

  IF v_stored_code <> 'demo_leave_type_guardrails_trim' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected trimmed code, got %', v_stored_code;
  END IF;

  -- Blank name
  BEGIN
    UPDATE puls_workflow.leave_types SET name = '   ' WHERE id = v_leave_type_id;
    RAISE EXCEPTION 'SMOKE_FAIL: blank name should raise PULS_LEAVE_TYPE_NAME_REQUIRED';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_LEAVE_TYPE_NAME_REQUIRED%' THEN RAISE; END IF;
  END;

  UPDATE puls_workflow.leave_types SET name = 'Demo Leave Trimmed' WHERE id = v_leave_type_id;

  -- Blank code
  BEGIN
    UPDATE puls_workflow.leave_types SET code = '   ' WHERE id = v_leave_type_id;
    RAISE EXCEPTION 'SMOKE_FAIL: blank code should raise PULS_LEAVE_TYPE_CODE_REQUIRED';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_LEAVE_TYPE_CODE_REQUIRED%' THEN RAISE; END IF;
  END;

  -- Invalid code formats
  FOR v_stored_name IN SELECT unnest(ARRAY['Demo Bad', 'demo-bad', '1demo']) LOOP
    BEGIN
      UPDATE puls_workflow.leave_types SET code = v_stored_name WHERE id = v_leave_type_id;
      RAISE EXCEPTION 'SMOKE_FAIL: invalid code % should raise PULS_LEAVE_TYPE_CODE_INVALID', v_stored_name;
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLERRM NOT LIKE '%PULS_LEAVE_TYPE_CODE_INVALID%' THEN RAISE; END IF;
    END;
  END LOOP;

  UPDATE puls_workflow.leave_types
  SET code = 'demo_leave_type_guardrails_trim'
  WHERE id = v_leave_type_id;

  -- Negative entitlement
  BEGIN
    UPDATE puls_workflow.leave_types SET default_entitlement_days = -1 WHERE id = v_leave_type_id;
    RAISE EXCEPTION 'SMOKE_FAIL: negative entitlement should raise PULS_LEAVE_TYPE_ENTITLEMENT_INVALID';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_LEAVE_TYPE_ENTITLEMENT_INVALID%' THEN RAISE; END IF;
  END;

  -- Entitlement > 365
  BEGIN
    UPDATE puls_workflow.leave_types SET default_entitlement_days = 366 WHERE id = v_leave_type_id;
    RAISE EXCEPTION 'SMOKE_FAIL: entitlement >365 should raise PULS_LEAVE_TYPE_ENTITLEMENT_INVALID';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_LEAVE_TYPE_ENTITLEMENT_INVALID%' THEN RAISE; END IF;
  END;

  -- Half-day entitlement (1.5) valid
  UPDATE puls_workflow.leave_types
  SET default_entitlement_days = 1.5
  WHERE id = v_leave_type_id;

  SELECT default_entitlement_days INTO v_stored_entitlement
  FROM puls_workflow.leave_types
  WHERE id = v_leave_type_id;

  IF v_stored_entitlement <> 1.5 THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected half-day entitlement 1.5, got %', v_stored_entitlement;
  END IF;

  UPDATE puls_workflow.leave_types
  SET default_entitlement_days = 20
  WHERE id = v_leave_type_id;

  -- Negative carry over
  BEGIN
    UPDATE puls_workflow.leave_types SET max_carry_over_days = -1 WHERE id = v_leave_type_id;
    RAISE EXCEPTION 'SMOKE_FAIL: negative carry over should raise PULS_LEAVE_TYPE_CARRY_OVER_INVALID';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_LEAVE_TYPE_CARRY_OVER_INVALID%' THEN RAISE; END IF;
  END;

  -- carry_over_allowed false + max > 0
  BEGIN
    UPDATE puls_workflow.leave_types
    SET carry_over_allowed = FALSE, max_carry_over_days = 3
    WHERE id = v_leave_type_id;
    RAISE EXCEPTION 'SMOKE_FAIL: carry over false with positive max should raise PULS_LEAVE_TYPE_CARRY_OVER_INVALID';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_LEAVE_TYPE_CARRY_OVER_INVALID%' THEN RAISE; END IF;
  END;

  UPDATE puls_workflow.leave_types
  SET carry_over_allowed = TRUE, max_carry_over_days = 5, default_entitlement_days = 20
  WHERE id = v_leave_type_id;

  -- Duplicate code (exact)
  BEGIN
    INSERT INTO puls_workflow.leave_types (tenant_id, code, name)
    VALUES (v_tenant_id, 'demo_leave_type_guardrails_trim', 'Duplicate Exact');
    RAISE EXCEPTION 'SMOKE_FAIL: duplicate code should raise 23505';
  EXCEPTION
    WHEN unique_violation THEN
      NULL;
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%23505%' AND SQLSTATE <> '23505' THEN RAISE; END IF;
  END;

  -- Duplicate code after trim
  BEGIN
    INSERT INTO puls_workflow.leave_types (tenant_id, code, name)
    VALUES (v_tenant_id, ' demo_leave_type_guardrails_dup ', 'Duplicate Trim A');
    INSERT INTO puls_workflow.leave_types (tenant_id, code, name)
    VALUES (v_tenant_id, 'demo_leave_type_guardrails_dup', 'Duplicate Trim B');
    RAISE EXCEPTION 'SMOKE_FAIL: trim-normalized duplicate code should raise 23505';
  EXCEPTION
    WHEN unique_violation THEN
      NULL;
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%23505%' AND SQLSTATE <> '23505' THEN RAISE; END IF;
  END;

  -- Policy module mismatch
  BEGIN
    UPDATE puls_workflow.leave_types
    SET approval_policy_id = v_expense_policy_id
    WHERE id = v_leave_type_id;
    RAISE EXCEPTION 'SMOKE_FAIL: expense policy should raise PULS_LEAVE_TYPE_POLICY_MODULE_INVALID';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_LEAVE_TYPE_POLICY_MODULE_INVALID%' THEN RAISE; END IF;
  END;

  -- Same-tenant leave policy
  UPDATE puls_workflow.leave_types
  SET approval_policy_id = v_leave_policy_id
  WHERE id = v_leave_type_id;

  -- Null policy
  UPDATE puls_workflow.leave_types
  SET approval_policy_id = NULL
  WHERE id = v_leave_type_id;

  RAISE NOTICE 'OK: PR10.11 leave type guardrails smoke passed';
END $$;

ROLLBACK;
