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

echo "Checking ${REF}: PR16.2 apply change-set and risk ledger ..."

DOC="$(file_at_ref docs/product/16_2_apply_change_set_risk_ledger.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
MIGRATION="$(file_at_ref supabase/migrations/20260605110000_puls_integration_apply_change_set.sql)"
ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/verikaynaklari.tsx)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
DATA_INDEX="$(file_at_ref src/lib/data/index.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"
VERIFY_SELF="$(file_at_ref scripts/verify-16-2-apply-change-set.sh)"

for needle in \
  "PR16.2 turns a previewed dry-run import batch into immutable apply decision evidence" \
  "does not execute apply" \
  "Safe item sample list with field names only" \
  "append-only" \
  "PR16.3 can use this change-set"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.2 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "connector_apply_change_set_status" \
  "connector_apply_risk_class" \
  "connector_apply_change_sets" \
  "connector_apply_change_set_items" \
  "reject_connector_apply_change_set_mutation" \
  "PULS_CONNECTOR_APPLY_CHANGE_SET_IMMUTABLE" \
  "create_connector_apply_change_set" \
  "list_connector_apply_change_set_summaries" \
  "blocked_update_requires_policy" \
  "stale_target_requires_repreview" \
  "field_value_readback" \
  "raw_payload_readback" \
  "canonical_write_enabled BOOLEAN NOT NULL DEFAULT FALSE" \
  "source_writeback_enabled BOOLEAN NOT NULL DEFAULT FALSE" \
  "credential_readback_enabled BOOLEAN NOT NULL DEFAULT FALSE" \
  "GRANT EXECUTE ON FUNCTION puls_integration.create_connector_apply_change_set(UUID)" \
  "TO authenticated, service_role"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: PR16.2 migration missing needle: $needle" >&2
    exit 1
  fi
done

for forbidden in \
  "GRANT INSERT" \
  "GRANT UPDATE" \
  "apply_import_batch(" \
  "connector_job_type THEN 'import_apply'"; do
  if grep -Fq "$forbidden" <<< "$MIGRATION"; then
    echo "FAIL: PR16.2 migration must not contain forbidden needle: $forbidden" >&2
    exit 1
  fi
done

CHECKSUM_FUNCTION="$(
  awk '/CREATE OR REPLACE FUNCTION puls_integration\._connector_apply_change_set_checksum/,/^\$\$;/' \
    <<< "$MIGRATION"
)"
if grep -Fxq "      )," <<< "$CHECKSUM_FUNCTION"; then
  echo "FAIL: checksum helper has an invalid trailing comma after convert_to(...)" >&2
  exit 1
fi

for needle in \
  "ConnectorApplyChangeSet" \
  "ConnectorApplyRiskClass" \
  "ConnectorApplyChangeSetItemSummary" \
  "requestConnectorApplyChangeSet" \
  "list_connector_apply_change_set_summaries" \
  "create_connector_apply_change_set" \
  "import_apply_change_set_generated" \
  "applyChangeSet" \
  "field_value_readback: false" \
  "raw_payload_readback: false" \
  "canonical_write_open: false"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing PR16.2 needle: $needle" >&2
    exit 1
  fi
done

if grep -Fq "apply_import_batch" <<< "$ERP_ADAPTER$ERP_ROUTE"; then
  echo "FAIL: app code must not reference apply_import_batch" >&2
  exit 1
fi

for needle in \
  "requestConnectorApplyChangeSet" \
  "erp-apply-change-set" \
  "applyChangeSetRiskTone" \
  "erp.applyChangeSet.riskClasses" \
  "requestApplyChangeSetMutation"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route missing PR16.2 UI needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "requestConnectorApplyChangeSet" \
  "ConnectorApplyChangeSet" \
  "ConnectorApplyRiskClass" \
  "RequestConnectorApplyChangeSetResult"; do
  if ! grep -Fq "$needle" <<< "$DATA_INDEX"; then
    echo "FAIL: data index missing PR16.2 export: $needle" >&2
    exit 1
  fi
done

for needle in \
  "applyChangeSet" \
  "guarded_overwrite" \
  "destructive_equivalent" \
  "stale_preview" \
  "applyChangeSetBlocked"; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing PR16.2 key: $needle" >&2
    exit 1
  fi
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing PR16.2 key: $needle" >&2
    exit 1
  fi
done

for needle in \
  "exposes safe apply change-set risk evidence without raw payloads" \
  "generates connector apply change-set evidence without calling apply import" \
  "list_connector_apply_change_set_summaries" \
  "create_connector_apply_change_set" \
  "import_apply_change_set_generated" \
  "not.toContain('raw_payload')" \
  "not.toContain('apply_import_batch')"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP tests missing PR16.2 assertion: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.2 implements immutable change-set generation" \
  "worker \`import_apply\`" \
  "remain closed"; do
  if ! grep -Fq "$needle" <<< "$ROADMAP"; then
    echo "FAIL: roadmap missing PR16.2 status needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.2 apply change-set and risk ledger" \
  "16_2_apply_change_set_risk_ledger.md" \
  "20260605110000_puls_integration_apply_change_set.sql" \
  "scripts/verify-16-2-apply-change-set.sh"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR16.2 reference: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR16.2 apply change-set" <<< "$VERIFY_SELF"; then
  echo "FAIL: verify script self-check missing PR16.2 label" >&2
  exit 1
fi

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
      docs/product/16_2_apply_change_set_risk_ledger.md) ;;
      docs/product/README.md) ;;
      scripts/verify-16-2-apply-change-set.sh) ;;
      supabase/migrations/20260605110000_puls_integration_apply_change_set.sql) ;;
      src/i18n/locales/en-US.json) ;;
      src/i18n/locales/tr-TR.json) ;;
      src/lib/data/index.ts) ;;
      src/lib/data/setup/erp.test.ts) ;;
      src/lib/data/setup/erp.ts) ;;
      src/routes/_app/verikaynaklari.tsx) ;;
      *)
        echo "FAIL: unexpected changed path for PR16.2 apply change-set: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      services/**|supabase/seed/**|package.json|pnpm-lock.yaml|.env*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR16.2 apply change-set: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

echo "OK: PR16.2 apply change-set verification passed"
