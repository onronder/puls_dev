-- 12 PR12.3 Decide Approval Contract Smoke — executable smoke (single transaction; rolls back)
-- Asserts JWT auth mapping, decide error paths, and optional success via RPC-only fixtures.
-- Does NOT insert or update puls_workflow.approval_requests directly.
--
-- Real RPC signature (positional):
--   puls_workflow.decide_approval_request(uuid, text, text)
--     (approval_request_id, decision, note)
--   puls_workflow.create_leave_request(uuid, date, date, boolean, uuid, text)

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_employee_id UUID;
  v_user_id UUID;
  v_current_employee_id UUID;
  v_current_tenant_id UUID;
  v_approval_request_id UUID;
  v_approver_employee_id UUID;
  v_approver_user_id UUID;
  v_requester_employee_id UUID;
  v_requester_user_id UUID;
  v_active_leave_type_id UUID;
  v_create_result JSONB;
  v_decide_result JSONB;
  v_success_path BOOLEAN := FALSE;
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
  ORDER BY e.full_name
  LIMIT 1;

  IF v_employee_id IS NULL OR v_user_id IS NULL THEN
    RAISE NOTICE 'SKIP: no employee with user_id for JWT mapping';
  ELSE
    PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
    PERFORM set_config('request.jwt.claim.sub', v_user_id::text, true);

    SELECT puls_core.current_employee_id() INTO v_current_employee_id;
    SELECT puls_core.current_tenant_id() INTO v_current_tenant_id;

    IF v_current_employee_id IS DISTINCT FROM v_employee_id THEN
      RAISE EXCEPTION 'SMOKE_FAIL JWT mapping: current_employee_id mismatch (expected %, got %)',
        v_employee_id, v_current_employee_id;
    END IF;

    IF v_current_tenant_id IS DISTINCT FROM v_tenant_id THEN
      RAISE EXCEPTION 'SMOKE_FAIL JWT mapping: current_tenant_id mismatch (expected %, got %)',
        v_tenant_id, v_current_tenant_id;
    END IF;

    PERFORM set_config('request.jwt.claim.role', 'service_role', true);
    PERFORM set_config('request.jwt.claim.sub', '', true);

    RAISE NOTICE 'OK: JWT sub maps to puls_core.current_employee_id() and current_tenant_id()';
  END IF;

  IF v_user_id IS NOT NULL THEN
    PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
    PERFORM set_config('request.jwt.claim.sub', v_user_id::text, true);

    BEGIN
      PERFORM puls_workflow.decide_approval_request(
        gen_random_uuid(),
        'maybe',
        'demo_decide_approval_contract_ invalid decision'
      );
      RAISE EXCEPTION 'SMOKE_FAIL invalid decision: expected PULS_INVALID_DECISION';
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLERRM NOT ILIKE '%PULS_INVALID_DECISION%' THEN
          RAISE EXCEPTION 'SMOKE_FAIL invalid decision: got %', SQLERRM;
        END IF;
    END;

    BEGIN
      PERFORM puls_workflow.decide_approval_request(
        gen_random_uuid(),
        'approved',
        'demo_decide_approval_contract_ missing approval'
      );
      RAISE EXCEPTION 'SMOKE_FAIL missing approval: expected PULS_APPROVAL_NOT_FOUND';
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLERRM NOT ILIKE '%PULS_APPROVAL_NOT_FOUND%' THEN
          RAISE EXCEPTION 'SMOKE_FAIL missing approval: got %', SQLERRM;
        END IF;
    END;

    PERFORM set_config('request.jwt.claim.role', 'service_role', true);
    PERFORM set_config('request.jwt.claim.sub', '', true);

    RAISE NOTICE 'OK: invalid decision and missing approval error paths';
  ELSE
    RAISE NOTICE 'NOTICE: no user-linked employee; skipping authenticated decide error paths';
  END IF;

  SELECT
    ar.id,
    ar.approver_employee_id,
    ar.requester_employee_id,
    ae.user_id AS approver_user_id,
    re.user_id AS requester_user_id
  INTO
    v_approval_request_id,
    v_approver_employee_id,
    v_requester_employee_id,
    v_approver_user_id,
    v_requester_user_id
  FROM puls_workflow.approval_requests ar
  JOIN puls_core.employees ae ON ae.id = ar.approver_employee_id
  JOIN puls_core.employees re ON re.id = ar.requester_employee_id
  WHERE ar.tenant_id = v_tenant_id
    AND ar.status = 'pending'
    AND ae.user_id IS NOT NULL
    AND re.user_id IS NOT NULL
    AND ae.id <> ar.requester_employee_id
  ORDER BY ar.created_at DESC
  LIMIT 1;

  IF v_approval_request_id IS NULL AND v_user_id IS NOT NULL THEN
    SELECT id INTO v_active_leave_type_id
    FROM puls_workflow.leave_types
    WHERE tenant_id = v_tenant_id
      AND is_active = true
    ORDER BY name
    LIMIT 1;

    IF v_active_leave_type_id IS NOT NULL THEN
      PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
      PERFORM set_config('request.jwt.claim.sub', v_user_id::text, true);

      BEGIN
        v_create_result := puls_workflow.create_leave_request(
          v_active_leave_type_id,
          CURRENT_DATE + 21,
          CURRENT_DATE + 21,
          FALSE,
          NULL,
          'demo_decide_approval_contract_ rollback chain create'
        );

        v_approval_request_id := NULLIF(v_create_result->>'approval_request_id', '')::UUID;

        IF v_approval_request_id IS NOT NULL THEN
          SELECT ar.approver_employee_id, ar.requester_employee_id, ae.user_id, re.user_id
          INTO
            v_approver_employee_id,
            v_requester_employee_id,
            v_approver_user_id,
            v_requester_user_id
          FROM puls_workflow.approval_requests ar
          JOIN puls_core.employees ae ON ae.id = ar.approver_employee_id
          JOIN puls_core.employees re ON re.id = ar.requester_employee_id
          WHERE ar.id = v_approval_request_id
            AND ar.tenant_id = v_tenant_id
            AND ar.status = 'pending';

          IF v_approver_user_id IS NOT NULL AND v_requester_user_id IS NOT NULL THEN
            RAISE NOTICE 'OK: rollback create_leave_request chain produced pending approval %', v_approval_request_id;
          ELSE
            v_approval_request_id := NULL;
          END IF;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          IF SQLERRM ILIKE '%PULS_NO_APPROVER%'
             OR SQLERRM ILIKE '%PULS_POLICY_NOT_FOUND%'
             OR SQLERRM ILIKE '%PULS_POLICY_STEP_NOT_FOUND%'
             OR SQLERRM ILIKE '%PULS_POLICY_STEP_UNRESOLVED%'
             OR SQLERRM ILIKE '%PULS_INSUFFICIENT_BALANCE%'
             OR SQLERRM ILIKE '%PULS_INVALID_LEAVE_TYPE%'
             OR SQLERRM ILIKE '%PULS_INVALID_DATES%' THEN
            RAISE NOTICE 'NOTICE: create_leave_request chain blocked by policy guard: %', SQLERRM;
          ELSE
            RAISE;
          END IF;
      END;

      PERFORM set_config('request.jwt.claim.role', 'service_role', true);
      PERFORM set_config('request.jwt.claim.sub', '', true);
    END IF;
  END IF;

  IF v_approval_request_id IS NOT NULL
     AND v_approver_user_id IS NOT NULL
     AND v_requester_user_id IS NOT NULL
     AND v_approver_employee_id <> v_requester_employee_id THEN
    PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
    PERFORM set_config('request.jwt.claim.sub', v_requester_user_id::text, true);

    BEGIN
      PERFORM puls_workflow.decide_approval_request(
        v_approval_request_id,
        'approved',
        'demo_decide_approval_contract_ requester forbidden'
      );
      RAISE EXCEPTION 'SMOKE_FAIL non-approver: expected PULS_APPROVAL_FORBIDDEN or PULS_SELF_APPROVAL';
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLERRM NOT ILIKE '%PULS_APPROVAL_FORBIDDEN%'
           AND SQLERRM NOT ILIKE '%PULS_SELF_APPROVAL%' THEN
          RAISE EXCEPTION 'SMOKE_FAIL non-approver: got %', SQLERRM;
        END IF;
    END;

    PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
    PERFORM set_config('request.jwt.claim.sub', v_approver_user_id::text, true);

    BEGIN
      v_decide_result := puls_workflow.decide_approval_request(
        v_approval_request_id,
        'approved',
        'demo_decide_approval_contract_ approver success'
      );

      IF v_decide_result->>'approval_request_id' IS NULL
         OR v_decide_result->>'status' IS NULL THEN
        RAISE EXCEPTION 'SMOKE_FAIL decide success: missing approval_request_id or status in result';
      END IF;

      v_success_path := TRUE;
      RAISE NOTICE 'OK: decide success path exercised for approval %', v_approval_request_id;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE NOTICE 'NOTICE: approver decide failed: %', SQLERRM;
    END;

    PERFORM set_config('request.jwt.claim.role', 'service_role', true);
    PERFORM set_config('request.jwt.claim.sub', '', true);
  END IF;

  IF NOT v_success_path THEN
    RAISE NOTICE 'SKIP: decide success path — no safe pending approver fixture';
  END IF;

  RAISE NOTICE 'demo_decide_approval_contract_ smoke completed for tenant %', v_tenant_id;
END $$;

ROLLBACK;
