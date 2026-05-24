-- 06 hotfix 2 — drop legacy audit_logs.tenant_id FK to public.tenants
-- Workflow RPCs write puls_core.tenants.id via puls_core.current_tenant_id().
-- RLS already supports dual tenant semantics (core + legacy public id).

DO $$
DECLARE
  constraint_record RECORD;
BEGIN
  FOR constraint_record IN
    SELECT c.conname
    FROM pg_constraint c
    JOIN pg_class source_table ON source_table.oid = c.conrelid
    JOIN pg_namespace source_schema ON source_schema.oid = source_table.relnamespace
    JOIN pg_class target_table ON target_table.oid = c.confrelid
    JOIN pg_namespace target_schema ON target_schema.oid = target_table.relnamespace
    WHERE c.contype = 'f'
      AND source_schema.nspname = 'puls_audit'
      AND source_table.relname = 'audit_logs'
      AND target_schema.nspname = 'public'
      AND target_table.relname = 'tenants'
      AND EXISTS (
        SELECT 1
        FROM unnest(c.conkey) AS key(attnum)
        JOIN pg_attribute a
          ON a.attrelid = c.conrelid
         AND a.attnum = key.attnum
        WHERE a.attname = 'tenant_id'
      )
  LOOP
    EXECUTE format(
      'ALTER TABLE puls_audit.audit_logs DROP CONSTRAINT IF EXISTS %I',
      constraint_record.conname
    );
  END LOOP;
END $$;

COMMENT ON COLUMN puls_audit.audit_logs.tenant_id IS
  'Audit tenant scope. During public-to-puls_core transition this may contain either legacy public.tenants.id or canonical puls_core.tenants.id. Do not add a single-table FK until audit tenant model is finalized.';
