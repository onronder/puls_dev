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

echo "Checking ${REF}: PR16.4.4 guarded update recovery runbook ..."

DOC="$(file_at_ref docs/product/16_4_4_guarded_update_recovery_runbook.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
MIGRATION="$(file_at_ref supabase/migrations/20260606120000_puls_integration_guarded_update_recovery_runbook.sql)"
ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/erp.tsx)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
DATA_INDEX="$(file_at_ref src/lib/data/index.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"

for needle in \
  "PR16.4.4 turns PR16.4.3 recovery readiness" \
  "list_connector_guarded_update_recovery_runbooks" \
  "pr16.4.4-guarded-update-recovery-runbook-v1" \
  "rollback_preview_enabled remains false" \
  "Handoff To PR16.5"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.4.4 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "list_connector_guarded_update_recovery_runbooks" \
  "ready_for_rollback_preview" \
  "evidence_gap" \
  "compensating_review_required" \
  "pr16.4.4-guarded-update-recovery-runbook-v1" \
  "guarded_update_recovery_runbook_open" \
  "review_guarded_update_recovery_runbook" \
  "FALSE AS rollback_preview_enabled" \
  "FALSE AS rollback_execution_enabled" \
  "FALSE AS compensating_execution_enabled" \
  "FALSE AS source_writeback_enabled" \
  "FALSE AS credential_readback_enabled" \
  "FALSE AS value_readback_enabled" \
  "GRANT EXECUTE ON FUNCTION puls_integration.list_connector_guarded_update_recovery_runbooks(UUID, INTEGER)" \
  "TO authenticated, service_role"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: PR16.4.4 migration missing needle: $needle" >&2
    exit 1
  fi
done

for forbidden in \
  "provider_response" \
  "credentials_ref" \
  "source_writeback_enabled', TRUE" \
  "credential_readback_enabled', TRUE" \
  "raw_payload_readback', TRUE" \
  "field_value_readback', TRUE" \
  "rollback_execution', TRUE" \
  "TRUE AS rollback_preview_enabled" \
  "TRUE AS rollback_execution_enabled" \
  "TRUE AS compensating_execution_enabled" \
  "execute_connector_rollback" \
  "execute_connector_compensating" \
  "UPDATE puls_core." \
  "apply_import_batch"; do
  if grep -Fq "$forbidden" <<< "$MIGRATION$ERP_ADAPTER$ERP_ROUTE"; then
    echo "FAIL: PR16.4.4 contains forbidden needle: $forbidden" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorGuardedUpdateRecoveryRunbook" \
  "ConnectorGuardedUpdateRecoveryRunbookStep" \
  "buildConnectorGuardedUpdateRecoveryRunbook" \
  "list_connector_guarded_update_recovery_runbooks" \
  "pr16.4.4-guarded-update-recovery-runbook-v1" \
  "rollbackPreviewEnabled: false" \
  "rollbackExecutionEnabled: false" \
  "compensatingExecutionEnabled: false" \
  "sourceWritebackEnabled: false" \
  "valueReadbackEnabled: false"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing PR16.4.4 needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "guardedUpdateRecoveryRunbook" \
  "erp-guarded-update-recovery-runbook" \
  "previewClosed" \
  "executionClosed"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE$TR_LOCALE$EN_LOCALE"; then
    echo "FAIL: UI/locales missing PR16.4.4 needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorGuardedUpdateRecoveryRunbook" \
  "ConnectorGuardedUpdateRecoveryRunbookAction" \
  "ConnectorGuardedUpdateRecoveryRunbookStep"; do
  if ! grep -Fq "$needle" <<< "$DATA_INDEX"; then
    echo "FAIL: data index missing PR16.4.4 export: $needle" >&2
    exit 1
  fi
done

for needle in \
  "list_connector_guarded_update_recovery_runbooks" \
  "rollbackPreviewEnabled: false" \
  "compensatingExecutionEnabled: false" \
  "not.toContain('snapshot_payload')" \
  "not.toContain('before_value')" \
  "not.toContain('after_value')"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP tests missing PR16.4.4 assertion: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.4.4 adds an operator-facing recovery runbook read model" \
  "16_4_4_guarded_update_recovery_runbook.md" \
  "20260606120000_puls_integration_guarded_update_recovery_runbook.sql" \
  "scripts/verify-16-4-4-guarded-update-recovery-runbook.sh"; do
  if ! grep -Fq "$needle" <<< "$ROADMAP$README"; then
    echo "FAIL: roadmap/README missing PR16.4.4 reference: $needle" >&2
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
      docs/product/16_4_4_guarded_update_recovery_runbook.md) ;;
      docs/product/README.md) ;;
      scripts/verify-16-4-4-guarded-update-recovery-runbook.sh) ;;
      supabase/migrations/20260606120000_puls_integration_guarded_update_recovery_runbook.sql) ;;
      src/i18n/locales/en-US.json) ;;
      src/i18n/locales/tr-TR.json) ;;
      src/lib/data/index.ts) ;;
      src/lib/data/setup/erp.test.ts) ;;
      src/lib/data/setup/erp.ts) ;;
      src/routes/_app/erp.tsx) ;;
      *)
        echo "FAIL: unexpected changed path for PR16.4.4 recovery runbook: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      services/**|supabase/seed/**|package.json|pnpm-lock.yaml|.env*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR16.4.4 recovery runbook: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

echo "PR16.4.4 guarded update recovery runbook verification passed."
