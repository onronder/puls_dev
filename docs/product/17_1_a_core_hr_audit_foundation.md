# PR17.1A — Core HR Audit Foundation

> **Status:** PR17.1 first implementation slice.
> **Scope:** Backend audit foundation only. No UI behavior, RLS, connector runtime, notification delivery, AI context, or source writeback changes.

## Why

PR17.0 identified that core HR and performance surfaces already mutate production data but do not leave a durable audit trail:

- `/departmanlar` creates and updates `puls_core.departments`.
- `/pozisyonlar` creates and updates `puls_core.positions`.
- Employee records can be changed by connector/import/service-role flows.
- `/performans` creates and activates `puls_performance.performance_cycles`.

This PR closes that audit gap before expanding Core HR closed-loop editing in PR17.1.

## What Changed

- Adds safe row-level audit triggers for:
  - `puls_core.departments`
  - `puls_core.positions`
  - `puls_core.employees`
  - `puls_performance.performance_cycles`
- Writes tenant-bound rows to `puls_audit.audit_logs`.
- Uses metadata-only audit payloads with allow-listed fields.
- Keeps names, emails, descriptions, raw payloads, credential values, and source snapshots out of audit metadata.
- Leaves existing UI, adapters, RLS, lifecycle guards, connector runtime, notification producers, and AI context untouched.

## Metadata Contract

Core HR audit metadata may include only operational identifiers and state fields:

- departments: `code`, `parent_id`, `manager_employee_id`, `cost_center_code`, `is_active`, `external_source`
- positions: `code`, `department_id`, `parent_position_id`, `employment_type`, `level`, `norm_headcount`, `is_active`, `external_source`
- employees: `employee_code`, `external_source`, `department_id`, `position_id`, `manager_employee_id`, `persona_role`, `employment_status`, `hire_date`, `termination_date`
- performance cycles: `status`, `starts_at`, `ends_at`, `scope`, `kpi_frequency`

The audit functions also add:

- `operation`
- `safe_row_audit`
- `changed_fields`

## Non-Goals

- No soft-delete/deactivate UI for departments or positions.
- No employee assignment editing UI.
- No company setup editing.
- No dashboard pending queue.
- No HR workflow notification producer.
- No AI Coach wiring.

Those remain later PR17 slices.

## Verification

Run:

```bash
bash scripts/verify-17-1-a-core-hr-audit-foundation.sh
```

The verify script checks the migration, trigger names, safe metadata allow-lists, forbidden payload/readback strings, docs, and README link.
