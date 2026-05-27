-- 10 PR10.8 Expense Category Lifecycle Consumption — executable smoke (single transaction; rolls back)

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_employee_id UUID;
  v_user_id UUID;
  v_category_id UUID;
  v_claim_id UUID;
  v_result JSONB;
  v_category_name TEXT;
  v_category_active BOOLEAN;
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

  SELECT e.id, e.user_id
  INTO v_employee_id, v_user_id
  FROM puls_core.employees e
  WHERE e.tenant_id = v_tenant_id
    AND e.user_id IS NOT NULL
  LIMIT 1;

  IF v_employee_id IS NULL OR v_user_id IS NULL THEN
    RAISE EXCEPTION 'SMOKE_SETUP_FAIL: expected employee with user_id for consumption smoke';
  END IF;

  DELETE FROM puls_workflow.expense_claims ec
  USING puls_workflow.expense_categories cat
  WHERE ec.category_id = cat.id
    AND cat.tenant_id = v_tenant_id
    AND cat.code LIKE 'demo_lifecycle_consumption%';

  DELETE FROM puls_workflow.expense_categories
  WHERE tenant_id = v_tenant_id
    AND code LIKE 'demo_lifecycle_consumption%';

  INSERT INTO puls_workflow.expense_categories (
    tenant_id, code, name, monthly_limit, receipt_required_over, is_active
  ) VALUES (
    v_tenant_id, 'demo_lifecycle_consumption', 'Demo Lifecycle Consumption', 5000, 0, TRUE
  )
  RETURNING id INTO v_category_id;

  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', v_user_id::text, true);

  BEGIN
    v_result := puls_workflow.create_expense_claim(
      v_category_id,
      'Demo consumption active create',
      100,
      'TRY',
      NULL,
      TRUE,
      CURRENT_DATE,
      'PR10.8 consumption smoke'
    );
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM LIKE '%PULS_NO_APPROVER%' OR SQLERRM LIKE '%PULS_POLICY_STEP_UNRESOLVED%' THEN
        PERFORM set_config('request.jwt.claim.role', 'service_role', true);
        PERFORM set_config('request.jwt.claim.sub', '', true);

        INSERT INTO puls_workflow.expense_claims (
          tenant_id, employee_id, category_id, amount, currency, expense_date, title, status,
          submitted_at, approved_at, exported_at
        ) VALUES (
          v_tenant_id, v_employee_id, v_category_id, 100, 'TRY', CURRENT_DATE,
          'Demo consumption seeded claim', 'exported', NOW(), NOW(), NOW()
        )
        RETURNING id INTO v_claim_id;

        PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
        PERFORM set_config('request.jwt.claim.sub', v_user_id::text, true);
      ELSE
        RAISE;
      END IF;
  END;

  IF v_claim_id IS NULL THEN
    v_claim_id := (v_result ->> 'expense_claim_id')::uuid;

    UPDATE puls_workflow.expense_claims
    SET status = 'exported',
        exported_at = COALESCE(exported_at, NOW()),
        approved_at = COALESCE(approved_at, NOW())
    WHERE id = v_claim_id;
  END IF;

  PERFORM set_config('request.jwt.claim.role', 'service_role', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);

  v_result := puls_workflow.deactivate_expense_category(v_category_id);
  IF v_result->>'status' <> 'deactivated' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected deactivated before consumption checks, got %', v_result;
  END IF;

  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', v_user_id::text, true);

  BEGIN
    v_result := puls_workflow.create_expense_claim(
      v_category_id,
      'Demo consumption inactive create',
      50,
      'TRY',
      NULL,
      TRUE,
      CURRENT_DATE,
      NULL
    );
    RAISE EXCEPTION 'SMOKE_FAIL: inactive category should reject create_expense_claim';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_INVALID_EXPENSE_CATEGORY%' THEN
        RAISE;
      END IF;
  END;

  PERFORM set_config('request.jwt.claim.role', 'service_role', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);

  SELECT cat.name, cat.is_active
  INTO v_category_name, v_category_active
  FROM puls_workflow.expense_claims ec
  JOIN puls_workflow.expense_categories cat ON cat.id = ec.category_id
  WHERE ec.id = v_claim_id;

  IF v_category_name IS NULL OR BTRIM(v_category_name) = '' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: historical claim category name should remain readable';
  END IF;

  IF v_category_active IS NOT FALSE THEN
    RAISE EXCEPTION 'SMOKE_FAIL: historical claim should reference inactive category row, got is_active=%', v_category_active;
  END IF;

  v_result := puls_workflow.restore_expense_category(v_category_id);
  IF v_result->>'status' <> 'restored' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected restored, got %', v_result;
  END IF;

  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', v_user_id::text, true);

  BEGIN
    v_result := puls_workflow.create_expense_claim(
      v_category_id,
      'Demo consumption post-restore create',
      75,
      'TRY',
      NULL,
      TRUE,
      CURRENT_DATE,
      NULL
    );
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM LIKE '%PULS_NO_APPROVER%' OR SQLERRM LIKE '%PULS_POLICY_STEP_UNRESOLVED%' THEN
        RAISE NOTICE 'SKIP post-restore create: approver not configured in demo tenant';
      ELSE
        RAISE;
      END IF;
  END;

  PERFORM set_config('request.jwt.claim.role', 'service_role', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
END;
$$;

ROLLBACK;
