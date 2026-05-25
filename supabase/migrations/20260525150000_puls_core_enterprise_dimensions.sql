-- 09 PR2 — Enterprise dimensions (legal entity, location, cost center) + assignments + employee cache
-- No authority graph in PR2; dimension owner columns deferred to PR3.
-- Assignment tables are SoT; employees.{legal_entity_id,location_id,cost_center_id} are cache only.

-- ---------------------------------------------------------------------------
-- Extend import entity enum (ADD VALUE only — no enum-typed DML in this migration)
-- ---------------------------------------------------------------------------

ALTER TYPE puls_integration.import_entity_type ADD VALUE IF NOT EXISTS 'legal_entity';
ALTER TYPE puls_integration.import_entity_type ADD VALUE IF NOT EXISTS 'location';
ALTER TYPE puls_integration.import_entity_type ADD VALUE IF NOT EXISTS 'cost_center';

-- ---------------------------------------------------------------------------
-- Dimension tables
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS puls_core.legal_entities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  source_namespace_id UUID NULL REFERENCES puls_integration.source_namespaces(id) ON DELETE SET NULL,
  external_id TEXT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, code)
);

CREATE INDEX IF NOT EXISTS idx_puls_core_legal_entities_tenant_active
  ON puls_core.legal_entities (tenant_id, is_active);

CREATE TABLE IF NOT EXISTS puls_core.locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  legal_entity_id UUID NOT NULL,
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  source_namespace_id UUID NULL REFERENCES puls_integration.source_namespaces(id) ON DELETE SET NULL,
  external_id TEXT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, code)
);

CREATE INDEX IF NOT EXISTS idx_puls_core_locations_tenant_legal_entity
  ON puls_core.locations (tenant_id, legal_entity_id);

CREATE TABLE IF NOT EXISTS puls_core.cost_centers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  legal_entity_id UUID NOT NULL,
  parent_cost_center_id UUID NULL,
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  source_namespace_id UUID NULL REFERENCES puls_integration.source_namespaces(id) ON DELETE SET NULL,
  external_id TEXT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, code),
  CHECK (parent_cost_center_id IS NULL OR parent_cost_center_id <> id)
);

CREATE INDEX IF NOT EXISTS idx_puls_core_cost_centers_tenant_legal_entity
  ON puls_core.cost_centers (tenant_id, legal_entity_id);

CREATE INDEX IF NOT EXISTS idx_puls_core_cost_centers_tenant_parent
  ON puls_core.cost_centers (tenant_id, parent_cost_center_id)
  WHERE parent_cost_center_id IS NOT NULL;

DO $$ BEGIN
  ALTER TABLE puls_core.locations
    ADD CONSTRAINT puls_core_locations_legal_entity_fk
    FOREIGN KEY (legal_entity_id) REFERENCES puls_core.legal_entities(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE puls_core.cost_centers
    ADD CONSTRAINT puls_core_cost_centers_legal_entity_fk
    FOREIGN KEY (legal_entity_id) REFERENCES puls_core.legal_entities(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE puls_core.cost_centers
    ADD CONSTRAINT puls_core_cost_centers_parent_fk
    FOREIGN KEY (parent_cost_center_id) REFERENCES puls_core.cost_centers(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- Assignment tables (SoT)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS puls_core.employee_legal_entity_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  employee_id UUID NOT NULL REFERENCES puls_core.employees(id) ON DELETE CASCADE,
  legal_entity_id UUID NOT NULL REFERENCES puls_core.legal_entities(id) ON DELETE RESTRICT,
  starts_on DATE NOT NULL DEFAULT CURRENT_DATE,
  ends_on DATE NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  source TEXT NOT NULL DEFAULT 'manual',
  source_namespace_id UUID NULL REFERENCES puls_integration.source_namespaces(id) ON DELETE SET NULL,
  external_id TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (ends_on IS NULL OR ends_on >= starts_on),
  CHECK (source IN ('manual', 'erp', 'bootstrap', 'demo', 'import'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_puls_core_emp_le_assign_one_active
  ON puls_core.employee_legal_entity_assignments (tenant_id, employee_id)
  WHERE is_active = TRUE;

CREATE TABLE IF NOT EXISTS puls_core.employee_location_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  employee_id UUID NOT NULL REFERENCES puls_core.employees(id) ON DELETE CASCADE,
  location_id UUID NOT NULL REFERENCES puls_core.locations(id) ON DELETE RESTRICT,
  starts_on DATE NOT NULL DEFAULT CURRENT_DATE,
  ends_on DATE NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  source TEXT NOT NULL DEFAULT 'manual',
  source_namespace_id UUID NULL REFERENCES puls_integration.source_namespaces(id) ON DELETE SET NULL,
  external_id TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (ends_on IS NULL OR ends_on >= starts_on),
  CHECK (source IN ('manual', 'erp', 'bootstrap', 'demo', 'import'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_puls_core_emp_loc_assign_one_active
  ON puls_core.employee_location_assignments (tenant_id, employee_id)
  WHERE is_active = TRUE;

CREATE TABLE IF NOT EXISTS puls_core.employee_cost_center_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  employee_id UUID NOT NULL REFERENCES puls_core.employees(id) ON DELETE CASCADE,
  cost_center_id UUID NOT NULL REFERENCES puls_core.cost_centers(id) ON DELETE RESTRICT,
  starts_on DATE NOT NULL DEFAULT CURRENT_DATE,
  ends_on DATE NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  source TEXT NOT NULL DEFAULT 'manual',
  source_namespace_id UUID NULL REFERENCES puls_integration.source_namespaces(id) ON DELETE SET NULL,
  external_id TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (ends_on IS NULL OR ends_on >= starts_on),
  CHECK (source IN ('manual', 'erp', 'bootstrap', 'demo', 'import'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_puls_core_emp_cc_assign_one_active
  ON puls_core.employee_cost_center_assignments (tenant_id, employee_id)
  WHERE is_active = TRUE;

-- ---------------------------------------------------------------------------
-- Employee cache columns (not SoT)
-- ---------------------------------------------------------------------------

ALTER TABLE puls_core.employees
  ADD COLUMN IF NOT EXISTS legal_entity_id UUID NULL,
  ADD COLUMN IF NOT EXISTS location_id UUID NULL,
  ADD COLUMN IF NOT EXISTS cost_center_id UUID NULL;

COMMENT ON COLUMN puls_core.employees.legal_entity_id IS
  'Cache only; SoT is employee_legal_entity_assignments. Synced by trigger from active assignment.';

COMMENT ON COLUMN puls_core.employees.location_id IS
  'Cache only; SoT is employee_location_assignments. Synced by trigger from active assignment.';

COMMENT ON COLUMN puls_core.employees.cost_center_id IS
  'Cache only; SoT is employee_cost_center_assignments. Synced by trigger from active assignment.';

DO $$ BEGIN
  ALTER TABLE puls_core.employees
    ADD CONSTRAINT puls_core_employees_legal_entity_fk
    FOREIGN KEY (legal_entity_id) REFERENCES puls_core.legal_entities(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE puls_core.employees
    ADD CONSTRAINT puls_core_employees_location_fk
    FOREIGN KEY (location_id) REFERENCES puls_core.locations(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE puls_core.employees
    ADD CONSTRAINT puls_core_employees_cost_center_fk
    FOREIGN KEY (cost_center_id) REFERENCES puls_core.cost_centers(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Department optional FK to cost center (replaces code-only linkage over time)
ALTER TABLE puls_core.departments
  ADD COLUMN IF NOT EXISTS cost_center_id UUID NULL;

DO $$ BEGIN
  ALTER TABLE puls_core.departments
    ADD CONSTRAINT puls_core_departments_cost_center_fk
    FOREIGN KEY (cost_center_id) REFERENCES puls_core.cost_centers(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

COMMENT ON COLUMN puls_core.departments.cost_center_id IS
  'Optional link to puls_core.cost_centers; validated same-tenant and active. cost_center_code legacy text retained.';

-- ---------------------------------------------------------------------------
-- updated_at triggers
-- ---------------------------------------------------------------------------

DROP TRIGGER IF EXISTS puls_core_legal_entities_set_updated_at ON puls_core.legal_entities;
CREATE TRIGGER puls_core_legal_entities_set_updated_at
  BEFORE UPDATE ON puls_core.legal_entities
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_core_locations_set_updated_at ON puls_core.locations;
CREATE TRIGGER puls_core_locations_set_updated_at
  BEFORE UPDATE ON puls_core.locations
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_core_cost_centers_set_updated_at ON puls_core.cost_centers;
CREATE TRIGGER puls_core_cost_centers_set_updated_at
  BEFORE UPDATE ON puls_core.cost_centers
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_core_emp_le_assign_set_updated_at ON puls_core.employee_legal_entity_assignments;
CREATE TRIGGER puls_core_emp_le_assign_set_updated_at
  BEFORE UPDATE ON puls_core.employee_legal_entity_assignments
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_core_emp_loc_assign_set_updated_at ON puls_core.employee_location_assignments;
CREATE TRIGGER puls_core_emp_loc_assign_set_updated_at
  BEFORE UPDATE ON puls_core.employee_location_assignments
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_core_emp_cc_assign_set_updated_at ON puls_core.employee_cost_center_assignments;
CREATE TRIGGER puls_core_emp_cc_assign_set_updated_at
  BEFORE UPDATE ON puls_core.employee_cost_center_assignments
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

-- ---------------------------------------------------------------------------
-- Dimension tenant / namespace validation
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_core.validate_enterprise_dimension_namespace()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_core, puls_integration
AS $$
BEGIN
  IF NEW.source_namespace_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM puls_integration.source_namespaces sn
      WHERE sn.id = NEW.source_namespace_id
        AND sn.tenant_id = NEW.tenant_id
        AND sn.is_active = TRUE
    ) THEN
      RAISE EXCEPTION 'PULS_DIMENSION_INVALID_NAMESPACE: source namespace missing, inactive, or cross-tenant.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION puls_core.validate_location_tenant()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM puls_core.legal_entities le
    WHERE le.id = NEW.legal_entity_id
      AND le.tenant_id = NEW.tenant_id
      AND le.is_active = TRUE
  ) THEN
    RAISE EXCEPTION 'PULS_LOCATION_INVALID_LEGAL_ENTITY: legal entity missing, inactive, or cross-tenant.';
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION puls_core.detect_cost_center_cycle(
  p_tenant_id UUID,
  p_cost_center_id UUID,
  p_parent_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
DECLARE
  v_current UUID := p_parent_id;
  v_depth INTEGER := 0;
  v_visited UUID[] := ARRAY[]::UUID[];
  v_next UUID;
BEGIN
  IF p_parent_id IS NULL THEN
    RETURN FALSE;
  END IF;

  IF p_cost_center_id IS NOT NULL AND p_parent_id = p_cost_center_id THEN
    RETURN TRUE;
  END IF;

  WHILE v_current IS NOT NULL AND v_depth < 20 LOOP
    IF p_cost_center_id IS NOT NULL AND v_current = p_cost_center_id THEN
      RETURN TRUE;
    END IF;

    IF v_current = ANY(v_visited) THEN
      RETURN TRUE;
    END IF;

    v_visited := v_visited || v_current;

    SELECT cc.parent_cost_center_id
    INTO v_next
    FROM puls_core.cost_centers cc
    WHERE cc.id = v_current
      AND cc.tenant_id = p_tenant_id;

    v_current := v_next;
    v_depth := v_depth + 1;
  END LOOP;

  IF v_current IS NOT NULL THEN
    RETURN TRUE;
  END IF;

  RETURN FALSE;
END;
$$;

CREATE OR REPLACE FUNCTION puls_core.validate_cost_center_tenant()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM puls_core.legal_entities le
    WHERE le.id = NEW.legal_entity_id
      AND le.tenant_id = NEW.tenant_id
      AND le.is_active = TRUE
  ) THEN
    RAISE EXCEPTION 'PULS_COST_CENTER_INVALID_LEGAL_ENTITY: legal entity missing, inactive, or cross-tenant.';
  END IF;

  IF NEW.parent_cost_center_id IS NOT NULL THEN
    IF NEW.parent_cost_center_id = NEW.id THEN
      RAISE EXCEPTION 'PULS_COST_CENTER_INVALID_PARENT: cost center cannot be its own parent.';
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM puls_core.cost_centers cc
      WHERE cc.id = NEW.parent_cost_center_id
        AND cc.tenant_id = NEW.tenant_id
        AND cc.is_active = TRUE
    ) THEN
      RAISE EXCEPTION 'PULS_COST_CENTER_INVALID_PARENT: parent missing, inactive, or cross-tenant.';
    END IF;

    IF puls_core.detect_cost_center_cycle(NEW.tenant_id, NEW.id, NEW.parent_cost_center_id) THEN
      RAISE EXCEPTION 'PULS_COST_CENTER_CYCLE: parent assignment would create a cycle or exceed max depth.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS puls_core_legal_entities_validate_namespace ON puls_core.legal_entities;
CREATE TRIGGER puls_core_legal_entities_validate_namespace
  BEFORE INSERT OR UPDATE ON puls_core.legal_entities
  FOR EACH ROW EXECUTE FUNCTION puls_core.validate_enterprise_dimension_namespace();

DROP TRIGGER IF EXISTS puls_core_locations_validate ON puls_core.locations;
CREATE TRIGGER puls_core_locations_validate
  BEFORE INSERT OR UPDATE ON puls_core.locations
  FOR EACH ROW EXECUTE FUNCTION puls_core.validate_enterprise_dimension_namespace();

DROP TRIGGER IF EXISTS puls_core_locations_validate_tenant ON puls_core.locations;
CREATE TRIGGER puls_core_locations_validate_tenant
  BEFORE INSERT OR UPDATE ON puls_core.locations
  FOR EACH ROW EXECUTE FUNCTION puls_core.validate_location_tenant();

DROP TRIGGER IF EXISTS puls_core_cost_centers_validate ON puls_core.cost_centers;
CREATE TRIGGER puls_core_cost_centers_validate
  BEFORE INSERT OR UPDATE ON puls_core.cost_centers
  FOR EACH ROW EXECUTE FUNCTION puls_core.validate_enterprise_dimension_namespace();

DROP TRIGGER IF EXISTS puls_core_cost_centers_validate_tenant ON puls_core.cost_centers;
CREATE TRIGGER puls_core_cost_centers_validate_tenant
  BEFORE INSERT OR UPDATE ON puls_core.cost_centers
  FOR EACH ROW EXECUTE FUNCTION puls_core.validate_cost_center_tenant();

-- ---------------------------------------------------------------------------
-- Assignment tenant validation
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_core.validate_employee_legal_entity_assignment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_core, puls_integration
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM puls_core.employees e
    WHERE e.id = NEW.employee_id
      AND e.tenant_id = NEW.tenant_id
      AND e.employment_status = 'active'
  ) THEN
    RAISE EXCEPTION 'PULS_ASSIGNMENT_INVALID_EMPLOYEE: employee missing, inactive, or cross-tenant.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM puls_core.legal_entities le
    WHERE le.id = NEW.legal_entity_id
      AND le.tenant_id = NEW.tenant_id
      AND le.is_active = TRUE
  ) THEN
    RAISE EXCEPTION 'PULS_ASSIGNMENT_INVALID_LEGAL_ENTITY: legal entity missing, inactive, or cross-tenant.';
  END IF;

  IF NEW.source_namespace_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM puls_integration.source_namespaces sn
      WHERE sn.id = NEW.source_namespace_id
        AND sn.tenant_id = NEW.tenant_id
        AND sn.is_active = TRUE
    ) THEN
      RAISE EXCEPTION 'PULS_ASSIGNMENT_INVALID_NAMESPACE: source namespace missing, inactive, or cross-tenant.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION puls_core.validate_employee_location_assignment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_core, puls_integration
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM puls_core.employees e
    WHERE e.id = NEW.employee_id
      AND e.tenant_id = NEW.tenant_id
      AND e.employment_status = 'active'
  ) THEN
    RAISE EXCEPTION 'PULS_ASSIGNMENT_INVALID_EMPLOYEE: employee missing, inactive, or cross-tenant.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM puls_core.locations loc
    WHERE loc.id = NEW.location_id
      AND loc.tenant_id = NEW.tenant_id
      AND loc.is_active = TRUE
  ) THEN
    RAISE EXCEPTION 'PULS_ASSIGNMENT_INVALID_LOCATION: location missing, inactive, or cross-tenant.';
  END IF;

  IF NEW.source_namespace_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM puls_integration.source_namespaces sn
      WHERE sn.id = NEW.source_namespace_id
        AND sn.tenant_id = NEW.tenant_id
        AND sn.is_active = TRUE
    ) THEN
      RAISE EXCEPTION 'PULS_ASSIGNMENT_INVALID_NAMESPACE: source namespace missing, inactive, or cross-tenant.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION puls_core.validate_employee_cost_center_assignment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_core, puls_integration
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM puls_core.employees e
    WHERE e.id = NEW.employee_id
      AND e.tenant_id = NEW.tenant_id
      AND e.employment_status = 'active'
  ) THEN
    RAISE EXCEPTION 'PULS_ASSIGNMENT_INVALID_EMPLOYEE: employee missing, inactive, or cross-tenant.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM puls_core.cost_centers cc
    WHERE cc.id = NEW.cost_center_id
      AND cc.tenant_id = NEW.tenant_id
      AND cc.is_active = TRUE
  ) THEN
    RAISE EXCEPTION 'PULS_ASSIGNMENT_INVALID_COST_CENTER: cost center missing, inactive, or cross-tenant.';
  END IF;

  IF NEW.source_namespace_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM puls_integration.source_namespaces sn
      WHERE sn.id = NEW.source_namespace_id
        AND sn.tenant_id = NEW.tenant_id
        AND sn.is_active = TRUE
    ) THEN
      RAISE EXCEPTION 'PULS_ASSIGNMENT_INVALID_NAMESPACE: source namespace missing, inactive, or cross-tenant.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS puls_core_emp_le_assign_validate ON puls_core.employee_legal_entity_assignments;
CREATE TRIGGER puls_core_emp_le_assign_validate
  BEFORE INSERT OR UPDATE ON puls_core.employee_legal_entity_assignments
  FOR EACH ROW EXECUTE FUNCTION puls_core.validate_employee_legal_entity_assignment();

DROP TRIGGER IF EXISTS puls_core_emp_loc_assign_validate ON puls_core.employee_location_assignments;
CREATE TRIGGER puls_core_emp_loc_assign_validate
  BEFORE INSERT OR UPDATE ON puls_core.employee_location_assignments
  FOR EACH ROW EXECUTE FUNCTION puls_core.validate_employee_location_assignment();

DROP TRIGGER IF EXISTS puls_core_emp_cc_assign_validate ON puls_core.employee_cost_center_assignments;
CREATE TRIGGER puls_core_emp_cc_assign_validate
  BEFORE INSERT OR UPDATE ON puls_core.employee_cost_center_assignments
  FOR EACH ROW EXECUTE FUNCTION puls_core.validate_employee_cost_center_assignment();

-- ---------------------------------------------------------------------------
-- Department cost_center_id tenant validation
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_core.validate_department_cost_center()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
BEGIN
  IF NEW.cost_center_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM puls_core.cost_centers cc
    WHERE cc.id = NEW.cost_center_id
      AND cc.tenant_id = NEW.tenant_id
      AND cc.is_active = TRUE
  ) THEN
    RAISE EXCEPTION 'PULS_DEPARTMENT_INVALID_COST_CENTER: cost center missing, inactive, or cross-tenant.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS puls_core_departments_validate_cost_center ON puls_core.departments;
CREATE TRIGGER puls_core_departments_validate_cost_center
  BEFORE INSERT OR UPDATE OF cost_center_id ON puls_core.departments
  FOR EACH ROW EXECUTE FUNCTION puls_core.validate_department_cost_center();

-- ---------------------------------------------------------------------------
-- Cache sync from assignments (INSERT/UPDATE/DELETE)
-- Tie-break: starts_on DESC, updated_at DESC, id ASC
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_core.sync_employee_legal_entity_from_assignments()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
DECLARE
  v_employee_id UUID;
  v_tenant_id UUID;
  v_legal_entity_id UUID;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_employee_id := OLD.employee_id;
    v_tenant_id := OLD.tenant_id;
  ELSE
    v_employee_id := NEW.employee_id;
    v_tenant_id := NEW.tenant_id;
  END IF;

  SELECT a.legal_entity_id
  INTO v_legal_entity_id
  FROM puls_core.employee_legal_entity_assignments a
  WHERE a.tenant_id = v_tenant_id
    AND a.employee_id = v_employee_id
    AND a.is_active = TRUE
  ORDER BY a.starts_on DESC, a.updated_at DESC, a.id ASC
  LIMIT 1;

  UPDATE puls_core.employees e
  SET legal_entity_id = v_legal_entity_id,
      updated_at = NOW()
  WHERE e.id = v_employee_id
    AND e.tenant_id = v_tenant_id
    AND e.legal_entity_id IS DISTINCT FROM v_legal_entity_id;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION puls_core.sync_employee_location_from_assignments()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
DECLARE
  v_employee_id UUID;
  v_tenant_id UUID;
  v_location_id UUID;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_employee_id := OLD.employee_id;
    v_tenant_id := OLD.tenant_id;
  ELSE
    v_employee_id := NEW.employee_id;
    v_tenant_id := NEW.tenant_id;
  END IF;

  SELECT a.location_id
  INTO v_location_id
  FROM puls_core.employee_location_assignments a
  WHERE a.tenant_id = v_tenant_id
    AND a.employee_id = v_employee_id
    AND a.is_active = TRUE
  ORDER BY a.starts_on DESC, a.updated_at DESC, a.id ASC
  LIMIT 1;

  UPDATE puls_core.employees e
  SET location_id = v_location_id,
      updated_at = NOW()
  WHERE e.id = v_employee_id
    AND e.tenant_id = v_tenant_id
    AND e.location_id IS DISTINCT FROM v_location_id;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION puls_core.sync_employee_cost_center_from_assignments()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
DECLARE
  v_employee_id UUID;
  v_tenant_id UUID;
  v_cost_center_id UUID;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_employee_id := OLD.employee_id;
    v_tenant_id := OLD.tenant_id;
  ELSE
    v_employee_id := NEW.employee_id;
    v_tenant_id := NEW.tenant_id;
  END IF;

  SELECT a.cost_center_id
  INTO v_cost_center_id
  FROM puls_core.employee_cost_center_assignments a
  WHERE a.tenant_id = v_tenant_id
    AND a.employee_id = v_employee_id
    AND a.is_active = TRUE
  ORDER BY a.starts_on DESC, a.updated_at DESC, a.id ASC
  LIMIT 1;

  UPDATE puls_core.employees e
  SET cost_center_id = v_cost_center_id,
      updated_at = NOW()
  WHERE e.id = v_employee_id
    AND e.tenant_id = v_tenant_id
    AND e.cost_center_id IS DISTINCT FROM v_cost_center_id;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS puls_core_emp_le_assign_sync_cache ON puls_core.employee_legal_entity_assignments;
CREATE TRIGGER puls_core_emp_le_assign_sync_cache
  AFTER INSERT OR UPDATE OR DELETE ON puls_core.employee_legal_entity_assignments
  FOR EACH ROW EXECUTE FUNCTION puls_core.sync_employee_legal_entity_from_assignments();

DROP TRIGGER IF EXISTS puls_core_emp_loc_assign_sync_cache ON puls_core.employee_location_assignments;
CREATE TRIGGER puls_core_emp_loc_assign_sync_cache
  AFTER INSERT OR UPDATE OR DELETE ON puls_core.employee_location_assignments
  FOR EACH ROW EXECUTE FUNCTION puls_core.sync_employee_location_from_assignments();

DROP TRIGGER IF EXISTS puls_core_emp_cc_assign_sync_cache ON puls_core.employee_cost_center_assignments;
CREATE TRIGGER puls_core_emp_cc_assign_sync_cache
  AFTER INSERT OR UPDATE OR DELETE ON puls_core.employee_cost_center_assignments
  FOR EACH ROW EXECUTE FUNCTION puls_core.sync_employee_cost_center_from_assignments();

-- ---------------------------------------------------------------------------
-- Employee cache guard — prevent direct cache bypass of assignment SoT
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_core.validate_employee_dimension_cache()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
DECLARE
  v_expected_le UUID;
  v_expected_loc UUID;
  v_expected_cc UUID;
BEGIN
  IF NEW.legal_entity_id IS DISTINCT FROM OLD.legal_entity_id THEN
    SELECT a.legal_entity_id
    INTO v_expected_le
    FROM puls_core.employee_legal_entity_assignments a
    WHERE a.tenant_id = NEW.tenant_id
      AND a.employee_id = NEW.id
      AND a.is_active = TRUE
    ORDER BY a.starts_on DESC, a.updated_at DESC, a.id ASC
    LIMIT 1;

    IF NEW.legal_entity_id IS DISTINCT FROM v_expected_le THEN
      RAISE EXCEPTION 'PULS_EMPLOYEE_CACHE_BYPASS: legal_entity_id must match active assignment cache or NULL when none exists.';
    END IF;
  END IF;

  IF NEW.location_id IS DISTINCT FROM OLD.location_id THEN
    SELECT a.location_id
    INTO v_expected_loc
    FROM puls_core.employee_location_assignments a
    WHERE a.tenant_id = NEW.tenant_id
      AND a.employee_id = NEW.id
      AND a.is_active = TRUE
    ORDER BY a.starts_on DESC, a.updated_at DESC, a.id ASC
    LIMIT 1;

    IF NEW.location_id IS DISTINCT FROM v_expected_loc THEN
      RAISE EXCEPTION 'PULS_EMPLOYEE_CACHE_BYPASS: location_id must match active assignment cache or NULL when none exists.';
    END IF;
  END IF;

  IF NEW.cost_center_id IS DISTINCT FROM OLD.cost_center_id THEN
    SELECT a.cost_center_id
    INTO v_expected_cc
    FROM puls_core.employee_cost_center_assignments a
    WHERE a.tenant_id = NEW.tenant_id
      AND a.employee_id = NEW.id
      AND a.is_active = TRUE
    ORDER BY a.starts_on DESC, a.updated_at DESC, a.id ASC
    LIMIT 1;

    IF NEW.cost_center_id IS DISTINCT FROM v_expected_cc THEN
      RAISE EXCEPTION 'PULS_EMPLOYEE_CACHE_BYPASS: cost_center_id must match active assignment cache or NULL when none exists.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS puls_core_employees_validate_dimension_cache ON puls_core.employees;
CREATE TRIGGER puls_core_employees_validate_dimension_cache
  BEFORE UPDATE OF legal_entity_id, location_id, cost_center_id ON puls_core.employees
  FOR EACH ROW EXECUTE FUNCTION puls_core.validate_employee_dimension_cache();

-- ---------------------------------------------------------------------------
-- Identity map allowlist expansion (PR2)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_integration.is_identity_map_target_allowed(
  p_schema TEXT,
  p_table TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog
AS $$
  SELECT
    p_schema = 'puls_core'
    AND p_table IN (
      'employees',
      'departments',
      'positions',
      'legal_entities',
      'locations',
      'cost_centers'
    );
$$;

CREATE OR REPLACE FUNCTION puls_integration.validate_entity_identity_map_tenant()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_exists BOOLEAN := FALSE;
  v_expected_table TEXT;
BEGIN
  NEW.external_id := puls_integration.normalize_import_external_id(NEW.external_id);

  IF NOT puls_integration.is_identity_map_target_allowed(NEW.canonical_schema, NEW.canonical_table) THEN
    RAISE EXCEPTION 'PULS_IDENTITY_MAP_TARGET_NOT_ALLOWED: %.% is not in the allowlist.', NEW.canonical_schema, NEW.canonical_table;
  END IF;

  v_expected_table := CASE NEW.entity_type::TEXT
    WHEN 'employee' THEN 'employees'
    WHEN 'department' THEN 'departments'
    WHEN 'position' THEN 'positions'
    WHEN 'legal_entity' THEN 'legal_entities'
    WHEN 'location' THEN 'locations'
    WHEN 'cost_center' THEN 'cost_centers'
    ELSE NULL
  END;

  IF v_expected_table IS NULL OR NEW.canonical_table <> v_expected_table THEN
    RAISE EXCEPTION 'PULS_IDENTITY_MAP_TYPE_MISMATCH: entity_type % does not match canonical_table %.', NEW.entity_type::TEXT, NEW.canonical_table;
  END IF;

  IF NEW.canonical_schema = 'puls_core' AND NEW.canonical_table = 'employees' THEN
    SELECT EXISTS (
      SELECT 1 FROM puls_core.employees e
      WHERE e.id = NEW.canonical_id AND e.tenant_id = NEW.tenant_id AND e.employment_status = 'active'
    ) INTO v_exists;
  ELSIF NEW.canonical_schema = 'puls_core' AND NEW.canonical_table = 'departments' THEN
    SELECT EXISTS (
      SELECT 1 FROM puls_core.departments d
      WHERE d.id = NEW.canonical_id AND d.tenant_id = NEW.tenant_id AND d.is_active = TRUE
    ) INTO v_exists;
  ELSIF NEW.canonical_schema = 'puls_core' AND NEW.canonical_table = 'positions' THEN
    SELECT EXISTS (
      SELECT 1 FROM puls_core.positions p
      WHERE p.id = NEW.canonical_id AND p.tenant_id = NEW.tenant_id AND p.is_active = TRUE
    ) INTO v_exists;
  ELSIF NEW.canonical_schema = 'puls_core' AND NEW.canonical_table = 'legal_entities' THEN
    SELECT EXISTS (
      SELECT 1 FROM puls_core.legal_entities le
      WHERE le.id = NEW.canonical_id AND le.tenant_id = NEW.tenant_id AND le.is_active = TRUE
    ) INTO v_exists;
  ELSIF NEW.canonical_schema = 'puls_core' AND NEW.canonical_table = 'locations' THEN
    SELECT EXISTS (
      SELECT 1 FROM puls_core.locations loc
      WHERE loc.id = NEW.canonical_id AND loc.tenant_id = NEW.tenant_id AND loc.is_active = TRUE
    ) INTO v_exists;
  ELSIF NEW.canonical_schema = 'puls_core' AND NEW.canonical_table = 'cost_centers' THEN
    SELECT EXISTS (
      SELECT 1 FROM puls_core.cost_centers cc
      WHERE cc.id = NEW.canonical_id AND cc.tenant_id = NEW.tenant_id AND cc.is_active = TRUE
    ) INTO v_exists;
  END IF;

  IF NOT v_exists THEN
    RAISE EXCEPTION 'PULS_IDENTITY_MAP_INVALID_TARGET: canonical target not found, inactive, or cross-tenant.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM puls_integration.source_namespaces sn
    WHERE sn.id = NEW.source_namespace_id
      AND sn.tenant_id = NEW.tenant_id
      AND sn.is_active = TRUE
  ) THEN
    RAISE EXCEPTION 'PULS_IDENTITY_MAP_INVALID_NAMESPACE: source namespace missing, inactive, or cross-tenant.';
  END IF;

  RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

ALTER TABLE puls_core.legal_entities ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_core.locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_core.cost_centers ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_core.employee_legal_entity_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_core.employee_location_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_core.employee_cost_center_assignments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS puls_core_legal_entities_select ON puls_core.legal_entities;
CREATE POLICY puls_core_legal_entities_select ON puls_core.legal_entities
  FOR SELECT TO authenticated
  USING (tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_core_legal_entities_insert ON puls_core.legal_entities;
CREATE POLICY puls_core_legal_entities_insert ON puls_core.legal_entities
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_core_legal_entities_update ON puls_core.legal_entities;
CREATE POLICY puls_core_legal_entities_update ON puls_core.legal_entities
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_core_locations_select ON puls_core.locations;
CREATE POLICY puls_core_locations_select ON puls_core.locations
  FOR SELECT TO authenticated
  USING (tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_core_locations_insert ON puls_core.locations;
CREATE POLICY puls_core_locations_insert ON puls_core.locations
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_core_locations_update ON puls_core.locations;
CREATE POLICY puls_core_locations_update ON puls_core.locations
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_core_cost_centers_select ON puls_core.cost_centers;
CREATE POLICY puls_core_cost_centers_select ON puls_core.cost_centers
  FOR SELECT TO authenticated
  USING (tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_core_cost_centers_insert ON puls_core.cost_centers;
CREATE POLICY puls_core_cost_centers_insert ON puls_core.cost_centers
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_core_cost_centers_update ON puls_core.cost_centers;
CREATE POLICY puls_core_cost_centers_update ON puls_core.cost_centers
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_core_emp_le_assign_select ON puls_core.employee_legal_entity_assignments;
CREATE POLICY puls_core_emp_le_assign_select ON puls_core.employee_legal_entity_assignments
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND puls_core.can_read_employee(employee_id)
  );

DROP POLICY IF EXISTS puls_core_emp_le_assign_insert ON puls_core.employee_legal_entity_assignments;
CREATE POLICY puls_core_emp_le_assign_insert ON puls_core.employee_legal_entity_assignments
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_core_emp_le_assign_update ON puls_core.employee_legal_entity_assignments;
CREATE POLICY puls_core_emp_le_assign_update ON puls_core.employee_legal_entity_assignments
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_core_emp_loc_assign_select ON puls_core.employee_location_assignments;
CREATE POLICY puls_core_emp_loc_assign_select ON puls_core.employee_location_assignments
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND puls_core.can_read_employee(employee_id)
  );

DROP POLICY IF EXISTS puls_core_emp_loc_assign_insert ON puls_core.employee_location_assignments;
CREATE POLICY puls_core_emp_loc_assign_insert ON puls_core.employee_location_assignments
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_core_emp_loc_assign_update ON puls_core.employee_location_assignments;
CREATE POLICY puls_core_emp_loc_assign_update ON puls_core.employee_location_assignments
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_core_emp_cc_assign_select ON puls_core.employee_cost_center_assignments;
CREATE POLICY puls_core_emp_cc_assign_select ON puls_core.employee_cost_center_assignments
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND puls_core.can_read_employee(employee_id)
  );

DROP POLICY IF EXISTS puls_core_emp_cc_assign_insert ON puls_core.employee_cost_center_assignments;
CREATE POLICY puls_core_emp_cc_assign_insert ON puls_core.employee_cost_center_assignments
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_core_emp_cc_assign_update ON puls_core.employee_cost_center_assignments;
CREATE POLICY puls_core_emp_cc_assign_update ON puls_core.employee_cost_center_assignments
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

GRANT SELECT, INSERT, UPDATE ON puls_core.legal_entities TO authenticated;
GRANT SELECT, INSERT, UPDATE ON puls_core.locations TO authenticated;
GRANT SELECT, INSERT, UPDATE ON puls_core.cost_centers TO authenticated;
GRANT SELECT, INSERT, UPDATE ON puls_core.employee_legal_entity_assignments TO authenticated;
GRANT SELECT, INSERT, UPDATE ON puls_core.employee_location_assignments TO authenticated;
GRANT SELECT, INSERT, UPDATE ON puls_core.employee_cost_center_assignments TO authenticated;

GRANT ALL ON puls_core.legal_entities TO service_role;
GRANT ALL ON puls_core.locations TO service_role;
GRANT ALL ON puls_core.cost_centers TO service_role;
GRANT ALL ON puls_core.employee_legal_entity_assignments TO service_role;
GRANT ALL ON puls_core.employee_location_assignments TO service_role;
GRANT ALL ON puls_core.employee_cost_center_assignments TO service_role;

-- Function execute surface
REVOKE ALL ON FUNCTION puls_core.validate_enterprise_dimension_namespace() FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_core.validate_location_tenant() FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_core.detect_cost_center_cycle(UUID, UUID, UUID) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_core.validate_cost_center_tenant() FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_core.validate_employee_legal_entity_assignment() FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_core.validate_employee_location_assignment() FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_core.validate_employee_cost_center_assignment() FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_core.validate_department_cost_center() FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_core.validate_employee_dimension_cache() FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_core.sync_employee_legal_entity_from_assignments() FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_core.sync_employee_location_from_assignments() FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_core.sync_employee_cost_center_from_assignments() FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.is_identity_map_target_allowed(TEXT, TEXT) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.validate_entity_identity_map_tenant() FROM PUBLIC, authenticated, anon;

GRANT EXECUTE ON FUNCTION puls_core.sync_employee_legal_entity_from_assignments() TO service_role;
GRANT EXECUTE ON FUNCTION puls_core.sync_employee_location_from_assignments() TO service_role;
GRANT EXECUTE ON FUNCTION puls_core.sync_employee_cost_center_from_assignments() TO service_role;
