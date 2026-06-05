# PR16.1 Apply Safety Contract And Permission Hardening

Date: 5 June 2026

## Summary

PR16.1 is the first implementation step after the PR16 safety plan. It does not apply imports, does not write canonical records, does not run Canias, and does not write back to ERP/source systems.

The goal is to close the legacy direct apply surface and make the future apply contract inspectable from `/erp` and AI-safe runtime evidence.

## Product Boundary

| Boundary                    | PR16.1 behavior                                                                                    |
| --------------------------- | -------------------------------------------------------------------------------------------------- |
| Browser direct apply        | Closed. The app does not call `apply_import_batch`.                                                |
| Authenticated apply RPC     | Closed. `apply_import_batch(UUID, TEXT)` is service-role only.                                     |
| Worker `import_apply` queue | Closed. `connector_jobs` rejects `import_apply` until PR16 create-only gates exist.                |
| Canonical writes            | Closed. No create, update, delete, restore, rollback, or compensating update runs.                 |
| CRUD audit model            | Defined as safety contract evidence: object event, field diff, rollback snapshot, archive summary. |
| Retention policy            | Field diff and rollback snapshot hot retention default to 90 days.                                 |
| UI/AI evidence              | Safe summary only; no raw payload, provider response, credential value, or secret reference.       |

## Database Changes

- Adds `connector_apply_policy_state` enum:
  - `create_only`
  - `guarded_update`
  - `blocked_destructive`
  - `rollback_preview_required`
- Adds `connector_apply_operation` enum:
  - `insert`
  - `update`
  - `soft_delete`
  - `restore`
  - `rollback`
  - `compensating_update`
- Adds `connector_apply_audit_tier` enum:
  - `object_event`
  - `field_diff`
  - `rollback_snapshot`
  - `archive_summary`
- Adds `reject_closed_import_apply_job()` trigger function and `puls_integration_connector_jobs_import_apply_closed` trigger.
- Adds `list_connector_apply_safety_contracts(p_connection_id)` as authenticated-safe read model.
- Revokes authenticated/anon execution from `apply_import_batch(UUID, TEXT)` and keeps it service-role only.

## `/erp` Read Model

The ERP workbench now exposes `applySafetyContract` and upgrades the execution contract version to `pr16.1-apply-safety-contract-v1`.

The visible controls include:

- Direct apply RPC: service-role only.
- Worker apply gate: `import_apply` closed.
- CRUD audit policy: object event plus field diff.
- Retention policy: 90-day hot retention for field diffs and rollback snapshots.

These are evidence controls only. They do not add an apply button, enqueue a job, claim a job, or write canonical data.

## Acceptance Criteria

- `apply_import_batch(UUID, TEXT)` is not executable by `authenticated` or `anon`.
- `import_apply` cannot be inserted into `connector_jobs`.
- `/erp` can show the PR16.1 safety contract without exposing payloads or credentials.
- Existing preview, human review, and admin approval audit actions still do not call apply.
- AI-safe evidence can explain why apply execution remains closed.

## PR16.2 Handoff

PR16.2 can now build immutable change-sets and before snapshots on top of this closed contract. It must not open canonical writes until change-set, source ownership, stale hash, field diff, retention, and approval evidence are proven.
