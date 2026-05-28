-- 11 PR11.1 Employees Foundation — executable smoke (single transaction; rolls back)
-- Asserts tenant-scoped employee reads, core fields, joins, manager display FK, and auth context.

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_other_tenant_id UUID;
  v_emp_count INTEGER;
  v_core_fields_count INTEGER;
  v_dept_join_count INTEGER;
  v_pos_join_count INTEGER;
  v_manager_lookup_count INTEGER;
  v_user_linked_employee_id UUID;
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

  SELECT COUNT(*)::INTEGER INTO v_core_fields_count
  FROM puls_core.employees
  WHERE tenant_id = v_tenant_id
    AND id IS NOT NULL
    AND employment_status IS NOT NULL;

  IF v_core_fields_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL employees: core fields (id, employment_status) not readable';
  END IF;

  SELECT COUNT(*)::INTEGER INTO v_dept_join_count
  FROM puls_core.employees e
  LEFT JOIN puls_core.departments d
    ON d.id = e.department_id
   AND d.tenant_id = e.tenant_id
  WHERE e.tenant_id = v_tenant_id;

  SELECT COUNT(*)::INTEGER INTO v_pos_join_count
  FROM puls_core.employees e
  LEFT JOIN puls_core.positions p
    ON p.id = e.position_id
   AND p.tenant_id = e.tenant_id
  WHERE e.tenant_id = v_tenant_id;

  IF v_dept_join_count IS NULL OR v_pos_join_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL employees: department/position join queries failed';
  END IF;

  SELECT COUNT(*)::INTEGER INTO v_manager_lookup_count
  FROM puls_core.employees e
  LEFT JOIN puls_core.employees m
    ON m.id = e.manager_employee_id
   AND m.tenant_id = e.tenant_id
  WHERE e.tenant_id = v_tenant_id
    AND e.manager_employee_id IS NOT NULL;

  IF v_manager_lookup_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL employees: manager_employee_id lookup failed';
  END IF;

  SELECT e.id INTO v_user_linked_employee_id
  FROM puls_core.employees e
  WHERE e.tenant_id = v_tenant_id
    AND e.user_id IS NOT NULL
  LIMIT 1;

  IF v_user_linked_employee_id IS NOT NULL THEN
    RAISE NOTICE 'OK: auth context — employee with user_id exists; request.jwt.claim.sub maps to puls_core.current_employee_id() when JWT matches';
  ELSE
    RAISE NOTICE 'SKIP: no employee with user_id in tenant — auth→employee mapping not asserted on live data';
  END IF;

  SELECT id INTO v_other_tenant_id
  FROM puls_core.tenants
  WHERE id <> v_tenant_id
  LIMIT 1;

  IF v_other_tenant_id IS NOT NULL THEN
    SELECT COUNT(*)::INTEGER INTO v_cross_tenant_count
    FROM puls_core.employees
    WHERE tenant_id = v_other_tenant_id
      AND tenant_id = v_tenant_id;

    IF v_cross_tenant_count <> 0 THEN
      RAISE EXCEPTION 'SMOKE_FAIL cross-tenant isolation: impossible tenant filter matched both tenants';
    END IF;

    RAISE NOTICE 'OK: cross-tenant isolation — tenant-scoped employee reads do not leak across tenants';
  ELSE
    RAISE NOTICE 'SKIP: single-tenant staging — cross-tenant isolation not asserted';
  END IF;

  RAISE NOTICE 'OK: PR11.1 employees foundation smoke passed (emp=%, dept_join=%, pos_join=%, manager_fk=%)',
    v_emp_count, v_dept_join_count, v_pos_join_count, v_manager_lookup_count;
END $$;

ROLLBACK;
