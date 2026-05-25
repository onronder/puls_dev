#!/usr/bin/env bash
# Verifies 10 PR10.2 resolver config V1 migration (POSIX grep/awk).
set -euo pipefail

REF="${1:-HEAD}"
FILE="supabase/migrations/20260525171000_puls_workflow_resolver_config_v1.sql"
SMOKE="docs/data/10_resolver_config_v1_smoke.sql"

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
  "scope_strategy"
  "scope_type"
  "scope_id"
  "scope_code"
  "allow_tenant_fallback"
  "DROP FUNCTION IF EXISTS puls_workflow._resolve_pool_approver_by_type"
  "DROP FUNCTION IF EXISTS puls_workflow._resolve_approver_type_branch"
  "CREATE OR REPLACE FUNCTION puls_workflow.policy_step_condition_config_allowed_keys"
  "ARRAY[]::TEXT[]"
  "_validate_policy_step_resolver_config_semantics"
  "_resolver_step_config_scope"
  "p_include_tenant_fallback"
  "PULS_POLICY_STEP_RESOLVER_CONFIG_INVALID_SCOPE_ID"
  "jsonb_typeof"
  "s.step_resolver_config"
  "step_resolver_config"
  "CREATE OR REPLACE FUNCTION puls_workflow.resolve_approver"
  "CREATE OR REPLACE FUNCTION puls_workflow._resolve_approver_type_branch"
  "REVOKE ALL ON FUNCTION puls_workflow._resolve_pool_approver_by_type(UUID, puls_core.authority_pool_type, TEXT, puls_core.authority_scope_type, UUID, UUID, BOOLEAN, DATE)"
  "REVOKE ALL ON FUNCTION puls_workflow._resolve_approver_type_branch(UUID, UUID, TEXT, puls_workflow.approver_type, UUID, JSONB)"
  "p_module <> 'expense'"
)

for needle in "${needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$CONTENT"; then
    echo "FAIL: missing required fragment: $needle"
    exit 1
  fi
done

for forbidden in \
  "CREATE OR REPLACE FUNCTION puls_workflow.decide_approval_request" \
  "CREATE OR REPLACE FUNCTION puls_workflow.find_first_required_policy_step" \
  "CREATE OR REPLACE FUNCTION puls_workflow.find_next_required_policy_step"
do
  if grep -v '^[[:space:]]*--' <<< "$CONTENT" | grep -Fq "$forbidden"; then
    echo "FAIL: migration must not replace runtime engine function: $forbidden"
    exit 1
  fi
done

if grep -E "search_path = .*\\bpublic\\b" <<< "$CONTENT" >/dev/null 2>&1; then
  echo "FAIL: functions must not include public in search_path"
  exit 1
fi

if git diff --name-only "${REF}" -- src/ 2>/dev/null | grep -q .; then
  echo "FAIL: PR10.2 must not change src/ files"
  exit 1
fi

echo "Checking ${REF}:${SMOKE} ..."

smoke_needles=(
  "BEGIN;"
  "ROLLBACK;"
  "scope_strategy"
  "tenant"
  "allow_tenant_fallback"
  "explicit"
  "scope_code"
  "cost_center_owner"
  "resolve_policy_step_approver"
  "PULS_POLICY_STEP_RESOLVER_CONFIG"
  "hr_admin"
  "specific_employee"
  "leave"
)

for needle in "${smoke_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$SMOKE_CONTENT"; then
    echo "FAIL: smoke missing required fragment: $needle"
    exit 1
  fi
done

if grep -E "^-- Manual negative checks" <<< "$SMOKE_CONTENT" >/dev/null 2>&1; then
  echo "FAIL: smoke must not leave negative checks as comment-only section"
  exit 1
fi

echo "OK: 10 PR10.2 resolver config V1 migration structural checks passed for ${REF}"
