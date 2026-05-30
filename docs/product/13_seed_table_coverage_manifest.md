# PR13.3 — Seed Table Coverage Manifest

Product-facing `puls_*` object coverage for the **Puls Sanayi A.Ş.** demo tenant — mapped to completeness classes, row targets, proof routes, and owner PRs.

**Documentation-only.** PR13.4 implements rows; PR13.5 proves calc views and route smoke with `VITE_PULS_DEMO_MODE=false`.

Production-facing product behavior must not depend on embedded TypeScript business fixtures.

## Executive summary

- **Not every table must be seeded** — use PR13.1 completeness classes consistently
- **Calc views are derived** — seed underlying base tables; proof via route + `puls_calc.*` reads
- Manifest lists **all product-facing `puls_*` objects identified from PR13.1 + migration inspection** (currently observed inventory — count may evolve with migrations)
- **Sensitive/system** objects excluded from demo narrative
- Supersedes PR13.1 **20–40 employee** target → **120 employees** for seed spec

## Completeness class mapping

| Class | Seed posture in PR13.3 spec |
|-------|----------------------------|
| `required seeded` | Baseline rows in PR13.4 CSV/SQL |
| `required scenario-generated` | Created post-bootstrap by PR13.5 scenario scripts |
| `readable empty-ok` | Zero rows valid; do not inflate for packaging |
| `future/not V1` | Document only |
| `sensitive/system` | Do-not-seed list |

## Manifest — `puls_core`

| Schema | Object | Class | Row target | Seed source | Source ownership | Proof route | Proof adapter/view | Owner PR | Notes |
|--------|--------|-------|------------|-------------|------------------|-------------|-------------------|----------|-------|
| puls_core | tenants | required seeded | 1 | PR13.4 baseline | PULS-owned | `/menu`, all routes | tenant context | PR13.4 | **Puls Sanayi A.Ş.** |
| puls_core | employees | required seeded | 120 | PR13.4 baseline | PULS-owned (+ optional imported metadata) | `/calisanlar`, `/profil` | `core/employees.ts`, `puls_calc.employee_list_overview` | PR13.4 | **120 employees** |
| puls_core | departments | required seeded | 12 | PR13.4 baseline | Mixed PULS + imported | `/departmanlar` | `core/organization.ts`, `puls_calc.organization_overview` | PR13.4 | 12 dept names from company spec |
| puls_core | positions | required seeded | 35–50 | PR13.4 baseline | Mixed PULS + imported | `/pozisyonlar` | `core/organization.ts`, `organization_overview` | PR13.4 | Every employee linked |
| puls_core | cost_centers | required seeded | 12–20 | PR13.4 baseline | Mixed | `/masraf-kategorileri` | `setup/cost-center-readiness.ts` | PR13.4 | ERP routing readiness |
| puls_core | employee_reporting_lines | required seeded | 119+ | PR13.4 baseline | PULS-owned | `/sirket-kurulum`, `/calisanlar` | `setup/employee-assignment-readiness.ts` | PR13.4 | **puls_core.employee_reporting_lines** |
| puls_core | employee_cost_center_assignments | required seeded | 120 | PR13.4 baseline | PULS-owned | `/masraf-kategorileri`, `/sirket-kurulum` | `setup/cost-center-readiness.ts` | PR13.4 | **puls_core.employee_cost_center_assignments** |
| puls_core | legal_entities | required seeded | 1 | PR13.4 baseline | PULS-owned | `/sirket-kurulum` | setup readiness | PR13.4 | **Puls Sanayi A.Ş.** legal entity |
| puls_core | locations | required seeded | 3 | PR13.4 baseline | PULS-owned | `/sirket-kurulum` | setup readiness | PR13.4 | **puls_core.locations** — İstanbul HQ, Bursa production, İzmir sales/service |
| puls_core | employee_legal_entity_assignments | required seeded | 120 | PR13.4 baseline | PULS-owned | `/sirket-kurulum` | assignment readiness | PR13.4 | All 120 employees linked to legal entity |
| puls_core | employee_location_assignments | required seeded | 120 | PR13.4 baseline | PULS-owned | `/sirket-kurulum` | assignment readiness | PR13.4 | Every employee assigned to one of 3 sites; aligns with department/site model |
| puls_core | authority_pools | future/not V1 | 0 | — | — | — | — | — | Enterprise authority graph |
| puls_core | authority_pool_members | future/not V1 | 0 | — | — | — | — | — | Enterprise authority graph |
| puls_core | authority_relationships | future/not V1 | 0 | — | — | — | — | — | Enterprise authority graph |

## Manifest — `puls_workflow`

| Schema | Object | Class | Row target | Seed source | Source ownership | Proof route | Proof adapter/view | Owner PR | Notes |
|--------|--------|-------|------------|-------------|------------------|-------------|-------------------|----------|-------|
| puls_workflow | leave_types | required seeded | 6–10 | PR13.4 baseline | PULS-owned (+ 1 inactive historical) | `/izin-tanimlari`, `/izin` | `setup/leave-types.ts` | PR13.4 | Include inactive for historical label scenario |
| puls_workflow | approval_policies | required seeded | 2–4 | PR13.4 baseline | PULS-owned | `/izin-tanimlari`, `/masraf-kategorileri` | `workflow/policies.ts` | PR13.4 | Leave + expense domains |
| puls_workflow | approval_policy_steps | required seeded | 4–8 | PR13.4 baseline | PULS-owned | `/izin-tanimlari` | `workflow/policies.ts` | PR13.4 | Manager approver steps |
| puls_workflow | expense_categories | required seeded | 8–15 | PR13.4 baseline | PULS-owned (+ 1 inactive historical) | `/masraf-kategorileri`, `/masraf` | `setup/expense-categories.ts` | PR13.4 | Category limits for warning scenario |
| puls_workflow | leave_balances | required seeded | 120+ | PR13.4 baseline | PULS-owned | `/izin`, `/profil` | `leave/overview.ts` | PR13.4 | Per employee × active leave types where useful |
| puls_workflow | leave_requests | required scenario-generated | 20–40 | PR13.5 scenario | PULS-owned | `/izin`, `/dashboard` | `leave/requests.ts`, `puls_calc.leave_overview` | PR13.5 | **puls_workflow.leave_requests** |
| puls_workflow | expense_claims | required scenario-generated | 20–40 | PR13.5 scenario | PULS-owned | `/masraf`, `/dashboard` | `expense/claims.ts`, `puls_calc.expense_overview` | PR13.5 | **puls_workflow.expense_claims** |
| puls_workflow | approval_requests | required scenario-generated | 20+ | PR13.5 scenario | PULS-owned | `/izin`, `/masraf` | `workflow/approvals.ts` | PR13.5 | **puls_workflow.approval_requests**; mixed statuses |
| puls_workflow | leave_type_lifecycle_events | required scenario-generated | 2+ | PR13.5 scenario | PULS-owned | `/izin-tanimlari` | lifecycle RPC smoke | PR13.5 | Deactivate/restore audit |
| puls_workflow | expense_category_lifecycle_events | required scenario-generated | 2+ | PR13.5 scenario | PULS-owned | `/masraf-kategorileri` | lifecycle RPC smoke | PR13.5 | Deactivate/restore audit |
| puls_workflow | contracts | required seeded | 15–30 | PR13.4 baseline + PR13.5 enrich | PULS-owned or imported metadata | `/sozlesmeler` | `contracts/overview.ts`, `puls_calc.contracts_overview` | PR13.4, PR13.5 | Risk variety in scenarios |
| puls_workflow | leave_documents | readable empty-ok | 0 | — | — | `/izin` | — | — | Attachment metadata optional |
| puls_workflow | expense_receipts | readable empty-ok | 0 | — | — | `/masraf` | — | — | Attachment metadata optional |
| puls_workflow | contract_files | readable empty-ok | 0 | — | — | `/sozlesmeler` | — | — | File metadata optional |

## Manifest — `puls_performance`

| Schema | Object | Class | Row target | Seed source | Source ownership | Proof route | Proof adapter/view | Owner PR | Notes |
|--------|--------|-------|------------|-------------|------------------|-------------|-------------------|----------|-------|
| puls_performance | performance_cycles | required seeded | 1–2 | PR13.4 baseline | PULS-owned | `/performans`, `/performans-parametreleri` | `performance/cycles.ts` | PR13.4 | **puls_performance.performance_cycles**; draft + active |
| puls_performance | competency_templates | required seeded | 8–15 | PR13.4 baseline | PULS-owned | `/performans-parametreleri` | `setup/performance-parameters.ts` | PR13.4 | Params route proof |
| puls_performance | performance_kpis | readable empty-ok | 0–20 | PR13.4 optional | PULS-owned | `/performans` | `performance/overview.ts` | PR13.4 | Optional KPI defs |
| puls_performance | competency_evaluations | required scenario-generated | 40+ | PR13.5 scenario | PULS-owned | `/performans` | `performance/overview.ts` | PR13.5 | Manager + self evals |
| puls_performance | performance_scores | required scenario-generated | 40+ | PR13.5 scenario | PULS-owned | `/performans`, `/profil` | `performance/overview.ts`, `puls_calc.performance_overview` | PR13.5 | **puls_performance.performance_scores** |
| puls_performance | career_profiles | required seeded | 15–30 | PR13.4 baseline | PULS-owned | `/kariyer` | `career/overview.ts` | PR13.4 | Enough for rich UI or honest partial |
| puls_performance | training_needs | required seeded | 10–20 | PR13.4 baseline | PULS-owned | `/egitim` | `training/overview.ts` | PR13.4 | Optional catalog rows |
| puls_performance | kpi_category_weights | required seeded | 4–8 | PR13.4 baseline | PULS-owned | `/performans-parametreleri` | `setup/performance-parameters.ts` | PR13.4 | Weights populated |
| puls_performance | score_bands | required seeded | 3–5 | PR13.4 baseline | PULS-owned | `/performans-parametreleri` | `setup/performance-parameters.ts` | PR13.4 | Band definitions |

## Manifest — `puls_integration`

| Schema | Object | Class | Row target | Seed source | Source ownership | Proof route | Proof adapter/view | Owner PR | Notes |
|--------|--------|-------|------------|-------------|------------------|-------------|-------------------|----------|-------|
| puls_integration | erp_connections | required seeded | 1 | PR13.4 baseline | PULS config | `/erp`, `/dashboard` | `setup/erp.ts` | PR13.4 | **puls_integration.erp_connections**; inactive **Canias** |
| puls_integration | erp_field_mappings | required seeded | 10–25 | PR13.4 baseline | PULS config | `/erp` | `setup/erp.ts` | PR13.4 | Sample non-sensitive mappings |
| puls_integration | source_namespaces | required seeded | 1 | PR13.4 baseline | Imported namespace | `/masraf-kategorileri` | `setup/cost-center-readiness.ts` | PR13.4 | Canias source namespace |
| puls_integration | entity_identity_map | required seeded | 6–15 | PR13.4 baseline | Imported identity | `/departmanlar`, `/pozisyonlar`, `/masraf-kategorileri` | org + cost-center adapters | PR13.4 | **puls_integration.entity_identity_map** for imported org |
| puls_integration | erp_sync_batches | readable empty-ok | 0 | — | — | `/erp` | `setup/erp.ts` | — | Sync history optional |
| puls_integration | erp_staging_records | readable empty-ok | 0 | — | — | `/erp` | — | — | Staging optional |
| puls_integration | import_batches | readable empty-ok | 0 | — | — | — | — | — | No import scenario in baseline |
| puls_integration | import_records | readable empty-ok | 0 | — | — | — | — | — | No import scenario in baseline |
| puls_integration | import_field_violations | readable empty-ok | 0 | — | — | — | — | — | No import scenario in baseline |

**Canias boundary:** **metadata seed only**; **no Canias runtime**; **no automatic destructive ERP writes**. Runtime connector is **PR13.7**.

## Manifest — `puls_calc` (derived proof targets)

Do **not** INSERT into calc views. Seed underlying tables; proof via routes:

| Schema | Object | Class | Row target | Proof route | Underlying seed |
|--------|--------|-------|------------|-------------|-----------------|
| puls_calc | dashboard_overview | derived proof | non-zero KPIs | `/dashboard` | employees, workflows, ERP metadata |
| puls_calc | employee_list_overview | derived proof | 120 rows | `/calisanlar` | puls_core.employees |
| puls_calc | organization_overview | derived proof | 12 depts, 35–50 positions | `/departmanlar`, `/pozisyonlar` | departments, positions |
| puls_calc | leave_overview | derived proof | balances + requests | `/izin`, `/profil` | leave_types, balances, requests |
| puls_calc | expense_overview | derived proof | claims + categories | `/masraf`, `/profil` | expense_categories, claims |
| puls_calc | performance_overview | derived proof | scores + cycles | `/performans`, `/profil` | performance_cycles, scores, evaluations |
| puls_calc | contracts_overview | derived proof | 15–30 contracts | `/sozlesmeler` | puls_workflow.contracts |
| puls_calc | setup_readiness_summary | derived proof | readiness aggregates | `/sirket-kurulum`, `/erp` | org, assignments, ERP mappings |
| puls_calc | menu_overview | derived proof | tenant counts | `/menu` | employees, departments, positions — **puls_calc.menu_overview** |

## Sensitive / system — do-not-seed

| Schema | Object | Class | Demo posture |
|--------|--------|-------|--------------|
| puls_vault | conversation_messages | sensitive/system | Do not seed narrative; PR13.6 defines AI vault usage |
| puls_audit | audit_logs | sensitive/system | System-generated only; empty OK for demo |
| auth | users / employee link | sensitive/system | Indirect via PR13.5 bootstrap runbook |
| puls_integration | ERP credentials / secrets | sensitive/system | Never in CSV; inactive connection metadata only |

## Retirement package mapping

| Retirement package (PR13.2) | Primary manifest objects |
|----------------------------|-------------------------|
| Employee directory | employees, employee_list_overview |
| Employee assignment readiness | employee_reporting_lines, employee_cost_center_assignments |
| Departments / Positions | departments, positions, organization_overview, entity_identity_map |
| Cost center readiness | cost_centers, source_namespaces, entity_identity_map |
| Leave / expense setup | leave_types, expense_categories, approval_policies |
| Request-creation-readiness | leave_balances, types, categories, assignments |
| Performance / params | performance_cycles, competency_templates, kpi_category_weights, score_bands |
| Contracts | contracts, contracts_overview |
| ERP metadata | erp_connections, erp_field_mappings |
| Dashboard / menu | all calc views via underlying seed |

## PR13.4 artifact blueprint

PR13.4 CSV/SQL pack must implement every `required seeded` row in this manifest. PR13.5 adds `required scenario-generated` rows and validates calc view output with **`VITE_PULS_DEMO_MODE=false`**.

## References

- [`13_synthetic_company_seed_spec.md`](./13_synthetic_company_seed_spec.md)
- [`13_db_table_completeness_classes.md`](./13_db_table_completeness_classes.md)
- [`13_embedded_demo_retirement_plan.md`](./13_embedded_demo_retirement_plan.md)
- [`13_seed_scenario_generation_spec.md`](./13_seed_scenario_generation_spec.md)
