# PR16.10.10 DataSource Operational Hardening

PR16.10.10 stabilizes the PR16.10.8 CSV / Excel lane and PR16.10.9 runtime
safety work without changing the DataSource Manager user journey.

## Product Contract

- DataSource Manager stays source-instance oriented.
- No release notes, development notes, or future-work notes are added to the UI.
- CSV / Excel upload remains a dry-run staging flow.
- Provider API calls, credential readback, source writeback, canonical writes, raw
  payload readback, field value readback, and snapshot payload readback remain
  closed.
- Existing source list, source detail, file import, and technical detail entry
  points keep their current behavior.

## Backend Contract

- Multi-file import packages must follow canonical HR dependency order:
  legal entities, locations, cost centers, departments, positions, employees.
- Server-side package ingest rejects duplicate, unsupported, or out-of-order
  scopes before staging any rows.
- Credential reference validation uses deterministic scheme/path parsing rather
  than regex operator matching.
- File import package ingest remains dry-run only and does not write canonical HR
  records.
- New database changes do not mutate the immutable notification ledger.

## Frontend Contract

- Browser-side file package parsing is sequential to avoid large parallel XLSX
  memory spikes.
- The file import adapter sends package items in canonical dependency order.
- Notification realtime subscriptions are tenant-scoped and shared across
  multiple mounts; duplicate channels are not opened for the same tenant.
- File import and provider draft sheets are extracted from the route into
  presentation components.
- Import preview failures are not silently swallowed.

## Verification

```bash
scripts/verify-16-10-10-datasource-operational-hardening.sh WORKTREE
pnpm run test
pnpm run typecheck
pnpm run lint
pnpm run check-i18n
supabase db push --local --yes
supabase db lint --local --schema puls_integration --fail-on error
supabase db lint --local --schema puls_app --fail-on error
```

Remote smoke should verify:

- `puls_integration.file_import_scope_rank('legal_entities') = 1`.
- `puls_integration.file_import_scope_rank('employees') = 6`.
- unsafe credential references with query strings, spaces, or unsupported schemes
  return `false`.
- supported credential reference schemes return `true`.
- `puls_integration.ingest_file_import_package` function definition contains the
  `PULS_FILE_IMPORT_PACKAGE_SCOPE_ORDER_INVALID` guard.
