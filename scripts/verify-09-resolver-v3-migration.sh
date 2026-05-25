#!/usr/bin/env bash
# Verifies 09 PR5 resolver V3 migrations (enum split + resolver; POSIX grep/awk).
set -euo pipefail

REF="${1:-HEAD}"
ENUM_FILE="supabase/migrations/20260525162500_puls_workflow_approver_type_v3.sql"
RESOLVER_FILE="supabase/migrations/20260525163000_puls_workflow_resolver_v3.sql"
SMOKE="docs/data/09_resolver_v3_smoke.sql"
POLICY_ENGINE="supabase/migrations/20260524153000_puls_workflow_policy_engine.sql"

enum_sql() {
  git show "${REF}:${ENUM_FILE}" 2>/dev/null || cat "${ENUM_FILE}"
}

resolver_sql() {
  git show "${REF}:${RESOLVER_FILE}" 2>/dev/null || cat "${RESOLVER_FILE}"
}

smoke() {
  git show "${REF}:${SMOKE}" 2>/dev/null || cat "${SMOKE}"
}

ENUM_CONTENT="$(enum_sql)"
RESOLVER_CONTENT="$(resolver_sql)"
SMOKE_CONTENT="$(smoke)"

echo "Checking ${REF}:${ENUM_FILE} ..."

if grep -Fq "CREATE OR REPLACE FUNCTION" <<< "$ENUM_CONTENT"; then
  echo "FAIL: enum migration must not contain functions"
  exit 1
fi

for forbidden in finance_pool hr_pool legal_pool cost_center_owner; do
  if grep -v '^[[:space:]]*--' <<< "$ENUM_CONTENT" \
    | grep -v 'ALTER TYPE puls_workflow.approver_type ADD VALUE' \
    | grep -Eiq "'${forbidden}'::puls_workflow\.approver_type|approver_type.*'${forbidden}'"; then
    echo "FAIL: enum migration must not use new enum values outside ALTER TYPE ADD VALUE: ${forbidden}"
    exit 1
  fi
done

if grep -v '^[[:space:]]*--' <<< "$ENUM_CONTENT" \
  | grep -v 'ALTER TYPE puls_workflow.approver_type ADD VALUE' \
  | grep -Eiq 'CREATE|INSERT|UPDATE|DELETE|SELECT|FUNCTION'; then
  echo "FAIL: enum migration must contain only ALTER TYPE ADD VALUE statements"
  exit 1
fi

if ! grep -Fq "ALTER TYPE puls_workflow.approver_type ADD VALUE IF NOT EXISTS 'finance_pool'" <<< "$ENUM_CONTENT"; then
  echo "FAIL: missing finance_pool enum ADD VALUE"
  exit 1
fi

echo "Checking ${REF}:${RESOLVER_FILE} ..."

needles=(
  "CREATE OR REPLACE FUNCTION puls_workflow.resolve_policy_step_approver"
  "CREATE OR REPLACE FUNCTION puls_workflow.resolve_approver"
  "_resolve_pool_approver_by_type"
  "_resolve_cost_center_owner_approver"
  "_resolve_approver_type_branch"
  "_resolver_requester_cost_center_id"
  "_resolver_pool_scope"
  "finance_pool"
  "hr_pool"
  "legal_pool"
  "cost_center_owner"
  "pool_type"
  "authority_pools"
  "authority_pool_members"
  "authority_relationships"
  "resolve_org_primary_manager"
  "WHEN p.scope_type = p_scope_type"
  "employment_status = 'active'"
  "REVOKE ALL ON FUNCTION puls_workflow.resolve_policy_step_approver"
  "REVOKE ALL ON FUNCTION puls_workflow.resolve_approver"
)

for needle in "${needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$RESOLVER_CONTENT"; then
    echo "FAIL: missing required fragment: $needle"
    exit 1
  fi
done

if grep -v '^[[:space:]]*--' <<< "$RESOLVER_CONTENT" | grep -Fq "decide_approval_request"; then
  echo "FAIL: resolver migration must not reference decide_approval_request"
  exit 1
fi

if grep -E "search_path = .*\\bpublic\\b" <<< "$RESOLVER_CONTENT" >/dev/null 2>&1; then
  echo "FAIL: functions must not include public in search_path"
  exit 1
fi

if grep -Fq "GRANT EXECUTE ON FUNCTION puls_workflow.resolve_policy_step_approver" <<< "$RESOLVER_CONTENT"; then
  echo "FAIL: resolve_policy_step_approver must not be granted to authenticated"
  exit 1
fi

if grep -Fq "GRANT EXECUTE ON FUNCTION puls_workflow.resolve_approver" <<< "$RESOLVER_CONTENT"; then
  echo "FAIL: resolve_approver must not be granted to authenticated"
  exit 1
fi

if grep -v '^[[:space:]]*--' <<< "$RESOLVER_CONTENT" | grep -Fq "authority_relationships"; then
  manager_block="$(awk '
    /IF p_approver_type = .manager/ { in_mgr = 1 }
    in_mgr { print }
    in_mgr && /END IF;/ { exit }
  ' <<< "$RESOLVER_CONTENT")"
  if grep -Fq "authority_relationships" <<< "$manager_block"; then
    echo "FAIL: manager branch must not read authority_relationships"
    exit 1
  fi
fi

echo "Checking ${REF}:${POLICY_ENGINE} unchanged by PR5 (decide still present in baseline) ..."

if ! grep -Fq "CREATE OR REPLACE FUNCTION puls_workflow.decide_approval_request" <<< "$(git show "${REF}:${POLICY_ENGINE}" 2>/dev/null || cat "${POLICY_ENGINE}")"; then
  echo "FAIL: baseline policy engine must still define decide_approval_request"
  exit 1
fi

echo "Checking ${REF}:${SMOKE} ..."

smoke_needles=(
  "BEGIN;"
  "ROLLBACK;"
  "set_config('request.jwt.claim.role', 'service_role', true)"
  "SELECT puls_workflow.resolve_policy_step_approver"
  "finance_pool"
  "hr_pool"
  "legal_pool"
  "cost_center_owner"
  "scoped pool precedence"
  "manager"
  "hr_admin"
  "specific_employee"
  "inactive"
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

echo "OK: 09 PR5 resolver V3 migration structural checks passed for ${REF}"
