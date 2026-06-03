-- PR14.16 — Connector import preview dry-run boundary
-- Stores safe row-level preview classification for connector import batches.
-- No live connector runtime, secret capture, apply step, or external system write is opened here.

ALTER TABLE puls_integration.import_records
  ADD COLUMN IF NOT EXISTS preview_action TEXT NULL,
  ADD COLUMN IF NOT EXISTS preview_skip_code TEXT NULL,
  ADD COLUMN IF NOT EXISTS previewed_at TIMESTAMPTZ NULL;

ALTER TABLE puls_integration.import_records
  DROP CONSTRAINT IF EXISTS import_records_preview_action_valid;

ALTER TABLE puls_integration.import_records
  ADD CONSTRAINT import_records_preview_action_valid
  CHECK (
    preview_action IS NULL
    OR preview_action IN ('create', 'update', 'skip')
  );

CREATE INDEX IF NOT EXISTS idx_puls_integration_import_records_preview_action
  ON puls_integration.import_records (batch_id, preview_action);

COMMENT ON COLUMN puls_integration.import_records.preview_action IS
  'Safe dry-run preview classification. Does not imply apply/import execution.';

COMMENT ON COLUMN puls_integration.import_records.preview_skip_code IS
  'Safe skip reason emitted by preview classification; no source payload or provider response.';

COMMENT ON COLUMN puls_integration.import_records.previewed_at IS
  'Timestamp when row-level dry-run preview classification was last computed.';

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
  v_previewed_at TIMESTAMPTZ := NOW();
  v_diff JSONB := '[]'::jsonb;
BEGIN
  v_batch := puls_integration._import_lock_batch(p_batch_id);

  IF v_batch.mode <> 'dry_run'::puls_integration.import_batch_mode THEN
    RAISE EXCEPTION 'PULS_IMPORT_PREVIEW_DRY_RUN_REQUIRED: connector preview requires a dry_run batch.';
  END IF;

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

    UPDATE puls_integration.import_records ir
    SET
      canonical_id = v_class.canonical_id,
      preview_action = v_class.action,
      preview_skip_code = v_class.skip_code,
      previewed_at = v_previewed_at,
      updated_at = v_previewed_at
    WHERE ir.id = v_rec.id;

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
    previewed_at = v_previewed_at,
    create_count = v_create_count,
    update_count = v_update_count,
    skip_count = v_skip_count,
    updated_at = v_previewed_at
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

CREATE OR REPLACE FUNCTION puls_integration.list_connector_import_preview_records(p_batch_id UUID)
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
  preview_action TEXT,
  preview_skip_code TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  previewed_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, puls_integration, puls_core
AS $$
DECLARE
  v_tenant_id UUID := puls_core.current_tenant_id();
BEGIN
  IF p_batch_id IS NULL THEN
    RETURN;
  END IF;

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
    ir.preview_action,
    ir.preview_skip_code,
    ir.created_at,
    ir.updated_at,
    ir.previewed_at
  FROM puls_integration.import_records ir
  JOIN puls_integration.import_batches ib ON ib.id = ir.batch_id
  WHERE ir.tenant_id = v_tenant_id
    AND ib.tenant_id = v_tenant_id
    AND ir.batch_id = p_batch_id
  ORDER BY ir.row_number;
END;
$$;

REVOKE ALL ON FUNCTION puls_integration.list_connector_import_preview_records(UUID)
  FROM PUBLIC, authenticated, anon;

GRANT EXECUTE ON FUNCTION puls_integration.list_connector_import_preview_records(UUID)
  TO authenticated, service_role;
