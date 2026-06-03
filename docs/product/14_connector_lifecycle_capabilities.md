# PR14.13 Connector Lifecycle Capabilities

PR14.13 makes the connector setup workbench source-independent at the product-contract layer. Canias remains one source profile; PULS models source capabilities, lifecycle stage, and canonical domain ownership for any future ERP, file, or custom API connector.

## What This PR Proves

- A selected source exposes a lifecycle stage derived from real setup state, mapping coverage, namespace evidence, credential posture, and preflight result.
- Source capabilities are visible without pretending that live connector runtime exists.
- Canonical domain ownership is shown per data class so a future second connector cannot silently overwrite an existing data flow.
- The `/erp` workbench stays readable across desktop, tablet, and narrow viewport layouts.

## What This PR Does Not Do

- No migration.
- No credential capture.
- No credential readback.
- No live API call.
- No import, export, sync execution, or ERP writeback.
- No Canias-only architecture.

## Product Rules

PULS is source-independent. Canias, CSV / Excel, Logo, and custom APIs are source profiles that must pass through the same connector lifecycle model.

Domain ownership is canonical-data-class scoped. A source may own employees, departments, positions, cost centers, or locations only when that ownership is explicit in connector state. Additional connectors must use available domains or a future ownership transfer flow.

Lifecycle is derived, not manually authored copy. The UI reads adapter fields such as `lifecycle`, `capabilities`, and `domainOwnership`; it does not render raw setup enum values.

## Acceptance Criteria

- `ErpOverview` includes `lifecycle`, `capabilities`, and `domainOwnership`.
- `/erp` shows lifecycle and capability posture for selected sources.
- `/erp` shows canonical domain ownership before the canonical mapping table.
- Responsive layout uses wrapping grids, not accidental page-level horizontal overflow.
- Tests cover credential-pending lifecycle, domain ownership, and CSV / Excel transfer capability.

## Handoff

PR14.14 can use this foundation for source profile persistence, domain transfer design, or connector runtime planning without changing the user-facing lifecycle language again.
