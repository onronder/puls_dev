-- 09 PR4 Import Apply — executable smoke (single transaction; rolls back)
-- Run after supabase db push through 20260525160000 on staging.

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_employee_id UUID;
  v_ns_high UUID;
  v_ns_low UUID;
  v_batch_id UUID;
  v_dry_batch_id UUID;
  v_bad_batch_id UUID;
  v_prio_batch_id UUID;
  v_dup_batch_id UUID;
  v_order_batch_id UUID;
  v_order_result JSONB;
  v_le_id UUID;
  v_loc_id UUID;
  v_cc_id UUID;
  v_dept_id UUID;
  v_pos_id UUID;
  v_emp_id UUID;
  v_cache_le UUID;
  v_cache_loc UUID;
  v_cache_cc UUID;
  v_result JSONB;
  v_norm JSONB;
  v_raw JSONB;
  v_count INTEGER;
  v_existing_le UUID;
BEGIN
  PERFORM set_config('request.jwt.claim.role', 'service_role', true);

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

  INSERT INTO puls_integration.source_namespaces (
    tenant_id, code, name, source_type, priority_rank
  )
  VALUES (v_tenant_id, 'smoke_apply_erp', 'Smoke Apply ERP', 'erp', 5)
  ON CONFLICT (tenant_id, code) DO UPDATE
    SET is_active = TRUE, priority_rank = 5, source_type = 'erp'
  RETURNING id INTO v_ns_high;

  IF v_ns_high IS NULL THEN
    SELECT id INTO v_ns_high
    FROM puls_integration.source_namespaces
    WHERE tenant_id = v_tenant_id AND code = 'smoke_apply_erp';
  END IF;

  INSERT INTO puls_integration.source_namespaces (
    tenant_id, code, name, source_type, priority_rank
  )
  VALUES (v_tenant_id, 'smoke_apply_csv', 'Smoke Apply CSV', 'excel_csv', 50)
  ON CONFLICT (tenant_id, code) DO UPDATE
    SET is_active = TRUE, priority_rank = 50, source_type = 'excel_csv'
  RETURNING id INTO v_ns_low;

  IF v_ns_low IS NULL THEN
    SELECT id INTO v_ns_low
    FROM puls_integration.source_namespaces
    WHERE tenant_id = v_tenant_id AND code = 'smoke_apply_csv';
  END IF;

  -- Seed canonical row owned by high-priority namespace for priority skip test
  INSERT INTO puls_core.legal_entities (
    tenant_id, code, name, source_namespace_id, external_id
  )
  VALUES (v_tenant_id, 'smoke_prio_le', 'Priority Owned LE', v_ns_high, 'PRIO-LE-001')
  ON CONFLICT (tenant_id, code) DO UPDATE
    SET is_active = TRUE,
        source_namespace_id = EXCLUDED.source_namespace_id,
        external_id = EXCLUDED.external_id
  RETURNING id INTO v_existing_le;

  IF v_existing_le IS NULL THEN
    SELECT id INTO v_existing_le
    FROM puls_core.legal_entities
    WHERE tenant_id = v_tenant_id AND code = 'smoke_prio_le';
  END IF;

  INSERT INTO puls_integration.entity_identity_map (
    tenant_id, source_namespace_id, entity_type, external_id,
    canonical_schema, canonical_table, canonical_id, source_hash, is_active
  )
  VALUES (
    v_tenant_id, v_ns_high, 'legal_entity', 'PRIO-LE-001',
    'puls_core', 'legal_entities', v_existing_le, 'seed-hash', TRUE
  )
  ON CONFLICT (tenant_id, source_namespace_id, entity_type, external_id)
  DO UPDATE SET canonical_id = EXCLUDED.canonical_id, is_active = TRUE;

  -- Duplicate active email ambiguity fixture
  IF v_employee_id IS NOT NULL THEN
    INSERT INTO puls_core.employees (
      tenant_id, full_name, email, employment_status, employee_code
    )
    VALUES (
      v_tenant_id, 'Smoke Dup Ambiguity A', 'smoke.dup.ambiguity@test.local', 'active', 'SMK-DUP-A'
    )
    ON CONFLICT DO NOTHING;

    INSERT INTO puls_core.employees (
      tenant_id, full_name, email, employment_status, employee_code
    )
    VALUES (
      v_tenant_id, 'Smoke Dup Ambiguity B', 'smoke.dup.ambiguity@test.local', 'active', 'SMK-DUP-B'
    )
    ON CONFLICT DO NOTHING;
  END IF;

  -- -------------------------------------------------------------------------
  -- Happy path: full entity chain + assignments + manager line
  -- -------------------------------------------------------------------------

  SELECT puls_integration.create_import_batch('smoke_apply_erp', 'apply', 'smoke-apply-v1', v_tenant_id)
  INTO v_batch_id;

  SELECT puls_integration.record_import_row(
    v_batch_id, 1, 'legal_entity', 'LE-SMOKE-001',
    jsonb_build_object('code', 'smoke_apply_le', 'name', 'Smoke Apply LE')
  );
  SELECT puls_integration.record_import_row(
    v_batch_id, 2, 'location', 'LOC-SMOKE-001',
    jsonb_build_object(
      'code', 'smoke_apply_loc', 'name', 'Smoke Apply Loc',
      'legal_entity_external_id', 'LE-SMOKE-001'
    )
  );
  SELECT puls_integration.record_import_row(
    v_batch_id, 3, 'cost_center', 'CC-SMOKE-001',
    jsonb_build_object(
      'code', 'smoke_apply_cc', 'name', 'Smoke Apply CC',
      'legal_entity_external_id', 'LE-SMOKE-001'
    )
  );
  SELECT puls_integration.record_import_row(
    v_batch_id, 4, 'department', 'DEPT-SMOKE-001',
    jsonb_build_object(
      'code', 'smoke_apply_dept', 'name', 'Smoke Apply Dept',
      'cost_center_code', 'smoke_apply_cc'
    )
  );
  SELECT puls_integration.record_import_row(
    v_batch_id, 5, 'position', 'POS-SMOKE-001',
    jsonb_build_object(
      'code', 'smoke_apply_pos', 'name', 'Smoke Apply Position',
      'department_code', 'smoke_apply_dept'
    )
  );
  SELECT puls_integration.record_import_row(
    v_batch_id, 6, 'employee', 'EMP-SMOKE-001',
    jsonb_build_object(
      'full_name', 'Smoke Import Employee',
      'employee_code', 'SMK-EMP-001',
      'email', 'smoke.import.employee@test.local',
      'department_code', 'smoke_apply_dept',
      'position_code', 'smoke_apply_pos',
      'legal_entity_external_id', 'LE-SMOKE-001',
      'location_external_id', 'LOC-SMOKE-001',
      'cost_center_external_id', 'CC-SMOKE-001',
      'manager_employee_code', (
        SELECT employee_code FROM puls_core.employees
        WHERE id = v_employee_id LIMIT 1
      )
    )
  );

  SELECT puls_integration.validate_import_batch(v_batch_id) INTO v_result;
  IF (v_result ->> 'error_count')::integer <> 0 THEN
    RAISE EXCEPTION 'SMOKE_FAIL: happy path validate error_count=%', v_result ->> 'error_count';
  END IF;

  SELECT puls_integration.preview_import_diff(v_batch_id) INTO v_result;
  IF (v_result ->> 'status') <> 'previewed' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: preview status=%', v_result ->> 'status';
  END IF;

  SELECT puls_integration.apply_import_batch(v_batch_id) INTO v_result;
  IF (v_result ->> 'status') <> 'applied' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: apply status=%', v_result ->> 'status';
  END IF;

  SELECT id INTO v_le_id FROM puls_core.legal_entities
  WHERE tenant_id = v_tenant_id AND code = 'smoke_apply_le';
  SELECT id INTO v_loc_id FROM puls_core.locations
  WHERE tenant_id = v_tenant_id AND code = 'smoke_apply_loc';
  SELECT id INTO v_cc_id FROM puls_core.cost_centers
  WHERE tenant_id = v_tenant_id AND code = 'smoke_apply_cc';
  SELECT id INTO v_dept_id FROM puls_core.departments
  WHERE tenant_id = v_tenant_id AND code = 'smoke_apply_dept';
  SELECT id INTO v_pos_id FROM puls_core.positions
  WHERE tenant_id = v_tenant_id AND code = 'smoke_apply_pos';
  SELECT id INTO v_emp_id FROM puls_core.employees
  WHERE tenant_id = v_tenant_id AND employee_code = 'SMK-EMP-001';

  IF v_le_id IS NULL OR v_loc_id IS NULL OR v_cc_id IS NULL
     OR v_dept_id IS NULL OR v_pos_id IS NULL OR v_emp_id IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL: canonical rows missing after happy path apply';
  END IF;

  SELECT legal_entity_id, location_id, cost_center_id
  INTO v_cache_le, v_cache_loc, v_cache_cc
  FROM puls_core.employees WHERE id = v_emp_id;

  IF v_cache_le IS DISTINCT FROM v_le_id
     OR v_cache_loc IS DISTINCT FROM v_loc_id
     OR v_cache_cc IS DISTINCT FROM v_cc_id THEN
    RAISE EXCEPTION 'SMOKE_FAIL: employee cache not synced from assignment SoT';
  END IF;

  SELECT normalized_payload INTO v_norm
  FROM puls_integration.import_records
  WHERE batch_id = v_batch_id AND external_id = 'EMP-SMOKE-001';

  IF v_norm ? 'salary' OR v_norm ? 'iban' OR v_norm ? 'tckn' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: sensitive fields in normalized_payload';
  END IF;

  SELECT raw_payload INTO v_raw
  FROM puls_integration.import_records
  WHERE batch_id = v_batch_id
  LIMIT 1;

  IF v_raw IS NOT NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL: raw_payload must remain NULL';
  END IF;

  -- Re-apply rejected
  BEGIN
    PERFORM puls_integration.apply_import_batch(v_batch_id);
    RAISE EXCEPTION 'SMOKE_FAIL: expected re-apply rejection';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_IMPORT_BATCH_STATE_INVALID%' THEN
        RAISE;
      END IF;
  END;

  -- -------------------------------------------------------------------------
  -- dry_run batch → apply rejected
  -- -------------------------------------------------------------------------

  SELECT puls_integration.create_import_batch('smoke_apply_erp', 'dry_run', NULL, v_tenant_id)
  INTO v_dry_batch_id;

  SELECT puls_integration.record_import_row(
    v_dry_batch_id, 1, 'legal_entity', 'DRY-LE-001',
    jsonb_build_object('code', 'smoke_dry_le', 'name', 'Dry Run LE')
  );

  PERFORM puls_integration.validate_import_batch(v_dry_batch_id);
  PERFORM puls_integration.preview_import_diff(v_dry_batch_id);

  BEGIN
    PERFORM puls_integration.apply_import_batch(v_dry_batch_id);
    RAISE EXCEPTION 'SMOKE_FAIL: expected dry_run apply rejection';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_IMPORT_DRY_RUN%' THEN
        RAISE;
      END IF;
  END;

  SELECT COUNT(*) INTO v_count
  FROM puls_core.legal_entities
  WHERE tenant_id = v_tenant_id AND code = 'smoke_dry_le';

  IF v_count <> 0 THEN
    RAISE EXCEPTION 'SMOKE_FAIL: dry_run apply must not create canonical rows';
  END IF;

  -- -------------------------------------------------------------------------
  -- unresolved ref → UNRESOLVED_REFERENCE row error, apply blocked
  -- -------------------------------------------------------------------------

  SELECT puls_integration.create_import_batch('smoke_apply_erp', 'apply', NULL, v_tenant_id)
  INTO v_bad_batch_id;

  SELECT puls_integration.record_import_row(
    v_bad_batch_id, 1, 'location', 'BAD-LOC-001',
    jsonb_build_object(
      'code', 'smoke_bad_loc', 'name', 'Bad Loc',
      'legal_entity_external_id', 'DOES-NOT-EXIST'
    )
  );

  SELECT puls_integration.validate_import_batch(v_bad_batch_id) INTO v_result;

  IF (v_result ->> 'error_count')::integer = 0 THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected unresolved ref validation error';
  END IF;

  BEGIN
    PERFORM puls_integration.preview_import_diff(v_bad_batch_id);
    RAISE EXCEPTION 'SMOKE_FAIL: expected preview blocked on error batch';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_IMPORT_BATCH_STATE_INVALID%' THEN
        RAISE;
      END IF;
  END;

  -- -------------------------------------------------------------------------
  -- lower-priority overwrite → LOWER_PRIORITY_SOURCE_SKIPPED
  -- -------------------------------------------------------------------------

  SELECT puls_integration.create_import_batch('smoke_apply_csv', 'apply', NULL, v_tenant_id)
  INTO v_prio_batch_id;

  SELECT puls_integration.record_import_row(
    v_prio_batch_id, 1, 'legal_entity', 'PRIO-LE-001',
    jsonb_build_object('code', 'smoke_prio_le', 'name', 'Lower Priority Attempt')
  );

  PERFORM puls_integration.validate_import_batch(v_prio_batch_id);
  PERFORM puls_integration.preview_import_diff(v_prio_batch_id);
  PERFORM puls_integration.apply_import_batch(v_prio_batch_id);

  SELECT COUNT(*) INTO v_count
  FROM puls_integration.import_records
  WHERE batch_id = v_prio_batch_id
    AND status = 'skipped'
    AND 'LOWER_PRIORITY_SOURCE_SKIPPED' = ANY(error_codes);

  IF v_count <> 1 THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected LOWER_PRIORITY_SOURCE_SKIPPED on priority batch';
  END IF;

  -- -------------------------------------------------------------------------
  -- duplicate email → AMBIGUOUS_REFERENCE
  -- -------------------------------------------------------------------------

  SELECT puls_integration.create_import_batch('smoke_apply_erp', 'apply', NULL, v_tenant_id)
  INTO v_dup_batch_id;

  SELECT puls_integration.record_import_row(
    v_dup_batch_id, 1, 'employee', 'DUP-EMP-001',
    jsonb_build_object(
      'full_name', 'Dup Lookup',
      'email', 'smoke.dup.ambiguity@test.local'
    )
  );

  SELECT puls_integration.validate_import_batch(v_dup_batch_id) INTO v_result;

  IF NOT EXISTS (
    SELECT 1 FROM puls_integration.import_records ir
    WHERE ir.batch_id = v_dup_batch_id
      AND 'AMBIGUOUS_REFERENCE' = ANY(ir.error_codes)
  ) THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected AMBIGUOUS_REFERENCE for duplicate email';
  END IF;

  -- -------------------------------------------------------------------------
  -- same-batch ref: child row before parent row still validates
  -- -------------------------------------------------------------------------

  SELECT puls_integration.create_import_batch('smoke_apply_erp', 'apply', NULL, v_tenant_id)
  INTO v_order_batch_id;

  SELECT puls_integration.record_import_row(
    v_order_batch_id, 1, 'location', 'ORD-LOC-001',
    jsonb_build_object(
      'code', 'smoke_order_loc', 'name', 'Order Loc',
      'legal_entity_code', 'smoke_order_le'
    )
  );
  SELECT puls_integration.record_import_row(
    v_order_batch_id, 2, 'legal_entity', 'ORD-LE-001',
    jsonb_build_object('code', 'smoke_order_le', 'name', 'Order LE')
  );

  SELECT puls_integration.validate_import_batch(v_order_batch_id) INTO v_order_result;

  IF (v_order_result ->> 'error_count')::integer <> 0 THEN
    RAISE EXCEPTION 'SMOKE_FAIL: same-batch out-of-order refs should validate, error_count=%',
      v_order_result ->> 'error_count';
  END IF;

  -- -------------------------------------------------------------------------
  -- single-match natural-key lookup exercises UUID deterministic pick
  -- -------------------------------------------------------------------------

  SELECT lb.canonical_id
  INTO v_existing_le
  FROM puls_integration._import_lookup_by_code(
    v_tenant_id,
    'legal_entity'::puls_integration.import_entity_type,
    'smoke_apply_le'
  ) lb
  WHERE lb.error_code IS NULL;

  IF v_existing_le IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected single-match legal_entity lookup to return a canonical id';
  END IF;

  RAISE NOTICE '09 PR4 import apply smoke passed';

  PERFORM set_config('request.jwt.claim.role', '', true);
END $$;

ROLLBACK;
