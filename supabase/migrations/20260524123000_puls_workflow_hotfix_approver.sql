-- 06 hotfix — resolve_approver manager persona fallback (forward-only)
-- Primary path remains requester.manager_employee_id; manager persona is a V1 deterministic fallback.

CREATE OR REPLACE FUNCTION puls_workflow.resolve_approver(
  p_tenant_id uuid,
  p_requester_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core, puls_audit
AS $$
DECLARE
  v_manager_id uuid;
  v_approver_id uuid;
BEGIN
  SELECT e.manager_employee_id
  INTO v_manager_id
  FROM puls_core.employees e
  WHERE e.id = p_requester_id
    AND e.tenant_id = p_tenant_id
    AND e.employment_status = 'active';

  IF v_manager_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1
      FROM puls_core.employees m
      WHERE m.id = v_manager_id
        AND m.tenant_id = p_tenant_id
        AND m.employment_status = 'active'
        AND m.id <> p_requester_id
    ) THEN
      RETURN v_manager_id;
    END IF;
  END IF;

  SELECT e.id
  INTO v_approver_id
  FROM puls_core.employees e
  WHERE e.tenant_id = p_tenant_id
    AND e.employment_status = 'active'
    AND e.persona_role = 'manager'::puls_core.persona_role
    AND e.id <> p_requester_id
  ORDER BY e.created_at ASC NULLS LAST
  LIMIT 1;

  IF v_approver_id IS NOT NULL THEN
    RETURN v_approver_id;
  END IF;

  SELECT e.id
  INTO v_approver_id
  FROM puls_core.employees e
  WHERE e.tenant_id = p_tenant_id
    AND e.employment_status = 'active'
    AND e.persona_role = 'hr_admin'::puls_core.persona_role
    AND e.id <> p_requester_id
  ORDER BY e.created_at ASC NULLS LAST
  LIMIT 1;

  IF v_approver_id IS NOT NULL THEN
    RETURN v_approver_id;
  END IF;

  SELECT e.id
  INTO v_approver_id
  FROM puls_core.employees e
  WHERE e.tenant_id = p_tenant_id
    AND e.employment_status = 'active'
    AND e.persona_role = 'superadmin'::puls_core.persona_role
    AND e.id <> p_requester_id
  ORDER BY e.created_at ASC NULLS LAST
  LIMIT 1;

  RETURN v_approver_id;
END;
$$;

REVOKE ALL ON FUNCTION puls_workflow.resolve_approver(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION puls_workflow.resolve_approver(uuid, uuid) FROM authenticated;
REVOKE ALL ON FUNCTION puls_workflow.resolve_approver(uuid, uuid) FROM anon;
