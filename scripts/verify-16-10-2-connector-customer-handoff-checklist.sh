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

echo "Checking ${REF}: PR16.10.2 connector customer handoff checklist ..."

DOC="$(file_at_ref docs/product/16_10_2_connector_customer_handoff_checklist.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/erp.tsx)"
ERP_TESTS="$(file_at_ref src/lib/data/setup/erp.test.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"

for needle in \
  "PR16.10.2 Connector Customer Handoff Checklist" \
  "customer-facing access package" \
  "source identity" \
  "transfer method" \
  "No provider API calls" \
  "No credential value readback" \
  "No database migration"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.10.2 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorCustomerHandoff" \
  "ConnectorCustomerHandoffItemId" \
  "buildConnectorCustomerHandoff" \
  "shareableWithCustomer" \
  "customerHandoffItem" \
  "erp.customerHandoff.values.secureAccessPartial" \
  "liveProviderCallsEnabled: false" \
  "credentialReadbackEnabled: false" \
  "sourceWritebackEnabled: false"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing customer handoff needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "erp-customer-handoff" \
  "erp.customerHandoff.title" \
  "data.customerHandoff.score" \
  "data.customerHandoff.shareableWithCustomer" \
  "data.customerHandoff.items.map" \
  "erp.customerHandoff.boundaryNote"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route missing customer handoff UI needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "result.data.customerHandoff" \
  "score: 83" \
  "shareableWithCustomer: true" \
  "erp.customerHandoff.nextActions.request_secure_reference" \
  "erp.customerHandoff.values.secureAccessReady" \
  "shareableWithCustomer: false"; do
  if ! grep -Fq "$needle" <<< "$ERP_TESTS"; then
    echo "FAIL: ERP tests missing customer handoff needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  '"customerHandoff"' \
  '"Müşteri erişim paketi"' \
  '"Kaynak kimliği"' \
  '"Güvenli erişim"' \
  '"Paylaşıma hazır"'; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing customer handoff copy: $needle" >&2
    exit 1
  fi
done

for needle in \
  '"customerHandoff"' \
  '"Customer access package"' \
  '"Source identity"' \
  '"Secure access"' \
  '"Ready to share"'; do
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing customer handoff copy: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR16.10.2 - Connector Customer Handoff Checklist" <<< "$ROADMAP"; then
  echo "FAIL: roadmap missing PR16.10.2 section" >&2
  exit 1
fi

if ! grep -Fq "PR16.10.2 connector customer handoff checklist" <<< "$README"; then
  echo "FAIL: README missing PR16.10.2 section" >&2
  exit 1
fi

echo "PR16.10.2 connector customer handoff checklist verification passed."
