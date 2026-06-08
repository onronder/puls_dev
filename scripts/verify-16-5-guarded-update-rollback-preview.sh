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

echo "Checking ${REF}: PR16.5 guarded update rollback preview ..."

DOC="$(file_at_ref docs/product/16_5_guarded_update_rollback_preview.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
MIGRATION="$(file_at_ref supabase/migrations/20260606130000_puls_integration_guarded_update_rollback_preview.sql)"
MIGRATION_FIX="$(file_at_ref supabase/migrations/20260606131000_puls_integration_rollback_preview_generation_disambiguation.sql)"
ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/verikaynaklari.tsx)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
DATA_INDEX="$(file_at_ref src/lib/data/index.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"

for needle in \
  "PR16.5 starts rollback safely by opening preview generation only" \
  "generate_connector_guarded_update_rollback_preview" \
  "list_connector_guarded_update_rollback_previews" \
  "pr16.5-guarded-update-rollback-preview-v1" \
  "rollback execution remains false" \
  "Handoff To The Next PR16.5 Step"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.5 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "connector_apply_rollback_previews" \
  "connector_apply_rollback_preview_items" \
  "reject_connector_rollback_preview_mutation" \
  "generate_connector_guarded_update_rollback_preview" \
  "list_connector_guarded_update_rollback_previews" \
  "ready_for_rollback_review" \
  "current_state_drift" \
  "rollback_snapshot_unavailable" \
  "field_diff_missing" \
  "pr16.5-guarded-update-rollback-preview-v1" \
  "guarded_update_rollback_preview_open" \
  "review_guarded_update_rollback_preview" \
  "GRANT EXECUTE ON FUNCTION puls_integration.generate_connector_guarded_update_rollback_preview(UUID)" \
  "TO authenticated, service_role" \
  "GRANT EXECUTE ON FUNCTION puls_integration.list_connector_guarded_update_rollback_previews(UUID, INTEGER)" \
  "GRANT SELECT, INSERT ON TABLE puls_integration.connector_apply_rollback_previews" \
  "GRANT SELECT, INSERT ON TABLE puls_integration.connector_apply_rollback_preview_items"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: PR16.5 migration missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.5 rollback preview generation ambiguity fix" \
  "generate_connector_guarded_update_rollback_preview" \
  "#variable_conflict use_column" \
  "pr16.5-guarded-update-rollback-preview-v1" \
  "current_state_drift" \
  "field_diff_missing" \
  "PULS_CONNECTOR_ROLLBACK_PREVIEW_ITEM_COUNT_MISMATCH"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION_FIX"; then
    echo "FAIL: PR16.5 hotfix migration missing needle: $needle" >&2
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
    echo "FAIL: PR16.5 migration missing closed-boundary needle: $needle" >&2
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
  "snapshot_payload\"" \
  "before_value\"" \
  "after_value\""; do
  if grep -Fq "$forbidden" <<< "$MIGRATION$MIGRATION_FIX$ERP_ADAPTER$ERP_ROUTE"; then
    echo "FAIL: PR16.5 contains forbidden needle: $forbidden" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorGuardedUpdateRollbackPreview" \
  "ConnectorGuardedUpdateRollbackPreviewItem" \
  "buildConnectorGuardedUpdateRollbackPreview" \
  "list_connector_guarded_update_rollback_previews" \
  "pr16.5-guarded-update-rollback-preview-v1" \
  "rollbackPreviewEnabled:" \
  "rollbackExecutionEnabled: false" \
  "compensatingExecutionEnabled: false" \
  "sourceWritebackEnabled: false" \
  "valueReadbackEnabled: false"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing PR16.5 needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "guardedUpdateRollbackPreview" \
  "erp-guarded-update-rollback-preview" \
  "previewOpen" \
  "executionClosed"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE$TR_LOCALE$EN_LOCALE"; then
    echo "FAIL: UI/locales missing PR16.5 needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorGuardedUpdateRollbackPreview" \
  "ConnectorGuardedUpdateRollbackPreviewAction" \
  "ConnectorGuardedUpdateRollbackPreviewItem"; do
  if ! grep -Fq "$needle" <<< "$DATA_INDEX"; then
    echo "FAIL: data index missing PR16.5 export: $needle" >&2
    exit 1
  fi
done

for needle in \
  "list_connector_guarded_update_rollback_previews" \
  "rollbackPreviewEnabled: true" \
  "rollbackExecutionEnabled: false" \
  "compensatingExecutionEnabled: false" \
  "not.toContain('snapshot_payload')" \
  "not.toContain('before_value')" \
  "not.toContain('after_value')"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP tests missing PR16.5 assertion: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.5 starts with guarded-update rollback preview only" \
  "16_5_guarded_update_rollback_preview.md" \
  "20260606130000_puls_integration_guarded_update_rollback_preview.sql" \
  "scripts/verify-16-5-guarded-update-rollback-preview.sh"; do
  if ! grep -Fq "$needle" <<< "$ROADMAP$README"; then
    echo "FAIL: roadmap/README missing PR16.5 reference: $needle" >&2
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
      docs/product/16_5_guarded_update_rollback_preview.md) ;;
      docs/product/README.md) ;;
      scripts/verify-16-5-guarded-update-rollback-preview.sh) ;;
      supabase/migrations/20260606130000_puls_integration_guarded_update_rollback_preview.sql) ;;
      supabase/migrations/20260606131000_puls_integration_rollback_preview_generation_disambiguation.sql) ;;
      src/i18n/locales/en-US.json) ;;
      src/i18n/locales/tr-TR.json) ;;
      src/lib/data/index.ts) ;;
      src/lib/data/setup/erp.test.ts) ;;
      src/lib/data/setup/erp.ts) ;;
      src/routes/_app/verikaynaklari.tsx) ;;
      *)
        echo "FAIL: unexpected changed path for PR16.5 rollback preview: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      services/**|supabase/seed/**|package.json|pnpm-lock.yaml|.env*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR16.5 rollback preview: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

echo "PR16.5 guarded update rollback preview verification passed."
