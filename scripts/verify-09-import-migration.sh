#!/usr/bin/env bash
# Verifies 09 PR1 import foundation migration SQL invariants.
set -euo pipefail

REF="${1:-origin/cursor/09-import-foundation-b5b2}"
FILE="supabase/migrations/20260525143000_puls_integration_import_foundation.sql"

sql() {
  git show "${REF}:${FILE}" 2>/dev/null || cat "${FILE}"
}

echo "Checking ${REF}:${FILE} ..."

SQL_CONTENT="$(sql)"

contains_fixed() {
  grep -Fq "$1" <<<"${SQL_CONTENT}"
}

hash_function_body() {
  awk '
    /FUNCTION puls_integration.compute_import_row_hash/ { in_body = 1 }
    in_body { print }
    in_body && /\$\$;/ { exit }
  ' <<<"${SQL_CONTENT}"
}

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
  "'tenant_id', p_tenant_id" \
  "'source_namespace_id', p_source_namespace_id" \
  "CREATE OR REPLACE FUNCTION puls_integration.validate_entity_identity_map_tenant" \
  "PULS_IDENTITY_MAP_TARGET_NOT_ALLOWED" \
  "CREATE OR REPLACE FUNCTION puls_integration.create_import_batch" \
  "p_tenant_id UUID DEFAULT NULL" \
  "CREATE OR REPLACE FUNCTION puls_integration.record_import_row" \
  "SECURITY DEFINER" \
  "puls_integration.can_read_import_payload()" \
  "puls_integration.list_import_record_summaries" \
  "REVOKE ALL ON FUNCTION puls_integration.create_import_batch" \
  "REVOKE ALL ON FUNCTION puls_integration.record_import_row" \
  "REVOKE ALL ON FUNCTION puls_integration.validate_entity_identity_map_tenant" \
  "GRANT EXECUTE ON FUNCTION puls_integration.create_import_batch" \
  "GRANT EXECUTE ON FUNCTION puls_integration.record_import_row"; do
  if ! contains_fixed "$needle"; then
    echo "FAIL: missing required fragment: $needle"
    exit 1
  fi
done

if grep -n "INSERT INTO" <<<"${SQL_CONTENT}" | grep -Fq "redact_import_payload"; then
  echo "FAIL: redact_import_payload must be pure (no INSERT)"
  exit 1
fi

if hash_function_body | grep -Fq "'batch_id'"; then
  echo "FAIL: compute_import_row_hash must not include batch_id in hash input"
  exit 1
fi

if hash_function_body | grep -Fq "'row_number'"; then
  echo "FAIL: compute_import_row_hash must not include row_number in hash input"
  exit 1
fi

if grep -Eiq "search_path = .*\\bpublic\\b" <<<"${SQL_CONTENT}"; then
  echo "FAIL: SECURITY DEFINER functions must not include public in search_path"
  exit 1
fi

if hash_function_body | grep -Eq "\\bdigest\\("; then
  echo "FAIL: compute_import_row_hash must not use unqualified digest(); use pg_catalog.sha256(convert_to(...))"
  exit 1
fi

if ! hash_function_body | grep -Fq "sha256("; then
  echo "FAIL: compute_import_row_hash must use sha256(convert_to(...))"
  exit 1
fi

if ! contains_fixed "updated_at DESC, id ASC"; then
  echo "FAIL: missing priority_rank tie-break documentation"
  exit 1
fi

echo "OK: 09 PR1 migration structural checks passed for ${REF}"
