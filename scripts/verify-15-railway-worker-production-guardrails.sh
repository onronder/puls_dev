#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"

file_at_ref() {
  local path="$1"
  if [[ "$REF" == "WORKTREE" ]]; then
    cat "$path"
    return
  fi
  git show "${REF}:${path}" 2>/dev/null || cat "$path"
}

echo "Checking ${REF}: PR15.8 Railway worker production guardrails ..."

DOC="$(file_at_ref docs/product/15_railway_worker_production_guardrails.md)"
READINESS_DOC="$(file_at_ref docs/product/15_railway_worker_deployment_readiness.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
SERVICE_README="$(file_at_ref services/erp-connector/README.md)"
RAILWAY_CONFIG="$(file_at_ref services/erp-connector/railway.toml)"
SERVICE_INDEX="$(file_at_ref services/erp-connector/src/index.ts)"
SERVICE_WORKER="$(file_at_ref services/erp-connector/src/worker.ts)"
SERVICE_WORKER_TEST="$(file_at_ref services/erp-connector/src/worker.test.ts)"
VERIFY_SELF="$(file_at_ref scripts/verify-15-railway-worker-production-guardrails.sh)"

for needle in \
  "PR15.8 hardens the deployed Railway connector worker before PR16 opens controlled data movement." \
  "PULS_CONNECTOR_WORKER_ALLOW_NON_PRODUCTION=false" \
  "PULS_CONNECTOR_WORKER_IMPORT_APPLY_ENABLED=false" \
  "RAILWAY_ENVIRONMENT_NAME" \
  "non-production Railway environments must not run the loop" \
  "import_apply" \
  "numReplicas = 1" \
  "overlapSeconds = 0" \
  "drainingSeconds = 30" \
  "watchPatterns" \
  "SIGTERM" \
  "connector_job_events" \
  "worker_id='railway-erp-connector-production-1'" \
  "job completion clears the runtime lock" \
  "Before PR16 can set"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR15.8 doc missing guardrail needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PULS_CONNECTOR_WORKER_ALLOW_NON_PRODUCTION" \
  "PULS_CONNECTOR_WORKER_IMPORT_APPLY_ENABLED" \
  "15_railway_worker_production_guardrails.md" \
  "job completion clears lock ownership" \
  "connector_job_events" \
  "worker_id"; do
  if ! grep -Fq "$needle" <<< "$READINESS_DOC"; then
    echo "FAIL: PR15.7 readiness doc missing PR15.8 handoff needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR15.8 - Railway Worker Production Guardrails" \
  "PULS_CONNECTOR_WORKER_ALLOW_NON_PRODUCTION" \
  "PULS_CONNECTOR_WORKER_IMPORT_APPLY_ENABLED" \
  "numReplicas = 1" \
  "overlapSeconds = 0" \
  "drainingSeconds = 30" \
  "connector_job_events.worker_id"; do
  if ! grep -Fq "$needle" <<< "$ROADMAP"; then
    echo "FAIL: roadmap missing PR15.8 needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR15.8 Railway worker production guardrails" \
  "15_railway_worker_production_guardrails.md" \
  "verify-15-railway-worker-production-guardrails.sh"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: product README missing PR15.8 index needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PULS_CONNECTOR_WORKER_ALLOW_NON_PRODUCTION" \
  "PULS_CONNECTOR_WORKER_IMPORT_APPLY_ENABLED" \
  "RAILWAY_ENVIRONMENT_NAME" \
  "preview, staging, or other non-production environments" \
  "\`import_apply\` is ignored" \
  "numReplicas = 1" \
  "overlapSeconds = 0" \
  "drainingSeconds = 30" \
  "SIGTERM" \
  "SIGINT"; do
  if ! grep -Fq "$needle" <<< "$SERVICE_README"; then
    echo "FAIL: service README missing PR15.8 guardrail needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  'watchPatterns = [' \
  '/services/erp-connector/**' \
  '/package.json' \
  '/pnpm-lock.yaml' \
  'numReplicas = 1' \
  'overlapSeconds = 0' \
  'drainingSeconds = 30' \
  'restartPolicyType = "ALWAYS"'; do
  if ! grep -Fq "$needle" <<< "$RAILWAY_CONFIG"; then
    echo "FAIL: railway.toml missing production guardrail needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "SIGTERM" \
  "SIGINT" \
  "installShutdownHandlers" \
  "stopService"; do
  if ! grep -Fq "$needle" <<< "$SERVICE_INDEX"; then
    echo "FAIL: service index missing shutdown guardrail needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PULS_CONNECTOR_WORKER_ALLOW_NON_PRODUCTION" \
  "PULS_CONNECTOR_WORKER_IMPORT_APPLY_ENABLED" \
  "RAILWAY_ENVIRONMENT_NAME" \
  "railwayEnvironmentName" \
  "nonProductionWorkerAllowed" \
  "importApplyEnabled" \
  "parseSupportedJobTypes(env.PULS_CONNECTOR_WORKER_JOB_TYPES" \
  "jobType !== 'import_apply'"; do
  if ! grep -Fq "$needle" <<< "$SERVICE_WORKER"; then
    echo "FAIL: worker missing production guardrail needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "keeps Railway non-production worker loops disabled unless explicitly allowed" \
  "requires an explicit PR16 gate before claiming import_apply jobs" \
  "RAILWAY_ENVIRONMENT_NAME: 'preview'" \
  "PULS_CONNECTOR_WORKER_ALLOW_NON_PRODUCTION: 'true'" \
  "PULS_CONNECTOR_WORKER_IMPORT_APPLY_ENABLED: 'true'" \
  "parseSupportedJobTypes('import_apply,noop_health')" \
  "importApplyEnabled: true"; do
  if ! grep -Fq "$needle" <<< "$SERVICE_WORKER_TEST"; then
    echo "FAIL: worker tests missing guardrail regression needle: $needle" >&2
    exit 1
  fi
done

if grep -Eiq "(SUPABASE_SERVICE_ROLE_KEY|PULS_SUPABASE_SERVICE_ROLE_KEY)\\s*=" <<< "$RAILWAY_CONFIG"; then
  echo "FAIL: railway.toml must not contain secret values or variable assignments" >&2
  exit 1
fi

if grep -Eiq "canias\\.(com|local|test)|logo\\.(com|local|test)|ftp://|sftp://|/api/(sync|write|export)|apply_import_batch|credentials_ref\\s*=|raw_payload\\s*=|request_body\\s*=|response_body\\s*=|eyJ[A-Za-z0-9_-]+\\.|sk-[A-Za-z0-9]|postgres(ql)?://" <<< "$DOC$READINESS_DOC$SERVICE_README$RAILWAY_CONFIG"; then
  echo "FAIL: PR15.8 artifacts include forbidden provider endpoint, secret, payload, or apply pattern" >&2
  exit 1
fi

if ! grep -Fq "PR15.8 Railway worker production guardrails" <<< "$VERIFY_SELF"; then
  echo "FAIL: verify script self-check missing PR15.8 label" >&2
  exit 1
fi

if [[ "$REF" == "WORKTREE" ]]; then
  BASE="$(git merge-base origin/main HEAD)"
  CHANGED_FILES="$(
    git diff --name-only "$BASE"
    git ls-files --others --exclude-standard
  )"
else
  BASE="$(git merge-base origin/main "$REF")"
  CHANGED_FILES="$(git diff --name-only "$BASE...$REF")"
fi

if [[ -n "$CHANGED_FILES" ]]; then
  while IFS= read -r changed; do
    [[ -z "$changed" ]] && continue
    if [[ "$REF" == "WORKTREE" && "$changed" == supabase/.temp/* ]]; then
      continue
    fi
    if [[ "$REF" == "WORKTREE" && "$changed" == supabase/.branches/* ]]; then
      continue
    fi

    case "$changed" in
      docs/product/15_railway_worker_production_guardrails.md) ;;
      docs/product/15_railway_worker_deployment_readiness.md) ;;
      docs/product/15_16_connector_runtime_ai_roadmap.md) ;;
      docs/product/README.md) ;;
      scripts/verify-15-railway-worker-production-guardrails.sh) ;;
      services/erp-connector/README.md) ;;
      services/erp-connector/railway.toml) ;;
      services/erp-connector/src/index.ts) ;;
      services/erp-connector/src/worker.ts) ;;
      services/erp-connector/src/worker.test.ts) ;;
      *)
        echo "FAIL: unexpected changed path for PR15.8 Railway worker production guardrails: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      supabase/migrations/*|supabase/seed/*|src/**|services/llm-gateway/**|package.json|pnpm-lock.yaml|.env*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR15.8 Railway worker production guardrails: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

echo "OK: PR15.8 Railway worker production guardrails verification passed"
