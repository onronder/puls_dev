-- 10 PR10.8 Expense Category Lifecycle Consumption — executable smoke (single transaction; rolls back)
--
-- Invariant: use separate fixtures or close created claims to exported/rejected/cancelled
-- before deactivate_expense_category. Otherwise PR10.7 open-claim guard (draft|pending|approved)
-- correctly blocks deactivate and this smoke would test the wrong invariant.
--
-- Fixture A: active create path (+ restore/post-restore create)
-- Fixture B: exported historical claim + deactivate + historical SELECT
-- Fixture C: inactive create rejection + historical SELECT still readable

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_employee_id UUID;
  v_user_id UUID;
  v_active_category_id UUID;
  v_history_category_id UUID;
  v_active_claim_id UUID;
  v_historical_claim_id UUID;
  v_result JSONB;
  v_category_name TEXT;
  v_category_code TEXT;
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

  -- ---------------------------------------------------------------------------
  -- Fixture A: active create path (separate category; no deactivate here)
  -- ---------------------------------------------------------------------------

  INSERT INTO puls_workflow.expense_categories (
    tenant_id, code, name, monthly_limit, receipt_required_over, is_active
  ) VALUES (
    v_tenant_id, 'demo_lifecycle_consumption_active', 'Demo Consumption Active', 5000, 0, TRUE
  )
  RETURNING id INTO v_active_category_id;

  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', v_user_id::text, true);

  BEGIN
    v_result := puls_workflow.create_expense_claim(
      v_active_category_id,
      'Fixture A active create',
      100,
      'TRY',
      NULL,
      TRUE,
      CURRENT_DATE,
      'PR10.8 Fixture A'
    );
    v_active_claim_id := (v_result ->> 'expense_claim_id')::uuid;
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM LIKE '%PULS_NO_APPROVER%' OR SQLERRM LIKE '%PULS_POLICY_STEP_UNRESOLVED%' THEN
        PERFORM set_config('request.jwt.claim.role', 'service_role', true);
        PERFORM set_config('request.jwt.claim.sub', '', true);

        INSERT INTO puls_workflow.expense_claims (
          tenant_id, employee_id, category_id, amount, currency, expense_date, title, status,
          submitted_at, approved_at, exported_at
        ) VALUES (
          v_tenant_id, v_employee_id, v_active_category_id, 100, 'TRY', CURRENT_DATE,
          'Fixture A seeded exported claim', 'exported', NOW(), NOW(), NOW()
        )
        RETURNING id INTO v_active_claim_id;
      ELSE
        RAISE;
      END IF;
  END;

  IF v_active_claim_id IS NOT NULL THEN
    UPDATE puls_workflow.expense_claims
    SET status = 'exported',
        exported_at = COALESCE(exported_at, NOW()),
        approved_at = COALESCE(approved_at, NOW())
    WHERE id = v_active_claim_id
      AND status IN ('draft', 'pending', 'approved');
  END IF;

  -- ---------------------------------------------------------------------------
  -- Fixture B: exported historical claim + deactivate + historical SELECT
  -- ---------------------------------------------------------------------------

  PERFORM set_config('request.jwt.claim.role', 'service_role', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);

  INSERT INTO puls_workflow.expense_categories (
    tenant_id, code, name, monthly_limit, receipt_required_over, is_active
  ) VALUES (
    v_tenant_id, 'demo_lifecycle_consumption_history', 'Demo Consumption History', 5000, 0, TRUE
  )
  RETURNING id INTO v_history_category_id;

  INSERT INTO puls_workflow.expense_claims (
    tenant_id, employee_id, category_id, amount, currency, expense_date, title, status,
    submitted_at, approved_at, exported_at
  ) VALUES (
    v_tenant_id, v_employee_id, v_history_category_id, 250, 'TRY', CURRENT_DATE - 30,
    'Fixture B historical exported claim', 'exported', NOW(), NOW(), NOW()
  )
  RETURNING id INTO v_historical_claim_id;

  v_result := puls_workflow.deactivate_expense_category(v_history_category_id);
  IF v_result->>'status' <> 'deactivated' THEN
    RAISE EXCEPTION 'SMOKE_FAIL Fixture B: expected deactivated, got %', v_result;
  END IF;

  SELECT cat.name, cat.code, cat.is_active
  INTO v_category_name, v_category_code, v_category_active
  FROM puls_workflow.expense_claims ec
  JOIN puls_workflow.expense_categories cat ON cat.id = ec.category_id
  WHERE ec.id = v_historical_claim_id;

  IF v_category_name IS NULL OR BTRIM(v_category_name) = '' THEN
    RAISE EXCEPTION 'SMOKE_FAIL Fixture B: historical claim category name should remain readable';
  END IF;

  IF v_category_code IS NULL OR BTRIM(v_category_code) = '' THEN
    RAISE EXCEPTION 'SMOKE_FAIL Fixture B: historical claim category code should remain readable';
  END IF;

  IF v_category_active IS NOT FALSE THEN
    RAISE EXCEPTION 'SMOKE_FAIL Fixture B: historical claim should reference inactive category row, got is_active=%', v_category_active;
  END IF;

  -- ---------------------------------------------------------------------------
  -- Fixture C: inactive create rejection + historical still readable
  -- ---------------------------------------------------------------------------

  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', v_user_id::text, true);

  BEGIN
    v_result := puls_workflow.create_expense_claim(
      v_history_category_id,
      'Fixture C inactive create',
      50,
      'TRY',
      NULL,
      TRUE,
      CURRENT_DATE,
      NULL
    );
    RAISE EXCEPTION 'SMOKE_FAIL Fixture C: inactive category should reject create_expense_claim';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_INVALID_EXPENSE_CATEGORY%' THEN
        RAISE;
      END IF;
  END;

  PERFORM set_config('request.jwt.claim.role', 'service_role', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);

  SELECT cat.name, cat.code, cat.is_active
  INTO v_category_name, v_category_code, v_category_active
  FROM puls_workflow.expense_claims ec
  JOIN puls_workflow.expense_categories cat ON cat.id = ec.category_id
  WHERE ec.id = v_historical_claim_id;

  IF v_category_name IS NULL OR BTRIM(v_category_name) = '' THEN
    RAISE EXCEPTION 'SMOKE_FAIL Fixture C: historical claim category name should remain readable after inactive create reject';
  END IF;

  IF v_category_code IS NULL OR BTRIM(v_category_code) = '' THEN
    RAISE EXCEPTION 'SMOKE_FAIL Fixture C: historical claim category code should remain readable after inactive create reject';
  END IF;

  IF v_category_active IS NOT FALSE THEN
    RAISE EXCEPTION 'SMOKE_FAIL Fixture C: historical claim should reference inactive category row after inactive create reject, got is_active=%', v_category_active;
  END IF;

  -- Fixture A continued: restore history category and attempt post-restore create
  v_result := puls_workflow.restore_expense_category(v_history_category_id);
  IF v_result->>'status' <> 'restored' THEN
    RAISE EXCEPTION 'SMOKE_FAIL Fixture A: expected restored, got %', v_result;
  END IF;

  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM set_config('request.jwt.claim.sub', v_user_id::text, true);

  BEGIN
    v_result := puls_workflow.create_expense_claim(
      v_history_category_id,
      'Fixture A post-restore create',
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
        RAISE NOTICE 'SKIP Fixture A post-restore create: approver not configured in demo tenant';
      ELSE
        RAISE;
      END IF;
  END;

  PERFORM set_config('request.jwt.claim.role', 'service_role', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
END;
$$;

ROLLBACK;
