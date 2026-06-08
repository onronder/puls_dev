-- PR16.10.10 DataSource Manager operational hardening.
-- Keeps the product flow unchanged while tightening file package ordering and
-- credential reference validation.

CREATE OR REPLACE FUNCTION puls_integration.connector_credential_reference_is_safe(
  p_credentials_ref TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
SET search_path = pg_catalog
AS $$
DECLARE
  v_ref TEXT := p_credentials_ref;
  v_trimmed TEXT;
  v_lower TEXT;
  v_scheme_separator INTEGER;
  v_scheme TEXT;
  v_path TEXT;
  v_char TEXT;
BEGIN
  IF v_ref IS NULL THEN
    RETURN FALSE;
  END IF;

  v_trimmed := pg_catalog.btrim(v_ref);
  IF v_trimmed IS DISTINCT FROM v_ref THEN
    RETURN FALSE;
  END IF;

  IF pg_catalog.length(v_ref) < 24 OR pg_catalog.length(v_ref) > 280 THEN
    RETURN FALSE;
  END IF;

  v_lower := pg_catalog.lower(v_ref);
  v_scheme_separator := pg_catalog.strpos(v_lower, '://');
  IF v_scheme_separator <= 1 THEN
    RETURN FALSE;
  END IF;

  v_scheme := pg_catalog.substr(v_lower, 1, v_scheme_separator - 1);
  IF v_scheme NOT IN ('pulsref', 'vaultref', 'supavault', 'awsref', 'gcpref', 'azureref') THEN
    RETURN FALSE;
  END IF;

  v_path := pg_catalog.substr(v_lower, v_scheme_separator + 3);
  IF pg_catalog.length(v_path) = 0 THEN
    RETURN FALSE;
  END IF;

  IF pg_catalog.strpos('abcdefghijklmnopqrstuvwxyz0123456789', pg_catalog.substr(v_path, 1, 1)) = 0 THEN
    RETURN FALSE;
  END IF;

  FOR v_index IN 1..pg_catalog.length(v_path) LOOP
    v_char := pg_catalog.substr(v_path, v_index, 1);
    IF pg_catalog.strpos('abcdefghijklmnopqrstuvwxyz0123456789._~:/-', v_char) = 0 THEN
      RETURN FALSE;
    END IF;
  END LOOP;

  RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration.file_import_scope_rank(
  p_scope_key TEXT
)
RETURNS INTEGER
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog
AS $$
  SELECT CASE pg_catalog.lower(pg_catalog.btrim(COALESCE(p_scope_key, '')))
    WHEN 'legal_entities' THEN 1
    WHEN 'locations' THEN 2
    WHEN 'cost_centers' THEN 3
    WHEN 'departments' THEN 4
    WHEN 'positions' THEN 5
    WHEN 'employees' THEN 6
    ELSE NULL
  END
$$;

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
  v_scope_rank INTEGER;
  v_previous_scope_rank INTEGER := 0;
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

  -- Validate the complete package before staging any file rows.
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

    v_scope_rank := puls_integration.file_import_scope_rank(v_scope_key);
    IF v_scope_rank IS NULL THEN
      RAISE EXCEPTION 'PULS_FILE_IMPORT_PACKAGE_SCOPE_UNSUPPORTED: scope % is not supported.', v_scope_key;
    END IF;

    IF v_scope_rank <= v_previous_scope_rank THEN
      RAISE EXCEPTION 'PULS_FILE_IMPORT_PACKAGE_SCOPE_ORDER_INVALID: package scopes must follow canonical dependency order.';
    END IF;

    v_seen_scopes := array_append(v_seen_scopes, v_scope_key);
    v_previous_scope_rank := v_scope_rank;

    v_manifest := v_item -> 'manifest';
    v_rows := v_item -> 'rows';
    IF v_manifest IS NULL OR jsonb_typeof(v_manifest) <> 'object' THEN
      RAISE EXCEPTION 'PULS_FILE_IMPORT_PACKAGE_MANIFEST_INVALID: each package item requires a manifest object.';
    END IF;

    IF v_rows IS NULL OR jsonb_typeof(v_rows) <> 'array' THEN
      RAISE EXCEPTION 'PULS_FILE_IMPORT_PACKAGE_ROWS_INVALID: each package item requires rows as an array.';
    END IF;
  END LOOP;

  FOR v_item IN
    SELECT value
    FROM jsonb_array_elements(v_items)
  LOOP
    v_scope_key := lower(btrim(COALESCE(v_item ->> 'scope', '')));
    v_manifest := v_item -> 'manifest';
    v_rows := v_item -> 'rows';
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
    'contract_version', 'pr16.10.10-file-import-package-hardening-v1',
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

REVOKE ALL ON FUNCTION puls_integration.ingest_file_import_package(UUID, JSONB)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION puls_integration.ingest_file_import_package(UUID, JSONB)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_integration.file_import_scope_rank(TEXT)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION puls_integration.file_import_scope_rank(TEXT)
  TO service_role;

COMMENT ON FUNCTION puls_integration.connector_credential_reference_is_safe(TEXT) IS
  'PR16.10.10 credential reference validator. Uses deterministic scheme/path parsing without regex operator dependency.';
COMMENT ON FUNCTION puls_integration.file_import_scope_rank(TEXT) IS
  'PR16.10.10 canonical dependency rank for CSV/Excel HR import package scopes.';
COMMENT ON FUNCTION puls_integration.ingest_file_import_package(UUID, JSONB) IS
  'PR16.10.10 hardened multi-file CSV/Excel import package ingest. Enforces canonical scope order and keeps dry-run/no-write boundaries.';
