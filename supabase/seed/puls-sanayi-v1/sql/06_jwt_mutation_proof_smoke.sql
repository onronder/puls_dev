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

CREATE TEMP TABLE IF NOT EXISTS pr13_psql_vars (
  key text PRIMARY KEY,
  raw_value text NOT NULL
);
TRUNCATE pr13_psql_vars;
INSERT INTO pr13_psql_vars (key, raw_value) VALUES
  ('admin_user_id', :'admin_user_id'),
  ('hr_admin_user_id', :'hr_admin_user_id'),
  ('manager_user_id', :'manager_user_id'),
  ('employee_user_id', :'employee_user_id'),
  ('incomplete_setup_user_id', :'incomplete_setup_user_id');

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
  v_lt_reserved uuid := 'a0000012-0012-4012-8012-000000000006';
  v_lt_eski uuid := 'a0000012-0012-4012-8012-000000000008';
  v_ec_yemek uuid := 'a0000015-0015-4015-8015-000000000001';
  v_ec_reserved uuid := 'a0000015-0015-4015-8015-000000000008';
  v_ec_eski uuid := 'a0000015-0015-4015-8015-000000000010';
  v_current_emp uuid;
  v_current_tenant uuid;
  v_create_result jsonb;
  v_decide_result jsonb;
  v_lifecycle_result jsonb;
  v_approval_id uuid;
  v_raw text;
BEGIN
  SELECT raw_value INTO v_raw FROM pr13_psql_vars WHERE key = 'employee_user_id';
  v_employee_user := NULLIF(NULLIF(BTRIM(COALESCE(v_raw, '')), ''), v_zero::text)::uuid;
  SELECT raw_value INTO v_raw FROM pr13_psql_vars WHERE key = 'manager_user_id';
  v_manager_user := NULLIF(NULLIF(BTRIM(COALESCE(v_raw, '')), ''), v_zero::text)::uuid;

  IF v_employee_user IS NULL AND v_manager_user IS NULL THEN
    RAISE NOTICE 'JWT smoke skipped — provide auth UUIDs via psql -v';
    RETURN;
  END IF;

  IF v_employee_user IS NOT NULL THEN
    PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
    PERFORM set_config('request.jwt.claim.sub', v_employee_user::text, true);

    SELECT puls_core.current_employee_id() INTO v_current_emp;
    SELECT puls_core.current_tenant_id() INTO v_current_tenant;

    IF v_current_emp IS DISTINCT FROM v_employee_id THEN
      RAISE EXCEPTION 'JWT smoke fail: employee current_employee_id % (expected %)',
        v_current_emp, v_employee_id;
    END IF;
    IF v_current_tenant IS DISTINCT FROM v_tenant THEN
      RAISE EXCEPTION 'JWT smoke fail: employee current_tenant_id % (expected %)',
        v_current_tenant, v_tenant;
    END IF;

    v_create_result := puls_workflow.create_leave_request(
      v_lt_yillik,
      CURRENT_DATE + 30,
      CURRENT_DATE + 32,
      FALSE,
      NULL,
      'PR13.5 JWT smoke leave'
    );
    IF COALESCE(v_create_result->>'status', '') = '' THEN
      RAISE EXCEPTION 'JWT smoke fail: create_leave_request returned empty status: %', v_create_result;
    END IF;
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
    IF COALESCE(v_create_result->>'status', '') = '' THEN
      RAISE EXCEPTION 'JWT smoke fail: create_expense_claim returned empty status: %', v_create_result;
    END IF;
    RAISE NOTICE 'create_expense_claim: %', v_create_result->>'status';

    PERFORM set_config('request.jwt.claim.role', 'service_role', true);
    PERFORM set_config('request.jwt.claim.sub', '', true);
  END IF;

  IF v_manager_user IS NOT NULL THEN
    PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
    PERFORM set_config('request.jwt.claim.sub', v_manager_user::text, true);

    SELECT puls_core.current_employee_id() INTO v_current_emp;
    IF v_current_emp IS DISTINCT FROM v_manager_id THEN
      RAISE EXCEPTION 'JWT smoke fail: manager current_employee_id % (expected %)',
        v_current_emp, v_manager_id;
    END IF;

    SELECT ar.id INTO v_approval_id
    FROM puls_workflow.approval_requests ar
    WHERE ar.tenant_id = v_tenant
      AND ar.status = 'pending'
      AND ar.approver_employee_id = v_manager_id
    ORDER BY ar.created_at DESC
    LIMIT 1;

    IF v_approval_id IS NULL THEN
      RAISE EXCEPTION 'JWT smoke fail: no pending approval for manager %', v_manager_id;
    END IF;

    v_decide_result := puls_workflow.decide_approval_request(
      v_approval_id, 'approved', 'PR13.5 smoke approved'
    );
    IF COALESCE(v_decide_result->>'status', '') NOT IN ('approved', 'step_approved') THEN
      RAISE EXCEPTION 'JWT smoke fail: decide_approval_request unexpected status: %', v_decide_result;
    END IF;
    RAISE NOTICE 'decide_approval_request approved: %', v_decide_result->>'status';

    v_lifecycle_result := puls_workflow.deactivate_leave_type(v_lt_reserved, 'PR13.5 lifecycle smoke');
    IF COALESCE(v_lifecycle_result->>'status', '') NOT IN ('deactivated', 'already_inactive') THEN
      RAISE EXCEPTION 'JWT smoke fail: deactivate_leave_type (UCRETSIZ): %', v_lifecycle_result;
    END IF;

    v_lifecycle_result := puls_workflow.restore_leave_type(v_lt_reserved);
    IF COALESCE(v_lifecycle_result->>'status', '') NOT IN ('restored', 'already_active') THEN
      RAISE EXCEPTION 'JWT smoke fail: restore_leave_type (UCRETSIZ): %', v_lifecycle_result;
    END IF;

    v_lifecycle_result := puls_workflow.deactivate_expense_category(v_ec_reserved, 'PR13.5 lifecycle smoke');
    IF COALESCE(v_lifecycle_result->>'status', '') NOT IN ('deactivated', 'already_inactive') THEN
      RAISE EXCEPTION 'JWT smoke fail: deactivate_expense_category (HED): %', v_lifecycle_result;
    END IF;

    v_lifecycle_result := puls_workflow.restore_expense_category(v_ec_reserved);
    IF COALESCE(v_lifecycle_result->>'status', '') NOT IN ('restored', 'already_active') THEN
      RAISE EXCEPTION 'JWT smoke fail: restore_expense_category (HED): %', v_lifecycle_result;
    END IF;

    v_lifecycle_result := puls_workflow.deactivate_leave_type(v_lt_eski, 'PR13.5 already inactive check');
    IF v_lifecycle_result->>'status' IS DISTINCT FROM 'already_inactive' THEN
      RAISE EXCEPTION 'JWT smoke fail: ESKI-TIP expected already_inactive, got %', v_lifecycle_result;
    END IF;

    v_lifecycle_result := puls_workflow.deactivate_expense_category(v_ec_eski, 'PR13.5 already inactive check');
    IF v_lifecycle_result->>'status' IS DISTINCT FROM 'already_inactive' THEN
      RAISE EXCEPTION 'JWT smoke fail: ESKI-KAT expected already_inactive, got %', v_lifecycle_result;
    END IF;

    PERFORM set_config('request.jwt.claim.role', 'service_role', true);
    PERFORM set_config('request.jwt.claim.sub', '', true);
  END IF;

  RAISE NOTICE 'OK: PR13.5 JWT mutation smoke completed (ROLLBACK pending)';
END $$;

ROLLBACK;
