-- PR16.2 apply change-set, before-snapshot metadata, and risk ledger.
-- Generates immutable, safe change-set evidence from previewed dry-run batches.
-- Does not open canonical writes, import_apply jobs, ERP/source writeback, credential readback, or raw payload readback.

DO $$
BEGIN
  CREATE TYPE puls_integration.connector_apply_change_set_status AS ENUM (
    'ready_for_create_only_review',
    'blocked'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE puls_integration.connector_apply_risk_class AS ENUM (
    'create_only',
    'no_change_skip',
    'safe_additive_update',
    'guarded_overwrite',
    'destructive_equivalent',
    'source_conflict',
    'stale_preview',
    'rollback_required'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS puls_integration.connector_apply_change_sets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  connection_id UUID NULL REFERENCES puls_integration.erp_connections(id) ON DELETE SET NULL,
  source_namespace_id UUID NOT NULL REFERENCES puls_integration.source_namespaces(id) ON DELETE RESTRICT,
  import_batch_id UUID NOT NULL REFERENCES puls_integration.import_batches(id) ON DELETE RESTRICT,
  status puls_integration.connector_apply_change_set_status NOT NULL DEFAULT 'blocked',
  source_checksum TEXT NOT NULL,
  change_set_checksum TEXT NOT NULL,
  previewed_at TIMESTAMPTZ NOT NULL,
  row_count INTEGER NOT NULL DEFAULT 0,
  create_count INTEGER NOT NULL DEFAULT 0,
  update_count INTEGER NOT NULL DEFAULT 0,
  skip_count INTEGER NOT NULL DEFAULT 0,
  blocked_count INTEGER NOT NULL DEFAULT 0,
  stale_count INTEGER NOT NULL DEFAULT 0,
  destructive_count INTEGER NOT NULL DEFAULT 0,
  source_conflict_count INTEGER NOT NULL DEFAULT 0,
  guarded_update_count INTEGER NOT NULL DEFAULT 0,
  no_change_count INTEGER NOT NULL DEFAULT 0,
  execution_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  canonical_write_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  source_writeback_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  credential_readback_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  approval_required BOOLEAN NOT NULL DEFAULT TRUE,
  safe_summary JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_by_employee_id UUID NULL REFERENCES puls_core.employees(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (source_checksum <> ''),
  CHECK (change_set_checksum <> ''),
  CHECK (jsonb_typeof(safe_summary) = 'object'),
  UNIQUE (import_batch_id, source_checksum),
  UNIQUE (change_set_checksum)
);

CREATE INDEX IF NOT EXISTS idx_puls_integration_apply_change_sets_tenant_created
  ON puls_integration.connector_apply_change_sets (tenant_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_puls_integration_apply_change_sets_connection
  ON puls_integration.connector_apply_change_sets (tenant_id, connection_id, created_at DESC);

CREATE TABLE IF NOT EXISTS puls_integration.connector_apply_change_set_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  change_set_id UUID NOT NULL REFERENCES puls_integration.connector_apply_change_sets(id) ON DELETE CASCADE,
  import_batch_id UUID NOT NULL REFERENCES puls_integration.import_batches(id) ON DELETE RESTRICT,
  import_record_id UUID NOT NULL REFERENCES puls_integration.import_records(id) ON DELETE RESTRICT,
  row_number INTEGER NOT NULL,
  entity_type puls_integration.import_entity_type NOT NULL,
  external_id TEXT NOT NULL,
  target_schema TEXT NOT NULL DEFAULT 'puls_core',
  target_table TEXT NOT NULL,
  canonical_id UUID NULL,
  operation puls_integration.connector_apply_operation NULL,
  risk_class puls_integration.connector_apply_risk_class NOT NULL,
  blocked BOOLEAN NOT NULL DEFAULT TRUE,
  risk_reasons TEXT[] NOT NULL DEFAULT '{}'::TEXT[],
  audit_tiers puls_integration.connector_apply_audit_tier[] NOT NULL DEFAULT '{}'::puls_integration.connector_apply_audit_tier[],
  retention_bucket TEXT NOT NULL DEFAULT 'object_event',
  source_row_hash TEXT NOT NULL,
  expected_current_hash TEXT NULL,
  current_action TEXT NULL,
  current_skip_code TEXT NULL,
  preview_action TEXT NULL,
  preview_skip_code TEXT NULL,
  previewed_at TIMESTAMPTZ NOT NULL,
  safe_field_names TEXT[] NOT NULL DEFAULT '{}'::TEXT[],
  destructive_field_names TEXT[] NOT NULL DEFAULT '{}'::TEXT[],
  safe_diff_summary JSONB NOT NULL DEFAULT '{}'::JSONB,
  rollback_snapshot_required BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (external_id <> ''),
  CHECK (target_table <> ''),
  CHECK (source_row_hash <> ''),
  CHECK (jsonb_typeof(safe_diff_summary) = 'object'),
  CHECK (
    current_action IS NULL
    OR current_action IN ('create', 'update', 'skip')
  ),
  CHECK (
    preview_action IS NULL
    OR preview_action IN ('create', 'update', 'skip')
  ),
  CHECK (
    retention_bucket IN ('object_event', 'field_diff', 'rollback_snapshot')
  ),
  UNIQUE (change_set_id, import_record_id)
);

CREATE INDEX IF NOT EXISTS idx_puls_integration_apply_change_set_items_change_set
  ON puls_integration.connector_apply_change_set_items (change_set_id, row_number);

CREATE INDEX IF NOT EXISTS idx_puls_integration_apply_change_set_items_risk
  ON puls_integration.connector_apply_change_set_items (tenant_id, risk_class, blocked);

COMMENT ON TABLE puls_integration.connector_apply_change_sets IS
  'PR16.2 immutable apply change-set header. Safe metadata only; no canonical write or raw payload readback.';

COMMENT ON TABLE puls_integration.connector_apply_change_set_items IS
  'PR16.2 immutable apply change-set item risk ledger. Stores safe field names, hashes, audit intent, and retention bucket without raw source values.';

CREATE OR REPLACE FUNCTION puls_integration.reject_connector_apply_change_set_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration
AS $$
BEGIN
  RAISE EXCEPTION
    'PULS_CONNECTOR_APPLY_CHANGE_SET_IMMUTABLE: apply change-set evidence cannot be updated or deleted.';
END;
$$;

DROP TRIGGER IF EXISTS puls_integration_apply_change_sets_immutable
  ON puls_integration.connector_apply_change_sets;
CREATE TRIGGER puls_integration_apply_change_sets_immutable
  BEFORE UPDATE OR DELETE ON puls_integration.connector_apply_change_sets
  FOR EACH ROW EXECUTE FUNCTION puls_integration.reject_connector_apply_change_set_mutation();

DROP TRIGGER IF EXISTS puls_integration_apply_change_set_items_immutable
  ON puls_integration.connector_apply_change_set_items;
CREATE TRIGGER puls_integration_apply_change_set_items_immutable
  BEFORE UPDATE OR DELETE ON puls_integration.connector_apply_change_set_items
  FOR EACH ROW EXECUTE FUNCTION puls_integration.reject_connector_apply_change_set_mutation();

CREATE OR REPLACE FUNCTION puls_integration._connector_apply_destructive_field_names(
  p_normalized JSONB
)
RETURNS TEXT[]
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog
AS $$
  SELECT COALESCE(array_agg(field_name ORDER BY field_name), '{}'::TEXT[])
  FROM (
    SELECT key AS field_name
    FROM jsonb_object_keys(COALESCE(p_normalized, '{}'::JSONB)) AS keys(key)
    WHERE key IN (
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
    )
  ) destructive_fields;
$$;

CREATE OR REPLACE FUNCTION puls_integration._connector_apply_safe_field_names(
  p_normalized JSONB
)
RETURNS TEXT[]
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog
AS $$
  SELECT COALESCE(array_agg(key ORDER BY key), '{}'::TEXT[])
  FROM jsonb_object_keys(COALESCE(p_normalized, '{}'::JSONB)) AS keys(key);
$$;

CREATE OR REPLACE FUNCTION puls_integration._connector_apply_expected_current_hash(
  p_tenant_id UUID,
  p_namespace_id UUID,
  p_entity_type puls_integration.import_entity_type,
  p_external_id TEXT,
  p_canonical_id UUID
)
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration
AS $$
  SELECT eim.source_hash
  FROM puls_integration.entity_identity_map eim
  WHERE eim.tenant_id = p_tenant_id
    AND eim.source_namespace_id = p_namespace_id
    AND eim.entity_type = p_entity_type
    AND eim.external_id = p_external_id
    AND (p_canonical_id IS NULL OR eim.canonical_id = p_canonical_id)
    AND eim.is_active IS TRUE
  ORDER BY eim.updated_at DESC, eim.id ASC
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION puls_integration._connector_apply_change_set_checksum(
  p_batch_id UUID,
  p_source_checksum TEXT
)
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration
AS $$
  SELECT encode(
    sha256(
      convert_to(
        concat_ws(
          ':',
          'pr16.2-change-set-v1',
          p_batch_id::TEXT,
          p_source_checksum,
          COALESCE(
            string_agg(
              concat_ws(
                '|',
                ir.row_number::TEXT,
                ir.entity_type::TEXT,
                ir.external_id,
                COALESCE(ir.row_hash, ''),
                COALESCE(ir.preview_action, ''),
                COALESCE(ir.preview_skip_code, ''),
                COALESCE(ir.canonical_id::TEXT, '')
              ),
              '||'
              ORDER BY ir.row_number
            ),
            ''
          )
        ),
        'UTF8'
      ),
    ),
    'hex'
  )
  FROM puls_integration.import_records ir
  WHERE ir.batch_id = p_batch_id;
$$;

CREATE OR REPLACE FUNCTION puls_integration._connector_apply_classify_change_set_item(
  p_tenant_id UUID,
  p_namespace_id UUID,
  p_namespace_rank INTEGER,
  p_record puls_integration.import_records
)
RETURNS TABLE (
  canonical_id UUID,
  operation puls_integration.connector_apply_operation,
  risk_class puls_integration.connector_apply_risk_class,
  blocked BOOLEAN,
  risk_reasons TEXT[],
  audit_tiers puls_integration.connector_apply_audit_tier[],
  retention_bucket TEXT,
  expected_current_hash TEXT,
  current_action TEXT,
  current_skip_code TEXT,
  safe_field_names TEXT[],
  destructive_field_names TEXT[],
  safe_diff_summary JSONB,
  rollback_snapshot_required BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_class RECORD;
  v_expected_current_hash TEXT;
  v_safe_fields TEXT[];
  v_destructive_fields TEXT[];
  v_target_table TEXT;
  v_is_stale BOOLEAN;
BEGIN
  SELECT c.action, c.skip_code, c.canonical_id
  INTO v_class
  FROM puls_integration._import_classify_record(
    p_tenant_id,
    p_namespace_id,
    p_namespace_rank,
    p_record.entity_type,
    p_record.external_id,
    p_record.normalized_payload,
    p_record.row_hash
  ) c;

  v_safe_fields := puls_integration._connector_apply_safe_field_names(p_record.normalized_payload);
  v_destructive_fields := puls_integration._connector_apply_destructive_field_names(p_record.normalized_payload);
  v_target_table := puls_integration._import_canonical_table(p_record.entity_type);
  v_expected_current_hash := puls_integration._connector_apply_expected_current_hash(
    p_tenant_id,
    p_namespace_id,
    p_record.entity_type,
    p_record.external_id,
    v_class.canonical_id
  );
  v_is_stale :=
    COALESCE(p_record.preview_action, '') <> COALESCE(v_class.action, '')
    OR COALESCE(p_record.preview_skip_code, '') <> COALESCE(v_class.skip_code, '')
    OR COALESCE(p_record.canonical_id::TEXT, '') <> COALESCE(v_class.canonical_id::TEXT, '');

  canonical_id := v_class.canonical_id;
  current_action := v_class.action;
  current_skip_code := v_class.skip_code;
  safe_field_names := v_safe_fields;
  destructive_field_names := v_destructive_fields;
  expected_current_hash := v_expected_current_hash;

  IF v_is_stale THEN
    operation := NULL;
    risk_class := 'stale_preview'::puls_integration.connector_apply_risk_class;
    blocked := TRUE;
    risk_reasons := ARRAY['stale_target_requires_repreview']::TEXT[];
    audit_tiers := ARRAY[
      'object_event'::puls_integration.connector_apply_audit_tier,
      'field_diff'::puls_integration.connector_apply_audit_tier,
      'rollback_snapshot'::puls_integration.connector_apply_audit_tier
    ];
    retention_bucket := 'rollback_snapshot';
    rollback_snapshot_required := TRUE;
  ELSIF v_class.action = 'create' THEN
    operation := 'insert'::puls_integration.connector_apply_operation;
    risk_class := 'create_only'::puls_integration.connector_apply_risk_class;
    blocked := FALSE;
    risk_reasons := ARRAY['create_only_candidate']::TEXT[];
    audit_tiers := ARRAY['object_event'::puls_integration.connector_apply_audit_tier];
    retention_bucket := 'object_event';
    rollback_snapshot_required := FALSE;
  ELSIF v_class.action = 'update' AND COALESCE(array_length(v_destructive_fields, 1), 0) > 0 THEN
    operation := 'update'::puls_integration.connector_apply_operation;
    risk_class := 'destructive_equivalent'::puls_integration.connector_apply_risk_class;
    blocked := TRUE;
    risk_reasons := ARRAY[
      'blocked_update_requires_policy',
      'destructive_field_policy_required'
    ]::TEXT[];
    audit_tiers := ARRAY[
      'object_event'::puls_integration.connector_apply_audit_tier,
      'field_diff'::puls_integration.connector_apply_audit_tier,
      'rollback_snapshot'::puls_integration.connector_apply_audit_tier
    ];
    retention_bucket := 'rollback_snapshot';
    rollback_snapshot_required := TRUE;
  ELSIF v_class.action = 'update' THEN
    operation := 'update'::puls_integration.connector_apply_operation;
    risk_class := 'guarded_overwrite'::puls_integration.connector_apply_risk_class;
    blocked := TRUE;
    risk_reasons := ARRAY['blocked_update_requires_policy']::TEXT[];
    audit_tiers := ARRAY[
      'object_event'::puls_integration.connector_apply_audit_tier,
      'field_diff'::puls_integration.connector_apply_audit_tier,
      'rollback_snapshot'::puls_integration.connector_apply_audit_tier
    ];
    retention_bucket := 'field_diff';
    rollback_snapshot_required := TRUE;
  ELSIF v_class.action = 'skip' AND v_class.skip_code = 'LOWER_PRIORITY_SOURCE_SKIPPED' THEN
    operation := NULL;
    risk_class := 'source_conflict'::puls_integration.connector_apply_risk_class;
    blocked := TRUE;
    risk_reasons := ARRAY['source_priority_conflict']::TEXT[];
    audit_tiers := ARRAY['object_event'::puls_integration.connector_apply_audit_tier];
    retention_bucket := 'object_event';
    rollback_snapshot_required := FALSE;
  ELSE
    operation := NULL;
    risk_class := 'no_change_skip'::puls_integration.connector_apply_risk_class;
    blocked := FALSE;
    risk_reasons := ARRAY['unchanged_row_hash']::TEXT[];
    audit_tiers := ARRAY['object_event'::puls_integration.connector_apply_audit_tier];
    retention_bucket := 'object_event';
    rollback_snapshot_required := FALSE;
  END IF;

  safe_diff_summary := jsonb_build_object(
    'target_schema', 'puls_core',
    'target_table', v_target_table,
    'field_count', COALESCE(array_length(v_safe_fields, 1), 0),
    'destructive_field_count', COALESCE(array_length(v_destructive_fields, 1), 0),
    'value_readback', FALSE,
    'canonical_write', FALSE,
    'source_writeback', FALSE,
    'credential_readback', FALSE
  );

  RETURN NEXT;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration.create_connector_apply_change_set(
  p_batch_id UUID
)
RETURNS TABLE (
  id UUID,
  tenant_id UUID,
  connection_id UUID,
  source_namespace_id UUID,
  import_batch_id UUID,
  status puls_integration.connector_apply_change_set_status,
  source_checksum TEXT,
  change_set_checksum TEXT,
  previewed_at TIMESTAMPTZ,
  row_count INTEGER,
  create_count INTEGER,
  update_count INTEGER,
  skip_count INTEGER,
  blocked_count INTEGER,
  stale_count INTEGER,
  destructive_count INTEGER,
  source_conflict_count INTEGER,
  guarded_update_count INTEGER,
  no_change_count INTEGER,
  execution_enabled BOOLEAN,
  canonical_write_enabled BOOLEAN,
  source_writeback_enabled BOOLEAN,
  credential_readback_enabled BOOLEAN,
  approval_required BOOLEAN,
  safe_summary JSONB,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_tenant_id UUID := puls_core.current_tenant_id();
  v_batch puls_integration.import_batches;
  v_namespace puls_integration.source_namespaces;
  v_connection_id UUID;
  v_existing puls_integration.connector_apply_change_sets;
  v_change_set_id UUID;
  v_checksum TEXT;
  v_status puls_integration.connector_apply_change_set_status;
  v_actor_employee_id UUID;
  v_rec puls_integration.import_records;
  v_item RECORD;
  v_create_count INTEGER := 0;
  v_update_count INTEGER := 0;
  v_skip_count INTEGER := 0;
  v_blocked_count INTEGER := 0;
  v_stale_count INTEGER := 0;
  v_destructive_count INTEGER := 0;
  v_source_conflict_count INTEGER := 0;
  v_guarded_update_count INTEGER := 0;
  v_no_change_count INTEGER := 0;
  v_row_count INTEGER := 0;
  v_safe_summary JSONB;
BEGIN
  IF auth.role() <> 'service_role' AND NOT puls_core.is_admin() THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_APPLY_CHANGE_SET_ADMIN_REQUIRED: admin permission is required.';
  END IF;

  IF auth.role() <> 'service_role' AND v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_APPLY_CHANGE_SET_TENANT_REQUIRED: authenticated caller has no tenant context.';
  END IF;

  v_batch := puls_integration._import_lock_batch(p_batch_id);

  IF auth.role() <> 'service_role' AND v_batch.tenant_id <> v_tenant_id THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_APPLY_CHANGE_SET_FORBIDDEN: batch belongs to another tenant.';
  END IF;

  IF v_batch.mode <> 'dry_run'::puls_integration.import_batch_mode THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_APPLY_CHANGE_SET_DRY_RUN_REQUIRED: change-set requires a dry_run batch.';
  END IF;

  IF v_batch.status <> 'previewed'::puls_integration.import_batch_status THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_APPLY_CHANGE_SET_PREVIEW_REQUIRED: batch must be previewed before change-set generation.';
  END IF;

  IF COALESCE(v_batch.error_count, 0) > 0 THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_APPLY_CHANGE_SET_ROW_ERRORS: batch has row errors.';
  END IF;

  IF v_batch.source_checksum IS NULL OR btrim(v_batch.source_checksum) = '' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_APPLY_CHANGE_SET_CHECKSUM_REQUIRED: batch source checksum is required.';
  END IF;

  IF v_batch.previewed_at IS NULL THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_APPLY_CHANGE_SET_PREVIEW_REQUIRED: batch preview timestamp is required.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM puls_integration.import_records ir
    WHERE ir.batch_id = p_batch_id
      AND (
        ir.status <> 'validated'::puls_integration.import_record_status
        OR ir.preview_action IS NULL
        OR ir.previewed_at IS NULL
      )
  ) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_APPLY_CHANGE_SET_PREVIEW_REQUIRED: all rows must be validated and previewed.';
  END IF;

  SELECT sn.* INTO v_namespace
  FROM puls_integration.source_namespaces sn
  WHERE sn.id = v_batch.source_namespace_id
    AND sn.tenant_id = v_batch.tenant_id;

  IF v_namespace.id IS NULL THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_APPLY_CHANGE_SET_NAMESPACE_REQUIRED: source namespace is missing.';
  END IF;

  v_connection_id := v_namespace.connection_id;
  v_checksum := puls_integration._connector_apply_change_set_checksum(
    p_batch_id,
    v_batch.source_checksum
  );

  SELECT cs.* INTO v_existing
  FROM puls_integration.connector_apply_change_sets cs
  WHERE cs.import_batch_id = p_batch_id
    AND cs.source_checksum = v_batch.source_checksum;

  IF v_existing.id IS NOT NULL THEN
    RETURN QUERY
    SELECT
      cs.id,
      cs.tenant_id,
      cs.connection_id,
      cs.source_namespace_id,
      cs.import_batch_id,
      cs.status,
      cs.source_checksum,
      cs.change_set_checksum,
      cs.previewed_at,
      cs.row_count,
      cs.create_count,
      cs.update_count,
      cs.skip_count,
      cs.blocked_count,
      cs.stale_count,
      cs.destructive_count,
      cs.source_conflict_count,
      cs.guarded_update_count,
      cs.no_change_count,
      cs.execution_enabled,
      cs.canonical_write_enabled,
      cs.source_writeback_enabled,
      cs.credential_readback_enabled,
      cs.approval_required,
      cs.safe_summary,
      cs.created_at
    FROM puls_integration.connector_apply_change_sets cs
    WHERE cs.id = v_existing.id;
    RETURN;
  END IF;

  DROP TABLE IF EXISTS tmp_connector_apply_change_set_items;
  CREATE TEMP TABLE tmp_connector_apply_change_set_items (
    import_record_id UUID,
    row_number INTEGER,
    entity_type puls_integration.import_entity_type,
    external_id TEXT,
    target_table TEXT,
    canonical_id UUID,
    operation puls_integration.connector_apply_operation,
    risk_class puls_integration.connector_apply_risk_class,
    blocked BOOLEAN,
    risk_reasons TEXT[],
    audit_tiers puls_integration.connector_apply_audit_tier[],
    retention_bucket TEXT,
    source_row_hash TEXT,
    expected_current_hash TEXT,
    current_action TEXT,
    current_skip_code TEXT,
    preview_action TEXT,
    preview_skip_code TEXT,
    previewed_at TIMESTAMPTZ,
    safe_field_names TEXT[],
    destructive_field_names TEXT[],
    safe_diff_summary JSONB,
    rollback_snapshot_required BOOLEAN
  ) ON COMMIT DROP;

  FOR v_rec IN
    SELECT ir.*
    FROM puls_integration.import_records ir
    WHERE ir.batch_id = p_batch_id
    ORDER BY ir.row_number
  LOOP
    SELECT *
    INTO v_item
    FROM puls_integration._connector_apply_classify_change_set_item(
      v_batch.tenant_id,
      v_batch.source_namespace_id,
      v_namespace.priority_rank,
      v_rec
    );

    INSERT INTO tmp_connector_apply_change_set_items (
      import_record_id,
      row_number,
      entity_type,
      external_id,
      target_table,
      canonical_id,
      operation,
      risk_class,
      blocked,
      risk_reasons,
      audit_tiers,
      retention_bucket,
      source_row_hash,
      expected_current_hash,
      current_action,
      current_skip_code,
      preview_action,
      preview_skip_code,
      previewed_at,
      safe_field_names,
      destructive_field_names,
      safe_diff_summary,
      rollback_snapshot_required
    )
    VALUES (
      v_rec.id,
      v_rec.row_number,
      v_rec.entity_type,
      v_rec.external_id,
      puls_integration._import_canonical_table(v_rec.entity_type),
      v_item.canonical_id,
      v_item.operation,
      v_item.risk_class,
      v_item.blocked,
      v_item.risk_reasons,
      v_item.audit_tiers,
      v_item.retention_bucket,
      v_rec.row_hash,
      v_item.expected_current_hash,
      v_item.current_action,
      v_item.current_skip_code,
      v_rec.preview_action,
      v_rec.preview_skip_code,
      v_rec.previewed_at,
      v_item.safe_field_names,
      v_item.destructive_field_names,
      v_item.safe_diff_summary,
      v_item.rollback_snapshot_required
    );
  END LOOP;

  SELECT
    COUNT(*)::INTEGER,
    COUNT(*) FILTER (WHERE operation = 'insert')::INTEGER,
    COUNT(*) FILTER (WHERE operation = 'update')::INTEGER,
    COUNT(*) FILTER (WHERE operation IS NULL)::INTEGER,
    COUNT(*) FILTER (WHERE blocked)::INTEGER,
    COUNT(*) FILTER (WHERE risk_class = 'stale_preview')::INTEGER,
    COUNT(*) FILTER (WHERE risk_class = 'destructive_equivalent')::INTEGER,
    COUNT(*) FILTER (WHERE risk_class = 'source_conflict')::INTEGER,
    COUNT(*) FILTER (WHERE risk_class = 'guarded_overwrite')::INTEGER,
    COUNT(*) FILTER (WHERE risk_class = 'no_change_skip')::INTEGER
  INTO
    v_row_count,
    v_create_count,
    v_update_count,
    v_skip_count,
    v_blocked_count,
    v_stale_count,
    v_destructive_count,
    v_source_conflict_count,
    v_guarded_update_count,
    v_no_change_count
  FROM tmp_connector_apply_change_set_items;

  v_status := CASE
    WHEN v_blocked_count = 0 THEN 'ready_for_create_only_review'::puls_integration.connector_apply_change_set_status
    ELSE 'blocked'::puls_integration.connector_apply_change_set_status
  END;
  v_safe_summary := jsonb_build_object(
    'contract_version', 'pr16.2-apply-change-set-v1',
    'row_count', v_row_count,
    'create_count', v_create_count,
    'update_count', v_update_count,
    'skip_count', v_skip_count,
    'blocked_count', v_blocked_count,
    'stale_count', v_stale_count,
    'destructive_count', v_destructive_count,
    'source_conflict_count', v_source_conflict_count,
    'guarded_update_count', v_guarded_update_count,
    'no_change_count', v_no_change_count,
    'execution_enabled', FALSE,
    'canonical_write_enabled', FALSE,
    'source_writeback_enabled', FALSE,
    'credential_readback_enabled', FALSE,
    'raw_payload_readback', FALSE,
    'field_value_readback', FALSE,
    'next_action_key', CASE
      WHEN v_blocked_count = 0 THEN 'review_create_only_change_set'
      ELSE 'resolve_change_set_blockers'
    END
  );
  v_actor_employee_id := CASE
    WHEN auth.role() = 'service_role' THEN NULL
    ELSE puls_core.current_employee_id()
  END;

  INSERT INTO puls_integration.connector_apply_change_sets AS change_set (
    tenant_id,
    connection_id,
    source_namespace_id,
    import_batch_id,
    status,
    source_checksum,
    change_set_checksum,
    previewed_at,
    row_count,
    create_count,
    update_count,
    skip_count,
    blocked_count,
    stale_count,
    destructive_count,
    source_conflict_count,
    guarded_update_count,
    no_change_count,
    safe_summary,
    created_by_employee_id
  )
  VALUES (
    v_batch.tenant_id,
    v_connection_id,
    v_batch.source_namespace_id,
    p_batch_id,
    v_status,
    v_batch.source_checksum,
    v_checksum,
    v_batch.previewed_at,
    v_row_count,
    v_create_count,
    v_update_count,
    v_skip_count,
    v_blocked_count,
    v_stale_count,
    v_destructive_count,
    v_source_conflict_count,
    v_guarded_update_count,
    v_no_change_count,
    v_safe_summary,
    v_actor_employee_id
  )
  RETURNING change_set.id INTO v_change_set_id;

  INSERT INTO puls_integration.connector_apply_change_set_items (
    tenant_id,
    change_set_id,
    import_batch_id,
    import_record_id,
    row_number,
    entity_type,
    external_id,
    target_table,
    canonical_id,
    operation,
    risk_class,
    blocked,
    risk_reasons,
    audit_tiers,
    retention_bucket,
    source_row_hash,
    expected_current_hash,
    current_action,
    current_skip_code,
    preview_action,
    preview_skip_code,
    previewed_at,
    safe_field_names,
    destructive_field_names,
    safe_diff_summary,
    rollback_snapshot_required
  )
  SELECT
    v_batch.tenant_id,
    v_change_set_id,
    p_batch_id,
    tmp.import_record_id,
    tmp.row_number,
    tmp.entity_type,
    tmp.external_id,
    tmp.target_table,
    tmp.canonical_id,
    tmp.operation,
    tmp.risk_class,
    tmp.blocked,
    tmp.risk_reasons,
    tmp.audit_tiers,
    tmp.retention_bucket,
    tmp.source_row_hash,
    tmp.expected_current_hash,
    tmp.current_action,
    tmp.current_skip_code,
    tmp.preview_action,
    tmp.preview_skip_code,
    tmp.previewed_at,
    tmp.safe_field_names,
    tmp.destructive_field_names,
    tmp.safe_diff_summary,
    tmp.rollback_snapshot_required
  FROM tmp_connector_apply_change_set_items tmp
  ORDER BY tmp.row_number;

  RETURN QUERY
  SELECT
    cs.id,
    cs.tenant_id,
    cs.connection_id,
    cs.source_namespace_id,
    cs.import_batch_id,
    cs.status,
    cs.source_checksum,
    cs.change_set_checksum,
    cs.previewed_at,
    cs.row_count,
    cs.create_count,
    cs.update_count,
    cs.skip_count,
    cs.blocked_count,
    cs.stale_count,
    cs.destructive_count,
    cs.source_conflict_count,
    cs.guarded_update_count,
    cs.no_change_count,
    cs.execution_enabled,
    cs.canonical_write_enabled,
    cs.source_writeback_enabled,
    cs.credential_readback_enabled,
    cs.approval_required,
    cs.safe_summary,
    cs.created_at
  FROM puls_integration.connector_apply_change_sets cs
  WHERE cs.id = v_change_set_id;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration.list_connector_apply_change_set_summaries(
  p_batch_id UUID DEFAULT NULL,
  p_connection_id UUID DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  tenant_id UUID,
  connection_id UUID,
  source_namespace_id UUID,
  import_batch_id UUID,
  status puls_integration.connector_apply_change_set_status,
  source_checksum TEXT,
  change_set_checksum TEXT,
  previewed_at TIMESTAMPTZ,
  row_count INTEGER,
  create_count INTEGER,
  update_count INTEGER,
  skip_count INTEGER,
  blocked_count INTEGER,
  stale_count INTEGER,
  destructive_count INTEGER,
  source_conflict_count INTEGER,
  guarded_update_count INTEGER,
  no_change_count INTEGER,
  execution_enabled BOOLEAN,
  canonical_write_enabled BOOLEAN,
  source_writeback_enabled BOOLEAN,
  credential_readback_enabled BOOLEAN,
  approval_required BOOLEAN,
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
  v_tenant_id UUID := puls_core.current_tenant_id();
BEGIN
  IF auth.role() <> 'service_role' AND NOT puls_integration.is_import_metadata_reader() THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    cs.id,
    cs.tenant_id,
    cs.connection_id,
    cs.source_namespace_id,
    cs.import_batch_id,
    cs.status,
    cs.source_checksum,
    cs.change_set_checksum,
    cs.previewed_at,
    cs.row_count,
    cs.create_count,
    cs.update_count,
    cs.skip_count,
    cs.blocked_count,
    cs.stale_count,
    cs.destructive_count,
    cs.source_conflict_count,
    cs.guarded_update_count,
    cs.no_change_count,
    cs.execution_enabled,
    cs.canonical_write_enabled,
    cs.source_writeback_enabled,
    cs.credential_readback_enabled,
    cs.approval_required,
    cs.safe_summary,
    COALESCE(samples.sample_items, '[]'::JSONB) AS sample_items,
    cs.created_at
  FROM puls_integration.connector_apply_change_sets cs
  LEFT JOIN LATERAL (
    SELECT jsonb_agg(
      jsonb_build_object(
        'id', item.id,
        'row_number', item.row_number,
        'entity_type', item.entity_type,
        'external_id', item.external_id,
        'target_table', item.target_table,
        'operation', item.operation,
        'risk_class', item.risk_class,
        'blocked', item.blocked,
        'risk_reasons', item.risk_reasons,
        'audit_tiers', item.audit_tiers,
        'retention_bucket', item.retention_bucket,
        'expected_current_hash_available', item.expected_current_hash IS NOT NULL,
        'safe_field_names', item.safe_field_names,
        'destructive_field_names', item.destructive_field_names,
        'rollback_snapshot_required', item.rollback_snapshot_required
      )
      ORDER BY item.row_number
    ) AS sample_items
    FROM (
      SELECT csi.*
      FROM puls_integration.connector_apply_change_set_items csi
      WHERE csi.change_set_id = cs.id
      ORDER BY csi.blocked DESC, csi.row_number
      LIMIT 8
    ) item
  ) samples ON TRUE
  WHERE (auth.role() = 'service_role' OR cs.tenant_id = v_tenant_id)
    AND (p_batch_id IS NULL OR cs.import_batch_id = p_batch_id)
    AND (p_connection_id IS NULL OR cs.connection_id = p_connection_id)
  ORDER BY cs.created_at DESC;
END;
$$;

ALTER TABLE puls_integration.connector_apply_change_sets ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_integration.connector_apply_change_set_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS puls_integration_apply_change_sets_select
  ON puls_integration.connector_apply_change_sets;
CREATE POLICY puls_integration_apply_change_sets_select
  ON puls_integration.connector_apply_change_sets
  FOR SELECT
  USING (
    puls_integration.is_import_metadata_reader()
    AND tenant_id = puls_core.current_tenant_id()
  );

DROP POLICY IF EXISTS puls_integration_apply_change_set_items_select
  ON puls_integration.connector_apply_change_set_items;
CREATE POLICY puls_integration_apply_change_set_items_select
  ON puls_integration.connector_apply_change_set_items
  FOR SELECT
  USING (
    puls_integration.is_import_metadata_reader()
    AND tenant_id = puls_core.current_tenant_id()
  );

GRANT SELECT ON puls_integration.connector_apply_change_sets TO authenticated;
GRANT SELECT ON puls_integration.connector_apply_change_set_items TO authenticated;

REVOKE ALL ON FUNCTION puls_integration.reject_connector_apply_change_set_mutation()
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.reject_connector_apply_change_set_mutation()
  TO service_role;

REVOKE ALL ON FUNCTION puls_integration._connector_apply_destructive_field_names(JSONB)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration._connector_apply_destructive_field_names(JSONB)
  TO service_role;

REVOKE ALL ON FUNCTION puls_integration._connector_apply_safe_field_names(JSONB)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration._connector_apply_safe_field_names(JSONB)
  TO service_role;

REVOKE ALL ON FUNCTION puls_integration._connector_apply_expected_current_hash(
  UUID,
  UUID,
  puls_integration.import_entity_type,
  TEXT,
  UUID
) FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration._connector_apply_expected_current_hash(
  UUID,
  UUID,
  puls_integration.import_entity_type,
  TEXT,
  UUID
) TO service_role;

REVOKE ALL ON FUNCTION puls_integration._connector_apply_change_set_checksum(UUID, TEXT)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration._connector_apply_change_set_checksum(UUID, TEXT)
  TO service_role;

REVOKE ALL ON FUNCTION puls_integration._connector_apply_classify_change_set_item(
  UUID,
  UUID,
  INTEGER,
  puls_integration.import_records
) FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration._connector_apply_classify_change_set_item(
  UUID,
  UUID,
  INTEGER,
  puls_integration.import_records
) TO service_role;

REVOKE ALL ON FUNCTION puls_integration.create_connector_apply_change_set(UUID)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.create_connector_apply_change_set(UUID)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_integration.list_connector_apply_change_set_summaries(UUID, UUID)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.list_connector_apply_change_set_summaries(UUID, UUID)
  TO authenticated, service_role;

COMMENT ON TYPE puls_integration.connector_apply_change_set_status IS
  'PR16.2 change-set status. Does not represent executable apply state.';

COMMENT ON TYPE puls_integration.connector_apply_risk_class IS
  'PR16.2 safe risk classes for create-only, guarded overwrite, destructive-equivalent, source conflict, stale preview, rollback, and no-change skip decisions.';

COMMENT ON FUNCTION puls_integration.create_connector_apply_change_set(UUID) IS
  'Creates immutable PR16.2 apply change-set evidence from a previewed dry-run batch. No canonical write, import_apply job, source writeback, credential readback, raw payload readback, or AI action is opened.';

COMMENT ON FUNCTION puls_integration.list_connector_apply_change_set_summaries(UUID, UUID) IS
  'Authenticated-safe PR16.2 change-set read model with counters and sample item risk metadata only.';
