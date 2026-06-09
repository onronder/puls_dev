# PR17.1C — Employee Assignment Edit

> **Status:** PR17.1 third implementation slice.
> **Scope:** PULS-owned employee assignment editing only. No employee create, hard delete, connector runtime, source writeback, notification producer, or AI Coach wiring.

## Why

PR17.0 identified `/calisanlar` as a read-only page even though employee assignment readiness already drove leave and expense workflows. PR17.1A added Core HR audit coverage, and PR17.1B made organization records lifecycle-safe. PR17.1C closes the next loop: admins can correct PULS-owned employee assignments without touching imported employee master data.

## What Changed

- Adds `puls_core.update_employee_assignment(...)` as the single server-side write path.
- Allows assignment changes only for current-tenant admins.
- Allows assignment changes only for active, PULS-owned employees.
- Validates active same-tenant department, position, cost center, and manager references.
- Validates position-to-department compatibility.
- Validates manager self-reference and reporting cycles.
- Updates the reporting-line and cost-center assignment source-of-truth tables instead of bypassing their cache triggers.
- Writes metadata-only assignment audit evidence to `puls_audit.audit_logs`.
- Adds typed frontend adapters, assignment options, error mapping, and compact `/calisanlar` sheet editing.

## Product Contract

- `/calisanlar` remains a compact employee assignment workbench.
- A selected PULS-owned active employee can be edited from the existing detail sheet.
- Imported, demo, inactive, or unauthorized rows stay read-only.
- The edit form has one primary action: save assignments.
- No raw payload, credential, connector execution, ERP writeback, source writeback, or technical runbook is shown in the UI.

## Non-Goals

- No employee create or delete.
- No document upload.
- No HR workflow notification producer.
- No AI context wiring.
- No employee personal profile editing.
- No imported employee writeback.

## Verification

Run:

```bash
bash scripts/verify-17-1-c-employee-assignment-edit.sh
```

The verify script checks the migration RPC, server guardrails, adapter exports, source-aware UI wiring, i18n keys, README link, and no-writeback boundaries.
