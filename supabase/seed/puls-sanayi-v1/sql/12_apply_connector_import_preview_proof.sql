-- PR14.16 connector import preview proof batch
-- Creates a dry-run import batch for the existing connector source namespace.
-- This is internal proof data for validating canonical import preview behavior; it does not apply data.

DO $$
DECLARE
  v_tenant_id UUID := 'a0000001-0001-4001-8001-000000000001';
  v_namespace_id UUID;
  v_batch_id UUID;
  v_payload JSONB;
  v_sanitized JSONB;
  v_violations JSONB;
  v_row_hash TEXT;
  v_row RECORD;
BEGIN
  SELECT sn.id
  INTO v_namespace_id
  FROM puls_integration.source_namespaces sn
  JOIN puls_integration.erp_connections ec ON ec.id = sn.connection_id
  WHERE sn.tenant_id = v_tenant_id
    AND sn.is_active = TRUE
    AND ec.tenant_id = v_tenant_id
    AND ec.is_enabled = TRUE
  ORDER BY sn.priority_rank ASC, sn.updated_at DESC, sn.id ASC
  LIMIT 1;

  IF v_namespace_id IS NULL THEN
    RAISE EXCEPTION 'PR14_16_PROOF_NAMESPACE_MISSING';
  END IF;

  DELETE FROM puls_integration.import_batches ib
  WHERE ib.tenant_id = v_tenant_id
    AND ib.source_namespace_id = v_namespace_id
    AND ib.source_checksum = 'pr14_16_connector_preview_proof_v1';

  INSERT INTO puls_integration.import_batches (
    tenant_id,
    source_namespace_id,
    status,
    mode,
    source_checksum
  )
  VALUES (
    v_tenant_id,
    v_namespace_id,
    'uploaded',
    'dry_run',
    'pr14_16_connector_preview_proof_v1'
  )
  RETURNING id INTO v_batch_id;

  FOR v_row IN
    SELECT *
    FROM (
      VALUES
        (
          1,
          'legal_entity',
          'LE-PT-01',
          '{"code":"LE-PT-01","name":"Puls Teknik Anonim Sirketi","is_active":true}'::jsonb
        ),
        (
          2,
          'department',
          'CANIAS-DEPT-PR14-16',
          '{"code":"PR14-16-DEPT","name":"Connector Preview Departmani","is_active":true}'::jsonb
        ),
        (
          3,
          'position',
          'CANIAS-POS-PR14-16',
          '{"code":"PR14-16-POS","name":"Connector Preview Uzmani","is_active":true,"department_code":"PR14-16-DEPT"}'::jsonb
        ),
        (
          4,
          'cost_center',
          'CANIAS-CC-PR14-16',
          '{"code":"PR14-16-CC","name":"Connector Preview Masraf Merkezi","is_active":true,"legal_entity_code":"LE-PT-01"}'::jsonb
        ),
        (
          5,
          'employee',
          'CANIAS-EMP-PR14-16',
          '{"employee_code":"PR14-16-001","full_name":"Connector Preview Calisani","email":"connector-preview@puls.demo","hire_date":"2026-06-03","department_code":"PR14-16-DEPT","position_code":"PR14-16-POS","cost_center_code":"PR14-16-CC"}'::jsonb
        )
    ) AS proof(row_number, entity_type, external_id, payload)
  LOOP
    v_payload := v_row.payload;

    SELECT redacted.sanitized_payload, redacted.violations
    INTO v_sanitized, v_violations
    FROM puls_integration.redact_import_payload(v_payload) AS redacted;

    v_row_hash := puls_integration.compute_import_row_hash(
      v_tenant_id,
      v_namespace_id,
      v_row.entity_type::puls_integration.import_entity_type,
      puls_integration.normalize_import_external_id(v_row.external_id),
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
      v_tenant_id,
      v_batch_id,
      v_row.row_number,
      v_row.entity_type::puls_integration.import_entity_type,
      puls_integration.normalize_import_external_id(v_row.external_id),
      v_sanitized,
      NULL,
      NULL,
      v_row_hash,
      'pending',
      CASE
        WHEN jsonb_array_length(v_violations) > 0 THEN ARRAY['SENSITIVE_FIELDS_REDACTED']
        ELSE '{}'::text[]
      END
    );
  END LOOP;

  UPDATE puls_integration.import_batches ib
  SET row_count = (
    SELECT COUNT(*) FROM puls_integration.import_records ir WHERE ir.batch_id = v_batch_id
  )
  WHERE ib.id = v_batch_id;

  RAISE NOTICE 'PR14.16 connector preview proof batch ready: %', v_batch_id;
END $$;
