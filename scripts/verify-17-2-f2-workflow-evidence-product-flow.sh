#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT_DIR"

MIGRATION="supabase/migrations/20260610120000_puls_workflow_evidence_product_flow.sql"
DOC="docs/product/17_2_f2_workflow_evidence_product_flow.md"
FOUNDATION_DOC="docs/product/17_2_f_workflow_evidence_upload_foundation.md"
README="docs/product/README.md"
AUDIT="docs/product/17_0_product_reality_audit.md"
VERIFY_PR17="scripts/verify-pr17.sh"
VERIFY_SELF="scripts/verify-17-2-f2-workflow-evidence-product-flow.sh"

fail() {
  echo "PR17.2F2 verify failed: $*" >&2
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

for file in "$MIGRATION" "$DOC" "$FOUNDATION_DOC" "$README" "$AUDIT" "$VERIFY_PR17" "$VERIFY_SELF"; do
  require_file "$file"
done

require_executable "$VERIFY_PR17"
require_executable "$VERIFY_SELF"

require_pattern "$MIGRATION" "CREATE OR REPLACE FUNCTION puls_workflow.create_leave_request_with_evidence"
require_pattern "$MIGRATION" "CREATE OR REPLACE FUNCTION puls_workflow.create_expense_claim_with_evidence"
require_pattern "$MIGRATION" "CREATE OR REPLACE FUNCTION puls_workflow._attach_leave_document_evidence"
require_pattern "$MIGRATION" "CREATE OR REPLACE FUNCTION puls_workflow._attach_expense_receipt_evidence"
require_pattern "$MIGRATION" "PULS_DOCUMENT_REQUIRED"
require_pattern "$MIGRATION" "PULS_RECEIPT_REQUIRED"
require_pattern "$MIGRATION" "workflow_evidence.leave_document_attached"
require_pattern "$MIGRATION" "workflow_evidence.expense_receipt_attached"
require_pattern "$MIGRATION" "GRANT EXECUTE ON FUNCTION puls_workflow.create_leave_request_with_evidence"
require_pattern "$MIGRATION" "GRANT EXECUTE ON FUNCTION puls_workflow.create_expense_claim_with_evidence"
reject_pattern "$MIGRATION" "ocr_confidence"
reject_pattern "$MIGRATION" "ocr_vendor"
reject_pattern "$MIGRATION" "virus_scanned"
reject_pattern "$MIGRATION" "public = TRUE"

require_pattern "src/lib/data/workflow/evidence.ts" "uploadWorkflowEvidenceFile"
require_pattern "src/lib/data/workflow/evidence.ts" "create_workflow_evidence_upload_intent"
require_pattern "src/lib/data/workflow/evidence.ts" "finalize_workflow_evidence_upload"
require_pattern "src/lib/data/workflow/evidence.ts" "attach_contract_file_evidence"
require_pattern "src/components/puls/EvidenceUploadField.tsx" "EvidenceUploadField"

require_pattern "src/lib/data/leave/requests.ts" "createLeaveRequestWithEvidence"
require_pattern "src/lib/data/expense/claims.ts" "createExpenseClaimWithEvidence"
require_pattern "src/routes/_app/izin.tsx" "EvidenceUploadField"
require_pattern "src/routes/_app/izin.tsx" "createLeaveRequestWithEvidence"
require_pattern "src/routes/_app/masraf.tsx" "EvidenceUploadField"
require_pattern "src/routes/_app/masraf.tsx" "createExpenseClaimWithEvidence"
require_pattern "src/routes/_app/sozlesmeler.tsx" "EvidenceUploadField"
require_pattern "src/routes/_app/sozlesmeler.tsx" "attachContractFileEvidence"

reject_pattern "src/routes/_app/izin.tsx" "Belge yükleme özelliği yakında"
reject_pattern "src/routes/_app/masraf.tsx" "Belge yükleme açılana kadar"
reject_pattern "src/routes/_app/sozlesmeler.tsx" "uploadUnavailable"
reject_pattern "src/i18n/locales/tr-TR.json" "Belge yükleme açılana kadar"
reject_pattern "src/i18n/locales/en-US.json" "until document upload is available"

require_pattern "$DOC" "No OCR"
require_pattern "$DOC" "create_leave_request_with_evidence"
require_pattern "$DOC" "create_expense_claim_with_evidence"
require_pattern "$FOUNDATION_DOC" "PR17.2F2 Product Flow"
require_pattern "$README" "17_2_f2_workflow_evidence_product_flow.md"
require_pattern "$AUDIT" "Rev 9"
require_pattern "$AUDIT" "17.2F1/F2 tamam"
require_pattern "$VERIFY_PR17" "verify-17-2-f2-workflow-evidence-product-flow.sh"

echo "PR17.2F2 workflow evidence product flow verification passed."
