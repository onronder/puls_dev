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

echo "Checking ${REF}: PR16.3 create-only worker apply ..."

DOC="$(file_at_ref docs/product/16_3_create_only_worker_apply.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
MIGRATION="$(file_at_ref supabase/migrations/20260605120000_puls_integration_create_only_worker_apply.sql)"
ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/erp.tsx)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
DATA_INDEX="$(file_at_ref src/lib/data/index.ts)"
WORKER="$(file_at_ref services/erp-connector/src/worker.ts)"
WORKER_TEST="$(file_at_ref services/erp-connector/src/worker.test.ts)"
WORKER_README="$(file_at_ref services/erp-connector/README.md)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"

for needle in \
  "first controlled canonical write path" \
  "worker-only create apply" \
  "existing-record updates" \
  "Employee import/apply" \
  "PULS_CONNECTOR_WORKER_IMPORT_APPLY_ENABLED=true" \
  "Handoff To PR16.4"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.3 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "connector_apply_object_events" \
  "enqueue_connector_create_only_apply_job" \
  "execute_connector_create_only_apply_job" \
  "list_connector_apply_object_events" \
  "_connector_apply_validate_create_only_change_set" \
  "_connector_apply_is_create_only_reference_entity" \
  "_connector_apply_create_only_field_allowed" \
  "PULS_CONNECTOR_IMPORT_APPLY_CLOSED" \
  "pr16.3-create-only-worker-apply-v1" \
  "PULS_CONNECTOR_CREATE_ONLY_TARGET_EXISTS" \
  "PULS_CONNECTOR_CREATE_ONLY_ITEM_COUNT_MISMATCH" \
  "PULS_CONNECTOR_CREATE_ONLY_CREATE_COUNT_MISMATCH" \
  "GRANT EXECUTE ON FUNCTION puls_integration.enqueue_connector_create_only_apply_job(UUID)" \
  "TO authenticated, service_role" \
  "GRANT EXECUTE ON FUNCTION puls_integration.execute_connector_create_only_apply_job(UUID, TEXT)" \
  "TO service_role"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: PR16.3 migration missing needle: $needle" >&2
    exit 1
  fi
done

EXECUTE_CREATE_ONLY_GRANT="$(
  grep -A1 -F "GRANT EXECUTE ON FUNCTION puls_integration.execute_connector_create_only_apply_job(UUID, TEXT)" \
    <<< "$MIGRATION" || true
)"
if grep -Fq "authenticated" <<< "$EXECUTE_CREATE_ONLY_GRANT"; then
  echo "FAIL: create-only worker execution RPC must not be granted to authenticated" >&2
  exit 1
fi

for forbidden in \
  "provider_response" \
  "credentials_ref"; do
  if grep -Fq "$forbidden" <<< "$MIGRATION"; then
    echo "FAIL: PR16.3 migration contains forbidden needle: $forbidden" >&2
    exit 1
  fi
done

if ! grep -Fq "employee" <<< "$MIGRATION"; then
  echo "FAIL: migration should explicitly keep employee outside PR16.3 scope through allowed entity checks/docs" >&2
  exit 1
fi

for needle in \
  "requestConnectorCreateOnlyApplyJob" \
  "enqueue_connector_create_only_apply_job" \
  "safeToExecute" \
  "worker_create_only_job" \
  "import_apply_create_only_queued" \
  "createOnlyApplyBlocked" \
  "import_apply_execution" \
  "field_value_readback: false" \
  "raw_payload_readback: false"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing PR16.3 needle: $needle" >&2
    exit 1
  fi
done

if grep -Fq "apply_import_batch" <<< "$ERP_ADAPTER$ERP_ROUTE$WORKER"; then
  echo "FAIL: app/worker code must not reference apply_import_batch" >&2
  exit 1
fi

for needle in \
  "requestConnectorCreateOnlyApplyJob" \
  "requestCreateOnlyApplyJobMutation" \
  "canRequestCreateOnlyApplyJob" \
  "erp.applyExecutionContract.actions.enqueueCreateOnly" \
  "worker_create_only_job"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route missing PR16.3 UI needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "requestConnectorCreateOnlyApplyJob" \
  "RequestConnectorCreateOnlyApplyJobResult"; do
  if ! grep -Fq "$needle" <<< "$DATA_INDEX"; then
    echo "FAIL: data index missing PR16.3 export: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PULS_CONNECTOR_WORKER_IMPORT_APPLY_ENABLED" \
  "execute_connector_create_only_apply_job" \
  "buildCreateOnlyApplyCompletionFromResult" \
  "buildCreateOnlyApplyFailureCompletion" \
  "CREATE_ONLY_APPLY_CONTRACT_VERSION" \
  "importApplyEnabled"; do
  if ! grep -Fq "$needle" <<< "$WORKER"; then
    echo "FAIL: worker missing PR16.3 needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "requires an explicit PR16 gate before claiming import_apply jobs" \
  "executes import_apply only through the PR16 create-only worker RPC" \
  "fails import_apply safely" \
  "not.toContain('raw_payload')" \
  "not.toContain('credentials_ref')"; do
  if ! grep -Fq "$needle" <<< "$WORKER_TEST"; then
    echo "FAIL: worker tests missing PR16.3 assertion: $needle" >&2
    exit 1
  fi
done

for needle in \
  "queues create-only apply only when approval, change-set, and worker gates are ready" \
  "blocks create-only apply before queue RPC" \
  "enqueue_connector_create_only_apply_job" \
  "not.toContain('apply_import_batch')" \
  "createOnlyApplyBlocked"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP tests missing PR16.3 assertion: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.3 create-only worker apply" \
  "PULS_CONNECTOR_WORKER_IMPORT_APPLY_ENABLED=true" \
  "noop_health,connector_runtime_preflight,import_apply"; do
  if ! grep -Fq "$needle" <<< "$WORKER_README"; then
    echo "FAIL: worker README missing PR16.3 ops needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "createOnlyApplyJob" \
  "createOnlyApplyBlocked" \
  "import_apply_create_only_queued" \
  "import_apply_create_only_completed" \
  "createOnlyWorkerReady" \
  "workerCreateOnlyJob"; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing PR16.3 key: $needle" >&2
    exit 1
  fi
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing PR16.3 key: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.3 opens worker-only create apply" \
  "16_3_create_only_worker_apply.md" \
  "20260605120000_puls_integration_create_only_worker_apply.sql" \
  "scripts/verify-16-3-create-only-worker-apply.sh"; do
  if ! grep -Fq "$needle" <<< "$ROADMAP$README"; then
    echo "FAIL: roadmap/README missing PR16.3 reference: $needle" >&2
    exit 1
  fi
done

echo "PR16.3 create-only worker apply verification passed."
