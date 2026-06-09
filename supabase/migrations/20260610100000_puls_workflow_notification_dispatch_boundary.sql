-- PR17.2D: connector-independent workflow notification dispatch.
-- Live leave/expense workflow events now emit metadata-only in-app notifications
-- inside the workflow transaction, without waiting for the connector worker.

CREATE OR REPLACE FUNCTION puls_app.emit_workflow_app_notification_internal(
  p_tenant_id UUID,
  p_source_event_key TEXT,
  p_title_key TEXT,
  p_source_table TEXT,
  p_source_id UUID,
  p_severity TEXT,
  p_priority INTEGER,
  p_target_employee_ids UUID[],
  p_subject_type TEXT,
  p_subject_id UUID,
  p_body_key TEXT,
  p_route_hint TEXT,
  p_action_key TEXT,
  p_dedupe_key TEXT,
  p_safe_summary JSONB,
  p_occurred_at TIMESTAMPTZ DEFAULT NOW()
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_app, puls_core
AS $$
DECLARE
  v_target_employee_ids UUID[] := COALESCE(p_target_employee_ids, '{}'::UUID[]);
  v_safe_summary JSONB := COALESCE(p_safe_summary, '{}'::JSONB);
  v_dedupe_key TEXT := NULLIF(BTRIM(COALESCE(p_dedupe_key, '')), '');
  v_occurred_at TIMESTAMPTZ := COALESCE(p_occurred_at, NOW());
  v_notification_id UUID;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION
      'PULS_WORKFLOW_NOTIFICATION_TENANT_REQUIRED: tenant is required.'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM puls_core.tenants tenant WHERE tenant.id = p_tenant_id) THEN
    RAISE EXCEPTION
      'PULS_WORKFLOW_NOTIFICATION_TENANT_NOT_FOUND: tenant was not found.'
      USING ERRCODE = 'P0001';
  END IF;

  IF COALESCE(p_source_event_key, '') NOT IN (
    'leave_approval_requested',
    'expense_approval_requested',
    'leave_request_approved',
    'leave_request_rejected',
    'expense_claim_approved',
    'expense_claim_rejected'
  ) THEN
    RAISE EXCEPTION
      'PULS_WORKFLOW_NOTIFICATION_EVENT_INVALID: workflow event is invalid.'
      USING ERRCODE = 'P0001';
  END IF;

  IF COALESCE(p_source_table, '') NOT IN (
    'puls_workflow.approval_requests',
    'puls_workflow.leave_requests',
    'puls_workflow.expense_claims'
  ) THEN
    RAISE EXCEPTION
      'PULS_WORKFLOW_NOTIFICATION_SOURCE_TABLE_INVALID: source table is invalid.'
      USING ERRCODE = 'P0001';
  END IF;

  IF p_source_id IS NULL OR p_subject_id IS NULL THEN
    RAISE EXCEPTION
      'PULS_WORKFLOW_NOTIFICATION_SOURCE_REQUIRED: source and subject ids are required.'
      USING ERRCODE = 'P0001';
  END IF;

  IF COALESCE(p_severity, '') NOT IN ('info', 'success', 'warning', 'error', 'critical') THEN
    RAISE EXCEPTION
      'PULS_WORKFLOW_NOTIFICATION_SEVERITY_INVALID: severity is invalid.'
      USING ERRCODE = 'P0001';
  END IF;

  IF COALESCE(p_priority, -1) NOT BETWEEN 0 AND 100 THEN
    RAISE EXCEPTION
      'PULS_WORKFLOW_NOTIFICATION_PRIORITY_INVALID: priority must be between 0 and 100.'
      USING ERRCODE = 'P0001';
  END IF;

  IF cardinality(v_target_employee_ids) = 0
     OR array_position(v_target_employee_ids, NULL) IS NOT NULL THEN
    RAISE EXCEPTION
      'PULS_WORKFLOW_NOTIFICATION_TARGET_INVALID: target employee is required.'
      USING ERRCODE = 'P0001';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM unnest(v_target_employee_ids) target(employee_id)
    LEFT JOIN puls_core.employees employee
      ON employee.id = target.employee_id
     AND employee.tenant_id = p_tenant_id
    WHERE employee.id IS NULL
  ) THEN
    RAISE EXCEPTION
      'PULS_WORKFLOW_NOTIFICATION_TARGET_TENANT_MISMATCH: target employee is outside tenant.'
      USING ERRCODE = 'P0001';
  END IF;

  IF COALESCE(p_subject_type, '') NOT IN ('leave_request', 'expense_claim') THEN
    RAISE EXCEPTION
      'PULS_WORKFLOW_NOTIFICATION_SUBJECT_INVALID: subject type is invalid.'
      USING ERRCODE = 'P0001';
  END IF;

  IF COALESCE(p_route_hint, '') NOT IN ('workflow.leave', 'workflow.expense') THEN
    RAISE EXCEPTION
      'PULS_WORKFLOW_NOTIFICATION_ROUTE_INVALID: route hint is invalid.'
      USING ERRCODE = 'P0001';
  END IF;

  IF COALESCE(p_action_key, '') NOT IN ('review_workflow_approval', 'view_workflow_request') THEN
    RAISE EXCEPTION
      'PULS_WORKFLOW_NOTIFICATION_ACTION_INVALID: action key is invalid.'
      USING ERRCODE = 'P0001';
  END IF;

  IF NULLIF(BTRIM(COALESCE(p_title_key, '')), '') IS NULL
     OR NULLIF(BTRIM(COALESCE(p_body_key, '')), '') IS NULL
     OR v_dedupe_key IS NULL THEN
    RAISE EXCEPTION
      'PULS_WORKFLOW_NOTIFICATION_METADATA_REQUIRED: title, body, and dedupe key are required.'
      USING ERRCODE = 'P0001';
  END IF;

  IF jsonb_typeof(v_safe_summary) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION
      'PULS_WORKFLOW_NOTIFICATION_SAFE_SUMMARY_OBJECT_REQUIRED: safe summary must be an object.'
      USING ERRCODE = 'P0001';
  END IF;

  IF puls_app._app_notification_safe_summary_has_blocked_key(v_safe_summary) THEN
    RAISE EXCEPTION
      'PULS_WORKFLOW_NOTIFICATION_SAFE_SUMMARY_BLOCKED_KEY: safe summary contains blocked keys.'
      USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO puls_app.app_notifications (
    tenant_id,
    source_domain,
    source_event_key,
    source_table,
    source_id,
    severity,
    priority,
    target_roles,
    target_employee_ids,
    subject_type,
    subject_id,
    title_key,
    body_key,
    route_hint,
    action_key,
    dedupe_key,
    safe_summary,
    occurred_at,
    expires_at
  )
  VALUES (
    p_tenant_id,
    'puls_workflow',
    p_source_event_key,
    p_source_table,
    p_source_id,
    p_severity,
    p_priority,
    ARRAY[]::TEXT[],
    v_target_employee_ids,
    p_subject_type,
    p_subject_id,
    BTRIM(p_title_key),
    BTRIM(p_body_key),
    p_route_hint,
    p_action_key,
    v_dedupe_key,
    v_safe_summary || jsonb_build_object(
      'workflow_dispatch_contract_version', 'pr17.2d-workflow-notification-dispatch-v1',
      'workflow_notification_dispatch', TRUE,
      'connector_independent_delivery', TRUE,
      'notification_ledger', TRUE,
      'notification_realtime_enabled', FALSE,
      'external_delivery_enabled', FALSE,
      'source_writeback', FALSE,
      'provider_api_calls', FALSE,
      'credential_readback', FALSE,
      'raw_payload_readback', FALSE,
      'field_value_readback', FALSE,
      'snapshot_payload_readback', FALSE,
      'browser_direct_table_write', FALSE
    ),
    v_occurred_at,
    v_occurred_at + INTERVAL '90 days'
  )
  ON CONFLICT ON CONSTRAINT app_notifications_tenant_dedupe_unique DO NOTHING
  RETURNING id INTO v_notification_id;

  IF v_notification_id IS NULL THEN
    SELECT notification.id
    INTO v_notification_id
    FROM puls_app.app_notifications notification
    WHERE notification.tenant_id = p_tenant_id
      AND notification.dedupe_key = v_dedupe_key;
  END IF;

  RETURN v_notification_id;
END;
$$;

CREATE OR REPLACE FUNCTION puls_workflow.dispatch_approval_request_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_app, puls_core
AS $$
DECLARE
  v_leave_request RECORD;
  v_expense_claim RECORD;
BEGIN
  IF TG_OP <> 'INSERT'
     OR NEW.status <> 'pending'::puls_workflow.approval_status
     OR NEW.approver_employee_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.module = 'leave'::puls_workflow.approval_module
     AND NEW.leave_request_id IS NOT NULL THEN
    SELECT lr.*
    INTO v_leave_request
    FROM puls_workflow.leave_requests lr
    WHERE lr.id = NEW.leave_request_id
      AND lr.tenant_id = NEW.tenant_id;

    IF FOUND AND v_leave_request.status = 'pending'::puls_workflow.leave_request_status THEN
      PERFORM puls_app.emit_workflow_app_notification_internal(
        p_tenant_id := NEW.tenant_id,
        p_source_event_key := 'leave_approval_requested',
        p_title_key := 'notifications.workflow.leaveApprovalRequested.title',
        p_source_table := 'puls_workflow.approval_requests',
        p_source_id := NEW.id,
        p_severity := 'warning',
        p_priority := 80,
        p_target_employee_ids := ARRAY[NEW.approver_employee_id]::UUID[],
        p_subject_type := 'leave_request',
        p_subject_id := v_leave_request.id,
        p_body_key := 'notifications.workflow.leaveApprovalRequested.body',
        p_route_hint := 'workflow.leave',
        p_action_key := 'review_workflow_approval',
        p_dedupe_key := concat_ws(':', 'pr17.2a', 'leave_approval_requested', NEW.id::TEXT, NEW.approver_employee_id::TEXT),
        p_safe_summary := jsonb_build_object(
          'contract_version', 'pr17.2a-workflow-notifications-v1',
          'source_domain', 'puls_workflow',
          'source_event_key', 'leave_approval_requested',
          'workflow_module', 'leave',
          'workflow_status', v_leave_request.status::TEXT,
          'approval_status', NEW.status::TEXT,
          'approval_request_id', NEW.id,
          'leave_request_id', v_leave_request.id,
          'requester_employee_id', NEW.requester_employee_id,
          'approver_employee_id', NEW.approver_employee_id,
          'step_order', NEW.step_order,
          'target', 'approver',
          'notification_window_days', 90
        ),
        p_occurred_at := COALESCE(NEW.created_at, NOW())
      );
    END IF;
  ELSIF NEW.module = 'expense'::puls_workflow.approval_module
     AND NEW.expense_claim_id IS NOT NULL THEN
    SELECT ec.*
    INTO v_expense_claim
    FROM puls_workflow.expense_claims ec
    WHERE ec.id = NEW.expense_claim_id
      AND ec.tenant_id = NEW.tenant_id;

    IF FOUND AND v_expense_claim.status = 'pending'::puls_workflow.expense_claim_status THEN
      PERFORM puls_app.emit_workflow_app_notification_internal(
        p_tenant_id := NEW.tenant_id,
        p_source_event_key := 'expense_approval_requested',
        p_title_key := 'notifications.workflow.expenseApprovalRequested.title',
        p_source_table := 'puls_workflow.approval_requests',
        p_source_id := NEW.id,
        p_severity := 'warning',
        p_priority := 80,
        p_target_employee_ids := ARRAY[NEW.approver_employee_id]::UUID[],
        p_subject_type := 'expense_claim',
        p_subject_id := v_expense_claim.id,
        p_body_key := 'notifications.workflow.expenseApprovalRequested.body',
        p_route_hint := 'workflow.expense',
        p_action_key := 'review_workflow_approval',
        p_dedupe_key := concat_ws(':', 'pr17.2a', 'expense_approval_requested', NEW.id::TEXT, NEW.approver_employee_id::TEXT),
        p_safe_summary := jsonb_build_object(
          'contract_version', 'pr17.2a-workflow-notifications-v1',
          'source_domain', 'puls_workflow',
          'source_event_key', 'expense_approval_requested',
          'workflow_module', 'expense',
          'workflow_status', v_expense_claim.status::TEXT,
          'approval_status', NEW.status::TEXT,
          'approval_request_id', NEW.id,
          'expense_claim_id', v_expense_claim.id,
          'requester_employee_id', NEW.requester_employee_id,
          'approver_employee_id', NEW.approver_employee_id,
          'step_order', NEW.step_order,
          'policy_status', v_expense_claim.policy_status::TEXT,
          'target', 'approver',
          'notification_window_days', 90
        ),
        p_occurred_at := COALESCE(NEW.created_at, NOW())
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION puls_workflow.dispatch_leave_request_decision_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_app, puls_core
AS $$
DECLARE
  v_source_event_key TEXT;
BEGIN
  IF TG_OP <> 'UPDATE'
     OR OLD.status IS NOT DISTINCT FROM NEW.status
     OR NEW.status NOT IN (
       'approved'::puls_workflow.leave_request_status,
       'rejected'::puls_workflow.leave_request_status
     ) THEN
    RETURN NEW;
  END IF;

  v_source_event_key := CASE NEW.status::TEXT
    WHEN 'approved' THEN 'leave_request_approved'
    ELSE 'leave_request_rejected'
  END;

  PERFORM puls_app.emit_workflow_app_notification_internal(
    p_tenant_id := NEW.tenant_id,
    p_source_event_key := v_source_event_key,
    p_title_key := CASE NEW.status::TEXT
      WHEN 'approved' THEN 'notifications.workflow.leaveApproved.title'
      ELSE 'notifications.workflow.leaveRejected.title'
    END,
    p_source_table := 'puls_workflow.leave_requests',
    p_source_id := NEW.id,
    p_severity := CASE NEW.status::TEXT
      WHEN 'approved' THEN 'success'
      ELSE 'info'
    END,
    p_priority := 65,
    p_target_employee_ids := ARRAY[NEW.employee_id]::UUID[],
    p_subject_type := 'leave_request',
    p_subject_id := NEW.id,
    p_body_key := CASE NEW.status::TEXT
      WHEN 'approved' THEN 'notifications.workflow.leaveApproved.body'
      ELSE 'notifications.workflow.leaveRejected.body'
    END,
    p_route_hint := 'workflow.leave',
    p_action_key := 'view_workflow_request',
    p_dedupe_key := concat_ws(':', 'pr17.2a', 'leave_request_decision', NEW.id::TEXT, NEW.status::TEXT, NEW.employee_id::TEXT),
    p_safe_summary := jsonb_build_object(
      'contract_version', 'pr17.2a-workflow-notifications-v1',
      'source_domain', 'puls_workflow',
      'source_event_key', v_source_event_key,
      'workflow_module', 'leave',
      'workflow_status', NEW.status::TEXT,
      'leave_request_id', NEW.id,
      'requester_employee_id', NEW.employee_id,
      'business_days', NEW.business_days,
      'target', 'requester',
      'notification_window_days', 90
    ),
    p_occurred_at := COALESCE(NEW.approved_at, NEW.rejected_at, NEW.updated_at, NOW())
  );

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION puls_workflow.dispatch_expense_claim_decision_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_workflow, puls_app, puls_core
AS $$
DECLARE
  v_source_event_key TEXT;
BEGIN
  IF TG_OP <> 'UPDATE'
     OR OLD.status IS NOT DISTINCT FROM NEW.status
     OR NEW.status NOT IN (
       'approved'::puls_workflow.expense_claim_status,
       'rejected'::puls_workflow.expense_claim_status
     ) THEN
    RETURN NEW;
  END IF;

  v_source_event_key := CASE NEW.status::TEXT
    WHEN 'approved' THEN 'expense_claim_approved'
    ELSE 'expense_claim_rejected'
  END;

  PERFORM puls_app.emit_workflow_app_notification_internal(
    p_tenant_id := NEW.tenant_id,
    p_source_event_key := v_source_event_key,
    p_title_key := CASE NEW.status::TEXT
      WHEN 'approved' THEN 'notifications.workflow.expenseApproved.title'
      ELSE 'notifications.workflow.expenseRejected.title'
    END,
    p_source_table := 'puls_workflow.expense_claims',
    p_source_id := NEW.id,
    p_severity := CASE NEW.status::TEXT
      WHEN 'approved' THEN 'success'
      ELSE 'info'
    END,
    p_priority := 65,
    p_target_employee_ids := ARRAY[NEW.employee_id]::UUID[],
    p_subject_type := 'expense_claim',
    p_subject_id := NEW.id,
    p_body_key := CASE NEW.status::TEXT
      WHEN 'approved' THEN 'notifications.workflow.expenseApproved.body'
      ELSE 'notifications.workflow.expenseRejected.body'
    END,
    p_route_hint := 'workflow.expense',
    p_action_key := 'view_workflow_request',
    p_dedupe_key := concat_ws(':', 'pr17.2a', 'expense_claim_decision', NEW.id::TEXT, NEW.status::TEXT, NEW.employee_id::TEXT),
    p_safe_summary := jsonb_build_object(
      'contract_version', 'pr17.2a-workflow-notifications-v1',
      'source_domain', 'puls_workflow',
      'source_event_key', v_source_event_key,
      'workflow_module', 'expense',
      'workflow_status', NEW.status::TEXT,
      'expense_claim_id', NEW.id,
      'requester_employee_id', NEW.employee_id,
      'policy_status', NEW.policy_status::TEXT,
      'target', 'requester',
      'notification_window_days', 90
    ),
    p_occurred_at := COALESCE(NEW.approved_at, NEW.rejected_at, NEW.updated_at, NOW())
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS puls_workflow_approval_requests_notification_dispatch
  ON puls_workflow.approval_requests;
CREATE TRIGGER puls_workflow_approval_requests_notification_dispatch
  AFTER INSERT ON puls_workflow.approval_requests
  FOR EACH ROW
  EXECUTE FUNCTION puls_workflow.dispatch_approval_request_notification();

DROP TRIGGER IF EXISTS puls_workflow_leave_requests_notification_dispatch
  ON puls_workflow.leave_requests;
CREATE TRIGGER puls_workflow_leave_requests_notification_dispatch
  AFTER UPDATE OF status ON puls_workflow.leave_requests
  FOR EACH ROW
  EXECUTE FUNCTION puls_workflow.dispatch_leave_request_decision_notification();

DROP TRIGGER IF EXISTS puls_workflow_expense_claims_notification_dispatch
  ON puls_workflow.expense_claims;
CREATE TRIGGER puls_workflow_expense_claims_notification_dispatch
  AFTER UPDATE OF status ON puls_workflow.expense_claims
  FOR EACH ROW
  EXECUTE FUNCTION puls_workflow.dispatch_expense_claim_decision_notification();

REVOKE ALL ON FUNCTION puls_app.emit_workflow_app_notification_internal(
  UUID, TEXT, TEXT, TEXT, UUID, TEXT, INTEGER, UUID[], TEXT, UUID, TEXT, TEXT,
  TEXT, TEXT, JSONB, TIMESTAMPTZ
) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION puls_workflow.dispatch_approval_request_notification()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION puls_workflow.dispatch_leave_request_decision_notification()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION puls_workflow.dispatch_expense_claim_decision_notification()
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION puls_app.emit_workflow_app_notification_internal(
  UUID, TEXT, TEXT, TEXT, UUID, TEXT, INTEGER, UUID[], TEXT, UUID, TEXT, TEXT,
  TEXT, TEXT, JSONB, TIMESTAMPTZ
) TO service_role;
GRANT EXECUTE ON FUNCTION puls_workflow.dispatch_approval_request_notification()
  TO service_role;
GRANT EXECUTE ON FUNCTION puls_workflow.dispatch_leave_request_decision_notification()
  TO service_role;
GRANT EXECUTE ON FUNCTION puls_workflow.dispatch_expense_claim_decision_notification()
  TO service_role;

COMMENT ON FUNCTION puls_app.emit_workflow_app_notification_internal(
  UUID, TEXT, TEXT, TEXT, UUID, TEXT, INTEGER, UUID[], TEXT, UUID, TEXT, TEXT,
  TEXT, TEXT, JSONB, TIMESTAMPTZ
) IS
  'PR17.2D internal workflow-only in-app notification emitter. Trigger-owned, metadata-only, connector-independent, no browser grant.';

COMMENT ON FUNCTION puls_workflow.dispatch_approval_request_notification() IS
  'PR17.2D emits assigned approval notifications when workflow approval requests are inserted.';

COMMENT ON FUNCTION puls_workflow.dispatch_leave_request_decision_notification() IS
  'PR17.2D emits requester notifications when leave requests become approved or rejected.';

COMMENT ON FUNCTION puls_workflow.dispatch_expense_claim_decision_notification() IS
  'PR17.2D emits requester notifications when expense claims become approved or rejected.';
