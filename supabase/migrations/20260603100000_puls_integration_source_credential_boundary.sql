-- PR14.12 source-independent credential boundary.
-- This migration adds generic connector authentication posture without storing secret values.

DO $$
BEGIN
  CREATE TYPE puls_integration.connector_auth_mode AS ENUM (
    'none',
    'api_key',
    'basic_auth',
    'bearer_token',
    'oauth2_client_credentials',
    'sftp_password',
    'connection_string',
    'custom_secret_ref'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE puls_integration.connector_credential_state AS ENUM (
    'not_required',
    'missing',
    'configured',
    'verified',
    'failed',
    'revoked'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE puls_integration.erp_connections
  ADD COLUMN IF NOT EXISTS auth_mode puls_integration.connector_auth_mode NOT NULL DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS credential_required BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS credential_state puls_integration.connector_credential_state NOT NULL DEFAULT 'not_required',
  ADD COLUMN IF NOT EXISTS credential_last_verified_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS credential_last_failed_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS credential_error_code TEXT NULL,
  ADD COLUMN IF NOT EXISTS credential_updated_by_employee_id UUID NULL REFERENCES puls_core.employees(id) ON DELETE SET NULL;

UPDATE puls_integration.erp_connections
SET
  auth_mode = CASE
    WHEN connection_method = 'manual_import'::puls_integration.connection_method
      AND credentials_ref IS NULL
      THEN 'none'::puls_integration.connector_auth_mode
    WHEN connection_method = 'file_drop'::puls_integration.connection_method
      THEN 'sftp_password'::puls_integration.connector_auth_mode
    ELSE 'custom_secret_ref'::puls_integration.connector_auth_mode
  END,
  credential_required =
    connection_method <> 'manual_import'::puls_integration.connection_method
    OR credentials_ref IS NOT NULL,
  credential_state = CASE
    WHEN connection_method = 'manual_import'::puls_integration.connection_method
      AND credentials_ref IS NULL
      THEN 'not_required'::puls_integration.connector_credential_state
    WHEN credentials_ref IS NULL
      THEN 'missing'::puls_integration.connector_credential_state
    ELSE 'configured'::puls_integration.connector_credential_state
  END,
  setup_metadata = setup_metadata || jsonb_build_object(
    'credential_boundary', 'reference_only',
    'secret_readback', 'disabled',
    'runtime_secret_resolution', 'server_side_future'
  )
WHERE auth_mode = 'none'::puls_integration.connector_auth_mode
  AND credential_state = 'not_required'::puls_integration.connector_credential_state;

CREATE OR REPLACE FUNCTION puls_integration.apply_connector_credential_defaults()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.connection_method = 'manual_import'::puls_integration.connection_method THEN
    IF NEW.credentials_ref IS NULL THEN
      NEW.auth_mode := 'none'::puls_integration.connector_auth_mode;
      NEW.credential_required := FALSE;
      NEW.credential_state := 'not_required'::puls_integration.connector_credential_state;
    ELSIF NEW.auth_mode = 'none'::puls_integration.connector_auth_mode
       AND NEW.credential_required IS FALSE
       AND NEW.credential_state = 'not_required'::puls_integration.connector_credential_state THEN
      NEW.auth_mode := 'custom_secret_ref'::puls_integration.connector_auth_mode;
      NEW.credential_required := TRUE;
      NEW.credential_state := 'configured'::puls_integration.connector_credential_state;
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.auth_mode = 'none'::puls_integration.connector_auth_mode
     AND NEW.credential_required IS FALSE
     AND NEW.credential_state = 'not_required'::puls_integration.connector_credential_state THEN
    NEW.auth_mode := CASE
      WHEN NEW.connection_method = 'file_drop'::puls_integration.connection_method
        THEN 'sftp_password'::puls_integration.connector_auth_mode
      ELSE 'custom_secret_ref'::puls_integration.connector_auth_mode
    END;
    NEW.credential_required := TRUE;
    NEW.credential_state := CASE
      WHEN NEW.credentials_ref IS NULL
        THEN 'missing'::puls_integration.connector_credential_state
      ELSE 'configured'::puls_integration.connector_credential_state
    END;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS erp_connections_apply_credential_defaults
  ON puls_integration.erp_connections;
CREATE TRIGGER erp_connections_apply_credential_defaults
  BEFORE INSERT ON puls_integration.erp_connections
  FOR EACH ROW
  EXECUTE FUNCTION puls_integration.apply_connector_credential_defaults();

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'puls_integration_credential_state_ref_check'
  ) THEN
    ALTER TABLE puls_integration.erp_connections
      ADD CONSTRAINT puls_integration_credential_state_ref_check CHECK (
        (
          credential_required IS FALSE
          AND auth_mode = 'none'::puls_integration.connector_auth_mode
          AND credential_state = 'not_required'::puls_integration.connector_credential_state
          AND credentials_ref IS NULL
        )
        OR
        (
          credential_required IS TRUE
          AND auth_mode <> 'none'::puls_integration.connector_auth_mode
          AND (
            (
              credential_state = 'missing'::puls_integration.connector_credential_state
              AND credentials_ref IS NULL
            )
            OR
            (
              credential_state IN (
                'configured'::puls_integration.connector_credential_state,
                'failed'::puls_integration.connector_credential_state,
                'revoked'::puls_integration.connector_credential_state
              )
              AND credentials_ref IS NOT NULL
            )
            OR
            (
              credential_state = 'verified'::puls_integration.connector_credential_state
              AND credentials_ref IS NOT NULL
              AND credential_last_verified_at IS NOT NULL
            )
          )
        )
      );
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS erp_connections_tenant_credential_state_idx
  ON puls_integration.erp_connections (tenant_id, credential_state, credential_required);

COMMENT ON TYPE puls_integration.connector_auth_mode IS
  'Source-independent connector authentication mode. Values describe the future server-side secret boundary; they do not store secret material.';
COMMENT ON TYPE puls_integration.connector_credential_state IS
  'Source-independent connector credential posture used by setup and preflight without exposing secret values.';
COMMENT ON COLUMN puls_integration.erp_connections.auth_mode IS
  'Authentication mode required by the source profile. Generic across ERP, file, and custom API connectors.';
COMMENT ON COLUMN puls_integration.erp_connections.credential_required IS
  'Whether this source requires a secret boundary before live runtime can be enabled.';
COMMENT ON COLUMN puls_integration.erp_connections.credential_state IS
  'Setup-facing credential posture. Missing/configured/verified states are safe to display; secret values are never displayed.';
COMMENT ON COLUMN puls_integration.erp_connections.credentials_ref IS
  'Opaque server-side secret reference only. Product UI and client adapters must not read or expose this value.';
COMMENT ON COLUMN puls_integration.erp_connections.credential_last_verified_at IS
  'Last successful server-side credential verification time, when a future runtime boundary performs it.';
COMMENT ON COLUMN puls_integration.erp_connections.credential_last_failed_at IS
  'Last failed server-side credential verification time, when a future runtime boundary performs it.';
COMMENT ON COLUMN puls_integration.erp_connections.credential_error_code IS
  'Safe non-secret credential verification error class for setup recovery copy.';
COMMENT ON COLUMN puls_integration.erp_connections.credential_updated_by_employee_id IS
  'Employee who last changed credential posture metadata, not the secret value.';
COMMENT ON FUNCTION puls_integration.apply_connector_credential_defaults() IS
  'Applies source-independent credential defaults from connection_method when inserts omit explicit auth posture.';
