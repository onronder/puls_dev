#!/usr/bin/env bash
# Verifies 10 PR10.16 request creation hardening (POSIX grep/awk).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
SMOKE="docs/data/10_request_creation_hardening_smoke.sql"
READINESS="src/lib/data/setup/request-creation-readiness.ts"
READINESS_TEST="src/lib/data/setup/request-creation-readiness.test.ts"
ASSIGN_READINESS="src/lib/data/setup/employee-assignment-readiness.ts"
EXPENSE_OVERVIEW="src/lib/data/expense/overview.ts"
LEAVE_OVERVIEW="src/lib/data/leave/overview.ts"
EXPENSE_ROUTE="src/routes/_app/masraf.tsx"
LEAVE_ROUTE="src/routes/_app/izin.tsx"
DATA_INDEX="src/lib/data/index.ts"
ERRORS="src/lib/data/errors.ts"
I18N_TR="src/i18n/locales/tr-TR.json"
I18N_EN="src/i18n/locales/en-US.json"

file_at_ref() {
  local path="$1"
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

SMOKE_CONTENT="$(file_at_ref "$SMOKE")"
READINESS_CONTENT="$(file_at_ref "$READINESS")"
READINESS_TEST_CONTENT="$(file_at_ref "$READINESS_TEST")"
ASSIGN_READINESS_CONTENT="$(file_at_ref "$ASSIGN_READINESS")"
EXPENSE_OVERVIEW_CONTENT="$(file_at_ref "$EXPENSE_OVERVIEW")"
LEAVE_OVERVIEW_CONTENT="$(file_at_ref "$LEAVE_OVERVIEW")"
EXPENSE_ROUTE_CONTENT="$(file_at_ref "$EXPENSE_ROUTE")"
LEAVE_ROUTE_CONTENT="$(file_at_ref "$LEAVE_ROUTE")"
DATA_INDEX_CONTENT="$(file_at_ref "$DATA_INDEX")"
ERRORS_CONTENT="$(file_at_ref "$ERRORS")"

echo "Checking ${REF}: PR10.16 request creation hardening ..."

for file in "$SMOKE" "$READINESS" "$READINESS_TEST" "$ASSIGN_READINESS" "$EXPENSE_OVERVIEW" "$LEAVE_OVERVIEW" "$EXPENSE_ROUTE" "$LEAVE_ROUTE" "$DATA_INDEX" "$ERRORS"; do
  if [[ ! -f "$file" ]]; then
    echo "FAIL: missing required file: $file"
    exit 1
  fi
done

MIGRATION_CHANGES="$(git diff --name-only --diff-filter=A origin/main...HEAD -- supabase/migrations/ 2>/dev/null || true)"
if [[ -n "$(echo "$MIGRATION_CHANGES" | sed '/^$/d')" ]]; then
  echo "FAIL: PR10.16 must not add migrations:"
  echo "$MIGRATION_CHANGES" | sed '/^$/d'
  exit 1
fi

smoke_needles=(
  "BEGIN;"
  "ROLLBACK;"
  "demo_request_creation_hardening"
  "PULS_INVALID_EXPENSE_CATEGORY"
  "PULS_INVALID_LEAVE_TYPE"
  "historical inactive readability"
  "employee_cost_center_assignments"
  "employee_reporting_lines"
)

for needle in "${smoke_needles[@]}"; do
  if ! grep -Fiq "$needle" <<< "$SMOKE_CONTENT"; then
    echo "FAIL: smoke missing required fragment: $needle"
    exit 1
  fi
done

adapter_needles=(
  "RequestCreationBlocker"
  "buildExpenseCreationReadiness"
  "buildLeaveCreationReadiness"
  "fetchRequestCreationReadiness"
  "getPrimaryRequestCreationBlocker"
)

for needle in "${adapter_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$READINESS_CONTENT"; then
    echo "FAIL: adapter missing required fragment: $needle"
    exit 1
  fi
done

if ! grep -Fq "fetchCurrentEmployeeAssignmentReadiness" <<< "$ASSIGN_READINESS_CONTENT"; then
  echo "FAIL: employee-assignment-readiness must export fetchCurrentEmployeeAssignmentReadiness"
  exit 1
fi

BLOCKER_UNION="$(awk '/export type RequestCreationBlocker =/,/^$/' "$READINESS" | head -n 10)"
if grep -Eq "'missing_manager'|'policy_not_ready'" <<< "$BLOCKER_UNION"; then
  echo "FAIL: RequestCreationBlocker must not include missing_manager or policy_not_ready"
  exit 1
fi

if ! grep -Fq ".eq('is_active', true)" <<< "$EXPENSE_OVERVIEW_CONTENT"; then
  echo "FAIL: expense overview must keep active-only category picker query"
  exit 1
fi

if ! grep -Fq ".eq('is_active', true)" <<< "$LEAVE_OVERVIEW_CONTENT"; then
  echo "FAIL: leave overview must keep active-only leave type picker query"
  exit 1
fi

route_needles=(
  "fetchRequestCreationReadiness"
  "RequestCreationReadinessBanners"
  "requestCreationReadiness"
)

for needle in "${route_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$EXPENSE_ROUTE_CONTENT"; then
    echo "FAIL: masraf route missing required fragment: $needle"
    exit 1
  fi
  if ! grep -Fq "$needle" <<< "$LEAVE_ROUTE_CONTENT"; then
    echo "FAIL: izin route missing required fragment: $needle"
    exit 1
  fi
done

if ! grep -Fq "requestCreationReadiness.expense.noActiveCategories" <<< "$EXPENSE_ROUTE_CONTENT"; then
  echo "FAIL: masraf must use requestCreationReadiness expense empty copy"
  exit 1
fi

if ! grep -Fq "requestCreationReadiness.leave.noActiveLeaveTypes" <<< "$LEAVE_ROUTE_CONTENT"; then
  echo "FAIL: izin must use requestCreationReadiness leave empty copy"
  exit 1
fi

if ! grep -Fq "requestCreationReadiness.expense.invalidCategory" <<< "$ERRORS_CONTENT"; then
  echo "FAIL: errors.ts must map create expense category RPC to requestCreationReadiness key"
  exit 1
fi

if ! grep -Fq "requestCreationReadiness.leave.invalidLeaveType" <<< "$ERRORS_CONTENT"; then
  echo "FAIL: errors.ts must map create leave type RPC to requestCreationReadiness key"
  exit 1
fi

if ! grep -Fq "request-creation-readiness" <<< "$DATA_INDEX_CONTENT"; then
  echo "FAIL: data index must export request-creation-readiness helpers"
  exit 1
fi

for key in assignmentPartial blockingTitle warningTitle noActiveCategories noActiveLeaveTypes invalidCategory invalidLeaveType; do
  if ! grep -Fq "\"$key\"" "$I18N_TR" || ! grep -Fq "\"$key\"" "$I18N_EN"; then
    echo "FAIL: missing i18n key requestCreationReadiness fragment: $key"
    exit 1
  fi
done

for needle in buildExpenseCreationReadiness buildLeaveCreationReadiness assertNoForbiddenBlockers; do
  if ! grep -Fq "$needle" <<< "$READINESS_TEST_CONTENT"; then
    echo "FAIL: tests must cover $needle"
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

  for file in "${CHANGED_DATA_FILES[@]}"; do
    if [[ -f "$file" ]] && grep -Eiq '\.from\('"'"'[^'"'"']+'"'"'\).*\.(insert|update|upsert|delete)\(' "$file"; then
      if grep -Eiq '\.rpc\('"'"'create_expense_claim'"'"'|\.rpc\('"'"'create_leave_request'"'"'' "$file"; then
        continue
      fi
      if grep -Eiq '\.from\('"'"'employees'"'"'\).*\.(insert|update|upsert|delete)\(' "$file"; then
        echo "FAIL: forbidden employee mutations in $file"
        exit 1
      fi
      if grep -Eiq '\.from\('"'"'expense_categories'"'"'\).*\.(insert|update|upsert|delete)\(' "$file"; then
        echo "FAIL: forbidden setup mutations in $file"
        exit 1
      fi
      if grep -Eiq '\.from\('"'"'leave_types'"'"'\).*\.(insert|update|upsert|delete)\(' "$file"; then
        echo "FAIL: forbidden setup mutations in $file"
        exit 1
      fi
    fi
  done
fi

echo "OK: PR10.16 request creation hardening checks passed for ${REF}"
