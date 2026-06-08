#!/usr/bin/env bash
set -euo pipefail

REF="${1:-HEAD}"

file_at_ref() {
  local path="$1"
  if [[ "$REF" == "WORKTREE" ]]; then
    cat "$path"
  else
    git show "${REF}:${path}"
  fi
}

echo "Checking ${REF}: PR14.10 mapping discovery ..."

DOC="$(file_at_ref docs/product/14_mapping_discovery.md)"
README="$(file_at_ref docs/product/README.md)"
STRATEGY="$(file_at_ref docs/product/13_v1_product_packaging_strategy.md)"
ERP_TS="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
DASHBOARD_TS="$(file_at_ref src/lib/data/dashboard/overview.ts)"
DASHBOARD_TEST="$(file_at_ref src/lib/data/dashboard/overview.test.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/verikaynaklari.tsx)"
TR="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN="$(file_at_ref src/i18n/locales/en-US.json)"

for needle in \
  "PR14.10 turns connector setup from a selected source into a visible field contract." \
  "Mapping discovery uses \`puls_integration.erp_field_mappings\` as the tenant-scoped field contract." \
  "No connector import execution." \
  "No live Canias API call." \
  "No credential capture or secret storage." \
  "No ERP write-back." \
  "Canias default mapping uses only seed-proven generic fields" \
  "CSV / Excel default mapping uses neutral template header names"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR14.10 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "buildDefaultConnectorFieldMappings" \
  "DEFAULT_FIELD_MAPPINGS" \
  "ensureDefaultConnectorFieldMappings" \
  "erp_field_mappings" \
  "setup_status: 'mapping_ready'" \
  "setup_step: 'namespace'" \
  "canonicalClasses" \
  "ConnectorCanonicalDataClass"; do
  if ! grep -Fq "$needle" <<< "$ERP_TS"; then
    echo "FAIL: ERP adapter missing mapping discovery needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "erp.sections.canonicalClasses" \
  "erp-mapping-discovery" \
  "data.canonicalClasses" \
  "canonicalClass.mappedRequiredFields" \
  "erp.mapping.required"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route missing mapping discovery needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "dashboardSetup.erpCard.statusMappingReady" \
  "dashboardSetup.erpCard.descriptionMappingReady"; do
  if ! grep -Fq "$needle" <<< "$DASHBOARD_TS"; then
    echo "FAIL: dashboard adapter missing mapping-ready state: $needle" >&2
    exit 1
  fi
done

for needle in \
  "builds a seed-proven default Canias mapping contract" \
  "shows mapping-ready setup summary without implying preflight readiness" \
  "setupStatus: 'mapping_ready'" \
  "currentStep: 'namespace'"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP tests missing mapping discovery case: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "uses mapping-ready copy" <<< "$DASHBOARD_TEST"; then
  echo "FAIL: dashboard tests missing mapping-ready copy case" >&2
  exit 1
fi

for needle in \
  "Kanonik veri sınıfları" \
  "Alan sözleşmesini incele" \
  "Alanlar hazır" \
  "Zorunlu"; do
  if ! grep -Fq "$needle" <<< "$TR"; then
    echo "FAIL: Turkish locale missing mapping discovery copy: $needle" >&2
    exit 1
  fi
done

for needle in \
  "Canonical data classes" \
  "Review field contract" \
  "Fields ready" \
  "Required"; do
  if ! grep -Fq "$needle" <<< "$EN"; then
    echo "FAIL: English locale missing mapping discovery copy: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.10 Mapping discovery" \
  "14_mapping_discovery.md" \
  "scripts/verify-14-mapping-discovery.sh"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR14.10 reference: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "[x] Connector mapping discovery connects source fields to canonical PULS data classes without import execution (PR14.10)" <<< "$STRATEGY"; then
  echo "FAIL: strategy DoD missing completed PR14.10 checkbox" >&2
  exit 1
fi

if [[ "$REF" == "WORKTREE" ]]; then
  CHANGED="$(git diff --name-only && git diff --cached --name-only && git ls-files --others --exclude-standard)"
else
  BASE="$(git merge-base origin/main "$REF" 2>/dev/null || git merge-base main "$REF")"
  CHANGED="$(git diff --name-only "$BASE" "$REF")"
fi

while IFS= read -r changed; do
  [[ -z "$changed" ]] && continue
  case "$changed" in
    docs/product/14_mapping_discovery.md) ;;
    docs/product/README.md) ;;
    docs/product/13_v1_product_packaging_strategy.md) ;;
    scripts/verify-14-mapping-discovery.sh) ;;
    src/lib/data/index.ts) ;;
    src/lib/data/dashboard/overview.ts) ;;
    src/lib/data/dashboard/overview.test.ts) ;;
    src/lib/data/setup/erp.ts) ;;
    src/lib/data/setup/erp.test.ts) ;;
    src/routes/_app/verikaynaklari.tsx) ;;
    src/i18n/locales/tr-TR.json) ;;
    src/i18n/locales/en-US.json) ;;
    supabase/.temp/*) ;;
    supabase/.branches/*) ;;
    *)
      echo "FAIL: unexpected changed path for PR14.10 mapping discovery: $changed" >&2
      exit 1
      ;;
  esac

  case "$changed" in
    supabase/migrations/*|supabase/seed/puls-sanayi-v1/csv/*|supabase/seed/puls-sanayi-v1/manifest.json|package.json|pnpm-lock.yaml|.env*|services/*/src/*)
      echo "FAIL: forbidden path changed for PR14.10 mapping discovery: $changed" >&2
      exit 1
      ;;
  esac
done <<< "$CHANGED"

if grep -R -E "credentials_ref|OPENAI_API_KEY|CANIAS_API_KEY|chat\\.completions|responses\\.create|sync_canias_now|write_to_canias|apply_import_batch|record_import_row|create_import_batch" \
  docs/product/14_mapping_discovery.md \
  src/lib/data/setup/erp.ts \
  src/routes/_app/verikaynaklari.tsx \
  src/i18n/locales/tr-TR.json \
  src/i18n/locales/en-US.json >/dev/null; then
  echo "FAIL: PR14.10 changed files contain forbidden runtime, credential, or import patterns" >&2
  exit 1
fi

echo "OK: PR14.10 mapping discovery verification passed"
