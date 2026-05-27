#!/usr/bin/env bash
# Verifies 10 PR10.11 leave type guardrails migration + app wiring (POSIX grep/awk).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
MIGRATION="supabase/migrations/20260525175000_puls_workflow_leave_type_guardrails.sql"
SMOKE="docs/data/10_leave_type_guardrails_smoke.sql"
VALIDATION="src/lib/data/setup/leave-type-validation.ts"
ADAPTER="src/lib/data/setup/leave-types.ts"
POLICIES="src/lib/data/workflow/policies.ts"
ROUTE="src/routes/_app/izin-tanimlari.tsx"

sql() {
  git show "${REF}:${MIGRATION}" 2>/dev/null || cat "${MIGRATION}"
}

smoke() {
  git show "${REF}:${SMOKE}" 2>/dev/null || cat "${SMOKE}"
}

file_at_ref() {
  local path="$1"
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

CONTENT="$(sql)"
SMOKE_CONTENT="$(smoke)"
VALIDATION_CONTENT="$(file_at_ref "$VALIDATION")"
ADAPTER_CONTENT="$(file_at_ref "$ADAPTER")"
POLICIES_CONTENT="$(file_at_ref "$POLICIES")"
ROUTE_CONTENT="$(file_at_ref "$ROUTE")"

echo "Checking ${REF}: PR10.11 leave type guardrails ..."

for file in "$MIGRATION" "$SMOKE" "$VALIDATION" "$ADAPTER" "$POLICIES" "$ROUTE"; do
  if [[ ! -f "$file" ]]; then
    echo "FAIL: missing required file: $file"
    exit 1
  fi
done

needles=(
  "_normalize_leave_type_text"
  "validate_leave_type_guardrails"
  "BEFORE INSERT OR UPDATE"
  "puls_workflow_leave_types_validate_guardrails"
  "PULS_LEAVE_TYPE_NAME_REQUIRED"
  "PULS_LEAVE_TYPE_CODE_REQUIRED"
  "PULS_LEAVE_TYPE_CODE_INVALID"
  "PULS_LEAVE_TYPE_ENTITLEMENT_INVALID"
  "PULS_LEAVE_TYPE_CARRY_OVER_INVALID"
  "PULS_LEAVE_TYPE_POLICY_INVALID"
  "PULS_LEAVE_TYPE_POLICY_MODULE_INVALID"
  "^[a-z][a-z0-9_]{1,63}$"
  "'leave'::puls_workflow.approval_module"
  "REVOKE ALL ON FUNCTION"
  "GRANT EXECUTE ON FUNCTION puls_workflow._normalize_leave_type_text(TEXT) TO service_role"
  "GRANT EXECUTE ON FUNCTION puls_workflow.validate_leave_type_guardrails() TO service_role"
)

for needle in "${needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$CONTENT"; then
    echo "FAIL: migration missing required fragment: $needle"
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
  "CREATE OR REPLACE FUNCTION puls_integration.apply_import_batch" \
  "deactivate_leave_type" \
  "restore_leave_type"
do
  if grep -v '^[[:space:]]*--' <<< "$CONTENT" | grep -Fq "$forbidden"; then
    echo "FAIL: migration must not contain forbidden fragment: $forbidden"
    exit 1
  fi
done

smoke_needles=(
  "BEGIN;"
  "ROLLBACK;"
  "demo_leave_type_guardrails_"
  "PULS_LEAVE_TYPE_NAME_REQUIRED"
  "PULS_LEAVE_TYPE_CODE_REQUIRED"
  "PULS_LEAVE_TYPE_CODE_INVALID"
  "PULS_LEAVE_TYPE_ENTITLEMENT_INVALID"
  "PULS_LEAVE_TYPE_CARRY_OVER_INVALID"
  "PULS_LEAVE_TYPE_POLICY_MODULE_INVALID"
  "23505"
  "demo_leave_type_guardrails_dup"
  "expected half-day entitlement 1.5"
  "set_config('request.jwt.claim.role', 'service_role', true)"
)

for needle in "${smoke_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$SMOKE_CONTENT"; then
    echo "FAIL: smoke missing required fragment: $needle"
    exit 1
  fi
done

for needle in validateLeaveTypeForm createLeaveType updateLeaveType mapLeaveTypeMutationError; do
  if ! grep -Fq "$needle" <<< "$VALIDATION_CONTENT$ADAPTER_CONTENT"; then
    echo "FAIL: leave type setup missing: $needle"
    exit 1
  fi
done

if ! grep -Fq "resolveAdapterData" <<< "$POLICIES_CONTENT"; then
  echo "FAIL: fetchApprovalPoliciesOverview must use resolveAdapterData demo fallback"
  exit 1
fi

if ! grep -Fq "fetchDemoApprovalPoliciesOverview" <<< "$POLICIES_CONTENT"; then
  echo "FAIL: policies adapter must wire demo fallback"
  exit 1
fi

for needle in ApprovalPolicyBindingSection createLeaveType updateLeaveType validateLeaveTypeForm; do
  if ! grep -Fq "$needle" <<< "$ROUTE_CONTENT"; then
    echo "FAIL: izin-tanimlari route missing: $needle"
    exit 1
  fi
done

if ! grep -Fq "policyCurrent" <<< "$ROUTE_CONTENT"; then
  echo "FAIL: route must preserve current bound policy in select (policyCurrent)"
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
  scan_forbidden_in_src 'deactivate_leave_type|restore_leave_type' 'leave-lifecycle-rpc'
fi

echo "OK: PR10.11 leave type guardrails checks passed for ${REF}"
