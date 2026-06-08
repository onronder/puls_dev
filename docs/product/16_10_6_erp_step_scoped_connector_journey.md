# PR16.10.6 ERP Step-Scoped Connector Journey

PR16.10.6 turns `/erp` into a connector-first, step-scoped product journey
without adding new backend execution paths.

## Product Contract

- ERP connectors remain the main product path.
- CSV / Excel is treated as the first executable manual file connector lane, not
  as a replacement for ERP connectors.
- Selected connector state uses one canonical six-step journey:
  - source and access,
  - field mapping,
  - dry-run preview,
  - change review,
  - approval and worker handoff,
  - result tracking.
- Every visible step has exactly one primary action.
- Existing technical evidence remains available through step-scoped advanced
  details and legacy deep links.
- Existing Notification Center routes that pass `tab` and `focus` still open the
  matching journey step and the matching technical evidence target.

## Safety Boundary

- No database migration.
- No new RPC.
- No CSV / Excel parsing or upload implementation.
- No provider API call.
- No credential value readback.
- No source or ERP writeback.
- No browser-direct apply.
- No apply, rollback, notification, RLS, or worker contract changes.
- No release-note, roadmap, or future-work text is rendered inside the product UI.

## Why This Exists

PR16.10.4 collapsed technical evidence, but the page still behaved like a
workbench. PR16.10.6 keeps the existing backend and frontend actions, then binds
them to a production-grade step shell so admins can answer one question at every
point: what should I do next?

The executable CSV / Excel work remains split deliberately:

- PR16.10.7: file upload, parsing, and field mapping.
- PR16.10.8: import batch ingestion, validation, dry-run preview, and review.
- PR16.10.9: worker apply completion, activity, notification, and settings
  integration.

## Verification

```bash
scripts/verify-16-10-6-erp-step-scoped-connector-journey.sh WORKTREE
pnpm check-i18n
pnpm test -- src/lib/data/setup/erp.test.ts
pnpm typecheck
pnpm lint
pnpm build
```

Browser smoke:

- `/erp` selected-connector state shows the six-step journey shell.
- Each step has one primary action and one technical detail entry point.
- Normal page entry keeps technical evidence collapsed.
- Existing `tab`/`focus` deep links open the matching journey step and evidence
  target.
