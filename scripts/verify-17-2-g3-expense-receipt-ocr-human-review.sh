#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT_DIR"

MIGRATION="supabase/migrations/20260611090000_puls_workflow_expense_receipt_ocr_human_review.sql"
SMOKE="docs/data/17_2_g3_expense_receipt_ocr_human_review_smoke.sql"
DOC="docs/product/17_2_g3_expense_receipt_ocr_human_review.md"
G_DOC="docs/product/17_2_g_evidence_review_ocr_contract.md"
README="docs/product/README.md"
AUDIT="docs/product/17_0_product_reality_audit.md"
EVIDENCE_ADAPTER="src/lib/data/workflow/evidence.ts"
EXPENSE_ADAPTER="src/lib/data/expense/overview.ts"
EXPENSE_PAGE="src/routes/_app/masraf.tsx"
REVIEW_COMPONENT="src/components/puls/ExpenseReceiptOcrReviewPanel.tsx"
ERRORS="src/lib/data/errors.ts"
LOCALE_TR="src/i18n/locales/tr-TR.json"
LOCALE_EN="src/i18n/locales/en-US.json"
VERIFY_PR17="scripts/verify-pr17.sh"
VERIFY_SELF="scripts/verify-17-2-g3-expense-receipt-ocr-human-review.sh"

fail() {
  echo "PR17.2G3 verify failed: $*" >&2
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

for file in "$MIGRATION" "$SMOKE" "$DOC" "$G_DOC" "$README" "$AUDIT" "$EVIDENCE_ADAPTER" "$EXPENSE_ADAPTER" "$EXPENSE_PAGE" "$REVIEW_COMPONENT" "$ERRORS" "$LOCALE_TR" "$LOCALE_EN" "$VERIFY_PR17" "$VERIFY_SELF"; do
  require_file "$file"
done

require_executable "$VERIFY_PR17"
require_executable "$VERIFY_SELF"

require_pattern "$MIGRATION" "ADD COLUMN IF NOT EXISTS reviewed_by_employee_id"
require_pattern "$MIGRATION" "ADD COLUMN IF NOT EXISTS reviewed_at"
require_pattern "$MIGRATION" "ADD COLUMN IF NOT EXISTS review_note"
require_pattern "$MIGRATION" "ADD COLUMN IF NOT EXISTS corrected_fields"
require_pattern "$MIGRATION" "expense_receipt_ocr_review_fields_are_allowed"
require_pattern "$MIGRATION" "can_review_expense_receipt_ocr"
require_pattern "$MIGRATION" "record_expense_receipt_ocr_review"
require_pattern "$MIGRATION" "'accepted'::puls_workflow.expense_receipt_ocr_review_status"
require_pattern "$MIGRATION" "'corrected'::puls_workflow.expense_receipt_ocr_review_status"
require_pattern "$MIGRATION" "'rejected'::puls_workflow.expense_receipt_ocr_review_status"
require_pattern "$MIGRATION" "'needs_new_document'::puls_workflow.expense_receipt_ocr_review_status"
require_pattern "$MIGRATION" "PULS_OCR_REVIEW_ALREADY_RECORDED"
require_pattern "$MIGRATION" "expense_receipt_ocr.review_recorded"
require_pattern "$MIGRATION" "'canonical_write', FALSE"
require_pattern "$MIGRATION" "GRANT EXECUTE ON FUNCTION puls_workflow.record_expense_receipt_ocr_review"
require_pattern "$MIGRATION" "REVOKE ALL ON FUNCTION puls_workflow.record_expense_receipt_ocr_review"

reject_pattern "$MIGRATION" "UPDATE puls_workflow.expense_claims"
reject_pattern "$MIGRATION" "SET amount"
reject_pattern "$MIGRATION" "raw_ocr_text"
reject_pattern "$MIGRATION" "provider_payload"
reject_pattern "$MIGRATION" "signed_url"
reject_pattern "$MIGRATION" "public_url"

require_pattern "$SMOKE" "record_expense_receipt_ocr_review"
require_pattern "$SMOKE" "canonical expense claim changed"
require_pattern "$SMOKE" "PULS_OCR_REVIEW_ALREADY_RECORDED"
require_pattern "$SMOKE" "ROLLBACK;"
reject_pattern "$SMOKE" "COMMIT;"

require_pattern "$EVIDENCE_ADAPTER" "fetchExpenseReceiptOcrReviews"
require_pattern "$EVIDENCE_ADAPTER" "recordExpenseReceiptOcrReview"
require_pattern "$EVIDENCE_ADAPTER" "mapExpenseReceiptOcrReviewRow"
require_pattern "$EVIDENCE_ADAPTER" "record_expense_receipt_ocr_review"
reject_pattern "$EVIDENCE_ADAPTER" "expense_claims"
reject_pattern "$EVIDENCE_ADAPTER" "raw_ocr_text"
reject_pattern "$EVIDENCE_ADAPTER" "provider_payload"

require_pattern "$EXPENSE_ADAPTER" "ocrReviews"
require_pattern "$EXPENSE_ADAPTER" "fetchExpenseReceiptOcrReviews"
require_pattern "$EXPENSE_PAGE" "ExpenseReceiptOcrReviewPanel"
require_pattern "$EXPENSE_PAGE" "recordExpenseReceiptOcrReview"
require_pattern "$REVIEW_COMPONENT" "ExpenseReceiptOcrReviewPanel"
require_pattern "$REVIEW_COMPONENT" "needs_new_document"
require_pattern "$REVIEW_COMPONENT" "workflowEvidence.ocr.actions.accept"
require_pattern "$REVIEW_COMPONENT" "workflowEvidence.ocr.boundary"
reject_pattern "$REVIEW_COMPONENT" "dangerouslySetInnerHTML"

require_pattern "$ERRORS" "PULS_OCR_REVIEW_FORBIDDEN"
require_pattern "$LOCALE_TR" "\"ocr\""
require_pattern "$LOCALE_EN" "\"ocr\""

require_pattern "$DOC" "PR17.2G3 Expense Receipt OCR Human Review"
require_pattern "$DOC" 'No canonical `expense_claims` update'
require_pattern "$DOC" "No second review or decision overwrite"
require_pattern "$G_DOC" "G3 — Human Review UI"
require_pattern "$README" "17_2_g3_expense_receipt_ocr_human_review.md"
require_pattern "$AUDIT" "Rev 16"
require_pattern "$AUDIT" "17.2G3"
require_pattern "$AUDIT" "✅ Tamamlandı"
require_pattern "$VERIFY_PR17" "verify-17-2-g3-expense-receipt-ocr-human-review.sh"

echo "PR17.2G3 expense receipt OCR human review verification passed."
