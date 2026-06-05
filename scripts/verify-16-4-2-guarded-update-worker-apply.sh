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

echo "Checking ${REF}: PR16.4.2 guarded update worker apply ..."

DOC="$(file_at_ref docs/product/16_4_2_guarded_update_worker_apply.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
MIGRATION="$(file_at_ref supabase/migrations/20260606100000_puls_integration_guarded_update_worker_apply.sql)"
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
  "worker-only guarded update apply" \
  "stale-hash-guarded reference-dimension" \
  "execute_connector_guarded_update_apply_job" \
  "Still Closed" \
  "No new Railway job type is required" \
  "Handoff To PR16.5"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.4.2 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "enqueue_connector_guarded_update_apply_job" \
  "execute_connector_guarded_update_apply_job" \
  "_connector_apply_validate_guarded_update_change_set" \
  "_connector_apply_update_reference_name" \
  "pr16.4.2-guarded-update-worker-apply-v1" \
  "apply_mode', 'guarded_update" \
  "PULS_CONNECTOR_GUARDED_UPDATE_APPROVAL_REQUIRED" \
  "PULS_CONNECTOR_GUARDED_UPDATE_FIELD_DIFF_SCOPE_INVALID" \
  "PULS_CONNECTOR_GUARDED_UPDATE_STALE_TARGET" \
  "PULS_CONNECTOR_GUARDED_UPDATE_WORKER_ONLY" \
  "PULS_CONNECTOR_IMPORT_APPLY_CLOSED" \
  "import_apply_guarded_update_completed" \
  "review_guarded_update_object_events" \
  "GRANT EXECUTE ON FUNCTION puls_integration.enqueue_connector_guarded_update_apply_job(UUID)" \
  "TO authenticated, service_role" \
  "GRANT EXECUTE ON FUNCTION puls_integration.execute_connector_guarded_update_apply_job(UUID, TEXT)" \
  "TO service_role"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: PR16.4.2 migration missing needle: $needle" >&2
    exit 1
  fi
done

EXECUTE_GUARDED_GRANT="$(
  grep -A1 -F "GRANT EXECUTE ON FUNCTION puls_integration.execute_connector_guarded_update_apply_job(UUID, TEXT)" \
    <<< "$MIGRATION" || true
)"
if grep -Fq "authenticated" <<< "$EXECUTE_GUARDED_GRANT"; then
  echo "FAIL: guarded update execution RPC must not be granted to authenticated" >&2
  exit 1
fi

for forbidden in \
  "provider_response" \
  "credentials_ref" \
  "source_writeback_enabled', TRUE" \
  "credential_readback_enabled', TRUE" \
  "raw_payload_readback', TRUE" \
  "field_value_readback', TRUE" \
  "rollback_execution', TRUE" \
  "apply_import_batch"; do
  if grep -Fq "$forbidden" <<< "$MIGRATION$ERP_ADAPTER$ERP_ROUTE$WORKER"; then
    echo "FAIL: PR16.4.2 contains forbidden needle: $forbidden" >&2
    exit 1
  fi
done

for needle in \
  "GUARDED_UPDATE_APPLY_CONTRACT_VERSION" \
  "ConnectorGuardedUpdateApplyResult" \
  "buildGuardedUpdateApplyCompletionFromResult" \
  "buildGuardedUpdateApplyFailureCompletion" \
  "execute_connector_guarded_update_apply_job" \
  "isGuardedUpdateApplyJob" \
  "raw_payload_readback: false" \
  "field_value_readback: false" \
  "rollback_execution: false"; do
  if ! grep -Fq "$needle" <<< "$WORKER"; then
    echo "FAIL: worker missing PR16.4.2 needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "routes guarded update import_apply jobs through the PR16.4.2 worker RPC" \
  "fails guarded update import_apply safely" \
  "does not mark guarded update apply successful" \
  "execute_connector_guarded_update_apply_job" \
  "not.toContain('raw_payload')" \
  "not.toContain('credentials_ref')"; do
  if ! grep -Fq "$needle" <<< "$WORKER_TEST"; then
    echo "FAIL: worker tests missing PR16.4.2 assertion: $needle" >&2
    exit 1
  fi
done

for needle in \
  "requestConnectorGuardedUpdateApplyJob" \
  "enqueue_connector_guarded_update_apply_job" \
  "worker_guarded_update_job" \
  "guardedUpdateExecutionReady" \
  "import_apply_guarded_update_queued" \
  "guardedUpdateApplyBlocked" \
  "field_value_readback: false" \
  "raw_payload_readback: false" \
  "rollback_execution: false"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing PR16.4.2 needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "requestConnectorGuardedUpdateApplyJob" \
  "requestGuardedUpdateApplyJobMutation" \
  "canRequestGuardedUpdateApplyJob" \
  "erp.applyExecutionContract.actions.enqueueGuardedUpdate" \
  "worker_guarded_update_job"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route missing PR16.4.2 UI needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "requestConnectorGuardedUpdateApplyJob" \
  "RequestConnectorGuardedUpdateApplyJobResult"; do
  if ! grep -Fq "$needle" <<< "$DATA_INDEX"; then
    echo "FAIL: data index missing PR16.4.2 export: $needle" >&2
    exit 1
  fi
done

for needle in \
  "guardedUpdateApplyJob" \
  "guardedUpdateApplyBlocked" \
  "guardedUpdateWorkerReady" \
  "workerGuardedUpdateJob" \
  "guardedUpdateWorkerOpen" \
  "guardedUpdateExecutionReady" \
  "enqueueGuardedUpdate"; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing PR16.4.2 key: $needle" >&2
    exit 1
  fi
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing PR16.4.2 key: $needle" >&2
    exit 1
  fi
done

for needle in \
  "queues guarded update apply only when evidence, approval, and worker gates are ready" \
  "blocks guarded update apply before queue RPC" \
  "enqueue_connector_guarded_update_apply_job" \
  "import_apply_guarded_update_queued"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP tests missing PR16.4.2 assertion: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.4.2 opens a narrow worker-only guarded update apply path" \
  "16_4_2_guarded_update_worker_apply.md" \
  "20260606100000_puls_integration_guarded_update_worker_apply.sql" \
  "scripts/verify-16-4-2-guarded-update-worker-apply.sh"; do
  if ! grep -Fq "$needle" <<< "$ROADMAP$README"; then
    echo "FAIL: roadmap/README missing PR16.4.2 reference: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.4.2 guarded update worker apply" \
  "execute_connector_guarded_update_apply_job" \
  "apply_mode=guarded_update"; do
  if ! grep -Fq "$needle" <<< "$WORKER_README"; then
    echo "FAIL: worker README missing PR16.4.2 ops needle: $needle" >&2
    exit 1
  fi
done

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
      docs/product/15_16_connector_runtime_ai_roadmap.md) ;;
      docs/product/16_4_2_guarded_update_worker_apply.md) ;;
      docs/product/README.md) ;;
      scripts/verify-16-4-2-guarded-update-worker-apply.sh) ;;
      services/erp-connector/README.md) ;;
      services/erp-connector/src/worker.test.ts) ;;
      services/erp-connector/src/worker.ts) ;;
      supabase/migrations/20260606100000_puls_integration_guarded_update_worker_apply.sql) ;;
      src/i18n/locales/en-US.json) ;;
      src/i18n/locales/tr-TR.json) ;;
      src/lib/data/index.ts) ;;
      src/lib/data/setup/erp.test.ts) ;;
      src/lib/data/setup/erp.ts) ;;
      src/routes/_app/erp.tsx) ;;
      *)
        echo "FAIL: unexpected changed path for PR16.4.2 guarded update worker apply: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      supabase/seed/**|package.json|pnpm-lock.yaml|.env*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR16.4.2 guarded update worker apply: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

echo "PR16.4.2 guarded update worker apply verification passed."
