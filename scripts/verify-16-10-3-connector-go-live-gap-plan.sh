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

echo "Checking ${REF}: PR16.10.3 connector go-live gap plan ..."

DOC="$(file_at_ref docs/product/16_10_3_connector_go_live_gap_plan.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/erp.tsx)"
ERP_TESTS="$(file_at_ref src/lib/data/setup/erp.test.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"

for needle in \
  "PR16.10.3 Connector Go-Live Gap Plan" \
  "go-live gap plan" \
  "source and transfer method" \
  "safe evidence" \
  "No provider API calls" \
  "No credential value readback" \
  "No database migration"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.10.3 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorGoLivePlan" \
  "ConnectorGoLiveGapId" \
  "buildConnectorGoLivePlan" \
  "canStartCustomerPilot" \
  "goLiveGap(" \
  "erp.goLivePlan.evidence.secureAccessPartial" \
  "liveProviderCallsEnabled: false" \
  "credentialReadbackEnabled: false" \
  "sourceWritebackEnabled: false"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing go-live plan needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "erp-go-live-plan" \
  "erp.goLivePlan.title" \
  "data.goLivePlan.score" \
  "data.goLivePlan.canStartCustomerPilot" \
  "data.goLivePlan.gaps.map" \
  "erp.goLivePlan.boundaryNote"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route missing go-live plan UI needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "result.data.goLivePlan" \
  "canStartCustomerPilot: true" \
  "erp.goLivePlan.nextActions.request_secure_access" \
  "erp.goLivePlan.evidence.secureAccessReady" \
  "canStartCustomerPilot: false"; do
  if ! grep -Fq "$needle" <<< "$ERP_TESTS"; then
    echo "FAIL: ERP tests missing go-live plan needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  '"goLivePlan"' \
  '"Canlıya geçiş boşluk planı"' \
  '"Veri sahipliği"' \
  '"Müşteri teyidi"' \
  '"Müşteri pilotuna hazır"'; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing go-live plan copy: $needle" >&2
    exit 1
  fi
done

for needle in \
  '"goLivePlan"' \
  '"Go-live gap plan"' \
  '"Data ownership"' \
  '"Customer confirmation"' \
  '"Ready for customer pilot"'; do
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing go-live plan copy: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR16.10.3 - Connector Go-Live Gap Plan" <<< "$ROADMAP"; then
  echo "FAIL: roadmap missing PR16.10.3 section" >&2
  exit 1
fi

if ! grep -Fq "PR16.10.3 connector go-live gap plan" <<< "$README"; then
  echo "FAIL: README missing PR16.10.3 section" >&2
  exit 1
fi

echo "PR16.10.3 connector go-live gap plan verification passed."
