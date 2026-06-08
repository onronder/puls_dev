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

echo "Checking ${REF}: PR14.9 error observability and Sentry ..."

DOC="$(file_at_ref docs/product/14_error_observability_sentry.md)"
README="$(file_at_ref docs/product/README.md)"
STRATEGY="$(file_at_ref docs/product/13_v1_product_packaging_strategy.md)"
PACKAGE_JSON="$(file_at_ref package.json)"
ENV_EXAMPLE="$(file_at_ref .env.example)"
VITE_CONFIG="$(file_at_ref vite.config.ts)"
SENTRY_TS="$(file_at_ref src/lib/observability/sentry.ts)"
SENTRY_TEST="$(file_at_ref src/lib/observability/sentry.test.ts)"
ROOT_ROUTE="$(file_at_ref src/routes/__root.tsx)"
ERROR_BOUNDARY="$(file_at_ref src/components/puls/AppErrorBoundary.tsx)"
ERROR_FALLBACK="$(file_at_ref src/components/puls/AppErrorFallback.tsx)"
ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/verikaynaklari.tsx)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
INDEX_TS="$(file_at_ref src/lib/data/index.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"
ERP_SERVICE_README="$(file_at_ref services/erp-connector/README.md)"
LLM_SERVICE_README="$(file_at_ref services/llm-gateway/README.md)"

for required in \
  docs/product/14_error_observability_sentry.md \
  scripts/verify-14-error-observability-sentry.sh \
  src/lib/observability/sentry.ts \
  src/lib/observability/sentry.test.ts \
  src/components/puls/AppErrorBoundary.tsx \
  src/components/puls/AppErrorFallback.tsx; do
  if [[ "$REF" == "WORKTREE" ]]; then
    [[ -f "$required" ]] || { echo "FAIL: missing required file $required" >&2; exit 1; }
  elif ! git cat-file -e "${REF}:${required}" 2>/dev/null; then
    echo "FAIL: missing required file at ${REF}: $required" >&2
    exit 1
  fi
done

for needle in \
  "PR14.9 makes the connector setup flow observable without opening connector runtime." \
  "Sentry must not receive auth emails, raw auth UUIDs, tenant UUIDs, passwords, API keys, tokens, DSNs, service-role keys, cookies, authorization headers, connector credentials, or raw provider payloads." \
  "\`VITE_SENTRY_DSN\` empty means no Sentry init." \
  "No connector mapping editor." \
  "No credential capture or secret reference storage." \
  "Service skeletons remain health-only; backend Sentry wiring waits for real runtime."; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR14.9 doc missing needle: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq '"@sentry/react"' <<< "$PACKAGE_JSON"; then
  echo "FAIL: package.json missing @sentry/react dependency" >&2
  exit 1
fi

for needle in \
  "VITE_SENTRY_DSN=" \
  "VITE_SENTRY_TRACES_SAMPLE_RATE=0"; do
  if ! grep -Fq "$needle" <<< "$ENV_EXAMPLE"; then
    echo "FAIL: .env.example missing Sentry needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "sendDefaultPii: false" \
  "tracesSampleRate: traceSampleRate" \
  "beforeSend" \
  "sanitizeSentryEvent" \
  "redactSensitiveText" \
  "SENSITIVE_QUERY_KEYS" \
  "loadBrowserSentry" \
  "captureAppError" \
  "isObservabilityConfigured"; do
  if ! grep -Fq "$needle" <<< "$SENTRY_TS"; then
    echo "FAIL: observability helper missing needle: $needle" >&2
    exit 1
  fi
done

if grep -Fq "@sentry" <<< "$VITE_CONFIG"; then
  echo "FAIL: vite config must not externalize or special-case Sentry in the server bundle" >&2
  exit 1
fi

for needle in \
  "redacts sensitive text" \
  "sanitizes URL query values" \
  "removes user identity and request secrets"; do
  if ! grep -Fq "$needle" <<< "$SENTRY_TEST"; then
    echo "FAIL: observability tests missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "initObservability()" \
  "AppErrorBoundary" \
  "Outlet"; do
  if ! grep -Fq "$needle" <<< "$ROOT_ROUTE"; then
    echo "FAIL: root route missing Sentry boundary needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "captureAppError" \
  "react_error_boundary" \
  "AppErrorFallback"; do
  if ! grep -Fq "$needle" <<< "$ERROR_BOUNDARY"; then
    echo "FAIL: app error boundary missing observability needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "Sayfayı yenile" \
  "Go to dashboard" \
  "AppErrorFallback"; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE$EN_LOCALE$ERROR_FALLBACK"; then
    echo "FAIL: app error fallback missing i18n/UI needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "mapConnectorSetupError" \
  "PULS_CONNECTOR_ADMIN_REQUIRED" \
  "PULS_CONNECTOR_PROVIDER_UNAVAILABLE" \
  "erp.errors.permissionDenied"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing connector error mapping needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "captureAppError" \
  "mapConnectorSetupError" \
  "providerId: selectedProviderId" \
  "toast.error(t(mapped.toastKey))"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route missing setup observability needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "maps connector setup errors to safe user messages" \
  "rejects setup when tenant context is missing" \
  "rejects setup when persona is not admin scoped"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP tests missing connector setup error case: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "mapConnectorSetupError" <<< "$INDEX_TS"; then
  echo "FAIL: data index missing connector setup error export" >&2
  exit 1
fi

for needle in \
  '"appError"' \
  '"tenantMissing"' \
  '"adminRequired"' \
  '"providerUnavailable"' \
  '"permissionDenied"' \
  '"setupSaveFailed"'; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing observability key: $needle" >&2
    exit 1
  fi
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing observability key: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.9 Error observability and Sentry" \
  "14_error_observability_sentry.md" \
  "scripts/verify-14-error-observability-sentry.sh"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR14.9 reference: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "[x] Connector setup errors are observable, scrubbed, and user-friendly (PR14.9)" <<< "$STRATEGY"; then
  echo "FAIL: strategy DoD missing completed PR14.9 checkbox" >&2
  exit 1
fi

for needle in \
  "PR14.9 defines the Sentry posture" \
  "raw Canias payloads" \
  "prompts, auth tokens"; do
  if ! grep -Fq "$needle" <<< "$ERP_SERVICE_README$LLM_SERVICE_README"; then
    echo "FAIL: service README missing backend observability posture: $needle" >&2
    exit 1
  fi
done

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
      docs/product/14_error_observability_sentry.md) ;;
      docs/product/README.md) ;;
      docs/product/13_v1_product_packaging_strategy.md) ;;
      package.json) ;;
      pnpm-lock.yaml) ;;
      scripts/verify-14-error-observability-sentry.sh) ;;
      vite.config.ts) ;;
      src/components/puls/AppErrorBoundary.tsx) ;;
      services/erp-connector/README.md) ;;
      services/llm-gateway/README.md) ;;
      src/components/puls/AppErrorFallback.tsx) ;;
      src/i18n/locales/en-US.json) ;;
      src/i18n/locales/tr-TR.json) ;;
      src/lib/data/index.ts) ;;
      src/lib/data/setup/erp.test.ts) ;;
      src/lib/data/setup/erp.ts) ;;
      src/lib/observability/sentry.test.ts) ;;
      src/lib/observability/sentry.ts) ;;
      src/routes/__root.tsx) ;;
      src/routes/_app/verikaynaklari.tsx) ;;
      *)
        echo "FAIL: unexpected changed path for PR14.9 error observability: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      supabase/migrations/*|supabase/seed/puls-sanayi-v1/csv/*|supabase/seed/puls-sanayi-v1/manifest.json|services/*/src/*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR14.9 error observability: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"

  CHANGED_CONTENT="$(
    while IFS= read -r changed; do
      [[ -z "$changed" ]] && continue
      [[ "$changed" == scripts/verify-14-error-observability-sentry.sh ]] && continue
      [[ "$REF" == "WORKTREE" && "$changed" == supabase/.temp/* ]] && continue
      file_at_ref "$changed"
      printf '\n'
    done <<< "$CHANGED_FILES"
  )"
  if grep -Eiq "VITE_SENTRY_DSN=https://|SENTRY_DSN=https://|postgres(ql)?://|service_role[[:space:]]*[:=][^[:space:]]+|sk-[A-Za-z0-9]{20,}|sync_canias_now|write_to_canias|delete_or_overwrite|chat\\.completions|responses\\.create" <<< "$CHANGED_CONTENT"; then
    echo "FAIL: changed files contain real secret/runtime/ERP-write enablement tokens" >&2
    exit 1
  fi
fi

echo "OK: PR14.9 error observability and Sentry verification passed"
