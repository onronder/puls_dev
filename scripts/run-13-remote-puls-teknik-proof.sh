#!/usr/bin/env bash
# PR13.9 — Remote Puls Teknik development proof with mandatory auth/JWT smoke.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACK="${ROOT}/supabase/seed/puls-sanayi-v1"
FIXED_TENANT_ID="a0000001-0001-4001-8001-000000000001"
CONFIRM_VALUE="PULS_TEKNIK_REMOTE_PROOF"

if [[ -n "${ENV_FILE:-}" ]]; then
  if [[ ! -f "$ENV_FILE" ]]; then
    echo "FAIL: ENV_FILE does not exist: $ENV_FILE"
    exit 1
  fi
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "FAIL: ${name} is required for PR13.9 remote Puls Teknik proof"
    exit 1
  fi
}

if [[ "${REMOTE_PROOF_CONFIRM:-}" != "$CONFIRM_VALUE" ]]; then
  echo "FAIL: set REMOTE_PROOF_CONFIRM=${CONFIRM_VALUE} before remote proof"
  exit 1
fi

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

prepare_pg_env_from_database_url() {
  if [[ -n "${PGHOST:-}" && -n "${PGPASSWORD:-}" ]]; then
    return
  fi
  if [[ -z "${DATABASE_URL:-}" ]]; then
    return
  fi
  if [[ "$DATABASE_URL" != postgresql://* && "$DATABASE_URL" != postgres://* ]]; then
    return
  fi

  local url="${DATABASE_URL#postgresql://}"
  url="${url#postgres://}"
  local userinfo="${url%@*}"
  local hostinfo="${url##*@}"

  if [[ "$userinfo" == "$hostinfo" || "$userinfo" != *:* ]]; then
    return
  fi

  export PGUSER="${PGUSER:-${userinfo%%:*}}"
  export PGPASSWORD="${PGPASSWORD:-${userinfo#*:}}"
  export PGHOST="${PGHOST:-${hostinfo%%[:/]*}}"

  local rest="${hostinfo#${PGHOST}}"
  if [[ "$rest" == :* ]]; then
    export PGPORT="${PGPORT:-${rest#:}}"
    PGPORT="${PGPORT%%/*}"
    rest="${rest#:${PGPORT}}"
  fi
  rest="${rest#/}"
  export PGDATABASE="${PGDATABASE:-${rest%%\?*}}"
  if [[ "$hostinfo" == *"sslmode=require"* ]]; then
    export PGSSLMODE="${PGSSLMODE:-require}"
  fi
}

prepare_pg_env_from_database_url

if [[ -z "${DATABASE_URL:-}" && ( -z "${PGHOST:-}" || -z "${PGPASSWORD:-}" ) ]]; then
  echo "FAIL: provide DATABASE_URL or PGHOST/PGPASSWORD connection env"
  exit 1
fi

psql_target() {
  if [[ -n "${PGHOST:-}" && -n "${PGPASSWORD:-}" ]]; then
    printf 'host=%s port=%s dbname=%s user=%s sslmode=%s' \
      "${PGHOST}" "${PGPORT:-5432}" "${PGDATABASE:-postgres}" "${PGUSER:-postgres}" "${PGSSLMODE:-require}"
  else
    printf '%s' "$DATABASE_URL"
  fi
}

run_psql_file() {
  local file="$1"
  if command -v psql >/dev/null 2>&1; then
    psql "$(psql_target)" -v ON_ERROR_STOP=1 -f "$file"
    return
  fi
  if ! command -v docker >/dev/null 2>&1; then
    echo "FAIL: psql is not installed and docker fallback is unavailable"
    exit 1
  fi
  docker run --rm -i \
    -e DATABASE_URL -e PGHOST -e PGPORT -e PGDATABASE -e PGUSER -e PGPASSWORD -e PGSSLMODE \
    -v "$PACK:/workspace:ro" \
    -w /workspace \
    public.ecr.aws/supabase/postgres:17.6.1.113 \
    psql "$(psql_target)" -v ON_ERROR_STOP=1 -f "$file"
}

run_psql_persona_file() {
  local file="$1"
  if command -v psql >/dev/null 2>&1; then
    psql "$(psql_target)" -v ON_ERROR_STOP=1 "${persona_args[@]}" -f "$file"
    return
  fi
  if ! command -v docker >/dev/null 2>&1; then
    echo "FAIL: psql is not installed and docker fallback is unavailable"
    exit 1
  fi
  docker run --rm -i \
    -e DATABASE_URL -e PGHOST -e PGPORT -e PGDATABASE -e PGUSER -e PGPASSWORD -e PGSSLMODE \
    -v "$PACK:/workspace:ro" \
    -w /workspace \
    public.ecr.aws/supabase/postgres:17.6.1.113 \
    psql "$(psql_target)" -v ON_ERROR_STOP=1 "${persona_args[@]}" -f "$file"
}

run_psql_sql() {
  local sql="$1"
  if command -v psql >/dev/null 2>&1; then
    psql "$(psql_target)" -v ON_ERROR_STOP=1 -Atc "$sql"
    return
  fi
  docker run --rm -i \
    -e DATABASE_URL -e PGHOST -e PGPORT -e PGDATABASE -e PGUSER -e PGPASSWORD -e PGSSLMODE \
    public.ecr.aws/supabase/postgres:17.6.1.113 \
    psql "$(psql_target)" -v ON_ERROR_STOP=1 -Atc "$sql"
}

echo "== PR13.9 remote Puls Teknik preflight =="
run_psql_sql "select 'remote_db=' || current_database() || ', user=' || current_user || ', server=' || current_setting('server_version');"

if [[ "${ALLOW_RESEED_FIXED_TENANT:-}" != "1" ]]; then
  existing_fixed_tenant="$(run_psql_sql "select count(*) from puls_core.tenants where id = '${FIXED_TENANT_ID}';")"
  if [[ "$existing_fixed_tenant" != "0" ]]; then
    echo "FAIL: fixed PR13 proof tenant already exists remotely; set ALLOW_RESEED_FIXED_TENANT=1 to reseed it intentionally"
    exit 1
  fi
fi

run_psql_sql "select 'existing_non_fixed_tenants=' || count(*) from puls_core.tenants where id <> '${FIXED_TENANT_ID}';"

cd "$PACK"

echo "== PR13.9 remote seed/proof stack =="
run_psql_file sql/00_reset_puls_sanayi_seed.sql
run_psql_file sql/01_load_puls_sanayi_seed.sql
run_psql_file sql/10_apply_puls_teknik_remote_posture.sql
run_psql_file sql/02_validate_puls_sanayi_seed.sql
run_psql_file sql/03_generate_workflow_scenarios.sql
run_psql_file sql/04_generate_performance_scenarios.sql
run_psql_file sql/07_validate_packaging_proof.sql
run_psql_file sql/08_validate_ai_context_readiness.sql
run_psql_file sql/09_validate_canias_connector_readiness.sql

echo "== PR13.9 mandatory remote auth persona link =="
run_psql_persona_file sql/05_link_auth_personas_template.sql

echo "== PR13.9 mandatory remote JWT/RPC smoke =="
run_psql_persona_file sql/06_jwt_mutation_proof_smoke.sql

echo "== PR13.9 remote postflight =="
run_psql_sql "select 'proof_tenant=' || id || ', name=' || name from puls_core.tenants where id = '${FIXED_TENANT_ID}';"
run_psql_sql "select 'existing_non_fixed_tenants=' || count(*) from puls_core.tenants where id <> '${FIXED_TENANT_ID}';"

echo "OK: PR13.9 remote Puls Teknik proof completed"
