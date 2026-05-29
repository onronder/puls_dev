#!/usr/bin/env bash
# Verifies 12 PR12.0 app-wide API boundary inventory (documentation-only PR).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
INVENTORY="docs/data/12_app_api_boundary_inventory.md"
README="docs/data/README.md"

file_at_ref() {
  local path="$1"
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

INVENTORY_CONTENT="$(file_at_ref "$INVENTORY")"

echo "Checking ${REF}: PR12.0 app-wide API boundary inventory ..."

if [[ ! -f "$INVENTORY" ]]; then
  echo "FAIL: missing required file: $INVENTORY"
  exit 1
fi

if [[ ! -f "scripts/verify-12-app-api-boundary-inventory.sh" ]]; then
  echo "FAIL: missing required file: scripts/verify-12-app-api-boundary-inventory.sh"
  exit 1
fi

section_needles=(
  "Executive summary"
  "Boundary taxonomy"
  "App-exposed mutation catalog"
  "RPC contract details"
  "Direct table-write contract details"
  "App read-model inventory"
  "Internal backend-only inventory"
  "Not app-exposed"
  "Auth/RLS/security model"
  "Error contract inventory"
  "Smoke and test coverage matrix"
  "OpenAPI inclusion map"
  "PR12 follow-up map"
  "Verification notes"
)

for needle in "${section_needles[@]}"; do
  if ! grep -Fiq "$needle" <<< "$INVENTORY_CONTENT"; then
    echo "FAIL: inventory missing required section: $needle"
    exit 1
  fi
done

taxonomy_needles=(
  "app_exposed_mutation"
  "app_read_model"
  "internal_backend_only"
  "not_app_exposed"
  "future_candidate"
  "include_in_openapi: yes"
  "include_in_openapi: read_model_appendix"
  "include_in_openapi: internal_appendix"
  "include_in_openapi: no"
  "include_in_openapi: future"
)

for needle in "${taxonomy_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$INVENTORY_CONTENT"; then
    echo "FAIL: inventory missing taxonomy token: $needle"
    exit 1
  fi
done

adapter_needles=(
  "createExpenseClaim"
  "createLeaveRequest"
  "decideApprovalRequest"
  "deactivateExpenseCategory"
  "restoreExpenseCategory"
  "deactivateLeaveType"
  "restoreLeaveType"
  "createExpenseCategory"
  "updateExpenseCategory"
  "createLeaveType"
  "updateLeaveType"
  "createDepartment"
  "updateDepartment"
  "createPosition"
  "updatePosition"
  "createPerformanceCycle"
  "updatePerformanceCycle"
)

for needle in "${adapter_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$INVENTORY_CONTENT"; then
    echo "FAIL: inventory missing mutation adapter: $needle"
    exit 1
  fi
done

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
  "puls_integration.apply_import_batch"
  "puls_integration.validate_import_batch"
  "puls_integration.preview_import_diff"
  "puls_workflow.resolve_approver"
  "puls_workflow.resolve_policy_step_approver"
  "supabase.functions.invoke"
)

for needle in "${backend_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$INVENTORY_CONTENT"; then
    echo "FAIL: inventory missing backend needle: $needle"
    exit 1
  fi
done

route_needles=(
  "/dashboard"
  "/profil"
  "/calisanlar"
  "/sirket-kurulum"
  "/departmanlar"
  "/pozisyonlar"
  "/izin"
  "/izin-tanimlari"
  "/masraf"
  "/masraf-kategorileri"
  "/performans"
  "/kariyer"
  "/egitim"
  "/is-degerleme"
  "/sozlesmeler"
  "/erp"
  "/ayarlar"
  "/ai-koc"
  "/performans-parametreleri"
  "/menu"
)

for needle in "${route_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$INVENTORY_CONTENT"; then
    echo "FAIL: inventory missing route: $needle"
    exit 1
  fi
done

security_error_needles=(
  "auth.uid()"
  "request.jwt.claim.sub"
  "puls_core.current_employee_id()"
  "puls_core.current_tenant_id()"
  "puls_core.is_admin()"
  "PULS_"
  "23505"
  "invalid_rpc_result"
  "fromRpcError"
  "fromSupabaseError"
  "service_role"
)

for needle in "${security_error_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$INVENTORY_CONTENT"; then
    echo "FAIL: inventory missing security/error needle: $needle"
    exit 1
  fi
done

if ! grep -Fq "17" <<< "$INVENTORY_CONTENT" || ! grep -Fq "12" <<< "$INVENTORY_CONTENT"; then
  echo "FAIL: inventory must document adapter count (17) and contract group count (12)"
  exit 1
fi

if ! grep -Fiq "no generated Swagger" <<< "$INVENTORY_CONTENT"; then
  echo "FAIL: inventory must state no generated Swagger yet"
  exit 1
fi

# --- Docs-only diff guard ---
CHANGED_FILES=()
while IFS= read -r file; do
  [[ -n "$file" ]] && CHANGED_FILES+=("$file")
done < <(git diff --name-only origin/main...HEAD 2>/dev/null || true)

ALLOWED=(
  "$INVENTORY"
  "scripts/verify-12-app-api-boundary-inventory.sh"
  "$README"
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
  "openapi.yaml"
  "openapi.json"
  "swagger.json"
  "package.json"
)

if ((${#CHANGED_FILES[@]} > 0)); then
  for file in "${CHANGED_FILES[@]}"; do
    if ! is_allowed "$file"; then
      echo "FAIL: PR12.0 must not change implementation files: $file"
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

if git diff --name-only origin/main...HEAD -- "$README" 2>/dev/null | grep -q .; then
  echo "NOTE: optional docs/data/README.md updated"
fi

chmod +x "$0" 2>/dev/null || true

echo "OK: PR12.0 app-wide API boundary inventory checks passed for ${REF}"
