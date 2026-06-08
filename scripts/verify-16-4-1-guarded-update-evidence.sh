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

echo "Checking ${REF}: PR16.4.1 guarded update evidence ..."

DOC="$(file_at_ref docs/product/16_4_1_guarded_update_evidence.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
MIGRATION="$(file_at_ref supabase/migrations/20260605130000_puls_integration_guarded_update_evidence.sql)"
ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/verikaynaklari.tsx)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
DATA_INDEX="$(file_at_ref src/lib/data/index.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"

for needle in \
  "PR16.4.1 is the first guarded-update step" \
  "hash-only field diffs" \
  "service-role-only" \
  "does **not** execute updates" \
  "Handoff To PR16.4.2" \
  "review evidence only"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.4.1 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "connector_apply_field_diffs" \
  "connector_apply_rollback_snapshots" \
  "reject_connector_guarded_update_evidence_mutation" \
  "_connector_apply_guarded_update_field_allowed" \
  "_connector_apply_guarded_update_mutable_field_allowed" \
  "_connector_apply_current_reference_payload" \
  "generate_connector_guarded_update_evidence" \
  "list_connector_guarded_update_evidence" \
  "PULS_CONNECTOR_GUARDED_UPDATE_EVIDENCE_IMMUTABLE" \
  "PULS_CONNECTOR_GUARDED_UPDATE_STALE_TARGET" \
  "pr16.4.1-guarded-update-evidence-v1" \
  "field_value_readback', FALSE" \
  "raw_payload_readback', FALSE" \
  "GRANT EXECUTE ON FUNCTION puls_integration.generate_connector_guarded_update_evidence(UUID)" \
  "TO authenticated, service_role" \
  "GRANT EXECUTE ON FUNCTION puls_integration.list_connector_guarded_update_evidence(UUID, INTEGER)" \
  "GRANT SELECT, INSERT ON puls_integration.connector_apply_field_diffs TO service_role" \
  "GRANT SELECT, INSERT ON puls_integration.connector_apply_rollback_snapshots TO service_role"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: PR16.4.1 migration missing needle: $needle" >&2
    exit 1
  fi
done

if grep -F "GRANT SELECT" <<< "$MIGRATION" | grep -F "connector_apply_field_diffs" | grep -Fq "authenticated"; then
  echo "FAIL: field diff table must not grant direct authenticated SELECT" >&2
  exit 1
fi

if grep -F "GRANT SELECT" <<< "$MIGRATION" | grep -F "connector_apply_rollback_snapshots" | grep -Fq "authenticated"; then
  echo "FAIL: rollback snapshot table must not grant direct authenticated SELECT" >&2
  exit 1
fi

for forbidden in \
  "execute_connector_guarded_update_apply_job" \
  "enqueue_connector_guarded_update_apply_job" \
  "guarded_update_apply_job" \
  "provider_response" \
  "credentials_ref" \
  "UPDATE puls_core." \
  "source_writeback_enabled', TRUE" \
  "field_value_readback', TRUE" \
  "raw_payload_readback', TRUE"; do
  if grep -Fq "$forbidden" <<< "$MIGRATION"; then
    echo "FAIL: PR16.4.1 migration contains forbidden needle: $forbidden" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorGuardedUpdateEvidence" \
  "ConnectorGuardedUpdateFieldDiffSummary" \
  "requestConnectorGuardedUpdateEvidence" \
  "list_connector_guarded_update_evidence" \
  "generate_connector_guarded_update_evidence" \
  "import_apply_guarded_update_evidence_generated" \
  "safeToExecute: false" \
  "canonicalWriteEnabled: false" \
  "sourceWritebackEnabled: false" \
  "valueReadbackEnabled: false" \
  "raw_payload_readback: false"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing PR16.4.1 needle: $needle" >&2
    exit 1
  fi
done

if grep -Fq "apply_import_batch" <<< "$ERP_ADAPTER$ERP_ROUTE"; then
  echo "FAIL: PR16.4.1 app code must not reference apply_import_batch" >&2
  exit 1
fi

for needle in \
  "requestConnectorGuardedUpdateEvidence" \
  "requestGuardedUpdateEvidenceMutation" \
  "erp-guarded-update-evidence" \
  "guardedUpdateEvidence" \
  "fieldClass"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route missing PR16.4.1 UI needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "requestConnectorGuardedUpdateEvidence" \
  "ConnectorGuardedUpdateEvidence" \
  "ConnectorGuardedUpdateEvidenceStatus" \
  "RequestConnectorGuardedUpdateEvidenceResult"; do
  if ! grep -Fq "$needle" <<< "$DATA_INDEX"; then
    echo "FAIL: data index missing PR16.4.1 export: $needle" >&2
    exit 1
  fi
done

for needle in \
  "guardedUpdateEvidence" \
  "guardedUpdateEvidenceBlocked" \
  "evidence_ready" \
  "generate_evidence" \
  "hashPairReady" \
  "rollbackReady"; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing PR16.4.1 key: $needle" >&2
    exit 1
  fi
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing PR16.4.1 key: $needle" >&2
    exit 1
  fi
done

for needle in \
  "exposes guarded update evidence without values or execution flags" \
  "generates guarded update evidence without queueing execution or exposing values" \
  "generate_connector_guarded_update_evidence" \
  "import_apply_guarded_update_evidence_generated" \
  "not.toContain('snapshot_payload')" \
  "not.toContain('apply_import_batch')"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP tests missing PR16.4.1 assertion: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.4.1 adds guarded update evidence only" \
  "hash-only field diffs" \
  "service-role rollback snapshots" \
  "remain closed"; do
  if ! grep -Fq "$needle" <<< "$ROADMAP"; then
    echo "FAIL: roadmap missing PR16.4.1 status needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.4.1 guarded update evidence" \
  "16_4_1_guarded_update_evidence.md" \
  "20260605130000_puls_integration_guarded_update_evidence.sql" \
  "scripts/verify-16-4-1-guarded-update-evidence.sh"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR16.4.1 reference: $needle" >&2
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
      docs/product/16_4_1_guarded_update_evidence.md) ;;
      docs/product/README.md) ;;
      scripts/verify-16-4-1-guarded-update-evidence.sh) ;;
      supabase/migrations/20260605130000_puls_integration_guarded_update_evidence.sql) ;;
      src/i18n/locales/en-US.json) ;;
      src/i18n/locales/tr-TR.json) ;;
      src/lib/data/index.ts) ;;
      src/lib/data/setup/erp.test.ts) ;;
      src/lib/data/setup/erp.ts) ;;
      src/routes/_app/verikaynaklari.tsx) ;;
      *)
        echo "FAIL: unexpected changed path for PR16.4.1 guarded update evidence: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      services/**|supabase/seed/**|package.json|pnpm-lock.yaml|.env*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR16.4.1 guarded update evidence: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

echo "OK: PR16.4.1 guarded update evidence verification passed"
