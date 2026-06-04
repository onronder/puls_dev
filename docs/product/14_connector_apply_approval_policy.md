# PR14.19 Connector Apply Approval Policy

PR14.19 defines the MVP approval policy for future connector apply without opening canonical import apply.

## Product Boundary

PULS remains a source-independent connectivity product.

Canias is one connector profile, not the connectivity architecture.

Admin approval is an audit signal, not canonical import apply.

No apply_import_batch call is opened from the app.

`applyApprovalPolicy.safeToApply` is always `false`.

`controlledApplyPlan.executionOpen` is always `false`.

`controlledApplyPlan.applyRpcExposed` is always `false`.

## Business Value

PR14.17 let an admin record that preview results need human review. PR14.18 made future apply gates visible. PR14.19 makes the approval authority explicit: the MVP policy is admin-only, and approval is recorded as a safe audit event before any runtime apply path exists.

This keeps the product honest for development tenants. Admins can see that a clean preview has been reviewed and approved, while the app still refuses to imply that records were written, a connector ran, or ERP/source data changed.

## State Model

| State | Meaning | User action |
| ----- | ------- | ----------- |
| `not_available` | Source or preview batch is missing. | Complete setup and preview first. |
| `needs_review` | Preview may exist, but human review audit is not recorded. | Record human review request. |
| `admin_only` | MVP policy is defined and admin approval can be recorded. | Record admin approval. |
| `approval_recorded` | Admin approval audit event exists for the reviewed preview. | Wait for future apply execution design. |
| `blocked` | Preview has errors or missing evidence. | Resolve blockers before approval. |

## Audit Contract

Admin approval writes a safe `puls_integration.erp_sync_batches` row:

- `sync_type = import_apply_review`
- `event_key = import_apply_approval_recorded`
- `next_action_key = hold_for_apply_execution_design`
- `safe_error_context.approval_policy = admin_only`
- `safe_error_context.approval_recorded = true`
- `safe_error_context.safe_to_apply = false`
- `safe_error_context.apply_execution_open = false`
- `safe_error_context.canonical_write_open = false`

The audit row may include safe counters such as row count, create count, update count, skip count, source namespace code, and approver role. It must not include raw payload, credential values, provider responses, or secret references.

## UI Contract

`/erp` shows the approval policy inside the controlled apply section. The card must say that admin approval is required or recorded, and it must keep the execution-closed badge visible through the parent controlled apply plan.

The action label is `Record admin approval`. It records audit only. It does not apply the batch, run a connector, read credentials, write canonical records, or write ERP/source-system data.

## Out Of Scope

- Canonical import apply
- Runtime connector execution
- Credential capture, credential readback, or secret storage
- ERP or external source writeback
- Batch lock implementation
- Rollback execution
- Notification delivery

## Acceptance Criteria

- `ErpOverview` includes `applyApprovalPolicy`.
- Admin-only approval is represented as explicit product policy, not hidden UI copy.
- Admin can record approval only after clean preview and human review audit exist.
- Non-admin users cannot record approval.
- Approval creates a safe activity event.
- Approval does not call `apply_import_batch`.
- Approval does not expose payloads, credentials, provider responses, or secret references.
- Controlled apply execution remains closed after approval.
