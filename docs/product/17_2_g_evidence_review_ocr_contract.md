# PR17.2G Evidence Viewing, OCR Contract & Human Review

> **Status:** Living PR17.2G contract. G1-G3 are implemented slices; G4 remains a vendor/production-enqueue decision gate.
> **Decision:** PR17.2G is not "build our own OCR" and not "send every receipt to an expensive vendor". It is the controlled path from attached evidence to reviewed, auditable suggestions.

PR17.2F1/F2/F3 completed the evidence upload boundary: private storage, staging upload intents, finalized upload checks, product upload flows, attached metadata, and localized evidence errors. PR17.2G starts only after that boundary: authorized users must be able to view attached evidence, optional OCR/extraction can propose fields, and a human must review before any canonical expense data is changed.

## Product Principle

OCR output is evidence, not truth.

PULS may suggest `vendor`, `receipt_date`, `total_amount`, `currency`, `tax_amount`, or `receipt_number` from a receipt or invoice, but those values are not canonical until a human reviews them. The product must never silently overwrite `expense_claims.amount`, `expense_claims.expense_date`, category, currency, or approval state from OCR alone.

## Cost Principle

OCR is not the first parser. The first parser is the cheapest reliable path.

For every uploaded expense evidence file, the system should try cheaper routes before external OCR:

1. **Structured invoice data:** if an e-invoice/e-archive XML or machine-readable structured payload is available, parse that instead of OCR. This path is future-gated: PR17.2F currently accepts only PDF/PNG/JPEG evidence, so XML/e-invoice intake requires explicit G2+ schema, bucket MIME allowlist, and intent validation changes before it can be used.
2. **PDF text layer:** if the PDF has extractable text, parse the text before image OCR.
3. **Duplicate detection:** if the same file hash or receipt identity was already processed, reuse or block instead of paying again. Dedupe must not rely on `sha256_client`; that value is client-declared metadata. The OCR/processing worker must compute a server-side content hash after reading the private storage object.
4. **Image OCR fallback:** only scanned PDFs, photos, and POS receipt images need OCR.
5. **Manual fallback:** if OCR is disabled, over quota, low confidence, or too expensive, the user can still fill fields manually and keep the file as evidence.

This means Azure, Google, AWS, or any paid OCR provider must not be hard-coded into PR17.2G1-G3. Vendor selection belongs to PR17.2G4 after cost, quality, data residency, and KVKK/GDPR review.

## Provider Strategy

PR17.2G must define a provider-agnostic adapter contract:

```ts
extractExpenseEvidence(fileRef) -> {
  extractedFields,
  fieldConfidence,
  documentConfidence,
  mismatchFlags,
  providerMetadata,
  costMetadata
}
```

Allowed provider classes for later evaluation:

- self-hosted/open-source OCR for low-cost image text extraction,
- low-cost receipt/invoice OCR APIs,
- hyperscaler OCR/document-intelligence providers as benchmark or fallback,
- structured e-invoice/e-archive parsers that avoid OCR entirely.

Vendor choice is blocked until a sample set of real Turkish receipts/invoices is tested for:

- total amount accuracy,
- date accuracy,
- vendor/merchant accuracy,
- currency and VAT/tax extraction,
- image quality tolerance,
- Turkish character handling,
- average cost per document,
- data residency and retention,
- provider training/data-use terms,
- operational reliability and retry behavior.

## PR17.2G Sub-Phases

### PR17.2G1 — Evidence Viewing Access

Goal: humans can securely view attached evidence before review or approval decisions.

Scope:

1. Add an authorized attached-evidence read model for leave documents, expense receipts, and contract files.
2. Return safe metadata only: id, domain, parent id, original file name, MIME type, file size, uploaded by, attached at, scan status, and the storage path only for authorized signed URL generation. The UI must never render the path, copy it to the clipboard, expose it in notification/AI context, or log it.
3. Use the existing private `workflow-evidence` bucket and Storage RLS. A new SECURITY DEFINER signed-URL RPC is not required in the current architecture.
4. Generate short-lived signed URLs from the authenticated browser client through Supabase Storage. Recommended TTL: **120 seconds**.
5. Never render storage paths in the UI.
6. Never create public URLs.
7. Add compact "View document" / "Open receipt" actions in leave, expense, and contract detail surfaces.
8. Optional best-effort view audit RPC may record `workflow_evidence.view_requested`; this is not compliance-grade enforcement because a browser caller can skip it. A mandatory audit trail would require a proxy/Edge Function.

Non-goals:

- OCR.
- Human review decisions.
- Provider integration.
- Storage object janitor.
- Notification enrichment.
- AI context feed.

### PR17.2G2 — OCR Job & Result Contract

Goal: define safe, provider-agnostic OCR/extraction records for expense receipts only.

PR17.2G2 is split:

- **G2A — DB contract:** workflow-owned queue/result/event tables and service-role-only queue RPCs. No production enqueue path, worker, provider SDK, or external call.
- **G2B — Worker skeleton:** disabled-by-default worker package that reads private storage, computes server-side content hash, and exercises the G2A RPC contract without selecting a paid OCR provider.

Scope:

1. Add `expense_receipt_ocr_jobs` and `expense_receipt_ocr_results`, or equivalent workflow-owned tables.
2. Keep OCR scope limited to `puls_workflow.expense_receipts`.
3. Do not add OCR fields to leave documents or contract files.
4. Use a separate workflow OCR queue/worker contract. Do not put OCR jobs into the ERP connector queue.
5. Start with provider disabled/mock; no external OCR call is required in G2.
6. Track job status separately from review status.
7. Mirror the proven connector job conventions where useful: `attempt_count`, `max_attempts`, lease/heartbeat fields, dead-letter state, immutable job events, idempotency keys, and concurrency-safe claim behavior.
8. Add server-side content hashing in the worker path before duplicate detection or paid provider calls. `sha256_client` remains informational only.
9. Decide whether XML/e-invoice intake is opened in this slice. If yes, update the evidence file extension check, Storage bucket MIME allowlist, intent/finalize validation, UI copy, and tests together. If no, keep structured parsing as a future path and document that PR17.2G2 only parses current PDF/image inputs.
10. Store safe extracted fields and confidence:
   - vendor,
   - receipt date,
   - total amount,
   - currency,
   - tax amount,
   - receipt/invoice number,
   - per-field confidence,
   - document confidence,
   - mismatch flags,
   - provider class/name/version/reference,
   - estimated or actual cost metadata.
11. Avoid raw OCR text by default. If raw text is needed later, it must have explicit retention, RLS, and redaction rules.

G2A enqueue decision:

- No trigger should enqueue when `expense_receipts` rows are inserted.
- No browser/authenticated role should enqueue.
- The service-role enqueue RPC exists only for rollback smoke, future worker integration, and controlled operations.
- Production enqueue waits for G2B/G4 guardrails: tenant-level OCR flag, quota/cost controls, and a deployed worker posture.

G2B worker decision:

- The worker lives in `services/workflow-evidence-worker`, not in `services/erp-connector`.
- The worker is disabled by default and has no Railway deployment file in G2B.
- The worker may download private `workflow-evidence` objects through service-role Storage headers to compute `server_sha256`.
- Provider class is limited to `disabled` or `mock`; both record `external_call: false`.
- No production enqueue is added in G2B.
- No canonical expense field is changed by the worker.
- Real provider evaluation remains G4.

Job state recommendation:

- `not_requested`
- `queued`
- `processing`
- `completed`
- `failed`
- `cancelled`

Review state recommendation:

- `pending_review`
- `accepted`
- `corrected`
- `rejected`
- `needs_new_document`

### PR17.2G3 — Human Review UI

Goal: turn OCR output into a human-reviewed decision.

Implemented in PR17.2G3 as a bounded human-review layer for existing expense receipt OCR results:
review decisions are stored on `expense_receipt_ocr_results`, audit/event metadata stays safe, and
canonical expense fields are not changed.

Scope:

1. Show attached document and extracted suggestions side-by-side.
2. Compare extracted fields with the existing expense claim:
   - amount mismatch,
   - date mismatch,
   - currency mismatch,
   - duplicate suspicion,
   - low confidence.
3. Allow authorized reviewer actions:
   - accept suggestion,
   - correct and accept,
   - reject evidence,
   - request a new document.
4. Store review decision and reviewer identity.
5. Store review notes only in the review table under RLS; audit metadata must not include raw notes.
6. Canonical expense mutation remains closed unless a separate explicit, audited apply step is added.

Actor recommendation:

- requester can view own evidence and respond to correction requests,
- assigned approver can review evidence for assigned claims,
- admin means the existing `hr_admin` / `superadmin` authority; a dedicated `finance` reviewer role does not exist today and requires a separate product/RBAC decision before implementation,
- AI cannot approve, reject, or write canonical values.

### PR17.2G4 — Vendor Evaluation & Worker Integration

Goal: choose and integrate an OCR/structured parsing provider only after cost and compliance gates are explicit.

Required gates:

1. Product approval of monthly OCR budget and per-tenant quota.
2. KVKK/GDPR review for document transfer and retention.
3. Region/data-residency decision.
4. Real Turkish receipt/invoice benchmark set.
5. Cost comparison across:
   - structured parse path,
   - self-host/open-source OCR path,
   - low-cost OCR API path,
   - Azure/Google/AWS or similar hyperscaler path.
6. Fallback behavior when OCR is disabled or quota is exhausted.

Runtime guardrails:

- tenant-level OCR enabled flag,
- monthly OCR quota,
- max pages per document,
- max file size,
- duplicate detection before OCR,
- provider timeout/retry/dead-letter,
- cost metadata per job,
- no OCR for documents that structured parse can handle.

## Notification Strategy

PR17.2G1 should not add new notification events.

OCR/review phases may add events later, for example:

- `expense_receipt_ocr_completed`,
- `expense_receipt_review_requested`,
- `expense_receipt_review_rejected`,
- `expense_receipt_new_document_requested`.

If new events are added, they must follow the PR17.2D/E duplicate-safety convention:

- same trigger/backfill dedupe key when both live and reconcile paths exist,
- `UNIQUE(tenant_id, dedupe_key)`,
- `ON CONFLICT DO NOTHING`,
- safe summary only,
- preferences UI toggle if user-controllable.

If no backfill/reconcile path exists for a new event, the contract must explicitly say so.

## AI Context Boundary

PR17.2G may prepare safe evidence summaries for PR17.4, but it does not make `/ai-koc` autonomous.

Allowed AI context fields:

- evidence attached count,
- OCR job status,
- review status,
- mismatch flags,
- confidence bands,
- safe next action labels.

Forbidden AI context fields:

- raw document bytes,
- public URLs,
- storage paths,
- raw OCR text unless a later retention/redaction policy explicitly allows it,
- provider payloads,
- review notes,
- personal bank/payment identifiers.

## Remaining Operational Decisions

1. Is best-effort view audit enough long-term, or should viewing move behind a proxy/Edge Function?
2. Should the signed URL TTL remain **120 seconds** after live tenant feedback?
3. Is orphan storage object cleanup explicitly outside PR17.2G, or should a service-role janitor be included as a later G sub-slice?
4. Which G4 provider/cost/KVKK gates must block production enqueue?

## Non-Goals For All G Slices

- Building a custom OCR engine from scratch.
- Sending every document to a high-cost provider by default.
- Automatic canonical expense update from OCR.
- Public document URLs.
- Browser-side provider calls.
- ERP connector worker coupling.
- AI autonomous approval or write actions.
