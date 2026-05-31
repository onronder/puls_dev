# Puls Sanayi A.Ş. — V1 baseline seed pack (PR13.4)

DB-backed, source-aware, resettable baseline CSV/SQL artifacts for the canonical V1 demo tenant **Puls Sanayi A.Ş.** — 120 employees, 12 departments, 3 locations.

## What this pack is

- PR13.3 / PR13.3A-aligned **baseline seed artifacts** (CSV + SQL scaffold + manifest)
- Deterministic synthetic data targeting `puls_core`, `puls_workflow`, `puls_performance`, `puls_integration`
- Mixed **PULS-owned** and **imported/source-owned** org rows (Canias metadata only)
- FK-safe `manifest.loadOrder` for real DB load in PR13.5

## What this pack is not

- Not embedded TypeScript demo proof (`fetchDemo` is not packaging proof)
- Not app code, migrations, or live `supabase db push`
- Not Canias runtime or ERP writeback (**metadata seed only**)
- Not auth/users bootstrap (`employees.user_id` deferred to PR13.5)
- Not workflow scenario rows (`leave_requests`, `expense_claims`, `approval_requests`, scores — PR13.5)

## Core principles

Production-facing product behavior must not depend on embedded TypeScript business fixtures.

The canonical V1 demo company is DB-backed, source-aware, resettable, and large enough to exercise real product workflows.

PR13.4 seed artifacts must follow the data dictionary alignment crosswalk.

Packaging proof uses **`VITE_PULS_DEMO_MODE=false`** — `source: demo is not packaging proof` (demo pill / embedded demo may remain as dev fallback only).

Canias boundary: **metadata seed only**; **no Canias runtime**; **no automatic destructive ERP writes**.

## Numbered filenames vs load order

**Numbered CSV filenames are artifact identifiers, not load order.** See [`load-order.md`](./load-order.md) and `manifest.json` → `loadOrder`.

## File `21_performance_parameters.csv`

This is a **multi-table baseline context file**, not setup parameters only. It includes:

- `competency_templates`, `kpi_category_weights`, `score_bands` (setup params)
- `training_needs` (20–40 rows, spread across departments) for `/egitim`
- `career_profiles` (20–40 rows, representative employees only — not 120) for `/kariyer`

`manifest.tableColumnMap` defines separate `insertableColumns` per `target_table`.

## How to load locally

**Supabase SQL Editor cannot read local CSV file paths directly.**

Use local `psql` from this pack root:

```bash
export DATABASE_URL='postgresql://...'
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/00_reset_puls_sanayi_seed.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/01_load_puls_sanayi_seed.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/02_validate_puls_sanayi_seed.sql
```

`01_load_puls_sanayi_seed.sql` is a **psql-local loader** using `\copy`. PR13.5 may add an inline SQL loader; PR13.4 does not imply one-click SQL Editor CSV loading.

## How to validate

1. Run `sql/02_validate_puls_sanayi_seed.sql` after load
2. Run repo verify: `./scripts/verify-13-synthetic-seed-artifacts.sh HEAD`

## Legacy exclusion

-- LEGACY_PUBLIC_EXCLUSION: public.* seed-demo.sql is intentionally not used; this pack targets puls_* schemas only.

Historical legacy fixture names (e.g. in old `seed-demo.sql`) are not the canonical V1 tenant. This pack uses **Puls Sanayi A.Ş.** only in CSV/manifest data.

## PR13.5 handoff

PR13.5 loads this pack, runs scenario scripts (`03`–`07`), binds auth users (`05`–`06`), and proves routes with **`VITE_PULS_DEMO_MODE=false`**.

See [`docs/product/13_seed_bootstrap_proof_runbook.md`](../../docs/product/13_seed_bootstrap_proof_runbook.md).

### PR13.5 SQL (after baseline load)

| Script | Purpose |
|--------|---------|
| `sql/03_generate_workflow_scenarios.sql` | Leave/expense scenarios + lifecycle event narrative |
| `sql/04_generate_performance_scenarios.sql` | KPIs, evaluations, scores (80+ combined) |
| `sql/05_link_auth_personas_template.sql` | Auth UUID → `employees.user_id` template |
| `sql/06_jwt_mutation_proof_smoke.sql` | RPC proof (ROLLBACK) |
| `sql/07_validate_packaging_proof.sql` | Baseline + scenario + calc validation |

## References

- [`docs/product/13_synthetic_company_seed_spec.md`](../../docs/product/13_synthetic_company_seed_spec.md)
- [`docs/product/13_seed_table_coverage_manifest.md`](../../docs/product/13_seed_table_coverage_manifest.md)
- [`docs/product/13_data_dictionary_seed_crosswalk.json`](../../docs/product/13_data_dictionary_seed_crosswalk.json)
