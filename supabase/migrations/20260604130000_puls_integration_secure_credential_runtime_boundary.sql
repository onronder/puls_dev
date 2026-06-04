-- PR15.4 secure credential storage and runtime boundary.
-- Stores only opaque server-side references, never connector secret values.

DO $$
BEGIN
  CREATE TYPE puls_integration.connector_credential_event_key AS ENUM (
    'reference_configured',
    'reference_updated',
    'reference_revoked',
    'verification_succeeded',
    'verification_failed'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE OR REPLACE FUNCTION puls_integration.connector_credential_reference_is_safe(
  p_credentials_ref TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog
AS $$
  SELECT
    p_credentials_ref IS NOT NULL
    AND btrim(p_credentials_ref) = p_credentials_ref
    AND length(p_credentials_ref) BETWEEN 24 AND 280
    AND lower(p_credentials_ref) ~ '^(pulsref|vaultref|supavault|awsref|gcpref|azureref)://[a-z0-9][a-z0-9._~:/-]+$'
    AND p_credentials_ref !~ '[[:space:]?=&@]'
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'erp_connections_credentials_ref_safe_format'
  ) THEN
    ALTER TABLE puls_integration.erp_connections
      ADD CONSTRAINT erp_connections_credentials_ref_safe_format
      CHECK (
        credentials_ref IS NULL
        OR puls_integration.connector_credential_reference_is_safe(credentials_ref)
      );
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS puls_integration.connector_credential_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  connection_id UUID NOT NULL REFERENCES puls_integration.erp_connections(id) ON DELETE CASCADE,
  event_key puls_integration.connector_credential_event_key NOT NULL,
  auth_mode puls_integration.connector_auth_mode NOT NULL,
  credential_state puls_integration.connector_credential_state NOT NULL,
  actor_employee_id UUID NULL REFERENCES puls_core.employees(id) ON DELETE SET NULL,
  safe_error_code TEXT NULL,
  safe_context JSONB NOT NULL DEFAULT '{}'::JSONB,
  next_action_key TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (jsonb_typeof(safe_context) = 'object'),
  CHECK (puls_integration.connector_safe_context_has_blocked_key(safe_context) IS FALSE)
);

CREATE INDEX IF NOT EXISTS connector_credential_events_connection_created_idx
  ON puls_integration.connector_credential_events (tenant_id, connection_id, created_at DESC);

CREATE INDEX IF NOT EXISTS connector_credential_events_state_idx
  ON puls_integration.connector_credential_events (tenant_id, credential_state, created_at DESC);

CREATE OR REPLACE FUNCTION puls_integration.assert_connector_credential_actor(
  p_tenant_id UUID,
  p_actor_employee_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
BEGIN
  IF p_actor_employee_id IS NULL THEN
    RETURN;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM puls_core.employees e
    WHERE e.id = p_actor_employee_id
      AND e.tenant_id = p_tenant_id
  ) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREDENTIAL_ACTOR_INVALID: actor is missing or cross-tenant.';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration.record_connector_credential_event(
  p_tenant_id UUID,
  p_connection_id UUID,
  p_event_key puls_integration.connector_credential_event_key,
  p_auth_mode puls_integration.connector_auth_mode,
  p_credential_state puls_integration.connector_credential_state,
  p_actor_employee_id UUID DEFAULT NULL,
  p_safe_error_code TEXT DEFAULT NULL,
  p_safe_context JSONB DEFAULT '{}'::JSONB,
  p_next_action_key TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration
AS $$
DECLARE
  v_event_id UUID;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREDENTIAL_WORKER_ONLY: credential event recording requires service_role.';
  END IF;

  IF p_safe_context IS NULL OR jsonb_typeof(p_safe_context) <> 'object' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREDENTIAL_SAFE_CONTEXT_INVALID: safe context must be a JSON object.';
  END IF;

  IF puls_integration.connector_safe_context_has_blocked_key(p_safe_context) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREDENTIAL_SAFE_CONTEXT_FORBIDDEN: safe context contains blocked keys.';
  END IF;

  INSERT INTO puls_integration.connector_credential_events (
    tenant_id,
    connection_id,
    event_key,
    auth_mode,
    credential_state,
    actor_employee_id,
    safe_error_code,
    safe_context,
    next_action_key
  )
  VALUES (
    p_tenant_id,
    p_connection_id,
    p_event_key,
    p_auth_mode,
    p_credential_state,
    p_actor_employee_id,
    NULLIF(btrim(COALESCE(p_safe_error_code, '')), ''),
    COALESCE(p_safe_context, '{}'::JSONB),
    NULLIF(btrim(COALESCE(p_next_action_key, '')), '')
  )
  RETURNING id INTO v_event_id;

  RETURN v_event_id;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration.set_connector_credential_reference(
  p_connection_id UUID,
  p_credentials_ref TEXT,
  p_actor_employee_id UUID DEFAULT NULL,
  p_safe_context JSONB DEFAULT '{}'::JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_connection puls_integration.erp_connections;
  v_ref TEXT := btrim(COALESCE(p_credentials_ref, ''));
  v_event_key puls_integration.connector_credential_event_key;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREDENTIAL_WORKER_ONLY: credential reference writes require service_role.';
  END IF;

  IF NOT puls_integration.connector_credential_reference_is_safe(v_ref) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_CREDENTIAL_REFERENCE_INVALID: credential reference must use an approved opaque reference format.';
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

  PERFORM puls_integration.assert_connector_credential_actor(
    v_connection.tenant_id,
    p_actor_employee_id
  );

  v_event_key := CASE
    WHEN v_connection.credentials_ref IS NULL
      OR v_connection.credential_state IN (
        'missing'::puls_integration.connector_credential_state,
        'revoked'::puls_integration.connector_credential_state
      )
      THEN 'reference_configured'::puls_integration.connector_credential_event_key
    ELSE 'reference_updated'::puls_integration.connector_credential_event_key
  END;

  UPDATE puls_integration.erp_connections c
  SET
    credentials_ref = v_ref,
    credential_state = 'configured'::puls_integration.connector_credential_state,
    credential_last_failed_at = NULL,
    credential_error_code = NULL,
    credential_updated_by_employee_id = p_actor_employee_id,
    credential_handoff_status = 'ready_for_verification'::puls_integration.connector_credential_handoff_status,
    credential_handoff_updated_at = NOW(),
    setup_metadata = COALESCE(c.setup_metadata, '{}'::JSONB) || jsonb_build_object(
      'credential_storage_boundary', 'server_side_reference',
      'credential_readback', 'disabled',
      'credential_reference_format', 'opaque'
    )
  WHERE c.id = p_connection_id;

  PERFORM puls_integration.record_connector_credential_event(
    v_connection.tenant_id,
    p_connection_id,
    v_event_key,
    v_connection.auth_mode,
    'configured'::puls_integration.connector_credential_state,
    p_actor_employee_id,
    NULL,
    COALESCE(p_safe_context, '{}'::JSONB) || jsonb_build_object('reference_available', true),
    'run_credential_verification'
  );

  RETURN p_connection_id;
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
        'retrying'::puls_integration.connector_job_status
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

CREATE OR REPLACE FUNCTION puls_integration.list_connector_credential_events(
  p_connection_id UUID DEFAULT NULL,
  p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
  id UUID,
  tenant_id UUID,
  connection_id UUID,
  event_key puls_integration.connector_credential_event_key,
  auth_mode puls_integration.connector_auth_mode,
  credential_state puls_integration.connector_credential_state,
  actor_employee_id UUID,
  safe_error_code TEXT,
  safe_context JSONB,
  next_action_key TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_tenant_id UUID := puls_core.current_tenant_id();
  v_limit INTEGER := LEAST(GREATEST(COALESCE(p_limit, 10), 1), 50);
BEGIN
  IF auth.role() <> 'service_role' THEN
    IF v_tenant_id IS NULL OR NOT puls_integration.is_connector_job_reader() THEN
      RETURN;
    END IF;
  END IF;

  RETURN QUERY
  SELECT
    cce.id,
    cce.tenant_id,
    cce.connection_id,
    cce.event_key,
    cce.auth_mode,
    cce.credential_state,
    cce.actor_employee_id,
    cce.safe_error_code,
    cce.safe_context,
    cce.next_action_key,
    cce.created_at
  FROM puls_integration.connector_credential_events cce
  WHERE (auth.role() = 'service_role' OR cce.tenant_id = v_tenant_id)
    AND (p_connection_id IS NULL OR cce.connection_id = p_connection_id)
  ORDER BY cce.created_at DESC
  LIMIT v_limit;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration.enqueue_connector_job(
  p_job_type puls_integration.connector_job_type,
  p_idempotency_key TEXT,
  p_connection_id UUID DEFAULT NULL,
  p_source_namespace_id UUID DEFAULT NULL,
  p_import_batch_id UUID DEFAULT NULL,
  p_domain TEXT DEFAULT NULL,
  p_priority INTEGER DEFAULT 100,
  p_scheduled_at TIMESTAMPTZ DEFAULT NOW(),
  p_max_attempts INTEGER DEFAULT 3,
  p_safe_error_context JSONB DEFAULT '{}'::JSONB,
  p_next_action_key TEXT DEFAULT NULL,
  p_tenant_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_tenant_id UUID;
  v_connection_tenant_id UUID;
  v_connection_credential_required BOOLEAN;
  v_connection_credential_state puls_integration.connector_credential_state;
  v_namespace_tenant_id UUID;
  v_namespace_connection_id UUID;
  v_batch_tenant_id UUID;
  v_batch_namespace_id UUID;
  v_domain TEXT := NULLIF(lower(btrim(COALESCE(p_domain, ''))), '');
  v_idempotency_key TEXT := btrim(COALESCE(p_idempotency_key, ''));
  v_concurrency_key TEXT;
  v_existing_id UUID;
  v_job_id UUID;
BEGIN
  IF NOT puls_integration.can_enqueue_connector_job() THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_JOB_FORBIDDEN: insufficient privileges to enqueue connector job.';
  END IF;

  IF auth.role() = 'service_role' THEN
    IF p_tenant_id IS NULL THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_JOB_TENANT_REQUIRED: service_role callers must pass p_tenant_id.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM puls_core.tenants t WHERE t.id = p_tenant_id) THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_JOB_TENANT_INVALID: tenant not found.';
    END IF;
    v_tenant_id := p_tenant_id;
  ELSE
    v_tenant_id := puls_core.current_tenant_id();
    IF v_tenant_id IS NULL THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_JOB_TENANT_REQUIRED: authenticated caller has no tenant context.';
    END IF;
    IF p_tenant_id IS NOT NULL AND p_tenant_id IS DISTINCT FROM v_tenant_id THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_JOB_FORBIDDEN: p_tenant_id is not allowed for authenticated callers.';
    END IF;
  END IF;

  IF v_idempotency_key = '' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_JOB_IDEMPOTENCY_REQUIRED: idempotency key is required.';
  END IF;

  IF p_priority < 0 THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_JOB_PRIORITY_INVALID: priority must be non-negative.';
  END IF;

  IF p_max_attempts < 1 OR p_max_attempts > 10 THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_JOB_MAX_ATTEMPTS_INVALID: max_attempts must be between 1 and 10.';
  END IF;

  IF p_safe_error_context IS NULL OR jsonb_typeof(p_safe_error_context) <> 'object' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_JOB_SAFE_CONTEXT_INVALID: safe_error_context must be a JSON object.';
  END IF;

  IF puls_integration.connector_safe_context_has_blocked_key(p_safe_error_context) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_JOB_SAFE_CONTEXT_FORBIDDEN: safe_error_context contains blocked keys.';
  END IF;

  SELECT cj.id
  INTO v_existing_id
  FROM puls_integration.connector_jobs cj
  WHERE cj.tenant_id = v_tenant_id
    AND cj.idempotency_key = v_idempotency_key
  ORDER BY cj.created_at DESC
  LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    RETURN v_existing_id;
  END IF;

  IF p_connection_id IS NOT NULL THEN
    SELECT c.tenant_id, c.credential_required, c.credential_state
    INTO v_connection_tenant_id, v_connection_credential_required, v_connection_credential_state
    FROM puls_integration.erp_connections c
    WHERE c.id = p_connection_id;

    IF v_connection_tenant_id IS NULL OR v_connection_tenant_id IS DISTINCT FROM v_tenant_id THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_JOB_CONNECTION_INVALID: connection missing or cross-tenant.';
    END IF;

    IF p_job_type = 'connector_runtime_preflight'::puls_integration.connector_job_type
       AND v_connection_credential_required IS TRUE
       AND v_connection_credential_state IN (
         'missing'::puls_integration.connector_credential_state,
         'failed'::puls_integration.connector_credential_state,
         'revoked'::puls_integration.connector_credential_state
       ) THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_JOB_CREDENTIAL_BLOCKED: credential reference is not available for runtime preflight.';
    END IF;
  END IF;

  IF p_source_namespace_id IS NOT NULL THEN
    SELECT sn.tenant_id, sn.connection_id
    INTO v_namespace_tenant_id, v_namespace_connection_id
    FROM puls_integration.source_namespaces sn
    WHERE sn.id = p_source_namespace_id;

    IF v_namespace_tenant_id IS NULL OR v_namespace_tenant_id IS DISTINCT FROM v_tenant_id THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_JOB_NAMESPACE_INVALID: namespace missing or cross-tenant.';
    END IF;

    IF p_connection_id IS NOT NULL
       AND v_namespace_connection_id IS NOT NULL
       AND v_namespace_connection_id IS DISTINCT FROM p_connection_id THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_JOB_NAMESPACE_INVALID: namespace belongs to another connection.';
    END IF;
  END IF;

  IF p_import_batch_id IS NOT NULL THEN
    SELECT ib.tenant_id, ib.source_namespace_id
    INTO v_batch_tenant_id, v_batch_namespace_id
    FROM puls_integration.import_batches ib
    WHERE ib.id = p_import_batch_id;

    IF v_batch_tenant_id IS NULL OR v_batch_tenant_id IS DISTINCT FROM v_tenant_id THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_JOB_IMPORT_BATCH_INVALID: import batch missing or cross-tenant.';
    END IF;

    IF p_source_namespace_id IS NOT NULL AND v_batch_namespace_id IS DISTINCT FROM p_source_namespace_id THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_JOB_IMPORT_BATCH_INVALID: import batch belongs to another namespace.';
    END IF;
  END IF;

  v_concurrency_key := concat_ws(
    ':',
    'connection', COALESCE(p_connection_id::TEXT, 'none'),
    'namespace', COALESCE(p_source_namespace_id::TEXT, v_batch_namespace_id::TEXT, 'none'),
    'domain', COALESCE(v_domain, 'tenant'),
    'job', p_job_type::TEXT
  );

  INSERT INTO puls_integration.connector_jobs (
    tenant_id,
    connection_id,
    source_namespace_id,
    import_batch_id,
    job_type,
    status,
    domain,
    idempotency_key,
    concurrency_key,
    priority,
    max_attempts,
    scheduled_at,
    safe_error_context,
    next_action_key,
    created_by_employee_id
  )
  VALUES (
    v_tenant_id,
    p_connection_id,
    p_source_namespace_id,
    p_import_batch_id,
    p_job_type,
    'queued'::puls_integration.connector_job_status,
    v_domain,
    v_idempotency_key,
    v_concurrency_key,
    p_priority,
    p_max_attempts,
    COALESCE(p_scheduled_at, NOW()),
    COALESCE(p_safe_error_context, '{}'::JSONB),
    p_next_action_key,
    puls_core.current_employee_id()
  )
  RETURNING id INTO v_job_id;

  RETURN v_job_id;
EXCEPTION WHEN unique_violation THEN
  SELECT cj.id
  INTO v_existing_id
  FROM puls_integration.connector_jobs cj
  WHERE cj.tenant_id = v_tenant_id
    AND cj.idempotency_key = v_idempotency_key
  ORDER BY cj.created_at DESC
  LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    RETURN v_existing_id;
  END IF;

  SELECT cj.id
  INTO v_existing_id
  FROM puls_integration.connector_jobs cj
  WHERE cj.tenant_id = v_tenant_id
    AND cj.concurrency_key = v_concurrency_key
    AND cj.status IN (
      'queued'::puls_integration.connector_job_status,
      'running'::puls_integration.connector_job_status,
      'retrying'::puls_integration.connector_job_status
    )
  ORDER BY cj.created_at DESC
  LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    RETURN v_existing_id;
  END IF;

  RAISE;
END;
$$;

ALTER TABLE puls_integration.connector_credential_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS puls_integration_connector_credential_events_select
  ON puls_integration.connector_credential_events;
CREATE POLICY puls_integration_connector_credential_events_select
  ON puls_integration.connector_credential_events
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND puls_integration.is_connector_job_reader()
  );

GRANT SELECT ON puls_integration.connector_credential_events TO authenticated;
GRANT ALL ON puls_integration.connector_credential_events TO service_role;

REVOKE ALL ON FUNCTION puls_integration.connector_credential_reference_is_safe(TEXT)
  FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.assert_connector_credential_actor(UUID, UUID)
  FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.record_connector_credential_event(
  UUID,
  UUID,
  puls_integration.connector_credential_event_key,
  puls_integration.connector_auth_mode,
  puls_integration.connector_credential_state,
  UUID,
  TEXT,
  JSONB,
  TEXT
) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.set_connector_credential_reference(UUID, TEXT, UUID, JSONB)
  FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.revoke_connector_credential_reference(UUID, UUID, TEXT, JSONB)
  FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.mark_connector_credential_verification(UUID, BOOLEAN, UUID, TEXT, JSONB)
  FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.list_connector_credential_events(UUID, INTEGER)
  FROM PUBLIC, authenticated, anon;

GRANT EXECUTE ON FUNCTION puls_integration.connector_credential_reference_is_safe(TEXT)
  TO service_role;
GRANT EXECUTE ON FUNCTION puls_integration.assert_connector_credential_actor(UUID, UUID)
  TO service_role;
GRANT EXECUTE ON FUNCTION puls_integration.record_connector_credential_event(
  UUID,
  UUID,
  puls_integration.connector_credential_event_key,
  puls_integration.connector_auth_mode,
  puls_integration.connector_credential_state,
  UUID,
  TEXT,
  JSONB,
  TEXT
) TO service_role;
GRANT EXECUTE ON FUNCTION puls_integration.set_connector_credential_reference(UUID, TEXT, UUID, JSONB)
  TO service_role;
GRANT EXECUTE ON FUNCTION puls_integration.revoke_connector_credential_reference(UUID, UUID, TEXT, JSONB)
  TO service_role;
GRANT EXECUTE ON FUNCTION puls_integration.mark_connector_credential_verification(UUID, BOOLEAN, UUID, TEXT, JSONB)
  TO service_role;
GRANT EXECUTE ON FUNCTION puls_integration.list_connector_credential_events(UUID, INTEGER)
  TO authenticated, service_role;

COMMENT ON TYPE puls_integration.connector_credential_event_key IS
  'Safe credential boundary event type. Events never include connector secret values or opaque reference values.';
COMMENT ON FUNCTION puls_integration.connector_credential_reference_is_safe(TEXT) IS
  'Validates approved opaque reference formats for server-side credential storage. It does not validate or expose secret values.';
COMMENT ON TABLE puls_integration.connector_credential_events IS
  'Tenant-scoped safe credential boundary history. Stores state, safe error class, and next action only; never secret values or reference values.';
COMMENT ON FUNCTION puls_integration.set_connector_credential_reference(UUID, TEXT, UUID, JSONB) IS
  'Service-role only write boundary for opaque connector credential references. No readback is provided.';
COMMENT ON FUNCTION puls_integration.revoke_connector_credential_reference(UUID, UUID, TEXT, JSONB) IS
  'Service-role only credential reference revocation boundary. Cancels pending runtime-preflight work for the connection.';
COMMENT ON FUNCTION puls_integration.mark_connector_credential_verification(UUID, BOOLEAN, UUID, TEXT, JSONB) IS
  'Service-role only credential verification state transition with safe audit event output.';
COMMENT ON FUNCTION puls_integration.list_connector_credential_events(UUID, INTEGER) IS
  'Tenant-safe credential event read model for setup UI and AI evidence. It never returns credentials_ref or secret values.';
