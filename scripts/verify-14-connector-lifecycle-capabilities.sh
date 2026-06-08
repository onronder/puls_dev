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

echo "Checking ${REF}: PR14.13 connector lifecycle capabilities ..."

DOC="$(file_at_ref docs/product/14_connector_lifecycle_capabilities.md)"
README="$(file_at_ref docs/product/README.md)"
ROADMAP="$(file_at_ref docs/product/14_connector_implementation_roadmap.md)"
ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/verikaynaklari.tsx)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"
VERIFY_SELF="$(file_at_ref scripts/verify-14-connector-lifecycle-capabilities.sh)"

for needle in \
  "PULS is source-independent" \
  "No Canias-only architecture" \
  "Domain ownership is canonical-data-class scoped" \
  "\`ErpOverview\` includes \`lifecycle\`, \`capabilities\`, and \`domainOwnership\`"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR14.13 doc missing lifecycle/capability needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorLifecycleStage" \
  "ConnectorSourceCapability" \
  "ConnectorDomainOwnership" \
  "buildConnectorLifecycle" \
  "buildConnectorSourceCapabilities" \
  "buildConnectorDomainOwnership" \
  "domainOwnership"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing PR14.13 model needle: $needle" >&2
    exit 1
  fi
done

if grep -Fq "select('*')" <<< "$ERP_ADAPTER"; then
  echo "FAIL: connector adapter must not use select('*')" >&2
  exit 1
fi

for needle in \
  "data.lifecycle" \
  "data.capabilities" \
  "data.domainOwnership" \
  "domainOwnershipTone" \
  't(data.lifecycle.labelKey)' \
  't(`erp.domainOwnership.status.${domain.status}`)' \
  "xl:grid-cols-5" \
  "xl:grid-cols-4"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route missing lifecycle/capability/responsive needle: $needle" >&2
    exit 1
  fi
done

if grep -Fq "data.lifecycle.stage" <<< "$ERP_ROUTE"; then
  echo "FAIL: ERP route must not render raw lifecycle stage enum values" >&2
  exit 1
fi

for needle in \
  '"lifecycleStages"' \
  '"capabilities"' \
  '"domainOwnership"' \
  '"runtime_closed"' \
  '"owned_by_current"'; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing PR14.13 key: $needle" >&2
    exit 1
  fi
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing PR14.13 key: $needle" >&2
    exit 1
  fi
done

for needle in \
  "stage: 'credential'" \
  "domain_ownership" \
  "api_runtime" \
  "owned_by_current" \
  "transfer_method"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP tests missing PR14.13 behavior case: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.13 Connector lifecycle capabilities" \
  "14_connector_lifecycle_capabilities.md" \
  "scripts/verify-14-connector-lifecycle-capabilities.sh"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR14.13 reference: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.13 - Connector Lifecycle Capabilities" \
  "Canias is treated as one source profile" \
  "Database migration"; do
  if ! grep -Fq "$needle" <<< "$ROADMAP"; then
    echo "FAIL: roadmap missing PR14.13 reference: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR14.13 connector lifecycle capabilities" <<< "$VERIFY_SELF"; then
  echo "FAIL: verify script self-check missing PR14.13 label" >&2
  exit 1
fi

if grep -Eiq 'type=["'\'']password["'\'']|name=["'\''](apiKey|api_key|token|secret|password|connectionString)["'\'']|placeholder=.*(API key|token|password|secret)|sync_canias_now|write_to_canias|delete_or_overwrite|live connector runtime enabled' <<< "$ERP_ROUTE"$'\n'"$ERP_ADAPTER"; then
  echo "FAIL: PR14.13 introduced credential input or runtime enablement pattern" >&2
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
      docs/product/14_connector_lifecycle_capabilities.md) ;;
      docs/product/14_connector_implementation_roadmap.md) ;;
      docs/product/README.md) ;;
      scripts/verify-14-connector-lifecycle-capabilities.sh) ;;
      e2e/smoke.spec.ts) ;;
      e2e/ui-stabilization.spec.ts) ;;
      src/i18n/locales/en-US.json) ;;
      src/i18n/locales/tr-TR.json) ;;
      src/lib/data/setup/erp.test.ts) ;;
      src/lib/data/setup/erp.ts) ;;
      src/routes/_app/verikaynaklari.tsx) ;;
      *)
        echo "FAIL: unexpected changed path for PR14.13 connector lifecycle capabilities: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      supabase/migrations/*|supabase/seed/puls-sanayi-v1/csv/*|supabase/seed/puls-sanayi-v1/manifest.json|services/*/src/*|package.json|.env*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR14.13 connector lifecycle capabilities: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

echo "OK: PR14.13 connector lifecycle capabilities verification passed"
