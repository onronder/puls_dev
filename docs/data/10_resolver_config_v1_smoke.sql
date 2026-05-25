-- 10 PR10.2 Resolver Config V1 — executable smoke (single transaction; rolls back)

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_other_tenant_id UUID;
  v_requester_id UUID;
  v_manager_id UUID;
  v_hr_admin_id UUID;
  v_specific_id UUID;
  v_scoped_member_id UUID;
  v_tenant_member_id UUID;
  v_cc_owner_id UUID;
  v_legal_entity_id UUID;
  v_cost_center_id UUID;
  v_other_cc_id UUID;
  v_policy_id UUID;
  v_step_id UUID;
  v_approver UUID;
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

  SELECT id INTO v_other_tenant_id
  FROM puls_core.tenants
  WHERE id <> v_tenant_id
  LIMIT 1;

  SELECT id INTO v_requester_id
  FROM puls_core.employees
  WHERE tenant_id = v_tenant_id AND employment_status = 'active'
  ORDER BY full_name LIMIT 1;

  SELECT id INTO v_manager_id
  FROM puls_core.employees
  WHERE tenant_id = v_tenant_id AND employment_status = 'active' AND id <> v_requester_id
  ORDER BY full_name LIMIT 1;

  SELECT id INTO v_hr_admin_id
  FROM puls_core.employees
  WHERE tenant_id = v_tenant_id AND employment_status = 'active'
    AND persona_role = 'hr_admin'::puls_core.persona_role AND id <> v_requester_id
  LIMIT 1;

  SELECT id INTO v_specific_id
  FROM puls_core.employees
  WHERE tenant_id = v_tenant_id AND employment_status = 'active'
    AND id <> v_requester_id AND id IS DISTINCT FROM v_manager_id
  LIMIT 1;

  IF v_requester_id IS NULL OR v_manager_id IS NULL THEN
    RAISE NOTICE 'SKIP: insufficient demo employees';
    RETURN;
  END IF;

  SELECT id INTO v_scoped_member_id
  FROM puls_core.employees
  WHERE tenant_id = v_tenant_id AND employment_status = 'active' AND id <> v_requester_id
  ORDER BY full_name LIMIT 1;

  SELECT id INTO v_tenant_member_id
  FROM puls_core.employees
  WHERE tenant_id = v_tenant_id AND employment_status = 'active'
    AND id <> v_requester_id AND id IS DISTINCT FROM v_scoped_member_id
  ORDER BY full_name LIMIT 1;

  IF v_scoped_member_id IS NULL OR v_tenant_member_id IS NULL
     OR v_scoped_member_id = v_tenant_member_id THEN
    RAISE EXCEPTION 'SMOKE_SETUP_FAIL: need two distinct employees for pool tests';
  END IF;

  v_cc_owner_id := v_manager_id;

  INSERT INTO puls_core.legal_entities (tenant_id, code, name)
  VALUES (v_tenant_id, 'smoke_rc10_le', 'Smoke RC10 LE')
  ON CONFLICT (tenant_id, code) DO UPDATE SET is_active = TRUE
  RETURNING id INTO v_legal_entity_id;

  IF v_legal_entity_id IS NULL THEN
    SELECT id INTO v_legal_entity_id FROM puls_core.legal_entities
    WHERE tenant_id = v_tenant_id AND code = 'smoke_rc10_le';
  END IF;

  INSERT INTO puls_core.cost_centers (tenant_id, legal_entity_id, code, name)
  VALUES (v_tenant_id, v_legal_entity_id, 'smoke_rc10_cc', 'Smoke RC10 CC')
  ON CONFLICT (tenant_id, code) DO UPDATE SET is_active = TRUE
  RETURNING id INTO v_cost_center_id;

  IF v_cost_center_id IS NULL THEN
    SELECT id INTO v_cost_center_id FROM puls_core.cost_centers
    WHERE tenant_id = v_tenant_id AND code = 'smoke_rc10_cc';
  END IF;

  IF v_other_tenant_id IS NOT NULL THEN
    INSERT INTO puls_core.legal_entities (tenant_id, code, name)
    VALUES (v_other_tenant_id, 'smoke_rc10_other_le', 'Other LE')
    ON CONFLICT (tenant_id, code) DO NOTHING;

    INSERT INTO puls_core.cost_centers (tenant_id, legal_entity_id, code, name, is_active)
    SELECT v_other_tenant_id, le.id, 'smoke_rc10_other_cc', 'Other CC', TRUE
    FROM puls_core.legal_entities le
    WHERE le.tenant_id = v_other_tenant_id AND le.code = 'smoke_rc10_other_le'
    ON CONFLICT (tenant_id, code) DO UPDATE SET is_active = TRUE;

    SELECT cc.id INTO v_other_cc_id
    FROM puls_core.cost_centers cc
    WHERE cc.tenant_id = v_other_tenant_id AND cc.code = 'smoke_rc10_other_cc';
  END IF;

  UPDATE puls_core.employee_cost_center_assignments
  SET is_active = FALSE, ends_on = COALESCE(ends_on, CURRENT_DATE), updated_at = NOW()
  WHERE tenant_id = v_tenant_id AND employee_id = v_requester_id AND is_active = TRUE;

  INSERT INTO puls_core.employee_cost_center_assignments (
    tenant_id, employee_id, cost_center_id, is_active, source
  ) VALUES (v_tenant_id, v_requester_id, v_cost_center_id, TRUE, 'manual');

  PERFORM puls_core.upsert_primary_reporting_line(v_tenant_id, v_requester_id, v_manager_id, 'demo');

  INSERT INTO puls_core.authority_pools (
    tenant_id, code, name, pool_type, module, scope_type, scope_id, priority
  ) VALUES (
    v_tenant_id, 'smoke_rc10_fin_tenant', 'RC10 Tenant Finance', 'finance', 'expense', 'tenant', NULL, 1
  ) ON CONFLICT (tenant_id, code) DO UPDATE SET is_active = TRUE, pool_type = 'finance', module = 'expense';

  INSERT INTO puls_core.authority_pools (
    tenant_id, code, name, pool_type, module, scope_type, scope_id, priority
  ) VALUES (
    v_tenant_id, 'smoke_rc10_fin_scoped', 'RC10 Scoped Finance', 'finance', 'expense',
    'cost_center', v_cost_center_id, 10
  ) ON CONFLICT (tenant_id, code) DO UPDATE
    SET is_active = TRUE, scope_type = 'cost_center', scope_id = v_cost_center_id;

  INSERT INTO puls_core.authority_pool_members (tenant_id, pool_id, employee_id, is_active, priority)
  SELECT v_tenant_id, p.id, v_tenant_member_id, TRUE, 1
  FROM puls_core.authority_pools p WHERE p.code = 'smoke_rc10_fin_tenant'
  ON CONFLICT DO NOTHING;

  UPDATE puls_core.authority_pool_members m SET is_active = TRUE
  FROM puls_core.authority_pools p
  WHERE m.pool_id = p.id AND p.code = 'smoke_rc10_fin_tenant' AND m.employee_id = v_tenant_member_id;

  INSERT INTO puls_core.authority_pool_members (tenant_id, pool_id, employee_id, is_active, priority)
  SELECT v_tenant_id, p.id, v_scoped_member_id, TRUE, 1
  FROM puls_core.authority_pools p WHERE p.code = 'smoke_rc10_fin_scoped'
  ON CONFLICT DO NOTHING;

  UPDATE puls_core.authority_pool_members m SET is_active = TRUE
  FROM puls_core.authority_pools p
  WHERE m.pool_id = p.id AND p.code = 'smoke_rc10_fin_scoped' AND m.employee_id = v_scoped_member_id;

  INSERT INTO puls_core.authority_relationships (
    tenant_id, authority_type, subject_employee_id, module, scope_type, scope_id, is_active
  ) VALUES (
    v_tenant_id, 'cost_center_owner', v_cc_owner_id, 'global', 'cost_center', v_cost_center_id, TRUE
  ) ON CONFLICT DO NOTHING;

  DELETE FROM puls_core.authority_relationships ar
  WHERE ar.tenant_id = v_tenant_id
    AND ar.authority_type = 'cost_center_owner'::puls_core.authority_type
    AND ar.scope_id = v_cost_center_id
    AND ar.subject_employee_id <> v_cc_owner_id;

  INSERT INTO puls_workflow.approval_policies (tenant_id, code, name, module)
  VALUES (v_tenant_id, 'smoke_rc10_fin', 'Smoke RC10 Finance', 'expense')
  ON CONFLICT (tenant_id, code) DO UPDATE SET is_active = TRUE;

  SELECT id INTO v_policy_id FROM puls_workflow.approval_policies
  WHERE tenant_id = v_tenant_id AND code = 'smoke_rc10_fin';

  DELETE FROM puls_workflow.approval_policy_steps WHERE policy_id = v_policy_id;

  INSERT INTO puls_workflow.approval_policy_steps (
    tenant_id, policy_id, step_order, approver_type, is_required, step_resolver_config
  ) VALUES (v_tenant_id, v_policy_id, 1, 'finance_pool', TRUE, NULL)
  RETURNING id INTO v_step_id;

  -- NULL config: scoped pool precedence (PR5 regression)
  SELECT puls_workflow.resolve_policy_step_approver(
    v_tenant_id, v_requester_id, 'expense', v_policy_id, 1
  ) INTO v_approver;

  IF v_approver IS DISTINCT FROM v_scoped_member_id THEN
    RAISE EXCEPTION 'SMOKE_FAIL: NULL config expected scoped member %, got %', v_scoped_member_id, v_approver;
  END IF;

  -- tenant override
  UPDATE puls_workflow.approval_policy_steps
  SET step_resolver_config = '{"scope_strategy":"tenant"}'::jsonb
  WHERE id = v_step_id;

  SELECT puls_workflow.resolve_policy_step_approver(
    v_tenant_id, v_requester_id, 'expense', v_policy_id, 1
  ) INTO v_approver;

  IF v_approver IS DISTINCT FROM v_tenant_member_id THEN
    RAISE EXCEPTION 'SMOKE_FAIL: tenant strategy expected tenant member %, got %', v_tenant_member_id, v_approver;
  END IF;

  -- no-fallback: inactive scoped member
  UPDATE puls_core.authority_pool_members m SET is_active = FALSE
  FROM puls_core.authority_pools p
  WHERE m.pool_id = p.id AND p.code = 'smoke_rc10_fin_scoped';

  UPDATE puls_workflow.approval_policy_steps
  SET step_resolver_config = jsonb_build_object(
    'scope_strategy', 'requester_cost_center',
    'allow_tenant_fallback', false
  )
  WHERE id = v_step_id;

  SELECT puls_workflow.resolve_policy_step_approver(
    v_tenant_id, v_requester_id, 'expense', v_policy_id, 1
  ) INTO v_approver;

  IF v_approver IS NOT NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL: no-fallback with inactive scoped member must resolve NULL, got %', v_approver;
  END IF;

  UPDATE puls_core.authority_pool_members m SET is_active = TRUE
  FROM puls_core.authority_pools p
  WHERE m.pool_id = p.id AND p.code = 'smoke_rc10_fin_scoped';

  -- explicit scope_code
  UPDATE puls_workflow.approval_policy_steps
  SET step_resolver_config = jsonb_build_object(
    'scope_strategy', 'explicit',
    'scope_type', 'cost_center',
    'scope_code', 'smoke_rc10_cc'
  )
  WHERE id = v_step_id;

  SELECT puls_workflow.resolve_policy_step_approver(
    v_tenant_id, v_requester_id, 'expense', v_policy_id, 1
  ) INTO v_approver;

  IF v_approver IS DISTINCT FROM v_scoped_member_id THEN
    RAISE EXCEPTION 'SMOKE_FAIL: explicit scope_code expected scoped member %, got %', v_scoped_member_id, v_approver;
  END IF;

  -- cost_center_owner + tenant strategy → NULL
  UPDATE puls_workflow.approval_policy_steps
  SET approver_type = 'cost_center_owner'::puls_workflow.approver_type,
      step_resolver_config = '{"scope_strategy":"tenant"}'::jsonb
  WHERE id = v_step_id;

  SELECT puls_workflow.resolve_policy_step_approver(
    v_tenant_id, v_requester_id, 'expense', v_policy_id, 1
  ) INTO v_approver;

  IF v_approver IS NOT NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL: cost_center_owner with tenant strategy must be NULL, got %', v_approver;
  END IF;

  -- explicit cost_center_owner
  UPDATE puls_workflow.approval_policy_steps
  SET step_resolver_config = jsonb_build_object(
    'scope_strategy', 'explicit',
    'scope_type', 'cost_center',
    'scope_code', 'smoke_rc10_cc'
  )
  WHERE id = v_step_id;

  SELECT puls_workflow.resolve_policy_step_approver(
    v_tenant_id, v_requester_id, 'expense', v_policy_id, 1
  ) INTO v_approver;

  IF v_approver IS DISTINCT FROM v_cc_owner_id THEN
    RAISE EXCEPTION 'SMOKE_FAIL: explicit owner expected %, got %', v_cc_owner_id, v_approver;
  END IF;

  -- valid config + unrelated column update passes
  UPDATE puls_workflow.approval_policy_steps
  SET step_resolver_config = '{}'::jsonb,
      approver_type = 'finance_pool'::puls_workflow.approver_type
  WHERE id = v_step_id;

  -- invalid JSON types on write
  BEGIN
    UPDATE puls_workflow.approval_policy_steps
    SET step_resolver_config = '{"scope_id":123}'::jsonb
    WHERE id = v_step_id;
    RAISE EXCEPTION 'SMOKE_FAIL: numeric scope_id should be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%PULS_POLICY_STEP_RESOLVER_CONFIG%' THEN RAISE; END IF;
  END;

  BEGIN
    UPDATE puls_workflow.approval_policy_steps
    SET step_resolver_config = '{"allow_tenant_fallback":"false"}'::jsonb
    WHERE id = v_step_id;
    RAISE EXCEPTION 'SMOKE_FAIL: string allow_tenant_fallback should be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%PULS_POLICY_STEP_RESOLVER_CONFIG%' THEN RAISE; END IF;
  END;

  BEGIN
    UPDATE puls_workflow.approval_policy_steps
    SET step_resolver_config = '{"scope_strategy":"not_a_strategy"}'::jsonb
    WHERE id = v_step_id;
    RAISE EXCEPTION 'SMOKE_FAIL: invalid scope_strategy should be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%PULS_POLICY_STEP_RESOLVER_CONFIG%' THEN RAISE; END IF;
  END;

  IF v_other_cc_id IS NOT NULL THEN
    BEGIN
      UPDATE puls_workflow.approval_policy_steps
      SET step_resolver_config = jsonb_build_object(
        'scope_strategy', 'explicit',
        'scope_type', 'cost_center',
        'scope_id', v_other_cc_id::text
      )
      WHERE id = v_step_id;
      RAISE EXCEPTION 'SMOKE_FAIL: cross-tenant scope_id should be rejected';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_POLICY_STEP_RESOLVER_CONFIG_INVALID_SCOPE_TARGET%' THEN RAISE; END IF;
    END;
  END IF;

  BEGIN
    UPDATE puls_workflow.approval_policy_steps
    SET step_condition_config = '{"min_amount":100}'::jsonb
    WHERE id = v_step_id;
    RAISE EXCEPTION 'SMOKE_FAIL: step_condition_config key should be rejected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%PULS_POLICY_STEP_CONFIG_UNKNOWN_FIELD%' THEN RAISE; END IF;
  END;

  -- manager regression NULL config
  INSERT INTO puls_workflow.approval_policies (tenant_id, code, name, module)
  VALUES (v_tenant_id, 'smoke_rc10_mgr', 'Smoke RC10 Manager', 'leave')
  ON CONFLICT (tenant_id, code) DO UPDATE SET is_active = TRUE;

  SELECT id INTO v_policy_id FROM puls_workflow.approval_policies
  WHERE tenant_id = v_tenant_id AND code = 'smoke_rc10_mgr';

  DELETE FROM puls_workflow.approval_policy_steps WHERE policy_id = v_policy_id;
  INSERT INTO puls_workflow.approval_policy_steps (
    tenant_id, policy_id, step_order, approver_type, is_required
  ) VALUES (v_tenant_id, v_policy_id, 1, 'manager', TRUE);

  SELECT puls_workflow.resolve_policy_step_approver(
    v_tenant_id, v_requester_id, 'leave', v_policy_id, 1
  ) INTO v_approver;

  IF v_approver IS DISTINCT FROM v_manager_id THEN
    RAISE EXCEPTION 'SMOKE_FAIL: manager regression expected %, got %', v_manager_id, v_approver;
  END IF;

  RAISE NOTICE '10 PR10.2 resolver config V1 smoke passed';
  PERFORM set_config('request.jwt.claim.role', '', true);
END $$;

ROLLBACK;
