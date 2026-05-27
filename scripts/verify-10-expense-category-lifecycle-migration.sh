#!/usr/bin/env bash
# Verifies 10 PR10.7 expense category lifecycle migration (POSIX grep/awk).
set -euo pipefail

REF="${1:-HEAD}"
FILE="supabase/migrations/20260525173000_puls_workflow_expense_category_lifecycle.sql"
SMOKE="docs/data/10_expense_category_lifecycle_smoke.sql"

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
  "_lock_expense_category_for_setup"
  "deactivate_expense_category"
  "restore_expense_category"
  "FOR UPDATE"
  "SECURITY DEFINER"
  "SET search_path = pg_catalog, puls_workflow, puls_core"
  "auth.role()"
  "PULS_EXPENSE_CATEGORY_FORBIDDEN"
  "current_tenant_id()"
  "PULS_EXPENSE_CATEGORY_IN_USE_ACTIVE_CLAIMS"
  "PULS_EXPENSE_CATEGORY_NOT_FOUND"
  "GRANT EXECUTE ON FUNCTION puls_workflow.deactivate_expense_category(UUID, TEXT) TO authenticated, service_role"
  "GRANT EXECUTE ON FUNCTION puls_workflow.restore_expense_category(UUID) TO authenticated, service_role"
  "REVOKE ALL ON FUNCTION puls_workflow._lock_expense_category_for_setup"
)

for needle in "${needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$CONTENT"; then
    echo "FAIL: missing required fragment: $needle"
    exit 1
  fi
done

if grep -v '^[[:space:]]*--' <<< "$CONTENT" | grep 'GRANT EXECUTE ON FUNCTION puls_workflow._lock_expense_category_for_setup' | grep -Fq 'authenticated'; then
  echo "FAIL: internal lock helper must not be granted to authenticated"
  exit 1
fi

if grep -E "search_path = .*\\bauth\\b" <<< "$CONTENT" >/dev/null 2>&1; then
  echo "FAIL: functions must not include auth in search_path"
  exit 1
fi

for forbidden in \
  "DELETE FROM puls_workflow.expense_categories" \
  "PULS_EXPENSE_CATEGORY_ACTIVE_POLICY_BOUND" \
  "CREATE OR REPLACE FUNCTION puls_workflow.resolve_policy_step_approver" \
  "CREATE OR REPLACE FUNCTION puls_workflow.resolve_approver" \
  "CREATE OR REPLACE FUNCTION puls_workflow.decide_approval_request" \
  "CREATE OR REPLACE FUNCTION puls_integration.apply_import_batch"
do
  if grep -v '^[[:space:]]*--' <<< "$CONTENT" | grep -Fq "$forbidden"; then
    echo "FAIL: migration must not contain forbidden fragment: $forbidden"
    exit 1
  fi
done

if grep -E "search_path = .*\\bpublic\\b" <<< "$CONTENT" >/dev/null 2>&1; then
  echo "FAIL: functions must not include public in search_path"
  exit 1
fi

echo "Checking ${REF}:${SMOKE} ..."

smoke_needles=(
  "BEGIN;"
  "ROLLBACK;"
  "deactivate_expense_category"
  "restore_expense_category"
  "demo_lifecycle_draft"
  "demo_lifecycle_pending"
  "demo_lifecycle_approved"
  "demo_lifecycle_exported"
  "has_history"
  "23505"
  "set_config('request.jwt.claim.role', 'service_role', true)"
)

for needle in "${smoke_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$SMOKE_CONTENT"; then
    echo "FAIL: smoke missing required fragment: $needle"
    exit 1
  fi
done

echo "OK: 10 PR10.7 expense category lifecycle migration structural checks passed for ${REF}"
