#!/usr/bin/env bash
# Verifies 11 PR11.2 org setup CRUD readiness (POSIX grep/awk).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
MATRIX="docs/data/11_org_setup_crud_readiness_matrix.md"
SMOKE="docs/data/11_org_setup_crud_readiness_smoke.sql"
MIGRATION="supabase/migrations/20260529110000_puls_core_org_setup_guardrails.sql"
VALIDATION="src/lib/data/setup/org-setup-validation.ts"
VALIDATION_TEST="src/lib/data/setup/org-setup-validation.test.ts"
ORG_ADAPTER="src/lib/data/core/organization.ts"
ORG_ADAPTER_TEST="src/lib/data/core/organization.test.ts"
ORG_ENTITY_SOURCE="src/lib/data/setup/org-entity-source.ts"
DEPT_ROUTE="src/routes/_app/departmanlar.tsx"
POS_ROUTE="src/routes/_app/pozisyonlar.tsx"
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
MIGRATION_CONTENT="$(file_at_ref "$MIGRATION")"
VALIDATION_CONTENT="$(file_at_ref "$VALIDATION")"
VALIDATION_TEST_CONTENT="$(file_at_ref "$VALIDATION_TEST")"
ORG_ADAPTER_CONTENT="$(file_at_ref "$ORG_ADAPTER")"
ORG_ADAPTER_TEST_CONTENT="$(file_at_ref "$ORG_ADAPTER_TEST")"
DEPT_ROUTE_CONTENT="$(file_at_ref "$DEPT_ROUTE")"
POS_ROUTE_CONTENT="$(file_at_ref "$POS_ROUTE")"
DATA_INDEX_CONTENT="$(file_at_ref "$DATA_INDEX")"

echo "Checking ${REF}: PR11.2 org setup CRUD readiness ..."

for file in "$MATRIX" "$SMOKE" "$MIGRATION" "$VALIDATION" "$VALIDATION_TEST" \
  "$ORG_ADAPTER" "$ORG_ADAPTER_TEST" "$ORG_ENTITY_SOURCE" "$DEPT_ROUTE" "$POS_ROUTE" "$DATA_INDEX"; do
  if [[ ! -f "$file" ]]; then
    echo "FAIL: missing required file: $file"
    exit 1
  fi
done

MIGRATION_CHANGES=()
while IFS= read -r file; do
  [[ -n "$file" ]] && MIGRATION_CHANGES+=("$file")
done < <(git diff --name-only --diff-filter=A origin/main...HEAD -- supabase/migrations/ 2>/dev/null || true)

if ((${#MIGRATION_CHANGES[@]} != 1)); then
  echo "FAIL: PR11.2 must add exactly one migration (found ${#MIGRATION_CHANGES[@]})"
  printf '%s\n' "${MIGRATION_CHANGES[@]:-}"
  exit 1
fi

if [[ "${MIGRATION_CHANGES[0]}" != "$MIGRATION" ]]; then
  echo "FAIL: expected migration $MIGRATION, got ${MIGRATION_CHANGES[0]}"
  exit 1
fi

matrix_needles=(
  "Writable vs read-only"
  "source-aware mixed CRUD"
  "employee dept/position assignment"
  "No ERP"
  "read_only"
)

for needle in "${matrix_needles[@]}"; do
  if ! grep -Fiq "$needle" <<< "$MATRIX_CONTENT"; then
    echo "FAIL: matrix missing topic: $needle"
    exit 1
  fi
done

smoke_needles=(
  "BEGIN;"
  "ROLLBACK;"
  "demo_org_setup_crud_"
  "NULLIF(BTRIM(OLD.external_source)"
  "PULS_ORG_DEPARTMENT_SOURCE_READ_ONLY"
  "PULS_ORG_POSITION_SOURCE_READ_ONLY"
  "cross-tenant"
)

for needle in "${smoke_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$SMOKE_CONTENT"; then
    echo "FAIL: smoke missing fragment: $needle"
    exit 1
  fi
done

migration_needles=(
  "validate_department_setup_guardrails"
  "validate_position_setup_guardrails"
  "puls_core_departments_validate_setup_guardrails"
  "puls_core_positions_validate_setup_guardrails"
  "PULS_ORG_DEPARTMENT_SOURCE_READ_ONLY"
  "PULS_ORG_POSITION_SOURCE_READ_ONLY"
  "PULS_ORG_DEPARTMENT_CODE_INVALID"
  "PULS_ORG_POSITION_NORM_INVALID"
)

for needle in "${migration_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION_CONTENT"; then
    echo "FAIL: migration missing fragment: $needle"
    exit 1
  fi
done

adapter_needles=(
  "createDepartment"
  "updateDepartment"
  "createPosition"
  "updatePosition"
  "mapDepartmentMutationError"
  "mapPositionMutationError"
  "resolveTenantContext"
  ".eq('tenant_id'"
  "isEditable"
)

for needle in "${adapter_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$ORG_ADAPTER_CONTENT"; then
    echo "FAIL: organization adapter missing fragment: $needle"
    exit 1
  fi
done

validation_needles=(
  "validateDepartmentForm"
  "validatePositionForm"
  "normalizeOrgSetupCode"
  "isDepartmentFormDirty"
  "isPositionFormDirty"
)

for needle in "${validation_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$VALIDATION_CONTENT"; then
    echo "FAIL: validation module missing fragment: $needle"
    exit 1
  fi
done

for needle in validateDepartmentForm validatePositionForm; do
  if ! grep -Fq "$needle" <<< "$VALIDATION_TEST_CONTENT"; then
    echo "FAIL: validation tests must cover $needle"
    exit 1
  fi
done

for needle in mapDepartmentMutationError isOrgEntityEditable; do
  if ! grep -Fq "$needle" <<< "$ORG_ADAPTER_TEST_CONTENT"; then
    echo "FAIL: organization tests must cover $needle"
    exit 1
  fi
done

for needle in validateDepartmentForm createDepartment orgSetupCrud.boundary.sourceReadOnly; do
  if ! grep -Fq "$needle" <<< "$DEPT_ROUTE_CONTENT"; then
    echo "FAIL: departmanlar route missing fragment: $needle"
    exit 1
  fi
done

for needle in validatePositionForm createPosition orgSetupCrud.boundary.sourceReadOnly; do
  if ! grep -Fq "$needle" <<< "$POS_ROUTE_CONTENT"; then
    echo "FAIL: pozisyonlar route missing fragment: $needle"
    exit 1
  fi
done

if grep -Fq "common.soon" <<< "$DEPT_ROUTE_CONTENT" || grep -Fq "common.soon" <<< "$POS_ROUTE_CONTENT"; then
  echo "FAIL: dept/position routes must not use common.soon"
  exit 1
fi

for key in createDepartment createPosition save sourceReadOnly; do
  if ! grep -Fq "\"$key\"" "$I18N_TR" || ! grep -Fq "\"$key\"" "$I18N_EN"; then
    echo "FAIL: missing orgSetupCrud i18n key containing $key"
    exit 1
  fi
done

CHANGED_FILES=()
while IFS= read -r file; do
  [[ -n "$file" ]] && CHANGED_FILES+=("$file")
done < <(git diff --name-only origin/main...HEAD -- 'src/**' 2>/dev/null || true)

scan_forbidden() {
  local pattern="$1"
  local label="$2"
  for file in "${CHANGED_FILES[@]}"; do
    if [[ -f "$file" ]] && grep -Eiq "$pattern" "$file"; then
      echo "FAIL: forbidden pattern ($label) in $file"
      grep -Ein "$pattern" "$file" || true
      exit 1
    fi
  done
}

if ((${#CHANGED_FILES[@]} > 0)); then
  scan_forbidden 'resolveApprover\(|decideApproval\(|importApply\(' 'resolver-decide-import-runtime'
  scan_forbidden 'supabase\.functions\.invoke' 'supabase-functions-invoke'
  scan_forbidden 'write.*erp' 'write-erp-en'
  scan_forbidden '\bsync\b.*erp' 'sync-erp-en'
  scan_forbidden 'push.*erp' 'push-erp-en'
  scan_forbidden 'ERP'"'"'ye yaz' 'erp-write-tr'
  scan_forbidden 'deactivate_department|restore_department|deactivate_position|restore_position' 'lifecycle-rpc'
  scan_forbidden '\.from\('"'"'employees'"'"'\).*\.(insert|update|upsert|delete)\(' 'employee-mutations'
  scan_forbidden '\.from\('"'"'employee_cost_center_assignments'"'"'\).*\.(insert|update|upsert|delete)\(' 'cc-assignment-mutations'
  scan_forbidden '\.from\('"'"'employee_reporting_lines'"'"'\).*\.(insert|update|upsert|delete)\(' 'reporting-line-mutations'
  scan_forbidden '\.from\('"'"'departments'"'"'\).*\.delete\(|\.from\('"'"'positions'"'"'\).*\.delete\(' 'hard-delete'
fi

echo "OK: PR11.2 org setup CRUD readiness checks passed for ${REF}"
