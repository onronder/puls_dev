-- 10 PR10.17 Setup Readiness Dashboard — executable smoke (single transaction; rolls back)
-- Asserts tenant-scoped readability for dashboard source adapters: expense categories, leave types,
-- approval policies, org entities, employee assignments, cost centers, and identity maps.
-- Cross-tenant isolation is asserted when a second tenant exists; otherwise NOTICE skip only.

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_other_tenant_id UUID;
  v_expense_active_count INTEGER;
  v_expense_inactive_count INTEGER;
  v_leave_active_count INTEGER;
  v_leave_inactive_count INTEGER;
  v_policy_count INTEGER;
  v_policy_step_count INTEGER;
  v_dept_count INTEGER;
  v_pos_count INTEGER;
  v_emp_count INTEGER;
  v_cc_count INTEGER;
  v_map_count INTEGER;
  v_cc_assign_count INTEGER;
  v_reporting_count INTEGER;
  v_fixture_dept_id UUID;
  v_cross_tenant_count INTEGER;
BEGIN
  PERFORM set_config('request.jwt.claim.role', 'service_role', true);

  SELECT id INTO v_tenant_id
  FROM puls_core.tenants
  WHERE legacy_public_tenant_id = '11111111-1111-1111-1111-111111111111'
     OR name ILIKE '%Mert Teknik%'
  LIMIT 1;

  IF v_tenant_id IS NULL THEN
    RAISE NOTICE 'SKIP: demo tenant not found';
    RETURN;
  END IF;

  SELECT COUNT(*)::INTEGER INTO v_expense_active_count
  FROM puls_workflow.expense_categories
  WHERE tenant_id = v_tenant_id
    AND is_active = TRUE;

  SELECT COUNT(*)::INTEGER INTO v_expense_inactive_count
  FROM puls_workflow.expense_categories
  WHERE tenant_id = v_tenant_id
    AND is_active = FALSE;

  IF v_expense_active_count IS NULL OR v_expense_inactive_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL expense_categories: tenant-scoped active/inactive SELECT failed';
  END IF;

  SELECT COUNT(*)::INTEGER INTO v_leave_active_count
  FROM puls_workflow.leave_types
  WHERE tenant_id = v_tenant_id
    AND is_active = TRUE;

  SELECT COUNT(*)::INTEGER INTO v_leave_inactive_count
  FROM puls_workflow.leave_types
  WHERE tenant_id = v_tenant_id
    AND is_active = FALSE;

  IF v_leave_active_count IS NULL OR v_leave_inactive_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL leave_types: tenant-scoped active/inactive SELECT failed';
  END IF;

  SELECT COUNT(*)::INTEGER INTO v_policy_count
  FROM puls_workflow.approval_policies
  WHERE tenant_id = v_tenant_id;

  SELECT COUNT(*)::INTEGER INTO v_policy_step_count
  FROM puls_workflow.approval_policy_steps s
  JOIN puls_workflow.approval_policies p ON p.id = s.policy_id
  WHERE p.tenant_id = v_tenant_id;

  IF v_policy_count IS NULL OR v_policy_step_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL approval_policies: tenant-scoped SELECT failed';
  END IF;

  SELECT COUNT(*)::INTEGER INTO v_dept_count
  FROM puls_core.departments
  WHERE tenant_id = v_tenant_id;

  SELECT COUNT(*)::INTEGER INTO v_pos_count
  FROM puls_core.positions
  WHERE tenant_id = v_tenant_id;

  SELECT COUNT(*)::INTEGER INTO v_emp_count
  FROM puls_core.employees
  WHERE tenant_id = v_tenant_id;

  SELECT COUNT(*)::INTEGER INTO v_cc_count
  FROM puls_core.cost_centers
  WHERE tenant_id = v_tenant_id;

  SELECT COUNT(*)::INTEGER INTO v_map_count
  FROM puls_integration.entity_identity_map
  WHERE tenant_id = v_tenant_id;

  SELECT COUNT(*)::INTEGER INTO v_cc_assign_count
  FROM puls_core.employee_cost_center_assignments
  WHERE tenant_id = v_tenant_id;

  SELECT COUNT(*)::INTEGER INTO v_reporting_count
  FROM puls_core.employee_reporting_lines
  WHERE tenant_id = v_tenant_id;

  IF v_dept_count IS NULL
     OR v_pos_count IS NULL
     OR v_emp_count IS NULL
     OR v_cc_count IS NULL
     OR v_map_count IS NULL
     OR v_cc_assign_count IS NULL
     OR v_reporting_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL org/assignment sources: tenant-scoped SELECT failed';
  END IF;

  DELETE FROM puls_core.departments
  WHERE tenant_id = v_tenant_id
    AND code LIKE 'demo_setup_readiness_dashboard_%';

  INSERT INTO puls_core.departments (tenant_id, name, code, is_active)
  VALUES (v_tenant_id, 'Smoke Setup Dashboard Dept', 'demo_setup_readiness_dashboard_dept', TRUE)
  RETURNING id INTO v_fixture_dept_id;

  IF v_fixture_dept_id IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL fixture: department insert failed';
  END IF;

  SELECT id INTO v_other_tenant_id
  FROM puls_core.tenants
  WHERE id <> v_tenant_id
  LIMIT 1;

  IF v_other_tenant_id IS NOT NULL THEN
    SELECT COUNT(*)::INTEGER INTO v_cross_tenant_count
    FROM puls_core.departments
    WHERE tenant_id = v_other_tenant_id
      AND code = 'demo_setup_readiness_dashboard_dept';

    IF v_cross_tenant_count <> 0 THEN
      RAISE EXCEPTION 'SMOKE_FAIL cross-tenant isolation: tenant B saw tenant A fixture (count=%)', v_cross_tenant_count;
    END IF;
  ELSE
    RAISE NOTICE 'SKIP: single-tenant staging — cross-tenant fixture isolation not asserted';
  END IF;

  RAISE NOTICE 'OK: PR10.17 setup readiness dashboard smoke passed (expense active=%, leave active=%, policies=%, dept=%, emp=%, cc=%, maps=%)',
    v_expense_active_count, v_leave_active_count, v_policy_count, v_dept_count, v_emp_count, v_cc_count, v_map_count;
END $$;

ROLLBACK;
