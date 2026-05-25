-- 09 PR3 — Authority graph + pools (non-manager authority only)
-- Manager SoT remains employee_reporting_lines (07). No resolver/decide changes in PR3.
-- No owner_employee_id on dimensions. PR5 wires graph into approval resolver V3.

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

DO $$ BEGIN
  CREATE TYPE puls_core.authority_type AS ENUM (
    'department_owner',
    'cost_center_owner',
    'legal_entity_owner',
    'location_owner',
    'hr_partner',
    'finance_approver',
    'legal_compliance_approver',
    'approval_delegate',
    'workflow_specific_delegate'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE puls_core.authority_scope_type AS ENUM (
    'tenant',
    'employee',
    'department',
    'legal_entity',
    'location',
    'cost_center',
    'leave_type',
    'expense_category'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE puls_core.authority_module AS ENUM (
    'global',
    'leave',
    'expense',
    'performance',
    'contracts'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE puls_core.authority_pool_type AS ENUM (
    'hr',
    'finance',
    'legal',
    'custom'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS puls_core.authority_pools (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  pool_type puls_core.authority_pool_type NOT NULL,
  module puls_core.authority_module NOT NULL DEFAULT 'global',
  scope_type puls_core.authority_scope_type NOT NULL DEFAULT 'tenant',
  scope_id UUID NULL,
  priority INTEGER NOT NULL DEFAULT 100,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  source TEXT NOT NULL DEFAULT 'manual',
  source_namespace_id UUID NULL REFERENCES puls_integration.source_namespaces(id) ON DELETE SET NULL,
  external_id TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, code),
  CHECK (
    (scope_type = 'tenant' AND scope_id IS NULL)
    OR (scope_type <> 'tenant' AND scope_id IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_puls_core_authority_pools_tenant_active
  ON puls_core.authority_pools (tenant_id, is_active);

CREATE INDEX IF NOT EXISTS idx_puls_core_authority_pools_tenant_code
  ON puls_core.authority_pools (tenant_id, code);

CREATE TABLE IF NOT EXISTS puls_core.authority_pool_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  pool_id UUID NOT NULL REFERENCES puls_core.authority_pools(id) ON DELETE CASCADE,
  employee_id UUID NOT NULL REFERENCES puls_core.employees(id) ON DELETE CASCADE,
  starts_on DATE NOT NULL DEFAULT CURRENT_DATE,
  ends_on DATE NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  priority INTEGER NOT NULL DEFAULT 100,
  source TEXT NOT NULL DEFAULT 'manual',
  source_namespace_id UUID NULL REFERENCES puls_integration.source_namespaces(id) ON DELETE SET NULL,
  external_id TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (ends_on IS NULL OR ends_on >= starts_on)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_puls_core_auth_pool_member_one_active
  ON puls_core.authority_pool_members (tenant_id, pool_id, employee_id)
  WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_puls_core_auth_pool_members_tenant_pool
  ON puls_core.authority_pool_members (tenant_id, pool_id, is_active);

CREATE TABLE IF NOT EXISTS puls_core.authority_relationships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  authority_type puls_core.authority_type NOT NULL,
  subject_employee_id UUID NOT NULL REFERENCES puls_core.employees(id) ON DELETE CASCADE,
  module puls_core.authority_module NOT NULL DEFAULT 'global',
  scope_type puls_core.authority_scope_type NOT NULL,
  scope_id UUID NULL,
  starts_on DATE NOT NULL DEFAULT CURRENT_DATE,
  ends_on DATE NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  priority INTEGER NOT NULL DEFAULT 100,
  source TEXT NOT NULL DEFAULT 'manual',
  source_namespace_id UUID NULL REFERENCES puls_integration.source_namespaces(id) ON DELETE SET NULL,
  external_id TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (
    (scope_type = 'tenant' AND scope_id IS NULL)
    OR (scope_type <> 'tenant' AND scope_id IS NOT NULL)
  ),
  CHECK (ends_on IS NULL OR ends_on >= starts_on)
);

CREATE INDEX IF NOT EXISTS idx_puls_core_auth_rel_tenant_active
  ON puls_core.authority_relationships (tenant_id, is_active);

CREATE INDEX IF NOT EXISTS idx_puls_core_auth_rel_lookup
  ON puls_core.authority_relationships (tenant_id, authority_type, scope_type, scope_id);

-- ---------------------------------------------------------------------------
-- updated_at triggers
-- ---------------------------------------------------------------------------

DROP TRIGGER IF EXISTS puls_core_authority_pools_set_updated_at ON puls_core.authority_pools;
CREATE TRIGGER puls_core_authority_pools_set_updated_at
  BEFORE UPDATE ON puls_core.authority_pools
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_core_auth_pool_members_set_updated_at ON puls_core.authority_pool_members;
CREATE TRIGGER puls_core_auth_pool_members_set_updated_at
  BEFORE UPDATE ON puls_core.authority_pool_members
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_core_auth_relationships_set_updated_at ON puls_core.authority_relationships;
CREATE TRIGGER puls_core_auth_relationships_set_updated_at
  BEFORE UPDATE ON puls_core.authority_relationships
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

-- ---------------------------------------------------------------------------
-- Shared scope + namespace validation
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_core.validate_authority_scope(
  p_tenant_id UUID,
  p_scope_type puls_core.authority_scope_type,
  p_scope_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_core, puls_workflow, puls_integration
AS $$
BEGIN
  IF p_scope_type = 'tenant'::puls_core.authority_scope_type THEN
    IF p_scope_id IS NOT NULL THEN
      RAISE EXCEPTION 'PULS_AUTHORITY_SCOPE_INVALID: tenant scope requires null scope_id.';
    END IF;
    RETURN;
  END IF;

  IF p_scope_id IS NULL THEN
    RAISE EXCEPTION 'PULS_AUTHORITY_SCOPE_INVALID: non-tenant scope requires scope_id.';
  END IF;

  CASE p_scope_type
    WHEN 'employee'::puls_core.authority_scope_type THEN
      IF NOT EXISTS (
        SELECT 1
        FROM puls_core.employees e
        WHERE e.id = p_scope_id
          AND e.tenant_id = p_tenant_id
          AND e.employment_status = 'active'::puls_core.employment_status
      ) THEN
        RAISE EXCEPTION 'PULS_AUTHORITY_SCOPE_INVALID: employee missing, inactive, or cross-tenant.';
      END IF;

    WHEN 'department'::puls_core.authority_scope_type THEN
      IF NOT EXISTS (
        SELECT 1
        FROM puls_core.departments d
        WHERE d.id = p_scope_id
          AND d.tenant_id = p_tenant_id
          AND d.is_active = TRUE
      ) THEN
        RAISE EXCEPTION 'PULS_AUTHORITY_SCOPE_INVALID: department missing, inactive, or cross-tenant.';
      END IF;

    WHEN 'legal_entity'::puls_core.authority_scope_type THEN
      IF NOT EXISTS (
        SELECT 1
        FROM puls_core.legal_entities le
        WHERE le.id = p_scope_id
          AND le.tenant_id = p_tenant_id
          AND le.is_active = TRUE
      ) THEN
        RAISE EXCEPTION 'PULS_AUTHORITY_SCOPE_INVALID: legal entity missing, inactive, or cross-tenant.';
      END IF;

    WHEN 'location'::puls_core.authority_scope_type THEN
      IF NOT EXISTS (
        SELECT 1
        FROM puls_core.locations loc
        WHERE loc.id = p_scope_id
          AND loc.tenant_id = p_tenant_id
          AND loc.is_active = TRUE
      ) THEN
        RAISE EXCEPTION 'PULS_AUTHORITY_SCOPE_INVALID: location missing, inactive, or cross-tenant.';
      END IF;

    WHEN 'cost_center'::puls_core.authority_scope_type THEN
      IF NOT EXISTS (
        SELECT 1
        FROM puls_core.cost_centers cc
        WHERE cc.id = p_scope_id
          AND cc.tenant_id = p_tenant_id
          AND cc.is_active = TRUE
      ) THEN
        RAISE EXCEPTION 'PULS_AUTHORITY_SCOPE_INVALID: cost center missing, inactive, or cross-tenant.';
      END IF;

    WHEN 'leave_type'::puls_core.authority_scope_type THEN
      IF NOT EXISTS (
        SELECT 1
        FROM puls_workflow.leave_types lt
        WHERE lt.id = p_scope_id
          AND lt.tenant_id = p_tenant_id
          AND lt.is_active = TRUE
      ) THEN
        RAISE EXCEPTION 'PULS_AUTHORITY_SCOPE_INVALID: leave type missing, inactive, or cross-tenant.';
      END IF;

    WHEN 'expense_category'::puls_core.authority_scope_type THEN
      IF NOT EXISTS (
        SELECT 1
        FROM puls_workflow.expense_categories ec
        WHERE ec.id = p_scope_id
          AND ec.tenant_id = p_tenant_id
          AND ec.is_active = TRUE
      ) THEN
        RAISE EXCEPTION 'PULS_AUTHORITY_SCOPE_INVALID: expense category missing, inactive, or cross-tenant.';
      END IF;

    ELSE
      RAISE EXCEPTION 'PULS_AUTHORITY_SCOPE_INVALID: unsupported scope_type.';
  END CASE;
END;
$$;

CREATE OR REPLACE FUNCTION puls_core.validate_authority_namespace(
  p_tenant_id UUID,
  p_source_namespace_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_core, puls_integration
AS $$
BEGIN
  IF p_source_namespace_id IS NULL THEN
    RETURN;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM puls_integration.source_namespaces sn
    WHERE sn.id = p_source_namespace_id
      AND sn.tenant_id = p_tenant_id
      AND sn.is_active = TRUE
  ) THEN
    RAISE EXCEPTION 'PULS_AUTHORITY_INVALID_NAMESPACE: source namespace missing, inactive, or cross-tenant.';
  END IF;
END;
$$;

-- ---------------------------------------------------------------------------
-- Pool validation triggers
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_core.validate_authority_pool()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_core, puls_workflow, puls_integration
AS $$
BEGIN
  NEW.code := btrim(NEW.code);
  IF NEW.code = '' THEN
    RAISE EXCEPTION 'PULS_AUTHORITY_INVALID_CODE: pool code must be non-empty.';
  END IF;

  PERFORM puls_core.validate_authority_scope(NEW.tenant_id, NEW.scope_type, NEW.scope_id);
  PERFORM puls_core.validate_authority_namespace(NEW.tenant_id, NEW.source_namespace_id);

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS puls_core_authority_pools_validate ON puls_core.authority_pools;
CREATE TRIGGER puls_core_authority_pools_validate
  BEFORE INSERT OR UPDATE ON puls_core.authority_pools
  FOR EACH ROW EXECUTE FUNCTION puls_core.validate_authority_pool();

CREATE OR REPLACE FUNCTION puls_core.validate_authority_pool_member()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_core, puls_workflow, puls_integration
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM puls_core.authority_pools p
    WHERE p.id = NEW.pool_id
      AND p.tenant_id = NEW.tenant_id
      AND p.is_active = TRUE
  ) THEN
    RAISE EXCEPTION 'PULS_AUTHORITY_INVALID_POOL: pool missing, inactive, or cross-tenant.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM puls_core.employees e
    WHERE e.id = NEW.employee_id
      AND e.tenant_id = NEW.tenant_id
      AND e.employment_status = 'active'::puls_core.employment_status
  ) THEN
    RAISE EXCEPTION 'PULS_AUTHORITY_INVALID_EMPLOYEE: employee missing, inactive, or cross-tenant.';
  END IF;

  IF NEW.ends_on IS NOT NULL AND NEW.ends_on < NEW.starts_on THEN
    RAISE EXCEPTION 'PULS_AUTHORITY_INVALID_DATES: ends_on must be >= starts_on.';
  END IF;

  PERFORM puls_core.validate_authority_namespace(NEW.tenant_id, NEW.source_namespace_id);

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS puls_core_auth_pool_members_validate ON puls_core.authority_pool_members;
CREATE TRIGGER puls_core_auth_pool_members_validate
  BEFORE INSERT OR UPDATE ON puls_core.authority_pool_members
  FOR EACH ROW EXECUTE FUNCTION puls_core.validate_authority_pool_member();

-- ---------------------------------------------------------------------------
-- Relationship validation trigger
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_core.validate_authority_relationship()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_core, puls_workflow, puls_integration
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM puls_core.employees e
    WHERE e.id = NEW.subject_employee_id
      AND e.tenant_id = NEW.tenant_id
      AND e.employment_status = 'active'::puls_core.employment_status
  ) THEN
    RAISE EXCEPTION 'PULS_AUTHORITY_INVALID_SUBJECT: subject employee missing, inactive, or cross-tenant.';
  END IF;

  PERFORM puls_core.validate_authority_scope(NEW.tenant_id, NEW.scope_type, NEW.scope_id);
  PERFORM puls_core.validate_authority_namespace(NEW.tenant_id, NEW.source_namespace_id);

  IF NEW.ends_on IS NOT NULL AND NEW.ends_on < NEW.starts_on THEN
    RAISE EXCEPTION 'PULS_AUTHORITY_INVALID_DATES: ends_on must be >= starts_on.';
  END IF;

  -- type ↔ scope (fail closed)
  CASE NEW.authority_type
    WHEN 'department_owner'::puls_core.authority_type THEN
      IF NEW.scope_type <> 'department'::puls_core.authority_scope_type THEN
        RAISE EXCEPTION 'PULS_AUTHORITY_SCOPE_INVALID: department_owner requires department scope.';
      END IF;
    WHEN 'cost_center_owner'::puls_core.authority_type THEN
      IF NEW.scope_type <> 'cost_center'::puls_core.authority_scope_type THEN
        RAISE EXCEPTION 'PULS_AUTHORITY_SCOPE_INVALID: cost_center_owner requires cost_center scope.';
      END IF;
    WHEN 'legal_entity_owner'::puls_core.authority_type THEN
      IF NEW.scope_type <> 'legal_entity'::puls_core.authority_scope_type THEN
        RAISE EXCEPTION 'PULS_AUTHORITY_SCOPE_INVALID: legal_entity_owner requires legal_entity scope.';
      END IF;
    WHEN 'location_owner'::puls_core.authority_type THEN
      IF NEW.scope_type <> 'location'::puls_core.authority_scope_type THEN
        RAISE EXCEPTION 'PULS_AUTHORITY_SCOPE_INVALID: location_owner requires location scope.';
      END IF;
    WHEN 'hr_partner'::puls_core.authority_type THEN
      IF NEW.scope_type NOT IN (
        'tenant'::puls_core.authority_scope_type,
        'legal_entity'::puls_core.authority_scope_type,
        'location'::puls_core.authority_scope_type,
        'department'::puls_core.authority_scope_type
      ) THEN
        RAISE EXCEPTION 'PULS_AUTHORITY_SCOPE_INVALID: hr_partner scope not allowed.';
      END IF;
    WHEN 'finance_approver'::puls_core.authority_type THEN
      IF NEW.scope_type NOT IN (
        'tenant'::puls_core.authority_scope_type,
        'legal_entity'::puls_core.authority_scope_type,
        'location'::puls_core.authority_scope_type,
        'cost_center'::puls_core.authority_scope_type,
        'expense_category'::puls_core.authority_scope_type
      ) THEN
        RAISE EXCEPTION 'PULS_AUTHORITY_SCOPE_INVALID: finance_approver scope not allowed.';
      END IF;
    WHEN 'legal_compliance_approver'::puls_core.authority_type THEN
      IF NEW.scope_type NOT IN (
        'tenant'::puls_core.authority_scope_type,
        'legal_entity'::puls_core.authority_scope_type,
        'location'::puls_core.authority_scope_type
      ) THEN
        RAISE EXCEPTION 'PULS_AUTHORITY_SCOPE_INVALID: legal_compliance_approver scope not allowed.';
      END IF;
    WHEN 'approval_delegate'::puls_core.authority_type,
         'workflow_specific_delegate'::puls_core.authority_type THEN
      IF NEW.scope_type NOT IN (
        'employee'::puls_core.authority_scope_type,
        'leave_type'::puls_core.authority_scope_type,
        'expense_category'::puls_core.authority_scope_type,
        'tenant'::puls_core.authority_scope_type
      ) THEN
        RAISE EXCEPTION 'PULS_AUTHORITY_SCOPE_INVALID: delegate scope not allowed.';
      END IF;
      IF NEW.scope_type = 'employee'::puls_core.authority_scope_type
         AND NEW.subject_employee_id = NEW.scope_id THEN
        RAISE EXCEPTION 'PULS_AUTHORITY_SELF_DELEGATE: subject cannot delegate authority to self via employee scope.';
      END IF;
    ELSE
      RAISE EXCEPTION 'PULS_AUTHORITY_SCOPE_INVALID: unsupported authority_type.';
  END CASE;

  -- type ↔ module (fail closed)
  CASE NEW.authority_type
    WHEN 'department_owner'::puls_core.authority_type,
         'cost_center_owner'::puls_core.authority_type,
         'legal_entity_owner'::puls_core.authority_type,
         'location_owner'::puls_core.authority_type THEN
      IF NEW.module <> 'global'::puls_core.authority_module THEN
        RAISE EXCEPTION 'PULS_AUTHORITY_MODULE_INVALID: owner authority types require global module.';
      END IF;
    WHEN 'hr_partner'::puls_core.authority_type THEN
      IF NEW.module NOT IN (
        'global'::puls_core.authority_module,
        'leave'::puls_core.authority_module,
        'performance'::puls_core.authority_module,
        'contracts'::puls_core.authority_module
      ) THEN
        RAISE EXCEPTION 'PULS_AUTHORITY_MODULE_INVALID: hr_partner module not allowed.';
      END IF;
    WHEN 'finance_approver'::puls_core.authority_type THEN
      IF NEW.module NOT IN (
        'global'::puls_core.authority_module,
        'expense'::puls_core.authority_module
      ) THEN
        RAISE EXCEPTION 'PULS_AUTHORITY_MODULE_INVALID: finance_approver module not allowed.';
      END IF;
    WHEN 'legal_compliance_approver'::puls_core.authority_type THEN
      IF NEW.module NOT IN (
        'global'::puls_core.authority_module,
        'contracts'::puls_core.authority_module
      ) THEN
        RAISE EXCEPTION 'PULS_AUTHORITY_MODULE_INVALID: legal_compliance_approver module not allowed.';
      END IF;
    WHEN 'approval_delegate'::puls_core.authority_type,
         'workflow_specific_delegate'::puls_core.authority_type THEN
      IF NEW.module NOT IN (
        'global'::puls_core.authority_module,
        'leave'::puls_core.authority_module,
        'expense'::puls_core.authority_module
      ) THEN
        RAISE EXCEPTION 'PULS_AUTHORITY_MODULE_INVALID: delegate module not allowed.';
      END IF;
    ELSE
      RAISE EXCEPTION 'PULS_AUTHORITY_MODULE_INVALID: unsupported authority_type.';
  END CASE;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS puls_core_auth_relationships_validate ON puls_core.authority_relationships;
CREATE TRIGGER puls_core_auth_relationships_validate
  BEFORE INSERT OR UPDATE ON puls_core.authority_relationships
  FOR EACH ROW EXECUTE FUNCTION puls_core.validate_authority_relationship();

-- ---------------------------------------------------------------------------
-- Helper functions (membership/authority only — no approval eligibility in PR3)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_core.can_manage_authority_graph()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
  SELECT puls_core.is_admin();
$$;

CREATE OR REPLACE FUNCTION puls_core.can_read_authority_graph()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
  SELECT puls_core.is_admin();
$$;

CREATE OR REPLACE FUNCTION puls_core.is_pool_member(
  p_pool_code TEXT,
  p_scope_type puls_core.authority_scope_type,
  p_scope_id UUID,
  p_module puls_core.authority_module DEFAULT 'global',
  p_as_of DATE DEFAULT CURRENT_DATE
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM puls_core.authority_pools p
    JOIN puls_core.authority_pool_members m
      ON m.pool_id = p.id
     AND m.tenant_id = p.tenant_id
    WHERE p.tenant_id = puls_core.current_tenant_id()
      AND p.code = p_pool_code
      AND p.is_active = TRUE
      AND (p.module = p_module OR p.module = 'global'::puls_core.authority_module)
      AND (
        p.scope_type = 'tenant'::puls_core.authority_scope_type
        OR (p.scope_type = p_scope_type AND p.scope_id IS NOT DISTINCT FROM p_scope_id)
      )
      AND m.employee_id = puls_core.current_employee_id()
      AND m.is_active = TRUE
      AND m.starts_on <= p_as_of
      AND (m.ends_on IS NULL OR m.ends_on >= p_as_of)
  );
$$;

CREATE OR REPLACE FUNCTION puls_core.is_pool_member_by_type(
  p_pool_type puls_core.authority_pool_type,
  p_scope_type puls_core.authority_scope_type,
  p_scope_id UUID,
  p_module puls_core.authority_module DEFAULT 'global',
  p_as_of DATE DEFAULT CURRENT_DATE
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM puls_core.authority_pools p
    JOIN puls_core.authority_pool_members m
      ON m.pool_id = p.id
     AND m.tenant_id = p.tenant_id
    WHERE p.tenant_id = puls_core.current_tenant_id()
      AND p.pool_type = p_pool_type
      AND p.is_active = TRUE
      AND (p.module = p_module OR p.module = 'global'::puls_core.authority_module)
      AND (
        p.scope_type = 'tenant'::puls_core.authority_scope_type
        OR (p.scope_type = p_scope_type AND p.scope_id IS NOT DISTINCT FROM p_scope_id)
      )
      AND m.employee_id = puls_core.current_employee_id()
      AND m.is_active = TRUE
      AND m.starts_on <= p_as_of
      AND (m.ends_on IS NULL OR m.ends_on >= p_as_of)
  );
$$;

CREATE OR REPLACE FUNCTION puls_core.has_authority(
  p_authority_type puls_core.authority_type,
  p_scope_type puls_core.authority_scope_type,
  p_scope_id UUID,
  p_module puls_core.authority_module DEFAULT 'global',
  p_as_of DATE DEFAULT CURRENT_DATE
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM puls_core.authority_relationships ar
    WHERE ar.tenant_id = puls_core.current_tenant_id()
      AND ar.subject_employee_id = puls_core.current_employee_id()
      AND ar.authority_type = p_authority_type
      AND ar.is_active = TRUE
      AND ar.starts_on <= p_as_of
      AND (ar.ends_on IS NULL OR ar.ends_on >= p_as_of)
      AND (ar.module = p_module OR ar.module = 'global'::puls_core.authority_module)
      AND ar.scope_type = p_scope_type
      AND ar.scope_id IS NOT DISTINCT FROM p_scope_id
  );
$$;

CREATE OR REPLACE FUNCTION puls_core.can_read_scope(
  p_scope_type puls_core.authority_scope_type,
  p_scope_id UUID,
  p_module puls_core.authority_module DEFAULT 'global'
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
BEGIN
  IF puls_core.is_admin() THEN
    RETURN TRUE;
  END IF;

  CASE p_scope_type
    WHEN 'department'::puls_core.authority_scope_type THEN
      IF puls_core.has_authority('department_owner'::puls_core.authority_type, p_scope_type, p_scope_id, p_module)
         OR puls_core.has_authority('hr_partner'::puls_core.authority_type, p_scope_type, p_scope_id, p_module) THEN
        RETURN TRUE;
      END IF;
      RETURN puls_core.is_pool_member_by_type('hr'::puls_core.authority_pool_type, p_scope_type, p_scope_id, p_module);

    WHEN 'cost_center'::puls_core.authority_scope_type THEN
      IF puls_core.has_authority('cost_center_owner'::puls_core.authority_type, p_scope_type, p_scope_id, p_module)
         OR puls_core.has_authority('finance_approver'::puls_core.authority_type, p_scope_type, p_scope_id, p_module) THEN
        RETURN TRUE;
      END IF;
      RETURN puls_core.is_pool_member_by_type('finance'::puls_core.authority_pool_type, p_scope_type, p_scope_id, p_module);

    WHEN 'legal_entity'::puls_core.authority_scope_type THEN
      IF puls_core.has_authority('legal_entity_owner'::puls_core.authority_type, p_scope_type, p_scope_id, p_module)
         OR puls_core.has_authority('hr_partner'::puls_core.authority_type, p_scope_type, p_scope_id, p_module)
         OR puls_core.has_authority('finance_approver'::puls_core.authority_type, p_scope_type, p_scope_id, p_module)
         OR puls_core.has_authority('legal_compliance_approver'::puls_core.authority_type, p_scope_type, p_scope_id, p_module) THEN
        RETURN TRUE;
      END IF;
      RETURN puls_core.is_pool_member_by_type('legal'::puls_core.authority_pool_type, p_scope_type, p_scope_id, p_module)
          OR puls_core.is_pool_member_by_type('hr'::puls_core.authority_pool_type, p_scope_type, p_scope_id, p_module)
          OR puls_core.is_pool_member_by_type('finance'::puls_core.authority_pool_type, p_scope_type, p_scope_id, p_module);

    WHEN 'location'::puls_core.authority_scope_type THEN
      IF puls_core.has_authority('location_owner'::puls_core.authority_type, p_scope_type, p_scope_id, p_module)
         OR puls_core.has_authority('hr_partner'::puls_core.authority_type, p_scope_type, p_scope_id, p_module)
         OR puls_core.has_authority('finance_approver'::puls_core.authority_type, p_scope_type, p_scope_id, p_module)
         OR puls_core.has_authority('legal_compliance_approver'::puls_core.authority_type, p_scope_type, p_scope_id, p_module) THEN
        RETURN TRUE;
      END IF;
      RETURN puls_core.is_pool_member_by_type('legal'::puls_core.authority_pool_type, p_scope_type, p_scope_id, p_module)
          OR puls_core.is_pool_member_by_type('hr'::puls_core.authority_pool_type, p_scope_type, p_scope_id, p_module)
          OR puls_core.is_pool_member_by_type('finance'::puls_core.authority_pool_type, p_scope_type, p_scope_id, p_module);

    WHEN 'employee'::puls_core.authority_scope_type THEN
      IF puls_core.has_authority('approval_delegate'::puls_core.authority_type, p_scope_type, p_scope_id, p_module)
         OR puls_core.has_authority('workflow_specific_delegate'::puls_core.authority_type, p_scope_type, p_scope_id, p_module) THEN
        RETURN TRUE;
      END IF;
      RETURN puls_core.is_pool_member_by_type('hr'::puls_core.authority_pool_type, p_scope_type, p_scope_id, p_module);

    WHEN 'leave_type'::puls_core.authority_scope_type THEN
      IF puls_core.has_authority('approval_delegate'::puls_core.authority_type, p_scope_type, p_scope_id, p_module)
         OR puls_core.has_authority('workflow_specific_delegate'::puls_core.authority_type, p_scope_type, p_scope_id, p_module)
         OR puls_core.has_authority('hr_partner'::puls_core.authority_type, p_scope_type, p_scope_id, p_module) THEN
        RETURN TRUE;
      END IF;
      RETURN puls_core.is_pool_member_by_type('hr'::puls_core.authority_pool_type, p_scope_type, p_scope_id, p_module);

    WHEN 'expense_category'::puls_core.authority_scope_type THEN
      IF puls_core.has_authority('approval_delegate'::puls_core.authority_type, p_scope_type, p_scope_id, p_module)
         OR puls_core.has_authority('workflow_specific_delegate'::puls_core.authority_type, p_scope_type, p_scope_id, p_module)
         OR puls_core.has_authority('finance_approver'::puls_core.authority_type, p_scope_type, p_scope_id, p_module) THEN
        RETURN TRUE;
      END IF;
      RETURN puls_core.is_pool_member_by_type('finance'::puls_core.authority_pool_type, p_scope_type, p_scope_id, p_module);

    WHEN 'tenant'::puls_core.authority_scope_type THEN
      IF puls_core.has_authority('hr_partner'::puls_core.authority_type, p_scope_type, NULL, p_module)
         OR puls_core.has_authority('finance_approver'::puls_core.authority_type, p_scope_type, NULL, p_module)
         OR puls_core.has_authority('legal_compliance_approver'::puls_core.authority_type, p_scope_type, NULL, p_module)
         OR puls_core.has_authority('approval_delegate'::puls_core.authority_type, p_scope_type, NULL, p_module)
         OR puls_core.has_authority('workflow_specific_delegate'::puls_core.authority_type, p_scope_type, NULL, p_module) THEN
        RETURN TRUE;
      END IF;
      RETURN puls_core.is_pool_member_by_type('hr'::puls_core.authority_pool_type, p_scope_type, NULL, p_module)
          OR puls_core.is_pool_member_by_type('finance'::puls_core.authority_pool_type, p_scope_type, NULL, p_module)
          OR puls_core.is_pool_member_by_type('legal'::puls_core.authority_pool_type, p_scope_type, NULL, p_module);

    ELSE
      RETURN FALSE;
  END CASE;
END;
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

ALTER TABLE puls_core.authority_pools ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_core.authority_pool_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_core.authority_relationships ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS puls_core_authority_pools_select ON puls_core.authority_pools;
CREATE POLICY puls_core_authority_pools_select ON puls_core.authority_pools
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND puls_core.can_read_authority_graph()
  );

DROP POLICY IF EXISTS puls_core_authority_pools_insert ON puls_core.authority_pools;
CREATE POLICY puls_core_authority_pools_insert ON puls_core.authority_pools
  FOR INSERT TO authenticated
  WITH CHECK (
    puls_core.can_manage_authority_graph()
    AND tenant_id = puls_core.current_tenant_id()
  );

DROP POLICY IF EXISTS puls_core_authority_pools_update ON puls_core.authority_pools;
CREATE POLICY puls_core_authority_pools_update ON puls_core.authority_pools
  FOR UPDATE TO authenticated
  USING (
    puls_core.can_manage_authority_graph()
    AND tenant_id = puls_core.current_tenant_id()
  )
  WITH CHECK (
    puls_core.can_manage_authority_graph()
    AND tenant_id = puls_core.current_tenant_id()
  );

DROP POLICY IF EXISTS puls_core_auth_pool_members_select ON puls_core.authority_pool_members;
CREATE POLICY puls_core_auth_pool_members_select ON puls_core.authority_pool_members
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND (
      puls_core.can_read_authority_graph()
      OR employee_id = puls_core.current_employee_id()
    )
  );

DROP POLICY IF EXISTS puls_core_auth_pool_members_insert ON puls_core.authority_pool_members;
CREATE POLICY puls_core_auth_pool_members_insert ON puls_core.authority_pool_members
  FOR INSERT TO authenticated
  WITH CHECK (
    puls_core.can_manage_authority_graph()
    AND tenant_id = puls_core.current_tenant_id()
  );

DROP POLICY IF EXISTS puls_core_auth_pool_members_update ON puls_core.authority_pool_members;
CREATE POLICY puls_core_auth_pool_members_update ON puls_core.authority_pool_members
  FOR UPDATE TO authenticated
  USING (
    puls_core.can_manage_authority_graph()
    AND tenant_id = puls_core.current_tenant_id()
  )
  WITH CHECK (
    puls_core.can_manage_authority_graph()
    AND tenant_id = puls_core.current_tenant_id()
  );

DROP POLICY IF EXISTS puls_core_auth_relationships_select ON puls_core.authority_relationships;
CREATE POLICY puls_core_auth_relationships_select ON puls_core.authority_relationships
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND (
      puls_core.can_read_authority_graph()
      OR subject_employee_id = puls_core.current_employee_id()
    )
  );

DROP POLICY IF EXISTS puls_core_auth_relationships_insert ON puls_core.authority_relationships;
CREATE POLICY puls_core_auth_relationships_insert ON puls_core.authority_relationships
  FOR INSERT TO authenticated
  WITH CHECK (
    puls_core.can_manage_authority_graph()
    AND tenant_id = puls_core.current_tenant_id()
  );

DROP POLICY IF EXISTS puls_core_auth_relationships_update ON puls_core.authority_relationships;
CREATE POLICY puls_core_auth_relationships_update ON puls_core.authority_relationships
  FOR UPDATE TO authenticated
  USING (
    puls_core.can_manage_authority_graph()
    AND tenant_id = puls_core.current_tenant_id()
  )
  WITH CHECK (
    puls_core.can_manage_authority_graph()
    AND tenant_id = puls_core.current_tenant_id()
  );

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

GRANT SELECT, INSERT, UPDATE ON puls_core.authority_pools TO authenticated;
GRANT SELECT, INSERT, UPDATE ON puls_core.authority_pool_members TO authenticated;
GRANT SELECT, INSERT, UPDATE ON puls_core.authority_relationships TO authenticated;

GRANT ALL ON puls_core.authority_pools TO service_role;
GRANT ALL ON puls_core.authority_pool_members TO service_role;
GRANT ALL ON puls_core.authority_relationships TO service_role;

REVOKE ALL ON FUNCTION puls_core.validate_authority_scope(UUID, puls_core.authority_scope_type, UUID) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_core.validate_authority_namespace(UUID, UUID) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_core.validate_authority_pool() FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_core.validate_authority_pool_member() FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_core.validate_authority_relationship() FROM PUBLIC, authenticated, anon;

REVOKE ALL ON FUNCTION puls_core.can_manage_authority_graph() FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_core.can_read_authority_graph() FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_core.is_pool_member(TEXT, puls_core.authority_scope_type, UUID, puls_core.authority_module, DATE) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_core.is_pool_member_by_type(puls_core.authority_pool_type, puls_core.authority_scope_type, UUID, puls_core.authority_module, DATE) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_core.has_authority(puls_core.authority_type, puls_core.authority_scope_type, UUID, puls_core.authority_module, DATE) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_core.can_read_scope(puls_core.authority_scope_type, UUID, puls_core.authority_module) FROM PUBLIC, authenticated, anon;

GRANT EXECUTE ON FUNCTION puls_core.can_manage_authority_graph() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_core.can_read_authority_graph() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_core.is_pool_member(TEXT, puls_core.authority_scope_type, UUID, puls_core.authority_module, DATE) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_core.is_pool_member_by_type(puls_core.authority_pool_type, puls_core.authority_scope_type, UUID, puls_core.authority_module, DATE) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_core.has_authority(puls_core.authority_type, puls_core.authority_scope_type, UUID, puls_core.authority_module, DATE) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_core.can_read_scope(puls_core.authority_scope_type, UUID, puls_core.authority_module) TO authenticated, service_role;
