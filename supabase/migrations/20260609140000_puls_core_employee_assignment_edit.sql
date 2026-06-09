-- PR17.1C employee assignment edit.
-- Adds one safe assignment RPC for PULS-owned employees. No employee create,
-- hard delete, connector runtime, external system write, credential readback, or
-- raw import payload readback.

CREATE OR REPLACE FUNCTION puls_core._employee_assignment_assert_admin()
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
    RAISE EXCEPTION 'PULS_EMPLOYEE_ASSIGNMENT_FORBIDDEN: employee assignment changes require an admin in the current tenant.'
      USING ERRCODE = 'P0001';
  END IF;

  RETURN v_tenant_id;
END;
$$;

CREATE OR REPLACE FUNCTION puls_core.update_employee_assignment(
  p_employee_id UUID,
  p_department_id UUID DEFAULT NULL,
  p_position_id UUID DEFAULT NULL,
  p_cost_center_id UUID DEFAULT NULL,
  p_manager_employee_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_core, puls_audit
AS $$
DECLARE
  v_tenant_id UUID := puls_core._employee_assignment_assert_admin();
  v_actor_employee_id UUID;
  v_employee puls_core.employees;
  v_old_department_id UUID;
  v_old_position_id UUID;
  v_old_manager_employee_id UUID;
  v_old_cost_center_id UUID;
  v_active_reporting_line_id UUID;
  v_current_manager_id UUID;
  v_active_cost_center_assignment_id UUID;
  v_position_department_id UUID;
  v_changed_fields TEXT[] := ARRAY[]::TEXT[];
BEGIN
  SELECT e.id
  INTO v_actor_employee_id
  FROM puls_core.employees e
  WHERE e.user_id = auth.uid()
    AND e.tenant_id = v_tenant_id
  LIMIT 1;

  SELECT e.*
  INTO v_employee
  FROM puls_core.employees e
  WHERE e.id = p_employee_id
    AND e.tenant_id = v_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_EMPLOYEE_ASSIGNMENT_NOT_FOUND: employee was not found for this tenant.'
      USING ERRCODE = 'P0001';
  END IF;

  IF NULLIF(BTRIM(v_employee.external_source), '') IS NOT NULL THEN
    RAISE EXCEPTION 'PULS_EMPLOYEE_ASSIGNMENT_SOURCE_READ_ONLY: imported employees cannot be changed locally.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_employee.employment_status::TEXT <> 'active' THEN
    RAISE EXCEPTION 'PULS_EMPLOYEE_ASSIGNMENT_INACTIVE_EMPLOYEE: inactive employees cannot be reassigned from this screen.'
      USING ERRCODE = 'P0001';
  END IF;

  IF p_department_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1
       FROM puls_core.departments d
       WHERE d.id = p_department_id
         AND d.tenant_id = v_tenant_id
         AND d.is_active = TRUE
     ) THEN
    RAISE EXCEPTION 'PULS_EMPLOYEE_ASSIGNMENT_INVALID_DEPARTMENT: department is missing, inactive, or cross-tenant.'
      USING ERRCODE = 'P0001';
  END IF;

  IF p_position_id IS NOT NULL THEN
    SELECT p.department_id
    INTO v_position_department_id
    FROM puls_core.positions p
    WHERE p.id = p_position_id
      AND p.tenant_id = v_tenant_id
      AND p.is_active = TRUE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'PULS_EMPLOYEE_ASSIGNMENT_INVALID_POSITION: position is missing, inactive, or cross-tenant.'
        USING ERRCODE = 'P0001';
    END IF;

    IF v_position_department_id IS NOT NULL
       AND p_department_id IS DISTINCT FROM v_position_department_id THEN
      RAISE EXCEPTION 'PULS_EMPLOYEE_ASSIGNMENT_POSITION_DEPARTMENT_MISMATCH: position must belong to the selected department.'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  IF p_cost_center_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1
       FROM puls_core.cost_centers cc
       WHERE cc.id = p_cost_center_id
         AND cc.tenant_id = v_tenant_id
         AND cc.is_active = TRUE
     ) THEN
    RAISE EXCEPTION 'PULS_EMPLOYEE_ASSIGNMENT_INVALID_COST_CENTER: cost center is missing, inactive, or cross-tenant.'
      USING ERRCODE = 'P0001';
  END IF;

  IF p_manager_employee_id IS NOT NULL THEN
    IF p_manager_employee_id = p_employee_id THEN
      RAISE EXCEPTION 'PULS_EMPLOYEE_ASSIGNMENT_SELF_MANAGER: employee cannot report to self.'
        USING ERRCODE = 'P0001';
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM puls_core.employees manager
      WHERE manager.id = p_manager_employee_id
        AND manager.tenant_id = v_tenant_id
        AND manager.employment_status = 'active'
    ) THEN
      RAISE EXCEPTION 'PULS_EMPLOYEE_ASSIGNMENT_INVALID_MANAGER: manager is missing, inactive, or cross-tenant.'
        USING ERRCODE = 'P0001';
    END IF;

    IF puls_core.detect_reporting_cycle(v_tenant_id, p_employee_id, p_manager_employee_id) THEN
      RAISE EXCEPTION 'PULS_EMPLOYEE_ASSIGNMENT_MANAGER_CYCLE: manager assignment would create a reporting cycle.'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  SELECT rl.id, rl.manager_employee_id
  INTO v_active_reporting_line_id, v_current_manager_id
  FROM puls_core.employee_reporting_lines rl
  WHERE rl.tenant_id = v_tenant_id
    AND rl.employee_id = p_employee_id
    AND rl.relationship_type = 'primary_manager'::puls_core.reporting_relationship_type
    AND rl.is_active = TRUE
  ORDER BY rl.starts_on DESC, rl.created_at DESC, rl.id ASC
  LIMIT 1
  FOR UPDATE;

  v_old_department_id := v_employee.department_id;
  v_old_position_id := v_employee.position_id;
  v_old_manager_employee_id := COALESCE(v_current_manager_id, v_employee.manager_employee_id);

  SELECT a.id, a.cost_center_id
  INTO v_active_cost_center_assignment_id, v_old_cost_center_id
  FROM puls_core.employee_cost_center_assignments a
  WHERE a.tenant_id = v_tenant_id
    AND a.employee_id = p_employee_id
    AND a.is_active = TRUE
  ORDER BY a.starts_on DESC, a.updated_at DESC, a.id ASC
  LIMIT 1
  FOR UPDATE;

  IF v_old_department_id IS DISTINCT FROM p_department_id THEN
    v_changed_fields := array_append(v_changed_fields, 'department_id');
  END IF;

  IF v_old_position_id IS DISTINCT FROM p_position_id THEN
    v_changed_fields := array_append(v_changed_fields, 'position_id');
  END IF;

  IF v_old_manager_employee_id IS DISTINCT FROM p_manager_employee_id THEN
    v_changed_fields := array_append(v_changed_fields, 'manager_employee_id');
  END IF;

  IF v_old_cost_center_id IS DISTINCT FROM p_cost_center_id THEN
    v_changed_fields := array_append(v_changed_fields, 'cost_center_id');
  END IF;

  IF array_length(v_changed_fields, 1) IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'unchanged',
      'employee_id', p_employee_id,
      'department_id', v_old_department_id,
      'position_id', v_old_position_id,
      'manager_employee_id', v_old_manager_employee_id,
      'cost_center_id', v_old_cost_center_id
    );
  END IF;

  UPDATE puls_core.employees e
  SET department_id = p_department_id,
      position_id = p_position_id,
      updated_at = NOW()
  WHERE e.id = p_employee_id
    AND e.tenant_id = v_tenant_id
    AND (
      e.department_id IS DISTINCT FROM p_department_id
      OR e.position_id IS DISTINCT FROM p_position_id
    );

  IF v_old_manager_employee_id IS DISTINCT FROM p_manager_employee_id THEN
    IF v_active_reporting_line_id IS NOT NULL THEN
      UPDATE puls_core.employee_reporting_lines rl
      SET is_active = FALSE,
          ends_on = COALESCE(rl.ends_on, CURRENT_DATE),
          updated_at = NOW()
      WHERE rl.id = v_active_reporting_line_id;
    ELSIF v_employee.manager_employee_id IS NOT NULL THEN
      UPDATE puls_core.employees e
      SET manager_employee_id = NULL,
          updated_at = NOW()
      WHERE e.id = p_employee_id
        AND e.tenant_id = v_tenant_id;
    END IF;

    IF p_manager_employee_id IS NOT NULL THEN
      INSERT INTO puls_core.employee_reporting_lines (
        tenant_id,
        employee_id,
        manager_employee_id,
        relationship_type,
        starts_on,
        is_active,
        source
      )
      VALUES (
        v_tenant_id,
        p_employee_id,
        p_manager_employee_id,
        'primary_manager'::puls_core.reporting_relationship_type,
        CURRENT_DATE,
        TRUE,
        'manual'
      );
    END IF;
  END IF;

  IF v_old_cost_center_id IS DISTINCT FROM p_cost_center_id THEN
    IF v_active_cost_center_assignment_id IS NOT NULL THEN
      UPDATE puls_core.employee_cost_center_assignments a
      SET is_active = FALSE,
          ends_on = COALESCE(a.ends_on, CURRENT_DATE),
          updated_at = NOW()
      WHERE a.id = v_active_cost_center_assignment_id;
    END IF;

    IF p_cost_center_id IS NOT NULL THEN
      INSERT INTO puls_core.employee_cost_center_assignments (
        tenant_id,
        employee_id,
        cost_center_id,
        starts_on,
        is_active,
        source
      )
      VALUES (
        v_tenant_id,
        p_employee_id,
        p_cost_center_id,
        CURRENT_DATE,
        TRUE,
        'manual'
      );
    END IF;
  END IF;

  INSERT INTO puls_audit.audit_logs (
    tenant_id,
    actor_user_id,
    actor_employee_id,
    action,
    target_schema,
    target_table,
    target_id,
    metadata,
    source
  )
  VALUES (
    v_tenant_id,
    auth.uid(),
    v_actor_employee_id,
    'core_hr.employee_assignment.update',
    'puls_core',
    'employees',
    p_employee_id,
    jsonb_build_object(
      'changed_fields', v_changed_fields,
      'department_id_before', v_old_department_id,
      'department_id_after', p_department_id,
      'position_id_before', v_old_position_id,
      'position_id_after', p_position_id,
      'manager_employee_id_before', v_old_manager_employee_id,
      'manager_employee_id_after', p_manager_employee_id,
      'cost_center_id_before', v_old_cost_center_id,
      'cost_center_id_after', p_cost_center_id,
      'safe_assignment_audit', TRUE
    ),
    'employee_assignment_rpc'
  );

  RETURN jsonb_build_object(
    'status', 'updated',
    'employee_id', p_employee_id,
    'department_id', p_department_id,
    'position_id', p_position_id,
    'manager_employee_id', p_manager_employee_id,
    'cost_center_id', p_cost_center_id
  );
END;
$$;

REVOKE ALL ON FUNCTION puls_core._employee_assignment_assert_admin() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION puls_core.update_employee_assignment(UUID, UUID, UUID, UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION puls_core.update_employee_assignment(UUID, UUID, UUID, UUID, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_core._employee_assignment_assert_admin() TO service_role;
