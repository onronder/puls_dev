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

echo "Checking ${REF}: PR14.2 ERP connector onboarding empty state ..."

ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/erp.tsx)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"
DOC="$(file_at_ref docs/product/14_erp_connector_onboarding_empty_state.md)"
README="$(file_at_ref docs/product/README.md)"
VERIFY_SELF="$(file_at_ref scripts/verify-14-erp-connector-empty-state.sh)"

for needle in \
  "New customer tenants must be able to start from a no-connector PULS empty state." \
  "The no-connector state is real data posture, not demo fallback." \
  "Provider selection precedes metadata-only and preflight-ready connector states." \
  "No runtime sync, no credentials, and no ERP writes are introduced in PR14.2."; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR14.2 doc missing required product needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorLifecycleState" \
  "'no_tenant' | 'no_connector' | 'connector_selected'" \
  "providerOptions" \
  "CONNECTOR_PROVIDER_OPTIONS" \
  "isErpOverviewEmpty(data: ErpOverview)" \
  "return data.connectorState === 'no_tenant'" \
  "connectorState: connection ? 'connector_selected' : 'no_connector'"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing no-connector state needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "hasNoConnector" \
  "erp.onboarding.title" \
  "data.providerOptions.map" \
  "erp.onboarding.selectProvider" \
  "erp.onboarding.importMapping"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: /erp route missing onboarding empty-state needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "\"onboarding\"" \
  "\"Henüz connector tanımlı değil\"" \
  "\"providerOptions\"" \
  "\"Provider seç\"" \
  "\"Mapping içe aktar\""; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: tr locale missing onboarding key/copy: $needle" >&2
    exit 1
  fi
done

for needle in \
  "\"onboarding\"" \
  "\"No connector configured yet\"" \
  "\"providerOptions\"" \
  "\"Select provider\"" \
  "\"Import mapping\""; do
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: en locale missing onboarding key/copy: $needle" >&2
    exit 1
  fi
done

for needle in \
  "returns real no-connector onboarding state without demo fallback" \
  "demoEnabled.mockReturnValue(true)" \
  "connectorState).toBe('no_connector')" \
  "source).toBe('real')" \
  "providerOptions.map"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP test missing no-connector fallback/state needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.2 ERP connector onboarding empty state" \
  "no-connector state machine"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR14.2 onboarding section" >&2
    exit 1
  fi
done

if ! grep -Fq "PR14.2 ERP connector onboarding empty state" <<< "$VERIFY_SELF"; then
  echo "FAIL: verify script self-check missing PR14.2 label" >&2
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
      docs/product/14_erp_connector_onboarding_empty_state.md) ;;
      docs/product/README.md) ;;
      docs/product/13_route_packaging_proof_matrix.md) ;;
      docs/product/13_v1_feature_traceability_matrix.md) ;;
      docs/product/13_v1_product_packaging_strategy.md) ;;
      scripts/verify-14-erp-connector-empty-state.sh) ;;
      *)
        echo "FAIL: unexpected changed path for PR14.2 connector empty state: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      supabase/migrations/*|supabase/seed/puls-sanayi-v1/csv/*|supabase/seed/puls-sanayi-v1/manifest.json|services/*/src/*|package.json|.env*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR14.2 connector empty state: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"

  CHANGED_CONTENT="$(
    while IFS= read -r changed; do
      [[ "$changed" == "scripts/verify-14-erp-connector-empty-state.sh" ]] && continue
      [[ "$REF" == "WORKTREE" && "$changed" == supabase/.temp/* ]] && continue
      file_at_ref "$changed"
      printf '\n'
    done <<< "$CHANGED_FILES"
  )"
  if grep -Eiq "OPENAI_API_KEY|CANIAS_API_KEY|chat\.completions|responses\.create|sync_canias_now|write_to_canias|delete_or_overwrite" <<< "$CHANGED_CONTENT"; then
    echo "FAIL: changed files contain runtime/secret/ERP-write enablement tokens" >&2
    exit 1
  fi
fi

echo "OK: PR14.2 ERP connector onboarding empty state verification passed"
