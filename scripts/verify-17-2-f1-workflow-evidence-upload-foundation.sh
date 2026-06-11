#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT_DIR"

MIGRATION="supabase/migrations/20260610110000_puls_workflow_evidence_upload_foundation.sql"
DOC="docs/product/17_2_f_workflow_evidence_upload_foundation.md"
README="docs/product/README.md"
AUDIT="docs/product/17_0_product_reality_audit.md"
VERIFY_PR17="scripts/verify-pr17.sh"
VERIFY_SELF="scripts/verify-17-2-f1-workflow-evidence-upload-foundation.sh"

fail() {
  echo "PR17.2F1 verify failed: $*" >&2
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

for file in "$MIGRATION" "$DOC" "$README" "$AUDIT" "$VERIFY_PR17" "$VERIFY_SELF"; do
  require_file "$file"
done

require_executable "$VERIFY_PR17"
require_executable "$VERIFY_SELF"

require_pattern "$MIGRATION" "CREATE TYPE puls_workflow.evidence_upload_domain"
require_pattern "$MIGRATION" "CREATE TYPE puls_workflow.evidence_upload_status"
require_pattern "$MIGRATION" "CREATE TYPE puls_workflow.evidence_scan_status"
require_pattern "$MIGRATION" "INSERT INTO storage.buckets"
require_pattern "$MIGRATION" "'workflow-evidence'"
require_pattern "$MIGRATION" "CREATE TABLE IF NOT EXISTS puls_workflow.evidence_uploads"
require_pattern "$MIGRATION" "sha256_client TEXT NULL"
require_pattern "$MIGRATION" "status puls_workflow.evidence_upload_status"
require_pattern "$MIGRATION" "scan_status puls_workflow.evidence_scan_status"
require_pattern "$MIGRATION" "expires_at TIMESTAMPTZ"
require_pattern "$MIGRATION" "CREATE OR REPLACE FUNCTION puls_workflow.create_workflow_evidence_upload_intent"
require_pattern "$MIGRATION" "CREATE OR REPLACE FUNCTION puls_workflow.finalize_workflow_evidence_upload"
require_pattern "$MIGRATION" "CREATE OR REPLACE FUNCTION puls_workflow.attach_contract_file_evidence"
require_pattern "$MIGRATION" "server_generated_storage_path"
require_pattern "$MIGRATION" "storage_object_exists"
require_pattern "$MIGRATION" "workflow_evidence.intent_created"
require_pattern "$MIGRATION" "workflow_evidence.upload_finalized"
require_pattern "$MIGRATION" "workflow_evidence.contract_file_attached"
require_pattern "$MIGRATION" "workflow_evidence_objects_insert"
require_pattern "$MIGRATION" "can_upload_workflow_evidence_storage_object"
require_pattern "$MIGRATION" "can_read_workflow_evidence_storage_object"
require_pattern "$MIGRATION" "DROP POLICY IF EXISTS puls_workflow_leave_documents_insert"
require_pattern "$MIGRATION" "DROP POLICY IF EXISTS puls_workflow_expense_receipts_insert"
require_pattern "$MIGRATION" "DROP POLICY IF EXISTS puls_workflow_contract_files_insert"
require_pattern "$MIGRATION" "ADD COLUMN IF NOT EXISTS uploaded_by_employee_id"
require_pattern "$MIGRATION" "metadata_only"
require_pattern "$MIGRATION" "_workflow_evidence_is_assigned_approver"

reject_pattern "$MIGRATION" "create_leave_request_with_evidence"
reject_pattern "$MIGRATION" "create_expense_claim_with_evidence"
reject_pattern "$MIGRATION" "ocr_confidence"
reject_pattern "$MIGRATION" "ocr_vendor"
reject_pattern "$MIGRATION" "virus_scanned"
reject_pattern "$MIGRATION" "public = TRUE"
reject_pattern "$MIGRATION" "decision_note"
reject_pattern "$MIGRATION" "raw_payload ->"
reject_pattern "$MIGRATION" "credential_value"

require_pattern "$DOC" "PR17.2F is split into F1, F2, and F3"
require_pattern "$DOC" "PR17.2F1 Backend Boundary"
require_pattern "$DOC" "PR17.2F2 Product Flow"
require_pattern "$DOC" "PR17.2F3 Finalization Hardening"
require_pattern "$DOC" '`sha256_client` is client-declared'
require_pattern "$DOC" "scan_status = 'not_scanned'"
require_pattern "$DOC" "OCR"
require_pattern "$DOC" "Non-Goals"

require_pattern "$README" "PR17.2F Workflow evidence upload foundation"
require_pattern "$README" "PR17.2F1 Backend Boundary"
require_pattern "$README" "PR17.2F2 Product Flow"
require_pattern "$README" "PR17.2F3 Evidence Finalization Hardening"
require_pattern "$AUDIT" "Rev 18"
require_pattern "$AUDIT" "17.2F1"
require_pattern "$AUDIT" "17.2F2"
require_pattern "$AUDIT" "17.2F3"
require_pattern "$VERIFY_PR17" "verify-17-2-f1-workflow-evidence-upload-foundation.sh"

echo "PR17.2F1 workflow evidence upload foundation verification passed."
