#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT_DIR"

MIGRATION="supabase/migrations/20260611100000_puls_workflow_expense_receipt_ocr_review_hardening.sql"
SMOKE="docs/data/17_2_g3_expense_receipt_ocr_human_review_smoke.sql"
DOC="docs/product/17_2_g3a_expense_receipt_ocr_review_hardening.md"
G3_DOC="docs/product/17_2_g3_expense_receipt_ocr_human_review.md"
G_DOC="docs/product/17_2_g_evidence_review_ocr_contract.md"
README="docs/product/README.md"
AUDIT="docs/product/17_0_product_reality_audit.md"
VERIFY_PR17="scripts/verify-pr17.sh"

fail() {
  echo "PR17.2G3A verify failed: $*" >&2
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

for file in "$MIGRATION" "$SMOKE" "$DOC" "$G3_DOC" "$G_DOC" "$README" "$AUDIT" "$VERIFY_PR17"; do
  require_file "$file"
done

require_pattern "$MIGRATION" "CREATE OR REPLACE FUNCTION puls_workflow.can_review_expense_receipt_ocr"
require_pattern "$MIGRATION" "JOIN puls_workflow.expense_claims claim"
require_pattern "$MIGRATION" "claim.employee_id IS DISTINCT FROM puls_core.current_employee_id()"
require_pattern "$MIGRATION" "Self-review is blocked even for admins"
require_pattern "$MIGRATION" "GRANT EXECUTE ON FUNCTION puls_workflow.can_review_expense_receipt_ocr"
reject_pattern "$MIGRATION" "UPDATE puls_workflow.expense_claims"
reject_pattern "$MIGRATION" "record_expense_receipt_ocr_review"
reject_pattern "$MIGRATION" "provider_payload"
reject_pattern "$MIGRATION" "raw_ocr_text"

require_pattern "$SMOKE" "unassigned reviewer should not be allowed"
require_pattern "$SMOKE" "requester self-review should not be allowed"
require_pattern "$SMOKE" "PULS_OCR_REVIEW_FORBIDDEN"
require_pattern "$SMOKE" "PULS_OCR_REVIEW_ALREADY_RECORDED"
require_pattern "$SMOKE" "ROLLBACK;"
reject_pattern "$SMOKE" "COMMIT;"

require_pattern "$DOC" "PR17.2G3A Expense Receipt OCR Review Hardening"
require_pattern "$DOC" "Block OCR self-review server-side"
require_pattern "$DOC" "structured correction form"
require_pattern "$DOC" "OCR job recover/dead-letter smoke"
require_pattern "$G3_DOC" "PR17.2G3A Hardening"
require_pattern "$G_DOC" "requester self-review is blocked even for admins"
require_pattern "$README" "17_2_g3a_expense_receipt_ocr_review_hardening.md"
grep -Eq "^> \*\*Tarih:\*\* .*\*\*Rev 2[0-9]\*\*" "$AUDIT" || fail "audit doc missing current PR17 Rev 2x marker"
require_pattern "$AUDIT" "17.2G3A"
require_pattern "$AUDIT" "✅ Tamamlandı"
require_pattern "$VERIFY_PR17" "verify-17-2-g3a-expense-receipt-ocr-review-hardening.sh"

echo "PR17.2G3A expense receipt OCR review hardening verification passed."
