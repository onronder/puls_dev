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

echo "Checking ${REF}: PR15.1 connector job queue contract ..."

DOC="$(file_at_ref docs/product/15_connector_job_queue_contract.md)"
README="$(file_at_ref docs/product/README.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
MIGRATION="$(file_at_ref supabase/migrations/20260604100000_puls_integration_connector_job_queue.sql)"
ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/verikaynaklari.tsx)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
DATA_INDEX="$(file_at_ref src/lib/data/index.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"
VERIFY_SELF="$(file_at_ref scripts/verify-15-connector-job-queue-contract.sh)"

for needle in \
  "PR15.1, PULS connector runtime fazının ilk güvenli temelidir." \
  "PULS'ta UI iş çalıştırmaz." \
  "Worker boundary" \
  "AI Coach can explain and summarize these signals, but must not enqueue, claim, complete, apply, sync, export, or write to ERP." \
  "Postgres/Supabase queue semantics are enough"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR15.1 doc missing queue contract needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "connector_job_status" \
  "connector_job_type" \
  "CREATE TABLE IF NOT EXISTS puls_integration.connector_jobs" \
  "idempotency_key" \
  "concurrency_key" \
  "connector_jobs_active_concurrency_idx" \
  "FOR UPDATE SKIP LOCKED" \
  "enqueue_connector_job" \
  "claim_next_connector_job" \
  "complete_connector_job" \
  "list_connector_job_summaries" \
  "safe_error_context" \
  "connector_safe_context_has_blocked_key" \
  "ALTER TABLE puls_integration.connector_jobs ENABLE ROW LEVEL SECURITY"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: PR15.1 migration missing queue contract needle: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "GRANT EXECUTE ON FUNCTION puls_integration.claim_next_connector_job" <<< "$MIGRATION"; then
  echo "FAIL: claim_next_connector_job grant missing" >&2
  exit 1
fi

if grep -F "GRANT EXECUTE ON FUNCTION puls_integration.claim_next_connector_job" <<< "$MIGRATION" | grep -Fq "authenticated"; then
  echo "FAIL: claim_next_connector_job must not be granted to authenticated" >&2
  exit 1
fi

if grep -F "GRANT EXECUTE ON FUNCTION puls_integration.complete_connector_job" <<< "$MIGRATION" | grep -Fq "authenticated"; then
  echo "FAIL: complete_connector_job must not be granted to authenticated" >&2
  exit 1
fi

for needle in \
  "ConnectorRuntimeQueue" \
  "ConnectorRuntimeJobSummary" \
  "runtimeQueue" \
  "buildConnectorRuntimeQueue" \
  "mapConnectorRuntimeJob" \
  "connector_jobs" \
  "pr15.1-db-job-queue-v1"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing runtime queue needle: $needle" >&2
    exit 1
  fi
done

if grep -Eiq "credentials_ref|raw_payload|sanitized_payload|normalized_payload|apply_import_batch|select\\('\\*'\\)|fetch\\(|axios|sync_canias_now|write_to_canias|delete_or_overwrite" <<< "$ERP_ADAPTER"; then
  echo "FAIL: ERP adapter introduced payload, credential, apply, or runtime API pattern" >&2
  exit 1
fi

for needle in \
  "data.runtimeQueue" \
  "erp.sections.runtimeQueue" \
  "erp.runtimeQueue.cards.contract" \
  "erp.empty.runtimeQueue" \
  "runtimeJobStatusTone"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route missing runtime queue UI needle: $needle" >&2
    exit 1
  fi
done

if grep -Eiq "type=[\"']password[\"']|name=[\"'](apiKey|api_key|token|secret|password|connectionString|ftpPassword)[\"']|placeholder=.*(API key|token|password|secret|connection string)|claim_next_connector_job|complete_connector_job|enqueue_connector_job|live connector runtime enabled" <<< "$ERP_ROUTE"; then
  echo "FAIL: ERP route introduced credential input or runtime job execution pattern" >&2
  exit 1
fi

for needle in \
  '"runtimeQueue"' \
  '"contract_ready"' \
  '"queued"' \
  '"running"' \
  '"dead_letter"' \
  '"wait_for_worker_runtime"'; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing runtime queue key: $needle" >&2
    exit 1
  fi
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing runtime queue key: $needle" >&2
    exit 1
  fi
done

for needle in \
  "connector_jobs" \
  "runtimeQueue" \
  "pr15.1-db-job-queue-v1" \
  "connector_job_failed" \
  "not.toContain('raw_payload')" \
  "not.toContain('credentials_ref')" \
  "not.toContain('secret://')"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP tests missing runtime queue case: $needle" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorRuntimeQueue" \
  "ConnectorRuntimeJobSummary" \
  "ConnectorRuntimeJobStatus" \
  "ConnectorRuntimeJobType"; do
  if ! grep -Fq "$needle" <<< "$DATA_INDEX"; then
    echo "FAIL: data index missing runtime queue export: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR15.1 Connector job queue contract" \
  "15_connector_job_queue_contract.md" \
  "20260604100000_puls_integration_connector_job_queue.sql" \
  "scripts/verify-15-connector-job-queue-contract.sh"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR15.1 reference: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR15.1 - Connector Job Queue Contract" \
  "Implementation status" \
  "puls_integration.connector_jobs"; do
  if ! grep -Fq "$needle" <<< "$ROADMAP"; then
    echo "FAIL: roadmap missing PR15.1 reference: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR15.1 connector job queue contract" <<< "$VERIFY_SELF"; then
  echo "FAIL: verify script self-check missing PR15.1 label" >&2
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
      docs/product/15_connector_job_queue_contract.md) ;;
      docs/product/15_16_connector_runtime_ai_roadmap.md) ;;
      docs/product/README.md) ;;
      scripts/verify-15-connector-job-queue-contract.sh) ;;
      supabase/migrations/20260604100000_puls_integration_connector_job_queue.sql) ;;
      src/i18n/locales/en-US.json) ;;
      src/i18n/locales/tr-TR.json) ;;
      src/lib/data/index.ts) ;;
      src/lib/data/setup/erp.test.ts) ;;
      src/lib/data/setup/erp.ts) ;;
      src/routes/_app/verikaynaklari.tsx) ;;
      *)
        echo "FAIL: unexpected changed path for PR15.1 connector job queue: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      services/*|supabase/seed/puls-sanayi-v1/csv/*|supabase/seed/puls-sanayi-v1/manifest.json|package.json|.env*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR15.1 connector job queue: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

echo "OK: PR15.1 connector job queue contract verification passed"
