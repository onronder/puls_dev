# PR16.10.8 CSV / Excel Import Contract

PR16.10.8 turns CSV / Excel into the first production-grade manual file lane
inside PULS DataSource Manager. It does not replace ERP connectors and it does
not open canonical apply. It only validates a file, stages a dry-run import
batch atomically, and hands the batch to the existing preview flow.

## Product Contract

- CSV / Excel is a managed data source instance, not a developer shortcut.
- The visible flow has one primary action at a time:
  - prepare source,
  - download template,
  - choose file,
  - prepare preview,
  - run preview.
- Every uploaded file must match the PULS HR Import Contract v1.
- Each file carries exactly one scope:
  - employees,
  - departments,
  - positions,
  - legal entities,
  - locations,
  - cost centers.
- Expected filename format is `puls_<scope>_v1_YYYYMMDD.csv|xlsx`.
- Templates are generated from the same contract used by parser validation.
- CSV delimiter detection supports comma, semicolon, and tab.
- Turkish characters are accepted in headers and values.
- Empty cells are normalized to null. Explicit `NULL` / `(null)` is normalized
  to null with a warning.
- Dates must be `YYYY-MM-DD` or timezone-bearing ISO datetime. Ambiguous slash
  dates are rejected.
- Excel formula cells are accepted only when a cached value can be read;
  formulas without values are rejected.
- ZIP and multi-file archives are not accepted.
- CSV size limit is 5 MB. XLSX size limit is 10 MB. Row limit is 5,000.
- Sensitive fields are blocked by header/key contract, including salary/pay,
  TCKN, IBAN, health, family, and birth-date style fields.
- Same checksum for the same tenant/source/scope cannot be ingested twice.
- Same scope and business date cannot have another open dry-run batch.

## Backend Contract

- `puls_integration.import_file_manifests` stores metadata only.
- `puls_integration.ingest_file_import_batch(...)` is the only browser-facing
  ingest boundary for file rows.
- The RPC stages manifest, batch, and rows in one transaction.
- If any row fails the contract, no partial import should be accepted.
- The RPC creates `import_batches` in `uploaded` + `dry_run` mode.
- The RPC uses existing `record_import_row` for row evidence.
- The RPC never writes canonical HR tables.
- The RPC never calls a provider, reads credentials, stores raw file bytes, or
  opens source writeback.
- Authenticated callers need tenant-scoped connector admin permission.
- Service-role can operate for automation, but the safety boundary stays the
  same.

## UI Contract

- `/verikaynaklari` opens a CSV / Excel import sheet from the data source
  primary action.
- The sheet is product UI, not release notes.
- Scope selection, template download, file selection, and contract result are
  visible together without exposing technical runbooks.
- Validation errors are short and local to the file result.
- The sheet remains mobile-safe, but the intended production path is desktop
  admin usage.
- Running preview after staging reuses the existing preview action; canonical
  writes remain closed.

## Safety Boundary

- No live ERP/API call.
- No provider response readback.
- No credential value readback.
- No raw file or raw payload UI.
- No source writeback.
- No canonical apply.
- No autonomous AI action.
- No birthday or employee engagement messaging in this PR.

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
- Invalid filenames, sensitive headers, invalid dates, and formula cells without
  cached values are rejected before RPC ingest.
- A valid file can be staged to a dry-run batch and then handed to preview.
