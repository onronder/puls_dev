#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT_DIR"

SMOKE="docs/data/17_2_g4b_expense_receipt_ocr_queue_resilience_smoke.sql"
DOC="docs/product/17_2_g4b_expense_receipt_ocr_queue_resilience.md"
G_DOC="docs/product/17_2_g_evidence_review_ocr_contract.md"
README="docs/product/README.md"
AUDIT="docs/product/17_0_product_reality_audit.md"
WORKER="services/workflow-evidence-worker/src/worker.ts"
WORKER_TEST="services/workflow-evidence-worker/src/worker.test.ts"
VERIFY_PR17="scripts/verify-pr17.sh"

fail() {
  echo "PR17.2G4B verify failed: $*" >&2
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

for file in "$SMOKE" "$DOC" "$G_DOC" "$README" "$AUDIT" "$WORKER" "$WORKER_TEST" "$VERIFY_PR17"; do
  require_file "$file"
done

require_pattern "$WORKER" "heartbeat_expense_receipt_ocr_job"
require_pattern "$WORKER" "p_lease_seconds: config.leaseSeconds"
require_pattern "$WORKER" "external_call: false"
require_pattern "$WORKER" "canonical_write: false"
require_pattern "$WORKER" "recover_stale_expense_receipt_ocr_jobs"
reject_pattern "$WORKER" "api.openai.com"
reject_pattern "$WORKER" "generativelanguage.googleapis.com"
reject_pattern "$WORKER" "anthropic.com"
reject_pattern "$WORKER" "mistral.ai"
reject_pattern "$WORKER" "UPDATE puls_workflow.expense_claims"
reject_pattern "$WORKER" "raw_ocr_text"
reject_pattern "$WORKER" "provider_payload"
reject_pattern "$WORKER" "signed_url"
reject_pattern "$WORKER" "public_url"

require_pattern "$WORKER_TEST" "heartbeat_expense_receipt_ocr_job"
require_pattern "$WORKER_TEST" "p_lease_seconds: 300"
require_pattern "$WORKER_TEST" "external_call: false"
require_pattern "$WORKER_TEST" "canonical_write: false"

require_pattern "$SMOKE" "recover_stale_expense_receipt_ocr_jobs"
require_pattern "$SMOKE" "heartbeat_expense_receipt_ocr_job"
require_pattern "$SMOKE" "expense_receipt_ocr.job_heartbeat"
require_pattern "$SMOKE" "expense_receipt_ocr.job_recovered"
require_pattern "$SMOKE" "expense_receipt_ocr.job_dead_lettered"
require_pattern "$SMOKE" "OCR_LEASE_EXPIRED"
require_pattern "$SMOKE" "ocr_status = 'queued'"
require_pattern "$SMOKE" "ocr_status = 'processing'"
require_pattern "$SMOKE" "ocr_status = 'failed'"
require_pattern "$SMOKE" "operator_review_required IS TRUE"
require_pattern "$SMOKE" "ROLLBACK;"
reject_pattern "$SMOKE" "COMMIT;"

require_pattern "$DOC" "PR17.2G4B Expense Receipt OCR Queue Resilience"
require_pattern "$DOC" "No new migration"
require_pattern "$DOC" "No paid OCR/VLM provider"
require_pattern "$DOC" 'No canonical `expense_claims` write'
require_pattern "$G_DOC" "G4B"
require_pattern "$README" "17_2_g4b_expense_receipt_ocr_queue_resilience.md"
require_pattern "$AUDIT" "Rev 20"
require_pattern "$AUDIT" "PR17.2G4B"
require_pattern "$VERIFY_PR17" "verify-17-2-g4b-expense-receipt-ocr-queue-resilience.sh"

echo "PR17.2G4B expense receipt OCR queue resilience verification passed."
