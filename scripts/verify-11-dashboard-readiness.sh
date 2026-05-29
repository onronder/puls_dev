#!/usr/bin/env bash
# Verifies 11 PR11.7 dashboard readiness (POSIX grep/awk).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
MATRIX="docs/data/11_dashboard_readiness_matrix.md"
SMOKE="docs/data/11_dashboard_readiness_smoke.sql"
OVERVIEW="src/lib/data/dashboard/overview.ts"
OVERVIEW_TEST="src/lib/data/dashboard/overview.test.ts"
ROUTE="src/routes/_app/dashboard.tsx"
DATA_INDEX="src/lib/data/index.ts"
SETUP_ROUTE="src/routes/_app/sirket-kurulum.tsx"
SETUP_ADAPTER="src/lib/data/setup/setup-readiness-dashboard.ts"

smoke() {
  git show "${REF}:${SMOKE}" 2>/dev/null || cat "${SMOKE}"
}

file_at_ref() {
  local path="$1"
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

MATRIX_CONTENT="$(file_at_ref "$MATRIX")"
SMOKE_CONTENT="$(smoke)"
OVERVIEW_CONTENT="$(file_at_ref "$OVERVIEW")"
OVERVIEW_TEST_CONTENT="$(file_at_ref "$OVERVIEW_TEST")"
ROUTE_CONTENT="$(file_at_ref "$ROUTE")"
DATA_INDEX_CONTENT="$(file_at_ref "$DATA_INDEX")"

echo "Checking ${REF}: PR11.7 dashboard readiness ..."

for file in "$MATRIX" "$SMOKE" "$OVERVIEW" "$OVERVIEW_TEST" "$ROUTE" "$DATA_INDEX"; do
  if [[ ! -f "$file" ]]; then
    echo "FAIL: missing required file: $file"
    exit 1
  fi
done

MIGRATION_CHANGES="$(git diff --name-only --diff-filter=A origin/main...HEAD -- supabase/migrations/ 2>/dev/null || true)"
if [[ -n "$(echo "$MIGRATION_CHANGES" | sed '/^$/d')" ]]; then
  echo "FAIL: PR11.7 must not add migrations:"
  echo "$MIGRATION_CHANGES" | sed '/^$/d'
  exit 1
fi

matrix_needles=(
  "production-partial"
  "recent activity"
  "dashboard_overview"
  "leave_overview"
  "expense_overview"
  "No migration"
)

for needle in "${matrix_needles[@]}"; do
  if ! grep -Fiq "$needle" <<< "$MATRIX_CONTENT"; then
    echo "FAIL: matrix missing topic: $needle"
    exit 1
  fi
done

smoke_needles=(
  "BEGIN;"
  "ROLLBACK;"
  "demo_dashboard_readiness_"
  "puls_calc.dashboard_overview"
  "puls_calc.leave_overview"
  "puls_calc.expense_overview"
  "puls_integration.erp_connections"
  "puls_integration.erp_field_mappings"
  "request.jwt.claim.sub"
  "puls_core.current_employee_id()"
)

for needle in "${smoke_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$SMOKE_CONTENT"; then
    echo "FAIL: smoke missing fragment: $needle"
    exit 1
  fi
done

adapter_needles=(
  "fetchDashboardOverviewWithMeta"
  "resolveAdapterDataWithMeta"
  "buildDashboardQueue"
  "buildDashboardErpStatus"
  "buildDashboardPageDataFromDemo"
  "isDashboardEmpty"
)

for needle in "${adapter_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$OVERVIEW_CONTENT"; then
    echo "FAIL: dashboard overview adapter missing fragment: $needle"
    exit 1
  fi
done

if ! grep -Fq "fetchDashboardOverviewWithMeta" <<< "$DATA_INDEX_CONTENT"; then
  echo "FAIL: data index must export fetchDashboardOverviewWithMeta"
  exit 1
fi

for needle in isDashboardEmpty buildDashboardQueue buildDashboardErpStatus buildDashboardPageDataFromDemo fetchDashboardOverviewWithMeta; do
  if ! grep -Fq "$needle" <<< "$OVERVIEW_TEST_CONTENT"; then
    echo "FAIL: dashboard overview tests must cover $needle"
    exit 1
  fi
done

for needle in fetchDashboardOverviewWithMeta dashboardResult orgSetupReadiness.source.demo; do
  if ! grep -Fq "$needle" <<< "$ROUTE_CONTENT"; then
    echo "FAIL: dashboard route missing fragment: $needle"
    exit 1
  fi
done

route_forbidden_needles=(
  "demoOverview"
  "leaveDemo"
  "expenseDemo"
)

for needle in "${route_forbidden_needles[@]}"; do
  if grep -Fq "$needle" <<< "$ROUTE_CONTENT"; then
    echo "FAIL: dashboard route must not use misleading local name: $needle"
    exit 1
  fi
done

CHANGED_FILES=()
while IFS= read -r file; do
  [[ -n "$file" ]] && CHANGED_FILES+=("$file")
done < <(git diff --name-only origin/main...HEAD -- 'src/**' 2>/dev/null || true)

scan_forbidden() {
  local pattern="$1"
  local label="$2"
  for file in "${CHANGED_FILES[@]}"; do
    if [[ -f "$file" ]] && grep -Eiq "$pattern" "$file"; then
      echo "FAIL: forbidden pattern ($label) in $file"
      grep -Ein "$pattern" "$file" || true
      exit 1
    fi
  done
}

if ((${#CHANGED_FILES[@]} > 0)); then
  if ! printf '%s\n' "${CHANGED_FILES[@]}" | grep -Fxq "$ROUTE"; then
    echo "FAIL: PR11.7 must change route $ROUTE"
    exit 1
  fi

  if printf '%s\n' "${CHANGED_FILES[@]}" | grep -Fxq "$SETUP_ROUTE"; then
    echo "FAIL: PR11.7 must not change setup route $SETUP_ROUTE"
    exit 1
  fi

  if printf '%s\n' "${CHANGED_FILES[@]}" | grep -Fxq "$SETUP_ADAPTER"; then
    echo "FAIL: PR11.7 must not change setup dashboard adapter $SETUP_ADAPTER"
    exit 1
  fi

  scan_forbidden '\.(insert|update|delete|upsert)\(' 'supabase-mutation'
  scan_forbidden 'supabase\.functions\.invoke' 'supabase-functions-invoke'
  scan_forbidden 'write.*erp' 'write-erp-en'
  scan_forbidden '\bsync\b.*erp' 'sync-erp-en'
  scan_forbidden 'push.*erp' 'push-erp-en'
  scan_forbidden 'resolveApprover\(|decideApproval\(|importApply\(' 'resolver-decide-import-runtime'
fi

chmod +x "$0" 2>/dev/null || true

echo "OK: PR11.7 dashboard readiness checks passed for ${REF}"
