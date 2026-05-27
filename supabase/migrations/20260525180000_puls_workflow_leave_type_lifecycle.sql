-- 10 PR10.12 — Leave type lifecycle (soft deactivate / restore via RPC)
-- Inspect notes (schema verified against 20260523160000_puls_workflow_leave_expense.sql):
--   leave_types: id, tenant_id, code, name, is_active, approval_policy_id, updated_at (+ PR10.11 guardrail trigger)
--   leave_requests.leave_type_id → leave_types ON DELETE RESTRICT
--   leave_request_status: draft, pending, approved, rejected, cancelled (no submitted; no completed/exported/taken)
--   create_leave_request enforces lt.is_active = TRUE (new leave entries already blocked for inactive)
-- Deactivate guard is date-aware for approved leave (NOT a blind copy of expense PR10.7):
--   draft, pending → always block
--   approved → block only when end_date >= CURRENT_DATE (current/future leave)
--   past approved (end_date < CURRENT_DATE) → historical, deactivate allowed
-- Expense PR10.7 treats all approved as open because exported is the finance closure status; leave has no equivalent.
-- approval_policy_id binding is preserved and does NOT block deactivate.
-- No audit reason yet (PR10.13). No hard DELETE. No ERP/resolver/decide/import/policy-editor changes.

-- ---------------------------------------------------------------------------
-- Internal: row lock + tenant / admin guard
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_workflow._lock_leave_type_for_setup(p_leave_type_id UUID)
RETURNS puls_workflow.leave_types
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core
AS $$
DECLARE
  v_leave_type puls_workflow.leave_types;
BEGIN
  SELECT *
  INTO v_leave_type
  FROM puls_workflow.leave_types lt
  WHERE lt.id = p_leave_type_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_LEAVE_TYPE_NOT_FOUND: leave type % not found.', p_leave_type_id
      USING ERRCODE = 'P0001';
  END IF;

  IF auth.role() <> 'service_role' THEN
    IF v_leave_type.tenant_id IS DISTINCT FROM puls_core.current_tenant_id() THEN
      RAISE EXCEPTION 'PULS_LEAVE_TYPE_FORBIDDEN: leave type belongs to another tenant.'
        USING ERRCODE = 'P0001';
    END IF;

    IF NOT puls_core.is_admin() THEN
      RAISE EXCEPTION 'PULS_LEAVE_TYPE_FORBIDDEN: admin privileges required.'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  RETURN v_leave_type;
END;
$$;

-- ---------------------------------------------------------------------------
-- Public: deactivate (soft; preserves approval_policy_id and historical requests)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_workflow.deactivate_leave_type(p_leave_type_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core
AS $$
DECLARE
  v_leave_type puls_workflow.leave_types;
  v_has_history BOOLEAN;
BEGIN
  v_leave_type := puls_workflow._lock_leave_type_for_setup(p_leave_type_id);

  IF NOT v_leave_type.is_active THEN
    RETURN jsonb_build_object(
      'status', 'already_inactive',
      'leave_type_id', v_leave_type.id
    );
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

  RETURN jsonb_build_object(
    'status', 'deactivated',
    'leave_type_id', v_leave_type.id,
    'has_history', v_has_history
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- Public: restore (reactivate; PR10.11 guardrails apply on UPDATE)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_workflow.restore_leave_type(p_leave_type_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_core
AS $$
DECLARE
  v_leave_type puls_workflow.leave_types;
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

  RETURN jsonb_build_object(
    'status', 'restored',
    'leave_type_id', v_leave_type.id
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- REVOKE / GRANT
-- ---------------------------------------------------------------------------

REVOKE ALL ON FUNCTION puls_workflow._lock_leave_type_for_setup(UUID) FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_workflow._lock_leave_type_for_setup(UUID) TO service_role;

REVOKE ALL ON FUNCTION puls_workflow.deactivate_leave_type(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION puls_workflow.deactivate_leave_type(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_workflow.restore_leave_type(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION puls_workflow.restore_leave_type(UUID) TO authenticated, service_role;
