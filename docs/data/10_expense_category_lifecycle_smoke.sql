-- 10 PR10.7 Expense Category Lifecycle — executable smoke (single transaction; rolls back)

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_employee_id UUID;
  v_policy_id UUID;
  v_category_id UUID;
  v_category_id_draft UUID;
  v_category_id_pending UUID;
  v_category_id_approved UUID;
  v_category_id_exported UUID;
  v_category_id_policy UUID;
  v_category_id_restore_a UUID;
  v_category_id_restore_b UUID;
  v_result JSONB;
  v_account_code TEXT;
  v_conflict_code TEXT;
  v_is_active BOOLEAN;
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

  SELECT e.id INTO v_employee_id
  FROM puls_core.employees e
  WHERE e.tenant_id = v_tenant_id
  LIMIT 1;

  IF v_employee_id IS NULL THEN
    RAISE EXCEPTION 'SMOKE_SETUP_FAIL: expected at least one employee for lifecycle smoke';
  END IF;

  SELECT ap.id INTO v_policy_id
  FROM puls_workflow.approval_policies ap
  WHERE ap.tenant_id = v_tenant_id
    AND ap.is_active = TRUE
  LIMIT 1;

  DELETE FROM puls_workflow.expense_claims ec
  USING puls_workflow.expense_categories cat
  WHERE ec.category_id = cat.id
    AND cat.tenant_id = v_tenant_id
    AND cat.code LIKE 'demo_lifecycle%';

  DELETE FROM puls_workflow.expense_categories
  WHERE tenant_id = v_tenant_id
    AND code LIKE 'demo_lifecycle%';

  WITH candidate_codes AS (
    SELECT format('%s.%s', gs / 100, lpad((gs % 100)::TEXT, 2, '0')) AS account_code
    FROM generate_series(91000, 91999) AS gs
  ),
  available_codes AS (
    SELECT c.account_code
    FROM candidate_codes c
    WHERE NOT EXISTS (
      SELECT 1
      FROM puls_workflow.expense_categories ec
      WHERE ec.tenant_id = v_tenant_id
        AND ec.is_active = TRUE
        AND NULLIF(BTRIM(ec.erp_account_code), '') = c.account_code
    )
    ORDER BY c.account_code
    LIMIT 2
  )
  SELECT
    (array_agg(account_code ORDER BY account_code))[1],
    (array_agg(account_code ORDER BY account_code))[2]
  INTO v_account_code, v_conflict_code
  FROM available_codes;

  IF v_account_code IS NULL OR v_conflict_code IS NULL THEN
    RAISE EXCEPTION 'SMOKE_SETUP_FAIL: expected at least two available accounting codes for lifecycle smoke';
  END IF;

  -- Fresh active category for core lifecycle path
  INSERT INTO puls_workflow.expense_categories (
    tenant_id, code, name, monthly_limit, receipt_required_over, erp_account_code, is_active
  ) VALUES (
    v_tenant_id, 'demo_lifecycle_fresh', 'Demo Lifecycle Fresh', 1000, 100, v_account_code, TRUE
  )
  RETURNING id INTO v_category_id;

  -- Fresh deactivate
  v_result := puls_workflow.deactivate_expense_category(v_category_id, 'smoke test');
  IF v_result->>'status' <> 'deactivated' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected deactivated, got %', v_result;
  END IF;

  SELECT is_active INTO v_is_active
  FROM puls_workflow.expense_categories
  WHERE id = v_category_id;

  IF v_is_active THEN
    RAISE EXCEPTION 'SMOKE_FAIL: category should be inactive after deactivate';
  END IF;

  -- Re-deactivate (idempotent)
  v_result := puls_workflow.deactivate_expense_category(v_category_id);
  IF v_result->>'status' <> 'already_inactive' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected already_inactive, got %', v_result;
  END IF;

  -- Restore
  v_result := puls_workflow.restore_expense_category(v_category_id);
  IF v_result->>'status' <> 'restored' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected restored, got %', v_result;
  END IF;

  SELECT is_active INTO v_is_active
  FROM puls_workflow.expense_categories
  WHERE id = v_category_id;

  IF NOT v_is_active THEN
    RAISE EXCEPTION 'SMOKE_FAIL: category should be active after restore';
  END IF;

  -- Re-restore (idempotent)
  v_result := puls_workflow.restore_expense_category(v_category_id);
  IF v_result->>'status' <> 'already_active' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected already_active, got %', v_result;
  END IF;

  -- Deactivate with draft claim (separate fixture)
  INSERT INTO puls_workflow.expense_categories (
    tenant_id, code, name, monthly_limit, receipt_required_over, is_active
  ) VALUES (
    v_tenant_id, 'demo_lifecycle_draft', 'Demo Lifecycle Draft Block', 500, 0, TRUE
  )
  RETURNING id INTO v_category_id_draft;

  INSERT INTO puls_workflow.expense_claims (
    tenant_id, employee_id, category_id, amount, currency, expense_date, title, status
  ) VALUES (
    v_tenant_id, v_employee_id, v_category_id_draft, 100, 'TRY', CURRENT_DATE, 'Draft claim', 'draft'
  );

  BEGIN
    v_result := puls_workflow.deactivate_expense_category(v_category_id_draft);
    RAISE EXCEPTION 'SMOKE_FAIL: draft claim should block deactivate';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_EXPENSE_CATEGORY_IN_USE_ACTIVE_CLAIMS%' THEN
        RAISE;
      END IF;
  END;

  -- Deactivate with pending claim (separate fixture)
  INSERT INTO puls_workflow.expense_categories (
    tenant_id, code, name, monthly_limit, receipt_required_over, is_active
  ) VALUES (
    v_tenant_id, 'demo_lifecycle_pending', 'Demo Lifecycle Pending Block', 500, 0, TRUE
  )
  RETURNING id INTO v_category_id_pending;

  INSERT INTO puls_workflow.expense_claims (
    tenant_id, employee_id, category_id, amount, currency, expense_date, title, status, submitted_at
  ) VALUES (
    v_tenant_id, v_employee_id, v_category_id_pending, 100, 'TRY', CURRENT_DATE, 'Pending claim', 'pending', NOW()
  );

  BEGIN
    v_result := puls_workflow.deactivate_expense_category(v_category_id_pending);
    RAISE EXCEPTION 'SMOKE_FAIL: pending claim should block deactivate';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_EXPENSE_CATEGORY_IN_USE_ACTIVE_CLAIMS%' THEN
        RAISE;
      END IF;
  END;

  -- Deactivate with approved claim (separate fixture — pre-export open finance workflow)
  INSERT INTO puls_workflow.expense_categories (
    tenant_id, code, name, monthly_limit, receipt_required_over, is_active
  ) VALUES (
    v_tenant_id, 'demo_lifecycle_approved', 'Demo Lifecycle Approved Block', 500, 0, TRUE
  )
  RETURNING id INTO v_category_id_approved;

  INSERT INTO puls_workflow.expense_claims (
    tenant_id, employee_id, category_id, amount, currency, expense_date, title, status,
    submitted_at, approved_at
  ) VALUES (
    v_tenant_id, v_employee_id, v_category_id_approved, 100, 'TRY', CURRENT_DATE, 'Approved claim',
    'approved', NOW(), NOW()
  );

  BEGIN
    v_result := puls_workflow.deactivate_expense_category(v_category_id_approved);
    RAISE EXCEPTION 'SMOKE_FAIL: approved claim should block deactivate';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_EXPENSE_CATEGORY_IN_USE_ACTIVE_CLAIMS%' THEN
        RAISE;
      END IF;
  END;

  -- Deactivate with only exported claim (allowed; has_history must be true)
  INSERT INTO puls_workflow.expense_categories (
    tenant_id, code, name, monthly_limit, receipt_required_over, is_active
  ) VALUES (
    v_tenant_id, 'demo_lifecycle_exported', 'Demo Lifecycle Exported Allow', 500, 0, TRUE
  )
  RETURNING id INTO v_category_id_exported;

  INSERT INTO puls_workflow.expense_claims (
    tenant_id, employee_id, category_id, amount, currency, expense_date, title, status,
    submitted_at, approved_at, exported_at
  ) VALUES (
    v_tenant_id, v_employee_id, v_category_id_exported, 100, 'TRY', CURRENT_DATE, 'Exported claim',
    'exported', NOW(), NOW(), NOW()
  );

  v_result := puls_workflow.deactivate_expense_category(v_category_id_exported);
  IF v_result->>'status' <> 'deactivated' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: exported-only claim should allow deactivate, got %', v_result;
  END IF;

  IF COALESCE((v_result->>'has_history')::boolean, FALSE) IS NOT TRUE THEN
    RAISE EXCEPTION 'SMOKE_FAIL: exported deactivate must return has_history = true, got %', v_result;
  END IF;

  -- Active policy binding does not block deactivate (no open claims)
  IF v_policy_id IS NOT NULL THEN
    INSERT INTO puls_workflow.expense_categories (
      tenant_id, code, name, monthly_limit, receipt_required_over, approval_policy_id, is_active
    ) VALUES (
      v_tenant_id, 'demo_lifecycle_policy', 'Demo Lifecycle Policy Bound', 500, 0, v_policy_id, TRUE
    )
    RETURNING id INTO v_category_id_policy;

    v_result := puls_workflow.deactivate_expense_category(v_category_id_policy);
    IF v_result->>'status' <> 'deactivated' THEN
      RAISE EXCEPTION 'SMOKE_FAIL: policy-bound category without open claims should deactivate, got %', v_result;
    END IF;

    SELECT approval_policy_id INTO v_policy_id
    FROM puls_workflow.expense_categories
    WHERE id = v_category_id_policy;

    IF v_policy_id IS NULL THEN
      RAISE EXCEPTION 'SMOKE_FAIL: approval_policy_id should be preserved after deactivate';
    END IF;
  END IF;

  -- Restore duplicate active accounting code -> 23505
  INSERT INTO puls_workflow.expense_categories (
    tenant_id, code, name, monthly_limit, receipt_required_over, erp_account_code, is_active
  ) VALUES (
    v_tenant_id, 'demo_lifecycle_restore_active', 'Demo Lifecycle Restore Active', 500, 0, v_conflict_code, TRUE
  )
  RETURNING id INTO v_category_id_restore_a;

  INSERT INTO puls_workflow.expense_categories (
    tenant_id, code, name, monthly_limit, receipt_required_over, erp_account_code, is_active
  ) VALUES (
    v_tenant_id, 'demo_lifecycle_restore_inactive', 'Demo Lifecycle Restore Inactive', 500, 0, v_conflict_code, FALSE
  )
  RETURNING id INTO v_category_id_restore_b;

  BEGIN
    v_result := puls_workflow.restore_expense_category(v_category_id_restore_b);
    RAISE EXCEPTION 'SMOKE_FAIL: restore with duplicate active accounting code should raise 23505';
  EXCEPTION
    WHEN unique_violation THEN
      IF SQLSTATE <> '23505' THEN
        RAISE;
      END IF;
  END;

  PERFORM set_config('request.jwt.claim.role', '', true);
END;
$$;

ROLLBACK;
