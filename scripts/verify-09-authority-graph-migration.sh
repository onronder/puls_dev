#!/usr/bin/env bash
# Verifies 09 PR3 authority graph migration SQL invariants (POSIX grep/awk; no rg).
set -euo pipefail

REF="${1:-origin/cursor/09-authority-graph-b5b2}"
FILE="supabase/migrations/20260525153000_puls_core_authority_graph.sql"
SMOKE="docs/data/09_authority_graph_smoke.sql"

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
  "CREATE TABLE IF NOT EXISTS puls_core.authority_pools"
  "CREATE TABLE IF NOT EXISTS puls_core.authority_pool_members"
  "CREATE TABLE IF NOT EXISTS puls_core.authority_relationships"
  "CREATE TYPE puls_core.authority_type AS ENUM"
  "CREATE TYPE puls_core.authority_scope_type AS ENUM"
  "CREATE TYPE puls_core.authority_module AS ENUM"
  "CREATE TYPE puls_core.authority_pool_type AS ENUM"
  "validate_authority_scope"
  "PULS_AUTHORITY_MODULE_INVALID"
  "PULS_AUTHORITY_SELF_DELEGATE"
  "is_pool_member_by_type"
  "puls_core_authority_pools_validate"
  "puls_core_auth_pool_members_validate"
  "puls_core_auth_relationships_validate"
  "ENABLE ROW LEVEL SECURITY"
  "puls_core_authority_pools_insert"
  "puls_core_authority_pools_update"
  "can_read_authority_graph"
  "can_manage_authority_graph"
  "GRANT ALL ON puls_core.authority_pools TO service_role"
  "GRANT ALL ON puls_core.authority_relationships TO service_role"
  "REVOKE ALL ON FUNCTION puls_core.validate_authority_scope"
  "GRANT EXECUTE ON FUNCTION puls_core.is_pool_member_by_type"
)

for needle in "${needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$CONTENT"; then
    echo "FAIL: missing required fragment: $needle"
    exit 1
  fi
done

if grep -E "owner_employee_id[[:space:]]+(UUID|uuid)" <<< "$CONTENT" >/dev/null 2>&1; then
  echo "FAIL: owner_employee_id column must not appear in PR3 migration"
  exit 1
fi

if grep -Fq "decide_approval_request" <<< "$CONTENT"; then
  echo "FAIL: decide_approval_request must not appear in PR3 migration"
  exit 1
fi

if grep -Fq "resolve_policy_step_approver" <<< "$CONTENT"; then
  echo "FAIL: resolve_policy_step_approver must not appear in PR3 migration"
  exit 1
fi

if grep -v '^[[:space:]]*--' <<< "$CONTENT" | grep -Fq "employee_reporting_lines"; then
  echo "FAIL: PR3 must not modify manager SoT (employee_reporting_lines)"
  exit 1
fi

if grep -E "search_path = .*\\bpublic\\b" <<< "$CONTENT" >/dev/null 2>&1; then
  echo "FAIL: functions must not include public in search_path"
  exit 1
fi

if grep -Fq "FOR DELETE" <<< "$CONTENT"; then
  echo "FAIL: PR3 must not add DELETE policies"
  exit 1
fi

# Parse authority_type enum DDL only — avoid comment false positives
ENUM_BLOCK="$(awk '
  /CREATE TYPE puls_core\.authority_type AS ENUM/ { in_enum = 1 }
  in_enum { print }
  in_enum && /\);/ { exit }
' <<< "$CONTENT")"

if [[ -z "$ENUM_BLOCK" ]]; then
  echo "FAIL: could not parse authority_type enum DDL block"
  exit 1
fi

for forbidden in direct_manager primary_manager management_chain manager; do
  if grep -Fq "'${forbidden}'" <<< "$ENUM_BLOCK"; then
    echo "FAIL: forbidden authority_type enum value in DDL: ${forbidden}"
    exit 1
  fi
done

# contracts must not appear in authority_scope_type enum
SCOPE_ENUM="$(awk '
  /CREATE TYPE puls_core\.authority_scope_type AS ENUM/ { in_enum = 1 }
  in_enum { print }
  in_enum && /\);/ { exit }
' <<< "$CONTENT")"

if grep -Fq "'contracts'" <<< "$SCOPE_ENUM"; then
  echo "FAIL: contracts must not appear in authority_scope_type enum"
  exit 1
fi

SCOPE_COUNT="$(grep -Eo "'[a-z_]+'" <<< "$SCOPE_ENUM" | wc -l | tr -d ' ')"
if [[ "$SCOPE_COUNT" != "8" ]]; then
  echo "FAIL: authority_scope_type enum must have exactly 8 values, got ${SCOPE_COUNT}"
  exit 1
fi

echo "Checking ${REF}:${SMOKE} ..."

smoke_needles=(
  "PULS_AUTHORITY_SCOPE_INVALID"
  "PULS_AUTHORITY_MODULE_INVALID"
  "PULS_AUTHORITY_SELF_DELEGATE"
  "smoke_finance_pool"
  "cost_center_owner"
  "pg_enum"
  "request.jwt.claim.sub"
  "set_config('request.jwt.claim.sub', '', true)"
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

echo "OK: 09 PR3 authority graph migration structural checks passed for ${REF}"
