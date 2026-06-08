# PR16.10.8 CSV / Excel Import Contract

PR16.10.8 turns CSV / Excel into the first production-grade manual file lane
inside PULS DataSource Manager. It does not replace ERP connectors and it does
not open canonical apply. It validates one or more scope files as a single HR
import package, stages the package atomically into dry-run import batches, and
hands the batches to the existing preview flow.

## Product Contract

- CSV / Excel is a managed data source instance, not a developer shortcut.
- The visible flow has one primary action at a time:
  - prepare source,
  - download template,
  - choose file,
  - prepare preview,
  - run preview.
- Every uploaded file must match the PULS HR Import Contract v1.
- A package may contain one or more files, but each scope can appear only once.
- The first production package scopes cover the HR core data needed to seed the
  closed-loop app:
  - employees,
  - departments,
  - positions,
  - legal entities,
  - locations,
  - cost centers.
- Expected filename format is `puls_<scope>_v1_YYYYMMDD.csv|xlsx`.
- Templates are generated from the same contract used by parser validation.
- The UI can download the selected scope template or all scope templates.
- Upload accepts multi-select files. ZIP and multi-file archives are not
  accepted.
- Package staging is all-or-nothing. If one file is invalid or one DB contract
  check fails, the package rolls back and no file from that package is staged.
- CSV delimiter detection supports comma, semicolon, and tab.
- Turkish characters are accepted in headers and values.
- Empty cells are normalized to null. Explicit `NULL` / `(null)` is normalized
  to null with a warning.
- Dates must be `YYYY-MM-DD` or timezone-bearing ISO datetime. Ambiguous slash
  dates are rejected.
- Excel formula cells are accepted only when a cached value can be read;
  formulas without values are rejected.
- CSV size limit is 5 MB. XLSX size limit is 10 MB. Row limit is 5,000.
- Sensitive fields are blocked by header/key contract, including salary/pay,
  TCKN, IBAN, health, family, and birth-date style fields.
- Same checksum for the same tenant/source/scope cannot be ingested twice.
- Same scope and business date cannot have another open dry-run batch.
- Each successfully staged file writes safe metadata, an import batch, import
  rows, a sync log event, and a service-role notification producer candidate.

## Backend Contract

- `puls_integration.import_file_manifests` stores metadata only.
- `puls_integration.ingest_file_import_batch(...)` is the only browser-facing
  ingest boundary for a single file row set.
- `puls_integration.ingest_file_import_package(...)` is the browser-facing
  package boundary used by the product UI.
- The package RPC stages every file in one database transaction.
- If any file or row fails the contract, no partial package import is accepted.
- The RPC creates `import_batches` in `uploaded` + `dry_run` mode.
- The RPC uses existing `record_import_row` for row evidence.
- The RPC writes `erp_sync_batches` event `file_import_uploaded` for each
  successfully staged file.
- The RPC never writes canonical HR tables.
- The RPC never calls a provider, reads credentials, stores raw file bytes, or
  opens source writeback.
- Authenticated callers need tenant-scoped connector admin permission.
- Service-role can operate for automation, but the safety boundary stays the
  same.
- `puls_app.refresh_file_import_app_notifications(...)` converts safe file
  manifest events into idempotent Notification Center items.
- `puls_app.run_app_notification_producers(...)` includes the file import
  producer alongside connector runtime producers.

## UI Contract

- `/verikaynaklari` opens a CSV / Excel import sheet from the data source
  primary action.
- The sheet is product UI, not release notes.
- Scope selection is used for template download; selected upload files declare
  their scope through the file name.
- Template download supports the selected scope and the full HR template set.
- File selection accepts one or more CSV/XLSX files.
- Package validation, file list, row count, ready file count, and short findings
  are visible without exposing technical runbooks.
- Validation errors are short and local to the package result.
- The sheet remains mobile-safe, but the intended production path is desktop
  admin usage.
- Running preview after package staging reuses the existing preview action;
  canonical writes remain closed.

## Safety Boundary

- No live ERP/API call.
- No provider response readback.
- No credential value readback.
- No raw file or raw payload UI.
- No source writeback.
- No canonical apply.
- No autonomous AI action.
- No birthday or employee engagement messaging in this PR.
- No direct browser notification writes.

## Verification

```bash
scripts/verify-16-10-8-csv-excel-import-contract.sh WORKTREE
pnpm exec vitest run src/lib/data/setup/file-import-contract.test.ts src/lib/data/setup/erp.test.ts
pnpm run check-i18n
pnpm run typecheck
pnpm run lint
supabase db push --local --yes
supabase db lint --local --schema puls_integration --fail-on error
```

Browser smoke:

- `/verikaynaklari` shows CSV / Excel as a managed source option.
- CSV / Excel primary action opens the import sheet.
- Template download produces the selected scope contract filename.
- All templates can be downloaded from the same sheet.
- Multi-file package upload shows file count, ready file count, row count, and
  short findings.
- Invalid filenames, sensitive headers, invalid dates, and formula cells without
  cached values are rejected before RPC ingest.
- A valid package can be staged atomically into dry-run batches and then handed
  to preview.
