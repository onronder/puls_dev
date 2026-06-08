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

echo "Checking ${REF}: PR16.10.0 connector access readiness ..."

DOC="$(file_at_ref docs/product/16_10_0_connector_access_readiness.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/verikaynaklari.tsx)"
ERP_TESTS="$(file_at_ref src/lib/data/setup/erp.test.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"

for needle in \
  "PR16.10.0 Connector Access Readiness" \
  "provider-independent access readiness" \
  "No provider API calls" \
  "No credential value readback" \
  "No database migration is required"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.10.0 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorAccessReadiness" \
  "buildConnectorAccessReadiness" \
  "liveProviderCallsEnabled: false" \
  "credentialReadbackEnabled: false" \
  "sourceWritebackEnabled: false" \
  "method === 'soap'" \
  "method === 'webhook'" \
  "customer_api_access" \
  "offline_preview_path"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing access readiness needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "erp-access-readiness" \
  "data.accessReadiness" \
  "erp.accessReadiness.title" \
  "requestSecureReference" \
  "reviewMetadata" \
  "openPreview"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route missing access readiness UI needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "result.data.accessReadiness" \
  "liveProviderCallsEnabled: false" \
  "credentialReadbackEnabled: false" \
  "sourceWritebackEnabled: false" \
  "customer_api_access"; do
  if ! grep -Fq "$needle" <<< "$ERP_TESTS"; then
    echo "FAIL: ERP tests missing access readiness needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "Erişim hazırlığı" \
  "Müşteri/API erişimi" \
  "API'siz önizleme yolu" \
  '"soap": "SOAP API"' \
  '"webhook": "Webhook"' \
  "provider çağrısı yapmaz"; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing access readiness copy: $needle" >&2
    exit 1
  fi
done

for needle in \
  "Access readiness" \
  "Customer/API access" \
  "Offline preview path" \
  '"soap": "SOAP API"' \
  '"webhook": "Webhook"' \
  "does not call providers"; do
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing access readiness copy: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR16.10.0 implements provider-independent connector access readiness" <<< "$ROADMAP"; then
  echo "FAIL: roadmap missing PR16.10.0 implementation status" >&2
  exit 1
fi

if ! grep -Fq "PR16.10.0 connector access readiness" <<< "$README"; then
  echo "FAIL: README missing PR16.10.0 section" >&2
  exit 1
fi

echo "PR16.10.0 connector access readiness verification passed."
