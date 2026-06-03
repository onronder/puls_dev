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

echo "Checking ${REF}: PR14.16 connector import preview ..."

DOC="$(file_at_ref docs/product/14_connector_import_preview_dry_run.md)"
README="$(file_at_ref docs/product/README.md)"
ROADMAP="$(file_at_ref docs/product/14_connector_implementation_roadmap.md)"
MIGRATION="$(file_at_ref supabase/migrations/20260603140000_puls_integration_connector_import_preview.sql)"
PROOF_SQL="$(file_at_ref supabase/seed/puls-sanayi-v1/sql/12_apply_connector_import_preview_proof.sql)"
ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/erp.tsx)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
DATA_INDEX="$(file_at_ref src/lib/data/index.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"
VERIFY_SELF="$(file_at_ref scripts/verify-14-connector-import-preview.sh)"

for needle in \
  "PR14.16 adds connector import preview dry-run, not import apply." \
  "Preview classifies create, update, and skip outcomes without writing canonical records." \
  "No live connector runtime, credential capture, apply_import_batch call, sync execution, or ERP writeback is enabled." \
  "Canias is one source profile; import preview is connector-agnostic." \
  "Payload readback is forbidden in product UI and adapter output." \
  "The proof SQL may create a dry-run batch, but it must not validate, preview, or apply it automatically."; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR14.16 doc missing import preview needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "preview_action" \
  "preview_skip_code" \
  "previewed_at" \
  "CREATE OR REPLACE FUNCTION puls_integration.preview_import_diff" \
  "CREATE OR REPLACE FUNCTION puls_integration.list_connector_import_preview_records" \
  "dry_run" \
  "preview_action IN ('create', 'update', 'skip')" \
  "GRANT EXECUTE ON FUNCTION puls_integration.list_connector_import_preview_records"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: PR14.16 migration missing import preview needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "source_checksum = 'pr14_16_connector_preview_proof_v1'" \
  "'uploaded'" \
  "'dry_run'" \
  "raw_payload" \
  "NULL" \
  "PR14.16 connector preview proof batch ready"; do
  if ! grep -Fq "$needle" <<< "$PROOF_SQL"; then
    echo "FAIL: PR14.16 proof SQL missing dry-run proof needle: $needle" >&2
    exit 1
  fi
done

if grep -Eiq "validate_import_batch|preview_import_diff|apply_import_batch" <<< "$PROOF_SQL"; then
  echo "FAIL: proof SQL must create pending dry-run batch only; no validate/preview/apply call" >&2
  exit 1
fi

for needle in \
  "ConnectorImportPreview" \
  "RunConnectorImportPreviewResult" \
  "importPreview" \
  "buildConnectorImportPreview" \
  "runConnectorImportPreview" \
  "validate_import_batch" \
  "preview_import_diff" \
  "list_connector_import_preview_records" \
  "sync_type: 'import_preview'" \
  "event_key: 'import_preview_generated'" \
  "event_key: 'import_preview_blocked'"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing import preview needle: $needle" >&2
    exit 1
  fi
done

if grep -Fq "apply_import_batch" <<< "$ERP_ADAPTER"; then
  echo "FAIL: ERP adapter must not call apply_import_batch in PR14.16" >&2
  exit 1
fi

if grep -Fq "credentials_ref" <<< "$ERP_ADAPTER"; then
  echo "FAIL: ERP adapter must not select or expose credentials_ref" >&2
  exit 1
fi

if grep -Fq "select('*')" <<< "$ERP_ADAPTER"; then
  echo "FAIL: ERP adapter must not use select('*') on connector data" >&2
  exit 1
fi

for needle in \
  "runConnectorImportPreview" \
  "erp.sections.importPreview" \
  "erp.importPreview.metrics.preview" \
  "erp.importPreview.recordActions" \
  "SearchCheck" \
  "data.importPreview.records"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route missing import preview UI needle: $needle" >&2
    exit 1
  fi
done

if grep -Eiq "raw_payload|sanitized_payload|normalized_payload|credentials_ref|apply_import_batch|type=[\"']password[\"']|name=[\"'](apiKey|api_key|token|secret|password|connectionString|ftpPassword)[\"']" <<< "$ERP_ROUTE"; then
  echo "FAIL: ERP route introduced payload/credential readback or apply UI" >&2
  exit 1
fi

if grep -Eiq "chat\.completions|responses\.create|OPENAI_API_KEY|CANIAS_API_KEY|sync_canias_now|write_to_canias|delete_or_overwrite|live connector runtime enabled" <<< "$ERP_ADAPTER"$'\n'"$ERP_ROUTE"; then
  echo "FAIL: PR14.16 introduced runtime, AI, or destructive connector enablement pattern" >&2
  exit 1
fi

for needle in \
  '"importPreview"' \
  '"preview_ready"' \
  '"run_dry_run_preview"' \
  '"import_preview_generated"' \
  '"import_preview_blocked"' \
  '"import_preview_has_errors"' \
  '"review_import_preview"' \
  '"review_import_errors"'; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing import preview key: $needle" >&2
    exit 1
  fi
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing import preview key: $needle" >&2
    exit 1
  fi
done

for needle in \
  "runConnectorImportPreview" \
  "safe dry-run import preview records" \
  "validate_import_batch" \
  "preview_import_diff" \
  "not.toContain('raw_payload')" \
  "not.toContain('sanitized_payload')" \
  "not.toContain('provider_response')" \
  "apply_import_batch"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP tests missing import preview case: $needle" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorImportPreview" \
  "ConnectorImportPreviewRecord" \
  "RunConnectorImportPreviewResult" \
  "runConnectorImportPreview"; do
  if ! grep -Fq "$needle" <<< "$DATA_INDEX"; then
    echo "FAIL: data index missing import preview export: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.16 Connector import preview dry-run" \
  "14_connector_import_preview_dry_run.md" \
  "20260603140000_puls_integration_connector_import_preview.sql" \
  "12_apply_connector_import_preview_proof.sql" \
  "scripts/verify-14-connector-import-preview.sh"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR14.16 reference: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.16 - Connector Import Preview Dry Run" \
  "PR14.16 adds connector import preview dry-run, not import apply." \
  "The product action never calls \`apply_import_batch\`."; do
  if ! grep -Fq "$needle" <<< "$ROADMAP"; then
    echo "FAIL: roadmap missing PR14.16 reference: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR14.16 connector import preview" <<< "$VERIFY_SELF"; then
  echo "FAIL: verify script self-check missing PR14.16 label" >&2
  exit 1
fi

if [[ "$REF" == "WORKTREE" ]]; then
  CHANGED_FILES="$(
    git diff --name-only "$(git merge-base origin/main HEAD)"
    git ls-files --others --exclude-standard
  )"
else
  CHANGED_FILES="$(git diff --name-only "$(git merge-base origin/main "$REF")...$REF")"
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
      docs/product/14_connector_import_preview_dry_run.md) ;;
      docs/product/14_connector_implementation_roadmap.md) ;;
      docs/product/README.md) ;;
      scripts/verify-14-connector-import-preview.sh) ;;
      supabase/migrations/20260603140000_puls_integration_connector_import_preview.sql) ;;
      supabase/seed/puls-sanayi-v1/sql/12_apply_connector_import_preview_proof.sql) ;;
      src/i18n/locales/en-US.json) ;;
      src/i18n/locales/tr-TR.json) ;;
      src/lib/data/index.ts) ;;
      src/lib/data/setup/erp.test.ts) ;;
      src/lib/data/setup/erp.ts) ;;
      src/routes/_app/erp.tsx) ;;
      *)
        echo "FAIL: unexpected changed path for PR14.16 import preview: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      supabase/seed/puls-sanayi-v1/csv/*|supabase/seed/puls-sanayi-v1/manifest.json|services/*/src/*|services/*/package.json|package.json|.env*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR14.16 import preview: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

echo "OK: PR14.16 connector import preview verification passed"
