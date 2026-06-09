#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(pwd)}"
cd "$ROOT_DIR"

MIGRATION="supabase/migrations/20260609140000_puls_core_employee_assignment_edit.sql"
DOC="docs/product/17_1_c_employee_assignment_edit.md"
README="docs/product/README.md"
EMPLOYEE_ADAPTER="src/lib/data/core/employees.ts"
READINESS_ADAPTER="src/lib/data/setup/employee-assignment-readiness.ts"
INDEX="src/lib/data/index.ts"
ROUTE="src/routes/_app/calisanlar.tsx"
TR_LOCALE="src/i18n/locales/tr-TR.json"
EN_LOCALE="src/i18n/locales/en-US.json"

fail() {
  echo "PR17.1C verify failed: $*" >&2
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

for file in "$MIGRATION" "$DOC" "$README" "$EMPLOYEE_ADAPTER" "$READINESS_ADAPTER" "$INDEX" "$ROUTE" "$TR_LOCALE" "$EN_LOCALE"; do
  require_file "$file"
done

require_pattern "$MIGRATION" "update_employee_assignment"
require_pattern "$MIGRATION" "PULS_EMPLOYEE_ASSIGNMENT_FORBIDDEN"
require_pattern "$MIGRATION" "PULS_EMPLOYEE_ASSIGNMENT_SOURCE_READ_ONLY"
require_pattern "$MIGRATION" "PULS_EMPLOYEE_ASSIGNMENT_INVALID_DEPARTMENT"
require_pattern "$MIGRATION" "PULS_EMPLOYEE_ASSIGNMENT_POSITION_DEPARTMENT_MISMATCH"
require_pattern "$MIGRATION" "PULS_EMPLOYEE_ASSIGNMENT_MANAGER_CYCLE"
require_pattern "$MIGRATION" "puls_core.employee_reporting_lines"
require_pattern "$MIGRATION" "puls_core.employee_cost_center_assignments"
require_pattern "$MIGRATION" "safe_assignment_audit"
require_pattern "$MIGRATION" "GRANT EXECUTE ON FUNCTION puls_core.update_employee_assignment(UUID, UUID, UUID, UUID, UUID) TO authenticated, service_role"

reject_pattern "$MIGRATION" "DELETE FROM puls_core.employees"
reject_pattern "$MIGRATION" "DELETE FROM puls_core.employee_reporting_lines"
reject_pattern "$MIGRATION" "DELETE FROM puls_core.employee_cost_center_assignments"
reject_pattern "$MIGRATION" "raw_payload"
reject_pattern "$MIGRATION" "credential_value"
reject_pattern "$MIGRATION" "source writeback"
reject_pattern "$MIGRATION" "provider call"

require_pattern "$EMPLOYEE_ADAPTER" "updateEmployeeAssignment"
require_pattern "$EMPLOYEE_ADAPTER" "mapEmployeeAssignmentMutationError"
require_pattern "$EMPLOYEE_ADAPTER" "PULS_EMPLOYEE_ASSIGNMENT_MANAGER_CYCLE"
require_pattern "$READINESS_ADAPTER" "fetchEmployeeAssignmentEditOptions"
require_pattern "$READINESS_ADAPTER" "canEditAssignment"
require_pattern "$READINESS_ADAPTER" "mapOrgEntitySource"
require_pattern "$INDEX" "updateEmployeeAssignment"
require_pattern "$INDEX" "fetchEmployeeAssignmentEditOptions"

require_pattern "$ROUTE" "employee-assignment-form"
require_pattern "$ROUTE" "employeeAssignmentReadiness.edit.open"
require_pattern "$ROUTE" "isSetupAdmin"
require_pattern "$ROUTE" "canEditSelectedAssignment"
require_pattern "$ROUTE" "selectedEmployee.source !== 'puls'"
require_pattern "$ROUTE" "updateEmployeeAssignment"
require_pattern "$ROUTE" "invalidateOrgStructureQueries"

require_pattern "$TR_LOCALE" "Atamaları düzenle"
require_pattern "$TR_LOCALE" "positionDepartmentMismatch"
require_pattern "$EN_LOCALE" "Edit assignments"
require_pattern "$EN_LOCALE" "positionDepartmentMismatch"

require_pattern "$DOC" "Employee Assignment Edit"
require_pattern "$DOC" "No employee create"
require_pattern "$README" "PR17.1C Employee assignment edit"
require_pattern "$README" "17_1_c_employee_assignment_edit.md"

echo "PR17.1C employee assignment edit verification passed."
