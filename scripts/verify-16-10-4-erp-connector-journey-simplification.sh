#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"

file_at_ref() {
  local path="$1"
  if [[ "$REF" == "WORKTREE" ]]; then
    cat "$path"
    return
  fi
  git show "${REF}:${path}" 2>/dev/null || cat "$path"
}

echo "Checking ${REF}: PR16.10.4 ERP connector journey simplification ..."

DOC="$(file_at_ref docs/product/16_10_4_erp_connector_journey_simplification.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
ERP_ROUTE="$(file_at_ref src/routes/_app/verikaynaklari.tsx)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"

for needle in \
  "PR16.10.4 ERP Connector Journey Simplification" \
  "simple connector setup journey" \
  "Technical evidence is still available" \
  "Deep links and in-page actions automatically open" \
  "No database migration" \
  "No provider API calls"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.10.4 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "technicalDetailsOpen" \
  "setTechnicalDetailsOpen(true)" \
  "erp-connector-journey" \
  "erp.journey.title" \
  "data.goLivePlan.gaps.map" \
  "erp.journey.actions.showDetails" \
  "erp.journey.technicalDetails.title" \
  "open={technicalDetailsOpen}" \
  "onToggle={(event) => setTechnicalDetailsOpen(event.currentTarget.open)}"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route missing journey simplification needle: $needle" >&2
    exit 1
  fi
done

if grep -Fq "import { MetricCard" <<< "$ERP_ROUTE"; then
  echo "FAIL: ERP route still imports MetricCard after journey simplification" >&2
  exit 1
fi

for needle in \
  '"journey"' \
  '"Bağlantı kurulumu"' \
  '"Sıradaki adım"' \
  '"Detayları göster"' \
  '"Teknik detaylar ve denetim kanıtları"'; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing journey copy: $needle" >&2
    exit 1
  fi
done

for needle in \
  '"journey"' \
  '"Connection setup"' \
  '"Next step"' \
  '"Show details"' \
  '"Technical details and audit evidence"'; do
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing journey copy: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR16.10.4 - ERP Connector Journey Simplification" <<< "$ROADMAP"; then
  echo "FAIL: roadmap missing PR16.10.4 section" >&2
  exit 1
fi

if ! grep -Fq "PR16.10.4 ERP connector journey simplification" <<< "$README"; then
  echo "FAIL: README missing PR16.10.4 section" >&2
  exit 1
fi

echo "PR16.10.4 ERP connector journey simplification verification passed."
