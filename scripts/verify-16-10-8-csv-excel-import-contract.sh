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

echo "Checking ${REF}: PR16.10.8 CSV / Excel import contract ..."

DOC="$(file_at_ref docs/product/16_10_8_csv_excel_import_contract.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
CONTRACT="$(file_at_ref src/lib/data/setup/file-import-contract.ts)"
CONTRACT_TEST="$(file_at_ref src/lib/data/setup/file-import-contract.test.ts)"
ERP_DATA="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/verikaynaklari.tsx)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"
MIGRATION="$(
  file_at_ref supabase/migrations/20260608100000_puls_integration_file_import_contract.sql
  printf '\n'
  file_at_ref supabase/migrations/20260608103000_puls_integration_file_import_package_contract.sql
)"
PACKAGE="$(file_at_ref package.json)"

for needle in \
  "PR16.10.8 CSV / Excel Import Contract" \
  "PULS HR Import Contract v1" \
  'puls_<scope>_v1_YYYYMMDD.csv|xlsx' \
  "A package may contain one or more files" \
  "Package staging is all-or-nothing" \
  "CSV delimiter detection supports comma, semicolon, and tab" \
  "Excel formula cells are accepted only when a cached value can be read" \
  "refresh_file_import_app_notifications" \
  "No canonical apply" \
  "No birthday or employee engagement messaging in this PR"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.10.8 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "FILE_IMPORT_TEMPLATE_VERSION" \
  "FILE_IMPORT_MAX_CSV_BYTES = 5 * 1024 * 1024" \
  "FILE_IMPORT_MAX_XLSX_BYTES = 10 * 1024 * 1024" \
  "FILE_IMPORT_SCOPE_CONTRACTS" \
  "parseFileImportPackage" \
  "inferFileImportScopeFromFileName" \
  "DUPLICATE_SCOPE_IN_PACKAGE" \
  "detectDelimiter" \
  "collectFormulaIssuesFromWorksheetXml" \
  "NULL_LITERALS" \
  "BLOCKED_HEADER_PATTERNS" \
  "parseFileImport"; do
  if ! grep -Fq "$needle" <<< "$CONTRACT"; then
    echo "FAIL: parser contract missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "puls_employees_v1_20260608.csv" \
  "parses semicolon CSV with Turkish characters and null literals" \
  "blocks sensitive columns by header name" \
  "rejects ambiguous slash-formatted dates" \
  "rejects Excel formula cells when cached value is unavailable" \
  "parses a multi-file HR import package in dependency order" \
  "blocks duplicate scopes inside the same package"; do
  if ! grep -Fq "$needle" <<< "$CONTRACT_TEST"; then
    echo "FAIL: parser tests missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "ingestFileImportBatch" \
  "ingestFileImportPackage" \
  "pulsIntegration().rpc('ingest_file_import_package'" \
  "i18nKey: 'erp.errors.fileImportBlocked'" \
  "id: 'csv_import'" \
  "'upload_file'"; do
  if ! grep -Fq "$needle" <<< "$ERP_DATA"; then
    echo "FAIL: data adapter missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "stages parsed CSV/Excel rows through the file import package RPC only" \
  "stages multiple parsed files through one atomic file import package RPC" \
  "allows CSV setup while Canias is still a non-runtime setup source"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP tests missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "fileImportSheetOpen" \
  "fileImportPackageResult" \
  "downloadFileImportTemplate" \
  "downloadAllFileImportTemplates" \
  "handleFileImportFileChange" \
  "ingestFileImportMutation" \
  "erp.fileImport.title" \
  "parseFileImportPackage" \
  "multiple" \
  "accept=\".csv,.xlsx" \
  "activeFileImportConnectionId"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: route missing file import UI needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  '"fileImport"' \
  '"CSV / Excel içe aktarımı"' \
  '"Paket önizlemeye hazır"' \
  '"Tüm şablonları indir"' \
  '"DUPLICATE_SCOPE_IN_PACKAGE"' \
  '"fileImportUploaded"' \
  '"INVALID_FILE_NAME"' \
  '"XLSX_FORMULA_VALUE_MISSING"' \
  '"legal_entities"'; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing file import needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  '"fileImport"' \
  '"CSV / Excel import"' \
  '"Package is ready for preview"' \
  '"Download all templates"' \
  '"DUPLICATE_SCOPE_IN_PACKAGE"' \
  '"fileImportUploaded"' \
  '"INVALID_FILE_NAME"' \
  '"XLSX_FORMULA_VALUE_MISSING"' \
  '"legal_entities"'; do
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing file import needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "CREATE TABLE IF NOT EXISTS puls_integration.import_file_manifests" \
  "CREATE OR REPLACE FUNCTION puls_integration.ingest_file_import_batch" \
  "CREATE OR REPLACE FUNCTION puls_integration.ingest_file_import_package" \
  "CREATE OR REPLACE FUNCTION puls_app.refresh_file_import_app_notifications" \
  "CREATE OR REPLACE FUNCTION puls_app.run_app_notification_producers" \
  "file_import_uploaded" \
  "package_id" \
  "PULS_FILE_IMPORT_DUPLICATE_CHECKSUM" \
  "PULS_FILE_IMPORT_OPEN_BATCH_EXISTS" \
  "record_import_row" \
  "'dry_run'" \
  "'source_writeback', FALSE" \
  "'provider_api_calls', FALSE" \
  "'canonical_write', FALSE" \
  "GRANT EXECUTE ON FUNCTION puls_integration.ingest_file_import_batch" \
  "GRANT EXECUTE ON FUNCTION puls_integration.ingest_file_import_package" \
  "GRANT EXECUTE ON FUNCTION puls_app.refresh_file_import_app_notifications"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: migration missing safety/RPC needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  '"papaparse"' \
  '"xlsx"' \
  '"@types/papaparse"'; do
  if ! grep -Fq "$needle" <<< "$PACKAGE"; then
    echo "FAIL: package.json missing dependency: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR16.10.8 - CSV / Excel Import Contract" <<< "$ROADMAP"; then
  echo "FAIL: roadmap missing PR16.10.8 section" >&2
  exit 1
fi

if ! grep -Fq "PR16.10.8 CSV / Excel import contract" <<< "$README"; then
  echo "FAIL: README missing PR16.10.8 section" >&2
  exit 1
fi

echo "PR16.10.8 CSV / Excel import contract verification passed."
