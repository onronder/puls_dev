#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(pwd)}"
cd "$ROOT_DIR"

MIGRATION="supabase/migrations/20260609070000_puls_workflow_audit_policy_hardening.sql"
DOC="docs/product/16_10_14_workflow_audit_policy_hardening.md"
README="docs/product/README.md"
ROADMAP="docs/product/15_16_connector_runtime_ai_roadmap.md"
EXPENSE_ROUTE="src/routes/_app/masraf.tsx"
EXPENSE_OVERVIEW="src/lib/data/expense/overview.ts"
DEMO_DATA="src/lib/demo/puls-demo-data.ts"
ERRORS="src/lib/data/errors.ts"
TR_LOCALE="src/i18n/locales/tr-TR.json"
EN_LOCALE="src/i18n/locales/en-US.json"

fail() {
  echo "PR16.10.14 verify failed: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || fail "missing file: $1"
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

for file in \
  "$MIGRATION" \
  "$DOC" \
  "$README" \
  "$ROADMAP" \
  "$EXPENSE_ROUTE" \
  "$EXPENSE_OVERVIEW" \
  "$DEMO_DATA" \
  "$ERRORS" \
  "$TR_LOCALE" \
  "$EN_LOCALE"; do
  require_file "$file"
done

require_pattern "$MIGRATION" "write_workflow_row_audit_log"
require_pattern "$MIGRATION" "_workflow_audit_transition_metadata"
require_pattern "$MIGRATION" "puls_workflow_leave_requests_audit_row"
require_pattern "$MIGRATION" "puls_workflow_expense_claims_audit_row"
require_pattern "$MIGRATION" "puls_workflow_approval_requests_audit_row"
require_pattern "$MIGRATION" "safe_row_audit"
require_pattern "$MIGRATION" "PULS_RECEIPT_REQUIRED"
require_pattern "$MIGRATION" "receipt_required_over"
require_pattern "$MIGRATION" "REVOKE ALL ON FUNCTION puls_workflow.write_workflow_row_audit_log"
reject_pattern "$MIGRATION" "raw_payload"
reject_pattern "$MIGRATION" "credential_value"

reject_pattern "$EXPENSE_ROUTE" "POLICY_RECEIPT_THRESHOLD"
require_pattern "$EXPENSE_ROUTE" "receiptRequiredOver"
require_pattern "$EXPENSE_ROUTE" "receiptRequired"
require_pattern "$EXPENSE_ROUTE" "policyReceiptBlockedDesc"

require_pattern "$EXPENSE_OVERVIEW" "receipt_required_over"
require_pattern "$EXPENSE_OVERVIEW" "receiptRequiredOver"
require_pattern "$DEMO_DATA" "receiptRequiredOver"

require_pattern "$ERRORS" "PULS_RECEIPT_REQUIRED"
require_pattern "$TR_LOCALE" "receiptRequired"
require_pattern "$TR_LOCALE" "policyReceiptBlockedDesc"
require_pattern "$EN_LOCALE" "receiptRequired"
require_pattern "$EN_LOCALE" "policyReceiptBlockedDesc"

require_pattern "$DOC" "metadata-only row audit triggers"
require_pattern "$DOC" "PULS_RECEIPT_REQUIRED"
require_pattern "$README" "PR16.10.14 Workflow audit and policy hardening"
require_pattern "$ROADMAP" "PR16.10.14 - Workflow Audit & Policy Hardening"

echo "PR16.10.14 workflow audit and policy hardening verification passed."
