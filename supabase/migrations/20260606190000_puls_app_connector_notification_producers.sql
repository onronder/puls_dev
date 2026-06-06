-- PR16.9.2 connector notification producer mapping.
-- Converts selected high-value connector/runtime evidence into app-wide
-- notifications through the PR16.9.1 service-role emit boundary. This does
-- not create another ledger, open direct browser writes, add realtime,
-- external delivery, provider calls, ERP/source writeback, credential
-- readback, raw payload readback, snapshot payload readback, or field value
-- readback.

CREATE OR REPLACE FUNCTION puls_app.refresh_connector_app_notifications(
  p_limit INTEGER DEFAULT 100,
  p_tenant_id UUID DEFAULT NULL,
  p_source_event_key TEXT DEFAULT NULL
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
  v_source_event_key TEXT := NULLIF(BTRIM(COALESCE(p_source_event_key, '')), '');
  v_candidate RECORD;
  v_emit RECORD;
BEGIN
  IF v_auth_role <> 'service_role' THEN
    RAISE EXCEPTION
      'PULS_APP_CONNECTOR_NOTIFICATION_REFRESH_SERVICE_ROLE_REQUIRED: connector notification refresh requires service_role.'
      USING ERRCODE = 'P0001';
  END IF;

  IF p_tenant_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM puls_core.tenants tenant WHERE tenant.id = p_tenant_id) THEN
    RAISE EXCEPTION
      'PULS_APP_CONNECTOR_NOTIFICATION_TENANT_NOT_FOUND: tenant was not found.'
      USING ERRCODE = 'P0001';
  END IF;

  FOR v_candidate IN
    WITH connector_job_candidates AS (
      SELECT
        CASE
          WHEN job.status = 'dead_letter'::puls_integration.connector_job_status THEN
            'connector_job_dead_letter'::TEXT
          WHEN job.job_type = 'connector_runtime_preflight'::puls_integration.connector_job_type THEN
            'runtime_preflight_failed'::TEXT
          ELSE
            'connector_job_failed'::TEXT
        END AS source_event_key,
        'puls_integration.connector_jobs'::TEXT AS source_table,
        job.id AS source_id,
        job.tenant_id,
        job.connection_id,
        job.source_namespace_id,
        job.import_batch_id,
        CASE
          WHEN job.status = 'dead_letter'::puls_integration.connector_job_status THEN 'critical'::TEXT
          WHEN job.operator_severity = 'critical'::puls_integration.connector_job_operator_severity THEN 'critical'::TEXT
          WHEN job.operator_severity = 'error'::puls_integration.connector_job_operator_severity THEN 'error'::TEXT
          ELSE 'warning'::TEXT
        END AS severity,
        CASE
          WHEN job.status = 'dead_letter'::puls_integration.connector_job_status THEN 95
          WHEN job.operator_severity = 'critical'::puls_integration.connector_job_operator_severity THEN 92
          WHEN job.operator_severity = 'error'::puls_integration.connector_job_operator_severity THEN 86
          ELSE 78
        END AS priority,
        ARRAY['hr_admin', 'admin', 'superadmin']::TEXT[] AS target_roles,
        'connector_job'::TEXT AS subject_type,
        job.id AS subject_id,
        CASE
          WHEN job.status = 'dead_letter'::puls_integration.connector_job_status THEN
            'notifications.connectorRuntime.jobDeadLetter.title'
          WHEN job.job_type = 'connector_runtime_preflight'::puls_integration.connector_job_type THEN
            'notifications.connectorRuntime.runtimePreflightFailed.title'
          ELSE
            'notifications.connectorRuntime.jobFailed.title'
        END AS title_key,
        CASE
          WHEN job.status = 'dead_letter'::puls_integration.connector_job_status THEN
            'notifications.connectorRuntime.jobDeadLetter.body'
          WHEN job.job_type = 'connector_runtime_preflight'::puls_integration.connector_job_type THEN
            'notifications.connectorRuntime.runtimePreflightFailed.body'
          ELSE
            'notifications.connectorRuntime.jobFailed.body'
        END AS body_key,
        'connector_runtime.jobs'::TEXT AS route_hint,
        COALESCE(NULLIF(job.next_action_key, ''), 'review_connector_job_failure') AS action_key,
        concat_ws(
          ':',
          'pr16.9.2-connector-notification-producer-v1',
          'connector_runtime',
          CASE
            WHEN job.status = 'dead_letter'::puls_integration.connector_job_status THEN
              'connector_job_dead_letter'
            WHEN job.job_type = 'connector_runtime_preflight'::puls_integration.connector_job_type THEN
              'runtime_preflight_failed'
            ELSE
              'connector_job_failed'
          END,
          job.id::TEXT,
          job.status::TEXT
        ) AS dedupe_key,
        jsonb_build_object(
          'contract_version', 'pr16.9.2-connector-notification-producer-v1',
          'source_domain', 'connector_runtime',
          'source_event_key', CASE
            WHEN job.status = 'dead_letter'::puls_integration.connector_job_status THEN
              'connector_job_dead_letter'
            WHEN job.job_type = 'connector_runtime_preflight'::puls_integration.connector_job_type THEN
              'runtime_preflight_failed'
            ELSE
              'connector_job_failed'
          END,
          'source_table', 'puls_integration.connector_jobs',
          'connector_job_id', job.id,
          'connection_id', job.connection_id,
          'source_namespace_id', job.source_namespace_id,
          'import_batch_id', job.import_batch_id,
          'job_type', job.job_type::TEXT,
          'job_status', job.status::TEXT,
          'failure_class', job.failure_class::TEXT,
          'operator_severity', job.operator_severity::TEXT,
          'safe_error_code', job.safe_error_code,
          'next_action_key', COALESCE(NULLIF(job.next_action_key, ''), 'review_connector_job_failure'),
          'operator_review_required', job.operator_review_required,
          'retry_after_seconds', job.retry_after_seconds,
          'attempt_count', job.attempt_count,
          'max_attempts', job.max_attempts,
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
        COALESCE(job.finished_at, job.dead_lettered_at, job.last_failure_at, job.updated_at, job.created_at) AS occurred_at
      FROM puls_integration.connector_jobs job
      WHERE job.status IN (
          'failed'::puls_integration.connector_job_status,
          'dead_letter'::puls_integration.connector_job_status
        )
        AND (p_tenant_id IS NULL OR job.tenant_id = p_tenant_id)
    ),
    apply_object_event_candidates AS (
      SELECT
        CASE event.operation
          WHEN 'insert'::puls_integration.connector_apply_operation THEN
            'import_apply_create_only_completed'::TEXT
          WHEN 'update'::puls_integration.connector_apply_operation THEN
            'import_apply_guarded_update_completed'::TEXT
          WHEN 'rollback'::puls_integration.connector_apply_operation THEN
            'import_apply_rollback_completed'::TEXT
        END AS source_event_key,
        'puls_integration.connector_apply_object_events'::TEXT AS source_table,
        event.id AS source_id,
        event.tenant_id,
        event.connection_id,
        event.source_namespace_id,
        event.import_batch_id,
        'success'::TEXT AS severity,
        CASE event.operation
          WHEN 'rollback'::puls_integration.connector_apply_operation THEN 92
          WHEN 'update'::puls_integration.connector_apply_operation THEN 78
          ELSE 72
        END AS priority,
        ARRAY['hr_admin', 'admin', 'superadmin']::TEXT[] AS target_roles,
        'connector_apply_change_set'::TEXT AS subject_type,
        event.change_set_id AS subject_id,
        CASE event.operation
          WHEN 'insert'::puls_integration.connector_apply_operation THEN
            'notifications.connectorRuntime.createOnlyCompleted.title'
          WHEN 'update'::puls_integration.connector_apply_operation THEN
            'notifications.connectorRuntime.guardedUpdateCompleted.title'
          WHEN 'rollback'::puls_integration.connector_apply_operation THEN
            'notifications.connectorRuntime.rollbackCompleted.title'
        END AS title_key,
        CASE event.operation
          WHEN 'insert'::puls_integration.connector_apply_operation THEN
            'notifications.connectorRuntime.createOnlyCompleted.body'
          WHEN 'update'::puls_integration.connector_apply_operation THEN
            'notifications.connectorRuntime.guardedUpdateCompleted.body'
          WHEN 'rollback'::puls_integration.connector_apply_operation THEN
            'notifications.connectorRuntime.rollbackCompleted.body'
        END AS body_key,
        CASE event.operation
          WHEN 'rollback'::puls_integration.connector_apply_operation THEN
            'connector_runtime.rollback'
          ELSE
            'connector_runtime.apply'
        END AS route_hint,
        CASE event.operation
          WHEN 'rollback'::puls_integration.connector_apply_operation THEN
            'review_guarded_update_rollback_object_events'
          ELSE
            'review_connector_apply_object_events'
        END AS action_key,
        concat_ws(
          ':',
          'pr16.9.2-connector-notification-producer-v1',
          'connector_runtime',
          CASE event.operation
            WHEN 'insert'::puls_integration.connector_apply_operation THEN
              'import_apply_create_only_completed'
            WHEN 'update'::puls_integration.connector_apply_operation THEN
              'import_apply_guarded_update_completed'
            WHEN 'rollback'::puls_integration.connector_apply_operation THEN
              'import_apply_rollback_completed'
          END,
          event.id::TEXT
        ) AS dedupe_key,
        jsonb_build_object(
          'contract_version', 'pr16.9.2-connector-notification-producer-v1',
          'source_domain', 'connector_runtime',
          'source_event_key', CASE event.operation
            WHEN 'insert'::puls_integration.connector_apply_operation THEN
              'import_apply_create_only_completed'
            WHEN 'update'::puls_integration.connector_apply_operation THEN
              'import_apply_guarded_update_completed'
            WHEN 'rollback'::puls_integration.connector_apply_operation THEN
              'import_apply_rollback_completed'
          END,
          'source_table', 'puls_integration.connector_apply_object_events',
          'object_event_id', event.id,
          'connector_job_id', event.connector_job_id,
          'change_set_id', event.change_set_id,
          'change_set_item_id', event.change_set_item_id,
          'import_batch_id', event.import_batch_id,
          'import_record_id', event.import_record_id,
          'connection_id', event.connection_id,
          'source_namespace_id', event.source_namespace_id,
          'operation', event.operation::TEXT,
          'entity_type', event.entity_type::TEXT,
          'target_table', event.target_table,
          'canonical_id', event.canonical_id,
          'canonical_write', TRUE,
          'rollback_execution', event.operation = 'rollback'::puls_integration.connector_apply_operation,
          'source_writeback', FALSE,
          'provider_api_calls', FALSE,
          'credential_readback', FALSE,
          'raw_payload_readback', FALSE,
          'field_value_readback', FALSE,
          'snapshot_payload_readback', FALSE,
          'external_delivery_enabled', FALSE,
          'notification_realtime_enabled', FALSE
        ) AS safe_summary,
        event.created_at AS occurred_at
      FROM puls_integration.connector_apply_object_events event
      WHERE event.operation IN (
          'insert'::puls_integration.connector_apply_operation,
          'update'::puls_integration.connector_apply_operation,
          'rollback'::puls_integration.connector_apply_operation
        )
        AND (p_tenant_id IS NULL OR event.tenant_id = p_tenant_id)
    ),
    rollback_preview_candidates AS (
      SELECT
        'import_apply_rollback_preview_ready'::TEXT AS source_event_key,
        'puls_integration.connector_apply_rollback_previews'::TEXT AS source_table,
        preview.id AS source_id,
        preview.tenant_id,
        preview.connection_id,
        preview.source_namespace_id,
        preview.import_batch_id,
        'warning'::TEXT AS severity,
        88 AS priority,
        ARRAY['hr_admin', 'admin', 'superadmin']::TEXT[] AS target_roles,
        'connector_apply_change_set'::TEXT AS subject_type,
        preview.change_set_id AS subject_id,
        'notifications.connectorRuntime.rollbackPreviewReady.title'::TEXT AS title_key,
        'notifications.connectorRuntime.rollbackPreviewReady.body'::TEXT AS body_key,
        'connector_runtime.rollback_preview'::TEXT AS route_hint,
        preview.next_action_key AS action_key,
        concat_ws(
          ':',
          'pr16.9.2-connector-notification-producer-v1',
          'connector_runtime',
          'import_apply_rollback_preview_ready',
          preview.id::TEXT,
          preview.rollback_preview_checksum
        ) AS dedupe_key,
        jsonb_build_object(
          'contract_version', 'pr16.9.2-connector-notification-producer-v1',
          'source_domain', 'connector_runtime',
          'source_event_key', 'import_apply_rollback_preview_ready',
          'source_table', 'puls_integration.connector_apply_rollback_previews',
          'rollback_preview_id', preview.id,
          'change_set_id', preview.change_set_id,
          'import_batch_id', preview.import_batch_id,
          'connection_id', preview.connection_id,
          'source_namespace_id', preview.source_namespace_id,
          'preview_status', preview.status,
          'row_count', preview.row_count,
          'rollback_count', preview.rollback_count,
          'blocked_count', preview.blocked_count,
          'stale_blocked_count', preview.stale_blocked_count,
          'field_diff_count', preview.field_diff_count,
          'rollback_snapshot_count', preview.rollback_snapshot_count,
          'next_action_key', preview.next_action_key,
          'approval_required', preview.approval_required,
          'operator_review_required', preview.operator_review_required,
          'canonical_write', FALSE,
          'rollback_preview_enabled', preview.rollback_preview_enabled,
          'rollback_execution', FALSE,
          'source_writeback', FALSE,
          'provider_api_calls', FALSE,
          'credential_readback', FALSE,
          'raw_payload_readback', FALSE,
          'field_value_readback', FALSE,
          'snapshot_payload_readback', FALSE,
          'external_delivery_enabled', FALSE,
          'notification_realtime_enabled', FALSE
        ) AS safe_summary,
        preview.created_at AS occurred_at
      FROM puls_integration.connector_apply_rollback_previews preview
      WHERE preview.status = 'ready_for_rollback_review'
        AND preview.blocked_count = 0
        AND preview.rollback_count > 0
        AND (p_tenant_id IS NULL OR preview.tenant_id = p_tenant_id)
    ),
    rollback_approval_candidates AS (
      SELECT
        'import_apply_rollback_approval_recorded'::TEXT AS source_event_key,
        'puls_integration.connector_apply_rollback_approvals'::TEXT AS source_table,
        approval.id AS source_id,
        approval.tenant_id,
        approval.connection_id,
        approval.source_namespace_id,
        approval.import_batch_id,
        'warning'::TEXT AS severity,
        84 AS priority,
        ARRAY['hr_admin', 'admin', 'superadmin']::TEXT[] AS target_roles,
        'connector_apply_change_set'::TEXT AS subject_type,
        approval.change_set_id AS subject_id,
        'notifications.connectorRuntime.rollbackApprovalRecorded.title'::TEXT AS title_key,
        'notifications.connectorRuntime.rollbackApprovalRecorded.body'::TEXT AS body_key,
        'connector_runtime.rollback_approval'::TEXT AS route_hint,
        approval.next_action_key AS action_key,
        concat_ws(
          ':',
          'pr16.9.2-connector-notification-producer-v1',
          'connector_runtime',
          'import_apply_rollback_approval_recorded',
          approval.id::TEXT,
          approval.rollback_preview_checksum
        ) AS dedupe_key,
        jsonb_build_object(
          'contract_version', 'pr16.9.2-connector-notification-producer-v1',
          'source_domain', 'connector_runtime',
          'source_event_key', 'import_apply_rollback_approval_recorded',
          'source_table', 'puls_integration.connector_apply_rollback_approvals',
          'rollback_approval_id', approval.id,
          'rollback_preview_id', approval.rollback_preview_id,
          'change_set_id', approval.change_set_id,
          'import_batch_id', approval.import_batch_id,
          'connection_id', approval.connection_id,
          'source_namespace_id', approval.source_namespace_id,
          'approval_status', approval.approval_status,
          'approval_policy', approval.approval_policy,
          'row_count', approval.row_count,
          'rollback_count', approval.rollback_count,
          'blocked_count', approval.blocked_count,
          'stale_blocked_count', approval.stale_blocked_count,
          'field_diff_count', approval.field_diff_count,
          'rollback_snapshot_count', approval.rollback_snapshot_count,
          'next_action_key', approval.next_action_key,
          'approval_required', TRUE,
          'operator_review_required', approval.operator_review_required,
          'canonical_write', FALSE,
          'rollback_execution', FALSE,
          'source_writeback', FALSE,
          'provider_api_calls', FALSE,
          'credential_readback', FALSE,
          'raw_payload_readback', FALSE,
          'field_value_readback', FALSE,
          'snapshot_payload_readback', FALSE,
          'external_delivery_enabled', FALSE,
          'notification_realtime_enabled', FALSE
        ) AS safe_summary,
        approval.created_at AS occurred_at
      FROM puls_integration.connector_apply_rollback_approvals approval
      WHERE approval.approval_status = 'approval_recorded'
        AND approval.blocked_count = 0
        AND approval.rollback_count > 0
        AND (p_tenant_id IS NULL OR approval.tenant_id = p_tenant_id)
    ),
    rollback_worker_ready_candidates AS (
      SELECT
        'import_apply_rollback_worker_ready'::TEXT AS source_event_key,
        'puls_integration.connector_apply_rollback_worker_readiness'::TEXT AS source_table,
        readiness.id AS source_id,
        readiness.tenant_id,
        readiness.connection_id,
        readiness.source_namespace_id,
        readiness.import_batch_id,
        'warning'::TEXT AS severity,
        86 AS priority,
        ARRAY['hr_admin', 'admin', 'superadmin']::TEXT[] AS target_roles,
        'connector_apply_change_set'::TEXT AS subject_type,
        readiness.change_set_id AS subject_id,
        'notifications.connectorRuntime.rollbackWorkerReady.title'::TEXT AS title_key,
        'notifications.connectorRuntime.rollbackWorkerReady.body'::TEXT AS body_key,
        'connector_runtime.rollback_worker_readiness'::TEXT AS route_hint,
        readiness.next_action_key AS action_key,
        concat_ws(
          ':',
          'pr16.9.2-connector-notification-producer-v1',
          'connector_runtime',
          'import_apply_rollback_worker_ready',
          readiness.id::TEXT,
          readiness.rollback_preview_checksum
        ) AS dedupe_key,
        jsonb_build_object(
          'contract_version', 'pr16.9.2-connector-notification-producer-v1',
          'source_domain', 'connector_runtime',
          'source_event_key', 'import_apply_rollback_worker_ready',
          'source_table', 'puls_integration.connector_apply_rollback_worker_readiness',
          'rollback_worker_readiness_id', readiness.id,
          'rollback_approval_id', readiness.rollback_approval_id,
          'rollback_preview_id', readiness.rollback_preview_id,
          'change_set_id', readiness.change_set_id,
          'import_batch_id', readiness.import_batch_id,
          'connection_id', readiness.connection_id,
          'source_namespace_id', readiness.source_namespace_id,
          'readiness_status', readiness.readiness_status,
          'worker_handoff_ready', readiness.worker_handoff_ready,
          'row_count', readiness.row_count,
          'rollback_count', readiness.rollback_count,
          'blocker_count', readiness.blocker_count,
          'stale_blocked_count', readiness.stale_blocked_count,
          'drift_blocked_count', readiness.drift_blocked_count,
          'expired_snapshot_count', readiness.expired_snapshot_count,
          'field_diff_count', readiness.field_diff_count,
          'rollback_snapshot_count', readiness.rollback_snapshot_count,
          'original_apply_event_count', readiness.original_apply_event_count,
          'current_state_verified_count', readiness.current_state_verified_count,
          'retention_verified_count', readiness.retention_verified_count,
          'next_action_key', readiness.next_action_key,
          'approval_required', readiness.approval_required,
          'operator_review_required', readiness.operator_review_required,
          'canonical_write', FALSE,
          'rollback_execution', FALSE,
          'source_writeback', FALSE,
          'provider_api_calls', FALSE,
          'credential_readback', FALSE,
          'raw_payload_readback', FALSE,
          'field_value_readback', FALSE,
          'snapshot_payload_readback', FALSE,
          'external_delivery_enabled', FALSE,
          'notification_realtime_enabled', FALSE
        ) AS safe_summary,
        readiness.created_at AS occurred_at
      FROM puls_integration.connector_apply_rollback_worker_readiness readiness
      WHERE readiness.readiness_status = 'ready_for_worker_handoff'
        AND readiness.worker_handoff_ready IS TRUE
        AND readiness.blocker_count = 0
        AND (p_tenant_id IS NULL OR readiness.tenant_id = p_tenant_id)
    ),
    candidates AS (
      SELECT * FROM connector_job_candidates
      UNION ALL
      SELECT * FROM apply_object_event_candidates
      UNION ALL
      SELECT * FROM rollback_preview_candidates
      UNION ALL
      SELECT * FROM rollback_approval_candidates
      UNION ALL
      SELECT * FROM rollback_worker_ready_candidates
    )
    SELECT candidate.*
    FROM candidates candidate
    WHERE v_source_event_key IS NULL
      OR candidate.source_event_key = v_source_event_key
    ORDER BY candidate.occurred_at DESC, candidate.source_id DESC
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

CREATE OR REPLACE FUNCTION puls_app.get_notification_center_bootstrap_status()
RETURNS TABLE (
  contract_version TEXT,
  schema_name TEXT,
  auth_role TEXT,
  current_tenant_id UUID,
  current_employee_id UUID,
  current_persona_role TEXT,
  is_admin BOOLEAN,
  app_schema_available BOOLEAN,
  notification_ledger_enabled BOOLEAN,
  notification_realtime_enabled BOOLEAN,
  external_delivery_enabled BOOLEAN,
  next_action_key TEXT,
  safe_summary JSONB
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_app, puls_core
AS $$
DECLARE
  v_auth_role TEXT := COALESCE(auth.role(), '');
  v_is_service_role BOOLEAN := COALESCE(auth.role(), '') = 'service_role';
  v_tenant_id UUID;
  v_employee_id UUID;
  v_persona_role TEXT;
  v_is_admin BOOLEAN := FALSE;
BEGIN
  IF v_is_service_role THEN
    v_tenant_id := NULL;
    v_employee_id := NULL;
    v_persona_role := NULL;
    v_is_admin := FALSE;
  ELSE
    v_tenant_id := puls_core.current_tenant_id();
    v_employee_id := puls_core.current_employee_id();
    v_persona_role := puls_core.current_persona_role()::TEXT;
    v_is_admin := COALESCE(puls_core.is_admin(), FALSE);

    IF v_tenant_id IS NULL THEN
      RAISE EXCEPTION
        'PULS_APP_NOTIFICATION_BOOTSTRAP_TENANT_REQUIRED: authenticated caller has no tenant context.'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  RETURN QUERY
  SELECT
    'pr16.9.2-connector-notification-producer-v1'::TEXT AS contract_version,
    'puls_app'::TEXT AS schema_name,
    v_auth_role AS auth_role,
    v_tenant_id AS current_tenant_id,
    v_employee_id AS current_employee_id,
    v_persona_role AS current_persona_role,
    v_is_admin AS is_admin,
    TRUE AS app_schema_available,
    TRUE AS notification_ledger_enabled,
    FALSE AS notification_realtime_enabled,
    FALSE AS external_delivery_enabled,
    'implement_notification_center_ui_pr16_9_3'::TEXT AS next_action_key,
    jsonb_build_object(
      'contract_version', 'pr16.9.2-connector-notification-producer-v1',
      'schema_name', 'puls_app',
      'app_wide_capability', TRUE,
      'app_schema_available', TRUE,
      'notification_ledger_enabled', TRUE,
      'notification_tables_created', TRUE,
      'notification_tables_exist', (
        to_regclass('puls_app.app_notifications') IS NOT NULL
        AND to_regclass('puls_app.app_notification_reads') IS NOT NULL
      ),
      'connector_producer_mapping_enabled', TRUE,
      'source_domain', 'connector_runtime',
      'producer_refresh_rpc', 'refresh_connector_app_notifications',
      'first_producer_enabled', 'connector_runtime',
      'first_surface_planned', '/erp',
      'notification_realtime_enabled', FALSE,
      'realtime_required', FALSE,
      'external_delivery_enabled', FALSE,
      'browser_direct_table_write', FALSE,
      'authenticated_direct_table_write', FALSE,
      'source_writeback', FALSE,
      'provider_api_calls', FALSE,
      'provider_response_readback', FALSE,
      'credential_readback', FALSE,
      'raw_payload_readback', FALSE,
      'field_value_readback', FALSE,
      'snapshot_payload_readback', FALSE,
      'ai_autonomous_action', FALSE,
      'postgrest_schema_exposure_required', TRUE,
      'postgrest_schema_reload_hint', 'NOTIFY pgrst, reload schema',
      'next_action_key', 'implement_notification_center_ui_pr16_9_3'
    ) AS safe_summary;
END;
$$;

REVOKE ALL ON FUNCTION puls_app.refresh_connector_app_notifications(INTEGER, UUID, TEXT)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_app.refresh_connector_app_notifications(INTEGER, UUID, TEXT)
  TO service_role;

REVOKE ALL ON FUNCTION puls_app.get_notification_center_bootstrap_status()
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_app.get_notification_center_bootstrap_status()
  TO authenticated, service_role;

COMMENT ON FUNCTION puls_app.refresh_connector_app_notifications(INTEGER, UUID, TEXT) IS
  'PR16.9.2 service-role connector/runtime producer mapping. Emits idempotent app notifications from selected safe connector evidence only; no raw payloads, provider responses, field values, external delivery, realtime, or direct browser writes.';

COMMENT ON FUNCTION puls_app.get_notification_center_bootstrap_status() IS
  'PR16.9.2 app-wide Notification Center status RPC. Ledger and connector producer mapping are enabled; UI, realtime, and external delivery remain closed.';

NOTIFY pgrst, 'reload schema';
