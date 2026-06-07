-- PR16.9.3 notification center UI readiness.
-- Adds cursor paging for the app-wide notification inbox without opening
-- direct browser table access, realtime correctness, external delivery,
-- source writeback, provider calls, credential readback, raw payload readback,
-- snapshot payload readback, or field value readback.

CREATE OR REPLACE FUNCTION puls_app.list_app_notifications_page(
  p_limit INTEGER DEFAULT 25,
  p_filter TEXT DEFAULT 'all',
  p_source_domain TEXT DEFAULT NULL,
  p_cursor JSONB DEFAULT NULL
)
RETURNS TABLE (
  notification_id UUID,
  tenant_id UUID,
  source_domain TEXT,
  source_event_key TEXT,
  source_table TEXT,
  source_id UUID,
  severity TEXT,
  priority INTEGER,
  target_roles TEXT[],
  subject_type TEXT,
  subject_id UUID,
  title_key TEXT,
  body_key TEXT,
  route_hint TEXT,
  action_key TEXT,
  notification_status TEXT,
  safe_summary JSONB,
  occurred_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ,
  read_at TIMESTAMPTZ,
  dismissed_at TIMESTAMPTZ,
  is_read BOOLEAN,
  is_dismissed BOOLEAN,
  is_action_required BOOLEAN,
  page_has_more BOOLEAN,
  next_cursor JSONB
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
  v_limit INTEGER := LEAST(GREATEST(COALESCE(p_limit, 25), 1), 50);
  v_filter TEXT := LOWER(NULLIF(BTRIM(COALESCE(p_filter, 'all')), ''));
  v_cursor_priority INTEGER;
  v_cursor_occurred_at TIMESTAMPTZ;
  v_cursor_notification_id UUID;
BEGIN
  IF v_filter IS NULL THEN
    v_filter := 'all';
  END IF;

  IF v_filter NOT IN ('all', 'unread', 'action_required') THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_FILTER_INVALID: notification filter is invalid.'
      USING ERRCODE = 'P0001';
  END IF;

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

  IF p_cursor IS NOT NULL THEN
    IF jsonb_typeof(p_cursor) IS DISTINCT FROM 'object' THEN
      RAISE EXCEPTION
        'PULS_APP_NOTIFICATION_CURSOR_INVALID: notification cursor must be an object.'
        USING ERRCODE = 'P0001';
    END IF;

    v_cursor_priority := NULLIF(p_cursor ->> 'priority', '')::INTEGER;
    v_cursor_occurred_at := NULLIF(p_cursor ->> 'occurred_at', '')::TIMESTAMPTZ;
    v_cursor_notification_id := NULLIF(p_cursor ->> 'notification_id', '')::UUID;

    IF v_cursor_priority IS NULL
       OR v_cursor_occurred_at IS NULL
       OR v_cursor_notification_id IS NULL THEN
      RAISE EXCEPTION
        'PULS_APP_NOTIFICATION_CURSOR_INVALID: notification cursor is incomplete.'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  RETURN QUERY
  WITH visible_notifications AS (
    SELECT
      notification.id AS notification_id,
      notification.tenant_id,
      notification.source_domain,
      notification.source_event_key,
      notification.source_table,
      notification.source_id,
      notification.severity,
      notification.priority,
      notification.target_roles,
      notification.subject_type,
      notification.subject_id,
      notification.title_key,
      notification.body_key,
      notification.route_hint,
      notification.action_key,
      notification.notification_status,
      notification.safe_summary,
      notification.occurred_at,
      notification.expires_at,
      notification.created_at,
      read_state.read_at,
      read_state.dismissed_at,
      read_state.read_at IS NOT NULL AS is_read,
      read_state.dismissed_at IS NOT NULL AS is_dismissed,
      (
        notification.action_key IS NOT NULL
        OR notification.severity IN ('warning', 'error', 'critical')
      ) AS is_action_required
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
      AND (
        p_cursor IS NULL
        OR notification.priority < v_cursor_priority
        OR (
          notification.priority = v_cursor_priority
          AND notification.occurred_at < v_cursor_occurred_at
        )
        OR (
          notification.priority = v_cursor_priority
          AND notification.occurred_at = v_cursor_occurred_at
          AND notification.id < v_cursor_notification_id
        )
      )
  ),
  filtered_notifications AS (
    SELECT visible_notifications.*
    FROM visible_notifications
    WHERE (
        v_filter = 'all'
        OR (v_filter = 'unread' AND visible_notifications.is_read IS FALSE)
        OR (
          v_filter = 'action_required'
          AND visible_notifications.is_action_required IS TRUE
          AND visible_notifications.is_read IS FALSE
        )
      )
      AND visible_notifications.is_dismissed IS FALSE
  ),
  limited_notifications AS (
    SELECT
      filtered_notifications.*,
      ROW_NUMBER() OVER (
        ORDER BY
          filtered_notifications.priority DESC,
          filtered_notifications.occurred_at DESC,
          filtered_notifications.notification_id DESC
      ) AS page_row_number
    FROM filtered_notifications
    ORDER BY
      filtered_notifications.priority DESC,
      filtered_notifications.occurred_at DESC,
      filtered_notifications.notification_id DESC
    LIMIT v_limit + 1
  ),
  page_notifications AS (
    SELECT limited_notifications.*
    FROM limited_notifications
    WHERE limited_notifications.page_row_number <= v_limit
  ),
  page_state AS (
    SELECT
      EXISTS (
        SELECT 1
        FROM limited_notifications limited
        WHERE limited.page_row_number > v_limit
      ) AS page_has_more,
      (
        SELECT jsonb_build_object(
          'priority', last_page_row.priority,
          'occurred_at', last_page_row.occurred_at,
          'notification_id', last_page_row.notification_id
        )
        FROM page_notifications last_page_row
        ORDER BY last_page_row.page_row_number DESC
        LIMIT 1
      ) AS next_cursor
  )
  SELECT
    page.notification_id,
    page.tenant_id,
    page.source_domain,
    page.source_event_key,
    page.source_table,
    page.source_id,
    page.severity,
    page.priority,
    page.target_roles,
    page.subject_type,
    page.subject_id,
    page.title_key,
    page.body_key,
    page.route_hint,
    page.action_key,
    page.notification_status,
    page.safe_summary,
    page.occurred_at,
    page.expires_at,
    page.created_at,
    page.read_at,
    page.dismissed_at,
    page.is_read,
    page.is_dismissed,
    page.is_action_required,
    state.page_has_more,
    CASE WHEN state.page_has_more THEN state.next_cursor ELSE NULL::JSONB END AS next_cursor
  FROM page_notifications page
  CROSS JOIN page_state state
  ORDER BY page.page_row_number;
END;
$$;

CREATE OR REPLACE FUNCTION puls_app.get_notification_center_bootstrap_status()
RETURNS TABLE (
  contract_version TEXT,
  schema_name TEXT,
  auth_role TEXT,
  current_tenant_id UUID,
  current_employee_id UUID,
  current_persona_role TEXT,
  is_admin BOOLEAN,
  app_schema_available BOOLEAN,
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
  v_auth_role TEXT := COALESCE(auth.role(), '');
  v_is_service_role BOOLEAN := COALESCE(auth.role(), '') = 'service_role';
  v_tenant_id UUID;
  v_employee_id UUID;
  v_persona_role TEXT;
  v_is_admin BOOLEAN := FALSE;
BEGIN
  IF v_is_service_role THEN
    v_tenant_id := NULL;
    v_employee_id := NULL;
    v_persona_role := NULL;
    v_is_admin := FALSE;
  ELSE
    v_tenant_id := puls_core.current_tenant_id();
    v_employee_id := puls_core.current_employee_id();
    v_persona_role := puls_core.current_persona_role()::TEXT;
    v_is_admin := COALESCE(puls_core.is_admin(), FALSE);

    IF v_tenant_id IS NULL THEN
      RAISE EXCEPTION
        'PULS_APP_NOTIFICATION_BOOTSTRAP_TENANT_REQUIRED: authenticated caller has no tenant context.'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  RETURN QUERY
  SELECT
    'pr16.9.3-notification-center-ui-v1'::TEXT AS contract_version,
    'puls_app'::TEXT AS schema_name,
    v_auth_role AS auth_role,
    v_tenant_id AS current_tenant_id,
    v_employee_id AS current_employee_id,
    v_persona_role AS current_persona_role,
    v_is_admin AS is_admin,
    TRUE AS app_schema_available,
    TRUE AS notification_ledger_enabled,
    FALSE AS notification_realtime_enabled,
    FALSE AS external_delivery_enabled,
    'add_notification_realtime_pr16_9_4'::TEXT AS next_action_key,
    jsonb_build_object(
      'contract_version', 'pr16.9.3-notification-center-ui-v1',
      'schema_name', 'puls_app',
      'app_wide_capability', TRUE,
      'notification_center_ui_enabled', TRUE,
      'notification_cursor_paging_enabled', TRUE,
      'notification_detail_pane_enabled', TRUE,
      'notification_ledger_enabled', TRUE,
      'notification_tables_exist', (
        to_regclass('puls_app.app_notifications') IS NOT NULL
        AND to_regclass('puls_app.app_notification_reads') IS NOT NULL
      ),
      'connector_producer_mapping_enabled', TRUE,
      'source_domain', 'app_notification_center',
      'first_producer_enabled', 'connector_runtime',
      'first_surface_enabled', 'global_shell',
      'first_surface_planned', '/erp',
      'notification_realtime_enabled', FALSE,
      'realtime_required', FALSE,
      'external_delivery_enabled', FALSE,
      'email_delivery_enabled', FALSE,
      'push_delivery_enabled', FALSE,
      'browser_direct_table_write', FALSE,
      'authenticated_direct_table_write', FALSE,
      'source_writeback', FALSE,
      'provider_api_calls', FALSE,
      'provider_response_readback', FALSE,
      'credential_readback', FALSE,
      'raw_payload_readback', FALSE,
      'field_value_readback', FALSE,
      'snapshot_payload_readback', FALSE,
      'ai_autonomous_action', FALSE,
      'postgrest_schema_exposure_required', TRUE,
      'postgrest_schema_reload_hint', 'NOTIFY pgrst, reload schema',
      'next_action_key', 'add_notification_realtime_pr16_9_4'
    ) AS safe_summary;
END;
$$;

REVOKE ALL ON FUNCTION puls_app.list_app_notifications_page(INTEGER, TEXT, TEXT, JSONB)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_app.list_app_notifications_page(INTEGER, TEXT, TEXT, JSONB)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_app.get_notification_center_bootstrap_status()
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_app.get_notification_center_bootstrap_status()
  TO authenticated, service_role;

COMMENT ON FUNCTION puls_app.list_app_notifications_page(INTEGER, TEXT, TEXT, JSONB) IS
  'PR16.9.3 cursor-paged app notification inbox RPC. Authenticated callers read only tenant/role-visible notifications; direct table access remains closed.';

COMMENT ON FUNCTION puls_app.get_notification_center_bootstrap_status() IS
  'PR16.9.3 app-wide Notification Center bootstrap status. UI and cursor paging are open; realtime and external delivery remain closed.';

NOTIFY pgrst, 'reload schema';
