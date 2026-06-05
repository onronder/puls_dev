# PR16.3 Create-Only Apply Context Hardening

PR16.3A hardens the worker lease heartbeat path after production smoke showed the job heartbeat could replace the queue-time `safe_error_context` before the create-only execution RPC revalidated the job.

## What Changes

- `heartbeat_connector_job` now preserves existing `connector_jobs.safe_error_context` and only merges additional heartbeat metadata without overriding queue-time contract keys.
- The Railway worker sends an empty job heartbeat safe context; worker liveness and capability evidence remains on `connector_worker_heartbeats`.
- PR16.3 execution still requires service-role, `import_apply_create_only` scope, admin-reviewed change-set evidence, create-only reference rows, canonical writes only, and no source writeback or credential/raw payload readback.

## Smoke Finding

The failed smoke job stopped before canonical writes:

- `connector_jobs.status = failed`
- `import_batches.applied_at IS NULL`
- no object events were produced for the change-set

The failed job should remain as audit evidence. Re-run smoke with a fresh ref-only batch/change-set after this migration and worker update are deployed.

## Verify

Run:

```bash
scripts/verify-16-3-create-only-context-hardening.sh
pnpm test -- --run services/erp-connector/src/worker.test.ts
pnpm run typecheck
```
