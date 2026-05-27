#!/usr/bin/env bash
# Verifies 10 PR10.9 expense category lifecycle audit migration (POSIX grep/awk).
set -euo pipefail

REF="${1:-HEAD}"
FILE="supabase/migrations/20260525174000_puls_workflow_expense_category_lifecycle_audit.sql"
SMOKE="docs/data/10_expense_category_lifecycle_audit_smoke.sql"

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
  "expense_category_lifecycle_events"
  "action IN ('deactivated', 'restored')"
  "reason TEXT"
  "actor_user_id"
  "actor_role"
  "occurred_at"
  "ENABLE ROW LEVEL SECURITY"
  "expense_category_lifecycle_events_select_admin"
  "REVOKE ALL ON puls_workflow.expense_category_lifecycle_events"
  "GRANT SELECT ON puls_workflow.expense_category_lifecycle_events TO authenticated"
  "GRANT SELECT, INSERT ON puls_workflow.expense_category_lifecycle_events TO service_role"
  "CREATE OR REPLACE FUNCTION puls_workflow.deactivate_expense_category"
  "CREATE OR REPLACE FUNCTION puls_workflow.restore_expense_category"
  "PULS_EXPENSE_CATEGORY_LIFECYCLE_REASON_TOO_LONG"
  "INSERT INTO puls_workflow.expense_category_lifecycle_events"
  "'deactivated'"
  "'restored'"
  "auth.uid()"
  "auth.role()"
  "event_id"
  "SET search_path = pg_catalog, puls_workflow, puls_core"
)

for needle in "${needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$CONTENT"; then
    echo "FAIL: missing required fragment: $needle"
    exit 1
  fi
done

if grep -E "search_path = .*\\bauth\\b" <<< "$CONTENT" >/dev/null 2>&1; then
  echo "FAIL: functions must not include auth in search_path"
  exit 1
fi

if grep -E "search_path = .*\\bpublic\\b" <<< "$CONTENT" >/dev/null 2>&1; then
  echo "FAIL: functions must not include public in search_path"
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

for forbidden in \
  "supabase.functions.invoke" \
  "erp write" \
  "write to erp" \
  "ERP'ye" \
  "ERP’ye"
do
  if grep -v '^[[:space:]]*--' <<< "$CONTENT" | grep -Fiq "$forbidden"; then
    echo "FAIL: migration must not contain forbidden ERP fragment: $forbidden"
    exit 1
  fi
done

echo "Checking ${REF}:${SMOKE} ..."

smoke_needles=(
  "BEGIN;"
  "ROLLBACK;"
  "already_inactive"
  "already_active"
  "PULS_EXPENSE_CATEGORY_LIFECYCLE_REASON_TOO_LONG"
  "demo_lifecycle_audit_"
  "must not insert audit event"
  "should not insert new event"
  "is_active IS NOT TRUE"
  "ORDER BY occurred_at DESC, id DESC"
  "PULS_EXPENSE_CATEGORY_IN_USE_ACTIVE_CLAIMS"
)

for needle in "${smoke_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$SMOKE_CONTENT"; then
    echo "FAIL: smoke missing required fragment: $needle"
    exit 1
  fi
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if git rev-parse origin/main >/dev/null 2>&1; then
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
    scan_forbidden_in_src 'resolveApprover\(|decideApproval\(|importApply\(|puls_integration\(\).*\.(insert|update|upsert|delete)\(' 'resolver-decide-import-runtime'
    scan_forbidden_in_src 'write.*erp' 'write-erp-en'
    scan_forbidden_in_src '\bsync\b.*erp' 'sync-erp-en'
    scan_forbidden_in_src 'push.*erp' 'push-erp-en'
    scan_forbidden_in_src 'supabase\.functions\.invoke' 'supabase-functions-invoke'
  fi
fi

echo "OK: 10 PR10.9 expense category lifecycle audit checks passed for ${REF}"
