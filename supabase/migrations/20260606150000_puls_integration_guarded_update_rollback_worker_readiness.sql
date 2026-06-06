-- PR16.7 guarded update rollback worker readiness gate.
-- Produces an immutable, checksum-bound handoff record after rollback approval
-- without enqueueing rollback jobs, executing rollback, compensating writes,
-- source writeback, provider calls, credential readback, raw payload readback,
-- snapshot payload readback, or field value readback.

CREATE TABLE IF NOT EXISTS puls_integration.connector_apply_rollback_worker_readiness (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  connection_id UUID NULL REFERENCES puls_integration.erp_connections(id) ON DELETE SET NULL,
  source_namespace_id UUID NOT NULL REFERENCES puls_integration.source_namespaces(id) ON DELETE RESTRICT,
  import_batch_id UUID NOT NULL REFERENCES puls_integration.import_batches(id) ON DELETE RESTRICT,
  change_set_id UUID NOT NULL REFERENCES puls_integration.connector_apply_change_sets(id) ON DELETE RESTRICT,
  rollback_preview_id UUID NOT NULL REFERENCES puls_integration.connector_apply_rollback_previews(id) ON DELETE RESTRICT,
  rollback_approval_id UUID NOT NULL REFERENCES puls_integration.connector_apply_rollback_approvals(id) ON DELETE RESTRICT,
  rollback_preview_checksum TEXT NOT NULL,
  readiness_status TEXT NOT NULL DEFAULT 'ready_for_worker_handoff',
  readiness_policy TEXT NOT NULL DEFAULT 'approval_checksum_current_state_retention',
  worker_contract TEXT NOT NULL DEFAULT 'pr16.7-rollback-worker-readiness-v1',
  expected_job_type TEXT NOT NULL DEFAULT 'import_apply',
  expected_job_domain TEXT NOT NULL DEFAULT 'import_apply_guarded_update_rollback',
  row_count INTEGER NOT NULL,
  rollback_count INTEGER NOT NULL,
  blocker_count INTEGER NOT NULL DEFAULT 0,
  stale_blocked_count INTEGER NOT NULL DEFAULT 0,
  drift_blocked_count INTEGER NOT NULL DEFAULT 0,
  expired_snapshot_count INTEGER NOT NULL DEFAULT 0,
  field_diff_count INTEGER NOT NULL,
  rollback_snapshot_count INTEGER NOT NULL,
  original_apply_event_count INTEGER NOT NULL,
  current_state_verified_count INTEGER NOT NULL,
  retention_verified_count INTEGER NOT NULL,
  approval_verified BOOLEAN NOT NULL DEFAULT TRUE,
  approval_checksum_verified BOOLEAN NOT NULL DEFAULT TRUE,
  worker_handoff_ready BOOLEAN NOT NULL DEFAULT TRUE,
  rollback_job_enqueue_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  rollback_execution_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  canonical_write_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  compensating_execution_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  source_writeback_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  credential_readback_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  value_readback_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  provider_api_calls_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  approval_required BOOLEAN NOT NULL DEFAULT TRUE,
  operator_review_required BOOLEAN NOT NULL DEFAULT TRUE,
  next_action_key TEXT NOT NULL DEFAULT 'implement_guarded_update_rollback_worker_pr16_8',
  safe_summary JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (rollback_preview_checksum <> ''),
  CHECK (readiness_status = 'ready_for_worker_handoff'),
  CHECK (readiness_policy = 'approval_checksum_current_state_retention'),
  CHECK (worker_contract = 'pr16.7-rollback-worker-readiness-v1'),
  CHECK (expected_job_type = 'import_apply'),
  CHECK (expected_job_domain = 'import_apply_guarded_update_rollback'),
  CHECK (row_count > 0),
  CHECK (rollback_count = row_count),
  CHECK (blocker_count = 0),
  CHECK (stale_blocked_count = 0),
  CHECK (drift_blocked_count = 0),
  CHECK (expired_snapshot_count = 0),
  CHECK (field_diff_count > 0),
  CHECK (rollback_snapshot_count >= row_count),
  CHECK (original_apply_event_count >= row_count),
  CHECK (current_state_verified_count = row_count),
  CHECK (retention_verified_count = row_count),
  CHECK (approval_verified IS TRUE),
  CHECK (approval_checksum_verified IS TRUE),
  CHECK (worker_handoff_ready IS TRUE),
  CHECK (rollback_job_enqueue_enabled IS FALSE),
  CHECK (rollback_execution_enabled IS FALSE),
  CHECK (canonical_write_enabled IS FALSE),
  CHECK (compensating_execution_enabled IS FALSE),
  CHECK (source_writeback_enabled IS FALSE),
  CHECK (credential_readback_enabled IS FALSE),
  CHECK (value_readback_enabled IS FALSE),
  CHECK (provider_api_calls_enabled IS FALSE),
  CHECK (approval_required IS TRUE),
  CHECK (operator_review_required IS TRUE),
  CHECK (jsonb_typeof(safe_summary) = 'object'),
  CHECK (puls_integration.connector_safe_context_has_blocked_key(safe_summary) IS FALSE),
  UNIQUE (rollback_approval_id),
  UNIQUE (rollback_preview_id),
  UNIQUE (change_set_id)
);

CREATE INDEX IF NOT EXISTS idx_puls_integration_rollback_worker_readiness_tenant_created
  ON puls_integration.connector_apply_rollback_worker_readiness (tenant_id, created_at DESC);

COMMENT ON TABLE puls_integration.connector_apply_rollback_worker_readiness IS
  'PR16.7 immutable readiness gate for guarded-update rollback worker handoff. It proves approval, checksum, current-state, original apply event, and retention evidence without opening rollback execution.';

CREATE OR REPLACE FUNCTION puls_integration.reject_connector_rollback_worker_readiness_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration
AS $$
BEGIN
  RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_READINESS_IMMUTABLE: rollback worker readiness rows are immutable.';
END;
$$;

DROP TRIGGER IF EXISTS puls_integration_rollback_worker_readiness_immutable
  ON puls_integration.connector_apply_rollback_worker_readiness;
CREATE TRIGGER puls_integration_rollback_worker_readiness_immutable
  BEFORE UPDATE OR DELETE ON puls_integration.connector_apply_rollback_worker_readiness
  FOR EACH ROW EXECUTE FUNCTION puls_integration.reject_connector_rollback_worker_readiness_mutation();

CREATE OR REPLACE FUNCTION puls_integration.list_connector_guarded_update_rollback_worker_readiness(
  p_change_set_id UUID DEFAULT NULL,
  p_limit INTEGER DEFAULT 50
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
    readiness.id AS rollback_worker_readiness_id,
    readiness.rollback_approval_id,
    readiness.rollback_preview_id,
    readiness.change_set_id,
    readiness.tenant_id,
    readiness.connection_id,
    readiness.source_namespace_id,
    readiness.import_batch_id,
    readiness.readiness_status,
    readiness.readiness_policy,
    readiness.worker_contract,
    readiness.expected_job_type,
    readiness.expected_job_domain,
    readiness.rollback_preview_checksum,
    readiness.row_count,
    readiness.rollback_count,
    readiness.blocker_count,
    readiness.stale_blocked_count,
    readiness.drift_blocked_count,
    readiness.expired_snapshot_count,
    readiness.field_diff_count,
    readiness.rollback_snapshot_count,
    readiness.original_apply_event_count,
    readiness.current_state_verified_count,
    readiness.retention_verified_count,
    readiness.approval_verified,
    readiness.approval_checksum_verified,
    readiness.worker_handoff_ready,
    readiness.rollback_job_enqueue_enabled,
    readiness.rollback_execution_enabled,
    readiness.canonical_write_enabled,
    readiness.compensating_execution_enabled,
    readiness.source_writeback_enabled,
    readiness.credential_readback_enabled,
    readiness.value_readback_enabled,
    readiness.provider_api_calls_enabled,
    readiness.approval_required,
    readiness.operator_review_required,
    readiness.next_action_key,
    readiness.safe_summary,
    COALESCE(samples.sample_items, '[]'::JSONB) AS sample_items,
    readiness.created_at
  FROM puls_integration.connector_apply_rollback_worker_readiness readiness
  LEFT JOIN LATERAL (
    SELECT jsonb_agg(
      jsonb_build_object(
        'row_number', sample.row_number,
        'operation', 'rollback',
        'entity_type', sample.entity_type,
        'external_id', sample.external_id,
        'target_table', sample.target_table,
        'canonical_id', sample.canonical_id,
        'safe_field_names', sample.safe_field_names,
        'rollback_field_names', sample.rollback_field_names,
        'field_diff_count', sample.field_diff_count,
        'rollback_snapshot_available', sample.rollback_snapshot_available,
        'current_hash_available', sample.current_hash IS NOT NULL,
        'current_state_matches_apply', sample.current_state_matches_apply,
        'original_apply_event_count', COALESCE(event_counts.original_apply_event_count, 0),
        'rollback_execution', FALSE,
        'canonical_write', FALSE,
        'source_writeback', FALSE,
        'provider_api_calls', FALSE,
        'credential_readback', FALSE,
        'field_value_readback', FALSE,
        'raw_payload_readback', FALSE,
        'snapshot_payload_readback', FALSE
      )
      ORDER BY sample.row_number
    ) AS sample_items
    FROM (
      SELECT item.*
      FROM puls_integration.connector_apply_rollback_preview_items item
      WHERE item.rollback_preview_id = readiness.rollback_preview_id
      ORDER BY item.row_number
      LIMIT v_limit
    ) sample
    LEFT JOIN LATERAL (
      SELECT COUNT(*)::INTEGER AS original_apply_event_count
      FROM puls_integration.connector_apply_object_events event
      WHERE event.change_set_item_id = sample.change_set_item_id
        AND event.operation = 'update'::puls_integration.connector_apply_operation
        AND event.canonical_id = sample.canonical_id
    ) event_counts ON TRUE
  ) samples ON TRUE
  WHERE (v_auth_role = 'service_role' OR readiness.tenant_id = v_tenant_id)
    AND (p_change_set_id IS NULL OR readiness.change_set_id = p_change_set_id)
  ORDER BY readiness.created_at DESC, readiness.id DESC
  LIMIT v_limit;
END;
$$;

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
    COUNT(*) FILTER (WHERE cardinality(blocker_codes_out) > 0)::INTEGER,
    COUNT(*) FILTER (WHERE stale_blocked IS TRUE)::INTEGER,
    COUNT(*) FILTER (
      WHERE blocker_codes_out @> ARRAY['current_state_drift']::TEXT[]
        OR blocker_codes_out @> ARRAY['current_hash_missing']::TEXT[]
    )::INTEGER,
    COUNT(*) FILTER (
      WHERE blocker_codes_out @> ARRAY['rollback_snapshot_unavailable']::TEXT[]
    )::INTEGER,
    COALESCE(SUM(field_diff_count), 0)::INTEGER,
    COUNT(*) FILTER (WHERE retention_ready IS TRUE)::INTEGER,
    COALESCE(SUM(original_apply_event_count), 0)::INTEGER,
    COUNT(*) FILTER (WHERE current_state_matches_apply IS TRUE)::INTEGER,
    COUNT(*) FILTER (WHERE retention_ready IS TRUE)::INTEGER
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
  FROM classified;

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

CREATE OR REPLACE FUNCTION puls_integration._connector_apply_has_rollback_worker_readiness(
  p_rollback_approval_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM puls_integration.connector_apply_rollback_worker_readiness readiness
    JOIN puls_integration.connector_apply_rollback_approvals approval
      ON approval.id = readiness.rollback_approval_id
    WHERE readiness.rollback_approval_id = p_rollback_approval_id
      AND readiness.readiness_status = 'ready_for_worker_handoff'
      AND readiness.rollback_preview_checksum = approval.rollback_preview_checksum
      AND readiness.worker_handoff_ready IS TRUE
      AND readiness.rollback_job_enqueue_enabled IS FALSE
      AND readiness.rollback_execution_enabled IS FALSE
      AND readiness.canonical_write_enabled IS FALSE
      AND readiness.compensating_execution_enabled IS FALSE
      AND readiness.source_writeback_enabled IS FALSE
      AND readiness.credential_readback_enabled IS FALSE
      AND readiness.value_readback_enabled IS FALSE
      AND readiness.provider_api_calls_enabled IS FALSE
  );
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
    'pr16.7-guarded-update-rollback-worker-readiness-v1'::TEXT AS contract_version,
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
    'guarded_update_rollback_worker_readiness_open'::TEXT AS safe_error_code,
    'review_guarded_update_rollback_worker_readiness'::TEXT AS next_action_key
  FROM puls_integration.erp_connections c
  WHERE (v_auth_role = 'service_role' OR c.tenant_id = v_tenant_id)
    AND (p_connection_id IS NULL OR c.id = p_connection_id)
  ORDER BY c.updated_at DESC;
END;
$$;

ALTER TABLE puls_integration.connector_apply_rollback_worker_readiness ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS puls_integration_rollback_worker_readiness_service_role
  ON puls_integration.connector_apply_rollback_worker_readiness;
CREATE POLICY puls_integration_rollback_worker_readiness_service_role
  ON puls_integration.connector_apply_rollback_worker_readiness
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

REVOKE ALL ON TABLE puls_integration.connector_apply_rollback_worker_readiness
  FROM PUBLIC, authenticated, anon;
GRANT SELECT, INSERT ON TABLE puls_integration.connector_apply_rollback_worker_readiness
  TO service_role;

REVOKE ALL ON FUNCTION puls_integration.reject_connector_rollback_worker_readiness_mutation()
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.reject_connector_rollback_worker_readiness_mutation()
  TO service_role;

REVOKE ALL ON FUNCTION puls_integration.generate_connector_guarded_update_rollback_worker_readiness(UUID)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.generate_connector_guarded_update_rollback_worker_readiness(UUID)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_integration.list_connector_guarded_update_rollback_worker_readiness(UUID, INTEGER)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.list_connector_guarded_update_rollback_worker_readiness(UUID, INTEGER)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_integration._connector_apply_has_rollback_worker_readiness(UUID)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration._connector_apply_has_rollback_worker_readiness(UUID)
  TO service_role;

COMMENT ON FUNCTION puls_integration.generate_connector_guarded_update_rollback_worker_readiness(UUID) IS
  'PR16.7 admin/service-role RPC that records immutable guarded-update rollback worker readiness without enqueueing or executing rollback.';

COMMENT ON FUNCTION puls_integration.list_connector_guarded_update_rollback_worker_readiness(UUID, INTEGER) IS
  'PR16.7 authenticated-safe rollback worker readiness read model. Returns handoff metadata and closed execution boundaries only.';
