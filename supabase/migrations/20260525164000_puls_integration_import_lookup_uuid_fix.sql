-- 09 hotfix — PR4 import lookup UUID aggregate fix.
-- Forward-only replacement for PR4 lookup helpers. Applied migrations remain immutable.

CREATE OR REPLACE FUNCTION puls_integration._import_lookup_by_code(
  p_tenant_id UUID,
  p_entity_type puls_integration.import_entity_type,
  p_code TEXT
)
RETURNS TABLE (canonical_id UUID, error_code TEXT)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_count INTEGER;
  v_id UUID;
BEGIN
  IF p_code IS NULL OR btrim(p_code) = '' THEN
    canonical_id := NULL;
    error_code := NULL;
    RETURN NEXT;
    RETURN;
  END IF;

  CASE p_entity_type
    WHEN 'legal_entity'::puls_integration.import_entity_type THEN
      SELECT COUNT(*), (array_agg(le.id ORDER BY le.id))[1]
      INTO v_count, v_id
      FROM puls_core.legal_entities le
      WHERE le.tenant_id = p_tenant_id AND le.code = p_code AND le.is_active = TRUE;
    WHEN 'location'::puls_integration.import_entity_type THEN
      SELECT COUNT(*), (array_agg(loc.id ORDER BY loc.id))[1]
      INTO v_count, v_id
      FROM puls_core.locations loc
      WHERE loc.tenant_id = p_tenant_id AND loc.code = p_code AND loc.is_active = TRUE;
    WHEN 'cost_center'::puls_integration.import_entity_type THEN
      SELECT COUNT(*), (array_agg(cc.id ORDER BY cc.id))[1]
      INTO v_count, v_id
      FROM puls_core.cost_centers cc
      WHERE cc.tenant_id = p_tenant_id AND cc.code = p_code AND cc.is_active = TRUE;
    WHEN 'department'::puls_integration.import_entity_type THEN
      SELECT COUNT(*), (array_agg(d.id ORDER BY d.id))[1]
      INTO v_count, v_id
      FROM puls_core.departments d
      WHERE d.tenant_id = p_tenant_id AND d.code = p_code AND d.is_active = TRUE;
    WHEN 'position'::puls_integration.import_entity_type THEN
      SELECT COUNT(*), (array_agg(p.id ORDER BY p.id))[1]
      INTO v_count, v_id
      FROM puls_core.positions p
      WHERE p.tenant_id = p_tenant_id AND p.code = p_code AND p.is_active = TRUE;
    ELSE
      canonical_id := NULL;
      error_code := 'UNSUPPORTED_ENTITY_TYPE';
      RETURN NEXT;
      RETURN;
  END CASE;

  IF v_count > 1 THEN
    canonical_id := NULL;
    error_code := 'AMBIGUOUS_REFERENCE';
  ELSIF v_count = 1 THEN
    canonical_id := v_id;
    error_code := NULL;
  ELSE
    canonical_id := NULL;
    error_code := NULL;
  END IF;
  RETURN NEXT;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration._import_lookup_employee(
  p_tenant_id UUID,
  p_employee_code TEXT,
  p_email TEXT
)
RETURNS TABLE (canonical_id UUID, error_code TEXT)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
DECLARE
  v_count INTEGER;
  v_id UUID;
BEGIN
  IF p_employee_code IS NOT NULL AND btrim(p_employee_code) <> '' THEN
    SELECT COUNT(*), (array_agg(e.id ORDER BY e.id))[1]
    INTO v_count, v_id
    FROM puls_core.employees e
    WHERE e.tenant_id = p_tenant_id
      AND e.employee_code = p_employee_code
      AND e.employment_status = 'active'::puls_core.employment_status;

    IF v_count > 1 THEN
      canonical_id := NULL;
      error_code := 'AMBIGUOUS_REFERENCE';
      RETURN NEXT;
      RETURN;
    ELSIF v_count = 1 THEN
      canonical_id := v_id;
      error_code := NULL;
      RETURN NEXT;
      RETURN;
    END IF;
  END IF;

  IF p_email IS NOT NULL AND btrim(p_email) <> '' THEN
    SELECT COUNT(*), (array_agg(e.id ORDER BY e.id))[1]
    INTO v_count, v_id
    FROM puls_core.employees e
    WHERE e.tenant_id = p_tenant_id
      AND lower(e.email) = lower(p_email)
      AND e.employment_status = 'active'::puls_core.employment_status;

    IF v_count > 1 THEN
      canonical_id := NULL;
      error_code := 'AMBIGUOUS_REFERENCE';
    ELSIF v_count = 1 THEN
      canonical_id := v_id;
      error_code := NULL;
    ELSE
      canonical_id := NULL;
      error_code := NULL;
    END IF;
    RETURN NEXT;
    RETURN;
  END IF;

  canonical_id := NULL;
  error_code := NULL;
  RETURN NEXT;
END;
$$;
