-- PR17.2B — Workflow closed-loop notification proof smoke.
--
-- Runs inside BEGIN ... ROLLBACK so no workflow, notification, read-state, or
-- audit row is persisted. This proves the existing workflow RPCs, row audit
-- triggers, service-role notification producers, and notification ledger line
-- up for both leave and expense flows.
--
-- Usage:
--   psql "$DATABASE_URL" \
--     -v tenant_id='<optional tenant uuid>' \
--     -v requester_user_id='<optional employee auth uuid>' \
--     -v admin_user_id='<optional admin auth uuid>' \
--     -f docs/data/17_2_b_workflow_closed_loop_smoke.sql

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

CREATE TEMP TABLE IF NOT EXISTS pr17_2b_psql_vars (
  key TEXT PRIMARY KEY,
  raw_value TEXT NOT NULL
);

TRUNCATE pr17_2b_psql_vars;

INSERT INTO pr17_2b_psql_vars (key, raw_value) VALUES
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
  v_emitted_count INTEGER;
  v_expected_event_count INTEGER;
BEGIN
  SELECT raw_value INTO v_raw FROM pr17_2b_psql_vars WHERE key = 'tenant_id';
  v_requested_tenant_id := NULLIF(NULLIF(BTRIM(COALESCE(v_raw, '')), ''), v_zero::TEXT)::UUID;

  SELECT raw_value INTO v_raw FROM pr17_2b_psql_vars WHERE key = 'requester_user_id';
  v_requested_requester_user_id := NULLIF(NULLIF(BTRIM(COALESCE(v_raw, '')), ''), v_zero::TEXT)::UUID;

  SELECT raw_value INTO v_raw FROM pr17_2b_psql_vars WHERE key = 'admin_user_id';
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
    RAISE NOTICE 'PR17.2B smoke skipped — no linked active requester employee with leave and expense setup was found.';
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
    RAISE EXCEPTION 'PR17_2B_SMOKE_FAIL: missing active leave type or expense category for tenant %', v_tenant_id;
  END IF;

  PERFORM set_config('request.jwt.claim.role', 'authenticated', TRUE);
  PERFORM set_config('request.jwt.claim.sub', v_requester_user_id::TEXT, TRUE);

  IF puls_core.current_employee_id() IS DISTINCT FROM v_requester_employee_id THEN
    RAISE EXCEPTION 'PR17_2B_SMOKE_FAIL: requester JWT resolved to %, expected %',
      puls_core.current_employee_id(), v_requester_employee_id;
  END IF;

  v_leave_result := puls_workflow.create_leave_request(
    v_leave_type_id,
    CURRENT_DATE + 30,
    CURRENT_DATE + 30,
    TRUE,
    NULL,
    'PR17.2B rollback-only leave smoke'
  );

  v_leave_request_id := NULLIF(v_leave_result ->> 'leave_request_id', '')::UUID;
  v_leave_approval_id := NULLIF(v_leave_result ->> 'approval_request_id', '')::UUID;

  IF v_leave_request_id IS NULL OR v_leave_approval_id IS NULL THEN
    RAISE EXCEPTION 'PR17_2B_SMOKE_FAIL: create_leave_request did not return ids: %', v_leave_result;
  END IF;

  v_expense_result := puls_workflow.create_expense_claim(
    v_expense_category_id,
    'PR17.2B rollback-only expense smoke',
    100.00,
    'TRY',
    20,
    TRUE,
    CURRENT_DATE,
    'PR17.2B rollback-only expense smoke'
  );

  v_expense_claim_id := NULLIF(v_expense_result ->> 'expense_claim_id', '')::UUID;
  v_expense_approval_id := NULLIF(v_expense_result ->> 'approval_request_id', '')::UUID;

  IF v_expense_claim_id IS NULL OR v_expense_approval_id IS NULL THEN
    RAISE EXCEPTION 'PR17_2B_SMOKE_FAIL: create_expense_claim did not return ids: %', v_expense_result;
  END IF;

  PERFORM set_config('request.jwt.claim.role', 'service_role', TRUE);
  PERFORM set_config('request.jwt.claim.sub', '', TRUE);

  SELECT COUNT(*) INTO v_emitted_count
  FROM puls_app.run_app_notification_producers(500, v_tenant_id) produced
  WHERE produced.producer_key = 'workflow'
    AND produced.source_event_key IN ('leave_approval_requested', 'expense_approval_requested')
    AND produced.source_id IN (v_leave_approval_id, v_expense_approval_id);

  IF v_emitted_count < 2 THEN
    RAISE EXCEPTION 'PR17_2B_SMOKE_FAIL: expected both approval-requested workflow notifications, got %', v_emitted_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM puls_app.app_notifications n
    JOIN puls_workflow.approval_requests ar
      ON ar.id = v_leave_approval_id
    WHERE n.tenant_id = v_tenant_id
      AND n.source_domain = 'puls_workflow'
      AND n.source_event_key = 'leave_approval_requested'
      AND n.source_table = 'puls_workflow.approval_requests'
      AND n.source_id = v_leave_approval_id
      AND n.target_employee_ids @> ARRAY[ar.approver_employee_id]::UUID[]
      AND n.safe_summary ->> 'workflow_module' = 'leave'
      AND n.safe_summary ->> 'raw_payload_readback' IS NULL
  ) THEN
    RAISE EXCEPTION 'PR17_2B_SMOKE_FAIL: missing leave approval-requested notification ledger row';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM puls_app.app_notifications n
    JOIN puls_workflow.approval_requests ar
      ON ar.id = v_expense_approval_id
    WHERE n.tenant_id = v_tenant_id
      AND n.source_domain = 'puls_workflow'
      AND n.source_event_key = 'expense_approval_requested'
      AND n.source_table = 'puls_workflow.approval_requests'
      AND n.source_id = v_expense_approval_id
      AND n.target_employee_ids @> ARRAY[ar.approver_employee_id]::UUID[]
      AND n.safe_summary ->> 'workflow_module' = 'expense'
      AND n.safe_summary ->> 'raw_payload_readback' IS NULL
  ) THEN
    RAISE EXCEPTION 'PR17_2B_SMOKE_FAIL: missing expense approval-requested notification ledger row';
  END IF;

  v_current_approval_id := v_leave_approval_id;

  LOOP
    v_loop_guard := v_loop_guard + 1;
    IF v_loop_guard > 5 THEN
      RAISE EXCEPTION 'PR17_2B_SMOKE_FAIL: leave approval chain exceeded 5 steps';
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
      RAISE EXCEPTION 'PR17_2B_SMOKE_FAIL: pending leave approval % was not found', v_current_approval_id;
    END IF;

    v_decision_user_id := COALESCE(v_current_approver_user_id, v_admin_user_id);

    IF v_decision_user_id IS NULL THEN
      RAISE EXCEPTION 'PR17_2B_SMOKE_FAIL: approval % has no linked approver user and no admin fallback', v_current_approval_id;
    END IF;

    PERFORM set_config('request.jwt.claim.role', 'authenticated', TRUE);
    PERFORM set_config('request.jwt.claim.sub', v_decision_user_id::TEXT, TRUE);

    v_decide_result := puls_workflow.decide_approval_request(
      v_current_approval_id,
      'approved',
      'PR17.2B rollback-only leave approval'
    );

    IF COALESCE((v_decide_result ->> 'final')::BOOLEAN, FALSE) = TRUE
       OR COALESCE(v_decide_result ->> 'status', '') = 'approved' THEN
      EXIT;
    END IF;

    v_current_approval_id := NULLIF(v_decide_result ->> 'next_approval_request_id', '')::UUID;
    IF v_current_approval_id IS NULL THEN
      RAISE EXCEPTION 'PR17_2B_SMOKE_FAIL: leave approval did not finish or return next approval: %', v_decide_result;
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
    RAISE EXCEPTION 'PR17_2B_SMOKE_FAIL: pending expense approval % was not found', v_expense_approval_id;
  END IF;

  v_decision_user_id := COALESCE(v_current_approver_user_id, v_admin_user_id);

  IF v_decision_user_id IS NULL THEN
    RAISE EXCEPTION 'PR17_2B_SMOKE_FAIL: expense approval has no linked approver user and no admin fallback';
  END IF;

  PERFORM set_config('request.jwt.claim.role', 'authenticated', TRUE);
  PERFORM set_config('request.jwt.claim.sub', v_decision_user_id::TEXT, TRUE);

  v_decide_result := puls_workflow.decide_approval_request(
    v_expense_approval_id,
    'rejected',
    'PR17.2B rollback-only expense rejection'
  );

  IF COALESCE((v_decide_result ->> 'final')::BOOLEAN, FALSE) IS DISTINCT FROM TRUE
     OR COALESCE(v_decide_result ->> 'status', '') <> 'rejected' THEN
    RAISE EXCEPTION 'PR17_2B_SMOKE_FAIL: expense rejection did not finish the workflow: %', v_decide_result;
  END IF;

  PERFORM set_config('request.jwt.claim.role', 'service_role', TRUE);
  PERFORM set_config('request.jwt.claim.sub', '', TRUE);

  SELECT COUNT(*) INTO v_expected_event_count
  FROM puls_app.run_app_notification_producers(500, v_tenant_id) produced
  WHERE produced.producer_key = 'workflow'
    AND (
      (produced.source_event_key = 'leave_request_approved' AND produced.source_id = v_leave_request_id)
      OR (produced.source_event_key = 'expense_claim_rejected' AND produced.source_id = v_expense_claim_id)
    );

  IF v_expected_event_count < 2 THEN
    RAISE EXCEPTION 'PR17_2B_SMOKE_FAIL: expected leave-approved and expense-rejected workflow notifications, got %',
      v_expected_event_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM puls_app.app_notifications n
    WHERE n.tenant_id = v_tenant_id
      AND n.source_domain = 'puls_workflow'
      AND n.source_event_key = 'leave_request_approved'
      AND n.source_table = 'puls_workflow.leave_requests'
      AND n.source_id = v_leave_request_id
      AND n.target_employee_ids @> ARRAY[v_requester_employee_id]::UUID[]
      AND n.safe_summary ->> 'target' = 'requester'
  ) THEN
    RAISE EXCEPTION 'PR17_2B_SMOKE_FAIL: missing leave-approved requester notification';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM puls_app.app_notifications n
    WHERE n.tenant_id = v_tenant_id
      AND n.source_domain = 'puls_workflow'
      AND n.source_event_key = 'expense_claim_rejected'
      AND n.source_table = 'puls_workflow.expense_claims'
      AND n.source_id = v_expense_claim_id
      AND n.target_employee_ids @> ARRAY[v_requester_employee_id]::UUID[]
      AND n.safe_summary ->> 'target' = 'requester'
  ) THEN
    RAISE EXCEPTION 'PR17_2B_SMOKE_FAIL: missing expense-rejected requester notification';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM puls_audit.audit_logs audit
    WHERE audit.tenant_id = v_tenant_id
      AND audit.target_table = 'leave_requests'
      AND audit.target_id = v_leave_request_id
      AND audit.action IN ('leave_request.created', 'approval.approved', 'workflow.leave_requests.insert', 'workflow.leave_requests.update')
  ) THEN
    RAISE EXCEPTION 'PR17_2B_SMOKE_FAIL: missing leave audit evidence';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM puls_audit.audit_logs audit
    WHERE audit.tenant_id = v_tenant_id
      AND audit.target_table = 'expense_claims'
      AND audit.target_id = v_expense_claim_id
      AND audit.action IN ('expense_claim.created', 'approval.rejected', 'workflow.expense_claims.insert', 'workflow.expense_claims.update')
  ) THEN
    RAISE EXCEPTION 'PR17_2B_SMOKE_FAIL: missing expense audit evidence';
  END IF;

  RAISE NOTICE 'OK: PR17.2B workflow closed-loop smoke completed for tenant % (ROLLBACK pending)', v_tenant_id;
END $$;

ROLLBACK;
