-- PR16.8 guarded update rollback worker apply.
-- Opens a worker-only rollback execution path from the PR16.7 readiness
-- handoff. The worker restores safe reference-dimension name values from
-- service-role rollback snapshots, rechecks current-state immediately before
-- writing, emits rollback object events, and keeps source writeback, provider
-- calls, credential readback, raw payload readback, snapshot payload readback,
-- and field value readback closed.

DO $$
DECLARE
  v_constraint RECORD;
BEGIN
  FOR v_constraint IN
    SELECT con.conname
    FROM pg_constraint con
    JOIN pg_class rel ON rel.oid = con.conrelid
    JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
    WHERE nsp.nspname = 'puls_integration'
      AND rel.relname = 'connector_apply_object_events'
      AND con.contype = 'c'
      AND pg_get_constraintdef(con.oid) LIKE '%operation%'
  LOOP
    EXECUTE format(
      'ALTER TABLE puls_integration.connector_apply_object_events DROP CONSTRAINT %I',
      v_constraint.conname
    );
  END LOOP;
END;
$$;

ALTER TABLE puls_integration.connector_apply_object_events
  ADD CONSTRAINT connector_apply_object_events_operation_check
  CHECK (
    operation IN (
      'insert'::puls_integration.connector_apply_operation,
      'update'::puls_integration.connector_apply_operation,
      'rollback'::puls_integration.connector_apply_operation
    )
  );

DO $$
DECLARE
  v_constraint RECORD;
BEGIN
  FOR v_constraint IN
    SELECT con.conname
    FROM pg_constraint con
    JOIN pg_class rel ON rel.oid = con.conrelid
    JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
    WHERE nsp.nspname = 'puls_integration'
      AND rel.relname = 'connector_apply_object_events'
      AND con.contype = 'u'
      AND pg_get_constraintdef(con.oid) LIKE '%import_record_id%'
      AND pg_get_constraintdef(con.oid) NOT LIKE '%operation%'
  LOOP
    EXECUTE format(
      'ALTER TABLE puls_integration.connector_apply_object_events DROP CONSTRAINT %I',
      v_constraint.conname
    );
  END LOOP;
END;
$$;

CREATE UNIQUE INDEX IF NOT EXISTS connector_apply_object_events_change_record_operation_idx
  ON puls_integration.connector_apply_object_events (change_set_id, import_record_id, operation);

CREATE OR REPLACE FUNCTION puls_integration._connector_apply_validate_guarded_update_rollback_readiness(
  p_rollback_worker_readiness_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_readiness puls_integration.connector_apply_rollback_worker_readiness;
  v_approval puls_integration.connector_apply_rollback_approvals;
  v_preview puls_integration.connector_apply_rollback_previews;
  v_change_set puls_integration.connector_apply_change_sets;
  v_batch puls_integration.import_batches;
  v_row_count INTEGER := 0;
  v_blocker_count INTEGER := 0;
  v_field_diff_count INTEGER := 0;
  v_snapshot_count INTEGER := 0;
  v_original_event_count INTEGER := 0;
  v_current_state_verified_count INTEGER := 0;
  v_retention_verified_count INTEGER := 0;
BEGIN
  SELECT *
  INTO v_readiness
  FROM puls_integration.connector_apply_rollback_worker_readiness readiness
  WHERE readiness.id = p_rollback_worker_readiness_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_READINESS_NOT_FOUND: rollback worker readiness not found.';
  END IF;

  IF v_readiness.readiness_status IS DISTINCT FROM 'ready_for_worker_handoff'
     OR v_readiness.worker_handoff_ready IS NOT TRUE
     OR v_readiness.rollback_job_enqueue_enabled IS NOT FALSE
     OR v_readiness.rollback_execution_enabled IS NOT FALSE
     OR v_readiness.canonical_write_enabled IS NOT FALSE
     OR v_readiness.compensating_execution_enabled IS NOT FALSE
     OR v_readiness.source_writeback_enabled IS NOT FALSE
     OR v_readiness.credential_readback_enabled IS NOT FALSE
     OR v_readiness.value_readback_enabled IS NOT FALSE
     OR v_readiness.provider_api_calls_enabled IS NOT FALSE THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_READINESS_BOUNDARY_INVALID: readiness boundary is invalid.';
  END IF;

  IF v_readiness.blocker_count <> 0
     OR v_readiness.stale_blocked_count <> 0
     OR v_readiness.drift_blocked_count <> 0
     OR v_readiness.expired_snapshot_count <> 0
     OR v_readiness.row_count <= 0
     OR v_readiness.rollback_count <> v_readiness.row_count
     OR v_readiness.field_diff_count <= 0
     OR v_readiness.rollback_snapshot_count < v_readiness.row_count
     OR v_readiness.original_apply_event_count < v_readiness.row_count
     OR v_readiness.current_state_verified_count <> v_readiness.row_count
     OR v_readiness.retention_verified_count <> v_readiness.row_count THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_READINESS_COUNTS_INVALID: readiness evidence counts are invalid.';
  END IF;

  SELECT *
  INTO v_approval
  FROM puls_integration.connector_apply_rollback_approvals approval
  WHERE approval.id = v_readiness.rollback_approval_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_APPROVAL_NOT_FOUND: rollback approval not found.';
  END IF;

  SELECT *
  INTO v_preview
  FROM puls_integration.connector_apply_rollback_previews preview
  WHERE preview.id = v_readiness.rollback_preview_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_PREVIEW_NOT_FOUND: rollback preview not found.';
  END IF;

  SELECT *
  INTO v_change_set
  FROM puls_integration.connector_apply_change_sets cs
  WHERE cs.id = v_readiness.change_set_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_CHANGE_SET_NOT_FOUND: change-set not found.';
  END IF;

  SELECT *
  INTO v_batch
  FROM puls_integration.import_batches ib
  WHERE ib.id = v_readiness.import_batch_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_BATCH_NOT_FOUND: import batch not found.';
  END IF;

  IF v_batch.status IS DISTINCT FROM 'applied'::puls_integration.import_batch_status THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_APPLIED_BATCH_REQUIRED: rollback requires an applied guarded-update batch.';
  END IF;

  IF v_approval.approval_status IS DISTINCT FROM 'approval_recorded'
     OR v_approval.rollback_preview_checksum IS DISTINCT FROM v_readiness.rollback_preview_checksum
     OR v_approval.rollback_execution_enabled IS NOT FALSE
     OR v_approval.compensating_execution_enabled IS NOT FALSE
     OR v_approval.source_writeback_enabled IS NOT FALSE
     OR v_approval.credential_readback_enabled IS NOT FALSE
     OR v_approval.value_readback_enabled IS NOT FALSE THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_APPROVAL_INVALID: rollback approval is invalid.';
  END IF;

  IF v_preview.status IS DISTINCT FROM 'ready_for_rollback_review'
     OR v_preview.preview_kind IS DISTINCT FROM 'rollback'
     OR v_preview.rollback_preview_checksum IS DISTINCT FROM v_readiness.rollback_preview_checksum
     OR v_preview.rollback_count <> v_preview.row_count
     OR v_preview.blocked_count <> 0
     OR v_preview.stale_blocked_count <> 0
     OR v_preview.rollback_execution_enabled IS NOT FALSE
     OR v_preview.compensating_execution_enabled IS NOT FALSE
     OR v_preview.source_writeback_enabled IS NOT FALSE
     OR v_preview.credential_readback_enabled IS NOT FALSE
     OR v_preview.value_readback_enabled IS NOT FALSE THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_PREVIEW_INVALID: rollback preview is invalid.';
  END IF;

  IF v_readiness.tenant_id IS DISTINCT FROM v_change_set.tenant_id
     OR v_readiness.connection_id IS DISTINCT FROM v_change_set.connection_id
     OR v_readiness.source_namespace_id IS DISTINCT FROM v_change_set.source_namespace_id
     OR v_readiness.import_batch_id IS DISTINCT FROM v_change_set.import_batch_id
     OR v_readiness.change_set_id IS DISTINCT FROM v_approval.change_set_id
     OR v_readiness.rollback_preview_id IS DISTINCT FROM v_approval.rollback_preview_id
     OR v_readiness.import_batch_id IS DISTINCT FROM v_approval.import_batch_id
     OR v_readiness.change_set_id IS DISTINCT FROM v_preview.change_set_id
     OR v_readiness.import_batch_id IS DISTINCT FROM v_preview.import_batch_id THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_CONTEXT_MISMATCH: readiness, approval, preview, and change-set context mismatch.';
  END IF;

  WITH rollback_rows AS (
    SELECT
      item.id AS rollback_preview_item_id,
      item.change_set_item_id,
      item.item_status,
      item.blocker_codes,
      item.field_diff_count,
      item.rollback_snapshot_available,
      item.snapshot_state,
      item.hot_retention_expires_at,
      item.expected_post_apply_hash,
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
        v_readiness.tenant_id,
        v_readiness.source_namespace_id,
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
    WHERE item.rollback_preview_id = v_readiness.rollback_preview_id
  )
  SELECT
    COUNT(*)::INTEGER,
    COUNT(*) FILTER (
      WHERE rollback_row.item_status IS DISTINCT FROM 'ready'
        OR cardinality(rollback_row.blocker_codes) > 0
        OR rollback_row.current_state_matches_apply IS NOT TRUE
        OR rollback_row.retention_ready IS NOT TRUE
        OR rollback_row.original_apply_event_count <= 0
        OR rollback_row.field_diff_count <= 0
    )::INTEGER,
    COALESCE(SUM(rollback_row.field_diff_count), 0)::INTEGER,
    COUNT(*) FILTER (WHERE rollback_row.rollback_snapshot_available IS TRUE)::INTEGER,
    COALESCE(SUM(rollback_row.original_apply_event_count), 0)::INTEGER,
    COUNT(*) FILTER (WHERE rollback_row.current_state_matches_apply IS TRUE)::INTEGER,
    COUNT(*) FILTER (WHERE rollback_row.retention_ready IS TRUE)::INTEGER
  INTO
    v_row_count,
    v_blocker_count,
    v_field_diff_count,
    v_snapshot_count,
    v_original_event_count,
    v_current_state_verified_count,
    v_retention_verified_count
  FROM rollback_rows AS rollback_row;

  IF v_row_count <> v_readiness.row_count
     OR v_blocker_count <> 0
     OR v_field_diff_count <> v_readiness.field_diff_count
     OR v_snapshot_count < v_readiness.row_count
     OR v_original_event_count < v_readiness.row_count
     OR v_current_state_verified_count <> v_readiness.row_count
     OR v_retention_verified_count <> v_readiness.row_count THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_RECHECK_BLOCKED: current-state, event, or retention recheck failed.';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration.reject_closed_import_apply_job()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration
AS $$
DECLARE
  v_contract TEXT := NEW.safe_error_context ->> 'contract_version';
  v_mode TEXT := NEW.safe_error_context ->> 'apply_mode';
  v_change_set_id_text TEXT := NEW.safe_error_context ->> 'change_set_id';
  v_change_set_id UUID;
  v_readiness_id_text TEXT := NEW.safe_error_context ->> 'rollback_worker_readiness_id';
  v_readiness_id UUID;
BEGIN
  IF NEW.job_type <> 'import_apply'::puls_integration.connector_job_type THEN
    RETURN NEW;
  END IF;

  IF v_contract = 'pr16.3-create-only-worker-apply-v1'
     AND v_mode = 'create_only' THEN
    NULL;
  ELSIF v_contract = 'pr16.4.2-guarded-update-worker-apply-v1'
     AND v_mode = 'guarded_update' THEN
    NULL;
  ELSIF v_contract = 'pr16.8-guarded-update-rollback-worker-apply-v1'
     AND v_mode = 'guarded_update_rollback' THEN
    NULL;
  ELSE
    RAISE EXCEPTION
      'PULS_CONNECTOR_IMPORT_APPLY_CLOSED: import_apply is closed except approved PR16 worker apply jobs.';
  END IF;

  IF NEW.connection_id IS NULL OR NEW.source_namespace_id IS NULL OR NEW.import_batch_id IS NULL THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_APPLY_JOB_SCOPE_REQUIRED: connection, namespace, and batch are required.';
  END IF;

  IF NEW.max_attempts <> 1 THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_APPLY_SINGLE_ATTEMPT_REQUIRED: worker apply jobs require max_attempts = 1.';
  END IF;

  IF COALESCE(NEW.safe_error_context ->> 'canonical_write_enabled', 'false') <> 'true'
     OR COALESCE(NEW.safe_error_context ->> 'source_writeback_enabled', 'true') <> 'false'
     OR COALESCE(NEW.safe_error_context ->> 'credential_readback_enabled', 'true') <> 'false'
     OR COALESCE(NEW.safe_error_context ->> 'provider_api_calls', 'true') <> 'false'
     OR COALESCE(NEW.safe_error_context ->> 'raw_payload_readback', 'true') <> 'false'
     OR COALESCE(NEW.safe_error_context ->> 'field_value_readback', 'true') <> 'false'
     OR COALESCE(NEW.safe_error_context ->> 'snapshot_payload_readback', 'false') <> 'false' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_APPLY_BOUNDARY_INVALID: worker apply boundaries are invalid.';
  END IF;

  IF v_change_set_id_text IS NULL
     OR v_change_set_id_text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_APPLY_CHANGE_SET_REQUIRED: valid change_set_id is required.';
  END IF;

  v_change_set_id := v_change_set_id_text::UUID;

  IF v_mode = 'create_only' THEN
    PERFORM puls_integration._connector_apply_validate_create_only_change_set(v_change_set_id);
  ELSIF v_mode = 'guarded_update' THEN
    PERFORM puls_integration._connector_apply_validate_guarded_update_change_set(v_change_set_id);
  ELSE
    IF v_readiness_id_text IS NULL
       OR v_readiness_id_text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_READINESS_REQUIRED: valid rollback_worker_readiness_id is required.';
    END IF;

    v_readiness_id := v_readiness_id_text::UUID;
    PERFORM puls_integration._connector_apply_validate_guarded_update_rollback_readiness(v_readiness_id);
  END IF;

  IF v_mode = 'guarded_update_rollback' THEN
    IF NOT EXISTS (
      SELECT 1
      FROM puls_integration.connector_apply_rollback_worker_readiness readiness
      WHERE readiness.id = v_readiness_id
        AND readiness.tenant_id = NEW.tenant_id
        AND readiness.connection_id IS NOT DISTINCT FROM NEW.connection_id
        AND readiness.source_namespace_id = NEW.source_namespace_id
        AND readiness.import_batch_id = NEW.import_batch_id
        AND readiness.change_set_id = v_change_set_id
        AND readiness.rollback_approval_id::TEXT = NEW.safe_error_context ->> 'rollback_approval_id'
        AND readiness.rollback_preview_id::TEXT = NEW.safe_error_context ->> 'rollback_preview_id'
        AND readiness.rollback_preview_checksum = NEW.safe_error_context ->> 'rollback_preview_checksum'
    ) THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_JOB_CONTEXT_MISMATCH: job context does not match rollback readiness.';
    END IF;
  ELSIF NOT EXISTS (
    SELECT 1
    FROM puls_integration.connector_apply_change_sets cs
    WHERE cs.id = v_change_set_id
      AND cs.tenant_id = NEW.tenant_id
      AND cs.connection_id IS NOT DISTINCT FROM NEW.connection_id
      AND cs.source_namespace_id = NEW.source_namespace_id
      AND cs.import_batch_id = NEW.import_batch_id
      AND cs.change_set_checksum = NEW.safe_error_context ->> 'change_set_checksum'
  ) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_APPLY_JOB_CONTEXT_MISMATCH: job context does not match change-set.';
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration.enqueue_connector_guarded_update_rollback_apply_job(
  p_rollback_worker_readiness_id UUID
)
RETURNS TABLE (
  job_id UUID,
  status puls_integration.connector_job_status,
  rollback_worker_readiness_id UUID,
  rollback_approval_id UUID,
  rollback_preview_id UUID,
  change_set_id UUID,
  import_batch_id UUID,
  rollback_count INTEGER,
  field_diff_count INTEGER,
  rollback_snapshot_count INTEGER,
  next_action_key TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_auth_role TEXT := COALESCE(auth.role(), '');
  v_is_service_role BOOLEAN := v_auth_role = 'service_role';
  v_tenant_id UUID := puls_core.current_tenant_id();
  v_readiness puls_integration.connector_apply_rollback_worker_readiness;
  v_job_id UUID;
BEGIN
  IF NOT v_is_service_role AND NOT COALESCE(puls_core.is_admin(), FALSE) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_ADMIN_REQUIRED: admin permission is required.';
  END IF;

  IF NOT v_is_service_role AND v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_TENANT_REQUIRED: authenticated caller has no tenant context.';
  END IF;

  PERFORM puls_integration._connector_apply_validate_guarded_update_rollback_readiness(
    p_rollback_worker_readiness_id
  );

  SELECT *
  INTO v_readiness
  FROM puls_integration.connector_apply_rollback_worker_readiness readiness
  WHERE readiness.id = p_rollback_worker_readiness_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_READINESS_NOT_FOUND: rollback worker readiness not found.';
  END IF;

  IF NOT v_is_service_role AND v_readiness.tenant_id IS DISTINCT FROM v_tenant_id THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_FORBIDDEN: rollback readiness belongs to another tenant.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM puls_integration.connector_apply_object_events event
    WHERE event.change_set_id = v_readiness.change_set_id
      AND event.operation = 'rollback'::puls_integration.connector_apply_operation
  ) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_ALREADY_APPLIED: rollback object events already exist.';
  END IF;

  v_job_id := puls_integration.enqueue_connector_job(
    'import_apply'::puls_integration.connector_job_type,
    concat_ws(
      ':',
      'pr16.8-guarded-update-rollback',
      v_readiness.id::TEXT,
      v_readiness.rollback_preview_checksum
    ),
    v_readiness.connection_id,
    v_readiness.source_namespace_id,
    v_readiness.import_batch_id,
    'import_apply_guarded_update_rollback',
    35,
    NOW(),
    1,
    jsonb_build_object(
      'contract_version', 'pr16.8-guarded-update-rollback-worker-apply-v1',
      'apply_mode', 'guarded_update_rollback',
      'rollback_worker_readiness_id', v_readiness.id,
      'rollback_approval_id', v_readiness.rollback_approval_id,
      'rollback_preview_id', v_readiness.rollback_preview_id,
      'change_set_id', v_readiness.change_set_id,
      'rollback_preview_checksum', v_readiness.rollback_preview_checksum,
      'row_count', v_readiness.row_count,
      'rollback_count', v_readiness.rollback_count,
      'field_diff_count', v_readiness.field_diff_count,
      'rollback_snapshot_count', v_readiness.rollback_snapshot_count,
      'original_apply_event_count', v_readiness.original_apply_event_count,
      'execution_enabled', TRUE,
      'canonical_write_enabled', TRUE,
      'rollback_execution_enabled', TRUE,
      'rollback_job_enqueue_enabled', TRUE,
      'compensating_execution_enabled', FALSE,
      'source_writeback_enabled', FALSE,
      'credential_readback_enabled', FALSE,
      'provider_api_calls', FALSE,
      'raw_payload_readback', FALSE,
      'field_value_readback', FALSE,
      'snapshot_payload_readback', FALSE,
      'allowed_entity_scope', 'reference_dimensions',
      'allowed_field_names', ARRAY['name']::TEXT[]
    ),
    'wait_for_guarded_update_rollback_worker_apply',
    CASE WHEN v_is_service_role THEN v_readiness.tenant_id ELSE NULL END
  );

  RETURN QUERY
  SELECT
    cj.id,
    cj.status,
    v_readiness.id,
    v_readiness.rollback_approval_id,
    v_readiness.rollback_preview_id,
    v_readiness.change_set_id,
    v_readiness.import_batch_id,
    v_readiness.rollback_count,
    v_readiness.field_diff_count,
    v_readiness.rollback_snapshot_count,
    COALESCE(cj.next_action_key, 'wait_for_guarded_update_rollback_worker_apply')::TEXT
  FROM puls_integration.connector_jobs cj
  WHERE cj.id = v_job_id;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration._connector_apply_restore_reference_name(
  p_batch puls_integration.import_batches,
  p_namespace puls_integration.source_namespaces,
  p_preview_item puls_integration.connector_apply_rollback_preview_items,
  p_snapshot puls_integration.connector_apply_rollback_snapshots
)
RETURNS UUID
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_name TEXT := NULLIF(btrim(COALESCE(p_snapshot.snapshot_payload ->> 'name', '')), '');
  v_expected_post_apply_hash TEXT := p_preview_item.expected_post_apply_hash;
  v_current_hash TEXT;
  v_restored_hash TEXT;
BEGIN
  IF v_name IS NULL THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_SNAPSHOT_NAME_REQUIRED: row % rollback snapshot requires a non-empty name.', p_preview_item.row_number;
  END IF;

  IF p_preview_item.canonical_id IS NULL OR v_expected_post_apply_hash IS NULL THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_CURRENT_HASH_REQUIRED: row % requires canonical id and expected post-apply hash.', p_preview_item.row_number;
  END IF;

  IF p_snapshot.snapshot_state IS DISTINCT FROM 'available'
     OR p_snapshot.value_readback_allowed IS DISTINCT FROM FALSE
     OR p_snapshot.hot_retention_expires_at <= NOW()
     OR puls_integration._connector_apply_hash_jsonb(p_snapshot.snapshot_payload) IS DISTINCT FROM p_snapshot.snapshot_hash THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_SNAPSHOT_INVALID: row % rollback snapshot is unavailable or hash-invalid.', p_preview_item.row_number;
  END IF;

  v_current_hash := puls_integration._connector_apply_expected_current_hash(
    p_batch.tenant_id,
    p_namespace.id,
    p_preview_item.entity_type,
    p_preview_item.external_id,
    p_preview_item.canonical_id
  );

  IF v_current_hash IS NULL OR v_current_hash IS DISTINCT FROM v_expected_post_apply_hash THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_STALE_TARGET: row % current hash no longer matches rollback expectation.', p_preview_item.row_number;
  END IF;

  IF p_preview_item.entity_type = 'legal_entity'::puls_integration.import_entity_type THEN
    UPDATE puls_core.legal_entities le
    SET name = v_name, updated_at = NOW()
    WHERE le.tenant_id = p_batch.tenant_id
      AND le.id = p_preview_item.canonical_id;
  ELSIF p_preview_item.entity_type = 'location'::puls_integration.import_entity_type THEN
    UPDATE puls_core.locations loc
    SET name = v_name, updated_at = NOW()
    WHERE loc.tenant_id = p_batch.tenant_id
      AND loc.id = p_preview_item.canonical_id;
  ELSIF p_preview_item.entity_type = 'cost_center'::puls_integration.import_entity_type THEN
    UPDATE puls_core.cost_centers cc
    SET name = v_name, updated_at = NOW()
    WHERE cc.tenant_id = p_batch.tenant_id
      AND cc.id = p_preview_item.canonical_id;
  ELSIF p_preview_item.entity_type = 'department'::puls_integration.import_entity_type THEN
    UPDATE puls_core.departments dept
    SET name = v_name, updated_at = NOW()
    WHERE dept.tenant_id = p_batch.tenant_id
      AND dept.id = p_preview_item.canonical_id;
  ELSIF p_preview_item.entity_type = 'position'::puls_integration.import_entity_type THEN
    UPDATE puls_core.positions pos
    SET name = v_name, updated_at = NOW()
    WHERE pos.tenant_id = p_batch.tenant_id
      AND pos.id = p_preview_item.canonical_id;
  ELSE
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_ENTITY_UNSUPPORTED: entity type is outside PR16.8 rollback scope.';
  END IF;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_TARGET_NOT_FOUND: row % canonical target is missing.', p_preview_item.row_number;
  END IF;

  v_restored_hash := puls_integration._connector_apply_hash_jsonb(
    puls_integration._connector_apply_current_reference_payload(
      p_batch.tenant_id,
      p_preview_item.entity_type,
      p_preview_item.canonical_id
    )
  );

  IF v_restored_hash IS DISTINCT FROM p_snapshot.snapshot_hash THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_RESTORE_HASH_MISMATCH: row % restored payload hash does not match rollback snapshot.', p_preview_item.row_number;
  END IF;

  PERFORM puls_integration._import_upsert_identity_map(
    p_batch.tenant_id,
    p_namespace.id,
    p_preview_item.entity_type,
    p_preview_item.external_id,
    p_preview_item.canonical_id,
    p_snapshot.snapshot_hash
  );

  RETURN p_preview_item.canonical_id;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration.execute_connector_guarded_update_rollback_apply_job(
  p_job_id UUID,
  p_worker_id TEXT
)
RETURNS TABLE (
  rollback_worker_readiness_id UUID,
  rollback_approval_id UUID,
  rollback_preview_id UUID,
  change_set_id UUID,
  import_batch_id UUID,
  status TEXT,
  row_count INTEGER,
  rollback_count INTEGER,
  field_diff_count INTEGER,
  rollback_snapshot_count INTEGER,
  object_event_count INTEGER,
  execution_enabled BOOLEAN,
  canonical_write_enabled BOOLEAN,
  rollback_execution_enabled BOOLEAN,
  source_writeback_enabled BOOLEAN,
  credential_readback_enabled BOOLEAN,
  provider_api_calls_enabled BOOLEAN,
  next_action_key TEXT
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
#variable_conflict use_column
DECLARE
  v_auth_role TEXT := COALESCE(auth.role(), '');
  v_job puls_integration.connector_jobs;
  v_worker_id TEXT := btrim(COALESCE(p_worker_id, ''));
  v_readiness_id UUID;
  v_readiness puls_integration.connector_apply_rollback_worker_readiness;
  v_change_set puls_integration.connector_apply_change_sets;
  v_batch puls_integration.import_batches;
  v_namespace puls_integration.source_namespaces;
  v_preview_item puls_integration.connector_apply_rollback_preview_items;
  v_snapshot puls_integration.connector_apply_rollback_snapshots;
  v_canonical_id UUID;
  v_rollback_count INTEGER := 0;
  v_existing_event_count INTEGER := 0;
  v_field_diff_count INTEGER := 0;
  v_snapshot_count INTEGER := 0;
  v_original_apply_event_id UUID;
BEGIN
  IF v_auth_role <> 'service_role' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_ONLY: guarded update rollback execution requires service_role.';
  END IF;

  IF v_worker_id = '' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_REQUIRED: worker id is required.';
  END IF;

  SELECT *
  INTO v_job
  FROM puls_integration.connector_jobs cj
  WHERE cj.id = p_job_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_JOB_NOT_FOUND: connector job not found.';
  END IF;

  IF v_job.job_type <> 'import_apply'::puls_integration.connector_job_type THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_JOB_TYPE_INVALID: job type must be import_apply.';
  END IF;

  IF v_job.status <> 'running'::puls_integration.connector_job_status
     OR v_job.locked_by IS DISTINCT FROM v_worker_id THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_JOB_LEASE_INVALID: worker does not own this running job.';
  END IF;

  IF v_job.domain IS DISTINCT FROM 'import_apply_guarded_update_rollback'
     OR v_job.safe_error_context ->> 'contract_version' IS DISTINCT FROM 'pr16.8-guarded-update-rollback-worker-apply-v1'
     OR v_job.safe_error_context ->> 'apply_mode' IS DISTINCT FROM 'guarded_update_rollback' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_JOB_CONTEXT_INVALID: job is not a PR16.8 rollback apply job.';
  END IF;

  IF v_job.safe_error_context ->> 'rollback_worker_readiness_id' IS NULL
     OR v_job.safe_error_context ->> 'rollback_worker_readiness_id'
       !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_JOB_CONTEXT_INVALID: job is missing a valid rollback_worker_readiness_id.';
  END IF;

  v_readiness_id := (v_job.safe_error_context ->> 'rollback_worker_readiness_id')::UUID;
  PERFORM puls_integration._connector_apply_validate_guarded_update_rollback_readiness(v_readiness_id);

  SELECT *
  INTO v_readiness
  FROM puls_integration.connector_apply_rollback_worker_readiness readiness
  WHERE readiness.id = v_readiness_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_READINESS_NOT_FOUND: rollback worker readiness not found.';
  END IF;

  IF v_readiness.tenant_id IS DISTINCT FROM v_job.tenant_id
     OR v_readiness.connection_id IS DISTINCT FROM v_job.connection_id
     OR v_readiness.source_namespace_id IS DISTINCT FROM v_job.source_namespace_id
     OR v_readiness.import_batch_id IS DISTINCT FROM v_job.import_batch_id
     OR v_readiness.rollback_preview_checksum IS DISTINCT FROM v_job.safe_error_context ->> 'rollback_preview_checksum' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_JOB_CONTEXT_MISMATCH: job context does not match rollback readiness.';
  END IF;

  SELECT *
  INTO v_change_set
  FROM puls_integration.connector_apply_change_sets cs
  WHERE cs.id = v_readiness.change_set_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_CHANGE_SET_NOT_FOUND: change-set not found.';
  END IF;

  v_batch := puls_integration._import_lock_batch(v_readiness.import_batch_id);

  SELECT *
  INTO v_namespace
  FROM puls_integration.source_namespaces sn
  WHERE sn.id = v_readiness.source_namespace_id
    AND sn.tenant_id = v_readiness.tenant_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_NAMESPACE_REQUIRED: source namespace is missing.';
  END IF;

  SELECT COUNT(*)::INTEGER
  INTO v_existing_event_count
  FROM puls_integration.connector_apply_object_events event
  WHERE event.change_set_id = v_readiness.change_set_id
    AND event.operation = 'rollback'::puls_integration.connector_apply_operation;

  IF v_existing_event_count > 0 THEN
    IF EXISTS (
      SELECT 1
      FROM puls_integration.connector_apply_object_events event
      WHERE event.change_set_id = v_readiness.change_set_id
        AND event.operation = 'rollback'::puls_integration.connector_apply_operation
        AND event.connector_job_id IS DISTINCT FROM v_job.id
    ) THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_ALREADY_APPLIED: rollback was applied by another job.';
    END IF;

    RETURN QUERY
    SELECT
      v_readiness.id,
      v_readiness.rollback_approval_id,
      v_readiness.rollback_preview_id,
      v_readiness.change_set_id,
      v_readiness.import_batch_id,
      'applied_guarded_update_rollback'::TEXT,
      v_readiness.row_count,
      v_readiness.rollback_count,
      v_readiness.field_diff_count,
      v_readiness.rollback_snapshot_count,
      v_existing_event_count,
      TRUE,
      TRUE,
      TRUE,
      FALSE,
      FALSE,
      FALSE,
      'review_guarded_update_rollback_object_events'::TEXT;
    RETURN;
  END IF;

  SELECT COUNT(*)::INTEGER
  INTO v_field_diff_count
  FROM puls_integration.connector_apply_field_diffs diff
  WHERE diff.change_set_id = v_readiness.change_set_id;

  SELECT COUNT(*)::INTEGER
  INTO v_snapshot_count
  FROM puls_integration.connector_apply_rollback_snapshots snap
  WHERE snap.change_set_id = v_readiness.change_set_id
    AND snap.snapshot_state = 'available'
    AND snap.hot_retention_expires_at > NOW();

  PERFORM set_config('puls.import_apply.active', 'true', true);

  FOR v_preview_item IN
    SELECT item.*
    FROM puls_integration.connector_apply_rollback_preview_items item
    WHERE item.rollback_preview_id = v_readiness.rollback_preview_id
      AND item.item_status = 'ready'
    ORDER BY CASE item.entity_type
      WHEN 'legal_entity'::puls_integration.import_entity_type THEN 10
      WHEN 'location'::puls_integration.import_entity_type THEN 20
      WHEN 'cost_center'::puls_integration.import_entity_type THEN 30
      WHEN 'department'::puls_integration.import_entity_type THEN 40
      WHEN 'position'::puls_integration.import_entity_type THEN 50
      ELSE 100
    END,
    item.row_number
  LOOP
    SELECT *
    INTO v_snapshot
    FROM puls_integration.connector_apply_rollback_snapshots snap
    WHERE snap.change_set_item_id = v_preview_item.change_set_item_id
      AND snap.snapshot_state = 'available'
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_SNAPSHOT_REQUIRED: row % rollback snapshot is missing.', v_preview_item.row_number;
    END IF;

    v_original_apply_event_id := NULL;

    SELECT event.id
    INTO v_original_apply_event_id
    FROM puls_integration.connector_apply_object_events event
    WHERE event.change_set_item_id = v_preview_item.change_set_item_id
      AND event.operation = 'update'::puls_integration.connector_apply_operation
      AND event.canonical_id = v_preview_item.canonical_id
    ORDER BY event.created_at DESC
    LIMIT 1;

    IF v_original_apply_event_id IS NULL THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_ORIGINAL_EVENT_REQUIRED: row % original apply object event is missing.', v_preview_item.row_number;
    END IF;

    v_canonical_id := puls_integration._connector_apply_restore_reference_name(
      v_batch,
      v_namespace,
      v_preview_item,
      v_snapshot
    );

    INSERT INTO puls_integration.connector_apply_object_events (
      tenant_id,
      connection_id,
      source_namespace_id,
      import_batch_id,
      change_set_id,
      change_set_item_id,
      import_record_id,
      connector_job_id,
      operation,
      entity_type,
      external_id,
      target_table,
      canonical_id,
      source_row_hash,
      change_set_checksum,
      audit_tiers,
      retention_bucket,
      safe_summary,
      created_by_worker_id
    )
    VALUES (
      v_readiness.tenant_id,
      v_readiness.connection_id,
      v_readiness.source_namespace_id,
      v_readiness.import_batch_id,
      v_readiness.change_set_id,
      v_preview_item.change_set_item_id,
      v_preview_item.import_record_id,
      v_job.id,
      'rollback'::puls_integration.connector_apply_operation,
      v_preview_item.entity_type,
      v_preview_item.external_id,
      v_preview_item.target_table,
      v_canonical_id,
      v_snapshot.snapshot_hash,
      v_change_set.change_set_checksum,
      ARRAY[
        'object_event'::puls_integration.connector_apply_audit_tier,
        'field_diff'::puls_integration.connector_apply_audit_tier,
        'rollback_snapshot'::puls_integration.connector_apply_audit_tier
      ],
      'object_event',
      jsonb_build_object(
        'contract_version', 'pr16.8-guarded-update-rollback-worker-apply-v1',
        'rollback_worker_readiness_id', v_readiness.id,
        'rollback_approval_id', v_readiness.rollback_approval_id,
        'rollback_preview_id', v_readiness.rollback_preview_id,
        'change_set_id', v_readiness.change_set_id,
        'import_batch_id', v_readiness.import_batch_id,
        'original_apply_event_id', v_original_apply_event_id,
        'row_number', v_preview_item.row_number,
        'entity_type', v_preview_item.entity_type,
        'target_table', v_preview_item.target_table,
        'operation', 'rollback',
        'safe_field_names', ARRAY['name']::TEXT[],
        'rollback_field_names', v_preview_item.rollback_field_names,
        'destructive_field_names', '{}'::TEXT[],
        'field_diff_count', v_preview_item.field_diff_count,
        'rollback_snapshot_required', TRUE,
        'rollback_execution', TRUE,
        'canonical_write', TRUE,
        'compensating_execution', FALSE,
        'source_writeback', FALSE,
        'credential_readback', FALSE,
        'provider_api_calls', FALSE,
        'raw_payload_readback', FALSE,
        'field_value_readback', FALSE,
        'snapshot_payload_readback', FALSE
      ),
      v_worker_id
    );

    v_rollback_count := v_rollback_count + 1;
  END LOOP;

  IF v_rollback_count <> v_readiness.rollback_count THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_COUNT_MISMATCH: rollback record count does not match readiness.';
  END IF;

  INSERT INTO puls_integration.erp_sync_batches (
    tenant_id,
    connection_id,
    sync_type,
    status,
    started_at,
    finished_at,
    records_seen,
    records_inserted,
    records_updated,
    records_skipped,
    records_failed,
    event_key,
    actor_employee_id,
    safe_error_code,
    safe_error_context,
    next_action_key
  )
  VALUES (
    v_readiness.tenant_id,
    v_readiness.connection_id,
    'import_apply_execution',
    'success'::puls_integration.sync_status,
    v_job.started_at,
    NOW(),
    v_readiness.row_count,
    0,
    v_rollback_count,
    0,
    0,
    'import_apply_guarded_update_rollback_completed',
    v_job.created_by_employee_id,
    NULL,
    jsonb_build_object(
      'contract_version', 'pr16.8-guarded-update-rollback-worker-apply-v1',
      'rollback_worker_readiness_id', v_readiness.id,
      'rollback_approval_id', v_readiness.rollback_approval_id,
      'rollback_preview_id', v_readiness.rollback_preview_id,
      'change_set_id', v_readiness.change_set_id,
      'import_batch_id', v_readiness.import_batch_id,
      'row_count', v_readiness.row_count,
      'rollback_count', v_rollback_count,
      'field_diff_count', v_field_diff_count,
      'rollback_snapshot_count', v_snapshot_count,
      'object_event_count', v_rollback_count,
      'execution_enabled', TRUE,
      'canonical_write_enabled', TRUE,
      'rollback_execution_enabled', TRUE,
      'compensating_execution_enabled', FALSE,
      'source_writeback_enabled', FALSE,
      'credential_readback_enabled', FALSE,
      'provider_api_calls', FALSE,
      'raw_payload_readback', FALSE,
      'field_value_readback', FALSE,
      'snapshot_payload_readback', FALSE
    ),
    'review_guarded_update_rollback_object_events'
  );

  RETURN QUERY
  SELECT
    v_readiness.id,
    v_readiness.rollback_approval_id,
    v_readiness.rollback_preview_id,
    v_readiness.change_set_id,
    v_readiness.import_batch_id,
    'applied_guarded_update_rollback'::TEXT,
    v_readiness.row_count,
    v_rollback_count,
    v_field_diff_count,
    v_snapshot_count,
    v_rollback_count,
    TRUE,
    TRUE,
    TRUE,
    FALSE,
    FALSE,
    FALSE,
    'review_guarded_update_rollback_object_events'::TEXT;
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
    'pr16.8-guarded-update-rollback-worker-apply-v1'::TEXT AS contract_version,
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
    'guarded_update_rollback_worker_apply_open'::TEXT AS safe_error_code,
    'enqueue_guarded_update_rollback_after_readiness'::TEXT AS next_action_key
  FROM puls_integration.erp_connections c
  WHERE (v_auth_role = 'service_role' OR c.tenant_id = v_tenant_id)
    AND (p_connection_id IS NULL OR c.id = p_connection_id)
  ORDER BY c.updated_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION puls_integration._connector_apply_validate_guarded_update_rollback_readiness(UUID)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration._connector_apply_validate_guarded_update_rollback_readiness(UUID)
  TO service_role;

REVOKE ALL ON FUNCTION puls_integration.enqueue_connector_guarded_update_rollback_apply_job(UUID)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.enqueue_connector_guarded_update_rollback_apply_job(UUID)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_integration._connector_apply_restore_reference_name(
  puls_integration.import_batches,
  puls_integration.source_namespaces,
  puls_integration.connector_apply_rollback_preview_items,
  puls_integration.connector_apply_rollback_snapshots
) FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration._connector_apply_restore_reference_name(
  puls_integration.import_batches,
  puls_integration.source_namespaces,
  puls_integration.connector_apply_rollback_preview_items,
  puls_integration.connector_apply_rollback_snapshots
) TO service_role;

REVOKE ALL ON FUNCTION puls_integration.execute_connector_guarded_update_rollback_apply_job(UUID, TEXT)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.execute_connector_guarded_update_rollback_apply_job(UUID, TEXT)
  TO service_role;

COMMENT ON FUNCTION puls_integration.enqueue_connector_guarded_update_rollback_apply_job(UUID) IS
  'Admin-safe enqueue RPC for PR16.8 guarded update rollback worker apply. It queues a readiness-bound rollback job but does not directly write canonical data.';

COMMENT ON FUNCTION puls_integration.execute_connector_guarded_update_rollback_apply_job(UUID, TEXT) IS
  'Service-role worker execution RPC for PR16.8 guarded-update rollback. It revalidates readiness, current-state, snapshot hash, retention, and lease ownership immediately before restoring safe reference names.';

COMMENT ON FUNCTION puls_integration._connector_apply_validate_guarded_update_rollback_readiness(UUID) IS
  'PR16.8 rollback worker validator. Requires PR16.7 readiness, approval checksum match, current-state recheck, original apply event, active rollback snapshot retention, and closed source/provider/readback boundaries.';
