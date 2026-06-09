#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT_DIR"

MIGRATION="supabase/migrations/20260610100000_puls_workflow_notification_dispatch_boundary.sql"
DOC="docs/product/17_2_d_workflow_notification_dispatch_boundary.md"
README="docs/product/README.md"
AUDIT="docs/product/17_0_product_reality_audit.md"
PACKAGE_JSON="package.json"
CI=".github/workflows/ci.yml"
VERIFY_PR17="scripts/verify-pr17.sh"
VERIFY_SELF="scripts/verify-17-2-d-workflow-notification-dispatch.sh"

fail() {
  echo "PR17.2D verify failed: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || fail "missing file: $1"
}

require_executable() {
  [[ -x "$1" ]] || fail "script must be executable: $1"
}

require_pattern() {
  local file="$1"
  local pattern="$2"
  grep -Fq "$pattern" "$file" || fail "missing pattern in $file: $pattern"
}

reject_pattern() {
  local file="$1"
  local pattern="$2"
  if grep -Fq "$pattern" "$file"; then
    fail "forbidden pattern in $file: $pattern"
  fi
}

for file in "$MIGRATION" "$DOC" "$README" "$AUDIT" "$PACKAGE_JSON" "$CI" "$VERIFY_PR17" "$VERIFY_SELF"; do
  require_file "$file"
done

require_executable "$VERIFY_PR17"
require_executable "$VERIFY_SELF"

require_pattern "$MIGRATION" "emit_workflow_app_notification_internal"
require_pattern "$MIGRATION" "connector_independent_delivery"
require_pattern "$MIGRATION" "workflow_dispatch_contract_version"
require_pattern "$MIGRATION" "browser_direct_table_write', FALSE"
require_pattern "$MIGRATION" "puls_workflow_approval_requests_notification_dispatch"
require_pattern "$MIGRATION" "AFTER INSERT ON puls_workflow.approval_requests"
require_pattern "$MIGRATION" "puls_workflow_leave_requests_notification_dispatch"
require_pattern "$MIGRATION" "AFTER UPDATE OF status ON puls_workflow.leave_requests"
require_pattern "$MIGRATION" "puls_workflow_expense_claims_notification_dispatch"
require_pattern "$MIGRATION" "AFTER UPDATE OF status ON puls_workflow.expense_claims"
require_pattern "$MIGRATION" "leave_approval_requested"
require_pattern "$MIGRATION" "expense_approval_requested"
require_pattern "$MIGRATION" "leave_request_approved"
require_pattern "$MIGRATION" "expense_claim_rejected"
require_pattern "$MIGRATION" "concat_ws(':', 'pr17.2a', 'leave_approval_requested'"
require_pattern "$MIGRATION" "concat_ws(':', 'pr17.2a', 'expense_approval_requested'"
require_pattern "$MIGRATION" "concat_ws(':', 'pr17.2a', 'leave_request_decision'"
require_pattern "$MIGRATION" "concat_ws(':', 'pr17.2a', 'expense_claim_decision'"
require_pattern "$MIGRATION" "REVOKE ALL ON FUNCTION puls_app.emit_workflow_app_notification_internal"
require_pattern "$MIGRATION" "FROM PUBLIC, anon, authenticated"
require_pattern "$MIGRATION" "TO service_role"

reject_pattern "$MIGRATION" "credential_value"
reject_pattern "$MIGRATION" "provider_payload"
reject_pattern "$MIGRATION" "raw_payload ->"
reject_pattern "$MIGRATION" "decision_note"

require_pattern "$DOC" "connector-independent"
require_pattern "$DOC" "generic notification emitter"
require_pattern "$DOC" "same database transaction"
require_pattern "$DOC" "Existing PR17.2A dedupe keys are reused"
require_pattern "$README" "PR17.2D Workflow notification dispatch boundary"
require_pattern "$README" "17_2_d_workflow_notification_dispatch_boundary.md"

require_pattern "$PACKAGE_JSON" "\"verify:pr17\": \"bash scripts/verify-pr17.sh\""
require_pattern "$CI" "pnpm run verify:pr17"
require_pattern "$VERIFY_PR17" "verify-17-1-a-core-hr-audit-foundation.sh"
require_pattern "$VERIFY_PR17" "verify-17-2-d-workflow-notification-dispatch.sh"
require_pattern "$AUDIT" "R11"
require_pattern "$AUDIT" "PR17.2D"

echo "PR17.2D workflow notification dispatch verification passed."
