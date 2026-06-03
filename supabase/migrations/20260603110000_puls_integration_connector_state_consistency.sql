-- PR14.12B connector state consistency findings.
-- Keeps setup posture truthful when the credential boundary is not ready.

UPDATE puls_integration.erp_connections
SET
  setup_status = 'mapping_ready'::puls_integration.connector_setup_status,
  setup_step = 'preflight'::puls_integration.connector_setup_step,
  setup_metadata = setup_metadata || jsonb_build_object(
    'state_consistency_gate', 'credential_boundary_required',
    'preflight_ready_blocked_by', 'credential_state'
  )
WHERE setup_status = 'preflight_ready'::puls_integration.connector_setup_status
  AND credential_required IS TRUE
  AND credential_state <> 'verified'::puls_integration.connector_credential_state;

WITH stronger_connections AS (
  SELECT
    keeper.id AS keeper_id,
    duplicate.id AS duplicate_id
  FROM puls_integration.erp_connections duplicate
  JOIN puls_integration.erp_connections keeper
    ON keeper.tenant_id = duplicate.tenant_id
   AND keeper.provider = duplicate.provider
   AND keeper.id <> duplicate.id
   AND keeper.setup_status IN (
     'setup_in_progress'::puls_integration.connector_setup_status,
     'mapping_ready'::puls_integration.connector_setup_status,
     'preflight_ready'::puls_integration.connector_setup_status,
     'connected'::puls_integration.connector_setup_status
   )
   AND keeper.is_enabled IS TRUE
  WHERE duplicate.setup_status = 'draft'::puls_integration.connector_setup_status
    AND duplicate.is_enabled IS TRUE
    AND (
      duplicate.connection_key = keeper.connection_key
      OR COALESCE(array_length(duplicate.owned_domains, 1), 0) = 0
      OR duplicate.owned_domains && keeper.owned_domains
    )
)
UPDATE puls_integration.erp_connections c
SET
  setup_status = 'archived'::puls_integration.connector_setup_status,
  setup_step = 'source'::puls_integration.connector_setup_step,
  is_enabled = FALSE,
  setup_metadata = c.setup_metadata || jsonb_build_object(
    'archived_reason', 'duplicate_provider_domain_setup',
    'archived_by_migration', '20260603110000'
  )
FROM stronger_connections sc
WHERE c.id = sc.duplicate_id;

COMMENT ON COLUMN puls_integration.erp_connections.setup_status IS
  'Connector setup lifecycle state. preflight_ready means all dry-run setup checks are clean; missing credentials keep the setup at mapping_ready/preflight.';
