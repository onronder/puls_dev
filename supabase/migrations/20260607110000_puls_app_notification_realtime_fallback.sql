-- PR16.9.4 optional realtime enhancement for the app-wide Notification Center.
-- Realtime is a tenant-private hint path only. RPC reads and polling remain the
-- correctness path; broadcasts contain no raw payloads, provider responses,
-- credentials, field values, before/after values, or safe_summary bodies.

CREATE OR REPLACE FUNCTION puls_app.app_notification_realtime_topic(
  p_tenant_id UUID
)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
  SELECT CASE
    WHEN p_tenant_id IS NULL THEN NULL
    ELSE 'puls_app:notification-center:tenant:' || p_tenant_id::TEXT
  END;
$$;

REVOKE ALL ON FUNCTION puls_app.app_notification_realtime_topic(UUID)
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION puls_app.app_notification_realtime_topic(UUID)
TO authenticated, service_role;

COMMENT ON FUNCTION puls_app.app_notification_realtime_topic(UUID) IS
  'PR16.9.4 deterministic private Notification Center realtime topic helper. Contains only the tenant id and no notification payload.';

CREATE OR REPLACE FUNCTION puls_app.broadcast_app_notification_hint()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_app, realtime
AS $$
BEGIN
  IF TG_OP IS DISTINCT FROM 'INSERT' THEN
    RETURN NULL;
  END IF;

  IF NEW.notification_status IS DISTINCT FROM 'active' THEN
    RETURN NULL;
  END IF;

  PERFORM realtime.send(
    jsonb_build_object(
      'notification_id', NEW.id::TEXT,
      'source_domain', NEW.source_domain,
      'source_event_key', NEW.source_event_key,
      'severity', NEW.severity,
      'occurred_at', NEW.occurred_at,
      'count_hint', 1
    ),
    'app_notification_hint',
    puls_app.app_notification_realtime_topic(NEW.tenant_id),
    TRUE
  );

  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION puls_app.broadcast_app_notification_hint()
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION puls_app.broadcast_app_notification_hint()
TO service_role;

COMMENT ON FUNCTION puls_app.broadcast_app_notification_hint() IS
  'PR16.9.4 app notification insert trigger. Sends private minimal realtime hints only; UI refetches via RPC and polling remains the fallback.';

DROP TRIGGER IF EXISTS puls_app_app_notifications_realtime_hint
ON puls_app.app_notifications;

CREATE TRIGGER puls_app_app_notifications_realtime_hint
AFTER INSERT ON puls_app.app_notifications
FOR EACH ROW
EXECUTE FUNCTION puls_app.broadcast_app_notification_hint();

DO $$
BEGIN
  IF to_regnamespace('realtime') IS NOT NULL
    AND to_regclass('realtime.messages') IS NOT NULL THEN
    EXECUTE 'GRANT SELECT ON TABLE realtime.messages TO authenticated';
    EXECUTE 'DROP POLICY IF EXISTS puls_app_notification_broadcast_select ON realtime.messages';
    EXECUTE $policy$
      CREATE POLICY puls_app_notification_broadcast_select
      ON realtime.messages
      FOR SELECT
      TO authenticated
      USING (
        realtime.messages.extension = 'broadcast'
        AND (SELECT realtime.topic()) =
          puls_app.app_notification_realtime_topic(puls_core.current_tenant_id())
      )
    $policy$;
  END IF;
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
    'pr16.9.4-notification-realtime-fallback-v1'::TEXT AS contract_version,
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
    'plan_notification_preferences_pr16_9_5'::TEXT AS next_action_key,
    jsonb_build_object(
      'contract_version', 'pr16.9.4-notification-realtime-fallback-v1',
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
      'next_action_key', 'plan_notification_preferences_pr16_9_5'
    ) AS safe_summary;
END;
$$;

REVOKE ALL ON FUNCTION puls_app.get_notification_center_bootstrap_status()
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION puls_app.get_notification_center_bootstrap_status()
TO authenticated, service_role;

COMMENT ON FUNCTION puls_app.get_notification_center_bootstrap_status() IS
  'PR16.9.4 app-wide Notification Center status RPC. Realtime is enabled only as private minimal hints with RPC/polling fallback and no external delivery.';

NOTIFY pgrst, 'reload schema';
