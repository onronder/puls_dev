# PR17.2G2B Workflow Evidence Worker Skeleton

> **Status:** Implemented as a disabled-by-default worker skeleton. No paid OCR provider, production enqueue, Railway deployment config, or canonical expense mutation is included.

PR17.2G2B builds on the G2A database contract. It proves that a separate workflow evidence worker can safely claim expense receipt processing jobs, read private evidence, compute a server-side content hash, and complete the G2A RPC contract without coupling to the ERP connector queue or selecting an OCR vendor.

## Scope

New service package:

- `services/workflow-evidence-worker`

Runtime shape:

- HTTP health endpoint.
- Disabled by default via `PULS_WORKFLOW_EVIDENCE_WORKER_ENABLED=false`.
- Supabase service-role RPC calls against `puls_workflow`.
- Private `workflow-evidence` Storage object download.
- Server-side SHA-256 content hash.
- Disabled/mock provider adapter.
- Completion through `complete_expense_receipt_ocr_job`.

## Explicit Non-Goals

- No OCR provider SDK.
- No Azure, Google, AWS, Textract, or Document Intelligence integration.
- No external OCR/network call beyond Supabase REST and Supabase Storage.
- No Railway deployment file in this slice.
- No automatic enqueue trigger.
- No browser enqueue.
- No canonical `expense_claims` mutation.
- No raw OCR text or provider payload storage.
- No XML/e-fatura intake.

## Safety Boundary

The worker never reads or writes ERP connector credentials and does not use `services/erp-connector` queues. It has its own config namespace:

- `PULS_WORKFLOW_EVIDENCE_WORKER_ENABLED`
- `PULS_WORKFLOW_EVIDENCE_WORKER_ID`
- `PULS_WORKFLOW_EVIDENCE_WORKER_VERSION`
- `PULS_WORKFLOW_EVIDENCE_WORKER_POLL_MS`
- `PULS_WORKFLOW_EVIDENCE_WORKER_LEASE_SECONDS`
- `PULS_WORKFLOW_EVIDENCE_WORKER_RECOVER_STALE`
- `PULS_WORKFLOW_EVIDENCE_WORKER_RECOVERY_LIMIT`
- `PULS_WORKFLOW_EVIDENCE_PROVIDER_CLASS`

`PULS_WORKFLOW_EVIDENCE_PROVIDER_CLASS` supports only:

- `disabled`
- `mock`

Any other value resolves to `disabled`.

## Processing Flow

1. Recover stale OCR jobs through `recover_stale_expense_receipt_ocr_jobs`.
2. Claim one job through `claim_next_expense_receipt_ocr_job`.
3. Read the linked `expense_receipts` metadata through Supabase REST with the `puls_workflow` profile.
4. Download the private `workflow-evidence` object with service-role Storage headers.
5. Compare downloaded byte length with `expense_receipts.file_size_bytes`.
6. Compute server-side SHA-256.
7. Build a disabled/mock extraction result:
   - no extracted canonical values,
   - no raw text,
   - no provider payload,
   - `external_call: false`,
   - `estimated_cost_minor: 0`,
   - `human_review_required` mismatch flag.
8. Complete the G2A job through `complete_expense_receipt_ocr_job`.

If the receipt metadata or private storage object cannot be read, the worker completes the claimed job as failed with safe metadata only.

## Verification

The gate is:

```bash
bash scripts/verify-17-2-g2b-workflow-evidence-worker-skeleton.sh
```

It checks:

- service package presence,
- disabled-by-default config,
- service-role header redaction,
- private Storage URL construction,
- server SHA-256 helper,
- no provider SDK or hyperscaler strings,
- no Railway deployment file,
- no canonical expense writes,
- PR17 aggregate verify wiring.

Unit tests cover health/config posture, header redaction, private Storage metadata/download calls, SHA-256 calculation, disabled provider completion payload, and one full mocked job run.

## Handoff

PR17.2G3 can now build human review UI on top of:

- attached evidence viewing from G1,
- OCR queue/result/event DB contract from G2A,
- server-side hash and disabled/mock worker posture from G2B.

PR17.2G4 remains the first slice where a real OCR or structured parsing provider can be evaluated, and only after cost, quota, KVKK/GDPR, data residency, and benchmark gates.
