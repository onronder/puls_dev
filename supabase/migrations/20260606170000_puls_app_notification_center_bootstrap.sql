-- PR16.9.0 app-wide Notification Center bootstrap.
-- Creates only the puls_app schema and a minimal smoke RPC. It does not
-- create notification ledgers, realtime channels, external delivery, or UI data.

CREATE SCHEMA IF NOT EXISTS puls_app;

COMMENT ON SCHEMA puls_app IS
  'Application experience schema for app-wide capabilities such as Notification Center. PR16.9.0 bootstrap only; notification ledgers are added in later phases.';

REVOKE ALL ON SCHEMA puls_app FROM PUBLIC;
GRANT USAGE ON SCHEMA puls_app TO authenticated, service_role;

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
    'pr16.9.0-puls-app-bootstrap-v1'::TEXT AS contract_version,
    'puls_app'::TEXT AS schema_name,
    v_auth_role AS auth_role,
    v_tenant_id AS current_tenant_id,
    v_employee_id AS current_employee_id,
    v_persona_role AS current_persona_role,
    v_is_admin AS is_admin,
    TRUE AS app_schema_available,
    FALSE AS notification_ledger_enabled,
    FALSE AS notification_realtime_enabled,
    FALSE AS external_delivery_enabled,
    'implement_notification_ledger_pr16_9_1'::TEXT AS next_action_key,
    jsonb_build_object(
      'contract_version', 'pr16.9.0-puls-app-bootstrap-v1',
      'schema_name', 'puls_app',
      'app_wide_capability', TRUE,
      'bootstrap_phase', 'pr16.9.0',
      'notification_ledger_enabled', FALSE,
      'notification_tables_created', FALSE,
      'notification_realtime_enabled', FALSE,
      'realtime_required', FALSE,
      'external_delivery_enabled', FALSE,
      'email_delivery_enabled', FALSE,
      'push_delivery_enabled', FALSE,
      'browser_direct_table_write', FALSE,
      'authenticated_direct_table_write', FALSE,
      'source_domain', 'app_notification_center',
      'first_producer_planned', 'connector_runtime',
      'first_surface_planned', '/erp',
      'safe_payload_only', TRUE,
      'credential_readback', FALSE,
      'provider_api_calls', FALSE,
      'provider_response_readback', FALSE,
      'raw_payload_readback', FALSE,
      'field_value_readback', FALSE,
      'snapshot_payload_readback', FALSE,
      'source_writeback', FALSE,
      'ai_autonomous_action', FALSE,
      'postgrest_schema_exposure_required', TRUE,
      'postgrest_schema_reload_hint', 'NOTIFY pgrst, reload schema',
      'next_action_key', 'implement_notification_ledger_pr16_9_1'
    ) AS safe_summary;
END;
$$;

REVOKE ALL ON FUNCTION puls_app.get_notification_center_bootstrap_status()
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION puls_app.get_notification_center_bootstrap_status()
TO authenticated, service_role;

COMMENT ON FUNCTION puls_app.get_notification_center_bootstrap_status() IS
  'PR16.9.0 app-wide Notification Center bootstrap smoke RPC. Confirms puls_app exposure posture without creating notification ledgers, realtime, delivery, or raw payload access.';

NOTIFY pgrst, 'reload schema';
