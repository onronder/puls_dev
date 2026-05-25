#!/usr/bin/env bash
# Verifies 09 PR2 enterprise dimensions migration SQL invariants (POSIX grep; no rg).
set -euo pipefail

REF="${1:-origin/cursor/09-enterprise-dimensions-b5b2}"
FILE="supabase/migrations/20260525150000_puls_core_enterprise_dimensions.sql"
SMOKE="docs/data/09_enterprise_dimensions_smoke.sql"

sql() {
  git show "${REF}:${FILE}" 2>/dev/null || cat "${FILE}"
}

smoke() {
  git show "${REF}:${SMOKE}" 2>/dev/null || cat "${SMOKE}"
}

CONTENT="$(sql)"
SMOKE_CONTENT="$(smoke)"

echo "Checking ${REF}:${FILE} ..."

needles=(
  "CREATE TABLE IF NOT EXISTS puls_core.legal_entities"
  "CREATE TABLE IF NOT EXISTS puls_core.locations"
  "CREATE TABLE IF NOT EXISTS puls_core.cost_centers"
  "CREATE TABLE IF NOT EXISTS puls_core.employee_legal_entity_assignments"
  "CREATE TABLE IF NOT EXISTS puls_core.employee_location_assignments"
  "CREATE TABLE IF NOT EXISTS puls_core.employee_cost_center_assignments"
  "idx_puls_core_emp_le_assign_one_active"
  "idx_puls_core_emp_loc_assign_one_active"
  "idx_puls_core_emp_cc_assign_one_active"
  "WHERE is_active = TRUE"
  "Cache only; SoT is employee_legal_entity_assignments"
  "detect_cost_center_cycle"
  "PULS_COST_CENTER_CYCLE"
  "validate_employee_dimension_cache"
  "puls_core_employees_validate_dimension_cache"
  "BEFORE UPDATE OF legal_entity_id, location_id, cost_center_id"
  "sync_employee_legal_entity_from_assignments"
  "AFTER INSERT OR UPDATE OR DELETE"
  "PULS_IDENTITY_MAP_TYPE_MISMATCH"
  "NEW.entity_type::TEXT"
  "GRANT ALL ON puls_core.legal_entities TO service_role"
  "GRANT ALL ON puls_core.employee_cost_center_assignments TO service_role"
  "can_read_employee(employee_id)"
)

for needle in "${needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$CONTENT"; then
    echo "FAIL: missing required fragment: $needle"
    exit 1
  fi
done

if grep -E "owner_employee_id[[:space:]]+(UUID|uuid)" <<< "$CONTENT" >/dev/null 2>&1; then
  echo "FAIL: owner_employee_id column must not appear in PR2 dimensions migration"
  exit 1
fi

if grep -Fq "authority_relationships" <<< "$CONTENT"; then
  echo "FAIL: authority_relationships must not appear in PR2"
  exit 1
fi

if grep -E "search_path = .*\\bpublic\\b" <<< "$CONTENT" >/dev/null 2>&1; then
  echo "FAIL: functions must not include public in search_path"
  exit 1
fi

if grep -Fq "digest(" <<< "$CONTENT"; then
  echo "FAIL: unqualified digest() must not be used"
  exit 1
fi

if grep -Fq "ADD VALUE IF NOT EXISTS 'legal_entity'" <<< "$CONTENT"; then
  for label in legal_entity location cost_center; do
    if grep -E "'${label}'::puls_integration\\.import_entity_type" <<< "$CONTENT" >/dev/null 2>&1; then
      echo "FAIL: same-transaction enum usage detected for ${label} (::import_entity_type cast)"
      exit 1
    fi
  done
fi

echo "Checking ${REF}:${SMOKE} ..."

smoke_needles=(
  "PULS_COST_CENTER_CYCLE"
  "PULS_EMPLOYEE_CACHE_BYPASS"
  "PULS_LOCATION_INVALID_LEGAL_ENTITY"
  "PULS_DEPARTMENT_INVALID_COST_CENTER"
  "PULS_IDENTITY_MAP_TYPE_MISMATCH"
  "assignment DELETE"
)

for needle in "${smoke_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$SMOKE_CONTENT"; then
    echo "FAIL: smoke missing executable negative/assertion: $needle"
    exit 1
  fi
done

if grep -E "^-- Manual negative checks" <<< "$SMOKE_CONTENT" >/dev/null 2>&1; then
  echo "FAIL: smoke must not leave negative checks as comment-only section"
  exit 1
fi

echo "OK: 09 PR2 migration structural checks passed for ${REF}"
