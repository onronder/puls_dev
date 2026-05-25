#!/usr/bin/env bash
# Verifies 10 PR10.1 policy step config foundation migration (POSIX grep/awk).
set -euo pipefail

REF="${1:-HEAD}"
FILE="supabase/migrations/20260525170000_puls_workflow_policy_step_config.sql"
SMOKE="docs/data/10_policy_step_config_smoke.sql"

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
  "ADD COLUMN IF NOT EXISTS step_resolver_config"
  "ADD COLUMN IF NOT EXISTS step_condition_config"
  "policy_step_resolver_config_allowed_keys"
  "policy_step_condition_config_allowed_keys"
  "policy_step_config_blocked_keys"
  "_validate_policy_step_config_object"
  "validate_approval_policy_step_config"
  "LANGUAGE sql"
  "IMMUTABLE"
  "SECURITY DEFINER"
  "BEFORE INSERT OR UPDATE"
  "PULS_POLICY_STEP_CONFIG_INVALID"
  "PULS_POLICY_STEP_CONFIG_INVALID_VALUE"
  "PULS_POLICY_STEP_CONFIG_FORBIDDEN_FIELD"
  "PULS_POLICY_STEP_CONFIG_UNKNOWN_FIELD"
  "SENSITIVE_BLOCK_LIST_BEGIN"
  "SENSITIVE_BLOCK_LIST_END"
  "REVOKE ALL ON FUNCTION puls_workflow.policy_step_resolver_config_allowed_keys()"
  "REVOKE ALL ON FUNCTION puls_workflow.policy_step_condition_config_allowed_keys()"
  "REVOKE ALL ON FUNCTION puls_workflow.policy_step_config_blocked_keys()"
  "REVOKE ALL ON FUNCTION puls_workflow._validate_policy_step_config_object(JSONB, TEXT[], TEXT[], TEXT)"
  "REVOKE ALL ON FUNCTION puls_workflow.validate_approval_policy_step_config()"
)

for needle in "${needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$CONTENT"; then
    echo "FAIL: missing required fragment: $needle"
    exit 1
  fi
done

if grep -v '^[[:space:]]*--' <<< "$CONTENT" | grep -Fq "UPDATE OF step_resolver_config"; then
  echo "FAIL: trigger must not be scoped to UPDATE OF step_resolver_config"
  exit 1
fi

if grep -v '^[[:space:]]*--' <<< "$CONTENT" | grep -Fq "UPDATE OF step_condition_config"; then
  echo "FAIL: trigger must not be scoped to UPDATE OF step_condition_config"
  exit 1
fi

for forbidden in \
  "CREATE OR REPLACE FUNCTION puls_workflow.find_first_required_policy_step" \
  "CREATE OR REPLACE FUNCTION puls_workflow.find_next_required_policy_step" \
  "CREATE OR REPLACE FUNCTION puls_workflow.resolve_policy_step_approver" \
  "CREATE OR REPLACE FUNCTION puls_workflow.resolve_approver" \
  "CREATE OR REPLACE FUNCTION puls_workflow.decide_approval_request"
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

if grep -Fq "GRANT EXECUTE ON FUNCTION puls_workflow.validate_approval_policy_step_config" <<< "$CONTENT"; then
  echo "FAIL: validation helpers must not be granted to authenticated"
  exit 1
fi

echo "Checking ${REF}:${SMOKE} ..."

smoke_needles=(
  "BEGIN;"
  "ROLLBACK;"
  "step_resolver_config"
  "step_condition_config"
  "PULS_POLICY_STEP_CONFIG_UNKNOWN_FIELD"
  "PULS_POLICY_STEP_CONFIG_FORBIDDEN_FIELD"
  "PULS_POLICY_STEP_CONFIG_INVALID"
  "resolve_policy_step_approver"
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

echo "OK: 10 PR10.1 policy step config migration structural checks passed for ${REF}"
