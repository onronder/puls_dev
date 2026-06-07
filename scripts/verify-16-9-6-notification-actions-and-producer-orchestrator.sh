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

echo "Checking ${REF}: PR16.9.6 notification actions and producer orchestrator ..."

DOC="$(file_at_ref docs/product/16_9_6_notification_actions_and_producer_orchestrator.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
MIGRATION="$(file_at_ref supabase/migrations/20260607133000_puls_app_notification_actions_and_producer_orchestrator.sql)"
ACTION_HELPER="$(file_at_ref src/lib/notifications/app-notification-actions.ts)"
ACTION_TEST="$(file_at_ref src/lib/notifications/app-notification-actions.test.ts)"
NOTIFICATION_CENTER="$(file_at_ref src/components/notifications/AppNotificationCenter.tsx)"
ERP_ROUTE="$(file_at_ref src/routes/_app/erp.tsx)"
WORKER="$(file_at_ref services/erp-connector/src/worker.ts)"
WORKER_TEST="$(file_at_ref services/erp-connector/src/worker.test.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"
MIGRATION_FLAT="$(tr '\n' ' ' <<< "$MIGRATION")"

for needle in \
  "PR16.9.6 Notification Actions And Producer Orchestrator" \
  "run_app_notification_producers" \
  "Known ERP events show" \
  "Unknown ERP error events show only the CSV issue export" \
  "DB triggers are intentionally avoided" \
  "Worker notification refresh is best-effort" \
  "Browser smoke"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.9.6 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "CREATE OR REPLACE FUNCTION puls_app.run_app_notification_producers" \
  "pr16.9.6-notification-action-routing-v1" \
  "notification_action_routing_enabled', TRUE" \
  "notification_error_csv_export_enabled', TRUE" \
  "notification_producer_orchestrator_enabled', TRUE" \
  "notification_worker_refresh_enabled', TRUE" \
  "GRANT EXECUTE ON FUNCTION puls_app.run_app_notification_producers" \
  "TO service_role" \
  "NOTIFY pgrst, 'reload schema'"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: PR16.9.6 migration missing needle: $needle" >&2
    exit 1
  fi
done

for forbidden_regex in \
  "GRANT[[:space:]]+EXECUTE[[:space:]]+ON[[:space:]]+FUNCTION[[:space:]]+puls_app\\.run_app_notification_producers[^;]*TO[^;]*authenticated" \
  "GRANT[[:space:]]+SELECT[[:space:]]+ON[[:space:]]+TABLE[[:space:]]+puls_app\\.app_notifications[^;]*TO[^;]*authenticated" \
  "GRANT[[:space:]]+INSERT[[:space:]]+ON[[:space:]]+TABLE[[:space:]]+puls_app\\.app_notifications[^;]*TO[^;]*authenticated"; do
  if grep -Eq "$forbidden_regex" <<< "$MIGRATION_FLAT"; then
    echo "FAIL: PR16.9.6 migration opens forbidden authenticated access: $forbidden_regex" >&2
    exit 1
  fi
done

for forbidden in \
  "external_delivery_enabled', TRUE" \
  "provider_api_calls', TRUE" \
  "source_writeback', TRUE" \
  "credential_readback', TRUE" \
  "raw_payload_readback', TRUE" \
  "field_value_readback', TRUE" \
  "snapshot_payload_readback', TRUE" \
  "CREATE TRIGGER"; do
  if grep -Fq "$forbidden" <<< "$MIGRATION"; then
    echo "FAIL: PR16.9.6 migration contains forbidden needle: $forbidden" >&2
    exit 1
  fi
done

for needle in \
  "connectorRuntimeEventTargets" \
  "erp-runtime-queue" \
  "erp-controlled-apply" \
  "erp-guarded-update-rollback-preview" \
  "erp-guarded-update-rollback-approval" \
  "erp-guarded-update-rollback-worker-readiness" \
  "erp-guarded-update-rollback-worker-apply" \
  "buildAppNotificationIssueCsv" \
  "resolveAppNotificationAction"; do
  if ! grep -Fq "$needle" <<< "$ACTION_HELPER"; then
    echo "FAIL: action helper missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "unknown ERP error notifications" \
  "safe issue CSV" \
  "erp-runtime-queue" \
  "erp-guarded-update-rollback-worker-readiness"; do
  if ! grep -Fq "$needle" <<< "$ACTION_TEST"; then
    echo "FAIL: action tests missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "resolveAppNotificationAction" \
  "buildAppNotificationIssueCsv" \
  "notifications.center.exportIssueCsv" \
  "onExportIssue"; do
  if ! grep -Fq "$needle" <<< "$NOTIFICATION_CENTER"; then
    echo "FAIL: Notification Center missing PR16.9.6 needle: $needle" >&2
    exit 1
  fi
done

if grep -Fq "onClick={() => onNavigate(notification)}" <<< "$NOTIFICATION_CENTER"; then
  echo "FAIL: generic notification navigate action returned" >&2
  exit 1
fi

for needle in \
  "validateSearch: erpSearchSchema" \
  "tab: z.enum" \
  "focus: z.string().regex" \
  "Route.useSearch" \
  "document.getElementById(routeSearch.focus)?.scrollIntoView"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route missing deep-link needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorWorkerRpcSchema = 'puls_integration' | 'puls_app'" \
  "run_app_notification_producers" \
  "refreshConnectorAppNotificationsAfterJob" \
  "schema: ConnectorWorkerRpcSchema" \
  "'puls_app'"; do
  if ! grep -Fq "$needle" <<< "$WORKER"; then
    echo "FAIL: worker missing producer orchestration needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "puls_app schema profile" \
  "refreshes app notification producers after real connector jobs" \
  "does not refresh app notification producers for noop health checks"; do
  if ! grep -Fq "$needle" <<< "$WORKER_TEST"; then
    echo "FAIL: worker tests missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "Sürece git" \
  "Hatayı paylaş" \
  "ERP bağlantı işlemi başarısız oldu" \
  "Canlı bağlantı kontrolü başarısız"; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing user-friendly notification copy: $needle" >&2
    exit 1
  fi
done

for needle in \
  "Go to process" \
  "Share issue" \
  "ERP connection task failed" \
  "Live connection check failed"; do
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing user-friendly notification copy: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR16.9.6 implements notification action routing" <<< "$ROADMAP"; then
  echo "FAIL: roadmap missing PR16.9.6 reference" >&2
  exit 1
fi

if ! grep -Fq "PR16.9.6 notification actions and producer orchestrator" <<< "$README"; then
  echo "FAIL: README missing PR16.9.6 reference" >&2
  exit 1
fi

echo "PR16.9.6 notification actions and producer orchestrator verification passed."
