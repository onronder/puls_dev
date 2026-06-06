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

echo "Checking ${REF}: PR16.9.0 puls_app bootstrap ..."

STRATEGY="$(file_at_ref docs/product/16_9_app_wide_notification_center_strategy.md)"
DOC="$(file_at_ref docs/product/16_9_0_puls_app_bootstrap.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
CONFIG="$(file_at_ref supabase/config.toml)"
MIGRATION="$(file_at_ref supabase/migrations/20260606170000_puls_app_notification_center_bootstrap.sql)"

for needle in \
  "PR16.9 App-Wide Notification Center Strategy" \
  "Use a dedicated application schema:" \
  "\`puls_app\`" \
  "PR16.9.0 - puls_app Bootstrap And Exposure Smoke" \
  "No Notification Center tables until this passes." \
  "Realtime is optional and additive" \
  "No realtime-only correctness path"; do
  if ! grep -Fq "$needle" <<< "$STRATEGY"; then
    echo "FAIL: PR16.9 strategy missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.9.0 puls_app Bootstrap And Exposure Smoke" \
  "pr16.9.0-puls-app-bootstrap-v1" \
  "Remote Operator Requirement" \
  "PGRST106" \
  "supabase stop" \
  "supabase start" \
  "app_schema_exists = true" \
  "notification_tables_exist = false" \
  "anon_exec = false" \
  "authenticated_exec = true" \
  "service_role_exec = true" \
  "PULS_APP_NOTIFICATION_BOOTSTRAP_TENANT_REQUIRED" \
  "Handoff To PR16.9.1"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.9.0 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "CREATE SCHEMA IF NOT EXISTS puls_app" \
  "REVOKE ALL ON SCHEMA puls_app FROM PUBLIC" \
  "GRANT USAGE ON SCHEMA puls_app TO authenticated, service_role" \
  "get_notification_center_bootstrap_status" \
  "pr16.9.0-puls-app-bootstrap-v1" \
  "PULS_APP_NOTIFICATION_BOOTSTRAP_TENANT_REQUIRED" \
  "notification_ledger_enabled" \
  "notification_realtime_enabled" \
  "external_delivery_enabled" \
  "postgrest_schema_exposure_required" \
  "postgrest_schema_reload_hint" \
  "credential_readback', FALSE" \
  "provider_api_calls', FALSE" \
  "raw_payload_readback', FALSE" \
  "field_value_readback', FALSE" \
  "snapshot_payload_readback', FALSE" \
  "source_writeback', FALSE" \
  "ai_autonomous_action', FALSE" \
  "GRANT EXECUTE ON FUNCTION puls_app.get_notification_center_bootstrap_status()" \
  "TO authenticated, service_role" \
  "NOTIFY pgrst, 'reload schema'"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: PR16.9.0 migration missing needle: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq '"puls_app",' <<< "$CONFIG"; then
  echo "FAIL: supabase/config.toml must expose puls_app locally" >&2
  exit 1
fi

for needle in \
  "PR16.9 - App-Wide Notification Center Foundation" \
  "16_9_app_wide_notification_center_strategy.md" \
  "\`puls_app\` app experience schema bootstrap ve exposure smoke" \
  "Optional private realtime enhancement with polling/refetch fallback" \
  "Realtime-only correctness path"; do
  if ! grep -Fq "$needle" <<< "$ROADMAP"; then
    echo "FAIL: roadmap missing PR16.9.0 planning needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.9 app-wide notification center strategy" \
  "16_9_app_wide_notification_center_strategy.md" \
  "puls_app" \
  "PR16.9.0 puls_app bootstrap" \
  "16_9_0_puls_app_bootstrap.md" \
  "20260606170000_puls_app_notification_center_bootstrap.sql" \
  "scripts/verify-16-9-0-puls-app-bootstrap.sh"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR16.9.0 reference: $needle" >&2
    exit 1
  fi
done

for forbidden in \
  "CREATE TABLE puls_app.app_notifications" \
  "CREATE TABLE puls_app.app_notification_reads" \
  "CREATE PUBLICATION" \
  "realtime.broadcast" \
  "supabase_realtime" \
  "GRANT EXECUTE ON FUNCTION puls_app.get_notification_center_bootstrap_status() TO anon" \
  "GRANT USAGE ON SCHEMA puls_app TO anon" \
  "raw_payload', TRUE" \
  "credential_readback', TRUE" \
  "provider_api_calls', TRUE" \
  "field_value_readback', TRUE" \
  "snapshot_payload_readback', TRUE" \
  "external_delivery_enabled', TRUE" \
  "notification_realtime_enabled', TRUE" \
  "UPDATE puls_core." \
  "DELETE FROM puls_core." \
  "INSERT INTO puls_integration."; do
  if grep -Fq "$forbidden" <<< "$MIGRATION$DOC$STRATEGY"; then
    echo "FAIL: PR16.9.0 contains forbidden needle: $forbidden" >&2
    exit 1
  fi
done

for forbidden in \
  "CREATE TABLE puls_app.app_notifications" \
  "CREATE TABLE puls_app.app_notification_reads" \
  "app_notification_preferences" \
  "app_notification_deliveries" \
  "app_notification_subscriptions"; do
  if grep -Fq "$forbidden" <<< "$MIGRATION$DOC"; then
    echo "FAIL: PR16.9.0 bootstrap doc/migration opens future notification object: $forbidden" >&2
    exit 1
  fi
done

if [[ "$REF" == "WORKTREE" ]]; then
  BASE="$(git merge-base origin/main HEAD)"
  CHANGED_FILES="$(
    git diff --name-only "$BASE"
    git ls-files --others --exclude-standard
  )"
else
  BASE="$(git merge-base origin/main "$REF")"
  CHANGED_FILES="$(git diff --name-only "$BASE...$REF")"
fi

if [[ -n "$CHANGED_FILES" ]]; then
  while IFS= read -r changed; do
    [[ -z "$changed" ]] && continue
    if [[ "$REF" == "WORKTREE" && "$changed" == supabase/.temp/* ]]; then
      continue
    fi
    if [[ "$REF" == "WORKTREE" && "$changed" == supabase/.branches/* ]]; then
      continue
    fi

    case "$changed" in
      docs/product/15_16_connector_runtime_ai_roadmap.md) ;;
      docs/product/16_9_0_puls_app_bootstrap.md) ;;
      docs/product/16_9_app_wide_notification_center_strategy.md) ;;
      docs/product/README.md) ;;
      scripts/verify-16-9-0-puls-app-bootstrap.sh) ;;
      supabase/config.toml) ;;
      supabase/migrations/20260606170000_puls_app_notification_center_bootstrap.sql) ;;
      *)
        echo "FAIL: unexpected changed path for PR16.9.0 puls_app bootstrap: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

echo "PR16.9.0 puls_app bootstrap verification passed."
