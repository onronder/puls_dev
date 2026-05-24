-- 07 PR2 — org authority helpers (hardened search_path) + RLS standardization

-- ---------------------------------------------------------------------------
-- RLS predicate helpers (GRANT authenticated + service_role)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_core.is_direct_manager_of(target_employee_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
  SELECT
    target_employee_id IS NOT NULL
    AND puls_core.current_employee_id() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM puls_core.employees e
      WHERE e.id = target_employee_id
        AND e.tenant_id = puls_core.current_tenant_id()
        AND e.manager_employee_id = puls_core.current_employee_id()
    );
$$;

CREATE OR REPLACE FUNCTION puls_core.is_management_chain_member(target_employee_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
  WITH RECURSIVE chain AS (
    SELECT e.manager_employee_id AS mgr_id, 1 AS depth, ARRAY[e.id]::UUID[] AS visited
    FROM puls_core.employees e
    WHERE e.id = target_employee_id
      AND e.tenant_id = puls_core.current_tenant_id()
    UNION ALL
    SELECT e.manager_employee_id, c.depth + 1, c.visited || e.id
    FROM chain c
    JOIN puls_core.employees e ON e.id = c.mgr_id
    WHERE c.mgr_id IS NOT NULL
      AND c.depth < 20
      AND NOT e.id = ANY(c.visited)
      AND e.tenant_id = puls_core.current_tenant_id()
  )
  SELECT EXISTS (
    SELECT 1
    FROM chain
    WHERE mgr_id = puls_core.current_employee_id()
  );
$$;

CREATE OR REPLACE FUNCTION puls_core.is_assigned_approver_for(p_module TEXT, p_parent_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
  SELECT CASE COALESCE(p_module, '')
    WHEN 'leave' THEN EXISTS (
      SELECT 1
      FROM puls_workflow.approval_requests ar
      WHERE ar.leave_request_id = p_parent_id
        AND ar.tenant_id = puls_core.current_tenant_id()
        AND ar.status = 'pending'::puls_workflow.approval_status
        AND ar.approver_employee_id = puls_core.current_employee_id()
        AND ar.requester_employee_id <> puls_core.current_employee_id()
    )
    WHEN 'expense' THEN EXISTS (
      SELECT 1
      FROM puls_workflow.approval_requests ar
      WHERE ar.expense_claim_id = p_parent_id
        AND ar.tenant_id = puls_core.current_tenant_id()
        AND ar.status = 'pending'::puls_workflow.approval_status
        AND ar.approver_employee_id = puls_core.current_employee_id()
        AND ar.requester_employee_id <> puls_core.current_employee_id()
    )
    ELSE FALSE
  END;
$$;

CREATE OR REPLACE FUNCTION puls_core.can_read_employee(target_employee_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
  SELECT
    target_employee_id IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM puls_core.employees target
      WHERE target.id = target_employee_id
        AND target.tenant_id = puls_core.current_tenant_id()
    )
    AND (
      puls_core.is_admin()
      OR target_employee_id = puls_core.current_employee_id()
      OR puls_core.is_direct_manager_of(target_employee_id)
      OR puls_core.is_management_chain_member(target_employee_id)
      OR EXISTS (
        SELECT 1
        FROM puls_workflow.approval_requests ar
        WHERE ar.requester_employee_id = target_employee_id
          AND ar.approver_employee_id = puls_core.current_employee_id()
          AND ar.tenant_id = puls_core.current_tenant_id()
          AND ar.status = 'pending'::puls_workflow.approval_status
          AND ar.requester_employee_id <> puls_core.current_employee_id()
      )
    );
$$;

CREATE OR REPLACE FUNCTION puls_core.can_read_workflow_parent(p_module TEXT, p_parent_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
  SELECT CASE COALESCE(p_module, '')
    WHEN 'leave' THEN EXISTS (
      SELECT 1
      FROM puls_workflow.leave_requests lr
      WHERE lr.id = p_parent_id
        AND lr.tenant_id = puls_core.current_tenant_id()
        AND (
          puls_core.is_admin()
          OR lr.employee_id = puls_core.current_employee_id()
          OR puls_core.is_direct_manager_of(lr.employee_id)
          OR puls_core.is_management_chain_member(lr.employee_id)
          OR puls_core.is_assigned_approver_for('leave', lr.id)
        )
    )
    WHEN 'expense' THEN EXISTS (
      SELECT 1
      FROM puls_workflow.expense_claims ec
      WHERE ec.id = p_parent_id
        AND ec.tenant_id = puls_core.current_tenant_id()
        AND (
          puls_core.is_admin()
          OR ec.employee_id = puls_core.current_employee_id()
          OR puls_core.is_direct_manager_of(ec.employee_id)
          OR puls_core.is_management_chain_member(ec.employee_id)
          OR puls_core.is_assigned_approver_for('expense', ec.id)
        )
    )
    ELSE FALSE
  END;
$$;

DO $$
DECLARE
  v_fn TEXT;
BEGIN
  FOREACH v_fn IN ARRAY ARRAY[
    'is_direct_manager_of(uuid)',
    'is_management_chain_member(uuid)',
    'is_assigned_approver_for(text,uuid)',
    'can_read_employee(uuid)',
    'can_read_workflow_parent(text,uuid)'
  ] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION puls_core.%s FROM PUBLIC', v_fn);
    EXECUTE format('REVOKE ALL ON FUNCTION puls_core.%s FROM anon', v_fn);
    EXECUTE format('GRANT EXECUTE ON FUNCTION puls_core.%s TO authenticated', v_fn);
    EXECUTE format('GRANT EXECUTE ON FUNCTION puls_core.%s TO service_role', v_fn);
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- puls_core.employees — fixes assigned-approver requester name visibility
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS puls_core_employees_select ON puls_core.employees;
CREATE POLICY puls_core_employees_select ON puls_core.employees
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND puls_core.can_read_employee(id)
  );

-- ---------------------------------------------------------------------------
-- puls_core.employee_reporting_lines — expand SELECT beyond admin
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS puls_core_reporting_lines_select ON puls_core.employee_reporting_lines;
CREATE POLICY puls_core_reporting_lines_select ON puls_core.employee_reporting_lines
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND (
      puls_core.is_admin()
      OR puls_core.can_read_employee(employee_id)
    )
  );

-- ---------------------------------------------------------------------------
-- puls_workflow leave/expense — consolidate manager + assigned approver
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS puls_workflow_leave_requests_select_assigned_approver
  ON puls_workflow.leave_requests;

DROP POLICY IF EXISTS puls_workflow_leave_requests_select ON puls_workflow.leave_requests;
CREATE POLICY puls_workflow_leave_requests_select ON puls_workflow.leave_requests
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND puls_core.can_read_workflow_parent('leave', id)
  );

DROP POLICY IF EXISTS puls_workflow_expense_claims_select_assigned_approver
  ON puls_workflow.expense_claims;

DROP POLICY IF EXISTS puls_workflow_expense_claims_select ON puls_workflow.expense_claims;
CREATE POLICY puls_workflow_expense_claims_select ON puls_workflow.expense_claims
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND puls_core.can_read_workflow_parent('expense', id)
  );

DROP POLICY IF EXISTS puls_workflow_leave_balances_select ON puls_workflow.leave_balances;
CREATE POLICY puls_workflow_leave_balances_select ON puls_workflow.leave_balances
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND puls_core.can_read_employee(employee_id)
  );

DROP POLICY IF EXISTS puls_workflow_leave_documents_select ON puls_workflow.leave_documents;
CREATE POLICY puls_workflow_leave_documents_select ON puls_workflow.leave_documents
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND puls_core.can_read_workflow_parent('leave', leave_request_id)
  );

DROP POLICY IF EXISTS puls_workflow_expense_receipts_select ON puls_workflow.expense_receipts;
CREATE POLICY puls_workflow_expense_receipts_select ON puls_workflow.expense_receipts
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND puls_core.can_read_workflow_parent('expense', expense_claim_id)
  );

DROP POLICY IF EXISTS puls_workflow_approval_requests_select ON puls_workflow.approval_requests;
CREATE POLICY puls_workflow_approval_requests_select ON puls_workflow.approval_requests
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND (
      puls_core.is_admin()
      OR requester_employee_id = puls_core.current_employee_id()
      OR approver_employee_id = puls_core.current_employee_id()
      OR puls_core.can_read_employee(requester_employee_id)
    )
  );

-- ---------------------------------------------------------------------------
-- puls_performance — management chain via can_read_employee
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS puls_performance_kpis_select ON puls_performance.performance_kpis;
CREATE POLICY puls_performance_kpis_select ON puls_performance.performance_kpis
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND (
      puls_core.is_admin()
      OR employee_id = puls_core.current_employee_id()
      OR puls_core.can_read_employee(employee_id)
    )
  );

DROP POLICY IF EXISTS puls_performance_competency_evaluations_select
  ON puls_performance.competency_evaluations;
CREATE POLICY puls_performance_competency_evaluations_select
  ON puls_performance.competency_evaluations
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND (
      puls_core.is_admin()
      OR employee_id = puls_core.current_employee_id()
      OR puls_core.can_read_employee(employee_id)
    )
  );

DROP POLICY IF EXISTS puls_performance_scores_select ON puls_performance.performance_scores;
CREATE POLICY puls_performance_scores_select ON puls_performance.performance_scores
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND (
      puls_core.is_admin()
      OR employee_id = puls_core.current_employee_id()
      OR puls_core.can_read_employee(employee_id)
    )
  );

DROP POLICY IF EXISTS puls_performance_career_profiles_select ON puls_performance.career_profiles;
CREATE POLICY puls_performance_career_profiles_select ON puls_performance.career_profiles
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND (
      puls_core.is_admin()
      OR employee_id = puls_core.current_employee_id()
      OR puls_core.can_read_employee(employee_id)
    )
  );

DROP POLICY IF EXISTS puls_performance_training_needs_select ON puls_performance.training_needs;
CREATE POLICY puls_performance_training_needs_select ON puls_performance.training_needs
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND (
      puls_core.is_admin()
      OR employee_id = puls_core.current_employee_id()
      OR puls_core.can_read_employee(employee_id)
    )
  );
