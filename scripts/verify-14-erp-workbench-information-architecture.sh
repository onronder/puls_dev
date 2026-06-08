#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"

file_at_ref() {
  local path="$1"
  if [[ "$REF" == "WORKTREE" ]]; then
    cat "$path"
    return
  fi
  git show "${REF}:${path}" 2>/dev/null || cat "$path"
}

echo "Checking ${REF}: PR14.21 ERP workbench information architecture ..."

DOC="$(file_at_ref docs/product/14_erp_workbench_information_architecture.md)"
README="$(file_at_ref docs/product/README.md)"
ROADMAP="$(file_at_ref docs/product/14_connector_implementation_roadmap.md)"
ERP_ROUTE="$(file_at_ref src/routes/_app/verikaynaklari.tsx)"
E2E="$(file_at_ref e2e/ui-stabilization.spec.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"
VERIFY_SELF="$(file_at_ref scripts/verify-14-erp-workbench-information-architecture.sh)"

for needle in \
  "PR14.21 refactors \`/erp\` from one long vertical connector page into a tabbed workbench." \
  "PULS remains a source-independent connectivity product." \
  "Canias is one connector profile, not the workbench architecture." \
  "Tabs must be horizontally scrollable on narrow screens." \
  "No migration" \
  "No connector calls, no sync execution, no import apply"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR14.21 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "Tabs" \
  "TabsList" \
  "TabsTrigger" \
  "TabsContent" \
  "ERP_WORKBENCH_TABS" \
  "previewApply" \
  "showWorkbenchTab('fields'" \
  "showWorkbenchTab('check'" \
  "showWorkbenchTab('previewApply'"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route missing workbench IA needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  '"tabs"' \
  '"setup"' \
  '"fields"' \
  '"check"' \
  '"credentials"' \
  '"previewApply"' \
  '"activity"'; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing tab key: $needle" >&2
    exit 1
  fi
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing tab key: $needle" >&2
    exit 1
  fi
done

for needle in \
  "erp workbench tabs keep connector details navigable" \
  "Data connection workspace" \
  "Domain ownership" \
  "Activity history"; do
  if ! grep -Fq "$needle" <<< "$E2E"; then
    echo "FAIL: e2e missing tab navigation needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.21 ERP workbench information architecture" \
  "14_erp_workbench_information_architecture.md" \
  "scripts/verify-14-erp-workbench-information-architecture.sh"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR14.21 reference: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.21 - ERP Workbench Information Architecture" \
  "After PR14.21, PULS should be able to say" \
  "readable tabbed workbench"; do
  if ! grep -Fq "$needle" <<< "$ROADMAP"; then
    echo "FAIL: roadmap missing PR14.21 reference: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR14.21 ERP workbench information architecture" <<< "$VERIFY_SELF"; then
  echo "FAIL: verify script self-check missing PR14.21 label" >&2
  exit 1
fi

if grep -Eiq "apply_import_batch|credentials_ref|raw_payload|sanitized_payload|normalized_payload|type=[\"']password[\"']|name=[\"'](apiKey|api_key|token|secret|password|connectionString|ftpPassword)[\"']|sync_canias_now|write_to_canias|live connector runtime enabled" <<< "$ERP_ROUTE"; then
  echo "FAIL: ERP route introduced apply, payload readback, credential input, or runtime/writeback enablement" >&2
  exit 1
fi

if [[ "$REF" == "WORKTREE" ]]; then
  CHANGED_FILES="$(
    git diff --name-only "$(git merge-base origin/main HEAD)"
    git ls-files --others --exclude-standard
  )"
else
  CHANGED_FILES="$(git diff --name-only "$(git merge-base origin/main "$REF")...$REF")"
fi

if [[ -n "$CHANGED_FILES" ]]; then
  while IFS= read -r changed; do
    [[ -z "$changed" ]] && continue
    if [[ "$REF" == "WORKTREE" && "$changed" == supabase/.temp/* ]]; then
      continue
    fi
    if [[ "$REF" == "WORKTREE" && "$changed" == supabase/.branches/* ]]; then
      continue
    fi

    case "$changed" in
      docs/product/14_erp_workbench_information_architecture.md) ;;
      docs/product/14_connector_implementation_roadmap.md) ;;
      docs/product/README.md) ;;
      e2e/ui-stabilization.spec.ts) ;;
      scripts/verify-14-erp-workbench-information-architecture.sh) ;;
      src/i18n/locales/en-US.json) ;;
      src/i18n/locales/tr-TR.json) ;;
      src/routes/_app/verikaynaklari.tsx) ;;
      *)
        echo "FAIL: unexpected changed path for PR14.21 ERP workbench IA: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

FORBIDDEN_CHANGED="$(
  printf '%s\n' "$CHANGED_FILES" | grep -E '^(src/lib/data/|supabase/migrations/|supabase/seed/puls-sanayi-v1/csv/|supabase/seed/puls-sanayi-v1/manifest\\.json|package\\.json|\\.env|docs/api/openapi\\.yaml|openapi\\.json|swagger\\.json)' || true
)"
if [[ -n "$FORBIDDEN_CHANGED" ]]; then
  echo "FAIL: forbidden PR14.21 path changed:" >&2
  printf '%s\n' "$FORBIDDEN_CHANGED" >&2
  exit 1
fi

echo "OK: PR14.21 ERP workbench information architecture verification passed"
