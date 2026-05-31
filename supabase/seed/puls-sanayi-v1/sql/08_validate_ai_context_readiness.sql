-- PR13.6 — AI context readiness validation (read-only).
-- Run after PR13.5 proof (03, 04, 07). No inserts/updates/deletes.
-- Does not depend on puls_vault.conversation_messages.

\set ON_ERROR_STOP on

DO $$
DECLARE
  v_tenant uuid := 'a0000001-0001-4001-8001-000000000001';
  v_count int;
BEGIN
  SELECT count(*) INTO v_count FROM puls_core.employees WHERE tenant_id = v_tenant;
  IF v_count <> 120 THEN RAISE EXCEPTION 'AI context: employees expected 120, got %', v_count; END IF;

  SELECT count(*) INTO v_count FROM puls_core.departments WHERE tenant_id = v_tenant;
  IF v_count <> 12 THEN RAISE EXCEPTION 'AI context: departments expected 12, got %', v_count; END IF;

  SELECT count(*) INTO v_count FROM puls_workflow.leave_requests
  WHERE tenant_id = v_tenant AND external_source = 'pr13_scenario';
  IF v_count < 20 OR v_count > 40 THEN
    RAISE EXCEPTION 'AI context: scenario leave_requests expected 20-40, got %', v_count;
  END IF;

  SELECT count(*) INTO v_count FROM puls_workflow.expense_claims
  WHERE tenant_id = v_tenant AND external_source = 'pr13_scenario';
  IF v_count < 20 OR v_count > 40 THEN
    RAISE EXCEPTION 'AI context: scenario expense_claims expected 20-40, got %', v_count;
  END IF;

  SELECT
    (SELECT count(*) FROM puls_performance.performance_scores WHERE tenant_id = v_tenant AND id::text LIKE 'b0000004-%')
    + (SELECT count(*) FROM puls_performance.competency_evaluations WHERE tenant_id = v_tenant AND id::text LIKE 'b0000004-%')
  INTO v_count;
  IF v_count < 80 THEN RAISE EXCEPTION 'AI context: performance scores+evals expected >=80, got %', v_count; END IF;

  SELECT count(*) INTO v_count FROM puls_workflow.contracts WHERE tenant_id = v_tenant;
  IF v_count < 15 OR v_count > 30 THEN
    RAISE EXCEPTION 'AI context: contracts expected 15-30, got %', v_count;
  END IF;

  SELECT count(*) INTO v_count FROM puls_integration.source_namespaces WHERE tenant_id = v_tenant;
  IF v_count < 1 THEN RAISE EXCEPTION 'AI context: source_namespaces expected >=1, got %', v_count; END IF;

  SELECT count(*) INTO v_count FROM puls_integration.erp_connections
  WHERE tenant_id = v_tenant AND is_active = FALSE;
  IF v_count < 1 THEN RAISE EXCEPTION 'AI context: inactive Canias erp_connection expected >=1, got %', v_count; END IF;

  SELECT count(*) INTO v_count FROM puls_calc.dashboard_overview WHERE tenant_id = v_tenant;
  IF v_count < 1 THEN RAISE EXCEPTION 'AI context: dashboard_overview empty'; END IF;

  SELECT count(*) INTO v_count FROM puls_calc.setup_readiness_summary WHERE tenant_id = v_tenant;
  IF v_count < 1 THEN RAISE EXCEPTION 'AI context: setup_readiness_summary empty'; END IF;

  SELECT count(*) INTO v_count FROM puls_calc.leave_overview WHERE tenant_id = v_tenant;
  IF v_count < 1 THEN RAISE EXCEPTION 'AI context: leave_overview empty'; END IF;

  SELECT count(*) INTO v_count FROM puls_calc.expense_overview WHERE tenant_id = v_tenant;
  IF v_count < 1 THEN RAISE EXCEPTION 'AI context: expense_overview empty'; END IF;

  SELECT count(*) INTO v_count FROM puls_calc.performance_overview WHERE tenant_id = v_tenant;
  IF v_count < 1 THEN RAISE EXCEPTION 'AI context: performance_overview empty'; END IF;

  SELECT count(*) INTO v_count FROM puls_calc.contracts_overview WHERE tenant_id = v_tenant;
  IF v_count < 1 THEN RAISE EXCEPTION 'AI context: contracts_overview empty'; END IF;

  RAISE NOTICE 'OK: PR13.6 AI context readiness validation passed for tenant %', v_tenant;
END $$;
