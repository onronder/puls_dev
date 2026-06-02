# PR14.10 Mapping Discovery

PR14.10 turns connector setup from a selected source into a visible field contract. It connects known source fields to canonical PULS data classes without running import, sync, credential capture, or ERP writes.

## What PR14.10 Proves

- Mapping discovery uses `puls_integration.erp_field_mappings` as the tenant-scoped field contract.
- Canias and CSV / Excel setup drafts can create deterministic default mapping rows.
- Canonical PULS data classes show required-field completeness for employees, departments, positions, cost centers, and locations.
- `/erp` can show the mapping contract after refresh because the contract is persisted in the database.
- Dashboard status can say fields are ready without implying preflight or runtime readiness.

## What PR14.10 Does Not Prove

- No connector import execution.
- No live Canias API call.
- No CSV file upload execution.
- No credential capture or secret storage.
- No ERP write-back.
- No mapping editor that lets users change fields manually.

## Product Boundary

Mapping discovery is source-independent. Canias is the first provider with seed-proven generic fields, but the product model is the same for CSV / Excel and future providers.

The canonical data model is the stable product boundary. External source fields do not become product behavior until they are mapped to PULS canonical fields.

## Canonical Data Classes

| Class | PULS target | Required proof |
|-------|-------------|----------------|
| Employees | `puls_core.employees` | `employee_code`, `full_name` |
| Departments | `puls_core.departments` | `code`, `name` |
| Positions | `puls_core.positions` | `code`, `name` |
| Cost centers | `puls_core.cost_centers` | `code`, `name` |
| Locations | `puls_core.locations` | Optional location code coverage |

## Default Mapping Contracts

Canias default mapping uses only seed-proven generic fields from PR13.4 / PR13.7: `EMPLOYEE_CODE`, `FULL_NAME`, `EMAIL`, `HIRE_DATE`, `DEPT_CODE`, `DEPT_NAME`, `MANAGER_CODE`, `POS_CODE`, `POS_NAME`, `CC_CODE`, `CC_NAME`, and `LOC_CODE`.

CSV / Excel default mapping uses neutral template header names such as `employee_code`, `full_name`, `department_code`, `position_code`, and `cost_center_code`.

These are discovery defaults, not customer truth. Customer-specific field names remain future mapping-editor work.

## Acceptance Criteria

- Admin starts a connector setup draft and default mapping rows are written idempotently.
- Existing mapping rows are not overwritten.
- The connection moves to `mapping_ready` and `namespace` step only after the mapping contract exists.
- `/erp` shows canonical class completion and the explicit source-to-PULS field contract.
- `/dashboard` reflects mapping-ready setup separately from preflight-ready or connected states.
- No migrations are required because PR14.10 uses the existing `erp_field_mappings` table and existing admin RLS policies.
- No runtime sync, import apply, credential reference, or ERP write path is introduced.

## Handoff To PR14.11

PR14.11 can run dry-run preflight against this persisted mapping contract. It should validate namespace readiness, identity strategy, required-field completion, and credential-boundary posture without moving data.
