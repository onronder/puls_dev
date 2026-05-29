#!/usr/bin/env bash
# Verifies 11 PR11.9 demo fallback guard (POSIX grep/awk).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
MATRIX="docs/data/11_demo_fallback_guard_matrix.md"
DEMO_MODE="src/lib/data/demo-mode.ts"
DEMO_MODE_TEST="src/lib/data/demo-mode.test.ts"
RESULT="src/lib/data/result.ts"
RESULT_TEST="src/lib/data/result.test.ts"
PILL="src/components/puls/DemoSourcePill.tsx"
DATA_INDEX="src/lib/data/index.ts"
EXPENSE_OVERVIEW="src/lib/data/expense/overview.ts"
EXPENSE_OVERVIEW_TEST="src/lib/data/expense/overview.test.ts"

ROUTES=(
  "src/routes/_app/masraf.tsx"
  "src/routes/_app/masraf-kategorileri.tsx"
  "src/routes/_app/departmanlar.tsx"
  "src/routes/_app/pozisyonlar.tsx"
  "src/routes/_app/erp.tsx"
  "src/routes/_app/ayarlar.tsx"
  "src/routes/_app/ai-koc.tsx"
  "src/routes/_app/performans-parametreleri.tsx"
  "src/routes/_app/sirket-kurulum.tsx"
)

file_at_ref() {
  local path="$1"
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

echo "Checking ${REF}: PR11.9 demo fallback guard ..."

REQUIRED_FILES=(
  "$MATRIX"
  "$DEMO_MODE"
  "$DEMO_MODE_TEST"
  "$RESULT"
  "$RESULT_TEST"
  "$PILL"
  "$DATA_INDEX"
  "$EXPENSE_OVERVIEW"
  "$EXPENSE_OVERVIEW_TEST"
  "${ROUTES[@]}"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "FAIL: missing required file: $file"
    exit 1
  fi
done

MIGRATION_CHANGES="$(git diff --name-only --diff-filter=A origin/main...HEAD -- supabase/migrations/ 2>/dev/null || true)"
if [[ -n "$(echo "$MIGRATION_CHANGES" | sed '/^$/d')" ]]; then
  echo "FAIL: PR11.9 must not add migrations:"
  echo "$MIGRATION_CHANGES" | sed '/^$/d'
  exit 1
fi

MATRIX_CONTENT="$(file_at_ref "$MATRIX")"
DEMO_MODE_CONTENT="$(file_at_ref "$DEMO_MODE")"
DEMO_MODE_TEST_CONTENT="$(file_at_ref "$DEMO_MODE_TEST")"
RESULT_CONTENT="$(file_at_ref "$RESULT")"
RESULT_TEST_CONTENT="$(file_at_ref "$RESULT_TEST")"
PILL_CONTENT="$(file_at_ref "$PILL")"
DATA_INDEX_CONTENT="$(file_at_ref "$DATA_INDEX")"
EXPENSE_OVERVIEW_CONTENT="$(file_at_ref "$EXPENSE_OVERVIEW")"
EXPENSE_OVERVIEW_TEST_CONTENT="$(file_at_ref "$EXPENSE_OVERVIEW_TEST")"

matrix_needles=(
  "PR11.9"
  "PROD === true"
  "fallbackReason"
  "/menu"
  "No migration"
  "tenant_without_employee"
)

for needle in "${matrix_needles[@]}"; do
  if ! grep -Fiq "$needle" <<< "$MATRIX_CONTENT"; then
    echo "FAIL: matrix missing topic: $needle"
    exit 1
  fi
done

core_needles=(
  "readPulsDemoModeConfig"
  "VITE_PULS_ALLOW_DEMO_FALLBACK_IN_PROD"
  "production_build"
  "fallbackReason"
  "resolveAdapterDataWithMeta"
)

for needle in readPulsDemoModeConfig VITE_PULS_ALLOW_DEMO_FALLBACK_IN_PROD production_build; do
  if ! grep -Fq "$needle" <<< "$DEMO_MODE_CONTENT"; then
    echo "FAIL: demo-mode.ts missing fragment: $needle"
    exit 1
  fi
done

for needle in fallbackReason resolveAdapterDataWithMeta; do
  if ! grep -Fq "$needle" <<< "$RESULT_CONTENT"; then
    echo "FAIL: result.ts missing fragment: $needle"
    exit 1
  fi
done

pill_needles=(
  "useTranslation"
  "StatusPill"
  "orgSetupReadiness.source.demo"
)

for needle in "${pill_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$PILL_CONTENT"; then
    echo "FAIL: DemoSourcePill missing fragment: $needle"
    exit 1
  fi
done

adapter_exports=(
  "fetchExpenseOverviewWithMeta"
  "fetchExpenseCategoriesOverviewWithMeta"
  "fetchErpOverviewWithMeta"
  "fetchSettingsOverviewWithMeta"
  "fetchAiCoachOverviewWithMeta"
  "fetchPerformanceParametersOverviewWithMeta"
  "fetchCompanySetupOverviewWithMeta"
  "readPulsDemoModeConfig"
)

for needle in "${adapter_exports[@]}"; do
  if ! grep -Fq "$needle" <<< "$DATA_INDEX_CONTENT"; then
    echo "FAIL: data index must export $needle"
    exit 1
  fi
done

if ! grep -Fq "fetchExpenseOverviewWithMeta" <<< "$EXPENSE_OVERVIEW_CONTENT"; then
  echo "FAIL: expense overview adapter must export fetchExpenseOverviewWithMeta"
  exit 1
fi

for needle in readPulsDemoModeConfig production_build; do
  if ! grep -Fq "$needle" <<< "$DEMO_MODE_TEST_CONTENT"; then
    echo "FAIL: demo-mode tests must cover $needle"
    exit 1
  fi
done

for needle in fallbackReason empty error; do
  if ! grep -Fq "$needle" <<< "$RESULT_TEST_CONTENT"; then
    echo "FAIL: result tests must cover fallbackReason ($needle)"
    exit 1
  fi
done

if ! grep -Fq "fetchExpenseOverviewWithMeta" <<< "$EXPENSE_OVERVIEW_TEST_CONTENT"; then
  echo "FAIL: expense overview tests must cover fetchExpenseOverviewWithMeta"
  exit 1
fi

route_with_meta() {
  case "$1" in
    src/routes/_app/masraf.tsx) printf '%s' 'fetchExpenseOverviewWithMeta' ;;
    src/routes/_app/masraf-kategorileri.tsx) printf '%s' 'fetchExpenseCategoriesOverviewWithMeta' ;;
    src/routes/_app/departmanlar.tsx) printf '%s' 'fetchDepartmentsOverviewWithMeta' ;;
    src/routes/_app/pozisyonlar.tsx) printf '%s' 'fetchPositionsOverviewWithMeta' ;;
    src/routes/_app/erp.tsx) printf '%s' 'fetchErpOverviewWithMeta' ;;
    src/routes/_app/ayarlar.tsx) printf '%s' 'fetchSettingsOverviewWithMeta' ;;
    src/routes/_app/ai-koc.tsx) printf '%s' 'fetchAiCoachOverviewWithMeta' ;;
    src/routes/_app/performans-parametreleri.tsx) printf '%s' 'fetchPerformanceParametersOverviewWithMeta' ;;
    src/routes/_app/sirket-kurulum.tsx) printf '%s' 'fetchCompanySetupOverviewWithMeta' ;;
    *)
      echo "FAIL: unknown route in ROUTES: $1" >&2
      return 1
      ;;
  esac
}

for route in "${ROUTES[@]}"; do
  ROUTE_CONTENT="$(file_at_ref "$route")"
  with_meta="$(route_with_meta "$route")"

  if ! grep -Fq "$with_meta" <<< "$ROUTE_CONTENT"; then
    echo "FAIL: route $route must use $with_meta"
    exit 1
  fi

  if ! grep -Fq "DemoSourcePill" <<< "$ROUTE_CONTENT"; then
    echo "FAIL: route $route must render DemoSourcePill"
    exit 1
  fi
done

MASRAF_KAT_CONTENT="$(file_at_ref "src/routes/_app/masraf-kategorileri.tsx")"
if ! grep -Fq "fetchCostCenterReadinessOverviewWithMeta" <<< "$MASRAF_KAT_CONTENT"; then
  echo "FAIL: masraf-kategorileri must use fetchCostCenterReadinessOverviewWithMeta"
  exit 1
fi

POZ_CONTENT="$(file_at_ref "src/routes/_app/pozisyonlar.tsx")"
if ! grep -Fq "fetchDepartmentsOverviewWithMeta" <<< "$POZ_CONTENT"; then
  echo "FAIL: pozisyonlar must use fetchDepartmentsOverviewWithMeta"
  exit 1
fi

SIRKET_CONTENT="$(file_at_ref "src/routes/_app/sirket-kurulum.tsx")"
if ! grep -Fq "companySetupResult" <<< "$SIRKET_CONTENT"; then
  echo "FAIL: sirket-kurulum pill must bind companySetupResult source"
  exit 1
fi

MENU_CONTENT="$(file_at_ref "src/routes/_app/menu.tsx")"
if grep -Fq "fetchMenuOverviewWithMeta" <<< "$MENU_CONTENT"; then
  echo "FAIL: /menu must remain exception (no fetchMenuOverviewWithMeta)"
  exit 1
fi

CHANGED_FILES=()
while IFS= read -r file; do
  [[ -n "$file" ]] && CHANGED_FILES+=("$file")
done < <(git diff --name-only origin/main...HEAD -- 'src/**' 2>/dev/null || true)

scan_forbidden_in_diff() {
  local pattern="$1"
  local label="$2"
  for file in "${CHANGED_FILES[@]}"; do
    if git diff origin/main...HEAD -- "$file" 2>/dev/null | grep -Eiq "^\+[^+].*${pattern}"; then
      echo "FAIL: forbidden pattern ($label) introduced in $file"
      git diff origin/main...HEAD -- "$file" | grep -Ein "^\+[^+].*${pattern}" || true
      exit 1
    fi
  done
}

if ((${#CHANGED_FILES[@]} > 0)); then
  scan_forbidden_in_diff '\.(insert|update|delete|upsert)\(' 'supabase-mutation'
  scan_forbidden_in_diff 'supabase\.functions\.invoke' 'supabase-functions-invoke'
  scan_forbidden_in_diff 'resolveApprover\(|decideApproval\(|importApply\(' 'resolver-decide-import-runtime'
  scan_forbidden_in_diff 'write.*erp' 'write-erp-en'
  scan_forbidden_in_diff '\bsync\b.*erp' 'sync-erp-en'
  scan_forbidden_in_diff 'push.*erp' 'push-erp-en'
fi

if [[ -f ".env.example" ]] && ! grep -Fq "VITE_PULS_ALLOW_DEMO_FALLBACK_IN_PROD" .env.example; then
  echo "FAIL: .env.example must document VITE_PULS_ALLOW_DEMO_FALLBACK_IN_PROD"
  exit 1
fi

chmod +x "$0" 2>/dev/null || true

echo "OK: PR11.9 demo fallback guard checks passed for ${REF}"
