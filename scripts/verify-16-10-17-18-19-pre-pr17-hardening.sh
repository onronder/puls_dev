#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(pwd)}"
cd "$ROOT_DIR"

fail() {
  echo "verify-16-10-17-18-19: $1" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "missing file: $path"
}

require_pattern() {
  local path="$1"
  local pattern="$2"
  grep -Fq "$pattern" "$path" || fail "missing pattern in $path: $pattern"
}

reject_pattern() {
  local path="$1"
  local pattern="$2"
  if grep -Fq "$pattern" "$path"; then
    fail "forbidden pattern in $path: $pattern"
  fi
}

DOC="docs/product/16_10_17_18_19_pre_pr17_hardening.md"
MIGRATION="supabase/migrations/20260609100000_puls_performance_cycle_lifecycle_hardening.sql"
READINESS="src/lib/data/setup/request-creation-readiness.ts"
READINESS_TEST="src/lib/data/setup/request-creation-readiness.test.ts"
LEAVE_ROUTE="src/routes/_app/izin.tsx"
EXPENSE_ROUTE="src/routes/_app/masraf.tsx"
PERFORMANCE_ADAPTER="src/lib/data/performance/cycles.ts"
PERFORMANCE_TEST="src/lib/data/performance/cycles.test.ts"
PERSONA="src/lib/persona.ts"
PERSONA_TEST="src/lib/persona.test.ts"
FILE_IMPORT="src/lib/data/setup/file-import-contract.ts"
FILE_IMPORT_TEST="src/lib/data/setup/file-import-contract.test.ts"
TR_LOCALE="src/i18n/locales/tr-TR.json"
EN_LOCALE="src/i18n/locales/en-US.json"
README="docs/product/README.md"

for path in \
  "$DOC" \
  "$MIGRATION" \
  "$READINESS" \
  "$READINESS_TEST" \
  "$LEAVE_ROUTE" \
  "$EXPENSE_ROUTE" \
  "$PERFORMANCE_ADAPTER" \
  "$PERFORMANCE_TEST" \
  "$PERSONA" \
  "$PERSONA_TEST" \
  "$FILE_IMPORT" \
  "$FILE_IMPORT_TEST" \
  "$TR_LOCALE" \
  "$EN_LOCALE" \
  "$README"
do
  require_file "$path"
done

require_pattern "$READINESS" "invalid_expense_category"
require_pattern "$READINESS" "invalid_leave_type"
require_pattern "$READINESS_TEST" "blocks a selected expense category that is no longer active"
require_pattern "$READINESS_TEST" "blocks a selected leave type that is no longer active"
require_pattern "$EXPENSE_ROUTE" "selectedCategoryIsAvailable"
require_pattern "$EXPENSE_ROUTE" "!selectedCategoryIsAvailable"
require_pattern "$LEAVE_ROUTE" "selectedLeaveType"
require_pattern "$LEAVE_ROUTE" "resolvedLeaveType"

require_pattern "$PERFORMANCE_ADAPTER" "canTransitionPerformanceCycleStatus"
require_pattern "$PERFORMANCE_TEST" "allows only draft to active and active to closed lifecycle moves"
require_pattern "$MIGRATION" "enforce_performance_cycle_lifecycle"
require_pattern "$MIGRATION" "PULS_PERFORMANCE_ACTIVE_CYCLE_EXISTS"
require_pattern "$MIGRATION" "performance_cycles_one_active_per_tenant_idx"

require_pattern "$PERSONA" ".schema('puls_audit')"
reject_pattern "$PERSONA" ".schema('audit')"
reject_pattern "$PERSONA" "from('audit_log')"
require_pattern "$PERSONA_TEST" "does not fall back to legacy audit schemas"

require_pattern "$FILE_IMPORT" "FORMULA_LIKE_TEXT_VALUE"
require_pattern "$FILE_IMPORT" "sanitizeFileImportCsvExportValue"
require_pattern "$FILE_IMPORT_TEST" "flags them for safe export handling"
require_pattern "$FILE_IMPORT_TEST" "sanitizes formula-like values"
require_pattern "$TR_LOCALE" "FORMULA_LIKE_TEXT_VALUE"
require_pattern "$EN_LOCALE" "FORMULA_LIKE_TEXT_VALUE"

require_pattern "$README" "PR16.10.17-19"
require_pattern "$README" "16_10_17_18_19_pre_pr17_hardening.md"

echo "verify-16-10-17-18-19: OK"
