#!/usr/bin/env bash
# Verifies 11 PR11.0 sidebar data/API inventory (documentation-only PR).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
INVENTORY="docs/data/11_sidebar_data_api_inventory.md"
README="docs/data/README.md"

file_at_ref() {
  local path="$1"
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

INVENTORY_CONTENT="$(file_at_ref "$INVENTORY")"

echo "Checking ${REF}: PR11.0 sidebar data/API inventory ..."

if [[ ! -f "$INVENTORY" ]]; then
  echo "FAIL: missing required file: $INVENTORY"
  exit 1
fi

# --- Required route labels (Turkish screen names in doc) ---
route_needles=(
  "Ana Sayfa"
  "Performans"
  "Çalışanlar"
  "Kariyer"
  "Eğitim"
  "İş Değerleme"
  "İzin"
  "Masraf"
  "Sözleşmeler"
  "AI Koç"
  "Ayarlar"
  "Profil"
  "Şirket Kurulum"
  "Masraf Kategorileri"
  "İzin Tanımları"
  "Departmanlar"
  "Pozisyonlar"
)

for needle in "${route_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$INVENTORY_CONTENT"; then
    echo "FAIL: inventory missing required route/screen label: $needle"
    exit 1
  fi
done

# --- Required section headings / topics ---
section_needles=(
  "Route coverage matrix"
  "Demo fallback inventory"
  "Mutation/RPC inventory"
  "Tenant/RLS/security notes"
  "Swagger/OpenAPI candidates"
  "PR11 follow-up map"
)

for needle in "${section_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$INVENTORY_CONTENT"; then
    echo "FAIL: inventory missing required section: $needle"
    exit 1
  fi
done

# --- PR11.1 through PR11.9 ---
for n in 1 2 3 4 5 6 7 8 9; do
  if ! grep -Fq "PR11.${n}" <<< "$INVENTORY_CONTENT"; then
    echo "FAIL: inventory missing PR11.${n} in follow-up map"
    exit 1
  fi
done

# --- API / RPC candidate needles ---
api_needles=(
  "create_expense_claim"
  "create_leave_request"
  "deactivate_expense_category"
  "restore_expense_category"
  "deactivate_leave_type"
  "restore_leave_type"
)

for needle in "${api_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$INVENTORY_CONTENT"; then
    echo "FAIL: inventory missing required API/RPC candidate: $needle"
    exit 1
  fi
done

# --- Taxonomy needles ---
taxonomy_needles=(
  "production_real"
  "demo_fallback"
  "P0_security"
  "supabase_rpc"
)

for needle in "${taxonomy_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$INVENTORY_CONTENT"; then
    echo "FAIL: inventory missing required taxonomy token: $needle"
    exit 1
  fi
done

# --- Demo fallback: route/domain coverage without brittle adapter symbol names ---
if ! grep -Fq "/calisanlar" <<< "$INVENTORY_CONTENT"; then
  echo "FAIL: inventory must document /calisanlar in demo fallback context"
  exit 1
fi

if ! grep -Eiq 'inline (adapter )?stub|inline stub' <<< "$INVENTORY_CONTENT"; then
  echo "FAIL: inventory must document inline stub behavior (route/domain prose)"
  exit 1
fi

# Do not require adapter symbol needles (fetchEmployeeList, etc.) — human review only.

# --- No implementation changes vs origin/main ---
CHANGED_FILES=()
while IFS= read -r file; do
  [[ -n "$file" ]] && CHANGED_FILES+=("$file")
done < <(git diff --name-only origin/main...HEAD 2>/dev/null || true)

ALLOWED=(
  "$INVENTORY"
  "scripts/verify-11-sidebar-data-api-inventory.sh"
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

if ((${#CHANGED_FILES[@]} > 0)); then
  for file in "${CHANGED_FILES[@]}"; do
    if ! is_allowed "$file"; then
      echo "FAIL: PR11.0 must not change implementation files: $file"
      exit 1
    fi
  done
fi

FORBIDDEN_PREFIXES=(
  "supabase/migrations/"
  "src/routes/"
  "src/lib/data/"
  "src/components/"
)

for file in "${CHANGED_FILES[@]}"; do
  for prefix in "${FORBIDDEN_PREFIXES[@]}"; do
    if [[ "$file" == "$prefix"* ]]; then
      echo "FAIL: forbidden changed path under $prefix : $file"
      exit 1
    fi
  done
done

# README is optional — never fail if absent from diff
if git diff --name-only origin/main...HEAD -- "$README" 2>/dev/null | grep -q .; then
  echo "NOTE: optional docs/data/README.md updated"
fi

echo "OK: PR11.0 sidebar data/API inventory checks passed for ${REF}"
