-- PR16.1 apply safety contract and permission hardening.
-- Keeps canonical writes closed while making the apply safety boundary inspectable.

DO $$
BEGIN
  CREATE TYPE puls_integration.connector_apply_policy_state AS ENUM (
    'create_only',
    'guarded_update',
    'blocked_destructive',
    'rollback_preview_required'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE puls_integration.connector_apply_operation AS ENUM (
    'insert',
    'update',
    'soft_delete',
    'restore',
    'rollback',
    'compensating_update'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE puls_integration.connector_apply_audit_tier AS ENUM (
    'object_event',
    'field_diff',
    'rollback_snapshot',
    'archive_summary'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE OR REPLACE FUNCTION puls_integration.reject_closed_import_apply_job()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration
AS $$
BEGIN
  IF NEW.job_type = 'import_apply'::puls_integration.connector_job_type THEN
    RAISE EXCEPTION
      'PULS_CONNECTOR_IMPORT_APPLY_CLOSED: import_apply is closed until PR16 create-only apply gates are implemented.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS puls_integration_connector_jobs_import_apply_closed
  ON puls_integration.connector_jobs;
CREATE TRIGGER puls_integration_connector_jobs_import_apply_closed
  BEFORE INSERT OR UPDATE OF job_type ON puls_integration.connector_jobs
  FOR EACH ROW EXECUTE FUNCTION puls_integration.reject_closed_import_apply_job();

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
    'pr16.1-apply-safety-contract-v1'::TEXT AS contract_version,
    FALSE AS browser_direct_apply_enabled,
    FALSE AS authenticated_apply_rpc_exposed,
    FALSE AS worker_import_apply_enqueue_enabled,
    FALSE AS worker_import_apply_claim_enabled,
    FALSE AS execution_enabled,
    FALSE AS canonical_write_enabled,
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
    'apply_execution_closed_pr16_1'::TEXT AS safe_error_code,
    'implement_create_only_apply_change_set'::TEXT AS next_action_key
  FROM puls_integration.erp_connections c
  WHERE (auth.role() = 'service_role' OR c.tenant_id = v_tenant_id)
    AND (p_connection_id IS NULL OR c.id = p_connection_id)
  ORDER BY c.updated_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION puls_integration.reject_closed_import_apply_job()
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.reject_closed_import_apply_job()
  TO service_role;

REVOKE ALL ON FUNCTION puls_integration.list_connector_apply_safety_contracts(UUID)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.list_connector_apply_safety_contracts(UUID)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_integration.apply_import_batch(UUID, TEXT)
  FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.apply_import_batch(UUID, TEXT)
  TO service_role;

COMMENT ON TYPE puls_integration.connector_apply_policy_state IS
  'PR16 controlled apply policy states. PR16.1 defines the contract without opening execution.';

COMMENT ON TYPE puls_integration.connector_apply_operation IS
  'Canonical mutation operations that require explicit PR16 audit policy before execution opens.';

COMMENT ON TYPE puls_integration.connector_apply_audit_tier IS
  'Audit storage tiers for PR16 object events, field diffs, rollback snapshots, and optional archive summaries.';

COMMENT ON FUNCTION puls_integration.reject_closed_import_apply_job() IS
  'PR16.1 hard gate: import_apply connector jobs cannot be inserted until create-only apply gates are implemented.';

COMMENT ON FUNCTION puls_integration.list_connector_apply_safety_contracts(UUID) IS
  'Authenticated-safe PR16.1 read model for apply permission, audit, and retention boundaries. It does not expose payloads, credentials, or provider responses.';
