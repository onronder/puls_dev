-- 07 PR1 — employee_reporting_lines source of truth + validation/sync triggers + backfill

DO $$ BEGIN
  CREATE TYPE puls_core.reporting_relationship_type AS ENUM (
    'primary_manager',
    'dotted_line',
    'acting_manager',
    'approval_delegate'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS puls_core.employee_reporting_lines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  employee_id UUID NOT NULL REFERENCES puls_core.employees(id) ON DELETE CASCADE,
  manager_employee_id UUID NOT NULL REFERENCES puls_core.employees(id) ON DELETE CASCADE,
  relationship_type puls_core.reporting_relationship_type NOT NULL DEFAULT 'primary_manager',
  starts_on DATE NOT NULL DEFAULT CURRENT_DATE,
  ends_on DATE NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  source TEXT NOT NULL DEFAULT 'manual',
  external_source TEXT NULL,
  external_id TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (employee_id <> manager_employee_id),
  CHECK (ends_on IS NULL OR ends_on >= starts_on),
  CHECK (source IN ('manual', 'erp', 'bootstrap', 'demo'))
);

CREATE INDEX IF NOT EXISTS idx_puls_core_reporting_lines_tenant_employee_active
  ON puls_core.employee_reporting_lines (tenant_id, employee_id, relationship_type)
  WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_puls_core_reporting_lines_tenant_manager_active
  ON puls_core.employee_reporting_lines (tenant_id, manager_employee_id)
  WHERE is_active = TRUE;

CREATE UNIQUE INDEX IF NOT EXISTS idx_puls_core_reporting_lines_one_active_primary
  ON puls_core.employee_reporting_lines (tenant_id, employee_id)
  WHERE is_active = TRUE AND relationship_type = 'primary_manager'::puls_core.reporting_relationship_type;

DROP TRIGGER IF EXISTS puls_core_reporting_lines_set_updated_at ON puls_core.employee_reporting_lines;
CREATE TRIGGER puls_core_reporting_lines_set_updated_at
  BEFORE UPDATE ON puls_core.employee_reporting_lines
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

-- ---------------------------------------------------------------------------
-- Cycle detection (returns TRUE when a cycle would be created)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_core.detect_reporting_cycle(
  p_tenant_id UUID,
  p_employee_id UUID,
  p_manager_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
DECLARE
  v_current UUID := p_manager_id;
  v_depth INTEGER := 0;
  v_visited UUID[] := ARRAY[]::UUID[];
  v_next UUID;
BEGIN
  IF p_employee_id = p_manager_id THEN
    RETURN TRUE;
  END IF;

  WHILE v_current IS NOT NULL AND v_depth < 20 LOOP
    IF v_current = p_employee_id THEN
      RETURN TRUE;
    END IF;

    IF v_current = ANY(v_visited) THEN
      RETURN TRUE;
    END IF;

    v_visited := v_visited || v_current;

    SELECT rl.manager_employee_id
    INTO v_next
    FROM puls_core.employee_reporting_lines rl
    WHERE rl.tenant_id = p_tenant_id
      AND rl.employee_id = v_current
      AND rl.is_active = TRUE
      AND rl.relationship_type = 'primary_manager'::puls_core.reporting_relationship_type
    LIMIT 1;

    IF v_next IS NULL THEN
      SELECT e.manager_employee_id
      INTO v_next
      FROM puls_core.employees e
      WHERE e.id = v_current
        AND e.tenant_id = p_tenant_id;
    END IF;

    v_current := v_next;
    v_depth := v_depth + 1;
  END LOOP;

  RETURN FALSE;
END;
$$;

REVOKE ALL ON FUNCTION puls_core.detect_reporting_cycle(UUID, UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION puls_core.detect_reporting_cycle(UUID, UUID, UUID) FROM anon;
REVOKE ALL ON FUNCTION puls_core.detect_reporting_cycle(UUID, UUID, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION puls_core.detect_reporting_cycle(UUID, UUID, UUID) TO service_role;

-- ---------------------------------------------------------------------------
-- BEFORE trigger validation
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_core.validate_reporting_line_tenant()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
DECLARE
  v_employee_tenant UUID;
  v_manager_tenant UUID;
BEGIN
  SELECT e.tenant_id INTO v_employee_tenant
  FROM puls_core.employees e
  WHERE e.id = NEW.employee_id;

  IF v_employee_tenant IS NULL OR v_employee_tenant <> NEW.tenant_id THEN
    RAISE EXCEPTION 'PULS_REPORTING_LINE_TENANT: employee_id does not belong to tenant_id'
      USING ERRCODE = '23514';
  END IF;

  SELECT e.tenant_id INTO v_manager_tenant
  FROM puls_core.employees e
  WHERE e.id = NEW.manager_employee_id;

  IF v_manager_tenant IS NULL OR v_manager_tenant <> NEW.tenant_id THEN
    RAISE EXCEPTION 'PULS_REPORTING_LINE_TENANT: manager_employee_id does not belong to tenant_id'
      USING ERRCODE = '23514';
  END IF;

  IF NEW.employee_id = NEW.manager_employee_id THEN
    RAISE EXCEPTION 'PULS_REPORTING_LINE_SELF: employee cannot report to self'
      USING ERRCODE = '23514';
  END IF;

  IF NEW.is_active
     AND NEW.relationship_type = 'primary_manager'::puls_core.reporting_relationship_type
     AND puls_core.detect_reporting_cycle(NEW.tenant_id, NEW.employee_id, NEW.manager_employee_id) THEN
    RAISE EXCEPTION 'PULS_REPORTING_LINE_CYCLE: active primary manager would create a cycle'
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION puls_core.validate_reporting_line_tenant() FROM PUBLIC;
REVOKE ALL ON FUNCTION puls_core.validate_reporting_line_tenant() FROM anon;
REVOKE ALL ON FUNCTION puls_core.validate_reporting_line_tenant() FROM authenticated;
GRANT EXECUTE ON FUNCTION puls_core.validate_reporting_line_tenant() TO service_role;

DROP TRIGGER IF EXISTS puls_core_reporting_lines_validate ON puls_core.employee_reporting_lines;
CREATE TRIGGER puls_core_reporting_lines_validate
  BEFORE INSERT OR UPDATE ON puls_core.employee_reporting_lines
  FOR EACH ROW EXECUTE FUNCTION puls_core.validate_reporting_line_tenant();

-- ---------------------------------------------------------------------------
-- AFTER sync trigger — employees.manager_employee_id cache
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_core.sync_employee_manager_from_reporting_lines()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
DECLARE
  v_employee_id UUID;
  v_tenant_id UUID;
  v_manager_id UUID;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_employee_id := OLD.employee_id;
    v_tenant_id := OLD.tenant_id;
  ELSE
    v_employee_id := NEW.employee_id;
    v_tenant_id := NEW.tenant_id;
  END IF;

  SELECT rl.manager_employee_id
  INTO v_manager_id
  FROM puls_core.employee_reporting_lines rl
  WHERE rl.tenant_id = v_tenant_id
    AND rl.employee_id = v_employee_id
    AND rl.is_active = TRUE
    AND rl.relationship_type = 'primary_manager'::puls_core.reporting_relationship_type
  ORDER BY rl.starts_on DESC, rl.created_at DESC
  LIMIT 1;

  UPDATE puls_core.employees e
  SET manager_employee_id = v_manager_id,
      updated_at = NOW()
  WHERE e.id = v_employee_id
    AND e.tenant_id = v_tenant_id
    AND e.manager_employee_id IS DISTINCT FROM v_manager_id;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION puls_core.sync_employee_manager_from_reporting_lines() FROM PUBLIC;
REVOKE ALL ON FUNCTION puls_core.sync_employee_manager_from_reporting_lines() FROM anon;
REVOKE ALL ON FUNCTION puls_core.sync_employee_manager_from_reporting_lines() FROM authenticated;
GRANT EXECUTE ON FUNCTION puls_core.sync_employee_manager_from_reporting_lines() TO service_role;

DROP TRIGGER IF EXISTS puls_core_reporting_lines_sync_manager ON puls_core.employee_reporting_lines;
CREATE TRIGGER puls_core_reporting_lines_sync_manager
  AFTER INSERT OR UPDATE OR DELETE ON puls_core.employee_reporting_lines
  FOR EACH ROW EXECUTE FUNCTION puls_core.sync_employee_manager_from_reporting_lines();

-- ---------------------------------------------------------------------------
-- Idempotent upsert (service_role; source priority)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_core.upsert_primary_reporting_line(
  p_tenant_id UUID,
  p_employee_id UUID,
  p_manager_id UUID,
  p_source TEXT,
  p_external_source TEXT DEFAULT NULL,
  p_external_id TEXT DEFAULT NULL,
  p_starts_on DATE DEFAULT CURRENT_DATE
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
DECLARE
  v_existing_source TEXT;
  v_source_rank INTEGER;
  v_existing_rank INTEGER;
  v_line_id UUID;
BEGIN
  IF p_source NOT IN ('manual', 'erp', 'bootstrap', 'demo') THEN
    RAISE EXCEPTION 'PULS_REPORTING_LINE_SOURCE: invalid source %', p_source
      USING ERRCODE = '23514';
  END IF;

  v_source_rank := CASE p_source
    WHEN 'manual' THEN 4
    WHEN 'erp' THEN 3
    WHEN 'bootstrap' THEN 2
    WHEN 'demo' THEN 1
    ELSE 0
  END;

  SELECT rl.source, rl.id
  INTO v_existing_source, v_line_id
  FROM puls_core.employee_reporting_lines rl
  WHERE rl.tenant_id = p_tenant_id
    AND rl.employee_id = p_employee_id
    AND rl.is_active = TRUE
    AND rl.relationship_type = 'primary_manager'::puls_core.reporting_relationship_type
  LIMIT 1;

  IF v_existing_source IS NOT NULL THEN
    v_existing_rank := CASE v_existing_source
      WHEN 'manual' THEN 4
      WHEN 'erp' THEN 3
      WHEN 'bootstrap' THEN 2
      WHEN 'demo' THEN 1
      ELSE 0
    END;

    IF v_source_rank < v_existing_rank THEN
      RETURN v_line_id;
    END IF;

    IF v_existing_source = p_source
       AND EXISTS (
         SELECT 1
         FROM puls_core.employee_reporting_lines rl
         WHERE rl.id = v_line_id
           AND rl.manager_employee_id = p_manager_id
       ) THEN
      RETURN v_line_id;
    END IF;

    UPDATE puls_core.employee_reporting_lines rl
    SET is_active = FALSE,
        ends_on = COALESCE(rl.ends_on, CURRENT_DATE),
        updated_at = NOW()
    WHERE rl.id = v_line_id;
  END IF;

  IF puls_core.detect_reporting_cycle(p_tenant_id, p_employee_id, p_manager_id) THEN
    RAISE EXCEPTION 'PULS_REPORTING_LINE_CYCLE: upsert would create a cycle'
      USING ERRCODE = '23514';
  END IF;

  INSERT INTO puls_core.employee_reporting_lines (
    tenant_id,
    employee_id,
    manager_employee_id,
    relationship_type,
    starts_on,
    is_active,
    source,
    external_source,
    external_id
  )
  VALUES (
    p_tenant_id,
    p_employee_id,
    p_manager_id,
    'primary_manager'::puls_core.reporting_relationship_type,
    COALESCE(p_starts_on, CURRENT_DATE),
    TRUE,
    p_source,
    p_external_source,
    p_external_id
  )
  RETURNING id INTO v_line_id;

  RETURN v_line_id;
END;
$$;

REVOKE ALL ON FUNCTION puls_core.upsert_primary_reporting_line(UUID, UUID, UUID, TEXT, TEXT, TEXT, DATE) FROM PUBLIC;
REVOKE ALL ON FUNCTION puls_core.upsert_primary_reporting_line(UUID, UUID, UUID, TEXT, TEXT, TEXT, DATE) FROM anon;
REVOKE ALL ON FUNCTION puls_core.upsert_primary_reporting_line(UUID, UUID, UUID, TEXT, TEXT, TEXT, DATE) FROM authenticated;
GRANT EXECUTE ON FUNCTION puls_core.upsert_primary_reporting_line(UUID, UUID, UUID, TEXT, TEXT, TEXT, DATE) TO service_role;

-- ---------------------------------------------------------------------------
-- RLS (admin-only until PR2 expands SELECT via can_read_employee)
-- ---------------------------------------------------------------------------

ALTER TABLE puls_core.employee_reporting_lines ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS puls_core_reporting_lines_select ON puls_core.employee_reporting_lines;
CREATE POLICY puls_core_reporting_lines_select ON puls_core.employee_reporting_lines
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND puls_core.is_admin()
  );

DROP POLICY IF EXISTS puls_core_reporting_lines_insert ON puls_core.employee_reporting_lines;
CREATE POLICY puls_core_reporting_lines_insert ON puls_core.employee_reporting_lines
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_core_reporting_lines_update ON puls_core.employee_reporting_lines;
CREATE POLICY puls_core_reporting_lines_update ON puls_core.employee_reporting_lines
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

GRANT SELECT, INSERT, UPDATE ON puls_core.employee_reporting_lines TO authenticated;

-- ---------------------------------------------------------------------------
-- Bootstrap pass 3 — department/position hierarchy from public
-- ---------------------------------------------------------------------------

UPDATE puls_core.departments pd
SET parent_id = parent_dept.id
FROM public.departments pub
JOIN puls_core.departments parent_dept
  ON parent_dept.legacy_public_department_id = pub.parent_id
WHERE pd.legacy_public_department_id = pub.id
  AND pub.parent_id IS NOT NULL
  AND pd.parent_id IS NULL;

UPDATE puls_core.positions pp
SET parent_position_id = parent_pos.id
FROM public.positions pub
JOIN puls_core.positions parent_pos
  ON parent_pos.legacy_public_position_id = pub.parent_position_id
WHERE pp.legacy_public_position_id = pub.id
  AND pub.parent_position_id IS NOT NULL
  AND pp.parent_position_id IS NULL;

-- ---------------------------------------------------------------------------
-- Demo org — public GM + department managers (idempotent)
-- ---------------------------------------------------------------------------

INSERT INTO public.employees (
  anonymous_id,
  tenant_id,
  user_id,
  email,
  full_name,
  job_title,
  department_id,
  position_id,
  persona_role,
  hire_date
)
SELECT
  '44444444-4444-4444-4444-444444444402'::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid,
  NULL,
  'gm@mertteknik.demo',
  'Demo Genel Müdür',
  'Genel Müdür',
  '22222222-2222-2222-2222-222222222201'::uuid,
  '33333333-3333-3333-3333-333333333301'::uuid,
  'manager'::public.persona_role,
  '2010-01-15'::date
WHERE EXISTS (SELECT 1 FROM public.tenants WHERE id = '11111111-1111-1111-1111-111111111111'::uuid)
ON CONFLICT (anonymous_id) DO NOTHING;

UPDATE public.departments
SET manager_employee_id = '44444444-4444-4444-4444-444444444402'::uuid
WHERE id = '22222222-2222-2222-2222-222222222201'::uuid
  AND manager_employee_id IS DISTINCT FROM '44444444-4444-4444-4444-444444444402'::uuid;

UPDATE public.departments
SET manager_employee_id = '44444444-4444-4444-4444-444444444401'::uuid
WHERE id = '22222222-2222-2222-2222-222222222202'::uuid
  AND manager_employee_id IS DISTINCT FROM '44444444-4444-4444-4444-444444444401'::uuid;

UPDATE public.departments
SET manager_employee_id = '44444444-4444-4444-4444-444444444404'::uuid
WHERE id = '22222222-2222-2222-2222-222222222203'::uuid
  AND manager_employee_id IS DISTINCT FROM '44444444-4444-4444-4444-444444444404'::uuid;

INSERT INTO puls_core.employees (
  tenant_id,
  legacy_public_employee_id,
  user_id,
  email,
  full_name,
  job_title,
  persona_role,
  hire_date
)
SELECT
  t.id,
  pe.anonymous_id,
  pe.user_id,
  pe.email,
  pe.full_name,
  pe.job_title,
  pe.persona_role::text::puls_core.persona_role,
  pe.hire_date
FROM public.employees pe
JOIN puls_core.tenants t ON t.legacy_public_tenant_id = pe.tenant_id
WHERE pe.anonymous_id = '44444444-4444-4444-4444-444444444402'::uuid
ON CONFLICT (legacy_public_employee_id) WHERE legacy_public_employee_id IS NOT NULL
DO UPDATE SET
  email = EXCLUDED.email,
  full_name = EXCLUDED.full_name,
  job_title = EXCLUDED.job_title,
  persona_role = EXCLUDED.persona_role,
  updated_at = NOW();

UPDATE puls_core.employees pe
SET
  department_id = pd.id,
  position_id = pp.id
FROM public.employees pub
LEFT JOIN puls_core.departments pd ON pd.legacy_public_department_id = pub.department_id
LEFT JOIN puls_core.positions pp ON pp.legacy_public_position_id = pub.position_id
WHERE pe.legacy_public_employee_id = pub.anonymous_id
  AND pub.anonymous_id = '44444444-4444-4444-4444-444444444402'::uuid;

UPDATE puls_core.departments pd
SET manager_employee_id = me.id
FROM public.departments pub
JOIN puls_core.employees me ON me.legacy_public_employee_id = pub.manager_employee_id
WHERE pd.legacy_public_department_id = pub.id
  AND pub.manager_employee_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- Backfill reporting lines from existing manager_employee_id
-- ---------------------------------------------------------------------------

INSERT INTO puls_core.employee_reporting_lines (
  tenant_id,
  employee_id,
  manager_employee_id,
  relationship_type,
  starts_on,
  is_active,
  source
)
SELECT
  e.tenant_id,
  e.id,
  e.manager_employee_id,
  'primary_manager'::puls_core.reporting_relationship_type,
  COALESCE(e.hire_date, CURRENT_DATE),
  TRUE,
  'bootstrap'
FROM puls_core.employees e
WHERE e.manager_employee_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM puls_core.employee_reporting_lines rl
    WHERE rl.tenant_id = e.tenant_id
      AND rl.employee_id = e.id
      AND rl.is_active = TRUE
      AND rl.relationship_type = 'primary_manager'::puls_core.reporting_relationship_type
  );

-- Infer employee managers from department managers where still missing
INSERT INTO puls_core.employee_reporting_lines (
  tenant_id,
  employee_id,
  manager_employee_id,
  relationship_type,
  starts_on,
  is_active,
  source
)
SELECT
  pe.tenant_id,
  pe.id,
  pd.manager_employee_id,
  'primary_manager'::puls_core.reporting_relationship_type,
  COALESCE(pe.hire_date, CURRENT_DATE),
  TRUE,
  'bootstrap'
FROM puls_core.employees pe
JOIN puls_core.departments pd ON pd.id = pe.department_id
WHERE pd.manager_employee_id IS NOT NULL
  AND pd.manager_employee_id <> pe.id
  AND NOT EXISTS (
    SELECT 1
    FROM puls_core.employee_reporting_lines rl
    WHERE rl.tenant_id = pe.tenant_id
      AND rl.employee_id = pe.id
      AND rl.is_active = TRUE
      AND rl.relationship_type = 'primary_manager'::puls_core.reporting_relationship_type
  );

-- ---------------------------------------------------------------------------
-- Demo single-root reporting lines (Mert Teknik tenant)
-- ---------------------------------------------------------------------------

DO $$
DECLARE
  v_tenant_id UUID;
  v_gm UUID;
  v_ik UUID;
  v_ik2 UUID;
  v_mgr UUID;
  v_emp UUID;
BEGIN
  SELECT t.id INTO v_tenant_id
  FROM puls_core.tenants t
  WHERE t.legacy_public_tenant_id = '11111111-1111-1111-1111-111111111111'::uuid
     OR t.name ILIKE '%Mert Teknik%'
  LIMIT 1;

  IF v_tenant_id IS NULL THEN
    RETURN;
  END IF;

  SELECT id INTO v_gm FROM puls_core.employees
  WHERE tenant_id = v_tenant_id AND legacy_public_employee_id = '44444444-4444-4444-4444-444444444402'::uuid;

  SELECT id INTO v_ik FROM puls_core.employees
  WHERE tenant_id = v_tenant_id AND legacy_public_employee_id = '44444444-4444-4444-4444-444444444401'::uuid;

  SELECT id INTO v_ik2 FROM puls_core.employees
  WHERE tenant_id = v_tenant_id AND legacy_public_employee_id = '44444444-4444-4444-4444-444444444405'::uuid;

  SELECT id INTO v_mgr FROM puls_core.employees
  WHERE tenant_id = v_tenant_id AND legacy_public_employee_id = '44444444-4444-4444-4444-444444444404'::uuid;

  SELECT id INTO v_emp FROM puls_core.employees
  WHERE tenant_id = v_tenant_id AND legacy_public_employee_id = '44444444-4444-4444-4444-444444444403'::uuid;

  IF v_gm IS NOT NULL AND v_ik IS NOT NULL THEN
    PERFORM puls_core.upsert_primary_reporting_line(v_tenant_id, v_ik, v_gm, 'demo');
  END IF;

  IF v_gm IS NOT NULL AND v_mgr IS NOT NULL THEN
    PERFORM puls_core.upsert_primary_reporting_line(v_tenant_id, v_mgr, v_gm, 'demo');
  END IF;

  IF v_ik IS NOT NULL AND v_ik2 IS NOT NULL THEN
    PERFORM puls_core.upsert_primary_reporting_line(v_tenant_id, v_ik2, v_ik, 'demo');
  END IF;

  IF v_mgr IS NOT NULL AND v_emp IS NOT NULL THEN
    PERFORM puls_core.upsert_primary_reporting_line(v_tenant_id, v_emp, v_mgr, 'demo');
  END IF;
END $$;
