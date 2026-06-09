# PR17.2A Workflow Notification Producers

PR17.2A starts the Workflow Closed Loop track by connecting existing leave,
expense, and approval records to Notification Center through the existing
service-role producer boundary.

## Product Claim

HR workflow notifications are now source-aware and action-oriented:

- assigned leave approvals notify the assigned approver
- assigned expense approvals notify the assigned approver
- approved or rejected leave requests notify the requester
- approved or rejected expense claims notify the requester
- Notification Center can route those notifications to `/izin` or `/masraf`
- users can tune the `puls_workflow` source scope from Notification Center preferences

## Architecture

This PR does **not** add a new Railway service.

The current Railway connector worker already calls
`puls_app.run_app_notification_producers()` as a service-role job. PR17.2A adds
`puls_app.refresh_workflow_app_notifications()` and wires it into that existing
orchestrator.

That keeps `puls_app.emit_app_notification()` service-role only. Browser-called
workflow RPCs do not get direct ledger write access and the generic notification
emitter is not weakened.

## Event Taxonomy

Source domain: `puls_workflow`

| Event key | Target | Route |
| --- | --- | --- |
| `leave_approval_requested` | assigned approver employee | `/izin` |
| `expense_approval_requested` | assigned approver employee | `/masraf` |
| `leave_request_approved` | requester employee | `/izin` |
| `leave_request_rejected` | requester employee | `/izin` |
| `expense_claim_approved` | requester employee | `/masraf` |
| `expense_claim_rejected` | requester employee | `/masraf` |

## Safety Boundary

- No email, mobile push, SMS, Slack, or external delivery.
- No provider calls, connector runtime calls, source writeback, or ERP writeback.
- No raw descriptions, decision notes, receipts, documents, or field values are
  copied into notification summaries.
- Safe summaries include only ids, workflow module/status, approval status,
  step order, policy status, target class, and contract metadata.
- Producer only scans the last 90 days to avoid historical notification floods
  when the migration first lands.
- Dedupe keys are stable by event, request/approval id, status, and target
  employee.

## Non-Goals

- Document upload is still a separate PR17.2 follow-up.
- Full browser e2e for request -> approve -> notify -> audit is a follow-up.
- AI Coach does not consume workflow notifications yet.
- Railway worker behavior is not changed.

## Verification

Run:

```bash
scripts/verify-17-2-a-workflow-notification-producers.sh
pnpm run test -- src/lib/notifications/app-notification-actions.test.ts
pnpm run check-i18n
```
