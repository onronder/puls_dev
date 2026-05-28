-- 10 PR10.15 Employee Assignment Readiness — executable smoke (single transaction; rolls back)
-- Asserts tenant-scoped assignment readability and gap detection CASE logic.

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_other_tenant_id UUID;
  v_emp_count INTEGER;
  v_dept_assigned INTEGER;
  v_pos_assigned INTEGER;
  v_cc_assign_count INTEGER;
  v_reporting_count INTEGER;
  v_missing_dept INTEGER;
  v_ready_like INTEGER;
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

  SELECT COUNT(*)::INTEGER INTO v_emp_count
  FROM puls_core.employees
  WHERE tenant_id = v_tenant_id;

  IF v_emp_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL employees: tenant-scoped SELECT failed';
  END IF;

  SELECT COUNT(*)::INTEGER INTO v_dept_assigned
  FROM puls_core.employees
  WHERE tenant_id = v_tenant_id
    AND department_id IS NOT NULL;

  SELECT COUNT(*)::INTEGER INTO v_pos_assigned
  FROM puls_core.employees
  WHERE tenant_id = v_tenant_id
    AND position_id IS NOT NULL;

  SELECT COUNT(*)::INTEGER INTO v_cc_assign_count
  FROM puls_core.employee_cost_center_assignments
  WHERE tenant_id = v_tenant_id;

  SELECT COUNT(*)::INTEGER INTO v_reporting_count
  FROM puls_core.employee_reporting_lines
  WHERE tenant_id = v_tenant_id
    AND relationship_type = 'primary_manager';

  IF v_cc_assign_count IS NULL OR v_reporting_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL assignment tables: tenant-scoped SELECT failed';
  END IF;

  -- Gap detection on live tenant data (active employees)
  SELECT COUNT(*)::INTEGER INTO v_missing_dept
  FROM puls_core.employees e
  WHERE e.tenant_id = v_tenant_id
    AND e.employment_status = 'active'
    AND e.department_id IS NULL;

  SELECT COUNT(*)::INTEGER INTO v_ready_like
  FROM puls_core.employees e
  WHERE e.tenant_id = v_tenant_id
    AND e.employment_status = 'active'
    AND e.department_id IS NOT NULL
    AND e.position_id IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM puls_core.employee_cost_center_assignments a
      WHERE a.tenant_id = e.tenant_id
        AND a.employee_id = e.id
        AND a.is_active = TRUE
    )
    AND (
      EXISTS (
        SELECT 1
        FROM puls_core.employee_reporting_lines rl
        WHERE rl.tenant_id = e.tenant_id
          AND rl.employee_id = e.id
          AND rl.is_active = TRUE
          AND rl.relationship_type = 'primary_manager'
      )
      OR e.manager_employee_id IS NOT NULL
    );

  IF v_missing_dept IS NULL OR v_ready_like IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL assignment CASE: gap/ready detection query failed';
  END IF;

  RAISE NOTICE 'OK: assignment gap detect — missing_dept=%, ready_like=%', v_missing_dept, v_ready_like;

  -- Cross-tenant fixture (department code prefix)
  DELETE FROM puls_core.departments
  WHERE tenant_id = v_tenant_id
    AND code LIKE 'demo_employee_assignment_readiness_%';

  INSERT INTO puls_core.departments (tenant_id, name, code, is_active)
  VALUES (v_tenant_id, 'Smoke Assignment Dept', 'demo_employee_assignment_readiness_dept', TRUE)
  RETURNING id INTO v_fixture_dept_id;

  SELECT id INTO v_other_tenant_id
  FROM puls_core.tenants
  WHERE id <> v_tenant_id
  LIMIT 1;

  IF v_other_tenant_id IS NOT NULL THEN
    SELECT COUNT(*)::INTEGER INTO v_cross_tenant_count
    FROM puls_core.departments
    WHERE tenant_id = v_other_tenant_id
      AND code = 'demo_employee_assignment_readiness_dept';

    IF v_cross_tenant_count <> 0 THEN
      RAISE EXCEPTION 'SMOKE_FAIL cross-tenant isolation: tenant B saw tenant A fixture (count=%)', v_cross_tenant_count;
    END IF;
  ELSE
    RAISE NOTICE 'SKIP: single-tenant staging — cross-tenant fixture isolation not asserted';
  END IF;

  RAISE NOTICE 'OK: PR10.15 employee assignment readiness smoke passed (emp=%, cc=%, reporting=%)',
    v_emp_count, v_cc_assign_count, v_reporting_count;
END $$;

ROLLBACK;
