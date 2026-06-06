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

echo "Checking ${REF}: PR16.9.1 durable notification ledger ..."

DOC="$(file_at_ref docs/product/16_9_1_durable_notification_ledger.md)"
STRATEGY="$(file_at_ref docs/product/16_9_app_wide_notification_center_strategy.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
MIGRATION="$(file_at_ref supabase/migrations/20260606180000_puls_app_notification_ledger.sql)"
MIGRATION_FLAT="$(tr '\n' ' ' <<< "$MIGRATION")"

for needle in \
  "PR16.9 App-Wide Notification Center Strategy" \
  "PR16.9.1 - Durable Notification Ledger" \
  "app_notifications" \
  "app_notification_reads" \
  'Service-role `emit` RPC' \
  "Dedupe key prevents duplicate notifications" \
  "Direct authenticated table writes remain closed"; do
  if ! grep -Fq "$needle" <<< "$STRATEGY"; then
    echo "FAIL: PR16.9 strategy missing durable ledger needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.9.1 Durable Notification Ledger" \
  "pr16.9.1-app-notification-ledger-v1" \
  "app_notifications" \
  "app_notification_reads" \
  "list_app_notifications" \
  "get_app_notification_summary" \
  "mark_app_notification_read" \
  "mark_all_app_notifications_read" \
  "dismiss_app_notification" \
  "emit_app_notification" \
  'authenticated table privileges are `false`' \
  "PULS_APP_NOTIFICATION_SAFE_SUMMARY_BLOCKED_KEY" \
  "Handoff To PR16.9.2"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.9.1 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "CREATE TABLE IF NOT EXISTS puls_app.app_notifications" \
  "CREATE TABLE IF NOT EXISTS puls_app.app_notification_reads" \
  "CONSTRAINT app_notifications_tenant_dedupe_unique UNIQUE (tenant_id, dedupe_key)" \
  "CONSTRAINT app_notification_reads_notification_employee_unique UNIQUE (notification_id, employee_id)" \
  "_app_notification_safe_summary_has_blocked_key" \
  "_app_notification_target_visible" \
  "reject_app_notification_mutation" \
  "PULS_APP_NOTIFICATION_IMMUTABLE" \
  "emit_app_notification" \
  "ON CONFLICT ON CONSTRAINT app_notifications_tenant_dedupe_unique DO NOTHING" \
  "list_app_notifications" \
  "get_app_notification_summary" \
  "mark_app_notification_read" \
  "mark_all_app_notifications_read" \
  "dismiss_app_notification" \
  "PULS_APP_NOTIFICATION_SAFE_SUMMARY_BLOCKED_KEY" \
  "PULS_APP_NOTIFICATION_EMIT_SERVICE_ROLE_REQUIRED" \
  "PULS_APP_NOTIFICATION_TENANT_REQUIRED" \
  "PULS_APP_NOTIFICATION_EMPLOYEE_REQUIRED" \
  "map_connector_notifications_pr16_9_2" \
  "ALTER TABLE puls_app.app_notifications ENABLE ROW LEVEL SECURITY" \
  "ALTER TABLE puls_app.app_notification_reads ENABLE ROW LEVEL SECURITY" \
  "CREATE POLICY puls_app_notifications_service_role" \
  "CREATE POLICY puls_app_notification_reads_service_role" \
  "REVOKE ALL ON TABLE puls_app.app_notifications" \
  "FROM PUBLIC, anon, authenticated, service_role" \
  "GRANT SELECT, INSERT ON TABLE puls_app.app_notifications" \
  "GRANT SELECT, INSERT, UPDATE ON TABLE puls_app.app_notification_reads" \
  "GRANT EXECUTE ON FUNCTION puls_app.emit_app_notification" \
  "TO service_role" \
  "GRANT EXECUTE ON FUNCTION puls_app.list_app_notifications" \
  "TO authenticated, service_role" \
  "NOTIFY pgrst, 'reload schema'"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: PR16.9.1 migration missing needle: $needle" >&2
    exit 1
  fi
done

for forbidden in \
  "CREATE PUBLICATION" \
  "supabase_realtime" \
  "realtime.broadcast" \
  "app_notification_preferences" \
  "app_notification_deliveries" \
  "app_notification_subscriptions" \
  "GRANT USAGE ON SCHEMA puls_app TO anon" \
  "raw_payload', TRUE" \
  "credential_readback', TRUE" \
  "provider_api_calls', TRUE" \
  "field_value_readback', TRUE" \
  "snapshot_payload_readback', TRUE" \
  "external_delivery_enabled', TRUE" \
  "notification_realtime_enabled', TRUE" \
  "email_delivery_enabled', TRUE" \
  "push_delivery_enabled', TRUE"; do
  if grep -Fq "$forbidden" <<< "$MIGRATION"; then
    echo "FAIL: PR16.9.1 migration contains forbidden needle: $forbidden" >&2
    exit 1
  fi
done

for forbidden_regex in \
  "GRANT[[:space:]]+SELECT[[:space:]]+ON[[:space:]]+TABLE[[:space:]]+puls_app\\.app_notifications[^;]*TO[^;]*authenticated" \
  "GRANT[[:space:]]+INSERT[[:space:]]+ON[[:space:]]+TABLE[[:space:]]+puls_app\\.app_notifications[^;]*TO[^;]*authenticated" \
  "GRANT[[:space:]]+INSERT[[:space:]]+ON[[:space:]]+TABLE[[:space:]]+puls_app\\.app_notification_reads[^;]*TO[^;]*authenticated" \
  "GRANT[[:space:]]+EXECUTE[[:space:]]+ON[[:space:]]+FUNCTION[[:space:]]+puls_app\\.emit_app_notification[^;]*TO[^;]*authenticated"; do
  if grep -Eq "$forbidden_regex" <<< "$MIGRATION_FLAT"; then
    echo "FAIL: PR16.9.1 migration opens a forbidden authenticated grant: $forbidden_regex" >&2
    exit 1
  fi
done

for needle in \
  "PR16.9.1 implements the durable app-wide notification ledger" \
  "producer mapping, UI, realtime, and delivery remain closed until later PR16.9 sub-phases"; do
  if ! grep -Fq "$needle" <<< "$ROADMAP"; then
    echo "FAIL: roadmap missing PR16.9.1 reference: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.9.1 durable notification ledger" \
  "16_9_1_durable_notification_ledger.md" \
  "20260606180000_puls_app_notification_ledger.sql" \
  "scripts/verify-16-9-1-durable-notification-ledger.sh"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR16.9.1 reference: $needle" >&2
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
      docs/product/16_9_1_durable_notification_ledger.md) ;;
      docs/product/README.md) ;;
      scripts/verify-16-9-1-durable-notification-ledger.sh) ;;
      supabase/migrations/20260606180000_puls_app_notification_ledger.sql) ;;
      *)
        echo "FAIL: unexpected changed path for PR16.9.1 durable notification ledger: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

echo "PR16.9.1 durable notification ledger verification passed."
