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

echo "Checking ${REF}: PR16.9.5 notification scenario coverage ..."

DOC="$(file_at_ref docs/product/16_9_5_notification_scenario_coverage.md)"
STRATEGY="$(file_at_ref docs/product/16_9_app_wide_notification_center_strategy.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
MIGRATION="$(file_at_ref supabase/migrations/20260607123000_puls_app_notification_scenario_coverage.sql)"
ADAPTER="$(file_at_ref src/lib/data/app/notifications.ts)"
ADAPTER_TEST="$(file_at_ref src/lib/data/app/notifications.test.ts)"
INDEX="$(file_at_ref src/lib/data/index.ts)"
MIGRATION_FLAT="$(tr '\n' ' ' <<< "$MIGRATION")"

for needle in \
  "PR16.9.5 Notification Scenario Coverage" \
  "app_notification_preferences" \
  "list_app_notification_preferences" \
  "upsert_app_notification_preference" \
  "clear_app_notification_preference" \
  "list_app_notification_scenario_contracts" \
  "Preference Behavior Smoke" \
  "critical notifications always visible" \
  "External delivery remains closed"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.9.5 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "puls_app.app_notification_preferences" \
  "CREATE OR REPLACE FUNCTION puls_app._app_notification_preference_allows" \
  "CREATE OR REPLACE FUNCTION puls_app.list_app_notification_preferences" \
  "CREATE OR REPLACE FUNCTION puls_app.upsert_app_notification_preference" \
  "CREATE OR REPLACE FUNCTION puls_app.clear_app_notification_preference" \
  "CREATE OR REPLACE FUNCTION puls_app.list_app_notification_scenario_contracts" \
  "CREATE OR REPLACE FUNCTION puls_app.list_app_notifications_page" \
  "CREATE OR REPLACE FUNCTION puls_app.get_app_notification_summary" \
  "CREATE OR REPLACE FUNCTION puls_app.mark_all_app_notifications_read" \
  "pr16.9.5-notification-scenario-coverage-v1" \
  "notification_preferences_enabled', TRUE" \
  "notification_scenario_contracts_enabled', TRUE" \
  "critical_notifications_always_visible', TRUE" \
  "plan_external_notification_delivery_pr16_9_6" \
  "NOTIFY pgrst, 'reload schema'"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: PR16.9.5 migration missing needle: $needle" >&2
    exit 1
  fi
done

for scenario in \
  "empty_inbox" \
  "service_role_emit" \
  "dedupe" \
  "role_visibility" \
  "employee_target" \
  "cursor_paging" \
  "unread_filter" \
  "action_required_filter" \
  "read_state" \
  "dismiss_state" \
  "mark_all_read" \
  "preference_mute" \
  "preference_minimum_severity" \
  "critical_always_visible" \
  "realtime_hint" \
  "safe_summary_guard" \
  "external_delivery_closed"; do
  if ! grep -Fq "$scenario" <<< "$MIGRATION"; then
    echo "FAIL: PR16.9.5 migration missing scenario: $scenario" >&2
    exit 1
  fi
done

for forbidden in \
  "CREATE TABLE IF NOT EXISTS puls_app.app_notification_deliveries" \
  "CREATE TABLE IF NOT EXISTS puls_app.app_notification_subscriptions" \
  "external_delivery_enabled', TRUE" \
  "email_delivery_enabled', TRUE" \
  "push_delivery_enabled', TRUE" \
  "sms_delivery_enabled', TRUE" \
  "slack_delivery_enabled', TRUE" \
  "provider_response_readback', TRUE" \
  "credential_readback', TRUE" \
  "raw_payload_readback', TRUE" \
  "field_value_readback', TRUE" \
  "snapshot_payload_readback', TRUE" \
  "'raw_payload'," \
  "'provider_response'," \
  "'credential_value'," \
  "'before_value'," \
  "'after_value'," \
  "'snapshot_payload',"; do
  if grep -Fq "$forbidden" <<< "$MIGRATION"; then
    echo "FAIL: PR16.9.5 migration contains forbidden needle: $forbidden" >&2
    exit 1
  fi
done

for forbidden_regex in \
  "GRANT[[:space:]]+SELECT[[:space:]]+ON[[:space:]]+TABLE[[:space:]]+puls_app\\.app_notifications[^;]*TO[^;]*authenticated" \
  "GRANT[[:space:]]+INSERT[[:space:]]+ON[[:space:]]+TABLE[[:space:]]+puls_app\\.app_notifications[^;]*TO[^;]*authenticated" \
  "GRANT[[:space:]]+SELECT[[:space:]]+ON[[:space:]]+TABLE[[:space:]]+puls_app\\.app_notification_preferences[^;]*TO[^;]*authenticated" \
  "GRANT[[:space:]]+INSERT[[:space:]]+ON[[:space:]]+TABLE[[:space:]]+puls_app\\.app_notification_preferences[^;]*TO[^;]*authenticated" \
  "GRANT[[:space:]]+UPDATE[[:space:]]+ON[[:space:]]+TABLE[[:space:]]+puls_app\\.app_notification_preferences[^;]*TO[^;]*authenticated"; do
  if grep -Eq "$forbidden_regex" <<< "$MIGRATION_FLAT"; then
    echo "FAIL: PR16.9.5 migration opens a forbidden authenticated table grant: $forbidden_regex" >&2
    exit 1
  fi
done

for needle in \
  "AppNotificationPreference" \
  "AppNotificationScenarioContract" \
  "fetchAppNotificationPreferences" \
  "upsertAppNotificationPreference" \
  "clearAppNotificationPreference" \
  "fetchAppNotificationScenarioContracts"; do
  if ! grep -Fq "$needle" <<< "$ADAPTER"; then
    echo "FAIL: notification adapter missing PR16.9.5 needle: $needle" >&2
    exit 1
  fi
  if ! grep -Fq "$needle" <<< "$INDEX"; then
    echo "FAIL: data index missing PR16.9.5 export: $needle" >&2
    exit 1
  fi
done

for needle in \
  "maps notification preferences" \
  "upsert_app_notification_preference" \
  "clear_app_notification_preference" \
  "maps scenario contracts" \
  "list_app_notification_scenario_contracts"; do
  if ! grep -Fq "$needle" <<< "$ADAPTER_TEST"; then
    echo "FAIL: notification adapter tests missing PR16.9.5 needle: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "Optional future objects can include" <<< "$STRATEGY"; then
  echo "FAIL: strategy context unexpectedly missing preferences section" >&2
  exit 1
fi

if ! grep -Fq "PR16.9.5 implements notification scenario coverage" <<< "$ROADMAP"; then
  echo "FAIL: roadmap missing PR16.9.5 reference" >&2
  exit 1
fi

if ! grep -Fq "PR16.9.5 notification scenario coverage" <<< "$README"; then
  echo "FAIL: README missing PR16.9.5 reference" >&2
  exit 1
fi

echo "PR16.9.5 notification scenario coverage verification passed."
