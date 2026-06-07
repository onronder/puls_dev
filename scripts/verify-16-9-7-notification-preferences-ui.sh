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

echo "Checking ${REF}: PR16.9.7 notification preferences UI ..."

DOC="$(file_at_ref docs/product/16_9_7_notification_preferences_ui.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
MIGRATION="$(file_at_ref supabase/migrations/20260607150000_puls_app_notification_preferences_ui_contract.sql)"
NOTIFICATION_CENTER="$(file_at_ref src/components/notifications/AppNotificationCenter.tsx)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"
MIGRATION_FLAT="$(tr '\n' ' ' <<< "$MIGRATION")"

for needle in \
  "PR16.9.7 Notification Preferences UI" \
  "connector_runtime/all" \
  "Critical notifications always stay visible" \
  "No new authenticated table access" \
  "Browser smoke" \
  "Do not create domain-specific notification systems"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.9.7 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "CREATE OR REPLACE FUNCTION puls_app.get_notification_center_bootstrap_status" \
  "pr16.9.7-notification-preferences-ui-v1" \
  "notification_preferences_ui_enabled', TRUE" \
  "notification_preference_first_scope', 'connector_runtime/all'" \
  "critical_notifications_always_visible', TRUE" \
  "external_delivery_enabled', FALSE" \
  "push_delivery_enabled', FALSE" \
  "GRANT EXECUTE ON FUNCTION puls_app.get_notification_center_bootstrap_status()" \
  "NOTIFY pgrst, 'reload schema'"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: PR16.9.7 migration missing needle: $needle" >&2
    exit 1
  fi
done

for forbidden_regex in \
  "GRANT[[:space:]]+SELECT[[:space:]]+ON[[:space:]]+TABLE[[:space:]]+puls_app\\.app_notifications[^;]*TO[^;]*authenticated" \
  "GRANT[[:space:]]+INSERT[[:space:]]+ON[[:space:]]+TABLE[[:space:]]+puls_app\\.app_notifications[^;]*TO[^;]*authenticated" \
  "GRANT[[:space:]]+SELECT[[:space:]]+ON[[:space:]]+TABLE[[:space:]]+puls_app\\.app_notification_preferences[^;]*TO[^;]*authenticated" \
  "GRANT[[:space:]]+INSERT[[:space:]]+ON[[:space:]]+TABLE[[:space:]]+puls_app\\.app_notification_preferences[^;]*TO[^;]*authenticated"; do
  if grep -Eq "$forbidden_regex" <<< "$MIGRATION_FLAT"; then
    echo "FAIL: PR16.9.7 migration opens forbidden authenticated access: $forbidden_regex" >&2
    exit 1
  fi
done

for forbidden in \
  "external_delivery_enabled', TRUE" \
  "email_delivery_enabled', TRUE" \
  "push_delivery_enabled', TRUE" \
  "provider_api_calls', TRUE" \
  "source_writeback', TRUE" \
  "credential_readback', TRUE" \
  "raw_payload_readback', TRUE" \
  "field_value_readback', TRUE" \
  "snapshot_payload_readback', TRUE" \
  "CREATE TRIGGER"; do
  if grep -Fq "$forbidden" <<< "$MIGRATION"; then
    echo "FAIL: PR16.9.7 migration contains forbidden needle: $forbidden" >&2
    exit 1
  fi
done

for needle in \
  "NotificationPreferencesPanel" \
  "fetchAppNotificationPreferences" \
  "upsertAppNotificationPreference" \
  "clearAppNotificationPreference" \
  "preferenceScopes" \
  "connector_runtime" \
  "minimumSeverity" \
  "actionRequiredOnly" \
  "mutedUntilForMode" \
  "notifications.preferences.criticalNote"; do
  if ! grep -Fq "$needle" <<< "$NOTIFICATION_CENTER"; then
    echo "FAIL: Notification Center missing PR16.9.7 needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "Bildirim ayarları" \
  "Uygulama içi bildirimleri kaynak bazında yönet." \
  "ERP bağlantısı" \
  "Kritik bildirimler güvenlik nedeniyle her zaman görünür kalır" \
  "Varsayılana dön"; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing PR16.9.7 copy: $needle" >&2
    exit 1
  fi
done

for needle in \
  "Notification settings" \
  "Manage in-app notifications by source." \
  "ERP connection" \
  "Critical notifications always stay visible for safety" \
  "Reset defaults"; do
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing PR16.9.7 copy: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR16.9.7 exposes the in-app preference contract" <<< "$ROADMAP"; then
  echo "FAIL: roadmap missing PR16.9.7 implementation status" >&2
  exit 1
fi

if ! grep -Fq "PR16.9.7 notification preferences UI" <<< "$README"; then
  echo "FAIL: README missing PR16.9.7 section" >&2
  exit 1
fi

echo "PR16.9.7 notification preferences UI verification passed."
