# PR13.2 — Packaging Proof Demo Guardrails

Defines what counts — and does **not** count — as V1 packaging proof versus allowed dev fallback. Separates PR11/12 WithMeta honesty (`source: real` | `source: demo`) from PR13 packaging signoff.

Production-facing product behavior must not depend on embedded TypeScript business fixtures.

**Documentation-only.** Enforcement is via PR13.5 bootstrap smoke and process gates until runtime guards ship in later PRs.

## Executive summary

A DB-backed demo tenant is the **canonical packaging proof path**. Embedded TypeScript in [`puls-demo-data.ts`](../../src/lib/demo/puls-demo-data.ts) and `VITE_PULS_DEMO_MODE` may remain for **development** temporarily, but **`source: demo is not packaging proof`**.

## What counts as packaging proof

| Evidence type | Requirement |
|---------------|-------------|
| DB-backed tenant data | Seeded per [`13_db_table_completeness_classes.md`](./13_db_table_completeness_classes.md) |
| Full-stack path | route → adapter → backend/RLS/RPC/table/view → DB → UI |
| Source-aware rows | PULS-owned + imported/source-owned examples in demo tenant (source-aware mixed CRUD for org) |
| Scenario-generated workflows | Leave/expense requests, approvals via RPC smoke scripts |
| Manual smoke / runbook | Documented steps with demo mode **off** |
| WithMeta honesty | Core scenario returns `source: real` — not demo pill |

## What does not count

| Evidence type | Why rejected |
|---------------|--------------|
| `VITE_PULS_DEMO_MODE` alone | Env flag is dev fallback, not product demo |
| [`puls-demo-data.ts`](../../src/lib/demo/puls-demo-data.ts) | Embedded TypeScript business fixtures |
| Route-level hardcoded domain data | Bypasses adapter/DB path |
| `fetchDemo*` success state | Demo adapter path when DB empty |
| **`source: demo`** | Demo pill is honest WithMeta metadata — **source: demo is not packaging proof** |
| Screenshots from embedded demo fallback | Visual proof without DB backing |
| Static AI teaser ([`STATIC_AI_COACH_OVERVIEW`](../../src/lib/data/ai-coach/overview.ts)) | Not product-ready AI |

Reference: [`result.ts`](../../src/lib/data/result.ts) returns `source: 'real' | 'demo'` via `resolveAdapterDataWithMeta`. The demo pill correctly labels fallback — it must not be mistaken for packaging completeness.

## Allowed temporary uses

| Use | Classification | Packaging impact |
|-----|----------------|------------------|
| Dev fallback with demo flag | Interim until PR13.5 | Not proof |
| Unit/integration test fixtures | `test_only_ok` | Not proof |
| Static placeholder / teaser copy | `static_placeholder_ok` | Not proof |
| Empty state / i18n copy | Non-fixture | Not proof |

Embedded TypeScript demo data may remain temporarily as a dev fallback, but it cannot be used as V1 packaging proof.

## Packaging signoff gates

Before a feature row upgrades to packaging-ready in traceability docs:

1. **`VITE_PULS_DEMO_MODE=false`** (or unset) in proof environment
2. Demo tenant DB seeded per PR13.3 spec
3. Route smoke passes **without demo pill** — core scenario `source: real`
4. No packaging claim when only `fetchDemo*` fills rich UI
5. **AI Coach** remains labeled teaser until PR13.6 gates pass
6. **Canias:** **metadata seed only** in demo tenant (`erp_connections`, `erp_field_mappings`); **no Canias runtime** in PR13.2–13.5 proof (connector discovery PR13.7)

## New embedded fixture guard

Any new embedded business fixture must be classified before merge to product paths:

| Addition | Required classification |
|----------|-------------------------|
| New rich data in `puls-demo-data.ts` | P0/P1/P2 + retirement plan update |
| New product `fetchDemo*` in adapters | Same — or `test_only_ok` / `static_placeholder_ok` |
| New visible demo fallback surface | Update [`13_embedded_demo_dependency_map.md`](./13_embedded_demo_dependency_map.md) and retirement plan |

PR13.2 verify script needles guard doc consistency; optional grep automation is PR13.2+ follow-up.

## Dev fallback vs proof (quick reference)

| Condition | Dev fallback OK? | Packaging proof? |
|-----------|------------------|------------------|
| Demo mode on + empty DB + `fetchDemo*` | Yes (interim) | No |
| Demo mode off + seeded DB + `source: real` | N/A | Yes |
| Demo mode off + empty DB + empty state | Yes (honest) | Partial — empty-ok surfaces only |
| Demo mode on + seeded DB | Yes | No — proof requires demo off |
| `source: demo` pill showing | Yes (labeled) | No |

## References

- [`13_embedded_demo_retirement_plan.md`](./13_embedded_demo_retirement_plan.md)
- [`13_embedded_demo_dependency_map.md`](./13_embedded_demo_dependency_map.md)
- [`13_v1_product_packaging_strategy.md`](./13_v1_product_packaging_strategy.md)
- [`../data/11_demo_fallback_guard_matrix.md`](../data/11_demo_fallback_guard_matrix.md)
