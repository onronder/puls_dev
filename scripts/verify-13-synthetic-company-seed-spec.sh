#!/usr/bin/env bash
# Verifies PR13.3 synthetic company seed spec (documentation-only PR).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
VERIFY_SCRIPT="scripts/verify-13-synthetic-company-seed-spec.sh"

PR133_DOCS=(
  "docs/product/13_synthetic_company_seed_spec.md"
  "docs/product/13_seed_table_coverage_manifest.md"
  "docs/product/13_seed_scenario_generation_spec.md"
  "docs/product/13_seed_ai_context_manifest.md"
)

PR132_REFERENCE_DOCS=(
  "docs/product/13_embedded_demo_retirement_plan.md"
  "docs/product/13_db_table_completeness_classes.md"
)

file_at_ref() {
  local path="$1"
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

echo "Checking ${REF}: PR13.3 synthetic company seed spec ..."

REQUIRED_FILES=(
  "${PR133_DOCS[@]}"
  "${PR132_REFERENCE_DOCS[@]}"
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
for doc in "${PR133_DOCS[@]}"; do
  COMBINED_DOCS+="$(file_at_ref "$doc")"
done

doc_needles=(
  "Production-facing product behavior must not depend on embedded TypeScript business fixtures"
  "The canonical V1 demo company is DB-backed, source-aware, resettable, and large enough to exercise real product workflows."
  "120 employees"
  "Puls Sanayi A.Ş."
  "DB-backed"
  "source-aware"
  "VITE_PULS_DEMO_MODE=false"
  "source: demo is not packaging proof"
  "required seeded"
  "required scenario-generated"
  "puls_core.employees"
  "puls_core.employee_reporting_lines"
  "puls_core.employee_cost_center_assignments"
  "puls_workflow.leave_requests"
  "puls_workflow.expense_claims"
  "puls_workflow.approval_requests"
  "puls_performance.performance_cycles"
  "puls_performance.performance_scores"
  "puls_integration.erp_connections"
  "puls_integration.entity_identity_map"
  "puls_calc.dashboard_overview"
  "puls_calc.employee_list_overview"
  "puls_calc.organization_overview"
  "puls_calc.leave_overview"
  "puls_calc.expense_overview"
  "puls_calc.performance_overview"
  "puls_calc.contracts_overview"
  "puls_calc.setup_readiness_summary"
  "puls_calc.menu_overview"
  "Canias"
  "no automatic destructive ERP writes"
  "metadata seed only"
  "no Canias runtime"
  "AI Coach"
  "human-in-the-loop"
  "PR13.4"
  "PR13.5"
  "PR13.6"
  "PR13.7"
  "pending"
  "approved"
  "rejected"
  "half-day"
  "self-approval forbidden"
  "inactive category historical label"
  "inactive leave type historical label"
  "contract risk"
  "historical legacy fixture name"
  "Mert Teknik"
)

for needle in "${doc_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$COMBINED_DOCS"; then
    echo "FAIL: PR13.3 docs missing needle: $needle"
    exit 1
  fi
done

department_needles=(
  "Genel Müdürlük"
  "İnsan Kaynakları"
  "Finans & Muhasebe"
  "Satış"
  "Pazarlama"
  "Operasyon / Üretim"
  "Satınalma"
  "Lojistik & Depo"
  "Kalite / İSG"
  "BT & Dijital"
  "Ar-Ge / Proje"
  "Müşteri Operasyonları"
)

for needle in "${department_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$COMBINED_DOCS"; then
    echo "FAIL: PR13.3 docs missing department needle: $needle"
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
      docs/product/13_*.md|docs/product/README.md|scripts/verify-13-synthetic-company-seed-spec.sh)
        ;;
      *.csv|*.sql)
        echo "FAIL: forbidden changed path: $file"
        exit 1
        ;;
      src/*|supabase/*|docs/api/openapi.yaml|.env*|.env.example|package.json|openapi.json|swagger.json)
        echo "FAIL: forbidden changed path: $file"
        exit 1
        ;;
      *)
        echo "FAIL: PR13.3 must not change: $file"
        exit 1
        ;;
    esac
  done
fi

chmod +x "$0" 2>/dev/null || true

echo "OK: PR13.3 synthetic company seed spec checks passed for ${REF}"
