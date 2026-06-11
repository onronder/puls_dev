#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT_DIR"

SMOKE="docs/data/17_2_e_workflow_e2e_reconcile_smoke.sql"
DOC="docs/product/17_2_e_workflow_e2e_reconcile_contract.md"
README="docs/product/README.md"
AUDIT="docs/product/17_0_product_reality_audit.md"
VERIFY_PR17="scripts/verify-pr17.sh"
VERIFY_SELF="scripts/verify-17-2-e-workflow-e2e-reconcile.sh"

SEARCH_BIN="grep -R"
if command -v rg >/dev/null 2>&1; then
  SEARCH_BIN="rg"
fi

fail() {
  echo "PR17.2E verify failed: $*" >&2
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

for file in "$SMOKE" "$DOC" "$README" "$AUDIT" "$VERIFY_PR17" "$VERIFY_SELF"; do
  require_file "$file"
done

require_executable "$VERIFY_PR17"
require_executable "$VERIFY_SELF"

require_pattern "$SMOKE" "BEGIN;"
require_pattern "$SMOKE" "ROLLBACK;"
reject_pattern "$SMOKE" "COMMIT;"
require_pattern "$SMOKE" "puls_workflow.create_leave_request"
require_pattern "$SMOKE" "puls_workflow.create_expense_claim"
require_pattern "$SMOKE" "puls_workflow.decide_approval_request"
require_pattern "$SMOKE" "puls_app.run_app_notification_producers"
require_pattern "$SMOKE" "workflow_notification_dispatch"
require_pattern "$SMOKE" "connector_independent_delivery"
require_pattern "$SMOKE" "v_reconcile_inserted <> 0"
require_pattern "$SMOKE" "COUNT(*) FILTER (WHERE produced.inserted)"
require_pattern "$SMOKE" "dedupe_key IN"
require_pattern "$SMOKE" "HAVING COUNT(*) <> 1"
require_pattern "$SMOKE" "next_approval_request_id"
require_pattern "$SMOKE" "v_multi_step_seen"
require_pattern "$SMOKE" "puls_audit.audit_logs"
require_pattern "$SMOKE" "PR17_2E_SMOKE_FAIL"
require_pattern "$SMOKE" "ROLLBACK pending"

reject_pattern "$SMOKE" "credential_value"
reject_pattern "$SMOKE" "provider_payload"
reject_pattern "$SMOKE" "raw_payload ->"
reject_pattern "$SMOKE" "document_readback"
reject_pattern "$SMOKE" "receipt_readback"

require_pattern "$DOC" "PR17.2E"
require_pattern "$DOC" "database-boundary e2e"
require_pattern "$DOC" "duplicate-safe reconcile/backfill"
require_pattern "$DOC" "No database migration"
require_pattern "$DOC" "BEGIN ... ROLLBACK"
require_pattern "$DOC" "docs/data/17_2_e_workflow_e2e_reconcile_smoke.sql"

require_pattern "$README" "PR17.2E Workflow E2E baseline and reconcile contract"
require_pattern "$README" "17_2_e_workflow_e2e_reconcile_contract.md"
require_pattern "$README" "17_2_e_workflow_e2e_reconcile_smoke.sql"
require_pattern "$README" "PR17.2F1 Evidence Upload Backend Boundary"
require_pattern "$README" "PR17.2F2 Evidence Upload Product Flow"

require_pattern "$AUDIT" "Rev 19"
require_pattern "$AUDIT" "PR17.2E"
require_pattern "$AUDIT" "DB-boundary"
require_pattern "$AUDIT" "17_2_e_workflow_e2e_reconcile_smoke.sql"

require_pattern "$VERIFY_PR17" "verify-17-2-e-workflow-e2e-reconcile.sh"

if $SEARCH_BIN "17_2_e_workflow_e2e_reconcile_smoke" "$ROOT_DIR/supabase/migrations" >/dev/null 2>&1; then
  fail "PR17.2E smoke must stay out of migrations"
fi

echo "PR17.2E workflow e2e reconcile contract verification passed."
