#!/usr/bin/env bash
# Verifies PR12.4 contract examples and error catalog (documentation-only PR).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
EXAMPLES="docs/api/openapi-examples.yaml"
ERROR_CATALOG="docs/api/puls-error-catalog.md"
OPENAPI="docs/api/openapi.yaml"
ALLOWLIST="docs/api/openapi-contract-allowlist.json"
VALIDATOR="scripts/validate-openapi-contract.mjs"

file_at_ref() {
  local path="$1"
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

echo "Checking ${REF}: PR12.4 contract examples and error catalog ..."

REQUIRED_FILES=(
  "$EXAMPLES"
  "$ERROR_CATALOG"
  "$OPENAPI"
  "$ALLOWLIST"
  "$VALIDATOR"
  "scripts/verify-12-contract-examples-errors.sh"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "FAIL: missing required file: $file"
    exit 1
  fi
done

EXAMPLES_CONTENT="$(file_at_ref "$EXAMPLES")"
CATALOG_CONTENT="$(file_at_ref "$ERROR_CATALOG")"
OPENAPI_CONTENT="$(file_at_ref "$OPENAPI")"
ALLOWLIST_CONTENT="$(file_at_ref "$ALLOWLIST")"

OPERATION_IDS=(
  createExpenseClaim
  createLeaveRequest
  decideApprovalRequest
  createExpenseCategory
  updateExpenseCategory
  deactivateExpenseCategory
  restoreExpenseCategory
  createLeaveType
  updateLeaveType
  deactivateLeaveType
  restoreLeaveType
  createDepartment
  updateDepartment
  createPosition
  updatePosition
  createPerformanceCycle
  updatePerformanceCycle
)

for op in "${OPERATION_IDS[@]}"; do
  if ! grep -Fq "$op:" <<< "$EXAMPLES_CONTENT"; then
    echo "FAIL: examples missing operation: $op"
    exit 1
  fi
done

catalog_needles=(
  "PULS_"
  "invalid_rpc_result"
  "fromRpcError"
  "fromSupabaseError"
)

for needle in "${catalog_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$CATALOG_CONTENT"; then
    echo "FAIL: error catalog missing needle: $needle"
    exit 1
  fi
done

openapi_needles=(
  "x-puls-public-http: false"
  "x-puls-examples-doc: docs/api/openapi-examples.yaml"
  "x-puls-error-catalog: docs/api/puls-error-catalog.md"
)

for needle in "${openapi_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$OPENAPI_CONTENT"; then
    echo "FAIL: openapi missing needle: $needle"
    exit 1
  fi
done

examples_needles=(
  "x-puls-public-http: false"
  "x-puls-current-transport: supabase-js"
  "operations:"
  "request: null"
  "ok: true"
)

for needle in "${examples_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$EXAMPLES_CONTENT"; then
    echo "FAIL: examples missing needle: $needle"
    exit 1
  fi
done

if ! grep -Fq '"knownErrorCodes"' <<< "$ALLOWLIST_CONTENT"; then
  echo "FAIL: allowlist missing knownErrorCodes"
  exit 1
fi

for forbidden in tenant_id tenantId is_active isActive external_source created_at updated_at; do
  if grep -Fq "$forbidden:" <<< "$EXAMPLES_CONTENT"; then
    echo "FAIL: examples must not contain forbidden request field: $forbidden"
    exit 1
  fi
done

if grep -Fq 'https://api.' <<< "$EXAMPLES_CONTENT$CATALOG_CONTENT"; then
  echo "FAIL: examples/catalog must not imply live public REST API URLs"
  exit 1
fi

node "$VALIDATOR"

# --- Docs-only diff guard ---
CHANGED_FILES=()
while IFS= read -r file; do
  [[ -n "$file" ]] && CHANGED_FILES+=("$file")
done < <(git diff --name-only origin/main...HEAD 2>/dev/null || true)

ALLOWED=(
  "$EXAMPLES"
  "$ERROR_CATALOG"
  "$OPENAPI"
  "$ALLOWLIST"
  "docs/api/openapi-validation.md"
  "docs/api/README.md"
  "docs/data/README.md"
  "docs/api/12_mutation_contract_smoke_hardening.md"
  "docs/data/12_decide_approval_contract_smoke.sql"
  "docs/data/12_performance_cycle_contract_smoke.sql"
  "$VALIDATOR"
  "scripts/verify-12-contract-examples-errors.sh"
  "scripts/verify-12-openapi-draft.sh"
  "scripts/verify-12-mutation-contract-smoke.sh"
  "docs/api/api-contract-consumer-guide.md"
  "docs/api/pr12-release-checklist.md"
  "scripts/verify-12-api-contract-release-pack.sh"
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
      echo "FAIL: PR12.4 must not change implementation files: $file"
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

echo "OK: PR12.4 contract examples and error catalog checks passed for ${REF}"
