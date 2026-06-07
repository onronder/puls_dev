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

echo "Checking ${REF}: PR16.9.4 notification realtime fallback ..."

DOC="$(file_at_ref docs/product/16_9_4_notification_realtime_fallback.md)"
STRATEGY="$(file_at_ref docs/product/16_9_app_wide_notification_center_strategy.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
MIGRATION="$(file_at_ref supabase/migrations/20260607110000_puls_app_notification_realtime_fallback.sql)"
ADAPTER="$(file_at_ref src/lib/data/app/notifications.ts)"
ADAPTER_TEST="$(file_at_ref src/lib/data/app/notifications.test.ts)"
CENTER="$(file_at_ref src/components/notifications/AppNotificationCenter.tsx)"
INDEX="$(file_at_ref src/lib/data/index.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"
MIGRATION_FLAT="$(tr '\n' ' ' <<< "$MIGRATION")"

for needle in \
  "PR16.9.4 - Optional Realtime Enhancement" \
  "Private tenant channel" \
  "Minimal broadcast payload" \
  "Refetch on event" \
  "Polling fallback"; do
  if ! grep -Fq "$needle" <<< "$STRATEGY"; then
    echo "FAIL: strategy missing realtime fallback needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.9.4 Notification Realtime Fallback" \
  "private tenant topics" \
  "realtime.messages" \
  "Broadcast payloads contain only" \
  "polling as the fallback" \
  "Tenant Topic Policy Smoke" \
  "Minimal Payload Contract" \
  "Handoff To PR16.9.5"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.9.4 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "CREATE OR REPLACE FUNCTION puls_app.app_notification_realtime_topic" \
  "CREATE OR REPLACE FUNCTION puls_app.broadcast_app_notification_hint" \
  "realtime.send" \
  "app_notification_hint" \
  "puls_app_app_notifications_realtime_hint" \
  "puls_app_notification_broadcast_select" \
  "realtime.messages.extension = 'broadcast'" \
  "puls_core.current_tenant_id()" \
  "pr16.9.4-notification-realtime-fallback-v1" \
  "notification_realtime_enabled', TRUE" \
  "notification_polling_fallback_enabled', TRUE" \
  "notification_realtime_private_channel_enabled', TRUE" \
  "notification_realtime_payload_minimal', TRUE" \
  "notification_realtime_allowed_payload_keys" \
  "plan_notification_preferences_pr16_9_5" \
  "NOTIFY pgrst, 'reload schema'"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: PR16.9.4 migration missing needle: $needle" >&2
    exit 1
  fi
done

for allowed_key in \
  "notification_id" \
  "source_domain" \
  "source_event_key" \
  "severity" \
  "occurred_at" \
  "count_hint"; do
  if ! grep -Fq "$allowed_key" <<< "$MIGRATION"; then
    echo "FAIL: PR16.9.4 migration missing allowed payload key: $allowed_key" >&2
    exit 1
  fi
done

for forbidden in \
  "realtime.broadcast_changes" \
  "CREATE PUBLICATION" \
  "external_delivery_enabled', TRUE" \
  "email_delivery_enabled', TRUE" \
  "push_delivery_enabled', TRUE" \
  "raw_payload_readback', TRUE" \
  "field_value_readback', TRUE" \
  "snapshot_payload_readback', TRUE" \
  "provider_response_readback', TRUE" \
  "credential_readback', TRUE" \
  "safe_summary', NEW.safe_summary" \
  "raw_payload', NEW" \
  "provider_response', NEW" \
  "credential_value', NEW" \
  "before_value', NEW" \
  "after_value', NEW" \
  "snapshot_payload', NEW"; do
  if grep -Fq "$forbidden" <<< "$MIGRATION"; then
    echo "FAIL: PR16.9.4 migration contains forbidden needle: $forbidden" >&2
    exit 1
  fi
done

for forbidden_regex in \
  "GRANT[[:space:]]+INSERT[[:space:]]+ON[[:space:]]+TABLE[[:space:]]+realtime\\.messages[^;]*TO[^;]*authenticated" \
  "GRANT[[:space:]]+SELECT[[:space:]]+ON[[:space:]]+TABLE[[:space:]]+puls_app\\.app_notifications[^;]*TO[^;]*authenticated" \
  "GRANT[[:space:]]+INSERT[[:space:]]+ON[[:space:]]+TABLE[[:space:]]+puls_app\\.app_notifications[^;]*TO[^;]*authenticated" \
  "GRANT[[:space:]]+UPDATE[[:space:]]+ON[[:space:]]+TABLE[[:space:]]+puls_app\\.app_notification_reads[^;]*TO[^;]*authenticated"; do
  if grep -Eq "$forbidden_regex" <<< "$MIGRATION_FLAT"; then
    echo "FAIL: PR16.9.4 migration opens a forbidden grant: $forbidden_regex" >&2
    exit 1
  fi
done

for needle in \
  "appNotificationRealtimeTopic" \
  "mapAppNotificationRealtimeSignal" \
  "subscribeToAppNotificationSignals" \
  "APP_NOTIFICATION_REALTIME_EVENT = 'app_notification_hint'" \
  "private: true" \
  "broadcast: { self: false, ack: false }" \
  "supabase.realtime.setAuth" \
  "supabase.removeChannel" \
  "'safe_summary'" \
  "'raw_payload'" \
  "'provider_response'" \
  "'credential_value'" \
  "'before_value'" \
  "'after_value'" \
  "'snapshot_payload'"; do
  if ! grep -Fq "$needle" <<< "$ADAPTER"; then
    echo "FAIL: notification adapter missing realtime needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "appNotificationRealtimeTopic" \
  "mapAppNotificationRealtimeSignal" \
  "subscribeToAppNotificationSignals" \
  "AppNotificationRealtimeStatus"; do
  if ! grep -Fq "$needle" <<< "$INDEX"; then
    echo "FAIL: data index missing realtime export: $needle" >&2
    exit 1
  fi
done

for needle in \
  "realtimeStatus" \
  "subscribeToAppNotificationSignals" \
  "notificationRealtimeEnabled" \
  "notifications.center.realtime.connected" \
  "notifications.center.realtime.fallback" \
  "refetchInterval" \
  "invalidateNotifications"; do
  if ! grep -Fq "$needle" <<< "$CENTER"; then
    echo "FAIL: notification center UI missing realtime needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  '"realtime"' \
  '"connected"' \
  '"connecting"' \
  '"fallback"' \
  '"polling"'; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE" || ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: locale files missing realtime status needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "maps only minimal realtime broadcast hints" \
  "subscribes to a private tenant realtime channel" \
  "safe_summary" \
  "credential_value"; do
  if ! grep -Fq "$needle" <<< "$ADAPTER_TEST"; then
    echo "FAIL: notification adapter test missing realtime coverage needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.9.4 adds optional private realtime notification hints" \
  "PR16.9.4 notification realtime fallback"; do
  if ! grep -Fq "$needle" <<< "$ROADMAP" && ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: docs index/roadmap missing PR16.9.4 reference: $needle" >&2
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
      docs/product/16_9_4_notification_realtime_fallback.md) ;;
      docs/product/README.md) ;;
      scripts/verify-16-9-4-notification-realtime-fallback.sh) ;;
      supabase/migrations/20260607110000_puls_app_notification_realtime_fallback.sql) ;;
      src/components/notifications/AppNotificationCenter.tsx) ;;
      src/i18n/locales/en-US.json) ;;
      src/i18n/locales/tr-TR.json) ;;
      src/lib/data/app/notifications.ts) ;;
      src/lib/data/app/notifications.test.ts) ;;
      src/lib/data/index.ts) ;;
      *)
        echo "FAIL: unexpected changed path for PR16.9.4 notification realtime fallback: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

echo "PR16.9.4 notification realtime fallback verification passed."
