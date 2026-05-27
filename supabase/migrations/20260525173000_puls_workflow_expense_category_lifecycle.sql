-- 10 PR10.7 — Expense category lifecycle (soft deactivate / restore via RPC)
-- Inspect notes (schema verified against 20260523160000_puls_workflow_leave_expense.sql):
--   expense_categories: is_active, approval_policy_id, erp_account_code, updated_at (+ trigger)
--   expense_claims.category_id → expense_categories ON DELETE RESTRICT
--   expense_claim_status values: draft, pending, approved, rejected, cancelled, exported (no submitted)
--   approved = pre-export active finance workflow; exported = closed/reimbursed path
--   create_expense_claim enforces ec.is_active = TRUE (new expense entries already blocked for inactive)
-- Deactivate blocks only open claims: draft, pending, approved.
-- approval_policy_id binding is preserved and does NOT block deactivate (PR10.7 scope).
-- p_reason accepted in signature but not persisted (no reason column on table).
-- No hard DELETE. No ERP/resolver/decide/import/policy-editor changes.

-- ---------------------------------------------------------------------------
-- Internal: row lock + tenant / admin guard
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_workflow._lock_expense_category_for_setup(p_category_id UUID)
RETURNS puls_workflow.expense_categories
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core
AS $$
DECLARE
  v_category puls_workflow.expense_categories;
BEGIN
  SELECT *
  INTO v_category
  FROM puls_workflow.expense_categories ec
  WHERE ec.id = p_category_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_EXPENSE_CATEGORY_NOT_FOUND: category % not found.', p_category_id
      USING ERRCODE = 'P0001';
  END IF;

  IF auth.role() <> 'service_role' THEN
    IF v_category.tenant_id IS DISTINCT FROM puls_core.current_tenant_id() THEN
      RAISE EXCEPTION 'PULS_EXPENSE_CATEGORY_FORBIDDEN: category belongs to another tenant.'
        USING ERRCODE = 'P0001';
    END IF;

    IF NOT puls_core.is_admin() THEN
      RAISE EXCEPTION 'PULS_EXPENSE_CATEGORY_FORBIDDEN: admin privileges required.'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  RETURN v_category;
END;
$$;

-- ---------------------------------------------------------------------------
-- Public: deactivate (soft; preserves approval_policy_id and historical claims)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_workflow.deactivate_expense_category(
  p_category_id UUID,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core
AS $$
DECLARE
  v_category puls_workflow.expense_categories;
  v_has_history BOOLEAN;
BEGIN
  v_category := puls_workflow._lock_expense_category_for_setup(p_category_id);

  IF NOT v_category.is_active THEN
    RETURN jsonb_build_object(
      'status', 'already_inactive',
      'category_id', v_category.id
    );
  END IF;

  IF EXISTS (
    SELECT 1
    FROM puls_workflow.expense_claims ec
    WHERE ec.tenant_id = v_category.tenant_id
      AND ec.category_id = v_category.id
      AND ec.status IN ('draft', 'pending', 'approved')
  ) THEN
    RAISE EXCEPTION 'PULS_EXPENSE_CATEGORY_IN_USE_ACTIVE_CLAIMS: category has open expense claims.'
      USING ERRCODE = 'P0001';
  END IF;

  v_has_history := EXISTS (
    SELECT 1
    FROM puls_workflow.expense_claims ec
    WHERE ec.tenant_id = v_category.tenant_id
      AND ec.category_id = v_category.id
  );

  UPDATE puls_workflow.expense_categories
  SET is_active = FALSE,
      updated_at = NOW()
  WHERE id = v_category.id;

  RETURN jsonb_build_object(
    'status', 'deactivated',
    'category_id', v_category.id,
    'has_history', v_has_history
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- Public: restore (reactivate; PR10.5 guardrails + active accounting unique apply)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_workflow.restore_expense_category(p_category_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core
AS $$
DECLARE
  v_category puls_workflow.expense_categories;
BEGIN
  v_category := puls_workflow._lock_expense_category_for_setup(p_category_id);

  IF v_category.is_active THEN
    RETURN jsonb_build_object(
      'status', 'already_active',
      'category_id', v_category.id
    );
  END IF;

  UPDATE puls_workflow.expense_categories
  SET is_active = TRUE,
      updated_at = NOW()
  WHERE id = v_category.id;

  RETURN jsonb_build_object(
    'status', 'restored',
    'category_id', v_category.id
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- REVOKE / GRANT
-- ---------------------------------------------------------------------------

REVOKE ALL ON FUNCTION puls_workflow._lock_expense_category_for_setup(UUID) FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_workflow._lock_expense_category_for_setup(UUID) TO service_role;

REVOKE ALL ON FUNCTION puls_workflow.deactivate_expense_category(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION puls_workflow.deactivate_expense_category(UUID, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_workflow.restore_expense_category(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION puls_workflow.restore_expense_category(UUID) TO authenticated, service_role;
