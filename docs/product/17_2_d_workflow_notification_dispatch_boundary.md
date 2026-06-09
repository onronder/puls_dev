# PR17.2D Workflow Notification Dispatch Boundary

> **Status:** PR17.2 fourth implementation slice.

PR17.2A added HR workflow notification producers behind the existing
service-role producer orchestrator. PR17.2B proved the taxonomy with a
rollback-only SQL smoke, and PR17.2C exposed notification preferences in
Settings. PR17.2D closes the remaining R11 gap: live HR workflow notification
delivery no longer waits for the connector worker.

## Product Claim

Leave and expense workflow notifications are now connector-independent:

- creating a leave approval request emits a notification for the assigned
  approver;
- creating an expense approval request emits a notification for the assigned
  approver;
- approving or rejecting a leave request emits a notification for the requester;
- approving or rejecting an expense claim emits a notification for the
  requester;
- the existing PR17.2A producer remains available for safe backfill/reconciliation
  and uses the same dedupe keys, so duplicate ledger rows are not created.

## Architecture

This PR does **not** add a new Railway service and does **not** weaken the
generic notification emitter.

The generic `puls_app.emit_app_notification()` function remains service-role
only. PR17.2D adds a workflow-only internal emitter and row triggers:

- `puls_app.emit_workflow_app_notification_internal(...)`
- `puls_workflow.dispatch_approval_request_notification()`
- `puls_workflow.dispatch_leave_request_decision_notification()`
- `puls_workflow.dispatch_expense_claim_decision_notification()`

The internal emitter is not granted to browser roles. It accepts only the six
PR17.2A workflow event keys, only workflow source tables, only direct employee
targets, and only metadata-only safe summaries.

## Runtime Boundary

- No external delivery, e-mail, mobile push, SMS, Slack, or provider fanout.
- No connector runtime call, source writeback, ERP writeback, credential read,
  raw payload readback, document readback, receipt readback, or field-value
  readback.
- Notification rows are inserted in the same database transaction as the
  workflow mutation. If the workflow mutation rolls back, the notification rolls
  back too.
- Existing PR17.2A dedupe keys are reused so the producer orchestrator can still
  scan safely without duplicates.
- Multi-step approvals are covered because every newly inserted pending
  `approval_requests` row emits the assigned-approver notification.

## Non-Goals

- No visible UI changes.
- No document upload or receipt storage.
- No AI Coach response generation or AI context mutation feed.
- No change to the connector worker.
- No backfill of historical workflow records beyond the existing producer
  orchestrator.

## Verification

Run:

```bash
scripts/verify-17-2-d-workflow-notification-dispatch.sh
pnpm run verify:pr17
pnpm run test
pnpm run check-i18n
```
