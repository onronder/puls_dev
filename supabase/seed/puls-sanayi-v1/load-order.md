# Puls Sanayi V1 — FK-safe load order

**Numbered CSV filenames (`01_` … `22_`) are artifact identifiers, not load order.**

Use `manifest.json` → `loadOrder` for the FK-safe phase sequence below.

## Phase sequence

| Phase | File | Target |
|-------|------|--------|
| 1 | `01_tenant.csv` | `puls_core.tenants` |
| 2 | `16_erp_connections.csv` | `puls_integration.erp_connections` |
| 3 | `18_source_namespaces.csv` | `puls_integration.source_namespaces` |
| 4 | `02_legal_entities.csv` | `puls_core.legal_entities` |
| 5 | `03_locations.csv` | `puls_core.locations` |
| 6 | `10_cost_centers.csv` | `puls_core.cost_centers` |
| 7 | `04_departments.csv` | `puls_core.departments` (manager/cost_center may be post-updated) |
| 8 | `05_positions.csv` | `puls_core.positions` |
| 9 | `06_employees.csv` | `puls_core.employees` (no cache columns, no `user_id`) |
| 10 | `07_employee_reporting_lines.csv` | `puls_core.employee_reporting_lines` |
| 11 | `08_employee_legal_entity_assignments.csv` | assignments |
| 12 | `09_employee_location_assignments.csv` | assignments |
| 13 | `11_employee_cost_center_assignments.csv` | assignments |
| 14 | **post-load** | UPDATE `departments.manager_employee_id`, `departments.cost_center_id` |
| 15 | `13_approval_policies.csv` | policies + steps (multi-table) |
| 16 | `12_leave_types.csv` | `puls_workflow.leave_types` |
| 17 | `14_leave_balances.csv` | `puls_workflow.leave_balances` |
| 18 | `15_expense_categories.csv` | `puls_workflow.expense_categories` |
| 19 | `17_erp_field_mappings.csv` | `puls_integration.erp_field_mappings` |
| 20 | `19_entity_identity_map.csv` | `puls_integration.entity_identity_map` |
| 21 | `20_performance_cycles.csv` | `puls_performance.performance_cycles` |
| 22 | `21_performance_parameters.csv` | multi-table baseline context |
| 23 | `22_contracts.csv` | `puls_workflow.contracts` |

## Loader

Run from pack root with local `psql` (see `README.md`). Supabase SQL Editor cannot read local CSV paths.

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/01_load_puls_sanayi_seed.sql
```

## PR13.5 scenario layer (after baseline)

| Step | Script |
|------|--------|
| 1 | `03_generate_workflow_scenarios.sql` |
| 2 | `04_generate_performance_scenarios.sql` |
| 3 | `07_validate_packaging_proof.sql` |
| optional | `05_link_auth_personas_template.sql` → `06_jwt_mutation_proof_smoke.sql` |
