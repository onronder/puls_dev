# PR16.2 Apply Change-Set And Risk Ledger

Date: 5 June 2026

## Executive Summary

PR16.2 turns a previewed dry-run import batch into immutable apply decision evidence. It lets an admin see create/update/skip intent, blocked overwrite risks, stale preview risk, source conflict risk, audit tier, and retention bucket before any canonical write can open.

This PR does not execute apply. It does not create connector `import_apply` jobs, write canonical data, write back to ERP, read credentials, expose raw payloads, or give AI an execution path.

## Product Boundary

| Boundary              | PR16.2 behavior |
| --------------------- | --------------- |
| Canonical writes      | Closed          |
| Browser direct apply  | Closed          |
| Worker `import_apply` | Closed          |
| ERP/source writeback  | Closed          |
| Credential readback   | Closed          |
| Raw payload readback  | Closed          |
| AI autonomous action  | Closed          |

## What PR16.2 Adds

- Immutable `connector_apply_change_sets` header for a previewed dry-run batch.
- Immutable `connector_apply_change_set_items` risk ledger for each import row.
- Idempotent generation by `(import_batch_id, source_checksum)`.
- Safe risk classes: `create_only`, `no_change_skip`, `guarded_overwrite`, `destructive_equivalent`, `source_conflict`, `stale_preview`, `rollback_required`.
- Safe UI summary on `/erp`: create/update/skip, blockers, guarded/destructive risk, stale/source conflict counters.
- Safe item sample list with field names only, never field values.
- Audit intent and retention bucket per item: object event, field diff, rollback snapshot.
- Expected current hash availability to support future stale guard checks.

## Business Rules

- A change-set can be generated only from a clean, previewed, dry-run batch.
- Update-like rows are blocked by default until guarded update policy exists.
- Destructive-equivalent rows are blocked by default.
- Lower-priority source conflict rows are blocked by default.
- If the preview result no longer matches the current classification, the item is `stale_preview` and requires re-preview.
- Create-only rows can be reviewed but cannot execute until PR16.3 opens worker apply gates.
- Change-set evidence is append-only; update/delete is rejected.

## Data Minimization

PR16.2 stores safe field names, row hashes, expected hash metadata, risk classes, audit tiers, and counters. It does not store before/after personal values in the UI read model. Future rollback snapshots stay service-role-only and must respect 90-day hot retention before high-volume update paths open.

## Verification

- App code does not call `apply_import_batch`.
- `import_apply` job remains closed by PR16.1 trigger.
- Authenticated users can request generation only through admin-checked RPC.
- Change-set tables are immutable.
- UI and AI receive safe summaries only.
- Raw payload, normalized payload, provider response, credentials, and secret references do not appear in the change-set read model.

## Handoff To PR16.3

PR16.3 can use this change-set as the required precondition for create-only worker apply. It should execute only rows with `risk_class = create_only`, `blocked = false`, admin approval, batch lock, idempotency, and object event audit.
