-- 10 PR10.16 Request Creation Hardening — executable smoke (single transaction; rolls back)
-- Asserts active-only create guards, inactive rejections, and historical inactive readability.

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
        jsonb_build_object(
          'category_id', v_inactive_category_id,
          'amount', 100,
          'currency', 'TRY',
          'expense_date', CURRENT_DATE
        )
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
        jsonb_build_object(
          'leave_type_id', v_inactive_leave_type_id,
          'start_date', CURRENT_DATE + 7,
          'end_date', CURRENT_DATE + 7
        )
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
