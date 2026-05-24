-- 06 hotfix 3 — assigned approver parent read (display-only RLS)
-- Unblocks overview adapters: approval_requests visible but parent leave/expense
-- rows were hidden unless requester.manager_employee_id matched current user.
-- Pending-only: targets actionable approval tabs, not approval history.

DROP POLICY IF EXISTS puls_workflow_leave_requests_select_assigned_approver
  ON puls_workflow.leave_requests;

CREATE POLICY puls_workflow_leave_requests_select_assigned_approver
  ON puls_workflow.leave_requests
  FOR SELECT TO authenticated
  USING (
    leave_requests.tenant_id = puls_core.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM puls_workflow.approval_requests ar
      WHERE ar.leave_request_id = leave_requests.id
        AND ar.tenant_id = puls_core.current_tenant_id()
        AND ar.tenant_id = leave_requests.tenant_id
        AND ar.status = 'pending'::puls_workflow.approval_status
        AND ar.approver_employee_id = puls_core.current_employee_id()
        AND ar.requester_employee_id <> puls_core.current_employee_id()
    )
  );

DROP POLICY IF EXISTS puls_workflow_expense_claims_select_assigned_approver
  ON puls_workflow.expense_claims;

CREATE POLICY puls_workflow_expense_claims_select_assigned_approver
  ON puls_workflow.expense_claims
  FOR SELECT TO authenticated
  USING (
    expense_claims.tenant_id = puls_core.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM puls_workflow.approval_requests ar
      WHERE ar.expense_claim_id = expense_claims.id
        AND ar.tenant_id = puls_core.current_tenant_id()
        AND ar.tenant_id = expense_claims.tenant_id
        AND ar.status = 'pending'::puls_workflow.approval_status
        AND ar.approver_employee_id = puls_core.current_employee_id()
        AND ar.requester_employee_id <> puls_core.current_employee_id()
    )
  );
