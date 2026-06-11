#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT_DIR"

DOC="docs/product/17_2_g2b_workflow_evidence_worker_skeleton.md"
G_DOC="docs/product/17_2_g_evidence_review_ocr_contract.md"
README="docs/product/README.md"
AUDIT="docs/product/17_0_product_reality_audit.md"
SERVICE_DIR="services/workflow-evidence-worker"
PACKAGE="$SERVICE_DIR/package.json"
SERVICE_README="$SERVICE_DIR/README.md"
INDEX="$SERVICE_DIR/src/index.ts"
WORKER="$SERVICE_DIR/src/worker.ts"
WORKER_TEST="$SERVICE_DIR/src/worker.test.ts"
VERIFY_PR17="scripts/verify-pr17.sh"
VERIFY_SELF="scripts/verify-17-2-g2b-workflow-evidence-worker-skeleton.sh"

fail() {
  echo "PR17.2G2B verify failed: $*" >&2
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

for file in "$DOC" "$G_DOC" "$README" "$AUDIT" "$PACKAGE" "$SERVICE_README" "$INDEX" "$WORKER" "$WORKER_TEST" "$VERIFY_PR17" "$VERIFY_SELF"; do
  require_file "$file"
done

require_executable "$VERIFY_PR17"
require_executable "$VERIFY_SELF"

[[ ! -f "$SERVICE_DIR/railway.toml" ]] || fail "G2B must not add a Railway deployment file"

require_pattern "$PACKAGE" '"name": "@puls/workflow-evidence-worker"'
require_pattern "$PACKAGE" '"start": "node --experimental-strip-types src/index.ts"'
require_pattern "$SERVICE_README" "disabled-by-default worker skeleton"
require_pattern "$SERVICE_README" "compute a server-side SHA-256"
require_pattern "$SERVICE_README" "does not"
require_pattern "$INDEX" "workflow-evidence-worker"
require_pattern "$INDEX" "startWorkflowEvidenceWorkerLoop"

require_pattern "$WORKER" "PULS_WORKFLOW_EVIDENCE_WORKER_ENABLED"
require_pattern "$WORKER" "PULS_WORKFLOW_EVIDENCE_PROVIDER_CLASS"
require_pattern "$WORKER" "enabled: parseBoolean(env.PULS_WORKFLOW_EVIDENCE_WORKER_ENABLED, false)"
require_pattern "$WORKER" "providerClass: resolveProviderClass"
require_pattern "$WORKER" "externalProviderCalls: false"
require_pattern "$WORKER" "browserEnqueue: false"
require_pattern "$WORKER" "erpConnectorCoupling: false"
require_pattern "$WORKER" "canonicalExpenseWrites: false"
require_pattern "$WORKER" "rawOcrTextStorage: false"
require_pattern "$WORKER" "serverSideContentHash: true"
require_pattern "$WORKER" "buildSupabaseStorageHeaders"
require_pattern "$WORKER" "buildWorkflowEvidenceObjectUrl"
require_pattern "$WORKER" "/storage/v1/object/"
require_pattern "$WORKER" "computeSha256Hex"
require_pattern "$WORKER" "createHash('sha256')"
require_pattern "$WORKER" "claim_next_expense_receipt_ocr_job"
require_pattern "$WORKER" "complete_expense_receipt_ocr_job"
require_pattern "$WORKER" "recover_stale_expense_receipt_ocr_jobs"
require_pattern "$WORKER" "downloadWorkflowEvidenceObject"
require_pattern "$WORKER" "buildDisabledProviderExtraction"
require_pattern "$WORKER" "external_call: false"
require_pattern "$WORKER" "estimated_cost_minor: 0"
require_pattern "$WORKER" "human_review_required"
require_pattern "$WORKER" "server_side_content_hash: true"

reject_pattern "$WORKER" "getPublicUrl"
reject_pattern "$WORKER" "azure"
reject_pattern "$WORKER" "google"
reject_pattern "$WORKER" "aws"
reject_pattern "$WORKER" "textract"
reject_pattern "$WORKER" "document intelligence"
reject_pattern "$WORKER" "expense_claims"
reject_pattern "$WORKER" "p_amount"
reject_pattern "$WORKER" "p_expense_date"
reject_pattern "$WORKER" "p_category"
reject_pattern "$WORKER" "raw_ocr_text"
reject_pattern "$WORKER" "provider_payload"
reject_pattern "$WORKER" "signed_url"
reject_pattern "$WORKER" "public_url"

require_pattern "$WORKER_TEST" "computeSha256Hex"
require_pattern "$WORKER_TEST" "downloadWorkflowEvidenceObject"
require_pattern "$WORKER_TEST" "runWorkerOnce"
require_pattern "$WORKER_TEST" "complete_expense_receipt_ocr_job"
require_pattern "$WORKER_TEST" "serverSha256"
require_pattern "$WORKER_TEST" "not.toContain('tenant-1/expense/evidence.pdf')"
require_pattern "$WORKER_TEST" "externalProviderCalls: false"
require_pattern "$WORKER_TEST" "canonicalExpenseWrites: false"

require_pattern "$DOC" "PR17.2G2B Workflow Evidence Worker Skeleton"
require_pattern "$DOC" "disabled-by-default worker skeleton"
require_pattern "$DOC" "No OCR provider SDK"
require_pattern "$DOC" "No Railway deployment file"
require_pattern "$DOC" "No automatic enqueue trigger"
require_pattern "$DOC" "No browser enqueue"
require_pattern "$DOC" 'No canonical `expense_claims` mutation'
require_pattern "$DOC" "server-side SHA-256"
require_pattern "$G_DOC" "G2B worker decision"
require_pattern "$G_DOC" "services/workflow-evidence-worker"
require_pattern "$README" "17_2_g2b_workflow_evidence_worker_skeleton.md"
require_pattern "$AUDIT" "Rev 17"
require_pattern "$AUDIT" "17.2G2B"
require_pattern "$AUDIT" "✅ Tamamlandı"
require_pattern "$AUDIT" "production enqueue, Railway deploy ve paid OCR/VLM provider hâlâ kapalı"
require_pattern "$VERIFY_PR17" "verify-17-2-g2b-workflow-evidence-worker-skeleton.sh"

echo "PR17.2G2B workflow evidence worker skeleton verification passed."
