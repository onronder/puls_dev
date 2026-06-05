-- PR16.3 follow-up: treat a NULL auth.role() as non-service-role.
-- Supabase SQL editor can run with request JWT role unset; PL/pgSQL IF conditions
-- must not let NULL comparisons skip authenticated/service_role boundaries.

CREATE OR REPLACE FUNCTION puls_integration.enqueue_connector_create_only_apply_job(
  p_change_set_id UUID
)
RETURNS TABLE (
  job_id UUID,
  status puls_integration.connector_job_status,
  change_set_id UUID,
  import_batch_id UUID,
  create_count INTEGER,
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
BEGIN
  IF NOT v_is_service_role AND NOT COALESCE(puls_core.is_admin(), FALSE) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_ADMIN_REQUIRED: admin permission is required.';
  END IF;

  IF NOT v_is_service_role AND v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_TENANT_REQUIRED: authenticated caller has no tenant context.';
  END IF;

  PERFORM puls_integration._connector_apply_validate_create_only_change_set(p_change_set_id);

  SELECT *
  INTO v_change_set
  FROM puls_integration.connector_apply_change_sets cs
  WHERE cs.id = p_change_set_id;

  IF NOT v_is_service_role AND v_change_set.tenant_id IS DISTINCT FROM v_tenant_id THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_FORBIDDEN: change-set belongs to another tenant.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM puls_integration.connector_apply_object_events event
    WHERE event.change_set_id = p_change_set_id
  ) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_ALREADY_APPLIED: change-set already has object events.';
  END IF;

  v_job_id := puls_integration.enqueue_connector_job(
    'import_apply'::puls_integration.connector_job_type,
    concat_ws(
      ':',
      'pr16.3-create-only-apply',
      v_change_set.id::TEXT,
      v_change_set.change_set_checksum
    ),
    v_change_set.connection_id,
    v_change_set.source_namespace_id,
    v_change_set.import_batch_id,
    'import_apply_create_only',
    40,
    NOW(),
    1,
    jsonb_build_object(
      'contract_version', 'pr16.3-create-only-worker-apply-v1',
      'apply_mode', 'create_only',
      'change_set_id', v_change_set.id,
      'change_set_checksum', v_change_set.change_set_checksum,
      'row_count', v_change_set.row_count,
      'create_count', v_change_set.create_count,
      'execution_enabled', TRUE,
      'canonical_write_enabled', TRUE,
      'source_writeback_enabled', FALSE,
      'credential_readback_enabled', FALSE,
      'provider_api_calls', FALSE,
      'raw_payload_readback', FALSE,
      'field_value_readback', FALSE,
      'allowed_entity_scope', 'reference_dimensions'
    ),
    'wait_for_create_only_worker_apply',
    CASE WHEN v_is_service_role THEN v_change_set.tenant_id ELSE NULL END
  );

  RETURN QUERY
  SELECT
    cj.id,
    cj.status,
    v_change_set.id,
    v_change_set.import_batch_id,
    v_change_set.create_count,
    COALESCE(cj.next_action_key, 'wait_for_create_only_worker_apply')::TEXT
  FROM puls_integration.connector_jobs cj
  WHERE cj.id = v_job_id;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration.execute_connector_create_only_apply_job(
  p_job_id UUID,
  p_worker_id TEXT
)
RETURNS TABLE (
  change_set_id UUID,
  import_batch_id UUID,
  status TEXT,
  row_count INTEGER,
  create_count INTEGER,
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
  v_item RECORD;
  v_record puls_integration.import_records;
  v_canonical_id UUID;
  v_create_count INTEGER := 0;
  v_existing_event_count INTEGER := 0;
BEGIN
  IF v_auth_role <> 'service_role' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_WORKER_ONLY: create-only apply execution requires service_role.';
  END IF;

  IF v_worker_id = '' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_WORKER_REQUIRED: worker id is required.';
  END IF;

  SELECT *
  INTO v_job
  FROM puls_integration.connector_jobs cj
  WHERE cj.id = p_job_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_JOB_NOT_FOUND: connector job not found.';
  END IF;

  IF v_job.job_type <> 'import_apply'::puls_integration.connector_job_type THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_JOB_TYPE_INVALID: job type must be import_apply.';
  END IF;

  IF v_job.status <> 'running'::puls_integration.connector_job_status
     OR v_job.locked_by IS DISTINCT FROM v_worker_id THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_JOB_LEASE_INVALID: worker does not own this running job.';
  END IF;

  IF v_job.safe_error_context ->> 'contract_version' IS DISTINCT FROM 'pr16.3-create-only-worker-apply-v1'
     OR v_job.safe_error_context ->> 'apply_mode' IS DISTINCT FROM 'create_only' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_JOB_CONTEXT_INVALID: job is not a PR16.3 create-only apply job.';
  END IF;

  v_change_set_id := (v_job.safe_error_context ->> 'change_set_id')::UUID;

  SELECT *
  INTO v_change_set
  FROM puls_integration.connector_apply_change_sets cs
  WHERE cs.id = v_change_set_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_CHANGE_SET_NOT_FOUND: change-set not found.';
  END IF;

  IF v_change_set.tenant_id IS DISTINCT FROM v_job.tenant_id
     OR v_change_set.connection_id IS DISTINCT FROM v_job.connection_id
     OR v_change_set.source_namespace_id IS DISTINCT FROM v_job.source_namespace_id
     OR v_change_set.import_batch_id IS DISTINCT FROM v_job.import_batch_id THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_JOB_CONTEXT_MISMATCH: job context does not match change-set.';
  END IF;

  v_batch := puls_integration._import_lock_batch(v_change_set.import_batch_id);

  SELECT *
  INTO v_namespace
  FROM puls_integration.source_namespaces sn
  WHERE sn.id = v_change_set.source_namespace_id
    AND sn.tenant_id = v_change_set.tenant_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_NAMESPACE_REQUIRED: source namespace is missing.';
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
      RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_ALREADY_APPLIED: change-set was applied by another job.';
    END IF;

    RETURN QUERY
    SELECT
      v_change_set.id,
      v_change_set.import_batch_id,
      'applied_create_only'::TEXT,
      v_change_set.row_count,
      v_change_set.create_count,
      v_existing_event_count,
      TRUE,
      TRUE,
      FALSE,
      FALSE,
      'review_created_canonical_records'::TEXT;
    RETURN;
  END IF;

  PERFORM puls_integration._connector_apply_validate_create_only_change_set(v_change_set_id);

  IF v_batch.status = 'applied'::puls_integration.import_batch_status THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_BATCH_ALREADY_APPLIED: batch is already applied.';
  END IF;

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
      RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_RECORD_INVALID: row % is not validated.', v_item.row_number;
    END IF;

    v_canonical_id := puls_integration._connector_apply_insert_reference_record(
      v_batch,
      v_namespace,
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
      'insert'::puls_integration.connector_apply_operation,
      v_item.entity_type,
      v_item.external_id,
      v_item.target_table,
      v_canonical_id,
      v_item.source_row_hash,
      v_change_set.change_set_checksum,
      ARRAY['object_event'::puls_integration.connector_apply_audit_tier],
      'object_event',
      jsonb_build_object(
        'contract_version', 'pr16.3-create-only-worker-apply-v1',
        'change_set_id', v_change_set.id,
        'import_batch_id', v_change_set.import_batch_id,
        'row_number', v_item.row_number,
        'entity_type', v_item.entity_type,
        'target_table', v_item.target_table,
        'operation', 'insert',
        'safe_field_names', v_item.safe_field_names,
        'destructive_field_names', v_item.destructive_field_names,
        'canonical_write', TRUE,
        'source_writeback', FALSE,
        'credential_readback', FALSE,
        'provider_api_calls', FALSE,
        'raw_payload_readback', FALSE,
        'field_value_readback', FALSE
      ),
      v_worker_id
    );

    v_create_count := v_create_count + 1;
  END LOOP;

  IF v_create_count <> v_change_set.create_count THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_CREATE_COUNT_MISMATCH: created record count does not match change-set.';
  END IF;

  UPDATE puls_integration.import_batches ib
  SET
    status = 'applied'::puls_integration.import_batch_status,
    applied_at = NOW(),
    applied_by_employee_id = v_job.created_by_employee_id,
    create_count = v_create_count,
    update_count = 0,
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
    v_create_count,
    0,
    0,
    0,
    'import_apply_create_only_completed',
    v_job.created_by_employee_id,
    NULL,
    jsonb_build_object(
      'contract_version', 'pr16.3-create-only-worker-apply-v1',
      'change_set_id', v_change_set.id,
      'import_batch_id', v_change_set.import_batch_id,
      'row_count', v_change_set.row_count,
      'create_count', v_create_count,
      'object_event_count', v_create_count,
      'execution_enabled', TRUE,
      'canonical_write_enabled', TRUE,
      'source_writeback_enabled', FALSE,
      'credential_readback_enabled', FALSE,
      'provider_api_calls', FALSE,
      'raw_payload_readback', FALSE,
      'field_value_readback', FALSE
    ),
    'review_created_canonical_records'
  );

  RETURN QUERY
  SELECT
    v_change_set.id,
    v_change_set.import_batch_id,
    'applied_create_only'::TEXT,
    v_change_set.row_count,
    v_create_count,
    v_create_count,
    TRUE,
    TRUE,
    FALSE,
    FALSE,
    'review_created_canonical_records'::TEXT;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration.list_connector_apply_object_events(
  p_change_set_id UUID DEFAULT NULL,
  p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
  id UUID,
  tenant_id UUID,
  connection_id UUID,
  source_namespace_id UUID,
  import_batch_id UUID,
  change_set_id UUID,
  import_record_id UUID,
  connector_job_id UUID,
  operation puls_integration.connector_apply_operation,
  entity_type puls_integration.import_entity_type,
  external_id TEXT,
  target_table TEXT,
  canonical_id UUID,
  source_row_hash TEXT,
  change_set_checksum TEXT,
  audit_tiers puls_integration.connector_apply_audit_tier[],
  retention_bucket TEXT,
  safe_summary JSONB,
  created_by_worker_id TEXT,
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
    event.id,
    event.tenant_id,
    event.connection_id,
    event.source_namespace_id,
    event.import_batch_id,
    event.change_set_id,
    event.import_record_id,
    event.connector_job_id,
    event.operation,
    event.entity_type,
    event.external_id,
    event.target_table,
    event.canonical_id,
    event.source_row_hash,
    event.change_set_checksum,
    event.audit_tiers,
    event.retention_bucket,
    event.safe_summary,
    event.created_by_worker_id,
    event.created_at
  FROM puls_integration.connector_apply_object_events event
  WHERE (v_auth_role = 'service_role' OR event.tenant_id = v_tenant_id)
    AND (p_change_set_id IS NULL OR event.change_set_id = p_change_set_id)
  ORDER BY event.created_at DESC, event.id DESC
  LIMIT v_limit;
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
    'pr16.3-create-only-worker-apply-v1'::TEXT AS contract_version,
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
    'create_only_worker_apply_open'::TEXT AS safe_error_code,
    'enqueue_create_only_apply_after_review'::TEXT AS next_action_key
  FROM puls_integration.erp_connections c
  WHERE (v_auth_role = 'service_role' OR c.tenant_id = v_tenant_id)
    AND (p_connection_id IS NULL OR c.id = p_connection_id)
  ORDER BY c.updated_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION puls_integration.enqueue_connector_create_only_apply_job(UUID)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.enqueue_connector_create_only_apply_job(UUID)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_integration.execute_connector_create_only_apply_job(UUID, TEXT)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.execute_connector_create_only_apply_job(UUID, TEXT)
  TO service_role;

REVOKE ALL ON FUNCTION puls_integration.list_connector_apply_object_events(UUID, INTEGER)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.list_connector_apply_object_events(UUID, INTEGER)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_integration.list_connector_apply_safety_contracts(UUID)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.list_connector_apply_safety_contracts(UUID)
  TO authenticated, service_role;

COMMENT ON FUNCTION puls_integration.enqueue_connector_create_only_apply_job(UUID) IS
  'PR16.3 create-only apply queue RPC. NULL auth.role is treated as non-service-role.';

COMMENT ON FUNCTION puls_integration.execute_connector_create_only_apply_job(UUID, TEXT) IS
  'PR16.3 worker-only create apply execution RPC. Requires service_role request context.';

COMMENT ON FUNCTION puls_integration.list_connector_apply_safety_contracts(UUID) IS
  'Lists PR16.3 apply safety contracts with null-safe service_role handling.';
