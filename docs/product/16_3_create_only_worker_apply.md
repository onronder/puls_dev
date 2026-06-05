# PR16.3 Create-Only Worker Apply

Date: 5 June 2026

## Executive Summary

PR16.3 opens the first controlled canonical write path for connector data. It is deliberately narrow: admin-approved, previewed, immutable change-set rows can be queued to the Railway worker only when every row is a create-only reference-dimension insert.

In product terms, this is a worker-only create apply milestone, not a general import execution launch.

This PR does not open browser direct apply, authenticated direct canonical writes, existing-record updates, employee imports, destructive actions, credential readback, provider API calls, ERP/source writeback, or AI autonomous action.

## Product Boundary

| Boundary | PR16.3 behavior |
| --- | --- |
| Canonical writes | Open only inside service-role worker execution |
| Browser direct apply | Closed |
| Authenticated direct apply RPC | Closed |
| Worker `import_apply` | Open only for PR16.3 create-only jobs |
| Existing record overwrite | Closed |
| Employee import/apply | Closed |
| ERP/source writeback | Closed |
| Credential readback | Closed |
| Raw payload readback | Closed |
| AI autonomous action | Closed |

## What PR16.3 Adds

- `connector_apply_object_events` as a safe object-level audit ledger for create-only canonical inserts.
- `enqueue_connector_create_only_apply_job(change_set_id)` admin-safe RPC that queues, but does not directly write data.
- `execute_connector_create_only_apply_job(job_id, worker_id)` service-role worker RPC that revalidates the change-set before writing.
- PR16.3 replacement for the `import_apply` closed-job trigger, allowing only the create-only worker contract.
- Worker support for `import_apply` behind `PULS_CONNECTOR_WORKER_IMPORT_APPLY_ENABLED=true`.
- `/erp` execution contract that enables the queue action only when preview, approval, change-set, and worker gates are all ready.
- Safe activity records and connector job completion context without secrets, raw payloads, provider responses, or field values.

## Business Rules

- The source batch must be `dry_run`, `previewed`, clean, and checksum-matched to the change-set.
- Admin approval must be recorded after the preview/change-set evidence.
- The change-set must be `ready_for_create_only_review`.
- Every row must be `risk_class = create_only`, `operation = insert`, unblocked, and within reference-dimension scope.
- Supported PR16.3 entities are `legal_entity`, `location`, `cost_center`, `department`, and `position`.
- `employee`, guarded update, delete, restore, rollback, and source writeback remain closed.
- If target resolution finds an existing canonical record, the worker fails safely instead of updating.
- Object audit is mandatory for every created record.

## Railway Operations

PR16.3 requires a deliberate Railway env change before worker apply jobs can be claimed:

```bash
PULS_CONNECTOR_WORKER_IMPORT_APPLY_ENABLED=true
PULS_CONNECTOR_WORKER_JOB_TYPES=noop_health,connector_runtime_preflight,import_apply
```

Keep the worker at one replica until PR16 guarded updates and broader rollback flows are proven. Provider API credentials still do not belong in this service for PR16.3.

## Verification

- App code still does not call `apply_import_batch`.
- Authenticated users can enqueue only through `enqueue_connector_create_only_apply_job`.
- Worker execution is service-role only.
- Direct/import apply jobs with any other contract are rejected.
- Create-only jobs require admin approval, change-set checksum, batch scope, and single attempt.
- Employee rows or update-like rows cannot be queued for PR16.3.
- Object events contain safe metadata only.
- AI receives only safe job/activity/object-event evidence, not raw source data.

## Handoff To PR16.4

PR16.4 can add guarded updates only after field diff, stale-hash check, rollback snapshot, object event, and approval gates are proven for update paths. PR16.3 intentionally proves the write path with low-risk reference inserts first.
