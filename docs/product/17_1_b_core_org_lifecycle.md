# PR17.1B — Core Org Lifecycle

> **Status:** PR17.1 second implementation slice.
> **Scope:** Department and position soft lifecycle only. No hard delete, employee assignment editing, connector runtime, source writeback, notification producer, or AI Coach wiring.

## Why

PR17.0 identified that `/departmanlar` and `/pozisyonlar` already create and update real org data, but admins could not safely retire or restore PULS-owned records. PR17.1A added row audit for these tables. PR17.1B adds the lifecycle action that audit can now record.

## What Changed

- Adds server-side lifecycle RPCs in `puls_core`:
  - `deactivate_department`
  - `restore_department`
  - `deactivate_position`
  - `restore_position`
- Allows lifecycle changes only for the current tenant admin.
- Allows lifecycle changes only for PULS-owned records; imported records remain read-only.
- Blocks unsafe deactivation:
  - departments with active employees
  - departments with active positions
  - positions with active employees
- Blocks unsafe restore:
  - departments whose parent department is inactive
  - positions whose linked department is inactive
- Adds typed frontend adapters and lifecycle error mapping.
- Adds compact active/inactive/all filters on `/departmanlar` and `/pozisyonlar`.
- Adds one lifecycle action inside the existing edit sheet.

## Product Contract

- Lifecycle is soft: only `is_active` changes.
- The list remains operational and compact; no technical runbook, release notes, or new explanatory panels are added.
- Source ownership is preserved: ERP/file/API-owned org records are not editable or lifecycle-managed from PULS.
- PR17.1A audit triggers record the lifecycle transition as metadata-only audit rows.

## Non-Goals

- No hard delete.
- No employee assignment editing.
- No lifecycle reason capture.
- No lifecycle history panel.
- No HR workflow notification producer.
- No AI context wiring.

Those remain later PR17 slices.

## Verification

Run:

```bash
bash scripts/verify-17-1-b-core-org-lifecycle.sh
```

The verify script checks the migration, server guardrails, adapter exports, compact UI wiring, i18n keys, README link, and no-hard-delete/no-raw-payload boundaries.
