#!/usr/bin/env bash
# Verifies the 09 PR4 import lookup UUID aggregate hotfix.
set -euo pipefail

REF="${1:-HEAD}"
FILE="supabase/migrations/20260525164000_puls_integration_import_lookup_uuid_fix.sql"
SMOKE="docs/data/09_import_apply_smoke.sql"

sql() {
  git show "${REF}:${FILE}" 2>/dev/null || cat "${FILE}"
}

smoke() {
  git show "${REF}:${SMOKE}" 2>/dev/null || cat "${SMOKE}"
}

CONTENT="$(sql)"
SMOKE_CONTENT="$(smoke)"
NON_COMMENT="$(grep -v '^[[:space:]]*--' <<< "$CONTENT")"

echo "Checking ${REF}:${FILE} ..."

needles=(
  "CREATE OR REPLACE FUNCTION puls_integration._import_lookup_by_code"
  "CREATE OR REPLACE FUNCTION puls_integration._import_lookup_employee"
  "array_agg(le.id ORDER BY le.id)"
  "array_agg(loc.id ORDER BY loc.id)"
  "array_agg(cc.id ORDER BY cc.id)"
  "array_agg(d.id ORDER BY d.id)"
  "array_agg(p.id ORDER BY p.id)"
  "array_agg(e.id ORDER BY e.id)"
)

for needle in "${needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$CONTENT"; then
    echo "FAIL: missing required fragment: $needle"
    exit 1
  fi
done

if grep -Eiq '\bMIN[[:space:]]*\(' <<< "$NON_COMMENT"; then
  echo "FAIL: hotfix migration must not use MIN("
  exit 1
fi

for forbidden in \
  "CREATE OR REPLACE FUNCTION puls_integration.validate_import_batch" \
  "CREATE OR REPLACE FUNCTION puls_integration.preview_import_diff" \
  "CREATE OR REPLACE FUNCTION puls_integration.apply_import_batch" \
  "decide_approval_request" \
  "resolve_policy_step_approver"; do
  if grep -Fq "$forbidden" <<< "$NON_COMMENT"; then
    echo "FAIL: hotfix migration must not touch: $forbidden"
    exit 1
  fi
done

fn_count="$(grep -Ec '^[[:space:]]*CREATE OR REPLACE FUNCTION puls_integration\._import_lookup_(by_code|employee)\b' <<< "$NON_COMMENT")"
if [ "$fn_count" -ne 2 ]; then
  echo "FAIL: hotfix migration must redefine exactly the two lookup functions"
  exit 1
fi

echo "Checking ${REF}:${SMOKE} ..."

for needle in \
  "single-match natural-key lookup exercises UUID deterministic pick" \
  "puls_integration._import_lookup_by_code" \
  "SMOKE_FAIL: expected single-match legal_entity lookup"; do
  if ! grep -Fq "$needle" <<< "$SMOKE_CONTENT"; then
    echo "FAIL: import apply smoke missing required fragment: $needle"
    exit 1
  fi
done

echo "OK: 09 PR4 import lookup UUID hotfix structural checks passed for ${REF}"
