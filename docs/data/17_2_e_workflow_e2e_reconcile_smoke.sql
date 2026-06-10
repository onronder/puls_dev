-- PR17.2E — Workflow E2E baseline and reconcile contract smoke.
--
-- Runs inside BEGIN ... ROLLBACK so no workflow, notification, read-state, or
-- audit row is persisted. This smoke proves the current leave/expense workflow
-- boundary after PR17.2D:
--   1. browser-equivalent authenticated workflow RPCs create real requests,
--   2. workflow triggers emit approval/requester notifications before any
--      service-role producer/reconcile call,
--   3. the service-role producer remains a duplicate-safe reconcile/backfill
--      path because it uses the same deterministic dedupe keys, and
--   4. workflow audit evidence exists in the same rollback-only transaction.
--
-- Usage:
--   psql "$DATABASE_URL" \
--     -v tenant_id='<optional tenant uuid>' \
--     -v requester_user_id='<optional employee auth uuid>' \
--     -v admin_user_id='<optional admin auth uuid>' \
--     -f docs/data/17_2_e_workflow_e2e_reconcile_smoke.sql

\set ON_ERROR_STOP on

\if :{?tenant_id}
\else
\set tenant_id '00000000-0000-0000-0000-000000000000'
\endif

\if :{?requester_user_id}
\else
\set requester_user_id '00000000-0000-0000-0000-000000000000'
\endif

\if :{?admin_user_id}
\else
\set admin_user_id '00000000-0000-0000-0000-000000000000'
\endif

CREATE TEMP TABLE IF NOT EXISTS pr17_2e_psql_vars (
  key TEXT PRIMARY KEY,
  raw_value TEXT NOT NULL
);

TRUNCATE pr17_2e_psql_vars;

INSERT INTO pr17_2e_psql_vars (key, raw_value) VALUES
  ('tenant_id', :'tenant_id'),
  ('requester_user_id', :'requester_user_id'),
  ('admin_user_id', :'admin_user_id');

BEGIN;

DO $$
DECLARE
  v_zero UUID := '00000000-0000-0000-0000-000000000000';
  v_raw TEXT;
  v_requested_tenant_id UUID;
  v_requested_requester_user_id UUID;
  v_requested_admin_user_id UUID;
  v_tenant_id UUID;
  v_requester_employee_id UUID;
  v_requester_user_id UUID;
  v_admin_user_id UUID;
  v_leave_type_id UUID;
  v_expense_category_id UUID;
  v_leave_result JSONB;
  v_expense_result JSONB;
  v_decide_result JSONB;
  v_leave_request_id UUID;
  v_expense_claim_id UUID;
  v_leave_approval_id UUID;
  v_expense_approval_id UUID;
  v_current_approval_id UUID;
  v_current_approver_employee_id UUID;
  v_current_approver_user_id UUID;
  v_decision_user_id UUID;
  v_loop_guard INTEGER := 0;
  v_multi_step_seen BOOLEAN := FALSE;
  v_leave_approval_dedupe TEXT;
  v_expense_approval_dedupe TEXT;
  v_leave_decision_dedupe TEXT;
  v_expense_decision_dedupe TEXT;
  v_count_before INTEGER;
  v_count_after INTEGER;
  v_reconcile_seen INTEGER;
  v_reconcile_inserted INTEGER;
BEGIN
  SELECT raw_value INTO v_raw FROM pr17_2e_psql_vars WHERE key = 'tenant_id';
  v_requested_tenant_id := NULLIF(NULLIF(BTRIM(COALESCE(v_raw, '')), ''), v_zero::TEXT)::UUID;

  SELECT raw_value INTO v_raw FROM pr17_2e_psql_vars WHERE key = 'requester_user_id';
  v_requested_requester_user_id := NULLIF(NULLIF(BTRIM(COALESCE(v_raw, '')), ''), v_zero::TEXT)::UUID;

  SELECT raw_value INTO v_raw FROM pr17_2e_psql_vars WHERE key = 'admin_user_id';
  v_requested_admin_user_id := NULLIF(NULLIF(BTRIM(COALESCE(v_raw, '')), ''), v_zero::TEXT)::UUID;

  SELECT
    e.tenant_id,
    e.id,
    e.user_id
  INTO
    v_tenant_id,
    v_requester_employee_id,
    v_requester_user_id
  FROM puls_core.employees e
  WHERE e.user_id IS NOT NULL
    AND e.employment_status = 'active'::puls_core.employment_status
    AND (v_requested_tenant_id IS NULL OR e.tenant_id = v_requested_tenant_id)
    AND (v_requested_requester_user_id IS NULL OR e.user_id = v_requested_requester_user_id)
    AND EXISTS (
      SELECT 1
      FROM puls_workflow.leave_types lt
      WHERE lt.tenant_id = e.tenant_id
        AND lt.is_active = TRUE
        AND COALESCE(lt.requires_document, FALSE) = FALSE
    )
    AND EXISTS (
      SELECT 1
      FROM puls_workflow.expense_categories ec
      WHERE ec.tenant_id = e.tenant_id
        AND ec.is_active = TRUE
        AND COALESCE(ec.receipt_required_over, 999999) > 100
    )
  ORDER BY e.persona_role::TEXT = 'employee' DESC, e.employee_code NULLS LAST, e.id
  LIMIT 1;

  IF v_requester_employee_id IS NULL OR v_requester_user_id IS NULL OR v_tenant_id IS NULL THEN
    RAISE NOTICE 'PR17.2E smoke skipped — no linked active requester employee with leave and expense setup was found.';
    RETURN;
  END IF;

  IF v_requested_admin_user_id IS NOT NULL THEN
    v_admin_user_id := v_requested_admin_user_id;
  ELSE
    SELECT e.user_id
    INTO v_admin_user_id
    FROM puls_core.employees e
    WHERE e.tenant_id = v_tenant_id
      AND e.user_id IS NOT NULL
      AND e.employment_status = 'active'::puls_core.employment_status
      AND e.persona_role IN ('hr_admin'::puls_core.persona_role, 'superadmin'::puls_core.persona_role)
    ORDER BY e.persona_role::TEXT = 'superadmin' DESC, e.employee_code NULLS LAST, e.id
    LIMIT 1;
  END IF;

  SELECT lt.id
  INTO v_leave_type_id
  FROM puls_workflow.leave_types lt
  WHERE lt.tenant_id = v_tenant_id
    AND lt.is_active = TRUE
    AND COALESCE(lt.requires_document, FALSE) = FALSE
  ORDER BY lt.is_paid ASC, lt.code, lt.id
  LIMIT 1;

  SELECT ec.id
  INTO v_expense_category_id
  FROM puls_workflow.expense_categories ec
  WHERE ec.tenant_id = v_tenant_id
    AND ec.is_active = TRUE
    AND COALESCE(ec.receipt_required_over, 999999) > 100
  ORDER BY ec.monthly_limit DESC NULLS LAST, ec.code, ec.id
  LIMIT 1;

  IF v_leave_type_id IS NULL OR v_expense_category_id IS NULL THEN
    RAISE EXCEPTION 'PR17_2E_SMOKE_FAIL: missing active leave type or expense category for tenant %', v_tenant_id;
  END IF;

  PERFORM set_config('request.jwt.claim.role', 'authenticated', TRUE);
  PERFORM set_config('request.jwt.claim.sub', v_requester_user_id::TEXT, TRUE);

  IF puls_core.current_employee_id() IS DISTINCT FROM v_requester_employee_id THEN
    RAISE EXCEPTION 'PR17_2E_SMOKE_FAIL: requester JWT resolved to %, expected %',
      puls_core.current_employee_id(), v_requester_employee_id;
  END IF;

  v_leave_result := puls_workflow.create_leave_request(
    v_leave_type_id,
    CURRENT_DATE + 30,
    CURRENT_DATE + 30,
    TRUE,
    NULL,
    'PR17.2E rollback-only leave e2e smoke'
  );

  v_leave_request_id := NULLIF(v_leave_result ->> 'leave_request_id', '')::UUID;
  v_leave_approval_id := NULLIF(v_leave_result ->> 'approval_request_id', '')::UUID;

  IF v_leave_request_id IS NULL OR v_leave_approval_id IS NULL THEN
    RAISE EXCEPTION 'PR17_2E_SMOKE_FAIL: create_leave_request did not return ids: %', v_leave_result;
  END IF;

  v_expense_result := puls_workflow.create_expense_claim(
    v_expense_category_id,
    'PR17.2E rollback-only expense e2e smoke',
    100.00,
    'TRY',
    20,
    TRUE,
    CURRENT_DATE,
    'PR17.2E rollback-only expense e2e smoke'
  );

  v_expense_claim_id := NULLIF(v_expense_result ->> 'expense_claim_id', '')::UUID;
  v_expense_approval_id := NULLIF(v_expense_result ->> 'approval_request_id', '')::UUID;

  IF v_expense_claim_id IS NULL OR v_expense_approval_id IS NULL THEN
    RAISE EXCEPTION 'PR17_2E_SMOKE_FAIL: create_expense_claim did not return ids: %', v_expense_result;
  END IF;

  SELECT concat_ws(':', 'pr17.2a', 'leave_approval_requested', ar.id::TEXT, ar.approver_employee_id::TEXT)
  INTO v_leave_approval_dedupe
  FROM puls_workflow.approval_requests ar
  WHERE ar.id = v_leave_approval_id;

  SELECT concat_ws(':', 'pr17.2a', 'expense_approval_requested', ar.id::TEXT, ar.approver_employee_id::TEXT)
  INTO v_expense_approval_dedupe
  FROM puls_workflow.approval_requests ar
  WHERE ar.id = v_expense_approval_id;

  SELECT COUNT(*)
  INTO v_count_before
  FROM puls_app.app_notifications n
  WHERE n.tenant_id = v_tenant_id
    AND n.dedupe_key IN (v_leave_approval_dedupe, v_expense_approval_dedupe)
    AND n.safe_summary ->> 'workflow_notification_dispatch' = 'true'
    AND n.safe_summary ->> 'connector_independent_delivery' = 'true';

  IF v_count_before <> 2 THEN
    RAISE EXCEPTION
      'PR17_2E_SMOKE_FAIL: expected 2 live trigger approval notifications before producer reconcile, got %',
      v_count_before;
  END IF;

  PERFORM set_config('request.jwt.claim.role', 'service_role', TRUE);
  PERFORM set_config('request.jwt.claim.sub', '', TRUE);

  SELECT
    COUNT(*),
    COUNT(*) FILTER (WHERE produced.inserted)
  INTO
    v_reconcile_seen,
    v_reconcile_inserted
  FROM puls_app.run_app_notification_producers(500, v_tenant_id) produced
  WHERE produced.producer_key = 'workflow'
    AND produced.dedupe_key IN (v_leave_approval_dedupe, v_expense_approval_dedupe);

  IF v_reconcile_seen < 2 OR v_reconcile_inserted <> 0 THEN
    RAISE EXCEPTION
      'PR17_2E_SMOKE_FAIL: approval reconcile should see existing rows and insert none, seen %, inserted %',
      v_reconcile_seen,
      v_reconcile_inserted;
  END IF;

  SELECT COUNT(*)
  INTO v_count_after
  FROM puls_app.app_notifications n
  WHERE n.tenant_id = v_tenant_id
    AND n.dedupe_key IN (v_leave_approval_dedupe, v_expense_approval_dedupe);

  IF v_count_after <> 2 THEN
    RAISE EXCEPTION
      'PR17_2E_SMOKE_FAIL: approval reconcile changed notification cardinality from 2 to %',
      v_count_after;
  END IF;

  v_current_approval_id := v_leave_approval_id;

  LOOP
    v_loop_guard := v_loop_guard + 1;
    IF v_loop_guard > 5 THEN
      RAISE EXCEPTION 'PR17_2E_SMOKE_FAIL: leave approval chain exceeded 5 steps';
    END IF;

    v_current_approver_employee_id := NULL;
    v_current_approver_user_id := NULL;

    SELECT ar.approver_employee_id, approver.user_id
    INTO v_current_approver_employee_id, v_current_approver_user_id
    FROM puls_workflow.approval_requests ar
    JOIN puls_core.employees approver
      ON approver.id = ar.approver_employee_id
     AND approver.tenant_id = ar.tenant_id
    WHERE ar.id = v_current_approval_id
      AND ar.tenant_id = v_tenant_id
      AND ar.status = 'pending'::puls_workflow.approval_status;

    IF v_current_approver_employee_id IS NULL THEN
      RAISE EXCEPTION 'PR17_2E_SMOKE_FAIL: pending leave approval % was not found', v_current_approval_id;
    END IF;

    v_decision_user_id := COALESCE(v_current_approver_user_id, v_admin_user_id);

    IF v_decision_user_id IS NULL THEN
      RAISE EXCEPTION 'PR17_2E_SMOKE_FAIL: approval % has no linked approver user and no admin fallback', v_current_approval_id;
    END IF;

    PERFORM set_config('request.jwt.claim.role', 'authenticated', TRUE);
    PERFORM set_config('request.jwt.claim.sub', v_decision_user_id::TEXT, TRUE);

    v_decide_result := puls_workflow.decide_approval_request(
      v_current_approval_id,
      'approved',
      'PR17.2E rollback-only leave approval'
    );

    IF COALESCE((v_decide_result ->> 'final')::BOOLEAN, FALSE) = TRUE
       OR COALESCE(v_decide_result ->> 'status', '') = 'approved' THEN
      EXIT;
    END IF;

    v_current_approval_id := NULLIF(v_decide_result ->> 'next_approval_request_id', '')::UUID;
    IF v_current_approval_id IS NULL THEN
      RAISE EXCEPTION 'PR17_2E_SMOKE_FAIL: leave approval did not finish or return next approval: %', v_decide_result;
    END IF;

    v_multi_step_seen := TRUE;

    IF NOT EXISTS (
      SELECT 1
      FROM puls_app.app_notifications n
      JOIN puls_workflow.approval_requests ar
        ON ar.id = v_current_approval_id
       AND ar.tenant_id = n.tenant_id
      WHERE n.tenant_id = v_tenant_id
        AND n.source_domain = 'puls_workflow'
        AND n.source_event_key = 'leave_approval_requested'
        AND n.source_table = 'puls_workflow.approval_requests'
        AND n.source_id = v_current_approval_id
        AND n.target_employee_ids @> ARRAY[ar.approver_employee_id]::UUID[]
        AND n.safe_summary ->> 'workflow_notification_dispatch' = 'true'
    ) THEN
      RAISE EXCEPTION 'PR17_2E_SMOKE_FAIL: missing live trigger notification for next leave approval %', v_current_approval_id;
    END IF;
  END LOOP;

  v_current_approver_employee_id := NULL;
  v_current_approver_user_id := NULL;

  SELECT ar.approver_employee_id, approver.user_id
  INTO v_current_approver_employee_id, v_current_approver_user_id
  FROM puls_workflow.approval_requests ar
  JOIN puls_core.employees approver
    ON approver.id = ar.approver_employee_id
   AND approver.tenant_id = ar.tenant_id
  WHERE ar.id = v_expense_approval_id
    AND ar.tenant_id = v_tenant_id
    AND ar.status = 'pending'::puls_workflow.approval_status;

  IF v_current_approver_employee_id IS NULL THEN
    RAISE EXCEPTION 'PR17_2E_SMOKE_FAIL: pending expense approval % was not found', v_expense_approval_id;
  END IF;

  v_decision_user_id := COALESCE(v_current_approver_user_id, v_admin_user_id);

  IF v_decision_user_id IS NULL THEN
    RAISE EXCEPTION 'PR17_2E_SMOKE_FAIL: expense approval has no linked approver user and no admin fallback';
  END IF;

  PERFORM set_config('request.jwt.claim.role', 'authenticated', TRUE);
  PERFORM set_config('request.jwt.claim.sub', v_decision_user_id::TEXT, TRUE);

  v_decide_result := puls_workflow.decide_approval_request(
    v_expense_approval_id,
    'rejected',
    'PR17.2E rollback-only expense rejection'
  );

  IF COALESCE((v_decide_result ->> 'final')::BOOLEAN, FALSE) IS DISTINCT FROM TRUE
     OR COALESCE(v_decide_result ->> 'status', '') <> 'rejected' THEN
    RAISE EXCEPTION 'PR17_2E_SMOKE_FAIL: expense rejection did not finish the workflow: %', v_decide_result;
  END IF;

  v_leave_decision_dedupe := concat_ws(
    ':',
    'pr17.2a',
    'leave_request_decision',
    v_leave_request_id::TEXT,
    'approved',
    v_requester_employee_id::TEXT
  );
  v_expense_decision_dedupe := concat_ws(
    ':',
    'pr17.2a',
    'expense_claim_decision',
    v_expense_claim_id::TEXT,
    'rejected',
    v_requester_employee_id::TEXT
  );

  SELECT COUNT(*)
  INTO v_count_before
  FROM puls_app.app_notifications n
  WHERE n.tenant_id = v_tenant_id
    AND n.dedupe_key IN (v_leave_decision_dedupe, v_expense_decision_dedupe)
    AND n.safe_summary ->> 'workflow_notification_dispatch' = 'true'
    AND n.safe_summary ->> 'connector_independent_delivery' = 'true'
    AND n.target_employee_ids @> ARRAY[v_requester_employee_id]::UUID[];

  IF v_count_before <> 2 THEN
    RAISE EXCEPTION
      'PR17_2E_SMOKE_FAIL: expected 2 live trigger requester notifications before producer reconcile, got %',
      v_count_before;
  END IF;

  PERFORM set_config('request.jwt.claim.role', 'service_role', TRUE);
  PERFORM set_config('request.jwt.claim.sub', '', TRUE);

  SELECT
    COUNT(*),
    COUNT(*) FILTER (WHERE produced.inserted)
  INTO
    v_reconcile_seen,
    v_reconcile_inserted
  FROM puls_app.run_app_notification_producers(500, v_tenant_id) produced
  WHERE produced.producer_key = 'workflow'
    AND produced.dedupe_key IN (v_leave_decision_dedupe, v_expense_decision_dedupe);

  IF v_reconcile_seen < 2 OR v_reconcile_inserted <> 0 THEN
    RAISE EXCEPTION
      'PR17_2E_SMOKE_FAIL: decision reconcile should see existing rows and insert none, seen %, inserted %',
      v_reconcile_seen,
      v_reconcile_inserted;
  END IF;

  SELECT COUNT(*)
  INTO v_count_after
  FROM puls_app.app_notifications n
  WHERE n.tenant_id = v_tenant_id
    AND n.dedupe_key IN (
      v_leave_approval_dedupe,
      v_expense_approval_dedupe,
      v_leave_decision_dedupe,
      v_expense_decision_dedupe
    );

  IF v_count_after <> 4 THEN
    RAISE EXCEPTION
      'PR17_2E_SMOKE_FAIL: expected exactly 4 baseline notification rows after reconcile, got %',
      v_count_after;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM puls_app.app_notifications n
    WHERE n.tenant_id = v_tenant_id
      AND n.dedupe_key IN (
        v_leave_approval_dedupe,
        v_expense_approval_dedupe,
        v_leave_decision_dedupe,
        v_expense_decision_dedupe
      )
    GROUP BY n.tenant_id, n.dedupe_key
    HAVING COUNT(*) <> 1
  ) THEN
    RAISE EXCEPTION 'PR17_2E_SMOKE_FAIL: duplicate notification row detected for workflow dedupe key';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM puls_audit.audit_logs audit
    WHERE audit.tenant_id = v_tenant_id
      AND audit.target_table = 'leave_requests'
      AND audit.target_id = v_leave_request_id
      AND audit.action IN ('leave_request.created', 'approval.approved', 'workflow.leave_requests.insert', 'workflow.leave_requests.update')
  ) THEN
    RAISE EXCEPTION 'PR17_2E_SMOKE_FAIL: missing leave audit evidence';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM puls_audit.audit_logs audit
    WHERE audit.tenant_id = v_tenant_id
      AND audit.target_table = 'expense_claims'
      AND audit.target_id = v_expense_claim_id
      AND audit.action IN ('expense_claim.created', 'approval.rejected', 'workflow.expense_claims.insert', 'workflow.expense_claims.update')
  ) THEN
    RAISE EXCEPTION 'PR17_2E_SMOKE_FAIL: missing expense audit evidence';
  END IF;

  IF v_multi_step_seen THEN
    RAISE NOTICE 'OK: PR17.2E multi-step approval notification was observed.';
  ELSE
    RAISE NOTICE 'OK: PR17.2E single-step approval baseline completed; no multi-step policy was present for the selected tenant.';
  END IF;

  RAISE NOTICE 'OK: PR17.2E workflow e2e + reconcile smoke completed for tenant % (ROLLBACK pending)', v_tenant_id;
END $$;

ROLLBACK;
