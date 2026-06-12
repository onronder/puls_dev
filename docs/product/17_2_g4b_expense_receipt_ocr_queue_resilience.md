# PR17.2G4B Expense Receipt OCR Queue Resilience

> **Status:** Queue resilience proof for the existing OCR queue and worker skeleton. No paid OCR/VLM provider, browser enqueue, Railway deployment, or canonical expense mutation is included.

PR17.2G4B closes the queue-resilience evidence gap left by G2A/G2B/G3A. It proves that a claimed OCR job can heartbeat its lease, recover after lease expiry, retry safely, and dead-letter after max attempts while keeping `expense_receipts.ocr_status` consistent.

## Scope

Worker behavior:

- `runWorkerOnce` calls `heartbeat_expense_receipt_ocr_job` around metadata fetch, private evidence download, local extraction, and completion work so long operations can keep the lease alive.
- Heartbeats send an empty safe context so they extend the lease without overwriting the job's existing `safe_error_context`.
- Transient worker failures such as RPC/storage 5xx, 429, timeout, or fetch-level network errors complete as `retrying` with retry delay; permanent validation failures complete as `failed`.
- The worker rejects a claimed job when `job.provider_class` does not match the configured worker provider class.
- The worker supports `disabled`, `mock`, and the G4C local `pdf_text` provider class; all remain zero-network routes.

Rollback-only queue smoke:

- enqueue one mock OCR job under an explicitly enabled G4A tenant posture,
- claim the job, record a heartbeat event, and prove the heartbeat extends `lease_expires_at`,
- force lease expiry and recover to `retrying`,
- confirm receipt projection returns to `ocr_status = 'queued'`,
- reclaim the retrying job,
- force lease expiry at `max_attempts`,
- recover to `dead_letter`,
- confirm receipt projection moves to `ocr_status = 'failed'` and operator review is required.

## Explicit Non-Goals

- No new migration.
- No paid vendor SDK.
- No Gemini, OpenAI, Claude, Mistral, Azure, AWS, Google Document AI, Mindee, Veryfi, or Nanonets call.
- No browser enqueue.
- No trigger enqueue on `expense_receipts`.
- No Railway deployment.
- No canonical `expense_claims` write.
- No raw OCR text, provider payload, document bytes, storage paths, signed URLs, or credentials in DB safe contexts.
- No paid or image OCR extraction.

## Verification

Rollback-only smoke:

```bash
psql "$DATABASE_URL" \
  -f docs/data/17_2_g4b_expense_receipt_ocr_queue_resilience_smoke.sql
```

The smoke proves:

- active worker heartbeat records `expense_receipt_ocr.job_heartbeat` and extends `lease_expires_at`,
- stale processing jobs recover to `retrying`,
- recovered jobs clear locks and leases,
- recovered jobs set `safe_error_code = 'OCR_LEASE_EXPIRED'`,
- retry recovery keeps the receipt projection at `ocr_status = 'queued'`,
- retry claim restores `ocr_status = 'processing'`,
- max-attempt stale jobs recover to `dead_letter`,
- dead-letter recovery moves the receipt projection to `ocr_status = 'failed'`,
- dead-letter events require operator review.

Verify gate:

```bash
bash scripts/verify-17-2-g4b-expense-receipt-ocr-queue-resilience.sh
```

## Handoff

G4C added local extraction and benchmark harnesses on top of a queue contract that has proven heartbeat, recovery, retry, and dead-letter behavior. The G4C-A hardening pass additionally proves worker-side transient retry classification, provider-class mismatch failure, and non-overwriting heartbeat context.

G4D/G4E remain blocked until dataset/KVKK, budget/quota defaults, region/residency, and enqueue-trigger product decisions are explicitly approved.
