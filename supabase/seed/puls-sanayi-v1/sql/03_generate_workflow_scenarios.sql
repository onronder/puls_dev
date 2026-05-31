-- PR13.5 — Workflow scenario generation (narrative proof via direct INSERT).
-- RPC mutation proof is 06_jwt_mutation_proof_smoke.sql only.
-- Do not call deactivate_leave_type, restore_leave_type, deactivate_expense_category, or restore_expense_category here.
--
-- Scenario scripts must be idempotent per target table: use external_source='pr13_scenario' only where
-- the column exists; otherwise delete by deterministic PR13.5 UUID prefix or explicit fixed UUID list.
--
-- Delete order (child before parent):
--   1. approval_requests (child FK to leave_requests / expense_claims)
--   2. leave_type_lifecycle_events / expense_category_lifecycle_events (scenario UUID prefix)
--   3. leave_requests / expense_claims (external_source = 'pr13_scenario')
--
-- Lifecycle-smoke-reserved (no scenario open/pending on these):
--   leave type UCRETSIZ  a0000012-0012-4012-8012-000000000006
--   expense category HED a0000015-0015-4015-8015-000000000008

\set ON_ERROR_STOP on

DO $$
DECLARE
  v_tenant uuid := 'a0000001-0001-4001-8001-000000000001';
  v_leave_policy uuid := 'a0000013-0013-4013-8013-000000000001';
  v_expense_policy uuid := 'a0000013-0013-4013-8013-000000000002';
  v_lt_yillik uuid := 'a0000012-0012-4012-8012-000000000001';
  v_lt_eski uuid := 'a0000012-0012-4012-8012-000000000008';
  v_lt_ucretsiz uuid := 'a0000012-0012-4012-8012-000000000006';
  v_ec_yemek uuid := 'a0000015-0015-4015-8015-000000000001';
  v_ec_ulasim uuid := 'a0000015-0015-4015-8015-000000000002';
  v_ec_eski uuid := 'a0000015-0015-4015-8015-000000000010';
  v_ec_hed uuid := 'a0000015-0015-4015-8015-000000000008';
  v_i int;
  v_req_id uuid;
  v_apr_id uuid;
  v_emp_id uuid;
  v_mgr_id uuid;
  v_lt_id uuid;
  v_ec_id uuid;
  v_status text;
  v_bdays numeric;
  v_cur_step int;
  v_apr_status puls_workflow.approval_status;
  v_lr_status puls_workflow.leave_request_status;
  v_ec_status puls_workflow.expense_claim_status;
  v_start date;
  v_end date;
BEGIN
  -- Revert prior scenario balance deltas before delete
  UPDATE puls_workflow.leave_balances lb
  SET
    pending_days = GREATEST(0, lb.pending_days - COALESCE(s.pending, 0)),
    used_days = GREATEST(0, lb.used_days - COALESCE(s.used, 0))
  FROM (
    SELECT
      lr.employee_id,
      lr.leave_type_id,
      EXTRACT(YEAR FROM lr.start_date)::int AS period_year,
      SUM(CASE WHEN lr.status IN ('pending', 'draft') THEN lr.business_days ELSE 0 END) AS pending,
      SUM(CASE WHEN lr.status = 'approved' THEN lr.business_days ELSE 0 END) AS used
    FROM puls_workflow.leave_requests lr
    WHERE lr.tenant_id = v_tenant
      AND lr.external_source = 'pr13_scenario'
    GROUP BY 1, 2, 3
  ) s
  WHERE lb.tenant_id = v_tenant
    AND lb.employee_id = s.employee_id
    AND lb.leave_type_id = s.leave_type_id
    AND lb.period_year = s.period_year;

  DELETE FROM puls_workflow.approval_requests
  WHERE tenant_id = v_tenant
    AND (
      id::text LIKE 'b0000003-%'
      OR leave_request_id::text LIKE 'b0000003-%'
      OR expense_claim_id::text LIKE 'b0000003-%'
    );

  DELETE FROM puls_workflow.leave_type_lifecycle_events
  WHERE tenant_id = v_tenant AND id::text LIKE 'b0000003-%';

  DELETE FROM puls_workflow.expense_category_lifecycle_events
  WHERE tenant_id = v_tenant AND id::text LIKE 'b0000003-%';

  DELETE FROM puls_workflow.leave_requests
  WHERE tenant_id = v_tenant AND external_source = 'pr13_scenario';

  DELETE FROM puls_workflow.expense_claims
  WHERE tenant_id = v_tenant AND external_source = 'pr13_scenario';

  -- Historical lifecycle narrative for inactive baseline rows (restored T1 -> deactivated T2)
  INSERT INTO puls_workflow.leave_type_lifecycle_events (
    id, tenant_id, leave_type_id, action, reason, occurred_at
  ) VALUES
    (
      'b0000003-0003-4003-8003-000000000001'::uuid,
      v_tenant, v_lt_eski, 'restored', 'PR13.5 historical narrative',
      TIMESTAMPTZ '2024-06-01 10:00:00+00'
    ),
    (
      'b0000003-0003-4003-8003-000000000002'::uuid,
      v_tenant, v_lt_eski, 'deactivated', 'PR13.5 historical narrative',
      TIMESTAMPTZ '2025-01-15 14:00:00+00'
    );

  INSERT INTO puls_workflow.expense_category_lifecycle_events (
    id, tenant_id, category_id, action, reason, occurred_at
  ) VALUES
    (
      'b0000003-0003-4003-8003-000000000003'::uuid,
      v_tenant, v_ec_eski, 'restored', 'PR13.5 historical narrative',
      TIMESTAMPTZ '2024-07-01 09:00:00+00'
    ),
    (
      'b0000003-0003-4003-8003-000000000004'::uuid,
      v_tenant, v_ec_eski, 'deactivated', 'PR13.5 historical narrative',
      TIMESTAMPTZ '2025-02-01 11:00:00+00'
    );

  -- 30 leave requests (employees PS-023..PS-052)
  FOR v_i IN 1..30 LOOP
    v_req_id := ('b0000003-0003-4003-8003-' || lpad(v_i::text, 12, '0'))::uuid;
    v_apr_id := ('b0000003-0003-4003-8003-' || lpad((100000 + v_i)::text, 12, '0'))::uuid;
    v_emp_id := ('a0000006-0006-4006-8006-' || lpad((22 + v_i)::text, 12, '0'))::uuid;

    SELECT rl.manager_employee_id INTO v_mgr_id
    FROM puls_core.employee_reporting_lines rl
    WHERE rl.tenant_id = v_tenant
      AND rl.employee_id = v_emp_id
      AND rl.relationship_type = 'primary_manager'
      AND rl.is_active = TRUE
    LIMIT 1;

    v_lt_id := v_lt_yillik;
    IF v_i >= 29 THEN
      v_lt_id := v_lt_eski;
    END IF;

    v_bdays := CASE WHEN v_i IN (26, 27, 28) THEN 0.5 ELSE (1 + (v_i % 3))::numeric END;
    v_start := DATE '2026-03-01' + ((v_i - 1) % 20);
    v_end := v_start + CASE WHEN v_bdays <= 0.5 THEN 0 ELSE (v_bdays - 1)::int END;

    IF v_i <= 8 THEN
      v_lr_status := 'pending';
      v_cur_step := 1;
      v_apr_status := 'pending';
    ELSIF v_i <= 16 THEN
      v_lr_status := 'approved';
      v_cur_step := NULL;
      v_apr_status := 'approved';
    ELSIF v_i <= 22 THEN
      v_lr_status := 'rejected';
      v_cur_step := NULL;
      v_apr_status := 'rejected';
    ELSIF v_i <= 25 THEN
      v_lr_status := 'pending';
      v_cur_step := 1;
      v_apr_status := 'pending';
    ELSE
      v_lr_status := 'pending';
      v_cur_step := 1;
      v_apr_status := 'pending';
    END IF;

    INSERT INTO puls_workflow.leave_requests (
      id, tenant_id, employee_id, leave_type_id,
      start_date, end_date, business_days, half_day,
      delegate_employee_id, description, status,
      submitted_at, approved_at, rejected_at,
      current_approval_step, approval_policy_id,
      external_source, external_request_id
    ) VALUES (
      v_req_id, v_tenant, v_emp_id, v_lt_id,
      v_start, v_end, v_bdays, v_i IN (26, 27, 28),
      CASE WHEN v_i BETWEEN 23 AND 25 THEN v_mgr_id ELSE NULL END,
      'PR13.5 scenario leave ' || v_i,
      v_lr_status,
      CASE WHEN v_lr_status <> 'draft' THEN NOW() - INTERVAL '2 days' ELSE NULL END,
      CASE WHEN v_lr_status = 'approved' THEN NOW() - INTERVAL '1 day' ELSE NULL END,
      CASE WHEN v_lr_status = 'rejected' THEN NOW() - INTERVAL '1 day' ELSE NULL END,
      v_cur_step, v_leave_policy,
      'pr13_scenario', 'LR-SC-' || lpad(v_i::text, 4, '0')
    );

    IF v_mgr_id IS NOT NULL THEN
      INSERT INTO puls_workflow.approval_requests (
        id, tenant_id, module, leave_request_id,
        requester_employee_id, approver_employee_id,
        step_order, status, decision_note, decided_at,
        approval_policy_id
      ) VALUES (
        v_apr_id, v_tenant, 'leave', v_req_id,
        v_emp_id, v_mgr_id,
        1, v_apr_status,
        CASE WHEN v_apr_status = 'rejected' THEN 'PR13.5 scenario rejection' ELSE NULL END,
        CASE WHEN v_apr_status IN ('approved', 'rejected') THEN NOW() - INTERVAL '1 day' ELSE NULL END,
        v_leave_policy
      );
    END IF;
  END LOOP;

  -- 30 expense claims (employees PS-053..PS-082 mod 120 -> use 53..82)
  FOR v_i IN 1..30 LOOP
    v_req_id := ('b0000003-0003-4003-8003-' || lpad((200000 + v_i)::text, 12, '0'))::uuid;
    v_apr_id := ('b0000003-0003-4003-8003-' || lpad((300000 + v_i)::text, 12, '0'))::uuid;
    v_emp_id := ('a0000006-0006-4006-8006-' || lpad((52 + v_i)::text, 12, '0'))::uuid;

    SELECT rl.manager_employee_id INTO v_mgr_id
    FROM puls_core.employee_reporting_lines rl
    WHERE rl.tenant_id = v_tenant
      AND rl.employee_id = v_emp_id
      AND rl.relationship_type = 'primary_manager'
      AND rl.is_active = TRUE
    LIMIT 1;

    v_ec_id := CASE
      WHEN v_i >= 29 THEN v_ec_eski
      WHEN v_i % 2 = 0 THEN v_ec_ulasim
      ELSE v_ec_yemek
    END;

    IF v_i <= 8 THEN
      v_ec_status := 'pending';
      v_cur_step := 1;
      v_apr_status := 'pending';
    ELSIF v_i <= 18 THEN
      v_ec_status := 'approved';
      v_cur_step := NULL;
      v_apr_status := 'approved';
    ELSE
      v_ec_status := 'rejected';
      v_cur_step := NULL;
      v_apr_status := 'rejected';
    END IF;

    INSERT INTO puls_workflow.expense_claims (
      id, tenant_id, employee_id, category_id,
      amount, currency, vat_rate, vat_included,
      expense_date, title, description, policy_status, status,
      submitted_at, approved_at, rejected_at,
      current_approval_step, approval_policy_id,
      external_source, external_claim_id
    ) VALUES (
      v_req_id, v_tenant, v_emp_id, v_ec_id,
      (500 + v_i * 137)::numeric, 'TRY',
      CASE WHEN v_i % 3 = 0 THEN 20 ELSE 10 END,
      v_i % 2 = 1,
      DATE '2026-02-01' + ((v_i - 1) % 25),
      'PR13.5 scenario expense ' || v_i,
      'PR13.5 packaging proof claim',
      CASE WHEN v_i IN (7, 14, 21) THEN 'warning'::puls_workflow.policy_status ELSE 'unchecked'::puls_workflow.policy_status END,
      v_ec_status,
      NOW() - INTERVAL '3 days',
      CASE WHEN v_ec_status = 'approved' THEN NOW() - INTERVAL '1 day' ELSE NULL END,
      CASE WHEN v_ec_status = 'rejected' THEN NOW() - INTERVAL '1 day' ELSE NULL END,
      v_cur_step, v_expense_policy,
      'pr13_scenario', 'EC-SC-' || lpad(v_i::text, 4, '0')
    );

    IF v_mgr_id IS NOT NULL THEN
      INSERT INTO puls_workflow.approval_requests (
        id, tenant_id, module, expense_claim_id,
        requester_employee_id, approver_employee_id,
        step_order, status, decision_note, decided_at,
        approval_policy_id
      ) VALUES (
        v_apr_id, v_tenant, 'expense', v_req_id,
        v_emp_id, v_mgr_id,
        1, v_apr_status,
        CASE WHEN v_apr_status = 'rejected' THEN 'PR13.5 scenario rejection' ELSE NULL END,
        CASE WHEN v_apr_status IN ('approved', 'rejected') THEN NOW() - INTERVAL '1 day' ELSE NULL END,
        v_expense_policy
      );
    END IF;
  END LOOP;

  -- Recompute leave_balances pending_days / used_days for scenario leave rows
  UPDATE puls_workflow.leave_balances lb
  SET
    pending_days = lb.pending_days + COALESCE(s.pending, 0),
    used_days = lb.used_days + COALESCE(s.used, 0)
  FROM (
    SELECT
      lr.employee_id,
      lr.leave_type_id,
      EXTRACT(YEAR FROM lr.start_date)::int AS period_year,
      SUM(CASE WHEN lr.status IN ('pending', 'draft') THEN lr.business_days ELSE 0 END) AS pending,
      SUM(CASE WHEN lr.status = 'approved' THEN lr.business_days ELSE 0 END) AS used
    FROM puls_workflow.leave_requests lr
    WHERE lr.tenant_id = v_tenant
      AND lr.external_source = 'pr13_scenario'
    GROUP BY 1, 2, 3
  ) s
  WHERE lb.tenant_id = v_tenant
    AND lb.employee_id = s.employee_id
    AND lb.leave_type_id = s.leave_type_id
    AND lb.period_year = s.period_year;

  RAISE NOTICE 'OK: PR13.5 workflow scenarios generated (leave=%, expense=%, approvals>=60)',
    (SELECT count(*) FROM puls_workflow.leave_requests WHERE tenant_id = v_tenant AND external_source = 'pr13_scenario'),
    (SELECT count(*) FROM puls_workflow.expense_claims WHERE tenant_id = v_tenant AND external_source = 'pr13_scenario');
END $$;
