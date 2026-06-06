# PR16.6 Guarded Update Rollback Approval

PR16.6 records admin approval for a PR16.5 guarded-update rollback preview without executing rollback. The approval is immutable, checksum-bound, tenant-scoped, and safe for UI/AI read models.

## Scope

- Adds `connector_apply_rollback_approvals` as the immutable rollback approval ledger.
- Adds `record_connector_guarded_update_rollback_approval` for admin/service-role approval recording.
- Adds `list_connector_guarded_update_rollback_approvals` for authenticated-safe UI and AI-safe read models.
- Requires the rollback preview to be `ready_for_rollback_review`.
- Requires zero preview blockers, zero stale blockers, available rollback snapshots, field diffs, and matching current-state hashes.
- Stores the rollback preview checksum on the approval record so future execution can verify approval against the exact preview.
- Shows rollback approval status in `/erp`.

## Safety Contract

- Contract version is `pr16.6-guarded-update-rollback-approval-v1`.
- Approval is admin-only and idempotent per rollback preview.
- Rollback approval is enabled, but rollback execution remains false.
- Compensating execution remains false.
- Source writeback, credential readback, raw payload readback, snapshot payload readback, and field value readback remain false.
- Approval ledgers are immutable and service-role-only at table level; authenticated users use RPC safe summaries only.

## Out Of Scope

- Rollback worker execution.
- Rollback job enqueue.
- Compensating preview or compensating execution.
- ERP/source writeback.
- Raw rollback payload UI.
- Automatic conflict repair.

## Handoff To PR16.7

PR16.7 can implement rollback worker execution only after it proves:

- approval checksum matches the immutable rollback preview checksum,
- preview items still have no blockers,
- current-state hashes are rechecked immediately before write,
- rollback execution is service-role worker-only,
- rollback emits object events linked to the original apply event, rollback preview, approval, and worker job,
- source writeback, provider calls, credential readback, and raw value readback remain closed.
