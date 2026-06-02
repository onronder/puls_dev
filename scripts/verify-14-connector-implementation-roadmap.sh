#!/usr/bin/env bash
set -euo pipefail

REF="${1:-HEAD}"

echo "Checking ${REF}: PR14.8-PR14.11 connector implementation roadmap ..."

file_at_ref() {
  local path="$1"
  if [[ "$REF" == "WORKTREE" ]]; then
    cat "$path"
  else
    git show "${REF}:${path}"
  fi
}

require_file() {
  local path="$1"
  if [[ "$REF" == "WORKTREE" ]]; then
    if [[ ! -f "$path" ]]; then
      echo "FAIL: missing file ${path}" >&2
      exit 1
    fi
  elif ! git cat-file -e "${REF}:${path}" 2>/dev/null; then
    echo "FAIL: missing file ${path} at ${REF}" >&2
    exit 1
  fi
}

for path in \
  docs/product/14_connector_implementation_roadmap.md \
  docs/product/README.md \
  docs/product/13_v1_product_packaging_strategy.md \
  scripts/verify-14-connector-implementation-roadmap.sh; do
  require_file "$path"
done

ROADMAP="$(file_at_ref docs/product/14_connector_implementation_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
STRATEGY="$(file_at_ref docs/product/13_v1_product_packaging_strategy.md)"
VERIFY="$(file_at_ref scripts/verify-14-connector-implementation-roadmap.sh)"

for needle in \
  "PULS is data-source independent. Canias is the first native ERP connector, not the product abstraction." \
  "Connector setup persistence comes before connector runtime." \
  "PR14.8 - Connector Setup Persistence" \
  "PR14.9 - Error Observability And Sentry" \
  "PR14.10 - Mapping Discovery" \
  "PR14.11 - Connector Preflight Execution" \
  "A tenant may use more than one data source when different domains live in different systems." \
  "Use \`puls_integration.erp_connections\` lifecycle state instead of a separate setup-draft table." \
  "PR14.8 does not collect or store API keys, passwords, FTP secrets, OAuth tokens, or connector credentials." \
  "No live connector calls, no import execution, no sync button, no ERP writes." \
  "Runtime connector execution remains a separate future phase."; do
  if ! grep -Fq "$needle" <<< "$ROADMAP"; then
    echo "FAIL: roadmap missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "14_connector_implementation_roadmap.md" \
  "PR14.8-PR14.11 Connector implementation roadmap"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.8" \
  "PR14.9" \
  "PR14.10" \
  "PR14.11" \
  "Connector setup persistence" \
  "Error observability and Sentry" \
  "Mapping discovery" \
  "Connector preflight execution"; do
  if ! grep -Fq "$needle" <<< "$STRATEGY"; then
    echo "FAIL: strategy missing needle: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR14.8-PR14.11 connector implementation roadmap" <<< "$VERIFY"; then
  echo "FAIL: verify script missing self-identifying text" >&2
  exit 1
fi

if [[ "$REF" == "WORKTREE" ]]; then
  CHANGED="$(git diff --name-only; git ls-files --others --exclude-standard)"
else
  BASE="$(git merge-base origin/main "$REF")"
  CHANGED="$(git diff --name-only "$BASE" "$REF")"
fi

while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  case "$path" in
    docs/product/14_connector_implementation_roadmap.md|\
    docs/product/README.md|\
    docs/product/13_v1_product_packaging_strategy.md|\
    scripts/verify-14-connector-implementation-roadmap.sh)
      ;;
    supabase/.temp/*|supabase/.branches/*)
      if [[ "$REF" == "WORKTREE" ]]; then
        continue
      fi
      echo "FAIL: forbidden generated Supabase path changed in ${path}" >&2
      exit 1
      ;;
    *)
      echo "FAIL: unexpected PR14 roadmap path changed: ${path}" >&2
      exit 1
      ;;
  esac
done <<< "$CHANGED"

echo "OK: PR14.8-PR14.11 connector implementation roadmap verification passed"
