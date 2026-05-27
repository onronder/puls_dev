#!/usr/bin/env bash
# Verifies 10 PR10.13 leave type lifecycle audit migration (POSIX grep/awk).
set -euo pipefail

REF="${1:-HEAD}"
FILE="supabase/migrations/20260525181000_puls_workflow_leave_type_lifecycle_audit.sql"
TIMESTAMP_FIX_FILE="supabase/migrations/20260525181200_puls_workflow_leave_type_lifecycle_audit_timestamp_fix.sql"
SMOKE="docs/data/10_leave_type_lifecycle_audit_smoke.sql"

sql() {
  git show "${REF}:${FILE}" 2>/dev/null || cat "${FILE}"
}

timestamp_fix_sql() {
  git show "${REF}:${TIMESTAMP_FIX_FILE}" 2>/dev/null || cat "${TIMESTAMP_FIX_FILE}"
}

smoke() {
  git show "${REF}:${SMOKE}" 2>/dev/null || cat "${SMOKE}"
}

CONTENT="$(sql)"
TIMESTAMP_FIX_CONTENT="$(timestamp_fix_sql)"
SMOKE_CONTENT="$(smoke)"

echo "Checking ${REF}:${FILE} ..."

needles=(
  "leave_type_lifecycle_events"
  "action IN ('deactivated', 'restored')"
  "reason TEXT"
  "actor_user_id"
  "actor_role"
  "occurred_at"
  "ENABLE ROW LEVEL SECURITY"
  "leave_type_lifecycle_events_select_admin"
  "REVOKE ALL ON puls_workflow.leave_type_lifecycle_events"
  "GRANT SELECT ON puls_workflow.leave_type_lifecycle_events TO authenticated"
  "GRANT SELECT, INSERT ON puls_workflow.leave_type_lifecycle_events TO service_role"
  "DROP FUNCTION IF EXISTS puls_workflow.deactivate_leave_type(UUID)"
  "CREATE OR REPLACE FUNCTION puls_workflow.deactivate_leave_type"
  "CREATE OR REPLACE FUNCTION puls_workflow.restore_leave_type"
  "PULS_LEAVE_TYPE_LIFECYCLE_REASON_TOO_LONG"
  "INSERT INTO puls_workflow.leave_type_lifecycle_events"
  "'deactivated'"
  "'restored'"
  "auth.uid()"
  "auth.role()"
  "event_id"
  "end_date >= CURRENT_DATE"
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
  "DELETE FROM puls_workflow.leave_types" \
  "PULS_LEAVE_TYPE_ACTIVE_POLICY_BOUND" \
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

echo "Checking ${REF}:${TIMESTAMP_FIX_FILE} ..."

timestamp_fix_needles=(
  "ALTER COLUMN occurred_at SET DEFAULT clock_timestamp()"
  "CREATE OR REPLACE FUNCTION puls_workflow.deactivate_leave_type"
  "CREATE OR REPLACE FUNCTION puls_workflow.restore_leave_type"
  "occurred_at,"
  "clock_timestamp()"
  "GRANT EXECUTE ON FUNCTION puls_workflow.deactivate_leave_type(UUID, TEXT)"
  "GRANT EXECUTE ON FUNCTION puls_workflow.restore_leave_type(UUID)"
)

for needle in "${timestamp_fix_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$TIMESTAMP_FIX_CONTENT"; then
    echo "FAIL: timestamp fix migration missing required fragment: $needle"
    exit 1
  fi
done

if ! grep -Fq "clock_timestamp()" <<< "$TIMESTAMP_FIX_CONTENT"; then
  echo "FAIL: timestamp fix migration must use clock_timestamp() for audit ordering"
  exit 1
fi

if grep -E "search_path = .*\\bauth\\b" <<< "$TIMESTAMP_FIX_CONTENT" >/dev/null 2>&1; then
  echo "FAIL: timestamp fix functions must not include auth in search_path"
  exit 1
fi

if grep -E "search_path = .*\\bpublic\\b" <<< "$TIMESTAMP_FIX_CONTENT" >/dev/null 2>&1; then
  echo "FAIL: timestamp fix functions must not include public in search_path"
  exit 1
fi

for forbidden in \
  "DELETE FROM puls_workflow.leave_types" \
  "CREATE OR REPLACE FUNCTION puls_workflow.resolve_policy_step_approver" \
  "CREATE OR REPLACE FUNCTION puls_workflow.resolve_approver" \
  "CREATE OR REPLACE FUNCTION puls_workflow.decide_approval_request" \
  "CREATE OR REPLACE FUNCTION puls_integration.apply_import_batch"
do
  if grep -v '^[[:space:]]*--' <<< "$TIMESTAMP_FIX_CONTENT" | grep -Fq "$forbidden"; then
    echo "FAIL: timestamp fix migration must not contain forbidden fragment: $forbidden"
    exit 1
  fi
done

echo "Checking ${REF}:${SMOKE} ..."

smoke_needles=(
  "BEGIN;"
  "ROLLBACK;"
  "already_inactive"
  "already_active"
  "PULS_LEAVE_TYPE_LIFECYCLE_REASON_TOO_LONG"
  "demo_leave_type_lifecycle_audit_"
  "must not insert audit event"
  "should not insert new event"
  "is_active IS NOT TRUE"
  "ORDER BY occurred_at DESC, id DESC"
  "PULS_LEAVE_TYPE_IN_USE_ACTIVE_REQUESTS"
  "deactivate_leave_type(v_leave_type_id_omitted)"
  "omitted reason arg"
  "no open requests"
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

  for forbidden_file in \
    "src/routes/_app/izin.tsx" \
    "src/lib/data/leave/overview.ts"
  do
    if git diff --name-only origin/main...HEAD -- "$forbidden_file" 2>/dev/null | grep -Fq "$forbidden_file"; then
      echo "FAIL: PR10.13 must not change consumption file: $forbidden_file"
      exit 1
    fi
  done

  ADAPTER_NEEDLES=(
    "normalizeDeactivateLeaveTypeReason"
    "isDeactivateLeaveTypeReasonTooLong"
    "fetchLeaveTypeLifecycleEvents"
    "mapLeaveTypeLifecycleEventRow"
  )

  for needle in "${ADAPTER_NEEDLES[@]}"; do
    if ! grep -Fq "$needle" src/lib/data/setup/leave-types.ts 2>/dev/null; then
      echo "FAIL: adapter missing required fragment: $needle"
      exit 1
    fi
  done

  if ! grep -Fq '"lifecycleAudit"' src/i18n/locales/en-US.json 2>/dev/null; then
    echo "FAIL: en-US.json missing leaveTypeSetup.lifecycleAudit keys"
    exit 1
  fi

  if ! grep -Fq '"lifecycleAudit"' src/i18n/locales/tr-TR.json 2>/dev/null; then
    echo "FAIL: tr-TR.json missing leaveTypeSetup.lifecycleAudit keys"
    exit 1
  fi
fi

echo "OK: 10 PR10.13 leave type lifecycle audit checks passed for ${REF} (includes timestamp fix)"
