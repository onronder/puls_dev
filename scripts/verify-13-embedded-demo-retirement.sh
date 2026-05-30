#!/usr/bin/env bash
# Verifies PR13.2 embedded demo retirement plan (documentation-only PR).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
VERIFY_SCRIPT="scripts/verify-13-embedded-demo-retirement.sh"

PR132_DOCS=(
  "docs/product/13_embedded_demo_retirement_plan.md"
  "docs/product/13_packaging_proof_demo_guardrails.md"
)

PR131_REFERENCE_DOCS=(
  "docs/product/13_embedded_demo_dependency_map.md"
  "docs/product/13_feature_db_coverage_inventory.md"
)

file_at_ref() {
  local path="$1"
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

echo "Checking ${REF}: PR13.2 embedded demo retirement plan ..."

REQUIRED_FILES=(
  "${PR132_DOCS[@]}"
  "${PR131_REFERENCE_DOCS[@]}"
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
for doc in "${PR132_DOCS[@]}"; do
  COMBINED_DOCS+="$(file_at_ref "$doc")"
done

doc_needles=(
  "Production-facing product behavior must not depend on embedded TypeScript business fixtures"
  "puls-demo-data.ts"
  "fetchDemo"
  "VITE_PULS_DEMO_MODE"
  "P0_retire_for_packaging"
  "P1_replace_with_db_seed"
  "P2_keep_dev_fallback_temporarily"
  "DB-backed tenant"
  "packaging proof"
  "source-aware"
  "source: demo"
  "source: demo is not packaging proof"
  "AI Coach"
  "no Canias runtime"
  "metadata seed only"
  "PR13.3"
  "PR13.4"
  "PR13.5"
  "Embedded TypeScript demo data may remain temporarily as a dev fallback, but it cannot be used as V1 packaging proof."
)

for needle in "${doc_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$COMBINED_DOCS"; then
    echo "FAIL: PR13.2 docs missing needle: $needle"
    exit 1
  fi
done

package_needles=(
  "Dashboard"
  "Leave overview"
  "Expense overview"
  "Employee directory"
  "Performance overview"
  "Career"
  "Request-creation-readiness"
  "Departments"
  "Positions"
  "Expense categories"
  "Cost center readiness"
  "Contracts"
  "Profile"
  "ERP"
  "Menu"
  "Settings"
)

for needle in "${package_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$COMBINED_DOCS"; then
    echo "FAIL: retirement plan missing package needle: $needle"
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
      docs/product/13_*.md|docs/product/README.md|scripts/verify-13-embedded-demo-retirement.sh)
        ;;
      src/*|supabase/*|docs/api/openapi.yaml|.env*|.env.example|package.json|openapi.json|swagger.json)
        echo "FAIL: forbidden changed path: $file"
        exit 1
        ;;
      *)
        echo "FAIL: PR13.2 must not change: $file"
        exit 1
        ;;
    esac
  done
fi

chmod +x "$0" 2>/dev/null || true

echo "OK: PR13.2 embedded demo retirement plan checks passed for ${REF}"
