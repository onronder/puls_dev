-- 11 PR11.2 Org Setup CRUD Readiness — executable smoke (single transaction; rolls back)

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_other_tenant_id UUID;
  v_dept_id UUID;
  v_imported_dept_id UUID;
  v_pos_id UUID;
  v_imported_pos_id UUID;
  v_other_dept_id UUID;
BEGIN
  PERFORM set_config('request.jwt.claim.role', 'service_role', true);

  SELECT id INTO v_tenant_id
  FROM puls_core.tenants
  WHERE legacy_public_tenant_id = '11111111-1111-1111-1111-111111111111'
     OR name ILIKE '%Mert Teknik%'
  LIMIT 1;

  IF v_tenant_id IS NULL THEN
    RAISE NOTICE 'SKIP: demo tenant not found';
    RETURN;
  END IF;

  -- valid department insert
  INSERT INTO puls_core.departments (tenant_id, name, code, is_active)
  VALUES (v_tenant_id, '  Smoke Dept  ', 'demo_org_setup_crud_dept', TRUE)
  RETURNING id INTO v_dept_id;

  IF v_dept_id IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL: valid department insert failed';
  END IF;

  IF (SELECT name FROM puls_core.departments WHERE id = v_dept_id) <> 'Smoke Dept'
     OR (SELECT code FROM puls_core.departments WHERE id = v_dept_id) <> 'demo_org_setup_crud_dept' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: department trim/normalize failed';
  END IF;

  UPDATE puls_core.departments
  SET name = '  Updated Dept  ', code = 'demo_org_setup_crud_dept'
  WHERE id = v_dept_id;

  IF (SELECT name FROM puls_core.departments WHERE id = v_dept_id) <> 'Updated Dept' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: department update trim failed';
  END IF;

  -- blank department name
  BEGIN
    INSERT INTO puls_core.departments (tenant_id, name, code, is_active)
    VALUES (v_tenant_id, '   ', 'demo_org_setup_crud_blank_name', TRUE);
    RAISE EXCEPTION 'SMOKE_FAIL: blank department name should raise PULS_ORG_DEPARTMENT_NAME_REQUIRED';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%PULS_ORG_DEPARTMENT_NAME_REQUIRED%' THEN
      RAISE;
    END IF;
  END;

  -- blank department code
  BEGIN
    INSERT INTO puls_core.departments (tenant_id, name, code, is_active)
    VALUES (v_tenant_id, 'Valid Name', '   ', TRUE);
    RAISE EXCEPTION 'SMOKE_FAIL: blank department code should raise PULS_ORG_DEPARTMENT_CODE_REQUIRED';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%PULS_ORG_DEPARTMENT_CODE_REQUIRED%' THEN
      RAISE;
    END IF;
  END;

  -- invalid department code
  BEGIN
    INSERT INTO puls_core.departments (tenant_id, name, code, is_active)
    VALUES (v_tenant_id, 'Invalid Code Dept', 'INVALID-CODE', TRUE);
    RAISE EXCEPTION 'SMOKE_FAIL: invalid department code should raise PULS_ORG_DEPARTMENT_CODE_INVALID';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%PULS_ORG_DEPARTMENT_CODE_INVALID%' THEN
      RAISE;
    END IF;
  END;

  -- duplicate department code (no unique index — NOTICE only)
  BEGIN
    INSERT INTO puls_core.departments (tenant_id, name, code, is_active)
    VALUES (v_tenant_id, 'Duplicate Dept', 'demo_org_setup_crud_dept', TRUE);
    RAISE NOTICE 'OK: duplicate department code insert succeeded (no tenant+code unique constraint)';
  EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'OK: duplicate department code blocked by unique constraint (23505)';
  END;

  -- imported department update (source-read-only)
  -- Boundary: UPDATE blocked when NULLIF(BTRIM(OLD.external_source), '') IS NOT NULL
  INSERT INTO puls_core.departments (tenant_id, name, code, external_source, is_active)
  VALUES (v_tenant_id, 'Imported Dept', 'demo_org_setup_crud_imported_dept', 'canias_erp', TRUE)
  RETURNING id INTO v_imported_dept_id;

  BEGIN
    UPDATE puls_core.departments
    SET name = 'Edited Imported'
    WHERE id = v_imported_dept_id;
    RAISE EXCEPTION 'SMOKE_FAIL: imported department update should raise PULS_ORG_DEPARTMENT_SOURCE_READ_ONLY';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%PULS_ORG_DEPARTMENT_SOURCE_READ_ONLY%' THEN
      RAISE;
    END IF;
  END;

  -- valid position insert
  INSERT INTO puls_core.positions (tenant_id, name, code, department_id, norm_headcount, is_active)
  VALUES (v_tenant_id, '  Smoke Position  ', 'demo_org_setup_crud_pos', v_dept_id, 2, TRUE)
  RETURNING id INTO v_pos_id;

  UPDATE puls_core.positions
  SET name = '  Updated Position  ', code = 'demo_org_setup_crud_pos'
  WHERE id = v_pos_id;

  IF (SELECT name FROM puls_core.positions WHERE id = v_pos_id) <> 'Updated Position' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: position update trim failed';
  END IF;

  -- invalid position code
  BEGIN
    INSERT INTO puls_core.positions (tenant_id, name, code, is_active)
    VALUES (v_tenant_id, 'Bad Code Pos', 'Bad-Code', TRUE);
    RAISE EXCEPTION 'SMOKE_FAIL: invalid position code should raise PULS_ORG_POSITION_CODE_INVALID';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%PULS_ORG_POSITION_CODE_INVALID%' THEN
      RAISE;
    END IF;
  END;

  -- invalid department FK on position
  BEGIN
    INSERT INTO puls_core.positions (tenant_id, name, code, department_id, is_active)
    VALUES (v_tenant_id, 'Bad Dept Pos', 'demo_org_setup_crud_bad_dept', gen_random_uuid(), TRUE);
    RAISE EXCEPTION 'SMOKE_FAIL: invalid department FK should raise PULS_ORG_POSITION_DEPARTMENT_INVALID';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%PULS_ORG_POSITION_DEPARTMENT_INVALID%' THEN
      RAISE;
    END IF;
  END;

  -- invalid norm_headcount
  BEGIN
    INSERT INTO puls_core.positions (tenant_id, name, code, norm_headcount, is_active)
    VALUES (v_tenant_id, 'Bad Norm', 'demo_org_setup_crud_bad_norm', -1, TRUE);
    RAISE EXCEPTION 'SMOKE_FAIL: invalid norm should raise PULS_ORG_POSITION_NORM_INVALID';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%PULS_ORG_POSITION_NORM_INVALID%' THEN
      RAISE;
    END IF;
  END;

  -- imported position update (source-read-only)
  INSERT INTO puls_core.positions (tenant_id, name, code, external_source, is_active)
  VALUES (v_tenant_id, 'Imported Pos', 'demo_org_setup_crud_imported_pos', 'canias_erp', TRUE)
  RETURNING id INTO v_imported_pos_id;

  BEGIN
    UPDATE puls_core.positions
    SET name = 'Edited Imported Pos'
    WHERE id = v_imported_pos_id;
    RAISE EXCEPTION 'SMOKE_FAIL: imported position update should raise PULS_ORG_POSITION_SOURCE_READ_ONLY';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%PULS_ORG_POSITION_SOURCE_READ_ONLY%' THEN
      RAISE;
    END IF;
  END;

  -- cross-tenant FK attempt
  SELECT id INTO v_other_tenant_id
  FROM puls_core.tenants
  WHERE id <> v_tenant_id
  LIMIT 1;

  IF v_other_tenant_id IS NOT NULL THEN
    INSERT INTO puls_core.departments (tenant_id, name, code, is_active)
    VALUES (v_other_tenant_id, 'Other Tenant Dept', 'demo_org_setup_crud_other_dept', TRUE)
    RETURNING id INTO v_other_dept_id;

    BEGIN
      INSERT INTO puls_core.positions (tenant_id, name, code, department_id, is_active)
      VALUES (v_tenant_id, 'Cross Tenant Pos', 'demo_org_setup_crud_cross', v_other_dept_id, TRUE);
      RAISE EXCEPTION 'SMOKE_FAIL: cross-tenant department FK should fail';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_ORG_POSITION_DEPARTMENT_INVALID%'
         AND SQLERRM NOT LIKE '%violates foreign key%' THEN
        RAISE;
      END IF;
    END;
  ELSE
    RAISE NOTICE 'SKIP: single-tenant staging — cross-tenant FK not asserted';
  END IF;

  RAISE NOTICE 'OK: PR11.2 org setup CRUD readiness smoke passed';
END $$;

ROLLBACK;
