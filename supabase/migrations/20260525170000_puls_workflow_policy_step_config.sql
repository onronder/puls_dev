-- 10 PR10.1 — Policy step config foundation (schema + validation only; no runtime behavior change)
-- step_resolver_config / step_condition_config are stored but not consumed by resolver/decide until PR10.2+.

ALTER TABLE puls_workflow.approval_policy_steps
  ADD COLUMN IF NOT EXISTS step_resolver_config JSONB NULL,
  ADD COLUMN IF NOT EXISTS step_condition_config JSONB NULL;

COMMENT ON COLUMN puls_workflow.approval_policy_steps.step_resolver_config IS
  'Optional per-step resolver hints (JSON object). Validated on write; not read by resolver/decide in PR10.1.';

COMMENT ON COLUMN puls_workflow.approval_policy_steps.step_condition_config IS
  'Optional per-step condition hints (JSON object). Validated on write; not read by resolver/decide in PR10.1.';

-- ---------------------------------------------------------------------------
-- Key registries (empty allowlist v1; PR10.2 expands)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_workflow.policy_step_resolver_config_allowed_keys()
RETURNS TEXT[]
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog
AS $$
  SELECT ARRAY[]::TEXT[];
$$;

CREATE OR REPLACE FUNCTION puls_workflow.policy_step_condition_config_allowed_keys()
RETURNS TEXT[]
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog
AS $$
  SELECT ARRAY[]::TEXT[];
$$;

CREATE OR REPLACE FUNCTION puls_workflow.policy_step_config_blocked_keys()
RETURNS TEXT[]
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog
AS $$
  SELECT ARRAY[
    -- SENSITIVE_BLOCK_LIST_BEGIN
    'salary',
    'salary_min',
    'salary_max',
    'maas',
    'pay_band',
    'payroll',
    'compensation',
    'tckn',
    'iban',
    'birth_date',
    'dogum_tarihi',
    'health',
    'saglik',
    'family',
    'aile'
    -- SENSITIVE_BLOCK_LIST_END
  ]::TEXT[];
$$;

-- ---------------------------------------------------------------------------
-- Shared validator (pure; IMMUTABLE)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_workflow._validate_policy_step_config_object(
  p_config JSONB,
  p_allowed_keys TEXT[],
  p_blocked_keys TEXT[],
  p_field_name TEXT
)
RETURNS VOID
LANGUAGE plpgsql
IMMUTABLE
SET search_path = pg_catalog, puls_workflow
AS $$
DECLARE
  v_key TEXT;
  v_norm TEXT;
  v_value JSONB;
BEGIN
  IF p_config IS NULL THEN
    RETURN;
  END IF;

  IF jsonb_typeof(p_config) <> 'object' THEN
    RAISE EXCEPTION 'PULS_POLICY_STEP_CONFIG_INVALID: % must be a JSON object or NULL.', p_field_name
      USING ERRCODE = 'P0001';
  END IF;

  FOR v_key IN SELECT jsonb_object_keys(p_config) LOOP
    v_norm := lower(v_key);
    v_value := p_config -> v_key;

    IF v_norm = ANY(p_blocked_keys) THEN
      RAISE EXCEPTION 'PULS_POLICY_STEP_CONFIG_FORBIDDEN_FIELD: % contains forbidden field %.', p_field_name, v_key
        USING ERRCODE = 'P0001';
    END IF;

    IF NOT (v_norm = ANY(p_allowed_keys)) THEN
      RAISE EXCEPTION 'PULS_POLICY_STEP_CONFIG_UNKNOWN_FIELD: % contains unknown field %.', p_field_name, v_key
        USING ERRCODE = 'P0001';
    END IF;

    IF jsonb_typeof(v_value) IN ('object', 'array') THEN
      RAISE EXCEPTION 'PULS_POLICY_STEP_CONFIG_INVALID_VALUE: % field % must be a scalar value.', p_field_name, v_key
        USING ERRCODE = 'P0001';
    END IF;
  END LOOP;
END;
$$;

-- ---------------------------------------------------------------------------
-- Trigger (SECURITY DEFINER; re-validates config on every insert/update)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_workflow.validate_approval_policy_step_config()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow
AS $$
BEGIN
  PERFORM puls_workflow._validate_policy_step_config_object(
    NEW.step_resolver_config,
    puls_workflow.policy_step_resolver_config_allowed_keys(),
    puls_workflow.policy_step_config_blocked_keys(),
    'step_resolver_config'
  );

  PERFORM puls_workflow._validate_policy_step_config_object(
    NEW.step_condition_config,
    puls_workflow.policy_step_condition_config_allowed_keys(),
    puls_workflow.policy_step_config_blocked_keys(),
    'step_condition_config'
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS puls_workflow_approval_policy_steps_validate_config ON puls_workflow.approval_policy_steps;

CREATE TRIGGER puls_workflow_approval_policy_steps_validate_config
  BEFORE INSERT OR UPDATE
  ON puls_workflow.approval_policy_steps
  FOR EACH ROW
  EXECUTE FUNCTION puls_workflow.validate_approval_policy_step_config();

-- ---------------------------------------------------------------------------
-- REVOKE (internal validation surface only)
-- ---------------------------------------------------------------------------

REVOKE ALL ON FUNCTION puls_workflow.policy_step_resolver_config_allowed_keys() FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_workflow.policy_step_condition_config_allowed_keys() FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_workflow.policy_step_config_blocked_keys() FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_workflow._validate_policy_step_config_object(JSONB, TEXT[], TEXT[], TEXT) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_workflow.validate_approval_policy_step_config() FROM PUBLIC, authenticated, anon;
