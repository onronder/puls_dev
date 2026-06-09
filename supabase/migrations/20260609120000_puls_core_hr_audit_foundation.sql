-- PR17.1A core HR audit foundation.
-- Adds safe row-level audit triggers for org and performance records that are
-- already mutable in the product. This does not change UI behavior, RLS,
-- connector runtime, notifications, AI context, source writeback, or external
-- delivery.

CREATE OR REPLACE FUNCTION puls_core._core_hr_audit_transition_metadata(
  p_table_name TEXT,
  p_old JSONB,
  p_new JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SET search_path = pg_catalog
AS $$
DECLARE
  v_metadata JSONB := '{}'::JSONB;
  v_field TEXT;
  v_old_value TEXT;
  v_new_value TEXT;
  v_allowed_fields TEXT[] := CASE p_table_name
    WHEN 'departments' THEN ARRAY[
      'code',
      'parent_id',
      'manager_employee_id',
      'cost_center_code',
      'is_active',
      'external_source'
    ]
    WHEN 'positions' THEN ARRAY[
      'code',
      'department_id',
      'parent_position_id',
      'employment_type',
      'level',
      'norm_headcount',
      'is_active',
      'external_source'
    ]
    WHEN 'employees' THEN ARRAY[
      'employee_code',
      'external_source',
      'department_id',
      'position_id',
      'manager_employee_id',
      'persona_role',
      'employment_status',
      'hire_date',
      'termination_date'
    ]
    ELSE ARRAY[]::TEXT[]
  END;
  v_changed_fields TEXT[] := ARRAY[]::TEXT[];
BEGIN
  FOREACH v_field IN ARRAY v_allowed_fields LOOP
    v_old_value := NULLIF(p_old ->> v_field, '');
    v_new_value := NULLIF(p_new ->> v_field, '');

    IF p_old ? v_field OR p_new ? v_field THEN
      IF v_old_value IS DISTINCT FROM v_new_value THEN
        v_changed_fields := array_append(v_changed_fields, v_field);
        v_metadata := v_metadata || jsonb_build_object(
          v_field || '_before',
          v_old_value,
          v_field || '_after',
          v_new_value
        );
      END IF;
    END IF;
  END LOOP;

  IF COALESCE(array_length(v_changed_fields, 1), 0) > 0 THEN
    v_metadata := v_metadata || jsonb_build_object(
      'changed_fields',
      to_jsonb(v_changed_fields)
    );
  END IF;

  RETURN jsonb_strip_nulls(v_metadata);
END;
$$;

CREATE OR REPLACE FUNCTION puls_core.write_core_hr_row_audit_log()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_core, puls_audit
AS $$
DECLARE
  v_old JSONB := CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE '{}'::JSONB END;
  v_new JSONB := CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) ELSE '{}'::JSONB END;
  v_row JSONB := CASE WHEN TG_OP = 'DELETE' THEN v_old ELSE v_new END;
  v_tenant_id UUID := NULLIF(v_row ->> 'tenant_id', '')::UUID;
  v_target_id UUID := NULLIF(v_row ->> 'id', '')::UUID;
  v_metadata JSONB;
BEGIN
  IF v_tenant_id IS NULL OR v_target_id IS NULL THEN
    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    END IF;
    RETURN NEW;
  END IF;

  v_metadata := puls_core._core_hr_audit_transition_metadata(TG_TABLE_NAME, v_old, v_new)
    || jsonb_build_object(
      'operation', LOWER(TG_OP),
      'safe_row_audit', TRUE
    );

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
    puls_core.current_employee_id(),
    concat('core_hr.', TG_TABLE_NAME, '.', LOWER(TG_OP)),
    TG_TABLE_SCHEMA,
    TG_TABLE_NAME,
    v_target_id,
    v_metadata,
    'core_hr_row_audit'
  );

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION puls_performance._performance_audit_transition_metadata(
  p_table_name TEXT,
  p_old JSONB,
  p_new JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SET search_path = pg_catalog
AS $$
DECLARE
  v_metadata JSONB := '{}'::JSONB;
  v_field TEXT;
  v_old_value TEXT;
  v_new_value TEXT;
  v_allowed_fields TEXT[] := CASE p_table_name
    WHEN 'performance_cycles' THEN ARRAY[
      'status',
      'starts_at',
      'ends_at',
      'scope',
      'kpi_frequency'
    ]
    ELSE ARRAY[]::TEXT[]
  END;
  v_changed_fields TEXT[] := ARRAY[]::TEXT[];
BEGIN
  FOREACH v_field IN ARRAY v_allowed_fields LOOP
    v_old_value := NULLIF(p_old ->> v_field, '');
    v_new_value := NULLIF(p_new ->> v_field, '');

    IF p_old ? v_field OR p_new ? v_field THEN
      IF v_old_value IS DISTINCT FROM v_new_value THEN
        v_changed_fields := array_append(v_changed_fields, v_field);
        v_metadata := v_metadata || jsonb_build_object(
          v_field || '_before',
          v_old_value,
          v_field || '_after',
          v_new_value
        );
      END IF;
    END IF;
  END LOOP;

  IF COALESCE(array_length(v_changed_fields, 1), 0) > 0 THEN
    v_metadata := v_metadata || jsonb_build_object(
      'changed_fields',
      to_jsonb(v_changed_fields)
    );
  END IF;

  RETURN jsonb_strip_nulls(v_metadata);
END;
$$;

CREATE OR REPLACE FUNCTION puls_performance.write_performance_row_audit_log()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_performance, puls_core, puls_audit
AS $$
DECLARE
  v_old JSONB := CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE '{}'::JSONB END;
  v_new JSONB := CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) ELSE '{}'::JSONB END;
  v_row JSONB := CASE WHEN TG_OP = 'DELETE' THEN v_old ELSE v_new END;
  v_tenant_id UUID := NULLIF(v_row ->> 'tenant_id', '')::UUID;
  v_target_id UUID := NULLIF(v_row ->> 'id', '')::UUID;
  v_metadata JSONB;
BEGIN
  IF v_tenant_id IS NULL OR v_target_id IS NULL THEN
    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    END IF;
    RETURN NEW;
  END IF;

  v_metadata := puls_performance._performance_audit_transition_metadata(TG_TABLE_NAME, v_old, v_new)
    || jsonb_build_object(
      'operation', LOWER(TG_OP),
      'safe_row_audit', TRUE
    );

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
    puls_core.current_employee_id(),
    concat('performance.', TG_TABLE_NAME, '.', LOWER(TG_OP)),
    TG_TABLE_SCHEMA,
    TG_TABLE_NAME,
    v_target_id,
    v_metadata,
    'performance_row_audit'
  );

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS puls_core_departments_audit_row
  ON puls_core.departments;
CREATE TRIGGER puls_core_departments_audit_row
  AFTER INSERT OR UPDATE OR DELETE
  ON puls_core.departments
  FOR EACH ROW
  EXECUTE FUNCTION puls_core.write_core_hr_row_audit_log();

DROP TRIGGER IF EXISTS puls_core_positions_audit_row
  ON puls_core.positions;
CREATE TRIGGER puls_core_positions_audit_row
  AFTER INSERT OR UPDATE OR DELETE
  ON puls_core.positions
  FOR EACH ROW
  EXECUTE FUNCTION puls_core.write_core_hr_row_audit_log();

DROP TRIGGER IF EXISTS puls_core_employees_audit_row
  ON puls_core.employees;
CREATE TRIGGER puls_core_employees_audit_row
  AFTER INSERT OR UPDATE OR DELETE
  ON puls_core.employees
  FOR EACH ROW
  EXECUTE FUNCTION puls_core.write_core_hr_row_audit_log();

DROP TRIGGER IF EXISTS puls_performance_cycles_audit_row
  ON puls_performance.performance_cycles;
CREATE TRIGGER puls_performance_cycles_audit_row
  AFTER INSERT OR UPDATE OR DELETE
  ON puls_performance.performance_cycles
  FOR EACH ROW
  EXECUTE FUNCTION puls_performance.write_performance_row_audit_log();

REVOKE ALL ON FUNCTION puls_core._core_hr_audit_transition_metadata(TEXT, JSONB, JSONB)
  FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_core.write_core_hr_row_audit_log()
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_core._core_hr_audit_transition_metadata(TEXT, JSONB, JSONB)
  TO service_role;
GRANT EXECUTE ON FUNCTION puls_core.write_core_hr_row_audit_log()
  TO service_role;

REVOKE ALL ON FUNCTION puls_performance._performance_audit_transition_metadata(TEXT, JSONB, JSONB)
  FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_performance.write_performance_row_audit_log()
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_performance._performance_audit_transition_metadata(TEXT, JSONB, JSONB)
  TO service_role;
GRANT EXECUTE ON FUNCTION puls_performance.write_performance_row_audit_log()
  TO service_role;

COMMENT ON FUNCTION puls_core.write_core_hr_row_audit_log()
  IS 'PR17.1A safe core HR row audit trigger for departments, positions, and employees. Emits tenant-bound metadata-only audit rows without names, emails, free-text descriptions, payloads, or credential data.';

COMMENT ON FUNCTION puls_performance.write_performance_row_audit_log()
  IS 'PR17.1A safe performance row audit trigger for performance cycles. Emits tenant-bound metadata-only audit rows without names, descriptions, payloads, or credential data.';
