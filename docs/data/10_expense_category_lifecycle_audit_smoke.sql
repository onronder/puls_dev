-- 10 PR10.9 Expense Category Lifecycle Audit — executable smoke (single transaction; rolls back)

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_employee_id UUID;
  v_policy_id UUID;
  v_category_id UUID;
  v_category_id_reason UUID;
  v_category_id_long_reason UUID;
  v_category_id_draft UUID;
  v_category_id_policy UUID;
  v_result JSONB;
  v_event_count INTEGER;
  v_event_count_before INTEGER;
  v_reason TEXT;
  v_latest_action TEXT;
  v_is_active BOOLEAN;
  v_long_reason TEXT;
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
    RAISE EXCEPTION 'SMOKE_SETUP_FAIL: expected at least one employee for lifecycle audit smoke';
  END IF;

  SELECT ap.id INTO v_policy_id
  FROM puls_workflow.approval_policies ap
  WHERE ap.tenant_id = v_tenant_id
    AND ap.is_active = TRUE
  LIMIT 1;

  DELETE FROM puls_workflow.expense_category_lifecycle_events ev
  USING puls_workflow.expense_categories cat
  WHERE ev.category_id = cat.id
    AND cat.tenant_id = v_tenant_id
    AND cat.code LIKE 'demo_lifecycle_audit%';

  DELETE FROM puls_workflow.expense_claims ec
  USING puls_workflow.expense_categories cat
  WHERE ec.category_id = cat.id
    AND cat.tenant_id = v_tenant_id
    AND cat.code LIKE 'demo_lifecycle_audit%';

  DELETE FROM puls_workflow.expense_categories
  WHERE tenant_id = v_tenant_id
    AND code LIKE 'demo_lifecycle_audit%';

  -- ---------------------------------------------------------------------------
  -- Deactivate with trimmed reason
  -- ---------------------------------------------------------------------------

  INSERT INTO puls_workflow.expense_categories (
    tenant_id, code, name, monthly_limit, receipt_required_over, is_active
  ) VALUES (
    v_tenant_id, 'demo_lifecycle_audit_fresh', 'Demo Lifecycle Audit Fresh', 1000, 100, TRUE
  )
  RETURNING id INTO v_category_id;

  v_result := puls_workflow.deactivate_expense_category(v_category_id, '  smoke audit reason  ');
  IF v_result->>'status' <> 'deactivated' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected deactivated, got %', v_result;
  END IF;

  IF v_result->>'event_id' IS NULL OR BTRIM(v_result->>'event_id') = '' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected event_id on deactivated result';
  END IF;

  SELECT reason INTO v_reason
  FROM puls_workflow.expense_category_lifecycle_events
  WHERE category_id = v_category_id
    AND action = 'deactivated'
  ORDER BY occurred_at DESC, id DESC
  LIMIT 1;

  IF v_reason IS DISTINCT FROM 'smoke audit reason' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected trimmed reason, got %', v_reason;
  END IF;

  -- ---------------------------------------------------------------------------
  -- Deactivate blank reason (separate active category)
  -- ---------------------------------------------------------------------------

  INSERT INTO puls_workflow.expense_categories (
    tenant_id, code, name, monthly_limit, receipt_required_over, is_active
  ) VALUES (
    v_tenant_id, 'demo_lifecycle_audit_blank', 'Demo Lifecycle Audit Blank', 1000, 100, TRUE
  )
  RETURNING id INTO v_category_id_reason;

  v_result := puls_workflow.deactivate_expense_category(v_category_id_reason, '   ');
  IF v_result->>'status' <> 'deactivated' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected deactivated for blank reason, got %', v_result;
  END IF;

  SELECT reason INTO v_reason
  FROM puls_workflow.expense_category_lifecycle_events
  WHERE category_id = v_category_id_reason
    AND action = 'deactivated'
  ORDER BY occurred_at DESC, id DESC
  LIMIT 1;

  IF v_reason IS NOT NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL: blank reason should persist as NULL, got %', v_reason;
  END IF;

  -- ---------------------------------------------------------------------------
  -- Re-deactivate (idempotent, no new event)
  -- ---------------------------------------------------------------------------

  SELECT COUNT(*) INTO v_event_count_before
  FROM puls_workflow.expense_category_lifecycle_events
  WHERE category_id = v_category_id;

  v_result := puls_workflow.deactivate_expense_category(v_category_id);
  IF v_result->>'status' <> 'already_inactive' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected already_inactive, got %', v_result;
  END IF;

  SELECT COUNT(*) INTO v_event_count
  FROM puls_workflow.expense_category_lifecycle_events
  WHERE category_id = v_category_id;

  IF v_event_count <> v_event_count_before THEN
    RAISE EXCEPTION 'SMOKE_FAIL: idempotent deactivate should not insert new event (before=%, after=%)',
      v_event_count_before, v_event_count;
  END IF;

  -- ---------------------------------------------------------------------------
  -- Restore + restored event
  -- ---------------------------------------------------------------------------

  v_result := puls_workflow.restore_expense_category(v_category_id);
  IF v_result->>'status' <> 'restored' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected restored, got %', v_result;
  END IF;

  IF v_result->>'event_id' IS NULL OR BTRIM(v_result->>'event_id') = '' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected event_id on restored result';
  END IF;

  -- ---------------------------------------------------------------------------
  -- Re-restore (idempotent, no new event)
  -- ---------------------------------------------------------------------------

  SELECT COUNT(*) INTO v_event_count_before
  FROM puls_workflow.expense_category_lifecycle_events
  WHERE category_id = v_category_id;

  v_result := puls_workflow.restore_expense_category(v_category_id);
  IF v_result->>'status' <> 'already_active' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected already_active, got %', v_result;
  END IF;

  SELECT COUNT(*) INTO v_event_count
  FROM puls_workflow.expense_category_lifecycle_events
  WHERE category_id = v_category_id;

  IF v_event_count <> v_event_count_before THEN
    RAISE EXCEPTION 'SMOKE_FAIL: idempotent restore should not insert new event (before=%, after=%)',
      v_event_count_before, v_event_count;
  END IF;

  -- ---------------------------------------------------------------------------
  -- Reason > 500 on ACTIVE category (must stay active, no event)
  -- ---------------------------------------------------------------------------

  INSERT INTO puls_workflow.expense_categories (
    tenant_id, code, name, monthly_limit, receipt_required_over, is_active
  ) VALUES (
    v_tenant_id, 'demo_lifecycle_audit_long_reason', 'Demo Lifecycle Audit Long Reason', 1000, 100, TRUE
  )
  RETURNING id INTO v_category_id_long_reason;

  v_long_reason := repeat('x', 501);

  BEGIN
    v_result := puls_workflow.deactivate_expense_category(v_category_id_long_reason, v_long_reason);
    RAISE EXCEPTION 'SMOKE_FAIL: expected PULS_EXPENSE_CATEGORY_LIFECYCLE_REASON_TOO_LONG';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_EXPENSE_CATEGORY_LIFECYCLE_REASON_TOO_LONG%' THEN
        RAISE;
      END IF;
  END;

  SELECT is_active INTO v_is_active
  FROM puls_workflow.expense_categories
  WHERE id = v_category_id_long_reason;

  IF v_is_active IS NOT TRUE THEN
    RAISE EXCEPTION 'SMOKE_FAIL: reason-too-long must leave category active (is_active=%)', v_is_active;
  END IF;

  SELECT COUNT(*) INTO v_event_count
  FROM puls_workflow.expense_category_lifecycle_events
  WHERE category_id = v_category_id_long_reason;

  IF v_event_count <> 0 THEN
    RAISE EXCEPTION 'SMOKE_FAIL: reason-too-long must not insert audit event, count=%', v_event_count;
  END IF;

  -- ---------------------------------------------------------------------------
  -- History read (deterministic order: occurred_at DESC, id DESC)
  -- ---------------------------------------------------------------------------

  SELECT action INTO v_latest_action
  FROM puls_workflow.expense_category_lifecycle_events
  WHERE category_id = v_category_id
  ORDER BY occurred_at DESC, id DESC
  LIMIT 1;

  IF v_latest_action <> 'restored' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: latest lifecycle event should be restored, got %', v_latest_action;
  END IF;

  SELECT COUNT(*) INTO v_event_count
  FROM puls_workflow.expense_category_lifecycle_events
  WHERE category_id = v_category_id
    AND action IN ('deactivated', 'restored');

  IF v_event_count < 2 THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected at least deactivated + restored events, got %', v_event_count;
  END IF;

  -- ---------------------------------------------------------------------------
  -- Open claim block (no audit event)
  -- ---------------------------------------------------------------------------

  INSERT INTO puls_workflow.expense_categories (
    tenant_id, code, name, monthly_limit, receipt_required_over, is_active
  ) VALUES (
    v_tenant_id, 'demo_lifecycle_audit_draft', 'Demo Lifecycle Audit Draft', 1000, 100, TRUE
  )
  RETURNING id INTO v_category_id_draft;

  INSERT INTO puls_workflow.expense_claims (
    tenant_id, employee_id, category_id, amount, currency, expense_date, title, status
  ) VALUES (
    v_tenant_id, v_employee_id, v_category_id_draft, 100, 'TRY', CURRENT_DATE, 'Audit smoke draft', 'draft'
  );

  BEGIN
    v_result := puls_workflow.deactivate_expense_category(v_category_id_draft, 'blocked');
    RAISE EXCEPTION 'SMOKE_FAIL: expected PULS_EXPENSE_CATEGORY_IN_USE_ACTIVE_CLAIMS';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_EXPENSE_CATEGORY_IN_USE_ACTIVE_CLAIMS%' THEN
        RAISE;
      END IF;
  END;

  SELECT COUNT(*) INTO v_event_count
  FROM puls_workflow.expense_category_lifecycle_events
  WHERE category_id = v_category_id_draft;

  IF v_event_count <> 0 THEN
    RAISE EXCEPTION 'SMOKE_FAIL: open-claim block must not insert audit event, count=%', v_event_count;
  END IF;

  -- ---------------------------------------------------------------------------
  -- Policy-bound category still deactivates (no PULS_EXPENSE_CATEGORY_ACTIVE_POLICY_BOUND)
  -- ---------------------------------------------------------------------------

  IF v_policy_id IS NOT NULL THEN
    INSERT INTO puls_workflow.expense_categories (
      tenant_id, code, name, monthly_limit, receipt_required_over, is_active, approval_policy_id
    ) VALUES (
      v_tenant_id, 'demo_lifecycle_audit_policy', 'Demo Lifecycle Audit Policy', 1000, 100, TRUE, v_policy_id
    )
    RETURNING id INTO v_category_id_policy;

    v_result := puls_workflow.deactivate_expense_category(v_category_id_policy, 'policy bound ok');
    IF v_result->>'status' <> 'deactivated' THEN
      RAISE EXCEPTION 'SMOKE_FAIL: policy-bound category should deactivate, got %', v_result;
    END IF;
  ELSE
    RAISE NOTICE 'SKIP: no active approval policy for policy-bound audit smoke';
  END IF;
END;
$$;

ROLLBACK;
