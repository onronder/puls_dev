-- 10 PR10.5 Expense Category Guardrails — executable smoke (single transaction; rolls back)

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_category_id UUID;
  v_stored_name TEXT;
  v_stored_account_code TEXT;
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

  DELETE FROM puls_workflow.expense_categories
  WHERE tenant_id = v_tenant_id
    AND code LIKE 'demo_guardrails%';

  -- Valid insert
  INSERT INTO puls_workflow.expense_categories (
    tenant_id, code, name, monthly_limit, receipt_required_over, erp_account_code, is_active
  ) VALUES (
    v_tenant_id, 'demo_guardrails', 'Demo Guardrails', 1000, 100, '610.45', TRUE
  )
  RETURNING id INTO v_category_id;

  -- Valid update trims name and accounting code
  UPDATE puls_workflow.expense_categories
  SET name = '  Demo Guardrails Trimmed  ',
      erp_account_code = '  610.45  '
  WHERE id = v_category_id;

  SELECT name, erp_account_code
  INTO v_stored_name, v_stored_account_code
  FROM puls_workflow.expense_categories
  WHERE id = v_category_id;

  IF v_stored_name <> 'Demo Guardrails Trimmed' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected trimmed name, got %', v_stored_name;
  END IF;

  IF v_stored_account_code <> '610.45' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected trimmed account code, got %', v_stored_account_code;
  END IF;

  -- Blank name
  BEGIN
    UPDATE puls_workflow.expense_categories
    SET name = '   '
    WHERE id = v_category_id;
    RAISE EXCEPTION 'SMOKE_FAIL: blank name should raise PULS_EXPENSE_CATEGORY_NAME_REQUIRED';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_EXPENSE_CATEGORY_NAME_REQUIRED%' THEN
        RAISE;
      END IF;
  END;

  -- Restore name for subsequent tests
  UPDATE puls_workflow.expense_categories
  SET name = 'Demo Guardrails Trimmed'
  WHERE id = v_category_id;

  -- Blank code
  BEGIN
    UPDATE puls_workflow.expense_categories
    SET code = '   '
    WHERE id = v_category_id;
    RAISE EXCEPTION 'SMOKE_FAIL: blank code should raise PULS_EXPENSE_CATEGORY_CODE_REQUIRED';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_EXPENSE_CATEGORY_CODE_REQUIRED%' THEN
        RAISE;
      END IF;
  END;

  -- Invalid code formats
  FOR v_stored_name IN SELECT unnest(ARRAY['Demo Bad', 'demo-bad', '1demo']) LOOP
    BEGIN
      UPDATE puls_workflow.expense_categories
      SET code = v_stored_name
      WHERE id = v_category_id;
      RAISE EXCEPTION 'SMOKE_FAIL: invalid code % should raise PULS_EXPENSE_CATEGORY_CODE_INVALID', v_stored_name;
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLERRM NOT LIKE '%PULS_EXPENSE_CATEGORY_CODE_INVALID%' THEN
          RAISE;
        END IF;
    END;
  END LOOP;

  -- Negative monthly limit
  BEGIN
    UPDATE puls_workflow.expense_categories
    SET monthly_limit = -1
    WHERE id = v_category_id;
    RAISE EXCEPTION 'SMOKE_FAIL: negative monthly_limit should raise PULS_EXPENSE_CATEGORY_MONTHLY_LIMIT_INVALID';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_EXPENSE_CATEGORY_MONTHLY_LIMIT_INVALID%' THEN
        RAISE;
      END IF;
  END;

  -- Negative receipt threshold
  BEGIN
    UPDATE puls_workflow.expense_categories
    SET receipt_required_over = -1
    WHERE id = v_category_id;
    RAISE EXCEPTION 'SMOKE_FAIL: negative receipt_required_over should raise PULS_EXPENSE_CATEGORY_RECEIPT_THRESHOLD_INVALID';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_EXPENSE_CATEGORY_RECEIPT_THRESHOLD_INVALID%' THEN
        RAISE;
      END IF;
  END;

  -- Invalid VAT
  BEGIN
    UPDATE puls_workflow.expense_categories
    SET default_vat_rate = 101
    WHERE id = v_category_id;
    RAISE EXCEPTION 'SMOKE_FAIL: default_vat_rate 101 should raise PULS_EXPENSE_CATEGORY_VAT_INVALID';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_EXPENSE_CATEGORY_VAT_INVALID%' THEN
        RAISE;
      END IF;
  END;

  -- Invalid accounting codes
  FOR v_stored_name IN SELECT unnest(ARRAY['abc', '610.4', '610-45']) LOOP
    BEGIN
      UPDATE puls_workflow.expense_categories
      SET erp_account_code = v_stored_name
      WHERE id = v_category_id;
      RAISE EXCEPTION 'SMOKE_FAIL: invalid account code % should raise PULS_EXPENSE_CATEGORY_ACCOUNT_CODE_INVALID', v_stored_name;
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLERRM NOT LIKE '%PULS_EXPENSE_CATEGORY_ACCOUNT_CODE_INVALID%' THEN
          RAISE;
        END IF;
    END;
  END LOOP;

  -- Restore valid account code before duplicate tests
  UPDATE puls_workflow.expense_categories
  SET erp_account_code = '610.45'
  WHERE id = v_category_id;

  -- Two active rows with NULL accounting code pass
  INSERT INTO puls_workflow.expense_categories (
    tenant_id, code, name, monthly_limit, receipt_required_over, erp_account_code, is_active
  ) VALUES (
    v_tenant_id, 'demo_guardrails_null_a', 'Demo Guardrails Null A', 500, 0, NULL, TRUE
  );

  INSERT INTO puls_workflow.expense_categories (
    tenant_id, code, name, monthly_limit, receipt_required_over, erp_account_code, is_active
  ) VALUES (
    v_tenant_id, 'demo_guardrails_null_b', 'Demo Guardrails Null B', 500, 0, NULL, TRUE
  );

  -- Active duplicate accounting code -> 23505 (order: before inactive duplicate pass)
  INSERT INTO puls_workflow.expense_categories (
    tenant_id, code, name, monthly_limit, receipt_required_over, erp_account_code, is_active
  ) VALUES (
    v_tenant_id, 'demo_guardrails_dup_a', 'Demo Guardrails Dup A', 500, 0, '620.10', TRUE
  );

  BEGIN
    INSERT INTO puls_workflow.expense_categories (
      tenant_id, code, name, monthly_limit, receipt_required_over, erp_account_code, is_active
    ) VALUES (
      v_tenant_id, 'demo_guardrails_dup_b', 'Demo Guardrails Dup B', 500, 0, '620.10', TRUE
    );
    RAISE EXCEPTION 'SMOKE_FAIL: duplicate active accounting code should raise 23505';
  EXCEPTION
    WHEN unique_violation THEN
      IF SQLSTATE <> '23505' THEN
        RAISE;
      END IF;
  END;

  -- Inactive duplicate accounting code passes after active duplicate failure
  INSERT INTO puls_workflow.expense_categories (
    tenant_id, code, name, monthly_limit, receipt_required_over, erp_account_code, is_active
  ) VALUES (
    v_tenant_id, 'demo_guardrails_dup_inactive', 'Demo Guardrails Dup Inactive', 500, 0, '620.10', FALSE
  );

  PERFORM set_config('request.jwt.claim.role', '', true);
END;
$$;

ROLLBACK;
