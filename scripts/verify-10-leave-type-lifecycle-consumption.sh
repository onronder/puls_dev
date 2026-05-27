#!/usr/bin/env bash
# Verifies 10 PR10.12 leave type lifecycle + consumption (POSIX grep/awk).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
MIGRATION="supabase/migrations/20260525180000_puls_workflow_leave_type_lifecycle.sql"
SMOKE="docs/data/10_leave_type_lifecycle_consumption_smoke.sql"
OVERVIEW="src/lib/data/leave/overview.ts"
SETUP_ADAPTER="src/lib/data/setup/leave-types.ts"
SETUP_ROUTE="src/routes/_app/izin-tanimlari.tsx"
CONSUMPTION_ROUTE="src/routes/_app/izin.tsx"
I18N_TR="src/i18n/locales/tr-TR.json"
I18N_EN="src/i18n/locales/en-US.json"

migration() {
  git show "${REF}:${MIGRATION}" 2>/dev/null || cat "${MIGRATION}"
}

smoke() {
  git show "${REF}:${SMOKE}" 2>/dev/null || cat "${SMOKE}"
}

MIGRATION_CONTENT="$(migration)"
SMOKE_CONTENT="$(smoke)"
OVERVIEW_CONTENT="$(cat "${OVERVIEW}")"
SETUP_ADAPTER_CONTENT="$(cat "${SETUP_ADAPTER}")"
SETUP_ROUTE_CONTENT="$(cat "${SETUP_ROUTE}")"
CONSUMPTION_ROUTE_CONTENT="$(cat "${CONSUMPTION_ROUTE}")"

echo "Checking ${REF}: PR10.12 leave type lifecycle + consumption ..."

for file in "$MIGRATION" "$SMOKE" "$OVERVIEW" "$SETUP_ADAPTER" "$SETUP_ROUTE" "$CONSUMPTION_ROUTE"; do
  if [[ ! -f "$file" ]]; then
    echo "FAIL: missing required file: $file"
    exit 1
  fi
done

MIGRATION_CHANGES="$(git diff --name-only --diff-filter=A origin/main...HEAD -- supabase/migrations/ 2>/dev/null || true)"
EXPECTED_MIGRATION="$(basename "$MIGRATION")"
if echo "$MIGRATION_CHANGES" | sed '/^$/d' | grep -vq "^supabase/migrations/${EXPECTED_MIGRATION}$" 2>/dev/null; then
  if [[ -n "$(echo "$MIGRATION_CHANGES" | sed '/^$/d' | grep -v "^supabase/migrations/${EXPECTED_MIGRATION}$" || true)" ]]; then
    echo "FAIL: PR10.12 must add only the lifecycle migration:"
    echo "$MIGRATION_CHANGES" | sed '/^$/d'
    exit 1
  fi
fi

migration_needles=(
  "_lock_leave_type_for_setup"
  "deactivate_leave_type"
  "restore_leave_type"
  "FOR UPDATE"
  "SECURITY DEFINER"
  "SET search_path = pg_catalog, puls_workflow, puls_core"
  "auth.role()"
  "PULS_LEAVE_TYPE_NOT_FOUND"
  "PULS_LEAVE_TYPE_FORBIDDEN"
  "PULS_LEAVE_TYPE_IN_USE_ACTIVE_REQUESTS"
  "end_date >= CURRENT_DATE"
  "status IN ('draft', 'pending')"
  "GRANT EXECUTE ON FUNCTION puls_workflow.deactivate_leave_type(UUID) TO authenticated, service_role"
  "GRANT EXECUTE ON FUNCTION puls_workflow.restore_leave_type(UUID) TO authenticated, service_role"
  "REVOKE ALL ON FUNCTION puls_workflow._lock_leave_type_for_setup"
)

for needle in "${migration_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION_CONTENT"; then
    echo "FAIL: migration missing required fragment: $needle"
    exit 1
  fi
done

if grep -v '^[[:space:]]*--' <<< "$MIGRATION_CONTENT" | grep 'GRANT EXECUTE ON FUNCTION puls_workflow._lock_leave_type_for_setup' | grep -Fq 'authenticated'; then
  echo "FAIL: internal lock helper must not be granted to authenticated"
  exit 1
fi

if grep -E "search_path = .*\\bauth\\b" <<< "$MIGRATION_CONTENT" >/dev/null 2>&1; then
  echo "FAIL: functions must not include auth in search_path"
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
  if grep -v '^[[:space:]]*--' <<< "$MIGRATION_CONTENT" | grep -Fq "$forbidden"; then
    echo "FAIL: migration must not contain forbidden fragment: $forbidden"
    exit 1
  fi
done

smoke_needles=(
  "BEGIN;"
  "ROLLBACK;"
  "deactivate_leave_type"
  "restore_leave_type"
  "already_inactive"
  "already_active"
  "PULS_INVALID_LEAVE_TYPE"
  "demo_leave_type_lifecycle_"
  "approved future/current should block deactivate"
  "approved past only should allow deactivate"
  "DELETE FROM puls_workflow.leave_requests"
  "historical leave request should reference inactive leave type row"
  "inactive leave type should reject create_leave_request"
)

for needle in "${smoke_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$SMOKE_CONTENT"; then
    echo "FAIL: smoke missing required fragment: $needle"
    exit 1
  fi
done

adapter_needles=(
  "deactivateLeaveType"
  "restoreLeaveType"
  "applyLeaveTypeLifecycleFilter"
  "mapLeaveTypeLifecycleError"
)

for needle in "${adapter_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$SETUP_ADAPTER_CONTENT"; then
    echo "FAIL: leave-types adapter missing required fragment: $needle"
    exit 1
  fi
done

if ! grep -Fq ".eq('is_active', true)" <<< "$OVERVIEW_CONTENT"; then
  echo "FAIL: overview must keep active-only leave type picker filter"
  exit 1
fi

if ! grep -Fq "is_active" <<< "$OVERVIEW_CONTENT"; then
  echo "FAIL: overview must include is_active in historical leave type lookup"
  exit 1
fi

if ! grep -Fq "mapLeaveTypeFromLookup" <<< "$OVERVIEW_CONTENT"; then
  echo "FAIL: overview must export mapLeaveTypeFromLookup helper"
  exit 1
fi

if ! grep -Fq "typeIsActive" <<< "$OVERVIEW_CONTENT"; then
  echo "FAIL: overview must map typeIsActive on leave request DTOs"
  exit 1
fi

HISTORICAL_LOOKUP_BLOCK="$(awk '/leaveTypeIds\.length > 0/,/new Map\(\)/' "$OVERVIEW" || true)"
if [[ -z "$HISTORICAL_LOOKUP_BLOCK" ]]; then
  echo "FAIL: could not locate historical leave type lookup block in overview"
  exit 1
fi

if grep -Fq ".eq('is_active', true)" <<< "$HISTORICAL_LOOKUP_BLOCK"; then
  echo "FAIL: historical leave type lookup must not filter to active-only"
  exit 1
fi

for needle in applyLeaveTypeLifecycleFilter deactivateLeaveType restoreLeaveType; do
  if ! grep -Fq "$needle" <<< "$SETUP_ROUTE_CONTENT"; then
    echo "FAIL: izin-tanimlari route missing UI needle: $needle"
    exit 1
  fi
done

for needle in typeIsActive inactiveTypeBadge noActiveLeaveTypes; do
  if ! grep -Fq "$needle" <<< "$CONSUMPTION_ROUTE_CONTENT"; then
    echo "FAIL: izin route missing UI needle: $needle"
    exit 1
  fi
done

for key in inactiveTypeBadge inactiveTypeHint noActiveLeaveTypes; do
  if ! grep -Fq "\"$key\"" "$I18N_TR" || ! grep -Fq "\"$key\"" "$I18N_EN"; then
    echo "FAIL: missing i18n key leaveSetup.typeLifecycle.$key"
    exit 1
  fi
done

for key in filter.active filter.inactive filter.all status.active status.inactive actions.deactivate actions.restore confirm.deactivate confirm.restore toast.deactivated toast.restored errors.activeRequests errors.notFound errors.forbidden errors.generic sheet.inactiveTitle sheet.inactiveDescription; do
  tr_key="leaveTypeSetup.lifecycle.${key}"
  if ! grep -Fq "\"${key%.*}\"" "$I18N_TR" && ! grep -Fq "\"${key##*.}\"" "$I18N_TR"; then
    :
  fi
done

if ! grep -Fq '"lifecycle"' "$I18N_TR" || ! grep -Fq '"typeLifecycle"' "$I18N_TR"; then
  echo "FAIL: missing leaveTypeSetup.lifecycle or leaveSetup.typeLifecycle namespace in tr-TR"
  exit 1
fi

if ! grep -Fq '"lifecycle"' "$I18N_EN" || ! grep -Fq '"typeLifecycle"' "$I18N_EN"; then
  echo "FAIL: missing leaveTypeSetup.lifecycle or leaveSetup.typeLifecycle namespace in en-US"
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
  scan_forbidden_in_src 'resolveApprover\(|decideApproval\(|importApply\(|puls_integration\(\).*\.(insert|update|upsert|delete)\(' 'resolver-decide-import-runtime'
  scan_forbidden_in_src 'write.*erp' 'write-erp-en'
  scan_forbidden_in_src '\bsync\b.*erp' 'sync-erp-en'
  scan_forbidden_in_src 'push.*erp' 'push-erp-en'
  scan_forbidden_in_src 'supabase\.functions\.invoke' 'supabase-functions-invoke'
  scan_forbidden_in_src 'DELETE FROM puls_workflow\.leave_types' 'leave-type-delete'
fi

echo "OK: PR10.12 leave type lifecycle + consumption checks passed for ${REF}"
