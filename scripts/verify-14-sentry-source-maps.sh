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

echo "Checking ${REF}: PR14.9A Sentry source maps ..."

DOC="$(file_at_ref docs/product/14_sentry_source_maps.md)"
README="$(file_at_ref docs/product/README.md)"
STRATEGY="$(file_at_ref docs/product/13_v1_product_packaging_strategy.md)"
PACKAGE_JSON="$(file_at_ref package.json)"
ENV_EXAMPLE="$(file_at_ref .env.example)"
VITE_CONFIG="$(file_at_ref vite.config.ts)"
SENTRY_TS="$(file_at_ref src/lib/observability/sentry.ts)"

for required in \
  docs/product/14_sentry_source_maps.md \
  scripts/verify-14-sentry-source-maps.sh; do
  if [[ "$REF" == "WORKTREE" ]]; then
    [[ -f "$required" ]] || { echo "FAIL: missing required file $required" >&2; exit 1; }
  elif ! git cat-file -e "${REF}:${required}" 2>/dev/null; then
    echo "FAIL: missing required file at ${REF}: $required" >&2
    exit 1
  fi
done

for needle in \
  "PR14.9A completes the frontend Sentry setup posture" \
  "Source maps are uploaded through the Sentry Vite plugin and deleted from the public asset folder after upload." \
  "VITE_SENTRY_ALLOW_TEST_EVENT=true" \
  "?sentry_setup_check=1" \
  "No Sentry DSN, auth token, API key, connector credential, service-role key, or customer payload is committed."; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: source map doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  '"@sentry/vite-plugin"' \
  '"@sentry/react"'; do
  if ! grep -Fq "$needle" <<< "$PACKAGE_JSON"; then
    echo "FAIL: package.json missing Sentry dependency needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "SENTRY_SOURCE_MAPS=false" \
  "SENTRY_AUTH_TOKEN=" \
  "SENTRY_ORG=fittechs" \
  "SENTRY_PROJECT=puls_app" \
  "VITE_SENTRY_ALLOW_TEST_EVENT=false"; do
  if ! grep -Fq "$needle" <<< "$ENV_EXAMPLE"; then
    echo "FAIL: .env.example missing Sentry source map placeholder: $needle" >&2
    exit 1
  fi
done

for needle in \
  "sentryVitePlugin" \
  "SENTRY_SOURCE_MAPS" \
  "SENTRY_AUTH_TOKEN" \
  "VERCEL_GIT_COMMIT_SHA" \
  "build:" \
  "sourcemap: sentrySourceMapsEnabled" \
  "filesToDeleteAfterUpload" \
  ".output/public/assets/**/*.map" \
  "telemetry: false"; do
  if ! grep -Fq "$needle" <<< "$VITE_CONFIG"; then
    echo "FAIL: vite config missing source map needle: $needle" >&2
    exit 1
  fi
done

if grep -Fq "errorHandler" <<< "$VITE_CONFIG"; then
  echo "FAIL: source map upload failures must fail the build to avoid deploying public maps" >&2
  exit 1
fi

for needle in \
  "VITE_SENTRY_ALLOW_TEST_EVENT" \
  "sentry_setup_check" \
  "PULS Sentry setup check" \
  "isSentrySetupCheckRequested" \
  "captureSetupCheckOnce" \
  "sessionStorage"; do
  if ! grep -Fq "$needle" <<< "$SENTRY_TS"; then
    echo "FAIL: observability helper missing setup-check needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.9A Sentry source maps and setup check" \
  "14_sentry_source_maps.md" \
  "scripts/verify-14-sentry-source-maps.sh"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR14.9A reference: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "[x] Sentry source maps and guarded setup-check event are ready without exposing public maps or test UI (PR14.9A)" <<< "$STRATEGY"; then
  echo "FAIL: strategy DoD missing PR14.9A checkbox" >&2
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
      .env.example) ;;
      docs/product/13_v1_product_packaging_strategy.md) ;;
      docs/product/14_sentry_source_maps.md) ;;
      docs/product/README.md) ;;
      package.json) ;;
      pnpm-lock.yaml) ;;
      scripts/verify-14-sentry-source-maps.sh) ;;
      src/lib/observability/sentry.ts) ;;
      src/lib/observability/sentry.test.ts) ;;
      vite.config.ts) ;;
      *)
        echo "FAIL: unexpected changed path for PR14.9A source maps: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      supabase/migrations/*|supabase/seed/puls-sanayi-v1/csv/*|supabase/seed/puls-sanayi-v1/manifest.json|services/*/src/*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR14.9A source maps: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"

  CHANGED_CONTENT="$(
    while IFS= read -r changed; do
      [[ -z "$changed" ]] && continue
      [[ "$changed" == scripts/verify-14-sentry-source-maps.sh ]] && continue
      [[ "$REF" == "WORKTREE" && "$changed" == supabase/.temp/* ]] && continue
      file_at_ref "$changed"
      printf '\n'
    done <<< "$CHANGED_FILES"
  )"
  if grep -Eiq "VITE_SENTRY_DSN=https://|SENTRY_AUTH_TOKEN=[^[:space:]]+|postgres(ql)?://|service_role[[:space:]]*[:=][^[:space:]]+|sk-[A-Za-z0-9]{20,}|sync_canias_now|write_to_canias|delete_or_overwrite|chat\\.completions|responses\\.create" <<< "$CHANGED_CONTENT"; then
    echo "FAIL: changed files contain real secret/runtime/ERP-write enablement tokens" >&2
    exit 1
  fi
fi

echo "OK: PR14.9A Sentry source maps verification passed"
