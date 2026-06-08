-- PR16.10.8 DataSource Manager CSV/Excel import contract.
-- Browser upload only stages a dry-run import batch. It never writes canonical HR data,
-- never calls a provider, and never stores raw payloads or credentials.

CREATE TABLE IF NOT EXISTS puls_integration.import_file_manifests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  connection_id UUID NOT NULL REFERENCES puls_integration.erp_connections(id) ON DELETE CASCADE,
  source_namespace_id UUID NOT NULL REFERENCES puls_integration.source_namespaces(id) ON DELETE RESTRICT,
  import_batch_id UUID NOT NULL UNIQUE REFERENCES puls_integration.import_batches(id) ON DELETE CASCADE,
  scope_key TEXT NOT NULL,
  template_version TEXT NOT NULL DEFAULT 'v1',
  file_name TEXT NOT NULL,
  file_extension TEXT NOT NULL,
  file_size_bytes INTEGER NOT NULL,
  file_checksum TEXT NOT NULL,
  business_date DATE NOT NULL,
  delimiter TEXT NULL,
  row_count INTEGER NOT NULL,
  uploaded_by_employee_id UUID NULL REFERENCES puls_core.employees(id) ON DELETE SET NULL,
  safe_summary JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT import_file_manifests_scope_check CHECK (
    scope_key IN ('employees', 'departments', 'positions', 'legal_entities', 'locations', 'cost_centers')
  ),
  CONSTRAINT import_file_manifests_extension_check CHECK (file_extension IN ('csv', 'xlsx')),
  CONSTRAINT import_file_manifests_size_check CHECK (file_size_bytes > 0),
  CONSTRAINT import_file_manifests_checksum_check CHECK (file_checksum ~ '^[0-9a-f]{64}$'),
  CONSTRAINT import_file_manifests_row_count_check CHECK (row_count > 0 AND row_count <= 5000),
  CONSTRAINT import_file_manifests_safe_summary_object CHECK (jsonb_typeof(safe_summary) = 'object'),
  CONSTRAINT import_file_manifests_safe_summary_clean CHECK (
    puls_integration.connector_safe_context_has_blocked_key(safe_summary) IS FALSE
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS import_file_manifests_checksum_unique_idx
  ON puls_integration.import_file_manifests (
    tenant_id,
    source_namespace_id,
    scope_key,
    file_checksum
  );

CREATE INDEX IF NOT EXISTS import_file_manifests_tenant_created_idx
  ON puls_integration.import_file_manifests (tenant_id, connection_id, created_at DESC);

CREATE INDEX IF NOT EXISTS import_file_manifests_business_day_idx
  ON puls_integration.import_file_manifests (
    tenant_id,
    source_namespace_id,
    scope_key,
    business_date
  );

DROP TRIGGER IF EXISTS import_file_manifests_set_updated_at
  ON puls_integration.import_file_manifests;
CREATE TRIGGER import_file_manifests_set_updated_at
  BEFORE UPDATE ON puls_integration.import_file_manifests
  FOR EACH ROW
  EXECUTE FUNCTION puls_core.set_updated_at();

CREATE OR REPLACE FUNCTION puls_integration.ingest_file_import_batch(
  p_connection_id UUID,
  p_scope_key TEXT,
  p_manifest JSONB,
  p_rows JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_connection puls_integration.erp_connections;
  v_tenant_id UUID;
  v_employee_id UUID;
  v_source_namespace_id UUID;
  v_namespace_code TEXT;
  v_scope_key TEXT := lower(btrim(COALESCE(p_scope_key, '')));
  v_expected_entity_type puls_integration.import_entity_type;
  v_file_name TEXT;
  v_file_extension TEXT;
  v_file_checksum TEXT;
  v_file_size_bytes INTEGER;
  v_template_version TEXT;
  v_business_date_text TEXT;
  v_business_date DATE;
  v_delimiter TEXT;
  v_row_count INTEGER;
  v_file_date_match TEXT[];
  v_batch_id UUID;
  v_manifest_id UUID;
  v_row JSONB;
  v_row_number INTEGER;
  v_row_entity_type TEXT;
  v_external_id TEXT;
  v_payload JSONB;
  v_blocked_keys TEXT[];
  v_blocked_key TEXT;
BEGIN
  IF NOT puls_integration.can_write_import_data() THEN
    RAISE EXCEPTION 'PULS_FILE_IMPORT_FORBIDDEN: admin permission is required.';
  END IF;

  IF p_manifest IS NULL OR jsonb_typeof(p_manifest) <> 'object' THEN
    RAISE EXCEPTION 'PULS_FILE_IMPORT_MANIFEST_INVALID: manifest must be a JSON object.';
  END IF;

  IF p_rows IS NULL OR jsonb_typeof(p_rows) <> 'array' THEN
    RAISE EXCEPTION 'PULS_FILE_IMPORT_ROWS_INVALID: rows must be a JSON array.';
  END IF;

  SELECT c.*
  INTO v_connection
  FROM puls_integration.erp_connections c
  WHERE c.id = p_connection_id;

  IF v_connection.id IS NULL THEN
    RAISE EXCEPTION 'PULS_FILE_IMPORT_CONNECTION_NOT_FOUND: data source was not found.';
  END IF;

  IF auth.role() = 'service_role' THEN
    v_tenant_id := v_connection.tenant_id;
  ELSE
    v_tenant_id := puls_core.current_tenant_id();
    IF v_tenant_id IS NULL OR v_tenant_id IS DISTINCT FROM v_connection.tenant_id THEN
      RAISE EXCEPTION 'PULS_FILE_IMPORT_CROSS_TENANT: data source belongs to another tenant.';
    END IF;
  END IF;

  IF v_connection.provider <> 'csv'::puls_integration.erp_provider
    AND v_connection.connection_method <> 'manual_import'::puls_integration.connection_method THEN
    RAISE EXCEPTION 'PULS_FILE_IMPORT_CONNECTION_UNSUPPORTED: data source is not a CSV/Excel source.';
  END IF;

  IF v_connection.setup_status IN (
    'disabled'::puls_integration.connector_setup_status,
    'archived'::puls_integration.connector_setup_status
  ) OR v_connection.is_enabled IS FALSE THEN
    RAISE EXCEPTION 'PULS_FILE_IMPORT_CONNECTION_DISABLED: data source is disabled or archived.';
  END IF;

  v_expected_entity_type := CASE v_scope_key
    WHEN 'employees' THEN 'employee'::puls_integration.import_entity_type
    WHEN 'departments' THEN 'department'::puls_integration.import_entity_type
    WHEN 'positions' THEN 'position'::puls_integration.import_entity_type
    WHEN 'legal_entities' THEN 'legal_entity'::puls_integration.import_entity_type
    WHEN 'locations' THEN 'location'::puls_integration.import_entity_type
    WHEN 'cost_centers' THEN 'cost_center'::puls_integration.import_entity_type
    ELSE NULL
  END;

  IF v_expected_entity_type IS NULL THEN
    RAISE EXCEPTION 'PULS_FILE_IMPORT_SCOPE_UNSUPPORTED: scope % is not supported.', v_scope_key;
  END IF;

  IF COALESCE(array_length(v_connection.owned_domains, 1), 0) > 0
    AND v_scope_key <> ALL(v_connection.owned_domains) THEN
    RAISE EXCEPTION 'PULS_FILE_IMPORT_SCOPE_NOT_OWNED: data source does not own scope %.', v_scope_key;
  END IF;

  v_file_name := btrim(COALESCE(p_manifest ->> 'file_name', ''));
  v_file_extension := lower(btrim(COALESCE(p_manifest ->> 'file_extension', '')));
  v_file_checksum := lower(btrim(COALESCE(p_manifest ->> 'file_checksum', '')));
  v_template_version := lower(btrim(COALESCE(p_manifest ->> 'template_version', '')));
  v_business_date_text := btrim(COALESCE(p_manifest ->> 'business_date', ''));
  v_delimiter := NULLIF(btrim(COALESCE(p_manifest ->> 'delimiter', '')), '');

  IF COALESCE(p_manifest ->> 'file_size_bytes', '') !~ '^[0-9]+$' THEN
    RAISE EXCEPTION 'PULS_FILE_IMPORT_SIZE_INVALID: file_size_bytes must be a positive integer.';
  END IF;
  v_file_size_bytes := (p_manifest ->> 'file_size_bytes')::INTEGER;

  IF COALESCE(p_manifest ->> 'row_count', '') !~ '^[0-9]+$' THEN
    RAISE EXCEPTION 'PULS_FILE_IMPORT_ROW_COUNT_INVALID: row_count must be a positive integer.';
  END IF;
  v_row_count := (p_manifest ->> 'row_count')::INTEGER;

  IF v_file_extension NOT IN ('csv', 'xlsx') THEN
    RAISE EXCEPTION 'PULS_FILE_IMPORT_EXTENSION_UNSUPPORTED: extension % is not supported.', v_file_extension;
  END IF;

  IF v_template_version <> 'v1' THEN
    RAISE EXCEPTION 'PULS_FILE_IMPORT_TEMPLATE_UNSUPPORTED: template version % is not supported.', v_template_version;
  END IF;

  IF v_file_checksum !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'PULS_FILE_IMPORT_CHECKSUM_INVALID: file checksum must be a SHA-256 hex digest.';
  END IF;

  IF (v_file_extension = 'csv' AND v_file_size_bytes > 5242880)
    OR (v_file_extension = 'xlsx' AND v_file_size_bytes > 10485760)
    OR v_file_size_bytes <= 0 THEN
    RAISE EXCEPTION 'PULS_FILE_IMPORT_SIZE_EXCEEDED: file size is outside the allowed range.';
  END IF;

  IF v_row_count <= 0 OR v_row_count > 5000 THEN
    RAISE EXCEPTION 'PULS_FILE_IMPORT_ROW_COUNT_EXCEEDED: row_count must be between 1 and 5000.';
  END IF;

  IF jsonb_array_length(p_rows) <> v_row_count THEN
    RAISE EXCEPTION 'PULS_FILE_IMPORT_ROW_COUNT_MISMATCH: manifest row_count does not match rows.';
  END IF;

  v_file_date_match := regexp_match(
    v_file_name,
    '^puls_' || v_scope_key || '_v1_([0-9]{8})\.(csv|xlsx)$'
  );
  IF v_file_date_match IS NULL OR v_file_date_match[2] <> v_file_extension THEN
    RAISE EXCEPTION 'PULS_FILE_IMPORT_FILE_NAME_INVALID: file name does not match the import contract.';
  END IF;

  IF v_business_date_text <> v_file_date_match[1] THEN
    RAISE EXCEPTION 'PULS_FILE_IMPORT_BUSINESS_DATE_MISMATCH: manifest date does not match file name.';
  END IF;

  v_business_date := to_date(v_file_date_match[1], 'YYYYMMDD');
  IF to_char(v_business_date, 'YYYYMMDD') <> v_file_date_match[1] THEN
    RAISE EXCEPTION 'PULS_FILE_IMPORT_BUSINESS_DATE_INVALID: file date is invalid.';
  END IF;

  IF v_file_extension = 'csv' AND v_delimiter IS NULL THEN
    RAISE EXCEPTION 'PULS_FILE_IMPORT_DELIMITER_REQUIRED: CSV delimiter must be detected before ingest.';
  END IF;

  IF v_file_extension = 'xlsx' AND v_delimiter IS NOT NULL THEN
    RAISE EXCEPTION 'PULS_FILE_IMPORT_DELIMITER_FORBIDDEN: XLSX imports must not carry a delimiter.';
  END IF;

  v_namespace_code := COALESCE(NULLIF(v_connection.connection_key, ''), 'csv-excel-' || left(v_connection.id::TEXT, 8));

  INSERT INTO puls_integration.source_namespaces (
    tenant_id,
    code,
    name,
    source_type,
    trust_level,
    priority_rank,
    is_active,
    connection_id
  )
  VALUES (
    v_tenant_id,
    v_namespace_code,
    v_connection.display_name,
    'excel_csv',
    'standard',
    100,
    TRUE,
    v_connection.id
  )
  ON CONFLICT (tenant_id, code) DO UPDATE
  SET
    name = EXCLUDED.name,
    source_type = EXCLUDED.source_type,
    trust_level = EXCLUDED.trust_level,
    is_active = TRUE,
    connection_id = EXCLUDED.connection_id,
    updated_at = NOW()
  RETURNING id INTO v_source_namespace_id;

  IF EXISTS (
    SELECT 1
    FROM puls_integration.import_file_manifests manifest
    WHERE manifest.tenant_id = v_tenant_id
      AND manifest.source_namespace_id = v_source_namespace_id
      AND manifest.scope_key = v_scope_key
      AND manifest.file_checksum = v_file_checksum
  ) THEN
    RAISE EXCEPTION 'PULS_FILE_IMPORT_DUPLICATE_CHECKSUM: this file was already ingested for this scope.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM puls_integration.import_file_manifests manifest
    JOIN puls_integration.import_batches batch
      ON batch.id = manifest.import_batch_id
    WHERE manifest.tenant_id = v_tenant_id
      AND manifest.source_namespace_id = v_source_namespace_id
      AND manifest.scope_key = v_scope_key
      AND manifest.business_date = v_business_date
      AND batch.status IN (
        'uploaded'::puls_integration.import_batch_status,
        'normalized'::puls_integration.import_batch_status,
        'validated'::puls_integration.import_batch_status,
        'previewed'::puls_integration.import_batch_status
      )
  ) THEN
    RAISE EXCEPTION 'PULS_FILE_IMPORT_OPEN_BATCH_EXISTS: an open batch already exists for this scope and date.';
  END IF;

  v_employee_id := puls_core.current_employee_id();

  INSERT INTO puls_integration.import_batches (
    tenant_id,
    source_namespace_id,
    status,
    mode,
    source_checksum,
    created_by_employee_id
  )
  VALUES (
    v_tenant_id,
    v_source_namespace_id,
    'uploaded',
    'dry_run',
    v_file_checksum,
    v_employee_id
  )
  RETURNING id INTO v_batch_id;

  INSERT INTO puls_integration.import_file_manifests (
    tenant_id,
    connection_id,
    source_namespace_id,
    import_batch_id,
    scope_key,
    template_version,
    file_name,
    file_extension,
    file_size_bytes,
    file_checksum,
    business_date,
    delimiter,
    row_count,
    uploaded_by_employee_id,
    safe_summary
  )
  VALUES (
    v_tenant_id,
    v_connection.id,
    v_source_namespace_id,
    v_batch_id,
    v_scope_key,
    'v1',
    v_file_name,
    v_file_extension,
    v_file_size_bytes,
    v_file_checksum,
    v_business_date,
    v_delimiter,
    v_row_count,
    v_employee_id,
    jsonb_build_object(
      'scope_key', v_scope_key,
      'file_extension', v_file_extension,
      'row_count', v_row_count,
      'template_version', 'v1',
      'business_date', to_char(v_business_date, 'YYYY-MM-DD'),
      'source_writeback', FALSE,
      'provider_api_calls', FALSE,
      'raw_payload_readback', FALSE,
      'credential_readback', FALSE
    )
  )
  RETURNING id INTO v_manifest_id;

  v_blocked_keys := puls_integration.import_blocked_keys();

  FOR v_row IN
    SELECT value
    FROM jsonb_array_elements(p_rows)
  LOOP
    IF jsonb_typeof(v_row) <> 'object' THEN
      RAISE EXCEPTION 'PULS_FILE_IMPORT_ROW_INVALID: each row must be a JSON object.';
    END IF;

    IF COALESCE(v_row ->> 'row_number', '') !~ '^[0-9]+$' THEN
      RAISE EXCEPTION 'PULS_FILE_IMPORT_ROW_NUMBER_INVALID: row_number must be a positive integer.';
    END IF;
    v_row_number := (v_row ->> 'row_number')::INTEGER;
    IF v_row_number <= 0 THEN
      RAISE EXCEPTION 'PULS_FILE_IMPORT_ROW_NUMBER_INVALID: row_number must be positive.';
    END IF;

    v_row_entity_type := lower(btrim(COALESCE(v_row ->> 'entity_type', '')));
    IF v_row_entity_type <> v_expected_entity_type::TEXT THEN
      RAISE EXCEPTION 'PULS_FILE_IMPORT_ENTITY_TYPE_MISMATCH: row entity_type does not match scope.';
    END IF;

    v_external_id := btrim(COALESCE(v_row ->> 'external_id', ''));
    IF v_external_id = '' THEN
      RAISE EXCEPTION 'PULS_FILE_IMPORT_EXTERNAL_ID_REQUIRED: row external_id is required.';
    END IF;

    v_payload := v_row -> 'payload';
    IF v_payload IS NULL OR jsonb_typeof(v_payload) <> 'object' THEN
      RAISE EXCEPTION 'PULS_FILE_IMPORT_PAYLOAD_INVALID: row payload must be a JSON object.';
    END IF;

    SELECT payload_key
    INTO v_blocked_key
    FROM jsonb_object_keys(v_payload) AS payload_keys(payload_key)
    WHERE lower(payload_key) = ANY(v_blocked_keys)
    LIMIT 1;

    IF v_blocked_key IS NOT NULL THEN
      RAISE EXCEPTION 'PULS_FILE_IMPORT_PAYLOAD_FORBIDDEN: payload contains blocked key %.', v_blocked_key;
    END IF;

    PERFORM puls_integration.record_import_row(
      v_batch_id,
      v_row_number,
      v_expected_entity_type,
      v_external_id,
      v_payload
    );
  END LOOP;

  INSERT INTO puls_integration.erp_sync_batches (
    tenant_id,
    connection_id,
    sync_type,
    event_key,
    actor_employee_id,
    status,
    started_at,
    finished_at,
    records_seen,
    records_inserted,
    records_updated,
    records_skipped,
    records_failed,
    safe_error_context,
    next_action_key
  )
  VALUES (
    v_tenant_id,
    v_connection.id,
    'file_import_staged',
    'file_import_uploaded',
    v_employee_id,
    'success',
    NOW(),
    NOW(),
    v_row_count,
    v_row_count,
    0,
    0,
    0,
    jsonb_build_object(
      'scope_key', v_scope_key,
      'file_extension', v_file_extension,
      'row_count', v_row_count,
      'template_version', 'v1',
      'business_date', to_char(v_business_date, 'YYYY-MM-DD'),
      'import_batch_id', v_batch_id
    ),
    'run_file_import_preview'
  );

  UPDATE puls_integration.erp_connections connection
  SET
    setup_status = CASE
      WHEN connection.setup_status IN (
        'draft'::puls_integration.connector_setup_status,
        'setup_in_progress'::puls_integration.connector_setup_status
      )
      THEN 'mapping_ready'::puls_integration.connector_setup_status
      ELSE connection.setup_status
    END,
    setup_step = CASE
      WHEN connection.setup_step IN (
        'source'::puls_integration.connector_setup_step,
        'mapping'::puls_integration.connector_setup_step
      )
      THEN 'preflight'::puls_integration.connector_setup_step
      ELSE connection.setup_step
    END,
    last_status = 'success'::puls_integration.sync_status,
    setup_metadata = jsonb_strip_nulls(
      connection.setup_metadata || jsonb_build_object(
        'last_file_import', jsonb_build_object(
          'scope_key', v_scope_key,
          'file_extension', v_file_extension,
          'row_count', v_row_count,
          'business_date', to_char(v_business_date, 'YYYY-MM-DD'),
          'import_batch_id', v_batch_id,
          'staged_at', NOW()
        )
      )
    ),
    updated_by_employee_id = v_employee_id,
    updated_at = NOW()
  WHERE connection.id = v_connection.id;

  RETURN jsonb_build_object(
    'contract_version', 'pr16.10.8-file-import-contract-v1',
    'manifest_id', v_manifest_id,
    'import_batch_id', v_batch_id,
    'source_namespace_id', v_source_namespace_id,
    'connection_id', v_connection.id,
    'scope_key', v_scope_key,
    'row_count', v_row_count,
    'mode', 'dry_run',
    'status', 'uploaded',
    'next_action_key', 'run_file_import_preview',
    'source_writeback', FALSE,
    'provider_api_calls', FALSE,
    'canonical_write', FALSE,
    'raw_payload_readback', FALSE,
    'credential_readback', FALSE
  );
END;
$$;

ALTER TABLE puls_integration.import_file_manifests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS import_file_manifests_select
  ON puls_integration.import_file_manifests;
CREATE POLICY import_file_manifests_select
  ON puls_integration.import_file_manifests
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND puls_integration.is_import_metadata_reader()
  );

DROP POLICY IF EXISTS import_file_manifests_service_role
  ON puls_integration.import_file_manifests;
CREATE POLICY import_file_manifests_service_role
  ON puls_integration.import_file_manifests
  FOR ALL TO service_role
  USING (TRUE)
  WITH CHECK (TRUE);

REVOKE ALL ON TABLE puls_integration.import_file_manifests FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE puls_integration.import_file_manifests TO authenticated;
GRANT ALL ON TABLE puls_integration.import_file_manifests TO service_role;

REVOKE ALL ON FUNCTION puls_integration.ingest_file_import_batch(UUID, TEXT, JSONB, JSONB)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION puls_integration.ingest_file_import_batch(UUID, TEXT, JSONB, JSONB)
  TO authenticated, service_role;

COMMENT ON TABLE puls_integration.import_file_manifests IS
  'Metadata-only CSV/Excel file import manifests. No raw file bytes, raw payloads, credentials, or provider responses are stored.';
COMMENT ON FUNCTION puls_integration.ingest_file_import_batch(UUID, TEXT, JSONB, JSONB) IS
  'Atomically stages a CSV/Excel dry-run import batch and rows. Rejects duplicate/open files and never writes canonical HR data.';
