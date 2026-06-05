# PR16.4.2 Guarded Update Worker Apply

PR16.4.2 opens the first guarded-update canonical write path. It is a worker-only guarded update apply step. It keeps the PR16.4.1 evidence discipline intact and allows only admin-approved, worker-only, stale-hash-guarded reference-dimension `name` updates.

## Scope

- Adds `enqueue_connector_guarded_update_apply_job(UUID)` for admin/service-role queueing.
- Adds `execute_connector_guarded_update_apply_job(UUID, TEXT)` for service-role worker execution.
- Reuses `import_apply` only when the job safe context is `pr16.4.2-guarded-update-worker-apply-v1` and `apply_mode=guarded_update`.
- Revalidates admin approval, dry-run preview status, source checksum, guarded change-set counts, PR16.4.1 field diffs, rollback snapshots, lease ownership, and expected current hash immediately before writing.
- Updates only reference-dimension `name` fields for `legal_entity`, `location`, `cost_center`, `department`, and `position`.
- Writes object event audit for every successful update and links it to the worker job, change-set item, import record, field diff, and rollback snapshot evidence.
- Extends the Railway worker to route guarded update jobs by safe context while preserving the PR16.3 create-only path.
- Adds `/erp` queue gating so admins can queue guarded update apply only when evidence, rollback snapshots, approval, and worker gates are ready.

## Still Closed

- Browser direct apply.
- Authenticated direct canonical write RPCs.
- Employee master updates.
- Destructive-equivalent fields such as `is_active`, employment status, assignment close, manager reporting line, and explicit clear.
- ERP/source writeback.
- Provider API calls.
- Credential readback.
- Raw payload readback.
- Field value readback.
- Rollback execution.
- AI autonomous apply.

## Safety Contract

- Queueing is authenticated-admin safe but execution is service-role-only.
- Worker completion reports canonical write success only after the database RPC has written and audited the update.
- Stale targets fail before mutation because the current hash must match the PR16.2/PR16.4.1 expectation.
- Rollback snapshots stay service-role-only; UI and AI receive evidence counts and hash availability, not values.
- `import_apply` remains closed for any job outside the PR16.3 create-only or PR16.4.2 guarded-update contracts.

## Railway

No new Railway job type is required. Keep:

```text
PULS_CONNECTOR_WORKER_IMPORT_APPLY_ENABLED=true
PULS_CONNECTOR_WORKER_JOB_TYPES=noop_health,connector_runtime_preflight,import_apply
```

The worker chooses `execute_connector_create_only_apply_job` or `execute_connector_guarded_update_apply_job` from the queued job safe context.

## Handoff To PR16.5

PR16.5 can broaden guarded updates only after PR16.4.2 smoke proves:

- guarded update jobs cannot bypass evidence,
- stale target hashes block execution,
- object events are written for every update,
- rollback snapshots remain service-role-only,
- create-only jobs still route through the PR16.3 executor,
- no source writeback or credential/readback boundary opens.
