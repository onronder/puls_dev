#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(pwd)}"
cd "$ROOT_DIR"

scripts=(
  "scripts/verify-16-10-13-datasource-technical-details-split.sh"
  "scripts/verify-16-10-14-workflow-audit-policy-hardening.sh"
  "scripts/verify-16-10-15-route-boundary-hr-cache-hardening.sh"
  "scripts/verify-16-10-16-ai-coach-action-truth-hardening.sh"
  "scripts/verify-16-10-17-18-19-pre-pr17-hardening.sh"
  "scripts/verify-16-10-20-pre-pr17-ci-gate.sh"
)

for script in "${scripts[@]}"; do
  bash "$script" "$ROOT_DIR"
done

echo "verify-pre-pr17: OK"
