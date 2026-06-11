# PR17.2G4A Expense Receipt OCR Quota Gate

> **Status:** DB contract slice for tenant OCR posture and quota gates. No paid OCR/VLM provider, external API call, browser enqueue, Railway deployment, worker behavior change, or canonical expense mutation is included.

PR17.2G4A turns the G4 vendor evaluation decision into the first production-safety boundary: OCR enqueue is server-side gated by tenant posture, document quota, spend caps, provider allowlists, file/page limits, and safe cost metadata before any provider integration exists.

## Scope

New workflow-owned posture tables:

- `puls_workflow.expense_receipt_ocr_tenant_posture`
- `puls_workflow.expense_receipt_ocr_global_posture`

Default posture:

- tenant OCR `enabled = false`,
- tenant monthly document quota `0`,
- tenant monthly spend cap `0`,
- global monthly spend cap `0` when no global row exists,
- empty provider class allowlist,
- empty provider model allowlist,
- region and retention labels set to `unset`.

Queue metering additions:

- `expense_receipt_ocr_jobs.estimated_cost_minor`,
- `expense_receipt_ocr_jobs.estimated_cost_currency`,
- `expense_receipt_ocr_jobs.document_page_count`,
- `expense_receipt_ocr_jobs.normalized_image_pixels`,
- result-level `estimated_cost_minor`, `actual_cost_minor`, and `cost_currency` columns for later worker completion evidence.

## Enqueue Gate

`enqueue_expense_receipt_ocr_job` remains service-role-only and now rejects new jobs unless all checks pass:

1. Tenant posture exists and is enabled.
2. Monthly document quota is positive and not exhausted.
3. Provider class is in the tenant allowlist.
4. External providers include an allowlisted provider name.
5. Receipt file size is within the tenant limit.
6. Document page count is within the tenant limit.
7. Normalized image pixels are within the tenant limit when provided.
8. Positive estimated cost fits the tenant monthly spend cap.
9. Positive estimated cost fits the global monthly spend cap.
10. Cost currency matches tenant/global posture currency.

Idempotent enqueue hits return the existing job before consuming quota. This preserves retry/idempotency behavior without creating a new OCR job.

## Explicit Non-Goals

- No paid vendor SDK.
- No Gemini, OpenAI, Claude, Mistral, Azure, AWS, Google Document AI, Mindee, Veryfi, or Nanonets call.
- No browser enqueue.
- No trigger enqueue on `expense_receipts`.
- No worker provider change.
- No Railway deployment.
- No canonical `expense_claims` write.
- No raw OCR text, provider payload, document bytes, storage paths, signed URLs, or credentials in DB safe contexts.
- No benchmark runner yet.

## Verification

Rollback-only smoke:

```bash
psql "$DATABASE_URL" \
  -f docs/data/17_2_g4a_expense_receipt_ocr_quota_gate_smoke.sql
```

The smoke proves:

- enqueue without tenant posture is rejected with `PULS_OCR_TENANT_DISABLED`,
- disabled tenant posture is rejected,
- quota `0` is rejected with `PULS_OCR_QUOTA_EXHAUSTED`,
- disallowed provider class is rejected,
- positive estimated cost with tenant spend cap `0` is rejected,
- positive estimated cost with global spend cap `0` is rejected,
- zero-cost allowlisted mock enqueue succeeds only after posture is explicitly enabled,
- positive-cost enqueue succeeds only after tenant and global caps are explicitly configured,
- quota-gated enqueue events record safe `quota_gate_enforced` metadata.

Verify gate:

```bash
bash scripts/verify-17-2-g4a-expense-receipt-ocr-quota-gate.sh
```

## Handoff

G4B added queue resilience proof and worker heartbeat coverage on top of this default-closed enqueue contract.

G4C can add local extraction and benchmark harnesses without opening paid providers.

G4D/G4E remain blocked until dataset/KVKK, budget/quota defaults, region/residency, and enqueue-trigger product decisions are explicitly approved.
