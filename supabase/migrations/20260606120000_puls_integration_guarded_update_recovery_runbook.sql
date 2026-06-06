-- PR16.4.4 guarded update recovery runbook.
-- Adds an operator-facing, read-only recovery runbook before PR16.5 rollback
-- preview. It does not execute rollback, compensating updates, ERP/source
-- writeback, provider calls, credential readback, raw payload readback, or
-- field value readback.

CREATE OR REPLACE FUNCTION puls_integration.list_connector_guarded_update_recovery_runbooks(
  p_change_set_id UUID DEFAULT NULL,
  p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
  change_set_id UUID,
  tenant_id UUID,
  connection_id UUID,
  source_namespace_id UUID,
  import_batch_id UUID,
  status TEXT,
  recommended_action TEXT,
  readiness_status TEXT,
  applied_at TIMESTAMPTZ,
  update_count INTEGER,
  object_event_count INTEGER,
  field_diff_count INTEGER,
  rollback_snapshot_count INTEGER,
  rollback_ready_count INTEGER,
  stale_recheck_verified_count INTEGER,
  blocker_codes TEXT[],
  operator_review_required BOOLEAN,
  approval_required BOOLEAN,
  rollback_preview_candidate BOOLEAN,
  rollback_preview_enabled BOOLEAN,
  rollback_execution_enabled BOOLEAN,
  compensating_execution_enabled BOOLEAN,
  source_writeback_enabled BOOLEAN,
  credential_readback_enabled BOOLEAN,
  value_readback_enabled BOOLEAN,
  hot_retention_expires_at TIMESTAMPTZ,
  purge_after_at TIMESTAMPTZ,
  next_action_key TEXT,
  safe_steps JSONB,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_auth_role TEXT := COALESCE(auth.role(), '');
  v_tenant_id UUID := puls_core.current_tenant_id();
BEGIN
  IF v_auth_role <> 'service_role'
     AND NOT COALESCE(puls_integration.is_import_metadata_reader(), FALSE) THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH recovery AS (
    SELECT
      cs.id AS change_set_id,
      cs.tenant_id,
      cs.connection_id,
      cs.source_namespace_id,
      cs.import_batch_id,
      ib.status AS batch_status,
      ib.applied_at,
      cs.update_count,
      cs.guarded_update_count,
      COALESCE(event_counts.object_event_count, 0)::INTEGER AS object_event_count,
      COALESCE(diff_counts.field_diff_count, 0)::INTEGER AS field_diff_count,
      COALESCE(snapshot_counts.rollback_snapshot_count, 0)::INTEGER AS rollback_snapshot_count,
      COALESCE(snapshot_counts.rollback_ready_count, 0)::INTEGER AS rollback_ready_count,
      COALESCE(diff_counts.stale_recheck_verified_count, 0)::INTEGER
        AS stale_recheck_verified_count,
      snapshot_counts.hot_retention_expires_at,
      snapshot_counts.purge_after_at,
      COALESCE(event_counts.created_at, snapshot_counts.created_at, diff_counts.created_at, cs.created_at)
        AS created_at
    FROM puls_integration.connector_apply_change_sets cs
    JOIN puls_integration.import_batches ib
      ON ib.id = cs.import_batch_id
    LEFT JOIN LATERAL (
      SELECT
        COUNT(*)::INTEGER AS object_event_count,
        MIN(event.created_at) AS created_at
      FROM puls_integration.connector_apply_object_events event
      WHERE event.change_set_id = cs.id
        AND event.operation = 'update'::puls_integration.connector_apply_operation
    ) event_counts ON TRUE
    LEFT JOIN LATERAL (
      SELECT
        COUNT(*)::INTEGER AS field_diff_count,
        COUNT(*) FILTER (
          WHERE diff.expected_current_hash IS NOT NULL
            AND diff.current_hash IS NOT NULL
            AND diff.stale_blocked IS FALSE
        )::INTEGER AS stale_recheck_verified_count,
        MIN(diff.created_at) AS created_at
      FROM puls_integration.connector_apply_field_diffs diff
      WHERE diff.change_set_id = cs.id
    ) diff_counts ON TRUE
    LEFT JOIN LATERAL (
      SELECT
        COUNT(*)::INTEGER AS rollback_snapshot_count,
        COUNT(*) FILTER (
          WHERE snap.snapshot_state = 'available'
            AND snap.value_readback_allowed IS FALSE
            AND snap.hot_retention_expires_at > NOW()
        )::INTEGER AS rollback_ready_count,
        MIN(snap.hot_retention_expires_at) AS hot_retention_expires_at,
        MIN(snap.purge_after_at) AS purge_after_at,
        MIN(snap.created_at) AS created_at
      FROM puls_integration.connector_apply_rollback_snapshots snap
      WHERE snap.change_set_id = cs.id
    ) snapshot_counts ON TRUE
    WHERE cs.guarded_update_count > 0
      AND (v_auth_role = 'service_role' OR cs.tenant_id = v_tenant_id)
      AND (p_change_set_id IS NULL OR cs.id = p_change_set_id)
  ),
  classified AS (
    SELECT
      r.*,
      CASE
        WHEN r.batch_status IS DISTINCT FROM 'applied'::puls_integration.import_batch_status
          THEN 'needs_apply'
        WHEN r.object_event_count <> r.update_count
          OR r.field_diff_count < r.guarded_update_count
          OR r.rollback_snapshot_count < r.guarded_update_count
          THEN 'evidence_gap'
        WHEN r.rollback_ready_count < r.guarded_update_count
          THEN 'compensating_review_required'
        ELSE 'ready_for_rollback_preview'
      END AS status,
      array_remove(ARRAY[
        CASE
          WHEN r.batch_status IS DISTINCT FROM 'applied'::puls_integration.import_batch_status
            THEN 'batch_not_applied'
        END,
        CASE
          WHEN r.object_event_count <> r.update_count
            THEN 'object_event_incomplete'
        END,
        CASE
          WHEN r.field_diff_count < r.guarded_update_count
            THEN 'field_diff_incomplete'
        END,
        CASE
          WHEN r.rollback_snapshot_count < r.guarded_update_count
            THEN 'rollback_snapshot_incomplete'
        END,
        CASE
          WHEN r.rollback_snapshot_count >= r.guarded_update_count
            AND r.rollback_ready_count < r.guarded_update_count
            THEN 'hot_retention_expired'
        END
      ]::TEXT[], NULL) AS blocker_codes
    FROM recovery r
  )
  SELECT
    c.change_set_id,
    c.tenant_id,
    c.connection_id,
    c.source_namespace_id,
    c.import_batch_id,
    c.status,
    CASE c.status
      WHEN 'ready_for_rollback_preview' THEN 'prepare_rollback_preview'
      WHEN 'compensating_review_required' THEN 'prepare_compensating_review'
      WHEN 'evidence_gap' THEN 'repair_evidence_gap'
      ELSE 'wait_for_apply'
    END AS recommended_action,
    CASE
      WHEN c.status = 'ready_for_rollback_preview' THEN 'ready'
      WHEN c.status IN ('evidence_gap', 'compensating_review_required') THEN 'blocked'
      ELSE 'partial'
    END AS readiness_status,
    c.applied_at,
    c.update_count,
    c.object_event_count,
    c.field_diff_count,
    c.rollback_snapshot_count,
    c.rollback_ready_count,
    c.stale_recheck_verified_count,
    c.blocker_codes,
    TRUE AS operator_review_required,
    TRUE AS approval_required,
    c.status = 'ready_for_rollback_preview' AS rollback_preview_candidate,
    FALSE AS rollback_preview_enabled,
    FALSE AS rollback_execution_enabled,
    FALSE AS compensating_execution_enabled,
    FALSE AS source_writeback_enabled,
    FALSE AS credential_readback_enabled,
    FALSE AS value_readback_enabled,
    c.hot_retention_expires_at,
    c.purge_after_at,
    CASE c.status
      WHEN 'ready_for_rollback_preview' THEN 'prepare_rollback_preview_pr16_5'
      WHEN 'compensating_review_required' THEN 'prepare_compensating_review_runbook'
      WHEN 'evidence_gap' THEN 'regenerate_guarded_update_evidence'
      ELSE 'wait_for_guarded_update_worker_apply'
    END AS next_action_key,
    jsonb_build_array(
      jsonb_build_object(
        'step_key', 'verify_original_apply_event',
        'step_status',
          CASE
            WHEN c.batch_status IS DISTINCT FROM 'applied'::puls_integration.import_batch_status
              THEN 'pending'
            WHEN c.object_event_count = c.update_count THEN 'verified'
            ELSE 'blocked'
          END,
        'evidence_count', c.object_event_count,
        'required_count', c.update_count,
        'blocker_code',
          CASE WHEN c.object_event_count <> c.update_count THEN 'object_event_incomplete' END,
        'next_action_key',
          CASE WHEN c.object_event_count <> c.update_count THEN 'review_guarded_update_object_events' END
      ),
      jsonb_build_object(
        'step_key', 'verify_hash_only_field_diffs',
        'step_status',
          CASE
            WHEN c.field_diff_count >= c.guarded_update_count THEN 'verified'
            ELSE 'blocked'
          END,
        'evidence_count', c.field_diff_count,
        'required_count', c.guarded_update_count,
        'blocker_code',
          CASE WHEN c.field_diff_count < c.guarded_update_count THEN 'field_diff_incomplete' END,
        'next_action_key',
          CASE WHEN c.field_diff_count < c.guarded_update_count THEN 'regenerate_guarded_update_evidence' END
      ),
      jsonb_build_object(
        'step_key', 'verify_rollback_snapshot_window',
        'step_status',
          CASE
            WHEN c.rollback_snapshot_count < c.guarded_update_count THEN 'blocked'
            WHEN c.rollback_ready_count < c.guarded_update_count THEN 'blocked'
            ELSE 'verified'
          END,
        'evidence_count', c.rollback_ready_count,
        'required_count', c.guarded_update_count,
        'blocker_code',
          CASE
            WHEN c.rollback_snapshot_count < c.guarded_update_count
              THEN 'rollback_snapshot_incomplete'
            WHEN c.rollback_ready_count < c.guarded_update_count
              THEN 'hot_retention_expired'
          END,
        'next_action_key',
          CASE
            WHEN c.rollback_snapshot_count < c.guarded_update_count
              THEN 'regenerate_guarded_update_evidence'
            WHEN c.rollback_ready_count < c.guarded_update_count
              THEN 'prepare_compensating_review_runbook'
          END
      ),
      jsonb_build_object(
        'step_key', 'prepare_pr16_5_preview_gate',
        'step_status',
          CASE
            WHEN c.status = 'ready_for_rollback_preview' THEN 'candidate'
            ELSE 'blocked'
          END,
        'evidence_count',
          CASE WHEN c.status = 'ready_for_rollback_preview' THEN c.guarded_update_count ELSE 0 END,
        'required_count', c.guarded_update_count,
        'blocker_code',
          CASE WHEN c.status <> 'ready_for_rollback_preview' THEN c.status END,
        'next_action_key',
          CASE
            WHEN c.status = 'ready_for_rollback_preview' THEN 'prepare_rollback_preview_pr16_5'
            ELSE 'review_guarded_update_recovery_runbook'
          END
      )
    ) AS safe_steps,
    c.created_at
  FROM classified c
  ORDER BY c.created_at DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200);
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration.list_connector_apply_safety_contracts(
  p_connection_id UUID DEFAULT NULL
)
RETURNS TABLE (
  connection_id UUID,
  tenant_id UUID,
  contract_version TEXT,
  browser_direct_apply_enabled BOOLEAN,
  authenticated_apply_rpc_exposed BOOLEAN,
  worker_import_apply_enqueue_enabled BOOLEAN,
  worker_import_apply_claim_enabled BOOLEAN,
  execution_enabled BOOLEAN,
  canonical_write_enabled BOOLEAN,
  source_writeback_enabled BOOLEAN,
  credential_readback_enabled BOOLEAN,
  policy_states puls_integration.connector_apply_policy_state[],
  covered_operations puls_integration.connector_apply_operation[],
  audit_tiers puls_integration.connector_apply_audit_tier[],
  destructive_field_classes TEXT[],
  field_diff_hot_retention_days INTEGER,
  rollback_snapshot_hot_retention_days INTEGER,
  object_event_retention_months INTEGER,
  purge_archive_required BOOLEAN,
  safe_error_code TEXT,
  next_action_key TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_auth_role TEXT := COALESCE(auth.role(), '');
  v_tenant_id UUID;
BEGIN
  IF v_auth_role <> 'service_role' THEN
    v_tenant_id := puls_core.current_tenant_id();
    IF v_tenant_id IS NULL THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_APPLY_SAFETY_TENANT_REQUIRED: authenticated caller has no tenant context.';
    END IF;
  END IF;

  RETURN QUERY
  SELECT
    c.id AS connection_id,
    c.tenant_id,
    'pr16.4.4-guarded-update-recovery-runbook-v1'::TEXT AS contract_version,
    FALSE AS browser_direct_apply_enabled,
    FALSE AS authenticated_apply_rpc_exposed,
    TRUE AS worker_import_apply_enqueue_enabled,
    TRUE AS worker_import_apply_claim_enabled,
    TRUE AS execution_enabled,
    TRUE AS canonical_write_enabled,
    FALSE AS source_writeback_enabled,
    FALSE AS credential_readback_enabled,
    ARRAY[
      'create_only'::puls_integration.connector_apply_policy_state,
      'guarded_update'::puls_integration.connector_apply_policy_state,
      'blocked_destructive'::puls_integration.connector_apply_policy_state,
      'rollback_preview_required'::puls_integration.connector_apply_policy_state
    ] AS policy_states,
    ARRAY[
      'insert'::puls_integration.connector_apply_operation,
      'update'::puls_integration.connector_apply_operation,
      'soft_delete'::puls_integration.connector_apply_operation,
      'restore'::puls_integration.connector_apply_operation,
      'rollback'::puls_integration.connector_apply_operation,
      'compensating_update'::puls_integration.connector_apply_operation
    ] AS covered_operations,
    ARRAY[
      'object_event'::puls_integration.connector_apply_audit_tier,
      'field_diff'::puls_integration.connector_apply_audit_tier,
      'rollback_snapshot'::puls_integration.connector_apply_audit_tier,
      'archive_summary'::puls_integration.connector_apply_audit_tier
    ] AS audit_tiers,
    ARRAY[
      'employment_status',
      'is_active',
      'assignment_close',
      'manager_reporting_line',
      'explicit_clear'
    ]::TEXT[] AS destructive_field_classes,
    90 AS field_diff_hot_retention_days,
    90 AS rollback_snapshot_hot_retention_days,
    24 AS object_event_retention_months,
    TRUE AS purge_archive_required,
    'guarded_update_recovery_runbook_open'::TEXT AS safe_error_code,
    'review_guarded_update_recovery_runbook'::TEXT AS next_action_key
  FROM puls_integration.erp_connections c
  WHERE (v_auth_role = 'service_role' OR c.tenant_id = v_tenant_id)
    AND (p_connection_id IS NULL OR c.id = p_connection_id)
  ORDER BY c.updated_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION puls_integration.list_connector_guarded_update_recovery_runbooks(UUID, INTEGER)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.list_connector_guarded_update_recovery_runbooks(UUID, INTEGER)
  TO authenticated, service_role;

COMMENT ON FUNCTION puls_integration.list_connector_guarded_update_recovery_runbooks(UUID, INTEGER) IS
  'PR16.4.4 authenticated-safe guarded update recovery runbook read model. Returns recommended safe action, blocker codes, counts, retention metadata, and safe runbook steps only; no rollback preview/execution or value readback.';
