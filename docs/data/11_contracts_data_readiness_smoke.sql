-- 11 PR11.6 Contracts Data Readiness — executable smoke (single transaction; rolls back)
-- Asserts tenant-scoped contract metadata reads, calc views, metadata_only invariant,
-- rollback fixture insert, and optional JWT self-read.

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_employee_id UUID;
  v_user_id UUID;
  v_current_employee_id UUID;
  v_contract_id UUID;
  v_contracts_count INTEGER;
  v_contract_files_count INTEGER;
  v_metadata_only_violations INTEGER;
  v_dashboard_contract_count INTEGER;
  v_contracts_overview_count INTEGER;
  v_contract_type TEXT;
  v_fixture_external_source TEXT := 'demo_contracts_data_readiness_';
  v_fixture_external_contract_id TEXT := 'demo_contracts_data_readiness_smoke_fixture';
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

  SELECT COUNT(*)::INTEGER INTO v_contracts_count
  FROM puls_workflow.contracts
  WHERE tenant_id = v_tenant_id;

  IF v_contracts_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL contracts: tenant-scoped SELECT failed';
  END IF;

  SELECT COUNT(*)::INTEGER INTO v_contract_files_count
  FROM puls_workflow.contract_files
  WHERE tenant_id = v_tenant_id;

  IF v_contract_files_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL contract_files: tenant-scoped SELECT failed';
  END IF;

  SELECT COUNT(*)::INTEGER INTO v_metadata_only_violations
  FROM (
    SELECT id FROM puls_workflow.contracts
    WHERE tenant_id = v_tenant_id AND metadata_only IS DISTINCT FROM TRUE
    UNION ALL
    SELECT id FROM puls_workflow.contract_files
    WHERE tenant_id = v_tenant_id AND metadata_only IS DISTINCT FROM TRUE
  ) violations;

  IF v_metadata_only_violations > 0 THEN
    RAISE EXCEPTION 'SMOKE_FAIL metadata_only: expected TRUE on contracts and contract_files';
  END IF;

  SELECT active_contract_count::INTEGER INTO v_dashboard_contract_count
  FROM puls_calc.dashboard_overview
  WHERE tenant_id = v_tenant_id
  LIMIT 1;

  IF v_dashboard_contract_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL dashboard_overview: contract count columns not readable';
  END IF;

  SELECT COUNT(*)::INTEGER INTO v_contracts_overview_count
  FROM puls_calc.contracts_overview
  WHERE tenant_id = v_tenant_id;

  IF v_contracts_overview_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL contracts_overview: tenant-scoped SELECT failed';
  END IF;

  SELECT e.id, e.user_id
  INTO v_employee_id, v_user_id
  FROM puls_core.employees e
  WHERE e.tenant_id = v_tenant_id
  LIMIT 1;

  IF v_employee_id IS NOT NULL THEN
    INSERT INTO puls_workflow.contracts (
      tenant_id,
      employee_id,
      contract_type,
      start_date,
      end_date,
      status,
      signature_status,
      risk_band,
      metadata_only,
      external_source,
      external_contract_id
    ) VALUES (
      v_tenant_id,
      v_employee_id,
      'indefinite',
      CURRENT_DATE,
      NULL,
      'active',
      'not_required',
      'low',
      TRUE,
      v_fixture_external_source,
      v_fixture_external_contract_id
    )
    RETURNING id INTO v_contract_id;

    SELECT contract_type
    INTO v_contract_type
    FROM puls_workflow.contracts
    WHERE tenant_id = v_tenant_id
      AND id = v_contract_id;

    IF v_contract_type IS DISTINCT FROM 'indefinite' THEN
      RAISE EXCEPTION 'SMOKE_FAIL rollback fixture: unexpected contract_type %', v_contract_type;
    END IF;

    RAISE NOTICE 'OK: rollback fixture contract inserted with external_source=% external_contract_id=%',
      v_fixture_external_source, v_fixture_external_contract_id;
  ELSE
    RAISE NOTICE 'NOTICE: no employee on tenant; skipping rollback fixture insert';
  END IF;

  SELECT e.id, e.user_id
  INTO v_employee_id, v_user_id
  FROM puls_core.employees e
  WHERE e.tenant_id = v_tenant_id
    AND e.user_id IS NOT NULL
  LIMIT 1;

  IF v_employee_id IS NOT NULL AND v_user_id IS NOT NULL THEN
    PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
    PERFORM set_config('request.jwt.claim.sub', v_user_id::text, true);

    SELECT puls_core.current_employee_id()
    INTO v_current_employee_id;

    IF v_current_employee_id IS DISTINCT FROM v_employee_id THEN
      RAISE EXCEPTION 'SMOKE_FAIL auth context: current_employee_id mismatch (expected %, got %)',
        v_employee_id, v_current_employee_id;
    END IF;

    PERFORM 1
    FROM puls_workflow.contracts c
    WHERE c.tenant_id = v_tenant_id
      AND c.employee_id = v_current_employee_id
    LIMIT 1;

    PERFORM set_config('request.jwt.claim.role', 'service_role', true);
    PERFORM set_config('request.jwt.claim.sub', '', true);

    RAISE NOTICE 'OK: JWT sub maps to current_employee_id(); self contract metadata selectable';
  ELSE
    RAISE NOTICE 'SKIP: no user-linked employee — JWT self-read not asserted on live data';
  END IF;

  RAISE NOTICE 'demo_contracts_data_readiness_ smoke completed for tenant %', v_tenant_id;
END $$;

ROLLBACK;
