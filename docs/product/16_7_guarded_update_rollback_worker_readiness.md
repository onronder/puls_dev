# PR16.7 Guarded Update Rollback Worker Readiness

PR16.7 creates the final guarded-update rollback worker handoff record after PR16.6 approval. It does not enqueue or execute rollback. The readiness record is immutable, approval-bound, checksum-bound, tenant-scoped, and safe for UI/AI read models.

## Scope

- Adds `connector_apply_rollback_worker_readiness` as the immutable rollback worker readiness ledger.
- Adds `generate_connector_guarded_update_rollback_worker_readiness` for admin/service-role readiness recording.
- Adds `list_connector_guarded_update_rollback_worker_readiness` for authenticated-safe UI and AI-safe read models.
- Requires an immutable rollback approval with matching rollback preview checksum.
- Rechecks current-state hashes at readiness generation time.
- Requires original guarded-update apply object events, field diffs, rollback snapshots, and active hot-retention windows.
- Shows rollback worker readiness status in `/erp`.

## Safety Contract

- Contract version is `pr16.7-guarded-update-rollback-worker-readiness-v1`.
- Readiness is admin-only and idempotent per rollback approval.
- Worker handoff readiness is enabled, but rollback job enqueue remains false.
- Rollback execution remains false.
- Canonical write, compensating execution, source writeback, provider calls, credential readback, raw payload readback, snapshot payload readback, and field value readback remain false.
- Readiness ledgers are immutable and service-role-only at table level; authenticated users use RPC safe summaries only.

## Out Of Scope

- Rollback worker execution.
- Rollback job enqueue.
- Compensating preview or compensating execution.
- ERP/source writeback.
- Raw rollback payload UI.
- Automatic conflict repair.

## Handoff To PR16.8

PR16.8 can implement rollback worker enqueue/execution only after it proves:

- readiness checksum still matches approval and rollback preview,
- current-state hashes are rechecked immediately before the write,
- rollback execution is service-role worker-only,
- rollback emits object events linked to the original apply event, rollback preview, approval, readiness, and worker job,
- rollback remains idempotent per readiness record and target object,
- source writeback, provider calls, credential readback, and raw value readback remain closed.
