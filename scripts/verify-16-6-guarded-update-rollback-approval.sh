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

echo "Checking ${REF}: PR16.6 guarded update rollback approval ..."

DOC="$(file_at_ref docs/product/16_6_guarded_update_rollback_approval.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
MIGRATION="$(file_at_ref supabase/migrations/20260606140000_puls_integration_guarded_update_rollback_approval.sql)"
ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/verikaynaklari.tsx)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
DATA_INDEX="$(file_at_ref src/lib/data/index.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"

for needle in \
  "PR16.6 records admin approval" \
  "connector_apply_rollback_approvals" \
  "record_connector_guarded_update_rollback_approval" \
  "list_connector_guarded_update_rollback_approvals" \
  "pr16.6-guarded-update-rollback-approval-v1" \
  "rollback execution remains false" \
  "Handoff To PR16.7"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.6 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "connector_apply_rollback_approvals" \
  "reject_connector_rollback_approval_mutation" \
  "record_connector_guarded_update_rollback_approval" \
  "list_connector_guarded_update_rollback_approvals" \
  "_connector_apply_has_rollback_approval" \
  "pr16.6-guarded-update-rollback-approval-v1" \
  "guarded_update_rollback_approval_open" \
  "review_guarded_update_rollback_approval" \
  "PULS_CONNECTOR_ROLLBACK_APPROVAL_ITEM_BLOCKERS_PRESENT" \
  "PULS_CONNECTOR_ROLLBACK_APPROVAL_PREVIEW_COUNTS_INVALID" \
  "GRANT EXECUTE ON FUNCTION puls_integration.record_connector_guarded_update_rollback_approval(UUID)" \
  "TO authenticated, service_role" \
  "GRANT EXECUTE ON FUNCTION puls_integration.list_connector_guarded_update_rollback_approvals(UUID, INTEGER)" \
  "GRANT SELECT, INSERT ON TABLE puls_integration.connector_apply_rollback_approvals"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: PR16.6 migration missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "CHECK (rollback_execution_enabled IS FALSE)" \
  "CHECK (compensating_execution_enabled IS FALSE)" \
  "CHECK (source_writeback_enabled IS FALSE)" \
  "CHECK (credential_readback_enabled IS FALSE)" \
  "CHECK (value_readback_enabled IS FALSE)" \
  "'rollback_execution', FALSE" \
  "'compensating_execution', FALSE" \
  "'canonical_write', FALSE" \
  "'source_writeback', FALSE" \
  "'provider_api_calls', FALSE" \
  "'credential_readback', FALSE" \
  "'field_value_readback', FALSE" \
  "'raw_payload_readback', FALSE" \
  "'snapshot_payload_readback', FALSE"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: PR16.6 migration missing closed-boundary needle: $needle" >&2
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
  "source_writeback_enabled', TRUE" \
  "credential_readback_enabled', TRUE" \
  "raw_payload_readback', TRUE" \
  "snapshot_payload_readback', TRUE" \
  "field_value_readback', TRUE" \
  "rollback_execution', TRUE" \
  "compensating_execution', TRUE" \
  "rollback_execution_open: true" \
  "compensating_execution_open: true" \
  "snapshot_payload\"" \
  "before_value\"" \
  "after_value\""; do
  if grep -Fq "$forbidden" <<< "$MIGRATION$ERP_ADAPTER$ERP_ROUTE"; then
    echo "FAIL: PR16.6 contains forbidden needle: $forbidden" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorGuardedUpdateRollbackApproval" \
  "buildConnectorGuardedUpdateRollbackApproval" \
  "recordConnectorGuardedUpdateRollbackApproval" \
  "list_connector_guarded_update_rollback_approvals" \
  "pr16.6-guarded-update-rollback-approval-v1" \
  "rollbackApprovalEnabled:" \
  "rollbackExecutionEnabled: false" \
  "compensatingExecutionEnabled: false" \
  "sourceWritebackEnabled: false" \
  "valueReadbackEnabled: false"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing PR16.6 needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "guardedUpdateRollbackApproval" \
  "erp-guarded-update-rollback-approval" \
  "recordRollbackApprovalMutation" \
  "executionClosed"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE$TR_LOCALE$EN_LOCALE"; then
    echo "FAIL: UI/locales missing PR16.6 needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorGuardedUpdateRollbackApproval" \
  "ConnectorGuardedUpdateRollbackApprovalAction" \
  "ConnectorGuardedUpdateRollbackApprovalStatus" \
  "RecordConnectorGuardedUpdateRollbackApprovalResult" \
  "recordConnectorGuardedUpdateRollbackApproval"; do
  if ! grep -Fq "$needle" <<< "$DATA_INDEX"; then
    echo "FAIL: data index missing PR16.6 export: $needle" >&2
    exit 1
  fi
done

for needle in \
  "records rollback approval against preview checksum without opening rollback execution" \
  "record_connector_guarded_update_rollback_approval" \
  "rollbackApprovalEnabled: true" \
  "rollbackExecutionEnabled: false" \
  "not.toContain('snapshot_payload')" \
  "not.toContain('before_value')" \
  "not.toContain('after_value')"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP tests missing PR16.6 assertion: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.6 - Guarded Update Rollback Approval" \
  "16_6_guarded_update_rollback_approval.md" \
  "20260606140000_puls_integration_guarded_update_rollback_approval.sql" \
  "scripts/verify-16-6-guarded-update-rollback-approval.sh"; do
  if ! grep -Fq "$needle" <<< "$ROADMAP$README"; then
    echo "FAIL: roadmap/README missing PR16.6 reference: $needle" >&2
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
      docs/product/16_6_guarded_update_rollback_approval.md) ;;
      docs/product/README.md) ;;
      scripts/verify-16-6-guarded-update-rollback-approval.sh) ;;
      supabase/migrations/20260606140000_puls_integration_guarded_update_rollback_approval.sql) ;;
      src/i18n/locales/en-US.json) ;;
      src/i18n/locales/tr-TR.json) ;;
      src/lib/data/index.ts) ;;
      src/lib/data/setup/erp.test.ts) ;;
      src/lib/data/setup/erp.ts) ;;
      src/routes/_app/verikaynaklari.tsx) ;;
      *)
        echo "FAIL: unexpected changed path for PR16.6 rollback approval: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      services/**|supabase/seed/**|package.json|pnpm-lock.yaml|.env*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR16.6 rollback approval: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

echo "PR16.6 guarded update rollback approval verification passed."
