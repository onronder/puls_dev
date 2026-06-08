-- PR16.10.9 runtime safety and notification idempotency hardening.
-- Tightens audit tenant writes, normalizes connector notification dedupe keys,
-- and requires active worker leases before completion or apply execution. This
-- does not open source writeback, provider calls, browser direct writes,
-- credential readback, raw payload readback, field value readback, or snapshot
-- payload readback.

-- Authenticated audit writes must always be tenant-bound. System-wide audit
-- events stay behind service-role/RPC boundaries instead of nullable tenant
-- inserts from the browser role.
DROP POLICY IF EXISTS puls_audit_logs_insert ON puls_audit.audit_logs;
CREATE POLICY puls_audit_logs_insert ON puls_audit.audit_logs
  FOR INSERT TO authenticated
  WITH CHECK (
    tenant_id = puls_core.current_tenant_id()
    OR tenant_id = puls_core.current_legacy_public_tenant_id()
  );

CREATE OR REPLACE FUNCTION puls_app.normalize_app_notification_dedupe_key(
  p_source_domain TEXT,
  p_source_table TEXT,
  p_dedupe_key TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SET search_path = pg_catalog
AS $$
DECLARE
  v_key TEXT := NULLIF(BTRIM(COALESCE(p_dedupe_key, '')), '');
  v_parts TEXT[];
BEGIN
  IF v_key IS NULL THEN
    RETURN v_key;
  END IF;

  IF BTRIM(COALESCE(p_source_domain, '')) <> 'connector_runtime'
     OR BTRIM(COALESCE(p_source_table, '')) <> 'puls_integration.connector_jobs' THEN
    RETURN v_key;
  END IF;

  v_parts := regexp_split_to_array(v_key, ':');

  IF array_length(v_parts, 1) = 5
     AND v_parts[1] = 'pr16.9.2-connector-notification-producer-v1'
     AND v_parts[2] = 'connector_runtime'
     AND v_parts[3] IN (
       'connector_job_failed',
       'connector_job_dead_letter',
       'runtime_preflight_failed'
     )
     AND v_parts[4] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
     AND v_parts[5] IN (
       'queued',
       'running',
       'succeeded',
       'failed',
       'retrying',
       'cancelled',
       'dead_letter'
     ) THEN
    RETURN concat_ws(':', v_parts[1], v_parts[2], v_parts[3], v_parts[4]);
  END IF;

  RETURN v_key;
END;
$$;

CREATE OR REPLACE FUNCTION puls_app.normalize_app_notification_dedupe_key_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = pg_catalog, puls_app
AS $$
BEGIN
  NEW.dedupe_key := puls_app.normalize_app_notification_dedupe_key(
    NEW.source_domain,
    NEW.source_table,
    NEW.dedupe_key
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS app_notifications_normalize_dedupe_key
  ON puls_app.app_notifications;
CREATE TRIGGER app_notifications_normalize_dedupe_key
  BEFORE INSERT
  ON puls_app.app_notifications
  FOR EACH ROW
  EXECUTE FUNCTION puls_app.normalize_app_notification_dedupe_key_trigger();

-- Existing notification ledger rows are immutable by design. PR16.10.9 only
-- normalizes new connector job notification inserts; historical rows remain as
-- originally emitted and are not updated or deleted by this migration.


CREATE OR REPLACE FUNCTION puls_integration.complete_connector_job(
  p_job_id UUID,
  p_worker_id TEXT,
  p_status puls_integration.connector_job_status,
  p_safe_error_code TEXT DEFAULT NULL,
  p_safe_error_context JSONB DEFAULT '{}'::JSONB,
  p_next_action_key TEXT DEFAULT NULL,
  p_scheduled_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration
AS $$
DECLARE
  v_job puls_integration.connector_jobs;
  v_worker_id TEXT := btrim(COALESCE(p_worker_id, ''));
  v_next_status puls_integration.connector_job_status := p_status;
  v_failure_class puls_integration.connector_job_failure_class;
  v_retry_after_seconds INTEGER := 0;
  v_operator_severity puls_integration.connector_job_operator_severity;
  v_operator_review_required BOOLEAN := FALSE;
  v_next_action_key TEXT := COALESCE(NULLIF(btrim(COALESCE(p_next_action_key, '')), ''), 'review_job_status');
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_JOB_WORKER_ONLY: connector job completion requires service_role.';
  END IF;

  IF v_worker_id = '' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_JOB_WORKER_REQUIRED: worker id is required.';
  END IF;

  IF p_status NOT IN (
    'succeeded'::puls_integration.connector_job_status,
    'failed'::puls_integration.connector_job_status,
    'retrying'::puls_integration.connector_job_status,
    'cancelled'::puls_integration.connector_job_status,
    'dead_letter'::puls_integration.connector_job_status
  ) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_JOB_STATUS_INVALID: completion status % is not allowed.', p_status;
  END IF;

  IF p_safe_error_context IS NULL OR jsonb_typeof(p_safe_error_context) <> 'object' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_JOB_SAFE_CONTEXT_INVALID: safe_error_context must be a JSON object.';
  END IF;

  IF puls_integration.connector_safe_context_has_blocked_key(p_safe_error_context) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_JOB_SAFE_CONTEXT_FORBIDDEN: safe_error_context contains blocked keys.';
  END IF;

  SELECT *
  INTO v_job
  FROM puls_integration.connector_jobs cj
  WHERE cj.id = p_job_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_JOB_NOT_FOUND: job % not found.', p_job_id;
  END IF;

  IF v_job.status <> 'running'::puls_integration.connector_job_status
     OR v_job.locked_by IS DISTINCT FROM v_worker_id
     OR v_job.lease_expires_at IS NULL
     OR v_job.lease_expires_at <= NOW() THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_JOB_LOCK_INVALID: job is not locked by this worker.';
  END IF;

  v_failure_class := puls_integration.classify_connector_job_failure(
    p_safe_error_code,
    v_next_action_key
  );
  v_retry_after_seconds := puls_integration.connector_job_retry_after_seconds(
    v_failure_class,
    v_job.attempt_count
  );

  IF p_status = 'failed'::puls_integration.connector_job_status
     AND v_retry_after_seconds > 0
     AND v_job.attempt_count < v_job.max_attempts THEN
    v_next_status := 'retrying'::puls_integration.connector_job_status;
    v_next_action_key := 'wait_for_retry_window';
  ELSIF p_status = 'failed'::puls_integration.connector_job_status
     AND v_retry_after_seconds > 0
     AND v_job.attempt_count >= v_job.max_attempts THEN
    v_next_status := 'dead_letter'::puls_integration.connector_job_status;
    v_next_action_key := 'review_dead_letter_job';
  ELSIF p_status = 'retrying'::puls_integration.connector_job_status
     AND v_job.attempt_count >= v_job.max_attempts THEN
    v_next_status := 'dead_letter'::puls_integration.connector_job_status;
    v_next_action_key := 'review_dead_letter_job';
  END IF;

  IF v_next_status IN (
    'failed'::puls_integration.connector_job_status,
    'dead_letter'::puls_integration.connector_job_status
  ) THEN
    v_operator_review_required := TRUE;
  END IF;

  IF v_next_status <> 'retrying'::puls_integration.connector_job_status THEN
    v_retry_after_seconds := 0;
  END IF;

  v_operator_severity := puls_integration.connector_job_operator_severity(
    v_failure_class,
    v_next_status
  );

  UPDATE puls_integration.connector_jobs cj
  SET
    status = v_next_status,
    scheduled_at = CASE
      WHEN v_next_status = 'retrying'::puls_integration.connector_job_status
        THEN COALESCE(p_scheduled_at, NOW() + make_interval(secs => v_retry_after_seconds))
      ELSE cj.scheduled_at
    END,
    finished_at = CASE
      WHEN v_next_status = 'retrying'::puls_integration.connector_job_status THEN NULL
      ELSE NOW()
    END,
    locked_at = NULL,
    locked_by = NULL,
    worker_heartbeat_at = NULL,
    lease_expires_at = NULL,
    safe_error_code = p_safe_error_code,
    safe_error_context = COALESCE(p_safe_error_context, '{}'::JSONB),
    next_action_key = v_next_action_key,
    failure_class = v_failure_class,
    operator_severity = v_operator_severity,
    retry_after_seconds = v_retry_after_seconds,
    last_failure_at = CASE
      WHEN v_failure_class = 'none'::puls_integration.connector_job_failure_class THEN cj.last_failure_at
      ELSE NOW()
    END,
    dead_lettered_at = CASE
      WHEN v_next_status = 'dead_letter'::puls_integration.connector_job_status THEN NOW()
      ELSE cj.dead_lettered_at
    END,
    operator_review_required = v_operator_review_required
  WHERE cj.id = p_job_id;

  INSERT INTO puls_integration.connector_job_events (
    tenant_id,
    connection_id,
    job_id,
    job_type,
    status,
    event_key,
    level,
    failure_class,
    safe_error_code,
    safe_error_context,
    next_action_key,
    retry_after_seconds,
    operator_review_required,
    worker_id
  )
  VALUES (
    v_job.tenant_id,
    v_job.connection_id,
    v_job.id,
    v_job.job_type,
    v_next_status,
    puls_integration.connector_job_event_key(v_next_status),
    v_operator_severity,
    v_failure_class,
    p_safe_error_code,
    COALESCE(p_safe_error_context, '{}'::JSONB),
    v_next_action_key,
    v_retry_after_seconds,
    v_operator_review_required,
    v_worker_id
  );

  RETURN p_job_id;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration.revoke_connector_credential_reference(
  p_connection_id UUID,
  p_actor_employee_id UUID DEFAULT NULL,
  p_safe_error_code TEXT DEFAULT 'credential_reference_revoked',
  p_safe_context JSONB DEFAULT '{}'::JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_connection puls_integration.erp_connections;
  v_cancelled_job puls_integration.connector_jobs;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREDENTIAL_WORKER_ONLY: credential revocation requires service_role.';
  END IF;

  IF p_safe_context IS NULL OR jsonb_typeof(p_safe_context) <> 'object' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREDENTIAL_SAFE_CONTEXT_INVALID: safe context must be a JSON object.';
  END IF;

  IF puls_integration.connector_safe_context_has_blocked_key(p_safe_context) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREDENTIAL_SAFE_CONTEXT_FORBIDDEN: safe context contains blocked keys.';
  END IF;

  SELECT *
  INTO v_connection
  FROM puls_integration.erp_connections c
  WHERE c.id = p_connection_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREDENTIAL_CONNECTION_NOT_FOUND: connection not found.';
  END IF;

  IF v_connection.credential_required IS FALSE
     OR v_connection.auth_mode = 'none'::puls_integration.connector_auth_mode THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREDENTIAL_NOT_REQUIRED: this source does not require a credential reference.';
  END IF;

  IF v_connection.credentials_ref IS NULL THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREDENTIAL_REFERENCE_MISSING: cannot revoke a missing reference.';
  END IF;

  PERFORM puls_integration.assert_connector_credential_actor(
    v_connection.tenant_id,
    p_actor_employee_id
  );

  UPDATE puls_integration.erp_connections c
  SET
    credential_state = 'revoked'::puls_integration.connector_credential_state,
    credential_error_code = NULLIF(btrim(COALESCE(p_safe_error_code, '')), ''),
    credential_updated_by_employee_id = p_actor_employee_id,
    credential_handoff_status = 'revoked'::puls_integration.connector_credential_handoff_status,
    credential_handoff_updated_at = NOW()
  WHERE c.id = p_connection_id;

  PERFORM puls_integration.record_connector_credential_event(
    v_connection.tenant_id,
    p_connection_id,
    'reference_revoked'::puls_integration.connector_credential_event_key,
    v_connection.auth_mode,
    'revoked'::puls_integration.connector_credential_state,
    p_actor_employee_id,
    NULLIF(btrim(COALESCE(p_safe_error_code, '')), ''),
    COALESCE(p_safe_context, '{}'::JSONB) || jsonb_build_object('reference_available', false),
    'restore_secure_reference'
  );

  FOR v_cancelled_job IN
    UPDATE puls_integration.connector_jobs cj
    SET
      status = 'cancelled'::puls_integration.connector_job_status,
      finished_at = NOW(),
      locked_at = NULL,
      locked_by = NULL,
      safe_error_code = 'credential_reference_revoked',
      safe_error_context = jsonb_build_object('credential_state', 'revoked'),
      next_action_key = 'restore_secure_reference',
      failure_class = 'credential'::puls_integration.connector_job_failure_class,
      operator_severity = 'warning'::puls_integration.connector_job_operator_severity,
      retry_after_seconds = NULL,
      operator_review_required = TRUE
    WHERE cj.connection_id = p_connection_id
      AND cj.job_type = 'connector_runtime_preflight'::puls_integration.connector_job_type
      AND cj.status IN (
        'queued'::puls_integration.connector_job_status,
        'retrying'::puls_integration.connector_job_status,
        'running'::puls_integration.connector_job_status
      )
    RETURNING *
  LOOP
    INSERT INTO puls_integration.connector_job_events (
      tenant_id,
      connection_id,
      job_id,
      job_type,
      status,
      event_key,
      level,
      failure_class,
      safe_error_code,
      safe_error_context,
      next_action_key,
      operator_review_required
    )
    VALUES (
      v_cancelled_job.tenant_id,
      v_cancelled_job.connection_id,
      v_cancelled_job.id,
      v_cancelled_job.job_type,
      'cancelled'::puls_integration.connector_job_status,
      'connector_job_cancelled',
      'warning'::puls_integration.connector_job_operator_severity,
      'credential'::puls_integration.connector_job_failure_class,
      'credential_reference_revoked',
      jsonb_build_object('credential_state', 'revoked'),
      'restore_secure_reference',
      TRUE
    );
  END LOOP;

  RETURN p_connection_id;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration.mark_connector_credential_verification(
  p_connection_id UUID,
  p_verified BOOLEAN,
  p_actor_employee_id UUID DEFAULT NULL,
  p_safe_error_code TEXT DEFAULT NULL,
  p_safe_context JSONB DEFAULT '{}'::JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_connection puls_integration.erp_connections;
  v_state puls_integration.connector_credential_state;
  v_event_key puls_integration.connector_credential_event_key;
  v_safe_error_code TEXT := NULLIF(btrim(COALESCE(p_safe_error_code, '')), '');
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREDENTIAL_WORKER_ONLY: credential verification requires service_role.';
  END IF;

  IF p_safe_context IS NULL OR jsonb_typeof(p_safe_context) <> 'object' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREDENTIAL_SAFE_CONTEXT_INVALID: safe context must be a JSON object.';
  END IF;

  IF puls_integration.connector_safe_context_has_blocked_key(p_safe_context) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREDENTIAL_SAFE_CONTEXT_FORBIDDEN: safe context contains blocked keys.';
  END IF;

  SELECT *
  INTO v_connection
  FROM puls_integration.erp_connections c
  WHERE c.id = p_connection_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREDENTIAL_CONNECTION_NOT_FOUND: connection not found.';
  END IF;

  IF v_connection.credentials_ref IS NULL THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREDENTIAL_REFERENCE_MISSING: verification requires an opaque reference.';
  END IF;

  IF p_verified
     AND v_connection.credential_state = 'revoked'::puls_integration.connector_credential_state THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREDENTIAL_REVOKED: revoked credential reference cannot be marked verified.';
  END IF;

  IF p_verified
     AND v_connection.credential_handoff_status = 'revoked'::puls_integration.connector_credential_handoff_status THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREDENTIAL_HANDOFF_REVOKED: revoked credential handoff cannot be marked verified.';
  END IF;

  PERFORM puls_integration.assert_connector_credential_actor(
    v_connection.tenant_id,
    p_actor_employee_id
  );

  v_state := CASE
    WHEN p_verified THEN 'verified'::puls_integration.connector_credential_state
    ELSE 'failed'::puls_integration.connector_credential_state
  END;
  v_event_key := CASE
    WHEN p_verified THEN 'verification_succeeded'::puls_integration.connector_credential_event_key
    ELSE 'verification_failed'::puls_integration.connector_credential_event_key
  END;

  IF p_verified IS FALSE AND v_safe_error_code IS NULL THEN
    v_safe_error_code := 'credential_verification_failed';
  END IF;

  UPDATE puls_integration.erp_connections c
  SET
    credential_state = v_state,
    credential_last_verified_at = CASE WHEN p_verified THEN NOW() ELSE c.credential_last_verified_at END,
    credential_last_failed_at = CASE WHEN p_verified THEN NULL ELSE NOW() END,
    credential_error_code = CASE WHEN p_verified THEN NULL ELSE v_safe_error_code END,
    credential_updated_by_employee_id = p_actor_employee_id,
    credential_handoff_status = CASE
      WHEN p_verified
        THEN 'verified'::puls_integration.connector_credential_handoff_status
      ELSE 'failed'::puls_integration.connector_credential_handoff_status
    END,
    credential_handoff_updated_at = NOW()
  WHERE c.id = p_connection_id;

  PERFORM puls_integration.record_connector_credential_event(
    v_connection.tenant_id,
    p_connection_id,
    v_event_key,
    v_connection.auth_mode,
    v_state,
    p_actor_employee_id,
    v_safe_error_code,
    COALESCE(p_safe_context, '{}'::JSONB) || jsonb_build_object('reference_available', true),
    CASE WHEN p_verified THEN 'run_runtime_preflight' ELSE 'review_secure_reference' END
  );

  RETURN p_connection_id;
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
  v_auth_role TEXT := COALESCE(auth.role(), '');
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
  IF v_auth_role <> 'service_role' THEN
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
     OR v_job.locked_by IS DISTINCT FROM v_worker_id
     OR v_job.lease_expires_at IS NULL
     OR v_job.lease_expires_at <= NOW() THEN
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

CREATE OR REPLACE FUNCTION puls_integration.execute_connector_guarded_update_apply_job(
  p_job_id UUID,
  p_worker_id TEXT
)
RETURNS TABLE (
  change_set_id UUID,
  import_batch_id UUID,
  status TEXT,
  row_count INTEGER,
  update_count INTEGER,
  field_diff_count INTEGER,
  rollback_snapshot_count INTEGER,
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
  v_auth_role TEXT := COALESCE(auth.role(), '');
  v_job puls_integration.connector_jobs;
  v_worker_id TEXT := btrim(COALESCE(p_worker_id, ''));
  v_change_set_id UUID;
  v_change_set puls_integration.connector_apply_change_sets;
  v_batch puls_integration.import_batches;
  v_namespace puls_integration.source_namespaces;
  v_item puls_integration.connector_apply_change_set_items;
  v_record puls_integration.import_records;
  v_canonical_id UUID;
  v_update_count INTEGER := 0;
  v_field_diff_count INTEGER := 0;
  v_snapshot_count INTEGER := 0;
  v_existing_event_count INTEGER := 0;
BEGIN
  IF v_auth_role <> 'service_role' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_WORKER_ONLY: guarded update apply execution requires service_role.';
  END IF;

  IF v_worker_id = '' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_WORKER_REQUIRED: worker id is required.';
  END IF;

  SELECT *
  INTO v_job
  FROM puls_integration.connector_jobs cj
  WHERE cj.id = p_job_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_JOB_NOT_FOUND: connector job not found.';
  END IF;

  IF v_job.job_type <> 'import_apply'::puls_integration.connector_job_type THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_JOB_TYPE_INVALID: job type must be import_apply.';
  END IF;

  IF v_job.status <> 'running'::puls_integration.connector_job_status
     OR v_job.locked_by IS DISTINCT FROM v_worker_id
     OR v_job.lease_expires_at IS NULL
     OR v_job.lease_expires_at <= NOW() THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_JOB_LEASE_INVALID: worker does not own this running job.';
  END IF;

  IF v_job.safe_error_context ->> 'contract_version' IS DISTINCT FROM 'pr16.4.2-guarded-update-worker-apply-v1'
     OR v_job.safe_error_context ->> 'apply_mode' IS DISTINCT FROM 'guarded_update' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_JOB_CONTEXT_INVALID: job is not a PR16.4.2 guarded update apply job.';
  END IF;

  IF v_job.safe_error_context ->> 'change_set_id' IS NULL
     OR v_job.safe_error_context ->> 'change_set_id'
       !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_JOB_CONTEXT_INVALID: job is missing a valid change_set_id.';
  END IF;

  v_change_set_id := (v_job.safe_error_context ->> 'change_set_id')::UUID;

  SELECT *
  INTO v_change_set
  FROM puls_integration.connector_apply_change_sets cs
  WHERE cs.id = v_change_set_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_CHANGE_SET_NOT_FOUND: change-set not found.';
  END IF;

  IF v_change_set.tenant_id IS DISTINCT FROM v_job.tenant_id
     OR v_change_set.connection_id IS DISTINCT FROM v_job.connection_id
     OR v_change_set.source_namespace_id IS DISTINCT FROM v_job.source_namespace_id
     OR v_change_set.import_batch_id IS DISTINCT FROM v_job.import_batch_id THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_JOB_CONTEXT_MISMATCH: job context does not match change-set.';
  END IF;

  v_batch := puls_integration._import_lock_batch(v_change_set.import_batch_id);

  SELECT *
  INTO v_namespace
  FROM puls_integration.source_namespaces sn
  WHERE sn.id = v_change_set.source_namespace_id
    AND sn.tenant_id = v_change_set.tenant_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_NAMESPACE_REQUIRED: source namespace is missing.';
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
      RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_ALREADY_APPLIED: change-set was applied by another job.';
    END IF;

    SELECT COUNT(*)::INTEGER
    INTO v_field_diff_count
    FROM puls_integration.connector_apply_field_diffs diff
    WHERE diff.change_set_id = v_change_set.id;

    SELECT COUNT(*)::INTEGER
    INTO v_snapshot_count
    FROM puls_integration.connector_apply_rollback_snapshots snap
    WHERE snap.change_set_id = v_change_set.id
      AND snap.snapshot_state = 'available';

    RETURN QUERY
    SELECT
      v_change_set.id,
      v_change_set.import_batch_id,
      'applied_guarded_update'::TEXT,
      v_change_set.row_count,
      v_change_set.update_count,
      v_field_diff_count,
      v_snapshot_count,
      v_existing_event_count,
      TRUE,
      TRUE,
      FALSE,
      FALSE,
      'review_guarded_update_object_events'::TEXT;
    RETURN;
  END IF;

  PERFORM puls_integration._connector_apply_validate_guarded_update_change_set(v_change_set_id);

  IF v_batch.status = 'applied'::puls_integration.import_batch_status THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_BATCH_ALREADY_APPLIED: batch is already applied.';
  END IF;

  SELECT COUNT(*)::INTEGER
  INTO v_field_diff_count
  FROM puls_integration.connector_apply_field_diffs diff
  WHERE diff.change_set_id = v_change_set.id;

  SELECT COUNT(*)::INTEGER
  INTO v_snapshot_count
  FROM puls_integration.connector_apply_rollback_snapshots snap
  WHERE snap.change_set_id = v_change_set.id
    AND snap.snapshot_state = 'available';

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
      RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_RECORD_INVALID: row % is not validated.', v_item.row_number;
    END IF;

    v_canonical_id := puls_integration._connector_apply_update_reference_name(
      v_batch,
      v_namespace,
      v_item,
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
      'update'::puls_integration.connector_apply_operation,
      v_item.entity_type,
      v_item.external_id,
      v_item.target_table,
      v_canonical_id,
      v_item.source_row_hash,
      v_change_set.change_set_checksum,
      ARRAY[
        'object_event'::puls_integration.connector_apply_audit_tier,
        'field_diff'::puls_integration.connector_apply_audit_tier,
        'rollback_snapshot'::puls_integration.connector_apply_audit_tier
      ],
      'object_event',
      jsonb_build_object(
        'contract_version', 'pr16.4.2-guarded-update-worker-apply-v1',
        'change_set_id', v_change_set.id,
        'import_batch_id', v_change_set.import_batch_id,
        'row_number', v_item.row_number,
        'entity_type', v_item.entity_type,
        'target_table', v_item.target_table,
        'operation', 'update',
        'safe_field_names', ARRAY['name']::TEXT[],
        'destructive_field_names', '{}'::TEXT[],
        'field_diff_count', (
          SELECT COUNT(*)::INTEGER
          FROM puls_integration.connector_apply_field_diffs diff
          WHERE diff.change_set_item_id = v_item.id
        ),
        'rollback_snapshot_required', TRUE,
        'canonical_write', TRUE,
        'source_writeback', FALSE,
        'credential_readback', FALSE,
        'provider_api_calls', FALSE,
        'raw_payload_readback', FALSE,
        'field_value_readback', FALSE,
        'rollback_execution', FALSE
      ),
      v_worker_id
    );

    v_update_count := v_update_count + 1;
  END LOOP;

  IF v_update_count <> v_change_set.update_count THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_GUARDED_UPDATE_COUNT_MISMATCH: updated record count does not match change-set.';
  END IF;

  UPDATE puls_integration.import_batches ib
  SET
    status = 'applied'::puls_integration.import_batch_status,
    applied_at = NOW(),
    applied_by_employee_id = v_job.created_by_employee_id,
    create_count = 0,
    update_count = v_update_count,
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
    0,
    v_update_count,
    0,
    0,
    'import_apply_guarded_update_completed',
    v_job.created_by_employee_id,
    NULL,
    jsonb_build_object(
      'contract_version', 'pr16.4.2-guarded-update-worker-apply-v1',
      'change_set_id', v_change_set.id,
      'import_batch_id', v_change_set.import_batch_id,
      'row_count', v_change_set.row_count,
      'update_count', v_update_count,
      'field_diff_count', v_field_diff_count,
      'rollback_snapshot_count', v_snapshot_count,
      'object_event_count', v_update_count,
      'execution_enabled', TRUE,
      'canonical_write_enabled', TRUE,
      'source_writeback_enabled', FALSE,
      'credential_readback_enabled', FALSE,
      'provider_api_calls', FALSE,
      'raw_payload_readback', FALSE,
      'field_value_readback', FALSE,
      'rollback_execution', FALSE
    ),
    'review_guarded_update_object_events'
  );

  RETURN QUERY
  SELECT
    v_change_set.id,
    v_change_set.import_batch_id,
    'applied_guarded_update'::TEXT,
    v_change_set.row_count,
    v_update_count,
    v_field_diff_count,
    v_snapshot_count,
    v_update_count,
    TRUE,
    TRUE,
    FALSE,
    FALSE,
    'review_guarded_update_object_events'::TEXT;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration.execute_connector_guarded_update_rollback_apply_job(
  p_job_id UUID,
  p_worker_id TEXT
)
RETURNS TABLE (
  rollback_worker_readiness_id UUID,
  rollback_approval_id UUID,
  rollback_preview_id UUID,
  change_set_id UUID,
  import_batch_id UUID,
  status TEXT,
  row_count INTEGER,
  rollback_count INTEGER,
  field_diff_count INTEGER,
  rollback_snapshot_count INTEGER,
  object_event_count INTEGER,
  execution_enabled BOOLEAN,
  canonical_write_enabled BOOLEAN,
  rollback_execution_enabled BOOLEAN,
  source_writeback_enabled BOOLEAN,
  credential_readback_enabled BOOLEAN,
  provider_api_calls_enabled BOOLEAN,
  next_action_key TEXT
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
#variable_conflict use_column
DECLARE
  v_auth_role TEXT := COALESCE(auth.role(), '');
  v_job puls_integration.connector_jobs;
  v_worker_id TEXT := btrim(COALESCE(p_worker_id, ''));
  v_readiness_id UUID;
  v_readiness puls_integration.connector_apply_rollback_worker_readiness;
  v_change_set puls_integration.connector_apply_change_sets;
  v_batch puls_integration.import_batches;
  v_namespace puls_integration.source_namespaces;
  v_preview_item puls_integration.connector_apply_rollback_preview_items;
  v_snapshot puls_integration.connector_apply_rollback_snapshots;
  v_canonical_id UUID;
  v_rollback_count INTEGER := 0;
  v_existing_event_count INTEGER := 0;
  v_field_diff_count INTEGER := 0;
  v_snapshot_count INTEGER := 0;
  v_original_apply_event_id UUID;
BEGIN
  IF v_auth_role <> 'service_role' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_ONLY: guarded update rollback execution requires service_role.';
  END IF;

  IF v_worker_id = '' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_REQUIRED: worker id is required.';
  END IF;

  SELECT *
  INTO v_job
  FROM puls_integration.connector_jobs cj
  WHERE cj.id = p_job_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_JOB_NOT_FOUND: connector job not found.';
  END IF;

  IF v_job.job_type <> 'import_apply'::puls_integration.connector_job_type THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_JOB_TYPE_INVALID: job type must be import_apply.';
  END IF;

  IF v_job.status <> 'running'::puls_integration.connector_job_status
     OR v_job.locked_by IS DISTINCT FROM v_worker_id
     OR v_job.lease_expires_at IS NULL
     OR v_job.lease_expires_at <= NOW() THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_JOB_LEASE_INVALID: worker does not own this running job.';
  END IF;

  IF v_job.domain IS DISTINCT FROM 'import_apply_guarded_update_rollback'
     OR v_job.safe_error_context ->> 'contract_version' IS DISTINCT FROM 'pr16.8-guarded-update-rollback-worker-apply-v1'
     OR v_job.safe_error_context ->> 'apply_mode' IS DISTINCT FROM 'guarded_update_rollback' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_JOB_CONTEXT_INVALID: job is not a PR16.8 rollback apply job.';
  END IF;

  IF v_job.safe_error_context ->> 'rollback_worker_readiness_id' IS NULL
     OR v_job.safe_error_context ->> 'rollback_worker_readiness_id'
       !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_JOB_CONTEXT_INVALID: job is missing a valid rollback_worker_readiness_id.';
  END IF;

  v_readiness_id := (v_job.safe_error_context ->> 'rollback_worker_readiness_id')::UUID;
  PERFORM puls_integration._connector_apply_validate_guarded_update_rollback_readiness(v_readiness_id);

  SELECT *
  INTO v_readiness
  FROM puls_integration.connector_apply_rollback_worker_readiness readiness
  WHERE readiness.id = v_readiness_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_READINESS_NOT_FOUND: rollback worker readiness not found.';
  END IF;

  IF v_readiness.tenant_id IS DISTINCT FROM v_job.tenant_id
     OR v_readiness.connection_id IS DISTINCT FROM v_job.connection_id
     OR v_readiness.source_namespace_id IS DISTINCT FROM v_job.source_namespace_id
     OR v_readiness.import_batch_id IS DISTINCT FROM v_job.import_batch_id
     OR v_readiness.rollback_preview_checksum IS DISTINCT FROM v_job.safe_error_context ->> 'rollback_preview_checksum' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_JOB_CONTEXT_MISMATCH: job context does not match rollback readiness.';
  END IF;

  SELECT *
  INTO v_change_set
  FROM puls_integration.connector_apply_change_sets cs
  WHERE cs.id = v_readiness.change_set_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_CHANGE_SET_NOT_FOUND: change-set not found.';
  END IF;

  v_batch := puls_integration._import_lock_batch(v_readiness.import_batch_id);

  SELECT *
  INTO v_namespace
  FROM puls_integration.source_namespaces sn
  WHERE sn.id = v_readiness.source_namespace_id
    AND sn.tenant_id = v_readiness.tenant_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_NAMESPACE_REQUIRED: source namespace is missing.';
  END IF;

  SELECT COUNT(*)::INTEGER
  INTO v_existing_event_count
  FROM puls_integration.connector_apply_object_events event
  WHERE event.change_set_id = v_readiness.change_set_id
    AND event.operation = 'rollback'::puls_integration.connector_apply_operation;

  IF v_existing_event_count > 0 THEN
    IF EXISTS (
      SELECT 1
      FROM puls_integration.connector_apply_object_events event
      WHERE event.change_set_id = v_readiness.change_set_id
        AND event.operation = 'rollback'::puls_integration.connector_apply_operation
        AND event.connector_job_id IS DISTINCT FROM v_job.id
    ) THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_ALREADY_APPLIED: rollback was applied by another job.';
    END IF;

    RETURN QUERY
    SELECT
      v_readiness.id,
      v_readiness.rollback_approval_id,
      v_readiness.rollback_preview_id,
      v_readiness.change_set_id,
      v_readiness.import_batch_id,
      'applied_guarded_update_rollback'::TEXT,
      v_readiness.row_count,
      v_readiness.rollback_count,
      v_readiness.field_diff_count,
      v_readiness.rollback_snapshot_count,
      v_existing_event_count,
      TRUE,
      TRUE,
      TRUE,
      FALSE,
      FALSE,
      FALSE,
      'review_guarded_update_rollback_object_events'::TEXT;
    RETURN;
  END IF;

  SELECT COUNT(*)::INTEGER
  INTO v_field_diff_count
  FROM puls_integration.connector_apply_field_diffs diff
  WHERE diff.change_set_id = v_readiness.change_set_id;

  SELECT COUNT(*)::INTEGER
  INTO v_snapshot_count
  FROM puls_integration.connector_apply_rollback_snapshots snap
  WHERE snap.change_set_id = v_readiness.change_set_id
    AND snap.snapshot_state = 'available'
    AND snap.hot_retention_expires_at > NOW();

  PERFORM set_config('puls.import_apply.active', 'true', true);

  FOR v_preview_item IN
    SELECT item.*
    FROM puls_integration.connector_apply_rollback_preview_items item
    WHERE item.rollback_preview_id = v_readiness.rollback_preview_id
      AND item.item_status = 'ready'
    ORDER BY CASE item.entity_type
      WHEN 'legal_entity'::puls_integration.import_entity_type THEN 10
      WHEN 'location'::puls_integration.import_entity_type THEN 20
      WHEN 'cost_center'::puls_integration.import_entity_type THEN 30
      WHEN 'department'::puls_integration.import_entity_type THEN 40
      WHEN 'position'::puls_integration.import_entity_type THEN 50
      ELSE 100
    END,
    item.row_number
  LOOP
    SELECT *
    INTO v_snapshot
    FROM puls_integration.connector_apply_rollback_snapshots snap
    WHERE snap.change_set_item_id = v_preview_item.change_set_item_id
      AND snap.snapshot_state = 'available'
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_SNAPSHOT_REQUIRED: row % rollback snapshot is missing.', v_preview_item.row_number;
    END IF;

    v_original_apply_event_id := NULL;

    SELECT event.id
    INTO v_original_apply_event_id
    FROM puls_integration.connector_apply_object_events event
    WHERE event.change_set_item_id = v_preview_item.change_set_item_id
      AND event.operation = 'update'::puls_integration.connector_apply_operation
      AND event.canonical_id = v_preview_item.canonical_id
    ORDER BY event.created_at DESC
    LIMIT 1;

    IF v_original_apply_event_id IS NULL THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_ORIGINAL_EVENT_REQUIRED: row % original apply object event is missing.', v_preview_item.row_number;
    END IF;

    v_canonical_id := puls_integration._connector_apply_restore_reference_name(
      v_batch,
      v_namespace,
      v_preview_item,
      v_snapshot
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
      v_readiness.tenant_id,
      v_readiness.connection_id,
      v_readiness.source_namespace_id,
      v_readiness.import_batch_id,
      v_readiness.change_set_id,
      v_preview_item.change_set_item_id,
      v_preview_item.import_record_id,
      v_job.id,
      'rollback'::puls_integration.connector_apply_operation,
      v_preview_item.entity_type,
      v_preview_item.external_id,
      v_preview_item.target_table,
      v_canonical_id,
      v_snapshot.snapshot_hash,
      v_change_set.change_set_checksum,
      ARRAY[
        'object_event'::puls_integration.connector_apply_audit_tier,
        'field_diff'::puls_integration.connector_apply_audit_tier,
        'rollback_snapshot'::puls_integration.connector_apply_audit_tier
      ],
      'object_event',
      jsonb_build_object(
        'contract_version', 'pr16.8-guarded-update-rollback-worker-apply-v1',
        'rollback_worker_readiness_id', v_readiness.id,
        'rollback_approval_id', v_readiness.rollback_approval_id,
        'rollback_preview_id', v_readiness.rollback_preview_id,
        'change_set_id', v_readiness.change_set_id,
        'import_batch_id', v_readiness.import_batch_id,
        'original_apply_event_id', v_original_apply_event_id,
        'row_number', v_preview_item.row_number,
        'entity_type', v_preview_item.entity_type,
        'target_table', v_preview_item.target_table,
        'operation', 'rollback',
        'safe_field_names', ARRAY['name']::TEXT[],
        'rollback_field_names', v_preview_item.rollback_field_names,
        'destructive_field_names', '{}'::TEXT[],
        'field_diff_count', v_preview_item.field_diff_count,
        'rollback_snapshot_required', TRUE,
        'rollback_execution', TRUE,
        'canonical_write', TRUE,
        'compensating_execution', FALSE,
        'source_writeback', FALSE,
        'credential_readback', FALSE,
        'provider_api_calls', FALSE,
        'raw_payload_readback', FALSE,
        'field_value_readback', FALSE,
        'snapshot_payload_readback', FALSE
      ),
      v_worker_id
    );

    v_rollback_count := v_rollback_count + 1;
  END LOOP;

  IF v_rollback_count <> v_readiness.rollback_count THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_ROLLBACK_WORKER_COUNT_MISMATCH: rollback record count does not match readiness.';
  END IF;

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
    v_readiness.tenant_id,
    v_readiness.connection_id,
    'import_apply_execution',
    'success'::puls_integration.sync_status,
    v_job.started_at,
    NOW(),
    v_readiness.row_count,
    0,
    v_rollback_count,
    0,
    0,
    'import_apply_guarded_update_rollback_completed',
    v_job.created_by_employee_id,
    NULL,
    jsonb_build_object(
      'contract_version', 'pr16.8-guarded-update-rollback-worker-apply-v1',
      'rollback_worker_readiness_id', v_readiness.id,
      'rollback_approval_id', v_readiness.rollback_approval_id,
      'rollback_preview_id', v_readiness.rollback_preview_id,
      'change_set_id', v_readiness.change_set_id,
      'import_batch_id', v_readiness.import_batch_id,
      'row_count', v_readiness.row_count,
      'rollback_count', v_rollback_count,
      'field_diff_count', v_field_diff_count,
      'rollback_snapshot_count', v_snapshot_count,
      'object_event_count', v_rollback_count,
      'execution_enabled', TRUE,
      'canonical_write_enabled', TRUE,
      'rollback_execution_enabled', TRUE,
      'compensating_execution_enabled', FALSE,
      'source_writeback_enabled', FALSE,
      'credential_readback_enabled', FALSE,
      'provider_api_calls', FALSE,
      'raw_payload_readback', FALSE,
      'field_value_readback', FALSE,
      'snapshot_payload_readback', FALSE
    ),
    'review_guarded_update_rollback_object_events'
  );

  RETURN QUERY
  SELECT
    v_readiness.id,
    v_readiness.rollback_approval_id,
    v_readiness.rollback_preview_id,
    v_readiness.change_set_id,
    v_readiness.import_batch_id,
    'applied_guarded_update_rollback'::TEXT,
    v_readiness.row_count,
    v_rollback_count,
    v_field_diff_count,
    v_snapshot_count,
    v_rollback_count,
    TRUE,
    TRUE,
    TRUE,
    FALSE,
    FALSE,
    FALSE,
    'review_guarded_update_rollback_object_events'::TEXT;
END;
$$;



REVOKE ALL ON FUNCTION puls_app.normalize_app_notification_dedupe_key(TEXT, TEXT, TEXT)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION puls_app.normalize_app_notification_dedupe_key(TEXT, TEXT, TEXT)
  TO service_role;

REVOKE ALL ON FUNCTION puls_app.normalize_app_notification_dedupe_key_trigger()
  FROM PUBLIC, anon, authenticated;

COMMENT ON FUNCTION puls_app.normalize_app_notification_dedupe_key(TEXT, TEXT, TEXT) IS
  'PR16.10.9 immutable connector notification dedupe normalizer. Removes mutable job.status from connector job notification keys without reading provider, credential, raw payload, field value, or snapshot data.';

COMMENT ON POLICY puls_audit_logs_insert ON puls_audit.audit_logs IS
  'PR16.10.9 tenant-bound authenticated audit insert policy. Nullable tenant audit writes require controlled service-role/RPC boundaries.';
