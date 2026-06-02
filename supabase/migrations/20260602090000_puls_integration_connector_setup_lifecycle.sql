-- PR14.8 connector setup lifecycle: persisted setup state, no runtime sync.

DO $$ BEGIN
  CREATE TYPE puls_integration.connector_setup_status AS ENUM (
    'draft',
    'setup_in_progress',
    'mapping_ready',
    'preflight_ready',
    'connected',
    'disabled',
    'archived',
    'error'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE puls_integration.connector_setup_step AS ENUM (
    'source',
    'mapping',
    'namespace',
    'preflight',
    'runtime'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE puls_integration.erp_connections
  ADD COLUMN IF NOT EXISTS connection_key TEXT NULL,
  ADD COLUMN IF NOT EXISTS setup_status puls_integration.connector_setup_status NOT NULL DEFAULT 'draft',
  ADD COLUMN IF NOT EXISTS setup_step puls_integration.connector_setup_step NOT NULL DEFAULT 'source',
  ADD COLUMN IF NOT EXISTS is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS selected_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS setup_started_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS owned_domains TEXT[] NOT NULL DEFAULT '{}'::TEXT[],
  ADD COLUMN IF NOT EXISTS setup_metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
  ADD COLUMN IF NOT EXISTS created_by_employee_id UUID NULL REFERENCES puls_core.employees(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS updated_by_employee_id UUID NULL REFERENCES puls_core.employees(id) ON DELETE SET NULL;

UPDATE puls_integration.erp_connections
SET connection_key = LOWER(provider::TEXT) || '-default'
WHERE connection_key IS NULL;

UPDATE puls_integration.erp_connections c
SET
  setup_status = CASE
    WHEN c.is_active THEN 'connected'::puls_integration.connector_setup_status
    WHEN EXISTS (
      SELECT 1
      FROM puls_integration.erp_field_mappings fm
      WHERE fm.connection_id = c.id
        AND fm.is_active IS TRUE
    ) THEN 'preflight_ready'::puls_integration.connector_setup_status
    ELSE c.setup_status
  END,
  setup_step = CASE
    WHEN c.is_active THEN 'runtime'::puls_integration.connector_setup_step
    WHEN EXISTS (
      SELECT 1
      FROM puls_integration.erp_field_mappings fm
      WHERE fm.connection_id = c.id
        AND fm.is_active IS TRUE
    ) THEN 'preflight'::puls_integration.connector_setup_step
    ELSE c.setup_step
  END,
  selected_at = COALESCE(c.selected_at, c.created_at),
  setup_started_at = COALESCE(c.setup_started_at, c.created_at),
  owned_domains = CASE
    WHEN COALESCE(array_length(c.owned_domains, 1), 0) > 0 THEN c.owned_domains
    WHEN c.provider = 'canias'::puls_integration.erp_provider THEN ARRAY[
      'employees',
      'departments',
      'positions',
      'cost_centers'
    ]::TEXT[]
    WHEN c.provider = 'csv'::puls_integration.erp_provider THEN ARRAY[
      'employees',
      'departments',
      'positions',
      'cost_centers'
    ]::TEXT[]
    ELSE c.owned_domains
  END,
  setup_metadata = CASE
    WHEN c.setup_metadata = '{}'::JSONB THEN jsonb_build_object(
      'runtime_boundary', 'closed',
      'credential_boundary', 'reference_only_future',
      'source_ownership', 'domain_level'
    )
    ELSE c.setup_metadata
  END
WHERE c.setup_status IN (
  'draft'::puls_integration.connector_setup_status,
  'connected'::puls_integration.connector_setup_status
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_puls_integration_connections_tenant_key
  ON puls_integration.erp_connections (tenant_id, connection_key)
  WHERE connection_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_puls_integration_connections_tenant_status
  ON puls_integration.erp_connections (tenant_id, setup_status, is_enabled);

COMMENT ON COLUMN puls_integration.erp_connections.connection_key IS
  'Tenant-scoped stable setup key such as canias-default or csv-excel-default; not a credential.';
COMMENT ON COLUMN puls_integration.erp_connections.setup_status IS
  'Connector setup lifecycle state. Runtime sync remains separate from setup persistence.';
COMMENT ON COLUMN puls_integration.erp_connections.setup_step IS
  'Current setup wizard step: source, mapping, namespace, preflight, or runtime.';
COMMENT ON COLUMN puls_integration.erp_connections.is_enabled IS
  'Product-level setup enablement flag. Does not mean runtime sync is active.';
COMMENT ON COLUMN puls_integration.erp_connections.owned_domains IS
  'Canonical PULS domains this source may own after mapping is validated.';
COMMENT ON COLUMN puls_integration.erp_connections.setup_metadata IS
  'Non-secret setup metadata. API keys, passwords, tokens, and credentials do not belong here.';

DROP POLICY IF EXISTS puls_integration_connections_select ON puls_integration.erp_connections;
CREATE POLICY puls_integration_connections_select ON puls_integration.erp_connections
  FOR SELECT TO authenticated
  USING (
    puls_core.is_manager_or_admin()
    AND tenant_id = puls_core.current_tenant_id()
  );

DROP POLICY IF EXISTS puls_integration_connections_insert ON puls_integration.erp_connections;
CREATE POLICY puls_integration_connections_insert ON puls_integration.erp_connections
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_integration_connections_update ON puls_integration.erp_connections;
CREATE POLICY puls_integration_connections_update ON puls_integration.erp_connections
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_integration_mappings_select ON puls_integration.erp_field_mappings;
CREATE POLICY puls_integration_mappings_select ON puls_integration.erp_field_mappings
  FOR SELECT TO authenticated
  USING (
    puls_core.is_manager_or_admin()
    AND tenant_id = puls_core.current_tenant_id()
  );

DROP POLICY IF EXISTS puls_integration_batches_select ON puls_integration.erp_sync_batches;
CREATE POLICY puls_integration_batches_select ON puls_integration.erp_sync_batches
  FOR SELECT TO authenticated
  USING (
    puls_core.is_manager_or_admin()
    AND tenant_id = puls_core.current_tenant_id()
  );

DROP POLICY IF EXISTS puls_integration_source_namespaces_select ON puls_integration.source_namespaces;
CREATE POLICY puls_integration_source_namespaces_select ON puls_integration.source_namespaces
  FOR SELECT TO authenticated
  USING (
    puls_core.is_manager_or_admin()
    AND tenant_id = puls_core.current_tenant_id()
  );

DROP POLICY IF EXISTS puls_integration_identity_map_select ON puls_integration.entity_identity_map;
CREATE POLICY puls_integration_identity_map_select ON puls_integration.entity_identity_map
  FOR SELECT TO authenticated
  USING (
    puls_core.is_manager_or_admin()
    AND tenant_id = puls_core.current_tenant_id()
  );
