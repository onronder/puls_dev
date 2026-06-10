-- PR17.2G3A: tighten expense receipt OCR human-review authorization.
--
-- G3 already restricts write access to admins or assigned approvers. This
-- follow-up explicitly blocks self-review even when the requester also has an
-- admin persona. Canonical expense writes remain closed.

CREATE OR REPLACE FUNCTION puls_workflow.can_review_expense_receipt_ocr(
  p_result_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM puls_workflow.expense_receipt_ocr_results result
    JOIN puls_workflow.expense_claims claim
      ON claim.id = result.expense_claim_id
     AND claim.tenant_id = result.tenant_id
    WHERE result.id = p_result_id
      AND result.tenant_id = puls_core.current_tenant_id()
      AND claim.employee_id IS DISTINCT FROM puls_core.current_employee_id()
      AND (
        puls_core.is_admin()
        OR puls_workflow._workflow_evidence_is_assigned_approver(
          'expense'::puls_workflow.evidence_upload_domain,
          result.expense_claim_id,
          puls_core.current_employee_id()
        )
      )
  );
$$;

COMMENT ON FUNCTION puls_workflow.can_review_expense_receipt_ocr(UUID)
  IS 'Returns true when the current user can record an expense receipt OCR review. Self-review is blocked even for admins.';

REVOKE ALL ON FUNCTION puls_workflow.can_review_expense_receipt_ocr(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION puls_workflow.can_review_expense_receipt_ocr(UUID) TO authenticated;
