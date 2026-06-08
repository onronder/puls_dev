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

echo "Checking ${REF}: PR16.10.10 DataSource operational hardening ..."

DOC="$(file_at_ref docs/product/16_10_10_datasource_operational_hardening.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
MIGRATION="$(file_at_ref supabase/migrations/20260608130000_puls_datasource_operational_hardening.sql)"
CONTRACT="$(file_at_ref src/lib/data/setup/file-import-contract.ts)"
ERP_DATA="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
NOTIFICATIONS="$(file_at_ref src/lib/data/app/notifications.ts)"
NOTIFICATIONS_TEST="$(file_at_ref src/lib/data/app/notifications.test.ts)"
WORKER_TEST="$(file_at_ref services/erp-connector/src/worker.test.ts)"
ROUTE="$(file_at_ref src/routes/_app/verikaynaklari.tsx)"
FILE_IMPORT_SHEET="$(file_at_ref src/components/data-sources/FileImportSheet.tsx)"
PROVIDER_DRAFT_SHEET="$(file_at_ref src/components/data-sources/ProviderDraftSheet.tsx)"

for needle in \
  "PR16.10.10 DataSource Operational Hardening" \
  "No release notes, development notes, or future-work notes are added to the UI" \
  "Server-side package ingest rejects duplicate" \
  "out-of-order" \
  "Credential reference validation uses deterministic scheme/path parsing" \
  "Notification realtime subscriptions are tenant-scoped and shared" \
  "File import and provider draft sheets are extracted"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.10.10 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.10.10 - DataSource Operational Hardening" \
  "canonical HR dependency order" \
  "deterministic credential reference parser" \
  "shared Notification Center realtime subscription registry"; do
  if ! grep -Fq "$needle" <<< "$ROADMAP"; then
    echo "FAIL: roadmap missing PR16.10.10 needle: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR16.10.10 DataSource operational hardening" <<< "$README"; then
  echo "FAIL: README missing PR16.10.10 section" >&2
  exit 1
fi

for needle in \
  "CREATE OR REPLACE FUNCTION puls_integration.connector_credential_reference_is_safe" \
  "CREATE OR REPLACE FUNCTION puls_integration.file_import_scope_rank" \
  "CREATE OR REPLACE FUNCTION puls_integration.ingest_file_import_package" \
  "PULS_FILE_IMPORT_PACKAGE_DUPLICATE_SCOPE" \
  "PULS_FILE_IMPORT_PACKAGE_SCOPE_UNSUPPORTED" \
  "PULS_FILE_IMPORT_PACKAGE_SCOPE_ORDER_INVALID" \
  "PULS_FILE_IMPORT_PACKAGE_ROWS_INVALID" \
  "Validate the complete package before staging any file rows" \
  "pr16.10.10-file-import-package-hardening-v1" \
  "puls_integration.file_import_scope_rank(v_scope_key)" \
  "GRANT EXECUTE ON FUNCTION puls_integration.ingest_file_import_package"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: migration missing operational hardening needle: $needle" >&2
    exit 1
  fi
done

if grep -Fq "UPDATE puls_app.app_notifications" <<< "$MIGRATION"; then
  echo "FAIL: PR16.10.10 migration must not update immutable notification ledger rows" >&2
  exit 1
fi

if grep -Eq "[[:space:]][!]?~[[:space:]]" <<< "$MIGRATION"; then
  echo "FAIL: credential reference parser must not rely on regex match operators" >&2
  exit 1
fi

VALIDATION_LINE="$(grep -n "Validate the complete package before staging any file rows" <<< "$MIGRATION" | head -n1 | cut -d: -f1)"
INGEST_LINE="$(grep -n "SELECT puls_integration.ingest_file_import_batch" <<< "$MIGRATION" | head -n1 | cut -d: -f1)"
if [[ -z "$VALIDATION_LINE" || -z "$INGEST_LINE" || "$VALIDATION_LINE" -ge "$INGEST_LINE" ]]; then
  echo "FAIL: package validation must appear before any file ingest call" >&2
  exit 1
fi

for needle in \
  "export function fileImportScopeRank" \
  "for (const file of files)" \
  "fileImportScopeRank(left.scope)"; do
  if ! grep -Fq "$needle" <<< "$CONTRACT"; then
    echo "FAIL: file import contract missing sequential/order needle: $needle" >&2
    exit 1
  fi
done

if grep -Fq "Promise.all(" <<< "$CONTRACT"; then
  echo "FAIL: file import package parsing must stay sequential in PR16.10.10" >&2
  exit 1
fi

for needle in \
  "const orderedFiles = [...input.files].sort" \
  "fileImportScopeRank(left.scope)" \
  "items: orderedFiles.map" \
  "fileCount: Number(result.file_count ?? orderedFiles.length"; do
  if ! grep -Fq "$needle" <<< "$ERP_DATA"; then
    echo "FAIL: DataSource adapter missing canonical package order needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "packageArg.p_package?.items?.map" \
  "'legal_entities'" \
  "'employees'"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP tests missing canonical order assertion needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "appNotificationRealtimeEntries" \
  "releaseAppNotificationRealtimeEntry" \
  "signalListeners" \
  "statusListeners"; do
  if ! grep -Fq "$needle" <<< "$NOTIFICATIONS"; then
    echo "FAIL: notifications data layer missing shared subscription needle: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "shares one tenant realtime channel across multiple subscribers" <<< "$NOTIFICATIONS_TEST"; then
  echo "FAIL: notifications tests missing shared realtime channel regression" >&2
  exit 1
fi

if ! grep -Fq "active lease guard rejects execution" <<< "$WORKER_TEST"; then
  echo "FAIL: worker tests missing active lease rejection regression" >&2
  exit 1
fi

for needle in \
  "<FileImportSheet" \
  "<ProviderDraftSheet"; do
  if ! grep -Fq "$needle" <<< "$ROUTE"; then
    echo "FAIL: route missing extracted component usage: $needle" >&2
    exit 1
  fi
done

for needle in \
  "export function FileImportSheet" \
  "aria-disabled" \
  "onDownloadAllTemplates"; do
  if ! grep -Fq "$needle" <<< "$FILE_IMPORT_SHEET"; then
    echo "FAIL: FileImportSheet missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "export function ProviderDraftSheet" \
  "ProviderDraftSheetOption" \
  "aria-disabled"; do
  if ! grep -Fq "$needle" <<< "$PROVIDER_DRAFT_SHEET"; then
    echo "FAIL: ProviderDraftSheet missing needle: $needle" >&2
    exit 1
  fi
done

echo "PR16.10.10 DataSource operational hardening verification passed."
