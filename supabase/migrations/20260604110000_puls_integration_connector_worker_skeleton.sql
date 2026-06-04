-- PR15.2 connector worker skeleton.
-- Adds safe worker heartbeat, lease ownership, and stale-job recovery contracts
-- without provider API calls, credential resolution, import apply, or source writeback.

DO $$
BEGIN
  CREATE TYPE puls_integration.connector_worker_status AS ENUM (
    'idle',
    'claiming',
    'running',
    'recovering',
    'paused',
    'error'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE puls_integration.connector_jobs
  ADD COLUMN IF NOT EXISTS worker_heartbeat_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS lease_expires_at TIMESTAMPTZ NULL;

DO $$
BEGIN
  ALTER TABLE puls_integration.connector_jobs
    ADD CONSTRAINT connector_jobs_running_lease_contract
    CHECK (
      (
        status = 'running'::puls_integration.connector_job_status
        AND locked_by IS NOT NULL
        AND locked_at IS NOT NULL
        AND lease_expires_at IS NOT NULL
      )
      OR status <> 'running'::puls_integration.connector_job_status
    ) NOT VALID;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS connector_jobs_lease_expiry_idx
  ON puls_integration.connector_jobs (lease_expires_at, locked_at)
  WHERE status = 'running'::puls_integration.connector_job_status;

CREATE TABLE IF NOT EXISTS puls_integration.connector_worker_heartbeats (
  worker_id TEXT PRIMARY KEY,
  status puls_integration.connector_worker_status NOT NULL DEFAULT 'idle',
  runtime_version TEXT NOT NULL,
  supported_job_types puls_integration.connector_job_type[] NOT NULL
    DEFAULT ARRAY[]::puls_integration.connector_job_type[],
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_claimed_job_id UUID NULL REFERENCES puls_integration.connector_jobs(id) ON DELETE SET NULL,
  safe_error_code TEXT NULL,
  safe_context JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (btrim(worker_id) <> ''),
  CHECK (btrim(runtime_version) <> ''),
  CHECK (jsonb_typeof(safe_context) = 'object'),
  CHECK (puls_integration.connector_safe_context_has_blocked_key(safe_context) IS FALSE)
);

CREATE INDEX IF NOT EXISTS connector_worker_heartbeats_last_seen_idx
  ON puls_integration.connector_worker_heartbeats (last_seen_at DESC);

DROP TRIGGER IF EXISTS puls_integration_connector_worker_heartbeats_set_updated_at
  ON puls_integration.connector_worker_heartbeats;
CREATE TRIGGER puls_integration_connector_worker_heartbeats_set_updated_at
  BEFORE UPDATE ON puls_integration.connector_worker_heartbeats
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

CREATE OR REPLACE FUNCTION puls_integration.upsert_connector_worker_heartbeat(
  p_worker_id TEXT,
  p_status puls_integration.connector_worker_status DEFAULT 'idle',
  p_runtime_version TEXT DEFAULT '0.2.0-worker-skeleton',
  p_supported_job_types puls_integration.connector_job_type[] DEFAULT ARRAY['noop_health'::puls_integration.connector_job_type],
  p_last_claimed_job_id UUID DEFAULT NULL,
  p_safe_error_code TEXT DEFAULT NULL,
  p_safe_context JSONB DEFAULT '{}'::JSONB
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration
AS $$
DECLARE
  v_worker_id TEXT := btrim(COALESCE(p_worker_id, ''));
  v_runtime_version TEXT := btrim(COALESCE(p_runtime_version, ''));
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_WORKER_ONLY: worker heartbeat requires service_role.';
  END IF;

  IF v_worker_id = '' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_WORKER_ID_REQUIRED: worker id is required.';
  END IF;

  IF v_runtime_version = '' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_WORKER_VERSION_REQUIRED: runtime version is required.';
  END IF;

  IF p_safe_context IS NULL OR jsonb_typeof(p_safe_context) <> 'object' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_WORKER_SAFE_CONTEXT_INVALID: safe_context must be a JSON object.';
  END IF;

  IF puls_integration.connector_safe_context_has_blocked_key(p_safe_context) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_WORKER_SAFE_CONTEXT_FORBIDDEN: safe_context contains blocked keys.';
  END IF;

  INSERT INTO puls_integration.connector_worker_heartbeats (
    worker_id,
    status,
    runtime_version,
    supported_job_types,
    last_seen_at,
    last_claimed_job_id,
    safe_error_code,
    safe_context
  )
  VALUES (
    v_worker_id,
    COALESCE(p_status, 'idle'::puls_integration.connector_worker_status),
    v_runtime_version,
    COALESCE(p_supported_job_types, ARRAY[]::puls_integration.connector_job_type[]),
    NOW(),
    p_last_claimed_job_id,
    p_safe_error_code,
    COALESCE(p_safe_context, '{}'::JSONB)
  )
  ON CONFLICT (worker_id) DO UPDATE
  SET
    status = EXCLUDED.status,
    runtime_version = EXCLUDED.runtime_version,
    supported_job_types = EXCLUDED.supported_job_types,
    last_seen_at = NOW(),
    last_claimed_job_id = EXCLUDED.last_claimed_job_id,
    safe_error_code = EXCLUDED.safe_error_code,
    safe_context = EXCLUDED.safe_context;

  RETURN v_worker_id;
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
    worker_heartbeat_at = NOW(),
    lease_expires_at = NOW() + INTERVAL '5 minutes',
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

CREATE OR REPLACE FUNCTION puls_integration.heartbeat_connector_job(
  p_job_id UUID,
  p_worker_id TEXT,
  p_lease_seconds INTEGER DEFAULT 300,
  p_safe_context JSONB DEFAULT '{}'::JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration
AS $$
DECLARE
  v_worker_id TEXT := btrim(COALESCE(p_worker_id, ''));
  v_job_id UUID;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_JOB_WORKER_ONLY: connector job heartbeat requires service_role.';
  END IF;

  IF v_worker_id = '' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_JOB_WORKER_REQUIRED: worker id is required.';
  END IF;

  IF p_lease_seconds < 30 OR p_lease_seconds > 3600 THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_JOB_LEASE_INVALID: lease seconds must be between 30 and 3600.';
  END IF;

  IF p_safe_context IS NULL OR jsonb_typeof(p_safe_context) <> 'object' THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_JOB_SAFE_CONTEXT_INVALID: safe_context must be a JSON object.';
  END IF;

  IF puls_integration.connector_safe_context_has_blocked_key(p_safe_context) THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_JOB_SAFE_CONTEXT_FORBIDDEN: safe_context contains blocked keys.';
  END IF;

  UPDATE puls_integration.connector_jobs cj
  SET
    worker_heartbeat_at = NOW(),
    lease_expires_at = NOW() + make_interval(secs => p_lease_seconds),
    safe_error_context = CASE
      WHEN p_safe_context = '{}'::JSONB THEN cj.safe_error_context
      ELSE p_safe_context
    END
  WHERE cj.id = p_job_id
    AND cj.status = 'running'::puls_integration.connector_job_status
    AND cj.locked_by = v_worker_id
  RETURNING cj.id INTO v_job_id;

  IF v_job_id IS NULL THEN
    RAISE EXCEPTION 'PULS_CONNECTOR_JOB_LOCK_INVALID: job is not running or not locked by this worker.';
  END IF;

  RETURN v_job_id;
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
    worker_heartbeat_at = NULL,
    lease_expires_at = NULL,
    safe_error_code = p_safe_error_code,
    safe_error_context = COALESCE(p_safe_error_context, '{}'::JSONB),
    next_action_key = p_next_action_key
  WHERE cj.id = p_job_id;

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
      END
    FROM candidate
    WHERE cj.id = candidate.id
    RETURNING
      cj.id,
      candidate.status AS previous_status,
      cj.status AS next_status,
      cj.attempt_count,
      cj.max_attempts,
      candidate.lease_expires_at AS previous_lease_expires_at
  )
  SELECT
    recovered.id,
    recovered.previous_status,
    recovered.next_status,
    recovered.attempt_count,
    recovered.max_attempts,
    recovered.previous_lease_expires_at
  FROM recovered;
END;
$$;

ALTER TABLE puls_integration.connector_worker_heartbeats ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS puls_integration_connector_worker_heartbeats_select
  ON puls_integration.connector_worker_heartbeats;
CREATE POLICY puls_integration_connector_worker_heartbeats_select
  ON puls_integration.connector_worker_heartbeats
  FOR SELECT TO authenticated
  USING (puls_core.is_manager_or_admin());

GRANT SELECT ON puls_integration.connector_worker_heartbeats TO authenticated;
GRANT ALL ON puls_integration.connector_worker_heartbeats TO service_role;

REVOKE ALL ON FUNCTION puls_integration.upsert_connector_worker_heartbeat(
  TEXT,
  puls_integration.connector_worker_status,
  TEXT,
  puls_integration.connector_job_type[],
  UUID,
  TEXT,
  JSONB
) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.heartbeat_connector_job(UUID, TEXT, INTEGER, JSONB)
  FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.recover_stale_connector_jobs(TEXT, INTEGER)
  FROM PUBLIC, authenticated, anon;

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

GRANT EXECUTE ON FUNCTION puls_integration.upsert_connector_worker_heartbeat(
  TEXT,
  puls_integration.connector_worker_status,
  TEXT,
  puls_integration.connector_job_type[],
  UUID,
  TEXT,
  JSONB
) TO service_role;
GRANT EXECUTE ON FUNCTION puls_integration.heartbeat_connector_job(UUID, TEXT, INTEGER, JSONB)
  TO service_role;
GRANT EXECUTE ON FUNCTION puls_integration.recover_stale_connector_jobs(TEXT, INTEGER)
  TO service_role;
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

COMMENT ON TYPE puls_integration.connector_worker_status IS
  'Safe connector worker heartbeat status. It describes worker ownership only, not provider execution success.';
COMMENT ON TABLE puls_integration.connector_worker_heartbeats IS
  'Safe connector worker heartbeat read model. Does not contain credentials, provider payloads, or customer data.';
COMMENT ON COLUMN puls_integration.connector_jobs.worker_heartbeat_at IS
  'Last service-role worker heartbeat for a running connector job.';
COMMENT ON COLUMN puls_integration.connector_jobs.lease_expires_at IS
  'Lease expiry used by service-role worker recovery to prevent stuck running jobs.';
COMMENT ON FUNCTION puls_integration.upsert_connector_worker_heartbeat(
  TEXT,
  puls_integration.connector_worker_status,
  TEXT,
  puls_integration.connector_job_type[],
  UUID,
  TEXT,
  JSONB
) IS
  'Service-role only worker heartbeat contract. Stores safe runtime metadata only.';
COMMENT ON FUNCTION puls_integration.heartbeat_connector_job(UUID, TEXT, INTEGER, JSONB) IS
  'Service-role only job lease heartbeat. Extends the lock lease without exposing runtime payloads.';
COMMENT ON FUNCTION puls_integration.recover_stale_connector_jobs(TEXT, INTEGER) IS
  'Service-role only stale connector job recovery. Moves expired running jobs to retrying or dead_letter.';
