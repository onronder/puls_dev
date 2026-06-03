-- PR14.14 connector credential handoff semantics.
-- Models the safe handoff process; secret values stay outside product tables.

DO $$
BEGIN
  CREATE TYPE puls_integration.connector_credential_handoff_status AS ENUM (
    'not_required',
    'not_started',
    'requested',
    'reference_pending',
    'ready_for_verification',
    'verified',
    'failed',
    'revoked'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE puls_integration.erp_connections
  ADD COLUMN IF NOT EXISTS credential_handoff_status puls_integration.connector_credential_handoff_status NOT NULL DEFAULT 'not_started',
  ADD COLUMN IF NOT EXISTS credential_handoff_requested_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS credential_handoff_requested_by_employee_id UUID NULL REFERENCES puls_core.employees(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS credential_handoff_updated_at TIMESTAMPTZ NULL;

UPDATE puls_integration.erp_connections
SET
  credential_handoff_status = CASE
    WHEN credential_required IS FALSE
      OR credential_state = 'not_required'::puls_integration.connector_credential_state
      THEN 'not_required'::puls_integration.connector_credential_handoff_status
    WHEN credential_state = 'verified'::puls_integration.connector_credential_state
      THEN 'verified'::puls_integration.connector_credential_handoff_status
    WHEN credential_state = 'failed'::puls_integration.connector_credential_state
      THEN 'failed'::puls_integration.connector_credential_handoff_status
    WHEN credential_state = 'revoked'::puls_integration.connector_credential_state
      THEN 'revoked'::puls_integration.connector_credential_handoff_status
    WHEN credential_state = 'configured'::puls_integration.connector_credential_state
      THEN 'ready_for_verification'::puls_integration.connector_credential_handoff_status
    ELSE credential_handoff_status
  END,
  credential_handoff_updated_at = COALESCE(credential_handoff_updated_at, updated_at, NOW())
WHERE credential_handoff_status = 'not_started'::puls_integration.connector_credential_handoff_status;

CREATE OR REPLACE FUNCTION puls_integration.apply_connector_credential_handoff_defaults()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.credential_required IS FALSE
     OR NEW.credential_state = 'not_required'::puls_integration.connector_credential_state THEN
    NEW.credential_handoff_status := 'not_required'::puls_integration.connector_credential_handoff_status;
  ELSIF NEW.credential_state = 'verified'::puls_integration.connector_credential_state THEN
    NEW.credential_handoff_status := 'verified'::puls_integration.connector_credential_handoff_status;
  ELSIF NEW.credential_state = 'failed'::puls_integration.connector_credential_state THEN
    NEW.credential_handoff_status := 'failed'::puls_integration.connector_credential_handoff_status;
  ELSIF NEW.credential_state = 'revoked'::puls_integration.connector_credential_state THEN
    NEW.credential_handoff_status := 'revoked'::puls_integration.connector_credential_handoff_status;
  ELSIF NEW.credential_state = 'configured'::puls_integration.connector_credential_state
     AND NEW.credential_handoff_status IN (
       'not_required'::puls_integration.connector_credential_handoff_status,
       'not_started'::puls_integration.connector_credential_handoff_status,
       'requested'::puls_integration.connector_credential_handoff_status,
       'reference_pending'::puls_integration.connector_credential_handoff_status
     ) THEN
    NEW.credential_handoff_status := 'ready_for_verification'::puls_integration.connector_credential_handoff_status;
  ELSIF NEW.credential_state = 'missing'::puls_integration.connector_credential_state
     AND NEW.credential_handoff_status = 'not_required'::puls_integration.connector_credential_handoff_status THEN
    NEW.credential_handoff_status := 'not_started'::puls_integration.connector_credential_handoff_status;
  END IF;

  IF TG_OP = 'INSERT' THEN
    NEW.credential_handoff_updated_at := NOW();
  ELSIF NEW.credential_handoff_status IS DISTINCT FROM OLD.credential_handoff_status THEN
    NEW.credential_handoff_updated_at := NOW();
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS erp_connections_apply_credential_handoff_defaults
  ON puls_integration.erp_connections;
CREATE TRIGGER erp_connections_apply_credential_handoff_defaults
  BEFORE INSERT OR UPDATE OF credential_required, credential_state, credential_handoff_status
  ON puls_integration.erp_connections
  FOR EACH ROW
  EXECUTE FUNCTION puls_integration.apply_connector_credential_handoff_defaults();

CREATE INDEX IF NOT EXISTS erp_connections_tenant_credential_handoff_idx
  ON puls_integration.erp_connections (tenant_id, credential_handoff_status, credential_required);

COMMENT ON TYPE puls_integration.connector_credential_handoff_status IS
  'Source-independent credential handoff process state. It tracks safe setup progress, never secret values.';
COMMENT ON COLUMN puls_integration.erp_connections.credential_handoff_status IS
  'Safe credential handoff status for setup UX. Secret capture remains write-only and server-side.';
COMMENT ON COLUMN puls_integration.erp_connections.credential_handoff_requested_at IS
  'When an admin requested the secure credential handoff flow. This is not a secret timestamp.';
COMMENT ON COLUMN puls_integration.erp_connections.credential_handoff_requested_by_employee_id IS
  'Employee who requested secure credential handoff. Does not identify or expose a secret.';
COMMENT ON COLUMN puls_integration.erp_connections.credential_handoff_updated_at IS
  'Last time the safe credential handoff process state changed.';
COMMENT ON FUNCTION puls_integration.apply_connector_credential_handoff_defaults() IS
  'Keeps safe credential handoff status aligned with credential posture without storing secret material.';
