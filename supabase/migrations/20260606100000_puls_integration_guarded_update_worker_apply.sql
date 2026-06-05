-- PR16.4.2 guarded update worker apply.
-- Opens a narrow worker-only canonical update path after PR16.4.1 evidence.
-- Scope: admin-approved, evidence-ready, stale-hash-guarded reference-dimension
-- name updates only. Browser direct apply, employee updates, destructive fields,
-- ERP/source writeback, provider API calls, credential readback, raw payload
-- readback, rollback execution, and AI autonomous apply remain closed.

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
      'update'::puls_integration.connector_apply_operation
    )
  );

CREATE OR REPLACE FUNCTION puls_integration._connector_apply_validate_guarded_update_change_set(
  p_change_set_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_change_set puls_integration.connector_apply_change_sets;
  v_batch puls_integration.import_batches;
  v_item_count INTEGER := 0;
  v_diff_count INTEGER := 0;
  v_snapshot_count INTEGER := 0;
BEGIN
  SELECT *
  INTO v_change_set
  FROM puls_integration.connector_apply_change_sets cs
  WHERE cs.id = p_change_set_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_CHANGE_SET_NOT_FOUND: change-set not found.';
  END IF;

  SELECT *
  INTO v_batch
  FROM puls_integration.import_batches ib
  WHERE ib.id = v_change_set.import_batch_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_BATCH_NOT_FOUND: import batch not found.';
  END IF;

  IF v_batch.tenant_id IS DISTINCT FROM v_change_set.tenant_id THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_TENANT_MISMATCH: batch and change-set tenant mismatch.';
  END IF;

  IF v_batch.status <> 'previewed'::puls_integration.import_batch_status THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_PREVIEW_REQUIRED: batch must be previewed.';
  END IF;

  IF v_batch.mode <> 'dry_run'::puls_integration.import_batch_mode THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_DRY_RUN_REQUIRED: guarded update apply requires dry-run evidence.';
  END IF;

  IF COALESCE(v_batch.error_count, 0) > 0 THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_ROW_ERRORS: batch has row errors.';
  END IF;

  IF v_batch.source_checksum IS DISTINCT FROM v_change_set.source_checksum THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_CHECKSUM_MISMATCH: source checksum does not match change-set.';
  END IF;

  IF v_change_set.status <> 'blocked'::puls_integration.connector_apply_change_set_status THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_CHANGE_SET_NOT_BLOCKED_REVIEW: guarded update change-set must be blocked pending review.';
  END IF;

  IF v_change_set.row_count <= 0
     OR v_change_set.update_count <> v_change_set.row_count
     OR v_change_set.guarded_update_count <> v_change_set.row_count THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_UPDATE_ROWS_REQUIRED: all rows must be guarded update candidates.';
  END IF;

  IF COALESCE(v_change_set.create_count, 0) <> 0
     OR COALESCE(v_change_set.skip_count, 0) <> 0
     OR COALESCE(v_change_set.blocked_count, 0) <> v_change_set.guarded_update_count
     OR COALESCE(v_change_set.stale_count, 0) <> 0
     OR COALESCE(v_change_set.destructive_count, 0) <> 0
     OR COALESCE(v_change_set.source_conflict_count, 0) <> 0
     OR COALESCE(v_change_set.no_change_count, 0) <> 0 THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_BLOCKERS_PRESENT: only guarded update review blockers are allowed.';
  END IF;

  IF NOT puls_integration._connector_apply_has_batch_admin_approval(p_change_set_id) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_APPROVAL_REQUIRED: admin approval is required before enqueue.';
  END IF;

  SELECT COUNT(*)::INTEGER
  INTO v_item_count
  FROM puls_integration.connector_apply_change_set_items item
  WHERE item.change_set_id = p_change_set_id;

  IF v_item_count <> v_change_set.row_count THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_ITEM_COUNT_MISMATCH: change-set item count must match row count.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM puls_integration.connector_apply_change_set_items item
    WHERE item.change_set_id = p_change_set_id
      AND (
        item.operation IS DISTINCT FROM 'update'::puls_integration.connector_apply_operation
        OR item.risk_class IS DISTINCT FROM 'guarded_overwrite'::puls_integration.connector_apply_risk_class
        OR item.blocked IS DISTINCT FROM TRUE
        OR item.canonical_id IS NULL
        OR item.expected_current_hash IS NULL
        OR item.current_action IS DISTINCT FROM 'update'
        OR item.preview_action IS DISTINCT FROM 'update'
        OR item.rollback_snapshot_required IS DISTINCT FROM TRUE
        OR NOT puls_integration._connector_apply_is_create_only_reference_entity(item.entity_type)
      )
  ) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_ITEM_SCOPE_INVALID: all items must be guarded reference updates.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM puls_integration.connector_apply_change_set_items item
    CROSS JOIN LATERAL unnest(item.safe_field_names) AS fields(field_name)
    WHERE item.change_set_id = p_change_set_id
      AND NOT puls_integration._connector_apply_guarded_update_field_allowed(
        item.entity_type,
        fields.field_name
      )
  ) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_FIELD_SCOPE_INVALID: change-set contains fields outside guarded update scope.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM puls_integration.connector_apply_change_set_items item
    WHERE item.change_set_id = p_change_set_id
      AND COALESCE(array_length(item.destructive_field_names, 1), 0) > 0
  ) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_DESTRUCTIVE_FIELD_BLOCKED: destructive-equivalent fields are not allowed.';
  END IF;

  SELECT COUNT(*)::INTEGER
  INTO v_diff_count
  FROM puls_integration.connector_apply_field_diffs diff
  WHERE diff.change_set_id = p_change_set_id;

  SELECT COUNT(*)::INTEGER
  INTO v_snapshot_count
  FROM puls_integration.connector_apply_rollback_snapshots snap
  WHERE snap.change_set_id = p_change_set_id
    AND snap.snapshot_state = 'available';

  IF v_diff_count <= 0 OR v_snapshot_count <> v_change_set.guarded_update_count THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_EVIDENCE_REQUIRED: field diffs and rollback snapshots must be generated first.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM puls_integration.connector_apply_change_set_items item
    WHERE item.change_set_id = p_change_set_id
      AND NOT EXISTS (
        SELECT 1
        FROM puls_integration.connector_apply_field_diffs diff
        WHERE diff.change_set_item_id = item.id
      )
  ) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_FIELD_DIFF_REQUIRED: every guarded update row needs field diff evidence.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM puls_integration.connector_apply_field_diffs diff
    JOIN puls_integration.connector_apply_change_set_items item
      ON item.id = diff.change_set_item_id
    WHERE diff.change_set_id = p_change_set_id
      AND (
        diff.field_name <> 'name'
        OR diff.field_class <> 'safe'
        OR diff.operation <> 'set'
        OR diff.stale_blocked IS TRUE
        OR diff.value_readback_allowed IS DISTINCT FROM FALSE
        OR NOT puls_integration._connector_apply_guarded_update_mutable_field_allowed(
          item.entity_type,
          diff.field_name
        )
      )
  ) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_FIELD_DIFF_SCOPE_INVALID: only safe name set diffs are executable.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM puls_integration.connector_apply_rollback_snapshots snap
    WHERE snap.change_set_id = p_change_set_id
      AND snap.value_readback_allowed IS DISTINCT FROM FALSE
  ) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_SNAPSHOT_BOUNDARY_INVALID: rollback snapshots must not allow value readback.';
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
     OR COALESCE(NEW.safe_error_context ->> 'field_value_readback', 'true') <> 'false' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_APPLY_BOUNDARY_INVALID: worker apply boundaries are invalid.';
  END IF;

  IF v_change_set_id_text IS NULL
     OR v_change_set_id_text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_APPLY_CHANGE_SET_REQUIRED: valid change_set_id is required.';
  END IF;

  v_change_set_id := v_change_set_id_text::UUID;

  IF v_mode = 'create_only' THEN
    PERFORM puls_integration._connector_apply_validate_create_only_change_set(v_change_set_id);
  ELSE
    PERFORM puls_integration._connector_apply_validate_guarded_update_change_set(v_change_set_id);
  END IF;

  IF NOT EXISTS (
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

CREATE OR REPLACE FUNCTION puls_integration.enqueue_connector_guarded_update_apply_job(
  p_change_set_id UUID
)
RETURNS TABLE (
  job_id UUID,
  status puls_integration.connector_job_status,
  change_set_id UUID,
  import_batch_id UUID,
  update_count INTEGER,
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
  v_change_set puls_integration.connector_apply_change_sets;
  v_job_id UUID;
  v_field_diff_count INTEGER := 0;
  v_snapshot_count INTEGER := 0;
BEGIN
  IF NOT v_is_service_role AND NOT COALESCE(puls_core.is_admin(), FALSE) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_ADMIN_REQUIRED: admin permission is required.';
  END IF;

  IF NOT v_is_service_role AND v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_TENANT_REQUIRED: authenticated caller has no tenant context.';
  END IF;

  PERFORM puls_integration._connector_apply_validate_guarded_update_change_set(p_change_set_id);

  SELECT *
  INTO v_change_set
  FROM puls_integration.connector_apply_change_sets cs
  WHERE cs.id = p_change_set_id;

  IF NOT v_is_service_role AND v_change_set.tenant_id IS DISTINCT FROM v_tenant_id THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_FORBIDDEN: change-set belongs to another tenant.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM puls_integration.connector_apply_object_events event
    WHERE event.change_set_id = p_change_set_id
  ) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_ALREADY_APPLIED: change-set already has object events.';
  END IF;

  SELECT COUNT(*)::INTEGER
  INTO v_field_diff_count
  FROM puls_integration.connector_apply_field_diffs diff
  WHERE diff.change_set_id = p_change_set_id;

  SELECT COUNT(*)::INTEGER
  INTO v_snapshot_count
  FROM puls_integration.connector_apply_rollback_snapshots snap
  WHERE snap.change_set_id = p_change_set_id
    AND snap.snapshot_state = 'available';

  v_job_id := puls_integration.enqueue_connector_job(
    'import_apply'::puls_integration.connector_job_type,
    concat_ws(
      ':',
      'pr16.4.2-guarded-update-apply',
      v_change_set.id::TEXT,
      v_change_set.change_set_checksum
    ),
    v_change_set.connection_id,
    v_change_set.source_namespace_id,
    v_change_set.import_batch_id,
    'import_apply_guarded_update',
    45,
    NOW(),
    1,
    jsonb_build_object(
      'contract_version', 'pr16.4.2-guarded-update-worker-apply-v1',
      'apply_mode', 'guarded_update',
      'change_set_id', v_change_set.id,
      'change_set_checksum', v_change_set.change_set_checksum,
      'row_count', v_change_set.row_count,
      'update_count', v_change_set.update_count,
      'guarded_update_count', v_change_set.guarded_update_count,
      'field_diff_count', v_field_diff_count,
      'rollback_snapshot_count', v_snapshot_count,
      'execution_enabled', TRUE,
      'canonical_write_enabled', TRUE,
      'source_writeback_enabled', FALSE,
      'credential_readback_enabled', FALSE,
      'provider_api_calls', FALSE,
      'raw_payload_readback', FALSE,
      'field_value_readback', FALSE,
      'allowed_entity_scope', 'reference_dimensions',
      'allowed_field_names', ARRAY['name']::TEXT[]
    ),
    'wait_for_guarded_update_worker_apply',
    CASE WHEN v_is_service_role THEN v_change_set.tenant_id ELSE NULL END
  );

  RETURN QUERY
  SELECT
    cj.id,
    cj.status,
    v_change_set.id,
    v_change_set.import_batch_id,
    v_change_set.update_count,
    v_field_diff_count,
    v_snapshot_count,
    COALESCE(cj.next_action_key, 'wait_for_guarded_update_worker_apply')::TEXT
  FROM puls_integration.connector_jobs cj
  WHERE cj.id = v_job_id;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration._connector_apply_update_reference_name(
  p_batch puls_integration.import_batches,
  p_namespace puls_integration.source_namespaces,
  p_item puls_integration.connector_apply_change_set_items,
  p_record puls_integration.import_records
)
RETURNS UUID
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_payload JSONB := COALESCE(p_record.normalized_payload, '{}'::JSONB);
  v_name TEXT := NULLIF(btrim(COALESCE(v_payload ->> 'name', '')), '');
  v_current_hash TEXT;
BEGIN
  IF v_name IS NULL THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_NAME_REQUIRED: row % requires a non-empty name.', p_item.row_number;
  END IF;

  IF p_item.canonical_id IS NULL OR p_item.expected_current_hash IS NULL THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_CURRENT_HASH_REQUIRED: row % requires canonical id and expected current hash.', p_item.row_number;
  END IF;

  v_current_hash := puls_integration._connector_apply_expected_current_hash(
    p_batch.tenant_id,
    p_batch.source_namespace_id,
    p_item.entity_type,
    p_item.external_id,
    p_item.canonical_id
  );

  IF v_current_hash IS NULL OR v_current_hash IS DISTINCT FROM p_item.expected_current_hash THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_STALE_TARGET: row % current hash no longer matches change-set expectation.', p_item.row_number;
  END IF;

  IF p_item.entity_type = 'legal_entity'::puls_integration.import_entity_type THEN
    UPDATE puls_core.legal_entities le
    SET name = v_name, updated_at = NOW()
    WHERE le.tenant_id = p_batch.tenant_id
      AND le.id = p_item.canonical_id;
  ELSIF p_item.entity_type = 'location'::puls_integration.import_entity_type THEN
    UPDATE puls_core.locations loc
    SET name = v_name, updated_at = NOW()
    WHERE loc.tenant_id = p_batch.tenant_id
      AND loc.id = p_item.canonical_id;
  ELSIF p_item.entity_type = 'cost_center'::puls_integration.import_entity_type THEN
    UPDATE puls_core.cost_centers cc
    SET name = v_name, updated_at = NOW()
    WHERE cc.tenant_id = p_batch.tenant_id
      AND cc.id = p_item.canonical_id;
  ELSIF p_item.entity_type = 'department'::puls_integration.import_entity_type THEN
    UPDATE puls_core.departments dept
    SET name = v_name, updated_at = NOW()
    WHERE dept.tenant_id = p_batch.tenant_id
      AND dept.id = p_item.canonical_id;
  ELSIF p_item.entity_type = 'position'::puls_integration.import_entity_type THEN
    UPDATE puls_core.positions pos
    SET name = v_name, updated_at = NOW()
    WHERE pos.tenant_id = p_batch.tenant_id
      AND pos.id = p_item.canonical_id;
  ELSE
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_ENTITY_UNSUPPORTED: entity type is outside PR16.4.2 scope.';
  END IF;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_TARGET_NOT_FOUND: row % canonical target is missing.', p_item.row_number;
  END IF;

  PERFORM puls_integration._import_upsert_identity_map(
    p_batch.tenant_id,
    p_batch.source_namespace_id,
    p_record.entity_type,
    p_record.external_id,
    p_item.canonical_id,
    p_record.row_hash
  );

  PERFORM puls_integration._import_mark_applied(p_record.id, p_item.canonical_id);

  RETURN p_item.canonical_id;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration.execute_connector_guarded_update_apply_job(
  p_job_id UUID,
  p_worker_id TEXT
)
RETURNS TABLE (
  change_set_id UUID,
  import_batch_id UUID,
  status TEXT,
  row_count INTEGER,
  update_count INTEGER,
  field_diff_count INTEGER,
  rollback_snapshot_count INTEGER,
  object_event_count INTEGER,
  execution_enabled BOOLEAN,
  canonical_write_enabled BOOLEAN,
  source_writeback_enabled BOOLEAN,
  credential_readback_enabled BOOLEAN,
  next_action_key TEXT
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_auth_role TEXT := COALESCE(auth.role(), '');
  v_job puls_integration.connector_jobs;
  v_worker_id TEXT := btrim(COALESCE(p_worker_id, ''));
  v_change_set_id UUID;
  v_change_set puls_integration.connector_apply_change_sets;
  v_batch puls_integration.import_batches;
  v_namespace puls_integration.source_namespaces;
  v_item puls_integration.connector_apply_change_set_items;
  v_record puls_integration.import_records;
  v_canonical_id UUID;
  v_update_count INTEGER := 0;
  v_field_diff_count INTEGER := 0;
  v_snapshot_count INTEGER := 0;
  v_existing_event_count INTEGER := 0;
BEGIN
  IF v_auth_role <> 'service_role' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_WORKER_ONLY: guarded update apply execution requires service_role.';
  END IF;

  IF v_worker_id = '' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_WORKER_REQUIRED: worker id is required.';
  END IF;

  SELECT *
  INTO v_job
  FROM puls_integration.connector_jobs cj
  WHERE cj.id = p_job_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_JOB_NOT_FOUND: connector job not found.';
  END IF;

  IF v_job.job_type <> 'import_apply'::puls_integration.connector_job_type THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_JOB_TYPE_INVALID: job type must be import_apply.';
  END IF;

  IF v_job.status <> 'running'::puls_integration.connector_job_status
     OR v_job.locked_by IS DISTINCT FROM v_worker_id THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_JOB_LEASE_INVALID: worker does not own this running job.';
  END IF;

  IF v_job.safe_error_context ->> 'contract_version' IS DISTINCT FROM 'pr16.4.2-guarded-update-worker-apply-v1'
     OR v_job.safe_error_context ->> 'apply_mode' IS DISTINCT FROM 'guarded_update' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_JOB_CONTEXT_INVALID: job is not a PR16.4.2 guarded update apply job.';
  END IF;

  IF v_job.safe_error_context ->> 'change_set_id' IS NULL
     OR v_job.safe_error_context ->> 'change_set_id'
       !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_JOB_CONTEXT_INVALID: job is missing a valid change_set_id.';
  END IF;

  v_change_set_id := (v_job.safe_error_context ->> 'change_set_id')::UUID;

  SELECT *
  INTO v_change_set
  FROM puls_integration.connector_apply_change_sets cs
  WHERE cs.id = v_change_set_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_CHANGE_SET_NOT_FOUND: change-set not found.';
  END IF;

  IF v_change_set.tenant_id IS DISTINCT FROM v_job.tenant_id
     OR v_change_set.connection_id IS DISTINCT FROM v_job.connection_id
     OR v_change_set.source_namespace_id IS DISTINCT FROM v_job.source_namespace_id
     OR v_change_set.import_batch_id IS DISTINCT FROM v_job.import_batch_id THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_JOB_CONTEXT_MISMATCH: job context does not match change-set.';
  END IF;

  v_batch := puls_integration._import_lock_batch(v_change_set.import_batch_id);

  SELECT *
  INTO v_namespace
  FROM puls_integration.source_namespaces sn
  WHERE sn.id = v_change_set.source_namespace_id
    AND sn.tenant_id = v_change_set.tenant_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_NAMESPACE_REQUIRED: source namespace is missing.';
  END IF;

  SELECT COUNT(*)::INTEGER
  INTO v_existing_event_count
  FROM puls_integration.connector_apply_object_events event
  WHERE event.change_set_id = v_change_set.id;

  IF v_existing_event_count > 0 THEN
    IF EXISTS (
      SELECT 1
      FROM puls_integration.connector_apply_object_events event
      WHERE event.change_set_id = v_change_set.id
        AND event.connector_job_id IS DISTINCT FROM v_job.id
    ) THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_ALREADY_APPLIED: change-set was applied by another job.';
    END IF;

    SELECT COUNT(*)::INTEGER
    INTO v_field_diff_count
    FROM puls_integration.connector_apply_field_diffs diff
    WHERE diff.change_set_id = v_change_set.id;

    SELECT COUNT(*)::INTEGER
    INTO v_snapshot_count
    FROM puls_integration.connector_apply_rollback_snapshots snap
    WHERE snap.change_set_id = v_change_set.id
      AND snap.snapshot_state = 'available';

    RETURN QUERY
    SELECT
      v_change_set.id,
      v_change_set.import_batch_id,
      'applied_guarded_update'::TEXT,
      v_change_set.row_count,
      v_change_set.update_count,
      v_field_diff_count,
      v_snapshot_count,
      v_existing_event_count,
      TRUE,
      TRUE,
      FALSE,
      FALSE,
      'review_guarded_update_object_events'::TEXT;
    RETURN;
  END IF;

  PERFORM puls_integration._connector_apply_validate_guarded_update_change_set(v_change_set_id);

  IF v_batch.status = 'applied'::puls_integration.import_batch_status THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_BATCH_ALREADY_APPLIED: batch is already applied.';
  END IF;

  SELECT COUNT(*)::INTEGER
  INTO v_field_diff_count
  FROM puls_integration.connector_apply_field_diffs diff
  WHERE diff.change_set_id = v_change_set.id;

  SELECT COUNT(*)::INTEGER
  INTO v_snapshot_count
  FROM puls_integration.connector_apply_rollback_snapshots snap
  WHERE snap.change_set_id = v_change_set.id
    AND snap.snapshot_state = 'available';

  PERFORM set_config('puls.import_apply.active', 'true', true);

  FOR v_item IN
    SELECT csi.*
    FROM puls_integration.connector_apply_change_set_items csi
    WHERE csi.change_set_id = v_change_set.id
    ORDER BY CASE csi.entity_type
      WHEN 'legal_entity'::puls_integration.import_entity_type THEN 10
      WHEN 'location'::puls_integration.import_entity_type THEN 20
      WHEN 'cost_center'::puls_integration.import_entity_type THEN 30
      WHEN 'department'::puls_integration.import_entity_type THEN 40
      WHEN 'position'::puls_integration.import_entity_type THEN 50
      ELSE 100
    END,
    csi.row_number
  LOOP
    SELECT *
    INTO v_record
    FROM puls_integration.import_records ir
    WHERE ir.id = v_item.import_record_id
      AND ir.batch_id = v_change_set.import_batch_id
      AND ir.status = 'validated'::puls_integration.import_record_status
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_RECORD_INVALID: row % is not validated.', v_item.row_number;
    END IF;

    v_canonical_id := puls_integration._connector_apply_update_reference_name(
      v_batch,
      v_namespace,
      v_item,
      v_record
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
      v_change_set.tenant_id,
      v_change_set.connection_id,
      v_change_set.source_namespace_id,
      v_change_set.import_batch_id,
      v_change_set.id,
      v_item.id,
      v_item.import_record_id,
      v_job.id,
      'update'::puls_integration.connector_apply_operation,
      v_item.entity_type,
      v_item.external_id,
      v_item.target_table,
      v_canonical_id,
      v_item.source_row_hash,
      v_change_set.change_set_checksum,
      ARRAY[
        'object_event'::puls_integration.connector_apply_audit_tier,
        'field_diff'::puls_integration.connector_apply_audit_tier,
        'rollback_snapshot'::puls_integration.connector_apply_audit_tier
      ],
      'object_event',
      jsonb_build_object(
        'contract_version', 'pr16.4.2-guarded-update-worker-apply-v1',
        'change_set_id', v_change_set.id,
        'import_batch_id', v_change_set.import_batch_id,
        'row_number', v_item.row_number,
        'entity_type', v_item.entity_type,
        'target_table', v_item.target_table,
        'operation', 'update',
        'safe_field_names', ARRAY['name']::TEXT[],
        'destructive_field_names', '{}'::TEXT[],
        'field_diff_count', (
          SELECT COUNT(*)::INTEGER
          FROM puls_integration.connector_apply_field_diffs diff
          WHERE diff.change_set_item_id = v_item.id
        ),
        'rollback_snapshot_required', TRUE,
        'canonical_write', TRUE,
        'source_writeback', FALSE,
        'credential_readback', FALSE,
        'provider_api_calls', FALSE,
        'raw_payload_readback', FALSE,
        'field_value_readback', FALSE,
        'rollback_execution', FALSE
      ),
      v_worker_id
    );

    v_update_count := v_update_count + 1;
  END LOOP;

  IF v_update_count <> v_change_set.update_count THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_COUNT_MISMATCH: updated record count does not match change-set.';
  END IF;

  UPDATE puls_integration.import_batches ib
  SET
    status = 'applied'::puls_integration.import_batch_status,
    applied_at = NOW(),
    applied_by_employee_id = v_job.created_by_employee_id,
    create_count = 0,
    update_count = v_update_count,
    skip_count = 0,
    updated_at = NOW()
  WHERE ib.id = v_change_set.import_batch_id;

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
    v_change_set.tenant_id,
    v_change_set.connection_id,
    'import_apply_execution',
    'success'::puls_integration.sync_status,
    v_job.started_at,
    NOW(),
    v_change_set.row_count,
    0,
    v_update_count,
    0,
    0,
    'import_apply_guarded_update_completed',
    v_job.created_by_employee_id,
    NULL,
    jsonb_build_object(
      'contract_version', 'pr16.4.2-guarded-update-worker-apply-v1',
      'change_set_id', v_change_set.id,
      'import_batch_id', v_change_set.import_batch_id,
      'row_count', v_change_set.row_count,
      'update_count', v_update_count,
      'field_diff_count', v_field_diff_count,
      'rollback_snapshot_count', v_snapshot_count,
      'object_event_count', v_update_count,
      'execution_enabled', TRUE,
      'canonical_write_enabled', TRUE,
      'source_writeback_enabled', FALSE,
      'credential_readback_enabled', FALSE,
      'provider_api_calls', FALSE,
      'raw_payload_readback', FALSE,
      'field_value_readback', FALSE,
      'rollback_execution', FALSE
    ),
    'review_guarded_update_object_events'
  );

  RETURN QUERY
  SELECT
    v_change_set.id,
    v_change_set.import_batch_id,
    'applied_guarded_update'::TEXT,
    v_change_set.row_count,
    v_update_count,
    v_field_diff_count,
    v_snapshot_count,
    v_update_count,
    TRUE,
    TRUE,
    FALSE,
    FALSE,
    'review_guarded_update_object_events'::TEXT;
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
    'pr16.4.2-guarded-update-worker-apply-v1'::TEXT AS contract_version,
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
    'guarded_update_worker_apply_open'::TEXT AS safe_error_code,
    'enqueue_guarded_update_apply_after_review'::TEXT AS next_action_key
  FROM puls_integration.erp_connections c
  WHERE (v_auth_role = 'service_role' OR c.tenant_id = v_tenant_id)
    AND (p_connection_id IS NULL OR c.id = p_connection_id)
  ORDER BY c.updated_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION puls_integration._connector_apply_validate_guarded_update_change_set(UUID)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration._connector_apply_validate_guarded_update_change_set(UUID)
  TO service_role;

REVOKE ALL ON FUNCTION puls_integration.enqueue_connector_guarded_update_apply_job(UUID)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.enqueue_connector_guarded_update_apply_job(UUID)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_integration._connector_apply_update_reference_name(
  puls_integration.import_batches,
  puls_integration.source_namespaces,
  puls_integration.connector_apply_change_set_items,
  puls_integration.import_records
) FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration._connector_apply_update_reference_name(
  puls_integration.import_batches,
  puls_integration.source_namespaces,
  puls_integration.connector_apply_change_set_items,
  puls_integration.import_records
) TO service_role;

REVOKE ALL ON FUNCTION puls_integration.execute_connector_guarded_update_apply_job(UUID, TEXT)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.execute_connector_guarded_update_apply_job(UUID, TEXT)
  TO service_role;

COMMENT ON FUNCTION puls_integration.enqueue_connector_guarded_update_apply_job(UUID) IS
  'Admin-safe enqueue RPC for PR16.4.2 guarded update worker apply. It queues but does not directly write canonical data.';

COMMENT ON FUNCTION puls_integration.execute_connector_guarded_update_apply_job(UUID, TEXT) IS
  'Service-role worker execution RPC for PR16.4.2 guarded reference name updates. It revalidates approval, evidence, hashes, and lease ownership immediately before writing.';

COMMENT ON FUNCTION puls_integration._connector_apply_validate_guarded_update_change_set(UUID) IS
  'PR16.4.2 guarded update apply validator. Requires admin approval, PR16.4.1 evidence, no stale/destructive/source conflict blockers, and safe name-only reference updates.';
