-- PR13.5 — Packaging proof validation (baseline + scenario + calc + source-aware).
-- Run after 03_generate_workflow_scenarios.sql and 04_generate_performance_scenarios.sql.

\set ON_ERROR_STOP on

DO $$
DECLARE
  v_tenant uuid := 'a0000001-0001-4001-8001-000000000001';
  v_count int;
  v_demo_count int;
  v_neg_balance int;
BEGIN
  -- Baseline still present (reuse 02 thresholds)
  SELECT count(*) INTO v_count FROM puls_core.employees WHERE tenant_id = v_tenant;
  IF v_count <> 120 THEN RAISE EXCEPTION 'employees expected 120, got %', v_count; END IF;

  SELECT count(*) INTO v_count FROM puls_core.departments WHERE tenant_id = v_tenant;
  IF v_count <> 12 THEN RAISE EXCEPTION 'departments expected 12, got %', v_count; END IF;

  SELECT count(*) INTO v_count FROM puls_core.locations WHERE tenant_id = v_tenant;
  IF v_count <> 3 THEN RAISE EXCEPTION 'locations expected 3, got %', v_count; END IF;

  -- Scenario counts
  SELECT count(*) INTO v_count FROM puls_workflow.leave_requests
  WHERE tenant_id = v_tenant AND external_source = 'pr13_scenario';
  IF v_count < 20 OR v_count > 40 THEN
    RAISE EXCEPTION 'scenario leave_requests expected 20-40, got %', v_count;
  END IF;

  SELECT count(*) INTO v_count FROM puls_workflow.expense_claims
  WHERE tenant_id = v_tenant AND external_source = 'pr13_scenario';
  IF v_count < 20 OR v_count > 40 THEN
    RAISE EXCEPTION 'scenario expense_claims expected 20-40, got %', v_count;
  END IF;

  SELECT count(*) INTO v_count FROM puls_workflow.approval_requests WHERE tenant_id = v_tenant;
  IF v_count < 20 THEN RAISE EXCEPTION 'approval_requests expected >=20, got %', v_count; END IF;

  SELECT
    (SELECT count(*) FROM puls_performance.performance_scores WHERE tenant_id = v_tenant AND id::text LIKE 'b0000004-%')
    + (SELECT count(*) FROM puls_performance.competency_evaluations WHERE tenant_id = v_tenant AND id::text LIKE 'b0000004-%')
  INTO v_count;
  IF v_count < 80 THEN RAISE EXCEPTION 'performance scores+evals expected >=80, got %', v_count; END IF;

  SELECT count(*) INTO v_count FROM puls_workflow.leave_type_lifecycle_events
  WHERE tenant_id = v_tenant AND id::text LIKE 'b0000003-%';
  IF v_count < 2 THEN RAISE EXCEPTION 'leave lifecycle events expected >=2, got %', v_count; END IF;

  SELECT count(*) INTO v_count FROM puls_workflow.expense_category_lifecycle_events
  WHERE tenant_id = v_tenant AND id::text LIKE 'b0000003-%';
  IF v_count < 2 THEN RAISE EXCEPTION 'expense lifecycle events expected >=2, got %', v_count; END IF;

  -- Leave balance guard: no negative remaining_days
  SELECT count(*) INTO v_neg_balance FROM puls_workflow.leave_balances
  WHERE tenant_id = v_tenant AND remaining_days < 0;
  IF v_neg_balance > 0 THEN
    RAISE EXCEPTION 'leave_balances with remaining_days < 0: %', v_neg_balance;
  END IF;

  -- Calc views: tenant-scoped row existence
  SELECT count(*) INTO v_count FROM puls_calc.dashboard_overview WHERE tenant_id = v_tenant;
  IF v_count < 1 THEN RAISE EXCEPTION 'dashboard_overview empty for tenant'; END IF;

  SELECT count(*) INTO v_count FROM puls_calc.employee_list_overview WHERE tenant_id = v_tenant;
  IF v_count < 1 THEN RAISE EXCEPTION 'employee_list_overview empty for tenant'; END IF;

  SELECT count(*) INTO v_count FROM puls_calc.organization_overview WHERE tenant_id = v_tenant;
  IF v_count < 1 THEN RAISE EXCEPTION 'organization_overview empty for tenant'; END IF;

  SELECT count(*) INTO v_count FROM puls_calc.leave_overview WHERE tenant_id = v_tenant;
  IF v_count < 1 THEN RAISE EXCEPTION 'leave_overview empty for tenant'; END IF;

  SELECT count(*) INTO v_count FROM puls_calc.expense_overview WHERE tenant_id = v_tenant;
  IF v_count < 1 THEN RAISE EXCEPTION 'expense_overview empty for tenant'; END IF;

  SELECT count(*) INTO v_count FROM puls_calc.performance_overview WHERE tenant_id = v_tenant;
  IF v_count < 1 THEN RAISE EXCEPTION 'performance_overview empty for tenant'; END IF;

  SELECT count(*) INTO v_count FROM puls_calc.contracts_overview WHERE tenant_id = v_tenant;
  IF v_count < 1 THEN RAISE EXCEPTION 'contracts_overview empty for tenant'; END IF;

  SELECT count(*) INTO v_count FROM puls_calc.setup_readiness_summary WHERE tenant_id = v_tenant;
  IF v_count < 1 THEN RAISE EXCEPTION 'setup_readiness_summary empty for tenant'; END IF;

  SELECT count(*) INTO v_count FROM puls_calc.menu_overview WHERE tenant_id = v_tenant;
  IF v_count < 1 THEN RAISE EXCEPTION 'menu_overview empty for tenant'; END IF;

  -- KPI spot-check when columns exist (inspect-first from migration)
  BEGIN
    PERFORM pending_leave_count FROM puls_calc.dashboard_overview WHERE tenant_id = v_tenant LIMIT 1;
    SELECT pending_leave_count INTO v_count FROM puls_calc.dashboard_overview WHERE tenant_id = v_tenant LIMIT 1;
    IF v_count IS NULL OR v_count < 0 THEN
      RAISE NOTICE 'WARN: pending_leave_count unexpected: %', v_count;
    END IF;
  EXCEPTION WHEN undefined_column THEN
    RAISE NOTICE 'SKIP: dashboard_overview KPI columns differ — count check only';
  END;

  -- Source-aware proof
  SELECT count(*) INTO v_count FROM puls_core.departments
  WHERE tenant_id = v_tenant AND NULLIF(BTRIM(external_source), '') IS NOT NULL;
  IF v_count < 1 THEN RAISE EXCEPTION 'expected imported departments with external_source'; END IF;

  SELECT count(*) INTO v_count FROM puls_integration.source_namespaces WHERE tenant_id = v_tenant;
  IF v_count < 1 THEN RAISE EXCEPTION 'source_namespaces expected >=1'; END IF;

  SELECT count(*) INTO v_count FROM puls_integration.erp_connections
  WHERE tenant_id = v_tenant AND provider = 'canias' AND is_active = FALSE;
  IF v_count < 1 THEN RAISE EXCEPTION 'expected inactive Canias erp_connection'; END IF;

  -- source = 'demo' ban (column-aware assignment tables only)
  SELECT
    (SELECT count(*) FROM puls_core.employee_reporting_lines WHERE tenant_id = v_tenant AND source = 'demo')
    + (SELECT count(*) FROM puls_core.employee_legal_entity_assignments WHERE tenant_id = v_tenant AND source = 'demo')
    + (SELECT count(*) FROM puls_core.employee_location_assignments WHERE tenant_id = v_tenant AND source = 'demo')
    + (SELECT count(*) FROM puls_core.employee_cost_center_assignments WHERE tenant_id = v_tenant AND source = 'demo')
  INTO v_demo_count;

  IF v_demo_count > 0 THEN
    RAISE EXCEPTION 'source=demo rows in assignment tables: %', v_demo_count;
  END IF;

  RAISE NOTICE 'OK: PR13.5 packaging proof validation passed';
END $$;
