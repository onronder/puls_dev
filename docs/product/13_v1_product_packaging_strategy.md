# PR13.0 — V1 Product Packaging Strategy

Scope-lock document for PULS v1.0 product packaging after the PR12 API contract pack. **Strategy only** — no app code, migrations, or fixture files in PR13.0.

## Executive summary

PR13 defines how PULS v1.0 is packaged as a **real, full-stack product** aligned with V1 product documents and implemented capabilities — not as a demo-adapter showcase.

Production-facing product behavior must not depend on embedded TypeScript business fixtures.

## Why PR13 exists after PR12

PR12 closed the **API contract pack** (OpenAPI, validation, examples, error catalog) for in-app supabase-js mutations. PR13 shifts focus to **product packaging**:

- V1 docs ↔ implemented routes/adapters ↔ DB-backed demo ↔ AI Coach value layer ↔ Canias-first ERP readiness

See [`../api/pr12-release-checklist.md`](../api/pr12-release-checklist.md) for PR12 closure and PR13 handoff.

## V1 package definition

A **V1-ready packaged product** means:

1. Every V1 surface has an honest readiness posture (see [`13_v1_feature_traceability_matrix.md`](./13_v1_feature_traceability_matrix.md))
2. Demo and sales flows use a **DB-backed demo tenant** (importable, resettable, source-aware)
3. Full-stack path is explicit: **route → adapter → backend/RLS/RPC/table/view → DB → UI**
4. AI Coach is positioned as a **process-embedded value layer** with DB context and human-in-the-loop guardrails
5. Canias is the **first native ERP integration track**, starting only after DB-backed packaging gates are defined

V1 product intent: [`../specs/05-frontend-sayfa-gelistirme-spec.md`](../specs/05-frontend-sayfa-gelistirme-spec.md).

## Scope lock — in / out

### In scope (PR13 program)

| Area                      | PR13 deliverable |
| ------------------------- | ---------------- |
| Feature + DB coverage     | PR13.1 inventory |
| Embedded demo retirement  | PR13.2 inventory |
| Demo company spec         | PR13.3           |
| CSV fixture pack          | PR13.4           |
| Bootstrap / reset / smoke | PR13.5           |
| AI Coach DB context       | PR13.6           |
| Canias mapping discovery  | PR13.7           |

### Out of scope (PR13.0 and non-goals for MVP)

- App source changes (`src/**`)
- Migrations and SQL bootstrap scripts (`supabase/**`) in PR13.0
- Canias runtime connector implementation
- Public HTTP API productization
- SDK / client generation
- CRM integration
- Full bidirectional ERP sync
- Real-time ERP sync
- Automatic destructive ERP writes in MVP

## Non-negotiable principles

1. **V1 alignment** — Packaging must match V1 product documents and **real** implemented product capabilities, not artifact aspirations alone.
2. **No embedded TS business fixtures for product proof** — Production-facing product behavior must not depend on embedded TypeScript business fixtures.
3. **DB-backed demo** — Canonical demo path: DB-backed, importable, resettable, source-aware demo tenant (see [`13_demo_data_packaging_principles.md`](./13_demo_data_packaging_principles.md)).
4. **Full-stack readiness** — A feature is not “packaged” if UI only works via `VITE_PULS_DEMO_MODE` fallback or `fetchDemo*` when DB is empty.
5. **AI Coach** — Core value layer across workflows; DB-backed context; human-in-the-loop; no autonomous writes (see [`13_ai_coach_process_touchpoints.md`](./13_ai_coach_process_touchpoints.md)).
6. **Canias-first ERP** — First integration track after packaging gates; flexible transport modes; no automatic destructive ERP writes in MVP (see [`13_canias_first_integration_boundary.md`](./13_canias_first_integration_boundary.md)).
7. **Future candidates** — Public API, SDK/client generation, CRM integration, full bidirectional sync, and real-time sync are documented future candidates, **not** PR13 MVP commitments.

## DB-backed demo company principle

- One canonical **demo tenant** (evolve from Mert Teknik spec in [`../specs/07-supabase-demo-data-ihtiyaclari.md`](../specs/07-supabase-demo-data-ihtiyaclari.md))
- Target: **20-40 employees**, org hierarchy, leave/expense/performance/contracts, imported-source rows (PULS-owned and imported/source-owned org rows)
- Seed into `puls_*` schemas — not legacy `public.*` only ([`supabase/seed-demo.sql`](../../supabase/seed-demo.sql) gap documented for PR13.3+)
- Demo mode flag remains a **dev fallback**, not product-readiness proof ([`../data/11_demo_fallback_guard_matrix.md`](../data/11_demo_fallback_guard_matrix.md))

## Embedded TypeScript demo retirement principle

Retire as product-readiness dependencies:

- `src/lib/demo/*` (e.g. [`puls-demo-data.ts`](../../src/lib/demo/puls-demo-data.ts))
- `fetchDemo*` adapters used when real DB is empty
- Route-level hardcoded domain business data

Allowed interim: dev-only fallback under explicit env flags until PR13.5 bootstrap replaces it.

## Full-stack readiness definition

| Layer   | Question                                               |
| ------- | ------------------------------------------------------ |
| Route   | V1 route exists and matches spec?                      |
| Adapter | Reads/writes real backend when tenant has data?        |
| Backend | RPC / table / view / RLS documented?                   |
| DB      | Demo seed or import fills required completeness class? |
| UI      | Empty/error states honest (no silent demo masking)?    |

Reference inventories: [`../data/11_sidebar_data_api_inventory.md`](../data/11_sidebar_data_api_inventory.md), [`../data/11_org_setup_crud_readiness_matrix.md`](../data/11_org_setup_crud_readiness_matrix.md) (departments/positions source-aware mixed CRUD).

## AI Coach as process-embedded value layer

- Not only the `/ai-koc` teaser page — contextual assistance across setup, leave, expense, performance, contracts, dashboard
- Requires DB-backed context inventory (PR13.6)
- Today: static/teaser — **not** product-ready ([`13_ai_coach_process_touchpoints.md`](./13_ai_coach_process_touchpoints.md))

## Canias-first integration posture

- Canias before public API/SDK for first customer ERP path
- PULS UI remains read-only for ERP/import-owned master data today
- Integration modes and MVP bans: [`13_canias_first_integration_boundary.md`](./13_canias_first_integration_boundary.md)

## Table / data completeness classes

Use across PR13 docs — **not every table must be seeded**:

| Class                         | Meaning                                                              |
| ----------------------------- | -------------------------------------------------------------------- |
| `required seeded`             | Demo tenant must have baseline rows for V1 packaging proof           |
| `required scenario-generated` | Created by workflow smoke / scenario scripts (e.g. pending approval) |
| `readable empty-ok`           | UI valid with zero rows; empty state is honest                       |
| `future/not V1`               | Out of V1 packaging scope                                            |
| `sensitive/system`            | Auth, audit, vault — not demo narrative content                      |

## PR13 roadmap

| PR          | Deliverable                                                        |
| ----------- | ------------------------------------------------------------------ |
| **PR13.0**  | Scope lock + strategy docs (this PR)                               |
| **PR13.1**  | Feature + DB table coverage inventory (deepen traceability matrix) |
| **PR13.2**  | Embedded demo data retirement inventory                            |
| **PR13.3**  | DB-backed demo company data spec (`puls_*` aligned)                |
| **PR13.4**  | CSV fixture pack                                                   |
| **PR13.5**  | Demo bootstrap / reset / smoke                                     |
| **PR13.6**  | AI Coach DB context readiness                                      |
| **PR13.7**  | Canias connector discovery + AI action boundary                    |
| **PR14.1**  | Provider-agnostic connector preflight readiness                    |
| **PR14.2**  | ERP connector onboarding empty state                               |
| **PR14.3**  | Connector setup workbench                                          |
| **PR14.4**  | Tenant rollout readiness                                           |
| **PR14.5**  | Remote tenant rollout smoke results                                |
| **PR14.6**  | Authenticated E2E gate                                             |
| **PR14.7**  | Role + tenant empty-state gate                                     |
| **PR14.8**  | Connector setup persistence                                        |
| **PR14.9**  | Error observability and Sentry                                     |
| **PR14.9A** | Sentry source maps and setup check                                 |
| **PR14.10** | Mapping discovery                                                  |
| **PR14.11** | Connector preflight execution                                      |

## Definition of done before PR13.7

- [x] Traceability matrix verified against routes/adapters (PR13.1)
- [x] Embedded demo retirement list approved (PR13.2)
- [x] Demo company spec signed off with completeness classes (PR13.3)
- [x] CSV + bootstrap path defined (PR13.4–13.5)
- [x] AI context inventory complete (PR13.6)
- [x] Canias discovery checklist ready for first customer (PR13.7)
- [x] `/erp` uses canonical connector preflight posture instead of a Canias-only product abstraction (PR14.1)
- [x] `/erp` has a no-connector PULS empty state before provider metadata exists (PR14.2)
- [x] `/erp` exposes provider selection as local preview before runtime integration (PR14.3)
- [x] Tenant rollout readiness documents Puls Teknik A.S. and PULS Connector Lab as separate proof postures (PR14.4)
- [x] Remote Vercel smoke confirms both tenant postures on `/dashboard` and `/erp` (PR14.5)
- [x] Authenticated route stabilization can run against live Vercel when repository secrets are configured (PR14.6)
- [x] Role and tenant posture matrix covers Puls Teknik seeded state and PULS Connector Lab first-run empty state (PR14.7)
- [x] Connector setup persistence writes tenant-scoped setup lifecycle state without runtime sync (PR14.8)
- [x] Connector setup errors are observable, scrubbed, and user-friendly (PR14.9)
- [x] Sentry source maps and guarded setup-check event are ready without exposing public maps or test UI (PR14.9A)
- [ ] Connector mapping discovery connects source fields to canonical PULS data classes without import execution (PR14.10)
- [ ] Connector preflight validates readiness as a dry run with no ERP writes (PR14.11)

## Risks and mitigations

| Risk                         | Mitigation                                                       |
| ---------------------------- | ---------------------------------------------------------------- |
| Demo fallback masks empty DB | DB-backed demo + retirement of TS fixtures; honest matrix status |
| Legacy `public.*` seed drift | PR13.3 targets `puls_*` schemas                                  |
| AI over-promised in V1       | Teaser-only today; guardrails doc; PR13.6 context gate           |
| Destructive ERP writes       | MVP ban in strategy + Canias doc                                 |
| Public API scope creep       | Explicit future candidate; Canias-first track                    |
| Silent “ready” labels        | PR13 status taxonomy; no `production_ready` if demo-only         |

## Related documents

- [`13_v1_feature_traceability_matrix.md`](./13_v1_feature_traceability_matrix.md)
- [`13_demo_data_packaging_principles.md`](./13_demo_data_packaging_principles.md)
- [`13_ai_coach_process_touchpoints.md`](./13_ai_coach_process_touchpoints.md)
- [`13_canias_first_integration_boundary.md`](./13_canias_first_integration_boundary.md)
- [`../api/README.md`](../api/README.md) — PR12 contract pack
