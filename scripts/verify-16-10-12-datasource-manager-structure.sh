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

line_count_at_ref() {
  local path="$1"
  if [[ "$REF" == "WORKTREE" ]]; then
    wc -l < "$path"
    return
  fi
  git show "${REF}:${path}" 2>/dev/null | wc -l || wc -l < "$path"
}

echo "Checking ${REF}: PR16.10.12 DataSource Manager structure hardening ..."

DOC="$(file_at_ref docs/product/16_10_12_datasource_manager_structure.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
ROUTE="$(file_at_ref src/routes/_app/verikaynaklari.tsx)"
MANAGER_SECTION="$(file_at_ref src/components/data-sources/DataSourceManagerSection.tsx)"
TECHNICAL_SHEET="$(file_at_ref src/components/data-sources/DataSourceTechnicalDetailsSheet.tsx)"
UI_HELPERS="$(file_at_ref src/components/data-sources/dataSourceUi.tsx)"
UI_TEST="$(file_at_ref src/components/data-sources/dataSourceUi.test.tsx)"
ROUTE_LINES="$(line_count_at_ref src/routes/_app/verikaynaklari.tsx | tr -d ' ')"

for needle in \
  "PR16.10.12 DataSource Manager Structure Hardening" \
  "No release notes, development notes, future-work notes, or diagnostic prose" \
  "Source inventory and selected-source summary live in" \
  "The long technical audit sheet lives in" \
  "Shared UI helpers"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.10.12 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.10.12 - DataSource Manager Structure Hardening" \
  "DataSource source inventory" \
  "Teknik audit sheet" \
  "dataSourceUi"; do
  if ! grep -Fq "$needle" <<< "$ROADMAP"; then
    echo "FAIL: roadmap missing PR16.10.12 needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.10.12 DataSource Manager structure hardening" \
  "DataSourceManagerSection.tsx" \
  "DataSourceTechnicalDetailsSheet.tsx" \
  "dataSourceUi.test.tsx"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR16.10.12 needle: $needle" >&2
    exit 1
  fi
done

if (( ROUTE_LINES > 1500 )); then
  echo "FAIL: verikaynaklari route is still too large (${ROUTE_LINES} lines)" >&2
  exit 1
fi

for needle in \
  "DataSourceManagerSection" \
  "DataSourceTechnicalDetailsSheet" \
  "FileImportSheet" \
  "ProviderDraftSheet"; do
  if ! grep -Fq "$needle" <<< "$ROUTE"; then
    echo "FAIL: route missing component wiring: $needle" >&2
    exit 1
  fi
done

if grep -Fq "<SheetShell" <<< "$ROUTE"; then
  echo "FAIL: route must not render the technical SheetShell directly" >&2
  exit 1
fi

if grep -Fq "id=\"data-source-manager\"" <<< "$ROUTE"; then
  echo "FAIL: route must not render the source inventory section directly" >&2
  exit 1
fi

for needle in \
  "id=\"data-source-manager\"" \
  "dataSourceDisplayName" \
  "formatDataSourceScope" \
  "onOpenTechnicalDetails"; do
  if ! grep -Fq "$needle" <<< "$MANAGER_SECTION"; then
    echo "FAIL: manager section missing source inventory needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "<SheetShell" \
  "ERP_WORKBENCH_TABS" \
  "TabsContent" \
  "requestCredentialHandoffMutation"; do
  if ! grep -Fq "$needle" <<< "$TECHNICAL_SHEET"; then
    echo "FAIL: technical sheet missing isolated inspector needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "connectorJourneyStepFromTarget" \
  "readinessTone" \
  "dataSourceDisplayName" \
  "ProviderOptionIcon"; do
  if ! grep -Fq "$needle" <<< "$UI_HELPERS"; then
    echo "FAIL: shared UI helper missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "maps technical focus targets" \
  "uses provider translation" \
  "formats data source scope"; do
  if ! grep -Fq "$needle" <<< "$UI_TEST"; then
    echo "FAIL: data source UI tests missing needle: $needle" >&2
    exit 1
  fi
done

echo "PASS: PR16.10.12 DataSource Manager structure hardening contract verified."
