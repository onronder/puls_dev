# PR17.2F2 Workflow Evidence Product Flow

> **Status:** Implemented slice. Depends on PR17.2F1 storage/RLS/RPC boundary.
> **Scope:** Browser product flow + submit-with-evidence RPCs. No OCR, no malware scan claim, no AI extraction, no notification summary enrichment.

PR17.2F2 connects evidence upload to the real leave, expense, and contract workflows. It keeps the F1 trust boundary intact: files live in the private `workflow-evidence` bucket, upload paths are server-generated, file metadata is staged in `puls_workflow.evidence_uploads`, and domain tables receive metadata only after an RPC attaches finalized evidence.

## Product Behavior

- Leave requests that require a document now show a compact evidence upload field before submit.
- Expense claims whose category/amount requires a receipt now show a compact evidence upload field before submit.
- Contract admins can upload a PDF for an existing contract; the list/detail view shows attached document metadata.
- Existing no-evidence leave and expense RPCs remain valid for ordinary requests and for PR17.2E smoke coverage.
- The UI uses a file chip, upload state, remove-before-submit, and one primary submit CTA.
- Dead disabled upload controls are removed from leave, expense, and contract surfaces.

## Backend Contract

PR17.2F2 adds two browser-facing submit RPCs:

- `puls_workflow.create_leave_request_with_evidence(...)`
- `puls_workflow.create_expense_claim_with_evidence(...)`

Both RPCs preserve the validation posture of the existing no-evidence RPCs, then attach a finalized evidence upload inside the same transaction as the parent request/claim creation. If evidence attachment fails, the request/claim is rolled back. Approval request creation still happens after the parent row exists, so PR17.2D notification triggers continue to dispatch same-transaction workflow notifications with the existing dedupe keys.

Contract evidence uses the F1 admin RPC:

- `puls_workflow.attach_contract_file_evidence(...)`

## Security and Honesty Rules

- `sha256_client` remains client-declared metadata, not a server-verified content hash.
- `scan_status = 'not_scanned'` remains the honest default.
- MIME/size checks use the F1 allowlist and conservative byte limits.
- The product does not claim antivirus, OCR, text extraction, vendor/date/amount parsing, or AI review.
- Attached evidence audit rows include metadata only: no file content, OCR result, raw payload, credential, or provider data.
- Approvers only gain visibility to attached domain evidence metadata through F1 RLS; unattached staging uploads remain owner/admin-only.

## Acceptance Criteria

- Required-document leave requests can be submitted with evidence and are rejected without evidence.
- Receipt-required expenses can be submitted with evidence and are rejected without evidence.
- Contract admins can upload a PDF and see document metadata on the contract detail surface.
- Leave, expense, and contract pages no longer render dead disabled upload controls for the F2 flow.
- Existing no-evidence workflows and PR17.2E notification/reconcile invariants remain valid.
- `pnpm run verify:pr17` includes the PR17.2F2 verifier.

## Non-Goals

- OCR or human review.
- Malware scanning or server-side content hash verification.
- Signed URL preview/download UI.
- E-signature or external delivery.
- Notification safe-summary enrichment for evidence counts.
- AI context feed from evidence events.
