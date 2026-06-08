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

echo "Checking ${REF}: PR15.3 connector runtime observability ..."

DOC="$(file_at_ref docs/product/15_connector_runtime_observability_failure_model.md)"
README="$(file_at_ref docs/product/README.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
MIGRATION="$(file_at_ref supabase/migrations/20260604120000_puls_integration_connector_runtime_observability.sql)"
ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/verikaynaklari.tsx)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
DATA_INDEX="$(file_at_ref src/lib/data/index.ts)"
SERVICE_WORKER="$(file_at_ref services/erp-connector/src/worker.ts)"
SERVICE_TEST="$(file_at_ref services/erp-connector/src/worker.test.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"

for needle in \
  "PR15.3, PR15.1 job queue ve PR15.2 worker skeleton üzerine güvenli runtime gözlemlenebilirliği ekler." \
  "Bu model Canias'a özel değildir." \
  "Provider-specific runtime sadece bu ortak omurganın üstünde eklenir." \
  "Retryable failure classes" \
  "AI job claim edemez, complete edemez, credential okuyamaz, import apply başlatamaz veya ERP'ye yazamaz."; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR15.3 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR15.3 implements safe failure classification" \
  "Provider API runtime, credential resolution, import apply, canonical writes, and ERP/source writeback remain closed."; do
  if ! grep -Fq "$needle" <<< "$ROADMAP"; then
    echo "FAIL: roadmap missing PR15.3 status needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR15.3 Connector runtime observability and failure model" \
  "15_connector_runtime_observability_failure_model.md" \
  "verify-15-connector-runtime-observability.sh"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR15.3 needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "connector_job_failure_class" \
  "connector_job_operator_severity" \
  "connector_job_events" \
  "failure_class" \
  "operator_severity" \
  "retry_after_seconds" \
  "dead_lettered_at" \
  "operator_review_required" \
  "classify_connector_job_failure" \
  "connector_job_retry_after_seconds" \
  "connector_job_operator_severity" \
  "connector_job_event_key" \
  "list_connector_job_events" \
  "CREATE OR REPLACE FUNCTION puls_integration.complete_connector_job" \
  "CREATE OR REPLACE FUNCTION puls_integration.recover_stale_connector_jobs" \
  "PULS_CONNECTOR_JOB_WORKER_ONLY"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: migration missing observability needle: $needle" >&2
    exit 1
  fi
done

for fn in \
  "complete_connector_job" \
  "recover_stale_connector_jobs" \
  "classify_connector_job_failure" \
  "connector_job_retry_after_seconds" \
  "connector_job_operator_severity" \
  "connector_job_event_key"; do
  if grep -F "GRANT EXECUTE ON FUNCTION puls_integration.${fn}" <<< "$MIGRATION" | grep -Fq "authenticated"; then
    echo "FAIL: ${fn} must not be granted to authenticated" >&2
    exit 1
  fi
done

if ! grep -Fq "GRANT EXECUTE ON FUNCTION puls_integration.list_connector_job_events(UUID, INTEGER)" <<< "$MIGRATION" || \
   ! grep -Fq "TO authenticated, service_role" <<< "$MIGRATION"; then
  echo "FAIL: list_connector_job_events must be readable by authenticated tenant operators" >&2
  exit 1
fi

for needle in \
  "ConnectorRuntimeFailureClass" \
  "ConnectorRuntimeOperatorSeverity" \
  "ConnectorJobEventRow" \
  "buildConnectorJobActivityEvent" \
  "list_connector_job_events" \
  "failureClassLabelKey" \
  "operatorReviewRequired" \
  "retryAfterSeconds"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing runtime observability needle: $needle" >&2
    exit 1
  fi
done

if grep -Eiq "select\\('\\*'\\)|sync_canias_now|write_to_canias|delete_or_overwrite|apply_import_batch" <<< "$ERP_ADAPTER"; then
  echo "FAIL: ERP adapter introduced runtime/writeback/apply pattern" >&2
  exit 1
fi

for needle in \
  "job.failureClass" \
  "job.retryAfterSeconds" \
  "job.operatorReviewRequired" \
  "operatorReviewSummary" \
  "erp.runtimeQueue.labels.failureClass"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route missing runtime observability UI needle: $needle" >&2
    exit 1
  fi
done

if grep -Eiq "type=[\"']password[\"']|name=[\"'](apiKey|api_key|token|secret|password|connectionString|ftpPassword)[\"']|claim_next_connector_job|complete_connector_job|heartbeat_connector_job" <<< "$ERP_ROUTE"; then
  echo "FAIL: ERP route introduced credential input or worker execution pattern" >&2
  exit 1
fi

for needle in \
  "buildSafeWorkerFailureObservation" \
  "failure_class" \
  "operator_severity" \
  "operator_review_required" \
  "retry_after_seconds" \
  "providerApiCalls: false" \
  "credentialReadback: false" \
  "canonicalWrites: false" \
  "sourceWriteback: false"; do
  if ! grep -Fq "$needle" <<< "$SERVICE_WORKER"; then
    echo "FAIL: worker missing safe failure observation needle: $needle" >&2
    exit 1
  fi
done

if grep -Eiq "canias\\.(com|local|test)|logo\\.(com|local|test)|ftp://|sftp://|/api/(sync|write|export)|credentials_ref|request_body|response_body|password|token" <<< "$SERVICE_WORKER"; then
  echo "FAIL: worker introduced provider endpoint, credential, or raw IO pattern" >&2
  exit 1
fi

for needle in \
  "buildSafeWorkerFailureObservation" \
  "operatorReviewRequired: true" \
  "retryAfterSeconds: 120" \
  "not.toContain('credentials_ref')" \
  "not.toContain('raw_payload')"; do
  if ! grep -Fq "$needle" <<< "$SERVICE_TEST"; then
    echo "FAIL: worker tests missing observability assertion: $needle" >&2
    exit 1
  fi
done

for needle in \
  "rpc:list_connector_job_events" \
  "failureClassLabelKey" \
  "operatorSeverityLabelKey" \
  "operatorReviewRequired: 1" \
  "erp.activityTimeline.events.connector_job_failed.title" \
  "not.toContain('raw_payload')" \
  "not.toContain('credentials_ref')" \
  "not.toContain('secret://')"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP tests missing observability assertion: $needle" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorRuntimeFailureClass" \
  "ConnectorRuntimeOperatorSeverity"; do
  if ! grep -Fq "$needle" <<< "$DATA_INDEX"; then
    echo "FAIL: data index missing observability export: $needle" >&2
    exit 1
  fi
done

for needle in \
  '"failureClasses"' \
  '"operatorSeverity"' \
  '"operatorReviewSummary"' \
  '"connector_job_succeeded"' \
  '"connector_job_retry_scheduled"' \
  '"connector_job_failed"' \
  '"connector_job_dead_lettered"' \
  '"wait_for_retry_window"'; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing observability key: $needle" >&2
    exit 1
  fi
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing observability key: $needle" >&2
    exit 1
  fi
done

BASE="$(git merge-base HEAD origin/main 2>/dev/null || true)"
if [[ "$REF" == "WORKTREE" && -n "$BASE" ]]; then
  while IFS= read -r changed; do
    case "$changed" in
      docs/product/15_connector_runtime_observability_failure_model.md|\
      docs/product/15_16_connector_runtime_ai_roadmap.md|\
      docs/product/README.md|\
      scripts/verify-15-connector-runtime-observability.sh|\
      supabase/migrations/20260604120000_puls_integration_connector_runtime_observability.sql|\
      services/erp-connector/src/worker.ts|\
      services/erp-connector/src/worker.test.ts|\
      src/i18n/locales/en-US.json|\
      src/i18n/locales/tr-TR.json|\
      src/lib/data/index.ts|\
      src/lib/data/setup/erp.ts|\
      src/lib/data/setup/erp.test.ts|\
      src/routes/_app/verikaynaklari.tsx)
        ;;
      supabase/.temp/cli-latest|supabase/.branches/*)
        ;;
      *)
        echo "FAIL: unexpected changed file for PR15.3: $changed" >&2
        exit 1
        ;;
    esac
  done < <(git diff --name-only "$BASE" --)
fi

echo "OK: PR15.3 connector runtime observability verification passed"
