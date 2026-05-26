#!/usr/bin/env bash
# Verifies 10 PR10.5 expense category guardrails migration (POSIX grep/awk).
set -euo pipefail

REF="${1:-HEAD}"
FILE="supabase/migrations/20260525172000_puls_workflow_expense_category_guardrails.sql"
SMOKE="docs/data/10_expense_category_guardrails_smoke.sql"

sql() {
  git show "${REF}:${FILE}" 2>/dev/null || cat "${FILE}"
}

smoke() {
  git show "${REF}:${SMOKE}" 2>/dev/null || cat "${SMOKE}"
}

CONTENT="$(sql)"
SMOKE_CONTENT="$(smoke)"

echo "Checking ${REF}:${FILE} ..."

needles=(
  "validate_expense_category_guardrails"
  "_normalize_expense_category_text"
  "BEFORE INSERT OR UPDATE"
  "idx_puls_workflow_expense_categories_active_account_code_unique"
  "WHERE is_active = TRUE AND erp_account_code IS NOT NULL"
  "^[a-z][a-z0-9_]{1,63}$"
  "^[0-9]{3}(\\.[0-9]{2})?$"
  "PULS_EXPENSE_CATEGORY_NAME_REQUIRED"
  "PULS_EXPENSE_CATEGORY_CODE_REQUIRED"
  "PULS_EXPENSE_CATEGORY_CODE_INVALID"
  "PULS_EXPENSE_CATEGORY_MONTHLY_LIMIT_INVALID"
  "PULS_EXPENSE_CATEGORY_RECEIPT_THRESHOLD_INVALID"
  "PULS_EXPENSE_CATEGORY_VAT_INVALID"
  "PULS_EXPENSE_CATEGORY_ACCOUNT_CODE_INVALID"
  "REVOKE ALL ON FUNCTION"
  "GRANT EXECUTE ON FUNCTION puls_workflow._normalize_expense_category_text(TEXT) TO service_role"
  "GRANT EXECUTE ON FUNCTION puls_workflow.validate_expense_category_guardrails() TO service_role"
)

for needle in "${needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$CONTENT"; then
    echo "FAIL: missing required fragment: $needle"
    exit 1
  fi
done

if grep -v '^[[:space:]]*--' <<< "$CONTENT" | grep -Fq "GRANT EXECUTE ON FUNCTION" && \
   grep -v '^[[:space:]]*--' <<< "$CONTENT" | grep -Fq "TO authenticated"; then
  echo "FAIL: validation helpers must not be granted to authenticated"
  exit 1
fi

for forbidden in \
  "CREATE OR REPLACE FUNCTION puls_workflow.resolve_policy_step_approver" \
  "CREATE OR REPLACE FUNCTION puls_workflow.resolve_approver" \
  "CREATE OR REPLACE FUNCTION puls_workflow.decide_approval_request" \
  "CREATE OR REPLACE FUNCTION puls_integration.apply_import_batch"
do
  if grep -v '^[[:space:]]*--' <<< "$CONTENT" | grep -Fq "$forbidden"; then
    echo "FAIL: migration must not replace runtime engine function: $forbidden"
    exit 1
  fi
done

for forbidden in \
  "supabase.functions.invoke" \
  "http://" \
  "https://" \
  "erp write" \
  "write to erp" \
  "ERP'ye" \
  "ERP’ye"
do
  if grep -v '^[[:space:]]*--' <<< "$CONTENT" | grep -Fiq "$forbidden"; then
    echo "FAIL: migration must not contain forbidden fragment: $forbidden"
    exit 1
  fi
done

if grep -E "search_path = .*\\bpublic\\b" <<< "$CONTENT" >/dev/null 2>&1; then
  echo "FAIL: functions must not include public in search_path"
  exit 1
fi

if git rev-parse origin/main >/dev/null 2>&1; then
  SRC_DIFF="$(git diff --name-only origin/main...HEAD -- src/ 2>/dev/null || true)"
  if [[ -n "$SRC_DIFF" ]]; then
    echo "FAIL: PR10.5 must not change src/ files"
    echo "$SRC_DIFF"
    exit 1
  fi
fi

echo "Checking ${REF}:${SMOKE} ..."

smoke_needles=(
  "BEGIN;"
  "ROLLBACK;"
  "PULS_EXPENSE_CATEGORY_ACCOUNT_CODE_INVALID"
  "PULS_EXPENSE_CATEGORY_CODE_INVALID"
  "PULS_EXPENSE_CATEGORY_RECEIPT_THRESHOLD_INVALID"
  "23505"
  "set_config('request.jwt.claim.role', 'service_role', true)"
  "demo_guardrails_dup_inactive"
)

for needle in "${smoke_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$SMOKE_CONTENT"; then
    echo "FAIL: smoke missing required fragment: $needle"
    exit 1
  fi
done

echo "OK: 10 PR10.5 expense category guardrails migration structural checks passed for ${REF}"
