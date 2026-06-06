-- PR16.4.3 guarded update recovery readiness.
-- Adds a safe post-apply read model for guarded updates after PR16.4.2 worker
-- execution. It does not execute rollback, compensating updates, ERP/source
-- writeback, provider calls, credential readback, raw payload readback, or
-- field value readback.

CREATE OR REPLACE FUNCTION puls_integration.list_connector_guarded_update_recovery_readiness(
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
  applied_at TIMESTAMPTZ,
  update_count INTEGER,
  object_event_count INTEGER,
  field_diff_count INTEGER,
  rollback_snapshot_count INTEGER,
  rollback_ready_count INTEGER,
  stale_recheck_verified_count INTEGER,
  rollback_execution_enabled BOOLEAN,
  compensating_preview_enabled BOOLEAN,
  source_writeback_enabled BOOLEAN,
  credential_readback_enabled BOOLEAN,
  value_readback_enabled BOOLEAN,
  recovery_window_hot_retention_days INTEGER,
  hot_retention_expires_at TIMESTAMPTZ,
  purge_after_at TIMESTAMPTZ,
  purge_archive_required BOOLEAN,
  next_action_key TEXT,
  sample_events JSONB,
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
  v_limit INTEGER := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200);
BEGIN
  IF v_auth_role <> 'service_role'
     AND NOT COALESCE(puls_integration.is_import_metadata_reader(), FALSE) THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    cs.id AS change_set_id,
    cs.tenant_id,
    cs.connection_id,
    cs.source_namespace_id,
    cs.import_batch_id,
    CASE
      WHEN ib.status IS DISTINCT FROM 'applied'::puls_integration.import_batch_status
        THEN 'needs_apply'
      WHEN COALESCE(event_counts.object_event_count, 0) <> cs.update_count
        THEN 'object_event_incomplete'
      WHEN COALESCE(diff_counts.field_diff_count, 0) < cs.guarded_update_count
        THEN 'field_diff_incomplete'
      WHEN COALESCE(snapshot_counts.rollback_snapshot_count, 0) < cs.guarded_update_count
        THEN 'rollback_snapshot_incomplete'
      WHEN COALESCE(snapshot_counts.rollback_ready_count, 0) < cs.guarded_update_count
        THEN 'hot_retention_expired'
      ELSE 'recovery_ready'
    END AS status,
    ib.applied_at,
    cs.update_count,
    COALESCE(event_counts.object_event_count, 0)::INTEGER AS object_event_count,
    COALESCE(diff_counts.field_diff_count, 0)::INTEGER AS field_diff_count,
    COALESCE(snapshot_counts.rollback_snapshot_count, 0)::INTEGER AS rollback_snapshot_count,
    COALESCE(snapshot_counts.rollback_ready_count, 0)::INTEGER AS rollback_ready_count,
    COALESCE(diff_counts.stale_recheck_verified_count, 0)::INTEGER AS stale_recheck_verified_count,
    FALSE AS rollback_execution_enabled,
    FALSE AS compensating_preview_enabled,
    FALSE AS source_writeback_enabled,
    FALSE AS credential_readback_enabled,
    FALSE AS value_readback_enabled,
    90 AS recovery_window_hot_retention_days,
    snapshot_counts.hot_retention_expires_at,
    snapshot_counts.purge_after_at,
    TRUE AS purge_archive_required,
    CASE
      WHEN ib.status IS DISTINCT FROM 'applied'::puls_integration.import_batch_status
        THEN 'wait_for_guarded_update_worker_apply'
      WHEN COALESCE(event_counts.object_event_count, 0) <> cs.update_count
        THEN 'review_guarded_update_object_events'
      WHEN COALESCE(diff_counts.field_diff_count, 0) < cs.guarded_update_count
        OR COALESCE(snapshot_counts.rollback_snapshot_count, 0) < cs.guarded_update_count
        THEN 'regenerate_guarded_update_evidence'
      WHEN COALESCE(snapshot_counts.rollback_ready_count, 0) < cs.guarded_update_count
        THEN 'prepare_compensating_review_runbook'
      ELSE 'prepare_rollback_preview_pr16_5'
    END AS next_action_key,
    COALESCE(samples.sample_events, '[]'::JSONB) AS sample_events,
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
  LEFT JOIN LATERAL (
    SELECT jsonb_agg(
      jsonb_build_object(
        'id', sample.id,
        'row_number', sample.row_number,
        'operation', sample.operation,
        'entity_type', sample.entity_type,
        'external_id', sample.external_id,
        'target_table', sample.target_table,
        'canonical_id', sample.canonical_id,
        'connector_job_id', sample.connector_job_id,
        'created_by_worker_id', sample.created_by_worker_id,
        'created_at', sample.created_at,
        'safe_field_names', sample.safe_summary -> 'safe_field_names',
        'field_diff_count', COALESCE((sample.safe_summary ->> 'field_diff_count')::INTEGER, 0),
        'rollback_snapshot_required',
          COALESCE((sample.safe_summary ->> 'rollback_snapshot_required')::BOOLEAN, FALSE),
        'canonical_write', COALESCE((sample.safe_summary ->> 'canonical_write')::BOOLEAN, FALSE),
        'source_writeback', COALESCE((sample.safe_summary ->> 'source_writeback')::BOOLEAN, FALSE),
        'provider_api_calls', COALESCE((sample.safe_summary ->> 'provider_api_calls')::BOOLEAN, FALSE),
        'credential_readback',
          COALESCE((sample.safe_summary ->> 'credential_readback')::BOOLEAN, FALSE),
        'field_value_readback',
          COALESCE((sample.safe_summary ->> 'field_value_readback')::BOOLEAN, FALSE),
        'raw_payload_readback',
          COALESCE((sample.safe_summary ->> 'raw_payload_readback')::BOOLEAN, FALSE),
        'rollback_execution',
          COALESCE((sample.safe_summary ->> 'rollback_execution')::BOOLEAN, FALSE)
      )
      ORDER BY sample.created_at DESC, sample.id DESC
    ) AS sample_events
    FROM (
      SELECT event.*, item.row_number
      FROM puls_integration.connector_apply_object_events event
      JOIN puls_integration.connector_apply_change_set_items item
        ON item.id = event.change_set_item_id
      WHERE event.change_set_id = cs.id
        AND event.operation = 'update'::puls_integration.connector_apply_operation
      ORDER BY event.created_at DESC, event.id DESC
      LIMIT v_limit
    ) sample
  ) samples ON TRUE
  WHERE cs.guarded_update_count > 0
    AND (v_auth_role = 'service_role' OR cs.tenant_id = v_tenant_id)
    AND (p_change_set_id IS NULL OR cs.id = p_change_set_id)
  ORDER BY COALESCE(event_counts.created_at, snapshot_counts.created_at, diff_counts.created_at, cs.created_at) DESC;
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
    'pr16.4.3-guarded-update-recovery-readiness-v1'::TEXT AS contract_version,
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
    'guarded_update_recovery_readiness_open'::TEXT AS safe_error_code,
    'review_guarded_update_recovery_readiness'::TEXT AS next_action_key
  FROM puls_integration.erp_connections c
  WHERE (v_auth_role = 'service_role' OR c.tenant_id = v_tenant_id)
    AND (p_connection_id IS NULL OR c.id = p_connection_id)
  ORDER BY c.updated_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION puls_integration.list_connector_guarded_update_recovery_readiness(UUID, INTEGER)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.list_connector_guarded_update_recovery_readiness(UUID, INTEGER)
  TO authenticated, service_role;

COMMENT ON FUNCTION puls_integration.list_connector_guarded_update_recovery_readiness(UUID, INTEGER) IS
  'PR16.4.3 authenticated-safe guarded update post-apply recovery readiness read model. Returns counts, hashes/readiness flags, retention metadata, and safe object event summaries only; no rollback execution or value readback.';
