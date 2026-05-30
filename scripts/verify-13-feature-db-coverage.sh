#!/usr/bin/env bash
# Verifies PR13.1 feature + DB coverage inventory (documentation-only PR).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
VERIFY_SCRIPT="scripts/verify-13-feature-db-coverage.sh"

INVENTORY_DOCS=(
  "docs/product/13_feature_db_coverage_inventory.md"
  "docs/product/13_db_table_completeness_classes.md"
  "docs/product/13_embedded_demo_dependency_map.md"
  "docs/product/13_ai_context_data_requirements.md"
)

file_at_ref() {
  local path="$1"
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

echo "Checking ${REF}: PR13.1 feature DB coverage inventory ..."

REQUIRED_FILES=(
  "${INVENTORY_DOCS[@]}"
  "docs/product/README.md"
  "$VERIFY_SCRIPT"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "FAIL: missing required file: $file"
    exit 1
  fi
done

COMBINED_DOCS=""
for doc in "${INVENTORY_DOCS[@]}"; do
  COMBINED_DOCS+="$(file_at_ref "$doc")"
done

doc_needles=(
  "required seeded"
  "required scenario-generated"
  "readable empty-ok"
  "future/not V1"
  "sensitive/system"
  "puls_core.employees"
  "puls_core.departments"
  "puls_core.positions"
  "puls_workflow.leave_types"
  "puls_workflow.expense_categories"
  "puls_workflow.approval_requests"
  "puls_performance.performance_cycles"
  "puls_integration.erp_connections"
  "puls_calc"
  "fetchDemo"
  "puls-demo-data.ts"
  "P0_retire_for_packaging"
  "Embedded TypeScript demo data may remain temporarily as a dev fallback, but it cannot be used as V1 packaging proof."
  "DB-backed"
  "AI Coach"
  "human-in-the-loop"
  "Canias"
)

for needle in "${doc_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$COMBINED_DOCS"; then
    echo "FAIL: PR13.1 inventory docs missing needle: $needle"
    exit 1
  fi
done

feature_needles=(
  "Dashboard"
  "Company setup"
  "Employee directory"
  "Departments"
  "Positions"
  "Leave setup"
  "Leave request"
  "Expense categories"
  "Expense claim"
  "Performance overview"
  "Performance cycles"
  "Performance parameters"
  "Career"
  "Training"
  "Job evaluation"
  "Contracts metadata"
  "Profile"
  "Settings"
  "ERP setup"
  "Menu"
  "shell navigation"
  "AI Coach"
)

for needle in "${feature_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$COMBINED_DOCS"; then
    echo "FAIL: inventory docs missing feature needle: $needle"
    exit 1
  fi
done

# --- Docs-only diff guard (case glob) ---
CHANGED_FILES=()
while IFS= read -r file; do
  [[ -n "$file" ]] && CHANGED_FILES+=("$file")
done < <(git diff --name-only origin/main...HEAD 2>/dev/null || true)

if ((${#CHANGED_FILES[@]} > 0)); then
  for file in "${CHANGED_FILES[@]}"; do
    case "$file" in
      docs/product/13_*.md|docs/product/README.md|scripts/verify-13-feature-db-coverage.sh)
        ;;
      src/*|supabase/*|docs/api/openapi.yaml|.env*|.env.example|package.json|openapi.json|swagger.json)
        echo "FAIL: forbidden changed path: $file"
        exit 1
        ;;
      *)
        echo "FAIL: PR13.1 must not change: $file"
        exit 1
        ;;
    esac
  done
fi

chmod +x "$0" 2>/dev/null || true

echo "OK: PR13.1 feature DB coverage inventory checks passed for ${REF}"
