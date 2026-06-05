-- PR16.3 follow-up: preserve queued job context during worker lease heartbeats.
-- The PR16.3 create-only executor validates contract metadata from connector_jobs.safe_error_context.
-- Lease heartbeats must not replace that queue-time context with generic worker progress metadata.

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
  IF COALESCE(auth.role(), '') <> 'service_role' THEN
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
      ELSE p_safe_context || cj.safe_error_context
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

REVOKE ALL ON FUNCTION puls_integration.heartbeat_connector_job(UUID, TEXT, INTEGER, JSONB)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION puls_integration.heartbeat_connector_job(UUID, TEXT, INTEGER, JSONB)
  TO service_role;

COMMENT ON FUNCTION puls_integration.heartbeat_connector_job(UUID, TEXT, INTEGER, JSONB) IS
  'Worker-only lease heartbeat. Extends the lease while preserving queue-time safe_error_context so PR16.3 create-only apply contract metadata cannot be overwritten by heartbeat metadata.';
