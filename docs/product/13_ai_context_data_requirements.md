# PR13.1 — AI Context Data Requirements

DB-backed context requirements for AI Coach touchpoints — evidence-backed gaps between strategy ambition and current static/teaser implementation.

**Documentation-only.** PR13.6 delivers readiness gates and context inventory enforcement.

## Executive summary

AI Coach is a **core V1 product value column** in packaging strategy but **not product-ready** today. [`ai-coach/overview.ts`](../../src/lib/data/ai-coach/overview.ts) returns `STATIC_AI_COACH_OVERVIEW` with optional `fetchDemoAiCoachOverview` — **no DB reads**, no LLM, no autonomous actions.

Context for future touchpoints must be **DB-backed**, **tenant-scoped**, **source-aware**, **human-in-the-loop**, with **no autonomous mutation**.

## AI Coach current state

| Component | Status |
|-----------|--------|
| `/ai-koc` route | Teaser UI — capability cards + readiness checklist |
| `fetchAiCoachOverview` | Real path = static constants |
| Demo fallback | `fetchDemoAiCoachOverview` when demo mode |
| DB context reads | **None** on real path |
| Product-ready | **No** |

See also [`13_ai_coach_process_touchpoints.md`](./13_ai_coach_process_touchpoints.md).

## AI context source principles

| Principle | Requirement |
|-----------|-------------|
| DB-backed | Context from tenant tables/views — not `puls-demo-data.ts` |
| Tenant-scoped | `resolveTenantContext()` boundary |
| Source-aware | Label imported/ERP-owned vs PULS-owned in responses |
| No autonomous mutation | Suggest only; user confirms writes |
| Human-in-the-loop | No auto-approve, no ERP writes |

## Touchpoint matrix

| Touchpoint | Required DB context | Existing adapter/read model | Missing data | Completeness class | Safety guardrail | Follow-up PR |
|------------|---------------------|----------------------------|--------------|-------------------|------------------|--------------|
| Setup coach | `setup_readiness_summary`, `departments`, `positions`, `employees`, `erp_field_mappings`, `erp_connections` | `setup/company.ts`, `setup-readiness-dashboard.ts`, `setup/erp.ts` | Aggregated readiness rules not exposed for AI; no coach panel | `required seeded` | Read-only context; no setup mutations | PR13.6 |
| Employee data quality coach | `employees`, `employee_reporting_lines`, `employee_cost_center_assignments`, assignment readiness views | `core/employees.ts`, `setup/employee-assignment-readiness.ts` | Gap detection logic exists in readiness adapter — not AI-wired | `required seeded` | No bulk employee edits | PR13.6 |
| Leave request helper | `leave_types`, `leave_balances`, `approval_policies`, `leave_requests` (read) | `leave/overview.ts`, `setup/request-creation-readiness.ts` | Policy explain layer; create stays RPC + user confirm | `required seeded` + scenario reads | No auto-submit leave RPC | PR13.6 |
| Expense claim helper | `expense_categories`, `expense_claims` (read), limits | `expense/overview.ts`, `setup/request-creation-readiness.ts` | Receipt/limit explain; create stays RPC | `required seeded` + scenario reads | No auto-submit expense RPC | PR13.6 |
| Performance manager coach | `performance_cycles`, `competency_templates`, `competency_evaluations`, `performance_scores` | `performance/overview.ts`, `performance/cycles.ts` | Overview demo-heavy; evaluations sparse | `required seeded` | No cycle status auto-change | PR13.6 |
| Contract risk explainer | `puls_workflow.contracts`, `contracts_overview` | `contracts/overview.ts` | Risk rules not defined; metadata read exists | `required seeded` | Read-only contract metadata | PR13.6 |
| Dashboard insight summary | `dashboard_overview`, ERP readiness fields | `dashboard/overview.ts` | KPI narrative layer; calc views real when seeded | `required seeded` | No queue auto-actions | PR13.6 |
| Profile/persona assistant | `employees` linked to auth user, `leave_overview`, `expense_overview`, `performance_overview` | `profile/overview.ts` | Persona context reads exist; no AI layer | `required seeded` | Scoped to current user employee row | PR13.6 |

## Context gaps (summary)

| Gap | Detail |
|-----|--------|
| No unified context API | Each touchpoint would duplicate adapter reads |
| Vault/tool layer pending | Readiness UI shows tool-call layer **pending** |
| Demo fallback pollutes dev | AI must not train on `fetchDemo*` payloads |
| ERP context read-only | Canias mappings available; no write-back |

## No AI product-ready claim

- `/ai-koc` is a **static teaser** per V1 spec — not chat, not coaching
- **No embedded mock AI response** counts as V1 packaging proof
- Demo `fetchDemoAiCoachOverview` is **`static_placeholder_ok`** only
- Product-ready requires PR13.6: DB context inventory + guardrail enforcement + honest UX labeling

## PR13.6 handoff

PR13.6 will:

1. Authoritative table-level context inventory with RLS notes
2. Define context assembly boundary (read models vs new RPC/view)
3. Guardrail checklist before any touchpoint ships beyond teaser
4. Upgrade matrix AI row only when DB path proven without demo fixtures

## References

- [`13_ai_coach_process_touchpoints.md`](./13_ai_coach_process_touchpoints.md)
- [`13_feature_db_coverage_inventory.md`](./13_feature_db_coverage_inventory.md)
- [`13_db_table_completeness_classes.md`](./13_db_table_completeness_classes.md)
- [`../../src/lib/data/ai-coach/overview.ts`](../../src/lib/data/ai-coach/overview.ts)
