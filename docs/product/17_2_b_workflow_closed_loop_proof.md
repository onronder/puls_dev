# PR17.2B — Workflow Closed-Loop Proof

> **Status:** PR17.2 second implementation slice.

PR17.2A connected leave, expense, and approval records to Notification Center
through the service-role producer orchestrator. PR17.2B adds the executable
closed-loop proof for that contract without adding UI, Railway worker code, or
new database schema.

## Product Contract

The workflow closed loop is considered wired when a rollback-only SQL smoke can
prove:

1. An authenticated employee can create a leave request.
2. The service-role producer emits a `leave_approval_requested` notification for
   the approver.
3. The approval chain can complete with an approved leave request.
4. The service-role producer emits a `leave_request_approved` notification for
   the requester.
5. An authenticated employee can create an expense claim.
6. The service-role producer emits an `expense_approval_requested` notification
   for the approver.
7. The approval can be rejected.
8. The service-role producer emits an `expense_claim_rejected` notification for
   the requester.
9. Workflow row audit evidence exists for the leave and expense records.

## Runtime Boundary

- The proof uses existing browser-facing workflow RPCs:
  `puls_workflow.create_leave_request`,
  `puls_workflow.create_expense_claim`, and
  `puls_workflow.decide_approval_request`.
- Notification emission remains behind
  `puls_app.run_app_notification_producers()` with `service_role`.
- The smoke runs inside `BEGIN ... ROLLBACK`; it must not persist workflow,
  notification, read-state, or audit rows.
- The smoke may auto-discover linked demo personas. Operators can also pass
  `tenant_id`, `requester_user_id`, and `admin_user_id` with `psql -v`.
- The SQL verifies safe notification summaries and does not read back raw
  descriptions, documents, credentials, provider payloads, or field values.

## Non-Goals

- No new visible workflow UI.
- No external delivery, e-mail, push, or mobile delivery.
- No Railway worker implementation change.
- No document upload or receipt storage.
- No AI Coach response generation.

Those remain later PR17.2 and PR17.4 slices.

## Verification

```bash
scripts/verify-17-2-b-workflow-closed-loop-proof.sh
```

Optional executable smoke against a prepared local or remote development
database:

```bash
psql "$DATABASE_URL" \
  -v tenant_id='<optional tenant uuid>' \
  -v requester_user_id='<optional employee auth uuid>' \
  -v admin_user_id='<optional admin auth uuid>' \
  -f docs/data/17_2_b_workflow_closed_loop_smoke.sql
```

The SQL should finish with:

```text
OK: PR17.2B workflow closed-loop smoke completed ... (ROLLBACK pending)
```

If linked personas are not available, the smoke prints a skip notice instead of
creating synthetic auth users.
