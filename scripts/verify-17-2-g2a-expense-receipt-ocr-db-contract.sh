#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT_DIR"

MIGRATION="supabase/migrations/20260610150000_puls_workflow_expense_receipt_ocr_db_contract.sql"
DOC="docs/product/17_2_g2a_expense_receipt_ocr_db_contract.md"
G_DOC="docs/product/17_2_g_evidence_review_ocr_contract.md"
README="docs/product/README.md"
AUDIT="docs/product/17_0_product_reality_audit.md"
SMOKE="docs/data/17_2_g2a_expense_receipt_ocr_db_contract_smoke.sql"
VERIFY_PR17="scripts/verify-pr17.sh"
VERIFY_SELF="scripts/verify-17-2-g2a-expense-receipt-ocr-db-contract.sh"

fail() {
  echo "PR17.2G2A verify failed: $*" >&2
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

for file in "$MIGRATION" "$DOC" "$G_DOC" "$README" "$AUDIT" "$SMOKE" "$VERIFY_PR17" "$VERIFY_SELF"; do
  require_file "$file"
done

require_executable "$VERIFY_PR17"
require_executable "$VERIFY_SELF"

require_pattern "$MIGRATION" "CREATE TYPE puls_workflow.expense_receipt_ocr_job_status"
require_pattern "$MIGRATION" "CREATE TABLE IF NOT EXISTS puls_workflow.expense_receipt_ocr_jobs"
require_pattern "$MIGRATION" "CREATE TABLE IF NOT EXISTS puls_workflow.expense_receipt_ocr_results"
require_pattern "$MIGRATION" "CREATE TABLE IF NOT EXISTS puls_workflow.expense_receipt_ocr_job_events"
require_pattern "$MIGRATION" "expense_receipt_ocr_jobs_active_concurrency_idx"
require_pattern "$MIGRATION" "UNIQUE (tenant_id, idempotency_key)"
require_pattern "$MIGRATION" "FOR UPDATE SKIP LOCKED"
require_pattern "$MIGRATION" "lease_expires_at"
require_pattern "$MIGRATION" "server_sha256"
require_pattern "$MIGRATION" "duplicate_of_result_id"
require_pattern "$MIGRATION" "duplicate_suspected"
require_pattern "$MIGRATION" "expense_receipts"
require_pattern "$MIGRATION" "SET ocr_status = 'queued'"
require_pattern "$MIGRATION" "SET ocr_status = 'processing'"
require_pattern "$MIGRATION" "SET ocr_status = v_receipt_status"
require_pattern "$MIGRATION" "expense_receipt_ocr_safe_context_has_blocked_key"
require_pattern "$MIGRATION" "'raw_payload'"
require_pattern "$MIGRATION" "'provider_payload'"
require_pattern "$MIGRATION" "'ocr_text'"
require_pattern "$MIGRATION" "'storage_path'"
require_pattern "$MIGRATION" "auth.role() <> 'service_role'"
require_pattern "$MIGRATION" "GRANT EXECUTE ON FUNCTION puls_workflow.enqueue_expense_receipt_ocr_job"
require_pattern "$MIGRATION" "GRANT EXECUTE ON FUNCTION puls_workflow.claim_next_expense_receipt_ocr_job"
require_pattern "$MIGRATION" "GRANT EXECUTE ON FUNCTION puls_workflow.complete_expense_receipt_ocr_job"
require_pattern "$MIGRATION" "GRANT EXECUTE ON FUNCTION puls_workflow.recover_stale_expense_receipt_ocr_jobs"
require_pattern "$MIGRATION" "No trigger or browser path enqueues production jobs"

reject_pattern "$MIGRATION" "AFTER INSERT ON puls_workflow.expense_receipts"
reject_pattern "$MIGRATION" "CREATE EXTENSION IF NOT EXISTS http"
reject_pattern "$MIGRATION" "net.http"
reject_pattern "$MIGRATION" "azure"
reject_pattern "$MIGRATION" "google"
reject_pattern "$MIGRATION" "aws"
reject_pattern "$MIGRATION" "textract"
reject_pattern "$MIGRATION" "document intelligence"
reject_pattern "$MIGRATION" "getPublicUrl"

require_pattern "$SMOKE" "PR17.2G2A"
require_pattern "$SMOKE" "ROLLBACK;"
require_pattern "$SMOKE" "enqueue_expense_receipt_ocr_job"
require_pattern "$SMOKE" "claim_next_expense_receipt_ocr_job"
require_pattern "$SMOKE" "heartbeat_expense_receipt_ocr_job"
require_pattern "$SMOKE" "complete_expense_receipt_ocr_job"
require_pattern "$SMOKE" "duplicate_suspected"
reject_pattern "$SMOKE" "COMMIT;"

require_pattern "$DOC" "PR17.2G2A Expense Receipt OCR DB Contract"
require_pattern "$DOC" "No OCR provider, worker deployment, browser enqueue, or external network call"
require_pattern "$DOC" "no production enqueue path"
require_pattern "$DOC" "sha256_client remains informational"
require_pattern "$DOC" "No trigger automatically enqueues"
require_pattern "$DOC" "No XML/e-fatura intake is opened"
require_pattern "$DOC" "No raw OCR text"
require_pattern "$DOC" 'psql "$DATABASE_URL" -f docs/data/17_2_g2a_expense_receipt_ocr_db_contract_smoke.sql'
require_pattern "$G_DOC" "G2A — DB contract"
require_pattern "$G_DOC" "No trigger should enqueue"
require_pattern "$G_DOC" "No browser/authenticated role should enqueue"
require_pattern "$G_DOC" "Production enqueue waits"
require_pattern "$README" "17_2_g2a_expense_receipt_ocr_db_contract.md"
require_pattern "$AUDIT" "Rev 19"
require_pattern "$AUDIT" "17.2G2A"
require_pattern "$AUDIT" "✅ Tamamlandı"
require_pattern "$AUDIT" "canonical expense write açılmaz"
require_pattern "$VERIFY_PR17" "verify-17-2-g2a-expense-receipt-ocr-db-contract.sh"

echo "PR17.2G2A expense receipt OCR DB contract verification passed."
