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

echo "Checking ${REF}: PR14.8 connector setup persistence ..."

DOC="$(file_at_ref docs/product/14_connector_setup_persistence.md)"
README="$(file_at_ref docs/product/README.md)"
STRATEGY="$(file_at_ref docs/product/13_v1_product_packaging_strategy.md)"
MIGRATION="$(file_at_ref supabase/migrations/20260602090000_puls_integration_connector_setup_lifecycle.sql)"
SEED_LOAD="$(file_at_ref supabase/seed/puls-sanayi-v1/sql/01_load_puls_sanayi_seed.sql)"
ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/erp.tsx)"
DASHBOARD_ADAPTER="$(file_at_ref src/lib/data/dashboard/overview.ts)"
SETUP_ACCESS="$(file_at_ref src/lib/setup-access.ts)"
SETUP_GUARD="$(file_at_ref src/components/auth/SetupRouteGuard.tsx)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
VERIFY_SELF="$(file_at_ref scripts/verify-14-connector-setup-persistence.sh)"

for needle in \
  "Connector setup persistence is the first durable step between an empty PULS tenant and future connector runtime." \
  "Canias and CSV / Excel are MVP setup sources" \
  "No runtime sync is enabled." \
  "No credentials, API keys, tokens, passwords, or secret references are captured." \
  "Manager can inspect connector setup posture." \
  "PR14.8 does not require live authenticated e2e to click the new setup action"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR14.8 doc missing product needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "connector_setup_status" \
  "connector_setup_step" \
  "connection_key" \
  "setup_status" \
  "setup_step" \
  "is_enabled" \
  "owned_domains" \
  "setup_metadata" \
  "canias-default" \
  "csv-excel-default" \
  "puls_core.is_manager_or_admin()" \
  "puls_core.is_admin()"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: migration missing connector setup lifecycle needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "connection_key" \
  "preflight_ready" \
  "owned_domains" \
  "credential_boundary"; do
  if ! grep -Fq "$needle" <<< "$SEED_LOAD"; then
    echo "FAIL: seed load missing PR14.8 connector setup seed needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "startConnectorSetup" \
  "SETUP_PROVIDER_CONFIG" \
  "setupAvailable" \
  "canias-default" \
  "csv-excel-default" \
  "source_ownership" \
  "select('*')" \
  "setup_status" \
  "owned_domains"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing persistence needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "useMutation" \
  "startConnectorSetup" \
  "canManageConnectors" \
  "allowConnectorReadOnly" \
  "adminRequiredAction" \
  "persistedSetupHint"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route missing setup persistence UX needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "canInspectConnectorSetup" \
  "manager"; do
  if ! grep -Fq "$needle" <<< "$SETUP_ACCESS"; then
    echo "FAIL: setup access missing manager inspect needle: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "allowConnectorReadOnly" <<< "$SETUP_GUARD"; then
  echo "FAIL: setup route guard missing read-only connector access prop" >&2
  exit 1
fi

for needle in \
  "descriptionSetupDraft" \
  "statusSetupDraft" \
  "statusDisabled" \
  "setupStatus"; do
  if ! grep -Fq "$needle" <<< "$DASHBOARD_ADAPTER"; then
    echo "FAIL: dashboard adapter missing setup-status ERP card needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  '"persistedSetupHint"' \
  '"startSetup"' \
  '"creating"' \
  '"adminRequiredAction"' \
  '"setup_draft"' \
  '"preflight_ready"'; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing PR14.8 key: $needle" >&2
    exit 1
  fi
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing PR14.8 key: $needle" >&2
    exit 1
  fi
done

for needle in \
  "creates an admin-scoped Canias setup draft" \
  "keeps existing connector setup posture instead of downgrading to draft" \
  "rejects unsupported provider setup before writing"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP setup tests missing persistence case: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.8 Connector setup persistence" \
  "14_connector_setup_persistence.md" \
  "scripts/verify-14-connector-setup-persistence.sh"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR14.8 reference: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR14.8" <<< "$STRATEGY"; then
  echo "FAIL: packaging strategy missing PR14.8" >&2
  exit 1
fi

if ! grep -Fq "PR14.8 connector setup persistence" <<< "$VERIFY_SELF"; then
  echo "FAIL: verify script self-check missing PR14.8 label" >&2
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
      docs/product/14_connector_setup_persistence.md) ;;
      docs/product/README.md) ;;
      docs/product/13_v1_product_packaging_strategy.md) ;;
      scripts/verify-14-connector-setup-persistence.sh) ;;
      supabase/migrations/20260602090000_puls_integration_connector_setup_lifecycle.sql) ;;
      supabase/seed/puls-sanayi-v1/sql/01_load_puls_sanayi_seed.sql) ;;
      src/components/auth/SetupRouteGuard.tsx) ;;
      src/i18n/locales/en-US.json) ;;
      src/i18n/locales/tr-TR.json) ;;
      src/lib/data/dashboard/overview.test.ts) ;;
      src/lib/data/dashboard/overview.ts) ;;
      src/lib/data/index.ts) ;;
      src/lib/data/setup/erp.test.ts) ;;
      src/lib/data/setup/erp.ts) ;;
      src/lib/setup-access.ts) ;;
      src/routes/_app/erp.tsx) ;;
      *)
        echo "FAIL: unexpected changed path for PR14.8 connector setup persistence: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      supabase/seed/puls-sanayi-v1/csv/*|supabase/seed/puls-sanayi-v1/manifest.json|services/*/src/*|package.json|.env*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR14.8 connector setup persistence: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"

  CHANGED_CONTENT="$(
    while IFS= read -r changed; do
      [[ -z "$changed" ]] && continue
      [[ "$changed" == scripts/verify-14-connector-setup-persistence.sh ]] && continue
      [[ "$REF" == "WORKTREE" && "$changed" == supabase/.temp/* ]] && continue
      file_at_ref "$changed"
      printf '\n'
    done <<< "$CHANGED_FILES"
  )"
  if grep -Eiq "OPENAI_API_KEY|CANIAS_API_KEY|SUPABASE_SERVICE_ROLE|service_role|chat\.completions|responses\.create|sync_canias_now|write_to_canias|delete_or_overwrite|api[_-]?key[[:space:]]*[:=]|password[[:space:]]*[:=]|token[[:space:]]*[:=]" <<< "$CHANGED_CONTENT"; then
    echo "FAIL: changed files contain secret/runtime/ERP-write enablement tokens" >&2
    exit 1
  fi
fi

echo "OK: PR14.8 connector setup persistence verification passed"
