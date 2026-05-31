-- PR13.5 — Link auth personas template (no auth.users INSERT, no credentials).
-- Primary path: puls_core.employees.user_id
-- Public bridge only when legacy_public_tenant_id is set (never puls_core.tenants.id).
--
-- Usage:
--   psql "$DATABASE_URL" -v admin_user_id='<uuid>' -v hr_admin_user_id='<uuid>' \
--     -v manager_user_id='<uuid>' -v employee_user_id='<uuid>' \
--     -f sql/05_link_auth_personas_template.sql

\set ON_ERROR_STOP on

\if :{?admin_user_id}
\else
\set admin_user_id '00000000-0000-0000-0000-000000000000'
\endif

\if :{?hr_admin_user_id}
\else
\set hr_admin_user_id '00000000-0000-0000-0000-000000000000'
\endif

\if :{?manager_user_id}
\else
\set manager_user_id '00000000-0000-0000-0000-000000000000'
\endif

\if :{?employee_user_id}
\else
\set employee_user_id '00000000-0000-0000-0000-000000000000'
\endif

\if :{?incomplete_setup_user_id}
\else
\set incomplete_setup_user_id '00000000-0000-0000-0000-000000000000'
\endif

-- psql :'var' substitution does not run inside dollar-quoted DO bodies — stage vars first.
CREATE TEMP TABLE IF NOT EXISTS pr13_psql_vars (
  key text PRIMARY KEY,
  raw_value text NOT NULL
);
TRUNCATE pr13_psql_vars;
INSERT INTO pr13_psql_vars (key, raw_value) VALUES
  ('admin_user_id', :'admin_user_id'),
  ('hr_admin_user_id', :'hr_admin_user_id'),
  ('manager_user_id', :'manager_user_id'),
  ('employee_user_id', :'employee_user_id'),
  ('incomplete_setup_user_id', :'incomplete_setup_user_id');

DO $$
DECLARE
  v_tenant uuid := 'a0000001-0001-4001-8001-000000000001';
  v_zero uuid := '00000000-0000-0000-0000-000000000000';
  v_admin uuid;
  v_hr uuid;
  v_manager uuid;
  v_employee uuid;
  v_incomplete uuid;
  v_legacy_public_tenant_id uuid;
  v_has_user_tenants boolean;
  v_has_user_roles boolean;
  v_ut_cols_ok boolean;
  v_ur_cols_ok boolean;
  v_role_udt text;
  v_emp_superadmin uuid := 'a0000006-0006-4006-8006-000000000001';
  v_emp_hr_admin uuid := 'a0000006-0006-4006-8006-000000000006';
  v_emp_manager uuid := 'a0000006-0006-4006-8006-000000000021';
  v_emp_employee uuid := 'a0000006-0006-4006-8006-000000000023';
  v_raw text;
BEGIN
  SELECT raw_value INTO v_raw FROM pr13_psql_vars WHERE key = 'admin_user_id';
  v_admin := NULLIF(NULLIF(BTRIM(COALESCE(v_raw, '')), ''), v_zero::text)::uuid;
  SELECT raw_value INTO v_raw FROM pr13_psql_vars WHERE key = 'hr_admin_user_id';
  v_hr := NULLIF(NULLIF(BTRIM(COALESCE(v_raw, '')), ''), v_zero::text)::uuid;
  SELECT raw_value INTO v_raw FROM pr13_psql_vars WHERE key = 'manager_user_id';
  v_manager := NULLIF(NULLIF(BTRIM(COALESCE(v_raw, '')), ''), v_zero::text)::uuid;
  SELECT raw_value INTO v_raw FROM pr13_psql_vars WHERE key = 'employee_user_id';
  v_employee := NULLIF(NULLIF(BTRIM(COALESCE(v_raw, '')), ''), v_zero::text)::uuid;
  SELECT raw_value INTO v_raw FROM pr13_psql_vars WHERE key = 'incomplete_setup_user_id';
  v_incomplete := NULLIF(NULLIF(BTRIM(COALESCE(v_raw, '')), ''), v_zero::text)::uuid;

  IF v_admin IS NOT NULL THEN
    UPDATE puls_core.employees SET user_id = v_admin, updated_at = NOW()
    WHERE id = v_emp_superadmin AND tenant_id = v_tenant;
    RAISE NOTICE 'Linked superadmin (PS-001) -> %', v_admin;
  ELSE
    RAISE NOTICE 'SKIP: admin_user_id not provided';
  END IF;

  IF v_hr IS NOT NULL THEN
    UPDATE puls_core.employees SET user_id = v_hr, updated_at = NOW()
    WHERE id = v_emp_hr_admin AND tenant_id = v_tenant;
    RAISE NOTICE 'Linked hr_admin (PS-006) -> %', v_hr;
  ELSE
    RAISE NOTICE 'SKIP: hr_admin_user_id not provided';
  END IF;

  IF v_manager IS NOT NULL THEN
    UPDATE puls_core.employees SET user_id = v_manager, updated_at = NOW()
    WHERE id = v_emp_manager AND tenant_id = v_tenant;
    RAISE NOTICE 'Linked manager (PS-021) -> %', v_manager;
  ELSE
    RAISE NOTICE 'SKIP: manager_user_id not provided';
  END IF;

  IF v_employee IS NOT NULL THEN
    UPDATE puls_core.employees SET user_id = v_employee, updated_at = NOW()
    WHERE id = v_emp_employee AND tenant_id = v_tenant;
    RAISE NOTICE 'Linked employee (PS-023) -> %', v_employee;
  ELSE
    RAISE NOTICE 'SKIP: employee_user_id not provided';
  END IF;

  SELECT legacy_public_tenant_id INTO v_legacy_public_tenant_id
  FROM puls_core.tenants WHERE id = v_tenant;

  IF v_legacy_public_tenant_id IS NULL THEN
    RAISE NOTICE 'SKIP: no legacy_public_tenant_id — public bridge not attempted';
    RETURN;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'user_tenants'
  ) INTO v_has_user_tenants;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'user_roles'
  ) INTO v_has_user_roles;

  SELECT COUNT(*) = 3 INTO v_ut_cols_ok
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'user_tenants'
    AND column_name IN ('user_id', 'tenant_id', 'is_default');

  SELECT COUNT(*) = 3 INTO v_ur_cols_ok
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'user_roles'
    AND column_name IN ('user_id', 'tenant_id', 'role');

  IF NOT v_has_user_tenants OR NOT v_ut_cols_ok THEN
    RAISE NOTICE 'SKIP: public.user_tenants missing or required columns absent';
    RETURN;
  END IF;

  IF v_admin IS NOT NULL THEN
    INSERT INTO public.user_tenants (user_id, tenant_id, is_default)
    SELECT v_admin, v_legacy_public_tenant_id, TRUE
    WHERE NOT EXISTS (
      SELECT 1 FROM public.user_tenants ut
      WHERE ut.user_id = v_admin AND ut.tenant_id = v_legacy_public_tenant_id
    );
  END IF;

  IF v_manager IS NOT NULL THEN
    INSERT INTO public.user_tenants (user_id, tenant_id, is_default)
    SELECT v_manager, v_legacy_public_tenant_id, FALSE
    WHERE NOT EXISTS (
      SELECT 1 FROM public.user_tenants ut
      WHERE ut.user_id = v_manager AND ut.tenant_id = v_legacy_public_tenant_id
    );
  END IF;

  IF v_employee IS NOT NULL THEN
    INSERT INTO public.user_tenants (user_id, tenant_id, is_default)
    SELECT v_employee, v_legacy_public_tenant_id, FALSE
    WHERE NOT EXISTS (
      SELECT 1 FROM public.user_tenants ut
      WHERE ut.user_id = v_employee AND ut.tenant_id = v_legacy_public_tenant_id
    );
  END IF;

  IF v_incomplete IS NOT NULL THEN
    INSERT INTO public.user_tenants (user_id, tenant_id, is_default)
    SELECT v_incomplete, v_legacy_public_tenant_id, FALSE
    WHERE NOT EXISTS (
      SELECT 1 FROM public.user_tenants ut
      WHERE ut.user_id = v_incomplete AND ut.tenant_id = v_legacy_public_tenant_id
    );
    RAISE NOTICE 'Incomplete-setup edge: user_tenants only for %', v_incomplete;
  END IF;

  IF NOT v_has_user_roles OR NOT v_ur_cols_ok THEN
    RAISE NOTICE 'SKIP: public.user_roles missing or required columns absent';
    RETURN;
  END IF;

  SELECT c.udt_name INTO v_role_udt
  FROM information_schema.columns c
  WHERE c.table_schema = 'public'
    AND c.table_name = 'user_roles'
    AND c.column_name = 'role';

  IF v_manager IS NOT NULL THEN
    IF v_role_udt = 'app_role' THEN
      INSERT INTO public.user_roles (user_id, tenant_id, role)
      SELECT v_manager, v_legacy_public_tenant_id, 'yonetici'::public.app_role
      WHERE NOT EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = v_manager AND ur.tenant_id = v_legacy_public_tenant_id
      );
    ELSE
      INSERT INTO public.user_roles (user_id, tenant_id, role)
      SELECT v_manager, v_legacy_public_tenant_id, 'yonetici'
      WHERE NOT EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = v_manager AND ur.tenant_id = v_legacy_public_tenant_id
      );
    END IF;
  END IF;

  IF v_hr IS NOT NULL THEN
    IF v_role_udt = 'app_role' THEN
      INSERT INTO public.user_roles (user_id, tenant_id, role)
      SELECT v_hr, v_legacy_public_tenant_id, 'ik_admin'::public.app_role
      WHERE NOT EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = v_hr AND ur.tenant_id = v_legacy_public_tenant_id
      );
    ELSE
      INSERT INTO public.user_roles (user_id, tenant_id, role)
      SELECT v_hr, v_legacy_public_tenant_id, 'ik_admin'
      WHERE NOT EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = v_hr AND ur.tenant_id = v_legacy_public_tenant_id
      );
    END IF;
  END IF;
END $$;
