# PR13.0 — Canias-First Integration Boundary

Integration boundary for Canias ERP as PULS v1.0's first native ERP track — modes, source-of-truth rules, MVP constraints, and discovery checklist.

**Documentation-only.** PR13.7 delivers mapping discovery for first customer.

## Executive summary

Canias is the **first native ERP integration track** for PULS v1.0 packaging — prioritized **after** DB-backed demo and feature packaging gates (PR13.1–13.5) and **before** public API / SDK productization.

PULS remains the workflow system of record for leave, expense, and approvals. Canias remains master for imported HR/org master data until explicit export paths are defined.

**MVP ban:** no automatic destructive ERP writes.

## Why Canias before public API

| Track | Purpose | PR13 posture |
|-------|---------|--------------|
| **Canias ERP integration** | First customer ERP path; master data import; controlled export of workflow results | PR13.7 discovery; runtime connector future |
| **Public HTTP API / SDK** | Third-party productization, client generation, CRM hooks | **Future candidate** — not PR13 MVP |

PR12 closed the in-app supabase-js contract pack. PR13 does not productize a public REST API. Canias addresses the immediate customer need: ERP-sourced master data into PULS with honest source-aware UI.

See [`../api/pr12-release-checklist.md`](../api/pr12-release-checklist.md) for PR12 → PR13 handoff.

## Integration modes (kept open)

PR13.0 does not lock transport. Candidate modes for discovery and first implementation:

| Mode | Description | MVP fit |
|------|-------------|---------|
| Manual CSV | Admin export from Canias → PULS import batch | High — aligns with PR13.4 CSV pack |
| Scheduled file exchange | SFTP / shared folder drop | High |
| XML / Excel | Canias standard export formats | Medium |
| Staging table / view | Land in `puls_integration` staging; promote to `puls_core` | Medium |
| REST / SOAP | Canias web services where available | Future — connector skeleton exists |
| Controlled export | PULS workflow results → file or staging for Canias pickup | Post-import; no destructive write-back |

[`services/erp-connector/`](../../services/erp-connector/) is a **skeleton** (`0.1.0-skeleton`) — not production integration.

## Source-of-truth rules

| Data class | Master | PULS behavior |
|------------|--------|---------------|
| Org master (depts, positions, employees) | Canias → import | Imported rows: `external_source` set; **read-only** in UI (PR11.2) |
| PULS-owned setup | PULS tenant admin | Editable where CRUD implemented |
| Leave / expense workflows | PULS | Create/decide in PULS; export results staged for ERP pickup |
| ERP connection metadata | PULS | `puls_integration.erp_connections`, mappings, sync batches |

**Source-aware rows** must be distinguishable in UI and demo seed (PULS-owned + imported/source-owned examples).

## Current implementation posture

[`src/lib/data/setup/erp.ts`](../../src/lib/data/setup/erp.ts):

- Reads `puls_integration.erp_connections`, `erp_field_mappings`, `erp_sync_batches`
- Default provider label: **Canias**
- **Read-only** integration metadata UI — no sync trigger or write-back in app
- Demo fallback via `fetchDemoErpOverview` when DB empty

Aligns with matrix ERP row: `db_backed_demo_required`; packaging needs inactive Canias connection + sample mappings in demo tenant.

## MVP constraints (non-goals)

| Constraint | Rule |
|------------|------|
| **No automatic destructive ERP writes** | PULS must not delete or overwrite Canias master records without explicit human-approved export workflow |
| **No full bidirectional sync** | Future candidate |
| **No real-time sync** | Future candidate |
| **No public API productization** | Future candidate |
| **No SDK / client generation** | Future candidate |
| **No CRM integration** | Future candidate |

These appear in strategy non-goals and must not be implied by ERP setup UI or demo packaging.

## Discovery checklist (PR13.7)

PR13.7 will complete for first Canias customer:

- [ ] Canias modules and export formats available (HR, org, cost centers)
- [ ] Field mapping: Canias fields → `puls_core` / `puls_workflow` targets
- [ ] `external_source` values and read-only guards per entity
- [ ] Import frequency (manual, daily batch, etc.)
- [ ] PULS → Canias export candidates (approved leave, posted expenses)
- [ ] Staging vs direct upsert strategy
- [ ] Error handling and partial batch recovery
- [ ] Demo tenant: inactive connection + sample `canias_erp` imported rows
- [ ] Connector runtime scope (file watcher vs API poller)

## Demo packaging requirements

| Artifact | Completeness class |
|----------|-------------------|
| `erp_connections` row (Canias, inactive) | `required seeded` |
| Sample `erp_field_mappings` | `required seeded` |
| Imported org rows (`external_source` = Canias) | `required seeded` |
| Sync batch history (optional) | `readable empty-ok` |

See [`13_demo_data_packaging_principles.md`](./13_demo_data_packaging_principles.md).

## PR13.7 handoff

PR13.7 delivers:

1. Canias field mapping discovery document
2. Import/export boundary per entity
3. Connector implementation scope (post-packaging)
4. Verification that ERP UI remains read-only until export workflows are explicitly designed

## References

- [`13_v1_product_packaging_strategy.md`](./13_v1_product_packaging_strategy.md)
- [`13_v1_feature_traceability_matrix.md`](./13_v1_feature_traceability_matrix.md) — ERP row
- [`13_demo_data_packaging_principles.md`](./13_demo_data_packaging_principles.md)
- [`../data/11_org_setup_crud_readiness_matrix.md`](../data/11_org_setup_crud_readiness_matrix.md)
- [`../../src/lib/data/setup/erp.ts`](../../src/lib/data/setup/erp.ts)
