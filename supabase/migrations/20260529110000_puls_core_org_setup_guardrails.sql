-- 11 PR11.2 — Org setup guardrails (departments + positions)
-- Forward-only. Org setup guardrails only.
-- No employee assignment editing. No resolver/decide/import changes.
-- No ERP writes/sync. No hard delete. No lifecycle audit.

CREATE OR REPLACE FUNCTION puls_core._normalize_org_setup_text(p_value TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog
AS $$
  SELECT NULLIF(BTRIM(p_value), '');
$$;

CREATE OR REPLACE FUNCTION puls_core.validate_department_setup_guardrails()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
DECLARE
  v_name TEXT;
  v_code TEXT;
BEGIN
  IF TG_OP = 'UPDATE'
     AND NULLIF(BTRIM(OLD.external_source), '') IS NOT NULL THEN
    RAISE EXCEPTION 'PULS_ORG_DEPARTMENT_SOURCE_READ_ONLY: imported departments cannot be edited locally.';
  END IF;

  v_name := puls_core._normalize_org_setup_text(NEW.name);
  v_code := puls_core._normalize_org_setup_text(NEW.code);

  IF v_name IS NULL THEN
    RAISE EXCEPTION 'PULS_ORG_DEPARTMENT_NAME_REQUIRED: name is required.';
  END IF;

  IF v_code IS NULL THEN
    RAISE EXCEPTION 'PULS_ORG_DEPARTMENT_CODE_REQUIRED: code is required.';
  END IF;

  IF v_code !~ '^[a-z][a-z0-9_]{1,63}$' THEN
    RAISE EXCEPTION 'PULS_ORG_DEPARTMENT_CODE_INVALID: code must be lowercase slug.';
  END IF;

  IF NEW.manager_employee_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM puls_core.employees e
      WHERE e.id = NEW.manager_employee_id
        AND e.tenant_id = NEW.tenant_id
        AND e.employment_status = 'active'
    ) THEN
      RAISE EXCEPTION 'PULS_ORG_DEPARTMENT_MANAGER_INVALID: manager_employee_id is invalid for this tenant.';
    END IF;
  END IF;

  IF NEW.cost_center_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM puls_core.cost_centers cc
      WHERE cc.id = NEW.cost_center_id
        AND cc.tenant_id = NEW.tenant_id
        AND cc.is_active = TRUE
    ) THEN
      RAISE EXCEPTION 'PULS_ORG_DEPARTMENT_COST_CENTER_INVALID: cost_center_id is invalid for this tenant.';
    END IF;
  END IF;

  NEW.name := v_name;
  NEW.code := v_code;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION puls_core.validate_position_setup_guardrails()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
DECLARE
  v_name TEXT;
  v_code TEXT;
BEGIN
  IF TG_OP = 'UPDATE'
     AND NULLIF(BTRIM(OLD.external_source), '') IS NOT NULL THEN
    RAISE EXCEPTION 'PULS_ORG_POSITION_SOURCE_READ_ONLY: imported positions cannot be edited locally.';
  END IF;

  v_name := puls_core._normalize_org_setup_text(NEW.name);
  v_code := puls_core._normalize_org_setup_text(NEW.code);

  IF v_name IS NULL THEN
    RAISE EXCEPTION 'PULS_ORG_POSITION_NAME_REQUIRED: name is required.';
  END IF;

  IF v_code IS NULL THEN
    RAISE EXCEPTION 'PULS_ORG_POSITION_CODE_REQUIRED: code is required.';
  END IF;

  IF v_code !~ '^[a-z][a-z0-9_]{1,63}$' THEN
    RAISE EXCEPTION 'PULS_ORG_POSITION_CODE_INVALID: code must be lowercase slug.';
  END IF;

  IF NEW.department_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM puls_core.departments d
      WHERE d.id = NEW.department_id
        AND d.tenant_id = NEW.tenant_id
    ) THEN
      RAISE EXCEPTION 'PULS_ORG_POSITION_DEPARTMENT_INVALID: department_id is invalid for this tenant.';
    END IF;
  END IF;

  IF NEW.norm_headcount IS NOT NULL
     AND (NEW.norm_headcount < 0 OR NEW.norm_headcount > 100000) THEN
    RAISE EXCEPTION 'PULS_ORG_POSITION_NORM_INVALID: norm_headcount must be between 0 and 100000.';
  END IF;

  NEW.name := v_name;
  NEW.code := v_code;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS puls_core_departments_validate_setup_guardrails ON puls_core.departments;
CREATE TRIGGER puls_core_departments_validate_setup_guardrails
  BEFORE INSERT OR UPDATE ON puls_core.departments
  FOR EACH ROW
  EXECUTE FUNCTION puls_core.validate_department_setup_guardrails();

DROP TRIGGER IF EXISTS puls_core_positions_validate_setup_guardrails ON puls_core.positions;
CREATE TRIGGER puls_core_positions_validate_setup_guardrails
  BEFORE INSERT OR UPDATE ON puls_core.positions
  FOR EACH ROW
  EXECUTE FUNCTION puls_core.validate_position_setup_guardrails();

REVOKE ALL ON FUNCTION puls_core.validate_department_setup_guardrails() FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_core.validate_position_setup_guardrails() FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_core.validate_department_setup_guardrails() TO service_role;
GRANT EXECUTE ON FUNCTION puls_core.validate_position_setup_guardrails() TO service_role;
