#!/usr/bin/env bash
set -euo pipefail

REF="${1:-HEAD}"

file_at_ref() {
  local path="$1"
  if [[ "$REF" == "WORKTREE" ]]; then
    cat "$path"
  else
    git show "${REF}:${path}"
  fi
}

echo "Checking ${REF}: PR14.11 connector preflight execution ..."

DOC="$(file_at_ref docs/product/14_connector_preflight_execution.md)"
README="$(file_at_ref docs/product/README.md)"
ROADMAP="$(file_at_ref docs/product/14_connector_implementation_roadmap.md)"
STRATEGY="$(file_at_ref docs/product/13_v1_product_packaging_strategy.md)"
ERP_TS="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
DASHBOARD_TS="$(file_at_ref src/lib/data/dashboard/overview.ts)"
DASHBOARD_TEST="$(file_at_ref src/lib/data/dashboard/overview.test.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/verikaynaklari.tsx)"
TR="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN="$(file_at_ref src/i18n/locales/en-US.json)"

for needle in \
  "PR14.11 turns connector setup into an explicit dry-run readiness gate." \
  "No live connector API call." \
  "No connector import execution." \
  "No credential capture or secret storage." \
  "No runtime sync." \
  "No ERP write-back." \
  "Source profile" \
  "Required field contract" \
  "Credential boundary" \
  "ERP write guardrail"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR14.11 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorPreflightResult" \
  "ConnectorPreflightCheck" \
  "buildConnectorPreflightResult" \
  "deriveRequiredMappingStatus" \
  "safeToRunRuntime: false" \
  "runtimeExecution: 'not_started'" \
  "credential_boundary" \
  "write_guardrail"; do
  if ! grep -Fq "$needle" <<< "$ERP_TS"; then
    echo "FAIL: ERP adapter missing preflight needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "erp-preflight-result" \
  "runPreflightMutation" \
  "data.preflight.checks" \
  "data.preflight.summaryKey" \
  "erp.actions.runPreflight" \
  "erp.preflightResult.sessionRun"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route missing preflight UI needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "statusPreflightReady" \
  "descriptionPreflightReady"; do
  if ! grep -Fq "$needle" <<< "$DASHBOARD_TS"; then
    echo "FAIL: dashboard adapter missing preflight-ready state: $needle" >&2
    exit 1
  fi
done

for needle in \
  "result.data.preflight" \
  "runtimeExecution: 'not_started'" \
  "blockedCount: 1"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP tests missing preflight case: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "uses preflight-ready copy" <<< "$DASHBOARD_TEST"; then
  echo "FAIL: dashboard tests missing preflight-ready copy case" >&2
  exit 1
fi

for needle in \
  "Kurulum kontrolünü çalıştır" \
  "Kontrol temiz" \
  "Kimlik bilgisi sınırı" \
  "Runtime sınırı" \
  "ERP yazma koruması"; do
  if ! grep -Fq "$needle" <<< "$TR"; then
    echo "FAIL: Turkish locale missing preflight copy: $needle" >&2
    exit 1
  fi
done

for needle in \
  "Run setup check" \
  "Check clean" \
  "Credential boundary" \
  "Runtime boundary" \
  "ERP write guardrail"; do
  if ! grep -Fq "$needle" <<< "$EN"; then
    echo "FAIL: English locale missing preflight copy: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.11 Connector preflight execution" \
  "14_connector_preflight_execution.md" \
  "scripts/verify-14-connector-preflight-execution.sh"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR14.11 reference: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "Results survive refresh by being recomputed from the persisted setup, mapping, namespace, and identity state." <<< "$ROADMAP"; then
  echo "FAIL: roadmap missing deterministic preflight refresh contract" >&2
  exit 1
fi

if ! grep -Fq "[x] Connector preflight validates readiness as a dry run with no ERP writes (PR14.11)" <<< "$STRATEGY"; then
  echo "FAIL: strategy DoD missing completed PR14.11 checkbox" >&2
  exit 1
fi

if [[ "$REF" == "WORKTREE" ]]; then
  CHANGED="$(git diff --name-only && git diff --cached --name-only && git ls-files --others --exclude-standard)"
else
  BASE="$(git merge-base origin/main "$REF" 2>/dev/null || git merge-base main "$REF")"
  CHANGED="$(git diff --name-only "$BASE" "$REF")"
fi

while IFS= read -r changed; do
  [[ -z "$changed" ]] && continue
  case "$changed" in
    docs/product/14_connector_preflight_execution.md) ;;
    docs/product/14_connector_implementation_roadmap.md) ;;
    docs/product/README.md) ;;
    docs/product/13_v1_product_packaging_strategy.md) ;;
    scripts/verify-14-connector-preflight-execution.sh) ;;
    src/lib/data/index.ts) ;;
    src/lib/data/dashboard/overview.ts) ;;
    src/lib/data/dashboard/overview.test.ts) ;;
    src/lib/data/setup/erp.ts) ;;
    src/lib/data/setup/erp.test.ts) ;;
    src/routes/_app/verikaynaklari.tsx) ;;
    src/i18n/locales/tr-TR.json) ;;
    src/i18n/locales/en-US.json) ;;
    supabase/.temp/*) ;;
    supabase/.branches/*) ;;
    *)
      echo "FAIL: unexpected changed path for PR14.11 connector preflight: $changed" >&2
      exit 1
      ;;
  esac

  case "$changed" in
    supabase/migrations/*|supabase/seed/puls-sanayi-v1/csv/*|supabase/seed/puls-sanayi-v1/manifest.json|package.json|pnpm-lock.yaml|.env*|services/*/src/*)
      echo "FAIL: forbidden path changed for PR14.11 connector preflight: $changed" >&2
      exit 1
      ;;
  esac
done <<< "$CHANGED"

if grep -R -E "credentials_ref|OPENAI_API_KEY|CANIAS_API_KEY|chat\\.completions|responses\\.create|sync_canias_now|write_to_canias|apply_import_batch|record_import_row|create_import_batch" \
  docs/product/14_connector_preflight_execution.md \
  src/lib/data/setup/erp.ts \
  src/routes/_app/verikaynaklari.tsx \
  src/i18n/locales/tr-TR.json \
  src/i18n/locales/en-US.json >/dev/null; then
  echo "FAIL: PR14.11 changed files contain forbidden runtime, credential, or import patterns" >&2
  exit 1
fi

echo "OK: PR14.11 connector preflight execution verification passed"
