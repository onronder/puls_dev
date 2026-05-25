-- 09 PR4 — Import validate / preview / apply pipeline (MVP upsert-only; no tombstone sync)
-- Canonical writes only inside apply_import_batch. No resolver/decide changes. raw_payload stays NULL.

-- ---------------------------------------------------------------------------
-- Batch audit columns
-- ---------------------------------------------------------------------------

ALTER TABLE puls_integration.import_batches
  ADD COLUMN IF NOT EXISTS validated_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS previewed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS applied_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS applied_by_employee_id UUID NULL REFERENCES puls_core.employees(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS create_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS update_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS skip_count INTEGER NOT NULL DEFAULT 0;

-- ---------------------------------------------------------------------------
-- Internal: lock batch + tenant isolation
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_integration._import_lock_batch(p_batch_id UUID)
RETURNS puls_integration.import_batches
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core, puls_workflow
AS $$
DECLARE
  v_batch puls_integration.import_batches;
BEGIN
  SELECT *
  INTO v_batch
  FROM puls_integration.import_batches ib
  WHERE ib.id = p_batch_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PULS_IMPORT_BATCH_NOT_FOUND: batch % not found.', p_batch_id;
  END IF;

  IF auth.role() <> 'service_role' THEN
    IF v_batch.tenant_id IS DISTINCT FROM puls_core.current_tenant_id() THEN
      RAISE EXCEPTION 'PULS_IMPORT_CROSS_TENANT: batch belongs to another tenant.';
    END IF;
    IF NOT puls_integration.can_write_import_data() THEN
      RAISE EXCEPTION 'PULS_IMPORT_FORBIDDEN: insufficient privileges.';
    END IF;
  ELSE
    IF NOT puls_integration.can_write_import_data() THEN
      RAISE EXCEPTION 'PULS_IMPORT_FORBIDDEN: insufficient privileges.';
    END IF;
  END IF;

  RETURN v_batch;
END;
$$;

-- ---------------------------------------------------------------------------
-- Internal: reporting line source mapping (4 enum values only)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_integration._import_map_reporting_source(
  p_source_type puls_integration.source_type
)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog, puls_integration
AS $$
  SELECT CASE p_source_type
    WHEN 'manual'::puls_integration.source_type THEN 'manual'
    WHEN 'demo'::puls_integration.source_type THEN 'demo'
    WHEN 'erp'::puls_integration.source_type THEN 'erp'
    WHEN 'excel_csv'::puls_integration.source_type THEN 'erp'
    ELSE NULL
  END;
$$;

-- ---------------------------------------------------------------------------
-- Internal: normalize sanitized payload to allowlisted keys
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_integration._import_normalize_payload(
  p_entity_type puls_integration.import_entity_type,
  p_sanitized JSONB
)
RETURNS TABLE (normalized_payload JSONB, warning_codes TEXT[], error_codes TEXT[])
LANGUAGE plpgsql
IMMUTABLE
SET search_path = pg_catalog, puls_integration
AS $$
DECLARE
  v_allowed TEXT[];
  v_forbidden TEXT[] := ARRAY['persona_role', 'user_id'];
  v_blocked TEXT[] := puls_integration.import_blocked_keys();
  v_sensitive TEXT[] := ARRAY[
    -- SENSITIVE_BLOCK_LIST_BEGIN
    'salary', 'salary_min', 'salary_max', 'maas',
    'pay_band', 'payroll', 'compensation', 'tckn', 'iban', 'birth_date',
    'dogum_tarihi', 'health', 'saglik', 'family', 'aile'
    -- SENSITIVE_BLOCK_LIST_END
  ];
  v_key TEXT;
  v_norm TEXT;
  v_out JSONB := '{}'::jsonb;
  v_warnings TEXT[] := ARRAY[]::TEXT[];
  v_errors TEXT[] := ARRAY[]::TEXT[];
BEGIN
  v_allowed := CASE p_entity_type
    WHEN 'legal_entity'::puls_integration.import_entity_type THEN
      ARRAY['code', 'name', 'is_active']
    WHEN 'location'::puls_integration.import_entity_type THEN
      ARRAY['code', 'name', 'is_active', 'legal_entity_code', 'legal_entity_external_id']
    WHEN 'cost_center'::puls_integration.import_entity_type THEN
      ARRAY['code', 'name', 'is_active', 'legal_entity_code', 'legal_entity_external_id',
            'parent_cost_center_code', 'parent_cost_center_external_id']
    WHEN 'department'::puls_integration.import_entity_type THEN
      ARRAY['code', 'name', 'is_active', 'parent_department_code', 'parent_department_external_id',
            'manager_employee_code', 'manager_employee_external_id', 'manager_email',
            'cost_center_code', 'cost_center_external_id']
    WHEN 'position'::puls_integration.import_entity_type THEN
      ARRAY['code', 'name', 'is_active', 'department_code', 'department_external_id',
            'parent_position_code', 'parent_position_external_id', 'level', 'norm_headcount', 'employment_type']
    WHEN 'employee'::puls_integration.import_entity_type THEN
      ARRAY['employee_code', 'email', 'full_name', 'job_title', 'employment_status', 'hire_date',
            'termination_date', 'department_code', 'department_external_id', 'position_code',
            'position_external_id', 'manager_employee_code', 'manager_employee_external_id',
            'manager_email', 'legal_entity_code', 'legal_entity_external_id', 'location_code',
            'location_external_id', 'cost_center_code', 'cost_center_external_id']
    ELSE ARRAY[]::TEXT[]
  END;

  IF p_sanitized IS NULL OR jsonb_typeof(p_sanitized) <> 'object' THEN
    normalized_payload := '{}'::jsonb;
    warning_codes := v_warnings;
    error_codes := v_errors;
    RETURN NEXT;
    RETURN;
  END IF;

  FOR v_key IN SELECT jsonb_object_keys(p_sanitized) LOOP
    v_norm := lower(v_key);
    IF v_norm = ANY(v_forbidden) OR v_norm = ANY(v_blocked) OR v_norm = ANY(v_sensitive) THEN
      v_errors := array_append(v_errors, 'FORBIDDEN_FIELD_' || upper(v_norm));
    ELSIF v_norm = ANY(v_allowed) THEN
      v_out := v_out || jsonb_build_object(v_key, p_sanitized -> v_key);
    ELSE
      v_warnings := array_append(v_warnings, 'UNKNOWN_FIELD_STRIPPED');
    END IF;
  END LOOP;

  normalized_payload := v_out;
  warning_codes := v_warnings;
  error_codes := v_errors;
  RETURN NEXT;
END;
$$;

-- ---------------------------------------------------------------------------
-- Internal: entity type -> canonical table
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_integration._import_canonical_table(
  p_entity_type puls_integration.import_entity_type
)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog
AS $$
  SELECT CASE p_entity_type
    WHEN 'employee'::puls_integration.import_entity_type THEN 'employees'
    WHEN 'department'::puls_integration.import_entity_type THEN 'departments'
    WHEN 'position'::puls_integration.import_entity_type THEN 'positions'
    WHEN 'legal_entity'::puls_integration.import_entity_type THEN 'legal_entities'
    WHEN 'location'::puls_integration.import_entity_type THEN 'locations'
    WHEN 'cost_center'::puls_integration.import_entity_type THEN 'cost_centers'
    ELSE NULL
  END;
$$;

-- ---------------------------------------------------------------------------
-- Internal: natural key lookup (fail closed on ambiguity)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_integration._import_lookup_by_code(
  p_tenant_id UUID,
  p_entity_type puls_integration.import_entity_type,
  p_code TEXT
)
RETURNS TABLE (canonical_id UUID, error_code TEXT)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_count INTEGER;
  v_id UUID;
BEGIN
  IF p_code IS NULL OR btrim(p_code) = '' THEN
    canonical_id := NULL;
    error_code := NULL;
    RETURN NEXT;
    RETURN;
  END IF;

  CASE p_entity_type
    WHEN 'legal_entity'::puls_integration.import_entity_type THEN
      SELECT COUNT(*), MIN(le.id)
      INTO v_count, v_id
      FROM puls_core.legal_entities le
      WHERE le.tenant_id = p_tenant_id AND le.code = p_code AND le.is_active = TRUE;
    WHEN 'location'::puls_integration.import_entity_type THEN
      SELECT COUNT(*), MIN(loc.id)
      INTO v_count, v_id
      FROM puls_core.locations loc
      WHERE loc.tenant_id = p_tenant_id AND loc.code = p_code AND loc.is_active = TRUE;
    WHEN 'cost_center'::puls_integration.import_entity_type THEN
      SELECT COUNT(*), MIN(cc.id)
      INTO v_count, v_id
      FROM puls_core.cost_centers cc
      WHERE cc.tenant_id = p_tenant_id AND cc.code = p_code AND cc.is_active = TRUE;
    WHEN 'department'::puls_integration.import_entity_type THEN
      SELECT COUNT(*), MIN(d.id)
      INTO v_count, v_id
      FROM puls_core.departments d
      WHERE d.tenant_id = p_tenant_id AND d.code = p_code AND d.is_active = TRUE;
    WHEN 'position'::puls_integration.import_entity_type THEN
      SELECT COUNT(*), MIN(p.id)
      INTO v_count, v_id
      FROM puls_core.positions p
      WHERE p.tenant_id = p_tenant_id AND p.code = p_code AND p.is_active = TRUE;
    ELSE
      canonical_id := NULL;
      error_code := 'UNSUPPORTED_ENTITY_TYPE';
      RETURN NEXT;
      RETURN;
  END CASE;

  IF v_count > 1 THEN
    canonical_id := NULL;
    error_code := 'AMBIGUOUS_REFERENCE';
  ELSIF v_count = 1 THEN
    canonical_id := v_id;
    error_code := NULL;
  ELSE
    canonical_id := NULL;
    error_code := NULL;
  END IF;
  RETURN NEXT;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration._import_lookup_employee(
  p_tenant_id UUID,
  p_employee_code TEXT,
  p_email TEXT
)
RETURNS TABLE (canonical_id UUID, error_code TEXT)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
DECLARE
  v_count INTEGER;
  v_id UUID;
BEGIN
  IF p_employee_code IS NOT NULL AND btrim(p_employee_code) <> '' THEN
    SELECT COUNT(*), MIN(e.id)
    INTO v_count, v_id
    FROM puls_core.employees e
    WHERE e.tenant_id = p_tenant_id
      AND e.employee_code = p_employee_code
      AND e.employment_status = 'active'::puls_core.employment_status;

    IF v_count > 1 THEN
      canonical_id := NULL;
      error_code := 'AMBIGUOUS_REFERENCE';
      RETURN NEXT;
      RETURN;
    ELSIF v_count = 1 THEN
      canonical_id := v_id;
      error_code := NULL;
      RETURN NEXT;
      RETURN;
    END IF;
  END IF;

  IF p_email IS NOT NULL AND btrim(p_email) <> '' THEN
    SELECT COUNT(*), MIN(e.id)
    INTO v_count, v_id
    FROM puls_core.employees e
    WHERE e.tenant_id = p_tenant_id
      AND lower(e.email) = lower(p_email)
      AND e.employment_status = 'active'::puls_core.employment_status;

    IF v_count > 1 THEN
      canonical_id := NULL;
      error_code := 'AMBIGUOUS_REFERENCE';
    ELSIF v_count = 1 THEN
      canonical_id := v_id;
      error_code := NULL;
    ELSE
      canonical_id := NULL;
      error_code := NULL;
    END IF;
    RETURN NEXT;
    RETURN;
  END IF;

  canonical_id := NULL;
  error_code := NULL;
  RETURN NEXT;
END;
$$;

-- ---------------------------------------------------------------------------
-- Internal: owner priority rank for canonical target (identity map + dimension fallback)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_integration._import_owner_priority_rank(
  p_tenant_id UUID,
  p_entity_type puls_integration.import_entity_type,
  p_canonical_id UUID
)
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_rank INTEGER;
BEGIN
  SELECT sn.priority_rank
  INTO v_rank
  FROM puls_integration.entity_identity_map eim
  JOIN puls_integration.source_namespaces sn ON sn.id = eim.source_namespace_id
  WHERE eim.tenant_id = p_tenant_id
    AND eim.entity_type = p_entity_type
    AND eim.canonical_id = p_canonical_id
    AND eim.is_active = TRUE
  ORDER BY sn.priority_rank ASC, eim.updated_at DESC, eim.id ASC
  LIMIT 1;

  IF v_rank IS NOT NULL THEN
    RETURN v_rank;
  END IF;

  CASE p_entity_type
    WHEN 'legal_entity'::puls_integration.import_entity_type THEN
      SELECT sn.priority_rank INTO v_rank
      FROM puls_core.legal_entities le
      JOIN puls_integration.source_namespaces sn ON sn.id = le.source_namespace_id
      WHERE le.id = p_canonical_id AND le.tenant_id = p_tenant_id;
    WHEN 'location'::puls_integration.import_entity_type THEN
      SELECT sn.priority_rank INTO v_rank
      FROM puls_core.locations loc
      JOIN puls_integration.source_namespaces sn ON sn.id = loc.source_namespace_id
      WHERE loc.id = p_canonical_id AND loc.tenant_id = p_tenant_id;
    WHEN 'cost_center'::puls_integration.import_entity_type THEN
      SELECT sn.priority_rank INTO v_rank
      FROM puls_core.cost_centers cc
      JOIN puls_integration.source_namespaces sn ON sn.id = cc.source_namespace_id
      WHERE cc.id = p_canonical_id AND cc.tenant_id = p_tenant_id;
    WHEN 'department'::puls_integration.import_entity_type THEN
      SELECT sn.priority_rank INTO v_rank
      FROM puls_core.departments d
      JOIN puls_integration.source_namespaces sn
        ON sn.tenant_id = d.tenant_id AND sn.code = d.external_source
      WHERE d.id = p_canonical_id AND d.tenant_id = p_tenant_id;
    WHEN 'position'::puls_integration.import_entity_type THEN
      SELECT sn.priority_rank INTO v_rank
      FROM puls_core.positions p
      JOIN puls_integration.source_namespaces sn
        ON sn.tenant_id = p.tenant_id AND sn.code = p.external_source
      WHERE p.id = p_canonical_id AND p.tenant_id = p_tenant_id;
    WHEN 'employee'::puls_integration.import_entity_type THEN
      SELECT sn.priority_rank INTO v_rank
      FROM puls_core.employees e
      JOIN puls_integration.source_namespaces sn
        ON sn.tenant_id = e.tenant_id AND sn.code = e.external_source
      WHERE e.id = p_canonical_id AND e.tenant_id = p_tenant_id;
    ELSE
      NULL;
  END CASE;

  RETURN v_rank;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration._import_should_skip_priority(
  p_tenant_id UUID,
  p_incoming_namespace_id UUID,
  p_incoming_rank INTEGER,
  p_entity_type puls_integration.import_entity_type,
  p_canonical_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_owner_rank INTEGER;
BEGIN
  IF p_canonical_id IS NULL THEN
    RETURN FALSE;
  END IF;

  v_owner_rank := puls_integration._import_owner_priority_rank(
    p_tenant_id, p_entity_type, p_canonical_id
  );

  IF v_owner_rank IS NULL THEN
    RETURN FALSE;
  END IF;

  IF p_incoming_rank > v_owner_rank THEN
    RETURN TRUE;
  END IF;

  RETURN FALSE;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration._import_should_skip_unchanged_hash(
  p_tenant_id UUID,
  p_namespace_id UUID,
  p_entity_type puls_integration.import_entity_type,
  p_external_id TEXT,
  p_canonical_id UUID,
  p_row_hash TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM puls_integration.entity_identity_map eim
    WHERE eim.tenant_id = p_tenant_id
      AND eim.source_namespace_id = p_namespace_id
      AND eim.entity_type = p_entity_type
      AND eim.external_id = p_external_id
      AND eim.canonical_id = p_canonical_id
      AND eim.is_active = TRUE
      AND eim.source_hash IS NOT DISTINCT FROM p_row_hash
  );
$$;

-- ---------------------------------------------------------------------------
-- Internal: identity map upsert (apply path)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_integration._import_upsert_identity_map(
  p_tenant_id UUID,
  p_namespace_id UUID,
  p_entity_type puls_integration.import_entity_type,
  p_external_id TEXT,
  p_canonical_id UUID,
  p_row_hash TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_table TEXT := puls_integration._import_canonical_table(p_entity_type);
BEGIN
  INSERT INTO puls_integration.entity_identity_map (
    tenant_id,
    source_namespace_id,
    entity_type,
    external_id,
    canonical_schema,
    canonical_table,
    canonical_id,
    source_hash,
    last_seen_at,
    is_active
  )
  VALUES (
    p_tenant_id,
    p_namespace_id,
    p_entity_type,
    p_external_id,
    'puls_core',
    v_table,
    p_canonical_id,
    p_row_hash,
    NOW(),
    TRUE
  )
  ON CONFLICT (tenant_id, source_namespace_id, entity_type, external_id)
  DO UPDATE SET
    canonical_id = EXCLUDED.canonical_id,
    canonical_table = EXCLUDED.canonical_table,
    source_hash = EXCLUDED.source_hash,
    last_seen_at = NOW(),
    is_active = TRUE,
    updated_at = NOW();
END;
$$;

-- ---------------------------------------------------------------------------
-- Internal: assert all records validated before apply
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_integration._import_assert_batch_records_validated(p_batch_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration
AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM puls_integration.import_records ir
    WHERE ir.batch_id = p_batch_id
      AND ir.status <> 'validated'::puls_integration.import_record_status
  ) THEN
    RAISE EXCEPTION 'PULS_IMPORT_BATCH_STATE_INVALID: all records must be validated before apply.';
  END IF;
END;
$$;

-- ---------------------------------------------------------------------------
-- Internal: validate required fields per entity
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_integration._import_validate_required_fields(
  p_entity_type puls_integration.import_entity_type,
  p_normalized JSONB
)
RETURNS TEXT[]
LANGUAGE plpgsql
IMMUTABLE
SET search_path = pg_catalog
AS $$
DECLARE
  v_errors TEXT[] := ARRAY[]::TEXT[];
BEGIN
  CASE p_entity_type
    WHEN 'legal_entity'::puls_integration.import_entity_type THEN
      IF COALESCE(p_normalized ->> 'code', '') = '' THEN
        v_errors := array_append(v_errors, 'MISSING_CODE');
      END IF;
      IF COALESCE(p_normalized ->> 'name', '') = '' THEN
        v_errors := array_append(v_errors, 'MISSING_NAME');
      END IF;
    WHEN 'location'::puls_integration.import_entity_type THEN
      IF COALESCE(p_normalized ->> 'code', '') = '' THEN v_errors := array_append(v_errors, 'MISSING_CODE'); END IF;
      IF COALESCE(p_normalized ->> 'name', '') = '' THEN v_errors := array_append(v_errors, 'MISSING_NAME'); END IF;
      IF COALESCE(p_normalized ->> 'legal_entity_code', p_normalized ->> 'legal_entity_external_id', '') = '' THEN
        v_errors := array_append(v_errors, 'MISSING_LEGAL_ENTITY_REF');
      END IF;
    WHEN 'cost_center'::puls_integration.import_entity_type THEN
      IF COALESCE(p_normalized ->> 'code', '') = '' THEN v_errors := array_append(v_errors, 'MISSING_CODE'); END IF;
      IF COALESCE(p_normalized ->> 'name', '') = '' THEN v_errors := array_append(v_errors, 'MISSING_NAME'); END IF;
      IF COALESCE(p_normalized ->> 'legal_entity_code', p_normalized ->> 'legal_entity_external_id', '') = '' THEN
        v_errors := array_append(v_errors, 'MISSING_LEGAL_ENTITY_REF');
      END IF;
    WHEN 'department'::puls_integration.import_entity_type THEN
      IF COALESCE(p_normalized ->> 'code', '') = '' THEN v_errors := array_append(v_errors, 'MISSING_CODE'); END IF;
      IF COALESCE(p_normalized ->> 'name', '') = '' THEN v_errors := array_append(v_errors, 'MISSING_NAME'); END IF;
    WHEN 'position'::puls_integration.import_entity_type THEN
      IF COALESCE(p_normalized ->> 'code', '') = '' THEN v_errors := array_append(v_errors, 'MISSING_CODE'); END IF;
      IF COALESCE(p_normalized ->> 'name', '') = '' THEN v_errors := array_append(v_errors, 'MISSING_NAME'); END IF;
    WHEN 'employee'::puls_integration.import_entity_type THEN
      IF COALESCE(p_normalized ->> 'full_name', '') = '' THEN
        v_errors := array_append(v_errors, 'MISSING_FULL_NAME');
      END IF;
    ELSE
      v_errors := array_append(v_errors, 'UNSUPPORTED_ENTITY_TYPE');
  END CASE;

  RETURN v_errors;
END;
$$;

-- ---------------------------------------------------------------------------
-- Internal: identity map lookup by external_id
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_integration._import_identity_map_lookup(
  p_tenant_id UUID,
  p_namespace_id UUID,
  p_entity_type puls_integration.import_entity_type,
  p_external_id TEXT
)
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration
AS $$
  SELECT eim.canonical_id
  FROM puls_integration.entity_identity_map eim
  WHERE eim.tenant_id = p_tenant_id
    AND eim.source_namespace_id = p_namespace_id
    AND eim.entity_type = p_entity_type
    AND eim.external_id = p_external_id
    AND eim.is_active = TRUE
  LIMIT 1;
$$;

-- ---------------------------------------------------------------------------
-- Internal: same-batch reference lookup (entire batch; ambiguity-aware)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_integration._import_same_batch_lookup(
  p_batch_id UUID,
  p_entity_type puls_integration.import_entity_type,
  p_ref_external_id TEXT,
  p_ref_code TEXT,
  p_exclude_row_number INTEGER DEFAULT NULL
)
RETURNS TABLE (canonical_id UUID, same_batch_pending BOOLEAN, error_code TEXT)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration
AS $$
DECLARE
  v_ext TEXT := NULLIF(btrim(COALESCE(p_ref_external_id, '')), '');
  v_code TEXT := NULLIF(btrim(COALESCE(p_ref_code, '')), '');
  v_count INTEGER;
  v_rec puls_integration.import_records;
BEGIN
  IF v_ext IS NULL AND v_code IS NULL THEN
    canonical_id := NULL;
    same_batch_pending := FALSE;
    error_code := NULL;
    RETURN NEXT;
    RETURN;
  END IF;

  SELECT COUNT(*)
  INTO v_count
  FROM puls_integration.import_records ir
  WHERE ir.batch_id = p_batch_id
    AND ir.entity_type = p_entity_type
    AND (p_exclude_row_number IS NULL OR ir.row_number <> p_exclude_row_number)
    AND (
      (v_ext IS NOT NULL AND ir.external_id = v_ext)
      OR (
        v_code IS NOT NULL
        AND (
          COALESCE(ir.normalized_payload, ir.sanitized_payload) ->> 'code' = v_code
          OR (
            p_entity_type = 'employee'::puls_integration.import_entity_type
            AND COALESCE(ir.normalized_payload, ir.sanitized_payload) ->> 'employee_code' = v_code
          )
        )
      )
    );

  IF v_count > 1 THEN
    canonical_id := NULL;
    same_batch_pending := FALSE;
    error_code := 'AMBIGUOUS_REFERENCE';
    RETURN NEXT;
    RETURN;
  END IF;

  IF v_count = 0 THEN
    canonical_id := NULL;
    same_batch_pending := FALSE;
    error_code := NULL;
    RETURN NEXT;
    RETURN;
  END IF;

  SELECT ir.*
  INTO v_rec
  FROM puls_integration.import_records ir
  WHERE ir.batch_id = p_batch_id
    AND ir.entity_type = p_entity_type
    AND (p_exclude_row_number IS NULL OR ir.row_number <> p_exclude_row_number)
    AND (
      (v_ext IS NOT NULL AND ir.external_id = v_ext)
      OR (
        v_code IS NOT NULL
        AND (
          COALESCE(ir.normalized_payload, ir.sanitized_payload) ->> 'code' = v_code
          OR (
            p_entity_type = 'employee'::puls_integration.import_entity_type
            AND COALESCE(ir.normalized_payload, ir.sanitized_payload) ->> 'employee_code' = v_code
          )
        )
      )
    )
  ORDER BY ir.row_number ASC
  LIMIT 1;

  canonical_id := v_rec.canonical_id;
  same_batch_pending := v_rec.canonical_id IS NULL;
  error_code := NULL;
  RETURN NEXT;
END;
$$;

-- ---------------------------------------------------------------------------
-- Internal: 3-step reference resolution (identity map → same-batch → natural key)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_integration._import_resolve_ref(
  p_tenant_id UUID,
  p_namespace_id UUID,
  p_batch_id UUID,
  p_entity_type puls_integration.import_entity_type,
  p_ref_external_id TEXT,
  p_ref_code TEXT,
  p_exclude_row_number INTEGER DEFAULT NULL
)
RETURNS TABLE (canonical_id UUID, error_code TEXT, same_batch_pending BOOLEAN)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_ext TEXT := NULLIF(btrim(COALESCE(p_ref_external_id, '')), '');
  v_code TEXT := NULLIF(btrim(COALESCE(p_ref_code, '')), '');
  v_map_id UUID;
  v_lookup UUID;
  v_lookup_err TEXT;
  v_batch UUID;
  v_batch_pending BOOLEAN;
  v_batch_err TEXT;
BEGIN
  IF v_ext IS NULL AND v_code IS NULL THEN
    canonical_id := NULL;
    error_code := NULL;
    same_batch_pending := FALSE;
    RETURN NEXT;
    RETURN;
  END IF;

  IF v_ext IS NOT NULL THEN
    v_map_id := puls_integration._import_identity_map_lookup(
      p_tenant_id, p_namespace_id, p_entity_type, v_ext
    );
    IF v_map_id IS NOT NULL THEN
      canonical_id := v_map_id;
      error_code := NULL;
      same_batch_pending := FALSE;
      RETURN NEXT;
      RETURN;
    END IF;
  END IF;

  IF p_batch_id IS NOT NULL THEN
    SELECT sb.canonical_id, sb.same_batch_pending, sb.error_code
    INTO v_batch, v_batch_pending, v_batch_err
    FROM puls_integration._import_same_batch_lookup(
      p_batch_id, p_entity_type, v_ext, v_code, p_exclude_row_number
    ) sb;

    IF v_batch_err IS NOT NULL THEN
      canonical_id := NULL;
      error_code := v_batch_err;
      same_batch_pending := FALSE;
      RETURN NEXT;
      RETURN;
    END IF;

    IF v_batch IS NOT NULL OR COALESCE(v_batch_pending, FALSE) THEN
      canonical_id := v_batch;
      error_code := NULL;
      same_batch_pending := COALESCE(v_batch_pending, FALSE);
      RETURN NEXT;
      RETURN;
    END IF;
  END IF;

  IF p_entity_type = 'employee'::puls_integration.import_entity_type THEN
    SELECT le.canonical_id, le.error_code
    INTO v_lookup, v_lookup_err
    FROM puls_integration._import_lookup_employee(p_tenant_id, v_code, v_ext) le;

    IF v_lookup_err IS NOT NULL THEN
      canonical_id := NULL;
      error_code := v_lookup_err;
      same_batch_pending := FALSE;
      RETURN NEXT;
      RETURN;
    END IF;

    IF v_lookup IS NULL AND v_ext IS NULL AND v_code IS NOT NULL THEN
      SELECT le.canonical_id, le.error_code
      INTO v_lookup, v_lookup_err
      FROM puls_integration._import_lookup_employee(p_tenant_id, NULL, v_code) le;
    END IF;
  ELSE
    SELECT lb.canonical_id, lb.error_code
    INTO v_lookup, v_lookup_err
    FROM puls_integration._import_lookup_by_code(p_tenant_id, p_entity_type, COALESCE(v_code, v_ext)) lb;
  END IF;

  IF v_lookup_err IS NOT NULL THEN
    canonical_id := NULL;
    error_code := v_lookup_err;
    same_batch_pending := FALSE;
    RETURN NEXT;
    RETURN;
  END IF;

  canonical_id := v_lookup;
  error_code := NULL;
  same_batch_pending := FALSE;
  RETURN NEXT;
END;
$$;

-- ---------------------------------------------------------------------------
-- Internal: resolve import record target (identity map → natural key → create)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_integration._import_resolve_entity_target(
  p_tenant_id UUID,
  p_namespace_id UUID,
  p_entity_type puls_integration.import_entity_type,
  p_external_id TEXT,
  p_normalized JSONB
)
RETURNS TABLE (canonical_id UUID, error_code TEXT)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_map_id UUID;
  v_lookup UUID;
  v_err TEXT;
BEGIN
  v_map_id := puls_integration._import_identity_map_lookup(
    p_tenant_id, p_namespace_id, p_entity_type, p_external_id
  );
  IF v_map_id IS NOT NULL THEN
    canonical_id := v_map_id;
    error_code := NULL;
    RETURN NEXT;
    RETURN;
  END IF;

  IF p_entity_type = 'employee'::puls_integration.import_entity_type THEN
    SELECT le.canonical_id, le.error_code
    INTO v_lookup, v_err
    FROM puls_integration._import_lookup_employee(
      p_tenant_id,
      p_normalized ->> 'employee_code',
      p_normalized ->> 'email'
    ) le;
    canonical_id := v_lookup;
    error_code := v_err;
    RETURN NEXT;
    RETURN;
  END IF;

  SELECT lb.canonical_id, lb.error_code
  INTO v_lookup, v_err
  FROM puls_integration._import_lookup_by_code(
    p_tenant_id, p_entity_type, p_normalized ->> 'code'
  ) lb;

  canonical_id := v_lookup;
  error_code := v_err;
  RETURN NEXT;
END;
$$;

-- ---------------------------------------------------------------------------
-- Internal: validate one reference field (fail closed)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_integration._import_check_ref(
  p_tenant_id UUID,
  p_namespace_id UUID,
  p_batch_id UUID,
  p_ref_entity puls_integration.import_entity_type,
  p_ref_external_id TEXT,
  p_ref_code TEXT,
  p_required BOOLEAN DEFAULT FALSE
)
RETURNS TEXT[]
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_r UUID;
  v_e TEXT;
  v_p BOOLEAN;
BEGIN
  IF COALESCE(p_ref_external_id, '') = '' AND COALESCE(p_ref_code, '') = '' THEN
    IF p_required THEN
      RETURN ARRAY['UNRESOLVED_REFERENCE'];
    END IF;
    RETURN ARRAY[]::TEXT[];
  END IF;

  SELECT rr.canonical_id, rr.error_code, rr.same_batch_pending
  INTO v_r, v_e, v_p
  FROM puls_integration._import_resolve_ref(
    p_tenant_id, p_namespace_id, p_batch_id, p_ref_entity,
    p_ref_external_id, p_ref_code, NULL
  ) rr;

  IF v_e IS NOT NULL THEN
    RETURN ARRAY[v_e];
  ELSIF v_r IS NULL AND NOT COALESCE(v_p, FALSE) THEN
    RETURN ARRAY['UNRESOLVED_REFERENCE'];
  END IF;

  RETURN ARRAY[]::TEXT[];
END;
$$;

-- ---------------------------------------------------------------------------
-- Internal: validate entity references (fail closed)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_integration._import_validate_entity_refs(
  p_tenant_id UUID,
  p_namespace_id UUID,
  p_batch_id UUID,
  p_row_number INTEGER,
  p_entity_type puls_integration.import_entity_type,
  p_normalized JSONB
)
RETURNS TEXT[]
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_errors TEXT[] := ARRAY[]::TEXT[];
BEGIN
  CASE p_entity_type
    WHEN 'location'::puls_integration.import_entity_type THEN
      v_errors := v_errors || puls_integration._import_check_ref(
        p_tenant_id, p_namespace_id, p_batch_id,
        'legal_entity'::puls_integration.import_entity_type,
        p_normalized ->> 'legal_entity_external_id',
        p_normalized ->> 'legal_entity_code',
        TRUE
      );
    WHEN 'cost_center'::puls_integration.import_entity_type THEN
      v_errors := v_errors || puls_integration._import_check_ref(
        p_tenant_id, p_namespace_id, p_batch_id,
        'legal_entity'::puls_integration.import_entity_type,
        p_normalized ->> 'legal_entity_external_id',
        p_normalized ->> 'legal_entity_code',
        TRUE
      );
      IF p_normalized ? 'parent_cost_center_code' OR p_normalized ? 'parent_cost_center_external_id' THEN
        v_errors := v_errors || puls_integration._import_check_ref(
          p_tenant_id, p_namespace_id, p_batch_id,
          'cost_center'::puls_integration.import_entity_type,
          p_normalized ->> 'parent_cost_center_external_id',
          p_normalized ->> 'parent_cost_center_code',
          FALSE
        );
      END IF;
    WHEN 'department'::puls_integration.import_entity_type THEN
      IF p_normalized ? 'parent_department_code' OR p_normalized ? 'parent_department_external_id' THEN
        v_errors := v_errors || puls_integration._import_check_ref(
          p_tenant_id, p_namespace_id, p_batch_id,
          'department'::puls_integration.import_entity_type,
          p_normalized ->> 'parent_department_external_id',
          p_normalized ->> 'parent_department_code',
          FALSE
        );
      END IF;
      IF p_normalized ? 'manager_employee_code' OR p_normalized ? 'manager_employee_external_id' OR p_normalized ? 'manager_email' THEN
        v_errors := v_errors || puls_integration._import_check_ref(
          p_tenant_id, p_namespace_id, p_batch_id,
          'employee'::puls_integration.import_entity_type,
          p_normalized ->> 'manager_employee_external_id',
          p_normalized ->> 'manager_employee_code',
          FALSE
        );
        IF (p_normalized ->> 'manager_email') IS NOT NULL AND btrim(p_normalized ->> 'manager_email') <> '' THEN
          v_errors := v_errors || puls_integration._import_check_ref(
            p_tenant_id, p_namespace_id, p_batch_id,
            'employee'::puls_integration.import_entity_type,
            NULL,
            p_normalized ->> 'manager_email',
            FALSE
          );
        END IF;
      END IF;
      IF p_normalized ? 'cost_center_code' OR p_normalized ? 'cost_center_external_id' THEN
        v_errors := v_errors || puls_integration._import_check_ref(
          p_tenant_id, p_namespace_id, p_batch_id,
          'cost_center'::puls_integration.import_entity_type,
          p_normalized ->> 'cost_center_external_id',
          p_normalized ->> 'cost_center_code',
          FALSE
        );
      END IF;
    WHEN 'position'::puls_integration.import_entity_type THEN
      IF p_normalized ? 'department_code' OR p_normalized ? 'department_external_id' THEN
        v_errors := v_errors || puls_integration._import_check_ref(
          p_tenant_id, p_namespace_id, p_batch_id,
          'department'::puls_integration.import_entity_type,
          p_normalized ->> 'department_external_id',
          p_normalized ->> 'department_code',
          FALSE
        );
      END IF;
      IF p_normalized ? 'parent_position_code' OR p_normalized ? 'parent_position_external_id' THEN
        v_errors := v_errors || puls_integration._import_check_ref(
          p_tenant_id, p_namespace_id, p_batch_id,
          'position'::puls_integration.import_entity_type,
          p_normalized ->> 'parent_position_external_id',
          p_normalized ->> 'parent_position_code',
          FALSE
        );
      END IF;
    WHEN 'employee'::puls_integration.import_entity_type THEN
      IF p_normalized ? 'department_code' OR p_normalized ? 'department_external_id' THEN
        v_errors := v_errors || puls_integration._import_check_ref(
          p_tenant_id, p_namespace_id, p_batch_id,
          'department'::puls_integration.import_entity_type,
          p_normalized ->> 'department_external_id',
          p_normalized ->> 'department_code',
          FALSE
        );
      END IF;
      IF p_normalized ? 'position_code' OR p_normalized ? 'position_external_id' THEN
        v_errors := v_errors || puls_integration._import_check_ref(
          p_tenant_id, p_namespace_id, p_batch_id,
          'position'::puls_integration.import_entity_type,
          p_normalized ->> 'position_external_id',
          p_normalized ->> 'position_code',
          FALSE
        );
      END IF;
      IF p_normalized ? 'manager_employee_code' OR p_normalized ? 'manager_employee_external_id' OR p_normalized ? 'manager_email' THEN
        v_errors := v_errors || puls_integration._import_check_ref(
          p_tenant_id, p_namespace_id, p_batch_id,
          'employee'::puls_integration.import_entity_type,
          p_normalized ->> 'manager_employee_external_id',
          p_normalized ->> 'manager_employee_code',
          FALSE
        );
        IF (p_normalized ->> 'manager_email') IS NOT NULL AND btrim(p_normalized ->> 'manager_email') <> '' THEN
          v_errors := v_errors || puls_integration._import_check_ref(
            p_tenant_id, p_namespace_id, p_batch_id,
            'employee'::puls_integration.import_entity_type,
            NULL,
            p_normalized ->> 'manager_email',
            FALSE
          );
        END IF;
      END IF;
      IF p_normalized ? 'legal_entity_code' OR p_normalized ? 'legal_entity_external_id' THEN
        v_errors := v_errors || puls_integration._import_check_ref(
          p_tenant_id, p_namespace_id, p_batch_id,
          'legal_entity'::puls_integration.import_entity_type,
          p_normalized ->> 'legal_entity_external_id',
          p_normalized ->> 'legal_entity_code',
          FALSE
        );
      END IF;
      IF p_normalized ? 'location_code' OR p_normalized ? 'location_external_id' THEN
        v_errors := v_errors || puls_integration._import_check_ref(
          p_tenant_id, p_namespace_id, p_batch_id,
          'location'::puls_integration.import_entity_type,
          p_normalized ->> 'location_external_id',
          p_normalized ->> 'location_code',
          FALSE
        );
      END IF;
      IF p_normalized ? 'cost_center_code' OR p_normalized ? 'cost_center_external_id' THEN
        v_errors := v_errors || puls_integration._import_check_ref(
          p_tenant_id, p_namespace_id, p_batch_id,
          'cost_center'::puls_integration.import_entity_type,
          p_normalized ->> 'cost_center_external_id',
          p_normalized ->> 'cost_center_code',
          FALSE
        );
      END IF;
    ELSE
      NULL;
  END CASE;

  RETURN v_errors;
END;
$$;

-- ---------------------------------------------------------------------------
-- Internal: resolve reference during apply (includes applied batch rows)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_integration._import_resolve_ref_at_apply(
  p_tenant_id UUID,
  p_namespace_id UUID,
  p_batch_id UUID,
  p_entity_type puls_integration.import_entity_type,
  p_ref_external_id TEXT,
  p_ref_code TEXT
)
RETURNS UUID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_ext TEXT := NULLIF(btrim(COALESCE(p_ref_external_id, '')), '');
  v_code TEXT := NULLIF(btrim(COALESCE(p_ref_code, '')), '');
  v_id UUID;
  v_err TEXT;
BEGIN
  IF v_ext IS NULL AND v_code IS NULL THEN
    RETURN NULL;
  END IF;

  IF v_ext IS NOT NULL THEN
    v_id := puls_integration._import_identity_map_lookup(
      p_tenant_id, p_namespace_id, p_entity_type, v_ext
    );
    IF v_id IS NOT NULL THEN
      RETURN v_id;
    END IF;
  END IF;

  SELECT ir.canonical_id
  INTO v_id
  FROM puls_integration.import_records ir
  WHERE ir.batch_id = p_batch_id
    AND ir.entity_type = p_entity_type
    AND ir.status = 'applied'::puls_integration.import_record_status
    AND ir.canonical_id IS NOT NULL
    AND (
      (v_ext IS NOT NULL AND ir.external_id = v_ext)
      OR (v_code IS NOT NULL AND ir.normalized_payload ->> 'code' = v_code)
      OR (
        p_entity_type = 'employee'::puls_integration.import_entity_type
        AND v_code IS NOT NULL
        AND ir.normalized_payload ->> 'employee_code' = v_code
      )
    )
  ORDER BY ir.row_number DESC
  LIMIT 1;

  IF v_id IS NOT NULL THEN
    RETURN v_id;
  END IF;

  IF p_entity_type = 'employee'::puls_integration.import_entity_type THEN
    SELECT le.canonical_id, le.error_code
    INTO v_id, v_err
    FROM puls_integration._import_lookup_employee(p_tenant_id, v_code, COALESCE(v_ext, v_code)) le;
    RETURN v_id;
  END IF;

  SELECT lb.canonical_id, lb.error_code
  INTO v_id, v_err
  FROM puls_integration._import_lookup_by_code(p_tenant_id, p_entity_type, COALESCE(v_code, v_ext)) lb;

  RETURN v_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- Internal: classify record for preview (create / update / skip)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_integration._import_classify_record(
  p_tenant_id UUID,
  p_namespace_id UUID,
  p_incoming_rank INTEGER,
  p_entity_type puls_integration.import_entity_type,
  p_external_id TEXT,
  p_normalized JSONB,
  p_row_hash TEXT
)
RETURNS TABLE (action TEXT, skip_code TEXT, canonical_id UUID)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_target UUID;
  v_err TEXT;
BEGIN
  SELECT t.canonical_id, t.error_code
  INTO v_target, v_err
  FROM puls_integration._import_resolve_entity_target(
    p_tenant_id, p_namespace_id, p_entity_type, p_external_id, p_normalized
  ) t;

  IF v_err IS NOT NULL THEN
    RAISE EXCEPTION 'PULS_IMPORT_CLASSIFY_FAILED: target ambiguity % on import row.', v_err;
  END IF;

  IF v_target IS NULL THEN
    action := 'create';
    skip_code := NULL;
    canonical_id := NULL;
    RETURN NEXT;
    RETURN;
  END IF;

  IF puls_integration._import_should_skip_priority(
    p_tenant_id, p_namespace_id, p_incoming_rank, p_entity_type, v_target
  ) THEN
    action := 'skip';
    skip_code := 'LOWER_PRIORITY_SOURCE_SKIPPED';
    canonical_id := v_target;
    RETURN NEXT;
    RETURN;
  END IF;

  IF puls_integration._import_should_skip_unchanged_hash(
    p_tenant_id, p_namespace_id, p_entity_type, p_external_id, v_target, p_row_hash
  ) THEN
    action := 'skip';
    skip_code := 'UNCHANGED_ROW_HASH';
    canonical_id := v_target;
    RETURN NEXT;
    RETURN;
  END IF;

  action := 'update';
  skip_code := NULL;
  canonical_id := v_target;
  RETURN NEXT;
END;
$$;

-- ---------------------------------------------------------------------------
-- Internal: mark import record skipped
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_integration._import_mark_skipped(
  p_record_id UUID,
  p_skip_code TEXT,
  p_canonical_id UUID DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration
AS $$
BEGIN
  UPDATE puls_integration.import_records ir
  SET
    status = 'skipped'::puls_integration.import_record_status,
    error_codes = ARRAY[p_skip_code],
    canonical_id = COALESCE(p_canonical_id, ir.canonical_id),
    updated_at = NOW()
  WHERE ir.id = p_record_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- Internal: mark import record applied
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_integration._import_mark_applied(
  p_record_id UUID,
  p_canonical_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration
AS $$
BEGIN
  UPDATE puls_integration.import_records ir
  SET
    status = 'applied'::puls_integration.import_record_status,
    canonical_id = p_canonical_id,
    error_codes = '{}',
    updated_at = NOW()
  WHERE ir.id = p_record_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- RPC: validate_import_batch
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_integration.validate_import_batch(p_batch_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core, puls_workflow
AS $$
DECLARE
  v_batch puls_integration.import_batches;
  v_rec RECORD;
  v_norm JSONB;
  v_warnings TEXT[];
  v_errors TEXT[];
  v_ref_errors TEXT[];
  v_req_errors TEXT[];
  v_all_errors TEXT[];
  v_error_count INTEGER := 0;
  v_target UUID;
  v_target_err TEXT;
BEGIN
  v_batch := puls_integration._import_lock_batch(p_batch_id);

  IF v_batch.status IN (
    'applied'::puls_integration.import_batch_status,
    'cancelled'::puls_integration.import_batch_status
  ) THEN
    RAISE EXCEPTION 'PULS_IMPORT_BATCH_STATE_INVALID: batch status % cannot be validated.', v_batch.status;
  END IF;

  FOR v_rec IN
    SELECT ir.*
    FROM puls_integration.import_records ir
    WHERE ir.batch_id = p_batch_id
    ORDER BY ir.row_number
  LOOP
    SELECT n.normalized_payload, n.warning_codes, n.error_codes
    INTO v_norm, v_warnings, v_errors
    FROM puls_integration._import_normalize_payload(v_rec.entity_type, v_rec.sanitized_payload) n;

    v_req_errors := puls_integration._import_validate_required_fields(v_rec.entity_type, v_norm);
    v_ref_errors := puls_integration._import_validate_entity_refs(
      v_batch.tenant_id,
      v_batch.source_namespace_id,
      p_batch_id,
      v_rec.row_number,
      v_rec.entity_type,
      v_norm
    );

    SELECT t.canonical_id, t.error_code
    INTO v_target, v_target_err
    FROM puls_integration._import_resolve_entity_target(
      v_batch.tenant_id,
      v_batch.source_namespace_id,
      v_rec.entity_type,
      v_rec.external_id,
      v_norm
    ) t;

    v_all_errors := COALESCE(v_errors, '{}') || COALESCE(v_req_errors, '{}') || COALESCE(v_ref_errors, '{}');
    IF v_target_err IS NOT NULL THEN
      v_all_errors := v_all_errors || ARRAY[v_target_err];
    END IF;

    IF array_length(v_all_errors, 1) IS NOT NULL AND array_length(v_all_errors, 1) > 0 THEN
      UPDATE puls_integration.import_records ir
      SET
        normalized_payload = v_norm,
        status = 'error'::puls_integration.import_record_status,
        error_codes = v_all_errors,
        warning_codes = COALESCE(v_warnings, '{}'),
        canonical_id = NULL,
        updated_at = NOW()
      WHERE ir.id = v_rec.id;
      v_error_count := v_error_count + 1;
    ELSE
      UPDATE puls_integration.import_records ir
      SET
        normalized_payload = v_norm,
        status = 'validated'::puls_integration.import_record_status,
        error_codes = '{}',
        warning_codes = COALESCE(v_warnings, '{}'),
        canonical_id = v_target,
        updated_at = NOW()
      WHERE ir.id = v_rec.id;
    END IF;
  END LOOP;

  UPDATE puls_integration.import_batches ib
  SET
    status = 'validated'::puls_integration.import_batch_status,
    error_count = v_error_count,
    validated_at = NOW(),
    updated_at = NOW()
  WHERE ib.id = p_batch_id;

  RETURN jsonb_build_object(
    'batch_id', p_batch_id,
    'status', 'validated',
    'row_count', v_batch.row_count,
    'error_count', v_error_count,
    'validated_at', NOW()
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- RPC: preview_import_diff
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_integration.preview_import_diff(p_batch_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core, puls_workflow
AS $$
DECLARE
  v_batch puls_integration.import_batches;
  v_namespace puls_integration.source_namespaces;
  v_rec RECORD;
  v_class RECORD;
  v_create_count INTEGER := 0;
  v_update_count INTEGER := 0;
  v_skip_count INTEGER := 0;
  v_diff JSONB := '[]'::jsonb;
BEGIN
  v_batch := puls_integration._import_lock_batch(p_batch_id);

  IF v_batch.status NOT IN (
    'validated'::puls_integration.import_batch_status,
    'previewed'::puls_integration.import_batch_status
  ) THEN
    RAISE EXCEPTION 'PULS_IMPORT_BATCH_STATE_INVALID: batch must be validated before preview.';
  END IF;

  IF v_batch.error_count > 0 THEN
    RAISE EXCEPTION 'PULS_IMPORT_BATCH_STATE_INVALID: batch has row errors.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM puls_integration.import_records ir
    WHERE ir.batch_id = p_batch_id
      AND ir.status <> 'validated'::puls_integration.import_record_status
  ) THEN
    RAISE EXCEPTION 'PULS_IMPORT_BATCH_STATE_INVALID: all records must be validated before preview.';
  END IF;

  SELECT sn.* INTO v_namespace
  FROM puls_integration.source_namespaces sn
  WHERE sn.id = v_batch.source_namespace_id;

  FOR v_rec IN
    SELECT ir.*
    FROM puls_integration.import_records ir
    WHERE ir.batch_id = p_batch_id
    ORDER BY ir.row_number
  LOOP
    SELECT c.action, c.skip_code, c.canonical_id
    INTO v_class
    FROM puls_integration._import_classify_record(
      v_batch.tenant_id,
      v_batch.source_namespace_id,
      v_namespace.priority_rank,
      v_rec.entity_type,
      v_rec.external_id,
      v_rec.normalized_payload,
      v_rec.row_hash
    ) c;

    IF v_class.action = 'create' THEN
      v_create_count := v_create_count + 1;
    ELSIF v_class.action = 'update' THEN
      v_update_count := v_update_count + 1;
    ELSE
      v_skip_count := v_skip_count + 1;
    END IF;

    v_diff := v_diff || jsonb_build_array(jsonb_build_object(
      'row_number', v_rec.row_number,
      'entity_type', v_rec.entity_type,
      'external_id', v_rec.external_id,
      'action', v_class.action,
      'skip_code', v_class.skip_code,
      'canonical_id', v_class.canonical_id
    ));
  END LOOP;

  UPDATE puls_integration.import_batches ib
  SET
    status = 'previewed'::puls_integration.import_batch_status,
    previewed_at = NOW(),
    create_count = v_create_count,
    update_count = v_update_count,
    skip_count = v_skip_count,
    updated_at = NOW()
  WHERE ib.id = p_batch_id;

  RETURN jsonb_build_object(
    'batch_id', p_batch_id,
    'status', 'previewed',
    'create_count', v_create_count,
    'update_count', v_update_count,
    'skip_count', v_skip_count,
    'records', v_diff
  );
END;
$$;
-- ---------------------------------------------------------------------------
-- RPC: apply_import_batch (atomic; no per-row exception swallowing)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_integration.apply_import_batch(
  p_batch_id UUID,
  p_expected_source_checksum TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core, puls_workflow
AS $$
DECLARE
  v_batch puls_integration.import_batches;
  v_namespace puls_integration.source_namespaces;
  v_rec RECORD;
  v_payload JSONB;
  v_target UUID;
  v_target_err TEXT;
  v_canonical_id UUID;
  v_is_active BOOLEAN;
  v_le_id UUID;
  v_cc_id UUID;
  v_dept_id UUID;
  v_pos_id UUID;
  v_mgr_id UUID;
  v_create_count INTEGER := 0;
  v_update_count INTEGER := 0;
  v_skip_count INTEGER := 0;
  v_reporting_source TEXT;
  v_pass INTEGER;
  v_parent_id UUID;
  v_emp_status puls_core.employment_status;
BEGIN
  v_batch := puls_integration._import_lock_batch(p_batch_id);

  IF v_batch.mode = 'dry_run'::puls_integration.import_batch_mode THEN
    RAISE EXCEPTION 'PULS_IMPORT_DRY_RUN: apply requires mode = apply.';
  END IF;

  IF v_batch.status <> 'previewed'::puls_integration.import_batch_status THEN
    RAISE EXCEPTION 'PULS_IMPORT_BATCH_STATE_INVALID: batch must be previewed before apply.';
  END IF;

  IF v_batch.error_count > 0 THEN
    RAISE EXCEPTION 'PULS_IMPORT_BATCH_STATE_INVALID: batch has row errors.';
  END IF;

  IF p_expected_source_checksum IS NOT NULL
     AND v_batch.source_checksum IS DISTINCT FROM p_expected_source_checksum THEN
    RAISE EXCEPTION 'PULS_IMPORT_CHECKSUM_MISMATCH: source checksum does not match.';
  END IF;

  PERFORM puls_integration._import_assert_batch_records_validated(p_batch_id);

  SELECT sn.* INTO v_namespace
  FROM puls_integration.source_namespaces sn
  WHERE sn.id = v_batch.source_namespace_id;

  v_reporting_source := puls_integration._import_map_reporting_source(v_namespace.source_type);
  IF v_reporting_source IS NULL THEN
    RAISE EXCEPTION 'PULS_IMPORT_SOURCE_TYPE_INVALID: unsupported source_type for reporting lines.';
  END IF;

  -- 1) legal_entities
  FOR v_rec IN
    SELECT ir.* FROM puls_integration.import_records ir
    WHERE ir.batch_id = p_batch_id
      AND ir.entity_type = 'legal_entity'::puls_integration.import_entity_type
      AND ir.status = 'validated'::puls_integration.import_record_status
    ORDER BY ir.row_number
  LOOP
    v_payload := v_rec.normalized_payload;
    SELECT t.canonical_id, t.error_code
    INTO v_target, v_target_err
    FROM puls_integration._import_resolve_entity_target(
      v_batch.tenant_id, v_batch.source_namespace_id, v_rec.entity_type, v_rec.external_id, v_payload
    ) t;

    IF v_target_err IS NOT NULL THEN
      RAISE EXCEPTION 'PULS_IMPORT_APPLY_FAILED: ambiguous target on row % (%)', v_rec.row_number, v_target_err;
    END IF;

    IF v_target IS NOT NULL THEN
      IF puls_integration._import_should_skip_priority(
        v_batch.tenant_id, v_batch.source_namespace_id, v_namespace.priority_rank, v_rec.entity_type, v_target
      ) THEN
        PERFORM puls_integration._import_mark_skipped(v_rec.id, 'LOWER_PRIORITY_SOURCE_SKIPPED', v_target);
        v_skip_count := v_skip_count + 1;
        CONTINUE;
      END IF;
      IF puls_integration._import_should_skip_unchanged_hash(
        v_batch.tenant_id, v_batch.source_namespace_id, v_rec.entity_type,
        v_rec.external_id, v_target, v_rec.row_hash
      ) THEN
        PERFORM puls_integration._import_mark_skipped(v_rec.id, 'UNCHANGED_ROW_HASH', v_target);
        v_skip_count := v_skip_count + 1;
        CONTINUE;
      END IF;
    END IF;

    v_is_active := COALESCE(NULLIF(v_payload ->> 'is_active', '')::boolean, TRUE);

    IF v_target IS NULL THEN
      INSERT INTO puls_core.legal_entities (
        tenant_id, code, name, is_active, source_namespace_id, external_id
      ) VALUES (
        v_batch.tenant_id,
        v_payload ->> 'code',
        v_payload ->> 'name',
        v_is_active,
        v_batch.source_namespace_id,
        v_rec.external_id
      )
      RETURNING id INTO v_canonical_id;
      v_create_count := v_create_count + 1;
    ELSE
      UPDATE puls_core.legal_entities le
      SET
        name = COALESCE(v_payload ->> 'name', le.name),
        is_active = v_is_active,
        source_namespace_id = v_batch.source_namespace_id,
        external_id = v_rec.external_id,
        updated_at = NOW()
      WHERE le.id = v_target AND le.tenant_id = v_batch.tenant_id;
      v_canonical_id := v_target;
      v_update_count := v_update_count + 1;
    END IF;

    PERFORM puls_integration._import_upsert_identity_map(
      v_batch.tenant_id, v_batch.source_namespace_id, v_rec.entity_type,
      v_rec.external_id, v_canonical_id, v_rec.row_hash
    );
    PERFORM puls_integration._import_mark_applied(v_rec.id, v_canonical_id);
  END LOOP;

  -- 2) locations
  FOR v_rec IN
    SELECT ir.* FROM puls_integration.import_records ir
    WHERE ir.batch_id = p_batch_id
      AND ir.entity_type = 'location'::puls_integration.import_entity_type
      AND ir.status = 'validated'::puls_integration.import_record_status
    ORDER BY ir.row_number
  LOOP
    v_payload := v_rec.normalized_payload;
    SELECT t.canonical_id, t.error_code
    INTO v_target, v_target_err
    FROM puls_integration._import_resolve_entity_target(
      v_batch.tenant_id, v_batch.source_namespace_id, v_rec.entity_type, v_rec.external_id, v_payload
    ) t;

    IF v_target_err IS NOT NULL THEN
      RAISE EXCEPTION 'PULS_IMPORT_APPLY_FAILED: ambiguous target on row % (%)', v_rec.row_number, v_target_err;
    END IF;

    IF v_target IS NOT NULL THEN
      IF puls_integration._import_should_skip_priority(
        v_batch.tenant_id, v_batch.source_namespace_id, v_namespace.priority_rank, v_rec.entity_type, v_target
      ) THEN
        PERFORM puls_integration._import_mark_skipped(v_rec.id, 'LOWER_PRIORITY_SOURCE_SKIPPED', v_target);
        v_skip_count := v_skip_count + 1;
        CONTINUE;
      END IF;
      IF puls_integration._import_should_skip_unchanged_hash(
        v_batch.tenant_id, v_batch.source_namespace_id, v_rec.entity_type,
        v_rec.external_id, v_target, v_rec.row_hash
      ) THEN
        PERFORM puls_integration._import_mark_skipped(v_rec.id, 'UNCHANGED_ROW_HASH', v_target);
        v_skip_count := v_skip_count + 1;
        CONTINUE;
      END IF;
    END IF;

    v_le_id := puls_integration._import_resolve_ref_at_apply(
      v_batch.tenant_id, v_batch.source_namespace_id, p_batch_id,
      'legal_entity'::puls_integration.import_entity_type,
      v_payload ->> 'legal_entity_external_id',
      v_payload ->> 'legal_entity_code'
    );
    IF v_le_id IS NULL THEN
      RAISE EXCEPTION 'PULS_IMPORT_APPLY_FAILED: unresolved legal_entity for location row %.', v_rec.row_number;
    END IF;

    v_is_active := COALESCE(NULLIF(v_payload ->> 'is_active', '')::boolean, TRUE);

    IF v_target IS NULL THEN
      INSERT INTO puls_core.locations (
        tenant_id, legal_entity_id, code, name, is_active, source_namespace_id, external_id
      ) VALUES (
        v_batch.tenant_id, v_le_id, v_payload ->> 'code', v_payload ->> 'name',
        v_is_active, v_batch.source_namespace_id, v_rec.external_id
      )
      RETURNING id INTO v_canonical_id;
      v_create_count := v_create_count + 1;
    ELSE
      UPDATE puls_core.locations loc
      SET
        legal_entity_id = v_le_id,
        name = COALESCE(v_payload ->> 'name', loc.name),
        is_active = v_is_active,
        source_namespace_id = v_batch.source_namespace_id,
        external_id = v_rec.external_id,
        updated_at = NOW()
      WHERE loc.id = v_target AND loc.tenant_id = v_batch.tenant_id;
      v_canonical_id := v_target;
      v_update_count := v_update_count + 1;
    END IF;

    PERFORM puls_integration._import_upsert_identity_map(
      v_batch.tenant_id, v_batch.source_namespace_id, v_rec.entity_type,
      v_rec.external_id, v_canonical_id, v_rec.row_hash
    );
    PERFORM puls_integration._import_mark_applied(v_rec.id, v_canonical_id);
  END LOOP;

  -- 3) cost_centers (without parent)
  FOR v_rec IN
    SELECT ir.* FROM puls_integration.import_records ir
    WHERE ir.batch_id = p_batch_id
      AND ir.entity_type = 'cost_center'::puls_integration.import_entity_type
      AND ir.status = 'validated'::puls_integration.import_record_status
    ORDER BY ir.row_number
  LOOP
    v_payload := v_rec.normalized_payload;
    SELECT t.canonical_id, t.error_code
    INTO v_target, v_target_err
    FROM puls_integration._import_resolve_entity_target(
      v_batch.tenant_id, v_batch.source_namespace_id, v_rec.entity_type, v_rec.external_id, v_payload
    ) t;

    IF v_target_err IS NOT NULL THEN
      RAISE EXCEPTION 'PULS_IMPORT_APPLY_FAILED: ambiguous target on row % (%)', v_rec.row_number, v_target_err;
    END IF;

    IF v_target IS NOT NULL THEN
      IF puls_integration._import_should_skip_priority(
        v_batch.tenant_id, v_batch.source_namespace_id, v_namespace.priority_rank, v_rec.entity_type, v_target
      ) THEN
        PERFORM puls_integration._import_mark_skipped(v_rec.id, 'LOWER_PRIORITY_SOURCE_SKIPPED', v_target);
        v_skip_count := v_skip_count + 1;
        CONTINUE;
      END IF;
      IF puls_integration._import_should_skip_unchanged_hash(
        v_batch.tenant_id, v_batch.source_namespace_id, v_rec.entity_type,
        v_rec.external_id, v_target, v_rec.row_hash
      ) THEN
        PERFORM puls_integration._import_mark_skipped(v_rec.id, 'UNCHANGED_ROW_HASH', v_target);
        v_skip_count := v_skip_count + 1;
        CONTINUE;
      END IF;
    END IF;

    v_le_id := puls_integration._import_resolve_ref_at_apply(
      v_batch.tenant_id, v_batch.source_namespace_id, p_batch_id,
      'legal_entity'::puls_integration.import_entity_type,
      v_payload ->> 'legal_entity_external_id',
      v_payload ->> 'legal_entity_code'
    );
    IF v_le_id IS NULL THEN
      RAISE EXCEPTION 'PULS_IMPORT_APPLY_FAILED: unresolved legal_entity for cost_center row %.', v_rec.row_number;
    END IF;

    v_is_active := COALESCE(NULLIF(v_payload ->> 'is_active', '')::boolean, TRUE);

    IF v_target IS NULL THEN
      INSERT INTO puls_core.cost_centers (
        tenant_id, legal_entity_id, code, name, is_active, source_namespace_id, external_id
      ) VALUES (
        v_batch.tenant_id, v_le_id, v_payload ->> 'code', v_payload ->> 'name',
        v_is_active, v_batch.source_namespace_id, v_rec.external_id
      )
      RETURNING id INTO v_canonical_id;
      v_create_count := v_create_count + 1;
    ELSE
      UPDATE puls_core.cost_centers cc
      SET
        legal_entity_id = v_le_id,
        name = COALESCE(v_payload ->> 'name', cc.name),
        is_active = v_is_active,
        source_namespace_id = v_batch.source_namespace_id,
        external_id = v_rec.external_id,
        updated_at = NOW()
      WHERE cc.id = v_target AND cc.tenant_id = v_batch.tenant_id;
      v_canonical_id := v_target;
      v_update_count := v_update_count + 1;
    END IF;

    PERFORM puls_integration._import_upsert_identity_map(
      v_batch.tenant_id, v_batch.source_namespace_id, v_rec.entity_type,
      v_rec.external_id, v_canonical_id, v_rec.row_hash
    );
    PERFORM puls_integration._import_mark_applied(v_rec.id, v_canonical_id);
  END LOOP;

  -- 4) cost_center parent pass (depth <= 20)
  FOR v_pass IN 1..20 LOOP
    FOR v_rec IN
      SELECT ir.* FROM puls_integration.import_records ir
      WHERE ir.batch_id = p_batch_id
        AND ir.entity_type = 'cost_center'::puls_integration.import_entity_type
        AND ir.status = 'applied'::puls_integration.import_record_status
        AND (
          ir.normalized_payload ? 'parent_cost_center_code'
          OR ir.normalized_payload ? 'parent_cost_center_external_id'
        )
      ORDER BY ir.row_number
    LOOP
      v_payload := v_rec.normalized_payload;
      v_parent_id := puls_integration._import_resolve_ref_at_apply(
        v_batch.tenant_id, v_batch.source_namespace_id, p_batch_id,
        'cost_center'::puls_integration.import_entity_type,
        v_payload ->> 'parent_cost_center_external_id',
        v_payload ->> 'parent_cost_center_code'
      );
      IF v_parent_id IS NOT NULL AND v_rec.canonical_id IS NOT NULL THEN
        UPDATE puls_core.cost_centers cc
        SET parent_cost_center_id = v_parent_id, updated_at = NOW()
        WHERE cc.id = v_rec.canonical_id AND cc.tenant_id = v_batch.tenant_id;
      END IF;
    END LOOP;
  END LOOP;

  -- 5) departments (without parent/manager)
  FOR v_rec IN
    SELECT ir.* FROM puls_integration.import_records ir
    WHERE ir.batch_id = p_batch_id
      AND ir.entity_type = 'department'::puls_integration.import_entity_type
      AND ir.status = 'validated'::puls_integration.import_record_status
    ORDER BY ir.row_number
  LOOP
    v_payload := v_rec.normalized_payload;
    SELECT t.canonical_id, t.error_code
    INTO v_target, v_target_err
    FROM puls_integration._import_resolve_entity_target(
      v_batch.tenant_id, v_batch.source_namespace_id, v_rec.entity_type, v_rec.external_id, v_payload
    ) t;

    IF v_target_err IS NOT NULL THEN
      RAISE EXCEPTION 'PULS_IMPORT_APPLY_FAILED: ambiguous target on row % (%)', v_rec.row_number, v_target_err;
    END IF;

    IF v_target IS NOT NULL THEN
      IF puls_integration._import_should_skip_priority(
        v_batch.tenant_id, v_batch.source_namespace_id, v_namespace.priority_rank, v_rec.entity_type, v_target
      ) THEN
        PERFORM puls_integration._import_mark_skipped(v_rec.id, 'LOWER_PRIORITY_SOURCE_SKIPPED', v_target);
        v_skip_count := v_skip_count + 1;
        CONTINUE;
      END IF;
      IF puls_integration._import_should_skip_unchanged_hash(
        v_batch.tenant_id, v_batch.source_namespace_id, v_rec.entity_type,
        v_rec.external_id, v_target, v_rec.row_hash
      ) THEN
        PERFORM puls_integration._import_mark_skipped(v_rec.id, 'UNCHANGED_ROW_HASH', v_target);
        v_skip_count := v_skip_count + 1;
        CONTINUE;
      END IF;
    END IF;

    v_cc_id := NULL;
    IF v_payload ? 'cost_center_code' OR v_payload ? 'cost_center_external_id' THEN
      v_cc_id := puls_integration._import_resolve_ref_at_apply(
        v_batch.tenant_id, v_batch.source_namespace_id, p_batch_id,
        'cost_center'::puls_integration.import_entity_type,
        v_payload ->> 'cost_center_external_id',
        v_payload ->> 'cost_center_code'
      );
    END IF;

    v_is_active := COALESCE(NULLIF(v_payload ->> 'is_active', '')::boolean, TRUE);

    IF v_target IS NULL THEN
      INSERT INTO puls_core.departments (
        tenant_id, code, name, is_active, cost_center_id,
        external_department_id, external_source, last_synced_at
      ) VALUES (
        v_batch.tenant_id,
        v_payload ->> 'code',
        v_payload ->> 'name',
        v_is_active,
        v_cc_id,
        v_rec.external_id,
        v_namespace.code,
        NOW()
      )
      RETURNING id INTO v_canonical_id;
      v_create_count := v_create_count + 1;
    ELSE
      UPDATE puls_core.departments d
      SET
        name = COALESCE(v_payload ->> 'name', d.name),
        is_active = v_is_active,
        cost_center_id = COALESCE(v_cc_id, d.cost_center_id),
        external_department_id = v_rec.external_id,
        external_source = v_namespace.code,
        last_synced_at = NOW(),
        updated_at = NOW()
      WHERE d.id = v_target AND d.tenant_id = v_batch.tenant_id;
      v_canonical_id := v_target;
      v_update_count := v_update_count + 1;
    END IF;

    PERFORM puls_integration._import_upsert_identity_map(
      v_batch.tenant_id, v_batch.source_namespace_id, v_rec.entity_type,
      v_rec.external_id, v_canonical_id, v_rec.row_hash
    );
    PERFORM puls_integration._import_mark_applied(v_rec.id, v_canonical_id);
  END LOOP;

  -- 6) positions (without parent)
  FOR v_rec IN
    SELECT ir.* FROM puls_integration.import_records ir
    WHERE ir.batch_id = p_batch_id
      AND ir.entity_type = 'position'::puls_integration.import_entity_type
      AND ir.status = 'validated'::puls_integration.import_record_status
    ORDER BY ir.row_number
  LOOP
    v_payload := v_rec.normalized_payload;
    SELECT t.canonical_id, t.error_code
    INTO v_target, v_target_err
    FROM puls_integration._import_resolve_entity_target(
      v_batch.tenant_id, v_batch.source_namespace_id, v_rec.entity_type, v_rec.external_id, v_payload
    ) t;

    IF v_target_err IS NOT NULL THEN
      RAISE EXCEPTION 'PULS_IMPORT_APPLY_FAILED: ambiguous target on row % (%)', v_rec.row_number, v_target_err;
    END IF;

    IF v_target IS NOT NULL THEN
      IF puls_integration._import_should_skip_priority(
        v_batch.tenant_id, v_batch.source_namespace_id, v_namespace.priority_rank, v_rec.entity_type, v_target
      ) THEN
        PERFORM puls_integration._import_mark_skipped(v_rec.id, 'LOWER_PRIORITY_SOURCE_SKIPPED', v_target);
        v_skip_count := v_skip_count + 1;
        CONTINUE;
      END IF;
      IF puls_integration._import_should_skip_unchanged_hash(
        v_batch.tenant_id, v_batch.source_namespace_id, v_rec.entity_type,
        v_rec.external_id, v_target, v_rec.row_hash
      ) THEN
        PERFORM puls_integration._import_mark_skipped(v_rec.id, 'UNCHANGED_ROW_HASH', v_target);
        v_skip_count := v_skip_count + 1;
        CONTINUE;
      END IF;
    END IF;

    v_dept_id := NULL;
    IF v_payload ? 'department_code' OR v_payload ? 'department_external_id' THEN
      v_dept_id := puls_integration._import_resolve_ref_at_apply(
        v_batch.tenant_id, v_batch.source_namespace_id, p_batch_id,
        'department'::puls_integration.import_entity_type,
        v_payload ->> 'department_external_id',
        v_payload ->> 'department_code'
      );
    END IF;

    v_is_active := COALESCE(NULLIF(v_payload ->> 'is_active', '')::boolean, TRUE);

    IF v_target IS NULL THEN
      INSERT INTO puls_core.positions (
        tenant_id, code, name, is_active, department_id,
        level, norm_headcount, employment_type,
        external_position_id, external_source, last_synced_at
      ) VALUES (
        v_batch.tenant_id,
        v_payload ->> 'code',
        v_payload ->> 'name',
        v_is_active,
        v_dept_id,
        NULLIF(v_payload ->> 'level', '')::integer,
        COALESCE(NULLIF(v_payload ->> 'norm_headcount', '')::integer, 1),
        v_payload ->> 'employment_type',
        v_rec.external_id,
        v_namespace.code,
        NOW()
      )
      RETURNING id INTO v_canonical_id;
      v_create_count := v_create_count + 1;
    ELSE
      UPDATE puls_core.positions p
      SET
        name = COALESCE(v_payload ->> 'name', p.name),
        is_active = v_is_active,
        department_id = COALESCE(v_dept_id, p.department_id),
        level = COALESCE(NULLIF(v_payload ->> 'level', '')::integer, p.level),
        norm_headcount = COALESCE(NULLIF(v_payload ->> 'norm_headcount', '')::integer, p.norm_headcount),
        employment_type = COALESCE(v_payload ->> 'employment_type', p.employment_type),
        external_position_id = v_rec.external_id,
        external_source = v_namespace.code,
        last_synced_at = NOW(),
        updated_at = NOW()
      WHERE p.id = v_target AND p.tenant_id = v_batch.tenant_id;
      v_canonical_id := v_target;
      v_update_count := v_update_count + 1;
    END IF;

    PERFORM puls_integration._import_upsert_identity_map(
      v_batch.tenant_id, v_batch.source_namespace_id, v_rec.entity_type,
      v_rec.external_id, v_canonical_id, v_rec.row_hash
    );
    PERFORM puls_integration._import_mark_applied(v_rec.id, v_canonical_id);
  END LOOP;

  -- 7) employees (org fields only; no cache dimension columns)
  FOR v_rec IN
    SELECT ir.* FROM puls_integration.import_records ir
    WHERE ir.batch_id = p_batch_id
      AND ir.entity_type = 'employee'::puls_integration.import_entity_type
      AND ir.status = 'validated'::puls_integration.import_record_status
    ORDER BY ir.row_number
  LOOP
    v_payload := v_rec.normalized_payload;
    SELECT t.canonical_id, t.error_code
    INTO v_target, v_target_err
    FROM puls_integration._import_resolve_entity_target(
      v_batch.tenant_id, v_batch.source_namespace_id, v_rec.entity_type, v_rec.external_id, v_payload
    ) t;

    IF v_target_err IS NOT NULL THEN
      RAISE EXCEPTION 'PULS_IMPORT_APPLY_FAILED: ambiguous target on row % (%)', v_rec.row_number, v_target_err;
    END IF;

    IF v_target IS NOT NULL THEN
      IF puls_integration._import_should_skip_priority(
        v_batch.tenant_id, v_batch.source_namespace_id, v_namespace.priority_rank, v_rec.entity_type, v_target
      ) THEN
        PERFORM puls_integration._import_mark_skipped(v_rec.id, 'LOWER_PRIORITY_SOURCE_SKIPPED', v_target);
        v_skip_count := v_skip_count + 1;
        CONTINUE;
      END IF;
      IF puls_integration._import_should_skip_unchanged_hash(
        v_batch.tenant_id, v_batch.source_namespace_id, v_rec.entity_type,
        v_rec.external_id, v_target, v_rec.row_hash
      ) THEN
        PERFORM puls_integration._import_mark_skipped(v_rec.id, 'UNCHANGED_ROW_HASH', v_target);
        v_skip_count := v_skip_count + 1;
        CONTINUE;
      END IF;
    END IF;

    v_dept_id := NULL;
    IF v_payload ? 'department_code' OR v_payload ? 'department_external_id' THEN
      v_dept_id := puls_integration._import_resolve_ref_at_apply(
        v_batch.tenant_id, v_batch.source_namespace_id, p_batch_id,
        'department'::puls_integration.import_entity_type,
        v_payload ->> 'department_external_id',
        v_payload ->> 'department_code'
      );
    END IF;

    v_pos_id := NULL;
    IF v_payload ? 'position_code' OR v_payload ? 'position_external_id' THEN
      v_pos_id := puls_integration._import_resolve_ref_at_apply(
        v_batch.tenant_id, v_batch.source_namespace_id, p_batch_id,
        'position'::puls_integration.import_entity_type,
        v_payload ->> 'position_external_id',
        v_payload ->> 'position_code'
      );
    END IF;

    v_emp_status := CASE lower(COALESCE(v_payload ->> 'employment_status', 'active'))
      WHEN 'inactive' THEN 'inactive'::puls_core.employment_status
      WHEN 'terminated' THEN 'terminated'::puls_core.employment_status
      WHEN 'on_leave' THEN 'on_leave'::puls_core.employment_status
      ELSE 'active'::puls_core.employment_status
    END;

    IF v_target IS NULL THEN
      INSERT INTO puls_core.employees (
        tenant_id, employee_code, email, full_name, job_title,
        department_id, position_id, employment_status,
        hire_date, termination_date,
        external_employee_id, external_source, last_synced_at
      ) VALUES (
        v_batch.tenant_id,
        NULLIF(v_payload ->> 'employee_code', ''),
        NULLIF(v_payload ->> 'email', ''),
        v_payload ->> 'full_name',
        NULLIF(v_payload ->> 'job_title', ''),
        v_dept_id,
        v_pos_id,
        v_emp_status,
        NULLIF(v_payload ->> 'hire_date', '')::date,
        NULLIF(v_payload ->> 'termination_date', '')::date,
        v_rec.external_id,
        v_namespace.code,
        NOW()
      )
      RETURNING id INTO v_canonical_id;
      v_create_count := v_create_count + 1;
    ELSE
      UPDATE puls_core.employees e
      SET
        employee_code = COALESCE(NULLIF(v_payload ->> 'employee_code', ''), e.employee_code),
        email = COALESCE(NULLIF(v_payload ->> 'email', ''), e.email),
        full_name = COALESCE(v_payload ->> 'full_name', e.full_name),
        job_title = COALESCE(NULLIF(v_payload ->> 'job_title', ''), e.job_title),
        department_id = COALESCE(v_dept_id, e.department_id),
        position_id = COALESCE(v_pos_id, e.position_id),
        employment_status = v_emp_status,
        hire_date = COALESCE(NULLIF(v_payload ->> 'hire_date', '')::date, e.hire_date),
        termination_date = COALESCE(NULLIF(v_payload ->> 'termination_date', '')::date, e.termination_date),
        external_employee_id = v_rec.external_id,
        external_source = v_namespace.code,
        last_synced_at = NOW(),
        updated_at = NOW()
      WHERE e.id = v_target AND e.tenant_id = v_batch.tenant_id;
      v_canonical_id := v_target;
      v_update_count := v_update_count + 1;
    END IF;

    PERFORM puls_integration._import_upsert_identity_map(
      v_batch.tenant_id, v_batch.source_namespace_id, v_rec.entity_type,
      v_rec.external_id, v_canonical_id, v_rec.row_hash
    );
    PERFORM puls_integration._import_mark_applied(v_rec.id, v_canonical_id);
  END LOOP;

  -- 8) employee dimension assignments (SoT; source = import)
  FOR v_rec IN
    SELECT ir.* FROM puls_integration.import_records ir
    WHERE ir.batch_id = p_batch_id
      AND ir.entity_type = 'employee'::puls_integration.import_entity_type
      AND ir.status = 'applied'::puls_integration.import_record_status
    ORDER BY ir.row_number
  LOOP
    v_payload := v_rec.normalized_payload;
    v_canonical_id := v_rec.canonical_id;

    IF v_payload ? 'legal_entity_code' OR v_payload ? 'legal_entity_external_id' THEN
      v_le_id := puls_integration._import_resolve_ref_at_apply(
        v_batch.tenant_id, v_batch.source_namespace_id, p_batch_id,
        'legal_entity'::puls_integration.import_entity_type,
        v_payload ->> 'legal_entity_external_id',
        v_payload ->> 'legal_entity_code'
      );
      IF v_le_id IS NOT NULL THEN
        UPDATE puls_core.employee_legal_entity_assignments a
        SET is_active = FALSE, ends_on = COALESCE(a.ends_on, CURRENT_DATE), updated_at = NOW()
        WHERE a.tenant_id = v_batch.tenant_id AND a.employee_id = v_canonical_id AND a.is_active = TRUE;

        INSERT INTO puls_core.employee_legal_entity_assignments (
          tenant_id, employee_id, legal_entity_id, is_active,
          source, source_namespace_id, external_id
        ) VALUES (
          v_batch.tenant_id, v_canonical_id, v_le_id, TRUE,
          'import', v_batch.source_namespace_id, v_rec.external_id || ':le'
        );
      END IF;
    END IF;

    IF v_payload ? 'location_code' OR v_payload ? 'location_external_id' THEN
      v_le_id := puls_integration._import_resolve_ref_at_apply(
        v_batch.tenant_id, v_batch.source_namespace_id, p_batch_id,
        'location'::puls_integration.import_entity_type,
        v_payload ->> 'location_external_id',
        v_payload ->> 'location_code'
      );
      IF v_le_id IS NOT NULL THEN
        UPDATE puls_core.employee_location_assignments a
        SET is_active = FALSE, ends_on = COALESCE(a.ends_on, CURRENT_DATE), updated_at = NOW()
        WHERE a.tenant_id = v_batch.tenant_id AND a.employee_id = v_canonical_id AND a.is_active = TRUE;

        INSERT INTO puls_core.employee_location_assignments (
          tenant_id, employee_id, location_id, is_active,
          source, source_namespace_id, external_id
        ) VALUES (
          v_batch.tenant_id, v_canonical_id, v_le_id, TRUE,
          'import', v_batch.source_namespace_id, v_rec.external_id || ':loc'
        );
      END IF;
    END IF;

    IF v_payload ? 'cost_center_code' OR v_payload ? 'cost_center_external_id' THEN
      v_cc_id := puls_integration._import_resolve_ref_at_apply(
        v_batch.tenant_id, v_batch.source_namespace_id, p_batch_id,
        'cost_center'::puls_integration.import_entity_type,
        v_payload ->> 'cost_center_external_id',
        v_payload ->> 'cost_center_code'
      );
      IF v_cc_id IS NOT NULL THEN
        UPDATE puls_core.employee_cost_center_assignments a
        SET is_active = FALSE, ends_on = COALESCE(a.ends_on, CURRENT_DATE), updated_at = NOW()
        WHERE a.tenant_id = v_batch.tenant_id AND a.employee_id = v_canonical_id AND a.is_active = TRUE;

        INSERT INTO puls_core.employee_cost_center_assignments (
          tenant_id, employee_id, cost_center_id, is_active,
          source, source_namespace_id, external_id
        ) VALUES (
          v_batch.tenant_id, v_canonical_id, v_cc_id, TRUE,
          'import', v_batch.source_namespace_id, v_rec.external_id || ':cc'
        );
      END IF;
    END IF;
  END LOOP;

  -- 9) post-pass: department parent + manager
  FOR v_rec IN
    SELECT ir.* FROM puls_integration.import_records ir
    WHERE ir.batch_id = p_batch_id
      AND ir.entity_type = 'department'::puls_integration.import_entity_type
      AND ir.status = 'applied'::puls_integration.import_record_status
    ORDER BY ir.row_number
  LOOP
    v_payload := v_rec.normalized_payload;

    IF v_payload ? 'parent_department_code' OR v_payload ? 'parent_department_external_id' THEN
      v_parent_id := puls_integration._import_resolve_ref_at_apply(
        v_batch.tenant_id, v_batch.source_namespace_id, p_batch_id,
        'department'::puls_integration.import_entity_type,
        v_payload ->> 'parent_department_external_id',
        v_payload ->> 'parent_department_code'
      );
      IF v_parent_id IS NOT NULL AND v_rec.canonical_id IS NOT NULL THEN
        UPDATE puls_core.departments d
        SET parent_id = v_parent_id, updated_at = NOW()
        WHERE d.id = v_rec.canonical_id AND d.tenant_id = v_batch.tenant_id;
      END IF;
    END IF;

    v_mgr_id := NULL;
    IF v_payload ? 'manager_employee_code' OR v_payload ? 'manager_employee_external_id' THEN
      v_mgr_id := puls_integration._import_resolve_ref_at_apply(
        v_batch.tenant_id, v_batch.source_namespace_id, p_batch_id,
        'employee'::puls_integration.import_entity_type,
        v_payload ->> 'manager_employee_external_id',
        v_payload ->> 'manager_employee_code'
      );
    ELSIF v_payload ? 'manager_email' AND btrim(v_payload ->> 'manager_email') <> '' THEN
      v_mgr_id := puls_integration._import_resolve_ref_at_apply(
        v_batch.tenant_id, v_batch.source_namespace_id, p_batch_id,
        'employee'::puls_integration.import_entity_type,
        NULL,
        v_payload ->> 'manager_email'
      );
    END IF;

    IF v_mgr_id IS NOT NULL AND v_rec.canonical_id IS NOT NULL THEN
      UPDATE puls_core.departments d
      SET manager_employee_id = v_mgr_id, updated_at = NOW()
      WHERE d.id = v_rec.canonical_id AND d.tenant_id = v_batch.tenant_id;
    END IF;
  END LOOP;

  -- 10) post-pass: position parent
  FOR v_rec IN
    SELECT ir.* FROM puls_integration.import_records ir
    WHERE ir.batch_id = p_batch_id
      AND ir.entity_type = 'position'::puls_integration.import_entity_type
      AND ir.status = 'applied'::puls_integration.import_record_status
    ORDER BY ir.row_number
  LOOP
    v_payload := v_rec.normalized_payload;
    IF v_payload ? 'parent_position_code' OR v_payload ? 'parent_position_external_id' THEN
      v_parent_id := puls_integration._import_resolve_ref_at_apply(
        v_batch.tenant_id, v_batch.source_namespace_id, p_batch_id,
        'position'::puls_integration.import_entity_type,
        v_payload ->> 'parent_position_external_id',
        v_payload ->> 'parent_position_code'
      );
      IF v_parent_id IS NOT NULL AND v_rec.canonical_id IS NOT NULL THEN
        UPDATE puls_core.positions p
        SET parent_position_id = v_parent_id, updated_at = NOW()
        WHERE p.id = v_rec.canonical_id AND p.tenant_id = v_batch.tenant_id;
      END IF;
    END IF;
  END LOOP;

  -- 11) post-pass: employee manager reporting lines
  FOR v_rec IN
    SELECT ir.* FROM puls_integration.import_records ir
    WHERE ir.batch_id = p_batch_id
      AND ir.entity_type = 'employee'::puls_integration.import_entity_type
      AND ir.status = 'applied'::puls_integration.import_record_status
    ORDER BY ir.row_number
  LOOP
    v_payload := v_rec.normalized_payload;
    v_mgr_id := NULL;

    IF v_payload ? 'manager_employee_code' OR v_payload ? 'manager_employee_external_id' THEN
      v_mgr_id := puls_integration._import_resolve_ref_at_apply(
        v_batch.tenant_id, v_batch.source_namespace_id, p_batch_id,
        'employee'::puls_integration.import_entity_type,
        v_payload ->> 'manager_employee_external_id',
        v_payload ->> 'manager_employee_code'
      );
    ELSIF v_payload ? 'manager_email' AND btrim(v_payload ->> 'manager_email') <> '' THEN
      v_mgr_id := puls_integration._import_resolve_ref_at_apply(
        v_batch.tenant_id, v_batch.source_namespace_id, p_batch_id,
        'employee'::puls_integration.import_entity_type,
        NULL,
        v_payload ->> 'manager_email'
      );
    END IF;

    IF v_mgr_id IS NOT NULL AND v_rec.canonical_id IS NOT NULL THEN
      PERFORM puls_core.upsert_primary_reporting_line(
        v_batch.tenant_id,
        v_rec.canonical_id,
        v_mgr_id,
        v_reporting_source,
        v_namespace.code,
        v_rec.external_id || ':mgr',
        CURRENT_DATE
      );
    END IF;
  END LOOP;

  UPDATE puls_integration.import_batches ib
  SET
    status = 'applied'::puls_integration.import_batch_status,
    applied_at = NOW(),
    applied_by_employee_id = puls_core.current_employee_id(),
    create_count = v_create_count,
    update_count = v_update_count,
    skip_count = v_skip_count,
    updated_at = NOW()
  WHERE ib.id = p_batch_id;

  RETURN jsonb_build_object(
    'batch_id', p_batch_id,
    'status', 'applied',
    'create_count', v_create_count,
    'update_count', v_update_count,
    'skip_count', v_skip_count,
    'applied_at', NOW()
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- Grants (3 public RPCs only)
-- ---------------------------------------------------------------------------

REVOKE ALL ON FUNCTION puls_integration.validate_import_batch(UUID) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.preview_import_diff(UUID) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.apply_import_batch(UUID, TEXT) FROM PUBLIC, authenticated, anon;

GRANT EXECUTE ON FUNCTION puls_integration.validate_import_batch(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_integration.preview_import_diff(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_integration.apply_import_batch(UUID, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION puls_integration._import_lock_batch(UUID) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration._import_map_reporting_source(puls_integration.source_type) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration._import_normalize_payload(puls_integration.import_entity_type, JSONB) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration._import_canonical_table(puls_integration.import_entity_type) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration._import_lookup_by_code(UUID, puls_integration.import_entity_type, TEXT) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration._import_lookup_employee(UUID, TEXT, TEXT) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration._import_owner_priority_rank(UUID, puls_integration.import_entity_type, UUID) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration._import_should_skip_priority(UUID, UUID, INTEGER, puls_integration.import_entity_type, UUID) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration._import_should_skip_unchanged_hash(UUID, UUID, puls_integration.import_entity_type, TEXT, UUID, TEXT) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration._import_upsert_identity_map(UUID, UUID, puls_integration.import_entity_type, TEXT, UUID, TEXT) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration._import_assert_batch_records_validated(UUID) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration._import_validate_required_fields(puls_integration.import_entity_type, JSONB) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration._import_identity_map_lookup(UUID, UUID, puls_integration.import_entity_type, TEXT) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration._import_same_batch_lookup(UUID, puls_integration.import_entity_type, TEXT, TEXT, INTEGER) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration._import_resolve_ref(UUID, UUID, UUID, puls_integration.import_entity_type, TEXT, TEXT, INTEGER) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration._import_resolve_entity_target(UUID, UUID, puls_integration.import_entity_type, TEXT, JSONB) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration._import_check_ref(UUID, UUID, UUID, puls_integration.import_entity_type, TEXT, TEXT, BOOLEAN) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration._import_validate_entity_refs(UUID, UUID, UUID, INTEGER, puls_integration.import_entity_type, JSONB) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration._import_resolve_ref_at_apply(UUID, UUID, UUID, puls_integration.import_entity_type, TEXT, TEXT) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration._import_classify_record(UUID, UUID, INTEGER, puls_integration.import_entity_type, TEXT, JSONB, TEXT) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration._import_mark_skipped(UUID, TEXT, UUID) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration._import_mark_applied(UUID, UUID) FROM PUBLIC, authenticated, anon;

GRANT EXECUTE ON FUNCTION puls_integration._import_lock_batch(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION puls_integration._import_upsert_identity_map(UUID, UUID, puls_integration.import_entity_type, TEXT, UUID, TEXT) TO service_role;
