# PULS Product Packaging (PR13)

V1 product packaging strategy and inventory documents.

## PR13.0 strategy pack

| Document                                                                             | Purpose                                                 |
| ------------------------------------------------------------------------------------ | ------------------------------------------------------- |
| [13_v1_product_packaging_strategy.md](./13_v1_product_packaging_strategy.md)         | Scope lock, principles, PR13 roadmap, non-goals         |
| [13_v1_feature_traceability_matrix.md](./13_v1_feature_traceability_matrix.md)       | V1 features → routes, backends, demo, AI, honest status |
| [13_demo_data_packaging_principles.md](./13_demo_data_packaging_principles.md)       | DB-backed demo tenant; embedded TS retirement           |
| [13_ai_coach_process_touchpoints.md](./13_ai_coach_process_touchpoints.md)           | AI Coach value layer, guardrails, touchpoints           |
| [13_canias_first_integration_boundary.md](./13_canias_first_integration_boundary.md) | Canias-first ERP boundary, MVP constraints              |

Verify: [`../../scripts/verify-13-v1-product-packaging.sh`](../../scripts/verify-13-v1-product-packaging.sh)

## PR13.1 inventory pack

| Document                                                                     | Purpose                                           |
| ---------------------------------------------------------------------------- | ------------------------------------------------- |
| [13_feature_db_coverage_inventory.md](./13_feature_db_coverage_inventory.md) | Feature → route → adapter → DB object matrix      |
| [13_db_table_completeness_classes.md](./13_db_table_completeness_classes.md) | DB object completeness classes for demo packaging |
| [13_embedded_demo_dependency_map.md](./13_embedded_demo_dependency_map.md)   | `fetchDemo*` / embedded TS dependency inventory   |
| [13_ai_context_data_requirements.md](./13_ai_context_data_requirements.md)   | AI Coach DB context requirements and gaps         |

Verify: [`../../scripts/verify-13-feature-db-coverage.sh`](../../scripts/verify-13-feature-db-coverage.sh)

## PR13.2 retirement pack

PR13.2 **extends PR13.1** into an actionable retirement plan; it **does not replace** the dependency map or feature DB coverage docs.

| Document                                                                         | Purpose                                               |
| -------------------------------------------------------------------------------- | ----------------------------------------------------- |
| [13_embedded_demo_retirement_plan.md](./13_embedded_demo_retirement_plan.md)     | P0/P1/P2 work packages and PR13.3–13.5 mapping        |
| [13_packaging_proof_demo_guardrails.md](./13_packaging_proof_demo_guardrails.md) | Packaging proof vs dev fallback; `source: demo` rules |

Verify: [`../../scripts/verify-13-embedded-demo-retirement.sh`](../../scripts/verify-13-embedded-demo-retirement.sh)

## PR13.3 seed spec pack

PR13.3 **extends PR13.1 and PR13.2** into a DB-backed synthetic company specification; it **does not replace** the dependency map, feature inventory, or retirement plan.

| Document                                                                     | Purpose                                                                 |
| ---------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| [13_synthetic_company_seed_spec.md](./13_synthetic_company_seed_spec.md)     | 120-employee **Puls Sanayi A.Ş.** org model, personas, source ownership |
| [13_seed_table_coverage_manifest.md](./13_seed_table_coverage_manifest.md)   | Product-facing `puls_*` object coverage, row targets, proof routes      |
| [13_seed_scenario_generation_spec.md](./13_seed_scenario_generation_spec.md) | Workflow/performance/contract/dashboard scenario requirements           |
| [13_seed_ai_context_manifest.md](./13_seed_ai_context_manifest.md)           | Seed data → AI Coach touchpoints and guardrails                         |

Verify: [`../../scripts/verify-13-synthetic-company-seed-spec.sh`](../../scripts/verify-13-synthetic-company-seed-spec.sh)

## PR13.3A alignment pack

Bridge PR before PR13.4 — aligns [`Puls_Veri_Sozlugu_v1.0.xlsx`](../V1%20Dokümanlar/Puls_Veri_Sozlugu_v1.0.xlsx) with Supabase/Postgres + adapter architecture and PR13.3 seed spec. **Does not replace** PR13.3 docs; **no** CSV/SQL or `supabase/seed/**` in this PR.

| Document                                                                               | Purpose                                                         |
| -------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| [13_data_dictionary_seed_alignment.md](./13_data_dictionary_seed_alignment.md)         | Domain alignment matrix, route aliases, seed coverage decisions |
| [13_data_dictionary_architecture_notes.md](./13_data_dictionary_architecture_notes.md) | Microservice labels vs modular Supabase MVP architecture        |
| [13_data_dictionary_seed_crosswalk.json](./13_data_dictionary_seed_crosswalk.json)     | Machine-readable domain crosswalk for PR13.4 generator          |

Verify: [`../../scripts/verify-13-data-dictionary-alignment.sh`](../../scripts/verify-13-data-dictionary-alignment.sh)

## PR13.4 baseline seed pack

PR13.4 **implements PR13.3 spec + PR13.3A crosswalk** as importable CSV/SQL artifacts for **Puls Sanayi A.Ş.** (120 employees). Defers scenario/bootstrap proof to PR13.5. **No** app code or migrations.

| Artifact                                                                              | Purpose                                                                 |
| ------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| [`supabase/seed/puls-sanayi-v1/`](../supabase/seed/puls-sanayi-v1/)                   | 22 baseline CSVs, manifest, FK-safe load order, reset/load/validate SQL |
| [`supabase/seed/puls-sanayi-v1/README.md`](../supabase/seed/puls-sanayi-v1/README.md) | Runbook: psql-local `\copy`, packaging proof guardrails, PR13.5 handoff |

Verify: [`../../scripts/verify-13-synthetic-seed-artifacts.sh`](../../scripts/verify-13-synthetic-seed-artifacts.sh)

## PR13.5 bootstrap proof pack

PR13.5 **adds scenario/proof SQL on top of PR13.4 baseline** without changing CSV/manifest content. Defers embedded demo removal to later PRs. **No** app code or migrations.

| Document / artifact                                                                      | Purpose                                                                  |
| ---------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| [13_seed_bootstrap_proof_runbook.md](./13_seed_bootstrap_proof_runbook.md)               | Load order, two-layer proof, auth template, inspect-first UUIDs          |
| [13_route_packaging_proof_matrix.md](./13_route_packaging_proof_matrix.md)               | 20-route packaging proof with `VITE_PULS_DEMO_MODE=false`                |
| [`supabase/seed/puls-sanayi-v1/sql/03_*` … `07_*`](../supabase/seed/puls-sanayi-v1/sql/) | Scenario generation, auth link template, JWT smoke, packaging validation |

Verify: [`../../scripts/verify-13-seed-bootstrap-proof.sh`](../../scripts/verify-13-seed-bootstrap-proof.sh)

## PR13.6 AI Coach DB context readiness

PR13.6 **adds DB-backed AI Coach context readiness** for `/ai-koc` on top of PR13.5A seed proof. Teaser posture remains — no live chat, no LLM runtime. **No** migrations or seed CSV/manifest changes.

| Document / artifact                                                                                                                                 | Purpose                                                                       |
| --------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| [13_ai_coach_db_context_readiness.md](./13_ai_coach_db_context_readiness.md)                                                                        | Product vision, inspect-first table, guardrails, UX posture                   |
| [`src/lib/data/ai-coach/`](../src/lib/data/ai-coach/)                                                                                               | Context readiness adapter (`overview.ts`, `context-readiness.ts`, `types.ts`) |
| [`src/routes/_app/ai-koc.tsx`](../src/routes/_app/ai-koc.tsx)                                                                                       | Context readiness + guardrails UI                                             |
| [`supabase/seed/puls-sanayi-v1/sql/08_validate_ai_context_readiness.sql`](../supabase/seed/puls-sanayi-v1/sql/08_validate_ai_context_readiness.sql) | Optional read-only AI context validation                                      |
| [`scripts/verify-13-ai-coach-db-context-readiness.sh`](../../scripts/verify-13-ai-coach-db-context-readiness.sh)                                    | PR13.6 verify gate                                                            |

Verify: [`../../scripts/verify-13-ai-coach-db-context-readiness.sh`](../../scripts/verify-13-ai-coach-db-context-readiness.sh)

## PR13.7 Canias + AI connector boundary readiness

PR13.7 **defines Canias-first connector discovery and AI Coach action boundaries** on top of PR13.6 DB context readiness. No runtime connector, no LLM/live chat, no app source changes, no migrations, no seed CSV/manifest changes, no credentials.

| Document / artifact                                                                                                                                             | Purpose                                                              |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| [13_canias_connector_discovery.md](./13_canias_connector_discovery.md)                                                                                          | Canias-first discovery pack, inspect-first table, SoT rules, handoff |
| [13_canias_field_mapping_matrix.json](./13_canias_field_mapping_matrix.json)                                                                                    | 13 data classes including `source_identity_mappings`                 |
| [13_ai_coach_action_boundary.md](./13_ai_coach_action_boundary.md)                                                                                              | Allowed explain/draft vs forbidden mutations/sync/ERP writes         |
| [13_canias_ai_connector_readiness_matrix.md](./13_canias_ai_connector_readiness_matrix.md)                                                                      | Route touchpoint matrix                                              |
| [`services/erp-connector/README.md`](../../services/erp-connector/README.md)                                                                                    | Health-only skeleton posture                                         |
| [`services/llm-gateway/README.md`](../../services/llm-gateway/README.md)                                                                                        | Future LLM boundary hint                                             |
| [`supabase/seed/puls-sanayi-v1/sql/09_validate_canias_connector_readiness.sql`](../supabase/seed/puls-sanayi-v1/sql/09_validate_canias_connector_readiness.sql) | Read-only Canias metadata validation                                 |
| [`scripts/verify-13-canias-ai-connector-boundary.sh`](../../scripts/verify-13-canias-ai-connector-boundary.sh)                                                  | PR13.7 verify gate                                                   |

Verify: [`../../scripts/verify-13-canias-ai-connector-boundary.sh`](../../scripts/verify-13-canias-ai-connector-boundary.sh)

## PR13 closeout planning

PR13.0-13.7 established the packaging foundation. Closeout is bounded to local proof, remote tenant proof, demo-off route smoke, and fallback hardening before PR14+.

| Document                                                                   | Purpose                                                                                                             |
| -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| [13_v1_packaging_signoff_roadmap.md](./13_v1_packaging_signoff_roadmap.md) | PR13.8-13.10 prompts, stop conditions, and final claim boundaries                                                   |
| [13_v1_remaining_work_register.md](./13_v1_remaining_work_register.md)     | Living checklist for local proof, remote tenant proof, auth personas, route smoke, fallback guard, and PR14 handoff |

## PR13.8 Local Supabase packaging + mandatory auth proof

PR13.8 shifts the next gate to **local Supabase first**. Remote Puls Teknik A.S. tenant work waits until the local DB proof and mandatory auth/JWT smoke pass with real local auth UUIDs.

| Document / artifact                                                                                      | Purpose                                                    |
| -------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| [13_local_supabase_packaging_auth_proof.md](./13_local_supabase_packaging_auth_proof.md)                 | Local proof runbook, mandatory auth rules, stop conditions |
| [13_local_supabase_packaging_auth_proof_results.md](./13_local_supabase_packaging_auth_proof_results.md) | Sanitized local proof result template                      |
| [`scripts/run-13-local-supabase-auth-proof.sh`](../../scripts/run-13-local-supabase-auth-proof.sh)       | Runs SQL `00-09` plus mandatory `05`/`06` auth smoke       |
| [`scripts/verify-13-local-supabase-auth-proof.sh`](../../scripts/verify-13-local-supabase-auth-proof.sh) | PR13.8 local proof verify gate                             |

## PR13.9 Remote Puls Teknik tenant proof

PR13.9 moves from local proof to the remote development Supabase project. It keeps the PR13.4 CSV/manifest baseline unchanged, protects existing remote tenants, and labels the fixed PR13 proof tenant as **Puls Teknik A.S.** through a SQL posture overlay.

| Document / artifact                                                                                                                                          | Purpose                                                                       |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------- |
| [13_remote_puls_teknik_tenant_proof.md](./13_remote_puls_teknik_tenant_proof.md)                                                                             | Remote proof runbook, tenant posture, auth requirements, stop conditions      |
| [13_remote_puls_teknik_tenant_proof_results.md](./13_remote_puls_teknik_tenant_proof_results.md)                                                             | Sanitized remote inspect/proof results                                        |
| [`supabase/seed/puls-sanayi-v1/sql/10_apply_puls_teknik_remote_posture.sql`](../../supabase/seed/puls-sanayi-v1/sql/10_apply_puls_teknik_remote_posture.sql) | Labels the fixed proof tenant as Puls Teknik A.S. without CSV/manifest drift  |
| [`scripts/run-13-remote-puls-teknik-proof.sh`](../../scripts/run-13-remote-puls-teknik-proof.sh)                                                             | Runs remote SQL `00-10`, `02-04`, `07-09`, and mandatory `05`/`06` auth smoke |
| [`scripts/verify-13-remote-puls-teknik-proof.sh`](../../scripts/verify-13-remote-puls-teknik-proof.sh)                                                       | PR13.9 remote proof verify gate                                               |

## PR13.10 Demo-off route smoke + fallback closeout

PR13.10 closes the PR13 packaging track by walking all 20 V1 routes with **`VITE_PULS_DEMO_MODE=false`**, recording honest route readiness, and guarding against new product-path demo fallback drift.

| Document / artifact                                                                                                                           | Purpose                                                                                               |
| --------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| [13_v1_screen_readiness_truth_table.md](./13_v1_screen_readiness_truth_table.md)                                                              | Route-by-route source, DB model, readiness, and accepted gap table                                    |
| [13_v1_packaging_closeout.md](./13_v1_packaging_closeout.md)                                                                                  | Final PR13 claims, non-claims, and PR14 handoff                                                       |
| [`src/lib/persona.ts`](../../src/lib/persona.ts) + [`src/components/auth/SetupRouteGuard.tsx`](../../src/components/auth/SetupRouteGuard.tsx) | Small smoke-found blocker fixes: `puls_core` auth persona resolution and setup deep-link guard timing |
| [`scripts/check-13-demo-fallback-regression.sh`](../../scripts/check-13-demo-fallback-regression.sh)                                          | Fails new unclassified product-path demo fallback additions                                           |
| [`scripts/verify-13-demo-off-route-smoke-closeout.sh`](../../scripts/verify-13-demo-off-route-smoke-closeout.sh)                              | PR13.10 route smoke closeout verify gate                                                              |

## PR14.1 Connector preflight readiness

PR14.1 hardens `/erp` as a provider-agnostic connector preflight surface. Canias remains the seeded first provider, but the product abstraction is canonical PULS data, unified namespaces, field mapping, and identity reconciliation.

| Document / artifact                                                                                              | Purpose                                                                               |
| ---------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| [14_connector_preflight_readiness.md](./14_connector_preflight_readiness.md)                                     | Provider-independent connector readiness claim, inspect-first summary, and acceptance |
| [`src/lib/data/setup/erp.ts`](../../src/lib/data/setup/erp.ts)                                                   | Product-owned connector overview adapter and demo wrapper                             |
| [`src/routes/_app/erp.tsx`](../../src/routes/_app/erp.tsx)                                                       | Connector preflight UI with mapping, namespace, transfer posture, and guardrails      |
| [`scripts/verify-14-connector-preflight-readiness.sh`](../../scripts/verify-14-connector-preflight-readiness.sh) | PR14.1 verify gate                                                                    |

## PR14.2 ERP connector onboarding empty state

PR14.2 adds the missing first `/erp` state: a new customer tenant can have no connector configured yet, and that is treated as real product posture rather than demo fallback.

| Document / artifact                                                                                      | Purpose                                                               |
| -------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| [14_erp_connector_onboarding_empty_state.md](./14_erp_connector_onboarding_empty_state.md)               | no-connector state machine, provider options, and acceptance criteria |
| [`src/lib/data/setup/erp.ts`](../../src/lib/data/setup/erp.ts)                                           | Distinguishes `no_tenant`, `no_connector`, and `connector_selected`   |
| [`src/routes/_app/erp.tsx`](../../src/routes/_app/erp.tsx)                                               | Shows onboarding empty state before connector metadata exists         |
| [`scripts/verify-14-erp-connector-empty-state.sh`](../../scripts/verify-14-erp-connector-empty-state.sh) | PR14.2 verify gate                                                    |

## PR14.3 Connector setup workbench

PR14.3 upgrades `/erp` into a provider-agnostic setup workbench: provider selection, canonical mapping, namespace, preflight, and runtime boundary are visible as separate steps without enabling connector runtime.

| Document / artifact                                                                                      | Purpose                                                             |
| -------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| [14_connector_setup_workbench.md](./14_connector_setup_workbench.md)                                     | Setup workbench UX model, provider preview, and acceptance criteria |
| [`src/lib/data/setup/erp.ts`](../../src/lib/data/setup/erp.ts)                                           | Adds product-owned setup steps and provider preview requirements    |
| [`src/routes/_app/erp.tsx`](../../src/routes/_app/erp.tsx)                                               | Shows the setup stepper and selectable provider preview state       |
| [`scripts/verify-14-connector-setup-workbench.sh`](../../scripts/verify-14-connector-setup-workbench.sh) | PR14.3 verify gate                                                  |

## PR14.4 Tenant rollout readiness

PR14.4 records the two tenant postures needed before remote rollout: Puls Teknik A.S. for seeded connector metadata and PULS Connector Lab for no-connector onboarding. It keeps auth/persona proof explicit without adding runtime connector behavior.

| Document / artifact                                                                                    | Purpose                                                                                           |
| ------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------- |
| [14_tenant_rollout_readiness.md](./14_tenant_rollout_readiness.md)                                     | Tenant posture matrix, auth boundary, rollout order, and `/dashboard` + `/erp` smoke expectations |
| [`scripts/verify-14-tenant-rollout-readiness.sh`](../../scripts/verify-14-tenant-rollout-readiness.sh) | PR14.4 verify gate                                                                                |

## PR14.5 Remote tenant rollout smoke results

PR14.5 records the live remote UI smoke for the two PR14 tenant postures: PULS Connector Lab as no-connector onboarding and Puls Teknik as seeded inactive connector metadata.

| Document / artifact                                                                                                          | Purpose                                                            |
| ---------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| [14_remote_tenant_rollout_smoke_results.md](./14_remote_tenant_rollout_smoke_results.md)                                     | Sanitized live remote UI smoke results for `/dashboard` and `/erp` |
| [`scripts/verify-14-remote-tenant-rollout-smoke-results.sh`](../../scripts/verify-14-remote-tenant-rollout-smoke-results.sh) | PR14.5 verify gate                                                 |

## PR14.6 Authenticated e2e gate

PR14.6 enables live login coverage for authenticated route stabilization before any connector setup persistence work. It keeps connector runtime closed while allowing CI to run authenticated Playwright against the live Vercel deployment when repository secrets are configured.

| Document / artifact                                                                                | Purpose                                                                      |
| -------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| [14_authenticated_e2e_gate.md](./14_authenticated_e2e_gate.md)                                     | Authenticated e2e modes, CI secret boundary, and acceptance criteria         |
| [`e2e/ui-stabilization.spec.ts`](../../e2e/ui-stabilization.spec.ts)                               | Uses `E2E_REQUIRE_AUTH=true` to fail authenticated specs instead of skipping |
| [`playwright.config.ts`](../../playwright.config.ts)                                               | Supports external `E2E_BASE_URL` without starting the local dev server       |
| [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml)                                       | Adds live authenticated e2e job when secrets are present                     |
| [`scripts/verify-14-authenticated-e2e-gate.sh`](../../scripts/verify-14-authenticated-e2e-gate.sh) | PR14.6 verify gate                                                           |

## PR14.7 Role + tenant empty-state gate

PR14.7 expands authenticated e2e into a role and tenant posture matrix. It treats PULS Connector Lab as the first-run empty-state tenant, keeps Puls Teknik as the seeded operational tenant, and makes dashboard/ERP empty-state behavior part of the product contract before connector setup persistence.

| Document / artifact                                                                                            | Purpose                                                                   |
| -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| [14_role_tenant_empty_state_matrix.md](./14_role_tenant_empty_state_matrix.md)                                 | Role matrix, tenant posture contract, and empty-state acceptance criteria |
| [`e2e/role-tenant-matrix.spec.ts`](../../e2e/role-tenant-matrix.spec.ts)                                       | Live role + tenant e2e coverage for seeded and empty tenant behavior      |
| [`src/routes/_app/dashboard.tsx`](../../src/routes/_app/dashboard.tsx)                                         | First-run dashboard empty-state callout and setup actions                 |
| [`src/routes/_app/erp.tsx`](../../src/routes/_app/erp.tsx)                                                     | No-connector setup wizard posture                                         |
| [`scripts/verify-14-role-tenant-empty-state-gate.sh`](../../scripts/verify-14-role-tenant-empty-state-gate.sh) | PR14.7 verify gate                                                        |

## PR14.8-PR14.11 Connector implementation roadmap

This roadmap documents the agreed implementation order after PR14.7: connector setup persistence, observability, mapping discovery, and dry-run preflight. It keeps PULS source-independent while allowing Canias and CSV / Excel to become the first MVP setup paths.

| Document / artifact                                                                | Purpose                                                                             |
| ---------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| [14_connector_implementation_roadmap.md](./14_connector_implementation_roadmap.md) | PR14.8-PR14.11 implementation sequence, product boundaries, and acceptance criteria |

## PR14.8 Connector setup persistence

PR14.8 persists the connector setup selection as tenant-scoped DB state. Canias and CSV / Excel can create setup drafts; Logo and Custom API remain future candidates. Runtime sync, credentials, imports, and ERP writes stay closed.

| Document / artifact                                                                                                                                                            | Purpose                                                                                   |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------- |
| [14_connector_setup_persistence.md](./14_connector_setup_persistence.md)                                                                                                       | Persisted setup lifecycle, role boundary, data model, and rollout proof                   |
| [`supabase/migrations/20260602090000_puls_integration_connector_setup_lifecycle.sql`](../../supabase/migrations/20260602090000_puls_integration_connector_setup_lifecycle.sql) | Adds setup lifecycle columns, tenant key, manager read policies, and admin write boundary |
| [`src/lib/data/setup/erp.ts`](../../src/lib/data/setup/erp.ts)                                                                                                                 | Connector setup persistence adapter and provider setup config                             |
| [`src/routes/_app/erp.tsx`](../../src/routes/_app/erp.tsx)                                                                                                                     | Admin setup action and manager read-only notice                                           |
| [`scripts/verify-14-connector-setup-persistence.sh`](../../scripts/verify-14-connector-setup-persistence.sh)                                                                   | PR14.8 verify gate                                                                        |

## PR14.9 Error observability and Sentry

PR14.9 adds the first production-grade observability boundary for app errors and connector setup failures. Sentry is optional, disabled without `VITE_SENTRY_DSN`, and scrubbed before telemetry is sent. Connector runtime, credentials, mapping discovery, imports, and ERP writes remain closed.

| Document / artifact                                                                                        | Purpose                                                                       |
| ---------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| [14_error_observability_sentry.md](./14_error_observability_sentry.md)                                     | Sentry policy, scrub contract, user-facing error posture, and backend handoff |
| [`src/lib/observability/sentry.ts`](../../src/lib/observability/sentry.ts)                                 | Optional Sentry init, PII scrubber, and app error capture helper              |
| [`src/components/puls/AppErrorFallback.tsx`](../../src/components/puls/AppErrorFallback.tsx)               | Product-safe route/render error fallback                                      |
| [`src/lib/data/setup/erp.ts`](../../src/lib/data/setup/erp.ts)                                             | Connector setup error mapping                                                 |
| [`scripts/verify-14-error-observability-sentry.sh`](../../scripts/verify-14-error-observability-sentry.sh) | PR14.9 verify gate                                                            |

## PR14.9A Sentry source maps and setup check

PR14.9A adds build-time source map upload and a guarded setup-check event. Source maps upload only when `SENTRY_SOURCE_MAPS=true` and Sentry build env is present; setup check requires `VITE_SENTRY_ALLOW_TEST_EVENT=true` plus `?sentry_setup_check=1`.

| Document / artifact                                                                        | Purpose                                                             |
| ------------------------------------------------------------------------------------------ | ------------------------------------------------------------------- |
| [14_sentry_source_maps.md](./14_sentry_source_maps.md)                                     | Source map upload policy, setup-check flow, and acceptance criteria |
| [`vite.config.ts`](../../vite.config.ts)                                                   | Gated Sentry Vite plugin and public `.map` deletion after upload    |
| [`src/lib/observability/sentry.ts`](../../src/lib/observability/sentry.ts)                 | Browser-only setup-check capture guarded by env and query param     |
| [`scripts/verify-14-sentry-source-maps.sh`](../../scripts/verify-14-sentry-source-maps.sh) | PR14.9A verify gate                                                 |

## PR14.10 Mapping discovery

PR14.10 persists the first connector field contract. Canias and CSV / Excel setup drafts can create deterministic mapping rows in `puls_integration.erp_field_mappings`; `/erp` shows canonical data class completeness without import execution, credentials, runtime sync, or ERP writes.

| Document / artifact                                                                      | Purpose                                                                 |
| ---------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| [14_mapping_discovery.md](./14_mapping_discovery.md)                                     | Mapping discovery scope, canonical classes, defaults, and acceptance    |
| [`src/lib/data/setup/erp.ts`](../../src/lib/data/setup/erp.ts)                           | Default mapping contract, canonical class completeness, setup promotion |
| [`src/routes/_app/erp.tsx`](../../src/routes/_app/erp.tsx)                               | Mapping discovery workbench and source-to-PULS field contract           |
| [`scripts/verify-14-mapping-discovery.sh`](../../scripts/verify-14-mapping-discovery.sh) | PR14.10 verify gate                                                     |

## PR14.11 Connector preflight execution

PR14.11 adds the dry-run setup check before runtime connectors exist. `/erp` can evaluate source profile, required mapping, namespace, identity, credential boundary, runtime boundary, and ERP write guardrails without live API calls, imports, sync, credentials, or ERP writes.

| Document / artifact                                                                                              | Purpose                                                             |
| ---------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| [14_connector_preflight_execution.md](./14_connector_preflight_execution.md)                                     | Dry-run preflight scope, checks, result model, and acceptance       |
| [`src/lib/data/setup/erp.ts`](../../src/lib/data/setup/erp.ts)                                                   | Preflight result evaluator and selected-connector overview contract |
| [`src/routes/_app/erp.tsx`](../../src/routes/_app/erp.tsx)                                                       | Admin-run setup check and read-only result panel                    |
| [`scripts/verify-14-connector-preflight-execution.sh`](../../scripts/verify-14-connector-preflight-execution.sh) | PR14.11 verify gate                                                 |

## PR14.12 Source credential boundary

PR14.12 makes credential readiness source-independent. It adds generic auth mode and credential state metadata, keeps `credentials_ref` opaque and server-side, and shows `/erp` credential posture without collecting secrets or enabling runtime connectors.

| Document / artifact                                                                                                                                                              | Purpose                                                               |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| [14_source_credential_boundary.md](./14_source_credential_boundary.md)                                                                                                           | Source-independent credential state model, product rules, and handoff |
| [`supabase/migrations/20260603100000_puls_integration_source_credential_boundary.sql`](../../supabase/migrations/20260603100000_puls_integration_source_credential_boundary.sql) | Adds generic auth mode and credential state fields                    |
| [`src/lib/data/setup/erp.ts`](../../src/lib/data/setup/erp.ts)                                                                                                                   | Safe credential posture adapter; does not select `credentials_ref`    |
| [`src/routes/_app/erp.tsx`](../../src/routes/_app/erp.tsx)                                                                                                                       | Credential boundary status panel without secret inputs                |
| [`scripts/verify-14-source-credential-boundary.sh`](../../scripts/verify-14-source-credential-boundary.sh)                                                                       | PR14.12 verify gate                                                   |

## PR14.12B Connector state consistency findings

PR14.12B closes the dashboard/ERP state mismatch, duplicate provider/domain setup risk, and non-persisted setup check history found after PR14.12 remote validation. It keeps PULS source-independent: Canias is one connector profile, not the connectivity architecture.

| Document / artifact                                                                                                                                                                | Purpose                                                                  |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| [14_connector_state_consistency_findings.md](./14_connector_state_consistency_findings.md)                                                                                         | Findings, state truth rules, and PR14.13 handoff                         |
| [`supabase/migrations/20260603110000_puls_integration_connector_state_consistency.sql`](../../supabase/migrations/20260603110000_puls_integration_connector_state_consistency.sql) | Aligns credential-missing setup status and archives duplicate drafts     |
| [`src/lib/data/setup/erp.ts`](../../src/lib/data/setup/erp.ts)                                                                                                                     | Current connector selection, domain ownership guard, persisted preflight |
| [`src/lib/data/dashboard/overview.ts`](../../src/lib/data/dashboard/overview.ts)                                                                                                   | Dashboard ERP card uses credential-aware connector truth                 |
| [`scripts/verify-14-connector-state-consistency.sh`](../../scripts/verify-14-connector-state-consistency.sh)                                                                       | PR14.12B verify gate                                                     |

## PR14.13 Connector lifecycle capabilities

PR14.13 adds the source-independent connector lifecycle contract to `/erp`: lifecycle stage, source capabilities, and canonical domain ownership are derived from real setup state. No migration, credential capture, runtime connector, sync execution, or ERP writeback is added.

| Document / artifact                                                                                                    | Purpose                                                             |
| ---------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| [14_connector_lifecycle_capabilities.md](./14_connector_lifecycle_capabilities.md)                                     | Lifecycle, capability, and domain ownership acceptance              |
| [`src/lib/data/setup/erp.ts`](../../src/lib/data/setup/erp.ts)                                                         | `lifecycle`, `capabilities`, and `domainOwnership` adapter contract |
| [`src/routes/_app/erp.tsx`](../../src/routes/_app/erp.tsx)                                                             | Responsive lifecycle/capability/domain ownership workbench UI       |
| [`scripts/verify-14-connector-lifecycle-capabilities.sh`](../../scripts/verify-14-connector-lifecycle-capabilities.sh) | PR14.13 verify gate                                                 |

## PR14.14 Connector credential handoff

PR14.14 turns source-independent credential readiness into a safe handoff process. Admins can request secure reference preparation after mapping and identity readiness are clear. The product still does not collect, read, or display secret values, and no runtime connector execution is enabled.

| Document / artifact                                                                                                                                                                  | Purpose                                                          |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------- |
| [14_connector_credential_handoff.md](./14_connector_credential_handoff.md)                                                                                                           | Credential handoff state model, product boundary, and acceptance |
| [`supabase/migrations/20260603120000_puls_integration_connector_credential_handoff.sql`](../../supabase/migrations/20260603120000_puls_integration_connector_credential_handoff.sql) | Adds safe credential handoff state and timestamps                |
| [`src/lib/data/setup/erp.ts`](../../src/lib/data/setup/erp.ts)                                                                                                                       | Source-independent handoff adapter and admin request action      |
| [`src/routes/_app/erp.tsx`](../../src/routes/_app/erp.tsx)                                                                                                                           | Secure reference handoff sheet without secret inputs             |
| [`scripts/verify-14-connector-credential-handoff.sh`](../../scripts/verify-14-connector-credential-handoff.sh)                                                                       | PR14.14 verify gate                                              |

## PR14.15 Connector activity timeline

PR14.15 turns connector setup history into a safe activity timeline. `/erp` now shows setup start, field contract, dry-run preflight, and credential handoff events with sanitized details and next actions. Runtime sync, credential capture, imports, exports, and ERP writeback remain closed.

| Document / artifact                                                                                                                                                                | Purpose                                                                |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| [14_connector_activity_timeline.md](./14_connector_activity_timeline.md)                                                                                                           | Activity timeline state model, safe error detail rules, and acceptance |
| [`supabase/migrations/20260603130000_puls_integration_connector_activity_timeline.sql`](../../supabase/migrations/20260603130000_puls_integration_connector_activity_timeline.sql) | Adds metadata-only activity fields to connector setup history          |
| [`src/lib/data/setup/erp.ts`](../../src/lib/data/setup/erp.ts)                                                                                                                     | Builds `activityTimeline` and writes safe setup history records        |
| [`src/routes/_app/erp.tsx`](../../src/routes/_app/erp.tsx)                                                                                                                         | Renders connector activity timeline with safe details and next actions |
| [`scripts/verify-14-connector-activity-timeline.sh`](../../scripts/verify-14-connector-activity-timeline.sh)                                                                       | PR14.15 verify gate                                                    |

## PR14.16 Connector import preview dry-run

PR14.16 adds a safe import preview boundary for prepared dry-run connector batches. `/erp` can validate and classify create/update/skip outcomes without live connector runtime, credential capture, import apply, sync execution, or ERP writeback.

| Document / artifact                                                                                                                                                          | Purpose                                                                                            |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| [14_connector_import_preview_dry_run.md](./14_connector_import_preview_dry_run.md)                                                                                           | Import preview dry-run product boundary, proof SQL, and acceptance                                 |
| [`supabase/migrations/20260603140000_puls_integration_connector_import_preview.sql`](../../supabase/migrations/20260603140000_puls_integration_connector_import_preview.sql) | Adds safe preview metadata and product-safe preview record read RPC                                |
| [`supabase/seed/puls-sanayi-v1/sql/12_apply_connector_import_preview_proof.sql`](../../supabase/seed/puls-sanayi-v1/sql/12_apply_connector_import_preview_proof.sql)         | Creates a pending dry-run proof batch without validating, previewing, or applying it automatically |
| [`src/lib/data/setup/erp.ts`](../../src/lib/data/setup/erp.ts)                                                                                                               | Builds `importPreview` and runs validate + preview without apply                                   |
| [`src/routes/_app/erp.tsx`](../../src/routes/_app/erp.tsx)                                                                                                                   | Renders safe import preview state and row outcomes                                                 |
| [`scripts/verify-14-connector-import-preview.sh`](../../scripts/verify-14-connector-import-preview.sh)                                                                       | PR14.16 verify gate                                                                                |

## PR14.17 Connector apply readiness boundary

PR14.17 adds the human review boundary after dry-run preview. `/erp` can show whether preview results are ready for human review and record a safe audit signal, while canonical apply, runtime connector execution, credential capture, and ERP writeback remain closed.

| Document / artifact                                                                                      | Purpose                                                                     |
| -------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| [14_connector_apply_readiness_boundary.md](./14_connector_apply_readiness_boundary.md)                   | Apply readiness state model, human review boundary, and acceptance criteria |
| [`src/lib/data/setup/erp.ts`](../../src/lib/data/setup/erp.ts)                                           | Builds `applyReadiness` and records `import_apply_review` audit metadata    |
| [`src/routes/_app/erp.tsx`](../../src/routes/_app/erp.tsx)                                               | Renders apply readiness, blockers, checks, and human review request action  |
| [`scripts/verify-14-connector-apply-readiness.sh`](../../scripts/verify-14-connector-apply-readiness.sh) | PR14.17 verify gate                                                         |

## PR14.18 Controlled apply design

PR14.18 makes the future apply path visible without making it executable. `/erp` now shows source-independent apply gates for approval, idempotency, batch locking, rollback, audit, notification, runtime credentials, and execution boundary while canonical apply remains closed.

| Document / artifact                                                                                  | Purpose                                                                   |
| ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| [14_connector_controlled_apply_design.md](./14_connector_controlled_apply_design.md)                 | Controlled apply gate model, UX contract, and acceptance criteria         |
| [`src/lib/data/setup/erp.ts`](../../src/lib/data/setup/erp.ts)                                       | Builds `controlledApplyPlan` from preview, review, and credential posture |
| [`src/routes/_app/erp.tsx`](../../src/routes/_app/erp.tsx)                                           | Renders controlled apply gates with execution closed                      |
| [`scripts/verify-14-controlled-apply-design.sh`](../../scripts/verify-14-controlled-apply-design.sh) | PR14.18 verify gate                                                       |

## PR14.19 Connector apply approval policy

PR14.19 makes the MVP approval authority explicit before any canonical apply runtime exists. Admin approval is represented as source-independent product policy and recorded as safe audit metadata while apply execution, runtime connector calls, credential readback, and ERP/source writes remain closed.

| Document / artifact                                                                                                  | Purpose                                                                     |
| -------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| [14_connector_apply_approval_policy.md](./14_connector_apply_approval_policy.md)                                     | Admin-only approval policy, audit contract, and acceptance criteria         |
| [`src/lib/data/setup/erp.ts`](../../src/lib/data/setup/erp.ts)                                                       | Builds `applyApprovalPolicy` and records safe admin approval audit metadata |
| [`src/routes/_app/erp.tsx`](../../src/routes/_app/erp.tsx)                                                           | Renders approval policy inside controlled apply without opening execution   |
| [`scripts/verify-14-connector-apply-approval-policy.sh`](../../scripts/verify-14-connector-apply-approval-policy.sh) | PR14.19 verify gate                                                         |

## PR14.20 Connector apply execution contract

PR14.20 makes the future apply execution contract explicit while keeping canonical apply, runtime connector calls, credential readback, and ERP/source writes closed. Admin approval can make the contract ready, but execution remains disabled until batch lock, rollback, notification, and runtime job boundaries are implemented.

| Document / artifact                                                                                                        | Purpose                                                                              |
| -------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| [14_connector_apply_execution_contract.md](./14_connector_apply_execution_contract.md)                                     | Closed execution contract, control model, UX debt, and acceptance criteria           |
| [`src/lib/data/setup/erp.ts`](../../src/lib/data/setup/erp.ts)                                                             | Builds `applyExecutionContract` from preview, approval, and controlled apply posture |
| [`src/routes/_app/erp.tsx`](../../src/routes/_app/erp.tsx)                                                                 | Renders the closed execution contract without adding an apply action                 |
| [`scripts/verify-14-connector-apply-execution-contract.sh`](../../scripts/verify-14-connector-apply-execution-contract.sh) | PR14.20 verify gate                                                                  |

## PR14.21 ERP workbench information architecture

PR14.21 refactors `/erp` from one long vertical connector page into a source-independent tabbed workbench. It keeps setup, mapping, preflight, credential, preview/apply, and activity information visible without forcing users to read every section at once. No migration, connector runtime, credential capture, import apply, or ERP/source writeback is added.

| Document / artifact                                                                                                                | Purpose                                                           |
| ---------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| [14_erp_workbench_information_architecture.md](./14_erp_workbench_information_architecture.md)                                     | Tabbed workbench IA, mobile rules, scope, and acceptance criteria |
| [`src/routes/_app/erp.tsx`](../../src/routes/_app/erp.tsx)                                                                         | Source-independent tabbed workbench UI                            |
| [`e2e/ui-stabilization.spec.ts`](../../e2e/ui-stabilization.spec.ts)                                                               | Authenticated tab navigation and mobile overflow coverage         |
| [`scripts/verify-14-erp-workbench-information-architecture.sh`](../../scripts/verify-14-erp-workbench-information-architecture.sh) | PR14.21 verify gate                                               |

## PR14 closeout and PR15-PR16 runtime roadmap

PR14 closes with the connector control plane in place: setup, mapping, preflight, credential boundary, activity history, dry-run preview, review, approval policy, closed apply contract, and a tabbed `/erp` workbench. PR15-PR16 move the product toward a multi-tenant connector runtime and HR AI operating layer without weakening the human-confirmation boundary.

| Document / artifact | Purpose |
| --- | --- |
| [14_21_executive_status_report.md](./14_21_executive_status_report.md) | Turkish executive status report for product/sales stakeholders, including completion estimates and remaining work |
| [15_16_connector_runtime_ai_roadmap.md](./15_16_connector_runtime_ai_roadmap.md) | Detailed PR15-PR16 plan for DB-backed job queue, Railway worker, credential runtime boundary, controlled data movement, notifications, and AI operational recommendations |

## PR15.1 Connector job queue contract

PR15.1 opens the connector runtime phase by adding a tenant-scoped, idempotent, service-role worker job queue contract. It does not run connectors, resolve secrets, apply imports, write canonical data, or write back to ERP/source systems.

| Document / artifact | Purpose |
| --- | --- |
| [15_connector_job_queue_contract.md](./15_connector_job_queue_contract.md) | PR15.1 queue contract, security boundary, AI-safe evidence, and PR15.2 handoff |
| [`20260604100000_puls_integration_connector_job_queue.sql`](../../supabase/migrations/20260604100000_puls_integration_connector_job_queue.sql) | DB-backed connector job queue contract |
| [`scripts/verify-15-connector-job-queue-contract.sh`](../../scripts/verify-15-connector-job-queue-contract.sh) | PR15.1 verify gate |

## PR15.2 Connector worker skeleton

PR15.2 adds the safe worker ownership layer on top of the PR15.1 queue. It introduces worker heartbeat, lease renewal, stale-job recovery, and a source-independent `noop_health` skeleton path. It does not call provider APIs, read credentials, apply imports, write canonical data, or write back to ERP/source systems.

| Document / artifact | Purpose |
| --- | --- |
| [15_connector_worker_skeleton.md](./15_connector_worker_skeleton.md) | PR15.2 worker skeleton contract, security boundary, AI-safe evidence, and PR15.3 handoff |
| [`20260604110000_puls_integration_connector_worker_skeleton.sql`](../../supabase/migrations/20260604110000_puls_integration_connector_worker_skeleton.sql) | Worker heartbeat, lease ownership, and stale-job recovery DB contract |
| [`services/erp-connector/README.md`](../../services/erp-connector/README.md) | Runtime worker skeleton service posture |
| [`scripts/verify-15-connector-worker-skeleton.sh`](../../scripts/verify-15-connector-worker-skeleton.sh) | PR15.2 verify gate |

## PR15.3 Connector runtime observability and failure model

PR15.3 adds safe runtime observability on top of the PR15.1 queue and PR15.2 worker skeleton. Connector jobs now carry deterministic failure class, retry/backoff, dead-letter, operator severity, and safe job-event history. `/erp` shows these signals without provider payloads, credential readback, import apply, canonical writes, or ERP/source writeback.

| Document / artifact | Purpose |
| --- | --- |
| [15_connector_runtime_observability_failure_model.md](./15_connector_runtime_observability_failure_model.md) | PR15.3 failure model, retry/dead-letter rules, AI-safe evidence, and PR15.4 handoff |
| [`20260604120000_puls_integration_connector_runtime_observability.sql`](../../supabase/migrations/20260604120000_puls_integration_connector_runtime_observability.sql) | Runtime failure class, retry/backoff, connector job events, and safe read-model DB contract |
| [`scripts/verify-15-connector-runtime-observability.sh`](../../scripts/verify-15-connector-runtime-observability.sh) | PR15.3 verify gate |

## PR15.4 Secure credential runtime boundary

PR15.4 adds the source-independent secure credential boundary required before runtime preflight can use real connector credentials. It keeps credential values outside product UI, client adapters, activity history, and AI context; the product DB stores only opaque reference state through service-role-only RPCs. Provider API runtime, secret manager implementation, import apply, canonical writes, and ERP/source writeback remain closed.

| Document / artifact | Purpose |
| --- | --- |
| [15_connector_secure_credential_runtime_boundary.md](./15_connector_secure_credential_runtime_boundary.md) | PR15.4 credential reference, no-readback, safe event, and AI evidence boundary |
| [`20260604130000_puls_integration_secure_credential_runtime_boundary.sql`](../../supabase/migrations/20260604130000_puls_integration_secure_credential_runtime_boundary.sql) | Service-role-only credential reference RPCs, safe credential events, and runtime-preflight blocker |
| [`scripts/verify-15-secure-credential-runtime-boundary.sh`](../../scripts/verify-15-secure-credential-runtime-boundary.sh) | PR15.4 verify gate |

## PR15.5 Runtime preflight with credential reference

PR15.5 adds the first safe runtime-preflight path on top of PR15.4. Admins can queue a `connector_runtime_preflight` job only when required credentials are verified; the worker reads safe setup/credential context and records a safe job result. Provider API calls, credential readback, import apply, canonical writes, ERP/source writeback, and AI autonomous actions remain closed.

| Document / artifact | Purpose |
| --- | --- |
| [15_connector_runtime_preflight_credential_reference.md](./15_connector_runtime_preflight_credential_reference.md) | PR15.5 runtime preflight request, verified credential gate, worker safe context, and AI evidence boundary |
| [`20260604140000_puls_integration_runtime_preflight_credential_reference.sql`](../../supabase/migrations/20260604140000_puls_integration_runtime_preflight_credential_reference.sql) | Runtime preflight request/context RPCs and stricter verified credential enqueue gate |
| [`scripts/verify-15-runtime-preflight-credential-reference.sh`](../../scripts/verify-15-runtime-preflight-credential-reference.sh) | PR15.5 verify gate |

## PR15.6 AI runtime evidence contract

PR15.6 connects connector runtime signals to AI Coach as source-disclosed, safe evidence. `/ai-koc` can now show connector job, worker event, credential state, import preview, and safe activity posture without adding migration, job start, credential readback, import apply, canonical writes, ERP/source writeback, or autonomous AI actions.

| Document / artifact | Purpose |
| --- | --- |
| [15_ai_runtime_evidence_contract.md](./15_ai_runtime_evidence_contract.md) | PR15.6 AI-safe runtime evidence contract, allowed/forbidden suggestion taxonomy, and source disclosure rules |
| [`scripts/verify-15-ai-runtime-evidence-contract.sh`](../../scripts/verify-15-ai-runtime-evidence-contract.sh) | PR15.6 verify gate |

## PR15.7 Railway worker deployment readiness

PR15.7 makes the connector worker operationally deployable on Railway before PR16 data movement begins. It adds config-as-code, a Railway start command, `/health` deployment check, required environment variables, one-replica guidance, and a remote heartbeat/noop smoke runbook. Provider API runtime, credential readback, import apply, canonical writes, ERP/source writeback, and AI autonomous actions remain closed.

| Document / artifact | Purpose |
| --- | --- |
| [15_railway_worker_deployment_readiness.md](./15_railway_worker_deployment_readiness.md) | PR15.7 Railway setup, env contract, remote smoke SQL, and PR16 handoff |
| [`services/erp-connector/railway.toml`](../../services/erp-connector/railway.toml) | Railway config-as-code for the connector worker service |
| [`services/erp-connector/README.md`](../../services/erp-connector/README.md) | Worker service posture, env contract, and Railway smoke checklist |
| [`scripts/verify-15-railway-worker-deployment-readiness.sh`](../../scripts/verify-15-railway-worker-deployment-readiness.sh) | PR15.7 verify gate |

## PR15.8 Railway worker production guardrails

PR15.8 hardens the deployed Railway worker before PR16 data movement. It disables non-production Railway queue loops by default, gates `import_apply` behind an explicit PR16 flag, pins one worker replica with zero deploy overlap and graceful drain, narrows monorepo redeploy scope with watch patterns, and updates the remote smoke proof to use connector job events for worker attribution. Provider API runtime, credential readback, import apply execution, canonical writes, ERP/source writeback, and AI autonomous actions remain closed.

| Document / artifact | Purpose |
| --- | --- |
| [15_railway_worker_production_guardrails.md](./15_railway_worker_production_guardrails.md) | PR15.8 Railway production guardrails, env defaults, smoke expectations, and PR16 handoff |
| [`services/erp-connector/railway.toml`](../../services/erp-connector/railway.toml) | One-replica, zero-overlap, graceful-drain Railway config-as-code |
| [`services/erp-connector/README.md`](../../services/erp-connector/README.md) | Worker service guardrail env contract |
| [`scripts/verify-15-railway-worker-production-guardrails.sh`](../../scripts/verify-15-railway-worker-production-guardrails.sh) | PR15.8 verify gate |

## PR16 controlled data movement safety model

PR16 must not open blind import apply. Before canonical writes are enabled, PULS needs an overwrite-safe change-set model with before snapshots, source ownership, stale-hash guards, admin approval, worker-only execution, CRUD audit, retention policy, and rollback/compensating preview. The first execution path should be create-only master-data import; guarded updates and rollback execution follow only after their safety gates are proven.

The audit model is business-object first: every canonical insert, update, soft-delete, restore, rollback, or compensating update needs an object event ledger entry. Guarded updates add field-level diff evidence and service-role-only rollback snapshots with default 90-day hot retention, so PULS can stay transparent without turning the operational database into an unlimited raw personal-data archive.

| Document / artifact | Purpose |
| --- | --- |
| [16_controlled_data_movement_safety_model.md](./16_controlled_data_movement_safety_model.md) | PR16 overwrite, rollback, change-set, CRUD audit retention, worker execution, and AI evidence safety model |
| [15_16_connector_runtime_ai_roadmap.md](./15_16_connector_runtime_ai_roadmap.md) | Updated PR16 delivery order from apply safety contract through AI operational recommendations |

## PR16.1 apply safety contract and permission hardening

PR16.1 implements the first closed execution boundary for controlled data movement. It makes the legacy `apply_import_batch(UUID, TEXT)` RPC service-role only, rejects `import_apply` connector jobs while create-only gates are not implemented, and exposes a safe `/erp` apply contract covering CRUD audit tiers and 90-day hot retention for field diffs and rollback snapshots. It does not apply imports or write canonical data.

| Document / artifact                                                                                                                                                    | Purpose                                                                                                  |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| [16_1_apply_safety_contract_permission_hardening.md](./16_1_apply_safety_contract_permission_hardening.md)                                                             | PR16.1 apply permission boundary, closed worker apply gate, audit-retention evidence, and PR16.2 handoff |
| [`supabase/migrations/20260605100000_puls_integration_apply_safety_contract.sql`](../../supabase/migrations/20260605100000_puls_integration_apply_safety_contract.sql) | Service-role-only apply RPC, closed `import_apply` job trigger, and apply safety contract RPC            |
| [`scripts/verify-16-1-apply-safety-contract.sh`](../../scripts/verify-16-1-apply-safety-contract.sh)                                                                   | PR16.1 verify gate                                                                                       |

## PR16.2 apply change-set and risk ledger

PR16.2 adds immutable change-set evidence for previewed dry-run batches. Admins can generate and inspect safe row-level risk summaries before PR16.3 opens any create-only worker apply path. The change-set records create/update/skip intent, blocker counts, stale/source-conflict risk, audit tier, retention bucket, and expected-current-hash metadata without exposing raw payloads or writing canonical data.

| Document / artifact                                                                                                                                                  | Purpose                                                                                           |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| [16_2_apply_change_set_risk_ledger.md](./16_2_apply_change_set_risk_ledger.md)                                                                                       | PR16.2 immutable change-set, safe risk ledger, data minimization, and PR16.3 handoff              |
| [`supabase/migrations/20260605110000_puls_integration_apply_change_set.sql`](../../supabase/migrations/20260605110000_puls_integration_apply_change_set.sql)         | Change-set tables, risk classes, immutable triggers, admin generation RPC, and safe summary RPC   |
| [`scripts/verify-16-2-apply-change-set.sh`](../../scripts/verify-16-2-apply-change-set.sh)                                                                           | PR16.2 verify gate                                                                                |

## PR16.3 create-only worker apply

PR16.3 opens the first controlled canonical write path, but only through the service-role Railway worker and only for admin-approved create-only reference-dimension rows. Browser direct apply, authenticated direct canonical writes, existing-record updates, employee apply, ERP/source writeback, credential readback, raw payload readback, provider API calls, and AI autonomous actions remain closed.

| Document / artifact                                                                                                                                                            | Purpose                                                                                                      |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| [16_3_create_only_worker_apply.md](./16_3_create_only_worker_apply.md)                                                                                                         | PR16.3 create-only worker apply scope, Railway env gate, business rules, and PR16.4 handoff                  |
| [`supabase/migrations/20260605120000_puls_integration_create_only_worker_apply.sql`](../../supabase/migrations/20260605120000_puls_integration_create_only_worker_apply.sql) | Worker-only create apply RPCs, object event audit ledger, and PR16.3 `import_apply` trigger exception        |
| [16_3_create_only_apply_context_hardening.md](./16_3_create_only_apply_context_hardening.md)                                                                                   | PR16.3A create-only context hardening after Railway smoke exposed heartbeat context overwrite risk            |
| [`supabase/migrations/20260605122000_puls_integration_create_only_job_context_hardening.sql`](../../supabase/migrations/20260605122000_puls_integration_create_only_job_context_hardening.sql) | Preserves queued job safe context during worker lease heartbeats                                             |
| [`services/erp-connector/src/worker.ts`](../../services/erp-connector/src/worker.ts)                                                                                           | Worker execution path for PR16.3 create-only apply jobs behind an explicit env gate                          |
| [`scripts/verify-16-3-create-only-context-hardening.sh`](../../scripts/verify-16-3-create-only-context-hardening.sh)                                                           | PR16.3A verify gate                                                                                          |
| [`scripts/verify-16-3-create-only-worker-apply.sh`](../../scripts/verify-16-3-create-only-worker-apply.sh)                                                                     | PR16.3 verify gate                                                                                           |

## PR16.4.1 guarded update evidence

PR16.4.1 prepares overwrite-safe update evidence without opening update execution. It adds hash-only field diffs, service-role-only rollback snapshots, admin/service-role evidence generation, authenticated-safe listing, and `/erp` visibility. Canonical update execution, worker update jobs, employee updates, destructive fields, ERP/source writeback, credential readback, raw payload readback, provider API calls, rollback execution, and AI autonomous apply remain closed.

| Document / artifact                                                                                                                                                        | Purpose                                                                                           |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| [16_4_1_guarded_update_evidence.md](./16_4_1_guarded_update_evidence.md)                                                                                                   | PR16.4.1 guarded update evidence scope, safety contract, and PR16.4.2 handoff                     |
| [`supabase/migrations/20260605130000_puls_integration_guarded_update_evidence.sql`](../../supabase/migrations/20260605130000_puls_integration_guarded_update_evidence.sql) | Field diff and rollback snapshot ledgers plus generate/list RPCs; no guarded update execution RPC |
| [`scripts/verify-16-4-1-guarded-update-evidence.sh`](../../scripts/verify-16-4-1-guarded-update-evidence.sh)                                                               | PR16.4.1 verify gate                                                                              |

## Related packs

| Pack                    | Entry point                                                                                      |
| ----------------------- | ------------------------------------------------------------------------------------------------ |
| API contract (PR12)     | [`../api/README.md`](../api/README.md)                                                           |
| Data inventories (PR11) | [`../data/README.md`](../data/README.md)                                                         |
| V1 product specs        | [`../specs/05-frontend-sayfa-gelistirme-spec.md`](../specs/05-frontend-sayfa-gelistirme-spec.md) |
