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

## PR13.5 bootstrap proof pack

PR13.5 **adds scenario/proof SQL on top of PR13.4 baseline** without changing CSV/manifest content. Defers embedded demo removal to later PRs. **No** app code or migrations.

| Document / artifact | Purpose |
|---------------------|---------|
| [13_seed_bootstrap_proof_runbook.md](./13_seed_bootstrap_proof_runbook.md) | Load order, two-layer proof, auth template, inspect-first UUIDs |
| [13_route_packaging_proof_matrix.md](./13_route_packaging_proof_matrix.md) | 20-route packaging proof with `VITE_PULS_DEMO_MODE=false` |
| [`supabase/seed/puls-sanayi-v1/sql/03_*` … `07_*`](../supabase/seed/puls-sanayi-v1/sql/) | Scenario generation, auth link template, JWT smoke, packaging validation |

Verify: [`../../scripts/verify-13-seed-bootstrap-proof.sh`](../../scripts/verify-13-seed-bootstrap-proof.sh)

## PR13.6 AI Coach DB context readiness

PR13.6 **adds DB-backed AI Coach context readiness** for `/ai-koc` on top of PR13.5A seed proof. Teaser posture remains — no live chat, no LLM runtime. **No** migrations or seed CSV/manifest changes.

| Document / artifact | Purpose |
|---------------------|---------|
| [13_ai_coach_db_context_readiness.md](./13_ai_coach_db_context_readiness.md) | Product vision, inspect-first table, guardrails, UX posture |
| [`src/lib/data/ai-coach/`](../src/lib/data/ai-coach/) | Context readiness adapter (`overview.ts`, `context-readiness.ts`, `types.ts`) |
| [`src/routes/_app/ai-koc.tsx`](../src/routes/_app/ai-koc.tsx) | Context readiness + guardrails UI |
| [`supabase/seed/puls-sanayi-v1/sql/08_validate_ai_context_readiness.sql`](../supabase/seed/puls-sanayi-v1/sql/08_validate_ai_context_readiness.sql) | Optional read-only AI context validation |
| [`scripts/verify-13-ai-coach-db-context-readiness.sh`](../../scripts/verify-13-ai-coach-db-context-readiness.sh) | PR13.6 verify gate |

Verify: [`../../scripts/verify-13-ai-coach-db-context-readiness.sh`](../../scripts/verify-13-ai-coach-db-context-readiness.sh)

## PR13.7 Canias + AI connector boundary readiness

PR13.7 **defines Canias-first connector discovery and AI Coach action boundaries** on top of PR13.6 DB context readiness. No runtime connector, no LLM/live chat, no app source changes, no migrations, no seed CSV/manifest changes, no credentials.

| Document / artifact | Purpose |
|---------------------|---------|
| [13_canias_connector_discovery.md](./13_canias_connector_discovery.md) | Canias-first discovery pack, inspect-first table, SoT rules, handoff |
| [13_canias_field_mapping_matrix.json](./13_canias_field_mapping_matrix.json) | 13 data classes including `source_identity_mappings` |
| [13_ai_coach_action_boundary.md](./13_ai_coach_action_boundary.md) | Allowed explain/draft vs forbidden mutations/sync/ERP writes |
| [13_canias_ai_connector_readiness_matrix.md](./13_canias_ai_connector_readiness_matrix.md) | Route touchpoint matrix |
| [`services/erp-connector/README.md`](../../services/erp-connector/README.md) | Health-only skeleton posture |
| [`services/llm-gateway/README.md`](../../services/llm-gateway/README.md) | Future LLM boundary hint |
| [`supabase/seed/puls-sanayi-v1/sql/09_validate_canias_connector_readiness.sql`](../supabase/seed/puls-sanayi-v1/sql/09_validate_canias_connector_readiness.sql) | Read-only Canias metadata validation |
| [`scripts/verify-13-canias-ai-connector-boundary.sh`](../../scripts/verify-13-canias-ai-connector-boundary.sh) | PR13.7 verify gate |

Verify: [`../../scripts/verify-13-canias-ai-connector-boundary.sh`](../../scripts/verify-13-canias-ai-connector-boundary.sh)

## Related packs

| Pack | Entry point |
|------|-------------|
| API contract (PR12) | [`../api/README.md`](../api/README.md) |
| Data inventories (PR11) | [`../data/README.md`](../data/README.md) |
| V1 product specs | [`../specs/05-frontend-sayfa-gelistirme-spec.md`](../specs/05-frontend-sayfa-gelistirme-spec.md) |
