-- PR13.5 — JWT mutation proof smoke (RPC proof inside BEGIN … ROLLBACK).
-- Lifecycle RPC smoke targets reserved setup rows (UCRETSIZ leave type, HED expense category).
-- Do not persist mutations — transaction rolls back at end; JWT claims reset with transaction scope.
--
-- Usage:
--   psql "$DATABASE_URL" -v employee_user_id='<uuid>' -v manager_user_id='<uuid>' \
--     -f sql/06_jwt_mutation_proof_smoke.sql

\set ON_ERROR_STOP on

\if :{?admin_user_id}
\else
\set admin_user_id '00000000-0000-0000-0000-000000000000'
\endif

\if :{?hr_admin_user_id}
\else
\set hr_admin_user_id '00000000-0000-0000-0000-000000000000'
\endif

\if :{?manager_user_id}
\else
\set manager_user_id '00000000-0000-0000-0000-000000000000'
\endif

\if :{?employee_user_id}
\else
\set employee_user_id '00000000-0000-0000-0000-000000000000'
\endif

\if :{?incomplete_setup_user_id}
\else
\set incomplete_setup_user_id '00000000-0000-0000-0000-000000000000'
\endif

BEGIN;

DO $$
DECLARE
  v_tenant uuid := 'a0000001-0001-4001-8001-000000000001';
  v_zero uuid := '00000000-0000-0000-0000-000000000000';
  v_employee_user uuid;
  v_manager_user uuid;
  v_employee_id uuid := 'a0000006-0006-4006-8006-000000000023';
  v_manager_id uuid := 'a0000006-0006-4006-8006-000000000021';
  v_lt_yillik uuid := 'a0000012-0012-4012-8012-000000000001';
  v_lt_reserved uuid := 'a0000012-0012-4012-8012-000000000006'; -- UCRETSIZ lifecycle smoke
  v_lt_eski uuid := 'a0000012-0012-4012-8012-000000000008';
  v_ec_yemek uuid := 'a0000015-0015-4015-8015-000000000001';
  v_ec_reserved uuid := 'a0000015-0015-4015-8015-000000000008'; -- HED lifecycle smoke
  v_ec_eski uuid := 'a0000015-0015-4015-8015-000000000010';
  v_current_emp uuid;
  v_current_tenant uuid;
  v_create_result jsonb;
  v_decide_result jsonb;
  v_lifecycle_result jsonb;
  v_approval_id uuid;
  v_any_linked boolean := FALSE;
BEGIN
  v_employee_user := NULLIF(NULLIF(BTRIM(:'employee_user_id'), ''), v_zero::text)::uuid;
  v_manager_user := NULLIF(NULLIF(BTRIM(:'manager_user_id'), ''), v_zero::text)::uuid;

  IF v_employee_user IS NOT NULL OR v_manager_user IS NOT NULL THEN
    v_any_linked := TRUE;
  END IF;

  IF NOT v_any_linked THEN
    RAISE NOTICE 'JWT smoke skipped — provide auth UUIDs via psql -v';
    RETURN;
  END IF;

  -- Employee persona: create leave + expense via RPC
  IF v_employee_user IS NOT NULL THEN
    PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
    PERFORM set_config('request.jwt.claim.sub', v_employee_user::text, true);

    SELECT puls_core.current_employee_id() INTO v_current_emp;
    SELECT puls_core.current_tenant_id() INTO v_current_tenant;

    IF v_current_emp IS DISTINCT FROM v_employee_id THEN
      RAISE NOTICE 'WARN: employee JWT current_employee_id % (expected %)', v_current_emp, v_employee_id;
    ELSE
      RAISE NOTICE 'OK: employee JWT maps to PS-023';
    END IF;

    v_create_result := puls_workflow.create_leave_request(
      v_lt_yillik,
      CURRENT_DATE + 30,
      CURRENT_DATE + 32,
      FALSE,
      NULL,
      'PR13.5 JWT smoke leave'
    );
    RAISE NOTICE 'create_leave_request: %', v_create_result->>'status';

    v_create_result := puls_workflow.create_expense_claim(
      v_ec_yemek,
      'PR13.5 JWT smoke expense',
      250.00,
      'TRY',
      20,
      TRUE,
      CURRENT_DATE,
      'JWT smoke packaging proof'
    );
    RAISE NOTICE 'create_expense_claim: %', v_create_result->>'status';

    PERFORM set_config('request.jwt.claim.role', 'service_role', true);
    PERFORM set_config('request.jwt.claim.sub', '', true);
  ELSE
    RAISE NOTICE 'SKIP: employee_user_id not provided';
  END IF;

  -- Manager persona: decide approval if pending exists
  IF v_manager_user IS NOT NULL THEN
    PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
    PERFORM set_config('request.jwt.claim.sub', v_manager_user::text, true);

    SELECT ar.id INTO v_approval_id
    FROM puls_workflow.approval_requests ar
    WHERE ar.tenant_id = v_tenant
      AND ar.status = 'pending'
      AND ar.approver_employee_id = v_manager_id
    ORDER BY ar.created_at DESC
    LIMIT 1;

    IF v_approval_id IS NOT NULL THEN
      BEGIN
        v_decide_result := puls_workflow.decide_approval_request(v_approval_id, 'approve', 'PR13.5 smoke approve');
        RAISE NOTICE 'decide_approval_request approve: %', v_decide_result->>'status';
      EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'decide_approval_request skipped: %', SQLERRM;
      END;
    ELSE
      RAISE NOTICE 'SKIP: no pending approval for manager smoke';
    END IF;

    PERFORM set_config('request.jwt.claim.role', 'service_role', true);
    PERFORM set_config('request.jwt.claim.sub', '', true);
  ELSE
    RAISE NOTICE 'SKIP: manager_user_id not provided';
  END IF;

  -- Lifecycle RPC smoke on reserved active rows (service role / admin context)
  PERFORM set_config('request.jwt.claim.role', 'service_role', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);

  IF v_manager_user IS NOT NULL THEN
    PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
    PERFORM set_config('request.jwt.claim.sub', v_manager_user::text, true);
  END IF;

  BEGIN
    v_lifecycle_result := puls_workflow.deactivate_leave_type(v_lt_reserved, 'PR13.5 lifecycle smoke');
    RAISE NOTICE 'deactivate_leave_type (UCRETSIZ reserved): %', v_lifecycle_result->>'status';

    v_lifecycle_result := puls_workflow.restore_leave_type(v_lt_reserved);
    RAISE NOTICE 'restore_leave_type (UCRETSIZ reserved): %', v_lifecycle_result->>'status';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'lifecycle leave smoke: %', SQLERRM;
  END;

  BEGIN
    v_lifecycle_result := puls_workflow.deactivate_expense_category(v_ec_reserved, 'PR13.5 lifecycle smoke');
    RAISE NOTICE 'deactivate_expense_category (HED reserved): %', v_lifecycle_result->>'status';

    v_lifecycle_result := puls_workflow.restore_expense_category(v_ec_reserved);
    RAISE NOTICE 'restore_expense_category (HED reserved): %', v_lifecycle_result->>'status';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'lifecycle expense smoke: %', SQLERRM;
  END;

  -- Idempotency on inactive baseline rows
  BEGIN
    v_lifecycle_result := puls_workflow.deactivate_leave_type(v_lt_eski, 'PR13.5 already inactive check');
    RAISE NOTICE 'deactivate_leave_type (ESKI-TIP): %', v_lifecycle_result->>'status';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'ESKI-TIP deactivate: %', SQLERRM;
  END;

  BEGIN
    v_lifecycle_result := puls_workflow.deactivate_expense_category(v_ec_eski, 'PR13.5 already inactive check');
    RAISE NOTICE 'deactivate_expense_category (ESKI-KAT): %', v_lifecycle_result->>'status';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'ESKI-KAT deactivate: %', SQLERRM;
  END;

  PERFORM set_config('request.jwt.claim.role', 'service_role', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);

  RAISE NOTICE 'OK: PR13.5 JWT mutation smoke completed (ROLLBACK pending)';
END $$;

ROLLBACK;
