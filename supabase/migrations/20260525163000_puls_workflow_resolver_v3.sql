-- 09 PR5 — Approval Resolver V3 (authority graph pools + cost_center_owner)
-- Does NOT modify decide_approval_request or 08 policy engine file.
-- Manager SoT remains employee_reporting_lines (07). Fail closed on unresolved.

-- ---------------------------------------------------------------------------
-- Internal: requester cost center (assignment SoT, cache fallback)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_workflow._resolver_requester_cost_center_id(
  p_tenant_id UUID,
  p_requester_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core
AS $$
DECLARE
  v_cc_id UUID;
BEGIN
  SELECT a.cost_center_id
  INTO v_cc_id
  FROM puls_core.employee_cost_center_assignments a
  WHERE a.tenant_id = p_tenant_id
    AND a.employee_id = p_requester_id
    AND a.is_active = TRUE
  LIMIT 1;

  IF v_cc_id IS NULL THEN
    SELECT e.cost_center_id
    INTO v_cc_id
    FROM puls_core.employees e
    WHERE e.id = p_requester_id
      AND e.tenant_id = p_tenant_id;
  END IF;

  IF v_cc_id IS NULL THEN
    RETURN NULL;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM puls_core.cost_centers cc
    WHERE cc.id = v_cc_id
      AND cc.tenant_id = p_tenant_id
      AND cc.is_active = TRUE
  ) THEN
    RETURN v_cc_id;
  END IF;

  RETURN NULL;
END;
$$;

-- ---------------------------------------------------------------------------
-- Internal: pool lookup scope from module + cost center (no category routing)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_workflow._resolver_pool_scope(
  p_module TEXT,
  p_cost_center_id UUID
)
RETURNS TABLE (scope_type puls_core.authority_scope_type, scope_id UUID)
LANGUAGE plpgsql
IMMUTABLE
SET search_path = pg_catalog, puls_core
AS $$
BEGIN
  IF p_module = 'expense' AND p_cost_center_id IS NOT NULL THEN
    scope_type := 'cost_center'::puls_core.authority_scope_type;
    scope_id := p_cost_center_id;
    RETURN NEXT;
    RETURN;
  END IF;

  scope_type := 'tenant'::puls_core.authority_scope_type;
  scope_id := NULL;
  RETURN NEXT;
END;
$$;

-- ---------------------------------------------------------------------------
-- Internal: resolve pool member by pool_type (scope precedence before priority)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_workflow._resolve_pool_approver_by_type(
  p_tenant_id UUID,
  p_pool_type puls_core.authority_pool_type,
  p_module TEXT,
  p_scope_type puls_core.authority_scope_type,
  p_scope_id UUID,
  p_exclude_employee_id UUID,
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
      (p.scope_type = 'tenant'::puls_core.authority_scope_type AND p.scope_id IS NULL)
      OR (
        p.scope_type = p_scope_type
        AND p.scope_id IS NOT DISTINCT FROM p_scope_id
      )
    )
    AND m.is_active = TRUE
    AND m.starts_on <= p_as_of
    AND (m.ends_on IS NULL OR m.ends_on >= p_as_of)
    AND m.employee_id IS DISTINCT FROM p_exclude_employee_id
    AND e.employment_status = 'active'::puls_core.employment_status
  ORDER BY
    CASE
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
-- Internal: cost_center_owner from authority_relationships (active employee join)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_workflow._resolve_cost_center_owner_approver(
  p_tenant_id UUID,
  p_cost_center_id UUID,
  p_exclude_employee_id UUID,
  p_as_of DATE DEFAULT CURRENT_DATE
)
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core
AS $$
  SELECT ar.subject_employee_id
  FROM puls_core.authority_relationships ar
  JOIN puls_core.employees e
    ON e.id = ar.subject_employee_id
   AND e.tenant_id = ar.tenant_id
  WHERE ar.tenant_id = p_tenant_id
    AND ar.authority_type = 'cost_center_owner'::puls_core.authority_type
    AND ar.scope_type = 'cost_center'::puls_core.authority_scope_type
    AND ar.scope_id = p_cost_center_id
    AND ar.module = 'global'::puls_core.authority_module
    AND ar.is_active = TRUE
    AND ar.starts_on <= p_as_of
    AND (ar.ends_on IS NULL OR ar.ends_on >= p_as_of)
    AND ar.subject_employee_id IS DISTINCT FROM p_exclude_employee_id
    AND e.employment_status = 'active'::puls_core.employment_status
  ORDER BY ar.priority ASC, ar.starts_on ASC, ar.id ASC
  LIMIT 1;
$$;

-- ---------------------------------------------------------------------------
-- Internal: shared approver_type branch resolution
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_workflow._resolve_approver_type_branch(
  p_tenant_id UUID,
  p_requester_id UUID,
  p_module TEXT,
  p_approver_type puls_workflow.approver_type,
  p_specific_employee_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core
AS $$
DECLARE
  v_approver_id UUID;
  v_cost_center_id UUID;
  v_scope puls_core.authority_scope_type;
  v_scope_id UUID;
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

  v_cost_center_id := puls_workflow._resolver_requester_cost_center_id(p_tenant_id, p_requester_id);

  SELECT ps.scope_type, ps.scope_id
  INTO v_scope, v_scope_id
  FROM puls_workflow._resolver_pool_scope(p_module, v_cost_center_id) ps;

  IF p_approver_type = 'finance_pool'::puls_workflow.approver_type THEN
    RETURN puls_workflow._resolve_pool_approver_by_type(
      p_tenant_id,
      'finance'::puls_core.authority_pool_type,
      p_module,
      v_scope,
      v_scope_id,
      p_requester_id
    );
  END IF;

  IF p_approver_type = 'hr_pool'::puls_workflow.approver_type THEN
    RETURN puls_workflow._resolve_pool_approver_by_type(
      p_tenant_id,
      'hr'::puls_core.authority_pool_type,
      p_module,
      v_scope,
      v_scope_id,
      p_requester_id
    );
  END IF;

  IF p_approver_type = 'legal_pool'::puls_workflow.approver_type THEN
    RETURN puls_workflow._resolve_pool_approver_by_type(
      p_tenant_id,
      'legal'::puls_core.authority_pool_type,
      p_module,
      v_scope,
      v_scope_id,
      p_requester_id
    );
  END IF;

  IF p_approver_type = 'cost_center_owner'::puls_workflow.approver_type THEN
    IF p_module <> 'expense' OR v_cost_center_id IS NULL THEN
      RETURN NULL;
    END IF;
    RETURN puls_workflow._resolve_cost_center_owner_approver(
      p_tenant_id,
      v_cost_center_id,
      p_requester_id
    );
  END IF;

  RETURN NULL;
END;
$$;

-- ---------------------------------------------------------------------------
-- resolve_policy_step_approver V3
-- ---------------------------------------------------------------------------

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

  SELECT s.approver_type, s.specific_employee_id, s.is_required
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
    v_step.specific_employee_id
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- resolve_approver V2 bridge (delegates step 1; preserves is_required=false behavior)
-- ---------------------------------------------------------------------------

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
    SELECT s.approver_type, s.specific_employee_id, s.is_required, p.module::text AS policy_module
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
          v_step.specific_employee_id
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
-- REVOKE / GRANT (internal resolver surface unchanged)
-- ---------------------------------------------------------------------------

REVOKE ALL ON FUNCTION puls_workflow._resolver_requester_cost_center_id(UUID, UUID) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_workflow._resolver_pool_scope(TEXT, UUID) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_workflow._resolve_pool_approver_by_type(UUID, puls_core.authority_pool_type, TEXT, puls_core.authority_scope_type, UUID, UUID, DATE) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_workflow._resolve_cost_center_owner_approver(UUID, UUID, UUID, DATE) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_workflow._resolve_approver_type_branch(UUID, UUID, TEXT, puls_workflow.approver_type, UUID) FROM PUBLIC, authenticated, anon;

REVOKE ALL ON FUNCTION puls_workflow.resolve_policy_step_approver(UUID, UUID, TEXT, UUID, INTEGER) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_workflow.resolve_approver(UUID, UUID, TEXT, UUID) FROM PUBLIC, authenticated, anon;

GRANT EXECUTE ON FUNCTION puls_workflow._resolver_requester_cost_center_id(UUID, UUID) TO service_role;
GRANT EXECUTE ON FUNCTION puls_workflow._resolver_pool_scope(TEXT, UUID) TO service_role;
GRANT EXECUTE ON FUNCTION puls_workflow._resolve_pool_approver_by_type(UUID, puls_core.authority_pool_type, TEXT, puls_core.authority_scope_type, UUID, UUID, DATE) TO service_role;
GRANT EXECUTE ON FUNCTION puls_workflow._resolve_cost_center_owner_approver(UUID, UUID, UUID, DATE) TO service_role;
GRANT EXECUTE ON FUNCTION puls_workflow._resolve_approver_type_branch(UUID, UUID, TEXT, puls_workflow.approver_type, UUID) TO service_role;
