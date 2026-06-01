#!/usr/bin/env bash
# Verifies PR13.11 role/route product QA artifacts.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
MATRIX="docs/product/13_role_route_product_qa_matrix.md"
RESULTS="docs/product/13_role_route_product_qa_results.md"
SQL="supabase/seed/puls-sanayi-v1/sql/11_validate_role_route_product_qa.sql"
VERIFY="scripts/verify-13-role-route-product-qa.sh"

file_at_ref() {
  local path="$1"
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

echo "Checking ${REF}: PR13.11 role/route product QA ..."

for path in "$MATRIX" "$RESULTS" "$SQL" "$VERIFY"; do
  if ! file_at_ref "$path" >/dev/null; then
    echo "FAIL: missing required file: $path"
    exit 1
  fi
done

MATRIX_TEXT="$(file_at_ref "$MATRIX")"
RESULTS_TEXT="$(file_at_ref "$RESULTS")"
SQL_TEXT="$(file_at_ref "$SQL")"

needles=(
  "VITE_PULS_DEMO_MODE=false"
  "Puls Teknik A.S."
  "Role Route Product QA"
  "Function checks"
  "Anonymous"
  "Employee"
  "Manager"
  "HR admin"
  "Admin"
  "Incomplete setup"
  "No visible demo source pill"
  "ERP integration should connect into a product surface"
)
for needle in "${needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$MATRIX_TEXT"; then
    echo "FAIL: matrix missing needle: $needle"
    exit 1
  fi
done

routes=(
  "/dashboard"
  "/sirket-kurulum"
  "/calisanlar"
  "/departmanlar"
  "/pozisyonlar"
  "/izin-tanimlari"
  "/izin"
  "/masraf-kategorileri"
  "/masraf"
  "/performans"
  "/performans-parametreleri"
  "/kariyer"
  "/egitim"
  "/is-degerleme"
  "/sozlesmeler"
  "/profil"
  "/ayarlar"
  "/erp"
  "/ai-koc"
  "/menu"
)
for route in "${routes[@]}"; do
  if ! grep -Fq "$route" <<< "$MATRIX_TEXT"; then
    echo "FAIL: matrix missing route: $route"
    exit 1
  fi
  if ! grep -Fq "$route" <<< "$RESULTS_TEXT"; then
    echo "FAIL: results missing route: $route"
    exit 1
  fi
done

if ! grep -Fq "PR14 ERP/runtime work is **not approved yet**" <<< "$RESULTS_TEXT" &&
   ! grep -Fq "PR14 ERP/runtime work is **approved**" <<< "$RESULTS_TEXT"; then
  echo "FAIL: results must include PR14 go/no-go statement"
  exit 1
fi

sql_needles=(
  "PR13.11 role/route product QA validation"
  "auth.users"
  "admin@puls.demo"
  "ik@puls.demo"
  "yonetici@puls.demo"
  "calisan@puls.demo"
  "source = 'demo'"
  "dashboard_overview"
  "erp_connections"
)
for needle in "${sql_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$SQL_TEXT"; then
    echo "FAIL: SQL missing needle: $needle"
    exit 1
  fi
done

if grep -Eiq '\b(INSERT|UPDATE|DELETE|TRUNCATE|ALTER|DROP|CREATE TABLE)\b' <<< "$SQL_TEXT"; then
  echo "FAIL: SQL 11 must remain read-only"
  exit 1
fi

BASE_REF="$(git merge-base "${REF}" origin/main 2>/dev/null || echo "")"
if [[ -n "$BASE_REF" && "$BASE_REF" != "$REF" ]]; then
  CHANGED="$(git diff --name-only "$BASE_REF" "$REF" 2>/dev/null || true)"
  if [[ -n "$CHANGED" ]]; then
    while IFS= read -r path; do
      [[ -z "$path" ]] && continue
      case "$path" in
        "$MATRIX"|"$RESULTS"|"$SQL"|"$VERIFY") ;;
        docs/product/README.md) ;;
        src/lib/safe-redirect.ts|src/lib/safe-redirect.test.ts) ;;
        src/lib/data/contracts/overview.ts|src/lib/data/contracts/overview.test.ts) ;;
        src/lib/data/dashboard/overview.ts|src/lib/data/dashboard/overview.test.ts) ;;
        src/lib/data/setup/employee-assignment-readiness.ts|src/lib/data/setup/employee-assignment-readiness.test.ts) ;;
        src/routes/_app/dashboard.tsx|src/routes/_app/izin.tsx|src/routes/_app/masraf.tsx|src/routes/_app/performans.tsx) ;;
        *)
          case "$path" in
            src/*|supabase/migrations/*|supabase/seed/puls-sanayi-v1/csv/*|supabase/seed/puls-sanayi-v1/manifest.json|.env|.env.*|package.json)
              echo "FAIL: forbidden path changed: $path"
              exit 1
              ;;
            *)
              echo "FAIL: path not allowlisted for PR13.11 QA artifacts: $path"
              exit 1
              ;;
          esac
          ;;
      esac
    done <<< "$CHANGED"
  fi
fi

echo "OK: PR13.11 role/route product QA verification passed"
