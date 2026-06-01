#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"

file_at_ref() {
  local path="$1"
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

echo "Checking ${REF}: PR14.0 PR13 P2 QA closeout ..."

CONTRACTS_ROUTE="$(file_at_ref src/routes/_app/sozlesmeler.tsx)"
DEPARTMENTS_ROUTE="$(file_at_ref src/routes/_app/departmanlar.tsx)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"
CONTRACTS_TEST="$(file_at_ref src/lib/data/contracts/overview.test.ts)"
QA_RESULTS="$(file_at_ref docs/product/13_role_route_product_qa_results.md)"
VERIFY_SELF="$(file_at_ref scripts/verify-14-pr13-p2-qa-closeout.sh)"

for needle in "activePersona" "selfTitle" "selfDescription" "emptyTitleKey" "emptyDescriptionKey"; do
  if ! grep -Fq "$needle" <<< "$CONTRACTS_ROUTE"; then
    echo "FAIL: sozlesmeler route missing self-scope empty-state needle: $needle" >&2
    exit 1
  fi
done

for needle in "Sana ait sözleşme kaydı yok" "Tenant sözleşme metadata'sı mevcut"; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: tr locale missing contract self-scope copy: $needle" >&2
    exit 1
  fi
done

for needle in "No contract record for you" "Tenant contract metadata exists"; do
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: en locale missing contract self-scope copy: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "preserves tenant contract counts when scoped contract rows are empty" <<< "$CONTRACTS_TEST"; then
  echo "FAIL: contracts overview test must cover scoped-empty tenant-count preservation" >&2
  exit 1
fi

for needle in "assignedManagersHint" "emptyManagersHint"; do
  if ! grep -Fq "$needle" <<< "$DEPARTMENTS_ROUTE"; then
    echo "FAIL: departmanlar route missing manager metadata hint: $needle" >&2
    exit 1
  fi
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: tr locale missing manager metadata hint key: $needle" >&2
    exit 1
  fi
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: en locale missing manager metadata hint key: $needle" >&2
    exit 1
  fi
done

for needle in "QA-006 | P2" "QA-008 | P2" "Resolved" "Canias is the first provider, not the product abstraction"; do
  if ! grep -Fq "$needle" <<< "$QA_RESULTS"; then
    echo "FAIL: QA results missing closeout needle: $needle" >&2
    exit 1
  fi
done

if grep -Fq "| QA-006 | P2" <<< "$QA_RESULTS" && grep -F "| QA-006 | P2" <<< "$QA_RESULTS" | grep -Fq "| Open |"; then
  echo "FAIL: QA-006 is still open" >&2
  exit 1
fi

if grep -Fq "| QA-008 | P2" <<< "$QA_RESULTS" && grep -F "| QA-008 | P2" <<< "$QA_RESULTS" | grep -Fq "| Open |"; then
  echo "FAIL: QA-008 is still open" >&2
  exit 1
fi

if ! grep -Fq "PR14.0 PR13 P2 QA closeout" <<< "$VERIFY_SELF"; then
  echo "FAIL: verify script self-check missing PR14.0 label" >&2
  exit 1
fi

BASE_REF="$(git merge-base origin/main "$REF")"
while IFS= read -r changed; do
  [[ -z "$changed" ]] && continue
  case "$changed" in
    src/routes/_app/sozlesmeler.tsx) ;;
    src/routes/_app/departmanlar.tsx) ;;
    src/i18n/locales/tr-TR.json) ;;
    src/i18n/locales/en-US.json) ;;
    src/lib/data/contracts/overview.test.ts) ;;
    docs/product/13_role_route_product_qa_results.md) ;;
    scripts/verify-14-pr13-p2-qa-closeout.sh) ;;
    *)
      echo "FAIL: unexpected changed path for PR14.0 closeout: $changed" >&2
      exit 1
      ;;
  esac
done < <(git diff --name-only "$BASE_REF...$REF")

echo "OK: PR14.0 PR13 P2 QA closeout verification passed"
