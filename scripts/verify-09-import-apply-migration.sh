#!/usr/bin/env bash
# Verifies 09 PR4 import apply migration SQL invariants (POSIX grep/awk; no rg).
set -euo pipefail

REF="${1:-HEAD}"
FILE="supabase/migrations/20260525160000_puls_integration_import_apply.sql"
SMOKE="docs/data/09_import_apply_smoke.sql"

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
  "CREATE OR REPLACE FUNCTION puls_integration.validate_import_batch"
  "CREATE OR REPLACE FUNCTION puls_integration.preview_import_diff"
  "CREATE OR REPLACE FUNCTION puls_integration.apply_import_batch"
  "FOR UPDATE"
  "PULS_IMPORT_CROSS_TENANT"
  "PULS_IMPORT_BATCH_STATE_INVALID"
  "AMBIGUOUS_REFERENCE"
  "UNCHANGED_ROW_HASH"
  "LOWER_PRIORITY_SOURCE_SKIPPED"
  "employee_legal_entity_assignments"
  "employee_location_assignments"
  "employee_cost_center_assignments"
  "entity_identity_map"
  "_import_check_ref"
  "upsert_primary_reporting_line"
  "REVOKE ALL ON FUNCTION puls_integration.validate_import_batch"
  "GRANT EXECUTE ON FUNCTION puls_integration.apply_import_batch"
)

for needle in "${needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$CONTENT"; then
    echo "FAIL: missing required fragment: $needle"
    exit 1
  fi
done

if grep -v '^[[:space:]]*--' <<< "$CONTENT" | grep -Eiq 'raw_payload[[:space:]]*='; then
  echo "FAIL: migration must not assign raw_payload"
  exit 1
fi

if grep -Fq "decide_approval_request" <<< "$CONTENT"; then
  echo "FAIL: decide_approval_request must not appear in PR4 migration"
  exit 1
fi

if grep -Fq "resolve_policy_step_approver" <<< "$CONTENT"; then
  echo "FAIL: resolve_policy_step_approver must not appear in PR4 migration"
  exit 1
fi

if grep -E "search_path = .*\\bpublic\\b" <<< "$CONTENT" >/dev/null 2>&1; then
  echo "FAIL: functions must not include public in search_path"
  exit 1
fi

if grep -Eiq "hris|trusted_erp" <<< "$CONTENT"; then
  echo "FAIL: migration must not reference hris or trusted_erp"
  exit 1
fi

if grep -Eiq "authority_pools|authority_relationships" <<< "$CONTENT" | grep -v '^[[:space:]]*--' >/dev/null 2>&1; then
  if grep -v '^[[:space:]]*--' <<< "$CONTENT" | grep -Eiq "INSERT INTO.*authority_pools|INSERT INTO.*authority_relationships|UPDATE.*authority_pools|UPDATE.*authority_relationships"; then
    echo "FAIL: migration must not write authority graph tables"
    exit 1
  fi
fi

if grep -Eiq "PROCEDURE[[:space:]]+check_ref" <<< "$CONTENT"; then
  echo "FAIL: migration must not use nested PROCEDURE check_ref (invalid plpgsql)"
  exit 1
fi

if grep -Fq "request.jwt.claim.role" <<< "$SMOKE_CONTENT"; then
  :
else
  echo "FAIL: smoke must set request.jwt.claim.role for service_role RPC context"
  exit 1
fi

# Cache column writes on employees (blocker #8)
if awk '
  /UPDATE[[:space:]]+puls_core\.employees/ { in_upd = 1; buf = $0; next }
  in_upd {
    buf = buf "\n" $0
    if (/;/) {
      if (buf ~ /legal_entity_id[[:space:]]*=|location_id[[:space:]]*=|cost_center_id[[:space:]]*=/) {
        exit 1
      }
      in_upd = 0
      buf = ""
    }
  }
' <<< "$CONTENT"; then
  :
else
  echo "FAIL: UPDATE puls_core.employees must not set legal_entity_id, location_id, or cost_center_id"
  exit 1
fi

if grep -v '^[[:space:]]*--' <<< "$CONTENT" | grep -Eiq "INSERT INTO[[:space:]]+puls_core\.employees[[:space:]]*\([^)]*(legal_entity_id|location_id|cost_center_id)"; then
  echo "FAIL: INSERT INTO puls_core.employees must not include cache dimension columns"
  exit 1
fi

# No fake source=import on dimension tables
for dim_table in legal_entities locations cost_centers; do
  if grep -v '^[[:space:]]*--' <<< "$CONTENT" | grep -Eiq "(INSERT INTO|UPDATE)[[:space:]]+puls_core\.${dim_table}[^;]*source[[:space:]]*=[[:space:]]*'import'"; then
    echo "FAIL: must not set source='import' on puls_core.${dim_table}"
    exit 1
  fi
done

# No per-row exception swallow around canonical DML
if grep -Eiq "EXCEPTION[[:space:]]+WHEN" <<< "$CONTENT" | grep -v '^[[:space:]]*--' >/dev/null 2>&1; then
  echo "FAIL: apply_import_batch must not use EXCEPTION handlers (no per-row swallowing)"
  exit 1
fi

echo "Checking ${REF}:${SMOKE} ..."

smoke_needles=(
  "BEGIN;"
  "ROLLBACK;"
  "SELECT puls_integration.create_import_batch"
  "SELECT puls_integration.record_import_row"
  "SELECT puls_integration.validate_import_batch"
  "SELECT puls_integration.preview_import_diff"
  "SELECT puls_integration.apply_import_batch"
  "PULS_IMPORT_DRY_RUN"
  "AMBIGUOUS_REFERENCE"
  "LOWER_PRIORITY_SOURCE_SKIPPED"
  "UNRESOLVED_REFERENCE"
)

for needle in "${smoke_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$SMOKE_CONTENT"; then
    echo "FAIL: smoke missing required fragment: $needle"
    exit 1
  fi
done

if grep -E "^-- Manual negative checks" <<< "$SMOKE_CONTENT" >/dev/null 2>&1; then
  echo "FAIL: smoke must not leave negative checks as comment-only section"
  exit 1
fi

echo "OK: 09 PR4 import apply migration structural checks passed for ${REF}"
