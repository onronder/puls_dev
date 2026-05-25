-- 09 PR2 Enterprise Dimensions — executable smoke (rolls back)
-- Run after supabase db push through 20260525150000 on staging.
--
-- Pre-merge verification (from repo root):
--   ./scripts/verify-09-enterprise-dimensions-migration.sh origin/cursor/09-enterprise-dimensions-b5b2
--   ./scripts/verify-09-import-migration.sh HEAD
--   node scripts/check-sensitive-grep.mjs

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_employee_id UUID;
  v_legal_entity_id UUID;
  v_location_id UUID;
  v_cost_center_id UUID;
  v_dept_id UUID;
  v_cache_le UUID;
  v_cache_loc UUID;
  v_cache_cc UUID;
BEGIN
  SELECT id INTO v_tenant_id
  FROM puls_core.tenants
  WHERE legacy_public_tenant_id = '44444444-4444-4444-4444-444444444444'
  LIMIT 1;

  IF v_tenant_id IS NULL THEN
    RAISE NOTICE 'SKIP: demo tenant not found';
    RETURN;
  END IF;

  SELECT id INTO v_employee_id
  FROM puls_core.employees
  WHERE tenant_id = v_tenant_id
    AND employment_status = 'active'
  ORDER BY full_name
  LIMIT 1;

  IF v_employee_id IS NULL THEN
    RAISE NOTICE 'SKIP: no active employee in demo tenant';
    RETURN;
  END IF;

  INSERT INTO puls_core.legal_entities (tenant_id, code, name)
  VALUES (v_tenant_id, 'smoke_le', 'Smoke Legal Entity')
  RETURNING id INTO v_legal_entity_id;

  INSERT INTO puls_core.locations (tenant_id, legal_entity_id, code, name)
  VALUES (v_tenant_id, v_legal_entity_id, 'smoke_loc', 'Smoke Location')
  RETURNING id INTO v_location_id;

  INSERT INTO puls_core.cost_centers (tenant_id, legal_entity_id, code, name)
  VALUES (v_tenant_id, v_legal_entity_id, 'smoke_cc', 'Smoke Cost Center')
  RETURNING id INTO v_cost_center_id;

  INSERT INTO puls_core.employee_legal_entity_assignments (
    tenant_id, employee_id, legal_entity_id, is_active
  ) VALUES (v_tenant_id, v_employee_id, v_legal_entity_id, TRUE);

  INSERT INTO puls_core.employee_location_assignments (
    tenant_id, employee_id, location_id, is_active
  ) VALUES (v_tenant_id, v_employee_id, v_location_id, TRUE);

  INSERT INTO puls_core.employee_cost_center_assignments (
    tenant_id, employee_id, cost_center_id, is_active
  ) VALUES (v_tenant_id, v_employee_id, v_cost_center_id, TRUE);

  SELECT legal_entity_id, location_id, cost_center_id
  INTO v_cache_le, v_cache_loc, v_cache_cc
  FROM puls_core.employees
  WHERE id = v_employee_id;

  IF v_cache_le IS DISTINCT FROM v_legal_entity_id
     OR v_cache_loc IS DISTINCT FROM v_location_id
     OR v_cache_cc IS DISTINCT FROM v_cost_center_id THEN
    RAISE EXCEPTION 'SMOKE_FAIL: employee cache not synced from assignments';
  END IF;

  -- Deactivate assignment clears cache on re-sync
  UPDATE puls_core.employee_cost_center_assignments
  SET is_active = FALSE
  WHERE tenant_id = v_tenant_id AND employee_id = v_employee_id;

  SELECT cost_center_id INTO v_cache_cc FROM puls_core.employees WHERE id = v_employee_id;
  IF v_cache_cc IS NOT NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL: cost_center_id cache should be NULL after deactivate';
  END IF;

  -- Active uniqueness: second active assignment must fail
  BEGIN
    INSERT INTO puls_core.employee_legal_entity_assignments (
      tenant_id, employee_id, legal_entity_id, is_active
    ) VALUES (v_tenant_id, v_employee_id, v_legal_entity_id, TRUE);
    RAISE EXCEPTION 'SMOKE_FAIL: expected unique violation on second active legal entity assignment';
  EXCEPTION WHEN unique_violation THEN
    NULL;
  END;

  -- Department cost_center_id tenant guard
  SELECT id INTO v_dept_id FROM puls_core.departments WHERE tenant_id = v_tenant_id LIMIT 1;
  IF v_dept_id IS NOT NULL THEN
    UPDATE puls_core.departments SET cost_center_id = v_cost_center_id WHERE id = v_dept_id;
  END IF;

  RAISE NOTICE '09 PR2 smoke OK: cache sync, deactivate, uniqueness, department cost_center_id';
END $$;

ROLLBACK;

-- Manual negative checks (expect ERROR outside transaction):
-- Cross-tenant location.legal_entity_id
-- Identity map with entity_type/cost_center mismatch
-- INSERT with 'legal_entity'::puls_integration.import_entity_type in same migration already avoided
