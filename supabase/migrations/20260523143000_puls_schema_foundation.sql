-- PULS schema foundation: puls_core, puls_integration, puls_audit (evolved)
-- 01-db-schema-foundation — no leave/expense/performance/contract tables, no seed, no puls_core FK on audit.tenant_id

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE SCHEMA IF NOT EXISTS puls_core;
CREATE SCHEMA IF NOT EXISTS puls_integration;
CREATE SCHEMA IF NOT EXISTS puls_audit;

-- ---------------------------------------------------------------------------
-- puls_core enums
-- ---------------------------------------------------------------------------

DO $$ BEGIN
  CREATE TYPE puls_core.persona_role AS ENUM (
    'employee', 'manager', 'hr_admin', 'superadmin'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE puls_core.employment_status AS ENUM (
    'active', 'inactive', 'terminated', 'on_leave'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- puls_integration enums
-- ---------------------------------------------------------------------------

DO $$ BEGIN
  CREATE TYPE puls_integration.erp_provider AS ENUM (
    'canias', 'logo', 'netsis', 'sap_b1', 'mikro', 'csv'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE puls_integration.connection_method AS ENUM (
    'rest_api', 'soap', 'webhook', 'file_drop', 'manual_import'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE puls_integration.sync_direction AS ENUM (
    'erp_to_puls', 'puls_to_erp', 'bidirectional'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE puls_integration.sync_status AS ENUM (
    'pending', 'running', 'success', 'partial_success', 'failed', 'skipped'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE puls_integration.validation_status AS ENUM (
    'pending', 'valid', 'invalid', 'skipped'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE puls_integration.mapping_status AS ENUM (
    'pending', 'mapped', 'unmapped', 'ignored'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- puls_core tables (FK-safe create order)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS puls_core.tenants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  legacy_public_tenant_id UUID NULL,
  name TEXT NOT NULL,
  legal_name TEXT NULL,
  trade_name TEXT NULL,
  tax_no TEXT NULL,
  industry TEXT NULL,
  timezone TEXT NOT NULL DEFAULT 'Europe/Istanbul',
  locale TEXT NOT NULL DEFAULT 'tr-TR',
  plan_name TEXT NULL,
  kvkk_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS puls_core.employees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  legacy_public_employee_id UUID NULL,
  user_id UUID NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  external_employee_id TEXT NULL,
  external_source TEXT NULL,
  employee_code TEXT NULL,
  email TEXT NULL,
  full_name TEXT NOT NULL,
  job_title TEXT NULL,
  department_id UUID NULL,
  position_id UUID NULL,
  manager_employee_id UUID NULL,
  persona_role puls_core.persona_role NOT NULL DEFAULT 'employee',
  employment_status puls_core.employment_status NOT NULL DEFAULT 'active',
  hire_date DATE NULL,
  termination_date DATE NULL,
  source_updated_at TIMESTAMPTZ NULL,
  last_synced_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS puls_core.departments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  legacy_public_department_id UUID NULL,
  external_department_id TEXT NULL,
  external_source TEXT NULL,
  name TEXT NOT NULL,
  code TEXT NULL,
  parent_id UUID NULL,
  manager_employee_id UUID NULL,
  cost_center_code TEXT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  source_updated_at TIMESTAMPTZ NULL,
  last_synced_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS puls_core.positions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  legacy_public_position_id UUID NULL,
  external_position_id TEXT NULL,
  external_source TEXT NULL,
  name TEXT NOT NULL,
  code TEXT NULL,
  department_id UUID NULL,
  level INTEGER NULL,
  parent_position_id UUID NULL,
  employment_type TEXT NULL,
  norm_headcount INTEGER NOT NULL DEFAULT 1,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  source_updated_at TIMESTAMPTZ NULL,
  last_synced_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Deferred FK constraints (circular org graph)
DO $$ BEGIN
  ALTER TABLE puls_core.departments
    ADD CONSTRAINT puls_core_departments_parent_fk
    FOREIGN KEY (parent_id) REFERENCES puls_core.departments(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE puls_core.departments
    ADD CONSTRAINT puls_core_departments_manager_fk
    FOREIGN KEY (manager_employee_id) REFERENCES puls_core.employees(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE puls_core.employees
    ADD CONSTRAINT puls_core_employees_department_fk
    FOREIGN KEY (department_id) REFERENCES puls_core.departments(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE puls_core.employees
    ADD CONSTRAINT puls_core_employees_position_fk
    FOREIGN KEY (position_id) REFERENCES puls_core.positions(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE puls_core.employees
    ADD CONSTRAINT puls_core_employees_manager_fk
    FOREIGN KEY (manager_employee_id) REFERENCES puls_core.employees(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE puls_core.positions
    ADD CONSTRAINT puls_core_positions_department_fk
    FOREIGN KEY (department_id) REFERENCES puls_core.departments(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE puls_core.positions
    ADD CONSTRAINT puls_core_positions_parent_fk
    FOREIGN KEY (parent_position_id) REFERENCES puls_core.positions(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS idx_puls_core_tenants_legacy_public
  ON puls_core.tenants (legacy_public_tenant_id)
  WHERE legacy_public_tenant_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_puls_core_employees_tenant
  ON puls_core.employees (tenant_id);

CREATE INDEX IF NOT EXISTS idx_puls_core_employees_user
  ON puls_core.employees (user_id);

CREATE INDEX IF NOT EXISTS idx_puls_core_employees_manager
  ON puls_core.employees (manager_employee_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_puls_core_employees_external_unique
  ON puls_core.employees (tenant_id, external_source, external_employee_id)
  WHERE external_employee_id IS NOT NULL AND external_source IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_puls_core_departments_tenant
  ON puls_core.departments (tenant_id);

CREATE INDEX IF NOT EXISTS idx_puls_core_departments_external
  ON puls_core.departments (tenant_id, external_department_id);

CREATE INDEX IF NOT EXISTS idx_puls_core_positions_tenant
  ON puls_core.positions (tenant_id);

CREATE INDEX IF NOT EXISTS idx_puls_core_positions_external
  ON puls_core.positions (tenant_id, external_position_id);

-- ---------------------------------------------------------------------------
-- puls_integration tables
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS puls_integration.erp_connections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  provider puls_integration.erp_provider NOT NULL DEFAULT 'canias',
  display_name TEXT NOT NULL,
  connection_method puls_integration.connection_method NOT NULL DEFAULT 'rest_api',
  base_url TEXT NULL,
  firm_code TEXT NULL,
  credentials_ref TEXT NULL,
  is_active BOOLEAN NOT NULL DEFAULT FALSE,
  sync_direction puls_integration.sync_direction NOT NULL DEFAULT 'erp_to_puls',
  sync_schedule TEXT NULL,
  last_sync_at TIMESTAMPTZ NULL,
  last_status puls_integration.sync_status NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS puls_integration.erp_field_mappings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  connection_id UUID NOT NULL REFERENCES puls_integration.erp_connections(id) ON DELETE CASCADE,
  source_entity TEXT NOT NULL,
  source_field TEXT NOT NULL,
  target_schema TEXT NOT NULL,
  target_table TEXT NOT NULL,
  target_field TEXT NOT NULL,
  transform_rule JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_required BOOLEAN NOT NULL DEFAULT FALSE,
  is_sensitive BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  version INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS puls_integration.erp_sync_batches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  connection_id UUID NOT NULL REFERENCES puls_integration.erp_connections(id) ON DELETE CASCADE,
  sync_type TEXT NOT NULL,
  status puls_integration.sync_status NOT NULL DEFAULT 'pending',
  started_at TIMESTAMPTZ NULL,
  finished_at TIMESTAMPTZ NULL,
  records_seen INTEGER NOT NULL DEFAULT 0,
  records_inserted INTEGER NOT NULL DEFAULT 0,
  records_updated INTEGER NOT NULL DEFAULT 0,
  records_skipped INTEGER NOT NULL DEFAULT 0,
  records_failed INTEGER NOT NULL DEFAULT 0,
  error_summary TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS puls_integration.erp_staging_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  connection_id UUID NOT NULL REFERENCES puls_integration.erp_connections(id) ON DELETE CASCADE,
  sync_batch_id UUID NULL REFERENCES puls_integration.erp_sync_batches(id) ON DELETE SET NULL,
  source_entity TEXT NOT NULL,
  external_id TEXT NOT NULL,
  payload_hash TEXT NOT NULL,
  mapped_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  validation_status puls_integration.validation_status NOT NULL DEFAULT 'pending',
  validation_errors JSONB NOT NULL DEFAULT '[]'::jsonb,
  mapping_status puls_integration.mapping_status NOT NULL DEFAULT 'pending',
  source_updated_at TIMESTAMPTZ NULL,
  expires_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_puls_integration_field_mappings_unique
  ON puls_integration.erp_field_mappings (
    connection_id, source_entity, source_field,
    target_schema, target_table, target_field, version
  );

CREATE INDEX IF NOT EXISTS idx_puls_integration_connections_tenant
  ON puls_integration.erp_connections (tenant_id);

CREATE INDEX IF NOT EXISTS idx_puls_integration_mappings_tenant_connection
  ON puls_integration.erp_field_mappings (tenant_id, connection_id);

CREATE INDEX IF NOT EXISTS idx_puls_integration_batches_tenant_connection_created
  ON puls_integration.erp_sync_batches (tenant_id, connection_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_puls_integration_staging_tenant_entity_external
  ON puls_integration.erp_staging_records (tenant_id, source_entity, external_id);

-- ---------------------------------------------------------------------------
-- puls_audit.audit_logs — additive evolution (legacy-safe, no puls_core tenant FK)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS puls_audit.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NULL,
  actor_user_id UUID NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  actor_employee_id UUID NULL,
  actor_id UUID NULL,
  action TEXT NOT NULL,
  target_schema TEXT NULL,
  target_table TEXT NULL,
  target_id UUID NULL,
  target_object JSONB NULL DEFAULT '{}'::jsonb,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  request_id TEXT NULL,
  request_metadata JSONB NULL DEFAULT '{}'::jsonb,
  source TEXT NULL
);

ALTER TABLE puls_audit.audit_logs ADD COLUMN IF NOT EXISTS actor_user_id UUID NULL REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE puls_audit.audit_logs ADD COLUMN IF NOT EXISTS actor_employee_id UUID NULL;
ALTER TABLE puls_audit.audit_logs ADD COLUMN IF NOT EXISTS target_schema TEXT NULL;
ALTER TABLE puls_audit.audit_logs ADD COLUMN IF NOT EXISTS target_table TEXT NULL;
ALTER TABLE puls_audit.audit_logs ADD COLUMN IF NOT EXISTS target_id UUID NULL;
ALTER TABLE puls_audit.audit_logs ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE puls_audit.audit_logs ADD COLUMN IF NOT EXISTS request_id TEXT NULL;
ALTER TABLE puls_audit.audit_logs ADD COLUMN IF NOT EXISTS source TEXT NULL;

CREATE INDEX IF NOT EXISTS idx_puls_audit_logs_tenant_occurred
  ON puls_audit.audit_logs (tenant_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_puls_audit_logs_actor_user_occurred
  ON puls_audit.audit_logs (actor_user_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_puls_audit_logs_actor_id_occurred
  ON puls_audit.audit_logs (actor_id, occurred_at DESC);

-- ---------------------------------------------------------------------------
-- Helper functions (puls_core schema)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_core.current_legacy_public_tenant_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = puls_core, public
AS $$
  SELECT COALESCE(
    (SELECT tenant_id FROM public.employees WHERE user_id = auth.uid() LIMIT 1),
    (SELECT tenant_id FROM public.user_tenants WHERE user_id = auth.uid() AND is_default IS TRUE LIMIT 1),
    (SELECT tenant_id FROM public.user_tenants WHERE user_id = auth.uid() ORDER BY joined_at ASC NULLS LAST LIMIT 1)
  );
$$;

CREATE OR REPLACE FUNCTION puls_core.current_tenant_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = puls_core, public
AS $$
  SELECT COALESCE(
    (SELECT tenant_id FROM puls_core.employees WHERE user_id = auth.uid() LIMIT 1),
    (
      SELECT t.id
      FROM puls_core.tenants t
      WHERE t.legacy_public_tenant_id = puls_core.current_legacy_public_tenant_id()
      LIMIT 1
    )
  );
$$;

CREATE OR REPLACE FUNCTION puls_core.current_employee_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = puls_core, public
AS $$
  SELECT id FROM puls_core.employees WHERE user_id = auth.uid() LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION puls_core.current_persona_role()
RETURNS puls_core.persona_role
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = puls_core, public
AS $$
  SELECT COALESCE(
    (SELECT persona_role FROM puls_core.employees WHERE user_id = auth.uid() LIMIT 1),
    (
      SELECT CASE ur.role::text
        WHEN 'superadmin' THEN 'superadmin'::puls_core.persona_role
        WHEN 'patron' THEN 'superadmin'::puls_core.persona_role
        WHEN 'owner' THEN 'hr_admin'::puls_core.persona_role
        WHEN 'admin' THEN 'hr_admin'::puls_core.persona_role
        WHEN 'hr_admin' THEN 'hr_admin'::puls_core.persona_role
        WHEN 'hr' THEN 'hr_admin'::puls_core.persona_role
        WHEN 'ik_admin' THEN 'hr_admin'::puls_core.persona_role
        WHEN 'manager' THEN 'manager'::puls_core.persona_role
        WHEN 'yonetici' THEN 'manager'::puls_core.persona_role
        ELSE 'employee'::puls_core.persona_role
      END
      FROM public.user_roles ur
      WHERE ur.user_id = auth.uid()
        AND ur.tenant_id = puls_core.current_legacy_public_tenant_id()
      LIMIT 1
    ),
    'employee'::puls_core.persona_role
  );
$$;

CREATE OR REPLACE FUNCTION puls_core.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = puls_core, public
AS $$
  SELECT puls_core.current_persona_role() IN ('hr_admin'::puls_core.persona_role, 'superadmin'::puls_core.persona_role);
$$;

CREATE OR REPLACE FUNCTION puls_core.is_manager_or_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = puls_core, public
AS $$
  SELECT puls_core.current_persona_role() IN (
    'manager'::puls_core.persona_role,
    'hr_admin'::puls_core.persona_role,
    'superadmin'::puls_core.persona_role
  );
$$;

CREATE OR REPLACE FUNCTION puls_core.is_team_member(target_employee_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = puls_core, public
AS $$
  SELECT
    puls_core.is_admin()
    OR target_employee_id = puls_core.current_employee_id()
    OR EXISTS (
      SELECT 1
      FROM puls_core.employees e
      WHERE e.id = target_employee_id
        AND e.manager_employee_id = puls_core.current_employee_id()
        AND e.tenant_id = puls_core.current_tenant_id()
    );
$$;

CREATE OR REPLACE FUNCTION puls_core.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------
-- updated_at triggers
-- ---------------------------------------------------------------------------

DROP TRIGGER IF EXISTS puls_core_tenants_set_updated_at ON puls_core.tenants;
CREATE TRIGGER puls_core_tenants_set_updated_at
  BEFORE UPDATE ON puls_core.tenants
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_core_employees_set_updated_at ON puls_core.employees;
CREATE TRIGGER puls_core_employees_set_updated_at
  BEFORE UPDATE ON puls_core.employees
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_core_departments_set_updated_at ON puls_core.departments;
CREATE TRIGGER puls_core_departments_set_updated_at
  BEFORE UPDATE ON puls_core.departments
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_core_positions_set_updated_at ON puls_core.positions;
CREATE TRIGGER puls_core_positions_set_updated_at
  BEFORE UPDATE ON puls_core.positions
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_integration_connections_set_updated_at ON puls_integration.erp_connections;
CREATE TRIGGER puls_integration_connections_set_updated_at
  BEFORE UPDATE ON puls_integration.erp_connections
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_integration_mappings_set_updated_at ON puls_integration.erp_field_mappings;
CREATE TRIGGER puls_integration_mappings_set_updated_at
  BEFORE UPDATE ON puls_integration.erp_field_mappings
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_integration_staging_set_updated_at ON puls_integration.erp_staging_records;
CREATE TRIGGER puls_integration_staging_set_updated_at
  BEFORE UPDATE ON puls_integration.erp_staging_records
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

-- ---------------------------------------------------------------------------
-- Row level security
-- ---------------------------------------------------------------------------

ALTER TABLE puls_core.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_core.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_core.departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_core.positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_integration.erp_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_integration.erp_field_mappings ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_integration.erp_sync_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_integration.erp_staging_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_audit.audit_logs ENABLE ROW LEVEL SECURITY;

-- puls_core.tenants
DROP POLICY IF EXISTS puls_core_tenants_select ON puls_core.tenants;
CREATE POLICY puls_core_tenants_select ON puls_core.tenants
  FOR SELECT TO authenticated
  USING (id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_core_tenants_insert ON puls_core.tenants;
CREATE POLICY puls_core_tenants_insert ON puls_core.tenants
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_core_tenants_update ON puls_core.tenants;
CREATE POLICY puls_core_tenants_update ON puls_core.tenants
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND id = puls_core.current_tenant_id());

-- puls_core.employees
DROP POLICY IF EXISTS puls_core_employees_select ON puls_core.employees;
CREATE POLICY puls_core_employees_select ON puls_core.employees
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND (
      puls_core.is_admin()
      OR id = puls_core.current_employee_id()
      OR manager_employee_id = puls_core.current_employee_id()
    )
  );

DROP POLICY IF EXISTS puls_core_employees_insert ON puls_core.employees;
CREATE POLICY puls_core_employees_insert ON puls_core.employees
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_core_employees_update ON puls_core.employees;
CREATE POLICY puls_core_employees_update ON puls_core.employees
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

-- puls_core.departments
DROP POLICY IF EXISTS puls_core_departments_select ON puls_core.departments;
CREATE POLICY puls_core_departments_select ON puls_core.departments
  FOR SELECT TO authenticated
  USING (tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_core_departments_insert ON puls_core.departments;
CREATE POLICY puls_core_departments_insert ON puls_core.departments
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_core_departments_update ON puls_core.departments;
CREATE POLICY puls_core_departments_update ON puls_core.departments
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

-- puls_core.positions
DROP POLICY IF EXISTS puls_core_positions_select ON puls_core.positions;
CREATE POLICY puls_core_positions_select ON puls_core.positions
  FOR SELECT TO authenticated
  USING (tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_core_positions_insert ON puls_core.positions;
CREATE POLICY puls_core_positions_insert ON puls_core.positions
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_core_positions_update ON puls_core.positions;
CREATE POLICY puls_core_positions_update ON puls_core.positions
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

-- puls_integration.*
DROP POLICY IF EXISTS puls_integration_connections_select ON puls_integration.erp_connections;
CREATE POLICY puls_integration_connections_select ON puls_integration.erp_connections
  FOR SELECT TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

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
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_integration_mappings_insert ON puls_integration.erp_field_mappings;
CREATE POLICY puls_integration_mappings_insert ON puls_integration.erp_field_mappings
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_integration_mappings_update ON puls_integration.erp_field_mappings;
CREATE POLICY puls_integration_mappings_update ON puls_integration.erp_field_mappings
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_integration_batches_select ON puls_integration.erp_sync_batches;
CREATE POLICY puls_integration_batches_select ON puls_integration.erp_sync_batches
  FOR SELECT TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_integration_batches_insert ON puls_integration.erp_sync_batches;
CREATE POLICY puls_integration_batches_insert ON puls_integration.erp_sync_batches
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_integration_batches_update ON puls_integration.erp_sync_batches;
CREATE POLICY puls_integration_batches_update ON puls_integration.erp_sync_batches
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_integration_staging_select ON puls_integration.erp_staging_records;
CREATE POLICY puls_integration_staging_select ON puls_integration.erp_staging_records
  FOR SELECT TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_integration_staging_insert ON puls_integration.erp_staging_records;
CREATE POLICY puls_integration_staging_insert ON puls_integration.erp_staging_records
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_integration_staging_update ON puls_integration.erp_staging_records;
CREATE POLICY puls_integration_staging_update ON puls_integration.erp_staging_records
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

-- puls_audit.audit_logs (dual-tenant + legacy actor compatibility)
DROP POLICY IF EXISTS audit_insert ON puls_audit.audit_logs;
DROP POLICY IF EXISTS audit_select_tenant ON puls_audit.audit_logs;
DROP POLICY IF EXISTS puls_audit_logs_select ON puls_audit.audit_logs;
DROP POLICY IF EXISTS puls_audit_logs_insert ON puls_audit.audit_logs;

CREATE POLICY puls_audit_logs_select ON puls_audit.audit_logs
  FOR SELECT TO authenticated
  USING (
    (
      puls_core.is_admin()
      AND (
        tenant_id = puls_core.current_tenant_id()
        OR tenant_id = puls_core.current_legacy_public_tenant_id()
      )
    )
    OR actor_user_id = auth.uid()
    OR actor_id = auth.uid()
  );

CREATE POLICY puls_audit_logs_insert ON puls_audit.audit_logs
  FOR INSERT TO authenticated
  WITH CHECK (
    tenant_id IS NULL
    OR tenant_id = puls_core.current_tenant_id()
    OR tenant_id = puls_core.current_legacy_public_tenant_id()
  );

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

GRANT USAGE ON SCHEMA puls_core, puls_integration, puls_audit TO authenticated, service_role;

GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA puls_core TO authenticated;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA puls_integration TO authenticated;
GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA puls_audit TO authenticated;

GRANT ALL ON ALL TABLES IN SCHEMA puls_core, puls_integration, puls_audit TO service_role;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA puls_core TO authenticated, service_role;
