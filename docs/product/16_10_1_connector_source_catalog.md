# PR16.10.1 Connector Source Catalog

PR16.10.1 makes the `/erp` no-connector source selection surface behave like a
production connector catalog instead of a provider list.

## Product Contract

- Canias, Logo, CSV / Excel, and Custom API are presented as connector sources, not
  as separate product architectures.
- Each source exposes the same catalog fields:
  - source type,
  - transfer method,
  - setup availability,
  - recommended use.
- The catalog is shown in the source cards, selection preview, and setup draft
  sheet.
- Setup availability remains honest:
  - Canias and CSV / Excel can create setup drafts,
  - Logo requires customer confirmation,
  - Custom API is modeled but its setup flow stays closed.

## Safety Boundary

- No provider API calls.
- No credential value readback.
- No source or ERP writeback.
- No database migration.
- No runtime connector execution.

## Why This Exists

PR16.10.0 added access readiness for a selected connector. PR16.10.1 applies the
same source-independent discipline before a connector is selected, so operators can
choose the right source path without reading a developer-style provider checklist.

## Verification

```bash
scripts/verify-16-10-1-connector-source-catalog.sh WORKTREE
pnpm check-i18n
pnpm test -- src/lib/data/setup/erp.test.ts
pnpm typecheck
pnpm lint
pnpm build
```

Browser smoke:

- `/erp` no-connector source cards show source type and method.
- Selecting a source shows setup availability and recommended use in the preview.
- The setup draft sheet repeats source type and setup availability.
