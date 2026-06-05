-- PR16.3 create-only worker apply.
-- Opens the first canonical write path only for worker-owned create-only reference data.
-- Browser/direct apply, overwrite/update/delete, ERP writeback, provider API calls,
-- credential readback, and raw payload readback remain closed.

CREATE TABLE IF NOT EXISTS puls_integration.connector_apply_object_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  connection_id UUID NULL REFERENCES puls_integration.erp_connections(id) ON DELETE SET NULL,
  source_namespace_id UUID NOT NULL REFERENCES puls_integration.source_namespaces(id) ON DELETE RESTRICT,
  import_batch_id UUID NOT NULL REFERENCES puls_integration.import_batches(id) ON DELETE RESTRICT,
  change_set_id UUID NOT NULL REFERENCES puls_integration.connector_apply_change_sets(id) ON DELETE RESTRICT,
  change_set_item_id UUID NOT NULL REFERENCES puls_integration.connector_apply_change_set_items(id) ON DELETE RESTRICT,
  import_record_id UUID NOT NULL REFERENCES puls_integration.import_records(id) ON DELETE RESTRICT,
  connector_job_id UUID NOT NULL REFERENCES puls_integration.connector_jobs(id) ON DELETE RESTRICT,
  operation puls_integration.connector_apply_operation NOT NULL DEFAULT 'insert',
  entity_type puls_integration.import_entity_type NOT NULL,
  external_id TEXT NOT NULL,
  target_schema TEXT NOT NULL DEFAULT 'puls_core',
  target_table TEXT NOT NULL,
  canonical_id UUID NOT NULL,
  source_row_hash TEXT NOT NULL,
  change_set_checksum TEXT NOT NULL,
  audit_tiers puls_integration.connector_apply_audit_tier[] NOT NULL DEFAULT ARRAY[
    'object_event'::puls_integration.connector_apply_audit_tier
  ],
  retention_bucket TEXT NOT NULL DEFAULT 'object_event',
  safe_summary JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_by_worker_id TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (operation = 'insert'::puls_integration.connector_apply_operation),
  CHECK (external_id <> ''),
  CHECK (target_schema = 'puls_core'),
  CHECK (target_table <> ''),
  CHECK (source_row_hash <> ''),
  CHECK (change_set_checksum <> ''),
  CHECK (retention_bucket = 'object_event'),
  CHECK (jsonb_typeof(safe_summary) = 'object'),
  CHECK (puls_integration.connector_safe_context_has_blocked_key(safe_summary) IS FALSE),
  UNIQUE (change_set_id, import_record_id)
);

CREATE INDEX IF NOT EXISTS idx_puls_integration_apply_object_events_tenant_created
  ON puls_integration.connector_apply_object_events (tenant_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_puls_integration_apply_object_events_change_set
  ON puls_integration.connector_apply_object_events (change_set_id, created_at ASC);

CREATE OR REPLACE FUNCTION puls_integration._connector_apply_is_create_only_reference_entity(
  p_entity_type puls_integration.import_entity_type
)
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog, puls_integration
AS $$
  -- PR16.3 intentionally excludes employee, assignment, update, delete, and rollback scope.
  SELECT p_entity_type IN (
    'legal_entity'::puls_integration.import_entity_type,
    'location'::puls_integration.import_entity_type,
    'cost_center'::puls_integration.import_entity_type,
    'department'::puls_integration.import_entity_type,
    'position'::puls_integration.import_entity_type
  );
$$;

CREATE OR REPLACE FUNCTION puls_integration._connector_apply_create_only_field_allowed(
  p_entity_type puls_integration.import_entity_type,
  p_field_name TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog, puls_integration
AS $$
  SELECT CASE p_entity_type
    WHEN 'legal_entity'::puls_integration.import_entity_type THEN
      p_field_name IN ('code', 'name', 'is_active')
    WHEN 'location'::puls_integration.import_entity_type THEN
      p_field_name IN (
        'code',
        'name',
        'is_active',
        'legal_entity_code',
        'legal_entity_external_id'
      )
    WHEN 'cost_center'::puls_integration.import_entity_type THEN
      p_field_name IN (
        'code',
        'name',
        'is_active',
        'legal_entity_code',
        'legal_entity_external_id',
        'parent_cost_center_code',
        'parent_cost_center_external_id'
      )
    WHEN 'department'::puls_integration.import_entity_type THEN
      p_field_name IN (
        'code',
        'name',
        'is_active',
        'cost_center_code',
        'cost_center_external_id',
        'parent_department_code',
        'parent_department_external_id'
      )
    WHEN 'position'::puls_integration.import_entity_type THEN
      p_field_name IN (
        'code',
        'name',
        'is_active',
        'department_code',
        'department_external_id',
        'parent_position_code',
        'parent_position_external_id',
        'level',
        'norm_headcount',
        'employment_type'
      )
    ELSE FALSE
  END;
$$;

CREATE OR REPLACE FUNCTION puls_integration._connector_apply_has_batch_admin_approval(
  p_change_set_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM puls_integration.connector_apply_change_sets cs
    JOIN puls_integration.erp_sync_batches esb
      ON esb.tenant_id = cs.tenant_id
     AND esb.connection_id = cs.connection_id
    WHERE cs.id = p_change_set_id
      AND esb.sync_type = 'import_apply_review'
      AND esb.event_key = 'import_apply_approval_recorded'
      AND esb.status = 'success'::puls_integration.sync_status
      AND esb.created_at >= cs.previewed_at
  );
$$;

CREATE OR REPLACE FUNCTION puls_integration._connector_apply_validate_create_only_change_set(
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
BEGIN
  SELECT *
  INTO v_change_set
  FROM puls_integration.connector_apply_change_sets cs
  WHERE cs.id = p_change_set_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_CHANGE_SET_NOT_FOUND: change-set not found.';
  END IF;

  SELECT *
  INTO v_batch
  FROM puls_integration.import_batches ib
  WHERE ib.id = v_change_set.import_batch_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_BATCH_NOT_FOUND: import batch not found.';
  END IF;

  IF v_batch.tenant_id IS DISTINCT FROM v_change_set.tenant_id THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_TENANT_MISMATCH: batch and change-set tenant mismatch.';
  END IF;

  IF v_batch.status <> 'previewed'::puls_integration.import_batch_status THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_PREVIEW_REQUIRED: batch must be previewed.';
  END IF;

  IF v_batch.mode <> 'dry_run'::puls_integration.import_batch_mode THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_DRY_RUN_REQUIRED: create-only apply requires dry-run evidence.';
  END IF;

  IF COALESCE(v_batch.error_count, 0) > 0 THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_ROW_ERRORS: batch has row errors.';
  END IF;

  IF v_batch.source_checksum IS DISTINCT FROM v_change_set.source_checksum THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_CHECKSUM_MISMATCH: source checksum does not match change-set.';
  END IF;

  IF v_change_set.status <> 'ready_for_create_only_review'::puls_integration.connector_apply_change_set_status THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_CHANGE_SET_NOT_READY: change-set is not ready.';
  END IF;

  IF v_change_set.row_count <= 0 OR v_change_set.create_count <> v_change_set.row_count THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_CREATE_ROWS_REQUIRED: all rows must be create candidates.';
  END IF;

  IF (
    SELECT COUNT(*)::INTEGER
    FROM puls_integration.connector_apply_change_set_items item
    WHERE item.change_set_id = p_change_set_id
  ) <> v_change_set.row_count THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_ITEM_COUNT_MISMATCH: change-set item count must match row count.';
  END IF;

  IF COALESCE(v_change_set.update_count, 0) <> 0
     OR COALESCE(v_change_set.skip_count, 0) <> 0
     OR COALESCE(v_change_set.blocked_count, 0) <> 0
     OR COALESCE(v_change_set.stale_count, 0) <> 0
     OR COALESCE(v_change_set.destructive_count, 0) <> 0
     OR COALESCE(v_change_set.source_conflict_count, 0) <> 0
     OR COALESCE(v_change_set.guarded_update_count, 0) <> 0
     OR COALESCE(v_change_set.no_change_count, 0) <> 0 THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_BLOCKERS_PRESENT: change-set has non-create rows or blockers.';
  END IF;

  IF NOT puls_integration._connector_apply_has_batch_admin_approval(p_change_set_id) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_APPROVAL_REQUIRED: admin approval is required before enqueue.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM puls_integration.connector_apply_change_set_items item
    WHERE item.change_set_id = p_change_set_id
      AND (
        item.operation IS DISTINCT FROM 'insert'::puls_integration.connector_apply_operation
        OR item.risk_class IS DISTINCT FROM 'create_only'::puls_integration.connector_apply_risk_class
        OR item.blocked IS TRUE
        OR item.canonical_id IS NOT NULL
        OR item.current_action IS DISTINCT FROM 'create'
        OR item.preview_action IS DISTINCT FROM 'create'
        OR NOT puls_integration._connector_apply_is_create_only_reference_entity(item.entity_type)
      )
  ) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_ITEM_SCOPE_INVALID: all items must be unblocked reference inserts.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM puls_integration.connector_apply_change_set_items item
    CROSS JOIN LATERAL unnest(item.safe_field_names) AS fields(field_name)
    WHERE item.change_set_id = p_change_set_id
      AND NOT puls_integration._connector_apply_create_only_field_allowed(
        item.entity_type,
        fields.field_name
      )
  ) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_FIELD_SCOPE_INVALID: change-set contains fields outside PR16.3 create-only scope.';
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

  IF v_contract IS DISTINCT FROM 'pr16.3-create-only-worker-apply-v1'
     OR v_mode IS DISTINCT FROM 'create_only' THEN
    RAISE EXCEPTION
      'PULS_CONNECTOR_IMPORT_APPLY_CLOSED: import_apply is closed except PR16.3 create-only worker apply jobs.';
  END IF;

  IF NEW.connection_id IS NULL OR NEW.source_namespace_id IS NULL OR NEW.import_batch_id IS NULL THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_JOB_SCOPE_REQUIRED: connection, namespace, and batch are required.';
  END IF;

  IF NEW.max_attempts <> 1 THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_SINGLE_ATTEMPT_REQUIRED: create-only apply jobs require max_attempts = 1.';
  END IF;

  IF COALESCE(NEW.safe_error_context ->> 'canonical_write_enabled', 'false') <> 'true'
     OR COALESCE(NEW.safe_error_context ->> 'source_writeback_enabled', 'true') <> 'false'
     OR COALESCE(NEW.safe_error_context ->> 'credential_readback_enabled', 'true') <> 'false'
     OR COALESCE(NEW.safe_error_context ->> 'provider_api_calls', 'true') <> 'false' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_BOUNDARY_INVALID: create-only apply boundaries are invalid.';
  END IF;

  IF v_change_set_id_text IS NULL
     OR v_change_set_id_text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_CHANGE_SET_REQUIRED: valid change_set_id is required.';
  END IF;

  v_change_set_id := v_change_set_id_text::UUID;
  PERFORM puls_integration._connector_apply_validate_create_only_change_set(v_change_set_id);

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
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_JOB_CONTEXT_MISMATCH: job context does not match change-set.';
  END IF;

  RETURN NEW;
END;
$$;

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
  v_tenant_id UUID := puls_core.current_tenant_id();
  v_change_set puls_integration.connector_apply_change_sets;
  v_job_id UUID;
BEGIN
  IF auth.role() <> 'service_role' AND NOT puls_core.is_admin() THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_ADMIN_REQUIRED: admin permission is required.';
  END IF;

  IF auth.role() <> 'service_role' AND v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_TENANT_REQUIRED: authenticated caller has no tenant context.';
  END IF;

  PERFORM puls_integration._connector_apply_validate_create_only_change_set(p_change_set_id);

  SELECT *
  INTO v_change_set
  FROM puls_integration.connector_apply_change_sets cs
  WHERE cs.id = p_change_set_id;

  IF auth.role() <> 'service_role' AND v_change_set.tenant_id IS DISTINCT FROM v_tenant_id THEN
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
    CASE WHEN auth.role() = 'service_role' THEN v_change_set.tenant_id ELSE NULL END
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

CREATE OR REPLACE FUNCTION puls_integration._connector_apply_insert_reference_record(
  p_batch puls_integration.import_batches,
  p_namespace puls_integration.source_namespaces,
  p_record puls_integration.import_records
)
RETURNS UUID
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_payload JSONB := p_record.normalized_payload;
  v_target UUID;
  v_target_err TEXT;
  v_canonical_id UUID;
  v_is_active BOOLEAN;
  v_le_id UUID;
  v_cc_id UUID;
  v_dept_id UUID;
  v_parent_id UUID;
BEGIN
  SELECT t.canonical_id, t.error_code
  INTO v_target, v_target_err
  FROM puls_integration._import_resolve_entity_target(
    p_batch.tenant_id,
    p_batch.source_namespace_id,
    p_record.entity_type,
    p_record.external_id,
    v_payload
  ) t;

  IF v_target_err IS NOT NULL THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_TARGET_AMBIGUOUS: ambiguous target on row %.', p_record.row_number;
  END IF;

  IF v_target IS NOT NULL THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_TARGET_EXISTS: row % resolves to an existing target.', p_record.row_number;
  END IF;

  v_is_active := COALESCE(NULLIF(v_payload ->> 'is_active', '')::BOOLEAN, TRUE);

  IF p_record.entity_type = 'legal_entity'::puls_integration.import_entity_type THEN
    INSERT INTO puls_core.legal_entities (
      tenant_id,
      code,
      name,
      is_active,
      source_namespace_id,
      external_id
    )
    VALUES (
      p_batch.tenant_id,
      v_payload ->> 'code',
      v_payload ->> 'name',
      v_is_active,
      p_batch.source_namespace_id,
      p_record.external_id
    )
    RETURNING id INTO v_canonical_id;
  ELSIF p_record.entity_type = 'location'::puls_integration.import_entity_type THEN
    v_le_id := puls_integration._import_resolve_ref_at_apply(
      p_batch.tenant_id,
      p_batch.source_namespace_id,
      p_batch.id,
      'legal_entity'::puls_integration.import_entity_type,
      v_payload ->> 'legal_entity_external_id',
      v_payload ->> 'legal_entity_code'
    );
    IF v_le_id IS NULL THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_REFERENCE_UNRESOLVED: unresolved legal_entity for row %.', p_record.row_number;
    END IF;

    INSERT INTO puls_core.locations (
      tenant_id,
      legal_entity_id,
      code,
      name,
      is_active,
      source_namespace_id,
      external_id
    )
    VALUES (
      p_batch.tenant_id,
      v_le_id,
      v_payload ->> 'code',
      v_payload ->> 'name',
      v_is_active,
      p_batch.source_namespace_id,
      p_record.external_id
    )
    RETURNING id INTO v_canonical_id;
  ELSIF p_record.entity_type = 'cost_center'::puls_integration.import_entity_type THEN
    v_le_id := puls_integration._import_resolve_ref_at_apply(
      p_batch.tenant_id,
      p_batch.source_namespace_id,
      p_batch.id,
      'legal_entity'::puls_integration.import_entity_type,
      v_payload ->> 'legal_entity_external_id',
      v_payload ->> 'legal_entity_code'
    );
    IF v_le_id IS NULL THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_REFERENCE_UNRESOLVED: unresolved legal_entity for row %.', p_record.row_number;
    END IF;

    v_parent_id := puls_integration._import_resolve_ref_at_apply(
      p_batch.tenant_id,
      p_batch.source_namespace_id,
      p_batch.id,
      'cost_center'::puls_integration.import_entity_type,
      v_payload ->> 'parent_cost_center_external_id',
      v_payload ->> 'parent_cost_center_code'
    );

    IF (v_payload ? 'parent_cost_center_external_id' OR v_payload ? 'parent_cost_center_code')
       AND v_parent_id IS NULL THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_REFERENCE_UNRESOLVED: unresolved parent cost_center for row %.', p_record.row_number;
    END IF;

    INSERT INTO puls_core.cost_centers (
      tenant_id,
      legal_entity_id,
      parent_cost_center_id,
      code,
      name,
      is_active,
      source_namespace_id,
      external_id
    )
    VALUES (
      p_batch.tenant_id,
      v_le_id,
      v_parent_id,
      v_payload ->> 'code',
      v_payload ->> 'name',
      v_is_active,
      p_batch.source_namespace_id,
      p_record.external_id
    )
    RETURNING id INTO v_canonical_id;
  ELSIF p_record.entity_type = 'department'::puls_integration.import_entity_type THEN
    v_cc_id := puls_integration._import_resolve_ref_at_apply(
      p_batch.tenant_id,
      p_batch.source_namespace_id,
      p_batch.id,
      'cost_center'::puls_integration.import_entity_type,
      v_payload ->> 'cost_center_external_id',
      v_payload ->> 'cost_center_code'
    );

    IF (v_payload ? 'cost_center_external_id' OR v_payload ? 'cost_center_code')
       AND v_cc_id IS NULL THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_REFERENCE_UNRESOLVED: unresolved cost_center for row %.', p_record.row_number;
    END IF;

    v_parent_id := puls_integration._import_resolve_ref_at_apply(
      p_batch.tenant_id,
      p_batch.source_namespace_id,
      p_batch.id,
      'department'::puls_integration.import_entity_type,
      v_payload ->> 'parent_department_external_id',
      v_payload ->> 'parent_department_code'
    );

    IF (v_payload ? 'parent_department_external_id' OR v_payload ? 'parent_department_code')
       AND v_parent_id IS NULL THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_REFERENCE_UNRESOLVED: unresolved parent department for row %.', p_record.row_number;
    END IF;

    INSERT INTO puls_core.departments (
      tenant_id,
      code,
      name,
      is_active,
      cost_center_id,
      parent_id,
      external_department_id,
      external_source,
      last_synced_at
    )
    VALUES (
      p_batch.tenant_id,
      v_payload ->> 'code',
      v_payload ->> 'name',
      v_is_active,
      v_cc_id,
      v_parent_id,
      p_record.external_id,
      p_namespace.code,
      NOW()
    )
    RETURNING id INTO v_canonical_id;
  ELSIF p_record.entity_type = 'position'::puls_integration.import_entity_type THEN
    v_dept_id := puls_integration._import_resolve_ref_at_apply(
      p_batch.tenant_id,
      p_batch.source_namespace_id,
      p_batch.id,
      'department'::puls_integration.import_entity_type,
      v_payload ->> 'department_external_id',
      v_payload ->> 'department_code'
    );

    IF (v_payload ? 'department_external_id' OR v_payload ? 'department_code')
       AND v_dept_id IS NULL THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_REFERENCE_UNRESOLVED: unresolved department for row %.', p_record.row_number;
    END IF;

    v_parent_id := puls_integration._import_resolve_ref_at_apply(
      p_batch.tenant_id,
      p_batch.source_namespace_id,
      p_batch.id,
      'position'::puls_integration.import_entity_type,
      v_payload ->> 'parent_position_external_id',
      v_payload ->> 'parent_position_code'
    );

    IF (v_payload ? 'parent_position_external_id' OR v_payload ? 'parent_position_code')
       AND v_parent_id IS NULL THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_REFERENCE_UNRESOLVED: unresolved parent position for row %.', p_record.row_number;
    END IF;

    INSERT INTO puls_core.positions (
      tenant_id,
      code,
      name,
      is_active,
      department_id,
      parent_position_id,
      level,
      norm_headcount,
      employment_type,
      external_position_id,
      external_source,
      last_synced_at
    )
    VALUES (
      p_batch.tenant_id,
      v_payload ->> 'code',
      v_payload ->> 'name',
      v_is_active,
      v_dept_id,
      v_parent_id,
      NULLIF(v_payload ->> 'level', '')::INTEGER,
      COALESCE(NULLIF(v_payload ->> 'norm_headcount', '')::INTEGER, 1),
      NULLIF(v_payload ->> 'employment_type', ''),
      p_record.external_id,
      p_namespace.code,
      NOW()
    )
    RETURNING id INTO v_canonical_id;
  ELSE
    RAISE EXCEPTION 'PULS_CONNECTOR_CREATE_ONLY_ENTITY_UNSUPPORTED: entity type is outside PR16.3 scope.';
  END IF;

  PERFORM puls_integration._import_upsert_identity_map(
    p_batch.tenant_id,
    p_batch.source_namespace_id,
    p_record.entity_type,
    p_record.external_id,
    v_canonical_id,
    p_record.row_hash
  );

  PERFORM puls_integration._import_mark_applied(p_record.id, v_canonical_id);

  RETURN v_canonical_id;
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
  IF auth.role() <> 'service_role' THEN
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
  v_tenant_id UUID := puls_core.current_tenant_id();
  v_limit INTEGER := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200);
BEGIN
  IF auth.role() <> 'service_role' AND NOT puls_integration.is_import_metadata_reader() THEN
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
  WHERE (auth.role() = 'service_role' OR event.tenant_id = v_tenant_id)
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
  v_tenant_id UUID;
BEGIN
  IF auth.role() <> 'service_role' THEN
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
  WHERE (auth.role() = 'service_role' OR c.tenant_id = v_tenant_id)
    AND (p_connection_id IS NULL OR c.id = p_connection_id)
  ORDER BY c.updated_at DESC;
END;
$$;

ALTER TABLE puls_integration.connector_apply_object_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS puls_integration_apply_object_events_select
  ON puls_integration.connector_apply_object_events;
CREATE POLICY puls_integration_apply_object_events_select
  ON puls_integration.connector_apply_object_events
  FOR SELECT
  USING (
    auth.role() = 'service_role'
    OR (
      tenant_id = puls_core.current_tenant_id()
      AND puls_integration.is_import_metadata_reader()
    )
  );

REVOKE ALL ON TABLE puls_integration.connector_apply_object_events
  FROM PUBLIC, authenticated, anon;
GRANT SELECT ON TABLE puls_integration.connector_apply_object_events
  TO authenticated, service_role;
GRANT INSERT ON TABLE puls_integration.connector_apply_object_events
  TO service_role;

REVOKE ALL ON FUNCTION puls_integration._connector_apply_is_create_only_reference_entity(
  puls_integration.import_entity_type
) FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration._connector_apply_is_create_only_reference_entity(
  puls_integration.import_entity_type
) TO service_role;

REVOKE ALL ON FUNCTION puls_integration._connector_apply_create_only_field_allowed(
  puls_integration.import_entity_type,
  TEXT
) FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration._connector_apply_create_only_field_allowed(
  puls_integration.import_entity_type,
  TEXT
) TO service_role;

REVOKE ALL ON FUNCTION puls_integration._connector_apply_has_batch_admin_approval(UUID)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration._connector_apply_has_batch_admin_approval(UUID)
  TO service_role;

REVOKE ALL ON FUNCTION puls_integration._connector_apply_validate_create_only_change_set(UUID)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration._connector_apply_validate_create_only_change_set(UUID)
  TO service_role;

REVOKE ALL ON FUNCTION puls_integration.reject_closed_import_apply_job()
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.reject_closed_import_apply_job()
  TO service_role;

REVOKE ALL ON FUNCTION puls_integration.enqueue_connector_create_only_apply_job(UUID)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.enqueue_connector_create_only_apply_job(UUID)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_integration._connector_apply_insert_reference_record(
  puls_integration.import_batches,
  puls_integration.source_namespaces,
  puls_integration.import_records
) FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration._connector_apply_insert_reference_record(
  puls_integration.import_batches,
  puls_integration.source_namespaces,
  puls_integration.import_records
) TO service_role;

REVOKE ALL ON FUNCTION puls_integration.execute_connector_create_only_apply_job(UUID, TEXT)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.execute_connector_create_only_apply_job(UUID, TEXT)
  TO service_role;

REVOKE ALL ON FUNCTION puls_integration.list_connector_apply_object_events(UUID, INTEGER)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.list_connector_apply_object_events(UUID, INTEGER)
  TO authenticated, service_role;

COMMENT ON TABLE puls_integration.connector_apply_object_events IS
  'PR16.3 safe object-level audit ledger for worker create-only canonical inserts. No raw source payload, field values, credentials, or provider responses.';

COMMENT ON FUNCTION puls_integration.enqueue_connector_create_only_apply_job(UUID) IS
  'Admin-safe enqueue RPC for PR16.3 create-only worker apply. It queues but does not directly write canonical data.';

COMMENT ON FUNCTION puls_integration.execute_connector_create_only_apply_job(UUID, TEXT) IS
  'Service-role worker execution RPC for PR16.3 create-only reference inserts. It revalidates the immutable change-set immediately before writing.';

COMMENT ON FUNCTION puls_integration.list_connector_apply_object_events(UUID, INTEGER) IS
  'Authenticated-safe read model for PR16.3 object audit events. Safe metadata only.';
