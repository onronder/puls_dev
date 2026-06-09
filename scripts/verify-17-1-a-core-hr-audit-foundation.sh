#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(pwd)}"
cd "$ROOT_DIR"

MIGRATION="supabase/migrations/20260609120000_puls_core_hr_audit_foundation.sql"
DOC="docs/product/17_1_a_core_hr_audit_foundation.md"
README="docs/product/README.md"
AUDIT="docs/product/17_0_product_reality_audit.md"

fail() {
  echo "PR17.1A verify failed: $*" >&2
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

for file in "$MIGRATION" "$DOC" "$README" "$AUDIT"; do
  require_file "$file"
done

require_pattern "$MIGRATION" "write_core_hr_row_audit_log"
require_pattern "$MIGRATION" "_core_hr_audit_transition_metadata"
require_pattern "$MIGRATION" "write_performance_row_audit_log"
require_pattern "$MIGRATION" "_performance_audit_transition_metadata"
require_pattern "$MIGRATION" "puls_core_departments_audit_row"
require_pattern "$MIGRATION" "puls_core_positions_audit_row"
require_pattern "$MIGRATION" "puls_core_employees_audit_row"
require_pattern "$MIGRATION" "puls_performance_cycles_audit_row"
require_pattern "$MIGRATION" "concat('core_hr.', TG_TABLE_NAME"
require_pattern "$MIGRATION" "concat('performance.', TG_TABLE_NAME"
require_pattern "$MIGRATION" "safe_row_audit"
require_pattern "$MIGRATION" "changed_fields"
require_pattern "$MIGRATION" "cost_center_code"
require_pattern "$MIGRATION" "employment_status"
require_pattern "$MIGRATION" "kpi_frequency"
require_pattern "$MIGRATION" "REVOKE ALL ON FUNCTION puls_core.write_core_hr_row_audit_log"
require_pattern "$MIGRATION" "REVOKE ALL ON FUNCTION puls_performance.write_performance_row_audit_log"

reject_pattern "$MIGRATION" "raw_payload"
reject_pattern "$MIGRATION" "credential_value"
reject_pattern "$MIGRATION" "safe_summary"
reject_pattern "$MIGRATION" "email_before"
reject_pattern "$MIGRATION" "email_after"
reject_pattern "$MIGRATION" "full_name_before"
reject_pattern "$MIGRATION" "full_name_after"
reject_pattern "$MIGRATION" "name_before"
reject_pattern "$MIGRATION" "name_after"
reject_pattern "$MIGRATION" "description_before"
reject_pattern "$MIGRATION" "description_after"

require_pattern "$DOC" "Core HR Audit Foundation"
require_pattern "$DOC" "metadata-only audit payloads"
require_pattern "$DOC" "No HR workflow notification producer"
require_pattern "$README" "PR17.1A Core HR audit foundation"
require_pattern "$README" "17_1_a_core_hr_audit_foundation.md"
require_pattern "$AUDIT" "R3"
require_pattern "$AUDIT" "KAPANDI"
require_pattern "$AUDIT" "puls_core.{departments,positions,employees}"

echo "PR17.1A core HR audit foundation verification passed."
