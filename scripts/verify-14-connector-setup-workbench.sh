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

echo "Checking ${REF}: PR14.3 connector setup workbench ..."

ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/erp.tsx)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"
DOC="$(file_at_ref docs/product/14_connector_setup_workbench.md)"
README="$(file_at_ref docs/product/README.md)"
VERIFY_SELF="$(file_at_ref scripts/verify-14-connector-setup-workbench.sh)"

for needle in \
  "Connector Setup Workbench keeps provider selection separate from runtime integration." \
  "Provider preview is local UI state; it does not write connector metadata." \
  "Canonical mapping, unified namespace, and identity reconciliation remain the stable product boundary." \
  "No runtime sync, no credentials, and no ERP writes are introduced in PR14.3."; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR14.3 doc missing required product needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorSetupStep" \
  "ConnectorProviderRequirement" \
  "setupSteps" \
  "requirements: ConnectorProviderRequirement[]" \
  "readinessLabelKey" \
  "buildConnectorSetupSteps" \
  "'source' | 'mapping' | 'namespace' | 'preflight' | 'runtime'"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing setup workbench needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "selectedProviderId" \
  "data.setupSteps.map" \
  "aria-pressed" \
  "erp.workbench.title" \
  "erp.providerPreview.requirements" \
  "selectedProvider.requirements.map"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: /erp route missing setup workbench UI needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "\"workbench\"" \
  "\"Connector setup workbench\"" \
  "\"setupSteps\"" \
  "\"providerPreview\"" \
  "\"providerRequirements\"" \
  "\"Seçim önizlemesi\""; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: tr locale missing setup workbench key/copy: $needle" >&2
    exit 1
  fi
done

for needle in \
  "\"workbench\"" \
  "\"Connector setup workbench\"" \
  "\"setupSteps\"" \
  "\"providerPreview\"" \
  "\"providerRequirements\"" \
  "\"Selection preview\""; do
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: en locale missing setup workbench key/copy: $needle" >&2
    exit 1
  fi
done

for needle in \
  "overview.setupSteps.map" \
  "result.data.setupSteps.every" \
  "providerOptions.every((option) => option.requirements.length > 0)" \
  "erp.providerOptions.canias.readiness"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP test missing setup workbench coverage needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.3 Connector setup workbench" \
  "provider-agnostic setup workbench"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR14.3 setup workbench section" >&2
    exit 1
  fi
done

if ! grep -Fq "PR14.3 connector setup workbench" <<< "$VERIFY_SELF"; then
  echo "FAIL: verify script self-check missing PR14.3 label" >&2
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
      docs/product/14_connector_setup_workbench.md) ;;
      docs/product/README.md) ;;
      scripts/verify-14-connector-setup-workbench.sh) ;;
      *)
        echo "FAIL: unexpected changed path for PR14.3 connector setup workbench: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      supabase/migrations/*|supabase/seed/puls-sanayi-v1/csv/*|supabase/seed/puls-sanayi-v1/manifest.json|services/*/src/*|package.json|.env*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR14.3 connector setup workbench: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"

  CHANGED_CONTENT="$(
    while IFS= read -r changed; do
      [[ "$changed" == "scripts/verify-14-connector-setup-workbench.sh" ]] && continue
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

echo "OK: PR14.3 connector setup workbench verification passed"
