-- PR16.10.8 package extension for CSV/Excel import.
-- This keeps already-applied local/remote PR16.10.8 databases aligned with the
-- multi-file HR import package contract without opening canonical writes.

ALTER TABLE puls_integration.import_file_manifests
  ADD COLUMN IF NOT EXISTS package_id UUID NULL;

CREATE INDEX IF NOT EXISTS import_file_manifests_package_idx
  ON puls_integration.import_file_manifests (tenant_id, connection_id, package_id, created_at DESC)
  WHERE package_id IS NOT NULL;

CREATE OR REPLACE FUNCTION puls_integration.ingest_file_import_package(
  p_connection_id UUID,
  p_package JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_package_id UUID;
  v_items JSONB;
  v_item JSONB;
  v_scope_key TEXT;
  v_seen_scopes TEXT[] := '{}'::TEXT[];
  v_manifest JSONB;
  v_rows JSONB;
  v_result JSONB;
  v_results JSONB := '[]'::JSONB;
  v_file_count INTEGER;
  v_total_rows INTEGER := 0;
  v_manifest_id UUID;
  v_batch_id UUID;
BEGIN
  IF p_package IS NULL OR jsonb_typeof(p_package) <> 'object' THEN
    RAISE EXCEPTION 'PULS_FILE_IMPORT_PACKAGE_INVALID: package must be a JSON object.';
  END IF;

  v_items := p_package -> 'items';
  IF v_items IS NULL OR jsonb_typeof(v_items) <> 'array' THEN
    RAISE EXCEPTION 'PULS_FILE_IMPORT_PACKAGE_ITEMS_INVALID: package items must be an array.';
  END IF;

  v_file_count := jsonb_array_length(v_items);
  IF v_file_count <= 0 OR v_file_count > 6 THEN
    RAISE EXCEPTION 'PULS_FILE_IMPORT_PACKAGE_FILE_COUNT_INVALID: package must contain between 1 and 6 files.';
  END IF;

  v_package_id := COALESCE(
    NULLIF(btrim(COALESCE(p_package ->> 'package_id', '')), '')::UUID,
    gen_random_uuid()
  );

  FOR v_item IN
    SELECT value
    FROM jsonb_array_elements(v_items)
  LOOP
    IF jsonb_typeof(v_item) <> 'object' THEN
      RAISE EXCEPTION 'PULS_FILE_IMPORT_PACKAGE_ITEM_INVALID: each package item must be an object.';
    END IF;

    v_scope_key := lower(btrim(COALESCE(v_item ->> 'scope', '')));
    IF v_scope_key = '' THEN
      RAISE EXCEPTION 'PULS_FILE_IMPORT_PACKAGE_SCOPE_REQUIRED: each package item requires a scope.';
    END IF;

    IF v_scope_key = ANY(v_seen_scopes) THEN
      RAISE EXCEPTION 'PULS_FILE_IMPORT_PACKAGE_DUPLICATE_SCOPE: a package cannot contain the same scope twice.';
    END IF;
    v_seen_scopes := array_append(v_seen_scopes, v_scope_key);

    v_manifest := v_item -> 'manifest';
    v_rows := v_item -> 'rows';
    IF v_manifest IS NULL OR jsonb_typeof(v_manifest) <> 'object' THEN
      RAISE EXCEPTION 'PULS_FILE_IMPORT_PACKAGE_MANIFEST_INVALID: each package item requires a manifest object.';
    END IF;

    v_manifest := v_manifest || jsonb_build_object('package_id', v_package_id);

    SELECT puls_integration.ingest_file_import_batch(
      p_connection_id,
      v_scope_key,
      v_manifest,
      v_rows
    )
    INTO v_result;

    v_manifest_id := (v_result ->> 'manifest_id')::UUID;
    v_batch_id := (v_result ->> 'import_batch_id')::UUID;

    UPDATE puls_integration.import_file_manifests manifest
    SET
      package_id = v_package_id,
      safe_summary = jsonb_strip_nulls(
        manifest.safe_summary || jsonb_build_object('package_id', v_package_id)
      )
    WHERE manifest.id = v_manifest_id;

    UPDATE puls_integration.erp_sync_batches batch
    SET safe_error_context = jsonb_strip_nulls(
      batch.safe_error_context || jsonb_build_object('package_id', v_package_id)
    )
    WHERE batch.connection_id = p_connection_id
      AND batch.safe_error_context ->> 'import_batch_id' = v_batch_id::TEXT;

    v_result := v_result || jsonb_build_object('package_id', v_package_id);
    v_results := v_results || jsonb_build_array(v_result);
    v_total_rows := v_total_rows + COALESCE((v_result ->> 'row_count')::INTEGER, 0);
  END LOOP;

  RETURN jsonb_build_object(
    'contract_version', 'pr16.10.8-file-import-package-v1',
    'package_id', v_package_id,
    'connection_id', p_connection_id,
    'file_count', v_file_count,
    'row_count', v_total_rows,
    'mode', 'dry_run',
    'status', 'uploaded',
    'next_action_key', 'run_file_import_preview',
    'items', v_results,
    'source_writeback', FALSE,
    'provider_api_calls', FALSE,
    'canonical_write', FALSE,
    'raw_payload_readback', FALSE,
    'credential_readback', FALSE
  );
END;
$$;

CREATE OR REPLACE FUNCTION puls_app.refresh_file_import_app_notifications(
  p_limit INTEGER DEFAULT 100,
  p_tenant_id UUID DEFAULT NULL
)
RETURNS TABLE (
  source_event_key TEXT,
  source_table TEXT,
  source_id UUID,
  notification_id UUID,
  inserted BOOLEAN,
  severity TEXT,
  priority INTEGER,
  dedupe_key TEXT,
  action_key TEXT,
  safe_summary JSONB,
  occurred_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_app, puls_integration, puls_core
AS $$
DECLARE
  v_auth_role TEXT := COALESCE(auth.role(), '');
  v_limit INTEGER := LEAST(GREATEST(COALESCE(p_limit, 100), 1), 500);
  v_candidate RECORD;
  v_emit RECORD;
BEGIN
  IF v_auth_role <> 'service_role' THEN
    RAISE EXCEPTION
      'PULS_APP_FILE_IMPORT_NOTIFICATION_REFRESH_SERVICE_ROLE_REQUIRED: file import notification refresh requires service_role.'
      USING ERRCODE = 'P0001';
  END IF;

  IF p_tenant_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM puls_core.tenants tenant WHERE tenant.id = p_tenant_id) THEN
    RAISE EXCEPTION
      'PULS_APP_FILE_IMPORT_NOTIFICATION_TENANT_NOT_FOUND: tenant was not found.'
      USING ERRCODE = 'P0001';
  END IF;

  FOR v_candidate IN
    SELECT
      'file_import_uploaded'::TEXT AS source_event_key,
      'puls_integration.import_file_manifests'::TEXT AS source_table,
      manifest.id AS source_id,
      manifest.tenant_id,
      manifest.connection_id,
      manifest.source_namespace_id,
      manifest.import_batch_id,
      manifest.package_id,
      manifest.scope_key,
      manifest.file_name,
      manifest.file_extension,
      manifest.row_count,
      manifest.business_date,
      'success'::TEXT AS severity,
      64 AS priority,
      ARRAY['hr_admin', 'admin', 'superadmin']::TEXT[] AS target_roles,
      'file_import_manifest'::TEXT AS subject_type,
      manifest.id AS subject_id,
      'notifications.connectorRuntime.fileImportUploaded.title'::TEXT AS title_key,
      'notifications.connectorRuntime.fileImportUploaded.body'::TEXT AS body_key,
      'connector_runtime.file_import'::TEXT AS route_hint,
      'run_file_import_preview'::TEXT AS action_key,
      concat_ws(
        ':',
        'pr16.10.8-file-import-notification-v1',
        'connector_runtime',
        'file_import_uploaded',
        manifest.id::TEXT,
        manifest.file_checksum
      ) AS dedupe_key,
      jsonb_build_object(
        'contract_version', 'pr16.10.8-file-import-notification-v1',
        'source_domain', 'connector_runtime',
        'source_event_key', 'file_import_uploaded',
        'source_table', 'puls_integration.import_file_manifests',
        'import_file_manifest_id', manifest.id,
        'package_id', manifest.package_id,
        'connection_id', manifest.connection_id,
        'source_namespace_id', manifest.source_namespace_id,
        'import_batch_id', manifest.import_batch_id,
        'scope_key', manifest.scope_key,
        'file_name', manifest.file_name,
        'file_extension', manifest.file_extension,
        'row_count', manifest.row_count,
        'business_date', to_char(manifest.business_date, 'YYYY-MM-DD'),
        'next_action_key', 'run_file_import_preview',
        'canonical_write', FALSE,
        'source_writeback', FALSE,
        'provider_api_calls', FALSE,
        'credential_readback', FALSE,
        'raw_payload_readback', FALSE,
        'field_value_readback', FALSE,
        'snapshot_payload_readback', FALSE,
        'external_delivery_enabled', FALSE,
        'notification_realtime_enabled', FALSE
      ) AS safe_summary,
      manifest.created_at AS occurred_at
    FROM puls_integration.import_file_manifests manifest
    WHERE p_tenant_id IS NULL OR manifest.tenant_id = p_tenant_id
    ORDER BY manifest.created_at DESC, manifest.id DESC
    LIMIT v_limit
  LOOP
    SELECT emitted.*
    INTO v_emit
    FROM puls_app.emit_app_notification(
      p_tenant_id := v_candidate.tenant_id,
      p_source_domain := 'connector_runtime',
      p_source_event_key := v_candidate.source_event_key,
      p_title_key := v_candidate.title_key,
      p_source_table := v_candidate.source_table,
      p_source_id := v_candidate.source_id,
      p_severity := v_candidate.severity,
      p_priority := v_candidate.priority,
      p_target_roles := v_candidate.target_roles,
      p_target_employee_ids := '{}'::UUID[],
      p_subject_type := v_candidate.subject_type,
      p_subject_id := v_candidate.subject_id,
      p_body_key := v_candidate.body_key,
      p_route_hint := v_candidate.route_hint,
      p_action_key := v_candidate.action_key,
      p_dedupe_key := v_candidate.dedupe_key,
      p_safe_summary := v_candidate.safe_summary,
      p_occurred_at := v_candidate.occurred_at,
      p_expires_at := v_candidate.occurred_at + INTERVAL '180 days'
    ) emitted;

    source_event_key := v_candidate.source_event_key;
    source_table := v_candidate.source_table;
    source_id := v_candidate.source_id;
    notification_id := v_emit.notification_id;
    inserted := v_emit.inserted;
    severity := v_emit.severity;
    priority := v_emit.priority;
    dedupe_key := v_emit.dedupe_key;
    action_key := v_candidate.action_key;
    safe_summary := v_emit.safe_summary;
    occurred_at := v_emit.occurred_at;
    RETURN NEXT;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION puls_app.run_app_notification_producers(
  p_limit INTEGER DEFAULT 500,
  p_tenant_id UUID DEFAULT NULL
)
RETURNS TABLE (
  producer_key TEXT,
  source_event_key TEXT,
  source_table TEXT,
  source_id UUID,
  notification_id UUID,
  inserted BOOLEAN,
  severity TEXT,
  priority INTEGER,
  dedupe_key TEXT,
  action_key TEXT,
  safe_summary JSONB,
  occurred_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_app, puls_core
AS $$
DECLARE
  v_auth_role TEXT := COALESCE(auth.role(), '');
  v_limit INTEGER := LEAST(GREATEST(COALESCE(p_limit, 500), 1), 500);
BEGIN
  IF v_auth_role <> 'service_role' THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_PRODUCER_SERVICE_ROLE_REQUIRED: notification producers require service_role.'
      USING ERRCODE = 'P0001';
  END IF;

  RETURN QUERY
  SELECT
    'connector_runtime'::TEXT AS producer_key,
    refreshed.source_event_key,
    refreshed.source_table,
    refreshed.source_id,
    refreshed.notification_id,
    refreshed.inserted,
    refreshed.severity,
    refreshed.priority,
    refreshed.dedupe_key,
    refreshed.action_key,
    refreshed.safe_summary,
    refreshed.occurred_at
  FROM puls_app.refresh_connector_app_notifications(
    v_limit,
    p_tenant_id,
    NULL
  ) refreshed
  UNION ALL
  SELECT
    'file_import'::TEXT AS producer_key,
    refreshed.source_event_key,
    refreshed.source_table,
    refreshed.source_id,
    refreshed.notification_id,
    refreshed.inserted,
    refreshed.severity,
    refreshed.priority,
    refreshed.dedupe_key,
    refreshed.action_key,
    refreshed.safe_summary,
    refreshed.occurred_at
  FROM puls_app.refresh_file_import_app_notifications(
    v_limit,
    p_tenant_id
  ) refreshed;
END;
$$;

REVOKE ALL ON FUNCTION puls_integration.ingest_file_import_package(UUID, JSONB)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION puls_integration.ingest_file_import_package(UUID, JSONB)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_app.refresh_file_import_app_notifications(INTEGER, UUID)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_app.refresh_file_import_app_notifications(INTEGER, UUID)
  TO service_role;

REVOKE ALL ON FUNCTION puls_app.run_app_notification_producers(INTEGER, UUID)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_app.run_app_notification_producers(INTEGER, UUID)
  TO service_role;

COMMENT ON FUNCTION puls_integration.ingest_file_import_package(UUID, JSONB) IS
  'Atomically stages a multi-file CSV/Excel dry-run package. If one file fails, the package rolls back.';
COMMENT ON FUNCTION puls_app.refresh_file_import_app_notifications(INTEGER, UUID) IS
  'Service-role file import notification producer. Emits one idempotent user-friendly Notification Center item per staged file manifest.';
