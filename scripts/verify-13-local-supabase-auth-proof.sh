#!/usr/bin/env bash
# Verifies PR13.8 local Supabase packaging + mandatory auth proof pack.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
VERIFY_SCRIPT="scripts/verify-13-local-supabase-auth-proof.sh"
RUNNER="scripts/run-13-local-supabase-auth-proof.sh"
RUNBOOK="docs/product/13_local_supabase_packaging_auth_proof.md"
RESULTS="docs/product/13_local_supabase_packaging_auth_proof_results.md"

file_at_ref() {
  local path="$1"
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

echo "Checking ${REF}: PR13.8 local Supabase packaging + auth proof ..."

REQUIRED_FILES=(
  "$RUNBOOK"
  "$RESULTS"
  "$RUNNER"
  "$VERIFY_SCRIPT"
  "docs/product/README.md"
  "docs/product/13_v1_packaging_signoff_roadmap.md"
  "docs/product/13_v1_remaining_work_register.md"
  "supabase/seed/puls-sanayi-v1/sql/00_reset_puls_sanayi_seed.sql"
  "supabase/seed/puls-sanayi-v1/sql/01_load_puls_sanayi_seed.sql"
  "supabase/seed/puls-sanayi-v1/sql/02_validate_puls_sanayi_seed.sql"
  "supabase/seed/puls-sanayi-v1/sql/03_generate_workflow_scenarios.sql"
  "supabase/seed/puls-sanayi-v1/sql/04_generate_performance_scenarios.sql"
  "supabase/seed/puls-sanayi-v1/sql/05_link_auth_personas_template.sql"
  "supabase/seed/puls-sanayi-v1/sql/06_jwt_mutation_proof_smoke.sql"
  "supabase/seed/puls-sanayi-v1/sql/07_validate_packaging_proof.sql"
  "supabase/seed/puls-sanayi-v1/sql/08_validate_ai_context_readiness.sql"
  "supabase/seed/puls-sanayi-v1/sql/09_validate_canias_connector_readiness.sql"
)

for f in "${REQUIRED_FILES[@]}"; do
  if ! file_at_ref "$f" >/dev/null; then
    echo "FAIL: missing required file: $f"
    exit 1
  fi
done

RUNBOOK_TEXT="$(file_at_ref "$RUNBOOK")"
RESULTS_TEXT="$(file_at_ref "$RESULTS")"
RUNNER_TEXT="$(file_at_ref "$RUNNER")"
README_TEXT="$(file_at_ref docs/product/README.md)"
ROADMAP_TEXT="$(file_at_ref docs/product/13_v1_packaging_signoff_roadmap.md)"
REGISTER_TEXT="$(file_at_ref docs/product/13_v1_remaining_work_register.md)"

runbook_needles=(
  "PR13.8 is the local signoff gate before any remote Puls Teknik A.S. tenant work."
  "Auth persona proof is mandatory for PR13.8 signoff."
  "SQL Editor is not used for"
  "VITE_PULS_DEMO_MODE=false"
  "Do not proceed to remote Puls Teknik A.S. tenant work"
  "Cannot connect to the Docker daemon"
)

for needle in "${runbook_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$RUNBOOK_TEXT"; then
    echo "FAIL: runbook missing needle: $needle"
    exit 1
  fi
done

if ! grep -Fq "Status: Passed local execution." <<< "$RESULTS_TEXT"; then
  echo "FAIL: results doc must record passed local execution after proof run"
  exit 1
fi
if ! grep -Fq "Do not paste" <<< "$RESULTS_TEXT"; then
  echo "FAIL: results doc missing no-secret warning"
  exit 1
fi
if ! grep -Fq "Auth password-grant smoke | Passed" <<< "$RESULTS_TEXT"; then
  echo "FAIL: results doc must record auth password-grant smoke"
  exit 1
fi

for env_name in DATABASE_URL admin_user_id hr_admin_user_id manager_user_id employee_user_id; do
  if ! grep -Fq "require_env ${env_name}" <<< "$RUNNER_TEXT"; then
    echo "FAIL: runner must require ${env_name}"
    exit 1
  fi
done

for sql_file in \
  "00_reset_puls_sanayi_seed.sql" \
  "01_load_puls_sanayi_seed.sql" \
  "02_validate_puls_sanayi_seed.sql" \
  "03_generate_workflow_scenarios.sql" \
  "04_generate_performance_scenarios.sql" \
  "07_validate_packaging_proof.sql" \
  "08_validate_ai_context_readiness.sql" \
  "09_validate_canias_connector_readiness.sql" \
  "05_link_auth_personas_template.sql" \
  "06_jwt_mutation_proof_smoke.sql"; do
  if ! grep -Fq "$sql_file" <<< "$RUNNER_TEXT"; then
    echo "FAIL: runner missing SQL step: $sql_file"
    exit 1
  fi
done

if grep -Fq "SKIP: 05/06" <<< "$RUNNER_TEXT"; then
  echo "FAIL: PR13.8 runner must not skip mandatory auth proof"
  exit 1
fi
if grep -Ei '(password|secret|token)=' <<< "$RUNNER_TEXT"; then
  echo "FAIL: runner must not hardcode credentials"
  exit 1
fi

if ! grep -Fq "PR13.8 Local Supabase packaging + mandatory auth proof" <<< "$README_TEXT"; then
  echo "FAIL: README missing PR13.8 section"
  exit 1
fi
if ! grep -Fq "PR13.8 | Local Supabase packaging + auth proof" <<< "$ROADMAP_TEXT"; then
  echo "FAIL: roadmap must reflect local-first PR13.8"
  exit 1
fi
if ! grep -Fq "W1 | Local Supabase seed/proof" <<< "$REGISTER_TEXT"; then
  echo "FAIL: remaining work register must track local proof first"
  exit 1
fi

# Diff guard: PR13.8 must stay proof/docs/scripts only.
BASE_REF="$(git merge-base "${REF}" origin/main 2>/dev/null || echo "")"
if [[ -n "$BASE_REF" && "$BASE_REF" != "$REF" ]]; then
  CHANGED=$(git diff --name-only "$BASE_REF" "$REF" 2>/dev/null || true)
  if [[ -n "$CHANGED" ]]; then
    while IFS= read -r path; do
      [[ -z "$path" ]] && continue
      case "$path" in
        "$RUNBOOK") ;;
        "$RESULTS") ;;
        "$RUNNER") ;;
        "$VERIFY_SCRIPT") ;;
        supabase/seed/puls-sanayi-v1/sql/00_reset_puls_sanayi_seed.sql) ;;
        docs/product/README.md) ;;
        docs/product/13_v1_packaging_signoff_roadmap.md) ;;
        docs/product/13_v1_remaining_work_register.md) ;;
        *)
          case "$path" in
            src/*|supabase/migrations/*|supabase/seed/puls-sanayi-v1/csv/*|supabase/seed/puls-sanayi-v1/manifest.json|package.json|.env|.env.*|docs/api/openapi.yaml|openapi.json|swagger.json)
              echo "FAIL: forbidden path vs merge-base: $path"
              exit 1
              ;;
            *)
              echo "FAIL: path not allowlisted for PR13.8: $path"
              exit 1
              ;;
          esac
          ;;
      esac
    done <<< "$CHANGED"
  fi
fi

echo "OK: PR13.8 local Supabase packaging + auth proof verification passed"
