-- 11 PR11.2 — Org setup guardrails (departments + positions)
-- Forward-only. Org setup guardrails only.
-- Import apply sets puls.import_apply.active for re-import compatibility.
-- No employee assignment editing. No ERP writes/sync. No hard delete. No lifecycle audit.

CREATE OR REPLACE FUNCTION puls_integration.is_org_import_apply_active()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SET search_path = pg_catalog
AS $$
  SELECT COALESCE(NULLIF(current_setting('puls.import_apply.active', true), ''), 'false') = 'true';
$$;

REVOKE ALL ON FUNCTION puls_integration.is_org_import_apply_active() FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_integration.is_org_import_apply_active() TO service_role;
CREATE OR REPLACE FUNCTION puls_core._normalize_org_setup_text(p_value TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog
AS $$
  SELECT NULLIF(BTRIM(p_value), '');
$$;

CREATE OR REPLACE FUNCTION puls_core.validate_department_setup_guardrails()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
DECLARE
  v_name TEXT;
  v_code TEXT;
BEGIN
  IF TG_OP = 'UPDATE'
     AND NULLIF(BTRIM(OLD.external_source), '') IS NOT NULL
     AND NOT puls_integration.is_org_import_apply_active() THEN
    RAISE EXCEPTION 'PULS_ORG_DEPARTMENT_SOURCE_READ_ONLY: imported departments cannot be edited locally.';
  END IF;

  v_name := puls_core._normalize_org_setup_text(NEW.name);
  v_code := puls_core._normalize_org_setup_text(NEW.code);

  IF v_name IS NULL THEN
    RAISE EXCEPTION 'PULS_ORG_DEPARTMENT_NAME_REQUIRED: name is required.';
  END IF;

  IF v_code IS NULL THEN
    RAISE EXCEPTION 'PULS_ORG_DEPARTMENT_CODE_REQUIRED: code is required.';
  END IF;

  IF v_code !~ '^[a-z][a-z0-9_]{1,63}$' THEN
    RAISE EXCEPTION 'PULS_ORG_DEPARTMENT_CODE_INVALID: code must be lowercase slug.';
  END IF;

  IF NEW.manager_employee_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM puls_core.employees e
      WHERE e.id = NEW.manager_employee_id
        AND e.tenant_id = NEW.tenant_id
        AND e.employment_status = 'active'
    ) THEN
      RAISE EXCEPTION 'PULS_ORG_DEPARTMENT_MANAGER_INVALID: manager_employee_id is invalid for this tenant.';
    END IF;
  END IF;

  IF NEW.cost_center_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM puls_core.cost_centers cc
      WHERE cc.id = NEW.cost_center_id
        AND cc.tenant_id = NEW.tenant_id
        AND cc.is_active = TRUE
    ) THEN
      RAISE EXCEPTION 'PULS_ORG_DEPARTMENT_COST_CENTER_INVALID: cost_center_id is invalid for this tenant.';
    END IF;
  END IF;

  NEW.name := v_name;
  NEW.code := v_code;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION puls_core.validate_position_setup_guardrails()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, puls_core
AS $$
DECLARE
  v_name TEXT;
  v_code TEXT;
BEGIN
  IF TG_OP = 'UPDATE'
     AND NULLIF(BTRIM(OLD.external_source), '') IS NOT NULL
     AND NOT puls_integration.is_org_import_apply_active() THEN
    RAISE EXCEPTION 'PULS_ORG_POSITION_SOURCE_READ_ONLY: imported positions cannot be edited locally.';
  END IF;

  v_name := puls_core._normalize_org_setup_text(NEW.name);
  v_code := puls_core._normalize_org_setup_text(NEW.code);

  IF v_name IS NULL THEN
    RAISE EXCEPTION 'PULS_ORG_POSITION_NAME_REQUIRED: name is required.';
  END IF;

  IF v_code IS NULL THEN
    RAISE EXCEPTION 'PULS_ORG_POSITION_CODE_REQUIRED: code is required.';
  END IF;

  IF v_code !~ '^[a-z][a-z0-9_]{1,63}$' THEN
    RAISE EXCEPTION 'PULS_ORG_POSITION_CODE_INVALID: code must be lowercase slug.';
  END IF;

  IF NEW.department_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM puls_core.departments d
      WHERE d.id = NEW.department_id
        AND d.tenant_id = NEW.tenant_id
    ) THEN
      RAISE EXCEPTION 'PULS_ORG_POSITION_DEPARTMENT_INVALID: department_id is invalid for this tenant.';
    END IF;
  END IF;

  IF NEW.norm_headcount IS NOT NULL
     AND (NEW.norm_headcount < 0 OR NEW.norm_headcount > 100000) THEN
    RAISE EXCEPTION 'PULS_ORG_POSITION_NORM_INVALID: norm_headcount must be between 0 and 100000.';
  END IF;

  NEW.name := v_name;
  NEW.code := v_code;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS puls_core_departments_validate_setup_guardrails ON puls_core.departments;
CREATE TRIGGER puls_core_departments_validate_setup_guardrails
  BEFORE INSERT OR UPDATE ON puls_core.departments
  FOR EACH ROW
  EXECUTE FUNCTION puls_core.validate_department_setup_guardrails();

DROP TRIGGER IF EXISTS puls_core_positions_validate_setup_guardrails ON puls_core.positions;
CREATE TRIGGER puls_core_positions_validate_setup_guardrails
  BEFORE INSERT OR UPDATE ON puls_core.positions
  FOR EACH ROW
  EXECUTE FUNCTION puls_core.validate_position_setup_guardrails();

REVOKE ALL ON FUNCTION puls_core.validate_department_setup_guardrails() FROM PUBLIC, authenticated, anon;
REVOKE ALL ON FUNCTION puls_core.validate_position_setup_guardrails() FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION puls_core.validate_department_setup_guardrails() TO service_role;
GRANT EXECUTE ON FUNCTION puls_core.validate_position_setup_guardrails() TO service_role;
-- Import apply compatibility: org setup guardrails honor import context during apply_import_batch.

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
  PERFORM set_config('puls.import_apply.active', 'true', true);
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
