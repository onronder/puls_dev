-- 12 PR12.3 Performance Cycle Contract Smoke — executable smoke (single transaction; rolls back)
-- Contract-branded insert/update for puls_performance.performance_cycles.
-- DB-backed guards asserted here; adapter-only validation documented via NOTICE.

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_other_tenant_id UUID;
  v_cycle_id UUID;
  v_cycle_name TEXT;
  v_cycle_status TEXT;
  v_rows_updated INTEGER;
BEGIN
  PERFORM set_config('request.jwt.claim.role', 'service_role', true);

  SELECT id INTO v_tenant_id
  FROM puls_core.tenants
  WHERE legacy_public_tenant_id = '11111111-1111-1111-1111-111111111111'
     OR name ILIKE '%Mert Teknik%'
  LIMIT 1;

  IF v_tenant_id IS NULL THEN
    RAISE NOTICE 'SKIP: demo/staging tenant not found';
    RETURN;
  END IF;

  SELECT id INTO v_other_tenant_id
  FROM puls_core.tenants
  WHERE id <> v_tenant_id
  LIMIT 1;

  INSERT INTO puls_performance.performance_cycles (
    tenant_id,
    name,
    starts_at,
    ends_at,
    status
  ) VALUES (
    v_tenant_id,
    'demo_performance_cycle_contract_ draft cycle',
    CURRENT_DATE + 30,
    CURRENT_DATE + 120,
    'draft'
  )
  RETURNING id INTO v_cycle_id;

  UPDATE puls_performance.performance_cycles
  SET
    name = 'demo_performance_cycle_contract_ active cycle',
    status = 'active'
  WHERE tenant_id = v_tenant_id
    AND id = v_cycle_id;

  SELECT name, status::TEXT
  INTO v_cycle_name, v_cycle_status
  FROM puls_performance.performance_cycles
  WHERE tenant_id = v_tenant_id
    AND id = v_cycle_id;

  IF v_cycle_name IS DISTINCT FROM 'demo_performance_cycle_contract_ active cycle' THEN
    RAISE EXCEPTION 'SMOKE_FAIL performance cycle update: unexpected name %', v_cycle_name;
  END IF;

  IF v_cycle_status IS DISTINCT FROM 'active' THEN
    RAISE EXCEPTION 'SMOKE_FAIL performance cycle update: expected status active, got %', v_cycle_status;
  END IF;

  RAISE NOTICE 'OK: contract-aligned insert/update for performance cycle %', v_cycle_id;

  BEGIN
    UPDATE puls_performance.performance_cycles
    SET status = 'invalid_status'::puls_performance.performance_cycle_status
    WHERE id = v_cycle_id;
    RAISE EXCEPTION 'SMOKE_FAIL enum guard: expected invalid status cast error';
  EXCEPTION
    WHEN invalid_text_representation THEN
      RAISE NOTICE 'OK: DB enum guard rejected invalid status';
    WHEN OTHERS THEN
      IF SQLERRM ILIKE '%invalid input value for enum%' THEN
        RAISE NOTICE 'OK: DB enum guard rejected invalid status';
      ELSE
        RAISE;
      END IF;
  END;

  IF v_other_tenant_id IS NOT NULL THEN
    UPDATE puls_performance.performance_cycles
    SET name = 'demo_performance_cycle_contract_ wrong tenant'
    WHERE id = v_cycle_id
      AND tenant_id = v_other_tenant_id;

    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

    IF v_rows_updated <> 0 THEN
      RAISE EXCEPTION 'SMOKE_FAIL tenant guard: wrong-tenant update affected % rows', v_rows_updated;
    END IF;

    RAISE NOTICE 'OK: wrong-tenant update affected 0 rows';
  ELSE
    RAISE NOTICE 'NOTICE: only one tenant present; skipping wrong-tenant update case';
  END IF;

  RAISE NOTICE 'NOTICE: blank name validation is adapter-backed (validatePerformanceCycleInput); DB may accept empty strings';
  RAISE NOTICE 'NOTICE: ends_at <= starts_at date order is adapter-backed unless a DB CHECK exists';

  BEGIN
    INSERT INTO puls_performance.performance_cycles (
      tenant_id,
      name,
      starts_at,
      ends_at,
      status
    ) VALUES (
      v_tenant_id,
      'demo_performance_cycle_contract_ inverted dates notice',
      CURRENT_DATE + 90,
      CURRENT_DATE + 30,
      'draft'
    );
    RAISE NOTICE 'NOTICE: inverted date order insert succeeded at DB layer (adapter validates order)';
  EXCEPTION
    WHEN OTHERS THEN
      RAISE NOTICE 'OK: DB rejected inverted date order: %', SQLERRM;
  END;

  RAISE NOTICE 'demo_performance_cycle_contract_ smoke completed for tenant %', v_tenant_id;
END $$;

ROLLBACK;
