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

MIGRATION="$ROOT_DIR/supabase/migrations/20260609160000_puls_workflow_notification_producers.sql"
DOC="$ROOT_DIR/docs/product/17_2_a_workflow_notification_producers.md"
VERIFY="$ROOT_DIR/scripts/verify-17-2-a-workflow-notification-producers.sh"
ACTION="$ROOT_DIR/src/lib/notifications/app-notification-actions.ts"
CENTER="$ROOT_DIR/src/components/notifications/AppNotificationCenter.tsx"
TR="$ROOT_DIR/src/i18n/locales/tr-TR.json"
EN="$ROOT_DIR/src/i18n/locales/en-US.json"

echo "Checking PR17.2A workflow notification producer contract..."

[[ -f "$MIGRATION" ]] || fail "Missing workflow notification migration"
[[ -f "$DOC" ]] || fail "Missing PR17.2A product contract"
[[ -x "$VERIFY" ]] || fail "Verify script must be executable"

contains "$MIGRATION" "CREATE OR REPLACE FUNCTION puls_app.refresh_workflow_app_notifications"
contains "$MIGRATION" "v_auth_role <> 'service_role'"
contains "$MIGRATION" "GRANT EXECUTE ON FUNCTION puls_app.refresh_workflow_app_notifications(INTEGER, UUID)"
contains "$MIGRATION" "TO service_role"
contains "$MIGRATION" "FROM PUBLIC, anon, authenticated"
contains "$MIGRATION" "puls_app.run_app_notification_producers"
contains "$MIGRATION" "'workflow'::TEXT AS producer_key"
contains "$MIGRATION" "leave_approval_requested"
contains "$MIGRATION" "expense_approval_requested"
contains "$MIGRATION" "leave_request_approved"
contains "$MIGRATION" "expense_claim_rejected"
contains "$MIGRATION" "notification_window_days"
contains "$MIGRATION" "INTERVAL '90 days'"
contains "$MIGRATION" "'raw_payload_readback', FALSE"
not_contains "$MIGRATION" "credential_value"
not_contains "$MIGRATION" "decision_note"

contains "$ACTION" "sourceDomain === 'puls_workflow'"
contains "$ACTION" "leave_approval_requested"
contains "$ACTION" "expense_claim_rejected"
contains "$ACTION" "to: '/izin'"
contains "$ACTION" "to: '/masraf'"

contains "$CENTER" "sourceDomain: 'puls_workflow'"
contains "$CENTER" "notifications.preferences.scopes.workflow.title"
contains "$CENTER" "workflow_module"

contains "$TR" "\"puls_workflow\": \"İK süreci\""
contains "$TR" "\"leaveApprovalRequested\""
contains "$TR" "\"expenseRejected\""
contains "$EN" "\"puls_workflow\": \"HR workflow\""
contains "$EN" "\"leaveApprovalRequested\""
contains "$EN" "\"expenseRejected\""

if $SEARCH_BIN "refresh_workflow_app_notifications" "$ROOT_DIR/services" >/dev/null 2>&1; then
  fail "Workflow notification producer should not require Railway service code changes"
fi

echo "PR17.2A workflow notification producer contract OK."
