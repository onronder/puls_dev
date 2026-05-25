-- 09 PR1 — Namespace-aware import foundation (bridge alongside puls_integration.erp_*)
-- Writes: SECURITY DEFINER RPCs only (create_import_batch, record_import_row).
-- service_role may call RPCs with explicit p_tenant_id (connector/background jobs).
-- Pilot: import_records.raw_payload MUST remain NULL (encrypted/debug reserved).

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

DO $$ BEGIN
  CREATE TYPE puls_integration.source_type AS ENUM (
    'erp', 'excel_csv', 'manual', 'demo'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE puls_integration.import_batch_status AS ENUM (
    'uploaded', 'normalized', 'validated', 'previewed', 'applied', 'failed', 'cancelled'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE puls_integration.import_batch_mode AS ENUM (
    'dry_run', 'apply'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE puls_integration.import_record_status AS ENUM (
    'pending', 'validated', 'error', 'applied', 'skipped'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE puls_integration.import_entity_type AS ENUM (
    'employee', 'department', 'position'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS puls_integration.source_namespaces (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  source_type puls_integration.source_type NOT NULL DEFAULT 'manual',
  trust_level TEXT NOT NULL DEFAULT 'standard',
  priority_rank INTEGER NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  connection_id UUID NULL REFERENCES puls_integration.erp_connections(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, code),
  CHECK (priority_rank >= 0)
);

COMMENT ON COLUMN puls_integration.source_namespaces.priority_rank IS
  'Apply precedence: lower rank = higher priority. Not UNIQUE. Tie-break: priority_rank ASC, updated_at DESC, id ASC.';

CREATE INDEX IF NOT EXISTS idx_puls_integration_source_namespaces_tenant_active
  ON puls_integration.source_namespaces (tenant_id, is_active, priority_rank);

CREATE TABLE IF NOT EXISTS puls_integration.entity_identity_map (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  source_namespace_id UUID NOT NULL REFERENCES puls_integration.source_namespaces(id) ON DELETE CASCADE,
  entity_type puls_integration.import_entity_type NOT NULL,
  external_id TEXT NOT NULL,
  canonical_schema TEXT NOT NULL DEFAULT 'puls_core',
  canonical_table TEXT NOT NULL,
  canonical_id UUID NOT NULL,
  source_hash TEXT NULL,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, source_namespace_id, entity_type, external_id),
  CHECK (external_id <> '')
);

CREATE INDEX IF NOT EXISTS idx_puls_integration_identity_map_canonical
  ON puls_integration.entity_identity_map (tenant_id, canonical_schema, canonical_table, canonical_id);

CREATE TABLE IF NOT EXISTS puls_integration.import_batches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  source_namespace_id UUID NOT NULL REFERENCES puls_integration.source_namespaces(id) ON DELETE RESTRICT,
  status puls_integration.import_batch_status NOT NULL DEFAULT 'uploaded',
  mode puls_integration.import_batch_mode NOT NULL DEFAULT 'dry_run',
  source_checksum TEXT NULL,
  row_count INTEGER NOT NULL DEFAULT 0,
  violation_count INTEGER NOT NULL DEFAULT 0,
  error_count INTEGER NOT NULL DEFAULT 0,
  created_by_employee_id UUID NULL REFERENCES puls_core.employees(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_puls_integration_import_batches_tenant_created
  ON puls_integration.import_batches (tenant_id, created_at DESC);

CREATE TABLE IF NOT EXISTS puls_integration.import_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  batch_id UUID NOT NULL REFERENCES puls_integration.import_batches(id) ON DELETE CASCADE,
  row_number INTEGER NOT NULL,
  entity_type puls_integration.import_entity_type NOT NULL,
  external_id TEXT NOT NULL,
  sanitized_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  normalized_payload JSONB NULL,
  raw_payload JSONB NULL DEFAULT NULL,
  row_hash TEXT NOT NULL,
  status puls_integration.import_record_status NOT NULL DEFAULT 'pending',
  error_codes TEXT[] NOT NULL DEFAULT '{}',
  warning_codes TEXT[] NOT NULL DEFAULT '{}',
  canonical_id UUID NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (batch_id, row_number),
  CHECK (external_id <> '')
);

COMMENT ON COLUMN puls_integration.import_records.raw_payload IS
  'Reserved for future encrypted/debug use. Must remain NULL in pilot; never stores unredacted source values.';

CREATE INDEX IF NOT EXISTS idx_puls_integration_import_records_batch
  ON puls_integration.import_records (batch_id, row_number);

CREATE TABLE IF NOT EXISTS puls_integration.import_field_violations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES puls_core.tenants(id) ON DELETE CASCADE,
  batch_id UUID NOT NULL REFERENCES puls_integration.import_batches(id) ON DELETE CASCADE,
  import_record_id UUID NOT NULL REFERENCES puls_integration.import_records(id) ON DELETE CASCADE,
  field_name TEXT NOT NULL,
  violation_code TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_puls_integration_import_violations_batch
  ON puls_integration.import_field_violations (batch_id);

-- HR-safe summary RPC (no payload columns; bypasses admin-only import_records RLS)
CREATE OR REPLACE FUNCTION puls_integration.list_import_record_summaries(p_batch_id UUID DEFAULT NULL)
RETURNS TABLE (
  id UUID,
  tenant_id UUID,
  batch_id UUID,
  row_number INTEGER,
  entity_type puls_integration.import_entity_type,
  external_id TEXT,
  status puls_integration.import_record_status,
  error_codes TEXT[],
  warning_codes TEXT[],
  canonical_id UUID,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_tenant_id UUID := puls_core.current_tenant_id();
BEGIN
  IF NOT puls_integration.is_import_metadata_reader() THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    ir.id,
    ir.tenant_id,
    ir.batch_id,
    ir.row_number,
    ir.entity_type,
    ir.external_id,
    ir.status,
    ir.error_codes,
    ir.warning_codes,
    ir.canonical_id,
    ir.created_at,
    ir.updated_at
  FROM puls_integration.import_records ir
  WHERE ir.tenant_id = v_tenant_id
    AND (p_batch_id IS NULL OR ir.batch_id = p_batch_id)
  ORDER BY ir.batch_id, ir.row_number;
END;
$$;

-- ---------------------------------------------------------------------------
-- updated_at triggers
-- ---------------------------------------------------------------------------

DROP TRIGGER IF EXISTS puls_integration_source_namespaces_set_updated_at ON puls_integration.source_namespaces;
CREATE TRIGGER puls_integration_source_namespaces_set_updated_at
  BEFORE UPDATE ON puls_integration.source_namespaces
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_integration_identity_map_set_updated_at ON puls_integration.entity_identity_map;
CREATE TRIGGER puls_integration_identity_map_set_updated_at
  BEFORE UPDATE ON puls_integration.entity_identity_map
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_integration_import_batches_set_updated_at ON puls_integration.import_batches;
CREATE TRIGGER puls_integration_import_batches_set_updated_at
  BEFORE UPDATE ON puls_integration.import_batches
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

DROP TRIGGER IF EXISTS puls_integration_import_records_set_updated_at ON puls_integration.import_records;
CREATE TRIGGER puls_integration_import_records_set_updated_at
  BEFORE UPDATE ON puls_integration.import_records
  FOR EACH ROW EXECUTE FUNCTION puls_core.set_updated_at();

-- ---------------------------------------------------------------------------
-- Authorization helpers
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_integration.is_import_metadata_reader()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_core, puls_integration
AS $$
  SELECT
    puls_core.is_admin()
    OR puls_core.current_persona_role() = 'hr_admin'::puls_core.persona_role;
$$;

CREATE OR REPLACE FUNCTION puls_integration.can_read_import_payload()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_core, puls_integration
AS $$
  SELECT puls_core.is_admin();
$$;

CREATE OR REPLACE FUNCTION puls_integration.can_write_import_data()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_core, puls_integration
AS $$
  SELECT auth.role() = 'service_role' OR puls_core.is_admin();
$$;

-- ---------------------------------------------------------------------------
-- External ID normalization
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_integration.normalize_import_external_id(p_external_id TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
SET search_path = pg_catalog
AS $$
DECLARE
  v_normalized TEXT;
BEGIN
  v_normalized := BTRIM(COALESCE(p_external_id, ''));
  IF v_normalized = '' THEN
    RAISE EXCEPTION 'PULS_IMPORT_INVALID_EXTERNAL_ID: external_id must be non-empty after trim.';
  END IF;
  RETURN v_normalized;
END;
$$;

-- ---------------------------------------------------------------------------
-- Sensitive-field block list (pure redact — P1-1)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_integration.import_blocked_keys()
RETURNS TEXT[]
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog
AS $$
  SELECT ARRAY[
    -- SENSITIVE_BLOCK_LIST_BEGIN
    'salary',
    'salary_min',
    'salary_max',
    'maas',
    'pay_band',
    'payroll',
    'compensation',
    'tckn',
    'iban',
    'birth_date',
    'dogum_tarihi',
    'health',
    'saglik',
    'family',
    'aile'
    -- SENSITIVE_BLOCK_LIST_END
  ]::TEXT[];
$$;

CREATE OR REPLACE FUNCTION puls_integration._redact_jsonb_node(
  p_in JSONB,
  p_path TEXT,
  p_blocked TEXT[]
)
RETURNS TABLE (out_sanitized JSONB, out_violations JSONB)
LANGUAGE plpgsql
IMMUTABLE
SET search_path = pg_catalog
AS $$
DECLARE
  v_key TEXT;
  v_norm TEXT;
  v_field_path TEXT;
  v_child JSONB;
  v_sanitized_child JSONB;
  v_violations_child JSONB;
  v_obj JSONB := '{}'::jsonb;
  v_arr JSONB := '[]'::jsonb;
  v_violations JSONB := '[]'::jsonb;
  v_i INTEGER;
  v_elem JSONB;
BEGIN
  IF p_in IS NULL OR jsonb_typeof(p_in) = 'null' THEN
    out_sanitized := p_in;
    out_violations := '[]'::jsonb;
    RETURN NEXT;
    RETURN;
  END IF;

  IF jsonb_typeof(p_in) = 'object' THEN
    FOR v_key IN SELECT jsonb_object_keys(p_in) LOOP
      v_norm := lower(v_key);
      v_field_path := CASE WHEN p_path = '' THEN v_key ELSE p_path || '.' || v_key END;

      IF v_norm = ANY(p_blocked) THEN
        v_violations := v_violations || jsonb_build_array(
          jsonb_build_object('field_name', v_field_path, 'violation_code', 'SENSITIVE_FIELD_BLOCKED')
        );
        CONTINUE;
      END IF;

      SELECT r.out_sanitized, r.out_violations
      INTO v_sanitized_child, v_violations_child
      FROM puls_integration._redact_jsonb_node(p_in -> v_key, v_field_path, p_blocked) AS r;

      v_obj := v_obj || jsonb_build_object(v_key, v_sanitized_child);
      v_violations := v_violations || COALESCE(v_violations_child, '[]'::jsonb);
    END LOOP;

    out_sanitized := v_obj;
    out_violations := v_violations;
    RETURN NEXT;
    RETURN;
  END IF;

  IF jsonb_typeof(p_in) = 'array' THEN
    v_i := 0;
    FOR v_elem IN SELECT value FROM jsonb_array_elements(p_in) LOOP
      v_i := v_i + 1;
      v_field_path := p_path || '[' || v_i::text || ']';

      SELECT r.out_sanitized, r.out_violations
      INTO v_sanitized_child, v_violations_child
      FROM puls_integration._redact_jsonb_node(v_elem, v_field_path, p_blocked) AS r;

      v_arr := v_arr || jsonb_build_array(v_sanitized_child);
      v_violations := v_violations || COALESCE(v_violations_child, '[]'::jsonb);
    END LOOP;

    out_sanitized := v_arr;
    out_violations := v_violations;
    RETURN NEXT;
    RETURN;
  END IF;

  out_sanitized := p_in;
  out_violations := '[]'::jsonb;
  RETURN NEXT;
END;
$$;

CREATE OR REPLACE FUNCTION puls_integration.redact_import_payload(p_payload JSONB)
RETURNS TABLE (sanitized_payload JSONB, violations JSONB)
LANGUAGE plpgsql
IMMUTABLE
SET search_path = pg_catalog, puls_integration
AS $$
DECLARE
  v_blocked TEXT[] := puls_integration.import_blocked_keys();
BEGIN
  RETURN QUERY
  SELECT r.out_sanitized, r.out_violations
  FROM puls_integration._redact_jsonb_node(COALESCE(p_payload, '{}'::jsonb), '', v_blocked) AS r;
END;
$$;

-- ---------------------------------------------------------------------------
-- row_hash from stable identity + sanitized payload only (P1-5; batch/row excluded)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_integration.compute_import_row_hash(
  p_tenant_id UUID,
  p_source_namespace_id UUID,
  p_entity_type puls_integration.import_entity_type,
  p_external_id TEXT,
  p_sanitized_payload JSONB
)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog
AS $$
  SELECT encode(
    sha256(
      convert_to(
        jsonb_build_object(
          'tenant_id', p_tenant_id,
          'source_namespace_id', p_source_namespace_id,
          'entity_type', p_entity_type::text,
          'external_id', p_external_id,
          'sanitized_payload', COALESCE(p_sanitized_payload, '{}'::jsonb)
        )::text,
        'UTF8'
      )
    ),
    'hex'
  );
$$;

-- ---------------------------------------------------------------------------
-- Identity map validation (P1-4, P1-7)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_integration.is_identity_map_target_allowed(
  p_schema TEXT,
  p_table TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog
AS $$
  SELECT
    p_schema = 'puls_core'
    AND p_table IN ('employees', 'departments', 'positions');
$$;

CREATE OR REPLACE FUNCTION puls_integration.validate_entity_identity_map_tenant()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_exists BOOLEAN := FALSE;
BEGIN
  NEW.external_id := puls_integration.normalize_import_external_id(NEW.external_id);

  IF NOT puls_integration.is_identity_map_target_allowed(NEW.canonical_schema, NEW.canonical_table) THEN
    RAISE EXCEPTION 'PULS_IDENTITY_MAP_TARGET_NOT_ALLOWED: %.% is not in the PR1 allowlist.', NEW.canonical_schema, NEW.canonical_table;
  END IF;

  IF NEW.canonical_schema = 'puls_core' AND NEW.canonical_table = 'employees' THEN
    SELECT EXISTS (
      SELECT 1
      FROM puls_core.employees e
      WHERE e.id = NEW.canonical_id
        AND e.tenant_id = NEW.tenant_id
        AND e.employment_status = 'active'
    ) INTO v_exists;
  ELSIF NEW.canonical_schema = 'puls_core' AND NEW.canonical_table = 'departments' THEN
    SELECT EXISTS (
      SELECT 1
      FROM puls_core.departments d
      WHERE d.id = NEW.canonical_id
        AND d.tenant_id = NEW.tenant_id
        AND d.is_active = TRUE
    ) INTO v_exists;
  ELSIF NEW.canonical_schema = 'puls_core' AND NEW.canonical_table = 'positions' THEN
    SELECT EXISTS (
      SELECT 1
      FROM puls_core.positions p
      WHERE p.id = NEW.canonical_id
        AND p.tenant_id = NEW.tenant_id
        AND p.is_active = TRUE
    ) INTO v_exists;
  END IF;

  IF NOT v_exists THEN
    RAISE EXCEPTION 'PULS_IDENTITY_MAP_INVALID_TARGET: canonical target not found, inactive, or cross-tenant.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM puls_integration.source_namespaces sn
    WHERE sn.id = NEW.source_namespace_id
      AND sn.tenant_id = NEW.tenant_id
      AND sn.is_active = TRUE
  ) THEN
    RAISE EXCEPTION 'PULS_IDENTITY_MAP_INVALID_NAMESPACE: source namespace missing, inactive, or cross-tenant.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS puls_integration_identity_map_validate ON puls_integration.entity_identity_map;
CREATE TRIGGER puls_integration_identity_map_validate
  BEFORE INSERT OR UPDATE ON puls_integration.entity_identity_map
  FOR EACH ROW EXECUTE FUNCTION puls_integration.validate_entity_identity_map_tenant();

-- ---------------------------------------------------------------------------
-- RPC: create_import_batch
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_integration.create_import_batch(
  p_namespace_code TEXT,
  p_mode puls_integration.import_batch_mode DEFAULT 'dry_run',
  p_source_checksum TEXT DEFAULT NULL,
  p_tenant_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_tenant_id UUID;
  v_namespace_id UUID;
  v_batch_id UUID;
  v_employee_id UUID;
BEGIN
  IF NOT puls_integration.can_write_import_data() THEN
    RAISE EXCEPTION 'PULS_IMPORT_FORBIDDEN: insufficient privileges to create import batch.';
  END IF;

  IF auth.role() = 'service_role' THEN
    IF p_tenant_id IS NULL THEN
      RAISE EXCEPTION 'PULS_IMPORT_TENANT_REQUIRED: service_role callers must pass p_tenant_id.';
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM puls_core.tenants t WHERE t.id = p_tenant_id
    ) THEN
      RAISE EXCEPTION 'PULS_IMPORT_TENANT_INVALID: tenant % not found.', p_tenant_id;
    END IF;
    v_tenant_id := p_tenant_id;
  ELSE
    v_tenant_id := puls_core.current_tenant_id();
    IF p_tenant_id IS NOT NULL AND p_tenant_id IS DISTINCT FROM v_tenant_id THEN
      RAISE EXCEPTION 'PULS_IMPORT_FORBIDDEN: p_tenant_id is not allowed for authenticated callers.';
    END IF;
    IF v_tenant_id IS NULL THEN
      RAISE EXCEPTION 'PULS_IMPORT_TENANT_REQUIRED: authenticated caller has no tenant context.';
    END IF;
  END IF;

  SELECT sn.id
  INTO v_namespace_id
  FROM puls_integration.source_namespaces sn
  WHERE sn.tenant_id = v_tenant_id
    AND sn.code = p_namespace_code
    AND sn.is_active = TRUE;

  IF v_namespace_id IS NULL THEN
    RAISE EXCEPTION 'PULS_IMPORT_NAMESPACE_NOT_FOUND: active namespace % not found.', p_namespace_code;
  END IF;

  v_employee_id := puls_core.current_employee_id();

  INSERT INTO puls_integration.import_batches (
    tenant_id,
    source_namespace_id,
    status,
    mode,
    source_checksum,
    created_by_employee_id
  )
  VALUES (
    v_tenant_id,
    v_namespace_id,
    'uploaded',
    p_mode,
    p_source_checksum,
    v_employee_id
  )
  RETURNING id INTO v_batch_id;

  RETURN v_batch_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- RPC: record_import_row
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION puls_integration.record_import_row(
  p_batch_id UUID,
  p_row_number INTEGER,
  p_entity_type puls_integration.import_entity_type,
  p_external_id TEXT,
  p_payload JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_tenant_id UUID;
  v_batch_tenant UUID;
  v_source_namespace_id UUID;
  v_normalized_external_id TEXT;
  v_sanitized JSONB;
  v_violations JSONB;
  v_row_hash TEXT;
  v_record_id UUID;
  v_violation JSONB;
BEGIN
  IF NOT puls_integration.can_write_import_data() THEN
    RAISE EXCEPTION 'PULS_IMPORT_FORBIDDEN: insufficient privileges to record import row.';
  END IF;

  v_tenant_id := puls_core.current_tenant_id();

  SELECT ib.tenant_id, ib.source_namespace_id
  INTO v_batch_tenant, v_source_namespace_id
  FROM puls_integration.import_batches ib
  WHERE ib.id = p_batch_id;

  IF v_batch_tenant IS NULL THEN
    RAISE EXCEPTION 'PULS_IMPORT_BATCH_NOT_FOUND: batch % not found.', p_batch_id;
  END IF;

  IF v_batch_tenant IS DISTINCT FROM v_tenant_id AND auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'PULS_IMPORT_CROSS_TENANT: batch belongs to another tenant.';
  END IF;

  v_normalized_external_id := puls_integration.normalize_import_external_id(p_external_id);

  SELECT r.sanitized_payload, r.violations
  INTO v_sanitized, v_violations
  FROM puls_integration.redact_import_payload(COALESCE(p_payload, '{}'::jsonb)) AS r;

  v_row_hash := puls_integration.compute_import_row_hash(
    v_batch_tenant,
    v_source_namespace_id,
    p_entity_type,
    v_normalized_external_id,
    v_sanitized
  );

  INSERT INTO puls_integration.import_records (
    tenant_id,
    batch_id,
    row_number,
    entity_type,
    external_id,
    sanitized_payload,
    normalized_payload,
    raw_payload,
    row_hash,
    status,
    warning_codes
  )
  VALUES (
    v_batch_tenant,
    p_batch_id,
    p_row_number,
    p_entity_type,
    v_normalized_external_id,
    v_sanitized,
    NULL,
    NULL,
    v_row_hash,
    'pending',
    CASE WHEN jsonb_array_length(v_violations) > 0 THEN ARRAY['SENSITIVE_FIELDS_REDACTED'] ELSE '{}' END
  )
  RETURNING id INTO v_record_id;

  FOR v_violation IN
    SELECT value FROM jsonb_array_elements(v_violations)
  LOOP
    INSERT INTO puls_integration.import_field_violations (
      tenant_id,
      batch_id,
      import_record_id,
      field_name,
      violation_code
    )
    VALUES (
      v_batch_tenant,
      p_batch_id,
      v_record_id,
      v_violation ->> 'field_name',
      v_violation ->> 'violation_code'
    );
  END LOOP;

  UPDATE puls_integration.import_batches ib
  SET
    row_count = ib.row_count + 1,
    violation_count = ib.violation_count + jsonb_array_length(v_violations)
  WHERE ib.id = p_batch_id;

  RETURN v_record_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

ALTER TABLE puls_integration.source_namespaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_integration.entity_identity_map ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_integration.import_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_integration.import_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE puls_integration.import_field_violations ENABLE ROW LEVEL SECURITY;

-- source_namespaces: admin read/write; hr_admin read
DROP POLICY IF EXISTS puls_integration_source_namespaces_select ON puls_integration.source_namespaces;
CREATE POLICY puls_integration_source_namespaces_select ON puls_integration.source_namespaces
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND puls_integration.is_import_metadata_reader()
  );

DROP POLICY IF EXISTS puls_integration_source_namespaces_insert ON puls_integration.source_namespaces;
CREATE POLICY puls_integration_source_namespaces_insert ON puls_integration.source_namespaces
  FOR INSERT TO authenticated
  WITH CHECK (
    puls_core.is_admin()
    AND tenant_id = puls_core.current_tenant_id()
  );

DROP POLICY IF EXISTS puls_integration_source_namespaces_update ON puls_integration.source_namespaces;
CREATE POLICY puls_integration_source_namespaces_update ON puls_integration.source_namespaces
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

-- entity_identity_map: metadata readers; writes admin-only (PR4 apply will use RPC)
DROP POLICY IF EXISTS puls_integration_identity_map_select ON puls_integration.entity_identity_map;
CREATE POLICY puls_integration_identity_map_select ON puls_integration.entity_identity_map
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND puls_integration.is_import_metadata_reader()
  );

DROP POLICY IF EXISTS puls_integration_identity_map_insert ON puls_integration.entity_identity_map;
CREATE POLICY puls_integration_identity_map_insert ON puls_integration.entity_identity_map
  FOR INSERT TO authenticated
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

DROP POLICY IF EXISTS puls_integration_identity_map_update ON puls_integration.entity_identity_map;
CREATE POLICY puls_integration_identity_map_update ON puls_integration.entity_identity_map
  FOR UPDATE TO authenticated
  USING (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id())
  WITH CHECK (puls_core.is_admin() AND tenant_id = puls_core.current_tenant_id());

-- import_batches: metadata readers; no direct insert/update for authenticated (RPC only)
DROP POLICY IF EXISTS puls_integration_import_batches_select ON puls_integration.import_batches;
CREATE POLICY puls_integration_import_batches_select ON puls_integration.import_batches
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND puls_integration.is_import_metadata_reader()
  );

-- import_records: admin-only full payload SELECT; no direct writes
DROP POLICY IF EXISTS puls_integration_import_records_select ON puls_integration.import_records;
CREATE POLICY puls_integration_import_records_select ON puls_integration.import_records
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND puls_integration.can_read_import_payload()
  );

-- import_field_violations: metadata readers; no direct writes
DROP POLICY IF EXISTS puls_integration_import_violations_select ON puls_integration.import_field_violations;
CREATE POLICY puls_integration_import_violations_select ON puls_integration.import_field_violations
  FOR SELECT TO authenticated
  USING (
    tenant_id = puls_core.current_tenant_id()
    AND puls_integration.is_import_metadata_reader()
  );

-- ---------------------------------------------------------------------------
-- Grants for new tables
-- ---------------------------------------------------------------------------

GRANT SELECT, INSERT, UPDATE ON puls_integration.source_namespaces TO authenticated;
GRANT SELECT, INSERT, UPDATE ON puls_integration.entity_identity_map TO authenticated;
GRANT SELECT ON puls_integration.import_batches TO authenticated;
GRANT SELECT ON puls_integration.import_records TO authenticated;
GRANT SELECT ON puls_integration.import_field_violations TO authenticated;

GRANT ALL ON ALL TABLES IN SCHEMA puls_integration TO service_role;

-- Function execute surface (REVOKE default PUBLIC; grant only intended callers)
REVOKE ALL ON FUNCTION puls_integration.list_import_record_summaries(UUID) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.is_import_metadata_reader() FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.can_read_import_payload() FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.can_write_import_data() FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.normalize_import_external_id(TEXT) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.import_blocked_keys() FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration._redact_jsonb_node(JSONB, TEXT, TEXT[]) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.redact_import_payload(JSONB) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.compute_import_row_hash(UUID, UUID, puls_integration.import_entity_type, TEXT, JSONB) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.is_identity_map_target_allowed(TEXT, TEXT) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.validate_entity_identity_map_tenant() FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.create_import_batch(TEXT, puls_integration.import_batch_mode, TEXT, UUID) FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_integration.record_import_row(UUID, INTEGER, puls_integration.import_entity_type, TEXT, JSONB) FROM PUBLIC, authenticated, anon;

GRANT EXECUTE ON FUNCTION puls_integration.list_import_record_summaries(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_integration.is_import_metadata_reader() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_integration.can_read_import_payload() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_integration.create_import_batch(TEXT, puls_integration.import_batch_mode, TEXT, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION puls_integration.record_import_row(UUID, INTEGER, puls_integration.import_entity_type, TEXT, JSONB) TO authenticated, service_role;
