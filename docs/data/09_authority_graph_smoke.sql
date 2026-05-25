-- 09 PR3 Authority Graph — executable smoke (rolls back)
-- Run after supabase db push through 20260525153000 on staging.

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_other_tenant_id UUID;
  v_employee_id UUID;
  v_other_employee_id UUID;
  v_inactive_employee_id UUID;
  v_auth_user_id UUID;
  v_legal_entity_id UUID;
  v_cost_center_id UUID;
  v_inactive_cc_id UUID;
  v_other_cc_id UUID;
  v_pool_id UUID;
  v_member_id UUID;
  v_rel_id UUID;
  v_forbidden_count INTEGER;
  v_helper_ok BOOLEAN;
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

  SELECT id, user_id
  INTO v_employee_id, v_auth_user_id
  FROM puls_core.employees
  WHERE tenant_id = v_tenant_id
    AND employment_status = 'active'
    AND user_id IS NOT NULL
  ORDER BY full_name
  LIMIT 1;

  IF v_employee_id IS NULL THEN
    SELECT id INTO v_employee_id
    FROM puls_core.employees
    WHERE tenant_id = v_tenant_id
      AND employment_status = 'active'
    ORDER BY full_name
    LIMIT 1;
  END IF;

  IF v_employee_id IS NULL THEN
    RAISE NOTICE 'SKIP: no active employee in demo tenant';
    RETURN;
  END IF;

  SELECT id INTO v_other_employee_id
  FROM puls_core.employees
  WHERE tenant_id = v_tenant_id
    AND employment_status = 'active'
    AND id <> v_employee_id
  LIMIT 1;

  -- Minimal enterprise dimensions for scope targets
  INSERT INTO puls_core.legal_entities (tenant_id, code, name)
  VALUES (v_tenant_id, 'smoke_auth_le', 'Smoke Auth Legal Entity')
  ON CONFLICT (tenant_id, code) DO UPDATE SET is_active = TRUE
  RETURNING id INTO v_legal_entity_id;

  IF v_legal_entity_id IS NULL THEN
    SELECT id INTO v_legal_entity_id
    FROM puls_core.legal_entities
    WHERE tenant_id = v_tenant_id AND code = 'smoke_auth_le';
  END IF;

  INSERT INTO puls_core.cost_centers (tenant_id, legal_entity_id, code, name)
  VALUES (v_tenant_id, v_legal_entity_id, 'smoke_auth_cc', 'Smoke Auth Cost Center')
  ON CONFLICT (tenant_id, code) DO UPDATE SET is_active = TRUE
  RETURNING id INTO v_cost_center_id;

  IF v_cost_center_id IS NULL THEN
    SELECT id INTO v_cost_center_id
    FROM puls_core.cost_centers
    WHERE tenant_id = v_tenant_id AND code = 'smoke_auth_cc';
  END IF;

  INSERT INTO puls_core.cost_centers (tenant_id, legal_entity_id, code, name, is_active)
  VALUES (v_tenant_id, v_legal_entity_id, 'smoke_auth_cc_inactive', 'Inactive CC', FALSE)
  ON CONFLICT (tenant_id, code) DO UPDATE SET is_active = FALSE
  RETURNING id INTO v_inactive_cc_id;

  IF v_inactive_cc_id IS NULL THEN
    SELECT id INTO v_inactive_cc_id
    FROM puls_core.cost_centers
    WHERE tenant_id = v_tenant_id AND code = 'smoke_auth_cc_inactive';
  END IF;

  -- Happy path: tenant-scoped finance pool + member
  INSERT INTO puls_core.authority_pools (
    tenant_id, code, name, pool_type, module, scope_type, scope_id
  ) VALUES (
    v_tenant_id, 'smoke_finance_pool', 'Smoke Finance Pool', 'finance', 'expense', 'tenant', NULL
  )
  ON CONFLICT (tenant_id, code) DO UPDATE
    SET is_active = TRUE, pool_type = EXCLUDED.pool_type, module = EXCLUDED.module
  RETURNING id INTO v_pool_id;

  IF v_pool_id IS NULL THEN
    SELECT id INTO v_pool_id
    FROM puls_core.authority_pools
    WHERE tenant_id = v_tenant_id AND code = 'smoke_finance_pool';
  END IF;

  INSERT INTO puls_core.authority_pool_members (
    tenant_id, pool_id, employee_id, is_active
  ) VALUES (v_tenant_id, v_pool_id, v_employee_id, TRUE)
  ON CONFLICT DO NOTHING
  RETURNING id INTO v_member_id;

  -- Happy path: cost_center_owner relationship
  INSERT INTO puls_core.authority_relationships (
    tenant_id, authority_type, subject_employee_id, module, scope_type, scope_id
  ) VALUES (
    v_tenant_id, 'cost_center_owner', v_employee_id, 'global', 'cost_center', v_cost_center_id
  )
  RETURNING id INTO v_rel_id;

  -- Negative: cost_center_owner with legal_entity scope
  BEGIN
    INSERT INTO puls_core.authority_relationships (
      tenant_id, authority_type, subject_employee_id, module, scope_type, scope_id
    ) VALUES (
      v_tenant_id, 'cost_center_owner', v_employee_id, 'global', 'legal_entity', v_legal_entity_id
    );
    RAISE EXCEPTION 'SMOKE_FAIL: expected cost_center_owner scope rejection';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_AUTHORITY_SCOPE_INVALID%' THEN
        RAISE;
      END IF;
  END;

  -- Negative: legal_entity_owner with cost_center scope
  BEGIN
    INSERT INTO puls_core.authority_relationships (
      tenant_id, authority_type, subject_employee_id, module, scope_type, scope_id
    ) VALUES (
      v_tenant_id, 'legal_entity_owner', v_employee_id, 'global', 'cost_center', v_cost_center_id
    );
    RAISE EXCEPTION 'SMOKE_FAIL: expected legal_entity_owner scope rejection';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_AUTHORITY_SCOPE_INVALID%' THEN
        RAISE;
      END IF;
  END;

  -- Negative: legal_compliance_approver with expense module
  BEGIN
    INSERT INTO puls_core.authority_relationships (
      tenant_id, authority_type, subject_employee_id, module, scope_type, scope_id
    ) VALUES (
      v_tenant_id, 'legal_compliance_approver', v_employee_id, 'expense', 'tenant', NULL
    );
    RAISE EXCEPTION 'SMOKE_FAIL: expected legal_compliance module rejection';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_AUTHORITY_MODULE_INVALID%' THEN
        RAISE;
      END IF;
  END;

  -- Negative: finance_approver with leave module
  BEGIN
    INSERT INTO puls_core.authority_relationships (
      tenant_id, authority_type, subject_employee_id, module, scope_type, scope_id
    ) VALUES (
      v_tenant_id, 'finance_approver', v_employee_id, 'leave', 'tenant', NULL
    );
    RAISE EXCEPTION 'SMOKE_FAIL: expected finance_approver module rejection';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_AUTHORITY_MODULE_INVALID%' THEN
        RAISE;
      END IF;
  END;

  -- Negative: self-delegate via employee scope
  BEGIN
    INSERT INTO puls_core.authority_relationships (
      tenant_id, authority_type, subject_employee_id, module, scope_type, scope_id
    ) VALUES (
      v_tenant_id, 'approval_delegate', v_employee_id, 'leave', 'employee', v_employee_id
    );
    RAISE EXCEPTION 'SMOKE_FAIL: expected self-delegate rejection';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_AUTHORITY_SELF_DELEGATE%' THEN
        RAISE;
      END IF;
  END;

  -- Negative: cross-tenant scope
  IF v_other_tenant_id IS NOT NULL THEN
    SELECT cc.id INTO v_other_cc_id
    FROM puls_core.cost_centers cc
    WHERE cc.tenant_id = v_other_tenant_id AND cc.is_active = TRUE
    LIMIT 1;

    IF v_other_cc_id IS NOT NULL THEN
      BEGIN
        INSERT INTO puls_core.authority_relationships (
          tenant_id, authority_type, subject_employee_id, module, scope_type, scope_id
        ) VALUES (
          v_tenant_id, 'cost_center_owner', v_employee_id, 'global', 'cost_center', v_other_cc_id
        );
        RAISE EXCEPTION 'SMOKE_FAIL: expected cross-tenant scope rejection';
      EXCEPTION
        WHEN OTHERS THEN
          IF SQLERRM NOT LIKE '%PULS_AUTHORITY_SCOPE_INVALID%' THEN
            RAISE;
          END IF;
      END;
    END IF;
  ELSE
    RAISE NOTICE 'SKIP cross-tenant scope: only one tenant';
  END IF;

  -- Negative: inactive employee pool member
  SELECT id INTO v_inactive_employee_id
  FROM puls_core.employees
  WHERE tenant_id = v_tenant_id
    AND employment_status <> 'active'::puls_core.employment_status
  LIMIT 1;

  IF v_inactive_employee_id IS NULL AND v_other_employee_id IS NOT NULL THEN
    UPDATE puls_core.employees
    SET employment_status = 'terminated'::puls_core.employment_status
    WHERE id = v_other_employee_id;
    v_inactive_employee_id := v_other_employee_id;
  END IF;

  IF v_inactive_employee_id IS NOT NULL THEN
    BEGIN
      INSERT INTO puls_core.authority_pool_members (
        tenant_id, pool_id, employee_id, is_active
      ) VALUES (v_tenant_id, v_pool_id, v_inactive_employee_id, TRUE);
      RAISE EXCEPTION 'SMOKE_FAIL: expected inactive employee pool member rejection';
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLERRM NOT LIKE '%PULS_AUTHORITY_INVALID_EMPLOYEE%' THEN
          RAISE;
        END IF;
    END;
  END IF;

  -- Negative: inactive cost center scope
  IF v_inactive_cc_id IS NOT NULL THEN
    BEGIN
      INSERT INTO puls_core.authority_relationships (
        tenant_id, authority_type, subject_employee_id, module, scope_type, scope_id
      ) VALUES (
        v_tenant_id, 'cost_center_owner', v_employee_id, 'global', 'cost_center', v_inactive_cc_id
      );
      RAISE EXCEPTION 'SMOKE_FAIL: expected inactive cost center scope rejection';
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLERRM NOT LIKE '%PULS_AUTHORITY_SCOPE_INVALID%' THEN
          RAISE;
        END IF;
    END;
  END IF;

  -- Deactivate membership then reuse active slot
  UPDATE puls_core.authority_pool_members
  SET is_active = FALSE
  WHERE tenant_id = v_tenant_id AND pool_id = v_pool_id AND employee_id = v_employee_id;

  INSERT INTO puls_core.authority_pool_members (
    tenant_id, pool_id, employee_id, is_active
  ) VALUES (v_tenant_id, v_pool_id, v_employee_id, TRUE);

  -- No owner_employee_id on dimension tables
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'puls_core'
      AND table_name IN ('legal_entities', 'locations', 'cost_centers', 'departments')
      AND column_name = 'owner_employee_id'
  ) THEN
    RAISE EXCEPTION 'SMOKE_FAIL: owner_employee_id column must not exist on dimensions';
  END IF;

  -- Forbidden manager-like enum labels absent (pg_enum authoritative)
  SELECT COUNT(*) INTO v_forbidden_count
  FROM pg_enum e
  JOIN pg_type t ON t.oid = e.enumtypid
  JOIN pg_namespace n ON n.oid = t.typnamespace
  WHERE n.nspname = 'puls_core'
    AND t.typname = 'authority_type'
    AND e.enumlabel IN ('direct_manager', 'primary_manager', 'management_chain', 'manager');

  IF v_forbidden_count > 0 THEN
    RAISE EXCEPTION 'SMOKE_FAIL: forbidden manager-like authority_type enum labels present';
  END IF;

  -- Helper smoke with JWT context (required attempt)
  IF v_auth_user_id IS NOT NULL THEN
    BEGIN
      PERFORM set_config('request.jwt.claim.sub', v_auth_user_id::text, true);

      v_helper_ok := puls_core.is_pool_member(
        'smoke_finance_pool',
        'tenant'::puls_core.authority_scope_type,
        NULL,
        'expense'::puls_core.authority_module
      );

      IF NOT v_helper_ok THEN
        RAISE EXCEPTION 'SMOKE_FAIL: is_pool_member expected true for seeded finance pool member';
      END IF;

      v_helper_ok := puls_core.has_authority(
        'cost_center_owner'::puls_core.authority_type,
        'cost_center'::puls_core.authority_scope_type,
        v_cost_center_id,
        'global'::puls_core.authority_module
      );

      IF NOT v_helper_ok THEN
        RAISE EXCEPTION 'SMOKE_FAIL: has_authority expected true for seeded cost_center_owner';
      END IF;

      v_helper_ok := puls_core.can_read_scope(
        'cost_center'::puls_core.authority_scope_type,
        v_cost_center_id,
        'expense'::puls_core.authority_module
      );

      IF NOT v_helper_ok THEN
        RAISE EXCEPTION 'SMOKE_FAIL: can_read_scope expected true for cost_center with owner authority';
      END IF;

      RAISE NOTICE '09 PR3 helper smoke OK: JWT context honored for is_pool_member/has_authority/can_read_scope';
    EXCEPTION
      WHEN OTHERS THEN
        PERFORM set_config('request.jwt.claim.sub', '', true);
        RAISE;
    END;

    PERFORM set_config('request.jwt.claim.sub', '', true);
  ELSE
    RAISE NOTICE '09 PR3 helper smoke SKIP: no auth-linked employee (user_id NULL); manual JWT staging test required';
  END IF;

  RAISE NOTICE '09 PR3 smoke OK: pools, relationships, scope/module guards, membership reuse';
END $$;

ROLLBACK;
