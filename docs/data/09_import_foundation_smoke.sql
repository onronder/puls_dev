-- 09 PR1 Import Foundation — manual SQL smoke checklist
-- Run after supabase db push through 20260525143000 on staging.
--
-- Pre-merge verification (from repo root):
--   git fetch origin cursor/09-import-foundation-b5b2
--   ./scripts/verify-09-import-migration.sh origin/cursor/09-import-foundation-b5b2
--   node scripts/check-sensitive-grep.mjs

-- Prerequisites: demo tenant Mert Teknik seeded; admin session available for RPC calls.

-- ---------------------------------------------------------------------------
-- 1) Pure redact — negative cases (run as postgres / service_role)
-- Expect: salary/iban/tckn stripped; violations list field paths; safe fields kept
-- ---------------------------------------------------------------------------

/*
SELECT sanitized_payload, violations
FROM puls_integration.redact_import_payload(
  jsonb_build_object(
    'full_name', 'Demo User',
    'salary', 85000,
    'nested', jsonb_build_object('IBAN', 'TR330006100519786457841326', 'department', 'Ops'),
    'TCKN', '12345678901'
  )
);
-- sanitized_payload must NOT contain 85000, TR33..., 12345678901
-- violations must include salary, nested.IBAN (or nested.iban), TCKN paths
*/

-- ---------------------------------------------------------------------------
-- 2) record_import_row RPC — pilot stores sanitized only, raw_payload NULL
-- As admin (o.onder@fittechs.com): create namespace + batch, record row with sensitive keys
-- ---------------------------------------------------------------------------

/*
DO $$
DECLARE
  v_tenant_id uuid;
  v_batch_id uuid;
  v_record_id uuid;
BEGIN
  SELECT id INTO v_tenant_id
  FROM puls_core.tenants
  WHERE legacy_public_tenant_id = '44444444-4444-4444-4444-444444444444';

  INSERT INTO puls_integration.source_namespaces (
    tenant_id, code, name, source_type, priority_rank
  )
  VALUES (v_tenant_id, 'smoke_manual', 'Smoke Manual', 'manual', 10)
  ON CONFLICT (tenant_id, code) DO UPDATE
    SET is_active = TRUE, priority_rank = EXCLUDED.priority_rank;

  v_batch_id := puls_integration.create_import_batch('smoke_manual', 'dry_run', 'smoke-checksum-v1');

  v_record_id := puls_integration.record_import_row(
    v_batch_id,
    1,
    'employee',
    ' EXT-001 ',
    jsonb_build_object('full_name', 'Smoke Import', 'salary', 99999, 'iban', 'TR000000000000000000000000')
  );

  RAISE NOTICE 'batch=% record=%', v_batch_id, v_record_id;
END $$;

-- Assert:
-- SELECT raw_payload, sanitized_payload FROM puls_integration.import_records ORDER BY created_at DESC LIMIT 1;
-- raw_payload IS NULL; sanitized_payload has full_name only (no salary/iban values)
-- SELECT field_name, violation_code FROM puls_integration.import_field_violations ORDER BY created_at DESC;
-- field_name + code only — no value column
*/

-- ---------------------------------------------------------------------------
-- 3) row_hash stability — sanitized unchanged => hash stable
-- Change only redacted field in source input; sanitized_payload identical => same row_hash
-- Change sanitized-visible field => row_hash changes
-- ---------------------------------------------------------------------------

/*
SELECT puls_integration.compute_import_row_hash(
  '00000000-0000-0000-0000-000000000001'::uuid,
  1,
  'employee'::puls_integration.import_entity_type,
  'EXT-001',
  '{"full_name":"Smoke"}'::jsonb
) AS hash_a;

-- Different salary in source does not affect hash if sanitized identical (redact before hash)
*/

-- ---------------------------------------------------------------------------
-- 4) external_id trim + empty reject
-- ---------------------------------------------------------------------------

/*
SELECT puls_integration.normalize_import_external_id('  ABC  '); -- OK: ABC
SELECT puls_integration.normalize_import_external_id('   ');    -- ERROR: PULS_IMPORT_INVALID_EXTERNAL_ID
*/

-- ---------------------------------------------------------------------------
-- 5) priority_rank tie-break (documented ordering)
-- ---------------------------------------------------------------------------

/*
SELECT id, code, priority_rank, updated_at
FROM puls_integration.source_namespaces
WHERE tenant_id = puls_core.current_tenant_id()
ORDER BY priority_rank ASC, updated_at DESC, id ASC;
*/

-- ---------------------------------------------------------------------------
-- 6) entity_identity_map allowlist reject (expect ERROR)
-- ---------------------------------------------------------------------------

/*
INSERT INTO puls_integration.entity_identity_map (
  tenant_id, source_namespace_id, entity_type, external_id,
  canonical_schema, canonical_table, canonical_id
)
VALUES (
  ..., ..., 'employee', 'bad-target',
  'puls_core', 'leave_types', '00000000-0000-0000-0000-000000000000'
);
-- ERROR: PULS_IDENTITY_MAP_TARGET_NOT_ALLOWED
*/

-- ---------------------------------------------------------------------------
-- 7) cross-tenant identity map reject (expect ERROR)
-- Use canonical_id from another tenant
-- ERROR: PULS_IDENTITY_MAP_INVALID_TARGET
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 8) HR payload access — narrow RLS
-- As hr_admin: list_import_record_summaries(batch_id) returns status/external_id
-- Direct SELECT on import_records.sanitized_payload denied (admin-only policy)
-- ---------------------------------------------------------------------------

/*
SELECT * FROM puls_integration.list_import_record_summaries('<batch_id>');
-- hr_admin: rows visible without payload columns
-- admin: full import_records SELECT includes sanitized_payload
*/

-- Live accounts: o.onder@fittechs.com (admin), yonetici@mertteknik.demo, calisan@mertteknik.demo
