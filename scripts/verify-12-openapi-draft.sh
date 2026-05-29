#!/usr/bin/env bash
# Verifies PR12.1 OpenAPI draft + PR12.2 contract validation + PR12.3 mutation smokes (documentation-only PR).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
OPENAPI="docs/api/openapi.yaml"
API_README="docs/api/README.md"
DATA_README="docs/data/README.md"
ALLOWLIST="docs/api/openapi-contract-allowlist.json"
VALIDATION_DOC="docs/api/openapi-validation.md"
VALIDATOR="scripts/validate-openapi-contract.mjs"

file_at_ref() {
  local path="$1"
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

OPENAPI_CONTENT="$(file_at_ref "$OPENAPI")"

echo "Checking ${REF}: PR12.1 OpenAPI draft + PR12.2 contract validation + PR12.3 mutation smokes ..."

if [[ ! -f "$OPENAPI" ]]; then
  echo "FAIL: missing required file: $OPENAPI"
  exit 1
fi

if [[ ! -f "scripts/verify-12-openapi-draft.sh" ]]; then
  echo "FAIL: missing required file: scripts/verify-12-openapi-draft.sh"
  exit 1
fi

if [[ ! -f "$VALIDATOR" ]]; then
  echo "FAIL: missing required file: $VALIDATOR"
  exit 1
fi

if [[ ! -f "$ALLOWLIST" ]]; then
  echo "FAIL: missing required file: $ALLOWLIST"
  exit 1
fi

if [[ ! -f "$VALIDATION_DOC" ]]; then
  echo "FAIL: missing required file: $VALIDATION_DOC"
  exit 1
fi

# --- Structural YAML parse (no yaml dependency) ---
node -e "
const fs = require('fs');
const s = fs.readFileSync('docs/api/openapi.yaml', 'utf8');
for (const n of ['openapi: 3.1.0', 'PULS App API Boundary', 'paths:', 'components:']) {
  if (!s.includes(n)) process.exit(1);
}
"

top_level_needles=(
  "x-puls-source-inventory"
  "x-puls-public-http: false"
  "x-puls-current-transport: supabase-js"
  "SupabaseJwt"
  "x-puls-read-models"
  "x-puls-internal-backend-surfaces"
  "x-puls-not-exposed"
)

for needle in "${top_level_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$OPENAPI_CONTENT"; then
    echo "FAIL: openapi missing top-level needle: $needle"
    exit 1
  fi
done

# --- 17 operationIds — anchored count only ---
operation_ids=(
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

for op_id in "${operation_ids[@]}"; do
  count="$(grep -Ec "^[[:space:]]+operationId:[[:space:]]+${op_id}$" "$OPENAPI")"
  if [[ "$count" -ne 1 ]]; then
    echo "FAIL: operationId ${op_id} must appear exactly once under paths (found ${count})"
    exit 1
  fi

  block="$(awk "/operationId: ${op_id}/{flag=1} flag{print} flag && /^      responses:/{exit}" "$OPENAPI")"
  if ! grep -Fq "security:" <<< "$block"; then
    echo "FAIL: operation ${op_id} missing operation-level security"
    exit 1
  fi
  if ! grep -Fq "SupabaseJwt: []" <<< "$block"; then
    echo "FAIL: operation ${op_id} missing SupabaseJwt security requirement"
    exit 1
  fi
done

operation_security_count="$(grep -Ec "^      security:$" "$OPENAPI")"
if [[ "$operation_security_count" -ne 17 ]]; then
  echo "FAIL: expected 17 operation-level security blocks (found ${operation_security_count})"
  exit 1
fi

# --- Path parameter needles under paths: ---
paths_section="$(awk '/^paths:/{flag=1;next} /^components:/{flag=0} flag' "$OPENAPI")"

path_param_needles=(
  "name: categoryId"
  "name: leaveTypeId"
  "name: departmentId"
  "name: positionId"
  "name: cycleId"
)

for needle in "${path_param_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$paths_section"; then
    echo "FAIL: paths section missing path parameter: $needle"
    exit 1
  fi
done

# --- Performance cycle field map ---
if ! grep -Fq "x-puls-adapter-field-map" <<< "$OPENAPI_CONTENT"; then
  echo "FAIL: missing x-puls-adapter-field-map"
  exit 1
fi

if ! grep -Fq "startsAt: starts_at" <<< "$OPENAPI_CONTENT"; then
  echo "FAIL: missing startsAt: starts_at field map"
  exit 1
fi

if ! grep -Fq "endsAt: ends_at" <<< "$OPENAPI_CONTENT"; then
  echo "FAIL: missing endsAt: ends_at field map"
  exit 1
fi

# --- Required schema names in components/schemas ---
schema_needles=(
  "CreateExpenseClaimRequest:"
  "CreateExpenseClaimResponse:"
  "CreateLeaveRequestRequest:"
  "CreateLeaveRequestResponse:"
  "DecideApprovalRequestRequest:"
  "DecideApprovalRequestResponse:"
  "ExpenseCategoryMutationRequest:"
  "ExpenseCategoryLifecycleRequest:"
  "ExpenseCategoryLifecycleResponse:"
  "LeaveTypeMutationRequest:"
  "LeaveTypeLifecycleRequest:"
  "LeaveTypeLifecycleResponse:"
  "DepartmentMutationRequest:"
  "PositionMutationRequest:"
  "PerformanceCycleMutationRequest:"
  "PerformanceCycleMutationResponse:"
  "MutationAcceptedResponse:"
  "DataAdapterError:"
  "ErrorResponse:"
)

for needle in "${schema_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$OPENAPI_CONTENT"; then
    echo "FAIL: components/schemas missing: $needle"
    exit 1
  fi
done

# restoreExpenseCategory / restoreLeaveType must not require request schemas (no requestBody)
restore_ops=(
  restoreExpenseCategory
  restoreLeaveType
)

for op_id in "${restore_ops[@]}"; do
  block="$(awk "/operationId: ${op_id}/{flag=1} flag{print} flag && /^[[:space:]]+responses:/{exit}" "$OPENAPI")"
  if grep -Fq "requestBody:" <<< "$block"; then
    echo "FAIL: ${op_id} must omit requestBody"
    exit 1
  fi
done

# --- Backend qualified names ---
backend_needles=(
  "puls_workflow.create_expense_claim"
  "puls_workflow.create_leave_request"
  "puls_workflow.decide_approval_request"
  "puls_workflow.deactivate_expense_category"
  "puls_workflow.restore_expense_category"
  "puls_workflow.deactivate_leave_type"
  "puls_workflow.restore_leave_type"
  "puls_workflow.expense_categories"
  "puls_workflow.leave_types"
  "puls_core.departments"
  "puls_core.positions"
  "puls_performance.performance_cycles"
)

for needle in "${backend_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$OPENAPI_CONTENT"; then
    echo "FAIL: openapi missing backend needle: $needle"
    exit 1
  fi
done

# --- Forbidden fields in *Request component blocks only ---
schemas_section="$(awk '/^  schemas:/{flag=1;next} /^x-puls-read-models:/{flag=0} flag' "$OPENAPI")"

forbidden_fields=(
  tenant_id
  tenantId
  is_active
  isActive
  external_source
  externalSource
  created_at
  createdAt
  updated_at
  updatedAt
)

request_blocks="$(awk '
  /^    [A-Za-z0-9]+Request:$/ { block=$0; in_block=1; next }
  in_block && /^    [A-Za-z]/ && block != "" { in_block=0; block="" }
  in_block { print }
' <<< "$schemas_section")"

for field in "${forbidden_fields[@]}"; do
  if grep -Fq "$field" <<< "$request_blocks"; then
    echo "FAIL: forbidden field in *Request schema: $field"
    exit 1
  fi
done

# --- Internal-only path guard ---
internal_path_needles=(
  "puls_integration.apply_import_batch"
  "resolve_approver"
  "resolve_policy_step_approver"
  "supabase.functions.invoke"
)

for needle in "${internal_path_needles[@]}"; do
  if grep -Fq "$needle" <<< "$paths_section"; then
    echo "FAIL: internal surface must not appear under paths: $needle"
    exit 1
  fi
done

# --- PR12.2 semantic contract validation ---
node "$VALIDATOR"

# --- Docs-only diff guard ---
CHANGED_FILES=()
while IFS= read -r file; do
  [[ -n "$file" ]] && CHANGED_FILES+=("$file")
done < <(git diff --name-only origin/main...HEAD 2>/dev/null || true)

ALLOWED=(
  "$OPENAPI"
  "scripts/verify-12-openapi-draft.sh"
  "$VALIDATOR"
  "$ALLOWLIST"
  "$VALIDATION_DOC"
  "$API_README"
  "$DATA_README"
  "docs/api/12_mutation_contract_smoke_hardening.md"
  "docs/data/12_decide_approval_contract_smoke.sql"
  "docs/data/12_performance_cycle_contract_smoke.sql"
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
      echo "FAIL: PR12.1/PR12.2/PR12.3 must not change implementation files: $file"
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

echo "OK: PR12.1 OpenAPI draft + PR12.2 contract validation + PR12.3 mutation smokes checks passed for ${REF}"
