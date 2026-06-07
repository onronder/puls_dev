# PR16.10.2 Connector Customer Handoff Checklist

PR16.10.2 turns the selected `/erp` connector into a customer-facing access package instead of a technical setup notebook.

## Product Contract

- Selected connector setup exposes a customer handoff package with:
  - source identity,
  - transfer method,
  - data scope,
  - field contract,
  - secure access,
  - preview path.
- The package is derived from existing safe setup evidence and is visible before
  live provider runtime work starts.
- The UI separates internal access readiness from the customer conversation: access
  readiness is the safety posture, while customer handoff is the shareable setup
  package.

## Safety Boundary

- No database migration.
- No provider API calls.
- No credential value readback.
- No source or ERP writeback.
- No runtime connector execution.
- No raw payload or provider response readback.

## Why This Exists

PR16.10.0 made selected connector access readiness explicit. PR16.10.1 made source
selection a connector catalog. PR16.10.2 closes the product gap between those
states by showing what can be discussed with a customer before Canias or any other
connector has live API credentials.

## Verification

```bash
scripts/verify-16-10-2-connector-customer-handoff-checklist.sh WORKTREE
pnpm check-i18n
pnpm test -- src/lib/data/setup/erp.test.ts
pnpm typecheck
pnpm lint
pnpm build
```

Browser smoke:

- `/erp` selected-connector state shows the customer access package.
- The package shows score, shareability, source, next action, and six checklist
  items.
- The card remains read-only and does not expose provider payloads or credentials.
