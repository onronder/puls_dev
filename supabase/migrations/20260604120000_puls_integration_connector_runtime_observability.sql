-- PR15.3 connector runtime observability and failure model.
-- Adds deterministic retry/backoff evidence, safe failure classes, and immutable
-- job events without provider API calls, credential readback, import apply, or source writeback.

DO $$
BEGIN
  CREATE TYPE puls_integration.connector_job_failure_class AS ENUM (
    'none',
    'transient',
    'credential',
    'mapping',
    'provider_limit',
    'provider_unavailable',
    'worker',
    'unsupported',
    'unknown'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE puls_integration.connector_job_operator_severity AS ENUM (
    'info',
    'warning',
    'error',
    'critical'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE puls_integration.connector_jobs
  ADD COLUMN IF NOT EXISTS failure_class puls_integration.connector_job_failure_class
    NOT NULL DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS operator_severity puls_integration.connector_job_operator_severity
    NOT NULL DEFAULT 'info',
  ADD COLUMN IF NOT EXISTS retry_after_seconds INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_failure_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS dead_lettered_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS operator_review_required BOOLEAN NOT NULL DEFAULT FALSE;

DO $$
BEGIN
  ALTER TABLE puls_integration.connector_jobs
    ADD CONSTRAINT connector_jobs_retry_after_seconds_range
    CHECK (retry_after_seconds >= 0 AND retry_after_seconds <= 86400) NOT VALID;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS connector_jobs_failure_class_idx
  ON puls_integration.connector_jobs (tenant_id, failure_class, updated_at DESC)
  WHERE failure_class <> 'none'::puls_integration.connector_job_failure_class;

CREATE INDEX IF NOT EXISTS connector_jobs_operator_review_idx
  ON puls_integration.connector_jobs (tenant_id, operator_review_required, updated_at DESC)
  WHERE operator_review_required IS TRUE;

CREATE TABLE IF NOT EXISTS puls_integration.connector_job_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  connection_id UUID NULL REFERENCES puls_integration.erp_connections(id) ON DELETE SET NULL,
  job_id UUID NULL REFERENCES puls_integration.connector_jobs(id) ON DELETE SET NULL,
  job_type puls_integration.connector_job_type NOT NULL,
  status puls_integration.connector_job_status NOT NULL,
  event_key TEXT NOT NULL,
  level puls_integration.connector_job_operator_severity NOT NULL DEFAULT 'info',
  failure_class puls_integration.connector_job_failure_class NOT NULL DEFAULT 'none',
  safe_error_code TEXT NULL,
  safe_error_context JSONB NOT NULL DEFAULT '{}'::JSONB,
  next_action_key TEXT NOT NULL DEFAULT 'review_job_status',
  retry_after_seconds INTEGER NOT NULL DEFAULT 0,
  operator_review_required BOOLEAN NOT NULL DEFAULT FALSE,
  worker_id TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (btrim(event_key) <> ''),
  CHECK (btrim(next_action_key) <> ''),
  CHECK (retry_after_seconds >= 0 AND retry_after_seconds <= 86400),
  CHECK (jsonb_typeof(safe_error_context) = 'object'),
  CHECK (puls_integration.connector_safe_context_has_blocked_key(safe_error_context) IS FALSE)
);

CREATE INDEX IF NOT EXISTS connector_job_events_tenant_connection_created_idx
  ON puls_integration.connector_job_events (tenant_id, connection_id, created_at DESC);

CREATE INDEX IF NOT EXISTS connector_job_events_job_created_idx
  ON puls_integration.connector_job_events (job_id, created_at DESC);

CREATE INDEX IF NOT EXISTS connector_job_events_failure_idx
  ON puls_integration.connector_job_events (tenant_id, failure_class, created_at DESC)
  WHERE failure_class <> 'none'::puls_integration.connector_job_failure_class;

CREATE OR REPLACE FUNCTION puls_integration.classify_connector_job_failure(
  p_safe_error_code TEXT,
  p_next_action_key TEXT DEFAULT NULL
)
RETURNS puls_integration.connector_job_failure_class
LANGUAGE plpgsql
IMMUTABLE
SET search_path = pg_catalog, puls_integration
AS $$
DECLARE
  v_code TEXT := lower(COALESCE(p_safe_error_code, ''));
  v_action TEXT := lower(COALESCE(p_next_action_key, ''));
BEGIN
  IF v_code = '' THEN
    RETURN 'none'::puls_integration.connector_job_failure_class;
  END IF;

  IF v_code LIKE '%credential%'
     OR v_code LIKE '%secret%'
     OR v_code LIKE '%reference%'
     OR v_action LIKE '%secure_reference%' THEN
    RETURN 'credential'::puls_integration.connector_job_failure_class;
  END IF;

  IF v_code LIKE '%mapping%'
     OR v_code LIKE '%preview_has_errors%'
     OR v_code LIKE '%validation%'
     OR v_action LIKE '%mapping%' THEN
    RETURN 'mapping'::puls_integration.connector_job_failure_class;
  END IF;

  IF v_code LIKE '%rate_limit%'
     OR v_code LIKE '%too_many_requests%'
     OR v_code LIKE '%quota%' THEN
    RETURN 'provider_limit'::puls_integration.connector_job_failure_class;
  END IF;

  IF v_code LIKE '%provider_unavailable%'
     OR v_code LIKE '%timeout%'
     OR v_code LIKE '%http_5%'
     OR v_code LIKE '%network%' THEN
    RETURN 'provider_unavailable'::puls_integration.connector_job_failure_class;
  END IF;

  IF v_code LIKE '%lease%'
     OR v_code LIKE '%worker%'
     OR v_code LIKE '%rpc%'
     OR v_code LIKE '%lock%' THEN
    RETURN 'worker'::puls_integration.connector_job_failure_class;
  END IF;

  IF v_code LIKE '%unsupported%'
     OR v_action LIKE '%provider_runtime_implementation%' THEN
    RETURN 'unsupported'::puls_integration.connector_job_failure_class;
  END IF;

  IF v_code LIKE '%transient%' THEN
    RETURN 'transient'::puls_integration.connector_job_failure_class;
  END IF;

  RETURN 'unknown'::puls_integration.connector_job_failure_class;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration.connector_job_retry_after_seconds(
  p_failure_class puls_integration.connector_job_failure_class,
  p_attempt_count INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql
IMMUTABLE
SET search_path = pg_catalog, puls_integration
AS $$
DECLARE
  v_attempt INTEGER := GREATEST(COALESCE(p_attempt_count, 1), 1);
BEGIN
  CASE p_failure_class
    WHEN 'transient' THEN
      RETURN LEAST(60 * (2 ^ LEAST(v_attempt - 1, 4))::INTEGER, 900);
    WHEN 'provider_unavailable' THEN
      RETURN LEAST(120 * (2 ^ LEAST(v_attempt - 1, 4))::INTEGER, 1800);
    WHEN 'provider_limit' THEN
      RETURN LEAST(300 * (2 ^ LEAST(v_attempt - 1, 3))::INTEGER, 3600);
    WHEN 'worker' THEN
      RETURN LEAST(120 * (2 ^ LEAST(v_attempt - 1, 3))::INTEGER, 1200);
    ELSE
      RETURN 0;
  END CASE;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration.connector_job_operator_severity(
  p_failure_class puls_integration.connector_job_failure_class,
  p_status puls_integration.connector_job_status
)
RETURNS puls_integration.connector_job_operator_severity
LANGUAGE plpgsql
IMMUTABLE
SET search_path = pg_catalog, puls_integration
AS $$
BEGIN
  IF p_status = 'succeeded'::puls_integration.connector_job_status THEN
    RETURN 'info'::puls_integration.connector_job_operator_severity;
  END IF;

  IF p_status = 'dead_letter'::puls_integration.connector_job_status THEN
    RETURN 'critical'::puls_integration.connector_job_operator_severity;
  END IF;

  IF p_status = 'retrying'::puls_integration.connector_job_status THEN
    RETURN 'warning'::puls_integration.connector_job_operator_severity;
  END IF;

  IF p_failure_class IN (
    'credential'::puls_integration.connector_job_failure_class,
    'mapping'::puls_integration.connector_job_failure_class,
    'unsupported'::puls_integration.connector_job_failure_class,
    'unknown'::puls_integration.connector_job_failure_class
  ) THEN
    RETURN 'error'::puls_integration.connector_job_operator_severity;
  END IF;

  IF p_failure_class = 'none'::puls_integration.connector_job_failure_class THEN
    RETURN 'info'::puls_integration.connector_job_operator_severity;
  END IF;

  RETURN 'warning'::puls_integration.connector_job_operator_severity;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration.connector_job_event_key(
  p_status puls_integration.connector_job_status
)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
SET search_path = pg_catalog, puls_integration
AS $$
BEGIN
  CASE p_status
    WHEN 'succeeded' THEN RETURN 'connector_job_succeeded';
    WHEN 'retrying' THEN RETURN 'connector_job_retry_scheduled';
    WHEN 'dead_letter' THEN RETURN 'connector_job_dead_lettered';
    WHEN 'failed' THEN RETURN 'connector_job_failed';
    WHEN 'cancelled' THEN RETURN 'connector_job_cancelled';
    ELSE RETURN 'connector_job_recorded';
  END CASE;
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
     OR v_job.locked_by IS DISTINCT FROM v_worker_id THEN
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

CREATE OR REPLACE FUNCTION puls_integration.recover_stale_connector_jobs(
  p_worker_id TEXT,
  p_limit INTEGER DEFAULT 25
)
RETURNS TABLE (
  id UUID,
  previous_status puls_integration.connector_job_status,
  next_status puls_integration.connector_job_status,
  attempt_count INTEGER,
  max_attempts INTEGER,
  previous_lease_expires_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration
AS $$
DECLARE
  v_worker_id TEXT := btrim(COALESCE(p_worker_id, ''));
  v_limit INTEGER := LEAST(GREATEST(COALESCE(p_limit, 25), 1), 100);
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_JOB_WORKER_ONLY: stale job recovery requires service_role.';
  END IF;

  IF v_worker_id = '' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_JOB_WORKER_REQUIRED: worker id is required.';
  END IF;

  RETURN QUERY
  WITH candidate AS (
    SELECT
      cj.id,
      cj.tenant_id,
      cj.connection_id,
      cj.job_type,
      cj.status,
      cj.attempt_count,
      cj.max_attempts,
      cj.lease_expires_at
    FROM puls_integration.connector_jobs cj
    WHERE cj.status = 'running'::puls_integration.connector_job_status
      AND (
        cj.lease_expires_at < NOW()
        OR (cj.lease_expires_at IS NULL AND cj.locked_at < NOW() - INTERVAL '15 minutes')
      )
    ORDER BY cj.locked_at ASC, cj.created_at ASC
    LIMIT v_limit
    FOR UPDATE SKIP LOCKED
  ),
  recovered AS (
    UPDATE puls_integration.connector_jobs cj
    SET
      status = CASE
        WHEN candidate.attempt_count < candidate.max_attempts
          THEN 'retrying'::puls_integration.connector_job_status
        ELSE 'dead_letter'::puls_integration.connector_job_status
      END,
      scheduled_at = CASE
        WHEN candidate.attempt_count < candidate.max_attempts THEN NOW() + INTERVAL '2 minutes'
        ELSE cj.scheduled_at
      END,
      finished_at = CASE
        WHEN candidate.attempt_count < candidate.max_attempts THEN NULL
        ELSE NOW()
      END,
      locked_at = NULL,
      locked_by = NULL,
      worker_heartbeat_at = NULL,
      lease_expires_at = NULL,
      safe_error_code = 'connector_job_lease_expired',
      safe_error_context = jsonb_build_object(
        'recovered_by_worker', v_worker_id,
        'reason', 'lease_expired'
      ),
      next_action_key = CASE
        WHEN candidate.attempt_count < candidate.max_attempts THEN 'retry_after_worker_recovery'
        ELSE 'review_dead_letter_job'
      END,
      failure_class = 'worker'::puls_integration.connector_job_failure_class,
      operator_severity = CASE
        WHEN candidate.attempt_count < candidate.max_attempts
          THEN 'warning'::puls_integration.connector_job_operator_severity
        ELSE 'critical'::puls_integration.connector_job_operator_severity
      END,
      retry_after_seconds = CASE
        WHEN candidate.attempt_count < candidate.max_attempts THEN 120
        ELSE 0
      END,
      last_failure_at = NOW(),
      dead_lettered_at = CASE
        WHEN candidate.attempt_count < candidate.max_attempts THEN cj.dead_lettered_at
        ELSE NOW()
      END,
      operator_review_required = candidate.attempt_count >= candidate.max_attempts
    FROM candidate
    WHERE cj.id = candidate.id
    RETURNING
      cj.id,
      candidate.tenant_id,
      candidate.connection_id,
      candidate.job_type,
      candidate.status AS previous_status,
      cj.status AS next_status,
      cj.attempt_count,
      cj.max_attempts,
      candidate.lease_expires_at AS previous_lease_expires_at,
      cj.safe_error_code,
      cj.safe_error_context,
      cj.next_action_key,
      cj.retry_after_seconds,
      cj.operator_review_required,
      cj.operator_severity
  ),
  inserted_events AS (
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
    SELECT
      recovered.tenant_id,
      recovered.connection_id,
      recovered.id,
      recovered.job_type,
      recovered.next_status,
      puls_integration.connector_job_event_key(recovered.next_status),
      recovered.operator_severity,
      'worker'::puls_integration.connector_job_failure_class,
      recovered.safe_error_code,
      recovered.safe_error_context,
      recovered.next_action_key,
      recovered.retry_after_seconds,
      recovered.operator_review_required,
      v_worker_id
    FROM recovered
    RETURNING job_id
  )
  SELECT
    recovered.id,
    recovered.previous_status,
    recovered.next_status,
    recovered.attempt_count,
    recovered.max_attempts,
    recovered.previous_lease_expires_at
  FROM recovered
  LEFT JOIN inserted_events ON inserted_events.job_id = recovered.id;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration.list_connector_job_events(
  p_connection_id UUID DEFAULT NULL,
  p_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
  id UUID,
  tenant_id UUID,
  connection_id UUID,
  job_id UUID,
  job_type puls_integration.connector_job_type,
  status puls_integration.connector_job_status,
  event_key TEXT,
  level puls_integration.connector_job_operator_severity,
  failure_class puls_integration.connector_job_failure_class,
  safe_error_code TEXT,
  safe_error_context JSONB,
  next_action_key TEXT,
  retry_after_seconds INTEGER,
  operator_review_required BOOLEAN,
  worker_id TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_tenant_id UUID := puls_core.current_tenant_id();
  v_limit INTEGER := LEAST(GREATEST(COALESCE(p_limit, 20), 1), 100);
BEGIN
  IF auth.role() <> 'service_role' THEN
    IF v_tenant_id IS NULL OR NOT puls_integration.is_connector_job_reader() THEN
      RETURN;
    END IF;
  END IF;

  RETURN QUERY
  SELECT
    cje.id,
    cje.tenant_id,
    cje.connection_id,
    cje.job_id,
    cje.job_type,
    cje.status,
    cje.event_key,
    cje.level,
    cje.failure_class,
    cje.safe_error_code,
    cje.safe_error_context,
    cje.next_action_key,
    cje.retry_after_seconds,
    cje.operator_review_required,
    cje.worker_id,
    cje.created_at
  FROM puls_integration.connector_job_events cje
  WHERE (auth.role() = 'service_role' OR cje.tenant_id = v_tenant_id)
    AND (p_connection_id IS NULL OR cje.connection_id = p_connection_id)
  ORDER BY cje.created_at DESC
  LIMIT v_limit;
END;
$$;

ALTER TABLE puls_integration.connector_job_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS puls_integration_connector_job_events_select
  ON puls_integration.connector_job_events;
CREATE POLICY puls_integration_connector_job_events_select
  ON puls_integration.connector_job_events
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND puls_integration.is_connector_job_reader()
  );

GRANT SELECT ON puls_integration.connector_job_events TO authenticated;
GRANT ALL ON puls_integration.connector_job_events TO service_role;

REVOKE ALL ON FUNCTION puls_integration.classify_connector_job_failure(TEXT, TEXT)
  FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.connector_job_retry_after_seconds(
  puls_integration.connector_job_failure_class,
  INTEGER
) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.connector_job_operator_severity(
  puls_integration.connector_job_failure_class,
  puls_integration.connector_job_status
) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.connector_job_event_key(
  puls_integration.connector_job_status
) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.list_connector_job_events(UUID, INTEGER)
  FROM PUBLIC, authenticated, anon;

GRANT EXECUTE ON FUNCTION puls_integration.classify_connector_job_failure(TEXT, TEXT)
  TO service_role;
GRANT EXECUTE ON FUNCTION puls_integration.connector_job_retry_after_seconds(
  puls_integration.connector_job_failure_class,
  INTEGER
) TO service_role;
GRANT EXECUTE ON FUNCTION puls_integration.connector_job_operator_severity(
  puls_integration.connector_job_failure_class,
  puls_integration.connector_job_status
) TO service_role;
GRANT EXECUTE ON FUNCTION puls_integration.connector_job_event_key(
  puls_integration.connector_job_status
) TO service_role;
GRANT EXECUTE ON FUNCTION puls_integration.list_connector_job_events(UUID, INTEGER)
  TO authenticated, service_role;

COMMENT ON TYPE puls_integration.connector_job_failure_class IS
  'Safe connector job failure classification for operator review and AI recommendations. Does not expose provider payloads.';
COMMENT ON TYPE puls_integration.connector_job_operator_severity IS
  'Operator-facing severity for connector job events.';
COMMENT ON TABLE puls_integration.connector_job_events IS
  'Immutable safe connector job event history. Contains no credentials, raw provider payloads, request bodies, or response bodies.';
COMMENT ON COLUMN puls_integration.connector_jobs.failure_class IS
  'Safe deterministic failure class derived from safe_error_code and next_action_key.';
COMMENT ON COLUMN puls_integration.connector_jobs.retry_after_seconds IS
  'Deterministic retry delay for retrying connector jobs.';
COMMENT ON COLUMN puls_integration.connector_jobs.operator_review_required IS
  'True when a connector job needs an admin/operator review before further action.';
COMMENT ON FUNCTION puls_integration.list_connector_job_events(UUID, INTEGER) IS
  'Tenant-scoped safe connector job event read model for operators and AI-safe summaries.';
