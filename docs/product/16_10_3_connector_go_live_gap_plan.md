# PR16.10.3 Connector Go-Live Gap Plan

PR16.10.3 turns the selected `/erp` connector into an actionable go-live gap plan for work that can be completed before real customer API details arrive.

## Product Contract

- Selected connector setup exposes a go-live gap plan with:
  - source and transfer method,
  - data ownership,
  - field contract,
  - secure access,
  - preview validation,
  - customer confirmation.
- Each gap carries owner, status, safe evidence, and next action copy.
- The plan answers whether a customer pilot can start without implying that live
  provider runtime is open.
- The plan is derived from existing safe setup evidence and works across Canias,
  Logo, CSV / Excel, and custom API sources.

## Safety Boundary

- No database migration.
- No provider API calls.
- No credential value readback.
- No source or ERP writeback.
- No runtime connector execution.
- No raw payload or provider response readback.

## Why This Exists

PR16.10.0 made access readiness explicit. PR16.10.1 made source selection a
catalog. PR16.10.2 made the selected connector customer-facing. PR16.10.3 closes
the remaining non-API product gap by turning safe evidence into a prioritized
action plan instead of leaving `/erp` as an internal setup notebook.

## Verification

```bash
scripts/verify-16-10-3-connector-go-live-gap-plan.sh WORKTREE
pnpm check-i18n
pnpm test -- src/lib/data/setup/erp.test.ts
pnpm typecheck
pnpm lint
pnpm build
```

Browser smoke:

- `/erp` selected-connector state shows the go-live gap plan under the customer
  access package.
- The plan shows score, customer pilot readiness, next action, owner, safe
  evidence, and six ordered gaps.
- The card remains read-only and does not expose provider payloads or credential
  values.
