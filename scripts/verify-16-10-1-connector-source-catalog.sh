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

echo "Checking ${REF}: PR16.10.1 connector source catalog ..."

DOC="$(file_at_ref docs/product/16_10_1_connector_source_catalog.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/erp.tsx)"
ERP_TESTS="$(file_at_ref src/lib/data/setup/erp.test.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"

for needle in \
  "PR16.10.1 Connector Source Catalog" \
  "production connector catalog" \
  "source type" \
  "transfer method" \
  "No provider API calls" \
  "No database migration"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.10.1 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "categoryKey" \
  "transferMethodKey" \
  "availabilityKey" \
  "recommendedUseKey" \
  "erp.providerCatalog.categories.erp" \
  "erp.providerCatalog.methods.fileOrManual" \
  "erp.providerCatalog.availability.futureModelReady"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing connector catalog needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "erp.providerCatalog.labels.category" \
  "erp.providerCatalog.labels.method" \
  "selectedProvider.availabilityKey" \
  "selectedProvider.recommendedUseKey" \
  "selectedProvider.categoryKey"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route missing connector catalog UI needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "categoryKey.startsWith('erp.providerCatalog.categories.')" \
  "transferMethodKey.startsWith('erp.providerCatalog.methods.')" \
  "recommendedUseKey: 'erp.providerCatalog.recommendedUse.csv_import'"; do
  if ! grep -Fq "$needle" <<< "$ERP_TESTS"; then
    echo "FAIL: ERP tests missing connector catalog needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  '"providerCatalog"' \
  '"Kaynak türü"' \
  '"Dosya / manuel import"' \
  '"Taslak kuruluma açık"' \
  '"Müşteri doğrulaması bekler"'; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing connector catalog copy: $needle" >&2
    exit 1
  fi
done

for needle in \
  '"providerCatalog"' \
  '"Source type"' \
  '"File / manual import"' \
  '"Setup draft available"' \
  '"Customer confirmation required"'; do
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing connector catalog copy: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR16.10.1 - Connector Source Catalog" <<< "$ROADMAP"; then
  echo "FAIL: roadmap missing PR16.10.1 section" >&2
  exit 1
fi

if ! grep -Fq "PR16.10.1 connector source catalog" <<< "$README"; then
  echo "FAIL: README missing PR16.10.1 section" >&2
  exit 1
fi

echo "PR16.10.1 connector source catalog verification passed."
