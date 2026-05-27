#!/usr/bin/env bash
# Verifies 10 PR10.10 approval policy binding readiness (POSIX grep/awk).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
SMOKE="docs/data/10_approval_policy_binding_readiness_smoke.sql"
HELPER="src/lib/data/workflow/policy-binding-readiness.ts"
HELPER_TEST="src/lib/data/workflow/policy-binding-readiness.test.ts"
EXPENSE_ADAPTER="src/lib/data/setup/expense-categories.ts"
LEAVE_ADAPTER="src/lib/data/setup/leave-types.ts"
EXPENSE_ROUTE="src/routes/_app/masraf-kategorileri.tsx"
LEAVE_ROUTE="src/routes/_app/izin-tanimlari.tsx"
UI_COMPONENT="src/components/puls/ApprovalPolicyBindingSection.tsx"
DATA_INDEX="src/lib/data/index.ts"
I18N_TR="src/i18n/locales/tr-TR.json"
I18N_EN="src/i18n/locales/en-US.json"

smoke() {
  git show "${REF}:${SMOKE}" 2>/dev/null || cat "${SMOKE}"
}

file_at_ref() {
  local path="$1"
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

SMOKE_CONTENT="$(smoke)"
HELPER_CONTENT="$(file_at_ref "$HELPER")"
HELPER_TEST_CONTENT="$(file_at_ref "$HELPER_TEST")"
EXPENSE_ADAPTER_CONTENT="$(file_at_ref "$EXPENSE_ADAPTER")"
LEAVE_ADAPTER_CONTENT="$(file_at_ref "$LEAVE_ADAPTER")"
EXPENSE_ROUTE_CONTENT="$(file_at_ref "$EXPENSE_ROUTE")"
LEAVE_ROUTE_CONTENT="$(file_at_ref "$LEAVE_ROUTE")"
UI_COMPONENT_CONTENT="$(file_at_ref "$UI_COMPONENT")"
DATA_INDEX_CONTENT="$(file_at_ref "$DATA_INDEX")"

echo "Checking ${REF}: PR10.10 approval policy binding readiness ..."

for file in "$SMOKE" "$HELPER" "$HELPER_TEST" "$EXPENSE_ADAPTER" "$LEAVE_ADAPTER" \
  "$EXPENSE_ROUTE" "$LEAVE_ROUTE" "$UI_COMPONENT" "$DATA_INDEX"; do
  if [[ ! -f "$file" ]]; then
    echo "FAIL: missing required file: $file"
    exit 1
  fi
done

MIGRATION_CHANGES="$(git diff --name-only --diff-filter=A origin/main...HEAD -- supabase/migrations/ 2>/dev/null || true)"
if [[ -n "$(echo "$MIGRATION_CHANGES" | sed '/^$/d')" ]]; then
  echo "FAIL: PR10.10 must not add migrations:"
  echo "$MIGRATION_CHANGES" | sed '/^$/d'
  exit 1
fi

helper_needles=(
  "export type ApprovalPolicyBindingStatus"
  "'policy_unavailable'"
  "computeApprovalPolicyBindingStatus"
  "buildApprovalPolicyBindingInfo"
  "parseApprovalPolicyJoin"
)

for needle in "${helper_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$HELPER_CONTENT"; then
    echo "FAIL: helper missing required fragment: $needle"
    exit 1
  fi
done

status_needles=(
  "'ready'"
  "'unbound'"
  "'policy_unavailable'"
  "'inactive_policy'"
  "'missing_required_steps'"
  "'module_mismatch'"
)

for needle in "${status_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$HELPER_CONTENT"; then
    echo "FAIL: helper missing status: $needle"
    exit 1
  fi
done

if ! grep -Fq "policy_unavailable" <<< "$HELPER_TEST_CONTENT"; then
  echo "FAIL: mapper tests must cover policy_unavailable"
  exit 1
fi

for adapter_content in "$EXPENSE_ADAPTER_CONTENT" "$LEAVE_ADAPTER_CONTENT"; do
  if ! grep -Fq "approvalPolicy:" <<< "$adapter_content"; then
    echo "FAIL: adapter must expose approvalPolicy"
    exit 1
  fi
  if ! grep -Fq "approval_policies ( name, module, is_active )" <<< "$adapter_content"; then
    echo "FAIL: adapter must join approval policy metadata"
    exit 1
  fi
  if ! grep -Fq ".eq('tenant_id', ctx.tenantId)" <<< "$adapter_content"; then
    echo "FAIL: adapter must keep tenant guard on step query"
    exit 1
  fi
  if ! grep -Fq "buildApprovalPolicyBindingInfo" <<< "$adapter_content"; then
    echo "FAIL: adapter must use buildApprovalPolicyBindingInfo"
    exit 1
  fi
done

if ! grep -Fq "expectedModule: 'expense'" <<< "$EXPENSE_ADAPTER_CONTENT"; then
  echo "FAIL: expense adapter must use expectedModule expense"
  exit 1
fi

if ! grep -Fq "expectedModule: 'leave'" <<< "$LEAVE_ADAPTER_CONTENT"; then
  echo "FAIL: leave adapter must use expectedModule leave"
  exit 1
fi

if ! grep -Fq "ApprovalPolicyBindingSection" <<< "$EXPENSE_ROUTE_CONTENT"; then
  echo "FAIL: masraf-kategorileri must render ApprovalPolicyBindingSection"
  exit 1
fi

if ! grep -Fq "ApprovalPolicyBindingSection" <<< "$LEAVE_ROUTE_CONTENT"; then
  echo "FAIL: izin-tanimlari must render ApprovalPolicyBindingSection"
  exit 1
fi

if grep -Fq "policyBound" <<< "$EXPENSE_ROUTE_CONTENT"; then
  echo "FAIL: masraf-kategorileri must not use deprecated policyBound banner"
  exit 1
fi

if ! grep -Fq "approvalPolicyBinding" <<< "$UI_COMPONENT_CONTENT"; then
  echo "FAIL: UI component must use approvalPolicyBinding i18n"
  exit 1
fi

if ! grep -Fq "policy-binding-readiness" <<< "$DATA_INDEX_CONTENT"; then
  echo "FAIL: data index must export policy-binding-readiness helpers"
  exit 1
fi

smoke_needles=(
  "BEGIN;"
  "ROLLBACK;"
  "demo_policy_binding_"
  "SMOKE_FAIL expense ready"
  "SMOKE_FAIL expense unbound"
  "SMOKE_FAIL expense inactive_policy"
  "SMOKE_FAIL expense missing_required_steps"
  "SMOKE_FAIL expense module_mismatch"
  "SMOKE_FAIL leave ready"
  "SMOKE_FAIL leave unbound"
  "policy_unavailable"
  "s.tenant_id = ec.tenant_id"
  "s.is_required = TRUE"
)

for needle in "${smoke_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$SMOKE_CONTENT"; then
    echo "FAIL: smoke missing required fragment: $needle"
    exit 1
  fi
done

for key in ready unbound policy_unavailable inactive_policy missing_required_steps module_mismatch; do
  if ! grep -Fq "\"$key\"" "$I18N_TR" || ! grep -Fq "\"$key\"" "$I18N_EN"; then
    echo "FAIL: missing i18n key approvalPolicyBinding.status.$key"
    exit 1
  fi
done

for key in title empty; do
  if ! grep -Fq "\"$key\"" "$I18N_TR" || ! grep -Fq "\"$key\"" "$I18N_EN"; then
    echo "FAIL: missing i18n key approvalPolicyBinding.$key"
    exit 1
  fi
done

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
  scan_forbidden_in_src '\.from\('"'"'approval_policies'"'"'\).*\.(insert|update|upsert|delete)\(' 'approval-policy-mutations'
fi

echo "OK: PR10.10 approval policy binding readiness checks passed for ${REF}"
