-- 09 PR5 Resolver V3 — executable smoke (single transaction; rolls back)
-- Run after supabase db push through 20260525163000 on staging.
-- decide_approval_request is NOT modified by PR5; this smoke calls resolve_policy_step_approver directly.

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_requester_id UUID;
  v_manager_id UUID;
  v_hr_admin_id UUID;
  v_specific_id UUID;
  v_finance_member_id UUID;
  v_hr_member_id UUID;
  v_legal_member_id UUID;
  v_cc_owner_id UUID;
  v_scoped_member_id UUID;
  v_tenant_member_id UUID;
  v_legal_entity_id UUID;
  v_cost_center_id UUID;
  v_policy_id UUID;
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

  SELECT id INTO v_requester_id
  FROM puls_core.employees
  WHERE tenant_id = v_tenant_id
    AND employment_status = 'active'
  ORDER BY full_name
  LIMIT 1;

  SELECT id INTO v_manager_id
  FROM puls_core.employees
  WHERE tenant_id = v_tenant_id
    AND employment_status = 'active'
    AND id <> v_requester_id
  ORDER BY full_name
  LIMIT 1;

  SELECT id INTO v_hr_admin_id
  FROM puls_core.employees
  WHERE tenant_id = v_tenant_id
    AND employment_status = 'active'
    AND persona_role = 'hr_admin'::puls_core.persona_role
    AND id <> v_requester_id
  LIMIT 1;

  SELECT id INTO v_specific_id
  FROM puls_core.employees
  WHERE tenant_id = v_tenant_id
    AND employment_status = 'active'
    AND id <> v_requester_id
    AND id IS DISTINCT FROM v_manager_id
  LIMIT 1;

  IF v_requester_id IS NULL OR v_manager_id IS NULL THEN
    RAISE NOTICE 'SKIP: insufficient demo employees';
    RETURN;
  END IF;

  v_finance_member_id := COALESCE(v_specific_id, v_manager_id);
  v_hr_member_id := COALESCE(v_hr_admin_id, v_manager_id);
  v_legal_member_id := v_manager_id;
  v_cc_owner_id := v_manager_id;
  v_scoped_member_id := v_finance_member_id;
  v_tenant_member_id := CASE
    WHEN v_finance_member_id IS DISTINCT FROM v_hr_member_id THEN v_hr_member_id
    ELSE v_manager_id
  END;

  INSERT INTO puls_core.legal_entities (tenant_id, code, name)
  VALUES (v_tenant_id, 'smoke_rv3_le', 'Smoke Resolver LE')
  ON CONFLICT (tenant_id, code) DO UPDATE SET is_active = TRUE
  RETURNING id INTO v_legal_entity_id;

  IF v_legal_entity_id IS NULL THEN
    SELECT id INTO v_legal_entity_id
    FROM puls_core.legal_entities
    WHERE tenant_id = v_tenant_id AND code = 'smoke_rv3_le';
  END IF;

  INSERT INTO puls_core.cost_centers (tenant_id, legal_entity_id, code, name)
  VALUES (v_tenant_id, v_legal_entity_id, 'smoke_rv3_cc', 'Smoke Resolver CC')
  ON CONFLICT (tenant_id, code) DO UPDATE SET is_active = TRUE
  RETURNING id INTO v_cost_center_id;

  IF v_cost_center_id IS NULL THEN
    SELECT id INTO v_cost_center_id
    FROM puls_core.cost_centers
    WHERE tenant_id = v_tenant_id AND code = 'smoke_rv3_cc';
  END IF;

  UPDATE puls_core.employee_cost_center_assignments
  SET is_active = FALSE, ends_on = COALESCE(ends_on, CURRENT_DATE), updated_at = NOW()
  WHERE tenant_id = v_tenant_id AND employee_id = v_requester_id AND is_active = TRUE;

  INSERT INTO puls_core.employee_cost_center_assignments (
    tenant_id, employee_id, cost_center_id, is_active, source
  ) VALUES (v_tenant_id, v_requester_id, v_cost_center_id, TRUE, 'manual');

  -- Reporting line for manager regression
  PERFORM puls_core.upsert_primary_reporting_line(
    v_tenant_id, v_requester_id, v_manager_id, 'demo'
  );

  -- Finance pools: tenant (priority 1) vs scoped (priority 10) — scoped pool precedence
  INSERT INTO puls_core.authority_pools (
    tenant_id, code, name, pool_type, module, scope_type, scope_id, priority
  )
  VALUES (
    v_tenant_id, 'smoke_rv3_fin_tenant', 'RV3 Tenant Finance', 'finance', 'expense', 'tenant', NULL, 1
  )
  ON CONFLICT (tenant_id, code) DO UPDATE
    SET is_active = TRUE, priority = 1, pool_type = 'finance', module = 'expense';

  INSERT INTO puls_core.authority_pools (
    tenant_id, code, name, pool_type, module, scope_type, scope_id, priority
  )
  VALUES (
    v_tenant_id, 'smoke_rv3_fin_scoped', 'RV3 Scoped Finance', 'finance', 'expense',
    'cost_center', v_cost_center_id, 10
  )
  ON CONFLICT (tenant_id, code) DO UPDATE
    SET is_active = TRUE, priority = 10, scope_type = 'cost_center', scope_id = v_cost_center_id;

  INSERT INTO puls_core.authority_pool_members (tenant_id, pool_id, employee_id, is_active, priority)
  SELECT v_tenant_id, p.id, v_tenant_member_id, TRUE, 1
  FROM puls_core.authority_pools p
  WHERE p.tenant_id = v_tenant_id AND p.code = 'smoke_rv3_fin_tenant'
  ON CONFLICT DO NOTHING;

  UPDATE puls_core.authority_pool_members m
  SET is_active = TRUE, priority = 1
  FROM puls_core.authority_pools p
  WHERE m.pool_id = p.id
    AND p.code = 'smoke_rv3_fin_tenant'
    AND m.employee_id = v_tenant_member_id;

  INSERT INTO puls_core.authority_pool_members (tenant_id, pool_id, employee_id, is_active, priority)
  SELECT v_tenant_id, p.id, v_scoped_member_id, TRUE, 1
  FROM puls_core.authority_pools p
  WHERE p.tenant_id = v_tenant_id AND p.code = 'smoke_rv3_fin_scoped'
  ON CONFLICT DO NOTHING;

  UPDATE puls_core.authority_pool_members m
  SET is_active = TRUE, priority = 1
  FROM puls_core.authority_pools p
  WHERE m.pool_id = p.id
    AND p.code = 'smoke_rv3_fin_scoped'
    AND m.employee_id = v_scoped_member_id;

  -- HR pool (leave)
  INSERT INTO puls_core.authority_pools (
    tenant_id, code, name, pool_type, module, scope_type, priority
  )
  VALUES (v_tenant_id, 'smoke_rv3_hr', 'RV3 HR Pool', 'hr', 'leave', 'tenant', 100)
  ON CONFLICT (tenant_id, code) DO UPDATE SET is_active = TRUE, pool_type = 'hr', module = 'leave';

  INSERT INTO puls_core.authority_pool_members (tenant_id, pool_id, employee_id, is_active)
  SELECT v_tenant_id, p.id, v_hr_member_id, TRUE
  FROM puls_core.authority_pools p
  WHERE p.tenant_id = v_tenant_id AND p.code = 'smoke_rv3_hr'
  ON CONFLICT DO NOTHING;

  UPDATE puls_core.authority_pool_members m
  SET is_active = TRUE
  FROM puls_core.authority_pools p
  WHERE m.pool_id = p.id AND p.code = 'smoke_rv3_hr' AND m.employee_id = v_hr_member_id;

  -- Legal pool (tenant)
  INSERT INTO puls_core.authority_pools (
    tenant_id, code, name, pool_type, module, scope_type, priority
  )
  VALUES (v_tenant_id, 'smoke_rv3_legal', 'RV3 Legal Pool', 'legal', 'global', 'tenant', 100)
  ON CONFLICT (tenant_id, code) DO UPDATE SET is_active = TRUE, pool_type = 'legal';

  INSERT INTO puls_core.authority_pool_members (tenant_id, pool_id, employee_id, is_active)
  SELECT v_tenant_id, p.id, v_legal_member_id, TRUE
  FROM puls_core.authority_pools p
  WHERE p.tenant_id = v_tenant_id AND p.code = 'smoke_rv3_legal'
  ON CONFLICT DO NOTHING;

  -- cost_center_owner relationship
  INSERT INTO puls_core.authority_relationships (
    tenant_id, authority_type, subject_employee_id, module, scope_type, scope_id, is_active
  )
  VALUES (
    v_tenant_id, 'cost_center_owner', v_cc_owner_id, 'global', 'cost_center', v_cost_center_id, TRUE
  )
  ON CONFLICT DO NOTHING;

  DELETE FROM puls_core.authority_relationships ar
  WHERE ar.tenant_id = v_tenant_id
    AND ar.authority_type = 'cost_center_owner'::puls_core.authority_type
    AND ar.scope_id = v_cost_center_id
    AND ar.subject_employee_id <> v_cc_owner_id;

  -- Helper: create smoke policy + step
  CREATE TEMP TABLE IF NOT EXISTS _rv3_policies (
    code TEXT PRIMARY KEY,
    module puls_workflow.approval_module,
    approver_type puls_workflow.approver_type,
    specific_employee_id UUID
  ) ON COMMIT DROP;

  TRUNCATE _rv3_policies;

  INSERT INTO _rv3_policies (code, module, approver_type, specific_employee_id) VALUES
    ('smoke_rv3_mgr', 'leave', 'manager', NULL),
    ('smoke_rv3_hr', 'leave', 'hr_admin', NULL),
    ('smoke_rv3_spec', 'leave', 'specific_employee', v_specific_id),
    ('smoke_rv3_fin', 'expense', 'finance_pool', NULL),
    ('smoke_rv3_hr_pool', 'leave', 'hr_pool', NULL),
    ('smoke_rv3_legal', 'leave', 'legal_pool', NULL),
    ('smoke_rv3_cco', 'expense', 'cost_center_owner', NULL);

  -- manager regression
  INSERT INTO puls_workflow.approval_policies (tenant_id, code, name, module)
  VALUES (v_tenant_id, 'smoke_rv3_mgr', 'Smoke RV3 Manager', 'leave')
  ON CONFLICT (tenant_id, code) DO UPDATE SET is_active = TRUE
  RETURNING id INTO v_policy_id;

  SELECT id INTO v_policy_id FROM puls_workflow.approval_policies
  WHERE tenant_id = v_tenant_id AND code = 'smoke_rv3_mgr';

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

  -- hr_admin regression
  IF v_hr_admin_id IS NOT NULL THEN
    INSERT INTO puls_workflow.approval_policies (tenant_id, code, name, module)
    VALUES (v_tenant_id, 'smoke_rv3_hr', 'Smoke RV3 HR Admin', 'leave')
    ON CONFLICT (tenant_id, code) DO UPDATE SET is_active = TRUE;

    SELECT id INTO v_policy_id FROM puls_workflow.approval_policies
    WHERE tenant_id = v_tenant_id AND code = 'smoke_rv3_hr';

    DELETE FROM puls_workflow.approval_policy_steps WHERE policy_id = v_policy_id;
    INSERT INTO puls_workflow.approval_policy_steps (
      tenant_id, policy_id, step_order, approver_type, is_required
    ) VALUES (v_tenant_id, v_policy_id, 1, 'hr_admin', TRUE);

    SELECT puls_workflow.resolve_policy_step_approver(
      v_tenant_id, v_requester_id, 'leave', v_policy_id, 1
    ) INTO v_approver;

    IF v_approver IS DISTINCT FROM v_hr_admin_id THEN
      RAISE EXCEPTION 'SMOKE_FAIL: hr_admin regression expected %, got %', v_hr_admin_id, v_approver;
    END IF;
  END IF;

  -- specific_employee regression
  IF v_specific_id IS NOT NULL THEN
    INSERT INTO puls_workflow.approval_policies (tenant_id, code, name, module)
    VALUES (v_tenant_id, 'smoke_rv3_spec', 'Smoke RV3 Specific', 'leave')
    ON CONFLICT (tenant_id, code) DO UPDATE SET is_active = TRUE;

    SELECT id INTO v_policy_id FROM puls_workflow.approval_policies
    WHERE tenant_id = v_tenant_id AND code = 'smoke_rv3_spec';

    DELETE FROM puls_workflow.approval_policy_steps WHERE policy_id = v_policy_id;
    INSERT INTO puls_workflow.approval_policy_steps (
      tenant_id, policy_id, step_order, approver_type, specific_employee_id, is_required
    ) VALUES (v_tenant_id, v_policy_id, 1, 'specific_employee', v_specific_id, TRUE);

    SELECT puls_workflow.resolve_policy_step_approver(
      v_tenant_id, v_requester_id, 'leave', v_policy_id, 1
    ) INTO v_approver;

    IF v_approver IS DISTINCT FROM v_specific_id THEN
      RAISE EXCEPTION 'SMOKE_FAIL: specific_employee regression expected %, got %', v_specific_id, v_approver;
    END IF;
  END IF;

  -- finance_pool + scoped pool precedence
  INSERT INTO puls_workflow.approval_policies (tenant_id, code, name, module)
  VALUES (v_tenant_id, 'smoke_rv3_fin', 'Smoke RV3 Finance Pool', 'expense')
  ON CONFLICT (tenant_id, code) DO UPDATE SET is_active = TRUE;

  SELECT id INTO v_policy_id FROM puls_workflow.approval_policies
  WHERE tenant_id = v_tenant_id AND code = 'smoke_rv3_fin';

  DELETE FROM puls_workflow.approval_policy_steps WHERE policy_id = v_policy_id;
  INSERT INTO puls_workflow.approval_policy_steps (
    tenant_id, policy_id, step_order, approver_type, is_required
  ) VALUES (v_tenant_id, v_policy_id, 1, 'finance_pool', TRUE);

  SELECT puls_workflow.resolve_policy_step_approver(
    v_tenant_id, v_requester_id, 'expense', v_policy_id, 1
  ) INTO v_approver;

  IF v_approver IS DISTINCT FROM v_scoped_member_id THEN
    RAISE EXCEPTION 'SMOKE_FAIL: scoped pool precedence expected scoped member %, got %',
      v_scoped_member_id, v_approver;
  END IF;

  -- hr_pool leave
  INSERT INTO puls_workflow.approval_policies (tenant_id, code, name, module)
  VALUES (v_tenant_id, 'smoke_rv3_hr_pool', 'Smoke RV3 HR Pool', 'leave')
  ON CONFLICT (tenant_id, code) DO UPDATE SET is_active = TRUE;

  SELECT id INTO v_policy_id FROM puls_workflow.approval_policies
  WHERE tenant_id = v_tenant_id AND code = 'smoke_rv3_hr_pool';

  DELETE FROM puls_workflow.approval_policy_steps WHERE policy_id = v_policy_id;
  INSERT INTO puls_workflow.approval_policy_steps (
    tenant_id, policy_id, step_order, approver_type, is_required
  ) VALUES (v_tenant_id, v_policy_id, 1, 'hr_pool', TRUE);

  SELECT puls_workflow.resolve_policy_step_approver(
    v_tenant_id, v_requester_id, 'leave', v_policy_id, 1
  ) INTO v_approver;

  IF v_approver IS DISTINCT FROM v_hr_member_id THEN
    RAISE EXCEPTION 'SMOKE_FAIL: hr_pool expected %, got %', v_hr_member_id, v_approver;
  END IF;

  -- legal_pool
  INSERT INTO puls_workflow.approval_policies (tenant_id, code, name, module)
  VALUES (v_tenant_id, 'smoke_rv3_legal', 'Smoke RV3 Legal Pool', 'leave')
  ON CONFLICT (tenant_id, code) DO UPDATE SET is_active = TRUE;

  SELECT id INTO v_policy_id FROM puls_workflow.approval_policies
  WHERE tenant_id = v_tenant_id AND code = 'smoke_rv3_legal';

  DELETE FROM puls_workflow.approval_policy_steps WHERE policy_id = v_policy_id;
  INSERT INTO puls_workflow.approval_policy_steps (
    tenant_id, policy_id, step_order, approver_type, is_required
  ) VALUES (v_tenant_id, v_policy_id, 1, 'legal_pool', TRUE);

  SELECT puls_workflow.resolve_policy_step_approver(
    v_tenant_id, v_requester_id, 'leave', v_policy_id, 1
  ) INTO v_approver;

  IF v_approver IS DISTINCT FROM v_legal_member_id THEN
    RAISE EXCEPTION 'SMOKE_FAIL: legal_pool expected %, got %', v_legal_member_id, v_approver;
  END IF;

  -- cost_center_owner expense
  INSERT INTO puls_workflow.approval_policies (tenant_id, code, name, module)
  VALUES (v_tenant_id, 'smoke_rv3_cco', 'Smoke RV3 CC Owner', 'expense')
  ON CONFLICT (tenant_id, code) DO UPDATE SET is_active = TRUE;

  SELECT id INTO v_policy_id FROM puls_workflow.approval_policies
  WHERE tenant_id = v_tenant_id AND code = 'smoke_rv3_cco';

  DELETE FROM puls_workflow.approval_policy_steps WHERE policy_id = v_policy_id;
  INSERT INTO puls_workflow.approval_policy_steps (
    tenant_id, policy_id, step_order, approver_type, is_required
  ) VALUES (v_tenant_id, v_policy_id, 1, 'cost_center_owner', TRUE);

  SELECT puls_workflow.resolve_policy_step_approver(
    v_tenant_id, v_requester_id, 'expense', v_policy_id, 1
  ) INTO v_approver;

  IF v_approver IS DISTINCT FROM v_cc_owner_id THEN
    RAISE EXCEPTION 'SMOKE_FAIL: cost_center_owner expected %, got %', v_cc_owner_id, v_approver;
  END IF;

  -- Self approver excluded (requester is only pool member)
  UPDATE puls_core.authority_pool_members m
  SET is_active = FALSE
  FROM puls_core.authority_pools p
  WHERE m.pool_id = p.id AND p.code = 'smoke_rv3_hr_pool';

  INSERT INTO puls_core.authority_pool_members (tenant_id, pool_id, employee_id, is_active)
  SELECT v_tenant_id, p.id, v_requester_id, TRUE
  FROM puls_core.authority_pools p
  WHERE p.tenant_id = v_tenant_id AND p.code = 'smoke_rv3_hr_pool';

  SELECT puls_workflow.resolve_policy_step_approver(
    v_tenant_id, v_requester_id, 'leave', v_policy_id, 1
  ) INTO v_approver;

  IF v_approver IS NOT NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL: self approver must resolve to NULL, got %', v_approver;
  END IF;

  -- inactive pool member → unresolved
  UPDATE puls_core.authority_pool_members m
  SET is_active = FALSE
  FROM puls_core.authority_pools p
  WHERE m.pool_id = p.id AND p.code = 'smoke_rv3_legal';

  SELECT id INTO v_policy_id FROM puls_workflow.approval_policies
  WHERE tenant_id = v_tenant_id AND code = 'smoke_rv3_legal';

  SELECT puls_workflow.resolve_policy_step_approver(
    v_tenant_id, v_requester_id, 'leave', v_policy_id, 1
  ) INTO v_approver;

  IF v_approver IS NOT NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL: inactive pool member must resolve to NULL';
  END IF;

  -- inactive cost_center_owner subject → unresolved
  UPDATE puls_core.employees
  SET employment_status = 'inactive'::puls_core.employment_status
  WHERE id = v_cc_owner_id;

  SELECT id INTO v_policy_id FROM puls_workflow.approval_policies
  WHERE tenant_id = v_tenant_id AND code = 'smoke_rv3_cco';

  SELECT puls_workflow.resolve_policy_step_approver(
    v_tenant_id, v_requester_id, 'expense', v_policy_id, 1
  ) INTO v_approver;

  IF v_approver IS NOT NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL: inactive cost_center_owner must resolve to NULL';
  END IF;

  RAISE NOTICE '09 PR5 resolver V3 smoke passed';

  PERFORM set_config('request.jwt.claim.role', '', true);
END $$;

ROLLBACK;
