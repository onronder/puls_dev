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

SMOKE="$ROOT_DIR/docs/data/17_2_b_workflow_closed_loop_smoke.sql"
DOC="$ROOT_DIR/docs/product/17_2_b_workflow_closed_loop_proof.md"
README="$ROOT_DIR/docs/product/README.md"
VERIFY="$ROOT_DIR/scripts/verify-17-2-b-workflow-closed-loop-proof.sh"

echo "Checking PR17.2B workflow closed-loop proof contract..."

[[ -f "$SMOKE" ]] || fail "Missing rollback-only workflow closed-loop smoke SQL"
[[ -f "$DOC" ]] || fail "Missing PR17.2B product contract"
[[ -x "$VERIFY" ]] || fail "Verify script must be executable"

contains "$SMOKE" "BEGIN;"
contains "$SMOKE" "ROLLBACK;"
not_contains "$SMOKE" "COMMIT;"
contains "$SMOKE" "puls_workflow.create_leave_request"
contains "$SMOKE" "puls_workflow.create_expense_claim"
contains "$SMOKE" "puls_workflow.decide_approval_request"
contains "$SMOKE" "puls_app.run_app_notification_producers"
contains "$SMOKE" "set_config('request.jwt.claim.role', 'authenticated'"
contains "$SMOKE" "set_config('request.jwt.claim.role', 'service_role'"
contains "$SMOKE" "leave_approval_requested"
contains "$SMOKE" "expense_approval_requested"
contains "$SMOKE" "leave_request_approved"
contains "$SMOKE" "expense_claim_rejected"
contains "$SMOKE" "puls_app.app_notifications"
contains "$SMOKE" "puls_audit.audit_logs"
contains "$SMOKE" "target_employee_ids @>"
contains "$SMOKE" "safe_summary ->> 'target'"
contains "$SMOKE" "raw_payload_readback"
contains "$SMOKE" "PR17_2B_SMOKE_FAIL"
not_contains "$SMOKE" "credential_value"
not_contains "$SMOKE" "provider_payload"
not_contains "$SMOKE" "raw_payload ->"

contains "$DOC" "PR17.2B"
contains "$DOC" "BEGIN ... ROLLBACK"
contains "$DOC" "No Railway worker implementation change"
contains "$DOC" "docs/data/17_2_b_workflow_closed_loop_smoke.sql"
contains "$README" "PR17.2B Workflow closed-loop proof"
contains "$README" "17_2_b_workflow_closed_loop_proof.md"
contains "$README" "17_2_b_workflow_closed_loop_smoke.sql"

if $SEARCH_BIN "17_2_b_workflow_closed_loop_smoke" "$ROOT_DIR/supabase/migrations" >/dev/null 2>&1; then
  fail "PR17.2B smoke must stay out of migrations"
fi

echo "PR17.2B workflow closed-loop proof contract OK."
