#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT_DIR"

DOC="docs/product/17_2_g1_evidence_viewing_access.md"
G_DOC="docs/product/17_2_g_evidence_review_ocr_contract.md"
README="docs/product/README.md"
AUDIT="docs/product/17_0_product_reality_audit.md"
EVIDENCE="src/lib/data/workflow/evidence.ts"
EVIDENCE_TEST="src/lib/data/workflow/evidence.test.ts"
COMPONENT="src/components/puls/WorkflowEvidenceViewActions.tsx"
CONTRACTS="src/lib/data/contracts/overview.ts"
CONTRACTS_TEST="src/lib/data/contracts/overview.test.ts"
LEAVE_OVERVIEW="src/lib/data/leave/overview.ts"
EXPENSE_OVERVIEW="src/lib/data/expense/overview.ts"
INDEX="src/lib/data/index.ts"
LEAVE_ROUTE="src/routes/_app/izin.tsx"
EXPENSE_ROUTE="src/routes/_app/masraf.tsx"
CONTRACTS_ROUTE="src/routes/_app/sozlesmeler.tsx"
TR_LOCALE="src/i18n/locales/tr-TR.json"
EN_LOCALE="src/i18n/locales/en-US.json"
VERIFY_PR17="scripts/verify-pr17.sh"
VERIFY_SELF="scripts/verify-17-2-g1-evidence-viewing-access.sh"

fail() {
  echo "PR17.2G1 verify failed: $*" >&2
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

for file in \
  "$DOC" "$G_DOC" "$README" "$AUDIT" "$EVIDENCE" "$EVIDENCE_TEST" "$COMPONENT" \
  "$CONTRACTS" "$CONTRACTS_TEST" "$LEAVE_OVERVIEW" "$EXPENSE_OVERVIEW" "$INDEX" \
  "$LEAVE_ROUTE" "$EXPENSE_ROUTE" "$CONTRACTS_ROUTE" "$TR_LOCALE" "$EN_LOCALE" \
  "$VERIFY_PR17" "$VERIFY_SELF"; do
  require_file "$file"
done

require_executable "$VERIFY_PR17"
require_executable "$VERIFY_SELF"

require_pattern "$EVIDENCE" "WorkflowEvidenceAttachment"
require_pattern "$EVIDENCE" "fetchWorkflowEvidenceAttachments"
require_pattern "$EVIDENCE" "mapWorkflowEvidenceAttachmentRow"
require_pattern "$EVIDENCE" "groupWorkflowEvidenceByParent"
require_pattern "$EVIDENCE" "createWorkflowEvidenceSignedUrl"
require_pattern "$EVIDENCE" "expiresInSeconds = 120"
require_pattern "$EVIDENCE" "createSignedUrl(attachment.storagePath, expiresInSeconds)"
reject_pattern "$EVIDENCE" "getPublicUrl"
reject_pattern "$EVIDENCE" "ocr_confidence"
reject_pattern "$EVIDENCE" "ocr_vendor"

require_pattern "$COMPONENT" "WorkflowEvidenceViewActions"
require_pattern "$COMPONENT" "createWorkflowEvidenceSignedUrl"
require_pattern "$COMPONENT" "workflowEvidence.error.viewFailed"
require_pattern "$COMPONENT" "noopener noreferrer"
reject_pattern "$COMPONENT" "getPublicUrl"
reject_pattern "$COMPONENT" "attachment.storagePath"
reject_pattern "$COMPONENT" "OCR"

require_pattern "$LEAVE_OVERVIEW" "fetchWorkflowEvidenceAttachments"
require_pattern "$LEAVE_OVERVIEW" "'leave'"
require_pattern "$LEAVE_OVERVIEW" "evidence:"
require_pattern "$EXPENSE_OVERVIEW" "fetchWorkflowEvidenceAttachments"
require_pattern "$EXPENSE_OVERVIEW" "'expense'"
require_pattern "$EXPENSE_OVERVIEW" "evidence:"
require_pattern "$CONTRACTS" "fetchWorkflowEvidenceAttachments('contract'"
require_pattern "$CONTRACTS" "evidence:"
require_pattern "$INDEX" "createWorkflowEvidenceSignedUrl"
require_pattern "$INDEX" "WorkflowEvidenceAttachment"

require_pattern "$LEAVE_ROUTE" "WorkflowEvidenceViewActions"
require_pattern "$EXPENSE_ROUTE" "WorkflowEvidenceViewActions"
require_pattern "$CONTRACTS_ROUTE" "WorkflowEvidenceViewActions"
reject_pattern "$LEAVE_ROUTE" "getPublicUrl"
reject_pattern "$EXPENSE_ROUTE" "getPublicUrl"
reject_pattern "$CONTRACTS_ROUTE" "getPublicUrl"

require_pattern "$TR_LOCALE" '"workflowEvidence"'
require_pattern "$TR_LOCALE" '"view"'
require_pattern "$TR_LOCALE" '"viewFile"'
require_pattern "$TR_LOCALE" '"viewFailed"'
require_pattern "$EN_LOCALE" '"workflowEvidence"'
require_pattern "$EN_LOCALE" '"view"'
require_pattern "$EN_LOCALE" '"viewFile"'
require_pattern "$EN_LOCALE" '"viewFailed"'

require_pattern "$EVIDENCE_TEST" "createWorkflowEvidenceSignedUrl"
require_pattern "$EVIDENCE_TEST" "toHaveBeenCalledWith('tenant-1/expense/upload/evidence.pdf', 120)"
require_pattern "$CONTRACTS_TEST" "evidence:"

require_pattern "$DOC" "PR17.2G1 Evidence Viewing Access"
require_pattern "$DOC" "No SECURITY DEFINER signed-url RPC"
require_pattern "$DOC" 'No `getPublicUrl`'
require_pattern "$DOC" "Evidence view compliance audit"
require_pattern "$G_DOC" "PR17.2G1 — Evidence Viewing Access"
require_pattern "$README" "17_2_g1_evidence_viewing_access.md"
require_pattern "$AUDIT" "Rev 15"
require_pattern "$AUDIT" "17.2G1"
require_pattern "$AUDIT" "✅ Tamamlandı"
require_pattern "$VERIFY_PR17" "verify-17-2-g1-evidence-viewing-access.sh"

echo "PR17.2G1 evidence viewing access verification passed."
