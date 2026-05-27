-- 10 PR10.13 — Leave type lifecycle audit (forward-only)
-- Complements PR10.12 lifecycle RPCs with dedicated setup audit persistence.
-- Persists deactivate/restore events and optional deactivate reason (p_reason).
-- No ERP/resolver/decide/import changes. No hard DELETE. No consumption path changes.

-- ---------------------------------------------------------------------------
-- Event table
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS puls_workflow.leave_type_lifecycle_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE RESTRICT,
  leave_type_id UUID NOT NULL REFERENCES puls_workflow.leave_types(id) ON DELETE RESTRICT,
  action TEXT NOT NULL CHECK (action IN ('deactivated', 'restored')),
  reason TEXT NULL,
  actor_user_id UUID NULL,
  actor_role TEXT NULL,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_leave_type_lifecycle_events_type_time
  ON puls_workflow.leave_type_lifecycle_events (tenant_id, leave_type_id, occurred_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_leave_type_lifecycle_events_tenant_time
  ON puls_workflow.leave_type_lifecycle_events (tenant_id, occurred_at DESC, id DESC);

ALTER TABLE puls_workflow.leave_type_lifecycle_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS leave_type_lifecycle_events_select_admin
  ON puls_workflow.leave_type_lifecycle_events;

CREATE POLICY leave_type_lifecycle_events_select_admin
  ON puls_workflow.leave_type_lifecycle_events
  FOR SELECT
  TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND puls_core.is_admin()
  );

REVOKE ALL ON puls_workflow.leave_type_lifecycle_events FROM PUBLIC, anon, authenticated;
GRANT SELECT ON puls_workflow.leave_type_lifecycle_events TO authenticated;
GRANT SELECT, INSERT ON puls_workflow.leave_type_lifecycle_events TO service_role;

-- ---------------------------------------------------------------------------
-- Signature migration: PR10.12 single-arg deactivate must be dropped before
-- creating (UUID, TEXT DEFAULT NULL) — CREATE OR REPLACE cannot change arity.
-- ---------------------------------------------------------------------------

REVOKE ALL ON FUNCTION puls_workflow.deactivate_leave_type(UUID) FROM PUBLIC, anon, authenticated, service_role;
DROP FUNCTION IF EXISTS puls_workflow.deactivate_leave_type(UUID);

-- ---------------------------------------------------------------------------
-- Public: deactivate (soft; PR10.12 behavior + audit event on real state change)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_workflow.deactivate_leave_type(
  p_leave_type_id UUID,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core
AS $$
DECLARE
  v_leave_type puls_workflow.leave_types;
  v_has_history BOOLEAN;
  v_reason TEXT;
  v_event_id UUID;
BEGIN
  v_leave_type := puls_workflow._lock_leave_type_for_setup(p_leave_type_id);

  IF NOT v_leave_type.is_active THEN
    RETURN jsonb_build_object(
      'status', 'already_inactive',
      'leave_type_id', v_leave_type.id
    );
  END IF;

  v_reason := NULLIF(BTRIM(p_reason), '');

  IF v_reason IS NOT NULL AND char_length(v_reason) > 500 THEN
    RAISE EXCEPTION 'PULS_LEAVE_TYPE_LIFECYCLE_REASON_TOO_LONG: reason must be at most 500 characters.'
      USING ERRCODE = 'P0001';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM puls_workflow.leave_requests lr
    WHERE lr.tenant_id = v_leave_type.tenant_id
      AND lr.leave_type_id = v_leave_type.id
      AND (
        lr.status IN ('draft', 'pending')
        OR (
          lr.status = 'approved'
          AND lr.end_date >= CURRENT_DATE
        )
      )
  ) THEN
    RAISE EXCEPTION 'PULS_LEAVE_TYPE_IN_USE_ACTIVE_REQUESTS: leave type has open leave requests.'
      USING ERRCODE = 'P0001';
  END IF;

  v_has_history := EXISTS (
    SELECT 1
    FROM puls_workflow.leave_requests lr
    WHERE lr.tenant_id = v_leave_type.tenant_id
      AND lr.leave_type_id = v_leave_type.id
  );

  UPDATE puls_workflow.leave_types
  SET is_active = FALSE,
      updated_at = NOW()
  WHERE id = v_leave_type.id;

  INSERT INTO puls_workflow.leave_type_lifecycle_events (
    tenant_id,
    leave_type_id,
    action,
    reason,
    actor_user_id,
    actor_role,
    metadata
  )
  VALUES (
    v_leave_type.tenant_id,
    v_leave_type.id,
    'deactivated',
    v_reason,
    auth.uid(),
    auth.role(),
    jsonb_build_object('has_history', v_has_history)
  )
  RETURNING id INTO v_event_id;

  RETURN jsonb_build_object(
    'status', 'deactivated',
    'leave_type_id', v_leave_type.id,
    'has_history', v_has_history,
    'event_id', v_event_id
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- Public: restore (reactivate; PR10.12 behavior + audit event on real state change)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_workflow.restore_leave_type(p_leave_type_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core
AS $$
DECLARE
  v_leave_type puls_workflow.leave_types;
  v_event_id UUID;
BEGIN
  v_leave_type := puls_workflow._lock_leave_type_for_setup(p_leave_type_id);

  IF v_leave_type.is_active THEN
    RETURN jsonb_build_object(
      'status', 'already_active',
      'leave_type_id', v_leave_type.id
    );
  END IF;

  UPDATE puls_workflow.leave_types
  SET is_active = TRUE,
      updated_at = NOW()
  WHERE id = v_leave_type.id;

  INSERT INTO puls_workflow.leave_type_lifecycle_events (
    tenant_id,
    leave_type_id,
    action,
    reason,
    actor_user_id,
    actor_role
  )
  VALUES (
    v_leave_type.tenant_id,
    v_leave_type.id,
    'restored',
    NULL,
    auth.uid(),
    auth.role()
  )
  RETURNING id INTO v_event_id;

  RETURN jsonb_build_object(
    'status', 'restored',
    'leave_type_id', v_leave_type.id,
    'event_id', v_event_id
  );
END;
$$;

REVOKE ALL ON FUNCTION puls_workflow.deactivate_leave_type(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION puls_workflow.deactivate_leave_type(UUID, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_workflow.restore_leave_type(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION puls_workflow.restore_leave_type(UUID) TO authenticated, service_role;
