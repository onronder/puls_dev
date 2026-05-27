-- 10 PR10.9 — Expense category lifecycle audit (forward-only)
-- Complements PR10.7 lifecycle RPCs with dedicated setup audit persistence.
-- Persists deactivate/restore events and optional deactivate reason (p_reason).
-- No ERP/pre-accounting writes. No resolver/decide/import changes. No hard DELETE.

-- ---------------------------------------------------------------------------
-- Event table
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS puls_workflow.expense_category_lifecycle_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE RESTRICT,
  category_id UUID NOT NULL REFERENCES puls_workflow.expense_categories(id) ON DELETE RESTRICT,
  action TEXT NOT NULL CHECK (action IN ('deactivated', 'restored')),
  reason TEXT NULL,
  actor_user_id UUID NULL,
  actor_role TEXT NULL,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_expense_category_lifecycle_events_category_time
  ON puls_workflow.expense_category_lifecycle_events (tenant_id, category_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_expense_category_lifecycle_events_tenant_time
  ON puls_workflow.expense_category_lifecycle_events (tenant_id, occurred_at DESC);

ALTER TABLE puls_workflow.expense_category_lifecycle_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS expense_category_lifecycle_events_select_admin
  ON puls_workflow.expense_category_lifecycle_events;

CREATE POLICY expense_category_lifecycle_events_select_admin
  ON puls_workflow.expense_category_lifecycle_events
  FOR SELECT
  TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND puls_core.is_admin()
  );

REVOKE ALL ON puls_workflow.expense_category_lifecycle_events FROM PUBLIC, anon, authenticated;
GRANT SELECT ON puls_workflow.expense_category_lifecycle_events TO authenticated;
GRANT SELECT, INSERT ON puls_workflow.expense_category_lifecycle_events TO service_role;

-- ---------------------------------------------------------------------------
-- Public: deactivate (soft; PR10.7 behavior + audit event on real state change)
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
  v_reason TEXT;
  v_event_id UUID;
BEGIN
  v_category := puls_workflow._lock_expense_category_for_setup(p_category_id);

  IF NOT v_category.is_active THEN
    RETURN jsonb_build_object(
      'status', 'already_inactive',
      'category_id', v_category.id
    );
  END IF;

  v_reason := NULLIF(BTRIM(p_reason), '');

  IF v_reason IS NOT NULL AND char_length(v_reason) > 500 THEN
    RAISE EXCEPTION 'PULS_EXPENSE_CATEGORY_LIFECYCLE_REASON_TOO_LONG: reason must be at most 500 characters.'
      USING ERRCODE = 'P0001';
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

  INSERT INTO puls_workflow.expense_category_lifecycle_events (
    tenant_id,
    category_id,
    action,
    reason,
    actor_user_id,
    actor_role
  )
  VALUES (
    v_category.tenant_id,
    v_category.id,
    'deactivated',
    v_reason,
    auth.uid(),
    auth.role()
  )
  RETURNING id INTO v_event_id;

  RETURN jsonb_build_object(
    'status', 'deactivated',
    'category_id', v_category.id,
    'has_history', v_has_history,
    'event_id', v_event_id
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- Public: restore (reactivate; PR10.7 behavior + audit event on real state change)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_workflow.restore_expense_category(p_category_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core
AS $$
DECLARE
  v_category puls_workflow.expense_categories;
  v_event_id UUID;
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

  INSERT INTO puls_workflow.expense_category_lifecycle_events (
    tenant_id,
    category_id,
    action,
    reason,
    actor_user_id,
    actor_role
  )
  VALUES (
    v_category.tenant_id,
    v_category.id,
    'restored',
    NULL,
    auth.uid(),
    auth.role()
  )
  RETURNING id INTO v_event_id;

  RETURN jsonb_build_object(
    'status', 'restored',
    'category_id', v_category.id,
    'event_id', v_event_id
  );
END;
$$;

-- Preserve PR10.7 public RPC grants (functions replaced above)
REVOKE ALL ON FUNCTION puls_workflow.deactivate_expense_category(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION puls_workflow.deactivate_expense_category(UUID, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_workflow.restore_expense_category(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION puls_workflow.restore_expense_category(UUID) TO authenticated, service_role;
