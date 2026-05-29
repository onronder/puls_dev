-- 11 PR11.8 Profile Account Readiness — executable smoke (single transaction; rolls back)
-- Asserts auth→employee mapping reads, calc profile surfaces, and optional JWT context.
-- Read-only: no fixture inserts or permanent writes.

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_legacy_public_tenant_id UUID;
  v_employee_id UUID;
  v_user_id UUID;
  v_current_employee_id UUID;
  v_current_tenant_id UUID;
  v_employees_count INTEGER;
  v_user_tenants_count INTEGER;
  v_user_roles_count INTEGER;
  v_leave_overview_count INTEGER;
  v_expense_overview_count INTEGER;
  v_performance_overview_count INTEGER;
  v_self_leave_count INTEGER;
  v_self_expense_count INTEGER;
  v_self_performance_count INTEGER;
  v_profiles_exists BOOLEAN;
  v_tenant_without_employee_count INTEGER;
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

  SELECT legacy_public_tenant_id
  INTO v_legacy_public_tenant_id
  FROM puls_core.tenants
  WHERE id = v_tenant_id
  LIMIT 1;

  SELECT COUNT(*)::INTEGER INTO v_employees_count
  FROM puls_core.employees
  WHERE tenant_id = v_tenant_id;

  IF v_employees_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL employees: tenant-scoped SELECT failed';
  END IF;

  IF v_legacy_public_tenant_id IS NOT NULL THEN
    SELECT COUNT(*)::INTEGER INTO v_user_tenants_count
    FROM public.user_tenants
    WHERE tenant_id = v_legacy_public_tenant_id;

    IF v_user_tenants_count IS NULL THEN
      RAISE EXCEPTION 'SMOKE_FAIL user_tenants: tenant-scoped SELECT failed';
    END IF;

    SELECT COUNT(*)::INTEGER INTO v_user_roles_count
    FROM public.user_roles
    WHERE tenant_id = v_legacy_public_tenant_id;

    IF v_user_roles_count IS NULL THEN
      RAISE EXCEPTION 'SMOKE_FAIL user_roles: tenant-scoped SELECT failed';
    END IF;

    SELECT COUNT(*)::INTEGER
    INTO v_tenant_without_employee_count
    FROM public.user_tenants ut
    WHERE ut.tenant_id = v_legacy_public_tenant_id
      AND NOT EXISTS (
        SELECT 1
        FROM puls_core.employees e
        WHERE e.tenant_id = v_tenant_id
          AND e.user_id = ut.user_id
      );

    IF v_tenant_without_employee_count > 0 THEN
      RAISE NOTICE 'NOTICE: demo_profile_account_readiness_ tenant_without_employee memberships=%',
        v_tenant_without_employee_count;
    END IF;
  ELSE
    RAISE NOTICE 'SKIP: tenant has no legacy_public_tenant_id — public.user_tenants not asserted';
  END IF;

  SELECT to_regclass('public.profiles') IS NOT NULL INTO v_profiles_exists;

  IF v_profiles_exists THEN
    PERFORM 1 FROM public.profiles LIMIT 1;
    RAISE NOTICE 'OK: public.profiles readable';
  ELSE
    RAISE NOTICE 'SKIP: public.profiles table not present';
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

  SELECT COUNT(*)::INTEGER INTO v_performance_overview_count
  FROM puls_calc.performance_overview
  WHERE tenant_id = v_tenant_id;

  IF v_performance_overview_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL performance_overview: tenant-scoped SELECT failed';
  END IF;

  RAISE NOTICE 'OK: demo_profile_account_readiness_ account/calc reads for tenant %', v_tenant_id;

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

    SELECT puls_core.current_tenant_id()
    INTO v_current_tenant_id;

    IF v_current_tenant_id IS DISTINCT FROM v_tenant_id THEN
      RAISE EXCEPTION 'SMOKE_FAIL auth context: current_tenant_id mismatch (expected %, got %)',
        v_tenant_id, v_current_tenant_id;
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

    SELECT COUNT(*)::INTEGER
    INTO v_self_performance_count
    FROM puls_calc.performance_overview
    WHERE tenant_id = v_tenant_id
      AND employee_id = v_current_employee_id;

    PERFORM set_config('request.jwt.claim.role', 'service_role', true);
    PERFORM set_config('request.jwt.claim.sub', '', true);

    IF v_self_leave_count > 0 OR v_self_expense_count > 0 OR v_self_performance_count > 0 THEN
      RAISE NOTICE 'OK: JWT self-scoped profile calc reads (leave=%, expense=%, performance=%)',
        v_self_leave_count, v_self_expense_count, v_self_performance_count;
    ELSE
      RAISE NOTICE 'SKIP: no employee-scoped leave/expense/performance overview rows for JWT employee';
    END IF;
  ELSE
    RAISE NOTICE 'SKIP: no user-linked employee — JWT self-read not asserted on live data';
  END IF;

  RAISE NOTICE 'demo_profile_account_readiness_ smoke completed for tenant %', v_tenant_id;
END $$;

ROLLBACK;
