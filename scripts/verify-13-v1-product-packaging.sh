#!/usr/bin/env bash
# Verifies PR13.0 V1 product packaging strategy (documentation-only PR).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
API_README="docs/api/README.md"
VERIFY_SCRIPT="scripts/verify-13-v1-product-packaging.sh"

PRODUCT_DOCS=(
  "docs/product/13_v1_product_packaging_strategy.md"
  "docs/product/13_v1_feature_traceability_matrix.md"
  "docs/product/13_demo_data_packaging_principles.md"
  "docs/product/13_ai_coach_process_touchpoints.md"
  "docs/product/13_canias_first_integration_boundary.md"
)

file_at_ref() {
  local path="$1"
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

echo "Checking ${REF}: PR13.0 V1 product packaging strategy ..."

REQUIRED_FILES=("${PRODUCT_DOCS[@]}" "$API_README" "$VERIFY_SCRIPT")

for file in "${REQUIRED_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "FAIL: missing required file: $file"
    exit 1
  fi
done

COMBINED_DOCS=""
for doc in "${PRODUCT_DOCS[@]}"; do
  COMBINED_DOCS+="$(file_at_ref "$doc")"
done

doc_needles=(
  "Production-facing product behavior must not depend on embedded TypeScript business fixtures"
  "DB-backed demo tenant"
  "CSV"
  "AI Coach"
  "Canias"
  "no automatic destructive ERP writes"
  "full bidirectional sync"
  "real-time sync"
  "public API"
  "SDK/client generation"
  "CRM integration"
  "source-aware"
  "required seeded"
  "20-40 employees"
  "PR13.7"
)

for needle in "${doc_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$COMBINED_DOCS"; then
    echo "FAIL: product docs missing needle: $needle"
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
    echo "FAIL: traceability matrix missing feature needle: $needle"
    exit 1
  fi
done

# --- Docs-only diff guard (case glob — not exact array wildcard) ---
CHANGED_FILES=()
while IFS= read -r file; do
  [[ -n "$file" ]] && CHANGED_FILES+=("$file")
done < <(git diff --name-only origin/main...HEAD 2>/dev/null || true)

if ((${#CHANGED_FILES[@]} > 0)); then
  for file in "${CHANGED_FILES[@]}"; do
    case "$file" in
      docs/product/13_*.md|docs/product/README.md|scripts/verify-13-v1-product-packaging.sh)
        ;;
      src/*|supabase/*|docs/api/openapi.yaml|.env*|.env.example|package.json|openapi.json|swagger.json)
        echo "FAIL: forbidden changed path: $file"
        exit 1
        ;;
      *)
        echo "FAIL: PR13.0 must not change: $file"
        exit 1
        ;;
    esac
  done
fi

chmod +x "$0" 2>/dev/null || true

echo "OK: PR13.0 V1 product packaging strategy checks passed for ${REF}"
