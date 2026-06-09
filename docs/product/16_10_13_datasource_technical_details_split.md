# PR16.10.13 DataSource Technical Details Split

## Purpose

PR16.10.13 completes the structural follow-up from PR16.10.12 by splitting the DataSource Manager technical audit sheet into small tab and section components without changing connector behavior, canonical apply behavior, credential handling, runtime execution, file import behavior, notification behavior, or product copy.

## Scope

- Keep `/verikaynaklari` as route orchestration only.
- Keep `DataSourceTechnicalDetailsSheet` as the sheet shell and tab router only.
- Move each technical tab into a focused presentation component.
- Split the long preview/apply tab into import, recovery, rollback, and controlled-apply section modules.
- Group the sheet input surface into `permissions` and `mutations` objects instead of passing individual booleans and mutation objects through the sheet boundary.
- Add a verify gate that prevents the technical sheet from growing back into a god component.

## Non-Goals

- No database migration.
- No connector runtime execution change.
- No provider API call change.
- No canonical write/apply/rollback change.
- No credential readback or raw payload readback change.
- No DataSource Manager product copy or visible journey redesign.
- No HR workflow audit or policy enforcement change.

## Acceptance Criteria

- `DataSourceTechnicalDetailsSheet.tsx` stays below 200 lines.
- `DataSourcePreviewApplyTabPanel.tsx` stays below 120 lines.
- No technical details section module exceeds 700 lines.
- The route continues to pass only grouped `permissions` and `mutations` into the technical details sheet.
- Existing tab IDs and deep-link targets remain intact.
- Typecheck, tests, lint, i18n, build, and PR16.10.13 verify gate pass.

## Verification

Run:

```bash
scripts/verify-16-10-13-datasource-technical-details-split.sh WORKTREE
pnpm run typecheck
pnpm run test
pnpm run lint
pnpm run check-i18n
pnpm run build
```
