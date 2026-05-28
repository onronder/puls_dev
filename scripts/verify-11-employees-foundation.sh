#!/usr/bin/env bash
# Verifies 11 PR11.1 employees foundation (POSIX grep/awk).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
MATRIX="docs/data/11_employees_foundation_matrix.md"
SMOKE="docs/data/11_employees_foundation_smoke.sql"
EMPLOYEES="src/lib/data/core/employees.ts"
EMPLOYEES_TEST="src/lib/data/core/employees.test.ts"
PROFILE_MAPPING="src/lib/data/profile/mapping.ts"
PROFILE_MAPPING_TEST="src/lib/data/profile/mapping.test.ts"
EMPLOYEES_ROUTE="src/routes/_app/calisanlar.tsx"
DATA_INDEX="src/lib/data/index.ts"

smoke() {
  git show "${REF}:${SMOKE}" 2>/dev/null || cat "${SMOKE}"
}

file_at_ref() {
  local path="$1"
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

MATRIX_CONTENT="$(file_at_ref "$MATRIX")"
SMOKE_CONTENT="$(smoke)"
EMPLOYEES_CONTENT="$(file_at_ref "$EMPLOYEES")"
EMPLOYEES_TEST_CONTENT="$(file_at_ref "$EMPLOYEES_TEST")"
EMPLOYEES_ROUTE_CONTENT="$(file_at_ref "$EMPLOYEES_ROUTE")"
DATA_INDEX_CONTENT="$(file_at_ref "$DATA_INDEX")"

echo "Checking ${REF}: PR11.1 employees foundation ..."

for file in "$MATRIX" "$SMOKE" "$EMPLOYEES" "$EMPLOYEES_TEST" "$PROFILE_MAPPING" "$PROFILE_MAPPING_TEST" "$EMPLOYEES_ROUTE" "$DATA_INDEX"; do
  if [[ ! -f "$file" ]]; then
    echo "FAIL: missing required file: $file"
    exit 1
  fi
done

MIGRATION_CHANGES="$(git diff --name-only --diff-filter=A origin/main...HEAD -- supabase/migrations/ 2>/dev/null || true)"
if [[ -n "$(echo "$MIGRATION_CHANGES" | sed '/^$/d')" ]]; then
  echo "FAIL: PR11.1 must not add migrations:"
  echo "$MIGRATION_CHANGES" | sed '/^$/d'
  exit 1
fi

matrix_needles=(
  "Canonical sources"
  "Route usage"
  "Adapter inventory"
  "Demo fallback behavior"
  "Auth/profile mapping"
  "RLS/tenant assumptions"
  "Remaining gaps"
  "Empty real"
  "employee_reporting_lines"
  "No migrations"
  "PR11.8"
  "read_only"
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
  "current_employee_id"
  "request.jwt.claim.sub"
  "department_id"
  "position_id"
  "manager_employee_id"
  "employment_status"
  "cross-tenant"
)

for needle in "${smoke_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$SMOKE_CONTENT"; then
    echo "FAIL: smoke missing required fragment: $needle"
    exit 1
  fi
done

adapter_needles=(
  "mapEmployeeRow"
  "buildEmployeeListStats"
  "isActiveEmployeeStatus"
  "fetchEmployeeList"
  "fetchEmployeeListStats"
  "fetchEmployeeListWithMeta"
  "fetchEmployeeListStatsWithMeta"
  "fetchDemoEmployeeAssignmentReadiness"
)

for needle in "${adapter_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$EMPLOYEES_CONTENT"; then
    echo "FAIL: employees adapter missing required fragment: $needle"
    exit 1
  fi
done

if grep -Fq "employee_reporting_lines" <<< "$EMPLOYEES_CONTENT"; then
  echo "FAIL: core/employees.ts must not duplicate PR10.15 reporting-line logic"
  exit 1
fi

if ! grep -Fq "resolveTenantContext" <<< "$EMPLOYEES_CONTENT"; then
  echo "FAIL: employees adapter must use resolveTenantContext"
  exit 1
fi

if ! grep -Fq ".eq('tenant_id'" <<< "$EMPLOYEES_CONTENT"; then
  echo "FAIL: employees adapter must tenant-scope queries with .eq('tenant_id'"
  exit 1
fi

if grep -E 'fetchDemo:\s*async\s*\(\)\s*=>\s*\(\{\s*employeeCount:\s*4' <<< "$EMPLOYEES_CONTENT"; then
  echo "FAIL: fetchEmployeeListStats must not use inline hardcoded demo stats"
  exit 1
fi

if grep -E 'employeeCount:\s*4,\s*departmentCount:\s*3' <<< "$EMPLOYEES_CONTENT"; then
  echo "FAIL: employees adapter contains inline hardcoded fake stats"
  exit 1
fi

for needle in isActiveEmployeeStatus mapEmployeeRow buildEmployeeListStats; do
  if ! grep -Fq "$needle" <<< "$EMPLOYEES_TEST_CONTENT"; then
    echo "FAIL: employees tests must cover $needle"
    exit 1
  fi
done

if ! grep -Fiq "zero stats" <<< "$EMPLOYEES_TEST_CONTENT"; then
  echo "FAIL: employees tests must cover real empty tenant zero stats case"
  exit 1
fi

if ! grep -Fq "fetchEmployeeAssignmentReadiness" <<< "$EMPLOYEES_ROUTE_CONTENT"; then
  echo "FAIL: calisanlar must use fetchEmployeeAssignmentReadiness"
  exit 1
fi

if ! grep -Fq "fetchEmployeesOverview" <<< "$EMPLOYEES_ROUTE_CONTENT"; then
  echo "FAIL: calisanlar must use fetchEmployeesOverview for detail leave"
  exit 1
fi

if ! grep -Fq "orgSetupReadiness.source.demo" <<< "$EMPLOYEES_ROUTE_CONTENT"; then
  echo "FAIL: calisanlar must show demo source indicator"
  exit 1
fi

if grep -Fq "common.soon" <<< "$EMPLOYEES_ROUTE_CONTENT"; then
  echo "FAIL: calisanlar must not use common.soon"
  exit 1
fi

for needle in fetchEmployeeListWithMeta fetchEmployeeListStatsWithMeta mapEmployeeRow buildEmployeeListStats; do
  if ! grep -Fq "$needle" <<< "$DATA_INDEX_CONTENT"; then
    echo "FAIL: data index must export $needle"
    exit 1
  fi
done

CHANGED_FILES=()
while IFS= read -r file; do
  [[ -n "$file" ]] && CHANGED_FILES+=("$file")
done < <(git diff --name-only origin/main...HEAD -- 'src/**' 'scripts/**' 2>/dev/null || true)

scan_forbidden() {
  local pattern="$1"
  local label="$2"
  for file in "${CHANGED_FILES[@]}"; do
    if [[ -f "$file" ]] && grep -Eiq "$pattern" "$file"; then
      echo "FAIL: forbidden pattern ($label) in $file: $pattern"
      grep -Ein "$pattern" "$file" || true
      exit 1
    fi
  done
}

if ((${#CHANGED_FILES[@]} > 0)); then
  scan_forbidden 'resolveApprover\(|decideApproval\(|importApply\(' 'resolver-decide-import-runtime'
  scan_forbidden 'supabase\.functions\.invoke' 'supabase-functions-invoke'
  scan_forbidden '\.from\('"'"'employees'"'"'\).*\.(insert|update|upsert|delete)\(' 'employee-mutations'
  scan_forbidden '\.from\('"'"'departments'"'"'\).*\.(insert|update|upsert|delete)\(' 'department-mutations'
  scan_forbidden '\.from\('"'"'positions'"'"'\).*\.(insert|update|upsert|delete)\(' 'position-mutations'
  scan_forbidden '\.from\('"'"'employee_cost_center_assignments'"'"'\).*\.(insert|update|upsert|delete)\(' 'cc-assignment-mutations'
  scan_forbidden '\.from\('"'"'employee_reporting_lines'"'"'\).*\.(insert|update|upsert|delete)\(' 'reporting-line-mutations'
fi

chmod +x "$0" 2>/dev/null || true

echo "OK: PR11.1 employees foundation checks passed for ${REF}"
