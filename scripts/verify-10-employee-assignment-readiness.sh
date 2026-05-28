#!/usr/bin/env bash
# Verifies 10 PR10.15 employee assignment readiness (POSIX grep/awk).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
MATRIX="docs/data/10_employee_assignment_readiness_matrix.md"
SMOKE="docs/data/10_employee_assignment_readiness_smoke.sql"
ASSIGN_READINESS="src/lib/data/setup/employee-assignment-readiness.ts"
ASSIGN_READINESS_TEST="src/lib/data/setup/employee-assignment-readiness.test.ts"
EMPLOYEES_ROUTE="src/routes/_app/calisanlar.tsx"
DATA_INDEX="src/lib/data/index.ts"
I18N_TR="src/i18n/locales/tr-TR.json"
I18N_EN="src/i18n/locales/en-US.json"

smoke() {
  git show "${REF}:${SMOKE}" 2>/dev/null || cat "${SMOKE}"
}

file_at_ref() {
  local path="$1"
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

MATRIX_CONTENT="$(file_at_ref "$MATRIX")"
SMOKE_CONTENT="$(smoke)"
ASSIGN_READINESS_CONTENT="$(file_at_ref "$ASSIGN_READINESS")"
ASSIGN_READINESS_TEST_CONTENT="$(file_at_ref "$ASSIGN_READINESS_TEST")"
EMPLOYEES_ROUTE_CONTENT="$(file_at_ref "$EMPLOYEES_ROUTE")"
DATA_INDEX_CONTENT="$(file_at_ref "$DATA_INDEX")"

echo "Checking ${REF}: PR10.15 employee assignment readiness ..."

for file in "$MATRIX" "$SMOKE" "$ASSIGN_READINESS" "$ASSIGN_READINESS_TEST" "$EMPLOYEES_ROUTE" "$DATA_INDEX"; do
  if [[ ! -f "$file" ]]; then
    echo "FAIL: missing required file: $file"
    exit 1
  fi
done

MIGRATION_CHANGES="$(git diff --name-only --diff-filter=A origin/main...HEAD -- supabase/migrations/ 2>/dev/null || true)"
if [[ -n "$(echo "$MIGRATION_CHANGES" | sed '/^$/d')" ]]; then
  echo "FAIL: PR10.15 must not add migrations:"
  echo "$MIGRATION_CHANGES" | sed '/^$/d'
  exit 1
fi

matrix_needles=(
  "department"
  "position"
  "cost center"
  "reporting line"
  "No ERP writes"
  "no resolver/decide"
)

for needle in "${matrix_needles[@]}"; do
  if ! grep -Fiq "$needle" <<< "$MATRIX_CONTENT"; then
    echo "FAIL: matrix doc missing required topic: $needle"
    exit 1
  fi
done

smoke_needles=(
  "BEGIN;"
  "ROLLBACK;"
  "demo_employee_assignment_readiness"
  "cross-tenant"
  "employee_cost_center_assignments"
  "employee_reporting_lines"
  "primary_manager"
)

for needle in "${smoke_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$SMOKE_CONTENT"; then
    echo "FAIL: smoke missing required fragment: $needle"
    exit 1
  fi
done

adapter_needles=(
  "fetchEmployeeAssignmentReadiness"
  "computeEmployeeAssignmentReadiness"
  "buildEmployeeAssignmentReadinessSummary"
  "applyEmployeeAssignmentReadinessFilter"
  "pickCurrentCostCenterAssignment"
  "pickCurrentPrimaryManager"
)

for needle in "${adapter_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$ASSIGN_READINESS_CONTENT"; then
    echo "FAIL: adapter missing required fragment: $needle"
    exit 1
  fi
done

if ! grep -Fq "resolveTenantContext" <<< "$ASSIGN_READINESS_CONTENT"; then
  echo "FAIL: adapter must use resolveTenantContext"
  exit 1
fi

if ! grep -Fq ".eq('tenant_id'" <<< "$ASSIGN_READINESS_CONTENT"; then
  echo "FAIL: adapter must tenant-scope queries with .eq('tenant_id'"
  exit 1
fi

for needle in computeEmployeeAssignmentReadiness buildEmployeeAssignmentReadinessSummary; do
  if ! grep -Fq "$needle" <<< "$ASSIGN_READINESS_TEST_CONTENT"; then
    echo "FAIL: tests must cover $needle"
    exit 1
  fi
done

if ! grep -Fq "fetchEmployeeAssignmentReadiness" <<< "$EMPLOYEES_ROUTE_CONTENT"; then
  echo "FAIL: calisanlar must use fetchEmployeeAssignmentReadiness"
  exit 1
fi

if ! grep -Fq "StatusPill" <<< "$EMPLOYEES_ROUTE_CONTENT"; then
  echo "FAIL: calisanlar must render readiness StatusPill"
  exit 1
fi

if ! grep -Fq "applyEmployeeAssignmentReadinessFilter" <<< "$EMPLOYEES_ROUTE_CONTENT"; then
  echo "FAIL: calisanlar must use applyEmployeeAssignmentReadinessFilter"
  exit 1
fi

if grep -Fq "common.soon" <<< "$EMPLOYEES_ROUTE_CONTENT"; then
  echo "FAIL: calisanlar must not use common.soon"
  exit 1
fi

if ! grep -Fq "employee-assignment-readiness" <<< "$DATA_INDEX_CONTENT"; then
  echo "FAIL: data index must export employee-assignment-readiness helpers"
  exit 1
fi

for key in ready missing_department missing_position missing_cost_center missing_manager inactive_reference partial unknown; do
  if ! grep -Fq "\"$key\"" "$I18N_TR" || ! grep -Fq "\"$key\"" "$I18N_EN"; then
    echo "FAIL: missing i18n key employeeAssignmentReadiness.status.$key"
    exit 1
  fi
done

for key in all ready missingDepartment missingPosition missingCostCenter missingManager; do
  if ! grep -Fq "\"$key\"" "$I18N_TR" || ! grep -Fq "\"$key\"" "$I18N_EN"; then
    echo "FAIL: missing i18n key employeeAssignmentReadiness.filters.$key"
    exit 1
  fi
done

CHANGED_DATA_FILES=()
while IFS= read -r file; do
  [[ -n "$file" ]] && CHANGED_DATA_FILES+=("$file")
done < <(git diff --name-only origin/main...HEAD -- 'src/lib/data/**' 2>/dev/null || true)

scan_forbidden_in_data() {
  local pattern="$1"
  local label="$2"
  for file in "${CHANGED_DATA_FILES[@]}"; do
    if [[ -f "$file" ]] && grep -Eiq "$pattern" "$file"; then
      echo "FAIL: forbidden runtime pattern ($label) in changed data file $file: $pattern"
      grep -Ein "$pattern" "$file" || true
      exit 1
    fi
  done
}

if ((${#CHANGED_DATA_FILES[@]} > 0)); then
  scan_forbidden_in_data 'resolveApprover\(|decideApproval\(|importApply\(|puls_integration\(\).*\.(insert|update|upsert|delete)\(' 'resolver-decide-import-runtime'
  scan_forbidden_in_data 'supabase\.functions\.invoke' 'supabase-functions-invoke'
  scan_forbidden_in_data '\.from\('"'"'employees'"'"'\).*\.(insert|update|upsert|delete)\(' 'employee-mutations'
  scan_forbidden_in_data '\.from\('"'"'employee_cost_center_assignments'"'"'\).*\.(insert|update|upsert|delete)\(' 'cc-assignment-mutations'
  scan_forbidden_in_data '\.from\('"'"'employee_reporting_lines'"'"'\).*\.(insert|update|upsert|delete)\(' 'reporting-line-mutations'
fi

echo "OK: PR10.15 employee assignment readiness checks passed for ${REF}"
