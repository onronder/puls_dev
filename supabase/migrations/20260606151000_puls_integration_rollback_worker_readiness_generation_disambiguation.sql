-- PR16.7 rollback worker readiness generation ambiguity fix.
-- The original PR16.7 generation RPC used RETURNS TABLE output column names
-- that overlap with CTE column names. PL/pgSQL exposes output columns as
-- variables, so aggregate references such as field_diff_count can become
-- ambiguous at runtime. Replacing only the generation RPC with an explicit
-- variable_conflict policy and qualified aggregate aliases preserves the
-- readiness contract while keeping rollback execution closed.

CREATE OR REPLACE FUNCTION puls_integration.generate_connector_guarded_update_rollback_worker_readiness(
  p_rollback_approval_id UUID
)
RETURNS TABLE (
  rollback_worker_readiness_id UUID,
  rollback_approval_id UUID,
  rollback_preview_id UUID,
  change_set_id UUID,
  tenant_id UUID,
  connection_id UUID,
  source_namespace_id UUID,
  import_batch_id UUID,
  readiness_status TEXT,
  readiness_policy TEXT,
  worker_contract TEXT,
  expected_job_type TEXT,
  expected_job_domain TEXT,
  rollback_preview_checksum TEXT,
  row_count INTEGER,
  rollback_count INTEGER,
  blocker_count INTEGER,
  stale_blocked_count INTEGER,
  drift_blocked_count INTEGER,
  expired_snapshot_count INTEGER,
  field_diff_count INTEGER,
  rollback_snapshot_count INTEGER,
  original_apply_event_count INTEGER,
  current_state_verified_count INTEGER,
  retention_verified_count INTEGER,
  approval_verified BOOLEAN,
  approval_checksum_verified BOOLEAN,
  worker_handoff_ready BOOLEAN,
  rollback_job_enqueue_enabled BOOLEAN,
  rollback_execution_enabled BOOLEAN,
  canonical_write_enabled BOOLEAN,
  compensating_execution_enabled BOOLEAN,
  source_writeback_enabled BOOLEAN,
  credential_readback_enabled BOOLEAN,
  value_readback_enabled BOOLEAN,
  provider_api_calls_enabled BOOLEAN,
  approval_required BOOLEAN,
  operator_review_required BOOLEAN,
  next_action_key TEXT,
  safe_summary JSONB,
  sample_items JSONB,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
#variable_conflict use_column
DECLARE
  v_auth_role TEXT := COALESCE(auth.role(), '');
  v_is_service_role BOOLEAN := v_auth_role = 'service_role';
  v_tenant_id UUID := puls_core.current_tenant_id();
  v_approval puls_integration.connector_apply_rollback_approvals;
  v_preview puls_integration.connector_apply_rollback_previews;
  v_change_set puls_integration.connector_apply_change_sets;
  v_batch puls_integration.import_batches;
  v_existing_readiness_id UUID;
  v_row_count INTEGER := 0;
  v_blocker_count INTEGER := 0;
  v_stale_blocked_count INTEGER := 0;
  v_drift_blocked_count INTEGER := 0;
  v_expired_snapshot_count INTEGER := 0;
  v_field_diff_count INTEGER := 0;
  v_snapshot_ready_count INTEGER := 0;
  v_original_apply_event_count INTEGER := 0;
  v_current_state_verified_count INTEGER := 0;
  v_retention_verified_count INTEGER := 0;
BEGIN
  IF NOT v_is_service_role AND NOT COALESCE(puls_core.is_admin(), FALSE) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_READINESS_ADMIN_REQUIRED: admin permission is required.';
  END IF;

  IF NOT v_is_service_role AND v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_READINESS_TENANT_REQUIRED: authenticated caller has no tenant context.';
  END IF;

  SELECT *
  INTO v_approval
  FROM puls_integration.connector_apply_rollback_approvals approval
  WHERE approval.id = p_rollback_approval_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_READINESS_APPROVAL_NOT_FOUND: rollback approval not found.';
  END IF;

  IF NOT v_is_service_role AND v_approval.tenant_id IS DISTINCT FROM v_tenant_id THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_READINESS_FORBIDDEN: rollback approval belongs to another tenant.';
  END IF;

  SELECT *
  INTO v_preview
  FROM puls_integration.connector_apply_rollback_previews preview
  WHERE preview.id = v_approval.rollback_preview_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_READINESS_PREVIEW_NOT_FOUND: rollback preview not found.';
  END IF;

  SELECT *
  INTO v_change_set
  FROM puls_integration.connector_apply_change_sets cs
  WHERE cs.id = v_approval.change_set_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_READINESS_CHANGE_SET_NOT_FOUND: change-set not found.';
  END IF;

  SELECT *
  INTO v_batch
  FROM puls_integration.import_batches ib
  WHERE ib.id = v_approval.import_batch_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_READINESS_BATCH_NOT_FOUND: import batch not found.';
  END IF;

  IF v_batch.status IS DISTINCT FROM 'applied'::puls_integration.import_batch_status THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_READINESS_APPLIED_BATCH_REQUIRED: rollback worker readiness requires an applied batch.';
  END IF;

  IF v_approval.approval_status IS DISTINCT FROM 'approval_recorded'
     OR v_approval.rollback_approval_enabled IS NOT TRUE
     OR v_approval.rollback_execution_enabled IS NOT FALSE
     OR v_approval.compensating_execution_enabled IS NOT FALSE
     OR v_approval.source_writeback_enabled IS NOT FALSE
     OR v_approval.credential_readback_enabled IS NOT FALSE
     OR v_approval.value_readback_enabled IS NOT FALSE THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_READINESS_APPROVAL_INVALID: rollback approval safety boundary is invalid.';
  END IF;

  IF v_preview.status IS DISTINCT FROM 'ready_for_rollback_review'
     OR v_preview.preview_kind IS DISTINCT FROM 'rollback'
     OR v_preview.rollback_preview_checksum IS DISTINCT FROM v_approval.rollback_preview_checksum
     OR v_preview.rollback_execution_enabled IS NOT FALSE
     OR v_preview.compensating_execution_enabled IS NOT FALSE
     OR v_preview.source_writeback_enabled IS NOT FALSE
     OR v_preview.credential_readback_enabled IS NOT FALSE
     OR v_preview.value_readback_enabled IS NOT FALSE THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_READINESS_PREVIEW_INVALID: rollback preview is not readiness-safe.';
  END IF;

  SELECT readiness.id
  INTO v_existing_readiness_id
  FROM puls_integration.connector_apply_rollback_worker_readiness readiness
  WHERE readiness.rollback_approval_id = v_approval.id;

  IF FOUND THEN
    RETURN QUERY
    SELECT readiness_row.*
    FROM puls_integration.list_connector_guarded_update_rollback_worker_readiness(
      v_approval.change_set_id,
      50
    ) AS readiness_row
    WHERE readiness_row.rollback_worker_readiness_id = v_existing_readiness_id;
    RETURN;
  END IF;

  WITH readiness_rows AS (
    SELECT
      item.id AS rollback_preview_item_id,
      item.change_set_item_id,
      item.row_number,
      item.entity_type,
      item.external_id,
      item.canonical_id,
      item.item_status,
      item.blocker_codes,
      item.field_diff_count,
      item.rollback_snapshot_available,
      item.snapshot_state,
      item.hot_retention_expires_at,
      item.expected_post_apply_hash,
      item.stale_blocked,
      current_guard.current_hash,
      COALESCE(event_counts.original_apply_event_count, 0)::INTEGER AS original_apply_event_count,
      (
        current_guard.current_hash IS NOT NULL
        AND current_guard.current_hash IS NOT DISTINCT FROM item.expected_post_apply_hash
      ) AS current_state_matches_apply,
      (
        item.rollback_snapshot_available IS TRUE
        AND item.snapshot_state = 'available'
        AND item.hot_retention_expires_at > NOW()
      ) AS retention_ready
    FROM puls_integration.connector_apply_rollback_preview_items item
    CROSS JOIN LATERAL (
      SELECT puls_integration._connector_apply_expected_current_hash(
        v_approval.tenant_id,
        v_approval.source_namespace_id,
        item.entity_type,
        item.external_id,
        item.canonical_id
      ) AS current_hash
    ) current_guard
    LEFT JOIN LATERAL (
      SELECT COUNT(*)::INTEGER AS original_apply_event_count
      FROM puls_integration.connector_apply_object_events event
      WHERE event.change_set_item_id = item.change_set_item_id
        AND event.operation = 'update'::puls_integration.connector_apply_operation
        AND event.canonical_id = item.canonical_id
    ) event_counts ON TRUE
    WHERE item.rollback_preview_id = v_preview.id
  ),
  classified AS (
    SELECT
      readiness_rows.*,
      array_remove(ARRAY[
        CASE
          WHEN readiness_rows.item_status IS DISTINCT FROM 'ready'
            OR cardinality(readiness_rows.blocker_codes) > 0
          THEN 'rollback_preview_item_blocked'
        END,
        CASE WHEN readiness_rows.field_diff_count <= 0 THEN 'field_diff_missing' END,
        CASE WHEN readiness_rows.retention_ready IS NOT TRUE THEN 'rollback_snapshot_unavailable' END,
        CASE WHEN readiness_rows.current_hash IS NULL THEN 'current_hash_missing' END,
        CASE
          WHEN readiness_rows.current_hash IS NOT NULL
            AND readiness_rows.current_state_matches_apply IS FALSE
          THEN 'current_state_drift'
        END,
        CASE
          WHEN readiness_rows.original_apply_event_count <= 0
          THEN 'original_apply_event_missing'
        END
      ]::TEXT[], NULL) AS blocker_codes_out
    FROM readiness_rows
  )
  SELECT
    COUNT(*)::INTEGER,
    COUNT(*) FILTER (WHERE cardinality(classified_row.blocker_codes_out) > 0)::INTEGER,
    COUNT(*) FILTER (WHERE classified_row.stale_blocked IS TRUE)::INTEGER,
    COUNT(*) FILTER (
      WHERE classified_row.blocker_codes_out @> ARRAY['current_state_drift']::TEXT[]
        OR classified_row.blocker_codes_out @> ARRAY['current_hash_missing']::TEXT[]
    )::INTEGER,
    COUNT(*) FILTER (
      WHERE classified_row.blocker_codes_out @> ARRAY['rollback_snapshot_unavailable']::TEXT[]
    )::INTEGER,
    COALESCE(SUM(classified_row.field_diff_count), 0)::INTEGER,
    COUNT(*) FILTER (WHERE classified_row.retention_ready IS TRUE)::INTEGER,
    COALESCE(SUM(classified_row.original_apply_event_count), 0)::INTEGER,
    COUNT(*) FILTER (WHERE classified_row.current_state_matches_apply IS TRUE)::INTEGER,
    COUNT(*) FILTER (WHERE classified_row.retention_ready IS TRUE)::INTEGER
  INTO
    v_row_count,
    v_blocker_count,
    v_stale_blocked_count,
    v_drift_blocked_count,
    v_expired_snapshot_count,
    v_field_diff_count,
    v_snapshot_ready_count,
    v_original_apply_event_count,
    v_current_state_verified_count,
    v_retention_verified_count
  FROM classified AS classified_row;

  IF v_row_count <= 0
     OR v_row_count <> v_preview.row_count
     OR v_preview.rollback_count <> v_preview.row_count
     OR v_blocker_count <> 0
     OR v_stale_blocked_count <> 0
     OR v_drift_blocked_count <> 0
     OR v_expired_snapshot_count <> 0
     OR v_field_diff_count <= 0
     OR v_snapshot_ready_count < v_row_count
     OR v_original_apply_event_count < v_row_count
     OR v_current_state_verified_count <> v_row_count
     OR v_retention_verified_count <> v_row_count THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_READINESS_BLOCKED: approval, current-state, event, or retention checks are not ready.';
  END IF;

  INSERT INTO puls_integration.connector_apply_rollback_worker_readiness (
    tenant_id,
    connection_id,
    source_namespace_id,
    import_batch_id,
    change_set_id,
    rollback_preview_id,
    rollback_approval_id,
    rollback_preview_checksum,
    row_count,
    rollback_count,
    blocker_count,
    stale_blocked_count,
    drift_blocked_count,
    expired_snapshot_count,
    field_diff_count,
    rollback_snapshot_count,
    original_apply_event_count,
    current_state_verified_count,
    retention_verified_count,
    safe_summary
  )
  VALUES (
    v_approval.tenant_id,
    v_approval.connection_id,
    v_approval.source_namespace_id,
    v_approval.import_batch_id,
    v_approval.change_set_id,
    v_approval.rollback_preview_id,
    v_approval.id,
    v_approval.rollback_preview_checksum,
    v_row_count,
    v_preview.rollback_count,
    v_blocker_count,
    v_stale_blocked_count,
    v_drift_blocked_count,
    v_expired_snapshot_count,
    v_field_diff_count,
    v_snapshot_ready_count,
    v_original_apply_event_count,
    v_current_state_verified_count,
    v_retention_verified_count,
    jsonb_build_object(
      'contract_version', 'pr16.7-guarded-update-rollback-worker-readiness-v1',
      'worker_contract', 'pr16.7-rollback-worker-readiness-v1',
      'rollback_worker_readiness', TRUE,
      'rollback_worker_handoff_ready', TRUE,
      'expected_job_type', 'import_apply',
      'expected_job_domain', 'import_apply_guarded_update_rollback',
      'rollback_approval_id', v_approval.id,
      'rollback_preview_id', v_approval.rollback_preview_id,
      'change_set_id', v_approval.change_set_id,
      'import_batch_id', v_approval.import_batch_id,
      'rollback_preview_checksum', v_approval.rollback_preview_checksum,
      'row_count', v_row_count,
      'rollback_count', v_preview.rollback_count,
      'field_diff_count', v_field_diff_count,
      'rollback_snapshot_count', v_snapshot_ready_count,
      'original_apply_event_count', v_original_apply_event_count,
      'current_state_verified_count', v_current_state_verified_count,
      'retention_verified_count', v_retention_verified_count,
      'approval_verified', TRUE,
      'approval_checksum_verified', TRUE,
      'approval_required', TRUE,
      'operator_review_required', TRUE,
      'rollback_job_enqueue', FALSE,
      'rollback_execution', FALSE,
      'canonical_write', FALSE,
      'compensating_execution', FALSE,
      'source_writeback', FALSE,
      'provider_api_calls', FALSE,
      'credential_readback', FALSE,
      'field_value_readback', FALSE,
      'raw_payload_readback', FALSE,
      'snapshot_payload_readback', FALSE
    )
  )
  RETURNING id INTO v_existing_readiness_id;

  RETURN QUERY
  SELECT readiness_row.*
  FROM puls_integration.list_connector_guarded_update_rollback_worker_readiness(
    v_approval.change_set_id,
    50
  ) AS readiness_row
  WHERE readiness_row.rollback_worker_readiness_id = v_existing_readiness_id;
END;
$$;

REVOKE ALL ON FUNCTION puls_integration.generate_connector_guarded_update_rollback_worker_readiness(UUID)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.generate_connector_guarded_update_rollback_worker_readiness(UUID)
  TO authenticated, service_role;

COMMENT ON FUNCTION puls_integration.generate_connector_guarded_update_rollback_worker_readiness(UUID) IS
  'PR16.7 admin/service-role RPC that records immutable guarded-update rollback worker readiness without enqueueing or executing rollback. Replaced by 20260606151000 to disambiguate CTE columns from RETURNS TABLE output variables.';
