-- PR17.1B core org lifecycle hardening.
-- Adds safe soft-deactivate/restore RPCs for PULS-owned departments and
-- positions. No hard delete, connector execution, notification producer,
-- external delivery, or UI payload readback.

CREATE OR REPLACE FUNCTION puls_core._org_lifecycle_assert_admin()
RETURNS UUID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
DECLARE
  v_tenant_id UUID := puls_core.current_tenant_id();
BEGIN
  IF v_tenant_id IS NULL OR NOT puls_core.is_admin() THEN
    RAISE EXCEPTION 'PULS_ORG_LIFECYCLE_FORBIDDEN: organization lifecycle changes require an admin in the current tenant.'
      USING ERRCODE = 'P0001';
  END IF;

  RETURN v_tenant_id;
END;
$$;

CREATE OR REPLACE FUNCTION puls_core.deactivate_department(p_department_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
DECLARE
  v_tenant_id UUID := puls_core._org_lifecycle_assert_admin();
  v_department puls_core.departments;
  v_active_employee_count INTEGER := 0;
  v_active_position_count INTEGER := 0;
BEGIN
  SELECT d.* INTO v_department
  FROM puls_core.departments d
  WHERE d.id = p_department_id
    AND d.tenant_id = v_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_ORG_DEPARTMENT_NOT_FOUND: department was not found for this tenant.'
      USING ERRCODE = 'P0001';
  END IF;

  IF NULLIF(BTRIM(v_department.external_source), '') IS NOT NULL THEN
    RAISE EXCEPTION 'PULS_ORG_DEPARTMENT_SOURCE_READ_ONLY: imported departments cannot be changed locally.'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT v_department.is_active THEN
    RETURN jsonb_build_object(
      'status', 'already_inactive',
      'department_id', v_department.id
    );
  END IF;

  SELECT COUNT(*)::INTEGER INTO v_active_employee_count
  FROM puls_core.employees e
  WHERE e.tenant_id = v_tenant_id
    AND e.department_id = v_department.id
    AND e.employment_status = 'active';

  IF v_active_employee_count > 0 THEN
    RAISE EXCEPTION 'PULS_ORG_DEPARTMENT_IN_USE_ACTIVE_EMPLOYEES: department has active employees.'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT COUNT(*)::INTEGER INTO v_active_position_count
  FROM puls_core.positions p
  WHERE p.tenant_id = v_tenant_id
    AND p.department_id = v_department.id
    AND p.is_active = TRUE;

  IF v_active_position_count > 0 THEN
    RAISE EXCEPTION 'PULS_ORG_DEPARTMENT_IN_USE_ACTIVE_POSITIONS: department has active positions.'
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE puls_core.departments
  SET is_active = FALSE,
      updated_at = NOW()
  WHERE id = v_department.id;

  RETURN jsonb_build_object(
    'status', 'deactivated',
    'department_id', v_department.id
  );
END;
$$;

CREATE OR REPLACE FUNCTION puls_core.restore_department(p_department_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
DECLARE
  v_tenant_id UUID := puls_core._org_lifecycle_assert_admin();
  v_department puls_core.departments;
BEGIN
  SELECT d.* INTO v_department
  FROM puls_core.departments d
  WHERE d.id = p_department_id
    AND d.tenant_id = v_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_ORG_DEPARTMENT_NOT_FOUND: department was not found for this tenant.'
      USING ERRCODE = 'P0001';
  END IF;

  IF NULLIF(BTRIM(v_department.external_source), '') IS NOT NULL THEN
    RAISE EXCEPTION 'PULS_ORG_DEPARTMENT_SOURCE_READ_ONLY: imported departments cannot be changed locally.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_department.is_active THEN
    RETURN jsonb_build_object(
      'status', 'already_active',
      'department_id', v_department.id
    );
  END IF;

  IF v_department.parent_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1
       FROM puls_core.departments parent
       WHERE parent.id = v_department.parent_id
         AND parent.tenant_id = v_tenant_id
         AND parent.is_active = TRUE
     ) THEN
    RAISE EXCEPTION 'PULS_ORG_DEPARTMENT_PARENT_INACTIVE: parent department must be active before restore.'
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE puls_core.departments
  SET is_active = TRUE,
      updated_at = NOW()
  WHERE id = v_department.id;

  RETURN jsonb_build_object(
    'status', 'restored',
    'department_id', v_department.id
  );
END;
$$;

CREATE OR REPLACE FUNCTION puls_core.deactivate_position(p_position_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
DECLARE
  v_tenant_id UUID := puls_core._org_lifecycle_assert_admin();
  v_position puls_core.positions;
  v_active_employee_count INTEGER := 0;
BEGIN
  SELECT p.* INTO v_position
  FROM puls_core.positions p
  WHERE p.id = p_position_id
    AND p.tenant_id = v_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_ORG_POSITION_NOT_FOUND: position was not found for this tenant.'
      USING ERRCODE = 'P0001';
  END IF;

  IF NULLIF(BTRIM(v_position.external_source), '') IS NOT NULL THEN
    RAISE EXCEPTION 'PULS_ORG_POSITION_SOURCE_READ_ONLY: imported positions cannot be changed locally.'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT v_position.is_active THEN
    RETURN jsonb_build_object(
      'status', 'already_inactive',
      'position_id', v_position.id
    );
  END IF;

  SELECT COUNT(*)::INTEGER INTO v_active_employee_count
  FROM puls_core.employees e
  WHERE e.tenant_id = v_tenant_id
    AND e.position_id = v_position.id
    AND e.employment_status = 'active';

  IF v_active_employee_count > 0 THEN
    RAISE EXCEPTION 'PULS_ORG_POSITION_IN_USE_ACTIVE_EMPLOYEES: position has active employees.'
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE puls_core.positions
  SET is_active = FALSE,
      updated_at = NOW()
  WHERE id = v_position.id;

  RETURN jsonb_build_object(
    'status', 'deactivated',
    'position_id', v_position.id
  );
END;
$$;

CREATE OR REPLACE FUNCTION puls_core.restore_position(p_position_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
DECLARE
  v_tenant_id UUID := puls_core._org_lifecycle_assert_admin();
  v_position puls_core.positions;
BEGIN
  SELECT p.* INTO v_position
  FROM puls_core.positions p
  WHERE p.id = p_position_id
    AND p.tenant_id = v_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_ORG_POSITION_NOT_FOUND: position was not found for this tenant.'
      USING ERRCODE = 'P0001';
  END IF;

  IF NULLIF(BTRIM(v_position.external_source), '') IS NOT NULL THEN
    RAISE EXCEPTION 'PULS_ORG_POSITION_SOURCE_READ_ONLY: imported positions cannot be changed locally.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_position.is_active THEN
    RETURN jsonb_build_object(
      'status', 'already_active',
      'position_id', v_position.id
    );
  END IF;

  IF v_position.department_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1
       FROM puls_core.departments d
       WHERE d.id = v_position.department_id
         AND d.tenant_id = v_tenant_id
         AND d.is_active = TRUE
     ) THEN
    RAISE EXCEPTION 'PULS_ORG_POSITION_DEPARTMENT_INACTIVE: department must be active before restore.'
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE puls_core.positions
  SET is_active = TRUE,
      updated_at = NOW()
  WHERE id = v_position.id;

  RETURN jsonb_build_object(
    'status', 'restored',
    'position_id', v_position.id
  );
END;
$$;

REVOKE ALL ON FUNCTION puls_core._org_lifecycle_assert_admin() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION puls_core._org_lifecycle_assert_admin() TO service_role;

REVOKE ALL ON FUNCTION puls_core.deactivate_department(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION puls_core.deactivate_department(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_core.restore_department(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION puls_core.restore_department(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_core.deactivate_position(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION puls_core.deactivate_position(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_core.restore_position(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION puls_core.restore_position(UUID) TO authenticated, service_role;

COMMENT ON FUNCTION puls_core.deactivate_department(UUID)
  IS 'PR17.1B soft-deactivates PULS-owned departments only when no active employees or active positions depend on them. Emits audit through PR17.1A row audit trigger.';

COMMENT ON FUNCTION puls_core.restore_department(UUID)
  IS 'PR17.1B restores PULS-owned departments when parent lifecycle allows it. Emits audit through PR17.1A row audit trigger.';

COMMENT ON FUNCTION puls_core.deactivate_position(UUID)
  IS 'PR17.1B soft-deactivates PULS-owned positions only when no active employees depend on them. Emits audit through PR17.1A row audit trigger.';

COMMENT ON FUNCTION puls_core.restore_position(UUID)
  IS 'PR17.1B restores PULS-owned positions when the linked department lifecycle allows it. Emits audit through PR17.1A row audit trigger.';
