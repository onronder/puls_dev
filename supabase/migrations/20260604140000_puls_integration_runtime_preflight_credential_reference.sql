-- PR15.5 runtime preflight with credential reference.
-- Queues source-independent runtime preflight only when the credential boundary is safe.

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
  v_connection_reference_available BOOLEAN;
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
    SELECT
      c.tenant_id,
      c.credential_required,
      c.credential_state,
      c.credentials_ref IS NOT NULL
    INTO
      v_connection_tenant_id,
      v_connection_credential_required,
      v_connection_credential_state,
      v_connection_reference_available
    FROM puls_integration.erp_connections c
    WHERE c.id = p_connection_id;

    IF v_connection_tenant_id IS NULL OR v_connection_tenant_id IS DISTINCT FROM v_tenant_id THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_JOB_CONNECTION_INVALID: connection missing or cross-tenant.';
    END IF;

    IF p_job_type = 'connector_runtime_preflight'::puls_integration.connector_job_type
       AND v_connection_credential_required IS TRUE
       AND (
         v_connection_credential_state IS DISTINCT FROM 'verified'::puls_integration.connector_credential_state
         OR v_connection_reference_available IS DISTINCT FROM TRUE
       ) THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_JOB_CREDENTIAL_NOT_VERIFIED: runtime preflight requires a verified opaque credential reference.';
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
    c.provider,
    c.display_name,
    c.connection_method,
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

CREATE OR REPLACE FUNCTION puls_integration.request_connector_runtime_preflight(
  p_connection_id UUID,
  p_actor_employee_id UUID DEFAULT NULL
)
RETURNS TABLE (
  job_id UUID,
  status puls_integration.connector_job_status,
  credential_state puls_integration.connector_credential_state,
  next_action_key TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_connection puls_integration.erp_connections;
  v_source_namespace_id UUID;
  v_job_id UUID;
  v_now TIMESTAMPTZ := NOW();
  v_service_tenant_id UUID;
BEGIN
  IF NOT puls_integration.can_enqueue_connector_job() THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_RUNTIME_PREFLIGHT_FORBIDDEN: insufficient privileges to request runtime preflight.';
  END IF;

  SELECT *
  INTO v_connection
  FROM puls_integration.erp_connections c
  WHERE c.id = p_connection_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_RUNTIME_PREFLIGHT_CONNECTION_NOT_FOUND: connection not found.';
  END IF;

  IF auth.role() <> 'service_role'
     AND v_connection.tenant_id IS DISTINCT FROM puls_core.current_tenant_id() THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_RUNTIME_PREFLIGHT_FORBIDDEN: connection is outside current tenant.';
  END IF;

  PERFORM puls_integration.assert_connector_credential_actor(
    v_connection.tenant_id,
    p_actor_employee_id
  );

  IF v_connection.credential_required IS TRUE
     AND (
       v_connection.credential_state IS DISTINCT FROM 'verified'::puls_integration.connector_credential_state
       OR v_connection.credentials_ref IS NULL
     ) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_RUNTIME_PREFLIGHT_CREDENTIAL_NOT_VERIFIED: runtime preflight requires a verified opaque credential reference.';
  END IF;

  SELECT sn.id
  INTO v_source_namespace_id
  FROM puls_integration.source_namespaces sn
  WHERE sn.tenant_id = v_connection.tenant_id
    AND sn.connection_id = p_connection_id
    AND sn.is_active IS TRUE
  ORDER BY sn.priority_rank ASC, sn.created_at ASC
  LIMIT 1;

  v_service_tenant_id := CASE
    WHEN auth.role() = 'service_role' THEN v_connection.tenant_id
    ELSE NULL
  END;

  v_job_id := puls_integration.enqueue_connector_job(
    'connector_runtime_preflight'::puls_integration.connector_job_type,
    concat(
      'runtime_preflight:',
      p_connection_id::TEXT,
      ':',
      to_char(date_trunc('minute', v_now), 'YYYYMMDDHH24MI')
    ),
    p_connection_id,
    v_source_namespace_id,
    NULL,
    'runtime_preflight',
    40,
    v_now,
    2,
    jsonb_build_object(
      'request_scope', 'runtime_preflight',
      'provider', v_connection.provider,
      'credential_state', v_connection.credential_state::TEXT,
      'reference_available', v_connection.credentials_ref IS NOT NULL,
      'provider_api_calls', false,
      'canonical_write', false,
      'source_writeback', false
    ),
    'wait_for_worker_runtime_preflight',
    v_service_tenant_id
  );

  RETURN QUERY
  SELECT
    cj.id,
    cj.status,
    v_connection.credential_state,
    cj.next_action_key
  FROM puls_integration.connector_jobs cj
  WHERE cj.id = v_job_id;
END;
$$;

REVOKE ALL ON FUNCTION puls_integration.get_connector_runtime_preflight_context(UUID)
  FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.request_connector_runtime_preflight(UUID, UUID)
  FROM PUBLIC, authenticated, anon;

GRANT EXECUTE ON FUNCTION puls_integration.get_connector_runtime_preflight_context(UUID)
  TO service_role;
GRANT EXECUTE ON FUNCTION puls_integration.request_connector_runtime_preflight(UUID, UUID)
  TO authenticated, service_role;

COMMENT ON FUNCTION puls_integration.get_connector_runtime_preflight_context(UUID) IS
  'Service-role only safe runtime preflight context. It returns credential state and reference availability, never credential reference values or provider payloads.';
COMMENT ON FUNCTION puls_integration.request_connector_runtime_preflight(UUID, UUID) IS
  'Tenant admin runtime preflight request boundary. Queues connector_runtime_preflight only when required credentials are verified.';
