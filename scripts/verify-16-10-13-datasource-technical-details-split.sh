#!/usr/bin/env bash
set -euo pipefail

LABEL="${1:-WORKTREE}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "PASS: $*"
}

line_count() {
  wc -l "$1" | awk '{print $1}'
}

require_file() {
  local file="$1"
  [[ -f "$file" ]] || fail "$file is missing"
}

require_contains() {
  local file="$1"
  local needle="$2"
  rg -F "$needle" "$file" >/dev/null || fail "$file does not contain: $needle"
}

require_not_contains() {
  local file="$1"
  local needle="$2"
  if rg -F "$needle" "$file" >/dev/null; then
    fail "$file must not contain: $needle"
  fi
}

require_max_lines() {
  local file="$1"
  local max_lines="$2"
  local actual
  actual="$(line_count "$file")"
  if (( actual > max_lines )); then
    fail "$file has $actual lines; expected <= $max_lines"
  fi
}

echo "Checking ${LABEL}: PR16.10.13 DataSource technical details split ..."

require_file "docs/product/16_10_13_datasource_technical_details_split.md"
require_file "src/components/data-sources/DataSourceTechnicalDetailsTypes.ts"
require_file "src/components/data-sources/DataSourceTechnicalDetailsSheet.tsx"
require_file "src/components/data-sources/DataSourceSetupTabPanel.tsx"
require_file "src/components/data-sources/DataSourceCheckTabPanel.tsx"
require_file "src/components/data-sources/DataSourcePreviewApplyTabPanel.tsx"
require_file "src/components/data-sources/DataSourcePreviewApplyImportSections.tsx"
require_file "src/components/data-sources/DataSourcePreviewApplyRecoverySections.tsx"
require_file "src/components/data-sources/DataSourcePreviewApplyRollbackSections.tsx"
require_file "src/components/data-sources/DataSourceControlledApplySection.tsx"
require_file "src/components/data-sources/DataSourceCredentialsTabPanel.tsx"
require_file "src/components/data-sources/DataSourceFieldsTabPanel.tsx"
require_file "src/components/data-sources/DataSourceActivityTabPanel.tsx"

require_max_lines "src/components/data-sources/DataSourceTechnicalDetailsSheet.tsx" 200
require_max_lines "src/components/data-sources/DataSourcePreviewApplyTabPanel.tsx" 120
require_max_lines "src/components/data-sources/DataSourcePreviewApplyImportSections.tsx" 700
require_max_lines "src/components/data-sources/DataSourcePreviewApplyRecoverySections.tsx" 700
require_max_lines "src/components/data-sources/DataSourcePreviewApplyRollbackSections.tsx" 700
require_max_lines "src/components/data-sources/DataSourceControlledApplySection.tsx" 700
require_max_lines "src/components/data-sources/DataSourceCredentialsTabPanel.tsx" 700
require_max_lines "src/components/data-sources/DataSourceFieldsTabPanel.tsx" 700
require_max_lines "src/components/data-sources/DataSourceActivityTabPanel.tsx" 700

require_contains "src/components/data-sources/DataSourceTechnicalDetailsTypes.ts" "DataSourceTechnicalDetailsPermissions"
require_contains "src/components/data-sources/DataSourceTechnicalDetailsTypes.ts" "DataSourceTechnicalDetailsMutations"
require_contains "src/routes/_app/verikaynaklari.tsx" "permissions={{"
require_contains "src/routes/_app/verikaynaklari.tsx" "mutations={{"
require_not_contains "src/components/data-sources/DataSourceTechnicalDetailsSheet.tsx" "canManageConnectors={"
require_not_contains "src/components/data-sources/DataSourceTechnicalDetailsSheet.tsx" "requestRuntimePreflightMutation"

for target_id in \
  "erp-setup-details" \
  "erp-preflight-result" \
  "erp-import-preview" \
  "erp-apply-readiness" \
  "erp-apply-change-set" \
  "erp-guarded-update-evidence" \
  "erp-guarded-update-recovery" \
  "erp-guarded-update-recovery-runbook" \
  "erp-guarded-update-rollback-preview" \
  "erp-guarded-update-rollback-approval" \
  "erp-guarded-update-rollback-worker-readiness" \
  "erp-guarded-update-rollback-worker-apply" \
  "erp-controlled-apply" \
  "erp-credential-boundary" \
  "erp-mapping-discovery" \
  "erp-runtime-queue"; do
  rg -F "id=\"${target_id}\"" src/components/data-sources >/dev/null || \
    fail "deep-link target ${target_id} is missing from data-source components"
done

require_contains "docs/product/README.md" "PR16.10.13 DataSource technical details split"
require_contains "docs/product/15_16_connector_runtime_ai_roadmap.md" "PR16.10.13 - DataSource technical details split"

pass "PR16.10.13 DataSource technical details split contract verified."
