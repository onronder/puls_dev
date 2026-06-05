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

echo "Checking ${REF}: PR16.3 create-only context hardening ..."

MIGRATION="$(file_at_ref supabase/migrations/20260605122000_puls_integration_create_only_job_context_hardening.sql)"
WORKER="$(file_at_ref services/erp-connector/src/worker.ts)"
WORKER_TEST="$(file_at_ref services/erp-connector/src/worker.test.ts)"
DOC="$(file_at_ref docs/product/16_3_create_only_apply_context_hardening.md)"
README="$(file_at_ref docs/product/README.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"

for needle in \
  "CREATE OR REPLACE FUNCTION puls_integration.heartbeat_connector_job" \
  "COALESCE(auth.role(), '') <> 'service_role'" \
  "p_safe_context || cj.safe_error_context" \
  "WHEN p_safe_context = '{}'::JSONB THEN cj.safe_error_context" \
  "PULS_CONNECTOR_JOB_SAFE_CONTEXT_FORBIDDEN" \
  "GRANT EXECUTE ON FUNCTION puls_integration.heartbeat_connector_job(UUID, TEXT, INTEGER, JSONB)" \
  "TO service_role"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: context hardening migration missing needle: $needle" >&2
    exit 1
  fi
done

for forbidden in \
  "cj.safe_error_context || p_safe_context" \
  "auth.role() <> 'service_role'" \
  "provider_response" \
  "credentials_ref"; do
  if grep -Fq "$forbidden" <<< "$MIGRATION"; then
    echo "FAIL: context hardening migration contains forbidden needle: $forbidden" >&2
    exit 1
  fi
done

if ! grep -Fq "p_safe_context: {}" <<< "$WORKER"; then
  echo "FAIL: worker job heartbeat must not overwrite queued job safe context" >&2
  exit 1
fi

for needle in \
  "does not overwrite queued job safe context during lease heartbeat" \
  "p_safe_context: {}"; do
  if ! grep -Fq "$needle" <<< "$WORKER_TEST"; then
    echo "FAIL: worker tests missing context hardening assertion: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.3A" \
  "preserves existing" \
  "fresh ref-only batch/change-set"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.3A doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.3A create-only context hardening" \
  "16_3_create_only_apply_context_hardening.md" \
  "20260605122000_puls_integration_create_only_job_context_hardening.sql"; do
  if ! grep -Fq "$needle" <<< "$README$ROADMAP"; then
    echo "FAIL: roadmap/README missing PR16.3A reference: $needle" >&2
    exit 1
  fi
done

node - <<'JS'
const fs = require('fs')
const sql = fs.readFileSync(
  'supabase/migrations/20260605122000_puls_integration_create_only_job_context_hardening.sql',
  'utf8',
)
const dollarQuotes = (sql.match(/\$\$/g) ?? []).length
if (dollarQuotes % 2 !== 0) {
  console.error(`FAIL: unbalanced dollar quotes: ${dollarQuotes}`)
  process.exit(1)
}
JS

echo "PR16.3 create-only context hardening verification passed."
