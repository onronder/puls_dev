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

echo "Checking ${REF}: PR14.12B connector state consistency ..."

DOC="$(file_at_ref docs/product/14_connector_state_consistency_findings.md)"
README="$(file_at_ref docs/product/README.md)"
ROADMAP="$(file_at_ref docs/product/14_connector_implementation_roadmap.md)"
MIGRATION="$(file_at_ref supabase/migrations/20260603110000_puls_integration_connector_state_consistency.sql)"
SEED_LOAD="$(file_at_ref supabase/seed/puls-sanayi-v1/sql/01_load_puls_sanayi_seed.sql)"
ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
DASHBOARD_ADAPTER="$(file_at_ref src/lib/data/dashboard/overview.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/verikaynaklari.tsx)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
DASHBOARD_TEST="$(file_at_ref src/lib/data/dashboard/overview.test.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"
VERIFY_SELF="$(file_at_ref scripts/verify-14-connector-state-consistency.sh)"

for needle in \
  "PULS is source-independent. Canias is one source profile" \
  "Dashboard said \`Kontrol temiz\` while \`/erp\` showed credential warning" \
  "Starting setup for an already owned provider/domain must resume the existing setup" \
  "PR14.12B does not enable connector runtime"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR14.12B doc missing state consistency needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "credential_boundary_required" \
  "duplicate_provider_domain_setup" \
  "missing credentials keep the setup at mapping_ready/preflight"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: PR14.12B migration missing state consistency needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "mapping_ready'::puls_integration.connector_setup_status" \
  "credential_boundary"; do
  if ! grep -Fq "$needle" <<< "$SEED_LOAD"; then
    echo "FAIL: seed loader missing PR14.12B setup posture needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "pickCurrentErpConnection" \
  "hasConnectorDomainOverlap" \
  "runConnectorPreflight" \
  "setup_preflight" \
  "PULS_CONNECTOR_DOMAIN_OWNED"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing PR14.12B behavior needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "pickCurrentErpConnection" \
  "statusCredentialPending" \
  "descriptionCredentialPending" \
  "credentialState"; do
  if ! grep -Fq "$needle" <<< "$DASHBOARD_ADAPTER"; then
    echo "FAIL: dashboard adapter missing PR14.12B credential-aware needle: $needle" >&2
    exit 1
  fi
done

if grep -Fq "select('*')" <<< "$ERP_ADAPTER"$'\n'"$DASHBOARD_ADAPTER"; then
  echo "FAIL: connector/dashboard adapters must not use select('*') on connector data" >&2
  exit 1
fi

for needle in \
  "runConnectorPreflight" \
  "persistedRun" \
  "messageKey"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route missing persisted preflight UI needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  '"statusCredentialPending"' \
  '"descriptionCredentialPending"' \
  '"domainOwned"' \
  '"persistedRun"' \
  '"syncLogMessages"'; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing PR14.12B key: $needle" >&2
    exit 1
  fi
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing PR14.12B key: $needle" >&2
    exit 1
  fi
done

for needle in \
  "newer duplicate draft" \
  "PULS_CONNECTOR_DOMAIN_OWNED" \
  "persists a dry-run preflight record"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP tests missing PR14.12B behavior case: $needle" >&2
    exit 1
  fi
done

for needle in \
  "credential-missing preflight clean" \
  "statusCredentialPending"; do
  if ! grep -Fq "$needle" <<< "$DASHBOARD_TEST"; then
    echo "FAIL: dashboard tests missing PR14.12B dashboard consistency case: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.12B Connector state consistency findings" \
  "14_connector_state_consistency_findings.md" \
  "20260603110000_puls_integration_connector_state_consistency.sql" \
  "scripts/verify-14-connector-state-consistency.sh"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR14.12B reference: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.12B - Connector State Consistency Findings" \
  "A setup with missing credentials must not be shown as clean" \
  "Duplicate provider/domain setup is resumed or blocked"; do
  if ! grep -Fq "$needle" <<< "$ROADMAP"; then
    echo "FAIL: roadmap missing PR14.12B reference: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR14.12B connector state consistency" <<< "$VERIFY_SELF"; then
  echo "FAIL: verify script self-check missing PR14.12B label" >&2
  exit 1
fi

if grep -Eiq 'type=["'\'']password["'\'']|name=["'\''](apiKey|api_key|token|secret|password|connectionString)["'\'']|placeholder=.*(API key|token|password|secret)|sync_canias_now|write_to_canias|delete_or_overwrite|live connector runtime enabled' <<< "$ERP_ROUTE"$'\n'"$ERP_ADAPTER"$'\n'"$DASHBOARD_ADAPTER"; then
  echo "FAIL: PR14.12B introduced credential input or runtime enablement pattern" >&2
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
      docs/product/14_connector_state_consistency_findings.md) ;;
      docs/product/14_connector_implementation_roadmap.md) ;;
      docs/product/README.md) ;;
      scripts/verify-14-connector-state-consistency.sh) ;;
      supabase/migrations/20260603110000_puls_integration_connector_state_consistency.sql) ;;
      supabase/seed/puls-sanayi-v1/sql/01_load_puls_sanayi_seed.sql) ;;
      src/i18n/locales/en-US.json) ;;
      src/i18n/locales/tr-TR.json) ;;
      src/lib/data/dashboard/overview.test.ts) ;;
      src/lib/data/dashboard/overview.ts) ;;
      src/lib/data/index.ts) ;;
      src/lib/data/setup/erp.test.ts) ;;
      src/lib/data/setup/erp.ts) ;;
      src/routes/_app/verikaynaklari.tsx) ;;
      *)
        echo "FAIL: unexpected changed path for PR14.12B connector state consistency: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      supabase/seed/puls-sanayi-v1/csv/*|supabase/seed/puls-sanayi-v1/manifest.json|services/*/src/*|package.json|.env*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR14.12B connector state consistency: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

echo "OK: PR14.12B connector state consistency verification passed"
