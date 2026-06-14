# PR17.2G4C Expense Receipt OCR Local Extraction Benchmark

> **Status:** Local extraction and benchmark harness slice. No paid OCR/VLM provider, external API call, browser enqueue, Railway deployment, provider benchmark run, or canonical expense mutation is included.

PR17.2G4C adds the first zero-COGS extraction route after the G4A quota gate and G4B queue resilience proof. The G4C-A hardening pass makes the benchmark measure actual PDF bytes for `pdf_text` fixtures, separates direct text fixtures from PDF text-layer coverage, and adds accuracy/adversarial gates before any paid provider decision.

## Scope

Worker local route:

- `PULS_WORKFLOW_EVIDENCE_PROVIDER_CLASS=pdf_text` is now accepted by the disabled worker skeleton.
- The worker attempts a local PDF text-layer extraction after private Storage download and server-side SHA-256.
- The route never sends bytes or text to an external provider.
- The route never stores raw OCR text or full document text.
- If no readable text layer exists, the worker returns a safe `no_text_layer` result with human review required.

Deterministic parser:

- Turkish amount parsing for `1.234,56` and `123,45`; ambiguous English-formatted amounts such as `1,234.56` are rejected instead of partially normalized.
- Turkish date parsing for `GG.AA.YYYY`.
- Currency normalization for `TRY`, `TL`, `TRL`, `₺`, `USD`, and `EUR`.
- Label preference for `GENEL TOPLAM` and the last Turkish `TOPLAM` over `ARA TOPLAM`, payment lines, `PARA ÜSTÜ`, or adversarial English `TOTAL` lines.
- Columnar total rows such as `KDV DAHIL TOPLAM      1.080,00 TL` stay on one logical line so the amount is not split away from the label.
- `KDV DAHIL TOPLAM` is treated as a total label, not a tax label; benchmark fixtures assert it does not produce a `tax_amount` false positive.
- `TOPKDV`/`KDV` extraction as tax amount.
- Receipt number extraction from `FIS/FİŞ/BELGE/FATURA NO`.
- Document content is treated as untrusted input; benchmark fixtures include an adversarial instruction string.

Benchmark harness:

- Synthetic fixtures live in `docs/data/17_2_g4c_expense_receipt_ocr_benchmark_fixtures.json`.
- `pdf_text` fixtures use synthetic PDF bytes generated from `input_pdf_text_lines`; direct `input_text` fixtures are reported as `text_fixture` and do not inflate PDF text-layer route coverage.
- Runner: `scripts/run-17-2-g4c-ocr-local-benchmark.mjs`.
- Output includes:
  - `route_coverage`,
  - `route_used`,
  - `input_kind`,
  - field accuracy,
  - per-field exactness,
  - provider/model placeholders,
  - cost placeholders,
  - adversarial instruction ignored count,
  - `external_call: false`.
- Verify fails unless `mean_field_accuracy` meets the local threshold and adversarial fixtures preserve the expected total.
- Verify uses a current Rev marker regex instead of depending on a stale `Rev 20`/`Rev 21` substring in audit history.

## Explicit Non-Goals

- No paid vendor SDK.
- No Gemini, OpenAI, Claude, Mistral, Azure, AWS, Google Document AI, Mindee, Veryfi, or Nanonets call.
- No OCR engine dependency.
- No image OCR.
- No e-invoice/XML intake.
- No browser enqueue.
- No trigger enqueue on `expense_receipts`.
- No Railway deployment.
- No canonical `expense_claims` write.
- No raw OCR text, provider payload, document bytes, storage paths, signed URLs, or credentials in DB safe contexts.
- No real customer receipt benchmark set.

## Verification

Local benchmark:

```bash
node --experimental-strip-types scripts/run-17-2-g4c-ocr-local-benchmark.mjs
```

Verify gate:

```bash
bash scripts/verify-17-2-g4c-expense-receipt-ocr-local-extraction-benchmark.sh
```

Targeted tests:

```bash
pnpm exec vitest run \
  services/workflow-evidence-worker/src/local-extraction.test.ts \
  services/workflow-evidence-worker/src/worker.test.ts \
  --config vitest.config.ts
```

## Handoff

G4D can use this harness shape for paid provider benchmark runs only after dataset/KVKK, budget/quota defaults, region/residency, and enqueue-trigger product decisions are explicitly approved.
