#!/usr/bin/env bash
# Verifies 10 PR10.14 org setup readiness (POSIX grep/awk).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
MATRIX="docs/data/10_org_setup_readiness_matrix.md"
SMOKE="docs/data/10_org_setup_readiness_smoke.sql"
ORG_READINESS="src/lib/data/setup/org-setup-readiness.ts"
ORG_READINESS_TEST="src/lib/data/setup/org-setup-readiness.test.ts"
ORG_ENTITY_SOURCE="src/lib/data/setup/org-entity-source.ts"
ORG_ADAPTER="src/lib/data/core/organization.ts"
ORG_ADAPTER_TEST="src/lib/data/core/organization.test.ts"
CC_ADAPTER="src/lib/data/setup/cost-center-readiness.ts"
DEPT_ROUTE="src/routes/_app/departmanlar.tsx"
POS_ROUTE="src/routes/_app/pozisyonlar.tsx"
COMPANY_ROUTE="src/routes/_app/sirket-kurulum.tsx"
EXPENSE_ROUTE="src/routes/_app/masraf-kategorileri.tsx"
DATA_INDEX="src/lib/data/index.ts"
I18N_TR="src/i18n/locales/tr-TR.json"
I18N_EN="src/i18n/locales/en-US.json"

smoke() {
  git show "${REF}:${SMOKE}" 2>/dev/null || cat "${SMOKE}"
}

file_at_ref() {
  local path="$1"
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

MATRIX_CONTENT="$(file_at_ref "$MATRIX")"
SMOKE_CONTENT="$(smoke)"
ORG_READINESS_CONTENT="$(file_at_ref "$ORG_READINESS")"
ORG_READINESS_TEST_CONTENT="$(file_at_ref "$ORG_READINESS_TEST")"
ORG_ENTITY_SOURCE_CONTENT="$(file_at_ref "$ORG_ENTITY_SOURCE")"
ORG_ADAPTER_CONTENT="$(file_at_ref "$ORG_ADAPTER")"
ORG_ADAPTER_TEST_CONTENT="$(file_at_ref "$ORG_ADAPTER_TEST")"
CC_ADAPTER_CONTENT="$(file_at_ref "$CC_ADAPTER")"
DEPT_ROUTE_CONTENT="$(file_at_ref "$DEPT_ROUTE")"
POS_ROUTE_CONTENT="$(file_at_ref "$POS_ROUTE")"
COMPANY_ROUTE_CONTENT="$(file_at_ref "$COMPANY_ROUTE")"
EXPENSE_ROUTE_CONTENT="$(file_at_ref "$EXPENSE_ROUTE")"
DATA_INDEX_CONTENT="$(file_at_ref "$DATA_INDEX")"

echo "Checking ${REF}: PR10.14 org setup readiness ..."

for file in "$MATRIX" "$SMOKE" "$ORG_READINESS" "$ORG_READINESS_TEST" "$ORG_ENTITY_SOURCE" \
  "$ORG_ADAPTER" "$ORG_ADAPTER_TEST" "$CC_ADAPTER" "$DEPT_ROUTE" "$POS_ROUTE" \
  "$COMPANY_ROUTE" "$EXPENSE_ROUTE" "$DATA_INDEX"; do
  if [[ ! -f "$file" ]]; then
    echo "FAIL: missing required file: $file"
    exit 1
  fi
done

MIGRATION_CHANGES="$(git diff --name-only --diff-filter=A origin/main...HEAD -- supabase/migrations/ 2>/dev/null || true)"
if [[ -n "$(echo "$MIGRATION_CHANGES" | sed '/^$/d')" ]]; then
  echo "FAIL: PR10.14 must not add migrations:"
  echo "$MIGRATION_CHANGES" | sed '/^$/d'
  exit 1
fi

matrix_needles=(
  "Departments"
  "Positions"
  "Cost centers"
  "Employee department assignment"
  "Manager/reporting line"
  "No ERP writes"
)

for needle in "${matrix_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$MATRIX_CONTENT"; then
    echo "FAIL: matrix doc missing required row/topic: $needle"
    exit 1
  fi
done

smoke_needles=(
  "BEGIN;"
  "ROLLBACK;"
  "demo_org_setup_readiness"
  "cross-tenant"
  "single-tenant staging"
  "WHERE tenant_id = v_tenant_id"
  "employee_cost_center_assignments"
  "entity_identity_map"
)

for needle in "${smoke_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$SMOKE_CONTENT"; then
    echo "FAIL: smoke missing required fragment: $needle"
    exit 1
  fi
done

adapter_needles=(
  "fetchOrgSetupReadiness"
  "fetchDepartmentsOverview"
  "fetchPositionsOverview"
  "fetchCostCenterReadinessOverview"
  "computeDepartmentReadinessStatus"
  "computeCostCenterReadinessSummaryStatus"
  "buildOrgSetupReadinessSummary"
)

for needle in "${adapter_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$ORG_READINESS_CONTENT"; then
    echo "FAIL: org-setup-readiness missing required fragment: $needle"
    exit 1
  fi
done

for adapter_content in "$ORG_ADAPTER_CONTENT" "$CC_ADAPTER_CONTENT"; do
  if ! grep -Fq "resolveTenantContext" <<< "$adapter_content"; then
    echo "FAIL: adapter must use resolveTenantContext"
    exit 1
  fi
  if ! grep -Fq ".eq('tenant_id'" <<< "$adapter_content"; then
    echo "FAIL: adapter must tenant-scope queries with .eq('tenant_id'"
    exit 1
  fi
done

if ! grep -Fq "resolveTenantContext" <<< "$ORG_READINESS_CONTENT"; then
  echo "FAIL: fetchOrgSetupReadiness must use resolveTenantContext"
  exit 1
fi

if ! grep -Fq "fetchDepartmentsOverviewWithMeta" <<< "$ORG_ADAPTER_CONTENT"; then
  echo "FAIL: organization adapter must expose fetchDepartmentsOverviewWithMeta"
  exit 1
fi

if ! grep -Fq "fetchCostCenterReadinessOverviewWithMeta" <<< "$CC_ADAPTER_CONTENT"; then
  echo "FAIL: cost-center-readiness must expose fetchCostCenterReadinessOverviewWithMeta"
  exit 1
fi

if ! grep -Fq "computeDepartmentReadinessStatus" <<< "$ORG_READINESS_TEST_CONTENT"; then
  echo "FAIL: org-setup-readiness tests must cover computeDepartmentReadinessStatus"
  exit 1
fi

if ! grep -Fq "computeCostCenterReadinessSummaryStatus" <<< "$ORG_READINESS_TEST_CONTENT"; then
  echo "FAIL: org-setup-readiness tests must cover computeCostCenterReadinessSummaryStatus"
  exit 1
fi

if ! grep -Fq "mapOrgEntitySource" <<< "$ORG_ENTITY_SOURCE_CONTENT"; then
  echo "FAIL: org-entity-source must export mapOrgEntitySource"
  exit 1
fi

if ! grep -Fq "code" <<< "$ORG_ADAPTER_TEST_CONTENT" || ! grep -Fq "isActive" <<< "$ORG_ADAPTER_TEST_CONTENT"; then
  echo "FAIL: organization tests must cover code/isActive row fields"
  exit 1
fi

if ! grep -Fq "fetchDepartmentsOverview" <<< "$DEPT_ROUTE_CONTENT"; then
  echo "FAIL: departmanlar must use fetchDepartmentsOverview"
  exit 1
fi

if ! grep -Fq "fetchPositionsOverview" <<< "$POS_ROUTE_CONTENT"; then
  echo "FAIL: pozisyonlar must use fetchPositionsOverview"
  exit 1
fi

if ! grep -Fq "fetchOrgSetupReadiness" <<< "$COMPANY_ROUTE_CONTENT"; then
  echo "FAIL: sirket-kurulum must use fetchOrgSetupReadiness"
  exit 1
fi

if ! grep -Fq "StatusPill" <<< "$DEPT_ROUTE_CONTENT" || ! grep -Fq "StatusPill" <<< "$POS_ROUTE_CONTENT"; then
  echo "FAIL: dept/pos routes must render StatusPill"
  exit 1
fi

if ! grep -Fq "EmptyState" <<< "$DEPT_ROUTE_CONTENT" || ! grep -Fq "EmptyState" <<< "$POS_ROUTE_CONTENT"; then
  echo "FAIL: dept/pos routes must render EmptyState"
  exit 1
fi

if grep -Fq "common.soon" <<< "$DEPT_ROUTE_CONTENT"; then
  echo "FAIL: departmanlar must not use common.soon stub sheet"
  exit 1
fi

if grep -Fq "common.soon" <<< "$POS_ROUTE_CONTENT"; then
  echo "FAIL: pozisyonlar must not use common.soon stub sheet"
  exit 1
fi

if grep -Fq "SheetShell" <<< "$DEPT_ROUTE_CONTENT" || grep -Fq "SheetShell" <<< "$POS_ROUTE_CONTENT"; then
  echo "FAIL: dept/pos routes must not keep Add stub SheetShell"
  exit 1
fi

if ! grep -Fq "org-setup-readiness" <<< "$DATA_INDEX_CONTENT"; then
  echo "FAIL: data index must export org-setup-readiness helpers"
  exit 1
fi

if ! grep -Fq "orgSetupReadiness.boundary.erpNoWrite" <<< "$EXPENSE_ROUTE_CONTENT"; then
  echo "FAIL: masraf-kategorileri must use shared ERP boundary copy"
  exit 1
fi

for key in ready empty partial unmapped demo_only unknown; do
  if ! grep -Fq "\"$key\"" "$I18N_TR" || ! grep -Fq "\"$key\"" "$I18N_EN"; then
    echo "FAIL: missing i18n key orgSetupReadiness.status.$key"
    exit 1
  fi
done

for key in departments positions costCenters erpNoWrite readOnly crudDeferred; do
  if ! grep -Fq "\"$key\"" "$I18N_TR" || ! grep -Fq "\"$key\"" "$I18N_EN"; then
    echo "FAIL: missing i18n key under orgSetupReadiness (metrics/empty/boundary): $key"
    exit 1
  fi
done

CHANGED_SRC_FILES=()
while IFS= read -r file; do
  [[ -n "$file" ]] && CHANGED_SRC_FILES+=("$file")
done < <(git diff --name-only origin/main...HEAD -- 'src/**' 2>/dev/null || true)

scan_forbidden_in_src() {
  local pattern="$1"
  local label="$2"
  for file in "${CHANGED_SRC_FILES[@]}"; do
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
  scan_forbidden_in_src '\bsync\b.*erp' 'sync-erp-en'
  scan_forbidden_in_src 'push.*erp' 'push-erp-en'
  scan_forbidden_in_src 'supabase\.functions\.invoke' 'supabase-functions-invoke'
  scan_forbidden_in_src '\.from\('"'"'departments'"'"'\).*\.(insert|update|upsert|delete)\(' 'department-master-mutations'
  scan_forbidden_in_src '\.from\('"'"'positions'"'"'\).*\.(insert|update|upsert|delete)\(' 'position-master-mutations'
fi

echo "OK: PR10.14 org setup readiness checks passed for ${REF}"
