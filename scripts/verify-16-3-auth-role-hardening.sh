#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"

file_at_ref() {
  local path="$1"
  if [[ "$REF" == "WORKTREE" ]]; then
    cat "$path"
    return
  fi
  git show "${REF}:${path}" 2>/dev/null || cat "$path"
}

echo "Checking ${REF}: PR16.3 auth role hardening ..."

MIGRATION="$(file_at_ref supabase/migrations/20260605121000_puls_integration_create_only_auth_role_hardening.sql)"

for needle in \
  "COALESCE(auth.role(), '')" \
  "v_is_service_role BOOLEAN := v_auth_role = 'service_role'" \
  "NOT COALESCE(puls_core.is_admin(), FALSE)" \
  "NOT COALESCE(puls_integration.is_import_metadata_reader(), FALSE)" \
  "PULS_CONNECTOR_CREATE_ONLY_TENANT_REQUIRED" \
  "PULS_CONNECTOR_CREATE_ONLY_WORKER_ONLY" \
  "PULS_CONNECTOR_APPLY_SAFETY_TENANT_REQUIRED" \
  "GRANT EXECUTE ON FUNCTION puls_integration.enqueue_connector_create_only_apply_job(UUID)" \
  "GRANT EXECUTE ON FUNCTION puls_integration.execute_connector_create_only_apply_job(UUID, TEXT)" \
  "TO service_role" \
  "GRANT EXECUTE ON FUNCTION puls_integration.list_connector_apply_safety_contracts(UUID)" \
  "TO authenticated, service_role"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: auth hardening migration missing needle: $needle" >&2
    exit 1
  fi
done

for forbidden in \
  "auth.role() <> 'service_role'" \
  "auth.role() = 'service_role'" \
  "provider_response" \
  "credentials_ref"; do
  if grep -Fq "$forbidden" <<< "$MIGRATION"; then
    echo "FAIL: auth hardening migration contains forbidden needle: $forbidden" >&2
    exit 1
  fi
done

EXECUTE_CREATE_ONLY_GRANT="$(
  grep -A1 -F "GRANT EXECUTE ON FUNCTION puls_integration.execute_connector_create_only_apply_job(UUID, TEXT)" \
    <<< "$MIGRATION" || true
)"
if grep -Fq "authenticated" <<< "$EXECUTE_CREATE_ONLY_GRANT"; then
  echo "FAIL: create-only worker execution RPC must not be granted to authenticated" >&2
  exit 1
fi

node - <<'JS'
const fs = require('fs')
const sql = fs.readFileSync(
  'supabase/migrations/20260605121000_puls_integration_create_only_auth_role_hardening.sql',
  'utf8',
)
const dollarQuotes = (sql.match(/\$\$/g) ?? []).length
if (dollarQuotes % 2 !== 0) {
  console.error(`FAIL: unbalanced dollar quotes: ${dollarQuotes}`)
  process.exit(1)
}
JS

echo "PR16.3 auth role hardening verification passed."
