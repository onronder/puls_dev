#!/usr/bin/env bash
# Verifies 10 PR10.6 expense category UX hardening (POSIX grep/awk).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VALIDATION="src/lib/data/setup/expense-category-validation.ts"
VALIDATION_TEST="src/lib/data/setup/expense-category-validation.test.ts"
ADAPTER="src/lib/data/setup/expense-categories.ts"
ADAPTER_TEST="src/lib/data/setup/expense-categories.test.ts"
ROUTE="src/routes/_app/masraf-kategorileri.tsx"
I18N_TR="src/i18n/locales/tr-TR.json"
I18N_EN="src/i18n/locales/en-US.json"

echo "Checking PR10.6 expense category UX ..."

for file in "$VALIDATION" "$VALIDATION_TEST" "$ADAPTER" "$ADAPTER_TEST" "$ROUTE"; do
  if [[ ! -f "$file" ]]; then
    echo "FAIL: missing required file: $file"
    exit 1
  fi
done

MIGRATION_CHANGES="$(git diff --name-only --diff-filter=AM origin/main...HEAD -- supabase/migrations/ 2>/dev/null || true)"
if [[ -n "$(echo "$MIGRATION_CHANGES" | sed '/^$/d')" ]]; then
  echo "FAIL: PR10.6 must not add or modify migrations:"
  echo "$MIGRATION_CHANGES" | sed '/^$/d'
  exit 1
fi

if ! grep -Fq 'validateExpenseCategoryForm' "$VALIDATION"; then
  echo "FAIL: validation module must export validateExpenseCategoryForm"
  exit 1
fi

if ! grep -Fq 'isExpenseCategoryFormDirty' "$VALIDATION"; then
  echo "FAIL: validation module must export isExpenseCategoryFormDirty"
  exit 1
fi

if ! grep -Fq 'mapExpenseCategoryMutationError' "$ADAPTER"; then
  echo "FAIL: adapter must export mapExpenseCategoryMutationError"
  exit 1
fi

for needle in \
  PULS_EXPENSE_CATEGORY_NAME_REQUIRED \
  PULS_EXPENSE_CATEGORY_CODE_INVALID \
  expenseCategorySetup.validation.duplicateCode \
  expense_categories_tenant_id_code_key \
  idx_puls_workflow_expense_categories_active_account_code_unique; do
  if ! grep -Fq "$needle" "$ADAPTER"; then
    echo "FAIL: missing adapter needle: $needle"
    exit 1
  fi
done

if ! grep -Fq 'expenseCategorySetup.validation' "$I18N_TR" || ! grep -Fq 'expenseCategorySetup.validation' "$I18N_EN"; then
  echo "FAIL: missing expenseCategorySetup.validation i18n namespace"
  exit 1
fi

if ! grep -Fq 'discardConfirm' "$I18N_TR" || ! grep -Fq 'duplicateAccountingCode' "$I18N_EN"; then
  echo "FAIL: missing validation i18n keys"
  exit 1
fi

if ! grep -Fq 'erpAccountCode' "$ROUTE"; then
  echo "FAIL: route form must use erpAccountCode field name"
  exit 1
fi

if grep -Fq 'validateExpenseCategoryForm(form, t)' "$VALIDATION"; then
  echo "FAIL: validation helper must not accept translator function"
  exit 1
fi

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
fi

echo "OK: PR10.6 expense category UX checks passed."
