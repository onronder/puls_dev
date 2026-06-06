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

echo "Checking ${REF}: PR16.7 guarded update rollback worker readiness ..."

DOC="$(file_at_ref docs/product/16_7_guarded_update_rollback_worker_readiness.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
MIGRATION="$(file_at_ref supabase/migrations/20260606150000_puls_integration_guarded_update_rollback_worker_readiness.sql)"
MIGRATION_FIX="$(file_at_ref supabase/migrations/20260606151000_puls_integration_rollback_worker_readiness_generation_disambiguation.sql)"
ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/erp.tsx)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
DATA_INDEX="$(file_at_ref src/lib/data/index.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"

for needle in \
  "PR16.7 creates the final guarded-update rollback worker handoff" \
  "connector_apply_rollback_worker_readiness" \
  "generate_connector_guarded_update_rollback_worker_readiness" \
  "list_connector_guarded_update_rollback_worker_readiness" \
  "pr16.7-guarded-update-rollback-worker-readiness-v1" \
  "rollback job enqueue remains false" \
  "Handoff To PR16.8"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.7 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "connector_apply_rollback_worker_readiness" \
  "reject_connector_rollback_worker_readiness_mutation" \
  "generate_connector_guarded_update_rollback_worker_readiness" \
  "list_connector_guarded_update_rollback_worker_readiness" \
  "_connector_apply_has_rollback_worker_readiness" \
  "pr16.7-guarded-update-rollback-worker-readiness-v1" \
  "pr16.7-rollback-worker-readiness-v1" \
  "guarded_update_rollback_worker_readiness_open" \
  "review_guarded_update_rollback_worker_readiness" \
  "PULS_CONNECTOR_ROLLBACK_WORKER_READINESS_BLOCKED" \
  "PULS_CONNECTOR_ROLLBACK_WORKER_READINESS_APPROVAL_INVALID" \
  "PULS_CONNECTOR_ROLLBACK_WORKER_READINESS_PREVIEW_INVALID" \
  "GRANT EXECUTE ON FUNCTION puls_integration.generate_connector_guarded_update_rollback_worker_readiness(UUID)" \
  "TO authenticated, service_role" \
  "GRANT EXECUTE ON FUNCTION puls_integration.list_connector_guarded_update_rollback_worker_readiness(UUID, INTEGER)" \
  "GRANT SELECT, INSERT ON TABLE puls_integration.connector_apply_rollback_worker_readiness"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: PR16.7 migration missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.7 rollback worker readiness generation ambiguity fix" \
  "generate_connector_guarded_update_rollback_worker_readiness" \
  "#variable_conflict use_column" \
  "classified AS" \
  "classified_row.field_diff_count" \
  "classified_row.original_apply_event_count" \
  "classified_row.current_state_matches_apply" \
  "pr16.7-guarded-update-rollback-worker-readiness-v1" \
  "PULS_CONNECTOR_ROLLBACK_WORKER_READINESS_BLOCKED"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION_FIX"; then
    echo "FAIL: PR16.7 hotfix migration missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "CHECK (rollback_job_enqueue_enabled IS FALSE)" \
  "CHECK (rollback_execution_enabled IS FALSE)" \
  "CHECK (canonical_write_enabled IS FALSE)" \
  "CHECK (compensating_execution_enabled IS FALSE)" \
  "CHECK (source_writeback_enabled IS FALSE)" \
  "CHECK (credential_readback_enabled IS FALSE)" \
  "CHECK (value_readback_enabled IS FALSE)" \
  "CHECK (provider_api_calls_enabled IS FALSE)" \
  "'rollback_job_enqueue', FALSE" \
  "'rollback_execution', FALSE" \
  "'canonical_write', FALSE" \
  "'compensating_execution', FALSE" \
  "'source_writeback', FALSE" \
  "'provider_api_calls', FALSE" \
  "'credential_readback', FALSE" \
  "'field_value_readback', FALSE" \
  "'raw_payload_readback', FALSE" \
  "'snapshot_payload_readback', FALSE"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: PR16.7 migration missing closed-boundary needle: $needle" >&2
    exit 1
  fi
done

for forbidden in \
  "execute_connector_rollback" \
  "execute_connector_compensating" \
  "enqueue_connector_rollback" \
  "enqueue_connector_compensating" \
  "UPDATE puls_core." \
  "DELETE FROM puls_core." \
  "rollback_job_enqueue', TRUE" \
  "rollback_execution', TRUE" \
  "canonical_write', TRUE" \
  "compensating_execution', TRUE" \
  "source_writeback_enabled', TRUE" \
  "credential_readback_enabled', TRUE" \
  "raw_payload_readback', TRUE" \
  "snapshot_payload_readback', TRUE" \
  "field_value_readback', TRUE" \
  "rollback_execution_open: true" \
  "snapshot_payload\"" \
  "before_value\"" \
  "after_value\""; do
  if grep -Fq "$forbidden" <<< "$MIGRATION$MIGRATION_FIX$ERP_ADAPTER$ERP_ROUTE"; then
    echo "FAIL: PR16.7 contains forbidden needle: $forbidden" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorGuardedUpdateRollbackWorkerReadiness" \
  "buildConnectorGuardedUpdateRollbackWorkerReadiness" \
  "requestConnectorGuardedUpdateRollbackWorkerReadiness" \
  "list_connector_guarded_update_rollback_worker_readiness" \
  "generate_connector_guarded_update_rollback_worker_readiness" \
  "pr16.7-guarded-update-rollback-worker-readiness-v1" \
  "workerHandoffReady:" \
  "rollbackJobEnqueueEnabled: false" \
  "rollbackExecutionEnabled: false" \
  "canonicalWriteEnabled: false" \
  "sourceWritebackEnabled: false" \
  "valueReadbackEnabled: false"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing PR16.7 needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "guardedUpdateRollbackWorkerReadiness" \
  "erp-guarded-update-rollback-worker-readiness" \
  "requestRollbackWorkerReadinessMutation" \
  "rollbackJobClosed"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE$TR_LOCALE$EN_LOCALE"; then
    echo "FAIL: UI/locales missing PR16.7 needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorGuardedUpdateRollbackWorkerReadiness" \
  "ConnectorGuardedUpdateRollbackWorkerReadinessAction" \
  "ConnectorGuardedUpdateRollbackWorkerReadinessStatus" \
  "RequestConnectorGuardedUpdateRollbackWorkerReadinessResult" \
  "requestConnectorGuardedUpdateRollbackWorkerReadiness"; do
  if ! grep -Fq "$needle" <<< "$DATA_INDEX"; then
    echo "FAIL: data index missing PR16.7 export: $needle" >&2
    exit 1
  fi
done

for needle in \
  "requests rollback worker readiness without enqueueing rollback execution" \
  "generate_connector_guarded_update_rollback_worker_readiness" \
  "workerHandoffReady: true" \
  "rollbackJobEnqueueEnabled: false" \
  "rollbackExecutionEnabled: false" \
  "not.toContain('snapshot_payload')" \
  "not.toContain('before_value')" \
  "not.toContain('after_value')"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP tests missing PR16.7 assertion: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.7 - Guarded Update Rollback Worker Readiness" \
  "16_7_guarded_update_rollback_worker_readiness.md" \
  "20260606150000_puls_integration_guarded_update_rollback_worker_readiness.sql" \
  "scripts/verify-16-7-guarded-update-rollback-worker-readiness.sh"; do
  if ! grep -Fq "$needle" <<< "$ROADMAP$README"; then
    echo "FAIL: roadmap/README missing PR16.7 reference: $needle" >&2
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
      docs/product/16_7_guarded_update_rollback_worker_readiness.md) ;;
      docs/product/README.md) ;;
      scripts/verify-16-7-guarded-update-rollback-worker-readiness.sh) ;;
      supabase/migrations/20260606150000_puls_integration_guarded_update_rollback_worker_readiness.sql) ;;
      supabase/migrations/20260606151000_puls_integration_rollback_worker_readiness_generation_disambiguation.sql) ;;
      src/i18n/locales/en-US.json) ;;
      src/i18n/locales/tr-TR.json) ;;
      src/lib/data/index.ts) ;;
      src/lib/data/setup/erp.test.ts) ;;
      src/lib/data/setup/erp.ts) ;;
      src/routes/_app/erp.tsx) ;;
      *)
        echo "FAIL: unexpected changed path for PR16.7 rollback worker readiness: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      services/**|supabase/seed/**|package.json|pnpm-lock.yaml|.env*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR16.7 rollback worker readiness: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

echo "PR16.7 guarded update rollback worker readiness verification passed."
