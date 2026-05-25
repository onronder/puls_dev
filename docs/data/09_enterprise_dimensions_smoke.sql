-- 09 PR2 Enterprise Dimensions — executable smoke (rolls back)
-- Run after supabase db push through 20260525150000 on staging.

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_other_tenant_id UUID;
  v_employee_id UUID;
  v_legal_entity_id UUID;
  v_location_id UUID;
  v_cost_center_id UUID;
  v_cost_center_b UUID;
  v_dept_id UUID;
  v_namespace_id UUID;
  v_cache_le UUID;
  v_cache_loc UUID;
  v_cache_cc UUID;
  v_other_le UUID;
BEGIN
  SELECT id INTO v_tenant_id
  FROM puls_core.tenants
  WHERE legacy_public_tenant_id = '44444444-4444-4444-4444-444444444444'
  LIMIT 1;

  IF v_tenant_id IS NULL THEN
    RAISE NOTICE 'SKIP: demo tenant not found';
    RETURN;
  END IF;

  SELECT id INTO v_other_tenant_id
  FROM puls_core.tenants
  WHERE id <> v_tenant_id
  LIMIT 1;

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
  VALUES (v_tenant_id, v_legal_entity_id, 'smoke_cc_a', 'Smoke Cost Center A')
  RETURNING id INTO v_cost_center_id;

  INSERT INTO puls_core.cost_centers (tenant_id, legal_entity_id, code, name, parent_cost_center_id)
  VALUES (v_tenant_id, v_legal_entity_id, 'smoke_cc_b', 'Smoke Cost Center B', v_cost_center_id)
  RETURNING id INTO v_cost_center_b;

  -- Negative: cost center parent cycle A -> B -> A
  BEGIN
    UPDATE puls_core.cost_centers
    SET parent_cost_center_id = v_cost_center_b
    WHERE id = v_cost_center_id;
    RAISE EXCEPTION 'SMOKE_FAIL: expected cost center cycle rejection';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_COST_CENTER_CYCLE%' THEN
        RAISE;
      END IF;
  END;

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

  -- Negative: direct cache bypass without assignment SoT
  BEGIN
    UPDATE puls_core.employees
    SET legal_entity_id = NULL
    WHERE id = v_employee_id;
    RAISE EXCEPTION 'SMOKE_FAIL: expected cache bypass rejection when active assignment exists';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_EMPLOYEE_CACHE_BYPASS%' THEN
        RAISE;
      END IF;
  END;

  -- Deactivate then DELETE clears cache
  UPDATE puls_core.employee_cost_center_assignments
  SET is_active = FALSE
  WHERE tenant_id = v_tenant_id AND employee_id = v_employee_id AND cost_center_id = v_cost_center_id;

  SELECT cost_center_id INTO v_cache_cc FROM puls_core.employees WHERE id = v_employee_id;
  IF v_cache_cc IS NOT NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL: cost_center_id cache should be NULL after deactivate';
  END IF;

  DELETE FROM puls_core.employee_cost_center_assignments
  WHERE tenant_id = v_tenant_id AND employee_id = v_employee_id;

  SELECT cost_center_id INTO v_cache_cc FROM puls_core.employees WHERE id = v_employee_id;
  IF v_cache_cc IS NOT NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL: cost_center_id cache should be NULL after assignment DELETE';
  END IF;

  -- Active uniqueness
  BEGIN
    INSERT INTO puls_core.employee_legal_entity_assignments (
      tenant_id, employee_id, legal_entity_id, is_active
    ) VALUES (v_tenant_id, v_employee_id, v_legal_entity_id, TRUE);
    RAISE EXCEPTION 'SMOKE_FAIL: expected unique violation on second active legal entity assignment';
  EXCEPTION WHEN unique_violation THEN
    NULL;
  END;

  -- Cross-tenant location.legal_entity_id
  IF v_other_tenant_id IS NOT NULL THEN
    SELECT id INTO v_other_le
    FROM puls_core.legal_entities
    WHERE tenant_id = v_other_tenant_id AND is_active = TRUE
    LIMIT 1;

    IF v_other_le IS NOT NULL THEN
      BEGIN
        INSERT INTO puls_core.locations (tenant_id, legal_entity_id, code, name)
        VALUES (v_tenant_id, v_other_le, 'smoke_bad_loc', 'Bad Cross Tenant Location');
        RAISE EXCEPTION 'SMOKE_FAIL: expected cross-tenant location rejection';
      EXCEPTION
        WHEN OTHERS THEN
          IF SQLERRM NOT LIKE '%PULS_LOCATION_INVALID_LEGAL_ENTITY%' THEN
            RAISE;
          END IF;
      END;
    END IF;
  ELSE
    RAISE NOTICE 'SKIP cross-tenant location: only one tenant in database';
  END IF;

  -- Department cost_center_id valid same-tenant
  SELECT id INTO v_dept_id FROM puls_core.departments WHERE tenant_id = v_tenant_id LIMIT 1;
  IF v_dept_id IS NOT NULL THEN
    UPDATE puls_core.departments SET cost_center_id = v_cost_center_id WHERE id = v_dept_id;
  END IF;

  -- Department cost_center_id cross-tenant reject
  IF v_other_tenant_id IS NOT NULL THEN
    SELECT cc.id INTO v_other_le
    FROM puls_core.cost_centers cc
    WHERE cc.tenant_id = v_other_tenant_id AND cc.is_active = TRUE
    LIMIT 1;

    IF v_dept_id IS NOT NULL AND v_other_le IS NOT NULL THEN
      BEGIN
        UPDATE puls_core.departments SET cost_center_id = v_other_le WHERE id = v_dept_id;
        RAISE EXCEPTION 'SMOKE_FAIL: expected department cross-tenant cost_center rejection';
      EXCEPTION
        WHEN OTHERS THEN
          IF SQLERRM NOT LIKE '%PULS_DEPARTMENT_INVALID_COST_CENTER%' THEN
            RAISE;
          END IF;
      END;
    END IF;
  END IF;

  -- Identity map entity_type / canonical_table mismatch
  INSERT INTO puls_integration.source_namespaces (tenant_id, code, name, priority_rank)
  VALUES (v_tenant_id, 'smoke_ns_pr2', 'Smoke Namespace PR2', 50)
  ON CONFLICT (tenant_id, code) DO UPDATE SET is_active = TRUE, priority_rank = EXCLUDED.priority_rank
  RETURNING id INTO v_namespace_id;

  IF v_namespace_id IS NULL THEN
    SELECT id INTO v_namespace_id
    FROM puls_integration.source_namespaces
    WHERE tenant_id = v_tenant_id AND code = 'smoke_ns_pr2';
  END IF;

  BEGIN
    INSERT INTO puls_integration.entity_identity_map (
      tenant_id, source_namespace_id, entity_type, external_id,
      canonical_schema, canonical_table, canonical_id
    )
    VALUES (
      v_tenant_id, v_namespace_id, 'employee', 'smoke-map-001',
      'puls_core', 'cost_centers', v_cost_center_id
    );
    RAISE EXCEPTION 'SMOKE_FAIL: expected identity map type mismatch rejection';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_IDENTITY_MAP_TYPE_MISMATCH%' THEN
        RAISE;
      END IF;
  END;

  RAISE NOTICE '09 PR2 smoke OK: cycle, cache guard, deactivate/DELETE, cross-tenant, identity map';
END $$;

ROLLBACK;
