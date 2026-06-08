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

echo "Checking ${REF}: PR16.10.9 runtime safety hardening ..."

MIGRATION="$(
  file_at_ref supabase/migrations/20260608120000_puls_runtime_safety_notification_idempotency_hardening.sql
  printf '\n'
  file_at_ref supabase/migrations/20260608121000_puls_app_notification_dedupe_volatility_alignment.sql
)"
SUPABASE_CLIENT="$(file_at_ref src/lib/supabase.ts)"
CI="$(file_at_ref .github/workflows/ci.yml)"
DOC="$(file_at_ref docs/product/16_10_9_runtime_safety_hardening.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"

for needle in \
  "PR16.10.9 runtime safety and notification idempotency hardening" \
  "DROP POLICY IF EXISTS puls_audit_logs_insert" \
  "tenant_id = puls_core.current_tenant_id()" \
  "tenant_id = puls_core.current_legacy_public_tenant_id()" \
  "normalize_app_notification_dedupe_key" \
  "ALTER FUNCTION puls_app.normalize_app_notification_dedupe_key(TEXT, TEXT, TEXT)" \
  "STABLE" \
  "app_notifications_normalize_dedupe_key" \
  "dedupe_superseded" \
  "superseded_by_dedupe_key" \
  "CREATE OR REPLACE FUNCTION puls_integration.complete_connector_job" \
  "CREATE OR REPLACE FUNCTION puls_integration.revoke_connector_credential_reference" \
  "CREATE OR REPLACE FUNCTION puls_integration.mark_connector_credential_verification" \
  "CREATE OR REPLACE FUNCTION puls_integration.execute_connector_create_only_apply_job" \
  "CREATE OR REPLACE FUNCTION puls_integration.execute_connector_guarded_update_apply_job" \
  "CREATE OR REPLACE FUNCTION puls_integration.execute_connector_guarded_update_rollback_apply_job" \
  "OR v_job.lease_expires_at IS NULL" \
  "OR v_job.lease_expires_at <= NOW()" \
  "'running'::puls_integration.connector_job_status" \
  "PULS_CONNECTOR_CREDENTIAL_REVOKED" \
  "PULS_CONNECTOR_CREDENTIAL_HANDOFF_REVOKED" \
  "provider calls, browser direct writes" \
  "credential readback, raw payload readback"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: migration missing needle: $needle" >&2
    exit 1
  fi
done

if grep -Fq "tenant_id IS NULL" <<< "$MIGRATION"; then
  echo "FAIL: PR16.10.9 audit policy must not reintroduce nullable tenant inserts" >&2
  exit 1
fi

LEASE_GUARD_COUNT="$(grep -Fc "OR v_job.lease_expires_at <= NOW()" <<< "$MIGRATION")"
if [[ "$LEASE_GUARD_COUNT" -lt 4 ]]; then
  echo "FAIL: expected lease guard on completion plus three apply executors, got ${LEASE_GUARD_COUNT}" >&2
  exit 1
fi

if grep -Fq "job.status::TEXT" <<< "$MIGRATION"; then
  echo "FAIL: PR16.10.9 migration must not build dedupe keys from mutable job.status" >&2
  exit 1
fi

for needle in \
  "import.meta.env.PROD" \
  "VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY are required in production" \
  "http://localhost:54321" \
  "placeholder-anon-key"; do
  if ! grep -Fq "$needle" <<< "$SUPABASE_CLIENT"; then
    echo "FAIL: Supabase client missing production fail-fast needle: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "pnpm run test" <<< "$CI"; then
  echo "FAIL: CI must run Vitest regression tests" >&2
  exit 1
fi

for needle in \
  "PR16.10.9 Runtime Safety Hardening" \
  "audit tenant boundary" \
  "notification idempotency" \
  "active worker lease" \
  "revoked credential" \
  "production Supabase env fail-fast" \
  "No DataSource Manager UI refactor"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.10.9 doc missing needle: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR16.10.9 - Runtime Safety Hardening" <<< "$ROADMAP"; then
  echo "FAIL: roadmap missing PR16.10.9 section" >&2
  exit 1
fi

if ! grep -Fq "PR16.10.9 runtime safety hardening" <<< "$README"; then
  echo "FAIL: README missing PR16.10.9 section" >&2
  exit 1
fi

echo "PR16.10.9 runtime safety hardening verification passed."
