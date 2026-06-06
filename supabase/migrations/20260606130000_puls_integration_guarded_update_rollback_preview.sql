-- PR16.5 guarded update rollback preview foundation.
-- Generates immutable, hash-only rollback previews from applied guarded updates.
-- It does not execute rollback, compensating updates, ERP/source writeback,
-- provider calls, credential readback, raw payload readback, or field value
-- readback.

CREATE TABLE IF NOT EXISTS puls_integration.connector_apply_rollback_previews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  connection_id UUID NULL REFERENCES puls_integration.erp_connections(id) ON DELETE SET NULL,
  source_namespace_id UUID NOT NULL REFERENCES puls_integration.source_namespaces(id) ON DELETE RESTRICT,
  import_batch_id UUID NOT NULL REFERENCES puls_integration.import_batches(id) ON DELETE RESTRICT,
  change_set_id UUID NOT NULL REFERENCES puls_integration.connector_apply_change_sets(id) ON DELETE RESTRICT,
  status TEXT NOT NULL DEFAULT 'blocked',
  preview_kind TEXT NOT NULL DEFAULT 'rollback',
  rollback_preview_checksum TEXT NOT NULL,
  row_count INTEGER NOT NULL DEFAULT 0,
  rollback_count INTEGER NOT NULL DEFAULT 0,
  blocked_count INTEGER NOT NULL DEFAULT 0,
  stale_blocked_count INTEGER NOT NULL DEFAULT 0,
  field_diff_count INTEGER NOT NULL DEFAULT 0,
  rollback_snapshot_count INTEGER NOT NULL DEFAULT 0,
  rollback_preview_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  rollback_execution_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  compensating_execution_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  source_writeback_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  credential_readback_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  value_readback_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  approval_required BOOLEAN NOT NULL DEFAULT TRUE,
  operator_review_required BOOLEAN NOT NULL DEFAULT TRUE,
  next_action_key TEXT NOT NULL DEFAULT 'review_guarded_update_rollback_preview',
  safe_summary JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_by_employee_id UUID NULL REFERENCES puls_core.employees(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (status IN ('ready_for_rollback_review', 'blocked')),
  CHECK (preview_kind = 'rollback'),
  CHECK (rollback_preview_checksum <> ''),
  CHECK (row_count >= 0),
  CHECK (rollback_count >= 0),
  CHECK (blocked_count >= 0),
  CHECK (stale_blocked_count >= 0),
  CHECK (field_diff_count >= 0),
  CHECK (rollback_snapshot_count >= 0),
  CHECK (rollback_execution_enabled IS FALSE),
  CHECK (compensating_execution_enabled IS FALSE),
  CHECK (source_writeback_enabled IS FALSE),
  CHECK (credential_readback_enabled IS FALSE),
  CHECK (value_readback_enabled IS FALSE),
  CHECK (jsonb_typeof(safe_summary) = 'object'),
  CHECK (puls_integration.connector_safe_context_has_blocked_key(safe_summary) IS FALSE),
  UNIQUE (change_set_id),
  UNIQUE (rollback_preview_checksum)
);

CREATE INDEX IF NOT EXISTS idx_puls_integration_rollback_previews_tenant_created
  ON puls_integration.connector_apply_rollback_previews (tenant_id, created_at DESC);

CREATE TABLE IF NOT EXISTS puls_integration.connector_apply_rollback_preview_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  rollback_preview_id UUID NOT NULL REFERENCES puls_integration.connector_apply_rollback_previews(id) ON DELETE CASCADE,
  change_set_id UUID NOT NULL REFERENCES puls_integration.connector_apply_change_sets(id) ON DELETE RESTRICT,
  change_set_item_id UUID NOT NULL REFERENCES puls_integration.connector_apply_change_set_items(id) ON DELETE RESTRICT,
  import_batch_id UUID NOT NULL REFERENCES puls_integration.import_batches(id) ON DELETE RESTRICT,
  import_record_id UUID NOT NULL REFERENCES puls_integration.import_records(id) ON DELETE RESTRICT,
  row_number INTEGER NOT NULL,
  entity_type puls_integration.import_entity_type NOT NULL,
  external_id TEXT NOT NULL,
  target_schema TEXT NOT NULL DEFAULT 'puls_core',
  target_table TEXT NOT NULL,
  canonical_id UUID NOT NULL,
  operation puls_integration.connector_apply_operation NOT NULL DEFAULT 'rollback',
  item_status TEXT NOT NULL DEFAULT 'blocked',
  risk_class TEXT NOT NULL DEFAULT 'rollback_preview_required',
  blocker_codes TEXT[] NOT NULL DEFAULT '{}'::TEXT[],
  safe_field_names TEXT[] NOT NULL DEFAULT '{}'::TEXT[],
  rollback_field_names TEXT[] NOT NULL DEFAULT '{}'::TEXT[],
  field_diff_count INTEGER NOT NULL DEFAULT 0,
  rollback_snapshot_available BOOLEAN NOT NULL DEFAULT FALSE,
  snapshot_state TEXT NOT NULL DEFAULT 'missing',
  snapshot_hash TEXT NULL,
  expected_post_apply_hash TEXT NULL,
  current_hash TEXT NULL,
  current_state_matches_apply BOOLEAN NOT NULL DEFAULT FALSE,
  stale_blocked BOOLEAN NOT NULL DEFAULT FALSE,
  retention_bucket TEXT NOT NULL DEFAULT 'rollback_snapshot',
  hot_retention_expires_at TIMESTAMPTZ NULL,
  purge_after_at TIMESTAMPTZ NULL,
  safe_summary JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (external_id <> ''),
  CHECK (target_schema = 'puls_core'),
  CHECK (target_table <> ''),
  CHECK (operation = 'rollback'::puls_integration.connector_apply_operation),
  CHECK (item_status IN ('ready', 'blocked')),
  CHECK (risk_class = 'rollback_preview_required'),
  CHECK (field_diff_count >= 0),
  CHECK (retention_bucket = 'rollback_snapshot'),
  CHECK (jsonb_typeof(safe_summary) = 'object'),
  CHECK (puls_integration.connector_safe_context_has_blocked_key(safe_summary) IS FALSE),
  UNIQUE (rollback_preview_id, change_set_item_id),
  UNIQUE (change_set_id, change_set_item_id)
);

CREATE INDEX IF NOT EXISTS idx_puls_integration_rollback_preview_items_preview
  ON puls_integration.connector_apply_rollback_preview_items (rollback_preview_id, row_number);

COMMENT ON TABLE puls_integration.connector_apply_rollback_previews IS
  'PR16.5 immutable guarded-update rollback preview header. Safe metadata only; no rollback execution, source writeback, or raw value readback.';

COMMENT ON TABLE puls_integration.connector_apply_rollback_preview_items IS
  'PR16.5 immutable guarded-update rollback preview item ledger. Stores safe field names, hashes, blocker codes, and retention metadata only.';

CREATE OR REPLACE FUNCTION puls_integration.reject_connector_rollback_preview_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration
AS $$
BEGIN
  RAISE EXCEPTION
    'PULS_CONNECTOR_ROLLBACK_PREVIEW_IMMUTABLE: rollback previews cannot be updated or deleted.';
END;
$$;

DROP TRIGGER IF EXISTS puls_integration_rollback_previews_immutable
  ON puls_integration.connector_apply_rollback_previews;
CREATE TRIGGER puls_integration_rollback_previews_immutable
  BEFORE UPDATE OR DELETE ON puls_integration.connector_apply_rollback_previews
  FOR EACH ROW EXECUTE FUNCTION puls_integration.reject_connector_rollback_preview_mutation();

DROP TRIGGER IF EXISTS puls_integration_rollback_preview_items_immutable
  ON puls_integration.connector_apply_rollback_preview_items;
CREATE TRIGGER puls_integration_rollback_preview_items_immutable
  BEFORE UPDATE OR DELETE ON puls_integration.connector_apply_rollback_preview_items
  FOR EACH ROW EXECUTE FUNCTION puls_integration.reject_connector_rollback_preview_mutation();

CREATE OR REPLACE FUNCTION puls_integration.list_connector_guarded_update_rollback_previews(
  p_change_set_id UUID DEFAULT NULL,
  p_limit INTEGER DEFAULT 50
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
    preview.id AS rollback_preview_id,
    preview.change_set_id,
    preview.tenant_id,
    preview.connection_id,
    preview.source_namespace_id,
    preview.import_batch_id,
    preview.status,
    preview.preview_kind,
    preview.rollback_preview_checksum,
    preview.row_count,
    preview.rollback_count,
    preview.blocked_count,
    preview.stale_blocked_count,
    preview.field_diff_count,
    preview.rollback_snapshot_count,
    preview.rollback_preview_enabled,
    preview.rollback_execution_enabled,
    preview.compensating_execution_enabled,
    preview.source_writeback_enabled,
    preview.credential_readback_enabled,
    preview.value_readback_enabled,
    preview.approval_required,
    preview.operator_review_required,
    preview.next_action_key,
    COALESCE(samples.sample_items, '[]'::JSONB) AS sample_items,
    preview.created_at
  FROM puls_integration.connector_apply_rollback_previews preview
  LEFT JOIN LATERAL (
    SELECT jsonb_agg(
      jsonb_build_object(
        'id', item.id,
        'row_number', item.row_number,
        'entity_type', item.entity_type,
        'external_id', item.external_id,
        'target_table', item.target_table,
        'canonical_id', item.canonical_id,
        'operation', item.operation,
        'item_status', item.item_status,
        'risk_class', item.risk_class,
        'blocker_codes', item.blocker_codes,
        'safe_field_names', item.safe_field_names,
        'rollback_field_names', item.rollback_field_names,
        'field_diff_count', item.field_diff_count,
        'rollback_snapshot_available', item.rollback_snapshot_available,
        'snapshot_state', item.snapshot_state,
        'snapshot_hash_available', item.snapshot_hash IS NOT NULL,
        'expected_post_apply_hash_available', item.expected_post_apply_hash IS NOT NULL,
        'current_hash_available', item.current_hash IS NOT NULL,
        'current_state_matches_apply', item.current_state_matches_apply,
        'stale_blocked', item.stale_blocked,
        'retention_bucket', item.retention_bucket,
        'hot_retention_expires_at', item.hot_retention_expires_at,
        'purge_after_at', item.purge_after_at,
        'safe_summary', item.safe_summary
      )
      ORDER BY item.row_number ASC, item.id ASC
    ) AS sample_items
    FROM (
      SELECT preview_item.*
      FROM puls_integration.connector_apply_rollback_preview_items preview_item
      WHERE preview_item.rollback_preview_id = preview.id
      ORDER BY preview_item.row_number ASC, preview_item.id ASC
      LIMIT v_limit
    ) item
  ) samples ON TRUE
  WHERE (v_auth_role = 'service_role' OR preview.tenant_id = v_tenant_id)
    AND (p_change_set_id IS NULL OR preview.change_set_id = p_change_set_id)
  ORDER BY preview.created_at DESC, preview.id DESC
  LIMIT v_limit;
END;
$$;

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
    'pr16.5-guarded-update-rollback-preview-v1'::TEXT AS contract_version,
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
    'guarded_update_rollback_preview_open'::TEXT AS safe_error_code,
    'review_guarded_update_rollback_preview'::TEXT AS next_action_key
  FROM puls_integration.erp_connections c
  WHERE (v_auth_role = 'service_role' OR c.tenant_id = v_tenant_id)
    AND (p_connection_id IS NULL OR c.id = p_connection_id)
  ORDER BY c.updated_at DESC;
END;
$$;

ALTER TABLE puls_integration.connector_apply_rollback_previews ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_integration.connector_apply_rollback_preview_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS puls_integration_rollback_previews_service_role
  ON puls_integration.connector_apply_rollback_previews;
CREATE POLICY puls_integration_rollback_previews_service_role
  ON puls_integration.connector_apply_rollback_previews
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS puls_integration_rollback_preview_items_service_role
  ON puls_integration.connector_apply_rollback_preview_items;
CREATE POLICY puls_integration_rollback_preview_items_service_role
  ON puls_integration.connector_apply_rollback_preview_items
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

REVOKE ALL ON TABLE puls_integration.connector_apply_rollback_previews
  FROM PUBLIC, authenticated, anon;
REVOKE ALL ON TABLE puls_integration.connector_apply_rollback_preview_items
  FROM PUBLIC, authenticated, anon;
GRANT SELECT, INSERT ON TABLE puls_integration.connector_apply_rollback_previews
  TO service_role;
GRANT SELECT, INSERT ON TABLE puls_integration.connector_apply_rollback_preview_items
  TO service_role;

REVOKE ALL ON FUNCTION puls_integration.reject_connector_rollback_preview_mutation()
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.reject_connector_rollback_preview_mutation()
  TO service_role;

REVOKE ALL ON FUNCTION puls_integration.generate_connector_guarded_update_rollback_preview(UUID)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.generate_connector_guarded_update_rollback_preview(UUID)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_integration.list_connector_guarded_update_rollback_previews(UUID, INTEGER)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.list_connector_guarded_update_rollback_previews(UUID, INTEGER)
  TO authenticated, service_role;

COMMENT ON FUNCTION puls_integration.generate_connector_guarded_update_rollback_preview(UUID) IS
  'PR16.5 admin/service-role rollback preview generation for applied guarded updates. Generates immutable hash-only preview evidence; no rollback execution or raw value readback.';

COMMENT ON FUNCTION puls_integration.list_connector_guarded_update_rollback_previews(UUID, INTEGER) IS
  'PR16.5 authenticated-safe guarded update rollback preview read model. Returns safe item summaries, blocker codes, hash availability, and retention metadata only.';
