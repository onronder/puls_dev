-- PR16.9.5: notification scenario coverage and in-app preference contract.
-- Keeps external delivery closed. Adds only app-internal preference controls and
-- scenario contract smoke for the durable Notification Center.

CREATE OR REPLACE FUNCTION puls_app._app_notification_severity_rank(p_severity TEXT)
RETURNS INTEGER
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog
AS $$
  SELECT CASE p_severity
    WHEN 'info' THEN 10
    WHEN 'success' THEN 20
    WHEN 'warning' THEN 30
    WHEN 'error' THEN 40
    WHEN 'critical' THEN 50
    ELSE 0
  END;
$$;

CREATE TABLE IF NOT EXISTS puls_app.app_notification_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  employee_id UUID NOT NULL REFERENCES puls_core.employees(id) ON DELETE CASCADE,
  source_domain TEXT NOT NULL DEFAULT 'all',
  source_event_key TEXT NOT NULL DEFAULT 'all',
  inbox_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  minimum_severity TEXT NOT NULL DEFAULT 'info',
  muted_until TIMESTAMPTZ NULL,
  action_required_only BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (source_domain <> ''),
  CHECK (source_event_key <> ''),
  CHECK (minimum_severity IN ('info', 'success', 'warning', 'error', 'critical')),
  CHECK (muted_until IS NULL OR muted_until > created_at),
  CONSTRAINT app_notification_preferences_employee_scope_unique
    UNIQUE (tenant_id, employee_id, source_domain, source_event_key)
);

CREATE INDEX IF NOT EXISTS idx_puls_app_notification_preferences_employee
  ON puls_app.app_notification_preferences (tenant_id, employee_id, source_domain, source_event_key);

COMMENT ON TABLE puls_app.app_notification_preferences IS
  'PR16.9.5 per-employee in-app Notification Center preferences. Mutated only through RPCs; no external delivery, push, email, SMS, or browser table writes.';

DROP TRIGGER IF EXISTS puls_app_notification_preferences_set_updated_at
  ON puls_app.app_notification_preferences;
CREATE TRIGGER puls_app_notification_preferences_set_updated_at
  BEFORE UPDATE ON puls_app.app_notification_preferences
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

CREATE OR REPLACE FUNCTION puls_app._app_notification_preference_allows(
  p_tenant_id UUID,
  p_employee_id UUID,
  p_source_domain TEXT,
  p_source_event_key TEXT,
  p_severity TEXT,
  p_is_action_required BOOLEAN
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_app
AS $$
DECLARE
  v_preference puls_app.app_notification_preferences;
BEGIN
  IF p_employee_id IS NULL THEN
    RETURN TRUE;
  END IF;

  -- Critical app notifications are always visible in the in-app inbox.
  IF p_severity = 'critical' THEN
    RETURN TRUE;
  END IF;

  SELECT preference.*
  INTO v_preference
  FROM puls_app.app_notification_preferences preference
  WHERE preference.tenant_id = p_tenant_id
    AND preference.employee_id = p_employee_id
    AND preference.source_domain IN (COALESCE(NULLIF(p_source_domain, ''), 'all'), 'all')
    AND preference.source_event_key IN (COALESCE(NULLIF(p_source_event_key, ''), 'all'), 'all')
  ORDER BY
    CASE
      WHEN preference.source_domain = p_source_domain
        AND preference.source_event_key = p_source_event_key THEN 4
      WHEN preference.source_domain = p_source_domain
        AND preference.source_event_key = 'all' THEN 3
      WHEN preference.source_domain = 'all'
        AND preference.source_event_key = p_source_event_key THEN 2
      WHEN preference.source_domain = 'all'
        AND preference.source_event_key = 'all' THEN 1
      ELSE 0
    END DESC,
    preference.updated_at DESC
  LIMIT 1;

  IF v_preference.id IS NULL THEN
    RETURN TRUE;
  END IF;

  IF v_preference.inbox_enabled IS FALSE THEN
    RETURN FALSE;
  END IF;

  IF v_preference.muted_until IS NOT NULL AND v_preference.muted_until > NOW() THEN
    RETURN FALSE;
  END IF;

  IF puls_app._app_notification_severity_rank(p_severity)
      < puls_app._app_notification_severity_rank(v_preference.minimum_severity) THEN
    RETURN FALSE;
  END IF;

  IF v_preference.action_required_only IS TRUE
      AND COALESCE(p_is_action_required, FALSE) IS FALSE THEN
    RETURN FALSE;
  END IF;

  RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION puls_app.list_app_notification_preferences(
  p_source_domain TEXT DEFAULT NULL
)
RETURNS TABLE (
  preference_id UUID,
  tenant_id UUID,
  employee_id UUID,
  source_domain TEXT,
  source_event_key TEXT,
  inbox_enabled BOOLEAN,
  minimum_severity TEXT,
  muted_until TIMESTAMPTZ,
  action_required_only BOOLEAN,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_app, puls_core
AS $$
DECLARE
  v_tenant_id UUID := puls_core.current_tenant_id();
  v_employee_id UUID := puls_core.current_employee_id();
  v_source_domain TEXT := LOWER(NULLIF(BTRIM(COALESCE(p_source_domain, '')), ''));
BEGIN
  IF COALESCE(auth.role(), '') = 'service_role' AND v_employee_id IS NULL THEN
    v_employee_id := NULLIF(current_setting('request.jwt.claim.employee_id', true), '')::UUID;
    v_tenant_id := NULLIF(current_setting('request.jwt.claim.tenant_id', true), '')::UUID;
  END IF;

  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_TENANT_REQUIRED: caller has no tenant context.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_employee_id IS NULL THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_EMPLOYEE_REQUIRED: caller has no employee context.'
      USING ERRCODE = 'P0001';
  END IF;

  RETURN QUERY
  SELECT
    preference.id AS preference_id,
    preference.tenant_id,
    preference.employee_id,
    preference.source_domain,
    preference.source_event_key,
    preference.inbox_enabled,
    preference.minimum_severity,
    preference.muted_until,
    preference.action_required_only,
    preference.created_at,
    preference.updated_at
  FROM puls_app.app_notification_preferences preference
  WHERE preference.tenant_id = v_tenant_id
    AND preference.employee_id = v_employee_id
    AND (v_source_domain IS NULL OR preference.source_domain = v_source_domain)
  ORDER BY preference.source_domain, preference.source_event_key;
END;
$$;

CREATE OR REPLACE FUNCTION puls_app.upsert_app_notification_preference(
  p_source_domain TEXT DEFAULT 'all',
  p_source_event_key TEXT DEFAULT 'all',
  p_inbox_enabled BOOLEAN DEFAULT TRUE,
  p_minimum_severity TEXT DEFAULT 'info',
  p_muted_until TIMESTAMPTZ DEFAULT NULL,
  p_action_required_only BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
  preference_id UUID,
  tenant_id UUID,
  employee_id UUID,
  source_domain TEXT,
  source_event_key TEXT,
  inbox_enabled BOOLEAN,
  minimum_severity TEXT,
  muted_until TIMESTAMPTZ,
  action_required_only BOOLEAN,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_app, puls_core
AS $$
DECLARE
  v_tenant_id UUID := puls_core.current_tenant_id();
  v_employee_id UUID := puls_core.current_employee_id();
  v_source_domain TEXT := LOWER(NULLIF(BTRIM(COALESCE(p_source_domain, 'all')), ''));
  v_source_event_key TEXT := LOWER(NULLIF(BTRIM(COALESCE(p_source_event_key, 'all')), ''));
  v_minimum_severity TEXT := LOWER(NULLIF(BTRIM(COALESCE(p_minimum_severity, 'info')), ''));
  v_muted_until TIMESTAMPTZ := p_muted_until;
BEGIN
  IF COALESCE(auth.role(), '') = 'service_role' AND v_employee_id IS NULL THEN
    v_employee_id := NULLIF(current_setting('request.jwt.claim.employee_id', true), '')::UUID;
    v_tenant_id := NULLIF(current_setting('request.jwt.claim.tenant_id', true), '')::UUID;
  END IF;

  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_TENANT_REQUIRED: caller has no tenant context.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_employee_id IS NULL THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_EMPLOYEE_REQUIRED: caller has no employee context.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_source_domain IS NULL THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_PREFERENCE_SOURCE_DOMAIN_REQUIRED: source domain is required.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_source_event_key IS NULL THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_PREFERENCE_SOURCE_EVENT_REQUIRED: source event key is required.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_minimum_severity NOT IN ('info', 'success', 'warning', 'error', 'critical') THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_PREFERENCE_SEVERITY_INVALID: minimum severity is invalid.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_muted_until IS NOT NULL AND v_muted_until <= NOW() THEN
    v_muted_until := NULL;
  END IF;

  RETURN QUERY
  INSERT INTO puls_app.app_notification_preferences (
    tenant_id,
    employee_id,
    source_domain,
    source_event_key,
    inbox_enabled,
    minimum_severity,
    muted_until,
    action_required_only
  )
  VALUES (
    v_tenant_id,
    v_employee_id,
    v_source_domain,
    v_source_event_key,
    COALESCE(p_inbox_enabled, TRUE),
    v_minimum_severity,
    v_muted_until,
    COALESCE(p_action_required_only, FALSE)
  )
  ON CONFLICT ON CONSTRAINT app_notification_preferences_employee_scope_unique
  DO UPDATE SET
    inbox_enabled = EXCLUDED.inbox_enabled,
    minimum_severity = EXCLUDED.minimum_severity,
    muted_until = EXCLUDED.muted_until,
    action_required_only = EXCLUDED.action_required_only
  RETURNING
    app_notification_preferences.id AS preference_id,
    app_notification_preferences.tenant_id,
    app_notification_preferences.employee_id,
    app_notification_preferences.source_domain,
    app_notification_preferences.source_event_key,
    app_notification_preferences.inbox_enabled,
    app_notification_preferences.minimum_severity,
    app_notification_preferences.muted_until,
    app_notification_preferences.action_required_only,
    app_notification_preferences.created_at,
    app_notification_preferences.updated_at;
END;
$$;

CREATE OR REPLACE FUNCTION puls_app.clear_app_notification_preference(
  p_source_domain TEXT DEFAULT 'all',
  p_source_event_key TEXT DEFAULT 'all'
)
RETURNS TABLE (
  deleted_count INTEGER,
  source_domain TEXT,
  source_event_key TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_app, puls_core
AS $$
DECLARE
  v_tenant_id UUID := puls_core.current_tenant_id();
  v_employee_id UUID := puls_core.current_employee_id();
  v_source_domain TEXT := LOWER(NULLIF(BTRIM(COALESCE(p_source_domain, 'all')), ''));
  v_source_event_key TEXT := LOWER(NULLIF(BTRIM(COALESCE(p_source_event_key, 'all')), ''));
  v_deleted_count INTEGER := 0;
BEGIN
  IF COALESCE(auth.role(), '') = 'service_role' AND v_employee_id IS NULL THEN
    v_employee_id := NULLIF(current_setting('request.jwt.claim.employee_id', true), '')::UUID;
    v_tenant_id := NULLIF(current_setting('request.jwt.claim.tenant_id', true), '')::UUID;
  END IF;

  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_TENANT_REQUIRED: caller has no tenant context.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_employee_id IS NULL THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_EMPLOYEE_REQUIRED: caller has no employee context.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_source_domain IS NULL OR v_source_event_key IS NULL THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_PREFERENCE_SCOPE_REQUIRED: preference scope is required.'
      USING ERRCODE = 'P0001';
  END IF;

  DELETE FROM puls_app.app_notification_preferences preference
  WHERE preference.tenant_id = v_tenant_id
    AND preference.employee_id = v_employee_id
    AND preference.source_domain = v_source_domain
    AND preference.source_event_key = v_source_event_key;

  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

  RETURN QUERY
  SELECT
    v_deleted_count AS deleted_count,
    v_source_domain AS source_domain,
    v_source_event_key AS source_event_key;
END;
$$;

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
          AND puls_app._app_notification_preference_allows(
            notification.tenant_id,
            v_employee_id,
            notification.source_domain,
            notification.source_event_key,
            notification.severity,
            notification.action_key IS NOT NULL
              OR notification.severity IN ('warning', 'error', 'critical')
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
          AND puls_app._app_notification_preference_allows(
            notification.tenant_id,
            v_employee_id,
            notification.source_domain,
            notification.source_event_key,
            notification.severity,
            notification.action_key IS NOT NULL
              OR notification.severity IN ('warning', 'error', 'critical')
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
    'validate_notification_scenarios_pr16_9_5'::TEXT AS next_action_key,
    jsonb_build_object(
      'contract_version', 'pr16.9.5-notification-scenario-coverage-v1',
      'notification_ledger_enabled', TRUE,
      'notification_realtime_enabled', TRUE,
      'notification_preferences_enabled', TRUE,
      'notification_scenario_contracts_enabled', TRUE,
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
      'next_action_key', 'validate_notification_scenarios_pr16_9_5'
    ) AS safe_summary
  FROM visible_notifications;
END;
$$;

CREATE OR REPLACE FUNCTION puls_app.mark_all_app_notifications_read(
  p_source_domain TEXT DEFAULT NULL
)
RETURNS TABLE (
  marked_count INTEGER,
  unread_remaining_count INTEGER,
  read_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_app, puls_core
AS $$
DECLARE
  v_tenant_id UUID := puls_core.current_tenant_id();
  v_employee_id UUID := puls_core.current_employee_id();
  v_persona_role TEXT := puls_core.current_persona_role()::TEXT;
  v_is_admin BOOLEAN := COALESCE(puls_core.is_admin(), FALSE);
  v_read_at TIMESTAMPTZ := NOW();
  v_marked_count INTEGER := 0;
  v_unread_remaining_count INTEGER := 0;
BEGIN
  IF COALESCE(auth.role(), '') = 'service_role' AND v_employee_id IS NULL THEN
    v_employee_id := NULLIF(current_setting('request.jwt.claim.employee_id', true), '')::UUID;
    v_tenant_id := NULLIF(current_setting('request.jwt.claim.tenant_id', true), '')::UUID;
  END IF;

  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_TENANT_REQUIRED: caller has no tenant context.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_employee_id IS NULL THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_EMPLOYEE_REQUIRED: caller has no employee context.'
      USING ERRCODE = 'P0001';
  END IF;

  WITH visible_notifications AS (
    SELECT notification.id, notification.tenant_id
    FROM puls_app.app_notifications notification
    LEFT JOIN puls_app.app_notification_reads read_state
      ON read_state.notification_id = notification.id
     AND read_state.employee_id = v_employee_id
    WHERE notification.tenant_id = v_tenant_id
      AND notification.notification_status = 'active'
      AND (notification.expires_at IS NULL OR notification.expires_at > NOW())
      AND (p_source_domain IS NULL OR notification.source_domain = p_source_domain)
      AND read_state.dismissed_at IS NULL
      AND read_state.read_at IS NULL
      AND puls_app._app_notification_target_visible(
        notification.target_roles,
        notification.target_employee_ids,
        v_employee_id,
        v_persona_role,
        v_is_admin
      )
      AND puls_app._app_notification_preference_allows(
        notification.tenant_id,
        v_employee_id,
        notification.source_domain,
        notification.source_event_key,
        notification.severity,
        notification.action_key IS NOT NULL
          OR notification.severity IN ('warning', 'error', 'critical')
      )
  ),
  upserted AS (
    INSERT INTO puls_app.app_notification_reads (
      tenant_id,
      notification_id,
      employee_id,
      read_at
    )
    SELECT
      visible_notifications.tenant_id,
      visible_notifications.id,
      v_employee_id,
      v_read_at
    FROM visible_notifications
    ON CONFLICT ON CONSTRAINT app_notification_reads_notification_employee_unique
    DO UPDATE SET
      read_at = COALESCE(puls_app.app_notification_reads.read_at, EXCLUDED.read_at)
    RETURNING notification_id
  )
  SELECT COUNT(*)::INTEGER INTO v_marked_count FROM upserted;

  SELECT COUNT(*)::INTEGER
  INTO v_unread_remaining_count
  FROM puls_app.app_notifications notification
  LEFT JOIN puls_app.app_notification_reads read_state
    ON read_state.notification_id = notification.id
   AND read_state.employee_id = v_employee_id
  WHERE notification.tenant_id = v_tenant_id
    AND notification.notification_status = 'active'
    AND (notification.expires_at IS NULL OR notification.expires_at > NOW())
    AND (p_source_domain IS NULL OR notification.source_domain = p_source_domain)
    AND read_state.dismissed_at IS NULL
    AND read_state.read_at IS NULL
    AND puls_app._app_notification_target_visible(
      notification.target_roles,
      notification.target_employee_ids,
      v_employee_id,
      v_persona_role,
      v_is_admin
    )
    AND puls_app._app_notification_preference_allows(
      notification.tenant_id,
      v_employee_id,
      notification.source_domain,
      notification.source_event_key,
      notification.severity,
      notification.action_key IS NOT NULL
        OR notification.severity IN ('warning', 'error', 'critical')
    );

  RETURN QUERY
  SELECT
    v_marked_count AS marked_count,
    v_unread_remaining_count AS unread_remaining_count,
    v_read_at AS read_at;
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
      'contract_version', 'pr16.9.5-notification-scenario-coverage-v1',
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
      ('external_delivery_closed', 'all', 'Email, push, SMS, Slack, and provider fanout remain disabled.', 'bootstrap status')
  ) AS scenario(scenario_key, source_domain, expected_behavior, tested_by);
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
    'pr16.9.5-notification-scenario-coverage-v1'::TEXT AS contract_version,
    'puls_app'::TEXT AS schema_name,
    v_auth_role AS auth_role,
    v_tenant_id AS current_tenant_id,
    v_employee_id AS current_employee_id,
    v_persona_role AS current_persona_role,
    v_is_admin AS is_admin,
    TRUE AS app_schema_available,
    TRUE AS notification_ledger_enabled,
    TRUE AS notification_realtime_enabled,
    FALSE AS external_delivery_enabled,
    'plan_external_notification_delivery_pr16_9_6'::TEXT AS next_action_key,
    jsonb_build_object(
      'contract_version', 'pr16.9.5-notification-scenario-coverage-v1',
      'schema_name', 'puls_app',
      'app_wide_capability', TRUE,
      'notification_center_ui_enabled', TRUE,
      'notification_cursor_paging_enabled', TRUE,
      'notification_detail_pane_enabled', TRUE,
      'notification_ledger_enabled', TRUE,
      'notification_preferences_enabled', TRUE,
      'notification_scenario_contracts_enabled', TRUE,
      'notification_tables_exist', (
        to_regclass('puls_app.app_notifications') IS NOT NULL
        AND to_regclass('puls_app.app_notification_reads') IS NOT NULL
        AND to_regclass('puls_app.app_notification_preferences') IS NOT NULL
      ),
      'connector_producer_mapping_enabled', TRUE,
      'source_domain', 'app_notification_center',
      'first_producer_enabled', 'connector_runtime',
      'first_surface_enabled', 'global_shell',
      'first_surface_planned', '/erp',
      'notification_realtime_enabled', TRUE,
      'notification_realtime_required', FALSE,
      'notification_polling_fallback_enabled', TRUE,
      'notification_realtime_private_channel_enabled', TRUE,
      'notification_realtime_payload_minimal', TRUE,
      'notification_realtime_event', 'app_notification_hint',
      'notification_realtime_topic_prefix', 'puls_app:notification-center:tenant:',
      'notification_realtime_allowed_payload_keys',
        ARRAY[
          'notification_id',
          'source_domain',
          'source_event_key',
          'severity',
          'occurred_at',
          'count_hint'
        ]::TEXT[],
      'critical_notifications_always_visible', TRUE,
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
      'next_action_key', 'plan_external_notification_delivery_pr16_9_6'
    ) AS safe_summary;
END;
$$;

ALTER TABLE puls_app.app_notification_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS puls_app_notification_preferences_service_role
  ON puls_app.app_notification_preferences;
CREATE POLICY puls_app_notification_preferences_service_role
  ON puls_app.app_notification_preferences
  FOR ALL TO service_role
  USING (TRUE)
  WITH CHECK (TRUE);

REVOKE ALL ON TABLE puls_app.app_notification_preferences
  FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE puls_app.app_notification_preferences
  TO service_role;

REVOKE ALL ON FUNCTION puls_app._app_notification_severity_rank(TEXT)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION puls_app._app_notification_preference_allows(UUID, UUID, TEXT, TEXT, TEXT, BOOLEAN)
  FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON FUNCTION puls_app.list_app_notification_preferences(TEXT)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_app.list_app_notification_preferences(TEXT)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_app.upsert_app_notification_preference(TEXT, TEXT, BOOLEAN, TEXT, TIMESTAMPTZ, BOOLEAN)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_app.upsert_app_notification_preference(TEXT, TEXT, BOOLEAN, TEXT, TIMESTAMPTZ, BOOLEAN)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_app.clear_app_notification_preference(TEXT, TEXT)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_app.clear_app_notification_preference(TEXT, TEXT)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_app.list_app_notification_scenario_contracts()
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_app.list_app_notification_scenario_contracts()
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_app.list_app_notifications_page(INTEGER, TEXT, TEXT, JSONB)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_app.list_app_notifications_page(INTEGER, TEXT, TEXT, JSONB)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_app.get_app_notification_summary(TEXT)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_app.get_app_notification_summary(TEXT)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_app.mark_all_app_notifications_read(TEXT)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_app.mark_all_app_notifications_read(TEXT)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_app.get_notification_center_bootstrap_status()
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_app.get_notification_center_bootstrap_status()
  TO authenticated, service_role;

COMMENT ON FUNCTION puls_app.list_app_notification_preferences(TEXT) IS
  'PR16.9.5 lists current employee in-app notification preferences through RPC only.';
COMMENT ON FUNCTION puls_app.upsert_app_notification_preference(TEXT, TEXT, BOOLEAN, TEXT, TIMESTAMPTZ, BOOLEAN) IS
  'PR16.9.5 upserts current employee in-app notification preference without external delivery.';
COMMENT ON FUNCTION puls_app.clear_app_notification_preference(TEXT, TEXT) IS
  'PR16.9.5 clears current employee in-app notification preference scope.';
COMMENT ON FUNCTION puls_app.list_app_notification_scenario_contracts() IS
  'PR16.9.5 app-wide notification scenario contract list for smoke coverage.';
COMMENT ON FUNCTION puls_app.get_notification_center_bootstrap_status() IS
  'PR16.9.5 app-wide Notification Center status with preferences and scenario contracts enabled; external delivery remains closed.';

NOTIFY pgrst, 'reload schema';
