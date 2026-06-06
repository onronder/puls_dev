-- PR16.9.1 app-wide durable Notification Center ledger.
-- Creates the app notification source of truth and RPC boundary without
-- opening direct browser table writes, realtime delivery, external delivery,
-- ERP/source writeback, provider calls, credential readback, raw payload
-- readback, snapshot payload readback, or field value readback.

CREATE SCHEMA IF NOT EXISTS puls_app;

COMMENT ON SCHEMA puls_app IS
  'Application experience schema for app-wide capabilities such as Notification Center. Owns durable notification ledgers and user-visible app event state.';

CREATE OR REPLACE FUNCTION puls_app._app_notification_safe_summary_has_blocked_key(
  p_context JSONB
)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
SET search_path = pg_catalog
AS $$
DECLARE
  v_key TEXT;
  v_norm TEXT;
  v_value JSONB;
  v_item JSONB;
BEGIN
  IF p_context IS NULL OR jsonb_typeof(p_context) = 'null' THEN
    RETURN FALSE;
  END IF;

  IF jsonb_typeof(p_context) = 'object' THEN
    FOR v_key, v_value IN SELECT key, value FROM jsonb_each(p_context) LOOP
      v_norm := lower(v_key);
      IF v_norm IN (
        'api_key',
        'apikey',
        'authorization',
        'bearer',
        'credential',
        'credentials',
        'credentials_ref',
        'connection_string',
        'private_key',
        'client_secret',
        'refresh_token',
        'access_token',
        'raw_payload',
        'raw_source_payload',
        'raw_snapshot_payload',
        'provider_payload',
        'provider_response',
        'request_body',
        'response_body',
        'snapshot_payload',
        'field_value',
        'field_values',
        'before_value',
        'after_value'
      )
      OR v_norm LIKE '%password%'
      OR v_norm LIKE '%passwd%'
      OR v_norm LIKE '%secret%'
      OR v_norm LIKE '%token%' THEN
        RETURN TRUE;
      END IF;

      IF puls_app._app_notification_safe_summary_has_blocked_key(v_value) THEN
        RETURN TRUE;
      END IF;
    END LOOP;
    RETURN FALSE;
  END IF;

  IF jsonb_typeof(p_context) = 'array' THEN
    FOR v_item IN SELECT value FROM jsonb_array_elements(p_context) LOOP
      IF puls_app._app_notification_safe_summary_has_blocked_key(v_item) THEN
        RETURN TRUE;
      END IF;
    END LOOP;
  END IF;

  RETURN FALSE;
END;
$$;

CREATE OR REPLACE FUNCTION puls_app._app_notification_target_visible(
  p_target_roles TEXT[],
  p_target_employee_ids UUID[],
  p_employee_id UUID,
  p_persona_role TEXT,
  p_is_admin BOOLEAN
)
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog
AS $$
  SELECT
    p_employee_id IS NOT NULL
    AND (
      COALESCE(p_target_employee_ids, '{}'::UUID[]) @> ARRAY[p_employee_id]
      OR COALESCE(p_target_roles, '{}'::TEXT[]) && ARRAY['all']::TEXT[]
      OR COALESCE(p_target_roles, '{}'::TEXT[]) @> ARRAY[COALESCE(p_persona_role, '')]::TEXT[]
      OR (
        COALESCE(p_is_admin, FALSE)
        AND COALESCE(p_target_roles, '{}'::TEXT[]) && ARRAY['admin', 'hr_admin', 'superadmin']::TEXT[]
      )
    );
$$;

CREATE TABLE IF NOT EXISTS puls_app.app_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  source_domain TEXT NOT NULL,
  source_event_key TEXT NOT NULL,
  source_table TEXT NULL,
  source_id UUID NULL,
  severity TEXT NOT NULL DEFAULT 'info',
  priority INTEGER NOT NULL DEFAULT 50,
  target_roles TEXT[] NOT NULL DEFAULT ARRAY['admin']::TEXT[],
  target_employee_ids UUID[] NOT NULL DEFAULT '{}'::UUID[],
  subject_type TEXT NULL,
  subject_id UUID NULL,
  title_key TEXT NOT NULL,
  body_key TEXT NULL,
  route_hint TEXT NULL,
  action_key TEXT NULL,
  dedupe_key TEXT NOT NULL,
  notification_status TEXT NOT NULL DEFAULT 'active',
  safe_summary JSONB NOT NULL DEFAULT '{}'::JSONB,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NULL DEFAULT (NOW() + INTERVAL '180 days'),
  created_by_employee_id UUID NULL REFERENCES puls_core.employees(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (source_domain <> ''),
  CHECK (source_event_key <> ''),
  CHECK (severity IN ('info', 'success', 'warning', 'error', 'critical')),
  CHECK (priority BETWEEN 0 AND 100),
  CHECK (target_roles <@ ARRAY['all', 'employee', 'manager', 'hr_admin', 'superadmin', 'admin']::TEXT[]),
  CHECK (array_position(target_roles, NULL) IS NULL),
  CHECK (array_position(target_employee_ids, NULL) IS NULL),
  CHECK (cardinality(target_roles) > 0 OR cardinality(target_employee_ids) > 0),
  CHECK (title_key <> ''),
  CHECK (dedupe_key <> ''),
  CHECK (notification_status IN ('active', 'archived')),
  CHECK (expires_at IS NULL OR expires_at > occurred_at),
  CHECK (jsonb_typeof(safe_summary) = 'object'),
  CHECK (puls_app._app_notification_safe_summary_has_blocked_key(safe_summary) IS FALSE),
  CONSTRAINT app_notifications_tenant_dedupe_unique UNIQUE (tenant_id, dedupe_key)
);

CREATE TABLE IF NOT EXISTS puls_app.app_notification_reads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  notification_id UUID NOT NULL REFERENCES puls_app.app_notifications(id) ON DELETE CASCADE,
  employee_id UUID NOT NULL REFERENCES puls_core.employees(id) ON DELETE CASCADE,
  read_at TIMESTAMPTZ NULL,
  dismissed_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (read_at IS NULL OR read_at >= created_at),
  CHECK (dismissed_at IS NULL OR dismissed_at >= created_at),
  CONSTRAINT app_notification_reads_notification_employee_unique UNIQUE (notification_id, employee_id)
);

CREATE INDEX IF NOT EXISTS idx_puls_app_notifications_tenant_occurred
  ON puls_app.app_notifications (tenant_id, occurred_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_puls_app_notifications_tenant_status
  ON puls_app.app_notifications (tenant_id, notification_status, severity, source_domain);

CREATE INDEX IF NOT EXISTS idx_puls_app_notifications_source
  ON puls_app.app_notifications (tenant_id, source_domain, source_event_key, source_id);

CREATE INDEX IF NOT EXISTS idx_puls_app_notifications_target_roles
  ON puls_app.app_notifications USING GIN (target_roles);

CREATE INDEX IF NOT EXISTS idx_puls_app_notifications_target_employees
  ON puls_app.app_notifications USING GIN (target_employee_ids);

CREATE INDEX IF NOT EXISTS idx_puls_app_notification_reads_employee
  ON puls_app.app_notification_reads (tenant_id, employee_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_puls_app_notification_reads_notification
  ON puls_app.app_notification_reads (notification_id, employee_id);

COMMENT ON TABLE puls_app.app_notifications IS
  'PR16.9.1 durable app-wide notification ledger. Stores safe metadata only; no raw payloads, field values, provider responses, credentials, external delivery, or realtime correctness dependency.';

COMMENT ON TABLE puls_app.app_notification_reads IS
  'PR16.9.1 per-employee app notification read and dismiss state. Mutated only through RPCs; direct browser table writes remain closed.';

CREATE OR REPLACE FUNCTION puls_app.reject_app_notification_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_app
AS $$
BEGIN
  RAISE EXCEPTION
    'PULS_APP_NOTIFICATION_IMMUTABLE: app notification ledger rows cannot be updated or deleted.';
END;
$$;

DROP TRIGGER IF EXISTS puls_app_notifications_immutable
  ON puls_app.app_notifications;
CREATE TRIGGER puls_app_notifications_immutable
  BEFORE UPDATE OR DELETE ON puls_app.app_notifications
  FOR EACH ROW EXECUTE FUNCTION puls_app.reject_app_notification_mutation();

DROP TRIGGER IF EXISTS puls_app_notification_reads_set_updated_at
  ON puls_app.app_notification_reads;
CREATE TRIGGER puls_app_notification_reads_set_updated_at
  BEFORE UPDATE ON puls_app.app_notification_reads
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

CREATE OR REPLACE FUNCTION puls_app.emit_app_notification(
  p_tenant_id UUID,
  p_source_domain TEXT,
  p_source_event_key TEXT,
  p_title_key TEXT,
  p_source_table TEXT DEFAULT NULL,
  p_source_id UUID DEFAULT NULL,
  p_severity TEXT DEFAULT 'info',
  p_priority INTEGER DEFAULT 50,
  p_target_roles TEXT[] DEFAULT ARRAY['admin']::TEXT[],
  p_target_employee_ids UUID[] DEFAULT '{}'::UUID[],
  p_subject_type TEXT DEFAULT NULL,
  p_subject_id UUID DEFAULT NULL,
  p_body_key TEXT DEFAULT NULL,
  p_route_hint TEXT DEFAULT NULL,
  p_action_key TEXT DEFAULT NULL,
  p_dedupe_key TEXT DEFAULT NULL,
  p_safe_summary JSONB DEFAULT '{}'::JSONB,
  p_occurred_at TIMESTAMPTZ DEFAULT NOW(),
  p_expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '180 days')
)
RETURNS TABLE (
  notification_id UUID,
  tenant_id UUID,
  source_domain TEXT,
  source_event_key TEXT,
  severity TEXT,
  priority INTEGER,
  dedupe_key TEXT,
  inserted BOOLEAN,
  next_action_key TEXT,
  safe_summary JSONB,
  occurred_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_app, puls_core
AS $$
DECLARE
  v_auth_role TEXT := COALESCE(auth.role(), '');
  v_safe_summary JSONB := COALESCE(p_safe_summary, '{}'::JSONB);
  v_target_roles TEXT[] := COALESCE(p_target_roles, '{}'::TEXT[]);
  v_target_employee_ids UUID[] := COALESCE(p_target_employee_ids, '{}'::UUID[]);
  v_dedupe_key TEXT := NULLIF(BTRIM(COALESCE(p_dedupe_key, '')), '');
  v_notification_id UUID;
  v_inserted BOOLEAN := FALSE;
BEGIN
  IF v_auth_role <> 'service_role' THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_EMIT_SERVICE_ROLE_REQUIRED: app notification emission requires service_role.'
      USING ERRCODE = 'P0001';
  END IF;

  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_TENANT_REQUIRED: notification tenant is required.'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM puls_core.tenants tenant WHERE tenant.id = p_tenant_id) THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_TENANT_NOT_FOUND: notification tenant was not found.'
      USING ERRCODE = 'P0001';
  END IF;

  IF NULLIF(BTRIM(COALESCE(p_source_domain, '')), '') IS NULL THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_SOURCE_DOMAIN_REQUIRED: source domain is required.'
      USING ERRCODE = 'P0001';
  END IF;

  IF NULLIF(BTRIM(COALESCE(p_source_event_key, '')), '') IS NULL THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_SOURCE_EVENT_REQUIRED: source event key is required.'
      USING ERRCODE = 'P0001';
  END IF;

  IF NULLIF(BTRIM(COALESCE(p_title_key, '')), '') IS NULL THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_TITLE_KEY_REQUIRED: title key is required.'
      USING ERRCODE = 'P0001';
  END IF;

  IF COALESCE(p_severity, '') NOT IN ('info', 'success', 'warning', 'error', 'critical') THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_SEVERITY_INVALID: notification severity is invalid.'
      USING ERRCODE = 'P0001';
  END IF;

  IF COALESCE(p_priority, -1) NOT BETWEEN 0 AND 100 THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_PRIORITY_INVALID: notification priority must be between 0 and 100.'
      USING ERRCODE = 'P0001';
  END IF;

  IF array_position(v_target_roles, NULL) IS NOT NULL
     OR array_position(v_target_employee_ids, NULL) IS NOT NULL THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_TARGET_INVALID: notification targets cannot contain null values.'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT (v_target_roles <@ ARRAY['all', 'employee', 'manager', 'hr_admin', 'superadmin', 'admin']::TEXT[]) THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_TARGET_ROLE_INVALID: notification target role is invalid.'
      USING ERRCODE = 'P0001';
  END IF;

  IF cardinality(v_target_roles) = 0 AND cardinality(v_target_employee_ids) = 0 THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_TARGET_REQUIRED: at least one role or employee target is required.'
      USING ERRCODE = 'P0001';
  END IF;

  IF jsonb_typeof(v_safe_summary) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_SAFE_SUMMARY_OBJECT_REQUIRED: safe summary must be a JSON object.'
      USING ERRCODE = 'P0001';
  END IF;

  IF puls_app._app_notification_safe_summary_has_blocked_key(v_safe_summary) THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_SAFE_SUMMARY_BLOCKED_KEY: safe summary contains blocked sensitive keys.'
      USING ERRCODE = 'P0001';
  END IF;

  IF p_expires_at IS NOT NULL AND p_expires_at <= p_occurred_at THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_EXPIRY_INVALID: expiry must be after occurrence time.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_dedupe_key IS NULL THEN
    v_dedupe_key := encode(
      sha256(
        convert_to(
          concat_ws(
            '|',
            'pr16.9.1-app-notification-ledger-v1',
            p_tenant_id::TEXT,
            BTRIM(p_source_domain),
            BTRIM(p_source_event_key),
            COALESCE(BTRIM(p_source_table), ''),
            COALESCE(p_source_id::TEXT, ''),
            COALESCE(BTRIM(p_subject_type), ''),
            COALESCE(p_subject_id::TEXT, ''),
            BTRIM(p_title_key)
          ),
          'UTF8'
        )
      ),
      'hex'
    );
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
    BTRIM(p_source_domain),
    BTRIM(p_source_event_key),
    NULLIF(BTRIM(COALESCE(p_source_table, '')), ''),
    p_source_id,
    p_severity,
    p_priority,
    v_target_roles,
    v_target_employee_ids,
    NULLIF(BTRIM(COALESCE(p_subject_type, '')), ''),
    p_subject_id,
    BTRIM(p_title_key),
    NULLIF(BTRIM(COALESCE(p_body_key, '')), ''),
    NULLIF(BTRIM(COALESCE(p_route_hint, '')), ''),
    NULLIF(BTRIM(COALESCE(p_action_key, '')), ''),
    v_dedupe_key,
    v_safe_summary || jsonb_build_object(
      'contract_version', 'pr16.9.1-app-notification-ledger-v1',
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
    p_occurred_at,
    p_expires_at
  )
  ON CONFLICT ON CONSTRAINT app_notifications_tenant_dedupe_unique DO NOTHING
  RETURNING id INTO v_notification_id;

  v_inserted := v_notification_id IS NOT NULL;

  IF v_notification_id IS NULL THEN
    SELECT existing.id
    INTO v_notification_id
    FROM puls_app.app_notifications existing
    WHERE existing.tenant_id = p_tenant_id
      AND existing.dedupe_key = v_dedupe_key;
  END IF;

  RETURN QUERY
  SELECT
    notification.id AS notification_id,
    notification.tenant_id,
    notification.source_domain,
    notification.source_event_key,
    notification.severity,
    notification.priority,
    notification.dedupe_key,
    v_inserted AS inserted,
    notification.action_key AS next_action_key,
    notification.safe_summary,
    notification.occurred_at,
    notification.expires_at,
    notification.created_at
  FROM puls_app.app_notifications notification
  WHERE notification.id = v_notification_id;
END;
$$;

CREATE OR REPLACE FUNCTION puls_app.list_app_notifications(
  p_limit INTEGER DEFAULT 50,
  p_include_read BOOLEAN DEFAULT TRUE,
  p_include_dismissed BOOLEAN DEFAULT FALSE,
  p_severity TEXT DEFAULT NULL,
  p_source_domain TEXT DEFAULT NULL,
  p_tenant_id UUID DEFAULT NULL
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
  is_action_required BOOLEAN
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
  v_limit INTEGER := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
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
    AND (p_severity IS NULL OR notification.severity = p_severity)
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
    AND (NOT v_is_service_role OR p_tenant_id IS NULL OR notification.tenant_id = p_tenant_id)
    AND (p_include_read OR read_state.read_at IS NULL)
    AND (p_include_dismissed OR read_state.dismissed_at IS NULL)
  ORDER BY notification.priority DESC, notification.occurred_at DESC, notification.id DESC
  LIMIT v_limit;
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
    FALSE AS notification_realtime_enabled,
    FALSE AS external_delivery_enabled,
    'map_connector_notifications_pr16_9_2'::TEXT AS next_action_key,
    jsonb_build_object(
      'contract_version', 'pr16.9.1-app-notification-ledger-v1',
      'notification_ledger_enabled', TRUE,
      'notification_realtime_enabled', FALSE,
      'external_delivery_enabled', FALSE,
      'browser_direct_table_write', FALSE,
      'safe_payload_only', TRUE,
      'source_writeback', FALSE,
      'provider_api_calls', FALSE,
      'credential_readback', FALSE,
      'raw_payload_readback', FALSE,
      'field_value_readback', FALSE,
      'snapshot_payload_readback', FALSE,
      'next_action_key', 'map_connector_notifications_pr16_9_2'
    ) AS safe_summary
  FROM visible_notifications;
END;
$$;

CREATE OR REPLACE FUNCTION puls_app.mark_app_notification_read(
  p_notification_id UUID
)
RETURNS TABLE (
  notification_id UUID,
  employee_id UUID,
  read_at TIMESTAMPTZ,
  dismissed_at TIMESTAMPTZ,
  is_read BOOLEAN,
  is_dismissed BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_app, puls_core
AS $$
DECLARE
  v_auth_role TEXT := COALESCE(auth.role(), '');
  v_is_service_role BOOLEAN := v_auth_role = 'service_role';
  v_tenant_id UUID := puls_core.current_tenant_id();
  v_employee_id UUID := puls_core.current_employee_id();
  v_persona_role TEXT := puls_core.current_persona_role()::TEXT;
  v_is_admin BOOLEAN := COALESCE(puls_core.is_admin(), FALSE);
  v_notification puls_app.app_notifications;
BEGIN
  IF v_is_service_role AND v_employee_id IS NULL THEN
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

  SELECT notification.*
  INTO v_notification
  FROM puls_app.app_notifications notification
  WHERE notification.id = p_notification_id
    AND notification.tenant_id = v_tenant_id
    AND notification.notification_status = 'active'
    AND (notification.expires_at IS NULL OR notification.expires_at > NOW())
    AND (
      v_is_service_role
      OR puls_app._app_notification_target_visible(
        notification.target_roles,
        notification.target_employee_ids,
        v_employee_id,
        v_persona_role,
        v_is_admin
      )
    );

  IF v_notification.id IS NULL THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_NOT_FOUND: notification is not visible to this caller.'
      USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO puls_app.app_notification_reads (
    tenant_id,
    notification_id,
    employee_id,
    read_at
  )
  VALUES (
    v_notification.tenant_id,
    v_notification.id,
    v_employee_id,
    NOW()
  )
  ON CONFLICT ON CONSTRAINT app_notification_reads_notification_employee_unique
  DO UPDATE SET
    read_at = COALESCE(puls_app.app_notification_reads.read_at, EXCLUDED.read_at);

  RETURN QUERY
  SELECT
    read_state.notification_id,
    read_state.employee_id,
    read_state.read_at,
    read_state.dismissed_at,
    read_state.read_at IS NOT NULL AS is_read,
    read_state.dismissed_at IS NOT NULL AS is_dismissed
  FROM puls_app.app_notification_reads read_state
  WHERE read_state.notification_id = v_notification.id
    AND read_state.employee_id = v_employee_id;
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
    );

  RETURN QUERY
  SELECT
    v_marked_count AS marked_count,
    v_unread_remaining_count AS unread_remaining_count,
    v_read_at AS read_at;
END;
$$;

CREATE OR REPLACE FUNCTION puls_app.dismiss_app_notification(
  p_notification_id UUID
)
RETURNS TABLE (
  notification_id UUID,
  employee_id UUID,
  read_at TIMESTAMPTZ,
  dismissed_at TIMESTAMPTZ,
  is_read BOOLEAN,
  is_dismissed BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_app, puls_core
AS $$
DECLARE
  v_auth_role TEXT := COALESCE(auth.role(), '');
  v_is_service_role BOOLEAN := v_auth_role = 'service_role';
  v_tenant_id UUID := puls_core.current_tenant_id();
  v_employee_id UUID := puls_core.current_employee_id();
  v_persona_role TEXT := puls_core.current_persona_role()::TEXT;
  v_is_admin BOOLEAN := COALESCE(puls_core.is_admin(), FALSE);
  v_notification puls_app.app_notifications;
  v_now TIMESTAMPTZ := NOW();
BEGIN
  IF v_is_service_role AND v_employee_id IS NULL THEN
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

  SELECT notification.*
  INTO v_notification
  FROM puls_app.app_notifications notification
  WHERE notification.id = p_notification_id
    AND notification.tenant_id = v_tenant_id
    AND notification.notification_status = 'active'
    AND (notification.expires_at IS NULL OR notification.expires_at > NOW())
    AND (
      v_is_service_role
      OR puls_app._app_notification_target_visible(
        notification.target_roles,
        notification.target_employee_ids,
        v_employee_id,
        v_persona_role,
        v_is_admin
      )
    );

  IF v_notification.id IS NULL THEN
    RAISE EXCEPTION
      'PULS_APP_NOTIFICATION_NOT_FOUND: notification is not visible to this caller.'
      USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO puls_app.app_notification_reads (
    tenant_id,
    notification_id,
    employee_id,
    read_at,
    dismissed_at
  )
  VALUES (
    v_notification.tenant_id,
    v_notification.id,
    v_employee_id,
    v_now,
    v_now
  )
  ON CONFLICT ON CONSTRAINT app_notification_reads_notification_employee_unique
  DO UPDATE SET
    read_at = COALESCE(puls_app.app_notification_reads.read_at, EXCLUDED.read_at),
    dismissed_at = COALESCE(puls_app.app_notification_reads.dismissed_at, EXCLUDED.dismissed_at);

  RETURN QUERY
  SELECT
    read_state.notification_id,
    read_state.employee_id,
    read_state.read_at,
    read_state.dismissed_at,
    read_state.read_at IS NOT NULL AS is_read,
    read_state.dismissed_at IS NOT NULL AS is_dismissed
  FROM puls_app.app_notification_reads read_state
  WHERE read_state.notification_id = v_notification.id
    AND read_state.employee_id = v_employee_id;
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
    'pr16.9.1-app-notification-ledger-v1'::TEXT AS contract_version,
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
    'map_connector_notifications_pr16_9_2'::TEXT AS next_action_key,
    jsonb_build_object(
      'contract_version', 'pr16.9.1-app-notification-ledger-v1',
      'schema_name', 'puls_app',
      'app_wide_capability', TRUE,
      'notification_ledger_enabled', TRUE,
      'notification_tables_created', TRUE,
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
      'next_action_key', 'map_connector_notifications_pr16_9_2'
    ) AS safe_summary;
END;
$$;

ALTER TABLE puls_app.app_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_app.app_notification_reads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS puls_app_notifications_service_role
  ON puls_app.app_notifications;
CREATE POLICY puls_app_notifications_service_role
  ON puls_app.app_notifications
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS puls_app_notification_reads_service_role
  ON puls_app.app_notification_reads;
CREATE POLICY puls_app_notification_reads_service_role
  ON puls_app.app_notification_reads
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

REVOKE ALL ON SCHEMA puls_app FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA puls_app TO authenticated, service_role;

REVOKE ALL ON TABLE puls_app.app_notifications
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE puls_app.app_notification_reads
  FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT, INSERT ON TABLE puls_app.app_notifications
  TO service_role;
GRANT SELECT, INSERT, UPDATE ON TABLE puls_app.app_notification_reads
  TO service_role;

REVOKE ALL ON FUNCTION puls_app._app_notification_safe_summary_has_blocked_key(JSONB)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION puls_app._app_notification_safe_summary_has_blocked_key(JSONB)
  TO service_role;

REVOKE ALL ON FUNCTION puls_app._app_notification_target_visible(TEXT[], UUID[], UUID, TEXT, BOOLEAN)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION puls_app._app_notification_target_visible(TEXT[], UUID[], UUID, TEXT, BOOLEAN)
  TO service_role;

REVOKE ALL ON FUNCTION puls_app.reject_app_notification_mutation()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION puls_app.reject_app_notification_mutation()
  TO service_role;

REVOKE ALL ON FUNCTION puls_app.emit_app_notification(
  UUID, TEXT, TEXT, TEXT, TEXT, UUID, TEXT, INTEGER, TEXT[], UUID[], TEXT, UUID,
  TEXT, TEXT, TEXT, TEXT, JSONB, TIMESTAMPTZ, TIMESTAMPTZ
) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_app.emit_app_notification(
  UUID, TEXT, TEXT, TEXT, TEXT, UUID, TEXT, INTEGER, TEXT[], UUID[], TEXT, UUID,
  TEXT, TEXT, TEXT, TEXT, JSONB, TIMESTAMPTZ, TIMESTAMPTZ
) TO service_role;

REVOKE ALL ON FUNCTION puls_app.list_app_notifications(
  INTEGER, BOOLEAN, BOOLEAN, TEXT, TEXT, UUID
) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_app.list_app_notifications(
  INTEGER, BOOLEAN, BOOLEAN, TEXT, TEXT, UUID
) TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_app.get_app_notification_summary(TEXT)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_app.get_app_notification_summary(TEXT)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_app.mark_app_notification_read(UUID)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_app.mark_app_notification_read(UUID)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_app.mark_all_app_notifications_read(TEXT)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_app.mark_all_app_notifications_read(TEXT)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_app.dismiss_app_notification(UUID)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_app.dismiss_app_notification(UUID)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_app.get_notification_center_bootstrap_status()
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_app.get_notification_center_bootstrap_status()
  TO authenticated, service_role;

COMMENT ON FUNCTION puls_app.emit_app_notification(
  UUID, TEXT, TEXT, TEXT, TEXT, UUID, TEXT, INTEGER, TEXT[], UUID[], TEXT, UUID,
  TEXT, TEXT, TEXT, TEXT, JSONB, TIMESTAMPTZ, TIMESTAMPTZ
) IS
  'PR16.9.1 service-role app notification emitter. Inserts idempotently by tenant/dedupe key and rejects unsafe summaries; no external delivery or realtime dependency.';

COMMENT ON FUNCTION puls_app.list_app_notifications(
  INTEGER, BOOLEAN, BOOLEAN, TEXT, TEXT, UUID
) IS
  'PR16.9.1 authenticated app notification inbox read model. Resolves tenant, employee, and role visibility server-side and returns safe summaries only.';

COMMENT ON FUNCTION puls_app.get_app_notification_summary(TEXT) IS
  'PR16.9.1 authenticated app notification summary counts for visible, unread, dismissed, action-required, warning, and critical notifications.';

COMMENT ON FUNCTION puls_app.mark_app_notification_read(UUID) IS
  'PR16.9.1 authenticated per-employee notification read-state mutation through RPC only.';

COMMENT ON FUNCTION puls_app.mark_all_app_notifications_read(TEXT) IS
  'PR16.9.1 authenticated bulk read-state mutation for currently visible non-dismissed notifications.';

COMMENT ON FUNCTION puls_app.dismiss_app_notification(UUID) IS
  'PR16.9.1 authenticated per-employee notification dismiss mutation through RPC only.';

COMMENT ON FUNCTION puls_app.get_notification_center_bootstrap_status() IS
  'PR16.9.1 app-wide Notification Center status RPC. Confirms durable ledger is enabled while realtime, delivery, raw payload access, and browser table writes remain closed.';

NOTIFY pgrst, 'reload schema';
