#!/usr/bin/env bash
# Verifies 12 PR12.3 mutation contract smoke hardening (docs/SQL smoke only).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
DECIDE_SMOKE="docs/data/12_decide_approval_contract_smoke.sql"
PERF_SMOKE="docs/data/12_performance_cycle_contract_smoke.sql"
COVERAGE_DOC="docs/api/12_mutation_contract_smoke_hardening.md"
OPENAPI="docs/api/openapi.yaml"
ALLOWLIST="docs/api/openapi-contract-allowlist.json"
VALIDATOR="scripts/validate-openapi-contract.mjs"

file_at_ref() {
  local path="$1"
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

echo "Checking ${REF}: PR12.3 mutation contract smoke hardening ..."

REQUIRED_FILES=(
  "$DECIDE_SMOKE"
  "$PERF_SMOKE"
  "$COVERAGE_DOC"
  "$OPENAPI"
  "$ALLOWLIST"
  "$VALIDATOR"
  "scripts/verify-12-mutation-contract-smoke.sh"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "FAIL: missing required file: $file"
    exit 1
  fi
done

DECIDE_CONTENT="$(file_at_ref "$DECIDE_SMOKE")"
PERF_CONTENT="$(file_at_ref "$PERF_SMOKE")"
OPENAPI_CONTENT="$(file_at_ref "$OPENAPI")"
ALLOWLIST_CONTENT="$(file_at_ref "$ALLOWLIST")"

smoke_needles=(
  "BEGIN;"
  "ROLLBACK;"
  "demo_decide_approval_contract_"
  "demo_performance_cycle_contract_"
  "request.jwt.claim.sub"
  "puls_core.current_employee_id()"
  "puls_core.current_tenant_id()"
  "puls_workflow.decide_approval_request"
  "puls_performance.performance_cycles"
)

for needle in "${smoke_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$DECIDE_CONTENT$PERF_CONTENT"; then
    echo "FAIL: smoke files missing needle: $needle"
    exit 1
  fi
done

if grep -Fq "INSERT INTO puls_workflow.approval_requests" <<< "$DECIDE_CONTENT"; then
  echo "FAIL: decide smoke must not INSERT INTO puls_workflow.approval_requests"
  exit 1
fi

if grep -Fq "UPDATE puls_workflow.approval_requests" <<< "$DECIDE_CONTENT"; then
  echo "FAIL: decide smoke must not UPDATE puls_workflow.approval_requests"
  exit 1
fi

if ! grep -Fq "create_leave_request" <<< "$DECIDE_CONTENT"; then
  echo "FAIL: decide smoke should allow create_leave_request rollback chain"
  exit 1
fi

if ! grep -Fq "SKIP: decide success path" <<< "$DECIDE_CONTENT"; then
  echo "FAIL: decide smoke must document success-path SKIP when fixture absent"
  exit 1
fi

openapi_needles=(
  "x-puls-coverage: contract_smoke"
  "x-puls-coverage-doc: docs/data/12_performance_cycle_contract_smoke.sql"
  "x-puls-coverage: partial"
  "pending approver fixture"
)

for needle in "${openapi_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$OPENAPI_CONTENT"; then
    echo "FAIL: openapi missing needle: $needle"
    exit 1
  fi
done

if grep -Fq '"decideApprovalRequest"' <<< "$ALLOWLIST_CONTENT" && \
   grep -A20 '"partialCoverageOperationIds"' <<< "$ALLOWLIST_CONTENT" | grep -Fq '"decideApprovalRequest"'; then
  if ! grep -Fq 'operationId: decideApprovalRequest' <<< "$OPENAPI_CONTENT"; then
    echo "FAIL: decideApprovalRequest missing from openapi"
    exit 1
  fi
  if ! grep -Fq "x-puls-coverage: partial" <<< "$OPENAPI_CONTENT"; then
    echo "FAIL: decideApprovalRequest must remain partial in openapi when in partialCoverageOperationIds"
    exit 1
  fi
fi

if grep -Fq '"createPerformanceCycle"' <<< "$ALLOWLIST_CONTENT" && \
   grep -A10 '"contractSmokeOperationIds"' <<< "$ALLOWLIST_CONTENT" | grep -Fq '"createPerformanceCycle"'; then
  if ! grep -Fq "x-puls-coverage-doc: docs/data/12_performance_cycle_contract_smoke.sql" <<< "$OPENAPI_CONTENT"; then
    echo "FAIL: performance contract smoke doc missing from openapi"
    exit 1
  fi
fi

node "$VALIDATOR"

# --- Docs-only diff guard ---
CHANGED_FILES=()
while IFS= read -r file; do
  [[ -n "$file" ]] && CHANGED_FILES+=("$file")
done < <(git diff --name-only origin/main...HEAD 2>/dev/null || true)

ALLOWED=(
  "$DECIDE_SMOKE"
  "$PERF_SMOKE"
  "$COVERAGE_DOC"
  "$OPENAPI"
  "$ALLOWLIST"
  "docs/api/openapi-validation.md"
  "docs/api/README.md"
  "docs/data/README.md"
  "$VALIDATOR"
  "scripts/verify-12-mutation-contract-smoke.sh"
)

is_allowed() {
  local candidate="$1"
  for allowed in "${ALLOWED[@]}"; do
    if [[ "$candidate" == "$allowed" ]]; then
      return 0
    fi
  done
  return 1
}

FORBIDDEN_EXACT=(
  "openapi.json"
  "swagger.json"
  "package.json"
)

if ((${#CHANGED_FILES[@]} > 0)); then
  for file in "${CHANGED_FILES[@]}"; do
    if ! is_allowed "$file"; then
      echo "FAIL: PR12.3 must not change implementation files: $file"
      exit 1
    fi

    for forbidden in "${FORBIDDEN_EXACT[@]}"; do
      if [[ "$file" == "$forbidden" ]]; then
        echo "FAIL: forbidden changed file: $file"
        exit 1
      fi
    done

    case "$file" in
      src/*|supabase/migrations/*|supabase/functions/*|.env*|.env.example)
        echo "FAIL: forbidden changed path: $file"
        exit 1
        ;;
    esac
  done
fi

chmod +x "$0" 2>/dev/null || true

echo "OK: PR12.3 mutation contract smoke hardening checks passed for ${REF}"
