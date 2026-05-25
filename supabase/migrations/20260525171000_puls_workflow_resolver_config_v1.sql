-- 10 PR10.2 — Resolver config consumption V1 (step_resolver_config runtime wiring)
-- Does NOT modify decide_approval_request, find_* step selection, or step_condition_config allowlist expansion.

-- ---------------------------------------------------------------------------
-- Allowlist V1 (resolver); condition config stays empty
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_workflow.policy_step_resolver_config_allowed_keys()
RETURNS TEXT[]
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog
AS $$
  SELECT ARRAY[
    'scope_strategy',
    'scope_type',
    'scope_id',
    'scope_code',
    'allow_tenant_fallback'
  ]::TEXT[];
$$;

CREATE OR REPLACE FUNCTION puls_workflow.policy_step_condition_config_allowed_keys()
RETURNS TEXT[]
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog
AS $$
  SELECT ARRAY[]::TEXT[];
$$;

-- ---------------------------------------------------------------------------
-- Semantic validation (strict JSON types; write-time only)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_workflow._validate_policy_step_resolver_config_semantics(
  p_tenant_id UUID,
  p_config JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core
AS $$
DECLARE
  v_strategy TEXT;
  v_scope_type TEXT;
  v_scope_id_text TEXT;
  v_scope_code TEXT;
  v_cc_id UUID;
  v_has_scope_id BOOLEAN;
  v_has_scope_code BOOLEAN;
  v_has_scope_type BOOLEAN;
BEGIN
  IF p_config IS NULL OR p_config = '{}'::jsonb THEN
    RETURN;
  END IF;

  IF p_config ? 'scope_strategy' THEN
    IF jsonb_typeof(p_config -> 'scope_strategy') <> 'string' THEN
      RAISE EXCEPTION 'PULS_POLICY_STEP_RESOLVER_CONFIG_INVALID: scope_strategy must be a JSON string.'
        USING ERRCODE = 'P0001';
    END IF;
    v_strategy := lower(btrim(p_config ->> 'scope_strategy'));
    IF v_strategy NOT IN ('default', 'tenant', 'requester_cost_center', 'explicit') THEN
      RAISE EXCEPTION 'PULS_POLICY_STEP_RESOLVER_CONFIG_INVALID_STRATEGY: scope_strategy % is not allowed.', v_strategy
        USING ERRCODE = 'P0001';
    END IF;
  ELSE
    v_strategy := 'default';
  END IF;

  IF p_config ? 'scope_type' THEN
    IF jsonb_typeof(p_config -> 'scope_type') <> 'string' THEN
      RAISE EXCEPTION 'PULS_POLICY_STEP_RESOLVER_CONFIG_INVALID: scope_type must be a JSON string.'
        USING ERRCODE = 'P0001';
    END IF;
    v_scope_type := lower(btrim(p_config ->> 'scope_type'));
    IF v_scope_type <> 'cost_center' THEN
      RAISE EXCEPTION 'PULS_POLICY_STEP_RESOLVER_CONFIG_INVALID_SCOPE_TYPE: scope_type % is not allowed in V1.', v_scope_type
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  IF p_config ? 'scope_id' THEN
    IF jsonb_typeof(p_config -> 'scope_id') <> 'string' THEN
      RAISE EXCEPTION 'PULS_POLICY_STEP_RESOLVER_CONFIG_INVALID: scope_id must be a JSON string.'
        USING ERRCODE = 'P0001';
    END IF;
    v_scope_id_text := btrim(p_config ->> 'scope_id');
    BEGIN
      v_cc_id := v_scope_id_text::uuid;
    EXCEPTION
      WHEN invalid_text_representation THEN
        RAISE EXCEPTION 'PULS_POLICY_STEP_RESOLVER_CONFIG_INVALID_SCOPE_ID: scope_id is not a valid UUID.'
          USING ERRCODE = 'P0001';
    END;
  END IF;

  IF p_config ? 'scope_code' THEN
    IF jsonb_typeof(p_config -> 'scope_code') <> 'string' THEN
      RAISE EXCEPTION 'PULS_POLICY_STEP_RESOLVER_CONFIG_INVALID: scope_code must be a JSON string.'
        USING ERRCODE = 'P0001';
    END IF;
    v_scope_code := btrim(p_config ->> 'scope_code');
    IF v_scope_code = '' THEN
      RAISE EXCEPTION 'PULS_POLICY_STEP_RESOLVER_CONFIG_INVALID_SCOPE_CODE: scope_code must not be empty.'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  IF p_config ? 'allow_tenant_fallback' THEN
    IF jsonb_typeof(p_config -> 'allow_tenant_fallback') <> 'boolean' THEN
      RAISE EXCEPTION 'PULS_POLICY_STEP_RESOLVER_CONFIG_INVALID: allow_tenant_fallback must be a JSON boolean.'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  v_has_scope_id := p_config ? 'scope_id';
  v_has_scope_code := p_config ? 'scope_code';
  v_has_scope_type := p_config ? 'scope_type';

  IF v_has_scope_id AND v_has_scope_code THEN
    RAISE EXCEPTION 'PULS_POLICY_STEP_RESOLVER_CONFIG_INVALID: scope_id and scope_code are mutually exclusive.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_strategy = 'tenant' THEN
    IF v_has_scope_id OR v_has_scope_code OR v_has_scope_type THEN
      RAISE EXCEPTION 'PULS_POLICY_STEP_RESOLVER_CONFIG_INVALID: tenant strategy must not include scope_id, scope_code, or scope_type.'
        USING ERRCODE = 'P0001';
    END IF;
    RETURN;
  END IF;

  IF v_strategy <> 'explicit' THEN
    IF v_has_scope_id OR v_has_scope_code OR v_has_scope_type THEN
      RAISE EXCEPTION 'PULS_POLICY_STEP_RESOLVER_CONFIG_INVALID: scope_id, scope_code, and scope_type are allowed only with scope_strategy=explicit.'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  IF v_strategy = 'explicit' THEN
    IF NOT v_has_scope_type OR lower(btrim(p_config ->> 'scope_type')) <> 'cost_center' THEN
      RAISE EXCEPTION 'PULS_POLICY_STEP_RESOLVER_CONFIG_INVALID: explicit strategy requires scope_type=cost_center.'
        USING ERRCODE = 'P0001';
    END IF;
    IF NOT v_has_scope_id AND NOT v_has_scope_code THEN
      RAISE EXCEPTION 'PULS_POLICY_STEP_RESOLVER_CONFIG_INVALID: explicit strategy requires scope_id or scope_code.'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  IF v_has_scope_id THEN
    IF NOT EXISTS (
      SELECT 1
      FROM puls_core.cost_centers cc
      WHERE cc.id = v_cc_id
        AND cc.tenant_id = p_tenant_id
        AND cc.is_active = TRUE
    ) THEN
      RAISE EXCEPTION 'PULS_POLICY_STEP_RESOLVER_CONFIG_INVALID_SCOPE_TARGET: scope_id does not resolve to an active cost center in tenant.'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  IF v_has_scope_code THEN
    SELECT cc.id
    INTO v_cc_id
    FROM puls_core.cost_centers cc
    WHERE cc.tenant_id = p_tenant_id
      AND cc.code = v_scope_code
      AND cc.is_active = TRUE;

    IF v_cc_id IS NULL THEN
      RAISE EXCEPTION 'PULS_POLICY_STEP_RESOLVER_CONFIG_INVALID_SCOPE_TARGET: scope_code does not resolve to an active cost center in tenant.'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION puls_workflow.validate_approval_policy_step_config()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core
AS $$
BEGIN
  PERFORM puls_workflow._validate_policy_step_config_object(
    NEW.step_resolver_config,
    puls_workflow.policy_step_resolver_config_allowed_keys(),
    puls_workflow.policy_step_config_blocked_keys(),
    'step_resolver_config'
  );

  PERFORM puls_workflow._validate_policy_step_resolver_config_semantics(
    NEW.tenant_id,
    NEW.step_resolver_config
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

-- ---------------------------------------------------------------------------
-- Runtime scope from step_resolver_config
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_workflow._resolver_step_config_scope(
  p_tenant_id UUID,
  p_module TEXT,
  p_requester_id UUID,
  p_step_resolver_config JSONB
)
RETURNS TABLE (
  scope_type puls_core.authority_scope_type,
  scope_id UUID,
  include_tenant_fallback BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core
AS $$
DECLARE
  v_strategy TEXT;
  v_cc_id UUID;
  v_fallback BOOLEAN := TRUE;
BEGIN
  IF p_step_resolver_config IS NULL
     OR p_step_resolver_config = '{}'::jsonb
     OR lower(COALESCE(p_step_resolver_config ->> 'scope_strategy', 'default')) = 'default' THEN
    v_cc_id := puls_workflow._resolver_requester_cost_center_id(p_tenant_id, p_requester_id);
    SELECT ps.scope_type, ps.scope_id
    INTO scope_type, scope_id
    FROM puls_workflow._resolver_pool_scope(p_module, v_cc_id) ps;
    include_tenant_fallback := TRUE;
    RETURN NEXT;
    RETURN;
  END IF;

  v_strategy := lower(p_step_resolver_config ->> 'scope_strategy');

  IF p_step_resolver_config ? 'allow_tenant_fallback' THEN
    v_fallback := (p_step_resolver_config -> 'allow_tenant_fallback')::boolean;
  END IF;

  IF v_strategy = 'tenant' THEN
    scope_type := 'tenant'::puls_core.authority_scope_type;
    scope_id := NULL;
    include_tenant_fallback := TRUE;
    RETURN NEXT;
    RETURN;
  END IF;

  IF v_strategy = 'requester_cost_center' THEN
    v_cc_id := puls_workflow._resolver_requester_cost_center_id(p_tenant_id, p_requester_id);
    IF v_cc_id IS NULL THEN
      scope_type := NULL;
      scope_id := NULL;
      include_tenant_fallback := v_fallback;
      RETURN NEXT;
      RETURN;
    END IF;
    scope_type := 'cost_center'::puls_core.authority_scope_type;
    scope_id := v_cc_id;
    include_tenant_fallback := v_fallback;
    RETURN NEXT;
    RETURN;
  END IF;

  IF v_strategy = 'explicit' THEN
    IF p_step_resolver_config ? 'scope_id' THEN
      scope_id := (p_step_resolver_config ->> 'scope_id')::uuid;
    ELSE
      SELECT cc.id
      INTO scope_id
      FROM puls_core.cost_centers cc
      WHERE cc.tenant_id = p_tenant_id
        AND cc.code = btrim(p_step_resolver_config ->> 'scope_code')
        AND cc.is_active = TRUE;
    END IF;
    scope_type := 'cost_center'::puls_core.authority_scope_type;
    include_tenant_fallback := v_fallback;
    RETURN NEXT;
    RETURN;
  END IF;

  v_cc_id := puls_workflow._resolver_requester_cost_center_id(p_tenant_id, p_requester_id);
  SELECT ps.scope_type, ps.scope_id
  INTO scope_type, scope_id
  FROM puls_workflow._resolver_pool_scope(p_module, v_cc_id) ps;
  include_tenant_fallback := TRUE;
  RETURN NEXT;
END;
$$;

-- ---------------------------------------------------------------------------
-- Pool resolver — replace 7-arg signature (no overload)
-- ---------------------------------------------------------------------------

DROP FUNCTION IF EXISTS puls_workflow._resolve_pool_approver_by_type(
  UUID, puls_core.authority_pool_type, TEXT,
  puls_core.authority_scope_type, UUID, UUID, DATE
);

CREATE OR REPLACE FUNCTION puls_workflow._resolve_pool_approver_by_type(
  p_tenant_id UUID,
  p_pool_type puls_core.authority_pool_type,
  p_module TEXT,
  p_scope_type puls_core.authority_scope_type,
  p_scope_id UUID,
  p_exclude_employee_id UUID,
  p_include_tenant_fallback BOOLEAN DEFAULT TRUE,
  p_as_of DATE DEFAULT CURRENT_DATE
)
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core
AS $$
  SELECT m.employee_id
  FROM puls_core.authority_pools p
  JOIN puls_core.authority_pool_members m
    ON m.pool_id = p.id
   AND m.tenant_id = p.tenant_id
  JOIN puls_core.employees e
    ON e.id = m.employee_id
   AND e.tenant_id = p.tenant_id
  WHERE p.tenant_id = p_tenant_id
    AND p.pool_type = p_pool_type
    AND p.is_active = TRUE
    AND (
      p.module = p_module::puls_core.authority_module
      OR p.module = 'global'::puls_core.authority_module
    )
    AND (
      CASE
        WHEN p_include_tenant_fallback THEN
          (p.scope_type = 'tenant'::puls_core.authority_scope_type AND p.scope_id IS NULL)
          OR (
            p.scope_type = p_scope_type
            AND p.scope_id IS NOT DISTINCT FROM p_scope_id
          )
        ELSE
          p.scope_type = p_scope_type
          AND p.scope_id IS NOT DISTINCT FROM p_scope_id
      END
    )
    AND m.is_active = TRUE
    AND m.starts_on <= p_as_of
    AND (m.ends_on IS NULL OR m.ends_on >= p_as_of)
    AND m.employee_id IS DISTINCT FROM p_exclude_employee_id
    AND e.employment_status = 'active'::puls_core.employment_status
  ORDER BY
    CASE
      WHEN NOT p_include_tenant_fallback THEN 0
      WHEN p.scope_type = p_scope_type
       AND p.scope_id IS NOT DISTINCT FROM p_scope_id THEN 0
      WHEN p.scope_type = 'tenant'::puls_core.authority_scope_type
       AND p.scope_id IS NULL THEN 1
      ELSE 2
    END ASC,
    p.priority ASC,
    m.priority ASC,
    m.starts_on ASC,
    m.id ASC
  LIMIT 1;
$$;

-- ---------------------------------------------------------------------------
-- Approver branch + public resolvers (pass step_resolver_config)
-- ---------------------------------------------------------------------------

DROP FUNCTION IF EXISTS puls_workflow._resolve_approver_type_branch(
  UUID, UUID, TEXT, puls_workflow.approver_type, UUID
);

CREATE OR REPLACE FUNCTION puls_workflow._resolve_approver_type_branch(
  p_tenant_id UUID,
  p_requester_id UUID,
  p_module TEXT,
  p_approver_type puls_workflow.approver_type,
  p_specific_employee_id UUID DEFAULT NULL,
  p_step_resolver_config JSONB DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core
AS $$
DECLARE
  v_approver_id UUID;
  v_scope puls_core.authority_scope_type;
  v_scope_id UUID;
  v_include_tenant_fallback BOOLEAN := TRUE;
BEGIN
  IF p_approver_type = 'manager'::puls_workflow.approver_type THEN
    v_approver_id := puls_workflow.resolve_org_primary_manager(p_tenant_id, p_requester_id);
    IF v_approver_id IS NULL THEN
      v_approver_id := puls_workflow.resolve_dept_manager(p_tenant_id, p_requester_id);
    END IF;
    RETURN v_approver_id;
  END IF;

  IF p_approver_type = 'hr_admin'::puls_workflow.approver_type THEN
    RETURN puls_workflow.resolve_hr_admin_approver(p_tenant_id, p_requester_id);
  END IF;

  IF p_approver_type = 'specific_employee'::puls_workflow.approver_type THEN
    IF p_specific_employee_id IS NOT NULL
       AND p_specific_employee_id <> p_requester_id
       AND EXISTS (
         SELECT 1
         FROM puls_core.employees e
         WHERE e.id = p_specific_employee_id
           AND e.tenant_id = p_tenant_id
           AND e.employment_status = 'active'::puls_core.employment_status
       ) THEN
      RETURN p_specific_employee_id;
    END IF;
    RETURN NULL;
  END IF;

  SELECT rs.scope_type, rs.scope_id, rs.include_tenant_fallback
  INTO v_scope, v_scope_id, v_include_tenant_fallback
  FROM puls_workflow._resolver_step_config_scope(
    p_tenant_id,
    p_module,
    p_requester_id,
    p_step_resolver_config
  ) rs;

  IF p_approver_type = 'finance_pool'::puls_workflow.approver_type THEN
    RETURN puls_workflow._resolve_pool_approver_by_type(
      p_tenant_id,
      'finance'::puls_core.authority_pool_type,
      p_module,
      v_scope,
      v_scope_id,
      p_requester_id,
      v_include_tenant_fallback
    );
  END IF;

  IF p_approver_type = 'hr_pool'::puls_workflow.approver_type THEN
    RETURN puls_workflow._resolve_pool_approver_by_type(
      p_tenant_id,
      'hr'::puls_core.authority_pool_type,
      p_module,
      v_scope,
      v_scope_id,
      p_requester_id,
      v_include_tenant_fallback
    );
  END IF;

  IF p_approver_type = 'legal_pool'::puls_workflow.approver_type THEN
    RETURN puls_workflow._resolve_pool_approver_by_type(
      p_tenant_id,
      'legal'::puls_core.authority_pool_type,
      p_module,
      v_scope,
      v_scope_id,
      p_requester_id,
      v_include_tenant_fallback
    );
  END IF;

  IF p_approver_type = 'cost_center_owner'::puls_workflow.approver_type THEN
    IF p_module <> 'expense' THEN
      RETURN NULL;
    END IF;
    IF v_scope IS DISTINCT FROM 'cost_center'::puls_core.authority_scope_type
       OR v_scope_id IS NULL THEN
      RETURN NULL;
    END IF;
    RETURN puls_workflow._resolve_cost_center_owner_approver(
      p_tenant_id,
      v_scope_id,
      p_requester_id
    );
  END IF;

  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION puls_workflow.resolve_policy_step_approver(
  p_tenant_id UUID,
  p_requester_id UUID,
  p_module TEXT,
  p_policy_id UUID,
  p_step_order INTEGER
)
RETURNS UUID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core
AS $$
DECLARE
  v_step RECORD;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM puls_workflow.approval_policies p
    WHERE p.id = p_policy_id
      AND p.tenant_id = p_tenant_id
      AND p.is_active = TRUE
      AND p.module = p_module::puls_workflow.approval_module
  ) THEN
    RAISE EXCEPTION 'PULS_POLICY_NOT_FOUND: Approval policy not found or inactive.'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT s.approver_type, s.specific_employee_id, s.is_required, s.step_resolver_config
  INTO v_step
  FROM puls_workflow.approval_policy_steps s
  JOIN puls_workflow.approval_policies p
    ON p.id = s.policy_id
   AND p.tenant_id = p_tenant_id
  WHERE s.policy_id = p_policy_id
    AND s.tenant_id = p_tenant_id
    AND s.step_order = p_step_order
    AND p.is_active = TRUE
    AND p.module = p_module::puls_workflow.approval_module;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_POLICY_STEP_NOT_FOUND: Required policy step not found.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_step.is_required IS DISTINCT FROM TRUE THEN
    RETURN NULL;
  END IF;

  RETURN puls_workflow._resolve_approver_type_branch(
    p_tenant_id,
    p_requester_id,
    p_module,
    v_step.approver_type,
    v_step.specific_employee_id,
    v_step.step_resolver_config
  );
END;
$$;

CREATE OR REPLACE FUNCTION puls_workflow.resolve_approver(
  p_tenant_id UUID,
  p_requester_id UUID,
  p_module TEXT DEFAULT NULL,
  p_approval_policy_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core, puls_audit
AS $$
DECLARE
  v_step RECORD;
  v_approver_id UUID;
  v_module TEXT := COALESCE(p_module, 'leave');
BEGIN
  IF p_approval_policy_id IS NOT NULL THEN
    SELECT
      s.approver_type,
      s.specific_employee_id,
      s.is_required,
      s.step_resolver_config,
      p.module::text AS policy_module
    INTO v_step
    FROM puls_workflow.approval_policy_steps s
    JOIN puls_workflow.approval_policies p ON p.id = s.policy_id
    WHERE s.policy_id = p_approval_policy_id
      AND s.tenant_id = p_tenant_id
      AND s.step_order = 1
      AND p.is_active = TRUE;

    IF FOUND THEN
      v_module := COALESCE(p_module, v_step.policy_module);
      IF v_step.is_required THEN
        v_approver_id := puls_workflow.resolve_policy_step_approver(
          p_tenant_id,
          p_requester_id,
          v_module,
          p_approval_policy_id,
          1
        );
      ELSE
        v_approver_id := puls_workflow._resolve_approver_type_branch(
          p_tenant_id,
          p_requester_id,
          v_module,
          v_step.approver_type,
          v_step.specific_employee_id,
          v_step.step_resolver_config
        );
      END IF;

      IF v_approver_id IS NOT NULL THEN
        RETURN v_approver_id;
      END IF;
    END IF;
  END IF;

  v_approver_id := puls_workflow.resolve_org_primary_manager(p_tenant_id, p_requester_id);
  IF v_approver_id IS NOT NULL THEN
    RETURN v_approver_id;
  END IF;

  v_approver_id := puls_workflow.resolve_dept_manager(p_tenant_id, p_requester_id);
  IF v_approver_id IS NOT NULL THEN
    RETURN v_approver_id;
  END IF;

  RETURN puls_workflow.resolve_hr_admin_approver(p_tenant_id, p_requester_id);
END;
$$;

-- ---------------------------------------------------------------------------
-- REVOKE / GRANT (new signatures only)
-- ---------------------------------------------------------------------------

REVOKE ALL ON FUNCTION puls_workflow._validate_policy_step_resolver_config_semantics(UUID, JSONB) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_workflow._resolver_step_config_scope(UUID, TEXT, UUID, JSONB) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_workflow._resolve_pool_approver_by_type(UUID, puls_core.authority_pool_type, TEXT, puls_core.authority_scope_type, UUID, UUID, BOOLEAN, DATE) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_workflow._resolve_approver_type_branch(UUID, UUID, TEXT, puls_workflow.approver_type, UUID, JSONB) FROM PUBLIC, authenticated, anon;

GRANT EXECUTE ON FUNCTION puls_workflow._validate_policy_step_resolver_config_semantics(UUID, JSONB) TO service_role;
GRANT EXECUTE ON FUNCTION puls_workflow._resolver_step_config_scope(UUID, TEXT, UUID, JSONB) TO service_role;
GRANT EXECUTE ON FUNCTION puls_workflow._resolve_pool_approver_by_type(UUID, puls_core.authority_pool_type, TEXT, puls_core.authority_scope_type, UUID, UUID, BOOLEAN, DATE) TO service_role;
GRANT EXECUTE ON FUNCTION puls_workflow._resolve_approver_type_branch(UUID, UUID, TEXT, puls_workflow.approver_type, UUID, JSONB) TO service_role;
