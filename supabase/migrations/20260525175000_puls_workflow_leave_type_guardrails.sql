-- 10 PR10.11 — Leave type setup guardrails (validation trigger)
-- PULS setup guardrails only. No lifecycle. No resolver/decide/import changes.
-- No ERP/pre-accounting writes. Forward-only.

-- ---------------------------------------------------------------------------
-- Normalization helper (BTRIM only; no silent lowercase on code)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_workflow._normalize_leave_type_text(p_value TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog
AS $$
  SELECT NULLIF(BTRIM(p_value), '');
$$;

-- ---------------------------------------------------------------------------
-- Guardrail trigger (SECURITY DEFINER; full-row BEFORE INSERT OR UPDATE)
-- DB does not silently lowercase code; it trims and rejects non-canonical values.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_workflow.validate_leave_type_guardrails()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow
AS $$
DECLARE
  v_name TEXT;
  v_code TEXT;
  v_policy_tenant UUID;
  v_policy_module puls_workflow.approval_module;
BEGIN
  v_name := puls_workflow._normalize_leave_type_text(NEW.name);
  v_code := puls_workflow._normalize_leave_type_text(NEW.code);

  IF v_name IS NULL THEN
    RAISE EXCEPTION 'PULS_LEAVE_TYPE_NAME_REQUIRED: name is required.';
  END IF;

  IF v_code IS NULL THEN
    RAISE EXCEPTION 'PULS_LEAVE_TYPE_CODE_REQUIRED: code is required.';
  END IF;

  IF v_code !~ '^[a-z][a-z0-9_]{1,63}$' THEN
    RAISE EXCEPTION 'PULS_LEAVE_TYPE_CODE_INVALID: code must be lowercase slug.';
  END IF;

  IF NEW.default_entitlement_days IS NOT NULL
     AND (NEW.default_entitlement_days < 0 OR NEW.default_entitlement_days > 365) THEN
    RAISE EXCEPTION 'PULS_LEAVE_TYPE_ENTITLEMENT_INVALID: default_entitlement_days must be between 0 and 365.';
  END IF;

  IF NEW.max_carry_over_days IS NOT NULL
     AND (NEW.max_carry_over_days < 0 OR NEW.max_carry_over_days > 365) THEN
    RAISE EXCEPTION 'PULS_LEAVE_TYPE_CARRY_OVER_INVALID: max_carry_over_days must be between 0 and 365.';
  END IF;

  IF NOT NEW.carry_over_allowed
     AND NEW.max_carry_over_days IS NOT NULL
     AND NEW.max_carry_over_days > 0 THEN
    RAISE EXCEPTION 'PULS_LEAVE_TYPE_CARRY_OVER_INVALID: max_carry_over_days must be null or zero when carry_over_allowed is false.';
  END IF;

  IF NEW.approval_policy_id IS NOT NULL THEN
    SELECT ap.tenant_id, ap.module
    INTO v_policy_tenant, v_policy_module
    FROM puls_workflow.approval_policies ap
    WHERE ap.id = NEW.approval_policy_id;

    IF NOT FOUND OR v_policy_tenant IS DISTINCT FROM NEW.tenant_id THEN
      RAISE EXCEPTION 'PULS_LEAVE_TYPE_POLICY_INVALID: approval_policy_id is invalid for this tenant.';
    END IF;

    IF v_policy_module <> 'leave'::puls_workflow.approval_module THEN
      RAISE EXCEPTION 'PULS_LEAVE_TYPE_POLICY_MODULE_INVALID: approval policy module must be leave.';
    END IF;
  END IF;

  NEW.name := v_name;
  NEW.code := v_code;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS puls_workflow_leave_types_validate_guardrails
  ON puls_workflow.leave_types;

CREATE TRIGGER puls_workflow_leave_types_validate_guardrails
  BEFORE INSERT OR UPDATE
  ON puls_workflow.leave_types
  FOR EACH ROW
  EXECUTE FUNCTION puls_workflow.validate_leave_type_guardrails();

-- ---------------------------------------------------------------------------
-- REVOKE / GRANT (internal validation surface; not callable from UI)
-- ---------------------------------------------------------------------------

REVOKE ALL ON FUNCTION puls_workflow._normalize_leave_type_text(TEXT) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_workflow.validate_leave_type_guardrails() FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_workflow._normalize_leave_type_text(TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION puls_workflow.validate_leave_type_guardrails() TO service_role;
