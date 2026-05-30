# PR13.0 — Demo Data Packaging Principles

Principles for canonical DB-backed demo company data and retirement of embedded TypeScript business fixtures.

## Executive summary

PULS v1.0 product packaging **cannot** be validated by rich data in `src/lib/demo/puls-demo-data.ts` or `VITE_PULS_DEMO_MODE` fallback alone. The canonical demo path is a **DB-backed demo tenant** that is importable, resettable, and source-aware.

Production-facing product behavior must not depend on embedded TypeScript business fixtures.

## Canonical demo model: DB-backed demo tenant

| Property | Requirement |
|----------|-------------|
| Tenant | Single canonical demo company (evolve Mert Teknik from [`../specs/07-supabase-demo-data-ihtiyaclari.md`](../specs/07-supabase-demo-data-ihtiyaclari.md)) |
| Storage | `puls_core`, `puls_workflow`, `puls_performance`, `puls_integration`, `puls_calc` — **not** legacy `public.*` only |
| Scale | **20-40 employees**, manager hierarchy, departments, positions, cost centers |
| Lifecycle | Importable (CSV), bootstrap SQL, reset scripts, documented runbook |
| Source awareness | PULS-owned vs imported/ERP-owned rows distinguished (`external_source`, read-only guards) |

## No embedded TypeScript business fixtures

### Retire as product-readiness proof

| Pattern | Location | Action |
|---------|----------|--------|
| Central demo module | `src/lib/demo/*`, especially `puls-demo-data.ts` | PR13.2 inventory → PR13.5 replace with DB seed |
| Demo fetchers | `fetchDemo*` in adapters via `resolveAdapterData*` | Same |
| Inline demo stubs | e.g. performance cycles `[]`, employee list composites | PR13.2 inventory |
| Route mocks | Hardcoded domain arrays in route files | Forbidden for packaging proof |

### Allowed (interim / dev-only)

| Artifact | Use |
|----------|-----|
| `VITE_PULS_DEMO_MODE` | Dev fallback when DB empty — **not** product demo proof ([`../data/11_demo_fallback_guard_matrix.md`](../data/11_demo_fallback_guard_matrix.md)) |
| Test fixtures | Unit/integration tests only |
| Static UI copy | i18n, empty states |

## Allowed demo artifacts (PR13.4+)

- CSV fixture packs (employees, org, leave types, categories, etc.)
- SQL bootstrap scripts (`seed-demo-*.sql` targeting `puls_*`)
- Import runbooks (Supabase SQL editor, CLI, future import batch)
- Reset scripts (truncate tenant-scoped data, re-seed)
- Scenario scripts (create pending approval via RPC — `required scenario-generated`)

## Disallowed product-readiness proof

- Rich `.ts` business data presenting as complete product
- Route-level mocks bypassing adapters
- Production demo fallback without explicit env (`VITE_PULS_ALLOW_DEMO_FALLBACK_IN_PROD`)
- Claiming V1 ready when only demo pill shows data

## Demo data classes

| Class | Owner | UI behavior |
|-------|-------|-------------|
| PULS-owned editable | Tenant admin / setup routes | CRUD where implemented |
| Imported / source-owned | ERP or CSV import | Read-only or lifecycle-only in UI |
| Future Canias-owned | Canias master sync | Import candidate; no destructive write-back in MVP |

## Minimum DB-backed demo company content

| Domain | Completeness class | Notes |
|--------|-------------------|-------|
| Tenant / company | `required seeded` | Legal name, demo flag |
| Employees (20-40) | `required seeded` | Linked to auth personas for demo login |
| Departments / positions | `required seeded` | PULS-owned editable rows + imported/source-owned read-only examples |
| Manager hierarchy | `required seeded` | Approval chain resolution |
| Leave types / policies | `required seeded` | Policy binding for create |
| Leave balances | `required seeded` | Sufficient for create smoke |
| Leave requests (sample) | `required scenario-generated` | Optional pending rows |
| Expense categories | `required seeded` | Limits, receipt thresholds |
| Expense claims (sample) | `required scenario-generated` | Optional pending |
| Performance cycles | `required seeded` | At least one draft/active cycle |
| Performance templates/params | `required seeded` | Params route content |
| Contracts metadata | `required seeded` | Summary rows for `/sozlesmeler` |
| Profile-linked personas | `required seeded` | Demo users ↔ employees |
| ERP connection (Canias) | `required seeded` | Inactive/configured; partial mappings |
| Imported-source org rows | `required seeded` | At least one `canias_erp` read-only example |
| Career / training depth | `readable empty-ok` or `future/not V1` | Honest empty or future |
| AI vault context | `sensitive/system` | PR13.6 |

## Table completeness classes

| Class | Packaging rule |
|-------|----------------|
| `required seeded` | Must exist in demo tenant for V1 proof |
| `required scenario-generated` | Created by workflow/bootstrap scripts |
| `readable empty-ok` | Zero rows is valid UX |
| `future/not V1` | Not required for V1 packaging signoff |
| `sensitive/system` | Not part of demo narrative |

**Not every table must be seeded** — use classes above.

## Existing gap

[`supabase/seed-demo.sql`](../../supabase/seed-demo.sql) seeds legacy `public.*` (4 employees). PR13.3+ must specify `puls_*`-aligned seeds per [`../data/PULS_TECHNICAL_IMPLEMENTATION_PLAN.md`](../data/PULS_TECHNICAL_IMPLEMENTATION_PLAN.md).

## Verification strategy

1. PR13.5 smoke: key routes return `source: real` with demo tenant loaded (no demo flag)
2. PR13.2 grep inventory: `fetchDemo` / `puls-demo-data` usage per route
3. Matrix status upgrades only when DB path proven ([`13_v1_feature_traceability_matrix.md`](./13_v1_feature_traceability_matrix.md))

## PR13.2–13.5 handoff

| PR | Deliverable |
|----|-------------|
| PR13.2 | Embedded demo retirement inventory (file + route list) |
| PR13.3 | Demo company data spec with completeness classes |
| PR13.4 | CSV fixture pack |
| PR13.5 | Bootstrap, reset, smoke scripts |

## References

- [`13_v1_product_packaging_strategy.md`](./13_v1_product_packaging_strategy.md)
- [`../specs/07-supabase-demo-data-ihtiyaclari.md`](../specs/07-supabase-demo-data-ihtiyaclari.md)
