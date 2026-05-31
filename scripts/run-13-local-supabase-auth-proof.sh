#!/usr/bin/env bash
# PR13.8 — Local Supabase packaging proof with mandatory auth/JWT smoke.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACK="${ROOT}/supabase/seed/puls-sanayi-v1"

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "FAIL: ${name} is required for PR13.8 local auth proof"
    exit 1
  fi
}

require_env DATABASE_URL
require_env admin_user_id
require_env hr_admin_user_id
require_env manager_user_id
require_env employee_user_id

persona_args=(
  -v "admin_user_id=${admin_user_id}"
  -v "hr_admin_user_id=${hr_admin_user_id}"
  -v "manager_user_id=${manager_user_id}"
  -v "employee_user_id=${employee_user_id}"
)
if [[ -n "${incomplete_setup_user_id:-}" ]]; then
  persona_args+=(-v "incomplete_setup_user_id=${incomplete_setup_user_id}")
fi

cd "$PACK"

run_psql() {
  local file="$1"

  if command -v psql >/dev/null 2>&1; then
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$file"
    return
  fi

  if ! command -v docker >/dev/null 2>&1; then
    echo "FAIL: psql is not installed and docker fallback is unavailable"
    exit 1
  fi

  local docker_database_url="$DATABASE_URL"
  docker_database_url="${docker_database_url//127.0.0.1/host.docker.internal}"
  docker_database_url="${docker_database_url//localhost/host.docker.internal}"

  docker run --rm -i \
    -v "$PACK:/workspace:ro" \
    -w /workspace \
    public.ecr.aws/supabase/postgres:17.6.1.113 \
    psql "$docker_database_url" -v ON_ERROR_STOP=1 -f "$file"
}

run_psql_with_personas() {
  local file="$1"

  if command -v psql >/dev/null 2>&1; then
    psql "$DATABASE_URL" -v ON_ERROR_STOP=1 "${persona_args[@]}" -f "$file"
    return
  fi

  if ! command -v docker >/dev/null 2>&1; then
    echo "FAIL: psql is not installed and docker fallback is unavailable"
    exit 1
  fi

  local docker_database_url="$DATABASE_URL"
  docker_database_url="${docker_database_url//127.0.0.1/host.docker.internal}"
  docker_database_url="${docker_database_url//localhost/host.docker.internal}"

  docker run --rm -i \
    -v "$PACK:/workspace:ro" \
    -w /workspace \
    public.ecr.aws/supabase/postgres:17.6.1.113 \
    psql "$docker_database_url" -v ON_ERROR_STOP=1 "${persona_args[@]}" -f "$file"
}

echo "== PR13.8 local Supabase packaging proof =="
run_psql sql/00_reset_puls_sanayi_seed.sql
run_psql sql/01_load_puls_sanayi_seed.sql
run_psql sql/02_validate_puls_sanayi_seed.sql
run_psql sql/03_generate_workflow_scenarios.sql
run_psql sql/04_generate_performance_scenarios.sql
run_psql sql/07_validate_packaging_proof.sql
run_psql sql/08_validate_ai_context_readiness.sql
run_psql sql/09_validate_canias_connector_readiness.sql

echo "== PR13.8 mandatory auth persona link =="
run_psql_with_personas sql/05_link_auth_personas_template.sql

echo "== PR13.8 mandatory JWT/RPC smoke =="
run_psql_with_personas sql/06_jwt_mutation_proof_smoke.sql

echo "OK: PR13.8 local Supabase packaging + mandatory auth proof completed"
