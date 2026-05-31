# PULS Product Packaging (PR13)

V1 product packaging strategy and inventory documents.

## PR13.0 strategy pack

| Document | Purpose |
|----------|---------|
| [13_v1_product_packaging_strategy.md](./13_v1_product_packaging_strategy.md) | Scope lock, principles, PR13 roadmap, non-goals |
| [13_v1_feature_traceability_matrix.md](./13_v1_feature_traceability_matrix.md) | V1 features → routes, backends, demo, AI, honest status |
| [13_demo_data_packaging_principles.md](./13_demo_data_packaging_principles.md) | DB-backed demo tenant; embedded TS retirement |
| [13_ai_coach_process_touchpoints.md](./13_ai_coach_process_touchpoints.md) | AI Coach value layer, guardrails, touchpoints |
| [13_canias_first_integration_boundary.md](./13_canias_first_integration_boundary.md) | Canias-first ERP boundary, MVP constraints |

Verify: [`../../scripts/verify-13-v1-product-packaging.sh`](../../scripts/verify-13-v1-product-packaging.sh)

## PR13.1 inventory pack

| Document | Purpose |
|----------|---------|
| [13_feature_db_coverage_inventory.md](./13_feature_db_coverage_inventory.md) | Feature → route → adapter → DB object matrix |
| [13_db_table_completeness_classes.md](./13_db_table_completeness_classes.md) | DB object completeness classes for demo packaging |
| [13_embedded_demo_dependency_map.md](./13_embedded_demo_dependency_map.md) | `fetchDemo*` / embedded TS dependency inventory |
| [13_ai_context_data_requirements.md](./13_ai_context_data_requirements.md) | AI Coach DB context requirements and gaps |

Verify: [`../../scripts/verify-13-feature-db-coverage.sh`](../../scripts/verify-13-feature-db-coverage.sh)

## PR13.2 retirement pack

PR13.2 **extends PR13.1** into an actionable retirement plan; it **does not replace** the dependency map or feature DB coverage docs.

| Document | Purpose |
|----------|---------|
| [13_embedded_demo_retirement_plan.md](./13_embedded_demo_retirement_plan.md) | P0/P1/P2 work packages and PR13.3–13.5 mapping |
| [13_packaging_proof_demo_guardrails.md](./13_packaging_proof_demo_guardrails.md) | Packaging proof vs dev fallback; `source: demo` rules |

Verify: [`../../scripts/verify-13-embedded-demo-retirement.sh`](../../scripts/verify-13-embedded-demo-retirement.sh)

## PR13.3 seed spec pack

PR13.3 **extends PR13.1 and PR13.2** into a DB-backed synthetic company specification; it **does not replace** the dependency map, feature inventory, or retirement plan.

| Document | Purpose |
|----------|---------|
| [13_synthetic_company_seed_spec.md](./13_synthetic_company_seed_spec.md) | 120-employee **Puls Sanayi A.Ş.** org model, personas, source ownership |
| [13_seed_table_coverage_manifest.md](./13_seed_table_coverage_manifest.md) | Product-facing `puls_*` object coverage, row targets, proof routes |
| [13_seed_scenario_generation_spec.md](./13_seed_scenario_generation_spec.md) | Workflow/performance/contract/dashboard scenario requirements |
| [13_seed_ai_context_manifest.md](./13_seed_ai_context_manifest.md) | Seed data → AI Coach touchpoints and guardrails |

Verify: [`../../scripts/verify-13-synthetic-company-seed-spec.sh`](../../scripts/verify-13-synthetic-company-seed-spec.sh)

## PR13.3A alignment pack

Bridge PR before PR13.4 — aligns [`Puls_Veri_Sozlugu_v1.0.xlsx`](../V1%20Dokümanlar/Puls_Veri_Sozlugu_v1.0.xlsx) with Supabase/Postgres + adapter architecture and PR13.3 seed spec. **Does not replace** PR13.3 docs; **no** CSV/SQL or `supabase/seed/**` in this PR.

| Document | Purpose |
|----------|---------|
| [13_data_dictionary_seed_alignment.md](./13_data_dictionary_seed_alignment.md) | Domain alignment matrix, route aliases, seed coverage decisions |
| [13_data_dictionary_architecture_notes.md](./13_data_dictionary_architecture_notes.md) | Microservice labels vs modular Supabase MVP architecture |
| [13_data_dictionary_seed_crosswalk.json](./13_data_dictionary_seed_crosswalk.json) | Machine-readable domain crosswalk for PR13.4 generator |

Verify: [`../../scripts/verify-13-data-dictionary-alignment.sh`](../../scripts/verify-13-data-dictionary-alignment.sh)

## PR13.4 baseline seed pack

PR13.4 **implements PR13.3 spec + PR13.3A crosswalk** as importable CSV/SQL artifacts for **Puls Sanayi A.Ş.** (120 employees). Defers scenario/bootstrap proof to PR13.5. **No** app code or migrations.

| Artifact | Purpose |
|----------|---------|
| [`supabase/seed/puls-sanayi-v1/`](../supabase/seed/puls-sanayi-v1/) | 22 baseline CSVs, manifest, FK-safe load order, reset/load/validate SQL |
| [`supabase/seed/puls-sanayi-v1/README.md`](../supabase/seed/puls-sanayi-v1/README.md) | Runbook: psql-local `\copy`, packaging proof guardrails, PR13.5 handoff |

Verify: [`../../scripts/verify-13-synthetic-seed-artifacts.sh`](../../scripts/verify-13-synthetic-seed-artifacts.sh)

## Related packs

| Pack | Entry point |
|------|-------------|
| API contract (PR12) | [`../api/README.md`](../api/README.md) |
| Data inventories (PR11) | [`../data/README.md`](../data/README.md) |
| V1 product specs | [`../specs/05-frontend-sayfa-gelistirme-spec.md`](../specs/05-frontend-sayfa-gelistirme-spec.md) |
