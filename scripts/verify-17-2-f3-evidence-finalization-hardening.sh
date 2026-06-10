#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT_DIR"

MIGRATION="supabase/migrations/20260610130000_puls_workflow_evidence_finalization_hardening.sql"
DOC="docs/product/17_2_f3_evidence_finalization_hardening.md"
FOUNDATION_DOC="docs/product/17_2_f_workflow_evidence_upload_foundation.md"
README="docs/product/README.md"
AUDIT="docs/product/17_0_product_reality_audit.md"
ERRORS="src/lib/data/errors.ts"
ERRORS_TEST="src/lib/data/errors.test.ts"
TR_LOCALE="src/i18n/locales/tr-TR.json"
EN_LOCALE="src/i18n/locales/en-US.json"
VERIFY_PR17="scripts/verify-pr17.sh"
VERIFY_SELF="scripts/verify-17-2-f3-evidence-finalization-hardening.sh"

fail() {
  echo "PR17.2F3 verify failed: $*" >&2
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

for file in "$MIGRATION" "$DOC" "$FOUNDATION_DOC" "$README" "$AUDIT" "$ERRORS" "$ERRORS_TEST" "$TR_LOCALE" "$EN_LOCALE" "$VERIFY_PR17" "$VERIFY_SELF"; do
  require_file "$file"
done

require_executable "$VERIFY_PR17"
require_executable "$VERIFY_SELF"

require_pattern "$MIGRATION" "CREATE OR REPLACE FUNCTION puls_workflow.finalize_workflow_evidence_upload"
require_pattern "$MIGRATION" "SELECT object.metadata ->> 'size'"
require_pattern "$MIGRATION" "TRANSLATE(v_storage_size_text, '0123456789', '') <> ''"
require_pattern "$MIGRATION" "PULS_EVIDENCE_STORAGE_SIZE_UNVERIFIED"
require_pattern "$MIGRATION" "PULS_EVIDENCE_STORAGE_SIZE_MISMATCH"
require_pattern "$MIGRATION" "storage_size_verified"
require_pattern "$MIGRATION" "SHA-256 remains client-declared metadata"
require_pattern "$MIGRATION" "GRANT EXECUTE ON FUNCTION puls_workflow.finalize_workflow_evidence_upload"
reject_pattern "$MIGRATION" "ocr_confidence"
reject_pattern "$MIGRATION" "ocr_vendor"
reject_pattern "$MIGRATION" "virus_scanned"
reject_pattern "$MIGRATION" "public = TRUE"

require_pattern "$ERRORS" "PULS_EVIDENCE_STORAGE_SIZE_UNVERIFIED"
require_pattern "$ERRORS" "workflowEvidence.error.storageSizeUnverified"
require_pattern "$ERRORS" "PULS_EVIDENCE_STORAGE_SIZE_MISMATCH"
require_pattern "$ERRORS" "workflowEvidence.error.storageSizeMismatch"
require_pattern "$ERRORS_TEST" "PULS_EVIDENCE_STORAGE_SIZE_UNVERIFIED"
require_pattern "$ERRORS_TEST" "PULS_EVIDENCE_STORAGE_SIZE_MISMATCH"

require_pattern "$TR_LOCALE" "storageSizeUnverified"
require_pattern "$TR_LOCALE" "storageSizeMismatch"
require_pattern "$EN_LOCALE" "storageSizeUnverified"
require_pattern "$EN_LOCALE" "storageSizeMismatch"

require_pattern "$DOC" "PR17.2F3 Evidence Finalization Hardening"
require_pattern "$DOC" "storage.objects.metadata ->> 'size'"
require_pattern "$DOC" "server-computed content hashing"
require_pattern "$FOUNDATION_DOC" "PR17.2F3 Finalization Hardening"
require_pattern "$FOUNDATION_DOC" "storage_size_verified: true"
require_pattern "$README" "17_2_f3_evidence_finalization_hardening.md"
require_pattern "$AUDIT" "Rev 14"
require_pattern "$AUDIT" "17.2F1/F2/F3 + 17.2G1/G2A/G2B tamam"
require_pattern "$VERIFY_PR17" "verify-17-2-f3-evidence-finalization-hardening.sh"

echo "PR17.2F3 evidence finalization hardening verification passed."
