#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(pwd)}"
cd "$ROOT_DIR"

fail() {
  echo "verify-16-10-20: $1" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "missing file: $path"
}

require_pattern() {
  local path="$1"
  local pattern="$2"
  grep -Fq "$pattern" "$path" || fail "missing pattern in $path: $pattern"
}

DOC="docs/product/16_10_20_pre_pr17_ci_gate.md"
README="docs/product/README.md"
PACKAGE_JSON="package.json"
CI=".github/workflows/ci.yml"
AGGREGATE_SCRIPT="scripts/verify-pre-pr17.sh"
AUDIT_SQL="docs/data/16_10_20_performance_active_cycle_duplicate_audit.sql"

for path in "$DOC" "$README" "$PACKAGE_JSON" "$CI" "$AGGREGATE_SCRIPT" "$AUDIT_SQL"; do
  require_file "$path"
done

require_pattern "$PACKAGE_JSON" '"verify:pre-pr17": "bash scripts/verify-pre-pr17.sh"'
require_pattern "$CI" "pnpm run verify:pre-pr17"

for script in \
  "verify-16-10-13-datasource-technical-details-split.sh" \
  "verify-16-10-14-workflow-audit-policy-hardening.sh" \
  "verify-16-10-15-route-boundary-hr-cache-hardening.sh" \
  "verify-16-10-16-ai-coach-action-truth-hardening.sh" \
  "verify-16-10-17-18-19-pre-pr17-hardening.sh" \
  "verify-16-10-20-pre-pr17-ci-gate.sh"
do
  require_pattern "$AGGREGATE_SCRIPT" "$script"
done

require_pattern "$AUDIT_SQL" "puls_performance.performance_cycles"
require_pattern "$AUDIT_SQL" "status::TEXT = 'active'"
require_pattern "$AUDIT_SQL" "HAVING COUNT(*) > 1"
require_pattern "$AUDIT_SQL" "active_cycle_count"

if grep -Eiq '^[[:space:]]*(insert|update|delete|merge|alter|create|drop|truncate)\b' "$AUDIT_SQL"; then
  fail "performance duplicate audit SQL must remain read-only"
fi

require_pattern "$README" "PR16.10.20"
require_pattern "$README" "16_10_20_pre_pr17_ci_gate.md"
require_pattern "$DOC" "verify:pre-pr17"
require_pattern "$DOC" "16_10_20_performance_active_cycle_duplicate_audit.sql"

echo "verify-16-10-20: OK"
