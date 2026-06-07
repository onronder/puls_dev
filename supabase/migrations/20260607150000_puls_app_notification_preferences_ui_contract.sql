-- PR16.9.7 notification preference UI contract.
-- This phase does not create notification tables, direct browser table writes,
-- external delivery, provider calls, source writeback, or sensitive readback.
-- It exposes the already-safe PR16.9.5 preference RPC contract as product UI.

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
    'pr16.9.7-notification-preferences-ui-v1'::TEXT AS contract_version,
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
    'extend_notifications_to_app_surfaces_pr16_10'::TEXT AS next_action_key,
    jsonb_build_object(
      'contract_version', 'pr16.9.7-notification-preferences-ui-v1',
      'schema_name', 'puls_app',
      'app_wide_capability', TRUE,
      'notification_center_ui_enabled', TRUE,
      'notification_cursor_paging_enabled', TRUE,
      'notification_detail_pane_enabled', TRUE,
      'notification_action_routing_enabled', TRUE,
      'notification_error_csv_export_enabled', TRUE,
      'notification_producer_orchestrator_enabled', TRUE,
      'notification_worker_refresh_enabled', TRUE,
      'notification_preferences_enabled', TRUE,
      'notification_preferences_ui_enabled', TRUE,
      'notification_preference_controls_enabled', TRUE,
      'notification_preference_source_scope_enabled', TRUE,
      'notification_preference_first_scope', 'connector_runtime/all',
      'notification_preference_minimum_severity_enabled', TRUE,
      'notification_preference_action_only_enabled', TRUE,
      'notification_preference_temporary_mute_enabled', TRUE,
      'notification_preference_reset_enabled', TRUE,
      'critical_notifications_always_visible', TRUE,
      'notification_scenario_contracts_enabled', TRUE
    )
    ||
    jsonb_build_object(
      'notification_ledger_enabled', TRUE,
      'notification_tables_exist', (
        to_regclass('puls_app.app_notifications') IS NOT NULL
        AND to_regclass('puls_app.app_notification_reads') IS NOT NULL
        AND to_regclass('puls_app.app_notification_preferences') IS NOT NULL
      ),
      'producer_orchestrator_rpc', 'run_app_notification_producers',
      'connector_producer_mapping_enabled', TRUE,
      'source_domain', 'app_notification_center',
      'first_producer_enabled', 'connector_runtime',
      'first_surface_enabled', 'global_shell',
      'first_surface_planned', '/erp',
      'first_surface_action_targets',
        ARRAY[
          'erp-runtime-queue',
          'erp-controlled-apply',
          'erp-guarded-update-rollback-preview',
          'erp-guarded-update-rollback-approval',
          'erp-guarded-update-rollback-worker-readiness',
          'erp-guarded-update-rollback-worker-apply'
        ]::TEXT[],
      'future_surface_compatible', TRUE,
      'notification_realtime_enabled', TRUE,
      'notification_realtime_required', FALSE,
      'notification_polling_fallback_enabled', TRUE,
      'notification_realtime_private_channel_enabled', TRUE,
      'notification_realtime_payload_minimal', TRUE,
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
      'next_action_key', 'extend_notifications_to_app_surfaces_pr16_10'
    ) AS safe_summary;
END;
$$;

REVOKE ALL ON FUNCTION puls_app.get_notification_center_bootstrap_status()
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_app.get_notification_center_bootstrap_status()
  TO authenticated, service_role;

COMMENT ON FUNCTION puls_app.get_notification_center_bootstrap_status() IS
  'PR16.9.7 app-wide Notification Center status RPC. In-app preference UI is enabled through existing RPC boundaries; external delivery remains closed.';

NOTIFY pgrst, 'reload schema';
