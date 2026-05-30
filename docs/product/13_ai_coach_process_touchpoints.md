# PR13.0 — AI Coach Process Touchpoints

Process-embedded AI Coach value layer across PULS workflows — scope, guardrails, DB context requirements, and honest current status.

**Documentation-only.** PR13.6 delivers DB context inventory and readiness gates.

## Executive summary

AI Coach is a **core V1 product value column** in packaging strategy — contextual assistance embedded in setup, workflows, and dashboards, not only a standalone page.

Today the product implements a **teaser/static** `/ai-koc` surface. That is honest **implemented posture** (V1 spec: teaser not chat). It is **not** product-ready AI. PR13.6 gates readiness on DB-backed context and guardrails.

## V1 tension: implemented vs ambition vs package gate

| Dimension | Posture |
|-----------|---------|
| **Current implemented status** | `placeholder`/static/teaser — `STATIC_AI_COACH_OVERVIEW` in [`ai-coach/overview.ts`](../../src/lib/data/ai-coach/overview.ts); demo fallback via `fetchDemoAiCoachOverview`; **not product-ready** |
| **V1 product ambition** | Process-embedded AI value layer across workflows (strategy non-negotiable #5) |
| **V1 package decision** | `db_backed_demo_required` for context inventory; readiness gate = **PR13.6**; `/ai-koc` remains teaser until DB context + guardrails ship |

This is not a contradiction: the spec defines **what ships in UI today**; strategy defines **what packaging must prove** before AI Coach counts as a packaged capability.

## Role: process-embedded value layer

AI Coach is not limited to `/ai-koc`. Target touchpoints span:

- Company and org setup readiness
- Employee data quality during directory and assignment flows
- Leave and expense request helpers (policy explain, draft assist — human submits)
- Performance manager coaching (cycle context, review prep)
- Contract risk explainers on metadata surfaces
- Dashboard insight summaries (KPI context, queue prioritization hints)

Each touchpoint reads **tenant-scoped DB context** — not embedded TypeScript fixtures.

## Guardrails (non-negotiable)

| Rule | Rationale |
|------|-----------|
| **No autonomous mutations** | AI may suggest; user confirms all writes |
| **No autonomous approvals** | Approval decisions remain human-only |
| **No ERP writes** | Especially no automatic destructive ERP writes in MVP |
| **No cross-tenant access** | Context strictly scoped to resolved tenant + user |
| **Source disclosure** | Imported/ERP-owned vs PULS-owned data labeled in responses |
| **Human-in-the-loop** | Every action path requires explicit user intent |

Production-facing product behavior must not depend on embedded TypeScript business fixtures for AI context either — context must come from DB-backed tenant data (PR13.6 inventory).

## Required DB context (PR13.6 inventory)

| Domain | Tables / views (indicative) | Completeness class |
|--------|----------------------------|-------------------|
| Dashboard | `puls_calc.dashboard_overview`, activity queues | `required seeded` |
| Org quality | `puls_core.departments`, `positions`, `employees`, readiness views | `required seeded` |
| Leave policy | `puls_workflow.leave_types`, policies, balances | `required seeded` |
| Expense policy | `puls_workflow.expense_categories`, limits | `required seeded` |
| Performance | `puls_performance.performance_cycles`, scores, templates | `required seeded` |
| Contracts | `puls_workflow.contracts`, summary calc | `required seeded` |
| Profile / persona | `puls_core.employees` linked to auth user | `required seeded` |
| ERP context | `puls_integration.erp_connections`, mappings (read-only) | `required seeded` (inactive OK) |
| Vault / audit | `puls_vault`, `puls_audit` | `sensitive/system` |

PR13.6 will produce the authoritative table-level inventory with RLS notes.

## Touchpoint matrix

| Touchpoint | Surface / route | Context needed | MVP posture |
|------------|-----------------|----------------|-------------|
| Setup coach | `/sirket-kurulum`, setup routes | Org readiness, ERP mapping status | Future contextual panel; teaser today |
| Employee data quality | `/calisanlar` | Missing assignments, hierarchy gaps | Future; not V1 chat |
| Leave request helper | `/izin` | Balances, types, policy rules | Future assist; create remains user-driven RPC |
| Expense claim helper | `/masraf` | Categories, limits, receipt rules | Future assist; create remains user-driven RPC |
| Performance manager coach | `/performans` | Cycles, scores, competency templates | Future; overview demo-heavy today |
| Contract risk explainer | `/sozlesmeler` | Contract metadata, expiry patterns | Future |
| Dashboard insight | `/dashboard` | KPIs, queues, ERP readiness | Future summary; calc views real when seeded |

## Current implementation status

| Component | Status |
|-----------|--------|
| `/ai-koc` route | Renders capability cards + readiness checklist from adapter |
| `fetchAiCoachOverview` | Real path returns `STATIC_AI_COACH_OVERVIEW` constants — no LLM, no DB reads |
| Demo fallback | `fetchDemoAiCoachOverview` when demo mode active |
| Feature flag | `ai_coach_enabled` referenced in field ownership matrix — passive |
| Vault schema | Exists (`puls_vault`); tool-call layer **pending** per readiness UI |

**Verdict:** AI Coach is **not product-ready**. Packaging must not imply live coaching, chat, or autonomous workflow actions in V1.

## PR13.6 handoff

PR13.6 will deliver:

1. DB context inventory per touchpoint (tables, views, RLS, completeness class)
2. Guardrail enforcement checklist (no write paths without user confirmation)
3. Definition of done for upgrading matrix AI Coach row from `embedded_demo_only`
4. Explicit boundary: teaser UI may remain while contextual panels ship incrementally

## References

- [`13_v1_product_packaging_strategy.md`](./13_v1_product_packaging_strategy.md)
- [`13_v1_feature_traceability_matrix.md`](./13_v1_feature_traceability_matrix.md) — AI Coach row
- [`../specs/05-frontend-sayfa-gelistirme-spec.md`](../specs/05-frontend-sayfa-gelistirme-spec.md) — AI V1 = teaser not chat
- [`../../src/lib/data/ai-coach/overview.ts`](../../src/lib/data/ai-coach/overview.ts)
