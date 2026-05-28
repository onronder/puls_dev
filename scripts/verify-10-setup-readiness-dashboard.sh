#!/usr/bin/env bash
# Verifies 10 PR10.17 setup readiness dashboard (POSIX grep/awk).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
SMOKE="docs/data/10_setup_readiness_dashboard_smoke.sql"
DASHBOARD="src/lib/data/setup/setup-readiness-dashboard.ts"
DASHBOARD_TEST="src/lib/data/setup/setup-readiness-dashboard.test.ts"
COMPANY_ROUTE="src/routes/_app/sirket-kurulum.tsx"
DATA_INDEX="src/lib/data/index.ts"
I18N_TR="src/i18n/locales/tr-TR.json"
I18N_EN="src/i18n/locales/en-US.json"

file_at_ref() {
  local path="$1"
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

SMOKE_CONTENT="$(file_at_ref "$SMOKE")"
DASHBOARD_CONTENT="$(file_at_ref "$DASHBOARD")"
DASHBOARD_TEST_CONTENT="$(file_at_ref "$DASHBOARD_TEST")"
COMPANY_ROUTE_CONTENT="$(file_at_ref "$COMPANY_ROUTE")"
DATA_INDEX_CONTENT="$(file_at_ref "$DATA_INDEX")"

echo "Checking ${REF}: PR10.17 setup readiness dashboard ..."

for file in "$SMOKE" "$DASHBOARD" "$DASHBOARD_TEST" "$COMPANY_ROUTE" "$DATA_INDEX"; do
  if [[ ! -f "$file" ]]; then
    echo "FAIL: missing required file: $file"
    exit 1
  fi
done

MIGRATION_CHANGES="$(git diff --name-only --diff-filter=A origin/main...HEAD -- supabase/migrations/ 2>/dev/null || true)"
if [[ -n "$(echo "$MIGRATION_CHANGES" | sed '/^$/d')" ]]; then
  echo "FAIL: PR10.17 must not add migrations:"
  echo "$MIGRATION_CHANGES" | sed '/^$/d'
  exit 1
fi

smoke_needles=(
  "BEGIN;"
  "ROLLBACK;"
  "demo_setup_readiness_dashboard"
  "cross-tenant"
  "single-tenant staging"
  "WHERE tenant_id = v_tenant_id"
  "puls_workflow.expense_categories"
  "puls_workflow.leave_types"
  "puls_workflow.approval_policies"
  "puls_core.departments"
  "puls_core.positions"
  "puls_core.cost_centers"
  "puls_core.employees"
  "puls_core.employee_cost_center_assignments"
  "puls_core.employee_reporting_lines"
  "puls_integration.entity_identity_map"
)

for needle in "${smoke_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$SMOKE_CONTENT"; then
    echo "FAIL: smoke missing required fragment: $needle"
    exit 1
  fi
done

adapter_needles=(
  "fetchSetupReadinessDashboard"
  "buildExpenseReadinessSection"
  "buildLeaveReadinessSection"
  "buildApprovalPolicyReadinessSection"
  "buildOrgReadinessSection"
  "buildEmployeeAssignmentReadinessSection"
  "buildCostCenterReadinessSection"
  "buildRequestCreationReadinessSection"
  "combineSetupReadinessSeverity"
  "rankSetupReadinessSeverity"
  "Promise.allSettled"
  "fetchExpenseCategoriesOverview"
  "fetchLeaveTypesOverview"
  "fetchCostCenterReadinessOverview"
  "fetchOrgSetupReadiness"
  "fetchEmployeeAssignmentReadiness"
  "fetchRequestCreationReadiness"
)

for needle in "${adapter_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$DASHBOARD_CONTENT"; then
    echo "FAIL: setup-readiness-dashboard missing required fragment: $needle"
    exit 1
  fi
done

if grep -Eq "buildApprovalPolicyReadinessSection[\s\S]*severity:\s*'blocking'" <<< "$DASHBOARD_CONTENT"; then
  echo "FAIL: buildApprovalPolicyReadinessSection must not assign blocking section severity"
  exit 1
fi

if ! grep -Fq "sectionSeverityFromIssues(issues, 'warning')" <<< "$DASHBOARD_CONTENT"; then
  echo "FAIL: approval policy section must cap severity at warning"
  exit 1
fi

route_needles=(
  "fetchSetupReadinessDashboard"
  "setupReadinessDashboard"
  "StatusPill"
  "setupReadinessDashboard.actions.open"
)

for needle in "${route_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$COMPANY_ROUTE_CONTENT"; then
    echo "FAIL: sirket-kurulum route missing required fragment: $needle"
    exit 1
  fi
done

for needle in "/masraf-kategorileri" "/izin-tanimlari" "/calisanlar"; do
  if ! grep -Fq "$needle" <<< "$DASHBOARD_CONTENT"; then
    echo "FAIL: setup-readiness-dashboard must define navigation target: $needle"
    exit 1
  fi
done

if grep -Fq "fetchOrgSetupReadiness" <<< "$COMPANY_ROUTE_CONTENT"; then
  echo "FAIL: sirket-kurulum must use unified dashboard instead of standalone fetchOrgSetupReadiness"
  exit 1
fi

if ! grep -Fq "setup-readiness-dashboard" <<< "$DATA_INDEX_CONTENT"; then
  echo "FAIL: data index must export setup-readiness-dashboard helpers"
  exit 1
fi

test_needles=(
  "rankSetupReadinessSeverity"
  "combineSetupReadinessSeverity"
  "buildApprovalPolicyReadinessSection"
  "costCenters.unmapped"
  "expense.noActiveCategories"
  "sourceUnknown"
)

for needle in "${test_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$DASHBOARD_TEST_CONTENT"; then
    echo "FAIL: setup-readiness-dashboard tests missing required fragment: $needle"
    exit 1
  fi
done

if ! grep -Fq "never produces blocking severity" <<< "$DASHBOARD_TEST_CONTENT"; then
  echo "FAIL: tests must lock approval policy warning-only behavior"
  exit 1
fi

for key in ready warning blocking unknown; do
  if ! grep -Fq "\"$key\"" "$I18N_TR" || ! grep -Fq "\"$key\"" "$I18N_EN"; then
    echo "FAIL: missing i18n key setupReadinessDashboard.severity.$key"
    exit 1
  fi
done

for key in title subtitle overall generatedAt noneActive open erpNoWrite; do
  if ! grep -Fq "\"$key\"" "$I18N_TR" || ! grep -Fq "\"$key\"" "$I18N_EN"; then
    echo "FAIL: missing i18n key under setupReadinessDashboard: $key"
    exit 1
  fi
done

if ! grep -Fq "costCenters.unmapped" <<< "$DASHBOARD_TEST_CONTENT"; then
  echo "FAIL: tests must cover costCenters.unmapped setup/export blocker"
  exit 1
fi

if ! grep -Fq "Masraf merkezi eşleşmeleri tamamlanmadan" "$I18N_TR"; then
  echo "FAIL: TR i18n must include export-readiness copy for costCenters.unmapped"
  exit 1
fi

if ! grep -Fq "No active records" "$I18N_EN"; then
  echo "FAIL: EN i18n must include counts.noneActive label"
  exit 1
fi

CHANGED_SRC_FILES=()
while IFS= read -r file; do
  [[ -n "$file" ]] && CHANGED_SRC_FILES+=("$file")
done < <(git diff --name-only origin/main...HEAD -- 'src/**' 2>/dev/null || true)

scan_forbidden_in_src() {
  local pattern="$1"
  local label="$2"
  for file in "${CHANGED_SRC_FILES[@]}"; do
    if [[ "$file" == src/i18n/locales/* ]]; then
      continue
    fi
    if [[ -f "$file" ]] && grep -Eiq "$pattern" "$file"; then
      echo "FAIL: forbidden runtime pattern ($label) in changed src file $file: $pattern"
      grep -Ein "$pattern" "$file" || true
      exit 1
    fi
  done
}

if ((${#CHANGED_SRC_FILES[@]} > 0)); then
  scan_forbidden_in_src 'resolveApprover\(|decideApproval\(|importApply\(|puls_integration\(\).*\.(insert|update|upsert|delete)\(' 'resolver-decide-import-runtime'
  scan_forbidden_in_src 'write.*erp' 'write-erp-en'
fi

NAV_FILE="src/lib/navigation.ts"
if git diff --name-only origin/main...HEAD -- "$NAV_FILE" 2>/dev/null | grep -q "$NAV_FILE"; then
  NAV_DIFF="$(git diff origin/main...HEAD -- "$NAV_FILE" 2>/dev/null || true)"
  if grep -Eq '^\+.*setup-readiness|^\+.*sirket-kurulum.*sidebar' <<< "$NAV_DIFF"; then
    echo "FAIL: PR10.17 must not add new sidebar item for setup dashboard"
    exit 1
  fi
fi

echo "OK: PR10.17 setup readiness dashboard checks passed for ${REF}"
