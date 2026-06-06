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

echo "Checking ${REF}: PR16.9.2 connector notification producers ..."

DOC="$(file_at_ref docs/product/16_9_2_connector_notification_producers.md)"
STRATEGY="$(file_at_ref docs/product/16_9_app_wide_notification_center_strategy.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
MIGRATION="$(file_at_ref supabase/migrations/20260606190000_puls_app_connector_notification_producers.sql)"
MIGRATION_FLAT="$(tr '\n' ' ' <<< "$MIGRATION")"

for needle in \
  "PR16.9.2 - Connector Producer Mapping" \
  "refresh_connector_app_notifications" \
  "PR16.8 rollback success emits one notification" \
  "Dead-letter/failure emits action-required notification" \
  "Payload has no raw values or secrets"; do
  if ! grep -Fq "$needle" <<< "$STRATEGY"; then
    echo "FAIL: PR16.9 strategy missing connector producer needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.9.2 Connector Notification Producers" \
  "pr16.9.2-connector-notification-producer-v1" \
  "refresh_connector_app_notifications" \
  "emit_app_notification" \
  "connector_job_failed" \
  "connector_job_dead_letter" \
  "runtime_preflight_failed" \
  "import_apply_rollback_completed" \
  "import_apply_rollback_preview_ready" \
  "service-role only" \
  'Safe summaries do not copy `safe_error_context`' \
  "Handoff To PR16.9.3"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.9.2 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "CREATE OR REPLACE FUNCTION puls_app.refresh_connector_app_notifications" \
  "PULS_APP_CONNECTOR_NOTIFICATION_REFRESH_SERVICE_ROLE_REQUIRED" \
  "puls_app.emit_app_notification" \
  "connector_job_failed" \
  "connector_job_dead_letter" \
  "runtime_preflight_failed" \
  "import_apply_create_only_completed" \
  "import_apply_guarded_update_completed" \
  "import_apply_rollback_completed" \
  "import_apply_rollback_preview_ready" \
  "import_apply_rollback_approval_recorded" \
  "import_apply_rollback_worker_ready" \
  "pr16.9.2-connector-notification-producer-v1" \
  "connector_producer_mapping_enabled" \
  "implement_notification_center_ui_pr16_9_3" \
  "REVOKE ALL ON FUNCTION puls_app.refresh_connector_app_notifications" \
  "FROM PUBLIC, anon, authenticated, service_role" \
  "GRANT EXECUTE ON FUNCTION puls_app.refresh_connector_app_notifications" \
  "TO service_role" \
  "NOTIFY pgrst, 'reload schema'"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: PR16.9.2 migration missing needle: $needle" >&2
    exit 1
  fi
done

for forbidden in \
  "CREATE TABLE IF NOT EXISTS puls_app.app_notifications" \
  "CREATE TABLE IF NOT EXISTS puls_app.app_notification_reads" \
  "CREATE TABLE IF NOT EXISTS puls_app.app_notification_preferences" \
  "CREATE TABLE IF NOT EXISTS puls_app.app_notification_deliveries" \
  "CREATE TABLE IF NOT EXISTS puls_app.app_notification_subscriptions" \
  "CREATE PUBLICATION" \
  "supabase_realtime" \
  "realtime.broadcast" \
  "safe_error_context" \
  "provider_response', TRUE" \
  "external_delivery_enabled', TRUE" \
  "notification_realtime_enabled', TRUE" \
  "email_delivery_enabled', TRUE" \
  "push_delivery_enabled', TRUE" \
  "raw_payload_readback', TRUE" \
  "field_value_readback', TRUE" \
  "snapshot_payload_readback', TRUE"; do
  if grep -Fq "$forbidden" <<< "$MIGRATION"; then
    echo "FAIL: PR16.9.2 migration contains forbidden needle: $forbidden" >&2
    exit 1
  fi
done

for forbidden_regex in \
  "GRANT[[:space:]]+EXECUTE[[:space:]]+ON[[:space:]]+FUNCTION[[:space:]]+puls_app\\.refresh_connector_app_notifications[^;]*TO[^;]*authenticated" \
  "GRANT[[:space:]]+SELECT[[:space:]]+ON[[:space:]]+TABLE[[:space:]]+puls_app\\.app_notifications[^;]*TO[^;]*authenticated" \
  "GRANT[[:space:]]+INSERT[[:space:]]+ON[[:space:]]+TABLE[[:space:]]+puls_app\\.app_notifications[^;]*TO[^;]*authenticated"; do
  if grep -Eq "$forbidden_regex" <<< "$MIGRATION_FLAT"; then
    echo "FAIL: PR16.9.2 migration opens a forbidden authenticated grant: $forbidden_regex" >&2
    exit 1
  fi
done

for needle in \
  "PR16.9.2 implements connector producer mapping through a service-role refresh boundary" \
  "UI, realtime, and delivery remain closed until later PR16.9 sub-phases" \
  "PR16.9.2 connector producer refresh is service-role only and idempotent"; do
  if ! grep -Fq "$needle" <<< "$ROADMAP"; then
    echo "FAIL: roadmap missing PR16.9.2 reference: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.9.2 connector notification producers" \
  "16_9_2_connector_notification_producers.md" \
  "20260606190000_puls_app_connector_notification_producers.sql" \
  "scripts/verify-16-9-2-connector-notification-producers.sh"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR16.9.2 reference: $needle" >&2
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
      docs/product/16_9_2_connector_notification_producers.md) ;;
      docs/product/README.md) ;;
      scripts/verify-16-9-2-connector-notification-producers.sh) ;;
      supabase/migrations/20260606190000_puls_app_connector_notification_producers.sql) ;;
      *)
        echo "FAIL: unexpected changed path for PR16.9.2 connector notification producers: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

echo "PR16.9.2 connector notification producers verification passed."
