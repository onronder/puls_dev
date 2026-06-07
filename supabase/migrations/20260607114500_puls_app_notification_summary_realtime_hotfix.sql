-- PR16.9.4x: align the Notification Center summary RPC with the realtime fallback contract.
-- Live UI smoke showed the pane loading correctly but staying in polling-only mode because
-- get_app_notification_summary still advertised notification_realtime_enabled = false.

CREATE OR REPLACE FUNCTION puls_app.get_app_notification_summary(
  p_source_domain TEXT DEFAULT NULL
)
RETURNS TABLE (
  tenant_id UUID,
  employee_id UUID,
  visible_count INTEGER,
  unread_count INTEGER,
  dismissed_count INTEGER,
  action_required_count INTEGER,
  warning_count INTEGER,
  critical_count INTEGER,
  latest_occurred_at TIMESTAMPTZ,
  notification_ledger_enabled BOOLEAN,
  notification_realtime_enabled BOOLEAN,
  external_delivery_enabled BOOLEAN,
  next_action_key TEXT,
  safe_summary JSONB
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_app, puls_core
AS $$
DECLARE
  v_is_service_role BOOLEAN := COALESCE(auth.role(), '') = 'service_role';
  v_tenant_id UUID := puls_core.current_tenant_id();
  v_employee_id UUID := puls_core.current_employee_id();
  v_persona_role TEXT := puls_core.current_persona_role()::TEXT;
  v_is_admin BOOLEAN := COALESCE(puls_core.is_admin(), FALSE);
BEGIN
  IF NOT v_is_service_role THEN
    IF v_tenant_id IS NULL THEN
      RAISE EXCEPTION
        'PULS_APP_NOTIFICATION_TENANT_REQUIRED: authenticated caller has no tenant context.'
        USING ERRCODE = 'P0001';
    END IF;

    IF v_employee_id IS NULL THEN
      RAISE EXCEPTION
        'PULS_APP_NOTIFICATION_EMPLOYEE_REQUIRED: authenticated caller has no employee context.'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  RETURN QUERY
  WITH visible_notifications AS (
    SELECT
      notification.id,
      notification.severity,
      notification.action_key,
      notification.occurred_at,
      read_state.read_at,
      read_state.dismissed_at
    FROM puls_app.app_notifications notification
    LEFT JOIN puls_app.app_notification_reads read_state
      ON read_state.notification_id = notification.id
     AND read_state.employee_id = v_employee_id
    WHERE notification.notification_status = 'active'
      AND (notification.expires_at IS NULL OR notification.expires_at > NOW())
      AND (p_source_domain IS NULL OR notification.source_domain = p_source_domain)
      AND (
        v_is_service_role
        OR (
          notification.tenant_id = v_tenant_id
          AND puls_app._app_notification_target_visible(
            notification.target_roles,
            notification.target_employee_ids,
            v_employee_id,
            v_persona_role,
            v_is_admin
          )
        )
      )
  )
  SELECT
    v_tenant_id AS tenant_id,
    v_employee_id AS employee_id,
    COUNT(*) FILTER (WHERE dismissed_at IS NULL)::INTEGER AS visible_count,
    COUNT(*) FILTER (WHERE read_at IS NULL AND dismissed_at IS NULL)::INTEGER AS unread_count,
    COUNT(*) FILTER (WHERE dismissed_at IS NOT NULL)::INTEGER AS dismissed_count,
    COUNT(*) FILTER (
      WHERE dismissed_at IS NULL
        AND (action_key IS NOT NULL OR severity IN ('warning', 'error', 'critical'))
    )::INTEGER AS action_required_count,
    COUNT(*) FILTER (WHERE dismissed_at IS NULL AND severity = 'warning')::INTEGER AS warning_count,
    COUNT(*) FILTER (WHERE dismissed_at IS NULL AND severity IN ('error', 'critical'))::INTEGER AS critical_count,
    MAX(occurred_at) FILTER (WHERE dismissed_at IS NULL) AS latest_occurred_at,
    TRUE AS notification_ledger_enabled,
    TRUE AS notification_realtime_enabled,
    FALSE AS external_delivery_enabled,
    'plan_notification_preferences_pr16_9_5'::TEXT AS next_action_key,
    jsonb_build_object(
      'contract_version', 'pr16.9.4-notification-realtime-fallback-v1',
      'notification_ledger_enabled', TRUE,
      'notification_realtime_enabled', TRUE,
      'notification_polling_fallback_enabled', TRUE,
      'notification_realtime_private_channel_enabled', TRUE,
      'notification_realtime_payload_minimal', TRUE,
      'notification_realtime_event', 'app_notification_hint',
      'external_delivery_enabled', FALSE,
      'browser_direct_table_write', FALSE,
      'safe_payload_only', TRUE,
      'realtime_required', FALSE,
      'source_writeback', FALSE,
      'provider_api_calls', FALSE,
      'credential_readback', FALSE,
      'raw_payload_readback', FALSE,
      'field_value_readback', FALSE,
      'snapshot_payload_readback', FALSE,
      'next_action_key', 'plan_notification_preferences_pr16_9_5'
    ) AS safe_summary
  FROM visible_notifications;
END;
$$;

REVOKE ALL ON FUNCTION puls_app.get_app_notification_summary(TEXT)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION puls_app.get_app_notification_summary(TEXT)
  TO authenticated, service_role;

COMMENT ON FUNCTION puls_app.get_app_notification_summary(TEXT) IS
  'PR16.9.4x summary contract alignment for optional private notification realtime with polling fallback.';

NOTIFY pgrst, 'reload schema';
