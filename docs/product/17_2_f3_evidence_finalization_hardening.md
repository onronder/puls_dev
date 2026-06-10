# PR17.2F3 Evidence Finalization Hardening

> **Status:** Implemented hardening slice. Depends on PR17.2F1 storage/RLS/RPC boundary and PR17.2F2 product flow.

PR17.2F3 closes the pre-OCR evidence gap found after F1/F2: finalization must verify the actual private storage object size metadata, not only the client-declared upload intent metadata.

## Scope

1. Replace `finalize_workflow_evidence_upload(...)` with the same public RPC signature.
2. Keep storage paths server-generated and private.
3. Require the storage object to exist before finalization.
4. Require `storage.objects.metadata ->> 'size'` to be present, numeric, and equal to the server-recorded upload intent size.
5. Record metadata-only audit evidence that storage size was verified.
6. Map `PULS_EVIDENCE_*` RPC errors to workflow-evidence UI messages.
7. Keep PR17.2E notification/reconcile and PR17.2F2 product-flow behavior unchanged.

## Honest Boundaries

- `sha256_client` remains client-declared integrity metadata. This PR does not claim server-computed content hashing.
- MIME type remains declared/allowlisted metadata. This PR does not add content sniffing.
- `scan_status = 'not_scanned'` remains truthful. This PR does not add malware scanning.
- Attached evidence metadata remains readable to the requester, authorized admins/managers, and assigned approvers for review/audit continuity. Approvers still never see unattached staging uploads.
- Expired staging rows cannot be attached. Physical orphan object cleanup remains a service-role janitor/runbook task, not browser behavior.
- Evidence viewing/download signed URLs, OCR extraction, confidence scoring, and human review are PR17.2G or later.

## Acceptance Criteria

- A new migration redefines `puls_workflow.finalize_workflow_evidence_upload(UUID, BIGINT, TEXT, TEXT)` without changing its browser-facing signature.
- Finalize fails if the storage object is missing.
- Finalize fails if storage object size metadata is missing or non-numeric.
- Finalize fails if storage object size differs from the upload intent size.
- Finalize audit metadata includes `storage_size_verified: true` and no raw file content, OCR values, public URL, or storage payload.
- UI-facing RPC error mapping includes the evidence storage-size failure cases.
- `pnpm run verify:pr17` includes the PR17.2F3 verifier.

## Non-Goals

- OCR, AI extraction, vendor/date/amount parsing.
- Human review of OCR confidence.
- Antivirus or server-verified file hash claims.
- Public URLs or browser-readable storage paths.
- Canonical HR mutation based on file contents.
- Storage orphan cleanup worker.
