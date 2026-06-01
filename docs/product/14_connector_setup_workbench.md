# PR14.3 — Connector Setup Workbench

PR14.3 turns `/erp` from a static connector empty state into a guided setup workbench while keeping the runtime boundary closed.

## Product Claim

Connector Setup Workbench keeps provider selection separate from runtime integration.

Provider preview is local UI state; it does not write connector metadata.

Canonical mapping, unified namespace, and identity reconciliation remain the stable product boundary.

No runtime sync, no credentials, and no ERP writes are introduced in PR14.3.

## UX Model

The `/erp` route now presents connector setup as five visible steps:

| Step      | Meaning                                                             |
| --------- | ------------------------------------------------------------------- |
| Source    | Select a provider, file source, or future custom API path           |
| Mapping   | Map source fields to the PULS canonical model                       |
| Namespace | Resolve external IDs inside a unified source namespace              |
| Preflight | Check metadata, mapping, identity, and setup readiness              |
| Runtime   | Keep live sync and ERP write boundaries closed until a future phase |

This model keeps PULS source-independent: Canias is the first seeded provider, but the product abstraction is the connector setup workflow.

## No-Connector Behavior

When a tenant has no `erp_connections` row, `/erp` shows provider cards for:

- Canias
- Logo
- CSV / Excel
- Custom API

Selecting a card is intentionally local preview only. The preview explains requirements such as source profile, canonical mapping, source namespace, identity strategy, transfer mode, and runtime boundary. The route still returns `source: real` and must not fall back to demo fixtures for a tenant that simply has no connector yet.

## Selected Connector Behavior

When connector metadata exists, the PR14.1 preflight surface remains intact:

- Provider metadata
- Readiness score
- Field mapping counts
- Unified namespace
- Identity reconciliation
- Transfer modes
- Guardrails

The stepper is derived from the same adapter data so the selected connector state and empty onboarding state speak the same product language.

## Acceptance

- `/erp` shows a setup workbench stepper in both no-connector and selected-connector states.
- No-connector provider cards are selectable in the UI but do not persist data.
- Provider preview requirements are product-owned metadata, not provider runtime calls.
- Puls Teknik / Canias selected connector preflight remains unchanged.
- No migrations, seed CSV/manifest, credentials, connector runtime, or ERP writes are added.
