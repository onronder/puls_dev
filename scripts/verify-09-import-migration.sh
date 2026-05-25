#!/usr/bin/env bash
# Verifies 09 PR1 import foundation migration SQL invariants.
set -euo pipefail

REF="${1:-origin/cursor/09-import-foundation-b5b2}"
FILE="supabase/migrations/20260525143000_puls_integration_import_foundation.sql"

sql() {
  git show "${REF}:${FILE}" 2>/dev/null || cat "${FILE}"
}

echo "Checking ${REF}:${FILE} ..."

for needle in \
  "CREATE TABLE IF NOT EXISTS puls_integration.source_namespaces" \
  "priority_rank INTEGER NOT NULL" \
  "CREATE TABLE IF NOT EXISTS puls_integration.import_records" \
  "raw_payload JSONB NULL DEFAULT NULL" \
  "Must remain NULL in pilot" \
  "CREATE OR REPLACE FUNCTION puls_integration.redact_import_payload" \
  "SENSITIVE_BLOCK_LIST_BEGIN" \
  "SENSITIVE_BLOCK_LIST_END" \
  "CREATE OR REPLACE FUNCTION puls_integration.compute_import_row_hash" \
  "sanitized_payload" \
  "CREATE OR REPLACE FUNCTION puls_integration.validate_entity_identity_map_tenant" \
  "PULS_IDENTITY_MAP_TARGET_NOT_ALLOWED" \
  "CREATE OR REPLACE FUNCTION puls_integration.create_import_batch" \
  "CREATE OR REPLACE FUNCTION puls_integration.record_import_row" \
  "SECURITY DEFINER" \
  "puls_integration.can_read_import_payload()" \
  "puls_integration.list_import_record_summaries"; do
  if ! sql | rg -Fq "$needle"; then
    echo "FAIL: missing required fragment: $needle"
    exit 1
  fi
done

if sql | rg -n "INSERT INTO" | rg -F "redact_import_payload" -q; then
  echo "FAIL: redact_import_payload must be pure (no INSERT)"
  exit 1
fi

if ! sql | rg -Fq "ORDER BY priority_rank ASC, updated_at DESC, id ASC"; then
  if ! sql | rg -Fq "updated_at DESC, id ASC"; then
    echo "FAIL: missing priority_rank tie-break documentation"
    exit 1
  fi
fi

echo "OK: 09 PR1 migration structural checks passed for ${REF}"
