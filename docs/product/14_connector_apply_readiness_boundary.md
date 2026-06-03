# PR14.17 Connector Apply Readiness Boundary

PR14.17 defines apply readiness and human review boundary, not canonical import apply.

PR14.16 proved that a prepared dry-run batch can be classified into create, update, and skip outcomes. PR14.17 adds the next product boundary: the workbench can say whether those preview results are ready for human review, and it can record that review intent as safe audit metadata.

## Product Claim

PULS remains a source-independent connectivity layer. Canias is one source profile; apply readiness is connector-agnostic.

Apply readiness is not an execution feature. It is a decision-support boundary that keeps the future apply path honest.

| Boundary         | PR14.17 posture                                                                                  |
| ---------------- | ------------------------------------------------------------------------------------------------ |
| Preview evidence | Uses the latest dry-run preview batch and safe counters.                                         |
| Human review     | Admin can record review intent for a clean preview.                                              |
| Audit history    | Review intent is stored as a safe `erp_sync_batches` activity row.                               |
| Apply execution  | Still closed; future work must design approvals, runtime, rollback, retry, and canonical writes. |

safeToApply remains false in PR14.17.

## What PR14.17 Proves

- `/erp` can show whether previewed rows are ready for human review.
- The adapter derives apply readiness from connector state, preview status, row findings, credential posture, and existing review events.
- Admins can record a human review request without opening apply.
- The activity timeline records `import_apply_review_requested` with safe counters only.
- Existing dry-run preview evidence stays source-independent and does not assume Canias is the product architecture.

Human review records are audit signals, not ERP or canonical write approvals.

## What PR14.17 Does Not Prove

- No canonical import apply.
- No `apply_import_batch` execution.
- No runtime connector execution.
- No credential capture or credential verification.
- No ERP or external source writeback.
- No rollback/retry orchestration.

No apply_import_batch call is opened from the app.

## Data Boundary

PR14.17 does not add a database migration. It reuses the activity model hardened in PR14.15:

| Field                                             | Meaning                                                 |
| ------------------------------------------------- | ------------------------------------------------------- |
| `sync_type = 'import_apply_review'`               | Human review boundary event.                            |
| `event_key = 'import_apply_review_requested'`     | Admin recorded review intent.                           |
| `safe_error_context.safe_to_apply = false`        | Apply remains closed.                                   |
| `safe_error_context.apply_execution_open = false` | No execution path opened.                               |
| `next_action_key = 'hold_for_apply_design'`       | Future apply design must handle approvals and rollback. |

Payload readback remains forbidden.

## `/erp` UX

The workbench now shows an apply readiness section after import preview:

| State                   | User meaning                                          |
| ----------------------- | ----------------------------------------------------- |
| Review not available    | No source or no dry-run batch is ready.               |
| Preview required        | A batch exists but has not been previewed cleanly.    |
| Ready for human review  | Preview results are ready to be reviewed by an admin. |
| Review request recorded | Admin review intent is saved as audit metadata.       |
| Review blocked          | Preview errors must be resolved first.                |

The primary action records human review intent only. It does not approve import, run a connector, apply rows, store credentials, or write ERP data.

## Acceptance Criteria

- `ErpOverview` includes `applyReadiness`.
- `applyReadiness.safeToApply` is always `false`.
- `/erp` renders apply readiness with human review copy, not apply approval copy.
- Admin can record an `import_apply_review_requested` activity event for a clean preview.
- Non-admin users cannot record review intent.
- Tests prove app code does not call `apply_import_batch`.
- Verify script blocks payload readback, credential leakage, runtime enablement, and unexpected scope expansion.

## Handoff

PR14.17 closes the connector setup-to-preview review boundary. Future work can design canonical apply only after approval, rollback, idempotency, job orchestration, notification, and credential-runtime boundaries are explicit.
