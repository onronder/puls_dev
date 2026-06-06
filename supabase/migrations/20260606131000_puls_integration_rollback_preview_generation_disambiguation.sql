-- PR16.5 rollback preview generation ambiguity fix.
-- The original PR16.5 generation RPC used RETURNS TABLE output column names that
-- overlap with CTE column names. PL/pgSQL treats those output columns as
-- variables, so aggregate references such as field_diff_count can become
-- ambiguous at runtime. Replacing only the generation RPC with
-- variable_conflict=use_column preserves the existing preview contract while
-- forcing SQL statements to prefer CTE/table columns.

CREATE OR REPLACE FUNCTION puls_integration.generate_connector_guarded_update_rollback_preview(
  p_change_set_id UUID
)
RETURNS TABLE (
  rollback_preview_id UUID,
  change_set_id UUID,
  tenant_id UUID,
  connection_id UUID,
  source_namespace_id UUID,
  import_batch_id UUID,
  status TEXT,
  preview_kind TEXT,
  rollback_preview_checksum TEXT,
  row_count INTEGER,
  rollback_count INTEGER,
  blocked_count INTEGER,
  stale_blocked_count INTEGER,
  field_diff_count INTEGER,
  rollback_snapshot_count INTEGER,
  rollback_preview_enabled BOOLEAN,
  rollback_execution_enabled BOOLEAN,
  compensating_execution_enabled BOOLEAN,
  source_writeback_enabled BOOLEAN,
  credential_readback_enabled BOOLEAN,
  value_readback_enabled BOOLEAN,
  approval_required BOOLEAN,
  operator_review_required BOOLEAN,
  next_action_key TEXT,
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
  v_change_set puls_integration.connector_apply_change_sets;
  v_batch puls_integration.import_batches;
  v_runbook RECORD;
  v_preview_id UUID;
  v_preview_checksum TEXT;
  v_actor_employee_id UUID := NULLIF(current_setting('request.jwt.claim.employee_id', true), '')::UUID;
  v_row_count INTEGER := 0;
  v_blocked_count INTEGER := 0;
  v_stale_blocked_count INTEGER := 0;
  v_field_diff_count INTEGER := 0;
  v_snapshot_count INTEGER := 0;
BEGIN
  IF NOT v_is_service_role AND NOT COALESCE(puls_core.is_admin(), FALSE) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_PREVIEW_ADMIN_REQUIRED: admin permission is required.';
  END IF;

  IF NOT v_is_service_role AND v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_PREVIEW_TENANT_REQUIRED: authenticated caller has no tenant context.';
  END IF;

  SELECT *
  INTO v_change_set
  FROM puls_integration.connector_apply_change_sets cs
  WHERE cs.id = p_change_set_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_PREVIEW_CHANGE_SET_NOT_FOUND: change-set not found.';
  END IF;

  IF NOT v_is_service_role AND v_change_set.tenant_id IS DISTINCT FROM v_tenant_id THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_PREVIEW_FORBIDDEN: change-set belongs to another tenant.';
  END IF;

  IF COALESCE(v_change_set.guarded_update_count, 0) <= 0 THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_PREVIEW_GUARDED_UPDATE_REQUIRED: change-set has no guarded update rows.';
  END IF;

  SELECT *
  INTO v_batch
  FROM puls_integration.import_batches ib
  WHERE ib.id = v_change_set.import_batch_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_PREVIEW_BATCH_NOT_FOUND: import batch not found.';
  END IF;

  IF v_batch.status IS DISTINCT FROM 'applied'::puls_integration.import_batch_status THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_PREVIEW_APPLIED_BATCH_REQUIRED: guarded update batch must be applied.';
  END IF;

  IF NOT puls_integration._connector_apply_has_batch_admin_approval(p_change_set_id) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_PREVIEW_APPROVAL_REQUIRED: admin approval is required before rollback preview.';
  END IF;

  SELECT *
  INTO v_runbook
  FROM puls_integration.list_connector_guarded_update_recovery_runbooks(p_change_set_id, 1)
  LIMIT 1;

  IF NOT FOUND OR v_runbook.status IS DISTINCT FROM 'ready_for_rollback_preview' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_PREVIEW_RUNBOOK_NOT_READY: recovery runbook must be ready for rollback preview.';
  END IF;

  SELECT preview.id
  INTO v_preview_id
  FROM puls_integration.connector_apply_rollback_previews preview
  WHERE preview.change_set_id = p_change_set_id;

  IF FOUND THEN
    RETURN QUERY
    SELECT *
    FROM puls_integration.list_connector_guarded_update_rollback_previews(p_change_set_id, 50);
    RETURN;
  END IF;

  WITH rollback_rows AS (
    SELECT
      item.id AS change_set_item_id,
      item.row_number,
      item.entity_type,
      item.external_id,
      item.target_table,
      item.canonical_id,
      item.safe_field_names,
      item.source_row_hash AS expected_post_apply_hash,
      current_guard.current_hash,
      snap.snapshot_hash,
      COALESCE(snap.snapshot_state, 'missing') AS snapshot_state,
      snap.hot_retention_expires_at,
      diff_counts.field_diff_count,
      diff_counts.rollback_field_names,
      (
        snap.id IS NOT NULL
        AND snap.snapshot_state = 'available'
        AND snap.value_readback_allowed IS FALSE
        AND snap.hot_retention_expires_at > NOW()
      ) AS rollback_snapshot_available,
      (
        current_guard.current_hash IS NOT NULL
        AND current_guard.current_hash IS NOT DISTINCT FROM item.source_row_hash
      ) AS current_state_matches_apply
    FROM puls_integration.connector_apply_change_set_items item
    LEFT JOIN puls_integration.connector_apply_rollback_snapshots snap
      ON snap.change_set_item_id = item.id
    LEFT JOIN LATERAL (
      SELECT
        COUNT(*)::INTEGER AS field_diff_count,
        COALESCE(array_agg(diff.field_name ORDER BY diff.field_name), '{}'::TEXT[])
          AS rollback_field_names
      FROM puls_integration.connector_apply_field_diffs diff
      WHERE diff.change_set_item_id = item.id
    ) diff_counts ON TRUE
    CROSS JOIN LATERAL (
      SELECT puls_integration._connector_apply_expected_current_hash(
        v_change_set.tenant_id,
        v_change_set.source_namespace_id,
        item.entity_type,
        item.external_id,
        item.canonical_id
      ) AS current_hash
    ) current_guard
    WHERE item.change_set_id = p_change_set_id
      AND item.operation = 'update'::puls_integration.connector_apply_operation
      AND item.risk_class = 'guarded_overwrite'::puls_integration.connector_apply_risk_class
  ),
  classified AS (
    SELECT
      row.*,
      array_remove(ARRAY[
        CASE
          WHEN row.rollback_snapshot_available IS NOT TRUE THEN 'rollback_snapshot_unavailable'
        END,
        CASE
          WHEN row.field_diff_count <= 0 THEN 'field_diff_missing'
        END,
        CASE
          WHEN row.current_hash IS NULL THEN 'current_hash_missing'
        END,
        CASE
          WHEN row.current_hash IS NOT NULL
            AND row.current_state_matches_apply IS FALSE THEN 'current_state_drift'
        END
      ]::TEXT[], NULL) AS blocker_codes
    FROM rollback_rows row
  )
  SELECT
    COUNT(*)::INTEGER,
    COUNT(*) FILTER (WHERE cardinality(blocker_codes) > 0)::INTEGER,
    COUNT(*) FILTER (
      WHERE blocker_codes @> ARRAY['current_state_drift']::TEXT[]
        OR blocker_codes @> ARRAY['current_hash_missing']::TEXT[]
    )::INTEGER,
    COALESCE(SUM(field_diff_count), 0)::INTEGER,
    COUNT(*) FILTER (WHERE rollback_snapshot_available IS TRUE)::INTEGER,
    encode(
      sha256(
        convert_to(
          concat_ws(
            ':',
            'pr16.5-guarded-update-rollback-preview-v1',
            v_change_set.id::TEXT,
            v_change_set.change_set_checksum,
            COALESCE(
              string_agg(
                concat_ws(
                  '|',
                  row_number::TEXT,
                  entity_type::TEXT,
                  external_id,
                  canonical_id::TEXT,
                  COALESCE(expected_post_apply_hash, ''),
                  COALESCE(current_hash, ''),
                  COALESCE(snapshot_hash, ''),
                  COALESCE(array_to_string(rollback_field_names, ','), ''),
                  COALESCE(array_to_string(blocker_codes, ','), '')
                ),
                '||'
                ORDER BY row_number
              ),
              ''
            )
          ),
          'UTF8'
        )
      ),
      'hex'
    )
  INTO
    v_row_count,
    v_blocked_count,
    v_stale_blocked_count,
    v_field_diff_count,
    v_snapshot_count,
    v_preview_checksum
  FROM classified;

  IF v_row_count <> v_change_set.guarded_update_count THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_PREVIEW_ITEM_COUNT_MISMATCH: rollback preview item count must match guarded update count.';
  END IF;

  INSERT INTO puls_integration.connector_apply_rollback_previews (
    tenant_id,
    connection_id,
    source_namespace_id,
    import_batch_id,
    change_set_id,
    status,
    rollback_preview_checksum,
    row_count,
    rollback_count,
    blocked_count,
    stale_blocked_count,
    field_diff_count,
    rollback_snapshot_count,
    next_action_key,
    safe_summary,
    created_by_employee_id
  )
  VALUES (
    v_change_set.tenant_id,
    v_change_set.connection_id,
    v_change_set.source_namespace_id,
    v_change_set.import_batch_id,
    v_change_set.id,
    CASE WHEN v_blocked_count = 0 THEN 'ready_for_rollback_review' ELSE 'blocked' END,
    v_preview_checksum,
    v_row_count,
    v_row_count - v_blocked_count,
    v_blocked_count,
    v_stale_blocked_count,
    v_field_diff_count,
    v_snapshot_count,
    CASE
      WHEN v_blocked_count = 0 THEN 'review_rollback_preview_before_execution'
      WHEN v_stale_blocked_count > 0 THEN 'review_current_state_drift'
      ELSE 'repair_rollback_preview_evidence'
    END,
    jsonb_build_object(
      'contract_version', 'pr16.5-guarded-update-rollback-preview-v1',
      'change_set_id', v_change_set.id,
      'import_batch_id', v_change_set.import_batch_id,
      'row_count', v_row_count,
      'rollback_count', v_row_count - v_blocked_count,
      'blocked_count', v_blocked_count,
      'stale_blocked_count', v_stale_blocked_count,
      'field_diff_count', v_field_diff_count,
      'rollback_snapshot_count', v_snapshot_count,
      'rollback_preview', TRUE,
      'rollback_execution', FALSE,
      'compensating_execution', FALSE,
      'canonical_write', FALSE,
      'source_writeback', FALSE,
      'provider_api_calls', FALSE,
      'credential_readback', FALSE,
      'field_value_readback', FALSE,
      'raw_payload_readback', FALSE,
      'snapshot_payload_readback', FALSE
    ),
    CASE WHEN v_is_service_role THEN NULL ELSE v_actor_employee_id END
  )
  RETURNING id INTO v_preview_id;

  INSERT INTO puls_integration.connector_apply_rollback_preview_items (
    tenant_id,
    rollback_preview_id,
    change_set_id,
    change_set_item_id,
    import_batch_id,
    import_record_id,
    row_number,
    entity_type,
    external_id,
    target_table,
    canonical_id,
    item_status,
    blocker_codes,
    safe_field_names,
    rollback_field_names,
    field_diff_count,
    rollback_snapshot_available,
    snapshot_state,
    snapshot_hash,
    expected_post_apply_hash,
    current_hash,
    current_state_matches_apply,
    stale_blocked,
    hot_retention_expires_at,
    purge_after_at,
    safe_summary
  )
  SELECT
    v_change_set.tenant_id,
    v_preview_id,
    v_change_set.id,
    item.id,
    v_change_set.import_batch_id,
    item.import_record_id,
    item.row_number,
    item.entity_type,
    item.external_id,
    item.target_table,
    item.canonical_id,
    CASE WHEN cardinality(blockers.blocker_codes) = 0 THEN 'ready' ELSE 'blocked' END,
    blockers.blocker_codes,
    item.safe_field_names,
    diff_counts.rollback_field_names,
    diff_counts.field_diff_count,
    (
      snap.id IS NOT NULL
      AND snap.snapshot_state = 'available'
      AND snap.value_readback_allowed IS FALSE
      AND snap.hot_retention_expires_at > NOW()
    ),
    COALESCE(snap.snapshot_state, 'missing'),
    snap.snapshot_hash,
    item.source_row_hash,
    current_guard.current_hash,
    (
      current_guard.current_hash IS NOT NULL
      AND current_guard.current_hash IS NOT DISTINCT FROM item.source_row_hash
    ),
    cardinality(blockers.blocker_codes) > 0,
    snap.hot_retention_expires_at,
    snap.purge_after_at,
    jsonb_build_object(
      'contract_version', 'pr16.5-guarded-update-rollback-preview-v1',
      'rollback_preview_id', v_preview_id,
      'change_set_id', v_change_set.id,
      'import_batch_id', v_change_set.import_batch_id,
      'row_number', item.row_number,
      'entity_type', item.entity_type,
      'target_table', item.target_table,
      'operation', 'rollback_preview',
      'risk_class', 'rollback_preview_required',
      'safe_field_names', item.safe_field_names,
      'rollback_field_names', diff_counts.rollback_field_names,
      'blocker_codes', blockers.blocker_codes,
      'snapshot_hash_available', snap.snapshot_hash IS NOT NULL,
      'expected_post_apply_hash_available', item.source_row_hash IS NOT NULL,
      'current_hash_available', current_guard.current_hash IS NOT NULL,
      'current_state_matches_apply',
        current_guard.current_hash IS NOT NULL
        AND current_guard.current_hash IS NOT DISTINCT FROM item.source_row_hash,
      'rollback_preview', TRUE,
      'rollback_execution', FALSE,
      'compensating_execution', FALSE,
      'canonical_write', FALSE,
      'source_writeback', FALSE,
      'provider_api_calls', FALSE,
      'credential_readback', FALSE,
      'field_value_readback', FALSE,
      'raw_payload_readback', FALSE,
      'snapshot_payload_readback', FALSE
    )
  FROM puls_integration.connector_apply_change_set_items item
  LEFT JOIN puls_integration.connector_apply_rollback_snapshots snap
    ON snap.change_set_item_id = item.id
  LEFT JOIN LATERAL (
    SELECT
      COUNT(*)::INTEGER AS field_diff_count,
      COALESCE(array_agg(diff.field_name ORDER BY diff.field_name), '{}'::TEXT[])
        AS rollback_field_names
    FROM puls_integration.connector_apply_field_diffs diff
    WHERE diff.change_set_item_id = item.id
  ) diff_counts ON TRUE
  CROSS JOIN LATERAL (
    SELECT puls_integration._connector_apply_expected_current_hash(
      v_change_set.tenant_id,
      v_change_set.source_namespace_id,
      item.entity_type,
      item.external_id,
      item.canonical_id
    ) AS current_hash
  ) current_guard
  CROSS JOIN LATERAL (
    SELECT array_remove(ARRAY[
      CASE
        WHEN NOT (
          snap.id IS NOT NULL
          AND snap.snapshot_state = 'available'
          AND snap.value_readback_allowed IS FALSE
          AND snap.hot_retention_expires_at > NOW()
        ) THEN 'rollback_snapshot_unavailable'
      END,
      CASE WHEN diff_counts.field_diff_count <= 0 THEN 'field_diff_missing' END,
      CASE WHEN current_guard.current_hash IS NULL THEN 'current_hash_missing' END,
      CASE
        WHEN current_guard.current_hash IS NOT NULL
          AND current_guard.current_hash IS DISTINCT FROM item.source_row_hash
          THEN 'current_state_drift'
      END
    ]::TEXT[], NULL) AS blocker_codes
  ) blockers
  WHERE item.change_set_id = v_change_set.id
    AND item.operation = 'update'::puls_integration.connector_apply_operation
    AND item.risk_class = 'guarded_overwrite'::puls_integration.connector_apply_risk_class
  ORDER BY item.row_number;

  RETURN QUERY
  SELECT *
  FROM puls_integration.list_connector_guarded_update_rollback_previews(p_change_set_id, 50);
END;
$$;

COMMENT ON FUNCTION puls_integration.generate_connector_guarded_update_rollback_preview(UUID) IS
  'PR16.5 rollback preview generation RPC with PL/pgSQL CTE/output-column disambiguation. Generates immutable hash-only preview evidence; no rollback execution or raw value readback.';
