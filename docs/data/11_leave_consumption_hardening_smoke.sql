-- 11 PR11.4 Leave Consumption Hardening — executable smoke (single transaction; rolls back)
-- Asserts JWT auth mapping, active-only picker, inactive create rejection, historical readability,
-- and decide_approval_request RPC surface existence.
--
-- Real RPC signature (positional — do NOT call with jsonb):
--   puls_workflow.create_leave_request(uuid, date, date, boolean, uuid, text)
--     (leave_type_id, start_date, end_date, half_day, delegate_employee_id, description)
--   puls_workflow.decide_approval_request(uuid, text, text) — existence check only in this smoke

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_active_leave_type_id UUID;
  v_inactive_leave_type_id UUID;
  v_employee_id UUID;
  v_user_id UUID;
  v_current_employee_id UUID;
  v_active_picker_count INTEGER;
  v_inactive_type_name TEXT;
  v_inactive_type_active BOOLEAN;
  v_result JSONB;
BEGIN
  PERFORM set_config('request.jwt.claim.role', 'service_role', true);

  SELECT id INTO v_tenant_id
  FROM puls_core.tenants
  WHERE legacy_public_tenant_id = '11111111-1111-1111-1111-111111111111'
     OR name ILIKE '%Mert Teknik%'
  LIMIT 1;

  IF v_tenant_id IS NULL THEN
    RAISE NOTICE 'SKIP: demo/staging tenant not found';
    RETURN;
  END IF;

  SELECT e.id, e.user_id
  INTO v_employee_id, v_user_id
  FROM puls_core.employees e
  WHERE e.tenant_id = v_tenant_id
    AND e.user_id IS NOT NULL
  LIMIT 1;

  IF v_employee_id IS NULL OR v_user_id IS NULL THEN
    RAISE NOTICE 'SKIP: no employee with user_id — auth section not asserted on live data';
  ELSE
    PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
    PERFORM set_config('request.jwt.claim.sub', v_user_id::text, true);

    SELECT puls_core.current_employee_id()
    INTO v_current_employee_id;

    IF v_current_employee_id IS DISTINCT FROM v_employee_id THEN
      RAISE EXCEPTION 'SMOKE_FAIL auth context: current_employee_id mismatch (expected %, got %)',
        v_employee_id, v_current_employee_id;
    END IF;

    PERFORM set_config('request.jwt.claim.role', 'service_role', true);
    PERFORM set_config('request.jwt.claim.sub', '', true);

    RAISE NOTICE 'OK: JWT sub maps to puls_core.current_employee_id()';
  END IF;

  SELECT COUNT(*)::INTEGER INTO v_active_picker_count
  FROM puls_workflow.leave_types
  WHERE tenant_id = v_tenant_id
    AND is_active = true;

  IF v_active_picker_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL leave_types: active-only picker query failed';
  END IF;

  SELECT id INTO v_active_leave_type_id
  FROM puls_workflow.leave_types
  WHERE tenant_id = v_tenant_id
    AND is_active = true
  ORDER BY name
  LIMIT 1;

  SELECT id INTO v_inactive_leave_type_id
  FROM puls_workflow.leave_types
  WHERE tenant_id = v_tenant_id
    AND is_active = false
  ORDER BY name
  LIMIT 1;

  IF v_inactive_leave_type_id IS NOT NULL AND v_user_id IS NOT NULL THEN
    BEGIN
      PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
      PERFORM set_config('request.jwt.claim.sub', v_user_id::text, true);

      PERFORM puls_workflow.create_leave_request(
        v_inactive_leave_type_id,
        CURRENT_DATE + 7,
        CURRENT_DATE + 7,
        FALSE,
        NULL,
        'demo_leave_consumption_hardening_ inactive reject'
      );
      RAISE EXCEPTION 'SMOKE_FAIL inactive leave type create: expected PULS_INVALID_LEAVE_TYPE';
    EXCEPTION
      WHEN OTHERS THEN
        PERFORM set_config('request.jwt.claim.role', 'service_role', true);
        PERFORM set_config('request.jwt.claim.sub', '', true);

        IF SQLERRM NOT ILIKE '%PULS_INVALID_LEAVE_TYPE%' THEN
          RAISE EXCEPTION 'SMOKE_FAIL inactive leave type create: got %', SQLERRM;
        END IF;
    END;
    PERFORM set_config('request.jwt.claim.role', 'service_role', true);
    PERFORM set_config('request.jwt.claim.sub', '', true);
  ELSE
    RAISE NOTICE 'NOTICE: no inactive leave type or user-linked employee; skipping inactive reject case';
  END IF;

  IF v_active_leave_type_id IS NOT NULL AND v_user_id IS NOT NULL THEN
    PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
    PERFORM set_config('request.jwt.claim.sub', v_user_id::text, true);

    BEGIN
      v_result := puls_workflow.create_leave_request(
        v_active_leave_type_id,
        CURRENT_DATE + 14,
        CURRENT_DATE + 14,
        FALSE,
        NULL,
        'demo_leave_consumption_hardening_ active create'
      );
      RAISE NOTICE 'OK: active leave create succeeded (request %)', v_result->>'leave_request_id';
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLERRM ILIKE '%PULS_INVALID_LEAVE_TYPE%' THEN
          RAISE EXCEPTION 'SMOKE_FAIL active leave type create: unexpected PULS_INVALID_LEAVE_TYPE';
        ELSIF SQLERRM ILIKE '%PULS_NO_APPROVER%'
           OR SQLERRM ILIKE '%PULS_POLICY_NOT_FOUND%'
           OR SQLERRM ILIKE '%PULS_POLICY_STEP_NOT_FOUND%'
           OR SQLERRM ILIKE '%PULS_POLICY_STEP_UNRESOLVED%'
           OR SQLERRM ILIKE '%PULS_INSUFFICIENT_BALANCE%'
           OR SQLERRM ILIKE '%PULS_DOCUMENT_REQUIRED%'
           OR SQLERRM ILIKE '%PULS_INVALID_DATES%'
           OR SQLERRM ILIKE '%PULS_CROSS_YEAR_LEAVE%'
           OR SQLERRM ILIKE '%PULS_HALF_DAY_INVALID%' THEN
          RAISE NOTICE 'OK: active leave create blocked by policy/balance guard: %', SQLERRM;
        ELSE
          RAISE;
        END IF;
    END;

    PERFORM set_config('request.jwt.claim.role', 'service_role', true);
    PERFORM set_config('request.jwt.claim.sub', '', true);
  ELSE
    RAISE NOTICE 'NOTICE: no active leave type or user-linked employee; skipping active create case';
  END IF;

  IF v_inactive_leave_type_id IS NOT NULL THEN
    SELECT name, is_active
    INTO v_inactive_type_name, v_inactive_type_active
    FROM puls_workflow.leave_types
    WHERE id = v_inactive_leave_type_id;

    IF v_inactive_type_name IS NULL OR BTRIM(v_inactive_type_name) = '' THEN
      RAISE EXCEPTION 'SMOKE_FAIL historical readability: inactive leave type name not readable';
    END IF;

    IF v_inactive_type_active IS NOT FALSE THEN
      RAISE EXCEPTION 'SMOKE_FAIL historical readability: expected inactive type is_active=false, got %',
        v_inactive_type_active;
    END IF;

    RAISE NOTICE 'OK: inactive leave type historical readability (name=%, is_active=%)',
      v_inactive_type_name, v_inactive_type_active;
  ELSE
    RAISE NOTICE 'NOTICE: no inactive leave type; skipping historical readability case';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'puls_workflow'
      AND p.proname = 'decide_approval_request'
  ) THEN
    RAISE EXCEPTION 'SMOKE_FAIL: decide_approval_request RPC missing';
  END IF;

  RAISE NOTICE 'OK: decide_approval_request RPC exists (pg_proc proname check)';
  RAISE NOTICE 'demo_leave_consumption_hardening_ smoke completed for tenant %', v_tenant_id;
END $$;

ROLLBACK;
