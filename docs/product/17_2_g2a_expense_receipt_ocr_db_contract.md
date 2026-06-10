# PR17.2G2A Expense Receipt OCR DB Contract

> **Status:** Implemented as a database contract slice. No OCR provider, worker deployment, browser enqueue, or external network call is included.

PR17.2G2 is split into two reviewable slices:

- **G2A:** database queue/result/event contract for expense receipts.
- **G2B:** disabled worker skeleton that reads private storage, computes server-side SHA-256, and talks to the G2A RPCs without a real OCR provider.

This slice only lands G2A.

## Scope

G2A adds workflow-owned OCR/extraction contract tables for `puls_workflow.expense_receipts`:

- `puls_workflow.expense_receipt_ocr_jobs`
- `puls_workflow.expense_receipt_ocr_results`
- `puls_workflow.expense_receipt_ocr_job_events`

It also adds service-role-only queue RPCs:

- `enqueue_expense_receipt_ocr_job`
- `claim_next_expense_receipt_ocr_job`
- `heartbeat_expense_receipt_ocr_job`
- `complete_expense_receipt_ocr_job`
- `recover_stale_expense_receipt_ocr_jobs`

`expense_receipts.ocr_status` remains a projection. The queue RPC transactions update it to `queued`, `processing`, `completed`, `failed`, or `cancelled`; it is not treated as the source of truth.

## Explicit Non-Goals

- No trigger automatically enqueues OCR jobs when an expense receipt is attached.
- No browser/authenticated role can enqueue, claim, complete, or write OCR results.
- No worker package is added in this slice.
- No provider SDK, external OCR API, PDF parser, image OCR engine, or network call is added.
- No XML/e-fatura intake is opened; current evidence intake remains PDF/PNG/JPEG only.
- No raw OCR text, provider payload, storage path, signed URL, or document bytes are stored in job context, result metadata, or events.
- No canonical `expense_claims` field is mutated from OCR output.

## Enqueue Decision

G2A deliberately chooses **no production enqueue path**.

The service-role enqueue RPC exists so smoke tests and the future G2B worker can prove the contract, but nothing in the product calls it yet. This avoids the misleading state where provider-disabled tenants accumulate infinite queued jobs and users see "processing" without a running worker.

Production enqueue belongs to a later gate after:

- a tenant-level OCR enabled flag exists,
- quota/cost guardrails exist,
- the worker is deployed and disabled by default,
- provider selection or mock/manual processing posture is explicit.

## Idempotency And Concurrency

The contract mirrors the proven connector queue pattern:

- `UNIQUE (tenant_id, idempotency_key)` makes repeated enqueue calls return the same job.
- `expense_receipt_ocr_jobs_active_concurrency_idx` allows only one active job per receipt concurrency key while status is `queued`, `processing`, or `retrying`.
- Claim uses `FOR UPDATE SKIP LOCKED`.
- Running jobs use `locked_by`, `locked_at`, `worker_heartbeat_at`, and `lease_expires_at`.
- Completion rejects stale leases.
- Recovery moves expired running jobs to `retrying` or `dead_letter`.
- Events are append-only metadata and safe context only.

## Result Semantics

`server_sha256` is the future worker-computed content hash. `sha256_client remains informational` and must not be used for dedupe.

Duplicate detection is tenant scoped and non-blocking:

- results are indexed by `(tenant_id, server_sha256)`,
- a later result may point to `duplicate_of_result_id`,
- `duplicate_suspected` is added as a mismatch flag,
- the human review slice decides what to do with the suspicion.

This avoids blocking legitimate recurring receipts that can look identical or near-identical.

## Safe Payload Boundary

The migration adds `expense_receipt_ocr_safe_context_has_blocked_key(JSONB)` and applies it to job context, result extracted fields, field confidence, cost metadata, and event context.

Blocked keys include credential, token, provider payload, raw OCR text, raw document text, document bytes, public/signed URLs, storage paths, card/bank identifiers, and obvious secret/password variants.

Allowed result fields are safe suggestions such as:

- vendor,
- receipt date,
- total amount,
- currency,
- tax amount,
- receipt or invoice number,
- confidence values,
- mismatch flags,
- provider class/name/version/reference,
- cost metadata.

## Verification

The rollback-only smoke is optional but executable:

```bash
psql "$DATABASE_URL" -f docs/data/17_2_g2a_expense_receipt_ocr_db_contract_smoke.sql
```

It proves service-role enqueue, idempotent duplicate enqueue, claim, heartbeat, complete, receipt projection, result write, duplicate suspicion, and event recording inside a transaction that rolls back.

The static gate is:

```bash
bash scripts/verify-17-2-g2a-expense-receipt-ocr-db-contract.sh
```
