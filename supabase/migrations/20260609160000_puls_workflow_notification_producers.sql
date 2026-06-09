-- PR17.2A: workflow notification taxonomy and service-role producers.
-- Keeps app notification emission behind service_role and reuses the existing
-- producer orchestrator that the connector worker already calls.

CREATE OR REPLACE FUNCTION puls_app.refresh_workflow_app_notifications(
  p_limit INTEGER DEFAULT 500,
  p_tenant_id UUID DEFAULT NULL
)
RETURNS TABLE (
  source_event_key TEXT,
  source_table TEXT,
  source_id UUID,
  notification_id UUID,
  inserted BOOLEAN,
  severity TEXT,
  priority INTEGER,
  dedupe_key TEXT,
  action_key TEXT,
  safe_summary JSONB,
  occurred_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_app, puls_core, puls_workflow
AS $$
DECLARE
  v_auth_role TEXT := COALESCE(auth.role(), '');
  v_limit INTEGER := LEAST(GREATEST(COALESCE(p_limit, 500), 1), 500);
  v_candidate RECORD;
  v_emit RECORD;
  v_min_occurred_at TIMESTAMPTZ := NOW() - INTERVAL '90 days';
BEGIN
  IF v_auth_role <> 'service_role' THEN
    RAISE EXCEPTION
      'PULS_WORKFLOW_NOTIFICATION_PRODUCER_SERVICE_ROLE_REQUIRED: workflow notification producers require service_role.'
      USING ERRCODE = 'P0001';
  END IF;

  FOR v_candidate IN
    WITH candidates AS (
      SELECT
        ar.tenant_id,
        'leave_approval_requested'::TEXT AS source_event_key,
        'puls_workflow.approval_requests'::TEXT AS source_table,
        ar.id AS source_id,
        'notifications.workflow.leaveApprovalRequested.title'::TEXT AS title_key,
        'notifications.workflow.leaveApprovalRequested.body'::TEXT AS body_key,
        'warning'::TEXT AS severity,
        80::INTEGER AS priority,
        ARRAY[]::TEXT[] AS target_roles,
        ARRAY[ar.approver_employee_id]::UUID[] AS target_employee_ids,
        'leave_request'::TEXT AS subject_type,
        lr.id AS subject_id,
        'workflow.leave'::TEXT AS route_hint,
        'review_workflow_approval'::TEXT AS action_key,
        concat_ws(':', 'pr17.2a', 'leave_approval_requested', ar.id::TEXT, ar.approver_employee_id::TEXT) AS dedupe_key,
        jsonb_build_object(
          'contract_version', 'pr17.2a-workflow-notifications-v1',
          'source_domain', 'puls_workflow',
          'source_event_key', 'leave_approval_requested',
          'workflow_module', 'leave',
          'workflow_status', lr.status::TEXT,
          'approval_status', ar.status::TEXT,
          'approval_request_id', ar.id,
          'leave_request_id', lr.id,
          'requester_employee_id', ar.requester_employee_id,
          'approver_employee_id', ar.approver_employee_id,
          'step_order', ar.step_order,
          'target', 'approver',
          'notification_window_days', 90
        ) AS safe_summary,
        COALESCE(ar.created_at, lr.submitted_at, lr.created_at) AS occurred_at
      FROM puls_workflow.approval_requests ar
      JOIN puls_workflow.leave_requests lr
        ON lr.id = ar.leave_request_id
       AND lr.tenant_id = ar.tenant_id
      WHERE ar.module = 'leave'::puls_workflow.approval_module
        AND ar.status = 'pending'::puls_workflow.approval_status
        AND lr.status = 'pending'::puls_workflow.leave_request_status
        AND (p_tenant_id IS NULL OR ar.tenant_id = p_tenant_id)

      UNION ALL

      SELECT
        ar.tenant_id,
        'expense_approval_requested'::TEXT AS source_event_key,
        'puls_workflow.approval_requests'::TEXT AS source_table,
        ar.id AS source_id,
        'notifications.workflow.expenseApprovalRequested.title'::TEXT AS title_key,
        'notifications.workflow.expenseApprovalRequested.body'::TEXT AS body_key,
        'warning'::TEXT AS severity,
        80::INTEGER AS priority,
        ARRAY[]::TEXT[] AS target_roles,
        ARRAY[ar.approver_employee_id]::UUID[] AS target_employee_ids,
        'expense_claim'::TEXT AS subject_type,
        ec.id AS subject_id,
        'workflow.expense'::TEXT AS route_hint,
        'review_workflow_approval'::TEXT AS action_key,
        concat_ws(':', 'pr17.2a', 'expense_approval_requested', ar.id::TEXT, ar.approver_employee_id::TEXT) AS dedupe_key,
        jsonb_build_object(
          'contract_version', 'pr17.2a-workflow-notifications-v1',
          'source_domain', 'puls_workflow',
          'source_event_key', 'expense_approval_requested',
          'workflow_module', 'expense',
          'workflow_status', ec.status::TEXT,
          'approval_status', ar.status::TEXT,
          'approval_request_id', ar.id,
          'expense_claim_id', ec.id,
          'requester_employee_id', ar.requester_employee_id,
          'approver_employee_id', ar.approver_employee_id,
          'step_order', ar.step_order,
          'policy_status', ec.policy_status::TEXT,
          'target', 'approver',
          'notification_window_days', 90
        ) AS safe_summary,
        COALESCE(ar.created_at, ec.submitted_at, ec.created_at) AS occurred_at
      FROM puls_workflow.approval_requests ar
      JOIN puls_workflow.expense_claims ec
        ON ec.id = ar.expense_claim_id
       AND ec.tenant_id = ar.tenant_id
      WHERE ar.module = 'expense'::puls_workflow.approval_module
        AND ar.status = 'pending'::puls_workflow.approval_status
        AND ec.status = 'pending'::puls_workflow.expense_claim_status
        AND (p_tenant_id IS NULL OR ar.tenant_id = p_tenant_id)

      UNION ALL

      SELECT
        lr.tenant_id,
        CASE lr.status::TEXT
          WHEN 'approved' THEN 'leave_request_approved'
          ELSE 'leave_request_rejected'
        END AS source_event_key,
        'puls_workflow.leave_requests'::TEXT AS source_table,
        lr.id AS source_id,
        CASE lr.status::TEXT
          WHEN 'approved' THEN 'notifications.workflow.leaveApproved.title'
          ELSE 'notifications.workflow.leaveRejected.title'
        END AS title_key,
        CASE lr.status::TEXT
          WHEN 'approved' THEN 'notifications.workflow.leaveApproved.body'
          ELSE 'notifications.workflow.leaveRejected.body'
        END AS body_key,
        CASE lr.status::TEXT
          WHEN 'approved' THEN 'success'
          ELSE 'info'
        END AS severity,
        65::INTEGER AS priority,
        ARRAY[]::TEXT[] AS target_roles,
        ARRAY[lr.employee_id]::UUID[] AS target_employee_ids,
        'leave_request'::TEXT AS subject_type,
        lr.id AS subject_id,
        'workflow.leave'::TEXT AS route_hint,
        'view_workflow_request'::TEXT AS action_key,
        concat_ws(':', 'pr17.2a', 'leave_request_decision', lr.id::TEXT, lr.status::TEXT, lr.employee_id::TEXT) AS dedupe_key,
        jsonb_build_object(
          'contract_version', 'pr17.2a-workflow-notifications-v1',
          'source_domain', 'puls_workflow',
          'source_event_key', CASE lr.status::TEXT
            WHEN 'approved' THEN 'leave_request_approved'
            ELSE 'leave_request_rejected'
          END,
          'workflow_module', 'leave',
          'workflow_status', lr.status::TEXT,
          'leave_request_id', lr.id,
          'requester_employee_id', lr.employee_id,
          'business_days', lr.business_days,
          'target', 'requester',
          'notification_window_days', 90
        ) AS safe_summary,
        COALESCE(lr.approved_at, lr.rejected_at, lr.updated_at, lr.submitted_at, lr.created_at) AS occurred_at
      FROM puls_workflow.leave_requests lr
      WHERE lr.status IN (
          'approved'::puls_workflow.leave_request_status,
          'rejected'::puls_workflow.leave_request_status
        )
        AND (p_tenant_id IS NULL OR lr.tenant_id = p_tenant_id)

      UNION ALL

      SELECT
        ec.tenant_id,
        CASE ec.status::TEXT
          WHEN 'approved' THEN 'expense_claim_approved'
          ELSE 'expense_claim_rejected'
        END AS source_event_key,
        'puls_workflow.expense_claims'::TEXT AS source_table,
        ec.id AS source_id,
        CASE ec.status::TEXT
          WHEN 'approved' THEN 'notifications.workflow.expenseApproved.title'
          ELSE 'notifications.workflow.expenseRejected.title'
        END AS title_key,
        CASE ec.status::TEXT
          WHEN 'approved' THEN 'notifications.workflow.expenseApproved.body'
          ELSE 'notifications.workflow.expenseRejected.body'
        END AS body_key,
        CASE ec.status::TEXT
          WHEN 'approved' THEN 'success'
          ELSE 'info'
        END AS severity,
        65::INTEGER AS priority,
        ARRAY[]::TEXT[] AS target_roles,
        ARRAY[ec.employee_id]::UUID[] AS target_employee_ids,
        'expense_claim'::TEXT AS subject_type,
        ec.id AS subject_id,
        'workflow.expense'::TEXT AS route_hint,
        'view_workflow_request'::TEXT AS action_key,
        concat_ws(':', 'pr17.2a', 'expense_claim_decision', ec.id::TEXT, ec.status::TEXT, ec.employee_id::TEXT) AS dedupe_key,
        jsonb_build_object(
          'contract_version', 'pr17.2a-workflow-notifications-v1',
          'source_domain', 'puls_workflow',
          'source_event_key', CASE ec.status::TEXT
            WHEN 'approved' THEN 'expense_claim_approved'
            ELSE 'expense_claim_rejected'
          END,
          'workflow_module', 'expense',
          'workflow_status', ec.status::TEXT,
          'expense_claim_id', ec.id,
          'requester_employee_id', ec.employee_id,
          'policy_status', ec.policy_status::TEXT,
          'target', 'requester',
          'notification_window_days', 90
        ) AS safe_summary,
        COALESCE(ec.approved_at, ec.rejected_at, ec.updated_at, ec.submitted_at, ec.created_at) AS occurred_at
      FROM puls_workflow.expense_claims ec
      WHERE ec.status IN (
          'approved'::puls_workflow.expense_claim_status,
          'rejected'::puls_workflow.expense_claim_status
        )
        AND (p_tenant_id IS NULL OR ec.tenant_id = p_tenant_id)
    )
    SELECT candidate.*
    FROM candidates candidate
    WHERE candidate.occurred_at >= v_min_occurred_at
    ORDER BY candidate.occurred_at DESC, candidate.source_id
    LIMIT v_limit
  LOOP
    SELECT *
    INTO v_emit
    FROM puls_app.emit_app_notification(
      p_tenant_id := v_candidate.tenant_id,
      p_source_domain := 'puls_workflow',
      p_source_event_key := v_candidate.source_event_key,
      p_title_key := v_candidate.title_key,
      p_source_table := v_candidate.source_table,
      p_source_id := v_candidate.source_id,
      p_severity := v_candidate.severity,
      p_priority := v_candidate.priority,
      p_target_roles := v_candidate.target_roles,
      p_target_employee_ids := v_candidate.target_employee_ids,
      p_subject_type := v_candidate.subject_type,
      p_subject_id := v_candidate.subject_id,
      p_body_key := v_candidate.body_key,
      p_route_hint := v_candidate.route_hint,
      p_action_key := v_candidate.action_key,
      p_dedupe_key := v_candidate.dedupe_key,
      p_safe_summary := v_candidate.safe_summary,
      p_occurred_at := v_candidate.occurred_at,
      p_expires_at := v_candidate.occurred_at + INTERVAL '90 days'
    );

    source_event_key := v_candidate.source_event_key;
    source_table := v_candidate.source_table;
    source_id := v_candidate.source_id;
    notification_id := v_emit.notification_id;
    inserted := v_emit.inserted;
    severity := v_emit.severity;
    priority := v_emit.priority;
    dedupe_key := v_emit.dedupe_key;
    action_key := v_emit.next_action_key;
    safe_summary := v_emit.safe_summary;
    occurred_at := v_emit.occurred_at;
    RETURN NEXT;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION puls_app.run_app_notification_producers(
  p_limit INTEGER DEFAULT 500,
  p_tenant_id UUID DEFAULT NULL
)
RETURNS TABLE (
  producer_key TEXT,
  source_event_key TEXT,
  source_table TEXT,
  source_id UUID,
  notification_id UUID,
  inserted BOOLEAN,
  severity TEXT,
  priority INTEGER,
  dedupe_key TEXT,
  action_key TEXT,
  safe_summary JSONB,
  occurred_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_app, puls_core
AS $$
DECLARE
  v_auth_role TEXT := COALESCE(auth.role(), '');
  v_limit INTEGER := LEAST(GREATEST(COALESCE(p_limit, 500), 1), 500);
BEGIN
  IF v_auth_role <> 'service_role' THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_PRODUCER_SERVICE_ROLE_REQUIRED: notification producers require service_role.'
      USING ERRCODE = 'P0001';
  END IF;

  RETURN QUERY
  SELECT
    'connector_runtime'::TEXT AS producer_key,
    refreshed.source_event_key,
    refreshed.source_table,
    refreshed.source_id,
    refreshed.notification_id,
    refreshed.inserted,
    refreshed.severity,
    refreshed.priority,
    refreshed.dedupe_key,
    refreshed.action_key,
    refreshed.safe_summary,
    refreshed.occurred_at
  FROM puls_app.refresh_connector_app_notifications(
    v_limit,
    p_tenant_id,
    NULL
  ) refreshed
  UNION ALL
  SELECT
    'file_import'::TEXT AS producer_key,
    refreshed.source_event_key,
    refreshed.source_table,
    refreshed.source_id,
    refreshed.notification_id,
    refreshed.inserted,
    refreshed.severity,
    refreshed.priority,
    refreshed.dedupe_key,
    refreshed.action_key,
    refreshed.safe_summary,
    refreshed.occurred_at
  FROM puls_app.refresh_file_import_app_notifications(
    v_limit,
    p_tenant_id
  ) refreshed
  UNION ALL
  SELECT
    'workflow'::TEXT AS producer_key,
    refreshed.source_event_key,
    refreshed.source_table,
    refreshed.source_id,
    refreshed.notification_id,
    refreshed.inserted,
    refreshed.severity,
    refreshed.priority,
    refreshed.dedupe_key,
    refreshed.action_key,
    refreshed.safe_summary,
    refreshed.occurred_at
  FROM puls_app.refresh_workflow_app_notifications(
    v_limit,
    p_tenant_id
  ) refreshed;
END;
$$;

CREATE OR REPLACE FUNCTION puls_app.list_app_notification_scenario_contracts()
RETURNS TABLE (
  scenario_key TEXT,
  scenario_status TEXT,
  source_domain TEXT,
  expected_behavior TEXT,
  tested_by TEXT,
  notification_ledger_enabled BOOLEAN,
  notification_preferences_enabled BOOLEAN,
  notification_realtime_enabled BOOLEAN,
  external_delivery_enabled BOOLEAN,
  safe_summary JSONB
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_app
AS $$
  SELECT
    scenario.scenario_key,
    'ready'::TEXT AS scenario_status,
    scenario.source_domain,
    scenario.expected_behavior,
    scenario.tested_by,
    TRUE AS notification_ledger_enabled,
    TRUE AS notification_preferences_enabled,
    TRUE AS notification_realtime_enabled,
    FALSE AS external_delivery_enabled,
    jsonb_build_object(
      'contract_version', CASE
        WHEN scenario.source_domain = 'puls_workflow' THEN 'pr17.2a-workflow-notifications-v1'
        ELSE 'pr16.9.5-notification-scenario-coverage-v1'
      END,
      'scenario_key', scenario.scenario_key,
      'app_wide_capability', TRUE,
      'source_writeback', FALSE,
      'provider_api_calls', FALSE,
      'credential_readback', FALSE,
      'raw_payload_readback', FALSE,
      'field_value_readback', FALSE,
      'snapshot_payload_readback', FALSE,
      'external_delivery_enabled', FALSE,
      'browser_direct_table_write', FALSE,
      'realtime_required', FALSE
    ) AS safe_summary
  FROM (
    VALUES
      ('empty_inbox', 'all', 'Empty inbox renders without load errors.', 'browser smoke + get_app_notification_summary'),
      ('service_role_emit', 'all', 'Service-role emit writes safe durable notifications only.', 'emit_app_notification'),
      ('dedupe', 'all', 'Duplicate producer events resolve to one notification by tenant dedupe key.', 'emit_app_notification'),
      ('role_visibility', 'all', 'Role-targeted notifications are visible only to matching tenant users.', 'list_app_notifications_page'),
      ('employee_target', 'all', 'Employee-targeted notifications use per-employee visibility.', 'list_app_notifications_page'),
      ('cursor_paging', 'all', 'Priority/time/id cursor paging returns stable pages.', 'list_app_notifications_page'),
      ('unread_filter', 'all', 'Unread filter excludes read and dismissed rows.', 'list_app_notifications_page'),
      ('action_required_filter', 'all', 'Action filter returns unread actionable warnings/errors/critical/action_key rows.', 'list_app_notifications_page'),
      ('read_state', 'all', 'Read state is per employee and never mutates notification rows.', 'mark_app_notification_read'),
      ('dismiss_state', 'all', 'Dismiss state removes rows from the current employee inbox.', 'dismiss_app_notification'),
      ('mark_all_read', 'all', 'Bulk read respects visibility and preference filters.', 'mark_all_app_notifications_read'),
      ('preference_mute', 'all', 'Per-employee mute hides non-critical in-app rows without external delivery.', 'upsert_app_notification_preference'),
      ('preference_minimum_severity', 'all', 'Minimum severity preference hides lower-severity non-critical rows.', 'upsert_app_notification_preference'),
      ('critical_always_visible', 'all', 'Critical rows remain visible even when a preference mutes a scope.', '_app_notification_preference_allows'),
      ('realtime_hint', 'all', 'Realtime broadcasts contain minimal hints and refetch durable RPC state.', 'broadcast_app_notification_hint'),
      ('safe_summary_guard', 'all', 'Blocked raw/provider/credential/field/snapshot keys are rejected.', 'emit_app_notification'),
      ('external_delivery_closed', 'all', 'Email, push, SMS, Slack, and provider fanout remain disabled.', 'bootstrap status'),
      ('workflow_approval_requested', 'puls_workflow', 'Pending leave and expense approvals notify the assigned approver only.', 'refresh_workflow_app_notifications'),
      ('workflow_decision_result', 'puls_workflow', 'Approved and rejected leave or expense outcomes notify the requester only.', 'refresh_workflow_app_notifications'),
      ('workflow_route_actions', 'puls_workflow', 'Workflow notifications route to leave or expense process surfaces, never to technical connector workbench.', 'resolveAppNotificationAction'),
      ('workflow_preference_scope', 'puls_workflow', 'Users can tune non-critical HR workflow notifications by source scope.', 'Notification Center preferences'),
      ('workflow_safe_summary_guard', 'puls_workflow', 'Workflow notifications expose only ids, statuses, step, and non-sensitive metadata.', 'refresh_workflow_app_notifications')
  ) AS scenario(scenario_key, source_domain, expected_behavior, tested_by);
$$;

REVOKE ALL ON FUNCTION puls_app.refresh_workflow_app_notifications(INTEGER, UUID)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION puls_app.refresh_workflow_app_notifications(INTEGER, UUID)
  TO service_role;

REVOKE ALL ON FUNCTION puls_app.run_app_notification_producers(INTEGER, UUID)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION puls_app.run_app_notification_producers(INTEGER, UUID)
  TO service_role;

REVOKE ALL ON FUNCTION puls_app.list_app_notification_scenario_contracts()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION puls_app.list_app_notification_scenario_contracts()
  TO authenticated, service_role;

COMMENT ON FUNCTION puls_app.refresh_workflow_app_notifications(INTEGER, UUID) IS
  'PR17.2A service-role producer for metadata-only HR workflow notifications. No external delivery, provider calls, raw payload readback, or browser writes.';

COMMENT ON FUNCTION puls_app.run_app_notification_producers(INTEGER, UUID) IS
  'Runs connector runtime, file import, and HR workflow notification producers behind the existing service-role producer boundary.';

COMMENT ON FUNCTION puls_app.list_app_notification_scenario_contracts() IS
  'Lists durable Notification Center scenarios including PR17.2A HR workflow taxonomy and producer contracts.';
