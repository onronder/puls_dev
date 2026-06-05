# PR16.4.1 Guarded Update Evidence

PR16.4.1 is the first guarded-update step after create-only apply. It prepares the evidence needed to safely discuss an overwrite, but it does **not** execute updates.

## Scope

- Adds immutable hash-only field diffs in `connector_apply_field_diffs` for guarded update rows.
- Adds service-role-only `connector_apply_rollback_snapshots` ledger for rollback preparation.
- Generates evidence only from an existing PR16.2 change-set with `guarded_overwrite` rows.
- Allows only reference-dimension `name` changes in this step; `code` is an identity guard and must not change.
- Blocks stale hash, destructive-equivalent fields, source conflict rows, employee updates, assignment/status/manager updates, deletes, restores, rollback execution, ERP writeback, provider API calls, credential readback, raw payload readback, and AI autonomous apply.
- Exposes `/erp` UI evidence as counts, field names, hash availability, retention metadata, and safe status only.

## Safety Contract

- `generate_connector_guarded_update_evidence(UUID)` is admin/service-role only.
- `list_connector_guarded_update_evidence(UUID, INTEGER)` is authenticated-safe and returns no values.
- Field diffs store `before_value_hash` and `after_value_hash`, not before/after values.
- Rollback snapshots are retained in a service-role-only table and are not exposed to authenticated clients.
- Both evidence ledgers are immutable after insert.
- Hot retention defaults to 90 days; purge/archive policy remains required before broad rollout.
- Canonical update execution stays closed and no worker update job is introduced.

## Handoff To PR16.4.2

PR16.4.2 can consider worker-only guarded update execution only after this evidence layer proves:

- every guarded update row has a rollback snapshot,
- every mutable field has a hash-only diff,
- immutable guard fields did not change,
- current hash still matches the preview expectation,
- admin approval and batch lock are present,
- object event audit for update attempts/results is ready.

Until then, PR16.4.1 is review evidence only.
