# PR13.1 — DB Table Completeness Classes

Classification of product-facing DB objects for DB-backed demo packaging. **Not every table must be non-empty** — use completeness classes consistently.

**Documentation-only.** PR13.3 will specify demo company seed against this inventory.

## Executive summary

PULS v1.0 packaging proof requires a **DB-backed demo tenant** with baseline rows for `required seeded` objects and scenario scripts for `required scenario-generated` workflow artifacts. Calc views in `puls_calc` are **derived** — seed underlying base tables, not the views directly.

## Classification rules

| Class | Demo packaging rule |
|-------|---------------------|
| `required seeded` | Must exist in demo tenant for V1 proof |
| `required scenario-generated` | Created by workflow/bootstrap/smoke scripts after seed |
| `readable empty-ok` | Zero rows is valid UX; do not require for packaging signoff |
| `future/not V1` | Document only; not required for V1 |
| `sensitive/system` | Not part of demo narrative; indirect or auth-linked seed only |

Source ownership: distinguish PULS-owned (`external_source` null) vs imported/ERP-owned rows per [`../data/11_org_setup_crud_readiness_matrix.md`](../data/11_org_setup_crud_readiness_matrix.md).

## Currently observed product-facing calc views

Derived views in `puls_calc` (confirmed in migrations + adapters):

| View | Primary consumers | Underlying seed domains |
|------|-------------------|-------------------------|
| `dashboard_overview` | `/dashboard`, performance overview, contracts | employees, workflows, ERP metadata |
| `employee_list_overview` | `/calisanlar` | `puls_core.employees` |
| `organization_overview` | `/departmanlar`, `/pozisyonlar` | departments, positions |
| `leave_overview` | `/izin`, profile | leave types, balances, requests |
| `expense_overview` | `/masraf`, profile, dashboard | expense categories, claims |
| `performance_overview` | `/performans`, profile | cycles, evaluations, templates |
| `contracts_overview` | `/sozlesmeler` | `puls_workflow.contracts` |
| `setup_readiness_summary` | `/sirket-kurulum`, `/erp` | org, assignments, ERP mappings |
| `menu_overview` | `/menu` | tenant employee/dept/position counts |

Count may change as migrations evolve — treat as **currently observed minimum product-facing calc views**.

## Required seeded objects

| Schema | Object | Why | Demo requirement | Source ownership | Follow-up PR |
|--------|--------|-----|------------------|------------------|--------------|
| `puls_core` | `tenants` | Tenant context for all routes | Canonical demo company row | PULS-owned | PR13.3 |
| `puls_core` | `employees` | Directory, profile, calc views | 20-40 employees linked to auth personas | PULS-owned + optional imported | PR13.3 |
| `puls_core` | `departments` | Org UI, mixed CRUD | PULS-owned + imported examples | Mixed | PR13.3 |
| `puls_core` | `positions` | Org UI, mixed CRUD | PULS-owned + imported examples | Mixed | PR13.3 |
| `puls_core` | `cost_centers` | Expense category readiness | Baseline cost centers | PULS-owned or imported | PR13.3 |
| `puls_workflow` | `leave_types` | Leave setup + create RPC | Types with policies | PULS-owned | PR13.3 |
| `puls_workflow` | `approval_policies` | Policy binding for leave/expense | At least one active policy per domain | PULS-owned | PR13.3 |
| `puls_workflow` | `expense_categories` | Expense setup + create RPC | Categories with limits | PULS-owned | PR13.3 |
| `puls_performance` | `performance_cycles` | Performance UI + params route | At least one draft/active cycle | PULS-owned | PR13.3 |
| `puls_performance` | `competency_templates` | Performance params/overview | Template rows | PULS-owned | PR13.3 |
| `puls_workflow` | `contracts` | Contracts metadata surface | Summary contract rows | PULS-owned or imported metadata | PR13.3 |
| `puls_integration` | `erp_connections` | ERP setup (Canias) | Inactive configured connection | PULS config | PR13.3 |
| `puls_integration` | `erp_field_mappings` | ERP readiness display | Sample non-sensitive mappings | PULS config | PR13.3 |
| `puls_workflow` | `leave_balances` | Leave create/readiness | Balances per employee/type | PULS-owned | PR13.5 |

## Required scenario-generated objects

| Schema | Object | Why | Demo requirement | Follow-up PR |
|--------|--------|-----|------------------|--------------|
| `puls_workflow` | `leave_requests` | Workflow narrative, approvals | Optional pending/approved via RPC smoke | PR13.5 |
| `puls_workflow` | `expense_claims` | Workflow narrative | Optional pending claims via RPC smoke | PR13.5 |
| `puls_workflow` | `approval_requests` | Decide-approval contract smoke | Pending approver scenarios | PR13.5 |
| `puls_workflow` | `leave_type_lifecycle_events` | Admin lifecycle audit | Created by deactivate/restore smoke | PR13.5 |
| `puls_workflow` | `expense_category_lifecycle_events` | Admin lifecycle audit | Created by deactivate/restore smoke | PR13.5 |
| `puls_performance` | `competency_evaluations` | Performance overview richness | Optional evaluation rows post-cycle seed | PR13.5 |
| `puls_performance` | `performance_scores` | Performance overview KPIs | Optional score rows tied to cycles | PR13.5 |

## Readable empty-ok objects

| Schema | Object | Why |
|--------|--------|-----|
| `puls_integration` | `import_batches`, `import_records`, `import_field_violations` | No import scenario in baseline demo |
| `puls_integration` | `erp_sync_batches`, `erp_staging_records` | Sync history optional |
| `puls_integration` | `entity_identity_map`, `source_namespaces` | Present when import demo needed; else empty OK |
| `puls_audit` | `audit_logs` | System trail; not narrative |
| `puls_performance` | `training_needs`, `career_profiles` | Weak V1 depth; honest empty OK |
| `puls_workflow` | `leave_documents`, `expense_receipts` | Attachment metadata optional in demo |

## Future / not V1 objects

| Schema | Object | Why |
|--------|--------|-----|
| `puls_core` | `authority_pools`, `authority_relationships` | Enterprise authority graph — future depth |
| `puls_vault` | AI execution / tool-call tables (if added) | PR13.6+ scope |
| External CRM connectors | N/A in current migrations | Future candidate per strategy |

## Sensitive / system objects

| Schema | Object | Why | Demo posture |
|--------|--------|-----|--------------|
| `puls_vault` | `conversation_messages` | AI vault — not V1 teaser content | Do not seed narrative |
| `puls_audit` | `audit_logs` | Compliance trail | System-generated only |
| Auth | `auth.users` / employee link | Persona login | Indirect via bootstrap runbook |
| `puls_integration` | ERP credentials / secrets | Never in demo CSV | Config-only, inactive |

## Calc views / derived views posture

- Views are **read models** — packaging validates underlying table seed + RLS, then confirms calc output via route smoke.
- Do not INSERT directly into `puls_calc.*` views in demo bootstrap.
- Legacy [`supabase/seed-demo.sql`](../../supabase/seed-demo.sql) targets `public.*` — PR13.3+ must target `puls_*` base tables.

## Product-facing table coverage gaps

| Gap | Impact | Owner PR |
|-----|--------|----------|
| No `puls_*` demo bootstrap | All routes rely on demo fallback or empty UX | PR13.3, PR13.5 |
| Imported org row examples missing | Source-aware mixed CRUD not provable | PR13.3 |
| Scenario scripts undefined | Approval/workflow packaging incomplete | PR13.5 |
| Performance evaluation rows sparse | Overview remains demo-heavy | PR13.3, PR13.5 |

## PR13.3 handoff

PR13.3 will produce the demo company data spec mapping each `required seeded` object to CSV/SQL bootstrap rows with completeness class and source ownership.

## References

- [`13_feature_db_coverage_inventory.md`](./13_feature_db_coverage_inventory.md)
- [`13_demo_data_packaging_principles.md`](./13_demo_data_packaging_principles.md)
- [`../data/PULS_TECHNICAL_IMPLEMENTATION_PLAN.md`](../data/PULS_TECHNICAL_IMPLEMENTATION_PLAN.md)
