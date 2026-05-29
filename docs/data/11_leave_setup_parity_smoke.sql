-- 11 PR11.3 Leave Setup Parity — executable surface smoke (single transaction; rolls back)

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_leave_type_id UUID;
  v_leave_policy_id UUID;
  v_active_count INTEGER;
  v_inactive_count INTEGER;
  v_policy_count INTEGER;
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

  -- leave_types readable (tenant-scoped)
  PERFORM 1
  FROM puls_workflow.leave_types lt
  WHERE lt.tenant_id = v_tenant_id
  LIMIT 1;

  -- unique (tenant_id, code) constraint surface
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE n.nspname = 'puls_workflow'
      AND t.relname = 'leave_types'
      AND c.contype = 'u'
      AND pg_get_constraintdef(c.oid) ILIKE '%tenant_id%'
      AND pg_get_constraintdef(c.oid) ILIKE '%code%'
  ) THEN
    RAISE EXCEPTION 'SMOKE_FAIL: leave_types (tenant_id, code) unique constraint missing';
  END IF;

  -- guardrail trigger exists
  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger tg
    JOIN pg_class t ON t.oid = tg.tgrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE n.nspname = 'puls_workflow'
      AND t.relname = 'leave_types'
      AND NOT tg.tgisinternal
      AND tg.tgname = 'puls_workflow_leave_types_validate_guardrails'
  ) THEN
    RAISE EXCEPTION 'SMOKE_FAIL: puls_workflow_leave_types_validate_guardrails trigger missing';
  END IF;

  -- lifecycle RPCs exist
  IF to_regprocedure('puls_workflow.deactivate_leave_type(uuid,text)') IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL: deactivate_leave_type RPC missing';
  END IF;

  IF to_regprocedure('puls_workflow.restore_leave_type(uuid)') IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL: restore_leave_type RPC missing';
  END IF;

  -- audit table readable
  PERFORM 1
  FROM puls_workflow.leave_type_lifecycle_events e
  WHERE e.tenant_id = v_tenant_id
  LIMIT 1;

  -- active/inactive counts computable
  SELECT
    COUNT(*) FILTER (WHERE lt.is_active),
    COUNT(*) FILTER (WHERE NOT lt.is_active)
  INTO v_active_count, v_inactive_count
  FROM puls_workflow.leave_types lt
  WHERE lt.tenant_id = v_tenant_id;

  IF v_active_count IS NULL OR v_inactive_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL: active/inactive leave type counts not computable';
  END IF;

  -- policy join surface (leave module policies)
  SELECT COUNT(*)
  INTO v_policy_count
  FROM puls_workflow.approval_policies ap
  WHERE ap.tenant_id = v_tenant_id
    AND ap.module = 'leave';

  IF v_policy_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL: leave policy join surface failed';
  END IF;

  -- optional rollback fixture: valid insert/update under guardrails
  SELECT id INTO v_leave_policy_id
  FROM puls_workflow.approval_policies
  WHERE tenant_id = v_tenant_id
    AND module = 'leave'
    AND is_active = TRUE
  ORDER BY code
  LIMIT 1;

  IF v_leave_policy_id IS NOT NULL THEN
    INSERT INTO puls_workflow.leave_types (
      tenant_id, code, name, default_entitlement_days, requires_document,
      carry_over_allowed, max_carry_over_days, approval_policy_id, is_active
    ) VALUES (
      v_tenant_id, 'demo_leave_setup_parity_valid', 'Parity Smoke Leave', 10, FALSE,
      FALSE, NULL, v_leave_policy_id, TRUE
    )
    RETURNING id INTO v_leave_type_id;

    UPDATE puls_workflow.leave_types
    SET name = '  Parity Smoke Updated  '
    WHERE id = v_leave_type_id;

    IF (SELECT name FROM puls_workflow.leave_types WHERE id = v_leave_type_id) <> 'Parity Smoke Updated' THEN
      RAISE EXCEPTION 'SMOKE_FAIL: leave type update trim failed';
    END IF;
  ELSE
    RAISE NOTICE 'SKIP: no active leave policy — valid insert fixture skipped';
  END IF;

  -- invalid code fixture
  BEGIN
    INSERT INTO puls_workflow.leave_types (
      tenant_id, code, name, default_entitlement_days, is_active
    ) VALUES (
      v_tenant_id, 'INVALID-CODE', 'Bad Code Leave', 5, TRUE
    );
    RAISE EXCEPTION 'SMOKE_FAIL: invalid leave type code should raise PULS_LEAVE_TYPE_CODE_INVALID';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%PULS_LEAVE_TYPE_CODE_INVALID%' THEN
      RAISE;
    END IF;
  END;

  RAISE NOTICE 'OK: PR11.3 leave setup parity smoke passed';
END $$;

ROLLBACK;
