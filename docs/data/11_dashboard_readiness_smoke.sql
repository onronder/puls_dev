-- 11 PR11.7 Dashboard Readiness — executable smoke (single transaction; rolls back)
-- Asserts tenant-scoped calc/integration reads for dashboard surfaces.
-- Read-only: no fixture inserts or permanent writes.

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_employee_id UUID;
  v_user_id UUID;
  v_current_employee_id UUID;
  v_employee_count INTEGER;
  v_department_count INTEGER;
  v_position_count INTEGER;
  v_competency_template_count INTEGER;
  v_pending_leave_count INTEGER;
  v_pending_expense_count INTEGER;
  v_data_readiness_pct NUMERIC;
  v_active_cycle_name TEXT;
  v_leave_overview_count INTEGER;
  v_expense_overview_count INTEGER;
  v_erp_connections_count INTEGER;
  v_erp_mappings_count INTEGER;
  v_self_leave_count INTEGER;
  v_self_expense_count INTEGER;
BEGIN
  PERFORM set_config('request.jwt.claim.role', 'service_role', true);

  SELECT id INTO v_tenant_id
  FROM puls_core.tenants
  WHERE legacy_public_tenant_id = '11111111-1111-1111-1111-111111111111'
     OR name ILIKE '%Mert Teknik%'
  LIMIT 1;

  IF v_tenant_id IS NULL THEN
    RAISE NOTICE 'SKIP: demo/staging tenant not found';
    RETURN;
  END IF;

  SELECT
    employee_count::INTEGER,
    department_count::INTEGER,
    position_count::INTEGER,
    competency_template_count::INTEGER,
    pending_leave_count::INTEGER,
    pending_expense_count::INTEGER,
    data_readiness_pct,
    active_cycle_name
  INTO
    v_employee_count,
    v_department_count,
    v_position_count,
    v_competency_template_count,
    v_pending_leave_count,
    v_pending_expense_count,
    v_data_readiness_pct,
    v_active_cycle_name
  FROM puls_calc.dashboard_overview
  WHERE tenant_id = v_tenant_id
  LIMIT 1;

  IF v_employee_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL dashboard_overview: tenant-scoped SELECT failed';
  END IF;

  SELECT COUNT(*)::INTEGER INTO v_leave_overview_count
  FROM puls_calc.leave_overview
  WHERE tenant_id = v_tenant_id;

  IF v_leave_overview_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL leave_overview: tenant-scoped SELECT failed';
  END IF;

  SELECT COUNT(*)::INTEGER INTO v_expense_overview_count
  FROM puls_calc.expense_overview
  WHERE tenant_id = v_tenant_id;

  IF v_expense_overview_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL expense_overview: tenant-scoped SELECT failed';
  END IF;

  SELECT COUNT(*)::INTEGER INTO v_erp_connections_count
  FROM puls_integration.erp_connections
  WHERE tenant_id = v_tenant_id;

  IF v_erp_connections_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL erp_connections: tenant-scoped SELECT failed';
  END IF;

  SELECT COUNT(*)::INTEGER INTO v_erp_mappings_count
  FROM puls_integration.erp_field_mappings
  WHERE tenant_id = v_tenant_id;

  IF v_erp_mappings_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL erp_field_mappings: tenant-scoped SELECT failed';
  END IF;

  RAISE NOTICE 'OK: demo_dashboard_readiness_ calc/integration reads for tenant %', v_tenant_id;

  SELECT e.id, e.user_id
  INTO v_employee_id, v_user_id
  FROM puls_core.employees e
  WHERE e.tenant_id = v_tenant_id
    AND e.user_id IS NOT NULL
  LIMIT 1;

  IF v_employee_id IS NOT NULL AND v_user_id IS NOT NULL THEN
    PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
    PERFORM set_config('request.jwt.claim.sub', v_user_id::text, true);

    SELECT puls_core.current_employee_id()
    INTO v_current_employee_id;

    IF v_current_employee_id IS DISTINCT FROM v_employee_id THEN
      RAISE EXCEPTION 'SMOKE_FAIL auth context: current_employee_id mismatch (expected %, got %)',
        v_employee_id, v_current_employee_id;
    END IF;

    SELECT COUNT(*)::INTEGER
    INTO v_self_leave_count
    FROM puls_calc.leave_overview
    WHERE tenant_id = v_tenant_id
      AND employee_id = v_current_employee_id;

    SELECT COUNT(*)::INTEGER
    INTO v_self_expense_count
    FROM puls_calc.expense_overview
    WHERE tenant_id = v_tenant_id
      AND employee_id = v_current_employee_id;

    PERFORM set_config('request.jwt.claim.role', 'service_role', true);
    PERFORM set_config('request.jwt.claim.sub', '', true);

    IF v_self_leave_count > 0 OR v_self_expense_count > 0 THEN
      RAISE NOTICE 'OK: JWT self-scoped leave/expense overview readable (leave=%, expense=%)',
        v_self_leave_count, v_self_expense_count;
    ELSE
      RAISE NOTICE 'SKIP: no employee-scoped leave/expense overview rows for JWT employee';
    END IF;
  ELSE
    RAISE NOTICE 'SKIP: no user-linked employee — JWT self-read not asserted on live data';
  END IF;

  RAISE NOTICE 'demo_dashboard_readiness_ smoke completed for tenant %', v_tenant_id;
END $$;

ROLLBACK;
