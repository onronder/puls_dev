#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(pwd)}"
cd "$ROOT_DIR"

scripts=(
  "scripts/verify-17-1-a-core-hr-audit-foundation.sh"
  "scripts/verify-17-1-b-core-org-lifecycle.sh"
  "scripts/verify-17-1-c-employee-assignment-edit.sh"
  "scripts/verify-17-1-d-company-profile-edit.sh"
  "scripts/verify-17-2-a-workflow-notification-producers.sh"
  "scripts/verify-17-2-b-workflow-closed-loop-proof.sh"
  "scripts/verify-17-2-c-settings-notification-preferences.sh"
  "scripts/verify-17-2-d-workflow-notification-dispatch.sh"
  "scripts/verify-17-2-e-workflow-e2e-reconcile.sh"
  "scripts/verify-17-2-f1-workflow-evidence-upload-foundation.sh"
  "scripts/verify-17-2-f2-workflow-evidence-product-flow.sh"
  "scripts/verify-17-2-f3-evidence-finalization-hardening.sh"
  "scripts/verify-17-2-g1-evidence-viewing-access.sh"
  "scripts/verify-17-2-g2a-expense-receipt-ocr-db-contract.sh"
  "scripts/verify-17-2-g2b-workflow-evidence-worker-skeleton.sh"
  "scripts/verify-17-2-g3-expense-receipt-ocr-human-review.sh"
  "scripts/verify-17-2-g3a-expense-receipt-ocr-review-hardening.sh"
  "scripts/verify-17-2-g4a-expense-receipt-ocr-quota-gate.sh"
  "scripts/verify-17-2-g4b-expense-receipt-ocr-queue-resilience.sh"
  "scripts/verify-17-2-g4c-expense-receipt-ocr-local-extraction-benchmark.sh"
)

for script in "${scripts[@]}"; do
  bash "$script" "$ROOT_DIR"
done

g4_doc="docs/product/17_2_g4_expense_receipt_ocr_vendor_evaluation.md"
g4b_doc="docs/product/17_2_g4b_expense_receipt_ocr_queue_resilience.md"
g4c_doc="docs/product/17_2_g4c_expense_receipt_ocr_local_extraction_benchmark.md"
readme="docs/product/README.md"
audit="docs/product/17_0_product_reality_audit.md"

for file in "$g4_doc" "$g4b_doc" "$g4c_doc" "$readme" "$audit"; do
  [[ -f "$file" ]] || {
    echo "verify-pr17: missing file: $file" >&2
    exit 1
  }
done

grep -Fq "PR17.2G4 Expense Receipt OCR Vendor Evaluation" "$g4_doc" || {
  echo "verify-pr17: missing G4 document title" >&2
  exit 1
}
grep -Fq "OpenAI gpt-5.4-nano direct JSON" "$g4_doc" || {
  echo "verify-pr17: missing OpenAI VLM benchmark row" >&2
  exit 1
}
grep -Fq "Google Document AI Expense parser" "$g4_doc" || {
  echo "verify-pr17: missing Document AI expense parser cost row" >&2
  exit 1
}
grep -Fq "route_used" "$g4_doc" || {
  echo "verify-pr17: missing G4 route coverage benchmark field" >&2
  exit 1
}
grep -Fq "providerClass:" "$g4_doc" || {
  echo "verify-pr17: missing G4 provider class mapping contract" >&2
  exit 1
}
grep -Fq "No paid vendor SDK" "$g4_doc" || {
  echo "verify-pr17: missing G4 paid-provider non-goal" >&2
  exit 1
}
grep -Fq "PR17.2G4B Expense Receipt OCR Queue Resilience" "$g4b_doc" || {
  echo "verify-pr17: missing G4B document title" >&2
  exit 1
}
grep -Fq "recover to \`dead_letter\`" "$g4b_doc" || {
  echo "verify-pr17: missing G4B dead-letter proof" >&2
  exit 1
}
grep -Fq "PR17.2G4C Expense Receipt OCR Local Extraction Benchmark" "$g4c_doc" || {
  echo "verify-pr17: missing G4C document title" >&2
  exit 1
}
grep -Fq "route_coverage" "$g4c_doc" || {
  echo "verify-pr17: missing G4C route coverage contract" >&2
  exit 1
}
grep -Fq "mean_field_accuracy" "$g4c_doc" || {
  echo "verify-pr17: missing G4C accuracy gate contract" >&2
  exit 1
}
grep -Fq "17_2_g4_expense_receipt_ocr_vendor_evaluation.md" "$readme" || {
  echo "verify-pr17: README does not link G4 vendor evaluation doc" >&2
  exit 1
}
grep -Fq "17_2_g4b_expense_receipt_ocr_queue_resilience.md" "$readme" || {
  echo "verify-pr17: README does not link G4B queue resilience doc" >&2
  exit 1
}
grep -Fq "17_2_g4c_expense_receipt_ocr_local_extraction_benchmark.md" "$readme" || {
  echo "verify-pr17: README does not link G4C local extraction doc" >&2
  exit 1
}
grep -Eq "^> \*\*Tarih:\*\* .*\*\*Rev 2[0-9]\*\*" "$audit" || {
  echo "verify-pr17: audit doc missing current PR17 Rev 2x marker" >&2
  exit 1
}
grep -Fq "PR17.2G4C-B" "$audit" || {
  echo "verify-pr17: audit doc does not mention PR17.2G4C-B" >&2
  exit 1
}

echo "verify-pr17: OK"
