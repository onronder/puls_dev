-- 10 PR10.12 Leave Type Lifecycle Consumption — executable smoke (single transaction; rolls back)
--
-- Fixture prefix: demo_leave_type_lifecycle_*
-- Cleanup order: leave_requests first, then leave_types (ON DELETE RESTRICT on leave_type_id).
-- Approved guard is date-aware: future/current approved blocks; past approved allows deactivate.
--
-- Fixture A: lifecycle RPC path (deactivate / re-deactivate / restore / re-restore)
-- Fixture B: open-status guards (draft, pending, approved future) + approved past allowed
-- Fixture C: consumption (active create, inactive create reject, historical readability)

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_employee_id UUID;
  v_user_id UUID;
  v_policy_id UUID;
  v_lifecycle_type_id UUID;
  v_active_type_id UUID;
  v_history_type_id UUID;
  v_open_type_id UUID;
  v_past_type_id UUID;
  v_policy_type_id UUID;
  v_historical_request_id UUID;
  v_result JSONB;
  v_type_name TEXT;
  v_type_code TEXT;
  v_type_active BOOLEAN;
  v_status TEXT;
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

  SELECT e.id, e.user_id
  INTO v_employee_id, v_user_id
  FROM puls_core.employees e
  WHERE e.tenant_id = v_tenant_id
    AND e.user_id IS NOT NULL
  LIMIT 1;

  IF v_employee_id IS NULL OR v_user_id IS NULL THEN
    RAISE EXCEPTION 'SMOKE_SETUP_FAIL: expected employee with user_id for consumption smoke';
  END IF;

  -- Cleanup: leave_requests first, then leave_types (ON DELETE RESTRICT)
  DELETE FROM puls_workflow.leave_requests lr
  USING puls_workflow.leave_types lt
  WHERE lr.leave_type_id = lt.id
    AND lt.tenant_id = v_tenant_id
    AND lt.code LIKE 'demo_leave_type_lifecycle%';

  DELETE FROM puls_workflow.leave_types
  WHERE tenant_id = v_tenant_id
    AND code LIKE 'demo_leave_type_lifecycle%';

  INSERT INTO puls_workflow.approval_policies (tenant_id, code, name, module, is_active)
  VALUES (v_tenant_id, 'demo_leave_type_lifecycle_policy', 'Demo Leave Lifecycle', 'leave', TRUE)
  ON CONFLICT (tenant_id, code) DO UPDATE SET is_active = TRUE, module = 'leave';

  SELECT id INTO v_policy_id
  FROM puls_workflow.approval_policies
  WHERE tenant_id = v_tenant_id AND code = 'demo_leave_type_lifecycle_policy';

  DELETE FROM puls_workflow.approval_policy_steps WHERE policy_id = v_policy_id;

  INSERT INTO puls_workflow.approval_policy_steps (tenant_id, policy_id, step_order, approver_type, is_required)
  VALUES (v_tenant_id, v_policy_id, 1, 'manager', TRUE);

  -- ---------------------------------------------------------------------------
  -- Fixture A: lifecycle RPC (fresh deactivate / re-deactivate / restore / re-restore)
  -- ---------------------------------------------------------------------------

  INSERT INTO puls_workflow.leave_types (
    tenant_id, code, name, default_entitlement_days, requires_document,
    carry_over_allowed, is_active
  ) VALUES (
    v_tenant_id, 'demo_leave_type_lifecycle_rpc', 'Demo Lifecycle RPC', 10, FALSE, FALSE, TRUE
  )
  RETURNING id INTO v_lifecycle_type_id;

  v_result := puls_workflow.deactivate_leave_type(v_lifecycle_type_id);
  IF v_result->>'status' <> 'deactivated' THEN
    RAISE EXCEPTION 'SMOKE_FAIL Fixture A: expected deactivated, got %', v_result;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM puls_workflow.leave_types WHERE id = v_lifecycle_type_id AND is_active = FALSE
  ) THEN
    RAISE EXCEPTION 'SMOKE_FAIL Fixture A: leave type should be inactive after deactivate';
  END IF;

  v_result := puls_workflow.deactivate_leave_type(v_lifecycle_type_id);
  IF v_result->>'status' <> 'already_inactive' THEN
    RAISE EXCEPTION 'SMOKE_FAIL Fixture A: expected already_inactive, got %', v_result;
  END IF;

  v_result := puls_workflow.restore_leave_type(v_lifecycle_type_id);
  IF v_result->>'status' <> 'restored' THEN
    RAISE EXCEPTION 'SMOKE_FAIL Fixture A: expected restored, got %', v_result;
  END IF;

  v_result := puls_workflow.restore_leave_type(v_lifecycle_type_id);
  IF v_result->>'status' <> 'already_active' THEN
    RAISE EXCEPTION 'SMOKE_FAIL Fixture A: expected already_active, got %', v_result;
  END IF;

  -- ---------------------------------------------------------------------------
  -- Fixture B: open-status guards
  -- ---------------------------------------------------------------------------

  INSERT INTO puls_workflow.leave_types (
    tenant_id, code, name, default_entitlement_days, requires_document, carry_over_allowed
  ) VALUES (
    v_tenant_id, 'demo_leave_type_lifecycle_open', 'Demo Lifecycle Open Guard', 5, FALSE, FALSE
  )
  RETURNING id INTO v_open_type_id;

  FOR v_status IN SELECT unnest(ARRAY['draft', 'pending']) LOOP
    INSERT INTO puls_workflow.leave_requests (
      tenant_id, employee_id, leave_type_id, start_date, end_date, business_days, status
    ) VALUES (
      v_tenant_id, v_employee_id, v_open_type_id,
      CURRENT_DATE + 7, CURRENT_DATE + 7, 1, v_status::puls_workflow.leave_request_status
    );

    BEGIN
      PERFORM puls_workflow.deactivate_leave_type(v_open_type_id);
      RAISE EXCEPTION 'SMOKE_FAIL Fixture B: % request should block deactivate', v_status;
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLERRM NOT LIKE '%PULS_LEAVE_TYPE_IN_USE_ACTIVE_REQUESTS%' THEN RAISE; END IF;
    END;

    DELETE FROM puls_workflow.leave_requests
    WHERE leave_type_id = v_open_type_id AND tenant_id = v_tenant_id;
  END LOOP;

  -- approved future/current should block
  INSERT INTO puls_workflow.leave_requests (
    tenant_id, employee_id, leave_type_id, start_date, end_date, business_days, status, approved_at
  ) VALUES (
    v_tenant_id, v_employee_id, v_open_type_id,
    CURRENT_DATE, CURRENT_DATE + 3, 2, 'approved', NOW()
  );

  BEGIN
    PERFORM puls_workflow.deactivate_leave_type(v_open_type_id);
    RAISE EXCEPTION 'SMOKE_FAIL Fixture B: approved future/current should block deactivate';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_LEAVE_TYPE_IN_USE_ACTIVE_REQUESTS%' THEN RAISE; END IF;
  END;

  DELETE FROM puls_workflow.leave_requests
  WHERE leave_type_id = v_open_type_id AND tenant_id = v_tenant_id;

  -- approved past only should allow deactivate
  INSERT INTO puls_workflow.leave_types (
    tenant_id, code, name, default_entitlement_days, requires_document, carry_over_allowed
  ) VALUES (
    v_tenant_id, 'demo_leave_type_lifecycle_past', 'Demo Lifecycle Past Approved', 5, FALSE, FALSE
  )
  RETURNING id INTO v_past_type_id;

  INSERT INTO puls_workflow.leave_requests (
    tenant_id, employee_id, leave_type_id, start_date, end_date, business_days, status, approved_at
  ) VALUES (
    v_tenant_id, v_employee_id, v_past_type_id,
    CURRENT_DATE - 30, CURRENT_DATE - 28, 2, 'approved', NOW() - INTERVAL '29 days'
  );

  v_result := puls_workflow.deactivate_leave_type(v_past_type_id);
  IF v_result->>'status' <> 'deactivated' THEN
    RAISE EXCEPTION 'SMOKE_FAIL Fixture B: approved past only should allow deactivate, got %', v_result;
  END IF;

  -- rejected/cancelled history should allow deactivate
  INSERT INTO puls_workflow.leave_types (
    tenant_id, code, name, default_entitlement_days, requires_document, carry_over_allowed
  ) VALUES (
    v_tenant_id, 'demo_leave_type_lifecycle_closed', 'Demo Lifecycle Closed History', 5, FALSE, FALSE
  )
  RETURNING id INTO v_open_type_id;

  INSERT INTO puls_workflow.leave_requests (
    tenant_id, employee_id, leave_type_id, start_date, end_date, business_days, status
  ) VALUES
    (v_tenant_id, v_employee_id, v_open_type_id, CURRENT_DATE - 10, CURRENT_DATE - 9, 1, 'rejected'),
    (v_tenant_id, v_employee_id, v_open_type_id, CURRENT_DATE - 5, CURRENT_DATE - 4, 1, 'cancelled');

  v_result := puls_workflow.deactivate_leave_type(v_open_type_id);
  IF v_result->>'status' <> 'deactivated' THEN
    RAISE EXCEPTION 'SMOKE_FAIL Fixture B: rejected/cancelled history should allow deactivate, got %', v_result;
  END IF;

  -- policy binding with no open requests should allow deactivate
  INSERT INTO puls_workflow.leave_types (
    tenant_id, code, name, default_entitlement_days, requires_document,
    carry_over_allowed, approval_policy_id
  ) VALUES (
    v_tenant_id, 'demo_leave_type_lifecycle_policy', 'Demo Lifecycle Policy Bound', 5, FALSE, FALSE, v_policy_id
  )
  RETURNING id INTO v_policy_type_id;

  v_result := puls_workflow.deactivate_leave_type(v_policy_type_id);
  IF v_result->>'status' <> 'deactivated' THEN
    RAISE EXCEPTION 'SMOKE_FAIL Fixture B: policy binding should not block deactivate, got %', v_result;
  END IF;

  -- ---------------------------------------------------------------------------
  -- Fixture C: consumption (active create, inactive reject, historical readability)
  -- ---------------------------------------------------------------------------

  INSERT INTO puls_workflow.leave_types (
    tenant_id, code, name, default_entitlement_days, requires_document, carry_over_allowed
  ) VALUES (
    v_tenant_id, 'demo_leave_type_lifecycle_active', 'Demo Lifecycle Active', 10, FALSE, FALSE
  )
  RETURNING id INTO v_active_type_id;

  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', v_user_id::text, true);

  BEGIN
    v_result := puls_workflow.create_leave_request(
      v_active_type_id,
      CURRENT_DATE + 14,
      CURRENT_DATE + 14,
      FALSE,
      NULL,
      'PR10.12 Fixture C active create'
    );
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM LIKE '%PULS_NO_APPROVER%' OR SQLERRM LIKE '%PULS_POLICY_STEP_UNRESOLVED%' THEN
        RAISE NOTICE 'SKIP Fixture C active create: approver not configured in demo tenant';
      ELSE
        RAISE;
      END IF;
  END;

  INSERT INTO puls_workflow.leave_types (
    tenant_id, code, name, default_entitlement_days, requires_document, carry_over_allowed, is_active
  ) VALUES (
    v_tenant_id, 'demo_leave_type_lifecycle_history', 'Demo Lifecycle History', 10, FALSE, FALSE, TRUE
  )
  RETURNING id INTO v_history_type_id;

  INSERT INTO puls_workflow.leave_requests (
    tenant_id, employee_id, leave_type_id, start_date, end_date, business_days, status, approved_at
  ) VALUES (
    v_tenant_id, v_employee_id, v_history_type_id,
    CURRENT_DATE - 60, CURRENT_DATE - 58, 2, 'approved', NOW() - INTERVAL '59 days'
  )
  RETURNING id INTO v_historical_request_id;

  PERFORM set_config('request.jwt.claim.role', 'service_role', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);

  v_result := puls_workflow.deactivate_leave_type(v_history_type_id);
  IF v_result->>'status' <> 'deactivated' THEN
    RAISE EXCEPTION 'SMOKE_FAIL Fixture C: expected deactivated for history type, got %', v_result;
  END IF;

  SELECT lt.name, lt.code, lt.is_active
  INTO v_type_name, v_type_code, v_type_active
  FROM puls_workflow.leave_requests lr
  JOIN puls_workflow.leave_types lt ON lt.id = lr.leave_type_id
  WHERE lr.id = v_historical_request_id;

  IF v_type_name IS NULL OR BTRIM(v_type_name) = '' THEN
    RAISE EXCEPTION 'SMOKE_FAIL Fixture C: historical leave request type name should remain readable';
  END IF;

  IF v_type_code IS NULL OR BTRIM(v_type_code) = '' THEN
    RAISE EXCEPTION 'SMOKE_FAIL Fixture C: historical leave request type code should remain readable';
  END IF;

  IF v_type_active IS NOT FALSE THEN
    RAISE EXCEPTION 'SMOKE_FAIL Fixture C: historical leave request should reference inactive leave type row, got is_active=%', v_type_active;
  END IF;

  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', v_user_id::text, true);

  BEGIN
    v_result := puls_workflow.create_leave_request(
      v_history_type_id,
      CURRENT_DATE + 21,
      CURRENT_DATE + 21,
      FALSE,
      NULL,
      'Fixture C inactive create rejection'
    );
    RAISE EXCEPTION 'SMOKE_FAIL Fixture C: inactive leave type should reject create_leave_request';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_INVALID_LEAVE_TYPE%' THEN
        RAISE;
      END IF;
  END;

  PERFORM set_config('request.jwt.claim.role', 'service_role', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
END;
$$;

ROLLBACK;
