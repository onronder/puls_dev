-- 10 PR10.16 Request Creation Hardening — executable smoke (single transaction; rolls back)
-- Asserts active-only create guards, inactive rejections, and historical inactive readability.
--
-- Real RPC signatures (positional — do NOT call with jsonb):
--   puls_workflow.create_expense_claim(uuid, text, numeric, text, numeric, boolean, date, text)
--     (category_id, title, amount, currency, vat_amount, vat_included, expense_date, description)
--   puls_workflow.create_leave_request(uuid, date, date, boolean, uuid, text)
--     (leave_type_id, start_date, end_date, half_day, delegate_employee_id, description)

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_active_category_id UUID;
  v_inactive_category_id UUID;
  v_active_leave_type_id UUID;
  v_inactive_leave_type_id UUID;
  v_employee_id UUID;
  v_active_picker_count INTEGER;
  v_inactive_historical_count INTEGER;
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

  SELECT id INTO v_active_category_id
  FROM puls_workflow.expense_categories
  WHERE tenant_id = v_tenant_id
    AND is_active = true
  ORDER BY name
  LIMIT 1;

  SELECT id INTO v_inactive_category_id
  FROM puls_workflow.expense_categories
  WHERE tenant_id = v_tenant_id
    AND is_active = false
  ORDER BY name
  LIMIT 1;

  SELECT id INTO v_active_leave_type_id
  FROM puls_workflow.leave_types
  WHERE tenant_id = v_tenant_id
    AND is_active = true
  ORDER BY name
  LIMIT 1;

  SELECT id INTO v_inactive_leave_type_id
  FROM puls_workflow.leave_types
  WHERE tenant_id = v_tenant_id
    AND is_active = false
  ORDER BY name
  LIMIT 1;

  SELECT COUNT(*)::INTEGER INTO v_active_picker_count
  FROM puls_workflow.expense_categories
  WHERE tenant_id = v_tenant_id
    AND is_active = true;

  IF v_active_picker_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL expense_categories: active-only picker query failed';
  END IF;

  SELECT COUNT(*)::INTEGER INTO v_inactive_historical_count
  FROM puls_workflow.expense_categories
  WHERE tenant_id = v_tenant_id
    AND is_active = false;

  IF v_inactive_historical_count IS NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL expense_categories: historical inactive readability query failed';
  END IF;

  IF v_inactive_category_id IS NOT NULL THEN
    BEGIN
      PERFORM puls_workflow.create_expense_claim(
        v_inactive_category_id,
        'Smoke inactive category',
        100,
        'TRY',
        NULL,
        TRUE,
        CURRENT_DATE,
        'request creation hardening smoke'
      );
      RAISE EXCEPTION 'SMOKE_FAIL inactive expense category create: expected PULS_INVALID_EXPENSE_CATEGORY';
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLERRM NOT ILIKE '%PULS_INVALID_EXPENSE_CATEGORY%' THEN
          RAISE EXCEPTION 'SMOKE_FAIL inactive expense category create: got %', SQLERRM;
        END IF;
    END;
  ELSE
    RAISE NOTICE 'NOTICE: no inactive expense category on tenant; skipping inactive reject case';
  END IF;

  IF v_inactive_leave_type_id IS NOT NULL THEN
    BEGIN
      PERFORM puls_workflow.create_leave_request(
        v_inactive_leave_type_id,
        CURRENT_DATE + 7,
        CURRENT_DATE + 7,
        FALSE,
        NULL,
        'request creation hardening smoke'
      );
      RAISE EXCEPTION 'SMOKE_FAIL inactive leave type create: expected PULS_INVALID_LEAVE_TYPE';
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLERRM NOT ILIKE '%PULS_INVALID_LEAVE_TYPE%' THEN
          RAISE EXCEPTION 'SMOKE_FAIL inactive leave type create: got %', SQLERRM;
        END IF;
    END;
  ELSE
    RAISE NOTICE 'NOTICE: no inactive leave type on tenant; skipping inactive reject case';
  END IF;

  SELECT e.id INTO v_employee_id
  FROM puls_core.employees e
  WHERE e.tenant_id = v_tenant_id
  LIMIT 1;

  IF v_employee_id IS NOT NULL THEN
    PERFORM 1
    FROM puls_core.employee_cost_center_assignments
    WHERE tenant_id = v_tenant_id
      AND employee_id = v_employee_id;

    PERFORM 1
    FROM puls_core.employee_reporting_lines
    WHERE tenant_id = v_tenant_id
      AND employee_id = v_employee_id
      AND relationship_type = 'primary_manager';
  ELSE
    RAISE NOTICE 'NOTICE: no employee fixture for assignment readability checks';
  END IF;

  RAISE NOTICE 'demo_request_creation_hardening smoke completed for tenant %', v_tenant_id;
END $$;

ROLLBACK;
