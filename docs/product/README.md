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

## PR13 closeout planning

PR13.0-13.7 established the packaging foundation. Closeout is bounded to local proof, remote tenant proof, demo-off route smoke, and fallback hardening before PR14+.

| Document | Purpose |
|----------|---------|
| [13_v1_packaging_signoff_roadmap.md](./13_v1_packaging_signoff_roadmap.md) | PR13.8-13.10 prompts, stop conditions, and final claim boundaries |
| [13_v1_remaining_work_register.md](./13_v1_remaining_work_register.md) | Living checklist for local proof, remote tenant proof, auth personas, route smoke, fallback guard, and PR14 handoff |

## PR13.8 Local Supabase packaging + mandatory auth proof

PR13.8 shifts the next gate to **local Supabase first**. Remote Puls Teknik A.S. tenant work waits until the local DB proof and mandatory auth/JWT smoke pass with real local auth UUIDs.

| Document / artifact | Purpose |
|---------------------|---------|
| [13_local_supabase_packaging_auth_proof.md](./13_local_supabase_packaging_auth_proof.md) | Local proof runbook, mandatory auth rules, stop conditions |
| [13_local_supabase_packaging_auth_proof_results.md](./13_local_supabase_packaging_auth_proof_results.md) | Sanitized local proof result template |
| [`scripts/run-13-local-supabase-auth-proof.sh`](../../scripts/run-13-local-supabase-auth-proof.sh) | Runs SQL `00-09` plus mandatory `05`/`06` auth smoke |
| [`scripts/verify-13-local-supabase-auth-proof.sh`](../../scripts/verify-13-local-supabase-auth-proof.sh) | PR13.8 local proof verify gate |

## PR13.9 Remote Puls Teknik tenant proof

PR13.9 moves from local proof to the remote development Supabase project. It keeps the PR13.4 CSV/manifest baseline unchanged, protects existing remote tenants, and labels the fixed PR13 proof tenant as **Puls Teknik A.S.** through a SQL posture overlay.

| Document / artifact | Purpose |
|---------------------|---------|
| [13_remote_puls_teknik_tenant_proof.md](./13_remote_puls_teknik_tenant_proof.md) | Remote proof runbook, tenant posture, auth requirements, stop conditions |
| [13_remote_puls_teknik_tenant_proof_results.md](./13_remote_puls_teknik_tenant_proof_results.md) | Sanitized remote inspect/proof results |
| [`supabase/seed/puls-sanayi-v1/sql/10_apply_puls_teknik_remote_posture.sql`](../../supabase/seed/puls-sanayi-v1/sql/10_apply_puls_teknik_remote_posture.sql) | Labels the fixed proof tenant as Puls Teknik A.S. without CSV/manifest drift |
| [`scripts/run-13-remote-puls-teknik-proof.sh`](../../scripts/run-13-remote-puls-teknik-proof.sh) | Runs remote SQL `00-10`, `02-04`, `07-09`, and mandatory `05`/`06` auth smoke |
| [`scripts/verify-13-remote-puls-teknik-proof.sh`](../../scripts/verify-13-remote-puls-teknik-proof.sh) | PR13.9 remote proof verify gate |

## PR13.10 Demo-off route smoke + fallback closeout

PR13.10 closes the PR13 packaging track by walking all 20 V1 routes with **`VITE_PULS_DEMO_MODE=false`**, recording honest route readiness, and guarding against new product-path demo fallback drift.

| Document / artifact | Purpose |
|---------------------|---------|
| [13_v1_screen_readiness_truth_table.md](./13_v1_screen_readiness_truth_table.md) | Route-by-route source, DB model, readiness, and accepted gap table |
| [13_v1_packaging_closeout.md](./13_v1_packaging_closeout.md) | Final PR13 claims, non-claims, and PR14 handoff |
| [`src/lib/persona.ts`](../../src/lib/persona.ts) + [`src/components/auth/SetupRouteGuard.tsx`](../../src/components/auth/SetupRouteGuard.tsx) | Small smoke-found blocker fixes: `puls_core` auth persona resolution and setup deep-link guard timing |
| [`scripts/check-13-demo-fallback-regression.sh`](../../scripts/check-13-demo-fallback-regression.sh) | Fails new unclassified product-path demo fallback additions |
| [`scripts/verify-13-demo-off-route-smoke-closeout.sh`](../../scripts/verify-13-demo-off-route-smoke-closeout.sh) | PR13.10 route smoke closeout verify gate |

## PR14.1 Connector preflight readiness

PR14.1 hardens `/erp` as a provider-agnostic connector preflight surface. Canias remains the seeded first provider, but the product abstraction is canonical PULS data, unified namespaces, field mapping, and identity reconciliation.

| Document / artifact | Purpose |
|---------------------|---------|
| [14_connector_preflight_readiness.md](./14_connector_preflight_readiness.md) | Provider-independent connector readiness claim, inspect-first summary, and acceptance |
| [`src/lib/data/setup/erp.ts`](../../src/lib/data/setup/erp.ts) | Product-owned connector overview adapter and demo wrapper |
| [`src/routes/_app/erp.tsx`](../../src/routes/_app/erp.tsx) | Connector preflight UI with mapping, namespace, transfer posture, and guardrails |
| [`scripts/verify-14-connector-preflight-readiness.sh`](../../scripts/verify-14-connector-preflight-readiness.sh) | PR14.1 verify gate |

## PR14.2 ERP connector onboarding empty state

PR14.2 adds the missing first `/erp` state: a new customer tenant can have no connector configured yet, and that is treated as real product posture rather than demo fallback.

| Document / artifact | Purpose |
|---------------------|---------|
| [14_erp_connector_onboarding_empty_state.md](./14_erp_connector_onboarding_empty_state.md) | no-connector state machine, provider options, and acceptance criteria |
| [`src/lib/data/setup/erp.ts`](../../src/lib/data/setup/erp.ts) | Distinguishes `no_tenant`, `no_connector`, and `connector_selected` |
| [`src/routes/_app/erp.tsx`](../../src/routes/_app/erp.tsx) | Shows onboarding empty state before connector metadata exists |
| [`scripts/verify-14-erp-connector-empty-state.sh`](../../scripts/verify-14-erp-connector-empty-state.sh) | PR14.2 verify gate |

## PR14.3 Connector setup workbench

PR14.3 upgrades `/erp` into a provider-agnostic setup workbench: provider selection, canonical mapping, namespace, preflight, and runtime boundary are visible as separate steps without enabling connector runtime.

| Document / artifact | Purpose |
|---------------------|---------|
| [14_connector_setup_workbench.md](./14_connector_setup_workbench.md) | Setup workbench UX model, provider preview, and acceptance criteria |
| [`src/lib/data/setup/erp.ts`](../../src/lib/data/setup/erp.ts) | Adds product-owned setup steps and provider preview requirements |
| [`src/routes/_app/erp.tsx`](../../src/routes/_app/erp.tsx) | Shows the setup stepper and selectable provider preview state |
| [`scripts/verify-14-connector-setup-workbench.sh`](../../scripts/verify-14-connector-setup-workbench.sh) | PR14.3 verify gate |

## PR14.4 Tenant rollout readiness

PR14.4 records the two tenant postures needed before remote rollout: Puls Teknik A.S. for seeded connector metadata and PULS Connector Lab for no-connector onboarding. It keeps auth/persona proof explicit without adding runtime connector behavior.

| Document / artifact | Purpose |
|---------------------|---------|
| [14_tenant_rollout_readiness.md](./14_tenant_rollout_readiness.md) | Tenant posture matrix, auth boundary, rollout order, and `/dashboard` + `/erp` smoke expectations |
| [`scripts/verify-14-tenant-rollout-readiness.sh`](../../scripts/verify-14-tenant-rollout-readiness.sh) | PR14.4 verify gate |

## PR14.5 Remote tenant rollout smoke results

PR14.5 records the live remote UI smoke for the two PR14 tenant postures: PULS Connector Lab as no-connector onboarding and Puls Teknik as seeded inactive connector metadata.

| Document / artifact | Purpose |
|---------------------|---------|
| [14_remote_tenant_rollout_smoke_results.md](./14_remote_tenant_rollout_smoke_results.md) | Sanitized live remote UI smoke results for `/dashboard` and `/erp` |
| [`scripts/verify-14-remote-tenant-rollout-smoke-results.sh`](../../scripts/verify-14-remote-tenant-rollout-smoke-results.sh) | PR14.5 verify gate |

## PR14.6 Authenticated e2e gate

PR14.6 enables live login coverage for authenticated route stabilization before any connector setup persistence work. It keeps connector runtime closed while allowing CI to run authenticated Playwright against the live Vercel deployment when repository secrets are configured.

| Document / artifact | Purpose |
|---------------------|---------|
| [14_authenticated_e2e_gate.md](./14_authenticated_e2e_gate.md) | Authenticated e2e modes, CI secret boundary, and acceptance criteria |
| [`e2e/ui-stabilization.spec.ts`](../../e2e/ui-stabilization.spec.ts) | Uses `E2E_REQUIRE_AUTH=true` to fail authenticated specs instead of skipping |
| [`playwright.config.ts`](../../playwright.config.ts) | Supports external `E2E_BASE_URL` without starting the local dev server |
| [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) | Adds live authenticated e2e job when secrets are present |
| [`scripts/verify-14-authenticated-e2e-gate.sh`](../../scripts/verify-14-authenticated-e2e-gate.sh) | PR14.6 verify gate |

## PR14.7 Role + tenant empty-state gate

PR14.7 expands authenticated e2e into a role and tenant posture matrix. It treats PULS Connector Lab as the first-run empty-state tenant, keeps Puls Teknik as the seeded operational tenant, and makes dashboard/ERP empty-state behavior part of the product contract before connector setup persistence.

| Document / artifact | Purpose |
|---------------------|---------|
| [14_role_tenant_empty_state_matrix.md](./14_role_tenant_empty_state_matrix.md) | Role matrix, tenant posture contract, and empty-state acceptance criteria |
| [`e2e/role-tenant-matrix.spec.ts`](../../e2e/role-tenant-matrix.spec.ts) | Live role + tenant e2e coverage for seeded and empty tenant behavior |
| [`src/routes/_app/dashboard.tsx`](../../src/routes/_app/dashboard.tsx) | First-run dashboard empty-state callout and setup actions |
| [`src/routes/_app/erp.tsx`](../../src/routes/_app/erp.tsx) | No-connector setup wizard posture |
| [`scripts/verify-14-role-tenant-empty-state-gate.sh`](../../scripts/verify-14-role-tenant-empty-state-gate.sh) | PR14.7 verify gate |

## Related packs

| Pack | Entry point |
|------|-------------|
| API contract (PR12) | [`../api/README.md`](../api/README.md) |
| Data inventories (PR11) | [`../data/README.md`](../data/README.md) |
| V1 product specs | [`../specs/05-frontend-sayfa-gelistirme-spec.md`](../specs/05-frontend-sayfa-gelistirme-spec.md) |
