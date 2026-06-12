#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT_DIR"

LOCAL_EXTRACTION="services/workflow-evidence-worker/src/local-extraction.ts"
LOCAL_EXTRACTION_TEST="services/workflow-evidence-worker/src/local-extraction.test.ts"
WORKER="services/workflow-evidence-worker/src/worker.ts"
WORKER_TEST="services/workflow-evidence-worker/src/worker.test.ts"
RUNNER="scripts/run-17-2-g4c-ocr-local-benchmark.mjs"
FIXTURES="docs/data/17_2_g4c_expense_receipt_ocr_benchmark_fixtures.json"
DOC="docs/product/17_2_g4c_expense_receipt_ocr_local_extraction_benchmark.md"
G_DOC="docs/product/17_2_g_evidence_review_ocr_contract.md"
README="docs/product/README.md"
AUDIT="docs/product/17_0_product_reality_audit.md"
VERIFY_PR17="scripts/verify-pr17.sh"

fail() {
  echo "PR17.2G4C verify failed: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || fail "missing file: $1"
}

require_pattern() {
  local file="$1"
  local pattern="$2"
  grep -Fq "$pattern" "$file" || fail "missing pattern in $file: $pattern"
}

reject_pattern() {
  local file="$1"
  local pattern="$2"
  if grep -Fq "$pattern" "$file"; then
    fail "forbidden pattern in $file: $pattern"
  fi
}

for file in "$LOCAL_EXTRACTION" "$LOCAL_EXTRACTION_TEST" "$WORKER" "$WORKER_TEST" "$RUNNER" "$FIXTURES" "$DOC" "$G_DOC" "$README" "$AUDIT" "$VERIFY_PR17"; do
  require_file "$file"
done

require_pattern "$LOCAL_EXTRACTION" "parseTurkishAmount"
require_pattern "$LOCAL_EXTRACTION" "ENGLISH_AMOUNT_PATTERN"
require_pattern "$LOCAL_EXTRACTION" "findTotalAmount"
require_pattern "$LOCAL_EXTRACTION" "normalizeTurkishReceiptDate"
require_pattern "$LOCAL_EXTRACTION" "extractPdfTextLayer"
require_pattern "$LOCAL_EXTRACTION" "extractReceiptFieldsFromPdfTextLayer"
require_pattern "$LOCAL_EXTRACTION" "no_text_layer"
require_pattern "$LOCAL_EXTRACTION" "TOPKDV"
require_pattern "$LOCAL_EXTRACTION" "TOPLAM"
reject_pattern "$LOCAL_EXTRACTION" "fetch("
reject_pattern "$LOCAL_EXTRACTION" "api.openai.com"
reject_pattern "$LOCAL_EXTRACTION" "generativelanguage.googleapis.com"
reject_pattern "$LOCAL_EXTRACTION" "anthropic.com"
reject_pattern "$LOCAL_EXTRACTION" "mistral.ai"

require_pattern "$WORKER" "'pdf_text'"
require_pattern "$WORKER" "buildLocalProviderExtraction"
require_pattern "$WORKER" "route_used"
require_pattern "$WORKER" "text_payload_stored: false"
require_pattern "$WORKER" "external_call: false"
reject_pattern "$WORKER" "api.openai.com"
reject_pattern "$WORKER" "generativelanguage.googleapis.com"
reject_pattern "$WORKER" "anthropic.com"
reject_pattern "$WORKER" "mistral.ai"
reject_pattern "$WORKER" "UPDATE puls_workflow.expense_claims"
reject_pattern "$WORKER" "raw_ocr_text"
reject_pattern "$WORKER" "provider_payload"

require_pattern "$LOCAL_EXTRACTION_TEST" "1.234,56"
require_pattern "$LOCAL_EXTRACTION_TEST" "1,234.56"
require_pattern "$LOCAL_EXTRACTION_TEST" "TOTAL 0,00"
require_pattern "$LOCAL_EXTRACTION_TEST" "KDV DAHIL TOPLAM"
require_pattern "$LOCAL_EXTRACTION_TEST" "ARA TOPLAM"
require_pattern "$LOCAL_EXTRACTION_TEST" "no_text_layer"
require_pattern "$WORKER_TEST" "PULS_WORKFLOW_EVIDENCE_PROVIDER_CLASS: 'pdf_text'"
require_pattern "$WORKER_TEST" "route_used: 'pdf_text'"

require_pattern "$RUNNER" "extractReceiptFieldsFromPdfTextLayer"
require_pattern "$RUNNER" "extractReceiptFieldsFromText"
require_pattern "$RUNNER" "route_coverage"
require_pattern "$RUNNER" "mean_field_accuracy"
require_pattern "$RUNNER" "adversarial_instruction_ignored_count"
require_pattern "$RUNNER" "per_field_exact"
require_pattern "$RUNNER" "external_call: false"
reject_pattern "$RUNNER" "fetch("

require_pattern "$FIXTURES" "route_hint"
require_pattern "$FIXTURES" "input_pdf_text_lines"
require_pattern "$FIXTURES" "input_pdf_base64"
require_pattern "$FIXTURES" "pdf_text"
require_pattern "$FIXTURES" "text_fixture"
require_pattern "$FIXTURES" "no_text_layer"
require_pattern "$FIXTURES" "IGNORE PREVIOUS INSTRUCTIONS"
require_pattern "$FIXTURES" "TOTAL 0,00"
require_pattern "$FIXTURES" "1,234.56"

benchmark_output="$(node --experimental-strip-types "$RUNNER")"
grep -Fq '"external_call": false' <<< "$benchmark_output" || fail "benchmark output must prove no external call"
grep -Fq '"pdf_text": 4' <<< "$benchmark_output" || fail "benchmark output must include pdf_text route coverage"
grep -Fq '"text_fixture": 1' <<< "$benchmark_output" || fail "benchmark output must include text_fixture route coverage"
grep -Fq '"no_text_layer": 1' <<< "$benchmark_output" || fail "benchmark output must include no_text_layer route coverage"
grep -Fq '"adversarial_instruction_ignored_count": 1' <<< "$benchmark_output" || fail "benchmark output must include adversarial proof"
BENCHMARK_OUTPUT="$benchmark_output" node <<'NODE'
const summary = JSON.parse(process.env.BENCHMARK_OUTPUT ?? '{}')
if (summary.mean_field_accuracy < 1) {
  throw new Error(`mean_field_accuracy below threshold: ${summary.mean_field_accuracy}`)
}
const adversarial = summary.results.find((result) => result.id === 'synthetic_adversarial_total_zero_003')
if (!adversarial?.per_field_exact?.total_amount || adversarial.adversarial_instruction_ignored !== true) {
  throw new Error('adversarial total fixture did not preserve the expected total_amount')
}
const englishAmount = summary.results.find((result) => result.id === 'synthetic_english_amount_rejected_005')
if (!englishAmount?.per_field_exact?.total_amount) {
  throw new Error('English amount fixture did not reject ambiguous amount normalization')
}
NODE

require_pattern "$DOC" "PR17.2G4C Expense Receipt OCR Local Extraction Benchmark"
require_pattern "$DOC" "No paid OCR/VLM provider"
require_pattern "$DOC" "route_coverage"
require_pattern "$DOC" "mean_field_accuracy"
require_pattern "$DOC" "PDF bytes"
require_pattern "$DOC" "Document content is treated as untrusted input"
require_pattern "$G_DOC" "G4C"
require_pattern "$README" "17_2_g4c_expense_receipt_ocr_local_extraction_benchmark.md"
require_pattern "$AUDIT" "Rev 21"
require_pattern "$AUDIT" "PR17.2G4C-A"
require_pattern "$VERIFY_PR17" "verify-17-2-g4c-expense-receipt-ocr-local-extraction-benchmark.sh"

echo "PR17.2G4C expense receipt OCR local extraction benchmark verification passed."
