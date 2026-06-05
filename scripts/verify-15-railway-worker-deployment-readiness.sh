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

echo "Checking ${REF}: PR15.7 Railway worker deployment readiness ..."

DOC="$(file_at_ref docs/product/15_railway_worker_deployment_readiness.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
SERVICE_README="$(file_at_ref services/erp-connector/README.md)"
SERVICE_PACKAGE="$(file_at_ref services/erp-connector/package.json)"
SERVICE_WORKER="$(file_at_ref services/erp-connector/src/worker.ts)"
SERVICE_WORKER_TEST="$(file_at_ref services/erp-connector/src/worker.test.ts)"
RAILWAY_CONFIG="$(file_at_ref services/erp-connector/railway.toml)"
VERIFY_SELF="$(file_at_ref scripts/verify-15-railway-worker-deployment-readiness.sh)"

for needle in \
  "PR15.7 closes the gap between the PR15 runtime contract and an actually running connector worker." \
  "Root directory" \
  "services/erp-connector" \
  "/services/erp-connector/railway.toml" \
  "PULS_CONNECTOR_WORKER_ENABLED" \
  "PULS_SUPABASE_SERVICE_ROLE_KEY" \
  "PULS_CONNECTOR_WORKER_JOB_TYPES" \
  "noop_health,connector_runtime_preflight" \
  "railway-erp-connector-production-1" \
  "connector_worker_heartbeats" \
  "pr15_7_railway_noop_health_smoke_v1" \
  "PGRST202" \
  "Accept-Profile: puls_integration" \
  "Content-Profile: puls_integration" \
  "notify pgrst, 'reload schema';" \
  "It does not call Canias, Logo, SFTP, custom API, or any external ERP endpoint." \
  "It does not read credential values, apply imports, write canonical data, or write back to source systems."; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR15.7 doc missing deployment readiness needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR15.7 - Railway Worker Deployment Readiness" \
  "services/erp-connector/railway.toml" \
  "Railway healthcheck returns 200 without exposing secrets." \
  "Worker safe context contains no credential, raw payload, request, or response body."; do
  if ! grep -Fq "$needle" <<< "$ROADMAP"; then
    echo "FAIL: PR15.7 roadmap missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR15.7 Railway worker deployment readiness" \
  "15_railway_worker_deployment_readiness.md" \
  "services/erp-connector/railway.toml" \
  "verify-15-railway-worker-deployment-readiness.sh"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: product README missing PR15.7 index needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "Railway deployment readiness" \
  "Root directory" \
  "services/erp-connector" \
  "/services/erp-connector/railway.toml" \
  "pnpm start:railway" \
  "/health" \
  "PULS_CONNECTOR_WORKER_ENABLED=true" \
  "PULS_CONNECTOR_WORKER_JOB_TYPES=noop_health,connector_runtime_preflight" \
  "No credential readback" \
  "No import apply execution" \
  "No canonical writes" \
  "PGRST202" \
  "Accept-Profile: puls_integration" \
  "Content-Profile: puls_integration" \
  "notify pgrst, 'reload schema';"; do
  if ! grep -Fq "$needle" <<< "$SERVICE_README"; then
    echo "FAIL: service README missing Railway readiness needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  '"packageManager": "pnpm@10.33.3"' \
  '"start:railway"' \
  "node --experimental-strip-types src/index.ts" \
  '"node": ">=22.6.0"'; do
  if ! grep -Fq "$needle" <<< "$SERVICE_PACKAGE"; then
    echo "FAIL: erp-connector package missing Railway start/engine needle: $needle" >&2
    exit 1
  fi
done

if grep -Fq "readonly status: number," <<< "$SERVICE_WORKER" || \
   grep -Fq "readonly code: string," <<< "$SERVICE_WORKER"; then
  echo "FAIL: erp-connector worker must avoid TypeScript parameter properties for Node strip-types runtime" >&2
  exit 1
fi

for needle in \
  "const SUPABASE_RPC_SCHEMA = 'puls_integration'" \
  "'Accept-Profile': SUPABASE_RPC_SCHEMA" \
  "'Content-Profile': SUPABASE_RPC_SCHEMA"; do
  if ! grep -Fq "$needle" <<< "$SERVICE_WORKER"; then
    echo "FAIL: erp-connector worker missing Supabase RPC schema-profile needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "callSupabaseRpc(config, 'upsert_connector_worker_heartbeat'" \
  "Accept-Profile" \
  "Content-Profile" \
  "puls_integration"; do
  if ! grep -Fq "$needle" <<< "$SERVICE_WORKER_TEST"; then
    echo "FAIL: erp-connector worker test missing schema-profile regression needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  '[build]' \
  'builder = "RAILPACK"' \
  '[deploy]' \
  'startCommand = "pnpm start:railway"' \
  'healthcheckPath = "/health"' \
  'healthcheckTimeout = 100' \
  'restartPolicyType = "ALWAYS"' \
  'restartPolicyMaxRetries = 10'; do
  if ! grep -Fq "$needle" <<< "$RAILWAY_CONFIG"; then
    echo "FAIL: railway.toml missing deploy config needle: $needle" >&2
    exit 1
  fi
done

if grep -Eiq "(SUPABASE_SERVICE_ROLE_KEY|PULS_SUPABASE_SERVICE_ROLE_KEY)\\s*=" <<< "$RAILWAY_CONFIG"; then
  echo "FAIL: railway.toml must not contain secret values or variable assignments" >&2
  exit 1
fi

if grep -Eiq "canias\\.(com|local|test)|logo\\.(com|local|test)|ftp://|sftp://|/api/(sync|write|export)|apply_import_batch|credentials_ref\\s*=|raw_payload\\s*=|request_body\\s*=|response_body\\s*=|eyJ[A-Za-z0-9_-]+\\.|sk-[A-Za-z0-9]|postgres(ql)?://" <<< "$DOC$SERVICE_README$RAILWAY_CONFIG"; then
  echo "FAIL: PR15.7 artifacts include forbidden provider endpoint, secret, payload, or apply pattern" >&2
  exit 1
fi

if ! grep -Fq "PR15.7 Railway worker deployment readiness" <<< "$VERIFY_SELF"; then
  echo "FAIL: verify script self-check missing PR15.7 label" >&2
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
      docs/product/15_railway_worker_deployment_readiness.md) ;;
      docs/product/15_16_connector_runtime_ai_roadmap.md) ;;
      docs/product/README.md) ;;
      scripts/verify-15-railway-worker-deployment-readiness.sh) ;;
      services/erp-connector/README.md) ;;
      services/erp-connector/package.json) ;;
      services/erp-connector/railway.toml) ;;
      services/erp-connector/src/worker.ts) ;;
      services/erp-connector/src/worker.test.ts) ;;
      *)
        echo "FAIL: unexpected changed path for PR15.7 Railway worker deployment readiness: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      supabase/migrations/*|supabase/seed/*|src/**|services/llm-gateway/**|package.json|pnpm-lock.yaml|.env*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR15.7 Railway worker deployment readiness: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

echo "OK: PR15.7 Railway worker deployment readiness verification passed"
