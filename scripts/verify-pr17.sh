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
)

for script in "${scripts[@]}"; do
  bash "$script" "$ROOT_DIR"
done

echo "verify-pr17: OK"
