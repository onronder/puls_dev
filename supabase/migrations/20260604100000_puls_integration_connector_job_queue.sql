-- PR15.1 connector job queue contract.
-- Defines the tenant-scoped runtime queue boundary without opening connector runtime,
-- credential resolution, canonical apply, external API calls, or ERP/source writeback.

DO $$
BEGIN
  CREATE TYPE puls_integration.connector_job_status AS ENUM (
    'queued',
    'running',
    'succeeded',
    'failed',
    'retrying',
    'cancelled',
    'dead_letter'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE puls_integration.connector_job_type AS ENUM (
    'setup_preflight',
    'credential_verification',
    'import_preview',
    'import_apply',
    'connector_runtime_preflight',
    'source_discovery',
    'noop_health'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE OR REPLACE FUNCTION puls_integration.connector_safe_context_has_blocked_key(
  p_context JSONB
)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
SET search_path = pg_catalog
AS $$
DECLARE
  v_key TEXT;
  v_norm TEXT;
  v_value JSONB;
  v_item JSONB;
BEGIN
  IF p_context IS NULL OR jsonb_typeof(p_context) = 'null' THEN
    RETURN FALSE;
  END IF;

  IF jsonb_typeof(p_context) = 'object' THEN
    FOR v_key, v_value IN SELECT key, value FROM jsonb_each(p_context) LOOP
      v_norm := lower(v_key);
      IF v_norm IN (
        'api_key',
        'apikey',
        'authorization',
        'bearer',
        'credentials_ref',
        'connection_string',
        'private_key',
        'client_secret',
        'refresh_token',
        'access_token',
        'raw_payload',
        'provider_payload',
        'request_body',
        'response_body'
      )
      OR v_norm LIKE '%password%'
      OR v_norm LIKE '%passwd%'
      OR v_norm LIKE '%secret%'
      OR v_norm LIKE '%token%' THEN
        RETURN TRUE;
      END IF;

      IF puls_integration.connector_safe_context_has_blocked_key(v_value) THEN
        RETURN TRUE;
      END IF;
    END LOOP;
    RETURN FALSE;
  END IF;

  IF jsonb_typeof(p_context) = 'array' THEN
    FOR v_item IN SELECT value FROM jsonb_array_elements(p_context) LOOP
      IF puls_integration.connector_safe_context_has_blocked_key(v_item) THEN
        RETURN TRUE;
      END IF;
    END LOOP;
  END IF;

  RETURN FALSE;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration.is_connector_job_reader()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_core, puls_integration
AS $$
  SELECT auth.role() = 'service_role' OR puls_core.is_manager_or_admin();
$$;

CREATE OR REPLACE FUNCTION puls_integration.can_enqueue_connector_job()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_core, puls_integration
AS $$
  SELECT auth.role() = 'service_role' OR puls_core.is_admin();
$$;

CREATE TABLE IF NOT EXISTS puls_integration.connector_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  connection_id UUID NULL REFERENCES puls_integration.erp_connections(id) ON DELETE SET NULL,
  source_namespace_id UUID NULL REFERENCES puls_integration.source_namespaces(id) ON DELETE SET NULL,
  import_batch_id UUID NULL REFERENCES puls_integration.import_batches(id) ON DELETE SET NULL,
  job_type puls_integration.connector_job_type NOT NULL,
  status puls_integration.connector_job_status NOT NULL DEFAULT 'queued',
  domain TEXT NULL,
  idempotency_key TEXT NOT NULL,
  concurrency_key TEXT NOT NULL,
  priority INTEGER NOT NULL DEFAULT 100,
  attempt_count INTEGER NOT NULL DEFAULT 0,
  max_attempts INTEGER NOT NULL DEFAULT 3,
  scheduled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  started_at TIMESTAMPTZ NULL,
  finished_at TIMESTAMPTZ NULL,
  locked_at TIMESTAMPTZ NULL,
  locked_by TEXT NULL,
  safe_error_code TEXT NULL,
  safe_error_context JSONB NOT NULL DEFAULT '{}'::JSONB,
  next_action_key TEXT NULL,
  created_by_employee_id UUID NULL REFERENCES puls_core.employees(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, idempotency_key),
  CHECK (btrim(idempotency_key) <> ''),
  CHECK (btrim(concurrency_key) <> ''),
  CHECK (priority >= 0),
  CHECK (attempt_count >= 0),
  CHECK (max_attempts BETWEEN 1 AND 10),
  CHECK (attempt_count <= max_attempts),
  CHECK (jsonb_typeof(safe_error_context) = 'object'),
  CHECK (puls_integration.connector_safe_context_has_blocked_key(safe_error_context) IS FALSE),
  CHECK (
    (status = 'running'::puls_integration.connector_job_status AND locked_by IS NOT NULL AND locked_at IS NOT NULL)
    OR status <> 'running'::puls_integration.connector_job_status
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS connector_jobs_active_concurrency_idx
  ON puls_integration.connector_jobs (tenant_id, concurrency_key)
  WHERE status IN (
    'queued'::puls_integration.connector_job_status,
    'running'::puls_integration.connector_job_status,
    'retrying'::puls_integration.connector_job_status
  );

CREATE INDEX IF NOT EXISTS connector_jobs_claim_idx
  ON puls_integration.connector_jobs (status, scheduled_at, priority, created_at)
  WHERE status IN (
    'queued'::puls_integration.connector_job_status,
    'retrying'::puls_integration.connector_job_status
  );

CREATE INDEX IF NOT EXISTS connector_jobs_tenant_connection_created_idx
  ON puls_integration.connector_jobs (tenant_id, connection_id, created_at DESC);

CREATE INDEX IF NOT EXISTS connector_jobs_tenant_status_created_idx
  ON puls_integration.connector_jobs (tenant_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS connector_jobs_safe_error_idx
  ON puls_integration.connector_jobs (tenant_id, safe_error_code)
  WHERE safe_error_code IS NOT NULL;

DROP TRIGGER IF EXISTS puls_integration_connector_jobs_set_updated_at
  ON puls_integration.connector_jobs;
CREATE TRIGGER puls_integration_connector_jobs_set_updated_at
  BEFORE UPDATE ON puls_integration.connector_jobs
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

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
      RAISE EXCEPTION 'PULS_CONNECTOR_JOB_TENANT_INVALID: tenant % not found.', p_tenant_id;
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
    SELECT c.tenant_id
    INTO v_connection_tenant_id
    FROM puls_integration.erp_connections c
    WHERE c.id = p_connection_id;

    IF v_connection_tenant_id IS NULL OR v_connection_tenant_id IS DISTINCT FROM v_tenant_id THEN
      RAISE EXCEPTION 'PULS_CONNECTOR_JOB_CONNECTION_INVALID: connection missing or cross-tenant.';
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

CREATE OR REPLACE FUNCTION puls_integration.claim_next_connector_job(
  p_worker_id TEXT,
  p_job_types puls_integration.connector_job_type[] DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  tenant_id UUID,
  connection_id UUID,
  source_namespace_id UUID,
  import_batch_id UUID,
  job_type puls_integration.connector_job_type,
  status puls_integration.connector_job_status,
  domain TEXT,
  idempotency_key TEXT,
  concurrency_key TEXT,
  priority INTEGER,
  attempt_count INTEGER,
  max_attempts INTEGER,
  scheduled_at TIMESTAMPTZ,
  started_at TIMESTAMPTZ,
  locked_at TIMESTAMPTZ,
  locked_by TEXT,
  safe_error_context JSONB,
  next_action_key TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration
AS $$
DECLARE
  v_worker_id TEXT := btrim(COALESCE(p_worker_id, ''));
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_JOB_WORKER_ONLY: connector job claim requires service_role.';
  END IF;

  IF v_worker_id = '' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_JOB_WORKER_REQUIRED: worker id is required.';
  END IF;

  RETURN QUERY
  WITH candidate AS (
    SELECT cj.id
    FROM puls_integration.connector_jobs cj
    WHERE cj.status IN (
        'queued'::puls_integration.connector_job_status,
        'retrying'::puls_integration.connector_job_status
      )
      AND cj.scheduled_at <= NOW()
      AND cj.attempt_count < cj.max_attempts
      AND (p_job_types IS NULL OR cj.job_type = ANY(p_job_types))
    ORDER BY cj.priority ASC, cj.scheduled_at ASC, cj.created_at ASC
    LIMIT 1
    FOR UPDATE SKIP LOCKED
  )
  UPDATE puls_integration.connector_jobs cj
  SET
    status = 'running'::puls_integration.connector_job_status,
    locked_by = v_worker_id,
    locked_at = NOW(),
    started_at = NOW(),
    attempt_count = cj.attempt_count + 1
  FROM candidate
  WHERE cj.id = candidate.id
  RETURNING
    cj.id,
    cj.tenant_id,
    cj.connection_id,
    cj.source_namespace_id,
    cj.import_batch_id,
    cj.job_type,
    cj.status,
    cj.domain,
    cj.idempotency_key,
    cj.concurrency_key,
    cj.priority,
    cj.attempt_count,
    cj.max_attempts,
    cj.scheduled_at,
    cj.started_at,
    cj.locked_at,
    cj.locked_by,
    cj.safe_error_context,
    cj.next_action_key,
    cj.created_at,
    cj.updated_at;
END;
$$;

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
     OR v_job.locked_by IS DISTINCT FROM v_worker_id THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_JOB_LOCK_INVALID: job is not locked by this worker.';
  END IF;

  IF p_status = 'retrying'::puls_integration.connector_job_status
     AND v_job.attempt_count >= v_job.max_attempts THEN
    v_next_status := 'dead_letter'::puls_integration.connector_job_status;
  END IF;

  UPDATE puls_integration.connector_jobs cj
  SET
    status = v_next_status,
    scheduled_at = CASE
      WHEN v_next_status = 'retrying'::puls_integration.connector_job_status
        THEN COALESCE(p_scheduled_at, NOW() + INTERVAL '5 minutes')
      ELSE cj.scheduled_at
    END,
    finished_at = CASE
      WHEN v_next_status = 'retrying'::puls_integration.connector_job_status THEN NULL
      ELSE NOW()
    END,
    locked_at = NULL,
    locked_by = NULL,
    safe_error_code = p_safe_error_code,
    safe_error_context = COALESCE(p_safe_error_context, '{}'::JSONB),
    next_action_key = p_next_action_key
  WHERE cj.id = p_job_id;

  RETURN p_job_id;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration.list_connector_job_summaries(
  p_connection_id UUID DEFAULT NULL,
  p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
  id UUID,
  tenant_id UUID,
  connection_id UUID,
  source_namespace_id UUID,
  import_batch_id UUID,
  job_type puls_integration.connector_job_type,
  status puls_integration.connector_job_status,
  domain TEXT,
  priority INTEGER,
  attempt_count INTEGER,
  max_attempts INTEGER,
  scheduled_at TIMESTAMPTZ,
  started_at TIMESTAMPTZ,
  finished_at TIMESTAMPTZ,
  locked_at TIMESTAMPTZ,
  locked_by TEXT,
  safe_error_code TEXT,
  safe_error_context JSONB,
  next_action_key TEXT,
  created_by_employee_id UUID,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
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
    cj.id,
    cj.tenant_id,
    cj.connection_id,
    cj.source_namespace_id,
    cj.import_batch_id,
    cj.job_type,
    cj.status,
    cj.domain,
    cj.priority,
    cj.attempt_count,
    cj.max_attempts,
    cj.scheduled_at,
    cj.started_at,
    cj.finished_at,
    cj.locked_at,
    cj.locked_by,
    cj.safe_error_code,
    cj.safe_error_context,
    cj.next_action_key,
    cj.created_by_employee_id,
    cj.created_at,
    cj.updated_at
  FROM puls_integration.connector_jobs cj
  WHERE (auth.role() = 'service_role' OR cj.tenant_id = v_tenant_id)
    AND (p_connection_id IS NULL OR cj.connection_id = p_connection_id)
  ORDER BY cj.updated_at DESC, cj.created_at DESC
  LIMIT v_limit;
END;
$$;

ALTER TABLE puls_integration.connector_jobs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS puls_integration_connector_jobs_select ON puls_integration.connector_jobs;
CREATE POLICY puls_integration_connector_jobs_select ON puls_integration.connector_jobs
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND puls_integration.is_connector_job_reader()
  );

GRANT SELECT ON puls_integration.connector_jobs TO authenticated;
GRANT ALL ON puls_integration.connector_jobs TO service_role;

REVOKE ALL ON FUNCTION puls_integration.connector_safe_context_has_blocked_key(JSONB)
  FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.is_connector_job_reader()
  FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.can_enqueue_connector_job()
  FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.enqueue_connector_job(
  puls_integration.connector_job_type,
  TEXT,
  UUID,
  UUID,
  UUID,
  TEXT,
  INTEGER,
  TIMESTAMPTZ,
  INTEGER,
  JSONB,
  TEXT,
  UUID
) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.claim_next_connector_job(
  TEXT,
  puls_integration.connector_job_type[]
) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.complete_connector_job(
  UUID,
  TEXT,
  puls_integration.connector_job_status,
  TEXT,
  JSONB,
  TEXT,
  TIMESTAMPTZ
) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.list_connector_job_summaries(UUID, INTEGER)
  FROM PUBLIC, authenticated, anon;

GRANT EXECUTE ON FUNCTION puls_integration.is_connector_job_reader()
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_integration.enqueue_connector_job(
  puls_integration.connector_job_type,
  TEXT,
  UUID,
  UUID,
  UUID,
  TEXT,
  INTEGER,
  TIMESTAMPTZ,
  INTEGER,
  JSONB,
  TEXT,
  UUID
) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_integration.claim_next_connector_job(
  TEXT,
  puls_integration.connector_job_type[]
) TO service_role;
GRANT EXECUTE ON FUNCTION puls_integration.complete_connector_job(
  UUID,
  TEXT,
  puls_integration.connector_job_status,
  TEXT,
  JSONB,
  TEXT,
  TIMESTAMPTZ
) TO service_role;
GRANT EXECUTE ON FUNCTION puls_integration.list_connector_job_summaries(UUID, INTEGER)
  TO authenticated, service_role;

COMMENT ON TYPE puls_integration.connector_job_status IS
  'Tenant-scoped connector job lifecycle. Runtime workers transition jobs through this state model.';
COMMENT ON TYPE puls_integration.connector_job_type IS
  'Source-independent connector job type. Provider-specific work must fit this generic queue contract.';
COMMENT ON TABLE puls_integration.connector_jobs IS
  'Safe connector runtime queue contract. Does not store secrets, raw provider payloads, or canonical write payloads.';
COMMENT ON COLUMN puls_integration.connector_jobs.idempotency_key IS
  'Tenant-scoped idempotency key. Duplicate enqueue requests return the existing job.';
COMMENT ON COLUMN puls_integration.connector_jobs.concurrency_key IS
  'Tenant-scoped active-job guard used to prevent conflicting connector work for the same source/domain/job type.';
COMMENT ON COLUMN puls_integration.connector_jobs.safe_error_context IS
  'Sanitized operational context only. Secret values, provider payloads, request bodies, and response bodies are forbidden.';
COMMENT ON FUNCTION puls_integration.enqueue_connector_job(
  puls_integration.connector_job_type,
  TEXT,
  UUID,
  UUID,
  UUID,
  TEXT,
  INTEGER,
  TIMESTAMPTZ,
  INTEGER,
  JSONB,
  TEXT,
  UUID
) IS
  'Idempotently enqueues a connector job. Authenticated callers must be tenant admins; service_role callers must pass p_tenant_id.';
COMMENT ON FUNCTION puls_integration.claim_next_connector_job(TEXT, puls_integration.connector_job_type[]) IS
  'Service-role only queue claim contract for future connector workers. Uses FOR UPDATE SKIP LOCKED.';
COMMENT ON FUNCTION puls_integration.complete_connector_job(
  UUID,
  TEXT,
  puls_integration.connector_job_status,
  TEXT,
  JSONB,
  TEXT,
  TIMESTAMPTZ
) IS
  'Service-role only connector job completion contract. Does not execute connector work itself.';
COMMENT ON FUNCTION puls_integration.list_connector_job_summaries(UUID, INTEGER) IS
  'Safe connector job read model for product UI and future AI evidence. No payload or credential values are returned.';
