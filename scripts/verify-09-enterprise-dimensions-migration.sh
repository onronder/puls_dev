#!/usr/bin/env bash
# Verifies 09 PR2 enterprise dimensions migration SQL invariants (POSIX grep; no rg).
set -euo pipefail

REF="${1:-origin/cursor/09-enterprise-dimensions-b5b2}"
FILE="supabase/migrations/20260525150000_puls_core_enterprise_dimensions.sql"

sql() {
  git show "${REF}:${FILE}" 2>/dev/null || cat "${FILE}"
}

CONTENT="$(sql)"

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
  "Cache only; SoT is employee_location_assignments"
  "Cache only; SoT is employee_cost_center_assignments"
  "sync_employee_legal_entity_from_assignments"
  "sync_employee_location_from_assignments"
  "sync_employee_cost_center_from_assignments"
  "AFTER INSERT OR UPDATE OR DELETE"
  "legal_entities"
  "locations"
  "cost_centers"
  "PULS_IDENTITY_MAP_TYPE_MISMATCH"
  "NEW.entity_type::TEXT"
  "REVOKE ALL ON FUNCTION puls_core.sync_employee_legal_entity_from_assignments"
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

# Enum trap: ADD VALUE present but no same-file enum cast usage for new labels
if grep -Fq "ADD VALUE IF NOT EXISTS 'legal_entity'" <<< "$CONTENT"; then
  for label in legal_entity location cost_center; do
    if grep -E "'${label}'::puls_integration\\.import_entity_type" <<< "$CONTENT" >/dev/null 2>&1; then
      echo "FAIL: same-transaction enum usage detected for ${label} (::import_entity_type cast)"
      exit 1
    fi
  done
fi

echo "OK: 09 PR2 migration structural checks passed for ${REF}"
