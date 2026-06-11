# PR17.2G4 Expense Receipt OCR Vendor Evaluation

> **Status:** Research and decision gate. No production OCR provider, external API call, browser enqueue, Railway deployment, or canonical expense mutation is approved by this document.
> **Last verified:** 2026-06-11, Europe/Istanbul working context.

PR17.2G4 should not start by wiring a paid vendor into the worker. The safe next PR is a provider decision and benchmark gate: keep production OCR disabled, add explicit cost/quota posture, and only run real providers against a controlled benchmark set after product, legal, and budget approval.

## Local Contract Summary

Current PR17.2G state:

- G1 lets authorized users view private attached evidence through short-lived signed URLs.
- G2A defines service-role-only OCR queue/result/event tables for `puls_workflow.expense_receipts`.
- G2B adds a disabled-by-default `services/workflow-evidence-worker` that reads private Storage, computes server-side SHA-256, and completes jobs with `disabled` or `mock` provider classes only.
- G3/G3A add human review and block requester self-review, even for admins.

Current hard boundaries:

- No production enqueue path.
- No browser enqueue.
- No provider SDK.
- No external OCR call.
- No raw OCR text or provider payload storage.
- No canonical `expense_claims` mutation.
- `sha256_client` is informational only; dedupe must use worker-computed `server_sha256`.

G4 must preserve those boundaries unless each opening has its own flag, quota, benchmark, and rollback plan.

## Volume Assumption

The planning example is:

- 100 employees x 50 receipts/month = 5,000 receipts per tenant/month.
- 20 tenants = 100,000 receipts/month.

Most receipt uploads are assumed to be one page. Invoice PDFs can be multi-page, so every cost model must multiply by physical pages, not documents, unless the vendor explicitly prices per document.

This is a capacity and worst-case planning scenario, not a usage forecast. A more typical expense-workflow range may be closer to 2-10 receipts per employee/month, or 4,000-20,000 receipts/month for the same 20-tenant example. Lower volume strengthens the conclusion that VLM API COGS is manageable, but quota defaults and ROI thresholds must be set from measured tenant usage rather than this upper-bound scenario.

## Extraction Strategy Shift

The right G4 framing is not "OCR vendor selection". It is "document-to-JSON extraction route selection".

Classic OCR APIs return text or fixed receipt fields. Modern VLM APIs can accept a receipt image or PDF page and return a schema-shaped JSON suggestion directly. That makes them materially better R&D candidates for PULS than expensive vertical receipt APIs, as long as we treat the result as a suggestion and enforce deterministic validation plus human review.

The working answer to the product question is:

- Yes, Gemini 2.5 Flash/Flash-Lite can read PDF/image receipts and return only fields.
- Yes, OpenAI vision-capable GPT models can do the same with Structured Outputs.
- Yes, Claude and Mistral also have viable document/vision structured-output paths.
- No, this does not remove review, validation, quotas, or compliance gates.
- No, legacy `gpt-3.5-turbo` is not an appropriate current plan: the current OpenAI pricing page no longer lists GPT-3.5, and the document/image path should use current vision-capable models instead.

## Cost Model Assumptions

All VLM estimates below use the same planning volume:

- 100,000 one-page receipts/month.
- One provider request per receipt after duplicate/PDF-text/XML short-circuiting.
- Compact extraction schema and prompt: ~300 input text tokens/request.
- Compact JSON output: ~250 output tokens/request.
- No chain-of-thought, no web/search grounding, no function/tool fanout, no raw OCR text return.
- Currency, tax, date, amount, and receipt number validation happens locally after the model response.

This means the VLM text overhead alone is roughly:

- 30M repeated prompt/schema input tokens/month.
- 25M output tokens/month.

Image/PDF tokens vary by provider:

- Gemini PDF pages are cheap and predictable: Google documents each PDF page as 258 tokens.
- OpenAI image tokens depend on `detail` and image dimensions; a receipt photo at high detail can be roughly hundreds to low-thousands of input tokens, while `low` detail is cheaper but risky for small receipt text.
- Claude image tokens are approximately `width * height / 750`, and PDF visual mode is more expensive than basic text extraction.
- Mistral OCR is page-priced, not token-priced, for the OCR route.

These are estimates for decision-making, not procurement quotes. G4 must add a benchmark harness that records actual tokens, latency, and field accuracy per provider before production.

## Cross-Vendor VLM Cost Comparison

Indicative 100,000 one-page documents/month costs, before taxes, FX, storage, bandwidth, retries, support, human review, and engineering time:

| Path                                     | Verified pricing basis                                                             |                                                   100k docs/pages estimate | PULS readiness                                                                                                                                    |
| ---------------------------------------- | ---------------------------------------------------------------------------------- | -------------------------------------------------------------------------: | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| Structured e-invoice/e-archive XML parse | No OCR API fee; parse UBL/XML after explicit intake support                        |                                                            API cost near 0 | Best first path, but current evidence intake only allows PDF/PNG/JPEG. Requires MIME/extension/intake change before use.                          |
| PDF text-layer extraction                | No OCR API fee; parse existing text layer                                          |                                                            API cost near 0 | Best first implementation for PDFs; quality depends on issuer PDF.                                                                                |
| Server-side duplicate reuse              | No OCR API fee after first successful parse/OCR                                    |                                                       Saves repeated spend | Must use `server_sha256`, tenant scope, and non-blocking duplicate suspicion.                                                                     |
| Gemini 2.5 Flash-Lite direct JSON        | $0.10/1M input, $0.40/1M output standard; $0.05/$0.20 batch/flex                   |      ~$16 standard, ~$8 batch/flex under 558 input + 250 output tokens/doc | Lowest-cost primary VLM benchmark candidate. Must use paid tier; free tier must not receive customer documents.                                   |
| Gemini 2.5 Flash direct JSON             | $0.30/1M input, $2.50/1M output standard; $0.15/$1.25 batch/flex                   |     ~$79 standard, ~$40 batch/flex under 558 input + 250 output tokens/doc | Strong primary VLM benchmark candidate if Flash-Lite accuracy is insufficient.                                                                    |
| OpenAI gpt-5.4-nano direct JSON          | $0.20/1M input, $1.25/1M output standard; $0.10/$0.625 batch/flex                  | ~$45-$55 standard for high-detail receipt assumptions; ~$23-$28 batch/flex | Good low-cost OpenAI benchmark path. Must measure actual image tokens and set `detail` deliberately.                                              |
| OpenAI gpt-5.4-mini direct JSON          | $0.75/1M input, $4.50/1M output standard; $0.375/$2.25 batch/flex                  |                                   ~$165-$190 standard; ~$83-$95 batch/flex | Stronger OpenAI quality candidate, still far cheaper than vertical receipt APIs.                                                                  |
| Mistral OCR 3 with annotations           | $2/1,000 OCR pages; $3/1,000 annotated pages                                       |                                 ~$200 OCR-only; ~$300 annotated extraction | Very relevant benchmark because it is document-native and page-priced. More expensive than Gemini Flash-Lite, cheaper than vertical receipt APIs. |
| Claude Haiku 4.5 direct JSON             | $1/1M input, $5/1M output standard; $0.50/$2.50 batch                              |                             ~$250-$400 depending on image/PDF tokenization | Viable quality benchmark, but not the cost leader. Better as cross-check provider than default.                                                   |
| Google Document AI Enterprise OCR        | $1.50 / 1,000 pages for first 5M pages/month                                       |                                                                      ~$150 | Good OCR-only baseline; structured extraction still needs local parsing/validation.                                                               |
| Azure Document Intelligence Read         | ~$1.50 / 1,000 pages for Read/OCR                                                  |                                                                      ~$150 | Good OCR-only baseline if Azure region/compliance posture is chosen.                                                                              |
| AWS Textract DetectDocumentText          | $0.0015/page first 1M pages                                                        |                                                                      ~$150 | Good OCR-only benchmark, but receipt fields need post-processing.                                                                                 |
| Google Document AI Expense parser        | $0.10 for every 10 pages in a document; a 1-10 page document costs $0.10           |                                                                   ~$10,000 | Better structured output, but 66.7x OCR-only cost and limited-access/processor suitability must be verified.                                      |
| Azure prebuilt Receipt/Invoice           | ~$10 / 1,000 pages                                                                 |                                                                    ~$1,000 | Structured model candidate; region and retention posture are strong, cost is material.                                                            |
| AWS Textract AnalyzeExpense              | $0.01/page first 1M pages                                                          |                                                                    ~$1,000 | Structured expense candidate; still needs Turkish receipt benchmark.                                                                              |
| Mindee Business                          | 10,000 credits/month for 584 EUR annually billed, then 0.035 EUR/additional credit |                                                 ~3,200 EUR/month amortized | Easy API candidate, but expensive for default PULS volume.                                                                                        |
| Veryfi Receipts                          | $0.08/receipt, $500/month minimum, volume discounts above 10k docs                 |                                                   ~$8,000 before discounts | Too expensive as default. Could benchmark only if specialized receipt accuracy is materially better.                                              |
| Nanonets workflow pricing                | Complex AI blocks $0.30/run; typical invoice workflow 4-6 blocks/document          |   $30,000+ if one extraction block, $120,000-$180,000 for typical workflow | Not viable for cost-sensitive default unless private negotiated pricing changes the model.                                                        |
| Self-hosted Tesseract/OCRmyPDF/PaddleOCR | No per-document vendor fee; infra and ops only                                     |                                                            API cost near 0 | Strong low-cost fallback/benchmark; must prove accuracy on Turkish receipts and control native runtime risk.                                      |

Cost conclusion:

1. The default paid R&D candidates should be VLM/document-to-JSON APIs, not vertical receipt APIs.
2. Gemini 2.5 Flash-Lite is the cost floor for hosted VLM extraction.
3. Gemini 2.5 Flash and OpenAI gpt-5.4-nano/mini are the most relevant quality/cost challengers.
4. Mistral OCR 3 is the best page-priced document-native challenger.
5. Claude Haiku 4.5 is worth benchmarking as a quality comparator, but likely not first default for cost-sensitive receipts.
6. Classic OCR-only hyperscalers remain useful baselines, not ideal end-state extractors.
7. Google Document AI Expense parser, Mindee, Veryfi, and Nanonets should be premium/tenant-paid only unless benchmarked human-review savings justify their COGS.

The rational default cascade is:

1. server-side hash and duplicate check,
2. structured XML/e-invoice parse when intake supports it,
3. PDF text-layer parse,
4. Gemini Flash-Lite/Flash direct JSON extraction benchmark,
5. OpenAI gpt-5.4-nano/mini direct JSON extraction benchmark,
6. Mistral OCR 3 annotated extraction benchmark,
7. local/open-source OCR benchmark path,
8. paid OCR-only hyperscaler benchmark,
9. paid vertical structured parser only for tenants/documents that justify it.

## Rate Limit and Throughput Reality

100,000 receipts/month is not a concurrency problem if spread over time:

- Average rate across a 30-day month: ~3,333 receipts/day, ~139/hour, ~2.3/minute.
- If limited to an 8-hour workday: ~417/hour, ~7/minute.
- Even with 10x bursts: ~70/minute.

The risk is not average throughput. The risk is uncontrolled spikes, retry storms, and tenant-level overuse.

G4 production design should therefore enforce:

- tenant monthly document quota,
- tenant monthly spend cap,
- global monthly spend cap,
- provider token/page budget per job,
- max pages per document,
- max image dimensions after preprocessing,
- retry budget with exponential backoff,
- rate-limit aware queue leases,
- dead-letter after bounded attempts,
- provider-level circuit breaker,
- async/batch mode for non-urgent backlogs.

Batch/flex is attractive because receipt extraction does not need to be instant. OpenAI Batch gives a 50% cost discount and completion within 24 hours. Gemini Batch is also 50% of interactive cost, while Gemini Flex is a synchronous best-effort 50% discount option. Claude Message Batches are 50% of standard token cost. Mistral says batch does not count against real-time rate limits and OCR model cards list batching support.

## Vendor Notes

### Gemini 2.5 Flash / Flash-Lite Direct Extraction

This was underweighted in the first research pass. Gemini is not just "OCR"; it is a multimodal model that can read PDFs/images and produce schema-constrained JSON. For PULS, this may be simpler than a classic OCR pipeline:

```json
{
  "merchant_name": "string|null",
  "receipt_date": "YYYY-MM-DD|null",
  "total_amount": "number|null",
  "currency": "TRY|USD|EUR|null",
  "tax_amount": "number|null",
  "receipt_number": "string|null",
  "confidence": "number",
  "needs_human_review": "boolean",
  "warnings": ["string"]
}
```

Pros:

- Gemini API document understanding supports PDF input; docs state PDF files up to 50 MB or 1,000 pages, with each document page equivalent to 258 tokens.
- Gemini structured output supports JSON Schema-style responses and is explicitly positioned for data extraction from unstructured text.
- Gemini 2.5 Flash supports text, code, images, audio, and video inputs with text output and a 1,048,576 token input window.
- Gemini 2.5 Flash-Lite has the same broad multimodal family posture and is optimized for low latency / cost.
- Paid Gemini API terms say prompts, files, and responses are not used to improve Google products; unpaid services must not receive sensitive/customer documents.

Indicative cost model for 100,000 one-page receipts:

- PDF page visual cost: 100,000 x 258 = 25.8M input tokens.
- Add compact prompt/schema overhead: roughly 25M-50M extra input tokens if repeated per document.
- Output JSON: roughly 25M-50M output tokens depending on verbosity and warnings.
- Gemini 2.5 Flash standard: about $15-$30 input plus $62-$125 output, roughly $80-$155/month.
- Gemini 2.5 Flash-Lite standard: about $5-$8 input plus $10-$20 output, roughly $15-$30/month.
- Batch/Flex modes can reduce this further when latency is not important.

Risks:

- VLM output is a suggestion, not truth. It can hallucinate merchant names, normalize dates incorrectly, or infer missing values unless the schema includes `null`, confidence, and warnings.
- Images may cost more than PDF pages if high-resolution photos tile into multiple image chunks; every production benchmark must call `countTokens` before sending or use a bounded image preprocessing policy.
- Structured output validates shape, not factual correctness. PULS still needs deterministic post-validation: totals are numeric, currency is allowlisted, dates are plausible, amount matches claim within tolerance, and low confidence routes to human review.
- Document content is untrusted model input. Receipts and invoices can contain prompt-injection text, so extraction prompts must tell the model to treat visible instructions inside the document as document content only, never as system/developer instructions.
- Gemini should not receive raw document data through free/unpaid tiers. Use only paid API / Cloud billing posture, and prefer Vertex/Google Cloud contract posture if KVKK/GDPR review requires it.
- Files API uploads are retained for 48 hours; inline request or shortest practical file-retention path should be evaluated for receipts.

PULS fit: primary paid API R&D candidate. Flash-Lite should be tested first because it is the hosted VLM cost floor. Flash should be tested when Flash-Lite confidence or Turkish receipt accuracy is not enough. The first implementation should still be disabled by default and quota-capped.

### OpenAI GPT Vision + Structured Outputs

OpenAI is a credible direct JSON extraction path, but the current plan should not be "OpenAI 3.5 Turbo". GPT-3.5 is absent from the current OpenAI pricing page and does not solve current receipt image/PDF extraction as cleanly as the current vision-capable models.

Relevant current OpenAI facts:

- OpenAI's pricing page lists `gpt-5.4-nano` at $0.20/1M input and $1.25/1M output standard, with batch/flex at $0.10/1M input and $0.625/1M output.
- `gpt-5.4-mini` is $0.75/1M input and $4.50/1M output standard, with batch/flex at $0.375/1M input and $2.25/1M output.
- OpenAI Batch gives 50% lower cost, higher rate-limit headroom, and completion within 24 hours.
- OpenAI image inputs support `low`, `high`, `original`, and `auto` depending on model. `low` uses a 512px image; `high` is the normal high-fidelity route. Mini/nano models support `low`, `high`, and `auto`, not `original`.
- Image cost depends on tokenized image size. For high-detail receipt photos, G4 must record actual `usage.input_tokens` by model and preprocessing policy instead of hard-coding a price.
- Structured Outputs can enforce a JSON Schema shape with `strict: true`, but the docs also warn incomplete/refusal cases can fail to produce a valid schema response.
- API data is not used for training. Chat Completions and Responses have 30-day abuse monitoring retention by default; Zero Data Retention eligibility exists for those endpoints, with limitations. Files are retained until deleted or expiration rules if uploaded.

Indicative cost:

- If high-detail receipt input averages ~1,100 image+prompt input tokens plus ~250 JSON output tokens, `gpt-5.4-nano` is roughly $53/month standard or $26/month batch/flex for 100k receipts.
- The same workload on `gpt-5.4-mini` is roughly $195/month standard or $98/month batch/flex.
- If low detail is accurate enough, cost drops materially; if photos are large and `auto` over-selects detail, cost rises.

PULS fit: strong second benchmark after Gemini. Use OpenAI when quality, compliance controls, or vendor diversification justify the extra cost over Flash-Lite. Do not use Files API unless delete/expiry behavior is explicit; prefer inline image/PDF flow or shortest-retention file path.

### Claude Haiku / Sonnet Direct Extraction

Claude is a quality benchmark candidate, not the expected cost floor.

Relevant current Anthropic facts:

- Claude Haiku 4.5 is $1/1M input and $5/1M output; Message Batches are $0.50/1M input and $2.50/1M output.
- Claude Sonnet 4.6 is $3/1M input and $15/1M output; batches are $1.50/$7.50.
- Claude vision image tokens are approximately `width * height / 750`.
- Claude PDF support has a basic text-extraction mode and a visual PDF understanding mode. The visual mode is more expensive, roughly 7,000 tokens for a 3-page PDF in the cited example.
- Structured outputs are generally available for Claude Sonnet 4.5, Opus 4.5, and Haiku 4.5; Anthropic migration guidance also points newer Sonnet 4.6 and Opus 4.6+ integrations to structured outputs / `output_config.format` instead of prefilling.
- Rate limits are tier-based and Anthropic exposes spend limits and workspace controls.

Indicative cost:

- A 1024x1536 receipt image is roughly 2,097 input image tokens before prompt text. With ~300 prompt tokens and 250 output tokens, Claude Haiku 4.5 is roughly $370/month standard or ~$185/month batch for 100k receipts.
- Downsampling can reduce this, but too much downsampling may destroy small thermal receipt text.

PULS fit: useful cross-check for hard Turkish receipt cases and quality arbitration. It should not be the first default for a cost-sensitive base tier unless benchmark accuracy is clearly better than Gemini/OpenAI and reduces human review enough to offset cost.

### Mistral OCR 3 / Document AI

Mistral is different from generic VLM extraction because it has a document-native OCR endpoint with structured annotations.

Relevant current Mistral facts:

- OCR 3 `mistral-ocr-2512` is listed at $2/1,000 OCR pages and $3/1,000 annotated pages.
- The OCR endpoint supports `document_annotation_format`; setting JSON schema mode guarantees the model-generated annotation follows the provided schema.
- The OCR endpoint can request confidence scores at word or page granularity.
- Mistral rate limits vary by subscription tier; requests per second, tokens per minute, and monthly token caps are enforced.
- Free mode is for evaluation/prototyping; Scale/pay-as-you-go is the route for higher limits.

Indicative cost:

- OCR-only: ~$200/month for 100k one-page receipts.
- Annotated structured extraction: ~$300/month for 100k one-page receipts.
- Batch may improve economics or rate-limit posture depending on product availability and plan.

PULS fit: strongest document-native challenger. It is more expensive than Gemini Flash-Lite and likely more expensive than OpenAI nano, but it may win on OCR robustness, confidence scores, and document-specific behavior. It belongs in the first benchmark set.

### Google Document AI

Pros:

- OCR-only price is low at 100k pages/month.
- Security posture is mature: data residency, VPC Service Controls, Access Transparency, CMEK, and stated no customer-data training for Document AI.
- Online processing says document data is processed in memory and not persisted to disk; batch has short TTL behavior.

Risks:

- Specialized parsers cost more than OCR-only. Expense parser is about $10,000/month at 100,000 one-page receipts because each 1-10 page document costs $0.10.
- Expense parser suitability for Turkish receipts must be proven, not assumed.
- GCP project, processor location, IAM, billing alerts, and DPA posture are required before production.

PULS fit: benchmark candidate, not default integration.

### Azure AI Document Intelligence

Pros:

- Strong region story: documents are processed in the same region as the Document Intelligence resource.
- Analyze responses are retained for 24 hours and can be deleted via API.
- Read/OCR tier is cost-competitive with Google/AWS; prebuilt receipt/invoice is materially higher but still predictable.

Risks:

- Official pricing page is region/currency rendered and sometimes hides exact values unless locale is selected. Cost gate must pin the selected Azure region/SKU in the PR.
- Prebuilt receipt/invoice accuracy for Turkish receipts and Turkish tax/VAT fields must be benchmarked.

PULS fit: strong compliance benchmark candidate if an EU-region Azure posture is acceptable.

### AWS Textract

Pros:

- Clear pricing examples: DetectDocumentText is cheap; AnalyzeExpense is $0.01/page in the example region.
- HTTPS-only endpoints, AWS region processing for custom adapter training, encryption, IAM, CloudTrail, and KMS ecosystem.

Risks:

- AnalyzeExpense is still 6.7x OCR-only at 100k pages.
- The data-protection docs put substantial responsibility on the customer configuration.
- Turkish receipt field quality must be tested.

PULS fit: benchmark candidate; do not default to AnalyzeExpense until accuracy delta beats local/OCR-only by a wide margin.

### Mindee

Pros:

- Developer-friendly page-based credit model.
- Processing zone can be forced to Europe.
- API extracted data retention defaults to 12 hours, configurable 1-24 hours, with delete-when-fetched option.

Risks:

- At 100k pages/month, published Business overage math is far above hyperscaler OCR-only and structured parser baselines.
- Enterprise pricing may improve, but that is a sales negotiation, not a safe default.

PULS fit: benchmark only if its field accuracy reduces human review enough to justify 3,000+ EUR/month at the planning volume.

### Veryfi

Pros:

- Receipt-specific extraction and per-document pricing.
- Clear free and starter posture.

Risks:

- $0.08/receipt implies about $8,000/month at 100k receipts before volume discounts.
- Minimum commitment and add-ons complicate early-stage COGS.

PULS fit: not viable as default; benchmark only if a customer explicitly pays for a premium receipt automation tier.

### Nanonets

Pros:

- Enterprise capabilities include compliance, private cloud/on-prem, and data residency options.
- Flexible workflow product.

Risks:

- Public workflow/block pricing is not aligned with cost-sensitive high-volume receipts.
- A typical invoice workflow can run multiple paid blocks per document.

PULS fit: not viable as default without a custom commercial deal.

### Self-Hosted / Open Source

Candidates:

- Tesseract: Apache 2.0 OCR engine, broad language support, raw OCR/text outputs.
- OCRmyPDF: adds OCR text layer to scanned PDFs and uses Tesseract.
- PaddleOCR: modern OCR toolkit with structured outputs and multilingual support.
- PDF.js or a server-side equivalent: text extraction for PDFs with existing text layers.

Pros:

- No vendor per-page fee.
- Documents do not leave PULS infrastructure.
- Good match for cost-sensitive Turkish SMB/mid-market tenants.

Risks:

- Raw OCR is not structured receipt extraction; PULS must build conservative parsers and confidence scoring.
- Accuracy can degrade on crumpled POS receipts, bad lighting, rotation, and thermal print.
- Native OCR tooling increases deployment, sandboxing, CVE, and resource-control responsibilities.
- Do not use shell-wrapper packages that pass untrusted paths to a command unsafely; isolate file paths and run with strict timeouts.

PULS fit: best low-cost benchmark path, but production use needs timeout, memory, page, file-size, and native dependency controls.

## Compliance Gate

Before any paid provider receives a document:

- Product owner approves monthly OCR budget and per-tenant quotas.
- KVKK/GDPR review approves the provider, data transfer, retention, region, DPA, and subprocessors.
- Region is explicit: EU preferred unless a tenant contract requires otherwise.
- Provider must not train on customer documents.
- Retention must be minimized; delete-on-fetch or shortest available result retention is preferred.
- Provider credentials must never be readable by browser, AI context, logs, Sentry, notification payloads, or job safe context.
- Storage paths, signed URLs, raw OCR text, provider payloads, card/bank identifiers, and document bytes remain forbidden in DB safe contexts.

## PULS Integration Compatibility

The current codebase supports a safe integration shape, but not a production provider call yet.

Existing compatible pieces:

- `services/workflow-evidence-worker` already owns the OCR worker boundary instead of the ERP connector worker.
- The worker already reads private Storage with service-role credentials.
- The worker already computes `server_sha256`, which is the right dedupe key before any paid call.
- G2A queue/result/event tables already separate OCR job state from review state.
- G3/G3A already ensure extracted fields are human-reviewed suggestions, not canonical writes.

Required G4/G5 adapter shape:

```ts
type ExpenseEvidenceExtractionProvider = {
  providerClass:
    | 'disabled'
    | 'mock'
    | 'structured'
    | 'pdf_text'
    | 'image_ocr'
    | 'manual'
    | 'external'
  providerName: string
  providerVersion: string
  estimateCost(input: EvidenceInput): Promise<CostEstimate>
  extract(input: EvidenceInput, schema: ExpenseReceiptSchema): Promise<ExtractionResult>
}
```

This deliberately mirrors the existing `puls_workflow.expense_receipt_ocr_provider_class` enum. Provider families and model identities belong in `provider_name`, `provider_version`, and safe `cost_metadata`, not in the enum. Suggested mapping:

| Route                         | `provider_class` | `provider_name` example                                            |
| ----------------------------- | ---------------- | ------------------------------------------------------------------ |
| XML/e-invoice parse           | `structured`     | `puls-einvoice-xml`                                                |
| PDF text-layer parse          | `pdf_text`       | `puls-pdf-text-layer`                                              |
| Tesseract/OCRmyPDF/PaddleOCR  | `image_ocr`      | `puls-local-tesseract`                                             |
| Gemini/OpenAI/Claude VLM JSON | `external`       | `gemini-2.5-flash-lite`, `openai-gpt-5.4-nano`, `claude-haiku-4.5` |
| Mistral OCR 3 annotated       | `external`       | `mistral-ocr-3-annotated`                                          |
| Mindee/Veryfi/Nanonets        | `external`       | `mindee-receipt`, `veryfi-receipts`, `nanonets-workflow`           |

Do not add new enum values such as `vlm_json` or `document_ocr` in G4 unless the migration also updates queue/result RPCs, worker types, smoke tests, and review UI filters together.

Required pre-call checks:

1. Tenant OCR flag is enabled.
2. Tenant monthly document quota has remaining allowance.
3. Tenant monthly spend cap has remaining allowance.
4. Global monthly OCR spend cap has remaining allowance.
5. Provider is in the tenant/provider allowlist.
6. File MIME type is supported by the selected route.
7. File size and page count are within limits.
8. `server_sha256` duplicate check ran before paid extraction.
9. Provider retention and region labels match the tenant contract.

Required post-call checks:

1. Provider response matches the local schema.
2. Missing fields are stored as `null`, not guessed defaults.
3. Amount, tax, currency, date, and receipt number pass deterministic validation.
4. Claim amount/date/currency mismatch flags are computed locally.
5. Confidence is calibrated by benchmark data, not trusted blindly from the provider.
6. Actual input/output tokens, pages, and provider cost are recorded as safe cost metadata.
7. Raw provider payload, raw OCR text, and document bytes are not stored.
8. Result always remains `pending_review` until a non-requester authorized reviewer acts.

Provider-specific integration implications:

| Provider route           | Main integration advantage                                             | Main integration risk                                                                        | G4 stance                       |
| ------------------------ | ---------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- | ------------------------------- |
| Gemini Flash-Lite/Flash  | Direct PDF/image to JSON, very low cost, batch/flex options            | Free tier/data-use risk; JSON shape does not prove factual correctness                       | First paid benchmark            |
| OpenAI gpt-5.4-nano/mini | Strong Structured Outputs, mature API, batch and retention controls    | Image token cost depends heavily on preprocessing/detail; regional processing may add uplift | Second paid benchmark           |
| Mistral OCR 3 annotated  | Page-priced document OCR with annotation schema and confidence options | Higher than Gemini/OpenAI low-cost paths; plan/rate limits must be checked                   | First document-native benchmark |
| Claude Haiku 4.5         | Strong document/vision quality comparator and batch option             | Higher tokenized image/PDF cost                                                              | Quality cross-check benchmark   |
| OCR-only hyperscalers    | Stable page pricing and enterprise cloud posture                       | Need local parser after OCR; not direct JSON                                                 | Baseline only                   |
| Vertical receipt APIs    | Receipt-specific output                                                | Default COGS too high at 100k docs/month                                                     | Premium tenant-paid only        |

Production enqueue remains closed until the quota and spend checks are enforced server-side. A provider adapter without those checks is not acceptable even if the provider is cheap.

## Benchmark Requirement

Vendor selection is blocked until a real benchmark exists.

Minimum sample set:

- 200 Turkish POS receipts,
- 100 Turkish invoices/e-archive PDFs,
- 50 clean machine-generated PDFs with text layer,
- 50 scanned/photographed bad-quality receipts,
- 25 duplicate or near-duplicate cases,
- 25 multi-page invoice PDFs.
- 10-20 adversarial samples with visible prompt-injection text printed or overlaid on the document.

Required metrics:

- field accuracy for merchant/vendor,
- date accuracy,
- total amount accuracy,
- currency accuracy,
- VAT/tax extraction accuracy,
- receipt/invoice number accuracy,
- duplicate detection correctness,
- document-level confidence calibration,
- human-review override rate,
- average latency,
- timeout/retry/dead-letter rate,
- route coverage percentage for XML, PDF text-layer, duplicate reuse, local OCR, VLM JSON, and manual fallback,
- direct provider cost per successful reviewed suggestion,
- effective COGS after human review.

Benchmark provider set:

- `local_pdf_text_layer`,
- `local_e_invoice_xml` once intake supports XML,
- `gemini_2_5_flash_lite_json`,
- `gemini_2_5_flash_json`,
- `openai_gpt_5_4_nano_json`,
- `openai_gpt_5_4_mini_json`,
- `mistral_ocr_3_annotated_json`,
- `claude_haiku_4_5_json`,
- one OCR-only baseline from Google/Azure/AWS,
- optional Google Document AI Expense parser or vertical API only if a tenant or sales case justifies the benchmark cost.

Benchmark output schema:

```json
{
  "provider": "string",
  "model": "string",
  "route_used": "xml|pdf_text|duplicate_reuse|local_ocr|vlm_json|document_ocr|vertical_parser|manual_fallback",
  "document_type": "pos_receipt|invoice_pdf|e_archive_pdf|bad_photo|duplicate",
  "input_tokens": "number|null",
  "output_tokens": "number|null",
  "pages": "number",
  "estimated_cost_usd": "number",
  "actual_cost_usd": "number|null",
  "latency_ms": "number",
  "merchant_exact": "boolean",
  "date_exact": "boolean",
  "total_amount_exact": "boolean",
  "currency_exact": "boolean",
  "tax_amount_exact": "boolean|null",
  "receipt_number_exact": "boolean|null",
  "schema_valid": "boolean",
  "needs_human_review": "boolean",
  "adversarial_instruction_ignored": "boolean|null",
  "reviewer_minutes": "number|null",
  "failure_code": "string|null"
}
```

Pass threshold for a paid structured parser:

- It must reduce human review effort enough to justify at least 5x its extra cost over OCR-only/local extraction, or it should remain an optional tenant-paid premium path.

## Recommended G4 PR Scope

Recommended next PR should be named around "VLM extraction benchmark and quota gate", not "provider integration".

In scope:

- Add this decision document to PR17 references.
- Add provider-neutral extraction route contract documentation for:
  - `local_pdf_text_layer`,
  - `local_e_invoice_xml`,
  - `vlm_json`,
  - `document_ocr_annotated`,
  - `ocr_text_only`,
  - `vertical_receipt_parser`.
- Add tenant OCR posture contract design:
  - OCR disabled by default,
  - monthly quota default 0,
  - monthly spend cap default 0,
  - global monthly spend cap default 0,
  - max pages per document,
  - max file size,
  - max normalized image dimensions,
  - provider class allowlist,
  - provider model allowlist,
  - region/data-residency label,
  - retention policy label.
- Add benchmark fixture contract and scoring schema as documentation or local-only test harness.
- Add token/page/cost metering contract:
  - estimated cost before call,
  - actual provider usage after call,
  - cost minor unit and currency,
  - provider request id hash or safe reference only,
  - no raw prompt, raw OCR text, raw response, or document bytes.
- Add provider route decision matrix to the worker contract, still disabled by default.
- Add recover/dead-letter smoke coverage for the existing G2A queue.
- Add long-provider-call heartbeat requirement to worker contract.
- Keep worker provider enum limited to `disabled | mock` unless a local no-network parser is explicitly added behind disabled-by-default config.

Out of scope:

- No paid vendor SDK.
- No external network OCR call.
- No production enqueue trigger.
- No browser enqueue.
- No automatic OCR on every upload.
- No canonical expense write.
- No raw OCR text persistence.
- No AI context expansion beyond safe status/confidence/mismatch summaries.

## Final Recommendation

For PULS at the planning scale, the default should be:

1. **Do not select a paid vertical OCR vendor yet.**
2. **Use VLM/document-to-JSON extraction as the main R&D direction.**
3. **Benchmark Gemini 2.5 Flash-Lite first, then Gemini Flash, OpenAI gpt-5.4-nano/mini, and Mistral OCR 3 annotated extraction.**
4. **Use Claude Haiku as a quality comparator, not the expected base-tier default.**
5. **Benchmark structured XML and PDF text-layer parsing before any external API because they can drive API COGS to zero for machine-readable documents.**
6. **Build the G4 gate as quota, budget, token/page metering, benchmark, compliance, and recovery readiness.**
7. **Treat Google Document AI Expense parser, Mindee, Veryfi, Nanonets, and similar products as optional premium candidates only if Turkish benchmark accuracy creates a measurable human-review cost reduction.**
8. **Keep production OCR disabled until tenant-level flags and monthly caps are enforced server-side.**

Current ranking for the first benchmark pass:

| Rank | Route                      | Why                                                                        |
| ---: | -------------------------- | -------------------------------------------------------------------------- |
|    1 | PDF text layer / XML parse | Cheapest and deterministic when available.                                 |
|    2 | Gemini 2.5 Flash-Lite JSON | Lowest hosted VLM COGS; likely the base-tier candidate if accuracy passes. |
|    3 | Gemini 2.5 Flash JSON      | Same integration with stronger model budget.                               |
|    4 | OpenAI gpt-5.4-nano JSON   | Low-cost vendor diversification with Structured Outputs.                   |
|    5 | OpenAI gpt-5.4-mini JSON   | Higher-quality OpenAI challenger with still acceptable COGS.               |
|    6 | Mistral OCR 3 annotated    | Document-native fallback/challenger at predictable page pricing.           |
|    7 | Claude Haiku 4.5 JSON      | Quality cross-check for difficult receipts.                                |
|    8 | OCR-only Google/Azure/AWS  | Baseline only unless local parser quality is strong.                       |
|    9 | Vertical receipt APIs      | Premium only; default COGS is too high.                                    |

## Sources

- Google Cloud Document AI pricing: https://cloud.google.com/document-ai/pricing
- Google Document AI security and compliance: https://docs.cloud.google.com/document-ai/docs/security
- Gemini API pricing: https://ai.google.dev/gemini-api/docs/pricing
- Gemini API document processing: https://ai.google.dev/gemini-api/docs/document-processing
- Gemini API structured output: https://ai.google.dev/gemini-api/docs/structured-output
- Gemini API rate limits: https://ai.google.dev/gemini-api/docs/rate-limits
- Gemini API Batch API: https://ai.google.dev/gemini-api/docs/batch-api
- Gemini API Files API: https://ai.google.dev/gemini-api/docs/files
- Gemini API billing: https://ai.google.dev/gemini-api/docs/billing
- Gemini API token counting: https://ai.google.dev/gemini-api/docs/tokens
- Gemini API additional terms: https://ai.google.dev/gemini-api/terms
- Gemini 2.5 Flash model card: https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/gemini/2-5-flash
- Gemini 2.5 Flash-Lite model card: https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/gemini/2-5-flash-lite
- OpenAI API pricing: https://developers.openai.com/api/docs/pricing
- OpenAI Images and vision: https://developers.openai.com/api/docs/guides/images-vision
- OpenAI Structured Outputs: https://developers.openai.com/api/docs/guides/structured-outputs
- OpenAI Batch API: https://developers.openai.com/api/docs/guides/batch
- OpenAI rate limits: https://developers.openai.com/api/docs/guides/rate-limits
- OpenAI data controls: https://developers.openai.com/api/docs/guides/your-data
- OpenAI prompt caching: https://developers.openai.com/api/docs/guides/prompt-caching
- Claude API pricing: https://platform.claude.com/docs/en/about-claude/pricing
- Claude models overview: https://platform.claude.com/docs/en/about-claude/models/overview
- Claude vision: https://docs.anthropic.com/en/docs/build-with-claude/vision
- Claude PDF support: https://docs.anthropic.com/en/docs/build-with-claude/pdf-support
- Claude rate limits: https://docs.anthropic.com/en/api/rate-limits
- Claude batch processing: https://docs.anthropic.com/en/docs/build-with-claude/batch-processing
- Mistral OCR 3 model card: https://docs.mistral.ai/models/model-cards/ocr-3-25-12
- Mistral OCR endpoint: https://docs.mistral.ai/api/endpoint/ocr
- Mistral structured outputs: https://docs.mistral.ai/studio-api/conversations/structured-output
- Mistral rate limits and tiers: https://docs.mistral.ai/admin/user-management-finops/tier
- Mistral usage limits: https://docs.mistral.ai/admin/user-management-finops/usage-limits
- Azure AI Document Intelligence pricing: https://azure.microsoft.com/en-us/pricing/details/document-intelligence/
- Azure Document Intelligence data privacy/security: https://learn.microsoft.com/en-us/azure/foundry/responsible-ai/document-intelligence/data-privacy-security
- Azure Document Intelligence quotas and billing behavior: https://learn.microsoft.com/en-us/azure/ai-services/document-intelligence/service-limits?view=doc-intel-4.0.0
- AWS Textract pricing: https://aws.amazon.com/textract/pricing/
- AWS Textract data protection: https://docs.aws.amazon.com/textract/latest/dg/data-protection.html
- Mindee pricing: https://www.mindee.com/pricing
- Mindee data processing policies: https://docs.mindee.com/models/data-processing-policies
- Veryfi pricing: https://www.veryfi.com/pricing/
- Nanonets pricing: https://nanonets.com/pricing
- Tesseract documentation: https://tesseract-ocr.github.io/tessdoc/Installation.html
- OCRmyPDF documentation: https://ocrmypdf.readthedocs.io/
- PaddleOCR repository: https://github.com/PaddlePaddle/PaddleOCR
- PDF.js project: https://mozilla.github.io/pdf.js/
- GIB e-Belge portal: https://ebelge.gib.gov.tr/anasayfa.html
