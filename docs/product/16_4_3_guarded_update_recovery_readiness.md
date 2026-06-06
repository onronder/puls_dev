# PR16.4.3 Guarded Update Recovery Readiness

PR16.4.3 closes the guarded-update apply loop without opening rollback execution. It adds a safe post-apply recovery readiness read model so admins can verify that every guarded update has the expected object event, field diff evidence, rollback snapshot posture, and retention window before PR16.5 rollback preview work begins.

## Scope

- Adds `list_connector_guarded_update_recovery_readiness(UUID, INTEGER)` as an authenticated-safe read model.
- Reports guarded update recovery status after PR16.4.2 worker apply.
- Verifies applied batch state, update object events, hash-only field diffs, rollback snapshots, hot retention, and purge/archive posture.
- Exposes `/erp` recovery readiness as counts, retention dates, next action, and safe object-event summaries only.
- Updates the apply safety contract to `pr16.4.3-guarded-update-recovery-readiness-v1` while keeping the proven PR16.4.2 worker executor contract unchanged.

## Still Closed

- Rollback execution.
- Compensating update execution.
- ERP/source writeback.
- Provider API calls.
- Credential readback.
- Field value readback.
- Raw payload readback.
- Browser direct apply.
- Authenticated direct canonical write RPCs.
- AI autonomous apply.

## Safety Contract

- Recovery readiness is read-only and does not mutate canonical data.
- The read model returns no before/after values and no rollback snapshot payload.
- Object events remain the canonical post-apply audit proof.
- Field diffs remain hash-only.
- Rollback snapshots stay service-role-only and retention-limited.
- If snapshots are outside hot retention, the next action is a compensating review runbook instead of pretending rollback is ready.
- PR16.5 can start rollback preview only from `recovery_ready` status.

## Handoff To PR16.5

PR16.5 can implement rollback or compensating preview only after PR16.4.3 proves:

- applied guarded updates have one object event per updated row,
- field diff count and rollback snapshot count match guarded update count,
- stale recheck evidence is present,
- hot retention has not expired,
- rollback execution is still explicitly closed,
- UI/AI receive only safe summaries.
