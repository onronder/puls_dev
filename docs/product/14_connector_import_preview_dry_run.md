# PR14.16 Connector Import Preview Dry Run

PR14.16 adds connector import preview dry-run, not import apply.

This PR gives the connector setup workbench a safe way to answer: "If this prepared source batch were reviewed, what would PULS create, update, or skip?" It does that without running a live connector, without collecting credentials, and without writing canonical records.

## Product Claim

PULS is a source-independent connectivity layer. Canias is one source profile; import preview is connector-agnostic.

The connector backbone now has four separate boundaries:

| Boundary | PR14.16 posture |
|----------|-----------------|
| Source setup | Existing connector state selects source, mappings, namespace, and credential posture. |
| Dry-run batch | A connector, CSV flow, or proof SQL may prepare rows in import staging tables. |
| Preview | Product classifies create, update, and skip outcomes against canonical records. |
| Apply/runtime | Still closed; a future PR must design execution, rollback, jobs, credentials, and audit. |

Preview classifies create, update, and skip outcomes without writing canonical records.

## What PR14.16 Proves

- A tenant-scoped dry-run import batch can be discovered for the selected connector source namespace.
- Admins can run validation plus preview classification from `/erp`.
- The adapter exposes only safe row-level fields: row number, entity type, external id, validation status, warning/error codes, canonical id, preview action, and skip code.
- The activity timeline records import preview generation or blockage with sanitized counters and next-action keys.
- Preview results are provider-independent: Canias, CSV / Excel, Logo, Custom API, and future connectors can use the same import batch boundary once they produce safe staging records.

## What PR14.16 Does Not Prove

- No live Canias API integration.
- No runtime connector execution.
- No credential capture or credential verification.
- No source-system sync execution.
- No canonical apply/import execution.
- No ERP or external system writeback.

No live connector runtime, credential capture, apply_import_batch call, sync execution, or ERP writeback is enabled.

## Data Model Boundary

The migration extends `puls_integration.import_records` with safe preview metadata:

| Field | Meaning |
|-------|---------|
| `preview_action` | `create`, `update`, or `skip` classification from dry-run preview. |
| `preview_skip_code` | Safe reason for a skipped row, such as unchanged row hash. |
| `previewed_at` | Timestamp for row-level preview classification. |

The migration also replaces `puls_integration.preview_import_diff(p_batch_id)` so it persists row-level preview metadata while keeping the batch in dry-run mode. The product action never calls `apply_import_batch`.

`puls_integration.list_connector_import_preview_records(p_batch_id)` is the product read boundary. It returns safe preview metadata only. Payload readback is forbidden in product UI and adapter output.

## Proof SQL Boundary

The proof SQL may create a dry-run batch, but it must not validate, preview, or apply it automatically.

`supabase/seed/puls-sanayi-v1/sql/12_apply_connector_import_preview_proof.sql` creates a small dry-run proof batch for the existing source namespace. It leaves records pending so the product action can validate and preview the batch through the same adapter path used by future connector-produced batches.

## `/erp` UX

The `/erp` workbench now includes an import preview section after setup preflight:

| State | User meaning |
|-------|--------------|
| No batch | The selected source has no prepared dry-run batch yet. |
| Ready to preview | Admin can classify the batch; no apply or live connector starts. |
| Preview ready | Create/update/skip outcomes are visible for review. |
| Blocked | Validation errors must be closed before preview can proceed. |

The UI shows summary counters and a short safe row list. It intentionally does not render `raw_payload`, `sanitized_payload`, `normalized_payload`, provider response bodies, credentials, or secret references.

## Acceptance Criteria

- `ErpOverview` includes `importPreview`.
- `/erp` renders import preview state without raw payload fields.
- Admin can run dry-run preview when a dry-run batch exists.
- Validation errors block preview and leave a safe activity event.
- Successful preview writes a safe `import_preview` activity event.
- Tests prove `validate_import_batch` and `preview_import_diff` may run, while `apply_import_batch` does not run from app code.
- Verify script blocks payload readback, runtime enablement, credential leakage, and unexpected scope expansion.

## Handoff

PR14.16 is the last connector setup step before future import execution design. The next layer should decide how staged data is approved, applied, rolled back, audited, and retried. That future work must remain source-independent and must not couple PULS to Canias as the product architecture.
