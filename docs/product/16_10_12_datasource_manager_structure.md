# PR16.10.12 DataSource Manager Structure Hardening

PR16.10.12 closes the remaining DataSource Manager frontend maintainability risk
before PR16.11 / PR17. It keeps the existing product behavior intact while
splitting `/verikaynaklari` into source inventory, sheet, shared UI, and
technical-inspector modules.

## Product Contract

- `/verikaynaklari` remains PULS DataSource Manager.
- The first screen remains the source inventory and selected-source summary.
- Technical audit details remain hidden behind the existing advanced details
  entry point.
- No release notes, development notes, future-work notes, or diagnostic prose are
  added to production UI.
- No canonical apply, connector runtime execution, provider API call, credential
  readback, raw payload readback, source writeback, or ERP writeback behavior is
  changed.

## Structure Contract

- `src/routes/_app/verikaynaklari.tsx` owns route state, data loading, mutation
  orchestration, and sheet wiring only.
- Source inventory and selected-source summary live in
  `DataSourceManagerSection`.
- The long technical audit sheet lives in `DataSourceTechnicalDetailsSheet`.
- Shared UI helpers, journey tab mapping, tone mapping, icon mapping, and display
  formatting live in `dataSourceUi`.
- File import and provider draft sheets remain separate presentation components.

## Verification

```bash
scripts/verify-16-10-12-datasource-manager-structure.sh WORKTREE
pnpm exec vitest run --config vitest.config.ts src/components/data-sources/dataSourceUi.test.tsx
pnpm run typecheck
pnpm run lint
pnpm run check-i18n
pnpm run build
```

Remote smoke should verify:

- `/verikaynaklari` opens to the DataSource Manager inventory.
- Source cards still select a source and show the summary panel.
- The existing advanced audit action still opens the technical details sheet.
- File import and provider draft sheets still open through the same actions.
- No production UI text exposes release notes, development notes, or debug-only
  instructions.
