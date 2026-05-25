-- 10 PR10.1 Policy Step Config — executable smoke (single transaction; rolls back)
-- Config columns are validated on write; resolver/decide do not read them in PR10.1.

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_requester_id UUID;
  v_manager_id UUID;
  v_policy_id UUID;
  v_step_id UUID;
  v_approver UUID;
BEGIN
  PERFORM set_config('request.jwt.claim.role', 'service_role', true);

  SELECT id INTO v_tenant_id
  FROM puls_core.tenants
  WHERE legacy_public_tenant_id = '44444444-4444-4444-4444-444444444444'
  LIMIT 1;

  IF v_tenant_id IS NULL THEN
    RAISE NOTICE 'SKIP: demo tenant not found';
    RETURN;
  END IF;

  SELECT id INTO v_requester_id
  FROM puls_core.employees
  WHERE tenant_id = v_tenant_id
    AND employment_status = 'active'
  ORDER BY full_name
  LIMIT 1;

  SELECT id INTO v_manager_id
  FROM puls_core.employees
  WHERE tenant_id = v_tenant_id
    AND employment_status = 'active'
    AND id <> v_requester_id
  ORDER BY full_name
  LIMIT 1;

  IF v_requester_id IS NULL OR v_manager_id IS NULL THEN
    RAISE NOTICE 'SKIP: insufficient demo employees';
    RETURN;
  END IF;

  PERFORM puls_core.upsert_primary_reporting_line(
    v_tenant_id, v_requester_id, v_manager_id, 'demo'
  );

  INSERT INTO puls_workflow.approval_policies (tenant_id, code, name, module)
  VALUES (v_tenant_id, 'smoke_psc10', 'Smoke PR10.1 Step Config', 'leave')
  ON CONFLICT (tenant_id, code) DO UPDATE SET is_active = TRUE;

  SELECT id INTO v_policy_id
  FROM puls_workflow.approval_policies
  WHERE tenant_id = v_tenant_id AND code = 'smoke_psc10';

  DELETE FROM puls_workflow.approval_policy_steps WHERE policy_id = v_policy_id;

  INSERT INTO puls_workflow.approval_policy_steps (
    tenant_id, policy_id, step_order, approver_type, is_required,
    step_resolver_config, step_condition_config
  ) VALUES (
    v_tenant_id, v_policy_id, 1, 'manager', TRUE, NULL, NULL
  )
  RETURNING id INTO v_step_id;

  UPDATE puls_workflow.approval_policy_steps
  SET step_resolver_config = '{}'::jsonb,
      step_condition_config = '{}'::jsonb
  WHERE id = v_step_id;

  BEGIN
    UPDATE puls_workflow.approval_policy_steps
    SET step_condition_config = '[]'::jsonb
    WHERE id = v_step_id;
    RAISE EXCEPTION 'SMOKE_FAIL: [] config should raise PULS_POLICY_STEP_CONFIG_INVALID';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_POLICY_STEP_CONFIG_INVALID%' THEN
        RAISE;
      END IF;
  END;

  BEGIN
    UPDATE puls_workflow.approval_policy_steps
    SET step_resolver_config = '{"pool_code":"x"}'::jsonb
    WHERE id = v_step_id;
    RAISE EXCEPTION 'SMOKE_FAIL: unknown field should raise PULS_POLICY_STEP_CONFIG_UNKNOWN_FIELD';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_POLICY_STEP_CONFIG_UNKNOWN_FIELD%' THEN
        RAISE;
      END IF;
  END;

  BEGIN
    UPDATE puls_workflow.approval_policy_steps
    SET step_condition_config = '{"salary":1}'::jsonb
    WHERE id = v_step_id;
    RAISE EXCEPTION 'SMOKE_FAIL: salary field should raise PULS_POLICY_STEP_CONFIG_FORBIDDEN_FIELD';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_POLICY_STEP_CONFIG_FORBIDDEN_FIELD%' THEN
        RAISE;
      END IF;
  END;

  UPDATE puls_workflow.approval_policy_steps
  SET step_resolver_config = '{}'::jsonb,
      step_condition_config = '{}'::jsonb
  WHERE id = v_step_id;

  SELECT puls_workflow.resolve_policy_step_approver(
    v_tenant_id, v_requester_id, 'leave', v_policy_id, 1
  ) INTO v_approver;

  IF v_approver IS DISTINCT FROM v_manager_id THEN
    RAISE EXCEPTION 'SMOKE_FAIL: resolver regression expected manager %, got %', v_manager_id, v_approver;
  END IF;

  BEGIN
    UPDATE puls_workflow.approval_policy_steps
    SET step_condition_config = '{"salary":1}'::jsonb,
        approver_type = 'manager'::puls_workflow.approver_type
    WHERE id = v_step_id;
    RAISE EXCEPTION 'SMOKE_FAIL: bad config must fail even on unrelated column update';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_POLICY_STEP_CONFIG_FORBIDDEN_FIELD%' THEN
        RAISE;
      END IF;
  END;

  RAISE NOTICE '10 PR10.1 policy step config smoke passed';

  PERFORM set_config('request.jwt.claim.role', '', true);
END $$;

ROLLBACK;
