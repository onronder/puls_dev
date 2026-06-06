# PR16.4.4 Guarded Update Recovery Runbook

PR16.4.4 turns PR16.4.3 recovery readiness into an operator-facing safe runbook before PR16.5 rollback preview. It does not open rollback preview, rollback execution, compensating execution, source writeback, provider calls, credential readback, raw payload readback, or field value readback.

## Scope

- Adds `list_connector_guarded_update_recovery_runbooks(UUID, INTEGER)` as an authenticated-safe read model.
- Classifies applied guarded updates into `ready_for_rollback_preview`, `needs_apply`, `evidence_gap`, or `compensating_review_required`.
- Returns recommended safe action, blocker codes, evidence counts, retention metadata, and safe runbook steps.
- Exposes `/erp` recovery runbook status without showing before/after values or rollback snapshot payloads.
- Updates the apply safety contract to `pr16.4.4-guarded-update-recovery-runbook-v1`.

## Still Closed

- Rollback preview generation.
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

- A runbook can mark a change-set as a rollback-preview candidate, but rollback_preview_enabled remains false.
- Operator review and approval remain required before PR16.5 can generate any rollback preview.
- Evidence gaps route to `regenerate_guarded_update_evidence`.
- Expired hot retention routes to `prepare_compensating_review_runbook`.
- Safe steps contain only counts, blocker codes, and next action keys.

## Handoff To PR16.5

PR16.5 may implement rollback preview only after PR16.4.4 proves:

- the guarded update batch is applied,
- object event count matches updated row count,
- field diff count and rollback snapshot count match guarded update count,
- hot rollback snapshot retention is still valid,
- the operator runbook marks the change-set as `ready_for_rollback_preview`,
- rollback preview/execution flags remain explicitly closed until PR16.5.
