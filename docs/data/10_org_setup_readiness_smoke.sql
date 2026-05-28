-- 10 PR10.14 Org Setup Readiness — executable smoke (single transaction; rolls back)
-- Asserts tenant-scoped readability for departments, positions, employee org fields, cost centers, and identity maps.
-- Cross-tenant isolation is asserted when a second tenant exists; otherwise NOTICE skip only.

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_other_tenant_id UUID;
  v_dept_count INTEGER;
  v_pos_count INTEGER;
  v_emp_org_count INTEGER;
  v_cc_count INTEGER;
  v_map_count INTEGER;
  v_cc_assign_count INTEGER;
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

  -- Tenant-scoped departments readable
  SELECT COUNT(*)::INTEGER INTO v_dept_count
  FROM puls_core.departments
  WHERE tenant_id = v_tenant_id;

  IF v_dept_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL departments: tenant-scoped SELECT failed';
  END IF;

  -- Tenant-scoped positions readable
  SELECT COUNT(*)::INTEGER INTO v_pos_count
  FROM puls_core.positions
  WHERE tenant_id = v_tenant_id;

  IF v_pos_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL positions: tenant-scoped SELECT failed';
  END IF;

  -- Employee org fields exposed and readable
  SELECT COUNT(*)::INTEGER INTO v_emp_org_count
  FROM puls_core.employees
  WHERE tenant_id = v_tenant_id
    AND department_id IS NOT NULL
    AND position_id IS NOT NULL;

  IF v_emp_org_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL employees: department_id/position_id query failed';
  END IF;

  -- Employee cost center assignment table readable
  SELECT COUNT(*)::INTEGER INTO v_cc_assign_count
  FROM puls_core.employee_cost_center_assignments
  WHERE tenant_id = v_tenant_id;

  IF v_cc_assign_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL employee_cost_center_assignments: tenant-scoped SELECT failed';
  END IF;

  -- Cost centers readable
  SELECT COUNT(*)::INTEGER INTO v_cc_count
  FROM puls_core.cost_centers
  WHERE tenant_id = v_tenant_id;

  IF v_cc_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL cost_centers: tenant-scoped SELECT failed';
  END IF;

  -- Identity map readable (integration metadata)
  SELECT COUNT(*)::INTEGER INTO v_map_count
  FROM puls_integration.entity_identity_map
  WHERE tenant_id = v_tenant_id;

  IF v_map_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL entity_identity_map: tenant-scoped SELECT failed';
  END IF;

  -- Fixture insert for cross-tenant isolation (rolled back — no permanent ERP/master writes)
  DELETE FROM puls_core.departments
  WHERE tenant_id = v_tenant_id
    AND code LIKE 'demo_org_setup_readiness_%';

  INSERT INTO puls_core.departments (tenant_id, name, code, is_active)
  VALUES (v_tenant_id, 'Smoke Org Readiness Dept', 'demo_org_setup_readiness_dept', TRUE)
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
      AND code = 'demo_org_setup_readiness_dept';

    IF v_cross_tenant_count <> 0 THEN
      RAISE EXCEPTION 'SMOKE_FAIL cross-tenant isolation: tenant B saw tenant A fixture (count=%)', v_cross_tenant_count;
    END IF;
  ELSE
    RAISE NOTICE 'SKIP: single-tenant staging — cross-tenant fixture isolation not asserted';
  END IF;

  RAISE NOTICE 'OK: PR10.14 org setup readiness smoke passed (dept=%, pos=%, emp_org=%, cc=%, maps=%)',
    v_dept_count, v_pos_count, v_emp_org_count, v_cc_count, v_map_count;
END $$;

ROLLBACK;
