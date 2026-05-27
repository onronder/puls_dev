-- 10 PR10.13 Leave Type Lifecycle Audit — executable smoke (single transaction; rolls back)
--
-- Fixture prefix: demo_leave_type_lifecycle_audit_*
-- Cleanup order: leave_requests first, leave_type_lifecycle_events, leave_types, fixture policies.
-- Backward-compat: one-arg deactivate_leave_type(id) after dropping old (UUID) overload.
-- Reason-too-long: active leave type with no open requests (policy binding OK).

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_employee_id UUID;
  v_policy_id UUID;
  v_leave_type_id UUID;
  v_leave_type_id_reason UUID;
  v_leave_type_id_omitted UUID;
  v_leave_type_id_long_reason UUID;
  v_leave_type_id_draft UUID;
  v_leave_type_id_open UUID;
  v_leave_type_id_past UUID;
  v_leave_type_id_policy UUID;
  v_result JSONB;
  v_event_count INTEGER;
  v_event_count_before INTEGER;
  v_reason TEXT;
  v_latest_action TEXT;
  v_is_active BOOLEAN;
  v_long_reason TEXT;
  v_status TEXT;
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

  DELETE FROM puls_workflow.leave_requests lr
  USING puls_workflow.leave_types lt
  WHERE lr.leave_type_id = lt.id
    AND lt.tenant_id = v_tenant_id
    AND lt.code LIKE 'demo_leave_type_lifecycle_audit%';

  DELETE FROM puls_workflow.leave_type_lifecycle_events ev
  USING puls_workflow.leave_types lt
  WHERE ev.leave_type_id = lt.id
    AND lt.tenant_id = v_tenant_id
    AND lt.code LIKE 'demo_leave_type_lifecycle_audit%';

  DELETE FROM puls_workflow.leave_types
  WHERE tenant_id = v_tenant_id
    AND code LIKE 'demo_leave_type_lifecycle_audit%';

  -- ---------------------------------------------------------------------------
  -- Deactivate with trimmed reason
  -- ---------------------------------------------------------------------------

  INSERT INTO puls_workflow.leave_types (
    tenant_id, code, name, default_entitlement_days, requires_document, carry_over_allowed, is_active
  ) VALUES (
    v_tenant_id, 'demo_leave_type_lifecycle_audit_fresh', 'Demo Leave Audit Fresh', 10, FALSE, FALSE, TRUE
  )
  RETURNING id INTO v_leave_type_id;

  v_result := puls_workflow.deactivate_leave_type(v_leave_type_id, '  smoke audit reason  ');
  IF v_result->>'status' <> 'deactivated' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected deactivated, got %', v_result;
  END IF;

  IF v_result->>'event_id' IS NULL OR BTRIM(v_result->>'event_id') = '' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected event_id on deactivated result';
  END IF;

  SELECT reason INTO v_reason
  FROM puls_workflow.leave_type_lifecycle_events
  WHERE leave_type_id = v_leave_type_id
    AND action = 'deactivated'
  ORDER BY occurred_at DESC, id DESC
  LIMIT 1;

  IF v_reason IS DISTINCT FROM 'smoke audit reason' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected trimmed reason, got %', v_reason;
  END IF;

  -- ---------------------------------------------------------------------------
  -- Deactivate blank reason (explicit empty/whitespace arg)
  -- ---------------------------------------------------------------------------

  INSERT INTO puls_workflow.leave_types (
    tenant_id, code, name, default_entitlement_days, requires_document, carry_over_allowed, is_active
  ) VALUES (
    v_tenant_id, 'demo_leave_type_lifecycle_audit_blank', 'Demo Leave Audit Blank', 10, FALSE, FALSE, TRUE
  )
  RETURNING id INTO v_leave_type_id_reason;

  v_result := puls_workflow.deactivate_leave_type(v_leave_type_id_reason, '   ');
  IF v_result->>'status' <> 'deactivated' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected deactivated for blank reason, got %', v_result;
  END IF;

  SELECT reason INTO v_reason
  FROM puls_workflow.leave_type_lifecycle_events
  WHERE leave_type_id = v_leave_type_id_reason
    AND action = 'deactivated'
  ORDER BY occurred_at DESC, id DESC
  LIMIT 1;

  IF v_reason IS NOT NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL: blank reason should persist as NULL, got %', v_reason;
  END IF;

  -- ---------------------------------------------------------------------------
  -- Deactivate with omitted reason arg (backward compat after DROP single-arg fn)
  -- ---------------------------------------------------------------------------

  INSERT INTO puls_workflow.leave_types (
    tenant_id, code, name, default_entitlement_days, requires_document, carry_over_allowed, is_active
  ) VALUES (
    v_tenant_id, 'demo_leave_type_lifecycle_audit_omitted', 'Demo Leave Audit Omitted Reason', 10, FALSE, FALSE, TRUE
  )
  RETURNING id INTO v_leave_type_id_omitted;

  SELECT puls_workflow.deactivate_leave_type(v_leave_type_id_omitted) INTO v_result;
  IF v_result->>'status' <> 'deactivated' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected deactivated for omitted reason arg, got %', v_result;
  END IF;

  IF v_result->>'event_id' IS NULL OR BTRIM(v_result->>'event_id') = '' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected event_id on omitted-reason deactivate result';
  END IF;

  SELECT reason INTO v_reason
  FROM puls_workflow.leave_type_lifecycle_events
  WHERE leave_type_id = v_leave_type_id_omitted
    AND action = 'deactivated'
  ORDER BY occurred_at DESC, id DESC
  LIMIT 1;

  IF v_reason IS NOT NULL THEN
    RAISE EXCEPTION 'SMOKE_FAIL: omitted reason arg should persist as NULL, got %', v_reason;
  END IF;

  -- ---------------------------------------------------------------------------
  -- Re-deactivate (idempotent, no new event)
  -- ---------------------------------------------------------------------------

  SELECT COUNT(*) INTO v_event_count_before
  FROM puls_workflow.leave_type_lifecycle_events
  WHERE leave_type_id = v_leave_type_id;

  v_result := puls_workflow.deactivate_leave_type(v_leave_type_id);
  IF v_result->>'status' <> 'already_inactive' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected already_inactive, got %', v_result;
  END IF;

  SELECT COUNT(*) INTO v_event_count
  FROM puls_workflow.leave_type_lifecycle_events
  WHERE leave_type_id = v_leave_type_id;

  IF v_event_count <> v_event_count_before THEN
    RAISE EXCEPTION 'SMOKE_FAIL: idempotent deactivate should not insert new event (before=%, after=%)',
      v_event_count_before, v_event_count;
  END IF;

  -- ---------------------------------------------------------------------------
  -- Restore + restored event
  -- ---------------------------------------------------------------------------

  v_result := puls_workflow.restore_leave_type(v_leave_type_id);
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
  FROM puls_workflow.leave_type_lifecycle_events
  WHERE leave_type_id = v_leave_type_id;

  v_result := puls_workflow.restore_leave_type(v_leave_type_id);
  IF v_result->>'status' <> 'already_active' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected already_active, got %', v_result;
  END IF;

  SELECT COUNT(*) INTO v_event_count
  FROM puls_workflow.leave_type_lifecycle_events
  WHERE leave_type_id = v_leave_type_id;

  IF v_event_count <> v_event_count_before THEN
    RAISE EXCEPTION 'SMOKE_FAIL: idempotent restore should not insert new event (before=%, after=%)',
      v_event_count_before, v_event_count;
  END IF;

  -- ---------------------------------------------------------------------------
  -- Reason > 500 on ACTIVE leave type with no open requests (must stay active, no event)
  -- ---------------------------------------------------------------------------

  INSERT INTO puls_workflow.leave_types (
    tenant_id, code, name, default_entitlement_days, requires_document, carry_over_allowed, is_active
  ) VALUES (
    v_tenant_id, 'demo_leave_type_lifecycle_audit_long_reason', 'Demo Leave Audit Long Reason', 10, FALSE, FALSE, TRUE
  )
  RETURNING id INTO v_leave_type_id_long_reason;

  v_long_reason := repeat('x', 501);

  BEGIN
    v_result := puls_workflow.deactivate_leave_type(v_leave_type_id_long_reason, v_long_reason);
    RAISE EXCEPTION 'SMOKE_FAIL: expected PULS_LEAVE_TYPE_LIFECYCLE_REASON_TOO_LONG';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_LEAVE_TYPE_LIFECYCLE_REASON_TOO_LONG%' THEN
        RAISE;
      END IF;
  END;

  SELECT is_active INTO v_is_active
  FROM puls_workflow.leave_types
  WHERE id = v_leave_type_id_long_reason;

  IF v_is_active IS NOT TRUE THEN
    RAISE EXCEPTION 'SMOKE_FAIL: reason-too-long must leave leave type active (is_active=%)', v_is_active;
  END IF;

  SELECT COUNT(*) INTO v_event_count
  FROM puls_workflow.leave_type_lifecycle_events
  WHERE leave_type_id = v_leave_type_id_long_reason;

  IF v_event_count <> 0 THEN
    RAISE EXCEPTION 'SMOKE_FAIL: reason-too-long must not insert audit event, count=%', v_event_count;
  END IF;

  -- ---------------------------------------------------------------------------
  -- History read (deterministic order: occurred_at DESC, id DESC)
  -- ---------------------------------------------------------------------------

  SELECT action INTO v_latest_action
  FROM puls_workflow.leave_type_lifecycle_events
  WHERE leave_type_id = v_leave_type_id
  ORDER BY occurred_at DESC, id DESC
  LIMIT 1;

  IF v_latest_action <> 'restored' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: latest lifecycle event should be restored, got %', v_latest_action;
  END IF;

  SELECT COUNT(*) INTO v_event_count
  FROM puls_workflow.leave_type_lifecycle_events
  WHERE leave_type_id = v_leave_type_id
    AND action IN ('deactivated', 'restored');

  IF v_event_count < 2 THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected at least deactivated + restored events, got %', v_event_count;
  END IF;

  -- ---------------------------------------------------------------------------
  -- Open draft/pending block (no audit event)
  -- ---------------------------------------------------------------------------

  INSERT INTO puls_workflow.leave_types (
    tenant_id, code, name, default_entitlement_days, requires_document, carry_over_allowed, is_active
  ) VALUES (
    v_tenant_id, 'demo_leave_type_lifecycle_audit_draft', 'Demo Leave Audit Draft', 10, FALSE, FALSE, TRUE
  )
  RETURNING id INTO v_leave_type_id_draft;

  FOR v_status IN SELECT unnest(ARRAY['draft', 'pending']) LOOP
    DELETE FROM puls_workflow.leave_requests
    WHERE leave_type_id = v_leave_type_id_draft AND tenant_id = v_tenant_id;

    INSERT INTO puls_workflow.leave_requests (
      tenant_id, employee_id, leave_type_id, start_date, end_date, business_days, status
    ) VALUES (
      v_tenant_id, v_employee_id, v_leave_type_id_draft,
      CURRENT_DATE + 7, CURRENT_DATE + 7, 1, v_status::puls_workflow.leave_request_status
    );

    BEGIN
      v_result := puls_workflow.deactivate_leave_type(v_leave_type_id_draft, 'blocked');
      RAISE EXCEPTION 'SMOKE_FAIL: % request should block deactivate', v_status;
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLERRM NOT LIKE '%PULS_LEAVE_TYPE_IN_USE_ACTIVE_REQUESTS%' THEN
          RAISE;
        END IF;
    END;

    SELECT COUNT(*) INTO v_event_count
    FROM puls_workflow.leave_type_lifecycle_events
    WHERE leave_type_id = v_leave_type_id_draft;

    IF v_event_count <> 0 THEN
      RAISE EXCEPTION 'SMOKE_FAIL: open-% block must not insert audit event, count=%', v_status, v_event_count;
    END IF;
  END LOOP;

  DELETE FROM puls_workflow.leave_requests
  WHERE leave_type_id = v_leave_type_id_draft AND tenant_id = v_tenant_id;

  -- ---------------------------------------------------------------------------
  -- Approved future/current block (no audit event)
  -- ---------------------------------------------------------------------------

  INSERT INTO puls_workflow.leave_types (
    tenant_id, code, name, default_entitlement_days, requires_document, carry_over_allowed, is_active
  ) VALUES (
    v_tenant_id, 'demo_leave_type_lifecycle_audit_open', 'Demo Leave Audit Open Approved', 10, FALSE, FALSE, TRUE
  )
  RETURNING id INTO v_leave_type_id_open;

  INSERT INTO puls_workflow.leave_requests (
    tenant_id, employee_id, leave_type_id, start_date, end_date, business_days, status, approved_at
  ) VALUES (
    v_tenant_id, v_employee_id, v_leave_type_id_open,
    CURRENT_DATE, CURRENT_DATE + 3, 2, 'approved', NOW()
  );

  BEGIN
    v_result := puls_workflow.deactivate_leave_type(v_leave_type_id_open, 'blocked');
    RAISE EXCEPTION 'SMOKE_FAIL: approved future/current should block deactivate';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%PULS_LEAVE_TYPE_IN_USE_ACTIVE_REQUESTS%' THEN
        RAISE;
      END IF;
  END;

  SELECT COUNT(*) INTO v_event_count
  FROM puls_workflow.leave_type_lifecycle_events
  WHERE leave_type_id = v_leave_type_id_open;

  IF v_event_count <> 0 THEN
    RAISE EXCEPTION 'SMOKE_FAIL: approved future block must not insert audit event, count=%', v_event_count;
  END IF;

  -- ---------------------------------------------------------------------------
  -- Approved past only — deactivate allowed; event inserted
  -- ---------------------------------------------------------------------------

  INSERT INTO puls_workflow.leave_types (
    tenant_id, code, name, default_entitlement_days, requires_document, carry_over_allowed, is_active
  ) VALUES (
    v_tenant_id, 'demo_leave_type_lifecycle_audit_past', 'Demo Leave Audit Past Approved', 10, FALSE, FALSE, TRUE
  )
  RETURNING id INTO v_leave_type_id_past;

  INSERT INTO puls_workflow.leave_requests (
    tenant_id, employee_id, leave_type_id, start_date, end_date, business_days, status, approved_at
  ) VALUES (
    v_tenant_id, v_employee_id, v_leave_type_id_past,
    CURRENT_DATE - 30, CURRENT_DATE - 28, 2, 'approved', NOW() - INTERVAL '29 days'
  );

  v_result := puls_workflow.deactivate_leave_type(v_leave_type_id_past, 'past approved ok');
  IF v_result->>'status' <> 'deactivated' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: approved past only should allow deactivate, got %', v_result;
  END IF;

  IF v_result->>'event_id' IS NULL OR BTRIM(v_result->>'event_id') = '' THEN
    RAISE EXCEPTION 'SMOKE_FAIL: expected event_id on past-approved deactivate';
  END IF;

  -- ---------------------------------------------------------------------------
  -- Policy-bound leave type still deactivates (no PULS_LEAVE_TYPE_ACTIVE_POLICY_BOUND)
  -- ---------------------------------------------------------------------------

  IF v_policy_id IS NOT NULL THEN
    INSERT INTO puls_workflow.leave_types (
      tenant_id, code, name, default_entitlement_days, requires_document, carry_over_allowed,
      is_active, approval_policy_id
    ) VALUES (
      v_tenant_id, 'demo_leave_type_lifecycle_audit_policy', 'Demo Leave Audit Policy', 10, FALSE, FALSE,
      TRUE, v_policy_id
    )
    RETURNING id INTO v_leave_type_id_policy;

    v_result := puls_workflow.deactivate_leave_type(v_leave_type_id_policy, 'policy bound ok');
    IF v_result->>'status' <> 'deactivated' THEN
      RAISE EXCEPTION 'SMOKE_FAIL: policy-bound leave type should deactivate, got %', v_result;
    END IF;
  ELSE
    RAISE NOTICE 'SKIP: no active approval policy for policy-bound audit smoke';
  END IF;
END;
$$;

ROLLBACK;
