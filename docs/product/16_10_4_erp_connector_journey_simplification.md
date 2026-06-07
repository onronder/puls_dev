# PR16.10.4 ERP Connector Journey Simplification

PR16.10.4 turns `/erp` from a dense connector control board into a simple connector setup journey.

## Product Contract

- Selected connector state shows one primary journey surface:
  - source,
  - readiness score,
  - current go-live status,
  - next action,
  - six ordered setup gaps.
- Technical evidence is still available, but it is collapsed behind a details panel
  by default.
- Deep links and in-page actions automatically open the technical panel so existing
  Notification Center and support routes keep working.
- No-connector state still starts with source selection.

## Safety Boundary

- No database migration.
- No provider API calls.
- No credential value readback.
- No source or ERP writeback.
- No runtime connector execution.
- No apply, rollback, or notification contract changes.

## Why This Exists

PR16.10.0 through PR16.10.3 made connector readiness, source catalog, customer
handoff, and go-live gaps explicit. That created the right backend and read-model
evidence, but it also made `/erp` feel like a technical notebook. PR16.10.4 keeps
the evidence and changes the information architecture: the default view becomes
the next step, while details remain available on demand.

## Verification

```bash
scripts/verify-16-10-4-erp-connector-journey-simplification.sh WORKTREE
pnpm check-i18n
pnpm test -- src/lib/data/setup/erp.test.ts
pnpm typecheck
pnpm lint
pnpm build
```

Browser smoke:

- `/erp` selected-connector state shows one connection setup journey card.
- The old technical tab menu is hidden until details are opened.
- The details toggle exposes existing setup, field, check, credential, preview/apply,
  and activity tabs without breaking deep links.
