-- PR16.6 guarded update rollback approval gate.
-- Records admin approval for a hash-only rollback preview without opening
-- rollback execution, compensating execution, source writeback, credential
-- readback, raw payload readback, snapshot payload readback, or value readback.

CREATE TABLE IF NOT EXISTS puls_integration.connector_apply_rollback_approvals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  connection_id UUID NULL REFERENCES puls_integration.erp_connections(id) ON DELETE SET NULL,
  source_namespace_id UUID NOT NULL REFERENCES puls_integration.source_namespaces(id) ON DELETE RESTRICT,
  import_batch_id UUID NOT NULL REFERENCES puls_integration.import_batches(id) ON DELETE RESTRICT,
  change_set_id UUID NOT NULL REFERENCES puls_integration.connector_apply_change_sets(id) ON DELETE RESTRICT,
  rollback_preview_id UUID NOT NULL REFERENCES puls_integration.connector_apply_rollback_previews(id) ON DELETE RESTRICT,
  rollback_preview_checksum TEXT NOT NULL,
  approval_status TEXT NOT NULL DEFAULT 'approval_recorded',
  approval_policy TEXT NOT NULL DEFAULT 'admin_only',
  row_count INTEGER NOT NULL,
  rollback_count INTEGER NOT NULL,
  blocked_count INTEGER NOT NULL DEFAULT 0,
  stale_blocked_count INTEGER NOT NULL DEFAULT 0,
  field_diff_count INTEGER NOT NULL,
  rollback_snapshot_count INTEGER NOT NULL,
  rollback_approval_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  rollback_execution_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  compensating_execution_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  source_writeback_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  credential_readback_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  value_readback_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  operator_review_required BOOLEAN NOT NULL DEFAULT TRUE,
  next_action_key TEXT NOT NULL DEFAULT 'prepare_guarded_update_rollback_worker_pr16_7',
  safe_summary JSONB NOT NULL DEFAULT '{}'::JSONB,
  approved_by_employee_id UUID NULL REFERENCES puls_core.employees(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (rollback_preview_checksum <> ''),
  CHECK (approval_status = 'approval_recorded'),
  CHECK (approval_policy = 'admin_only'),
  CHECK (row_count > 0),
  CHECK (rollback_count = row_count),
  CHECK (blocked_count = 0),
  CHECK (stale_blocked_count = 0),
  CHECK (field_diff_count > 0),
  CHECK (rollback_snapshot_count >= row_count),
  CHECK (rollback_approval_enabled IS TRUE),
  CHECK (rollback_execution_enabled IS FALSE),
  CHECK (compensating_execution_enabled IS FALSE),
  CHECK (source_writeback_enabled IS FALSE),
  CHECK (credential_readback_enabled IS FALSE),
  CHECK (value_readback_enabled IS FALSE),
  CHECK (operator_review_required IS TRUE),
  CHECK (jsonb_typeof(safe_summary) = 'object'),
  CHECK (puls_integration.connector_safe_context_has_blocked_key(safe_summary) IS FALSE),
  UNIQUE (rollback_preview_id),
  UNIQUE (change_set_id),
  UNIQUE (rollback_preview_checksum)
);

CREATE INDEX IF NOT EXISTS idx_puls_integration_rollback_approvals_tenant_created
  ON puls_integration.connector_apply_rollback_approvals (tenant_id, created_at DESC);

COMMENT ON TABLE puls_integration.connector_apply_rollback_approvals IS
  'PR16.6 immutable admin approval ledger for guarded-update rollback previews. Approval is checksum-bound and does not open rollback execution.';

CREATE OR REPLACE FUNCTION puls_integration.reject_connector_rollback_approval_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration
AS $$
BEGIN
  RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_APPROVAL_IMMUTABLE: rollback approval audit rows are immutable.';
END;
$$;

DROP TRIGGER IF EXISTS puls_integration_rollback_approvals_immutable
  ON puls_integration.connector_apply_rollback_approvals;
CREATE TRIGGER puls_integration_rollback_approvals_immutable
  BEFORE UPDATE OR DELETE ON puls_integration.connector_apply_rollback_approvals
  FOR EACH ROW EXECUTE FUNCTION puls_integration.reject_connector_rollback_approval_mutation();

CREATE OR REPLACE FUNCTION puls_integration.list_connector_guarded_update_rollback_approvals(
  p_change_set_id UUID DEFAULT NULL,
  p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
  rollback_approval_id UUID,
  rollback_preview_id UUID,
  change_set_id UUID,
  tenant_id UUID,
  connection_id UUID,
  source_namespace_id UUID,
  import_batch_id UUID,
  approval_status TEXT,
  approval_policy TEXT,
  rollback_preview_checksum TEXT,
  row_count INTEGER,
  rollback_count INTEGER,
  blocked_count INTEGER,
  stale_blocked_count INTEGER,
  field_diff_count INTEGER,
  rollback_snapshot_count INTEGER,
  rollback_approval_enabled BOOLEAN,
  rollback_execution_enabled BOOLEAN,
  compensating_execution_enabled BOOLEAN,
  source_writeback_enabled BOOLEAN,
  credential_readback_enabled BOOLEAN,
  value_readback_enabled BOOLEAN,
  approval_required BOOLEAN,
  operator_review_required BOOLEAN,
  next_action_key TEXT,
  approved_by_employee_id UUID,
  approved_at TIMESTAMPTZ,
  safe_summary JSONB
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
    approval.id AS rollback_approval_id,
    approval.rollback_preview_id,
    approval.change_set_id,
    approval.tenant_id,
    approval.connection_id,
    approval.source_namespace_id,
    approval.import_batch_id,
    approval.approval_status,
    approval.approval_policy,
    approval.rollback_preview_checksum,
    approval.row_count,
    approval.rollback_count,
    approval.blocked_count,
    approval.stale_blocked_count,
    approval.field_diff_count,
    approval.rollback_snapshot_count,
    approval.rollback_approval_enabled,
    approval.rollback_execution_enabled,
    approval.compensating_execution_enabled,
    approval.source_writeback_enabled,
    approval.credential_readback_enabled,
    approval.value_readback_enabled,
    TRUE AS approval_required,
    approval.operator_review_required,
    approval.next_action_key,
    approval.approved_by_employee_id,
    approval.created_at AS approved_at,
    approval.safe_summary
  FROM puls_integration.connector_apply_rollback_approvals approval
  WHERE (v_auth_role = 'service_role' OR approval.tenant_id = v_tenant_id)
    AND (p_change_set_id IS NULL OR approval.change_set_id = p_change_set_id)
  ORDER BY approval.created_at DESC, approval.id DESC
  LIMIT v_limit;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration.record_connector_guarded_update_rollback_approval(
  p_rollback_preview_id UUID
)
RETURNS TABLE (
  rollback_approval_id UUID,
  rollback_preview_id UUID,
  change_set_id UUID,
  tenant_id UUID,
  connection_id UUID,
  source_namespace_id UUID,
  import_batch_id UUID,
  approval_status TEXT,
  approval_policy TEXT,
  rollback_preview_checksum TEXT,
  row_count INTEGER,
  rollback_count INTEGER,
  blocked_count INTEGER,
  stale_blocked_count INTEGER,
  field_diff_count INTEGER,
  rollback_snapshot_count INTEGER,
  rollback_approval_enabled BOOLEAN,
  rollback_execution_enabled BOOLEAN,
  compensating_execution_enabled BOOLEAN,
  source_writeback_enabled BOOLEAN,
  credential_readback_enabled BOOLEAN,
  value_readback_enabled BOOLEAN,
  approval_required BOOLEAN,
  operator_review_required BOOLEAN,
  next_action_key TEXT,
  approved_by_employee_id UUID,
  approved_at TIMESTAMPTZ,
  safe_summary JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_auth_role TEXT := COALESCE(auth.role(), '');
  v_is_service_role BOOLEAN := v_auth_role = 'service_role';
  v_tenant_id UUID := puls_core.current_tenant_id();
  v_preview puls_integration.connector_apply_rollback_previews;
  v_change_set puls_integration.connector_apply_change_sets;
  v_batch puls_integration.import_batches;
  v_actor_employee_id UUID := NULLIF(current_setting('request.jwt.claim.employee_id', true), '')::UUID;
  v_existing_approval_id UUID;
BEGIN
  IF NOT v_is_service_role AND NOT COALESCE(puls_core.is_admin(), FALSE) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_APPROVAL_ADMIN_REQUIRED: admin permission is required.';
  END IF;

  IF NOT v_is_service_role AND v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_APPROVAL_TENANT_REQUIRED: authenticated caller has no tenant context.';
  END IF;

  SELECT *
  INTO v_preview
  FROM puls_integration.connector_apply_rollback_previews preview
  WHERE preview.id = p_rollback_preview_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_APPROVAL_PREVIEW_NOT_FOUND: rollback preview not found.';
  END IF;

  IF NOT v_is_service_role AND v_preview.tenant_id IS DISTINCT FROM v_tenant_id THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_APPROVAL_FORBIDDEN: rollback preview belongs to another tenant.';
  END IF;

  SELECT *
  INTO v_change_set
  FROM puls_integration.connector_apply_change_sets cs
  WHERE cs.id = v_preview.change_set_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_APPROVAL_CHANGE_SET_NOT_FOUND: change-set not found.';
  END IF;

  SELECT *
  INTO v_batch
  FROM puls_integration.import_batches ib
  WHERE ib.id = v_preview.import_batch_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_APPROVAL_BATCH_NOT_FOUND: import batch not found.';
  END IF;

  IF v_batch.status IS DISTINCT FROM 'applied'::puls_integration.import_batch_status THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_APPROVAL_APPLIED_BATCH_REQUIRED: rollback approval requires an applied batch.';
  END IF;

  IF v_preview.status IS DISTINCT FROM 'ready_for_rollback_review' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_APPROVAL_PREVIEW_NOT_READY: rollback preview must be ready.';
  END IF;

  IF v_preview.preview_kind IS DISTINCT FROM 'rollback' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_APPROVAL_PREVIEW_KIND_INVALID: rollback preview kind is invalid.';
  END IF;

  IF v_preview.row_count <= 0
     OR v_preview.rollback_count <> v_preview.row_count
     OR v_preview.blocked_count <> 0
     OR v_preview.stale_blocked_count <> 0
     OR v_preview.field_diff_count <= 0
     OR v_preview.rollback_snapshot_count < v_preview.row_count THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_APPROVAL_PREVIEW_COUNTS_INVALID: rollback preview counts are not approval-safe.';
  END IF;

  IF v_preview.rollback_preview_enabled IS NOT TRUE
     OR v_preview.rollback_execution_enabled IS NOT FALSE
     OR v_preview.compensating_execution_enabled IS NOT FALSE
     OR v_preview.source_writeback_enabled IS NOT FALSE
     OR v_preview.credential_readback_enabled IS NOT FALSE
     OR v_preview.value_readback_enabled IS NOT FALSE THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_APPROVAL_BOUNDARY_INVALID: rollback preview safety boundary is invalid.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM puls_integration.connector_apply_rollback_preview_items item
    WHERE item.rollback_preview_id = v_preview.id
      AND (
        item.change_set_id IS DISTINCT FROM v_preview.change_set_id
        OR item.operation IS DISTINCT FROM 'rollback'::puls_integration.connector_apply_operation
        OR item.item_status IS DISTINCT FROM 'ready'
        OR item.risk_class IS DISTINCT FROM 'rollback_preview_required'
        OR cardinality(item.blocker_codes) > 0
        OR item.field_diff_count <= 0
        OR item.rollback_snapshot_available IS NOT TRUE
        OR item.snapshot_state IS DISTINCT FROM 'available'
        OR item.snapshot_hash IS NULL
        OR item.expected_post_apply_hash IS NULL
        OR item.current_hash IS NULL
        OR item.current_state_matches_apply IS NOT TRUE
        OR item.stale_blocked IS TRUE
        OR item.hot_retention_expires_at <= NOW()
      )
  ) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_APPROVAL_ITEM_BLOCKERS_PRESENT: rollback preview has blocked, stale, or expired items.';
  END IF;

  IF (
    SELECT COUNT(*)::INTEGER
    FROM puls_integration.connector_apply_rollback_preview_items item
    WHERE item.rollback_preview_id = v_preview.id
  ) <> v_preview.row_count THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_APPROVAL_ITEM_COUNT_MISMATCH: rollback preview item count must match row count.';
  END IF;

  SELECT approval.id
  INTO v_existing_approval_id
  FROM puls_integration.connector_apply_rollback_approvals approval
  WHERE approval.rollback_preview_id = v_preview.id;

  IF FOUND THEN
    RETURN QUERY
    SELECT approval_row.*
    FROM puls_integration.list_connector_guarded_update_rollback_approvals(
      v_preview.change_set_id,
      50
    ) AS approval_row
    WHERE approval_row.rollback_approval_id = v_existing_approval_id;
    RETURN;
  END IF;

  INSERT INTO puls_integration.connector_apply_rollback_approvals (
    tenant_id,
    connection_id,
    source_namespace_id,
    import_batch_id,
    change_set_id,
    rollback_preview_id,
    rollback_preview_checksum,
    row_count,
    rollback_count,
    blocked_count,
    stale_blocked_count,
    field_diff_count,
    rollback_snapshot_count,
    safe_summary,
    approved_by_employee_id
  )
  VALUES (
    v_preview.tenant_id,
    v_preview.connection_id,
    v_preview.source_namespace_id,
    v_preview.import_batch_id,
    v_preview.change_set_id,
    v_preview.id,
    v_preview.rollback_preview_checksum,
    v_preview.row_count,
    v_preview.rollback_count,
    v_preview.blocked_count,
    v_preview.stale_blocked_count,
    v_preview.field_diff_count,
    v_preview.rollback_snapshot_count,
    jsonb_build_object(
      'contract_version', 'pr16.6-guarded-update-rollback-approval-v1',
      'rollback_approval', TRUE,
      'rollback_preview_id', v_preview.id,
      'change_set_id', v_preview.change_set_id,
      'import_batch_id', v_preview.import_batch_id,
      'rollback_preview_checksum', v_preview.rollback_preview_checksum,
      'row_count', v_preview.row_count,
      'rollback_count', v_preview.rollback_count,
      'blocked_count', v_preview.blocked_count,
      'stale_blocked_count', v_preview.stale_blocked_count,
      'field_diff_count', v_preview.field_diff_count,
      'rollback_snapshot_count', v_preview.rollback_snapshot_count,
      'approval_policy', 'admin_only',
      'approver_role', CASE WHEN v_is_service_role THEN 'service_role' ELSE 'tenant_admin' END,
      'operator_review_required', TRUE,
      'approval_recorded', TRUE,
      'rollback_preview_enabled', TRUE,
      'rollback_execution', FALSE,
      'compensating_execution', FALSE,
      'canonical_write', FALSE,
      'source_writeback', FALSE,
      'provider_api_calls', FALSE,
      'credential_readback', FALSE,
      'field_value_readback', FALSE,
      'raw_payload_readback', FALSE,
      'snapshot_payload_readback', FALSE
    ),
    CASE WHEN v_is_service_role THEN NULL ELSE v_actor_employee_id END
  )
  RETURNING id INTO v_existing_approval_id;

  RETURN QUERY
  SELECT approval_row.*
  FROM puls_integration.list_connector_guarded_update_rollback_approvals(
    v_preview.change_set_id,
    50
  ) AS approval_row
  WHERE approval_row.rollback_approval_id = v_existing_approval_id;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration._connector_apply_has_rollback_approval(
  p_rollback_preview_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM puls_integration.connector_apply_rollback_approvals approval
    JOIN puls_integration.connector_apply_rollback_previews preview
      ON preview.id = approval.rollback_preview_id
    WHERE approval.rollback_preview_id = p_rollback_preview_id
      AND approval.approval_status = 'approval_recorded'
      AND approval.rollback_preview_checksum = preview.rollback_preview_checksum
      AND approval.rollback_execution_enabled IS FALSE
      AND approval.compensating_execution_enabled IS FALSE
      AND approval.source_writeback_enabled IS FALSE
      AND approval.credential_readback_enabled IS FALSE
      AND approval.value_readback_enabled IS FALSE
  );
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
    'pr16.6-guarded-update-rollback-approval-v1'::TEXT AS contract_version,
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
    'guarded_update_rollback_approval_open'::TEXT AS safe_error_code,
    'review_guarded_update_rollback_approval'::TEXT AS next_action_key
  FROM puls_integration.erp_connections c
  WHERE (v_auth_role = 'service_role' OR c.tenant_id = v_tenant_id)
    AND (p_connection_id IS NULL OR c.id = p_connection_id)
  ORDER BY c.updated_at DESC;
END;
$$;

ALTER TABLE puls_integration.connector_apply_rollback_approvals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS puls_integration_rollback_approvals_service_role
  ON puls_integration.connector_apply_rollback_approvals;
CREATE POLICY puls_integration_rollback_approvals_service_role
  ON puls_integration.connector_apply_rollback_approvals
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

REVOKE ALL ON TABLE puls_integration.connector_apply_rollback_approvals
  FROM PUBLIC, authenticated, anon;
GRANT SELECT, INSERT ON TABLE puls_integration.connector_apply_rollback_approvals
  TO service_role;

REVOKE ALL ON FUNCTION puls_integration.reject_connector_rollback_approval_mutation()
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.reject_connector_rollback_approval_mutation()
  TO service_role;

REVOKE ALL ON FUNCTION puls_integration.record_connector_guarded_update_rollback_approval(UUID)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.record_connector_guarded_update_rollback_approval(UUID)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_integration.list_connector_guarded_update_rollback_approvals(UUID, INTEGER)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.list_connector_guarded_update_rollback_approvals(UUID, INTEGER)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_integration._connector_apply_has_rollback_approval(UUID)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration._connector_apply_has_rollback_approval(UUID)
  TO service_role;

COMMENT ON FUNCTION puls_integration.record_connector_guarded_update_rollback_approval(UUID) IS
  'PR16.6 admin/service-role approval RPC for guarded-update rollback previews. Records immutable checksum-bound approval without opening rollback execution.';

COMMENT ON FUNCTION puls_integration.list_connector_guarded_update_rollback_approvals(UUID, INTEGER) IS
  'PR16.6 authenticated-safe guarded update rollback approval read model. Returns approval metadata and closed execution boundaries only.';
