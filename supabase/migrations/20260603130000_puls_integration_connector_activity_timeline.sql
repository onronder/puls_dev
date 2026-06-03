-- PR14.15 connector activity timeline: safe metadata-only setup history.

ALTER TABLE puls_integration.erp_sync_batches
  ADD COLUMN IF NOT EXISTS event_key TEXT NULL,
  ADD COLUMN IF NOT EXISTS actor_employee_id UUID NULL REFERENCES puls_core.employees(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS safe_error_code TEXT NULL,
  ADD COLUMN IF NOT EXISTS safe_error_context JSONB NOT NULL DEFAULT '{}'::JSONB,
  ADD COLUMN IF NOT EXISTS next_action_key TEXT NULL;

ALTER TABLE puls_integration.erp_sync_batches
  DROP CONSTRAINT IF EXISTS erp_sync_batches_safe_error_context_object,
  ADD CONSTRAINT erp_sync_batches_safe_error_context_object
    CHECK (jsonb_typeof(safe_error_context) = 'object');

UPDATE puls_integration.erp_sync_batches
SET
  event_key = COALESCE(
    event_key,
    CASE
      WHEN sync_type = 'setup_preflight' THEN 'setup_preflight_completed'
      WHEN sync_type = 'credential_handoff' THEN 'credential_handoff_requested'
      ELSE 'sync_batch_recorded'
    END
  ),
  safe_error_code = CASE
    WHEN safe_error_code IS NOT NULL THEN safe_error_code
    WHEN status = 'failed' THEN 'connector_activity_failed'
    WHEN status IN ('partial', 'partial_success') AND records_failed > 0 THEN 'connector_activity_has_blockers'
    ELSE NULL
  END,
  safe_error_context = CASE
    WHEN safe_error_context <> '{}'::JSONB THEN safe_error_context
    WHEN sync_type = 'setup_preflight' THEN jsonb_build_object(
      'checks_total', records_seen,
      'passed_count', records_inserted,
      'warning_count', records_updated,
      'blocked_count', records_failed
    )
    WHEN sync_type = 'credential_handoff' THEN jsonb_build_object(
      'handoff_request_recorded', TRUE,
      'reference_available', FALSE
    )
    ELSE '{}'::JSONB
  END,
  next_action_key = COALESCE(
    next_action_key,
    CASE
      WHEN sync_type = 'setup_preflight' AND status = 'success' THEN 'runtime_still_closed'
      WHEN sync_type = 'setup_preflight' THEN 'review_setup_findings'
      WHEN sync_type = 'credential_handoff' THEN 'wait_for_secure_reference'
      ELSE 'review_activity'
    END
  );

CREATE INDEX IF NOT EXISTS erp_sync_batches_tenant_event_created_idx
  ON puls_integration.erp_sync_batches (tenant_id, connection_id, event_key, created_at DESC);

CREATE INDEX IF NOT EXISTS erp_sync_batches_safe_error_idx
  ON puls_integration.erp_sync_batches (tenant_id, safe_error_code)
  WHERE safe_error_code IS NOT NULL;

COMMENT ON COLUMN puls_integration.erp_sync_batches.event_key IS
  'Product event key for source-independent connector setup history.';
COMMENT ON COLUMN puls_integration.erp_sync_batches.actor_employee_id IS
  'Employee who triggered the setup-history event when known.';
COMMENT ON COLUMN puls_integration.erp_sync_batches.safe_error_code IS
  'Sanitized connector setup error code. Does not store provider payloads or credential values.';
COMMENT ON COLUMN puls_integration.erp_sync_batches.safe_error_context IS
  'Sanitized connector setup context for UI diagnostics. Sensitive values and provider payloads do not belong here.';
COMMENT ON COLUMN puls_integration.erp_sync_batches.next_action_key IS
  'Product next-action key for connector setup history.';
