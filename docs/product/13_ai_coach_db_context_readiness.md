# PR13.6 — AI Coach DB Context Readiness

PR13.6 adds the DB-backed AI Coach **context readiness** layer on top of merged PR13.5A live-proof seed. With **`VITE_PULS_DEMO_MODE=false`**, `/ai-koc` reads tenant-scoped context readiness from real Supabase/Postgres adapters.

**PR13.6 proves DB context readiness, not live LLM chat.**

AI Coach is a process-embedded value layer, not only the /ai-koc page. Production-facing product behavior must not depend on embedded TypeScript business fixtures for AI context.

## What PR13.6 proves

- Tenant-scoped DB context assembly for 8 process touchpoints
- Honest teaser UX: context readiness + guardrails, no chat
- `source: real` adapter path when demo mode is off
- Read-only packaging posture aligned with PR13.4–13.5A seed

## Required verbatim guardrails (packaging proof)

- Production-facing product behavior must not depend on embedded TypeScript business fixtures for AI context.
- AI Coach is a process-embedded value layer, not only the /ai-koc page.
- Packaging proof uses `VITE_PULS_DEMO_MODE=false` and `source: real`.
- human-in-the-loop — no autonomous mutations — no auto-approvals — no ERP writes.
- puls_vault.conversation_messages is sensitive/system and must not be seeded for PR13.6.
- llm-gateway is a future service-boundary hint, not a physical MVP microservice.
- PR13.6 proves DB context readiness, not live LLM chat.

## What PR13.6 does not prove

- Live chat or LLM runtime
- OpenAI/API keys or **llm-gateway is a future service-boundary hint, not a physical MVP microservice**
- Autonomous mutations, auto-approvals, or ERP writes
- `puls_vault.conversation_messages` seed or writes — **puls_vault.conversation_messages is sensitive/system and must not be seeded for PR13.6**

## Inspect-first table

| Area | Source | Finding | PR13.6 decision |
|------|--------|---------|-----------------|
| AI adapter | `src/lib/data/ai-coach/overview.ts` | Was static `STATIC_AI_COACH_OVERVIEW` | DB-backed via `resolveTenantContext` + schema clients |
| AI route | `src/routes/_app/ai-koc.tsx` | Teaser hero + capabilities | Context readiness (8 domains) + guardrails |
| Demo fallback | `fetchDemoAiCoachOverview` | Legacy shape only | Wrapped by `buildDemoAiCoachOverview()` |
| Seed context | PR13.4–13.5A + `07_validate_packaging_proof.sql` | 120 employees, calc views, scenarios | Evidence thresholds |
| Calc views | `puls_calc.*` | Dashboard, setup, leave, expense, performance, contracts | Primary read models |
| Vault | crosswalk Koç row | `puls_vault.conversation_messages` sensitive/system | Readiness guardrail only |
| Guardrails | `13_seed_ai_context_manifest.md` | human-in-the-loop, no autonomous mutations | UI + verify |
| Route matrix | `13_route_packaging_proof_matrix.md` | `/ai-koc` teaser until PR13.6 | DB context readiness, still no chat |

## Eight touchpoints (context domain matrix)

| Domain | Route | DB evidence |
|--------|-------|-------------|
| Setup coach | `/sirket-kurulum` | `setup_readiness_summary`, departments, positions, employees |
| Employee data quality | `/calisanlar` | employees, reporting lines |
| Leave helper | `/izin` | leave types, balances, requests |
| Expense helper | `/masraf` | expense categories, claims |
| Performance coach | `/performans` | cycles, templates, scores/evaluations |
| Contract risk | `/sozlesmeler` | contracts, `contracts_overview` |
| Dashboard insight | `/dashboard` | `dashboard_overview` |
| Profile/persona | `/profil` | `resolveTenantContext` employee link |

## DB read model inventory

- `puls_calc.setup_readiness_summary`
- `puls_calc.dashboard_overview`
- `puls_calc.leave_overview`, `expense_overview`, `performance_overview`, `contracts_overview`
- `puls_core.employees`, `departments`, `positions`, `employee_reporting_lines`
- `puls_workflow.leave_*`, `expense_*`, `contracts`
- `puls_performance.performance_cycles`, `competency_templates`, `performance_scores`, `competency_evaluations`
- `puls_integration.source_namespaces`, `erp_connections` (inactive Canias metadata)

## Guardrail checklist

- DB-backed context — **enforced**
- Tenant scoped — **enforced**
- **human-in-the-loop** — **enforced**
- **no autonomous mutations** — **enforced**
- **no auto-approvals** — **enforced**
- **no ERP writes** — **enforced**
- No vault message seed — **enforced**
- No LLM/API runtime — **enforced**

## No-tenant + demo fallback behavior

| Mode | Behavior |
|------|----------|
| `VITE_PULS_DEMO_MODE=false` | Return real overview with blocked domains (`source: real`). No demo payload even if `isEmpty` is true. |
| `VITE_PULS_DEMO_MODE=true` | Blocked/no-tenant real overview may trigger demo fallback via `buildDemoAiCoachOverview()` (`source: demo`). |

## `/ai-koc` UX posture

- Teaser mode — no live chat, no “ask AI” input
- Product posture mapped to i18n (“DB context available — teaser mode”) — raw enum strings not shown
- Context readiness section with 8 domains and evidence counts
- Guardrails list with enforced/pending status

## Packaging acceptance criteria

- `./scripts/verify-13-ai-coach-db-context-readiness.sh HEAD` passes
- `node scripts/check-sensitive-grep.mjs` passes
- `pnpm check-i18n && pnpm test && pnpm build` passes
- Optional: `08_validate_ai_context_readiness.sql` after PR13.5 seed load

## Handoff to PR13.7+

- Canias mapping discovery (PR13.7) — metadata read-only; no runtime writeback
- Future LLM gateway — service boundary hint only; physical microservice out of MVP scope
- Live touchpoint UIs beyond `/ai-koc` teaser when guardrails and context assembly proven per route
