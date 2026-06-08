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

echo "Checking ${REF}: PR16.10.6 ERP step-scoped connector journey ..."

DOC="$(file_at_ref docs/product/16_10_6_erp_step_scoped_connector_journey.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
ERP_ROUTE="$(file_at_ref src/routes/_app/erp.tsx)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"

for needle in \
  "PR16.10.6 ERP Step-Scoped Connector Journey" \
  "ERP connectors remain the main product path" \
  "CSV / Excel is treated as the first executable manual file connector lane" \
  "Every visible step has exactly one primary action" \
  "No database migration" \
  "No CSV / Excel parsing or upload implementation" \
  "No release-note, roadmap, or future-work text is rendered inside the product UI"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.10.6 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "type ConnectorJourneyStepId" \
  "type ConnectorJourneyStep" \
  "connectorJourneyStepFromTarget" \
  "selectedJourneyStepId" \
  "journeySteps.map" \
  "activeJourneyStep.primaryAction" \
  "detailTab" \
  "detailTargetId" \
  "erp-setup-details"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route missing step-scoped journey needle: $needle" >&2
    exit 1
  fi
done

for forbidden in \
  "data.goLivePlan.gaps.map((gap, index)" \
  "JourneyActionIcon" \
  "const journeyAction"; do
  if grep -Fq "$forbidden" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route still has old single-card journey construct: $forbidden" >&2
    exit 1
  fi
done

for needle in \
  '"steps"' \
  '"Kaynak ve erişim"' \
  '"Alanları eşleştir"' \
  '"Önizleme çalıştır"' \
  '"Onayla ve worker' \
  '"Sonucu takip et"' \
  '"Worker modu"'; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing journey step copy: $needle" >&2
    exit 1
  fi
done

for needle in \
  '"steps"' \
  '"Source and access"' \
  '"Map fields"' \
  '"Run preview"' \
  '"Approve and send to worker"' \
  '"Track results"' \
  '"Worker mode"'; do
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing journey step copy: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR16.10.6 - ERP Step-Scoped Connector Journey" <<< "$ROADMAP"; then
  echo "FAIL: roadmap missing PR16.10.6 section" >&2
  exit 1
fi

if ! grep -Fq "PR16.10.6 ERP step-scoped connector journey" <<< "$README"; then
  echo "FAIL: README missing PR16.10.6 section" >&2
  exit 1
fi

echo "PR16.10.6 ERP step-scoped connector journey verification passed."
