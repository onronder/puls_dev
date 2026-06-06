-- PR16.9.0x backend lint hardening for existing PR15/PR16 puls_integration functions.
-- Keeps PR16.9 Notification Center scope untouched while making the general backend
-- lint gate error-free for local Docker and linked remote databases.

CREATE OR REPLACE FUNCTION puls_integration.get_connector_runtime_preflight_context(
  p_connection_id UUID
)
RETURNS TABLE (
  connection_id UUID,
  tenant_id UUID,
  provider TEXT,
  display_name TEXT,
  connection_method TEXT,
  setup_status TEXT,
  setup_step TEXT,
  auth_mode puls_integration.connector_auth_mode,
  credential_required BOOLEAN,
  credential_state puls_integration.connector_credential_state,
  reference_available BOOLEAN,
  credential_last_verified_at TIMESTAMPTZ,
  mapped_field_count INTEGER,
  active_namespace_count INTEGER,
  identity_count INTEGER,
  credential_ready BOOLEAN,
  provider_api_calls_enabled BOOLEAN,
  credential_readback_enabled BOOLEAN,
  canonical_writes_enabled BOOLEAN,
  source_writeback_enabled BOOLEAN,
  next_action_key TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_RUNTIME_PREFLIGHT_WORKER_ONLY: runtime preflight context requires service_role.';
  END IF;

  RETURN QUERY
  SELECT
    c.id,
    c.tenant_id,
    c.provider::TEXT,
    c.display_name,
    c.connection_method::TEXT,
    c.setup_status::TEXT,
    c.setup_step::TEXT,
    c.auth_mode,
    c.credential_required,
    c.credential_state,
    c.credentials_ref IS NOT NULL,
    c.credential_last_verified_at,
    (
      SELECT COUNT(*)::INTEGER
      FROM puls_integration.erp_field_mappings fm
      WHERE fm.tenant_id = c.tenant_id
        AND fm.connection_id = c.id
        AND fm.is_active IS TRUE
        AND fm.is_sensitive IS NOT TRUE
    ),
    (
      SELECT COUNT(*)::INTEGER
      FROM puls_integration.source_namespaces sn
      WHERE sn.tenant_id = c.tenant_id
        AND sn.connection_id = c.id
        AND sn.is_active IS TRUE
    ),
    (
      SELECT COUNT(*)::INTEGER
      FROM puls_integration.entity_identity_map eim
      WHERE eim.tenant_id = c.tenant_id
        AND eim.source_namespace_id IN (
          SELECT sn.id
          FROM puls_integration.source_namespaces sn
          WHERE sn.tenant_id = c.tenant_id
            AND sn.connection_id = c.id
            AND sn.is_active IS TRUE
        )
        AND eim.is_active IS TRUE
    ),
    CASE
      WHEN c.credential_required IS NOT TRUE THEN TRUE
      ELSE c.credential_state = 'verified'::puls_integration.connector_credential_state
        AND c.credentials_ref IS NOT NULL
    END,
    FALSE,
    FALSE,
    FALSE,
    FALSE,
    CASE
      WHEN c.credential_required IS TRUE
        AND (
          c.credential_state IS DISTINCT FROM 'verified'::puls_integration.connector_credential_state
          OR c.credentials_ref IS NULL
        )
        THEN 'run_credential_verification'
      ELSE 'review_runtime_preflight_result'
    END
  FROM puls_integration.erp_connections c
  WHERE c.id = p_connection_id;
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
  v_plan_item puls_integration.connector_apply_change_set_items%ROWTYPE;
  v_plan_items puls_integration.connector_apply_change_set_items[] :=
    ARRAY[]::puls_integration.connector_apply_change_set_items[];
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

    v_plan_item := NULL;
    v_plan_item.tenant_id := v_batch.tenant_id;
    v_plan_item.import_batch_id := p_batch_id;
    v_plan_item.import_record_id := v_rec.id;
    v_plan_item.row_number := v_rec.row_number;
    v_plan_item.entity_type := v_rec.entity_type;
    v_plan_item.external_id := v_rec.external_id;
    v_plan_item.target_schema := 'puls_core';
    v_plan_item.target_table := puls_integration._import_canonical_table(v_rec.entity_type);
    v_plan_item.canonical_id := v_item.canonical_id;
    v_plan_item.operation := v_item.operation;
    v_plan_item.risk_class := v_item.risk_class;
    v_plan_item.blocked := v_item.blocked;
    v_plan_item.risk_reasons := v_item.risk_reasons;
    v_plan_item.audit_tiers := v_item.audit_tiers;
    v_plan_item.retention_bucket := v_item.retention_bucket;
    v_plan_item.source_row_hash := v_rec.row_hash;
    v_plan_item.expected_current_hash := v_item.expected_current_hash;
    v_plan_item.current_action := v_item.current_action;
    v_plan_item.current_skip_code := v_item.current_skip_code;
    v_plan_item.preview_action := v_rec.preview_action;
    v_plan_item.preview_skip_code := v_rec.preview_skip_code;
    v_plan_item.previewed_at := v_rec.previewed_at;
    v_plan_item.safe_field_names := v_item.safe_field_names;
    v_plan_item.destructive_field_names := v_item.destructive_field_names;
    v_plan_item.safe_diff_summary := v_item.safe_diff_summary;
    v_plan_item.rollback_snapshot_required := v_item.rollback_snapshot_required;

    v_plan_items := array_append(v_plan_items, v_plan_item);
  END LOOP;

  SELECT
    COUNT(*)::INTEGER,
    COUNT(*) FILTER (
      WHERE plan_item.operation = 'insert'::puls_integration.connector_apply_operation
    )::INTEGER,
    COUNT(*) FILTER (
      WHERE plan_item.operation = 'update'::puls_integration.connector_apply_operation
    )::INTEGER,
    COUNT(*) FILTER (WHERE plan_item.operation IS NULL)::INTEGER,
    COUNT(*) FILTER (WHERE plan_item.blocked)::INTEGER,
    COUNT(*) FILTER (
      WHERE plan_item.risk_class = 'stale_preview'::puls_integration.connector_apply_risk_class
    )::INTEGER,
    COUNT(*) FILTER (
      WHERE plan_item.risk_class = 'destructive_equivalent'::puls_integration.connector_apply_risk_class
    )::INTEGER,
    COUNT(*) FILTER (
      WHERE plan_item.risk_class = 'source_conflict'::puls_integration.connector_apply_risk_class
    )::INTEGER,
    COUNT(*) FILTER (
      WHERE plan_item.risk_class = 'guarded_overwrite'::puls_integration.connector_apply_risk_class
    )::INTEGER,
    COUNT(*) FILTER (
      WHERE plan_item.risk_class = 'no_change_skip'::puls_integration.connector_apply_risk_class
    )::INTEGER
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
  FROM unnest(v_plan_items) AS plan_item;

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
    plan_item.import_record_id,
    plan_item.row_number,
    plan_item.entity_type,
    plan_item.external_id,
    plan_item.target_table,
    plan_item.canonical_id,
    plan_item.operation,
    plan_item.risk_class,
    plan_item.blocked,
    plan_item.risk_reasons,
    plan_item.audit_tiers,
    plan_item.retention_bucket,
    plan_item.source_row_hash,
    plan_item.expected_current_hash,
    plan_item.current_action,
    plan_item.current_skip_code,
    plan_item.preview_action,
    plan_item.preview_skip_code,
    plan_item.previewed_at,
    plan_item.safe_field_names,
    plan_item.destructive_field_names,
    plan_item.safe_diff_summary,
    plan_item.rollback_snapshot_required
  FROM unnest(v_plan_items) AS plan_item
  ORDER BY plan_item.row_number;

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

REVOKE ALL ON FUNCTION puls_integration.get_connector_runtime_preflight_context(UUID)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.get_connector_runtime_preflight_context(UUID)
  TO service_role;

REVOKE ALL ON FUNCTION puls_integration.create_connector_apply_change_set(UUID)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.create_connector_apply_change_set(UUID)
  TO authenticated, service_role;

COMMENT ON FUNCTION puls_integration.get_connector_runtime_preflight_context(UUID) IS
  'PR16.9.0x lint-hardened runtime preflight context. Explicitly casts enum fields to the published TEXT return contract and remains service-role only.';

COMMENT ON FUNCTION puls_integration.create_connector_apply_change_set(UUID) IS
  'PR16.9.0x lint-hardened PR16.2 apply change-set generator. Keeps one-pass classification semantics with a typed in-memory plan instead of a temp table.';

NOTIFY pgrst, 'reload schema';
