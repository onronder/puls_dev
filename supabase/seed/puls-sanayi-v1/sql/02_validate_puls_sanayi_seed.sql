-- PR13.4 validate: count and relationship checks for Puls Sanayi baseline seed.
-- Run after 01_load_puls_sanayi_seed.sql

\set ON_ERROR_STOP on

DO $$
DECLARE
  v_tenant uuid := 'a0000001-0001-4001-8001-000000000001';
  v_count int;
BEGIN
  -- Core org proof
  SELECT count(*) INTO v_count FROM puls_core.tenants WHERE id = v_tenant;
  IF v_count <> 1 THEN RAISE EXCEPTION 'tenants expected 1, got %', v_count; END IF;

  SELECT count(*) INTO v_count FROM puls_core.legal_entities WHERE tenant_id = v_tenant;
  IF v_count <> 1 THEN RAISE EXCEPTION 'legal_entities expected 1, got %', v_count; END IF;

  SELECT count(*) INTO v_count FROM puls_core.employees WHERE tenant_id = v_tenant;
  IF v_count <> 120 THEN RAISE EXCEPTION 'employees expected 120, got %', v_count; END IF;

  SELECT count(*) INTO v_count FROM puls_core.departments WHERE tenant_id = v_tenant;
  IF v_count <> 12 THEN RAISE EXCEPTION 'departments expected 12, got %', v_count; END IF;

  SELECT count(*) INTO v_count FROM puls_core.locations WHERE tenant_id = v_tenant;
  IF v_count <> 3 THEN RAISE EXCEPTION 'locations expected 3, got %', v_count; END IF;

  SELECT count(*) INTO v_count FROM puls_core.positions WHERE tenant_id = v_tenant;
  IF v_count < 35 OR v_count > 50 THEN RAISE EXCEPTION 'positions expected 35-50, got %', v_count; END IF;

  SELECT count(*) INTO v_count FROM puls_core.cost_centers WHERE tenant_id = v_tenant;
  IF v_count < 12 OR v_count > 20 THEN RAISE EXCEPTION 'cost_centers expected 12-20, got %', v_count; END IF;

  -- Assignments
  SELECT count(*) INTO v_count FROM puls_core.employee_reporting_lines WHERE tenant_id = v_tenant;
  IF v_count < 119 THEN RAISE EXCEPTION 'reporting_lines expected >=119, got %', v_count; END IF;

  SELECT count(*) INTO v_count FROM puls_core.employee_legal_entity_assignments WHERE tenant_id = v_tenant;
  IF v_count <> 120 THEN RAISE EXCEPTION 'legal_entity_assignments expected 120, got %', v_count; END IF;

  SELECT count(*) INTO v_count FROM puls_core.employee_location_assignments WHERE tenant_id = v_tenant;
  IF v_count <> 120 THEN RAISE EXCEPTION 'location_assignments expected 120, got %', v_count; END IF;

  SELECT count(*) INTO v_count FROM puls_core.employee_cost_center_assignments WHERE tenant_id = v_tenant;
  IF v_count <> 120 THEN RAISE EXCEPTION 'cost_center_assignments expected 120, got %', v_count; END IF;

  -- Workflow baseline
  SELECT count(*) INTO v_count FROM puls_workflow.leave_balances WHERE tenant_id = v_tenant;
  IF v_count < 120 THEN RAISE EXCEPTION 'leave_balances expected >=120, got %', v_count; END IF;

  SELECT count(*) INTO v_count FROM puls_workflow.contracts WHERE tenant_id = v_tenant;
  IF v_count < 15 OR v_count > 30 THEN RAISE EXCEPTION 'contracts expected 15-30, got %', v_count; END IF;

  -- Performance context
  SELECT count(*) INTO v_count FROM puls_performance.training_needs WHERE tenant_id = v_tenant;
  IF v_count < 20 OR v_count > 40 THEN RAISE EXCEPTION 'training_needs expected 20-40, got %', v_count; END IF;

  SELECT count(*) INTO v_count FROM puls_performance.career_profiles WHERE tenant_id = v_tenant;
  IF v_count < 20 OR v_count > 40 THEN RAISE EXCEPTION 'career_profiles expected 20-40, got %', v_count; END IF;
  IF v_count >= 100 THEN RAISE EXCEPTION 'career_profiles bloat guard: got %', v_count; END IF;

  -- Integration / ERP metadata
  SELECT count(*) INTO v_count FROM puls_integration.source_namespaces WHERE tenant_id = v_tenant;
  IF v_count < 1 THEN RAISE EXCEPTION 'source_namespaces expected >=1, got %', v_count; END IF;

  SELECT count(*) INTO v_count FROM puls_integration.entity_identity_map WHERE tenant_id = v_tenant;
  IF v_count < 6 OR v_count > 15 THEN RAISE EXCEPTION 'entity_identity_map expected 6-15, got %', v_count; END IF;

  SELECT count(*) INTO v_count FROM puls_integration.erp_connections WHERE tenant_id = v_tenant AND provider = 'canias';
  IF v_count < 1 THEN RAISE EXCEPTION 'Canias erp_connections expected >=1, got %', v_count; END IF;

  RAISE NOTICE 'OK: Puls Sanayi baseline seed validation passed';
END $$;
