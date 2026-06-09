#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(pwd)}"
cd "$ROOT_DIR"

MIGRATION="supabase/migrations/20260609130000_puls_core_org_lifecycle_hardening.sql"
DOC="docs/product/17_1_b_core_org_lifecycle.md"
README="docs/product/README.md"
ADAPTER="src/lib/data/core/organization.ts"
INDEX="src/lib/data/index.ts"
DEPARTMENTS_ROUTE="src/routes/_app/departmanlar.tsx"
POSITIONS_ROUTE="src/routes/_app/pozisyonlar.tsx"
TR_LOCALE="src/i18n/locales/tr-TR.json"
EN_LOCALE="src/i18n/locales/en-US.json"

fail() {
  echo "PR17.1B verify failed: $*" >&2
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

for file in "$MIGRATION" "$DOC" "$README" "$ADAPTER" "$INDEX" "$DEPARTMENTS_ROUTE" "$POSITIONS_ROUTE" "$TR_LOCALE" "$EN_LOCALE"; do
  require_file "$file"
done

require_pattern "$MIGRATION" "deactivate_department"
require_pattern "$MIGRATION" "restore_department"
require_pattern "$MIGRATION" "deactivate_position"
require_pattern "$MIGRATION" "restore_position"
require_pattern "$MIGRATION" "PULS_ORG_LIFECYCLE_FORBIDDEN"
require_pattern "$MIGRATION" "PULS_ORG_DEPARTMENT_IN_USE_ACTIVE_EMPLOYEES"
require_pattern "$MIGRATION" "PULS_ORG_DEPARTMENT_IN_USE_ACTIVE_POSITIONS"
require_pattern "$MIGRATION" "PULS_ORG_POSITION_IN_USE_ACTIVE_EMPLOYEES"
require_pattern "$MIGRATION" "PULS_ORG_POSITION_DEPARTMENT_INACTIVE"
require_pattern "$MIGRATION" "NULLIF(BTRIM(v_department.external_source), '') IS NOT NULL"
require_pattern "$MIGRATION" "NULLIF(BTRIM(v_position.external_source), '') IS NOT NULL"
require_pattern "$MIGRATION" "GRANT EXECUTE ON FUNCTION puls_core.deactivate_department(UUID) TO authenticated, service_role"
require_pattern "$MIGRATION" "GRANT EXECUTE ON FUNCTION puls_core.restore_position(UUID) TO authenticated, service_role"

reject_pattern "$MIGRATION" "DELETE FROM puls_core.departments"
reject_pattern "$MIGRATION" "DELETE FROM puls_core.positions"
reject_pattern "$MIGRATION" "raw_payload"
reject_pattern "$MIGRATION" "credential_value"
reject_pattern "$MIGRATION" "source writeback"

require_pattern "$ADAPTER" "applyOrgEntityLifecycleFilter"
require_pattern "$ADAPTER" "deactivateDepartment"
require_pattern "$ADAPTER" "restoreDepartment"
require_pattern "$ADAPTER" "deactivatePosition"
require_pattern "$ADAPTER" "restorePosition"
require_pattern "$ADAPTER" "mapDepartmentLifecycleError"
require_pattern "$ADAPTER" "mapPositionLifecycleError"

require_pattern "$INDEX" "deactivateDepartment"
require_pattern "$INDEX" "restorePosition"

require_pattern "$DEPARTMENTS_ROUTE" "Segmented"
require_pattern "$DEPARTMENTS_ROUTE" "handleDepartmentLifecycleAction"
require_pattern "$DEPARTMENTS_ROUTE" "applyOrgEntityLifecycleFilter"
require_pattern "$POSITIONS_ROUTE" "Segmented"
require_pattern "$POSITIONS_ROUTE" "handlePositionLifecycleAction"
require_pattern "$POSITIONS_ROUTE" "applyOrgEntityLifecycleFilter"

require_pattern "$TR_LOCALE" "departmentActiveEmployees"
require_pattern "$TR_LOCALE" "positionDepartmentInactive"
require_pattern "$EN_LOCALE" "departmentActiveEmployees"
require_pattern "$EN_LOCALE" "positionDepartmentInactive"

require_pattern "$DOC" "Core Org Lifecycle"
require_pattern "$DOC" "No hard delete"
require_pattern "$README" "PR17.1B Core org lifecycle"
require_pattern "$README" "17_1_b_core_org_lifecycle.md"

echo "PR17.1B core org lifecycle verification passed."
