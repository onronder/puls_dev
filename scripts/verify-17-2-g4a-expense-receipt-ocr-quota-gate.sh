#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT_DIR"

MIGRATION="supabase/migrations/20260611120000_puls_workflow_expense_receipt_ocr_quota_gate.sql"
SMOKE="docs/data/17_2_g4a_expense_receipt_ocr_quota_gate_smoke.sql"
DOC="docs/product/17_2_g4a_expense_receipt_ocr_quota_gate.md"
G_DOC="docs/product/17_2_g_evidence_review_ocr_contract.md"
README="docs/product/README.md"
AUDIT="docs/product/17_0_product_reality_audit.md"
VERIFY_PR17="scripts/verify-pr17.sh"

fail() {
  echo "PR17.2G4A verify failed: $*" >&2
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

for file in "$MIGRATION" "$SMOKE" "$DOC" "$G_DOC" "$README" "$AUDIT" "$VERIFY_PR17"; do
  require_file "$file"
done

require_pattern "$MIGRATION" "expense_receipt_ocr_tenant_posture"
require_pattern "$MIGRATION" "expense_receipt_ocr_global_posture"
require_pattern "$MIGRATION" "monthly_document_quota INTEGER NOT NULL DEFAULT 0"
require_pattern "$MIGRATION" "monthly_spend_cap_minor INTEGER NOT NULL DEFAULT 0"
require_pattern "$MIGRATION" "provider_class_allowlist puls_workflow.expense_receipt_ocr_provider_class[] NOT NULL"
require_pattern "$MIGRATION" "estimated_cost_minor INTEGER NOT NULL DEFAULT 0"
require_pattern "$MIGRATION" "DROP FUNCTION IF EXISTS puls_workflow.enqueue_expense_receipt_ocr_job"
require_pattern "$MIGRATION" "PULS_OCR_TENANT_DISABLED"
require_pattern "$MIGRATION" "PULS_OCR_QUOTA_EXHAUSTED"
require_pattern "$MIGRATION" "PULS_OCR_PROVIDER_CLASS_NOT_ALLOWED"
require_pattern "$MIGRATION" "PULS_OCR_SPEND_CAP_EXCEEDED"
require_pattern "$MIGRATION" "PULS_OCR_GLOBAL_SPEND_CAP_EXCEEDED"
require_pattern "$MIGRATION" "quota_gate_enforced"
require_pattern "$MIGRATION" "REVOKE ALL ON TABLE puls_workflow.expense_receipt_ocr_tenant_posture FROM anon, authenticated"
require_pattern "$MIGRATION" "GRANT ALL ON TABLE puls_workflow.expense_receipt_ocr_tenant_posture TO service_role"
reject_pattern "$MIGRATION" "https://generativelanguage.googleapis.com"
reject_pattern "$MIGRATION" "api.openai.com"
reject_pattern "$MIGRATION" "anthropic.com"
reject_pattern "$MIGRATION" "mistral.ai"
reject_pattern "$MIGRATION" "UPDATE puls_workflow.expense_claims"

require_pattern "$SMOKE" "PULS_OCR_TENANT_DISABLED"
require_pattern "$SMOKE" "PULS_OCR_QUOTA_EXHAUSTED"
require_pattern "$SMOKE" "PULS_OCR_PROVIDER_CLASS_NOT_ALLOWED"
require_pattern "$SMOKE" "PULS_OCR_SPEND_CAP_EXCEEDED"
require_pattern "$SMOKE" "PULS_OCR_GLOBAL_SPEND_CAP_EXCEEDED"
require_pattern "$SMOKE" "quota_gate_enforced"
require_pattern "$SMOKE" "ROLLBACK;"
reject_pattern "$SMOKE" "COMMIT;"

require_pattern "$DOC" "PR17.2G4A Expense Receipt OCR Quota Gate"
require_pattern "$DOC" "No paid OCR/VLM provider"
require_pattern "$DOC" "Default posture"
require_pattern "$DOC" "Idempotent enqueue hits return the existing job"
require_pattern "$G_DOC" "G4A"
require_pattern "$README" "17_2_g4a_expense_receipt_ocr_quota_gate.md"
grep -Eq "^> \*\*Tarih:\*\* .*\*\*Rev 2[0-9]\*\*" "$AUDIT" || fail "audit doc missing current PR17 Rev 2x marker"
require_pattern "$AUDIT" "PR17.2G4A"
require_pattern "$VERIFY_PR17" "verify-17-2-g4a-expense-receipt-ocr-quota-gate.sh"

echo "PR17.2G4A expense receipt OCR quota gate verification passed."
