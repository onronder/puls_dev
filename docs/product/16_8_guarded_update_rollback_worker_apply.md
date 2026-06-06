# PR16.8 Guarded Update Rollback Worker Apply

PR16.8 opens the first rollback execution path for previously applied guarded updates. It is worker-only, service-role-only, readiness-bound, approval-bound, checksum-bound, and limited to safe reference-dimension `name` restores from rollback snapshots.

## Scope

- Adds `enqueue_connector_guarded_update_rollback_apply_job` for admin/service-role rollback worker queueing.
- Adds `execute_connector_guarded_update_rollback_apply_job` for service-role worker execution.
- Adds `_connector_apply_validate_guarded_update_rollback_readiness` to revalidate PR16.7 readiness, approval, preview, checksum, original apply event, active retention, and current-state hashes immediately before enqueue/execution.
- Adds `_connector_apply_restore_reference_name` to restore only safe reference-dimension `name` values from hash-verified rollback snapshots.
- Extends rollback object events so rollback writes can be audited beside the original guarded-update apply event.
- Routes `import_apply_guarded_update_rollback` jobs through the ERP connector worker.
- Adds `/erp` rollback worker queue visibility and admin queue action.

## Safety Contract

- Contract version is `pr16.8-guarded-update-rollback-worker-apply-v1`.
- Browser direct rollback remains closed.
- Authenticated users can enqueue only after admin permissions and PR16.7 readiness are verified.
- Execution requires service-role worker lease ownership.
- Canonical write opens only inside `execute_connector_guarded_update_rollback_apply_job`.
- Rollback writes are limited to reference dimensions and the safe mutable field `name`.
- Source writeback, provider API calls, credential readback, raw payload readback, field value readback, and snapshot payload readback remain closed.
- Rollback object events include readiness, approval, preview, change-set, original apply event, worker job, counts, and boundary flags without exposing snapshot payload values.

## Out Of Scope

- Destructive rollback operations.
- Employee record rollback.
- Compensating execution.
- ERP/source writeback.
- Provider API calls.
- Browser direct canonical rollback.
- Snapshot or field value display in UI/AI.

## Verification

- Queue RPC rejects missing admin permission, invalid readiness, drift, expired snapshots, missing field diffs, and missing original apply events.
- Execute RPC rejects non-service-role callers and jobs not owned by the worker lease.
- Current-state hash is rechecked inside execution before every write.
- Rollback emits one `rollback` object event per rollback preview item.
- Re-running the same worker job is idempotent when its rollback events already exist.
- A second job cannot re-apply the same rollback.
- `/erp` can queue the rollback worker only when PR16.7 readiness is ready.

## Handoff To PR16.9

PR16.9 can build post-rollback confirmation and notification surfaces after proving:

- rollback object events can be shown without raw snapshot payload,
- runtime queue outcomes are visible to admins,
- rollback completion is linked to the original guarded-update apply event,
- no source writeback or provider call is implied by rollback completion.
