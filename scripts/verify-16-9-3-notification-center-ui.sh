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

echo "Checking ${REF}: PR16.9.3 notification center UI ..."

DOC="$(file_at_ref docs/product/16_9_3_notification_center_ui.md)"
STRATEGY="$(file_at_ref docs/product/16_9_app_wide_notification_center_strategy.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
MIGRATION="$(file_at_ref supabase/migrations/20260607100000_puls_app_notification_center_ui_readiness.sql)"
ADAPTER="$(file_at_ref src/lib/data/app/notifications.ts)"
ADAPTER_TEST="$(file_at_ref src/lib/data/app/notifications.test.ts)"
CENTER="$(file_at_ref src/components/notifications/AppNotificationCenter.tsx)"
HEADER="$(file_at_ref src/components/layout/AppHeader.tsx)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"
MIGRATION_FLAT="$(tr '\n' ' ' <<< "$MIGRATION")"

for needle in \
  "global shell notification bell" \
  "Read/unread/dismiss actions" \
  "UI has production-ready loading, empty, error, and filtered states"; do
  if ! grep -Fq "$needle" <<< "$STRATEGY"; then
    echo "FAIL: strategy missing UI needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.9.3 Notification Center UI" \
  "list_app_notifications_page" \
  "global shell notification bell" \
  "detail view inside the pane" \
  "Capacitor / Mobile Requirements" \
  "Realtime is not required for correctness" \
  "Handoff To PR16.9.4"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.9.3 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "CREATE OR REPLACE FUNCTION puls_app.list_app_notifications_page" \
  "PULS_APP_NOTIFICATION_FILTER_INVALID" \
  "PULS_APP_NOTIFICATION_CURSOR_INVALID" \
  "pr16.9.3-notification-center-ui-v1" \
  "notification_center_ui_enabled" \
  "notification_cursor_paging_enabled" \
  "notification_detail_pane_enabled" \
  "add_notification_realtime_pr16_9_4" \
  "REVOKE ALL ON FUNCTION puls_app.list_app_notifications_page" \
  "GRANT EXECUTE ON FUNCTION puls_app.list_app_notifications_page" \
  "TO authenticated, service_role" \
  "NOTIFY pgrst, 'reload schema'"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: PR16.9.3 migration missing needle: $needle" >&2
    exit 1
  fi
done

for forbidden in \
  "CREATE TABLE IF NOT EXISTS puls_app.app_notification_preferences" \
  "CREATE TABLE IF NOT EXISTS puls_app.app_notification_deliveries" \
  "CREATE TABLE IF NOT EXISTS puls_app.app_notification_subscriptions" \
  "CREATE PUBLICATION" \
  "supabase_realtime" \
  "realtime.broadcast" \
  "external_delivery_enabled', TRUE" \
  "notification_realtime_enabled', TRUE" \
  "email_delivery_enabled', TRUE" \
  "push_delivery_enabled', TRUE" \
  "raw_payload_readback', TRUE" \
  "field_value_readback', TRUE" \
  "snapshot_payload_readback', TRUE"; do
  if grep -Fq "$forbidden" <<< "$MIGRATION"; then
    echo "FAIL: PR16.9.3 migration contains forbidden needle: $forbidden" >&2
    exit 1
  fi
done

for forbidden_regex in \
  "GRANT[[:space:]]+SELECT[[:space:]]+ON[[:space:]]+TABLE[[:space:]]+puls_app\\.app_notifications[^;]*TO[^;]*authenticated" \
  "GRANT[[:space:]]+INSERT[[:space:]]+ON[[:space:]]+TABLE[[:space:]]+puls_app\\.app_notifications[^;]*TO[^;]*authenticated" \
  "GRANT[[:space:]]+UPDATE[[:space:]]+ON[[:space:]]+TABLE[[:space:]]+puls_app\\.app_notification_reads[^;]*TO[^;]*authenticated"; do
  if grep -Eq "$forbidden_regex" <<< "$MIGRATION_FLAT"; then
    echo "FAIL: PR16.9.3 migration opens a forbidden authenticated grant: $forbidden_regex" >&2
    exit 1
  fi
done

for needle in \
  "export const pulsApp = () => supabase.schema('puls_app')" \
  "fetchAppNotificationSummary" \
  "fetchAppNotificationPage" \
  "markAppNotificationRead" \
  "markAllAppNotificationsRead" \
  "dismissAppNotification" \
  "list_app_notifications_page"; do
  if ! grep -Fq "$needle" <<< "$ADAPTER"; then
    if ! grep -Fq "$needle" <<< "$(file_at_ref src/lib/data/client.ts)"; then
      echo "FAIL: notification adapter/client missing needle: $needle" >&2
      exit 1
    fi
  fi
done

for needle in \
  "AppNotificationCenter" \
  "useInfiniteQuery" \
  "markAllAppNotificationsRead" \
  "dismissAppNotification" \
  "routeForNotification" \
  "formatRelativeTime" \
  "safeSummaryFields" \
  "aria-live"; do
  if ! grep -Fq "$needle" <<< "$CENTER"; then
    echo "FAIL: notification center component missing needle: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "AppNotificationCenter" <<< "$HEADER"; then
  echo "FAIL: AppHeader does not render AppNotificationCenter" >&2
  exit 1
fi

for needle in \
  '"notifications"' \
  '"connectorRuntime"' \
  '"jobFailed"' \
  '"rollbackWorkerReady"' \
  '"center"' \
  '"safeSummary"' \
  '"raw_payload_readback"'; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE" || ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: locale files missing notification needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.9.3 implements the global Notification Center UI" \
  "cursor-paged" \
  "PR16.9.3 notification center UI"; do
  if ! grep -Fq "$needle" <<< "$ROADMAP" && ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: docs index/roadmap missing PR16.9.3 reference: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "fetchAppNotificationPage" <<< "$ADAPTER_TEST"; then
  echo "FAIL: notification adapter test missing page coverage" >&2
  exit 1
fi

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
      docs/product/16_9_3_notification_center_ui.md) ;;
      docs/product/README.md) ;;
      scripts/verify-16-9-3-notification-center-ui.sh) ;;
      supabase/migrations/20260607100000_puls_app_notification_center_ui_readiness.sql) ;;
      src/components/layout/AppHeader.tsx) ;;
      src/components/notifications/AppNotificationCenter.tsx) ;;
      src/i18n/locales/en-US.json) ;;
      src/i18n/locales/tr-TR.json) ;;
      src/lib/data/app/notifications.ts) ;;
      src/lib/data/app/notifications.test.ts) ;;
      src/lib/data/client.ts) ;;
      src/lib/data/index.ts) ;;
      *)
        echo "FAIL: unexpected changed path for PR16.9.3 notification center UI: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

echo "PR16.9.3 notification center UI verification passed."
