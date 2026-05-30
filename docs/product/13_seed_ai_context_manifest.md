# PR13.3 — Seed AI Context Manifest

Maps **Puls Sanayi A.Ş.** seed data to AI Coach touchpoints — context sources for PR13.6, not live autonomous AI.

**Documentation-only.** PR13.3 seeds **AI context sources only**; product-ready AI Coach is **PR13.6**. `/ai-koc` remains a teaser until then.

Production-facing product behavior must not depend on embedded TypeScript business fixtures.

## Executive summary

AI Coach is a core V1 value column but **not product-ready** today ([`13_ai_context_data_requirements.md`](./13_ai_context_data_requirements.md)). PR13.3 ensures the demo tenant carries enough **DB-backed**, **tenant-scoped**, **source-aware** context that PR13.6 can wire touchpoints without `fetchDemo*` pollution.

Guardrails: **human-in-the-loop**; no autonomous mutations; no auto-approvals; no ERP writes.

## AI guardrails (seed + future product)

| Guardrail | Requirement |
|-----------|-------------|
| No autonomous mutations | AI suggests; user confirms all writes |
| No auto-approvals | Leave/expense decide stays user-initiated RPC |
| No ERP writes | Canias context read-only — **metadata seed only**, **no Canias runtime** |
| Tenant-scoped | Context from `Puls Sanayi A.Ş.` tenant only via `resolveTenantContext()` |
| Source disclosure | Label PULS-owned vs imported rows in responses |
| Human-in-the-loop | Required for every touchpoint — **human-in-the-loop** |
| No demo training | Context reads must not use `puls-demo-data.ts` payloads |

## Touchpoint mapping

| Touchpoint | Seeded context | Tables / views | Minimum data | Guardrail | PR13.6 usage |
|------------|----------------|----------------|--------------|-----------|--------------|
| Setup coach | Org completeness, ERP mapping gaps, readiness checklist | `puls_calc.setup_readiness_summary`, `departments`, `positions`, `employees`, `erp_connections`, `erp_field_mappings` | 12 departments, 120 employees, inactive Canias + 10–25 mappings | Read-only context; no setup mutations | Wire aggregated readiness rules to **AI Coach** panel |
| Employee data quality coach | Assignment gaps, reporting completeness | `puls_core.employees`, `employee_reporting_lines`, `employee_cost_center_assignments` | 119+ reporting lines, 120 cost-center assignments | No bulk employee edits | Surface gap detection from readiness adapters |
| Leave request helper | Types, balances, policies, recent requests (read) | `leave_types`, `leave_balances`, `approval_policies`, `leave_requests`, `puls_calc.leave_overview` | 6–10 types, 120+ balances, scenario requests (**pending**, **approved**, **rejected**) | No auto-submit `create_leave_request` | Explain policy + balance; user confirms create |
| Expense claim helper | Categories, limits, claims (read) | `expense_categories`, `expense_claims`, `puls_calc.expense_overview` | 8–15 categories, scenario claims with VAT/limit examples | No auto-submit `create_expense_claim` | Explain limits; user confirms create |
| Performance manager coach | Cycles, templates, scores, evaluations | `performance_cycles`, `competency_templates`, `performance_scores`, `competency_evaluations`, `puls_calc.performance_overview` | 1–2 cycles, 8–15 templates, 80+ score/eval rows | No cycle status auto-change | Manager coaching summaries from real scores |
| Contract risk explainer | Contract metadata + risk tiers | `puls_workflow.contracts`, `puls_calc.contracts_overview` | 15–30 contracts with **contract risk** variety | Read-only contract metadata | Explain low/medium/high risk examples |
| Dashboard insight summary | KPIs, queues, ERP readiness | `puls_calc.dashboard_overview`, ERP fields | Non-zero KPIs, pending approvals, Canias readiness | No queue auto-actions | Narrative layer over calc view |
| Profile / persona assistant | Current user employee + personal summaries | `employees`, `puls_calc.leave_overview`, `expense_overview`, `performance_overview` | Persona-linked employee row per auth user | Scoped to current user only | Personal context without cross-employee leak |

## Data quality expectations

- Enough variety for **useful suggestions** — not synthetic nonsense labels
- Turkish business context aligned to **Puls Sanayi A.Ş.** industrial manufacturing domain
- **No real personal data**; synthetic names only
- **No hidden prompt/test secrets** in seed rows
- Scenario statuses (**pending**, **approved**, **rejected**, **half-day**, historical inactive labels) provide realistic coach examples

## What PR13.3 does not deliver

| Out of scope | Owner |
|--------------|-------|
| Live LLM / chat UI | PR13.6 |
| Unified context API / RPC | PR13.6 |
| `puls_vault.conversation_messages` seed | PR13.6 (sensitive/system) |
| Autonomous workflow actions | Never in V1 without explicit human confirm |

## PR13.6 handoff

PR13.6 will:

1. Authoritative context assembly boundary (read models vs new RPC/view)
2. RLS notes per touchpoint table
3. Guardrail checklist before any touchpoint ships beyond teaser
4. Upgrade feature matrix AI row only when DB path proven without demo fixtures

## PR13.7 note

Canias ERP runtime and write-back discovery — **PR13.7** only. Seed provides **metadata seed only** for coach ERP context reads.

## References

- [`13_ai_context_data_requirements.md`](./13_ai_context_data_requirements.md)
- [`13_ai_coach_process_touchpoints.md`](./13_ai_coach_process_touchpoints.md)
- [`13_seed_table_coverage_manifest.md`](./13_seed_table_coverage_manifest.md)
- [`13_seed_scenario_generation_spec.md`](./13_seed_scenario_generation_spec.md)
