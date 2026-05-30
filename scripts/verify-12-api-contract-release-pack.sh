#!/usr/bin/env bash
# Verifies PR12.5 API contract release pack (documentation-only PR).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
CONSUMER_GUIDE="docs/api/api-contract-consumer-guide.md"
RELEASE_CHECKLIST="docs/api/pr12-release-checklist.md"
API_README="docs/api/README.md"
OPENAPI="docs/api/openapi.yaml"
VALIDATION_DOC="docs/api/openapi-validation.md"
EXAMPLES="docs/api/openapi-examples.yaml"
ERROR_CATALOG="docs/api/puls-error-catalog.md"
ALLOWLIST="docs/api/openapi-contract-allowlist.json"
VALIDATOR="scripts/validate-openapi-contract.mjs"

file_at_ref() {
  local path="$1"
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

echo "Checking ${REF}: PR12.5 API contract release pack ..."

REQUIRED_FILES=(
  "$CONSUMER_GUIDE"
  "$RELEASE_CHECKLIST"
  "$API_README"
  "$OPENAPI"
  "$VALIDATION_DOC"
  "$EXAMPLES"
  "$ERROR_CATALOG"
  "$ALLOWLIST"
  "$VALIDATOR"
  "scripts/verify-12-api-contract-release-pack.sh"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "FAIL: missing required file: $file"
    exit 1
  fi
done

GUIDE_CONTENT="$(file_at_ref "$CONSUMER_GUIDE")"
CHECKLIST_CONTENT="$(file_at_ref "$RELEASE_CHECKLIST")"
README_CONTENT="$(file_at_ref "$API_README")"
OPENAPI_CONTENT="$(file_at_ref "$OPENAPI")"
COMBINED_DOCS="${GUIDE_CONTENT}${CHECKLIST_CONTENT}${README_CONTENT}"

guide_needles=(
  "supabase-js"
  "x-puls-public-http: false"
  "not live public REST"
  "client-writable"
  "tenant_id"
  "external_source"
  "contract_smoke"
  "partial"
  "decideApprovalRequest"
  "PR13"
)

for needle in "${guide_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$COMBINED_DOCS"; then
    echo "FAIL: release pack docs missing needle: $needle"
    exit 1
  fi
done

if ! grep -Fq "not public HTTP" <<< "$COMBINED_DOCS"; then
  echo "FAIL: release pack docs missing public HTTP disclaimer"
  exit 1
fi

if ! grep -Fq "17" <<< "$COMBINED_DOCS"; then
  echo "FAIL: release pack docs missing mutation count (17)"
  exit 1
fi

if ! grep -Fq "20" <<< "$COMBINED_DOCS" || ! grep -Fq "/menu" <<< "$COMBINED_DOCS"; then
  echo "FAIL: release pack docs missing read-model appendix (20 routes /menu)"
  exit 1
fi

checklist_commands=(
  "./scripts/verify-12-api-contract-release-pack.sh HEAD"
  "./scripts/verify-12-openapi-draft.sh HEAD"
  "./scripts/verify-12-mutation-contract-smoke.sh HEAD"
  "./scripts/verify-12-contract-examples-errors.sh HEAD"
  "./scripts/verify-12-app-api-boundary-inventory.sh origin/main"
  "node scripts/validate-openapi-contract.mjs"
  "node scripts/check-sensitive-grep.mjs"
  "pnpm check-i18n && pnpm test && pnpm build"
)

for cmd in "${checklist_commands[@]}"; do
  if ! grep -Fq "$cmd" <<< "$CHECKLIST_CONTENT"; then
    echo "FAIL: release checklist missing validation command: $cmd"
    exit 1
  fi
done

for forbidden in openapi.json swagger.json; do
  if ! grep -Fq "$forbidden" <<< "$CHECKLIST_CONTENT"; then
    echo "FAIL: release checklist must mention forbidden artifact: $forbidden"
    exit 1
  fi
done

if ! grep -Fq "x-puls-public-http: false" <<< "$OPENAPI_CONTENT"; then
  echo "FAIL: openapi missing x-puls-public-http: false"
  exit 1
fi

if grep -Fq 'https://api.' <<< "$COMBINED_DOCS"; then
  echo "FAIL: release pack docs must not imply live public REST API URLs"
  exit 1
fi

node "$VALIDATOR"

# --- Docs-only diff guard ---
CHANGED_FILES=()
while IFS= read -r file; do
  [[ -n "$file" ]] && CHANGED_FILES+=("$file")
done < <(git diff --name-only origin/main...HEAD 2>/dev/null || true)

ALLOWED=(
  "$CONSUMER_GUIDE"
  "$RELEASE_CHECKLIST"
  "$API_README"
  "$OPENAPI"
  "$ALLOWLIST"
  "$VALIDATION_DOC"
  "$EXAMPLES"
  "$ERROR_CATALOG"
  "docs/api/12_mutation_contract_smoke_hardening.md"
  "docs/data/README.md"
  "docs/data/12_decide_approval_contract_smoke.sql"
  "docs/data/12_performance_cycle_contract_smoke.sql"
  "$VALIDATOR"
  "scripts/verify-12-api-contract-release-pack.sh"
  "scripts/verify-12-openapi-draft.sh"
  "scripts/verify-12-mutation-contract-smoke.sh"
  "scripts/verify-12-contract-examples-errors.sh"
)

is_allowed() {
  local candidate="$1"
  for allowed in "${ALLOWED[@]}"; do
    if [[ "$candidate" == "$allowed" ]]; then
      return 0
    fi
  done
  return 1
}

FORBIDDEN_EXACT=(
  "openapi.json"
  "swagger.json"
  "package.json"
)

if ((${#CHANGED_FILES[@]} > 0)); then
  for file in "${CHANGED_FILES[@]}"; do
    if ! is_allowed "$file"; then
      echo "FAIL: PR12.5 must not change implementation files: $file"
      exit 1
    fi

    for forbidden in "${FORBIDDEN_EXACT[@]}"; do
      if [[ "$file" == "$forbidden" ]]; then
        echo "FAIL: forbidden changed file: $file"
        exit 1
      fi
    done

    case "$file" in
      src/*|supabase/migrations/*|supabase/functions/*|.env*|.env.example)
        echo "FAIL: forbidden changed path: $file"
        exit 1
        ;;
    esac
  done
fi

chmod +x "$0" 2>/dev/null || true

echo "OK: PR12.5 API contract release pack checks passed for ${REF}"
