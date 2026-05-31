-- PR13.7 — Canias connector readiness read-only validation.
-- Run after PR13.5 proof (03, 04, 07) and PR13.6 context check (08).
-- SELECT-only checks inside DO block. No auth schema user table or vault message dependency.

\set ON_ERROR_STOP on

DO $$
DECLARE
  v_tenant uuid := 'a0000001-0001-4001-8001-000000000001';
  v_count int;
  v_demo_count int;
BEGIN
  SELECT count(*) INTO v_count FROM puls_integration.erp_connections
  WHERE tenant_id = v_tenant AND provider = 'canias';
  IF v_count < 1 THEN RAISE EXCEPTION 'Canias erp_connections expected >=1, got %', v_count; END IF;

  SELECT count(*) INTO v_count FROM puls_integration.erp_connections
  WHERE tenant_id = v_tenant AND provider = 'canias' AND is_active = FALSE;
  IF v_count < 1 THEN RAISE EXCEPTION 'inactive Canias erp_connection expected >=1, got %', v_count; END IF;

  BEGIN
    SELECT count(*) INTO v_count FROM puls_integration.erp_connections
    WHERE tenant_id = v_tenant AND provider = 'canias' AND credentials_ref IS NOT NULL;
    IF v_count > 0 THEN RAISE EXCEPTION 'credentials_ref must be null on Canias connection, got % rows', v_count; END IF;
  EXCEPTION WHEN undefined_column THEN
    RAISE NOTICE 'SKIP: credentials_ref column absent — metadata-only posture assumed';
  END;

  SELECT count(*) INTO v_count FROM puls_integration.source_namespaces WHERE tenant_id = v_tenant;
  IF v_count < 1 THEN RAISE EXCEPTION 'source_namespaces expected >=1, got %', v_count; END IF;

  SELECT count(*) INTO v_count FROM puls_integration.erp_field_mappings WHERE tenant_id = v_tenant;
  IF v_count < 10 OR v_count > 15 THEN
    RAISE EXCEPTION 'erp_field_mappings expected 10-15, got %', v_count;
  END IF;

  SELECT count(*) INTO v_count FROM puls_integration.entity_identity_map WHERE tenant_id = v_tenant;
  IF v_count < 6 OR v_count > 15 THEN
    RAISE EXCEPTION 'entity_identity_map expected 6-15, got %', v_count;
  END IF;

  SELECT count(*) INTO v_count FROM puls_core.departments
  WHERE tenant_id = v_tenant AND lower(coalesce(external_source, '')) = 'canias';
  IF v_count < 1 THEN RAISE EXCEPTION 'imported canias departments expected >=1, got %', v_count; END IF;

  SELECT count(*) INTO v_count FROM puls_core.positions
  WHERE tenant_id = v_tenant AND lower(coalesce(external_source, '')) = 'canias';
  IF v_count < 1 THEN RAISE EXCEPTION 'imported canias positions expected >=1, got %', v_count; END IF;

  SELECT count(*) INTO v_count FROM puls_core.cost_centers
  WHERE tenant_id = v_tenant
    AND source_namespace_id IS NOT NULL
    AND NULLIF(BTRIM(external_id), '') IS NOT NULL;
  IF v_count < 1 THEN RAISE EXCEPTION 'cost_centers with namespace+external_id expected >=1, got %', v_count; END IF;

  SELECT
    (SELECT count(*) FROM puls_core.employee_reporting_lines WHERE tenant_id = v_tenant AND source = 'demo')
    + (SELECT count(*) FROM puls_core.employee_legal_entity_assignments WHERE tenant_id = v_tenant AND source = 'demo')
    + (SELECT count(*) FROM puls_core.employee_location_assignments WHERE tenant_id = v_tenant AND source = 'demo')
    + (SELECT count(*) FROM puls_core.employee_cost_center_assignments WHERE tenant_id = v_tenant AND source = 'demo')
  INTO v_demo_count;

  IF v_demo_count > 0 THEN
    RAISE EXCEPTION 'source=demo rows in assignment tables: %', v_demo_count;
  END IF;

  RAISE NOTICE 'OK: PR13.7 Canias connector readiness validation passed for tenant %', v_tenant;
END $$;
