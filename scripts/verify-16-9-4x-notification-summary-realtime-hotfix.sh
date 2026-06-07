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

echo "Checking ${REF}: PR16.9.4x notification summary realtime hotfix ..."

MIGRATION="$(file_at_ref supabase/migrations/20260607114500_puls_app_notification_summary_realtime_hotfix.sql)"
DOC="$(file_at_ref docs/product/16_9_4x_notification_summary_realtime_hotfix.md)"
TEST="$(file_at_ref src/lib/data/app/notifications.test.ts)"
README="$(file_at_ref docs/product/README.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
MIGRATION_FLAT="$(tr '\n' ' ' <<< "$MIGRATION")"

for needle in \
  "CREATE OR REPLACE FUNCTION puls_app.get_app_notification_summary" \
  "pr16.9.4-notification-realtime-fallback-v1" \
  "TRUE AS notification_realtime_enabled" \
  "FALSE AS external_delivery_enabled" \
  "notification_polling_fallback_enabled', TRUE" \
  "notification_realtime_private_channel_enabled', TRUE" \
  "notification_realtime_payload_minimal', TRUE" \
  "realtime_required', FALSE" \
  "plan_notification_preferences_pr16_9_5" \
  "NOTIFY pgrst, 'reload schema'"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: hotfix migration missing needle: $needle" >&2
    exit 1
  fi
done

for forbidden in \
  "external_delivery_enabled', TRUE" \
  "raw_payload_readback', TRUE" \
  "field_value_readback', TRUE" \
  "snapshot_payload_readback', TRUE" \
  "provider_response_readback', TRUE" \
  "credential_readback', TRUE" \
  "safe_summary', notification.safe_summary" \
  "'raw_payload'," \
  "'provider_response'," \
  "'credential_value'," \
  "'before_value'," \
  "'after_value'," \
  "'snapshot_payload',"; do
  if grep -Fq "$forbidden" <<< "$MIGRATION"; then
    echo "FAIL: hotfix migration contains forbidden needle: $forbidden" >&2
    exit 1
  fi
done

for forbidden_regex in \
  "GRANT[[:space:]]+SELECT[[:space:]]+ON[[:space:]]+TABLE[[:space:]]+puls_app\\.app_notifications[^;]*TO[^;]*authenticated" \
  "GRANT[[:space:]]+INSERT[[:space:]]+ON[[:space:]]+TABLE[[:space:]]+puls_app\\.app_notifications[^;]*TO[^;]*authenticated" \
  "GRANT[[:space:]]+INSERT[[:space:]]+ON[[:space:]]+TABLE[[:space:]]+realtime\\.messages[^;]*TO[^;]*authenticated"; do
  if grep -Eq "$forbidden_regex" <<< "$MIGRATION_FLAT"; then
    echo "FAIL: hotfix migration opens a forbidden grant: $forbidden_regex" >&2
    exit 1
  fi
done

for needle in \
  "PR16.9.4x Notification Summary Realtime Hotfix" \
  "polling-only mode" \
  "notification_realtime_enabled = true" \
  "external_delivery_enabled = false" \
  "Console has no notification RPC 406 errors"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: hotfix doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "notification_realtime_enabled: true" \
  "notificationRealtimeEnabled: true" \
  "notification_polling_fallback_enabled: true"; do
  if ! grep -Fq "$needle" <<< "$TEST"; then
    echo "FAIL: notification adapter test missing hotfix needle: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR16.9.4x notification summary realtime hotfix" <<< "$README"; then
  echo "FAIL: README missing hotfix reference" >&2
  exit 1
fi

if ! grep -Fq "PR16.9.4x aligns the summary RPC realtime flag" <<< "$ROADMAP"; then
  echo "FAIL: roadmap missing hotfix reference" >&2
  exit 1
fi

echo "PR16.9.4x notification summary realtime hotfix verification passed."
