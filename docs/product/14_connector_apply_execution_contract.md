# PR14.20 Connector Apply Execution Contract

PR14.20 defines the closed execution contract for future connector apply without opening canonical import apply.

PULS remains a source-independent connectivity product. Canias is one connector profile, not the connectivity architecture.

## Product Claim

PR14.20 turns the apply boundary into an explicit execution contract. The product can explain which evidence exists, which controls remain closed, and why a tenant still cannot execute canonical writes from the ERP workbench.

This is not connector runtime. This is not import apply. This is not ERP writeback.

## What PR14.20 Proves

| Area | PR14.20 behavior |
|------|------------------|
| Execution contract | Adapter exposes `applyExecutionContract` derived from preview, approval, and controlled apply state. |
| Safety flags | `executionEnabled`, `canonicalWriteEnabled`, `sourceWritebackEnabled`, `credentialReadbackEnabled`, `applyRpcExposed`, and `safeToExecute` are always `false`. |
| Source independence | The contract works for Canias, CSV / Excel, custom API, and future connector profiles once they produce the same dry-run evidence. |
| Idempotency | Source checksum is treated as an explicit control before future apply execution. |
| Admin approval | Approval is a prerequisite signal, but still does not open execution. |
| UX | `/erp` shows the execution contract as a compact read-only panel inside controlled apply. |

## What PR14.20 Does Not Prove

- No `apply_import_batch` call is opened from the app.
- No canonical data writes.
- No runtime connector execution.
- No credential capture, credential readback, or secret display.
- No ERP/source writeback.
- No batch lock implementation.
- No rollback execution.
- No Notification Center delivery.

## Contract Controls

| Control | Meaning |
|---------|---------|
| Dry-run boundary | The current batch is review evidence only. |
| Idempotency key | Source checksum must exist before future execution design can trust the batch. |
| Admin approval | Admin approval must be visible in audit history before future execution can be considered. |
| Batch lock | Future execution must prevent concurrent or repeated apply for the same batch. |
| Rollback plan | Future writes require a correction or rollback path. |
| Notification plan | Relevant roles must be notified around future execution. |
| Execution boundary | Product UI still does not start apply jobs, connector runtime, or ERP writes. |

## UX Debt Captured

The `/erp` workbench is becoming too long for sustained operator use. PR14.20 intentionally avoids a large information architecture refactor, but the next UX hardening pass should split the workbench into tabbed or sub-page sections for source setup, mapping, preflight, credentials, preview, apply controls, and activity history.

## Acceptance Criteria

- `ErpOverview` includes `applyExecutionContract`.
- `applyExecutionContract.contractVersion` is `pr14.20-closed-apply-contract-v1`.
- `applyExecutionContract.executionEnabled` is always `false`.
- `applyExecutionContract.canonicalWriteEnabled` is always `false`.
- `applyExecutionContract.sourceWritebackEnabled` is always `false`.
- `applyExecutionContract.credentialReadbackEnabled` is always `false`.
- `applyExecutionContract.applyRpcExposed` is always `false`.
- `applyExecutionContract.safeToExecute` is always `false`.
- `/erp` renders the contract without adding an apply button.
- Tests prove approval-recorded state can make the contract ready while execution remains closed.

## Handoff

Future work can introduce the actual apply runner only after batch lock, rollback, notification, runtime credential verification, and operator runbook ownership are implemented and tested. Until then, the contract keeps the product honest: ready evidence is not the same thing as executable apply.
