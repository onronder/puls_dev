# PR17.2E Workflow E2E Baseline & Reconcile Contract

> **Status:** PR17.2 fifth implementation slice.

PR17.2D made leave and expense workflow notifications connector-independent by
emitting metadata-only notification rows from workflow table events. PR17.2E
locks that behavior with an executable rollback-only baseline: the workflow
RPCs create and decide real leave/expense records, live dispatch is observed
before any service-role producer run, and the producer is then proven to be a
duplicate-safe reconcile/backfill path.

## Product Claim

The leave and expense workflow closed loop has a database-boundary e2e
baseline:

1. An authenticated employee creates a leave request and an expense claim
   through the browser-facing workflow RPCs.
2. The assigned approvers receive approval-requested notification ledger rows
   in the same transaction, before `run_app_notification_producers()` runs.
3. The service-role producer scans the same records and inserts no duplicates.
4. The leave request can be approved through all available approval steps.
5. The expense claim can be rejected.
6. The requester receives decision notification ledger rows in the same
   transaction, again before producer reconcile.
7. Workflow audit evidence exists for both records.

## Reconcile Contract

PR17.2A producer rows and PR17.2D live dispatch rows intentionally share the
same deterministic dedupe keys. `puls_app.app_notifications` enforces
`UNIQUE(tenant_id, dedupe_key)`, and both emitter paths use conflict-safe
insertion.

PR17.2E treats this as a regression guard, not an open correctness question:
the smoke first observes trigger-created rows, then runs the producer and
asserts `inserted = 0` for the same dedupe keys.

## Runtime Boundary

- No database migration.
- No visible UI change.
- No Railway worker change.
- No external delivery, e-mail, mobile push, SMS, Slack, or provider fanout.
- No connector runtime call, source writeback, ERP writeback, credential read,
  raw payload readback, document readback, receipt readback, or field-value
  readback.
- The smoke runs inside `BEGIN ... ROLLBACK`; it must not persist workflow,
  notification, read-state, or audit rows.

## Multi-Step Handling

The smoke follows the leave approval chain while the policy returns a
`next_approval_request_id`. When the selected tenant has a multi-step policy,
it also checks the next approver notification. When the selected tenant has only
a single-step policy, the smoke reports a skip-style notice for that optional
variant while still proving the baseline request -> decision loop.

## Verification

Contract check:

```bash
scripts/verify-17-2-e-workflow-e2e-reconcile.sh
pnpm run verify:pr17
```

Optional executable smoke against a prepared local or remote development
database:

```bash
psql "$DATABASE_URL" \
  -v tenant_id='<optional tenant uuid>' \
  -v requester_user_id='<optional employee auth uuid>' \
  -v admin_user_id='<optional admin auth uuid>' \
  -f docs/data/17_2_e_workflow_e2e_reconcile_smoke.sql
```

The SQL should finish with:

```text
OK: PR17.2E workflow e2e + reconcile smoke completed ... (ROLLBACK pending)
```

If linked personas or setup data are unavailable, the smoke prints a skip notice
instead of creating synthetic auth users.
