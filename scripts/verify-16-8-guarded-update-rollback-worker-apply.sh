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

echo "Checking ${REF}: PR16.8 guarded update rollback worker apply ..."

DOC="$(file_at_ref docs/product/16_8_guarded_update_rollback_worker_apply.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
MIGRATION="$(file_at_ref supabase/migrations/20260606160000_puls_integration_guarded_update_rollback_worker_apply.sql)"
WORKER="$(file_at_ref services/erp-connector/src/worker.ts)"
WORKER_README="$(file_at_ref services/erp-connector/README.md)"
WORKER_TEST="$(file_at_ref services/erp-connector/src/worker.test.ts)"
ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/verikaynaklari.tsx)"
DATA_INDEX="$(file_at_ref src/lib/data/index.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"

for needle in \
  "PR16.8 opens the first rollback execution path" \
  "enqueue_connector_guarded_update_rollback_apply_job" \
  "execute_connector_guarded_update_rollback_apply_job" \
  "service-role-only" \
  "safe reference-dimension \`name\` restores" \
  "Handoff To PR16.9"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.8 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "connector_apply_object_events_operation_check" \
  "connector_apply_object_events_change_record_operation_idx" \
  "_connector_apply_validate_guarded_update_rollback_readiness" \
  "enqueue_connector_guarded_update_rollback_apply_job" \
  "_connector_apply_restore_reference_name" \
  "execute_connector_guarded_update_rollback_apply_job" \
  "pr16.8-guarded-update-rollback-worker-apply-v1" \
  "import_apply_guarded_update_rollback" \
  "'rollback'::puls_integration.connector_apply_operation" \
  "PULS_CONNECTOR_ROLLBACK_WORKER_ONLY" \
  "PULS_CONNECTOR_ROLLBACK_WORKER_STALE_TARGET" \
  "PULS_CONNECTOR_ROLLBACK_WORKER_ALREADY_APPLIED" \
  "original_apply_event_id" \
  "snapshot_payload_readback', FALSE" \
  "GRANT EXECUTE ON FUNCTION puls_integration.enqueue_connector_guarded_update_rollback_apply_job(UUID)" \
  "TO authenticated, service_role" \
  "GRANT EXECUTE ON FUNCTION puls_integration.execute_connector_guarded_update_rollback_apply_job(UUID, TEXT)" \
  "TO service_role"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: PR16.8 migration missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "SET name = v_name, updated_at = NOW()" \
  "puls_integration._connector_apply_hash_jsonb(p_snapshot.snapshot_payload)" \
  "v_current_hash IS NULL OR v_current_hash IS DISTINCT FROM v_expected_post_apply_hash" \
  "p_snapshot.hot_retention_expires_at <= NOW()" \
  "PERFORM puls_integration._import_upsert_identity_map"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: PR16.8 migration missing restore guard needle: $needle" >&2
    exit 1
  fi
done

for forbidden in \
  "DELETE FROM puls_core." \
  "source_writeback_enabled', TRUE" \
  "credential_readback_enabled', TRUE" \
  "provider_api_calls', TRUE" \
  "raw_payload_readback', TRUE" \
  "field_value_readback', TRUE" \
  "snapshot_payload_readback', TRUE" \
  "compensating_execution_enabled', TRUE" \
  "execute_connector_compensating" \
  "provider_response" \
  "credentials_ref"; do
  if grep -Fq "$forbidden" <<< "$MIGRATION$WORKER$ERP_ADAPTER$ERP_ROUTE"; then
    echo "FAIL: PR16.8 contains forbidden needle: $forbidden" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorGuardedUpdateRollbackApplyResult" \
  "GUARDED_UPDATE_ROLLBACK_APPLY_CONTRACT_VERSION" \
  "buildGuardedUpdateRollbackApplyCompletionFromResult" \
  "buildGuardedUpdateRollbackApplyFailureCompletion" \
  "isGuardedUpdateRollbackApplyJob" \
  "execute_connector_guarded_update_rollback_apply_job" \
  "review_guarded_update_rollback_object_events" \
  "snapshot_payload_readback: false" \
  "compensating_execution: false"; do
  if ! grep -Fq "$needle" <<< "$WORKER"; then
    echo "FAIL: worker missing PR16.8 needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.8 guarded update rollback worker apply" \
  "apply_mode=guarded_update_rollback" \
  "execute_connector_guarded_update_rollback_apply_job" \
  "does not call provider APIs" \
  "expose snapshot payloads"; do
  if ! grep -Fq "$needle" <<< "$WORKER_README"; then
    echo "FAIL: worker README missing PR16.8 needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "routes guarded update rollback import_apply jobs through the PR16.8 worker RPC" \
  "fails guarded update rollback import_apply safely" \
  "does not mark guarded update rollback apply successful" \
  "execute_connector_guarded_update_rollback_apply_job" \
  "snapshot_payload_readback: false"; do
  if ! grep -Fq "$needle" <<< "$WORKER_TEST"; then
    echo "FAIL: worker tests missing PR16.8 assertion: $needle" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorGuardedUpdateRollbackApplyJobRow" \
  "RequestConnectorGuardedUpdateRollbackApplyJobResult" \
  "requestConnectorGuardedUpdateRollbackApplyJob" \
  "enqueue_connector_guarded_update_rollback_apply_job" \
  "import_apply_guarded_update_rollback_queued" \
  "pr16.8-guarded-update-rollback-worker-apply-v1" \
  "rollback_execution_open: true" \
  "canonical_write_open: true" \
  "source_writeback_open: false" \
  "snapshot_payload_readback: false"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing PR16.8 needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "queues guarded update rollback apply only after worker readiness handoff is ready" \
  "enqueue_connector_guarded_update_rollback_apply_job" \
  "import_apply_guarded_update_rollback_queued" \
  "rollback_execution_open: true" \
  "canonical_write_open: true" \
  "not.toContain('\"snapshot_payload\":')"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP tests missing PR16.8 assertion: $needle" >&2
    exit 1
  fi
done

for needle in \
  "requestConnectorGuardedUpdateRollbackApplyJob" \
  "guardedUpdateRollbackWorkerApply" \
  "erp-guarded-update-rollback-worker-apply" \
  "requestRollbackApplyJobMutation" \
  "guardedUpdateRollbackApplyJob"; do
  if ! grep -Fq "$needle" <<< "$DATA_INDEX$ERP_ROUTE$TR_LOCALE$EN_LOCALE"; then
    echo "FAIL: UI/locales/data index missing PR16.8 needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.8 - Guarded Update Rollback Worker Apply" \
  "PR16.9 - Notification Center Foundation" \
  "PR16.10 - Canias Runtime Spike" \
  "PR16.11 - AI Operational Recommendations" \
  "16_8_guarded_update_rollback_worker_apply.md" \
  "20260606160000_puls_integration_guarded_update_rollback_worker_apply.sql" \
  "scripts/verify-16-8-guarded-update-rollback-worker-apply.sh"; do
  if ! grep -Fq "$needle" <<< "$ROADMAP$README"; then
    echo "FAIL: roadmap/README missing PR16.8 reference: $needle" >&2
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
      docs/product/16_8_guarded_update_rollback_worker_apply.md) ;;
      docs/product/README.md) ;;
      scripts/verify-16-8-guarded-update-rollback-worker-apply.sh) ;;
      services/erp-connector/README.md) ;;
      services/erp-connector/src/worker.test.ts) ;;
      services/erp-connector/src/worker.ts) ;;
      src/i18n/locales/en-US.json) ;;
      src/i18n/locales/tr-TR.json) ;;
      src/lib/data/index.ts) ;;
      src/lib/data/setup/erp.test.ts) ;;
      src/lib/data/setup/erp.ts) ;;
      src/routes/_app/verikaynaklari.tsx) ;;
      supabase/migrations/20260606160000_puls_integration_guarded_update_rollback_worker_apply.sql) ;;
      *)
        echo "FAIL: unexpected changed path for PR16.8 rollback worker apply: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

echo "PR16.8 guarded update rollback worker apply verification passed."
