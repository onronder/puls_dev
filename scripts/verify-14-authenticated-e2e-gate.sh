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
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

echo "Checking ${REF}: PR14.6 authenticated e2e gate ..."

DOC="$(file_at_ref docs/product/14_authenticated_e2e_gate.md)"
README="$(file_at_ref docs/product/README.md)"
STRATEGY="$(file_at_ref docs/product/13_v1_product_packaging_strategy.md)"
PACKAGE_JSON="$(file_at_ref package.json)"
PLAYWRIGHT_CONFIG="$(file_at_ref playwright.config.ts)"
E2E_SPEC="$(file_at_ref e2e/ui-stabilization.spec.ts)"
CI_WORKFLOW="$(file_at_ref .github/workflows/ci.yml)"
VERIFY_SELF="$(file_at_ref scripts/verify-14-authenticated-e2e-gate.sh)"

for needle in \
  "Authenticated e2e is the next quality gate before connector setup persistence." \
  "Connector setup persistence stays future until connector runtime and credential boundaries are explicit." \
  "E2E credentials must come from GitHub repository secrets, never from repo files." \
  "E2E_BASE_URL points to live Vercel for remote auth smoke." \
  "E2E_REQUIRE_AUTH=true makes authenticated specs fail instead of skip." \
  "No runtime sync, no credentials, and no ERP writes are introduced in PR14.6."; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR14.6 doc missing required needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  '"test:e2e:auth"' \
  "E2E_REQUIRE_AUTH=true" \
  "authenticated stabilization"; do
  if ! grep -Fq "$needle" <<< "$PACKAGE_JSON"; then
    echo "FAIL: package.json missing authenticated e2e script needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "E2E_BASE_URL" \
  "E2E_REQUIRE_AUTH" \
  "workers:" \
  "useExternalServer" \
  "webServer" \
  "baseURL"; do
  if ! grep -Fq "$needle" <<< "$PLAYWRIGHT_CONFIG"; then
    echo "FAIL: Playwright config missing remote base URL needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "E2E_REQUIRE_AUTH" \
  "E2E_EMPLOYEE_EMAIL" \
  "getEmployeeCredentials" \
  "getCredentials" \
  "setup route resolves for authenticated account without login bounce" \
  "employee account blocks setup route" \
  "test.skip(!hasCredentials && !requireAuth" \
  "Set E2E_EMAIL and E2E_PASSWORD for authenticated e2e"; do
  if ! grep -Fq "$needle" <<< "$E2E_SPEC"; then
    echo "FAIL: e2e spec missing required-auth needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "playwright-authenticated" \
  "https://puls-dev.vercel.app" \
  "secrets.E2E_EMAIL" \
  "secrets.E2E_PASSWORD" \
  "secrets.E2E_EMPLOYEE_EMAIL" \
  "secrets.E2E_EMPLOYEE_PASSWORD" \
  "pnpm run test:e2e:auth" \
  "Authenticated e2e skipped"; do
  if ! grep -Fq "$needle" <<< "$CI_WORKFLOW"; then
    echo "FAIL: CI workflow missing authenticated e2e needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.6 Authenticated e2e gate" \
  "live login coverage"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR14.6 section: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.6" \
  "Authenticated E2E gate"; do
  if ! grep -Fq "$needle" <<< "$STRATEGY"; then
    echo "FAIL: packaging strategy missing PR14.6 reference: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR14.6 authenticated e2e gate" <<< "$VERIFY_SELF"; then
  echo "FAIL: verify script self-check missing PR14.6 label" >&2
  exit 1
fi

if [[ "$REF" == "WORKTREE" ]]; then
  CHANGED_FILES="$(git diff --name-only "$(git merge-base origin/main HEAD)")"
else
  CHANGED_FILES="$(git diff --name-only "$(git merge-base origin/main "$REF")...$REF")"
fi

if [[ -n "$CHANGED_FILES" ]]; then
  while IFS= read -r changed; do
    [[ -z "$changed" ]] && continue
    if [[ "$REF" == "WORKTREE" && "$changed" == supabase/.temp/* ]]; then
      continue
    fi
    case "$changed" in
      .github/workflows/ci.yml) ;;
      e2e/ui-stabilization.spec.ts) ;;
      playwright.config.ts) ;;
      package.json) ;;
      docs/product/14_authenticated_e2e_gate.md) ;;
      docs/product/README.md) ;;
      docs/product/13_v1_product_packaging_strategy.md) ;;
      scripts/verify-14-authenticated-e2e-gate.sh) ;;
      *)
        echo "FAIL: unexpected changed path for PR14.6 authenticated e2e gate: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      src/*|src/**|supabase/migrations/*|supabase/seed/puls-sanayi-v1/csv/*|supabase/seed/puls-sanayi-v1/manifest.json|services/*/src/*|.env*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR14.6 authenticated e2e gate: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"

  CHANGED_CONTENT="$(
    while IFS= read -r changed; do
      [[ -z "$changed" ]] && continue
      [[ "$changed" == "scripts/verify-14-authenticated-e2e-gate.sh" ]] && continue
      [[ "$REF" == "WORKTREE" && "$changed" == supabase/.temp/* ]] && continue
      file_at_ref "$changed"
      printf '\n'
    done <<< "$CHANGED_FILES"
  )"
  if grep -Eiq "OPENAI_API_KEY|CANIAS_API_KEY|chat\.completions|responses\.create|sync_canias_now|write_to_canias|delete_or_overwrite|service_role|supabase_service_role|DATABASE_URL" <<< "$CHANGED_CONTENT"; then
    echo "FAIL: changed files contain secret/runtime/ERP-write enablement tokens" >&2
    exit 1
  fi
fi

echo "OK: PR14.6 authenticated e2e gate verification passed"
