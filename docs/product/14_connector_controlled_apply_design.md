# PR14.18 Controlled Apply Design

PR14.18 defines controlled apply execution design, not canonical import apply.

PR14.16 proved that a prepared dry-run import batch can be previewed safely. PR14.17 proved that preview results can be marked for human review without opening canonical writes. PR14.18 turns the next boundary into a product-visible plan: PULS can show which gates must exist before apply execution is allowed.

## Product Claim

PULS remains a source-independent connectivity product. Canias is one connector profile, not the connectivity architecture.

Controlled apply design is not an apply feature. It is a gate model for future connector execution across ERP, CSV / Excel, custom API, SFTP, and other source types.

| Boundary | PR14.18 posture |
|----------|-----------------|
| Preview evidence | Uses the latest dry-run preview batch and safe counters. |
| Human review | Uses the `import_apply_review_requested` audit event from PR14.17. |
| Apply design gates | Shows approval, idempotency, batch lock, rollback, audit, notification, runtime credential, and execution gates. |
| Apply execution | Still closed; no product action calls `apply_import_batch`. |

Controlled apply execution remains closed in PR14.18.

## What PR14.18 Proves

- `/erp` can show a controlled apply plan derived from real connector setup, preview, review, and credential posture.
- The adapter exposes `controlledApplyPlan` with gate-level readiness, not an execution CTA.
- The plan is source-independent and does not assume Canias-specific runtime behavior.
- Human review is visible as one gate, not as final approval.
- Source checksum, batch lock, rollback strategy, notification plan, audit trail, and credential runtime boundary are explicit before future apply work.

## What PR14.18 Does Not Prove

- No canonical import apply.
- No runtime connector execution.
- No credential capture, credential readback, or secret storage.
- No ERP or external source writeback.
- No rollback execution.
- No background job orchestration.

No apply_import_batch call is opened from the app.

## Gate Model

| Gate | Meaning | PR14.18 state |
|------|---------|---------------|
| Preview evidence | Rows are classified as create, update, or skip in dry-run mode. | Ready only when preview is ready. |
| Human review | Admin review intent is recorded. | Ready only after review event. |
| Source checksum | Batch content has an idempotency fingerprint. | Ready when checksum exists. |
| Approval policy | Role and data-class approval rules are explicit. | Missing until future approval design. |
| Batch lock | Same batch cannot be applied twice or concurrently. | Design-visible, execution still closed. |
| Rollback strategy | Incorrect writes have a safe correction path. | Closed until rollback design. |
| Audit trail | Decisions and batch context are safely recorded. | Ready only when review audit exists. |
| Notification plan | Relevant roles are informed before and after apply. | Closed until Notification Center work. |
| Runtime credentials | Live connector execution uses a verified secret reference. | Boundary-visible; no secret value is shown. |
| Execution boundary | Product UI can invoke apply. | Closed in PR14.18. |

## UX Contract

The `/erp` workbench shows controlled apply design after apply readiness. The section is intentionally read-only:

- It has no apply button.
- It has no connector run button.
- It has no credential input.
- It has no raw payload or provider response.
- It explains that execution is closed.

This keeps the user journey honest: admins can see what remains before live apply, but they cannot accidentally run an import.

## Acceptance Criteria

- `ErpOverview` includes `controlledApplyPlan`.
- `controlledApplyPlan.executionOpen` is always `false`.
- `controlledApplyPlan.applyRpcExposed` is always `false`.
- `/erp` renders controlled apply gates without opening an action path.
- Tests prove clean preview, review-requested, and blocked states derive gate readiness correctly.
- Verify blocks payload readback, credential leakage, runtime enablement, and `apply_import_batch` calls from app code.

## Handoff

PR14.18 closes the product-visible apply design boundary. Future work can choose whether to implement approval persistence, rollback planning, Notification Center integration, or an actual apply job runner. Those future steps must keep source ownership, idempotency, audit, and rollback explicit before any canonical write path is exposed.
