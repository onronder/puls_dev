#!/usr/bin/env bash
# Verifies PR13.3A data dictionary seed alignment (documentation-only PR).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
VERIFY_SCRIPT="scripts/verify-13-data-dictionary-alignment.sh"
WORKBOOK="docs/V1 Dokümanlar/Puls_Veri_Sozlugu_v1.0.xlsx"

PR133A_DOCS=(
  "docs/product/13_data_dictionary_seed_alignment.md"
  "docs/product/13_data_dictionary_architecture_notes.md"
)

PR133A_JSON="docs/product/13_data_dictionary_seed_crosswalk.json"

PR133_REFERENCE_DOCS=(
  "docs/product/13_synthetic_company_seed_spec.md"
  "docs/product/13_seed_table_coverage_manifest.md"
)

file_at_ref() {
  local path="$1"
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

echo "Checking ${REF}: PR13.3A data dictionary seed alignment ..."

REQUIRED_FILES=(
  "$WORKBOOK"
  "${PR133A_DOCS[@]}"
  "$PR133A_JSON"
  "${PR133_REFERENCE_DOCS[@]}"
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
for doc in "${PR133A_DOCS[@]}"; do
  COMBINED_DOCS+="$(file_at_ref "$doc")"
done
COMBINED_DOCS+="$(file_at_ref "$PR133A_JSON")"

doc_needles=(
  "Puls_Veri_Sozlugu_v1.0.xlsx"
  "Puls Sanayi A.Ş."
  "Production-facing product behavior must not depend on embedded TypeScript business fixtures"
  "Data dictionary microservice labels are future service-boundary hints, not MVP deployment requirements."
  "PR13.4 seed artifacts must follow the data dictionary alignment crosswalk."
  "Supabase/Postgres + RLS/RPC/views + src/lib/data adapters"
  "future_service_boundary"
  "physicalMicroservicesInMvp"
  "covered_by_seed"
  "derived_calc"
  "scenario_generated"
  "future_not_v1"
  "sensitive_system"
  "configuration_static"
  "not_current_route"
  "needs_mapping_review"
  "identity-svc"
  "kpi-svc"
  "training-svc"
  "career-svc"
  "erp-connector"
  "llm-gateway"
  "bounded context"
  "not physical microservices"
  "Canias connector"
  "AI Coach"
  "494"
  "21"
)

for needle in "${doc_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$COMBINED_DOCS"; then
    echo "FAIL: PR13.3A docs/json missing needle: $needle"
    exit 1
  fi
done

domain_needles=(
  "Ortak Alanlar"
  "KPI Hedefleri"
  "Performans"
  "Eğitim Analizi"
  "Kariyer Haritası"
  "İş Değerleme"
  "Görev Tanımı"
  "İş Tanımı"
  "İş Analizi"
  "Tatil"
  "Cüzdan"
  "Belge"
  "Koç"
  "Şirket Kurulum"
  "Departmanlar"
  "Pozisyonlar"
  "Çalışanlar"
  "İzin Tipleri"
  "Masraf Kategorileri"
  "Performans Param"
  "ERP Entegrasyon"
)

for needle in "${domain_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$COMBINED_DOCS"; then
    echo "FAIL: PR13.3A docs/json missing domain needle: $needle"
    exit 1
  fi
done

# --- Docs-only diff guard (narrow allowlist) ---
CHANGED_FILES=()
while IFS= read -r file; do
  [[ -n "$file" ]] && CHANGED_FILES+=("$file")
done < <(git diff --name-only origin/main...HEAD 2>/dev/null || true)

if ((${#CHANGED_FILES[@]} > 0)); then
  for file in "${CHANGED_FILES[@]}"; do
    case "$file" in
      docs/product/13_data_dictionary_seed_alignment.md|docs/product/13_data_dictionary_seed_crosswalk.json|docs/product/13_data_dictionary_architecture_notes.md|docs/product/README.md|scripts/verify-13-data-dictionary-alignment.sh)
        ;;
      *.csv|*.sql)
        echo "FAIL: forbidden changed path: $file"
        exit 1
        ;;
      src/*|supabase/*|supabase/seed/*|docs/api/openapi.yaml|.env*|.env.example|package.json|openapi.json|swagger.json)
        echo "FAIL: forbidden changed path: $file"
        exit 1
        ;;
      *)
        echo "FAIL: PR13.3A must not change: $file"
        exit 1
        ;;
    esac
  done
fi

chmod +x "$0" 2>/dev/null || true

echo "OK: PR13.3A data dictionary seed alignment checks passed for ${REF}"
