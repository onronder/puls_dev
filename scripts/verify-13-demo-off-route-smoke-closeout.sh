#!/usr/bin/env bash
# Verifies PR13.10 demo-off route smoke closeout artifacts.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
VERIFY_SCRIPT="scripts/verify-13-demo-off-route-smoke-closeout.sh"
FALLBACK_GUARD="scripts/check-13-demo-fallback-regression.sh"
TRUTH_TABLE="docs/product/13_v1_screen_readiness_truth_table.md"
CLOSEOUT="docs/product/13_v1_packaging_closeout.md"

file_at_ref() {
  local path="$1"
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

echo "Checking ${REF}: PR13.10 demo-off route smoke closeout ..."

REQUIRED_FILES=(
  "$TRUTH_TABLE"
  "$CLOSEOUT"
  "$FALLBACK_GUARD"
  "$VERIFY_SCRIPT"
  "src/lib/persona.ts"
  "src/lib/persona.test.ts"
  "src/lib/auth.tsx"
  "src/components/auth/SetupRouteGuard.tsx"
  "src/i18n/locales/tr-TR.json"
  "src/i18n/locales/en-US.json"
  "docs/product/README.md"
  "docs/product/13_v1_packaging_signoff_roadmap.md"
  "docs/product/13_v1_remaining_work_register.md"
)

for f in "${REQUIRED_FILES[@]}"; do
  if ! file_at_ref "$f" >/dev/null; then
    echo "FAIL: missing required file: $f"
    exit 1
  fi
done

TRUTH_TEXT="$(file_at_ref "$TRUTH_TABLE")"
CLOSEOUT_TEXT="$(file_at_ref "$CLOSEOUT")"
GUARD_TEXT="$(file_at_ref "$FALLBACK_GUARD")"
README_TEXT="$(file_at_ref docs/product/README.md)"
ROADMAP_TEXT="$(file_at_ref docs/product/13_v1_packaging_signoff_roadmap.md)"
REGISTER_TEXT="$(file_at_ref docs/product/13_v1_remaining_work_register.md)"
PERSONA_TEXT="$(file_at_ref src/lib/persona.ts)"
AUTH_TEXT="$(file_at_ref src/lib/auth.tsx)"
SETUP_GUARD_TEXT="$(file_at_ref src/components/auth/SetupRouteGuard.tsx)"
TR_LOCALE_TEXT="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE_TEXT="$(file_at_ref src/i18n/locales/en-US.json)"

truth_needles=(
  "VITE_PULS_DEMO_MODE=false"
  "Puls Teknik A.S."
  "source: real"
  "Not visible"
  "demo_ready_core"
  "partial_v1"
  "placeholder_future"
  "Demo pill"
)
for needle in "${truth_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$TRUTH_TEXT"; then
    echo "FAIL: truth table missing needle: $needle"
    exit 1
  fi
done

ROUTES=(
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
for route in "${ROUTES[@]}"; do
  if ! grep -Fq "$route" <<< "$TRUTH_TEXT"; then
    echo "FAIL: truth table missing route: $route"
    exit 1
  fi
done

if grep -Fq "| Pending |" <<< "$TRUTH_TEXT"; then
  echo "FAIL: truth table must not contain pending route rows after PR13.10 smoke"
  exit 1
fi
if grep -Fq "source: demo" <<< "$TRUTH_TEXT"; then
  echo "FAIL: PR13.10 truth table must not claim source: demo"
  exit 1
fi

closeout_needles=(
  "PULS V1 has a DB-backed customer-demo packaging proof"
  "Every screen is production complete"
  "Canias integration is implemented"
  "AI Coach is live"
  "PR14 should start from customer discovery"
)
for needle in "${closeout_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$CLOSEOUT_TEXT"; then
    echo "FAIL: closeout doc missing needle: $needle"
    exit 1
  fi
done

guard_needles=(
  "fetchDemo"
  "DemoSourcePill"
  "source:"
  "demo"
  "Classify the route"
)
for needle in "${guard_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$GUARD_TEXT"; then
    echo "FAIL: fallback guard missing needle: $needle"
    exit 1
  fi
done

if ! grep -Fq "PR13.10 Demo-off route smoke + fallback closeout" <<< "$README_TEXT"; then
  echo "FAIL: README missing PR13.10 section"
  exit 1
fi
if ! grep -Fq "Demo-off route smoke | Done" <<< "$ROADMAP_TEXT"; then
  echo "FAIL: roadmap must show demo-off route smoke done"
  exit 1
fi
if ! grep -Fq "W4 | Demo-off route smoke | Done" <<< "$REGISTER_TEXT"; then
  echo "FAIL: register must show W4 done"
  exit 1
fi
if ! grep -Fq "W5 | Screen readiness truth table + fallback guard | Done" <<< "$REGISTER_TEXT"; then
  echo "FAIL: register must show W5 done"
  exit 1
fi

"./$FALLBACK_GUARD" "$REF"

if ! grep -Fq ".schema('puls_core')" <<< "$PERSONA_TEXT"; then
  echo "FAIL: persona resolver must check puls_core first"
  exit 1
fi
if ! grep -Fq "await loadPersona" <<< "$AUTH_TEXT"; then
  echo "FAIL: auth provider must await initial persona load"
  exit 1
fi
if ! grep -Fq "isPersonaPending" <<< "$SETUP_GUARD_TEXT"; then
  echo "FAIL: setup route guard must wait for persona resolution"
  exit 1
fi
if grep -Fq "Demo çalışanlar eklendi" <<< "$TR_LOCALE_TEXT"; then
  echo "FAIL: Turkish setup smoke path must not show legacy demo employee copy"
  exit 1
fi
if grep -Fq "Mert Teknik A.Ş. · Pilot paket" <<< "$TR_LOCALE_TEXT"; then
  echo "FAIL: Turkish settings smoke path must not show legacy Mert Teknik copy"
  exit 1
fi
if grep -Fq "Mert Teknik A.Ş. · Pilot plan" <<< "$EN_LOCALE_TEXT"; then
  echo "FAIL: English settings smoke path must not show legacy Mert Teknik copy"
  exit 1
fi

# Diff guard: PR13.10 allows docs/scripts plus narrow smoke-found blocker fixes.
BASE_REF="$(git merge-base "${REF}" origin/main 2>/dev/null || echo "")"
if [[ -n "$BASE_REF" && "$BASE_REF" != "$REF" ]]; then
  CHANGED=$(git diff --name-only "$BASE_REF" "$REF" 2>/dev/null || true)
  if [[ -n "$CHANGED" ]]; then
    while IFS= read -r path; do
      [[ -z "$path" ]] && continue
      case "$path" in
        "$TRUTH_TABLE") ;;
        "$CLOSEOUT") ;;
        "$FALLBACK_GUARD") ;;
        "$VERIFY_SCRIPT") ;;
        src/lib/persona.ts) ;;
        src/lib/persona.test.ts) ;;
        src/lib/auth.tsx) ;;
        src/components/auth/SetupRouteGuard.tsx) ;;
        src/i18n/locales/tr-TR.json) ;;
        src/i18n/locales/en-US.json) ;;
        docs/product/README.md) ;;
        docs/product/13_v1_packaging_signoff_roadmap.md) ;;
        docs/product/13_v1_remaining_work_register.md) ;;
        docs/product/13_embedded_demo_retirement_plan.md) ;;
        docs/product/13_packaging_proof_demo_guardrails.md) ;;
        *)
          case "$path" in
            src/*|supabase/migrations/*|supabase/seed/puls-sanayi-v1/csv/*|supabase/seed/puls-sanayi-v1/manifest.json|package.json|.env|.env.*|docs/api/openapi.yaml|openapi.json|swagger.json)
              echo "FAIL: forbidden path vs merge-base: $path"
              exit 1
              ;;
            *)
              echo "FAIL: path not allowlisted for PR13.10: $path"
              exit 1
              ;;
          esac
          ;;
      esac
    done <<< "$CHANGED"
  fi
fi

echo "OK: PR13.10 demo-off route smoke closeout verification passed"
