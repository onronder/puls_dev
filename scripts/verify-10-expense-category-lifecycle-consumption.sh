#!/usr/bin/env bash
# Verifies 10 PR10.8 expense category lifecycle consumption (POSIX grep/awk).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
SMOKE="docs/data/10_expense_category_lifecycle_consumption_smoke.sql"
OVERVIEW="src/lib/data/expense/overview.ts"
ROUTE="src/routes/_app/masraf.tsx"
I18N_TR="src/i18n/locales/tr-TR.json"
I18N_EN="src/i18n/locales/en-US.json"

smoke() {
  git show "${REF}:${SMOKE}" 2>/dev/null || cat "${SMOKE}"
}

overview() {
  cat "${OVERVIEW}"
}

route() {
  cat "${ROUTE}"
}

SMOKE_CONTENT="$(smoke)"
OVERVIEW_CONTENT="$(overview)"
ROUTE_CONTENT="$(route)"

echo "Checking ${REF}: PR10.8 expense category lifecycle consumption ..."

for file in "$SMOKE" "$OVERVIEW" "$ROUTE"; do
  if [[ ! -f "$file" ]]; then
    echo "FAIL: missing required file: $file"
    exit 1
  fi
done

MIGRATION_CHANGES="$(git diff --name-only --diff-filter=A origin/main...HEAD -- supabase/migrations/ 2>/dev/null || true)"
if [[ -n "$(echo "$MIGRATION_CHANGES" | sed '/^$/d')" ]]; then
  echo "FAIL: PR10.8 must not add migrations:"
  echo "$MIGRATION_CHANGES" | sed '/^$/d'
  exit 1
fi

if git diff --name-only origin/main...HEAD -- 'src/**' 2>/dev/null | grep -Fq . && \
   git diff origin/main...HEAD -- 'src/**' 2>/dev/null | grep -Fq 'DELETE FROM puls_workflow.expense_categories'; then
  echo "FAIL: src changes must not hard-delete expense categories"
  exit 1
fi

smoke_needles=(
  "BEGIN;"
  "ROLLBACK;"
  "create_expense_claim"
  "deactivate_expense_category"
  "restore_expense_category"
  "PULS_INVALID_EXPENSE_CATEGORY"
  "demo_lifecycle_consumption_active"
  "demo_lifecycle_consumption_history"
  "status = 'exported'"
  "historical claim should reference inactive category row"
  "Fixture B:"
  "Fixture C:"
)

for needle in "${smoke_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$SMOKE_CONTENT"; then
    echo "FAIL: smoke missing required fragment: $needle"
    exit 1
  fi
done

if ! grep -Fq ".eq('is_active', true)" <<< "$OVERVIEW_CONTENT"; then
  echo "FAIL: overview must keep active-only category options filter"
  exit 1
fi

if ! grep -Fq 'expense_categories ( name, is_active )' <<< "$OVERVIEW_CONTENT"; then
  echo "FAIL: historical claims join must include is_active"
  exit 1
fi

if ! grep -Fq "mapClaimCategoryFromJoin" <<< "$OVERVIEW_CONTENT"; then
  echo "FAIL: overview must export mapClaimCategoryFromJoin helper"
  exit 1
fi

if grep -Fq "expense_categories ( name, is_active )" <<< "$OVERVIEW_CONTENT" && \
   grep -A6 "expense_categories ( name, is_active )" <<< "$OVERVIEW_CONTENT" | grep -Fq ".eq('is_active', true)"; then
  echo "FAIL: historical claims join must not filter joined categories to active-only"
  exit 1
fi

for needle in categoryIsActive inactiveCategoryBadge noActiveCategories; do
  if ! grep -Fq "$needle" <<< "$ROUTE_CONTENT"; then
    echo "FAIL: masraf route missing UI needle: $needle"
    exit 1
  fi
done

for key in inactiveCategoryBadge inactiveCategoryHint noActiveCategories; do
  if ! grep -Fq "\"$key\"" "$I18N_TR" || ! grep -Fq "\"$key\"" "$I18N_EN"; then
    echo "FAIL: missing i18n key expenseSetup.categoryLifecycle.$key"
    exit 1
  fi
done

CHANGED_SRC_FILES=()
while IFS= read -r file; do
  [[ -n "$file" ]] && CHANGED_SRC_FILES+=("$file")
done < <(git diff --name-only origin/main...HEAD -- 'src/**' 2>/dev/null || true)

scan_forbidden_in_src() {
  local pattern="$1"
  local label="$2"
  for file in "${CHANGED_SRC_FILES[@]}"; do
    if [[ -f "$file" ]] && grep -Eiq "$pattern" "$file"; then
      echo "FAIL: forbidden runtime pattern ($label) in changed src file $file: $pattern"
      grep -Ein "$pattern" "$file" || true
      exit 1
    fi
  done
}

if ((${#CHANGED_SRC_FILES[@]} > 0)); then
  scan_forbidden_in_src 'resolveApprover\(|decideApproval(Request)?\(|importApply\(|puls_integration\(\).*\.(insert|update|upsert|delete)\(' 'resolver-decide-import-runtime'
  scan_forbidden_in_src 'write.*erp' 'write-erp-en'
  scan_forbidden_in_src 'sync.*erp' 'sync-erp-en'
  scan_forbidden_in_src 'push.*erp' 'push-erp-en'
  scan_forbidden_in_src 'supabase\.functions\.invoke' 'supabase-functions-invoke'
fi

echo "OK: PR10.8 expense category lifecycle consumption checks passed for ${REF}"
