#!/usr/bin/env bash
# Verifies PR13.5 seed bootstrap proof pack (scenario SQL, docs, verify guardrails).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
VERIFY_SCRIPT="scripts/verify-13-seed-bootstrap-proof.sh"
PACK="supabase/seed/puls-sanayi-v1"

ROUTES=(
  "/dashboard"
  "/sirket-kurulum"
  "/calisanlar"
  "/departmanlar"
  "/pozisyonlar"
  "/izin-tanimlari"
  "/izin"
  "/masraf-kategorileri"
  "/masraf"
  "/performans"
  "/performans-parametreleri"
  "/kariyer"
  "/egitim"
  "/is-degerleme"
  "/sozlesmeler"
  "/profil"
  "/ayarlar"
  "/erp"
  "/ai-koc"
  "/menu"
)

file_at_ref() {
  local path="$1"
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

echo "Checking ${REF}: PR13.5 seed bootstrap proof ..."

REQUIRED_FILES=(
  "${PACK}/sql/03_generate_workflow_scenarios.sql"
  "${PACK}/sql/04_generate_performance_scenarios.sql"
  "${PACK}/sql/05_link_auth_personas_template.sql"
  "${PACK}/sql/06_jwt_mutation_proof_smoke.sql"
  "${PACK}/sql/07_validate_packaging_proof.sql"
  "docs/product/13_seed_bootstrap_proof_runbook.md"
  "docs/product/13_route_packaging_proof_matrix.md"
  "scripts/run-13-puls-sanayi-proof.sh"
  "$VERIFY_SCRIPT"
  "${PACK}/sql/00_reset_puls_sanayi_seed.sql"
  "${PACK}/sql/01_load_puls_sanayi_seed.sql"
  "${PACK}/manifest.json"
)

for f in "${REQUIRED_FILES[@]}"; do
  if ! file_at_ref "$f" >/dev/null; then
    echo "FAIL: missing required file: $f"
    exit 1
  fi
done

RUNBOOK="$(file_at_ref docs/product/13_seed_bootstrap_proof_runbook.md)"
MATRIX="$(file_at_ref docs/product/13_route_packaging_proof_matrix.md)"
SQL03="$(file_at_ref "${PACK}/sql/03_generate_workflow_scenarios.sql")"
SQL04="$(file_at_ref "${PACK}/sql/04_generate_performance_scenarios.sql")"
SQL05="$(file_at_ref "${PACK}/sql/05_link_auth_personas_template.sql")"
SQL06="$(file_at_ref "${PACK}/sql/06_jwt_mutation_proof_smoke.sql")"
SQL07="$(file_at_ref "${PACK}/sql/07_validate_packaging_proof.sql")"
RUNNER="$(file_at_ref scripts/run-13-puls-sanayi-proof.sh)"

doc_needles=(
  "VITE_PULS_DEMO_MODE=false"
  "source: real"
  "source: demo is not packaging proof"
  "external_source='pr13_scenario'"
  "legacy_public_tenant_id"
  "two-layer proof"
  "Canias"
  "metadata seed only"
)

for needle in "${doc_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$RUNBOOK"; then
    echo "FAIL: runbook missing needle: $needle"
    exit 1
  fi
done

for route in "${ROUTES[@]}"; do
  if ! grep -Fq "$route" <<< "$MATRIX"; then
    echo "FAIL: route matrix missing route: $route"
    exit 1
  fi
done

# 03: no executable lifecycle RPC calls; approval columns present
if grep -E '(PERFORM|SELECT)[[:space:]]+puls_workflow\.(deactivate_|restore_)' <<< "$SQL03"; then
  echo "FAIL: 03 must not execute lifecycle RPCs (PERFORM/SELECT puls_workflow.deactivate_/restore_)"
  exit 1
fi
if ! grep -Fq "approval_policy_id" <<< "$SQL03"; then
  echo "FAIL: 03 missing approval_policy_id in scenario inserts"
  exit 1
fi
if ! grep -Fq "approval_requests" <<< "$SQL03" || ! grep -A12 "INSERT INTO puls_workflow.approval_requests" <<< "$SQL03" | grep -Fq "approval_policy_id"; then
  echo "FAIL: 03 approval_requests must set approval_policy_id"
  exit 1
fi
if ! grep -Fq "Delete order" <<< "$SQL03"; then
  echo "FAIL: 03 missing delete order documentation"
  exit 1
fi
if ! grep -Fq "deactivate_leave_type" <<< "$SQL03"; then
  echo "FAIL: 03 should document lifecycle RPC ban in comments"
  exit 1
fi

if ! grep -Fq "Delete order" <<< "$SQL04"; then
  echo "FAIL: 04 missing delete order documentation"
  exit 1
fi

# 05/06: conditional psql defaults + NULLIF; no auth.users; legacy gate
check_conditional_psql_defaults() {
  local sql_file="$1"
  local label="$2"
  if ! grep -Fq ':{?admin_user_id}' <<< "$sql_file"; then
    echo "FAIL: ${label} missing conditional psql default \\if :{?admin_user_id}"
    exit 1
  fi
  if grep -Pzo '(?s)\\if :\\{\\?admin_user_id\\}\\s*\\n\\set admin_user_id' <<< "$sql_file" >/dev/null 2>&1; then
    echo "FAIL: ${label} unconditional \\set admin_user_id (must be inside \\else after \\if :{?admin_user_id})"
    exit 1
  fi
  if ! grep -Fq "NULLIF" <<< "$sql_file"; then
    echo "FAIL: ${label} missing NULLIF empty -v handling"
    exit 1
  fi
  if ! grep -Fq "pr13_psql_vars" <<< "$sql_file"; then
    echo "FAIL: ${label} must stage psql vars in pr13_psql_vars temp table (outside DO body)"
    exit 1
  fi
  local do_body
  do_body="$(sed -n '/^DO \$\$/,/^END \$\$;/p' <<< "$sql_file")"
  if grep -Fq ":'admin_user_id'" <<< "$do_body"; then
    echo "FAIL: ${label} must not use :'admin_user_id' inside DO $$ body"
    exit 1
  fi
  if grep -Fq ":'employee_user_id'" <<< "$do_body"; then
    echo "FAIL: ${label} must not use :'employee_user_id' inside DO $$ body"
    exit 1
  fi
  if grep -Fq ":'manager_user_id'" <<< "$do_body"; then
    echo "FAIL: ${label} must not use :'manager_user_id' inside DO $$ body"
    exit 1
  fi
}

check_conditional_psql_defaults "$SQL05" "05"
check_conditional_psql_defaults "$SQL06" "06"

if grep -Fi "INSERT INTO auth.users" <<< "$SQL05"; then
  echo "FAIL: 05 must not INSERT INTO auth.users"
  exit 1
fi
if ! grep -Fq "'approved'" <<< "$SQL06"; then
  echo "FAIL: 06 must call decide_approval_request with approved"
  exit 1
fi
if grep -Fq "'approve'" <<< "$SQL06"; then
  echo "FAIL: 06 must not use invalid decide decision approve"
  exit 1
fi
if ! grep -Fq "pr13_psql_vars" <<< "$SQL05"; then
  echo "FAIL: 05 must stage psql vars in pr13_psql_vars temp table"
  exit 1
fi
if ! grep -Fq "information_schema.columns" <<< "$SQL05"; then
  echo "FAIL: 05 missing information_schema.columns guard for public bridge"
  exit 1
fi
if grep -Fq "v_tenant" <<< "$SQL05" && grep -E "user_tenants.*v_tenant" <<< "$SQL05"; then
  echo "FAIL: 05 must not use puls_core.tenants.id as public tenant id"
  exit 1
fi
if grep -E 'ON CONFLICT' <<< "$SQL05"; then
  echo "FAIL: 05 must not use ON CONFLICT on public bridge (use WHERE NOT EXISTS)"
  exit 1
fi

# 06: JWT + ROLLBACK + reserved lifecycle targets
if ! grep -Fq "request.jwt.claim.role" <<< "$SQL06"; then
  echo "FAIL: 06 missing request.jwt.claim.role"
  exit 1
fi
if ! grep -Fq "request.jwt.claim.sub" <<< "$SQL06"; then
  echo "FAIL: 06 missing request.jwt.claim.sub"
  exit 1
fi
if ! grep -Fq "ROLLBACK" <<< "$SQL06"; then
  echo "FAIL: 06 missing ROLLBACK"
  exit 1
fi
if ! grep -Fq "000000000006" <<< "$SQL06"; then
  echo "FAIL: 06 missing lifecycle-smoke-reserved leave type (UCRETSIZ)"
  exit 1
fi
if ! grep -Fq "000000000008" <<< "$SQL06"; then
  echo "FAIL: 06 missing lifecycle-smoke-reserved expense category (HED)"
  exit 1
fi
if ! grep -Fq "JWT smoke fail: employee current_employee_id" <<< "$SQL06"; then
  echo "FAIL: 06 must RAISE EXCEPTION on employee mapping mismatch when UUID provided"
  exit 1
fi
if ! grep -Fq "JWT smoke fail: decide_approval_request unexpected status" <<< "$SQL06"; then
  echo "FAIL: 06 must fail on unexpected decide_approval_request result"
  exit 1
fi

# 07: source=demo column-aware + remaining_days guard
if ! grep -Fq "remaining_days < 0" <<< "$SQL07"; then
  echo "FAIL: 07 missing negative remaining_days guard"
  exit 1
fi
if ! grep -Fq "employee_reporting_lines" <<< "$SQL07"; then
  echo "FAIL: 07 missing column-aware source=demo check"
  exit 1
fi

if ! grep -Fq 'DATABASE_URL' <<< "$RUNNER"; then
  echo "FAIL: runner must use DATABASE_URL"
  exit 1
fi
if grep -Ei '(password|secret|token)=' <<< "$RUNNER"; then
  echo "FAIL: runner must not hardcode credentials"
  exit 1
fi

# Diff guard: forbid modifying PR13.4 baseline artifacts (allow PR13.4 additions when stacked)
BASE_REF="$(git merge-base "${REF}" origin/main 2>/dev/null || echo "")"
if [[ -n "$BASE_REF" && "$BASE_REF" != "$REF" ]]; then
  CHANGED=$(git diff --name-only "$BASE_REF" "$REF" -- \
    "${PACK}/csv" \
    "${PACK}/manifest.json" \
    src \
    supabase/migrations \
    2>/dev/null || true)
  if [[ -n "$CHANGED" ]]; then
    while IFS= read -r path; do
      [[ -z "$path" ]] && continue
      if git cat-file -e "${BASE_REF}:${path}" 2>/dev/null; then
        echo "FAIL: forbidden modification vs merge-base: $path"
        exit 1
      fi
    done <<< "$CHANGED"
  fi
fi

echo "OK: PR13.5 seed bootstrap proof verification passed"
