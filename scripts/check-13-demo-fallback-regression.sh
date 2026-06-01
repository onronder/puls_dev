#!/usr/bin/env bash
# PR13.10 guard: new product-path demo fallback usage must be classified before merge.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
BASE_REF="${BASE_REF:-origin/main}"

echo "Checking ${REF}: no new unclassified product-path demo fallback additions ..."

if ! git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
  echo "FAIL: base ref not found: $BASE_REF"
  exit 1
fi

CHANGED_SRC="$(git diff --name-only "$BASE_REF...$REF" -- 'src/**' 2>/dev/null || true)"
if [[ -z "$CHANGED_SRC" ]]; then
  echo "OK: no src changes; demo fallback baseline unchanged"
  exit 0
fi

while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  case "$path" in
    *.test.ts|*.test.tsx|src/lib/demo/*|src/lib/data/demo-mode.ts|src/lib/data/result.ts)
      continue
      ;;
  esac

  if git diff "$BASE_REF...$REF" -- "$path" \
    | grep -Eiq '^\+[^+].*(fetchDemo[A-Za-z0-9_]*|DemoSourcePill|VITE_PULS_DEMO_MODE[[:space:]]*=[[:space:]]*["'\'']?true|source:[[:space:]]*["'\'']demo["'\''])'; then
    echo "FAIL: new unclassified demo fallback pattern introduced in $path"
    git diff "$BASE_REF...$REF" -- "$path" \
      | grep -Ein '^\+[^+].*(fetchDemo[A-Za-z0-9_]*|DemoSourcePill|VITE_PULS_DEMO_MODE[[:space:]]*=[[:space:]]*["'\'']?true|source:[[:space:]]*["'\'']demo["'\''])' || true
    echo "Classify the route in docs/product/13_v1_screen_readiness_truth_table.md or avoid the new demo dependency."
    exit 1
  fi
done <<< "$CHANGED_SRC"

echo "OK: no new unclassified product-path demo fallback additions"
