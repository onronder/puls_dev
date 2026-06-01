-- PR13.11 role/route product QA validation.
-- Read-only validation for the remote Puls Teknik proof tenant.

DO $$
DECLARE
  v_tenant uuid := 'a0000001-0001-4001-8001-000000000001'::uuid;
  v_count integer;
  v_bad_count integer;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM puls_core.tenants
  WHERE id = v_tenant
    AND (name ILIKE 'Puls Teknik%' OR legal_name ILIKE 'Puls Teknik%' OR trade_name ILIKE 'Puls Teknik%');
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'PR13.11 QA fail: Puls Teknik tenant missing or mislabeled';
  END IF;

  SELECT COUNT(*) INTO v_count FROM puls_core.employees WHERE tenant_id = v_tenant;
  IF v_count <> 120 THEN RAISE EXCEPTION 'PR13.11 QA fail: employees expected 120, got %', v_count; END IF;

  SELECT COUNT(*) INTO v_count FROM puls_core.departments WHERE tenant_id = v_tenant;
  IF v_count <> 12 THEN RAISE EXCEPTION 'PR13.11 QA fail: departments expected 12, got %', v_count; END IF;

  SELECT COUNT(*) INTO v_count FROM puls_core.positions WHERE tenant_id = v_tenant;
  IF v_count <> 36 THEN RAISE EXCEPTION 'PR13.11 QA fail: positions expected 36, got %', v_count; END IF;

  SELECT COUNT(*) INTO v_count FROM puls_workflow.leave_types WHERE tenant_id = v_tenant;
  IF v_count <> 8 THEN RAISE EXCEPTION 'PR13.11 QA fail: leave types expected 8, got %', v_count; END IF;

  SELECT COUNT(*) INTO v_count FROM puls_workflow.expense_categories WHERE tenant_id = v_tenant;
  IF v_count <> 10 THEN RAISE EXCEPTION 'PR13.11 QA fail: expense categories expected 10, got %', v_count; END IF;

  SELECT COUNT(*) INTO v_count
  FROM puls_workflow.leave_requests
  WHERE tenant_id = v_tenant AND external_source = 'pr13_scenario';
  IF v_count <> 30 THEN RAISE EXCEPTION 'PR13.11 QA fail: scenario leave requests expected 30, got %', v_count; END IF;

  SELECT COUNT(*) INTO v_count
  FROM puls_workflow.expense_claims
  WHERE tenant_id = v_tenant AND external_source = 'pr13_scenario';
  IF v_count <> 30 THEN RAISE EXCEPTION 'PR13.11 QA fail: scenario expense claims expected 30, got %', v_count; END IF;

  SELECT COUNT(*) INTO v_count FROM puls_workflow.approval_requests WHERE tenant_id = v_tenant;
  IF v_count < 60 THEN RAISE EXCEPTION 'PR13.11 QA fail: approval requests expected >=60, got %', v_count; END IF;

  SELECT COUNT(*) INTO v_count FROM puls_performance.performance_scores WHERE tenant_id = v_tenant;
  IF v_count <> 45 THEN RAISE EXCEPTION 'PR13.11 QA fail: performance scores expected 45, got %', v_count; END IF;

  SELECT COUNT(*) INTO v_count FROM puls_performance.competency_evaluations WHERE tenant_id = v_tenant;
  IF v_count <> 45 THEN RAISE EXCEPTION 'PR13.11 QA fail: competency evaluations expected 45, got %', v_count; END IF;

  SELECT COUNT(*) INTO v_count FROM puls_workflow.contracts WHERE tenant_id = v_tenant;
  IF v_count <> 20 THEN RAISE EXCEPTION 'PR13.11 QA fail: contracts expected 20, got %', v_count; END IF;

  SELECT COUNT(*) INTO v_count
  FROM auth.users
  WHERE email IN ('admin@puls.demo', 'ik@puls.demo', 'yonetici@puls.demo', 'calisan@puls.demo');
  IF v_count <> 4 THEN RAISE EXCEPTION 'PR13.11 QA fail: expected 4 demo auth users, got %', v_count; END IF;

  SELECT COUNT(*) INTO v_count
  FROM puls_core.employees e
  JOIN auth.users u ON u.id = e.user_id
  WHERE e.tenant_id = v_tenant
    AND u.email IN ('admin@puls.demo', 'ik@puls.demo', 'yonetici@puls.demo', 'calisan@puls.demo');
  IF v_count <> 4 THEN RAISE EXCEPTION 'PR13.11 QA fail: expected 4 linked employees, got %', v_count; END IF;

  SELECT COUNT(*) INTO v_bad_count
  FROM puls_core.employees e
  JOIN auth.users u ON u.id = e.user_id
  WHERE e.tenant_id = v_tenant
    AND (
      (u.email = 'admin@puls.demo' AND e.persona_role NOT IN ('superadmin', 'hr_admin')) OR
      (u.email = 'ik@puls.demo' AND e.persona_role <> 'hr_admin') OR
      (u.email = 'yonetici@puls.demo' AND e.persona_role <> 'manager') OR
      (u.email = 'calisan@puls.demo' AND e.persona_role <> 'employee')
    );
  IF v_bad_count <> 0 THEN RAISE EXCEPTION 'PR13.11 QA fail: linked auth persona role mismatch count %', v_bad_count; END IF;

  SELECT COUNT(*) INTO v_bad_count
  FROM puls_core.employees e
  JOIN auth.users u ON u.id = e.user_id
  WHERE e.tenant_id <> v_tenant
    AND u.email IN ('admin@puls.demo', 'ik@puls.demo', 'yonetici@puls.demo', 'calisan@puls.demo');
  IF v_bad_count <> 0 THEN RAISE EXCEPTION 'PR13.11 QA fail: demo auth users linked to non-target tenant rows %', v_bad_count; END IF;

  SELECT COUNT(*) INTO v_count
  FROM puls_core.employee_reporting_lines rl
  JOIN puls_core.employees employee ON employee.id = rl.employee_id
  JOIN auth.users employee_user ON employee_user.id = employee.user_id
  JOIN puls_core.employees manager ON manager.id = rl.manager_employee_id
  WHERE rl.tenant_id = v_tenant
    AND employee_user.email = 'calisan@puls.demo'
    AND rl.relationship_type = 'primary_manager'
    AND rl.is_active = true
    AND manager.employment_status = 'active';
  IF v_count <> 1 THEN RAISE EXCEPTION 'PR13.11 QA fail: calisan@puls.demo primary manager line expected 1, got %', v_count; END IF;

  SELECT COUNT(*) INTO v_bad_count
  FROM puls_core.employee_reporting_lines
  WHERE tenant_id = v_tenant AND source = 'demo';
  IF v_bad_count <> 0 THEN RAISE EXCEPTION 'PR13.11 QA fail: source=demo reporting rows %', v_bad_count; END IF;

  SELECT COUNT(*) INTO v_bad_count
  FROM puls_core.employee_legal_entity_assignments
  WHERE tenant_id = v_tenant AND source = 'demo';
  IF v_bad_count <> 0 THEN RAISE EXCEPTION 'PR13.11 QA fail: source=demo legal assignment rows %', v_bad_count; END IF;

  SELECT COUNT(*) INTO v_bad_count
  FROM puls_core.employee_location_assignments
  WHERE tenant_id = v_tenant AND source = 'demo';
  IF v_bad_count <> 0 THEN RAISE EXCEPTION 'PR13.11 QA fail: source=demo location assignment rows %', v_bad_count; END IF;

  SELECT COUNT(*) INTO v_bad_count
  FROM puls_core.employee_cost_center_assignments
  WHERE tenant_id = v_tenant AND source = 'demo';
  IF v_bad_count <> 0 THEN RAISE EXCEPTION 'PR13.11 QA fail: source=demo cost center assignment rows %', v_bad_count; END IF;

  SELECT COUNT(*) INTO v_count FROM puls_calc.dashboard_overview WHERE tenant_id = v_tenant;
  IF v_count < 1 THEN RAISE EXCEPTION 'PR13.11 QA fail: dashboard_overview empty'; END IF;

  SELECT COUNT(*) INTO v_count FROM puls_calc.employee_list_overview WHERE tenant_id = v_tenant;
  IF v_count < 1 THEN RAISE EXCEPTION 'PR13.11 QA fail: employee_list_overview empty'; END IF;

  SELECT COUNT(*) INTO v_count FROM puls_calc.organization_overview WHERE tenant_id = v_tenant;
  IF v_count < 1 THEN RAISE EXCEPTION 'PR13.11 QA fail: organization_overview empty'; END IF;

  SELECT COUNT(*) INTO v_count FROM puls_calc.leave_overview WHERE tenant_id = v_tenant;
  IF v_count < 1 THEN RAISE EXCEPTION 'PR13.11 QA fail: leave_overview empty'; END IF;

  SELECT COUNT(*) INTO v_count FROM puls_calc.expense_overview WHERE tenant_id = v_tenant;
  IF v_count < 1 THEN RAISE EXCEPTION 'PR13.11 QA fail: expense_overview empty'; END IF;

  SELECT COUNT(*) INTO v_count FROM puls_calc.performance_overview WHERE tenant_id = v_tenant;
  IF v_count < 1 THEN RAISE EXCEPTION 'PR13.11 QA fail: performance_overview empty'; END IF;

  SELECT COUNT(*) INTO v_count FROM puls_calc.contracts_overview WHERE tenant_id = v_tenant;
  IF v_count < 1 THEN RAISE EXCEPTION 'PR13.11 QA fail: contracts_overview empty'; END IF;

  SELECT COUNT(*) INTO v_count FROM puls_calc.setup_readiness_summary WHERE tenant_id = v_tenant;
  IF v_count < 1 THEN RAISE EXCEPTION 'PR13.11 QA fail: setup_readiness_summary empty'; END IF;

  SELECT COUNT(*) INTO v_count FROM puls_calc.menu_overview WHERE tenant_id = v_tenant;
  IF v_count < 1 THEN RAISE EXCEPTION 'PR13.11 QA fail: menu_overview empty'; END IF;

  SELECT COUNT(*) INTO v_count
  FROM puls_integration.erp_connections
  WHERE tenant_id = v_tenant AND provider = 'canias' AND is_active = false;
  IF v_count < 1 THEN RAISE EXCEPTION 'PR13.11 QA fail: inactive Canias connection missing'; END IF;

  SELECT COUNT(*) INTO v_count
  FROM puls_integration.erp_field_mappings
  WHERE tenant_id = v_tenant;
  IF v_count <> 12 THEN RAISE EXCEPTION 'PR13.11 QA fail: ERP field mappings expected 12, got %', v_count; END IF;

  RAISE NOTICE 'PR13.11 role/route product QA DB validation passed for tenant %', v_tenant;
END $$;
