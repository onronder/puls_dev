#!/usr/bin/env bash
# PR13.5 — Run Puls Sanayi baseline + scenario proof (requires DATABASE_URL).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACK="${ROOT}/supabase/seed/puls-sanayi-v1"

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "FAIL: DATABASE_URL is required"
  exit 1
fi

cd "$PACK"

echo "== PR13.5 Puls Sanayi proof runner =="
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/00_reset_puls_sanayi_seed.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/01_load_puls_sanayi_seed.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/03_generate_workflow_scenarios.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/04_generate_performance_scenarios.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/07_validate_packaging_proof.sql

if [[ -n "${admin_user_id:-}" \
   || -n "${hr_admin_user_id:-}" \
   || -n "${manager_user_id:-}" \
   || -n "${employee_user_id:-}" \
   || -n "${incomplete_setup_user_id:-}" ]]; then
  echo "== Optional auth/JWT smoke =="
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 \
    ${admin_user_id:+-v "admin_user_id=${admin_user_id}"} \
    ${hr_admin_user_id:+-v "hr_admin_user_id=${hr_admin_user_id}"} \
    ${manager_user_id:+-v "manager_user_id=${manager_user_id}"} \
    ${employee_user_id:+-v "employee_user_id=${employee_user_id}"} \
    ${incomplete_setup_user_id:+-v "incomplete_setup_user_id=${incomplete_setup_user_id}"} \
    -f sql/05_link_auth_personas_template.sql
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 \
    ${admin_user_id:+-v "admin_user_id=${admin_user_id}"} \
    ${hr_admin_user_id:+-v "hr_admin_user_id=${hr_admin_user_id}"} \
    ${manager_user_id:+-v "manager_user_id=${manager_user_id}"} \
    ${employee_user_id:+-v "employee_user_id=${employee_user_id}"} \
    ${incomplete_setup_user_id:+-v "incomplete_setup_user_id=${incomplete_setup_user_id}"} \
    -f sql/06_jwt_mutation_proof_smoke.sql
else
  echo "SKIP: 05/06 — set any persona env var (admin_user_id, hr_admin_user_id, manager_user_id, employee_user_id, incomplete_setup_user_id) for auth smoke"
fi

echo "OK: PR13.5 proof runner completed"
