-- PR16.4.1 guarded update evidence.
-- Produces immutable field-diff and rollback-snapshot evidence for reference-dimension
-- guarded updates. It does not open canonical update execution, source writeback,
-- provider API calls, credential readback, raw payload readback, or browser apply.

CREATE TABLE IF NOT EXISTS puls_integration.connector_apply_field_diffs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  connection_id UUID NULL REFERENCES puls_integration.erp_connections(id) ON DELETE SET NULL,
  source_namespace_id UUID NOT NULL REFERENCES puls_integration.source_namespaces(id) ON DELETE RESTRICT,
  import_batch_id UUID NOT NULL REFERENCES puls_integration.import_batches(id) ON DELETE RESTRICT,
  change_set_id UUID NOT NULL REFERENCES puls_integration.connector_apply_change_sets(id) ON DELETE RESTRICT,
  change_set_item_id UUID NOT NULL REFERENCES puls_integration.connector_apply_change_set_items(id) ON DELETE RESTRICT,
  import_record_id UUID NOT NULL REFERENCES puls_integration.import_records(id) ON DELETE RESTRICT,
  entity_type puls_integration.import_entity_type NOT NULL,
  external_id TEXT NOT NULL,
  target_schema TEXT NOT NULL DEFAULT 'puls_core',
  target_table TEXT NOT NULL,
  canonical_id UUID NOT NULL,
  field_name TEXT NOT NULL,
  field_class TEXT NOT NULL DEFAULT 'safe',
  operation TEXT NOT NULL DEFAULT 'set',
  before_value_hash TEXT NULL,
  after_value_hash TEXT NULL,
  before_value_present BOOLEAN NOT NULL DEFAULT FALSE,
  after_value_present BOOLEAN NOT NULL DEFAULT FALSE,
  value_readback_allowed BOOLEAN NOT NULL DEFAULT FALSE,
  source_row_hash TEXT NOT NULL,
  expected_current_hash TEXT NULL,
  current_hash TEXT NULL,
  stale_blocked BOOLEAN NOT NULL DEFAULT FALSE,
  retention_bucket TEXT NOT NULL DEFAULT 'field_diff',
  hot_retention_expires_at TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '90 days',
  safe_summary JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (external_id <> ''),
  CHECK (target_schema = 'puls_core'),
  CHECK (target_table <> ''),
  CHECK (field_name <> ''),
  CHECK (field_class IN ('safe', 'sensitive', 'destructive_equivalent')),
  CHECK (operation IN ('set', 'clear')),
  CHECK (source_row_hash <> ''),
  CHECK (retention_bucket = 'field_diff'),
  CHECK (jsonb_typeof(safe_summary) = 'object'),
  CHECK (puls_integration.connector_safe_context_has_blocked_key(safe_summary) IS FALSE),
  UNIQUE (change_set_item_id, field_name)
);

CREATE INDEX IF NOT EXISTS idx_puls_integration_apply_field_diffs_change_set
  ON puls_integration.connector_apply_field_diffs (change_set_id, created_at ASC);

CREATE INDEX IF NOT EXISTS idx_puls_integration_apply_field_diffs_tenant_retention
  ON puls_integration.connector_apply_field_diffs (tenant_id, hot_retention_expires_at);

CREATE TABLE IF NOT EXISTS puls_integration.connector_apply_rollback_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  connection_id UUID NULL REFERENCES puls_integration.erp_connections(id) ON DELETE SET NULL,
  source_namespace_id UUID NOT NULL REFERENCES puls_integration.source_namespaces(id) ON DELETE RESTRICT,
  import_batch_id UUID NOT NULL REFERENCES puls_integration.import_batches(id) ON DELETE RESTRICT,
  change_set_id UUID NOT NULL REFERENCES puls_integration.connector_apply_change_sets(id) ON DELETE RESTRICT,
  change_set_item_id UUID NOT NULL REFERENCES puls_integration.connector_apply_change_set_items(id) ON DELETE RESTRICT,
  import_record_id UUID NOT NULL REFERENCES puls_integration.import_records(id) ON DELETE RESTRICT,
  entity_type puls_integration.import_entity_type NOT NULL,
  external_id TEXT NOT NULL,
  target_schema TEXT NOT NULL DEFAULT 'puls_core',
  target_table TEXT NOT NULL,
  canonical_id UUID NOT NULL,
  snapshot_hash TEXT NOT NULL,
  snapshot_payload JSONB NOT NULL DEFAULT '{}'::JSONB,
  snapshot_state TEXT NOT NULL DEFAULT 'available',
  value_readback_allowed BOOLEAN NOT NULL DEFAULT FALSE,
  source_row_hash TEXT NOT NULL,
  expected_current_hash TEXT NULL,
  current_hash TEXT NULL,
  retention_bucket TEXT NOT NULL DEFAULT 'rollback_snapshot',
  hot_retention_expires_at TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '90 days',
  purge_after_at TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '24 months',
  safe_summary JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (external_id <> ''),
  CHECK (target_schema = 'puls_core'),
  CHECK (target_table <> ''),
  CHECK (snapshot_hash <> ''),
  CHECK (jsonb_typeof(snapshot_payload) = 'object'),
  CHECK (snapshot_state IN ('available', 'purged', 'blocked')),
  CHECK (source_row_hash <> ''),
  CHECK (retention_bucket = 'rollback_snapshot'),
  CHECK (jsonb_typeof(safe_summary) = 'object'),
  CHECK (puls_integration.connector_safe_context_has_blocked_key(safe_summary) IS FALSE),
  UNIQUE (change_set_item_id)
);

CREATE INDEX IF NOT EXISTS idx_puls_integration_apply_rollback_snapshots_change_set
  ON puls_integration.connector_apply_rollback_snapshots (change_set_id, created_at ASC);

CREATE INDEX IF NOT EXISTS idx_puls_integration_apply_rollback_snapshots_tenant_retention
  ON puls_integration.connector_apply_rollback_snapshots (tenant_id, hot_retention_expires_at, purge_after_at);

COMMENT ON TABLE puls_integration.connector_apply_field_diffs IS
  'PR16.4.1 immutable guarded-update field-diff evidence. Stores field names, value hashes, stale guard hashes, and retention metadata only; no raw source values.';

COMMENT ON TABLE puls_integration.connector_apply_rollback_snapshots IS
  'PR16.4.1 immutable service-role rollback snapshot evidence for guarded reference updates. Snapshot payload is not exposed to authenticated callers.';

CREATE OR REPLACE FUNCTION puls_integration.reject_connector_guarded_update_evidence_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration
AS $$
BEGIN
  RAISE EXCEPTION
    'PULS_CONNECTOR_GUARDED_UPDATE_EVIDENCE_IMMUTABLE: guarded update evidence cannot be updated or deleted.';
END;
$$;

DROP TRIGGER IF EXISTS puls_integration_apply_field_diffs_immutable
  ON puls_integration.connector_apply_field_diffs;
CREATE TRIGGER puls_integration_apply_field_diffs_immutable
  BEFORE UPDATE OR DELETE ON puls_integration.connector_apply_field_diffs
  FOR EACH ROW EXECUTE FUNCTION puls_integration.reject_connector_guarded_update_evidence_mutation();

DROP TRIGGER IF EXISTS puls_integration_apply_rollback_snapshots_immutable
  ON puls_integration.connector_apply_rollback_snapshots;
CREATE TRIGGER puls_integration_apply_rollback_snapshots_immutable
  BEFORE UPDATE OR DELETE ON puls_integration.connector_apply_rollback_snapshots
  FOR EACH ROW EXECUTE FUNCTION puls_integration.reject_connector_guarded_update_evidence_mutation();

CREATE OR REPLACE FUNCTION puls_integration._connector_apply_guarded_update_field_allowed(
  p_entity_type puls_integration.import_entity_type,
  p_field_name TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog, puls_integration
AS $$
  SELECT
    puls_integration._connector_apply_is_create_only_reference_entity(p_entity_type)
    AND p_field_name IN ('code', 'name');
$$;

CREATE OR REPLACE FUNCTION puls_integration._connector_apply_guarded_update_mutable_field_allowed(
  p_entity_type puls_integration.import_entity_type,
  p_field_name TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog, puls_integration
AS $$
  SELECT
    puls_integration._connector_apply_is_create_only_reference_entity(p_entity_type)
    AND p_field_name = 'name';
$$;

CREATE OR REPLACE FUNCTION puls_integration._connector_apply_field_class(
  p_field_name TEXT
)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog
AS $$
  SELECT CASE
    WHEN p_field_name IN (
      'employment_status',
      'is_active',
      'assignment_close',
      'assignment_closed_at',
      'assignment_end_date',
      'manager_reporting_line',
      'manager_employee_id',
      'manager_external_id',
      'manager_id',
      'reports_to',
      'terminated_at',
      'termination_date',
      'explicit_clear'
    ) THEN 'destructive_equivalent'
    WHEN p_field_name IN ('email', 'full_name', 'employee_code', 'hire_date') THEN 'sensitive'
    ELSE 'safe'
  END;
$$;

CREATE OR REPLACE FUNCTION puls_integration._connector_apply_hash_jsonb(
  p_value JSONB
)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog
AS $$
  SELECT encode(
    sha256(convert_to(COALESCE(p_value, 'null'::JSONB)::TEXT, 'UTF8')),
    'hex'
  );
$$;

CREATE OR REPLACE FUNCTION puls_integration._connector_apply_current_reference_payload(
  p_tenant_id UUID,
  p_entity_type puls_integration.import_entity_type,
  p_canonical_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_payload JSONB;
BEGIN
  IF p_entity_type = 'legal_entity'::puls_integration.import_entity_type THEN
    SELECT jsonb_build_object('code', le.code, 'name', le.name, 'is_active', le.is_active)
    INTO v_payload
    FROM puls_core.legal_entities le
    WHERE le.tenant_id = p_tenant_id
      AND le.id = p_canonical_id;
  ELSIF p_entity_type = 'location'::puls_integration.import_entity_type THEN
    SELECT jsonb_build_object('code', loc.code, 'name', loc.name, 'is_active', loc.is_active)
    INTO v_payload
    FROM puls_core.locations loc
    WHERE loc.tenant_id = p_tenant_id
      AND loc.id = p_canonical_id;
  ELSIF p_entity_type = 'cost_center'::puls_integration.import_entity_type THEN
    SELECT jsonb_build_object('code', cc.code, 'name', cc.name, 'is_active', cc.is_active)
    INTO v_payload
    FROM puls_core.cost_centers cc
    WHERE cc.tenant_id = p_tenant_id
      AND cc.id = p_canonical_id;
  ELSIF p_entity_type = 'department'::puls_integration.import_entity_type THEN
    SELECT jsonb_build_object('code', dept.code, 'name', dept.name, 'is_active', dept.is_active)
    INTO v_payload
    FROM puls_core.departments dept
    WHERE dept.tenant_id = p_tenant_id
      AND dept.id = p_canonical_id;
  ELSIF p_entity_type = 'position'::puls_integration.import_entity_type THEN
    SELECT jsonb_build_object('code', pos.code, 'name', pos.name, 'is_active', pos.is_active)
    INTO v_payload
    FROM puls_core.positions pos
    WHERE pos.tenant_id = p_tenant_id
      AND pos.id = p_canonical_id;
  ELSE
    RETURN NULL;
  END IF;

  RETURN v_payload;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration.generate_connector_guarded_update_evidence(
  p_change_set_id UUID
)
RETURNS TABLE (
  change_set_id UUID,
  tenant_id UUID,
  connection_id UUID,
  source_namespace_id UUID,
  import_batch_id UUID,
  status TEXT,
  guarded_update_count INTEGER,
  field_diff_count INTEGER,
  rollback_snapshot_count INTEGER,
  stale_blocked_count INTEGER,
  execution_enabled BOOLEAN,
  canonical_write_enabled BOOLEAN,
  source_writeback_enabled BOOLEAN,
  credential_readback_enabled BOOLEAN,
  value_readback_enabled BOOLEAN,
  hot_retention_days INTEGER,
  next_action_key TEXT,
  sample_field_diffs JSONB,
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
  v_item puls_integration.connector_apply_change_set_items;
  v_record puls_integration.import_records;
  v_current_payload JSONB;
  v_snapshot_hash TEXT;
  v_current_hash TEXT;
  v_field_name TEXT;
  v_field_class TEXT;
  v_before_value JSONB;
  v_after_value JSONB;
  v_before_hash TEXT;
  v_after_hash TEXT;
  v_before_present BOOLEAN;
  v_after_present BOOLEAN;
  v_operation TEXT;
  v_invalid_fields TEXT[];
BEGIN
  IF NOT v_is_service_role AND NOT COALESCE(puls_core.is_admin(), FALSE) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_ADMIN_REQUIRED: admin permission is required.';
  END IF;

  IF NOT v_is_service_role AND v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_TENANT_REQUIRED: authenticated caller has no tenant context.';
  END IF;

  SELECT *
  INTO v_change_set
  FROM puls_integration.connector_apply_change_sets cs
  WHERE cs.id = p_change_set_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_CHANGE_SET_NOT_FOUND: change-set not found.';
  END IF;

  IF NOT v_is_service_role AND v_change_set.tenant_id IS DISTINCT FROM v_tenant_id THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_FORBIDDEN: change-set belongs to another tenant.';
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

  IF v_batch.mode <> 'dry_run'::puls_integration.import_batch_mode
     OR v_batch.status <> 'previewed'::puls_integration.import_batch_status
     OR v_batch.source_checksum IS DISTINCT FROM v_change_set.source_checksum THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_PREVIEW_REQUIRED: guarded update evidence requires the original previewed dry-run batch.';
  END IF;

  IF COALESCE(v_change_set.guarded_update_count, 0) <= 0 THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_REQUIRED: change-set has no guarded update rows.';
  END IF;

  IF COALESCE(v_change_set.stale_count, 0) > 0
     OR COALESCE(v_change_set.destructive_count, 0) > 0
     OR COALESCE(v_change_set.source_conflict_count, 0) > 0 THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_BLOCKERS_PRESENT: stale, destructive, or source-conflict rows must be resolved first.';
  END IF;

  FOR v_item IN
    SELECT csi.*
    FROM puls_integration.connector_apply_change_set_items csi
    WHERE csi.change_set_id = v_change_set.id
      AND csi.operation = 'update'::puls_integration.connector_apply_operation
      AND csi.risk_class = 'guarded_overwrite'::puls_integration.connector_apply_risk_class
    ORDER BY csi.row_number
  LOOP
    IF NOT puls_integration._connector_apply_is_create_only_reference_entity(v_item.entity_type) THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_ENTITY_SCOPE_INVALID: guarded update evidence is limited to reference dimensions.';
    END IF;

    IF v_item.canonical_id IS NULL OR v_item.expected_current_hash IS NULL THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_CURRENT_HASH_REQUIRED: row % requires canonical id and expected current hash.', v_item.row_number;
    END IF;

    SELECT COALESCE(array_agg(field_name ORDER BY field_name), '{}'::TEXT[])
    INTO v_invalid_fields
    FROM unnest(COALESCE(v_item.safe_field_names, '{}'::TEXT[])) AS fields(field_name)
    WHERE NOT puls_integration._connector_apply_guarded_update_field_allowed(
      v_item.entity_type,
      fields.field_name
    );

    IF COALESCE(array_length(v_invalid_fields, 1), 0) > 0 THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_FIELD_SCOPE_INVALID: row % contains fields outside PR16.4.1 guarded-update evidence scope.', v_item.row_number;
    END IF;

    IF COALESCE(array_length(v_item.destructive_field_names, 1), 0) > 0 THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_DESTRUCTIVE_FIELD_BLOCKED: row % contains destructive-equivalent fields.', v_item.row_number;
    END IF;

    SELECT *
    INTO v_record
    FROM puls_integration.import_records ir
    WHERE ir.id = v_item.import_record_id
      AND ir.batch_id = v_change_set.import_batch_id
      AND ir.status = 'validated'::puls_integration.import_record_status;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_RECORD_INVALID: row % is not validated.', v_item.row_number;
    END IF;

    v_current_hash := puls_integration._connector_apply_expected_current_hash(
      v_change_set.tenant_id,
      v_change_set.source_namespace_id,
      v_item.entity_type,
      v_item.external_id,
      v_item.canonical_id
    );

    IF v_current_hash IS NULL OR v_current_hash IS DISTINCT FROM v_item.expected_current_hash THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_STALE_TARGET: row % current hash no longer matches change-set expectation.', v_item.row_number;
    END IF;

    v_current_payload := puls_integration._connector_apply_current_reference_payload(
      v_change_set.tenant_id,
      v_item.entity_type,
      v_item.canonical_id
    );

    IF v_current_payload IS NULL THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_TARGET_NOT_FOUND: row % canonical target is missing.', v_item.row_number;
    END IF;

    v_snapshot_hash := puls_integration._connector_apply_hash_jsonb(v_current_payload);

    INSERT INTO puls_integration.connector_apply_rollback_snapshots (
      tenant_id,
      connection_id,
      source_namespace_id,
      import_batch_id,
      change_set_id,
      change_set_item_id,
      import_record_id,
      entity_type,
      external_id,
      target_table,
      canonical_id,
      snapshot_hash,
      snapshot_payload,
      source_row_hash,
      expected_current_hash,
      current_hash,
      safe_summary
    )
    VALUES (
      v_change_set.tenant_id,
      v_change_set.connection_id,
      v_change_set.source_namespace_id,
      v_change_set.import_batch_id,
      v_change_set.id,
      v_item.id,
      v_item.import_record_id,
      v_item.entity_type,
      v_item.external_id,
      v_item.target_table,
      v_item.canonical_id,
      v_snapshot_hash,
      v_current_payload,
      v_item.source_row_hash,
      v_item.expected_current_hash,
      v_current_hash,
      jsonb_build_object(
        'contract_version', 'pr16.4.1-guarded-update-evidence-v1',
        'change_set_id', v_change_set.id,
        'import_batch_id', v_change_set.import_batch_id,
        'row_number', v_item.row_number,
        'entity_type', v_item.entity_type,
        'target_table', v_item.target_table,
        'operation', 'rollback_snapshot',
        'snapshot_hash_available', TRUE,
        'value_readback', FALSE,
        'canonical_write', FALSE,
        'source_writeback', FALSE,
        'credential_readback', FALSE,
        'provider_api_calls', FALSE,
        'field_value_readback', FALSE,
        'raw_payload_readback', FALSE
      )
    )
    ON CONFLICT (change_set_item_id) DO NOTHING;

    FOR v_field_name IN
      SELECT unnest(v_item.safe_field_names)
    LOOP
      v_before_present := v_current_payload ? v_field_name;
      v_after_present := COALESCE(v_record.normalized_payload, '{}'::JSONB) ? v_field_name;
      v_before_value := CASE WHEN v_before_present THEN v_current_payload -> v_field_name ELSE NULL END;
      v_after_value := CASE WHEN v_after_present THEN v_record.normalized_payload -> v_field_name ELSE NULL END;
      v_before_hash := CASE
        WHEN v_before_present THEN puls_integration._connector_apply_hash_jsonb(v_before_value)
        ELSE NULL
      END;
      v_after_hash := CASE
        WHEN v_after_present THEN puls_integration._connector_apply_hash_jsonb(v_after_value)
        ELSE NULL
      END;

      IF NOT puls_integration._connector_apply_guarded_update_mutable_field_allowed(
        v_item.entity_type,
        v_field_name
      ) THEN
        IF v_before_hash IS DISTINCT FROM v_after_hash THEN
          RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_IMMUTABLE_FIELD_CHANGED: row % attempts to change an identity guard field.', v_item.row_number;
        END IF;
        CONTINUE;
      END IF;

      IF v_before_hash IS NOT DISTINCT FROM v_after_hash THEN
        CONTINUE;
      END IF;

      v_field_class := puls_integration._connector_apply_field_class(v_field_name);
      IF v_field_class <> 'safe' THEN
        RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_FIELD_CLASS_BLOCKED: row % contains a non-safe field.', v_item.row_number;
      END IF;

      v_operation := CASE
        WHEN NOT v_after_present OR v_after_value = 'null'::JSONB THEN 'clear'
        ELSE 'set'
      END;

      INSERT INTO puls_integration.connector_apply_field_diffs (
        tenant_id,
        connection_id,
        source_namespace_id,
        import_batch_id,
        change_set_id,
        change_set_item_id,
        import_record_id,
        entity_type,
        external_id,
        target_table,
        canonical_id,
        field_name,
        field_class,
        operation,
        before_value_hash,
        after_value_hash,
        before_value_present,
        after_value_present,
        source_row_hash,
        expected_current_hash,
        current_hash,
        stale_blocked,
        safe_summary
      )
      VALUES (
        v_change_set.tenant_id,
        v_change_set.connection_id,
        v_change_set.source_namespace_id,
        v_change_set.import_batch_id,
        v_change_set.id,
        v_item.id,
        v_item.import_record_id,
        v_item.entity_type,
        v_item.external_id,
        v_item.target_table,
        v_item.canonical_id,
        v_field_name,
        v_field_class,
        v_operation,
        v_before_hash,
        v_after_hash,
        v_before_present,
        v_after_present,
        v_item.source_row_hash,
        v_item.expected_current_hash,
        v_current_hash,
        FALSE,
        jsonb_build_object(
          'contract_version', 'pr16.4.1-guarded-update-evidence-v1',
          'change_set_id', v_change_set.id,
          'import_batch_id', v_change_set.import_batch_id,
          'row_number', v_item.row_number,
          'entity_type', v_item.entity_type,
          'target_table', v_item.target_table,
          'field_name', v_field_name,
          'field_class', v_field_class,
          'operation', v_operation,
          'value_hash_only', TRUE,
          'value_readback', FALSE,
          'canonical_write', FALSE,
          'source_writeback', FALSE,
          'credential_readback', FALSE,
          'provider_api_calls', FALSE,
          'field_value_readback', FALSE,
          'raw_payload_readback', FALSE
        )
      )
      ON CONFLICT (change_set_item_id, field_name) DO NOTHING;
    END LOOP;
  END LOOP;

  IF (
    SELECT COUNT(*)::INTEGER
    FROM puls_integration.connector_apply_rollback_snapshots snap
    WHERE snap.change_set_id = v_change_set.id
  ) < v_change_set.guarded_update_count THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_SNAPSHOT_INCOMPLETE: rollback snapshots were not generated for every guarded update row.';
  END IF;

  IF (
    SELECT COUNT(*)::INTEGER
    FROM puls_integration.connector_apply_field_diffs diff
    WHERE diff.change_set_id = v_change_set.id
  ) <= 0 THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_FIELD_DIFF_REQUIRED: no changed safe fields were captured.';
  END IF;

  RETURN QUERY
  SELECT *
  FROM puls_integration.list_connector_guarded_update_evidence(v_change_set.id, 50);
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration.list_connector_guarded_update_evidence(
  p_change_set_id UUID DEFAULT NULL,
  p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
  change_set_id UUID,
  tenant_id UUID,
  connection_id UUID,
  source_namespace_id UUID,
  import_batch_id UUID,
  status TEXT,
  guarded_update_count INTEGER,
  field_diff_count INTEGER,
  rollback_snapshot_count INTEGER,
  stale_blocked_count INTEGER,
  execution_enabled BOOLEAN,
  canonical_write_enabled BOOLEAN,
  source_writeback_enabled BOOLEAN,
  credential_readback_enabled BOOLEAN,
  value_readback_enabled BOOLEAN,
  hot_retention_days INTEGER,
  next_action_key TEXT,
  sample_field_diffs JSONB,
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
    cs.id AS change_set_id,
    cs.tenant_id,
    cs.connection_id,
    cs.source_namespace_id,
    cs.import_batch_id,
    CASE
      WHEN COALESCE(diff_counts.field_diff_count, 0) > 0
       AND COALESCE(snapshot_counts.rollback_snapshot_count, 0) >= cs.guarded_update_count
        THEN 'evidence_ready'
      ELSE 'needs_evidence'
    END AS status,
    cs.guarded_update_count,
    COALESCE(diff_counts.field_diff_count, 0)::INTEGER AS field_diff_count,
    COALESCE(snapshot_counts.rollback_snapshot_count, 0)::INTEGER AS rollback_snapshot_count,
    COALESCE(diff_counts.stale_blocked_count, 0)::INTEGER AS stale_blocked_count,
    FALSE AS execution_enabled,
    FALSE AS canonical_write_enabled,
    FALSE AS source_writeback_enabled,
    FALSE AS credential_readback_enabled,
    FALSE AS value_readback_enabled,
    90 AS hot_retention_days,
    CASE
      WHEN COALESCE(diff_counts.field_diff_count, 0) > 0
       AND COALESCE(snapshot_counts.rollback_snapshot_count, 0) >= cs.guarded_update_count
        THEN 'review_guarded_update_evidence'
      ELSE 'generate_guarded_update_evidence'
    END AS next_action_key,
    COALESCE(samples.sample_field_diffs, '[]'::JSONB) AS sample_field_diffs,
    COALESCE(diff_counts.created_at, snapshot_counts.created_at, cs.created_at) AS created_at
  FROM puls_integration.connector_apply_change_sets cs
  LEFT JOIN LATERAL (
    SELECT
      COUNT(*)::INTEGER AS field_diff_count,
      COUNT(*) FILTER (WHERE diff.stale_blocked)::INTEGER AS stale_blocked_count,
      MIN(diff.created_at) AS created_at
    FROM puls_integration.connector_apply_field_diffs diff
    WHERE diff.change_set_id = cs.id
  ) diff_counts ON TRUE
  LEFT JOIN LATERAL (
    SELECT
      COUNT(*)::INTEGER AS rollback_snapshot_count,
      MIN(snap.created_at) AS created_at
    FROM puls_integration.connector_apply_rollback_snapshots snap
    WHERE snap.change_set_id = cs.id
  ) snapshot_counts ON TRUE
  LEFT JOIN LATERAL (
    SELECT jsonb_agg(
      jsonb_build_object(
        'id', sample.id,
        'row_number', sample.row_number,
        'entity_type', sample.entity_type,
        'external_id', sample.external_id,
        'target_table', sample.target_table,
        'field_name', sample.field_name,
        'field_class', sample.field_class,
        'operation', sample.operation,
        'before_value_hash_available', sample.before_value_hash IS NOT NULL,
        'after_value_hash_available', sample.after_value_hash IS NOT NULL,
        'before_value_present', sample.before_value_present,
        'after_value_present', sample.after_value_present,
        'expected_current_hash_available', sample.expected_current_hash IS NOT NULL,
        'current_hash_available', sample.current_hash IS NOT NULL,
        'stale_blocked', sample.stale_blocked,
        'rollback_snapshot_required', TRUE,
        'retention_bucket', sample.retention_bucket,
        'hot_retention_expires_at', sample.hot_retention_expires_at
      )
      ORDER BY sample.row_number, sample.field_name
    ) AS sample_field_diffs
    FROM (
      SELECT diff.*, item.row_number
      FROM puls_integration.connector_apply_field_diffs diff
      JOIN puls_integration.connector_apply_change_set_items item
        ON item.id = diff.change_set_item_id
      WHERE diff.change_set_id = cs.id
      ORDER BY item.row_number, diff.field_name
      LIMIT v_limit
    ) sample
  ) samples ON TRUE
  WHERE cs.guarded_update_count > 0
    AND (v_auth_role = 'service_role' OR cs.tenant_id = v_tenant_id)
    AND (p_change_set_id IS NULL OR cs.id = p_change_set_id)
  ORDER BY COALESCE(diff_counts.created_at, snapshot_counts.created_at, cs.created_at) DESC;
END;
$$;

ALTER TABLE puls_integration.connector_apply_field_diffs ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_integration.connector_apply_rollback_snapshots ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON puls_integration.connector_apply_field_diffs
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON puls_integration.connector_apply_rollback_snapshots
  FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT ON puls_integration.connector_apply_field_diffs TO service_role;
GRANT SELECT, INSERT ON puls_integration.connector_apply_rollback_snapshots TO service_role;

REVOKE ALL ON FUNCTION puls_integration.reject_connector_guarded_update_evidence_mutation()
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.reject_connector_guarded_update_evidence_mutation()
  TO service_role;

REVOKE ALL ON FUNCTION puls_integration._connector_apply_guarded_update_field_allowed(
  puls_integration.import_entity_type,
  TEXT
) FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration._connector_apply_guarded_update_field_allowed(
  puls_integration.import_entity_type,
  TEXT
) TO service_role;

REVOKE ALL ON FUNCTION puls_integration._connector_apply_guarded_update_mutable_field_allowed(
  puls_integration.import_entity_type,
  TEXT
) FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration._connector_apply_guarded_update_mutable_field_allowed(
  puls_integration.import_entity_type,
  TEXT
) TO service_role;

REVOKE ALL ON FUNCTION puls_integration._connector_apply_field_class(TEXT)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration._connector_apply_field_class(TEXT)
  TO service_role;

REVOKE ALL ON FUNCTION puls_integration._connector_apply_hash_jsonb(JSONB)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration._connector_apply_hash_jsonb(JSONB)
  TO service_role;

REVOKE ALL ON FUNCTION puls_integration._connector_apply_current_reference_payload(
  UUID,
  puls_integration.import_entity_type,
  UUID
) FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration._connector_apply_current_reference_payload(
  UUID,
  puls_integration.import_entity_type,
  UUID
) TO service_role;

REVOKE ALL ON FUNCTION puls_integration.generate_connector_guarded_update_evidence(UUID)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.generate_connector_guarded_update_evidence(UUID)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_integration.list_connector_guarded_update_evidence(UUID, INTEGER)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.list_connector_guarded_update_evidence(UUID, INTEGER)
  TO authenticated, service_role;

COMMENT ON FUNCTION puls_integration.generate_connector_guarded_update_evidence(UUID) IS
  'PR16.4.1 admin/service-role RPC that generates immutable guarded-update field-diff hashes and rollback snapshots. It does not execute updates or expose values.';

COMMENT ON FUNCTION puls_integration.list_connector_guarded_update_evidence(UUID, INTEGER) IS
  'Authenticated-safe PR16.4.1 read model for guarded-update evidence. Returns counts, hash availability, field names, and retention metadata only.';
