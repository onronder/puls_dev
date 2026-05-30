# PR13.0 — V1 Feature Traceability Matrix

Maps V1 product intent to implemented surfaces, backends, DB-backed demo needs, AI Coach touchpoints, and honest packaging status.

**Documentation-only.** PR13.1 will deepen and verify each row.

## Executive summary

PULS has **20 PR12 read-model routes** (19 standard inventory routes + `/menu` shell exception) plus additional setup surfaces such as `/performans-parametreleri`. Many routes still rely on `resolveAdapterData*` demo fallback or embedded `fetchDemo*` when DB is empty. **No row is marked `production_ready` if demo fallback is the only way to show rich UI.**

Status reflects the **PR13 capability taxonomy**, informed by PR11 inventory — **not a 1:1 PR11 label copy**.

## Traceability status taxonomy

| Status | Meaning |
|--------|---------|
| `production_ready` | Real DB path proves V1 UX without demo fallback for core scenario |
| `production_partial` | Real adapters exist; gaps in data completeness, aggregators, or demo fallback for empty UX |
| `db_backed_demo_required` | Real mutations/reads exist but demo tenant seed required for packaging proof |
| `embedded_demo_only` | Rich UI primarily from `puls-demo-data.ts` / demo fallback |
| `future_candidate` | Spec or artifact reference; not V1 packaging target |
| `not_v1` | Explicitly out of V1 scope |

## Matrix

| V1 feature | V1 doc/source | Route/surface | Adapter/backend | DB objects | DB-backed demo requirement | CSV/import requirement | AI Coach touchpoint | Current status | V1 package decision | Follow-up PR |
|------------|---------------|---------------|-----------------|------------|----------------------------|------------------------|---------------------|----------------|---------------------|--------------|
| Dashboard | specs/05 §4.1 | `/dashboard` | `dashboard/overview.ts` | `puls_calc.*`, `puls_integration.erp_*` | KPIs, queues, activity — `required seeded` + calc views | Optional ERP mapping rows | Dashboard insight summary | `production_partial` | Real calc views + demo composite when empty; package with DB demo | PR13.1, PR13.5 |
| Company setup readiness | specs/05 §4.2 | `/sirket-kurulum` | `setup-readiness-dashboard`, org/assignment readiness | `puls_core.*`, readiness views | Tenant, org, assignments — `required seeded` | Org CSV optional | Setup coach | `db_backed_demo_required` | Real readiness adapters; needs demo seed | PR13.3, PR13.5 |
| Employee directory | specs/05 §4.3 | `/calisanlar` | `core/employees.ts`, assignment-readiness | `puls_core.employees` | 20-40 employees — `required seeded` | Employee import CSV | Employee data quality coach | `production_partial` | Real list path; assignment-readiness source; DB seed needed for full list/stats | PR13.1, PR13.3 |
| Departments | specs/05 §4.4 | `/departmanlar` | `core/organization.ts` | `puls_core.departments` | PULS-owned depts — `required seeded`; imported/source-owned — `required seeded` | Org CSV | Setup coach | `production_partial` | Source-aware mixed CRUD: PULS-owned create/edit; imported read-only | PR13.3 |
| Positions | specs/05 §4.4 | `/pozisyonlar` | `core/organization.ts` | `puls_core.positions` | PULS-owned positions — `required seeded`; imported/source-owned — `required seeded` | Org CSV | Setup coach | `production_partial` | Source-aware mixed CRUD: PULS-owned create/edit; imported read-only | PR13.3 |
| Leave setup | specs/05 §4.5 | `/izin-tanimlari` | `setup/leave-types.ts` | `puls_workflow.leave_types`, policies | Leave types + policies — `required seeded` | Leave type CSV optional | Setup coach | `production_partial` | Real CRUD; demo for empty tenant | PR13.3 |
| Leave request | specs/05 §4.6 | `/izin` | `leave/requests.ts`, `leave/overview.ts` | `puls_workflow.create_leave_request`, balances, requests | Balances + types — `required seeded`; requests — `required scenario-generated` | — | Leave request helper | `db_backed_demo_required` | Create RPC real; overview demo fallback when empty | PR13.5 |
| Expense categories | specs/05 §4.7 | `/masraf-kategorileri` | `setup/expense-categories.ts` | `puls_workflow.expense_categories` | Categories + limits — `required seeded` | Category CSV optional | Setup coach | `production_partial` | Real CRUD | PR13.3 |
| Expense claim | specs/05 §4.8 | `/masraf` | `expense/claims.ts`, `expense/overview.ts` | `puls_workflow.create_expense_claim`, claims | Categories — `required seeded`; claims — `required scenario-generated` | — | Expense claim helper | `db_backed_demo_required` | Create RPC real; overview demo fallback when empty | PR13.5 |
| Performance overview | specs/05 §4.9 | `/performans` | `performance/overview.ts` | `puls_performance.*`, `puls_calc` | Scores/cycles — `required seeded` | Performance CSV optional | Performance manager coach | `embedded_demo_only` | Demo fallback for rich overview when DB sparse | PR13.3, PR13.5 |
| Performance cycles | specs/05 §4.9 | `/performans` | `performance/cycles.ts` | `puls_performance.performance_cycles` | Active/draft cycles — `required seeded` | — | Performance manager coach | `db_backed_demo_required` | Real mutations; demo fetch returns `[]` when empty | PR13.3, PR13.5 |
| Career | specs/05 §4.10 | `/kariyer` | `career/overview.ts` | `puls_core.employees`, `puls_performance.career_profiles` | Career map data — `future/not V1` depth | — | Career guidance (future) | `embedded_demo_only` | WithMeta exists; weak real DB coverage; demo fills UI | PR13.1 |
| Training | specs/05 §4.11 | `/egitim` | `training/overview.ts` | `puls_performance.training_needs` | Training catalog — `readable empty-ok` or future | — | Training recommender (future) | `embedded_demo_only` | WithMeta exists; weak real DB coverage; some `common.soon` UI | PR13.1 |
| Job evaluation | specs/05 §4.12 | `/is-degerleme` | `job-evaluation/overview.ts` | TBD | Job eval grades — `future/not V1` | — | — | `not_v1` | Placeholder / soon | PR13.1 |
| Contracts metadata | specs/05 §4.13 | `/sozlesmeler` | `contracts/overview.ts` | `puls_workflow.contracts`, calc summary | Contract metadata — `required seeded` | — | Contract risk explainer | `production_partial` | Real metadata read when tenant has rows; demo fallback for rich empty UX | PR13.3 |
| Profile/account | specs/05 §4.14 | `/profil` | `profile/overview.ts` | `puls_core.employees`, auth link | Persona-linked employee — `required seeded` | — | Profile/persona context | `production_partial` | Auth→employee readiness path; `tenant_without_employee` does not silently demo-fallback | PR13.3 |
| Settings | specs/05 §4.15 | `/ayarlar` | `settings/overview.ts` | Setup hub links | — | `readable empty-ok` | — | `production_partial` | Hub only; linked setup routes vary | PR13.1 |
| ERP setup/readiness | specs/05 §4.16 | `/erp` | `setup/erp.ts` | `puls_integration.erp_*` | Canias connection row — `required seeded` (inactive) | ERP mapping CSV future | Setup coach | `db_backed_demo_required` | Read-only integration metadata; Canias label; demo fallback when empty | PR13.7 |
| Menu / shell navigation | specs/05 mobile shell | `/menu` | `menu/overview.ts` | `puls_calc.menu_overview` | Tenant counts — `required seeded` | — | — | `production_partial` | Shell exception: no WithMeta/demo pill; navigation surface not domain CRUD | PR13.1 |
| AI Coach | specs/05 §4.17 | `/ai-koc` | `ai-coach/overview.ts` | `puls_vault` (passive) | Full context tables — PR13.6 inventory | — | All touchpoints (target) | `embedded_demo_only` | **Implemented:** static/teaser (`STATIC_AI_COACH_OVERVIEW`). **Ambition:** process-embedded value layer. **Package gate:** PR13.6; not product-ready today | PR13.6 |
| Performance parameters | specs/05 setup | `/performans-parametreleri` | `setup/performance-parameters.ts` | `puls_performance` params | Templates/bands — `required seeded` | CSV optional | Setup coach | `embedded_demo_only` | Demo fallback when DB empty | PR13.3 |

## Gap posture

- **No silent ready:** Rows use `embedded_demo_only` or `production_partial` where demo fallback, static content, or empty aggregators fill the UI.
- **Workflow creates are real:** Leave/expense **create** RPCs are implemented; packaging gap is overview + demo tenant completeness.
- **Org mixed CRUD (PR11.2):** Departments/positions support source-aware mixed CRUD — PULS-owned create/edit, imported/ERP-owned read-only. Demo seed must include **both** row classes.
- **AI Coach tension:** V1 spec = teaser not chat (implemented). Strategy = core value column (ambition). Neither implies product-ready until PR13.6.

## PR13.1 handoff

PR13.1 will:

1. Verify each row against `src/lib/data/**` and migrations
2. Assign completeness class per DB object
3. Add missing V1 sub-routes (`/izin/bekleyen`, `/haklar-uyum`, etc.) as `future_candidate` rows
4. Cross-link to PR12 OpenAPI ops where mutations exist

## References

- [`13_v1_product_packaging_strategy.md`](./13_v1_product_packaging_strategy.md)
- [`../data/11_sidebar_data_api_inventory.md`](../data/11_sidebar_data_api_inventory.md)
- [`../data/11_org_setup_crud_readiness_matrix.md`](../data/11_org_setup_crud_readiness_matrix.md)
- [`../data/12_app_api_boundary_inventory.md`](../data/12_app_api_boundary_inventory.md)
- [`../specs/05-frontend-sayfa-gelistirme-spec.md`](../specs/05-frontend-sayfa-gelistirme-spec.md)
