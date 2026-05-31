# PR13.7 — Canias Connector Discovery

First-customer Canias connector discovery pack for PULS v1.0: source-of-truth rules, field mapping matrix, import/export modes, conflict policy, and handoff to future runtime connector.

**Canias is the first native ERP integration track for PULS v1.0.**

**PR13.7 is connector discovery and action-boundary readiness, not runtime integration.**

## Executive summary

PR13.7 turns PR13.6 AI Coach DB context readiness into a concrete **service-boundary and connector discovery contract**. Canias is the first ERP integration track. PULS remains the workflow system of record for leave, expense, approvals, performance, and in-app decisions. Canias remains master for imported HR, organization, and cost-center master data until explicit export paths are designed.

No automatic destructive ERP writes. No credentials, API keys, tokens, or `credentials_ref` values are stored in PR13.7 artifacts.

## What PR13.7 proves

- Canias-first integration boundary documented with inspect-first evidence from merged PR13.4–13.6 seed and read-only app adapters
- Structured field mapping matrix ([`13_canias_field_mapping_matrix.json`](./13_canias_field_mapping_matrix.json)) for 13 data classes including identity reconciliation
- AI Coach action boundary ([`13_ai_coach_action_boundary.md`](./13_ai_coach_action_boundary.md)) — explain/suggest/draft only; humans confirm every workflow action
- Touchpoint readiness matrix tying Canias metadata to AI Coach allowed/forbidden actions
- Read-only SQL validation (`09_validate_canias_connector_readiness.sql`) aligned with seeded Canias metadata posture
- Service skeleton posture documented for `erp-connector` and `llm-gateway` (health-only, future boundary)

## What PR13.7 does not prove

- Runtime Canias connector, sync triggers, or ERP write-back
- Live LLM chat or OpenAI/API runtime
- App mutation paths, migrations, or seed CSV/manifest changes
- Credential storage or live Canias API calls
- Public HTTP API / SDK productization

## Inspect-first table

| Artifact | Source | Inspect finding | PR13.7 decision |
|----------|--------|-----------------|-----------------|
| Canias boundary | [`13_canias_first_integration_boundary.md`](./13_canias_first_integration_boundary.md) | PR13.7 checklist existed (unchecked) | Promote checklist into discovery pack; mark handoff implemented |
| ERP adapter | [`src/lib/data/setup/erp.ts`](../../src/lib/data/setup/erp.ts) | Reads `erp_connections`, `erp_field_mappings`, `erp_sync_batches`; no writes | Keep app read-only; no `src/**` change |
| ERP route | [`src/routes/_app/erp.tsx`](../../src/routes/_app/erp.tsx) | Metadata/readiness surface; Map/Test actions disabled | Document route posture; no runtime sync button |
| AI Coach adapter | [`src/lib/data/ai-coach/*`](../../src/lib/data/ai-coach/) | PR13.6 DB context readiness, 8 domains, guardrails | Add action-boundary doc; no live chat |
| Service skeleton | [`services/erp-connector/src/index.ts`](../../services/erp-connector/src/index.ts) | Health-only `0.1.0-skeleton` | Add README; keep skeleton health-only |
| LLM skeleton | [`services/llm-gateway/src/index.ts`](../../services/llm-gateway/src/index.ts) | Health-only boundary hint | Future only; no API keys |
| Seed connection | `csv/16_erp_connections.csv` | 1 row: `provider=canias`, `is_active=false`, `credentials_ref` omitted (NULL) | Validate metadata-only posture |
| Field mappings | `csv/17_erp_field_mappings.csv` | 12 sample rows with generic `source_field` names | Discovery sample, not customer truth |
| Source namespace | `csv/18_source_namespaces.csv` | 1 row: code `CANIAS` | Source disclosure anchor |
| Identity map | `csv/19_entity_identity_map.csv` | 13 rows (4 dept, 5 pos, 4 cost_center) | Import reconciliation proof |
| Imported org rows | `csv/04_departments.csv`, `05_positions.csv` | 4 depts + 5 positions with `external_source=canias` | Read-only guardrail proof |
| Cost centers | `csv/10_cost_centers.csv` | 4 rows with `source_namespace_id` + `external_id` | Namespace-based import proof |
| Employees | `csv/06_employees.csv` | No Canias-imported employees in seed | Inbound **candidate**; not proven in seed |
| Naming note | seed vs discovery JSON | Seed uses `external_source='canias'` + namespace code `CANIAS`; JSON uses logical `canias_erp` | Document both; crosswalk in mapping matrix |

**Seed-proven generic mapping fields** (sample labels in PR13.4 metadata — not proprietary Canias field names): `DEPT_CODE`, `DEPT_NAME`, `POS_CODE`, `POS_NAME`, `EMPLOYEE_CODE`, `FULL_NAME`, `CC_CODE`, `CC_NAME`, `LOC_CODE`, `HIRE_DATE`, `EMAIL`, `MANAGER_CODE`. All other Canias fields → `TBD_FROM_CUSTOMER_DISCOVERY`.

## Canias-first integration modes

| Mode | Description | MVP fit |
|------|-------------|---------|
| Manual CSV | Admin export from Canias → PULS import batch | High — aligns with PR13.4 CSV pack |
| Scheduled file exchange | SFTP / shared folder drop | High |
| Excel / XML | Canias standard export formats | Medium |
| Staging table | Land in `puls_integration` staging; promote to `puls_core` | Medium |
| REST / SOAP API | Canias web services where available | Future — `erp-connector` skeleton exists |
| Controlled export | PULS workflow results → file or staging for Canias pickup | Post-import; no destructive write-back |

[`services/erp-connector/`](../../services/erp-connector/) is a **skeleton** (`0.1.0-skeleton`) — **erp-connector is a future connector boundary, not a PR13.7 runtime connector.**

## Source-of-truth rules

**PULS remains the workflow system of record** for leave requests, expense claims, approval decisions, performance reviews, and in-app setup mutations.

| Data class | Master | PULS behavior |
|------------|--------|---------------|
| Org master (depts, positions, cost centers) | Canias → import | Imported rows: source labels; **read-only** in UI (PR11.2) |
| Employee identity (future inbound) | Canias → import candidate | Read-only when imported; workshop decides hire-date/balance SoT |
| Leave balances | TBD workshop (`tbd_workshop` in JSON) | Discovery-only until customer workshop |
| PULS-owned setup | PULS tenant admin | Editable where CRUD implemented |
| Leave / expense workflows | PULS | Create/decide in PULS; export results staged for ERP pickup (future) |
| Performance / contracts | PULS-only in MVP | No Canias MVP sync |
| ERP connection metadata | PULS | `puls_integration.erp_connections`, mappings, sync batches |
| Identity reconciliation | Canias namespace | `entity_identity_map` links external_id → canonical row |

## Inbound master data classes

See [`13_canias_field_mapping_matrix.json`](./13_canias_field_mapping_matrix.json) for full field-level discovery. Inbound candidates:

- departments, positions, employees, cost_centers (seed proves depts/positions/cost centers partially)
- legal_entities, locations (discovery-only)
- leave_balances (SoT: TBD workshop — JSON enum `tbd_workshop`)
- source_identity_mappings (13 seed rows prove reconciliation pattern)

## Outbound/export candidates

Future human-reviewed export only — no automatic destructive ERP writes:

- approved_leave_results (PULS → Canias)
- posted_expense_results (PULS → Canias)
- approval_audit_summary (PULS-only / export candidate)

## Conflict and idempotency policy

| Rule | Policy |
|------|--------|
| External ID match | Upsert imported row only; never overwrite PULS-owned row |
| Namespace collision | `source_namespace_id` + `external_id` + `entity_identity_map` is canonical reconciliation |
| Partial batch | Idempotent re-run by external_id; failed rows logged in sync batch metadata (future runtime) |
| PULS workflow wins | Leave/expense/approval state always owned by PULS until explicit export |

## Error and partial batch recovery policy

- **Discovery posture:** document error classes per field mapping (`missing_required_field`, `invalid_transform`, `duplicate_external_id`)
- **Future runtime:** sync batch status `partial` / `failed`; admin review queue; no silent retry of destructive operations
- **PR13.7 seed:** inactive connection; no active sync batches required

## Human approval boundaries

- Every import batch requires admin confirmation before promote to `puls_core`
- Every export batch requires human review before Canias pickup
- AI Coach may explain gaps and draft next steps — **humans confirm every workflow action**
- No auto-approvals, no autonomous sync, no credential storage in repo

## Security and credential posture

- `credentials_ref IS NULL` on demo Canias connection — metadata only
- **no credentials** — no API keys, tokens, or `credentials_ref` values in PR13.7 artifacts
- Future runtime: secrets in vault/env only; never in seed CSV or docs
- Source disclosure required: PULS-owned vs imported/Canias vs metadata-only vs unknown

## Open questions for first customer workshop

1. Which Canias modules export HR, org, and cost-center master data?
2. Available transport: CSV, XML, Excel, staging view, or API?
3. Real Canias field names for each entity (replace `TBD_FROM_CUSTOMER_DISCOVERY`)
4. Employee inbound scope: full roster vs delta vs manager-only?
5. Leave balance SoT: Canias vs PULS (currently `tbd_workshop`)
6. Export frequency and format for approved leave and posted expenses
7. Staging vs direct upsert strategy
8. Error notification and partial batch recovery expectations
9. Import frequency (manual, daily batch, etc.)
10. Connector runtime scope (file watcher vs API poller) — post PR13.7

## Handoff to future runtime connector PR

PR13.8+ may add read-only connector readiness panel in `/erp` UI using this discovery pack. Runtime connector PR (post-packaging) will:

1. Implement `services/erp-connector` beyond health-only skeleton
2. Wire import/export workflows with human confirmation gates
3. Use field mapping matrix as configuration input (not hardcoded in app)
4. Preserve read-only guards for imported org rows
5. Never perform automatic destructive ERP writes

## References

- [`13_canias_first_integration_boundary.md`](./13_canias_first_integration_boundary.md)
- [`13_canias_field_mapping_matrix.json`](./13_canias_field_mapping_matrix.json)
- [`13_ai_coach_action_boundary.md`](./13_ai_coach_action_boundary.md)
- [`13_canias_ai_connector_readiness_matrix.md`](./13_canias_ai_connector_readiness_matrix.md)
- [`13_ai_coach_db_context_readiness.md`](./13_ai_coach_db_context_readiness.md)
- [`../../scripts/verify-13-canias-ai-connector-boundary.sh`](../../scripts/verify-13-canias-ai-connector-boundary.sh)
