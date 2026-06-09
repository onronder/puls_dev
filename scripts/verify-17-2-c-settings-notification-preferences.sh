#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEARCH_BIN="grep -R"
if command -v rg >/dev/null 2>&1; then
  SEARCH_BIN="rg"
fi

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

contains() {
  local file="$1"
  local needle="$2"
  if ! grep -Fq "$needle" "$file"; then
    fail "$file does not contain: $needle"
  fi
}

not_contains() {
  local file="$1"
  local needle="$2"
  if grep -Fq "$needle" "$file"; then
    fail "$file unexpectedly contains: $needle"
  fi
}

PANEL="$ROOT_DIR/src/components/settings/NotificationPreferenceSettingsPanel.tsx"
SETTINGS_ROUTE="$ROOT_DIR/src/routes/_app/ayarlar.tsx"
DOC="$ROOT_DIR/docs/product/17_2_c_settings_notification_preferences.md"
README="$ROOT_DIR/docs/product/README.md"
VERIFY="$ROOT_DIR/scripts/verify-17-2-c-settings-notification-preferences.sh"
TR_LOCALE="$ROOT_DIR/src/i18n/locales/tr-TR.json"
EN_LOCALE="$ROOT_DIR/src/i18n/locales/en-US.json"

echo "Checking PR17.2C settings notification preference contract..."

[[ -f "$PANEL" ]] || fail "Missing settings notification preference panel"
[[ -f "$DOC" ]] || fail "Missing PR17.2C product contract"
[[ -x "$VERIFY" ]] || fail "Verify script must be executable"

contains "$PANEL" "fetchAppNotificationPreferences"
contains "$PANEL" "upsertAppNotificationPreference"
contains "$PANEL" "clearAppNotificationPreference"
contains "$PANEL" "sourceDomain: 'puls_workflow'"
contains "$PANEL" "sourceDomain: 'connector_runtime'"
contains "$PANEL" "minimumSeverity"
contains "$PANEL" "actionRequiredOnly"
contains "$PANEL" "mutedUntilForMode"
contains "$PANEL" "notifications.preferences.criticalNote"
contains "$PANEL" "['app-notifications', 'summary']"
contains "$PANEL" "['app-notifications', 'page']"
contains "$PANEL" "['app-notifications', 'preferences']"

contains "$SETTINGS_ROUTE" "NotificationPreferenceSettingsPanel"
contains "$SETTINGS_ROUTE" "selectedSection.id === 'notifications'"
contains "$SETTINGS_ROUTE" "selectedSection.id !== 'notifications'"

contains "$TR_LOCALE" "Uygulama içi bildirim tercihleri kaynak bazında yönetilebilir"
contains "$EN_LOCALE" "In-app notification preferences can be managed by source"
not_contains "$TR_LOCALE" "Uygulama içi bildirim tercihleri Bildirimler panelinden yönetilir"
not_contains "$EN_LOCALE" "In-app notification preferences are managed from the Notifications panel"

contains "$DOC" "No new database migration"
contains "$DOC" "upsertAppNotificationPreference"
contains "$DOC" "clearAppNotificationPreference"
contains "$README" "PR17.2C Settings notification preferences"
contains "$README" "17_2_c_settings_notification_preferences.md"

if $SEARCH_BIN "17_2_c_settings_notification_preferences" "$ROOT_DIR/supabase/migrations" >/dev/null 2>&1; then
  fail "PR17.2C must not add a database migration"
fi

echo "PR17.2C settings notification preference contract OK."
