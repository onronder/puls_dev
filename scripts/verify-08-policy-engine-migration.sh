#!/usr/bin/env bash
# Verifies 08 migration SQL invariants (run after fetch from origin).
set -euo pipefail

REF="${1:-origin/cursor/08-approval-policy-engine-b5b2}"
FILE="supabase/migrations/20260524153000_puls_workflow_policy_engine.sql"

sql() {
  git show "${REF}:${FILE}"
}

echo "Checking ${REF}:${FILE} ..."

if sql | rg -U "resolve_policy_step_approver\\([\\s\\S]*?\\);\\s*\\n\\s+v_expense_claim\\.id," -q; then
  echo "FAIL: broken expense intermediate approve branch (orphan args after resolve_policy_step_approver)"
  exit 1
fi

for needle in \
  "v_next_approval_id := puls_workflow.create_next_approval_request" \
  "PULS_POLICY_NOT_FOUND: Approval policy not found or inactive." \
  "AND p.tenant_id = p_tenant_id"; do
  if ! sql | rg -Fq "$needle"; then
    echo "FAIL: missing required fragment: $needle"
    exit 1
  fi
done

count_create="$(sql | rg -c "v_next_approval_id := puls_workflow.create_next_approval_request" || true)"
if [[ "$count_create" != "2" ]]; then
  echo "FAIL: expected 2 create_next_approval_request assignments (leave + expense), got ${count_create}"
  exit 1
fi

echo "OK: migration structural checks passed for ${REF}"
