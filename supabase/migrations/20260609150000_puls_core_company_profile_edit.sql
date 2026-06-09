-- PR17.1D company profile edit.
-- Adds one safe tenant profile RPC for setup admins. No tax identifier update,
-- plan mutation, connector runtime, external source update, credential readback, or
-- raw import payload readback.

CREATE OR REPLACE FUNCTION puls_core._company_profile_assert_admin()
RETURNS UUID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
DECLARE
  v_tenant_id UUID := puls_core.current_tenant_id();
BEGIN
  IF v_tenant_id IS NULL OR NOT puls_core.is_admin() THEN
    RAISE EXCEPTION 'PULS_COMPANY_PROFILE_FORBIDDEN: company profile changes require an admin in the current tenant.'
      USING ERRCODE = 'P0001';
  END IF;

  RETURN v_tenant_id;
END;
$$;

CREATE OR REPLACE FUNCTION puls_core.update_company_profile(
  p_trade_name TEXT,
  p_industry TEXT DEFAULT NULL,
  p_locale TEXT DEFAULT 'tr-TR',
  p_timezone TEXT DEFAULT 'Europe/Istanbul'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_core, puls_audit
AS $$
DECLARE
  v_tenant_id UUID := puls_core._company_profile_assert_admin();
  v_tenant puls_core.tenants;
  v_trade_name TEXT := NULLIF(BTRIM(COALESCE(p_trade_name, '')), '');
  v_industry TEXT := NULLIF(BTRIM(COALESCE(p_industry, '')), '');
  v_locale TEXT := NULLIF(BTRIM(COALESCE(p_locale, '')), '');
  v_timezone TEXT := NULLIF(BTRIM(COALESCE(p_timezone, '')), '');
  v_changed_fields TEXT[] := ARRAY[]::TEXT[];
BEGIN
  SELECT tenant.*
  INTO v_tenant
  FROM puls_core.tenants tenant
  WHERE tenant.id = v_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_COMPANY_PROFILE_NOT_FOUND: tenant profile was not found.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_trade_name IS NULL OR LENGTH(v_trade_name) < 2 OR LENGTH(v_trade_name) > 120 THEN
    RAISE EXCEPTION 'PULS_COMPANY_PROFILE_INVALID_NAME: company display name must be between 2 and 120 characters.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_industry IS NOT NULL AND LENGTH(v_industry) > 80 THEN
    RAISE EXCEPTION 'PULS_COMPANY_PROFILE_INVALID_INDUSTRY: sector must be 80 characters or shorter.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_locale IS NULL OR v_locale NOT IN ('tr-TR', 'en-US') THEN
    RAISE EXCEPTION 'PULS_COMPANY_PROFILE_INVALID_LOCALE: locale is not supported.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_timezone IS NULL
     OR NOT EXISTS (
       SELECT 1
       FROM pg_catalog.pg_timezone_names timezone_name
       WHERE timezone_name.name = v_timezone
     ) THEN
    RAISE EXCEPTION 'PULS_COMPANY_PROFILE_INVALID_TIMEZONE: timezone is not supported.'
      USING ERRCODE = 'P0001';
  END IF;

  IF COALESCE(v_tenant.trade_name, v_tenant.name) IS DISTINCT FROM v_trade_name THEN
    v_changed_fields := array_append(v_changed_fields, 'trade_name');
  END IF;

  IF v_tenant.industry IS DISTINCT FROM v_industry THEN
    v_changed_fields := array_append(v_changed_fields, 'industry');
  END IF;

  IF v_tenant.locale IS DISTINCT FROM v_locale THEN
    v_changed_fields := array_append(v_changed_fields, 'locale');
  END IF;

  IF v_tenant.timezone IS DISTINCT FROM v_timezone THEN
    v_changed_fields := array_append(v_changed_fields, 'timezone');
  END IF;

  IF array_length(v_changed_fields, 1) IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'unchanged',
      'tenant_id', v_tenant_id,
      'trade_name', COALESCE(v_tenant.trade_name, v_tenant.name),
      'industry', v_tenant.industry,
      'locale', v_tenant.locale,
      'timezone', v_tenant.timezone,
      'changed_fields', ARRAY[]::TEXT[]
    );
  END IF;

  UPDATE puls_core.tenants tenant
  SET trade_name = v_trade_name,
      industry = v_industry,
      locale = v_locale,
      timezone = v_timezone,
      updated_at = NOW()
  WHERE tenant.id = v_tenant_id;

  INSERT INTO puls_audit.audit_logs (
    tenant_id,
    actor_user_id,
    actor_employee_id,
    action,
    target_schema,
    target_table,
    target_id,
    metadata,
    source
  )
  VALUES (
    v_tenant_id,
    auth.uid(),
    puls_core.current_employee_id(),
    'core.company_profile.update',
    'puls_core',
    'tenants',
    v_tenant_id,
    jsonb_build_object(
      'changed_fields', to_jsonb(v_changed_fields),
      'safe_company_profile_audit', TRUE
    ),
    'company_profile_edit'
  );

  RETURN jsonb_build_object(
    'status', 'updated',
    'tenant_id', v_tenant_id,
    'trade_name', v_trade_name,
    'industry', v_industry,
    'locale', v_locale,
    'timezone', v_timezone,
    'changed_fields', to_jsonb(v_changed_fields)
  );
END;
$$;

REVOKE ALL ON FUNCTION puls_core._company_profile_assert_admin() FROM PUBLIC;
REVOKE ALL ON FUNCTION puls_core._company_profile_assert_admin() FROM anon;
REVOKE ALL ON FUNCTION puls_core._company_profile_assert_admin() FROM authenticated;
GRANT EXECUTE ON FUNCTION puls_core._company_profile_assert_admin() TO service_role;

REVOKE ALL ON FUNCTION puls_core.update_company_profile(TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION puls_core.update_company_profile(TEXT, TEXT, TEXT, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION puls_core.update_company_profile(TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role;

COMMENT ON FUNCTION puls_core.update_company_profile(TEXT, TEXT, TEXT, TEXT)
  IS 'PR17.1D safe company profile edit RPC. Admin-only, tenant-scoped, metadata-audited, and limited to display name, sector, locale, and timezone.';
