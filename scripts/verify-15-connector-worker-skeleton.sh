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

echo "Checking ${REF}: PR15.2 connector worker skeleton ..."

DOC="$(file_at_ref docs/product/15_connector_worker_skeleton.md)"
README="$(file_at_ref docs/product/README.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
SERVICE_README="$(file_at_ref services/erp-connector/README.md)"
SERVICE_INDEX="$(file_at_ref services/erp-connector/src/index.ts)"
SERVICE_WORKER="$(file_at_ref services/erp-connector/src/worker.ts)"
SERVICE_TEST="$(file_at_ref services/erp-connector/src/worker.test.ts)"
MIGRATION="$(file_at_ref supabase/migrations/20260604110000_puls_integration_connector_worker_skeleton.sql)"
ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/verikaynaklari.tsx)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
DATA_INDEX="$(file_at_ref src/lib/data/index.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"
VERIFY_SELF="$(file_at_ref scripts/verify-15-connector-worker-skeleton.sh)"

for needle in \
  "PR15.2, PR15.1 queue contract üzerine güvenli worker sahipliği ekler." \
  "PULS'ta UI iş çalıştırmaz." \
  "Worker service-role key'i yalnızca environment üzerinden alır." \
  "AI Coach job claim edemez, complete edemez, credential okuyamaz, import apply başlatamaz veya ERP'ye yazamaz." \
  "Skeleton worker provider runtime varmış gibi davranmaz."; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR15.2 doc missing worker skeleton needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "connector_worker_status" \
  "connector_worker_heartbeats" \
  "worker_heartbeat_at" \
  "lease_expires_at" \
  "connector_jobs_running_lease_contract" \
  "connector_jobs_lease_expiry_idx" \
  "upsert_connector_worker_heartbeat" \
  "heartbeat_connector_job" \
  "recover_stale_connector_jobs" \
  "PULS_CONNECTOR_JOB_WORKER_ONLY" \
  "GRANT EXECUTE ON FUNCTION puls_integration.heartbeat_connector_job" \
  "GRANT EXECUTE ON FUNCTION puls_integration.recover_stale_connector_jobs"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: PR15.2 migration missing worker/lease needle: $needle" >&2
    exit 1
  fi
done

for fn in \
  "claim_next_connector_job" \
  "complete_connector_job" \
  "heartbeat_connector_job" \
  "recover_stale_connector_jobs" \
  "upsert_connector_worker_heartbeat"; do
  if grep -F "GRANT EXECUTE ON FUNCTION puls_integration.${fn}" <<< "$MIGRATION" | grep -Fq "authenticated"; then
    echo "FAIL: ${fn} must not be granted to authenticated" >&2
    exit 1
  fi
done

for needle in \
  "Connector Worker Boundary" \
  "0.2.0-worker-skeleton" \
  "Source-independent" \
  "noop_health" \
  "PULS_CONNECTOR_WORKER_ENABLED" \
  "PULS_SUPABASE_SERVICE_ROLE_KEY" \
  "No credential readback" \
  "No import apply execution" \
  "No canonical writes"; do
  if ! grep -Fq "$needle" <<< "$SERVICE_README"; then
    echo "FAIL: erp-connector README missing worker posture needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "startConnectorWorkerLoop" \
  "buildHealthPayload" \
  "resolveWorkerConfig" \
  "pathToFileURL"; do
  if ! grep -Fq "$needle" <<< "$SERVICE_INDEX"; then
    echo "FAIL: erp-connector index missing safe startup needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PULS_CONNECTOR_WORKER_ENABLED" \
  "PULS_SUPABASE_SERVICE_ROLE_KEY" \
  "claim_next_connector_job" \
  "heartbeat_connector_job" \
  "complete_connector_job" \
  "recover_stale_connector_jobs" \
  "noop_health" \
  "connector_job_type_not_supported_by_worker_skeleton" \
  "providerApiCalls: false" \
  "credentialReadback: false" \
  "canonicalWrites: false" \
  "sourceWriteback: false"; do
  if ! grep -Fq "$needle" <<< "$SERVICE_WORKER"; then
    echo "FAIL: erp-connector worker missing skeleton runtime needle: $needle" >&2
    exit 1
  fi
done

if grep -Eiq "canias\\.(com|local|test)|logo\\.(com|local|test)|ftp://|sftp://|/api/(sync|write|export)|apply_import_batch|credentials_ref|raw_payload|request_body|response_body|password|token" <<< "$SERVICE_WORKER"; then
  echo "FAIL: erp-connector worker introduced provider endpoint, credential, payload, or apply pattern" >&2
  exit 1
fi

for needle in \
  "service-role-secret-value" \
  "not.toContain('service-role-secret-value')" \
  "not.toContain('credentials_ref')" \
  "not.toContain('raw_payload')" \
  "connector_job_type_not_supported_by_worker_skeleton"; do
  if ! grep -Fq "$needle" <<< "$SERVICE_TEST"; then
    echo "FAIL: erp-connector worker tests missing no-readback/skeleton case: $needle" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorRuntimeWorker" \
  "ConnectorRuntimeLeaseStatus" \
  "connector_worker_heartbeats" \
  "workerHeartbeatAt" \
  "leaseExpiresAt" \
  "pr15.2-worker-skeleton-v1" \
  "mapConnectorRuntimeWorker" \
  "mapRuntimeLeaseStatus"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing worker read-model needle: $needle" >&2
    exit 1
  fi
done

if grep -Eiq "credentials_ref|raw_payload|sanitized_payload|normalized_payload|apply_import_batch|select\\('\\*'\\)|sync_canias_now|write_to_canias|delete_or_overwrite" <<< "$ERP_ADAPTER"; then
  echo "FAIL: ERP adapter introduced payload, credential, apply, or ERP write pattern" >&2
  exit 1
fi

for needle in \
  "data.runtimeQueue.worker" \
  "worker.statusLabelKey" \
  "worker.descriptionKey" \
  "leaseStatusLabelKey" \
  "erp.runtimeQueue.labels.lease"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route missing worker/lease UI needle: $needle" >&2
    exit 1
  fi
done

if grep -Eiq "type=[\"']password[\"']|name=[\"'](apiKey|api_key|token|secret|password|connectionString|ftpPassword)[\"']|placeholder=.*(API key|token|password|secret|connection string)|claim_next_connector_job|complete_connector_job|heartbeat_connector_job" <<< "$ERP_ROUTE"; then
  echo "FAIL: ERP route introduced credential input or worker execution pattern" >&2
  exit 1
fi

for needle in \
  '"workerStatus"' \
  '"workerDescriptions"' \
  '"leaseStatus"' \
  '"workerLastSeen"' \
  '"lease"' \
  '"connector_job_lease_expired"' \
  '"connector_job_type_not_supported_by_worker_skeleton"' \
  '"worker_contract_ready"'; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing worker key: $needle" >&2
    exit 1
  fi
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing worker key: $needle" >&2
    exit 1
  fi
done

for needle in \
  "connector_worker_heartbeats" \
  "runtimeQueue.worker" \
  "leaseStatus" \
  "pr15.2-worker-skeleton-v1" \
  "not.toContain('raw_payload')" \
  "not.toContain('credentials_ref')" \
  "not.toContain('secret://')"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP tests missing worker/lease case: $needle" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorRuntimeWorker" \
  "ConnectorRuntimeWorkerStatus" \
  "ConnectorRuntimeLeaseStatus"; do
  if ! grep -Fq "$needle" <<< "$DATA_INDEX"; then
    echo "FAIL: data index missing worker export: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR15.2 Connector worker skeleton" \
  "15_connector_worker_skeleton.md" \
  "20260604110000_puls_integration_connector_worker_skeleton.sql" \
  "services/erp-connector/README.md" \
  "scripts/verify-15-connector-worker-skeleton.sh"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR15.2 reference: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR15.2 - Railway Worker Skeleton" \
  "Implementation status" \
  "connector_worker_heartbeats" \
  "noop_health"; do
  if ! grep -Fq "$needle" <<< "$ROADMAP"; then
    echo "FAIL: roadmap missing PR15.2 reference: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR15.2 connector worker skeleton" <<< "$VERIFY_SELF"; then
  echo "FAIL: verify script self-check missing PR15.2 label" >&2
  exit 1
fi

if [[ "$REF" == "WORKTREE" ]]; then
  CHANGED_FILES="$(
    git diff --name-only "$(git merge-base origin/main HEAD)"
    git ls-files --others --exclude-standard
  )"
else
  CHANGED_FILES="$(git diff --name-only "$(git merge-base origin/main "$REF")...$REF")"
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
      docs/product/15_connector_worker_skeleton.md) ;;
      docs/product/15_16_connector_runtime_ai_roadmap.md) ;;
      docs/product/README.md) ;;
      scripts/verify-15-connector-worker-skeleton.sh) ;;
      services/erp-connector/README.md) ;;
      services/erp-connector/src/index.ts) ;;
      services/erp-connector/src/worker.test.ts) ;;
      services/erp-connector/src/worker.ts) ;;
      supabase/migrations/20260604110000_puls_integration_connector_worker_skeleton.sql) ;;
      src/i18n/locales/en-US.json) ;;
      src/i18n/locales/tr-TR.json) ;;
      src/lib/data/index.ts) ;;
      src/lib/data/setup/erp.test.ts) ;;
      src/lib/data/setup/erp.ts) ;;
      src/routes/_app/verikaynaklari.tsx) ;;
      *)
        echo "FAIL: unexpected changed path for PR15.2 connector worker skeleton: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      services/llm-gateway/*|supabase/seed/puls-sanayi-v1/csv/*|supabase/seed/puls-sanayi-v1/manifest.json|package.json|.env*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR15.2 connector worker skeleton: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

echo "OK: PR15.2 connector worker skeleton verification passed"
