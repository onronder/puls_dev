#!/usr/bin/env bash
# Verifies PR13.9 remote Puls Teknik proof artifacts.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
VERIFY_SCRIPT="scripts/verify-13-remote-puls-teknik-proof.sh"
RUNNER="scripts/run-13-remote-puls-teknik-proof.sh"
RUNBOOK="docs/product/13_remote_puls_teknik_tenant_proof.md"
RESULTS="docs/product/13_remote_puls_teknik_tenant_proof_results.md"
OVERLAY_SQL="supabase/seed/puls-sanayi-v1/sql/10_apply_puls_teknik_remote_posture.sql"

file_at_ref() {
  local path="$1"
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

echo "Checking ${REF}: PR13.9 remote Puls Teknik proof artifacts ..."

REQUIRED_FILES=(
  "$RUNBOOK"
  "$RESULTS"
  "$RUNNER"
  "$VERIFY_SCRIPT"
  "$OVERLAY_SQL"
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
SQL_TEXT="$(file_at_ref "$OVERLAY_SQL")"
README_TEXT="$(file_at_ref docs/product/README.md)"
ROADMAP_TEXT="$(file_at_ref docs/product/13_v1_packaging_signoff_roadmap.md)"
REGISTER_TEXT="$(file_at_ref docs/product/13_v1_remaining_work_register.md)"

runbook_needles=(
  "PR13.9 is the remote development proof after PR13.8 local signoff."
  "Mert Teknik must not be modified."
  "Puls Teknik A.S."
  "fixed proof tenant"
  "not live customer data"
  "Auth persona proof is mandatory"
  "No secret value is committed."
)

for needle in "${runbook_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$RUNBOOK_TEXT"; then
    echo "FAIL: runbook missing needle: $needle"
    exit 1
  fi
done

if ! grep -Fq "Status: Passed remote execution." <<< "$RESULTS_TEXT"; then
  echo "FAIL: results doc must record passed remote execution"
  exit 1
fi
if ! grep -Fq "Remote read-only inspect | Passed" <<< "$RESULTS_TEXT"; then
  echo "FAIL: results doc must record read-only inspect"
  exit 1
fi
if ! grep -Fq "PR13.9 remote DB/auth proof is green." <<< "$RESULTS_TEXT"; then
  echo "FAIL: results doc must record remote DB/auth proof signoff"
  exit 1
fi

for env_name in admin_user_id hr_admin_user_id manager_user_id employee_user_id; do
  if ! grep -Fq "require_env ${env_name}" <<< "$RUNNER_TEXT"; then
    echo "FAIL: runner must require ${env_name}"
    exit 1
  fi
done

runner_needles=(
  "REMOTE_PROOF_CONFIRM"
  "PULS_TEKNIK_REMOTE_PROOF"
  "ALLOW_RESEED_FIXED_TENANT"
  "existing_non_fixed_tenants"
  "10_apply_puls_teknik_remote_posture.sql"
  "05_link_auth_personas_template.sql"
  "06_jwt_mutation_proof_smoke.sql"
  "OK: PR13.9 remote Puls Teknik proof completed"
)

for needle in "${runner_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$RUNNER_TEXT"; then
    echo "FAIL: runner missing needle: $needle"
    exit 1
  fi
done

if grep -Fq "SKIP: 05/06" <<< "$RUNNER_TEXT"; then
  echo "FAIL: PR13.9 runner must not skip mandatory auth proof"
  exit 1
fi
if grep -Ei '(password|secret|token)=["'\''][^"$]' <<< "$RUNNER_TEXT"; then
  echo "FAIL: runner must not hardcode credential values"
  exit 1
fi
if grep -Eiq 'service_role|SUPABASE_SERVICE_ROLE_KEY|auth\.users' <<< "$RUNNER_TEXT"; then
  echo "FAIL: runner must not use service role or auth.users directly"
  exit 1
fi

sql_needles=(
  "Puls Teknik A.S."
  "a0000001-0001-4001-8001-000000000001"
  "UPDATE puls_core.tenants"
)
for needle in "${sql_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$SQL_TEXT"; then
    echo "FAIL: overlay SQL missing needle: $needle"
    exit 1
  fi
done
if grep -Eiq 'auth\.users|credentials_ref|service_role|password|secret|token' <<< "$SQL_TEXT"; then
  echo "FAIL: overlay SQL must not reference auth/secrets"
  exit 1
fi

if ! grep -Fq "PR13.9 Remote Puls Teknik tenant proof" <<< "$README_TEXT"; then
  echo "FAIL: README missing PR13.9 section"
  exit 1
fi
if ! grep -Fq "Remote Puls Teknik A.S. tenant proof | Done" <<< "$ROADMAP_TEXT"; then
  echo "FAIL: roadmap must show PR13.9 done"
  exit 1
fi
if ! grep -Fq "W3 | Remote Puls Teknik tenant proof | Done" <<< "$REGISTER_TEXT"; then
  echo "FAIL: register must show W3 done"
  exit 1
fi
if ! grep -Fq "W1 | Local Supabase seed/proof | Done" <<< "$REGISTER_TEXT"; then
  echo "FAIL: register must show W1 done"
  exit 1
fi
if ! grep -Fq "W2 | Mandatory auth persona proof | Done" <<< "$REGISTER_TEXT"; then
  echo "FAIL: register must show W2 done"
  exit 1
fi

changed_files_for_secret_scan() {
  local base_ref
  base_ref="$(git merge-base "${REF}" origin/main 2>/dev/null || echo "")"
  if [[ -n "$base_ref" && "$base_ref" != "$REF" ]]; then
    git diff --name-only "$base_ref" "$REF"
  else
    printf '%s\n' "${REQUIRED_FILES[@]}"
  fi
}

while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  if [[ "$path" == "$VERIFY_SCRIPT" ]]; then
    continue
  fi
  if ! file_at_ref "$path" >/tmp/pr13_9_scan_file 2>/dev/null; then
    continue
  fi
  if grep -Eiq 'OPENAI_API_KEY|CANIAS_API_KEY|SUPABASE_SERVICE_ROLE_KEY|postgresql://postgres:[^.]|eyJ[A-Za-z0-9_-]{20,}' /tmp/pr13_9_scan_file; then
    echo "FAIL: possible secret-bearing content in $path"
    rm -f /tmp/pr13_9_scan_file
    exit 1
  fi
done < <(changed_files_for_secret_scan)
rm -f /tmp/pr13_9_scan_file

# Diff guard: PR13.9 must stay docs/scripts/remote posture SQL only.
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
        "$OVERLAY_SQL") ;;
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
              echo "FAIL: path not allowlisted for PR13.9: $path"
              exit 1
              ;;
          esac
          ;;
      esac
    done <<< "$CHANGED"
  fi
fi

echo "OK: PR13.9 remote Puls Teknik proof verification passed"
