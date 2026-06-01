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

echo "Checking ${REF}: PR14.1 connector preflight readiness ..."

ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/erp.tsx)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"
DOC="$(file_at_ref docs/product/14_connector_preflight_readiness.md)"
README="$(file_at_ref docs/product/README.md)"
VERIFY_SELF="$(file_at_ref scripts/verify-14-connector-preflight-readiness.sh)"

for needle in \
  "Canias is the first provider, not the product abstraction." \
  "PULS connector readiness is provider-agnostic." \
  "Canonical data model and unified namespace are the stable product boundary." \
  "Field mapping and identity reconciliation determine whether an external data source can feed PULS." \
  "No runtime sync, no credentials, and no ERP writes are introduced in PR14.1."; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: connector readiness doc missing required product needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "export type ErpOverview" \
  "ConnectorReadinessCheck" \
  "ConnectorNamespaceSummary" \
  "mapProviderLabel" \
  "buildDemoErpOverview" \
  "source_namespaces" \
  "entity_identity_map" \
  "is_sensitive"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing connector-preflight needle: $needle" >&2
    exit 1
  fi
done

if grep -Fq "type DemoErpOverview" <<< "$ERP_ADAPTER" || grep -Fq "DemoErpSyncLevel" <<< "$ERP_ADAPTER"; then
  echo "FAIL: ERP adapter must not use demo-owned ERP types as product contracts" >&2
  exit 1
fi

if grep -Fq "return 'Canias'" <<< "$ERP_ADAPTER"; then
  echo "FAIL: unknown ERP providers must not fall back to Canias" >&2
  exit 1
fi

for needle in \
  "Connector Preflight" \
  "data.readiness.checks" \
  "data.namespaces" \
  "data.transferModes" \
  "data.guardrails" \
  "canonicalField" \
  "sourceField"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: /erp route missing connector-preflight UI needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "\"title\": \"Connector preflight\"" \
  "\"canonicalField\"" \
  "\"sourceField\"" \
  "\"providerStatus\"" \
  "\"readinessChecks\"" \
  "\"guardrails\"" \
  "\"transferModes\""; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: tr locale missing connector-preflight key: $needle" >&2
    exit 1
  fi
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: en locale missing connector-preflight key: $needle" >&2
    exit 1
  fi
done

for needle in \
  "does not collapse unknown providers into Canias" \
  "hides sensitive" \
  "REDACTED_FIELD" \
  "keeps provider labels source-neutral"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP test missing connector source-neutrality/sensitivity needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.1 Connector preflight readiness" \
  "Provider-independent connector readiness"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR14.1 connector preflight section" >&2
    exit 1
  fi
done

if ! grep -Fq "PR14.1 connector preflight readiness" <<< "$VERIFY_SELF"; then
  echo "FAIL: verify script self-check missing PR14.1 label" >&2
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
      src/lib/data/setup/erp.ts) ;;
      src/lib/data/setup/erp.test.ts) ;;
      src/lib/data/index.ts) ;;
      src/routes/_app/erp.tsx) ;;
      src/i18n/locales/tr-TR.json) ;;
      src/i18n/locales/en-US.json) ;;
      docs/product/14_connector_preflight_readiness.md) ;;
      docs/product/README.md) ;;
      docs/product/13_route_packaging_proof_matrix.md) ;;
      docs/product/13_v1_feature_traceability_matrix.md) ;;
      docs/product/13_v1_product_packaging_strategy.md) ;;
      scripts/verify-14-connector-preflight-readiness.sh) ;;
      *)
        echo "FAIL: unexpected changed path for PR14.1 connector preflight: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      supabase/migrations/*|supabase/seed/puls-sanayi-v1/csv/*|supabase/seed/puls-sanayi-v1/manifest.json|services/*/src/*|package.json|.env*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR14.1 connector preflight: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"

  CHANGED_CONTENT="$(
    while IFS= read -r changed; do
      [[ "$changed" == "scripts/verify-14-connector-preflight-readiness.sh" ]] && continue
      file_at_ref "$changed"
      printf '\n'
    done <<< "$CHANGED_FILES"
  )"
  if grep -Eiq "OPENAI_API_KEY|CANIAS_API_KEY|chat\.completions|responses\.create|sync_canias_now|write_to_canias|delete_or_overwrite" <<< "$CHANGED_CONTENT"; then
    echo "FAIL: changed files contain runtime/secret/ERP-write enablement tokens" >&2
    exit 1
  fi
fi

echo "OK: PR14.1 connector preflight readiness verification passed"
