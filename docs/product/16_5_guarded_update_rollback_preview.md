# PR16.5 Guarded Update Rollback Preview

PR16.5 starts rollback safely by opening preview generation only. It turns a PR16.4.4 `ready_for_rollback_preview` runbook into immutable rollback-preview evidence without executing rollback, compensating updates, ERP/source writeback, provider calls, credential readback, raw payload readback, snapshot payload readback, or field value readback.

## Scope

- Adds immutable `connector_apply_rollback_previews` and `connector_apply_rollback_preview_items` ledgers.
- Adds `generate_connector_guarded_update_rollback_preview` for admin/service-role rollback preview generation.
- Adds `list_connector_guarded_update_rollback_previews` for authenticated-safe UI and AI-safe read models.
- Classifies rollback preview items with blocker codes such as `current_state_drift`, `current_hash_missing`, `field_diff_missing`, and `rollback_snapshot_unavailable`.
- Keeps preview output hash-only: safe field names, rollback field names, hash availability, counts, blocker codes, retention dates, and safe summaries.

## Safety Contract

- Contract version is `pr16.5-guarded-update-rollback-preview-v1`.
- Rollback preview can be generated only after the PR16.4.4 runbook is ready.
- Admin approval must already be recorded before preview generation.
- Rollback preview is enabled, but rollback execution remains false.
- Compensating execution remains false.
- Source writeback, credential readback, raw payload readback, snapshot payload readback, and field value readback remain false.
- Preview ledgers are immutable and service-role-only at table level; authenticated users read safe summaries through RPC only.

## Out Of Scope

- Rollback execution.
- Compensating preview or compensating execution.
- ERP/source writeback.
- Raw rollback payload UI.
- Automatic cross-source conflict repair.

## Handoff To The Next PR16.5 Step

The next PR16.5 step can implement rollback approval and worker execution only after this preview layer proves:

- every rollback preview item links to an applied guarded update item,
- rollback snapshot and field diff evidence are present,
- current state still matches the post-apply source hash,
- blocked preview items stay non-executable,
- rollback audit can link original apply event, rollback preview, future approval, worker job, and result.
