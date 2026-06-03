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

echo "Checking ${REF}: PR14.12 source credential boundary ..."

DOC="$(file_at_ref docs/product/14_source_credential_boundary.md)"
README="$(file_at_ref docs/product/README.md)"
ROADMAP="$(file_at_ref docs/product/14_connector_implementation_roadmap.md)"
MIGRATION="$(file_at_ref supabase/migrations/20260603100000_puls_integration_source_credential_boundary.sql)"
ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/erp.tsx)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"
VERIFY_SELF="$(file_at_ref scripts/verify-14-source-credential-boundary.sh)"

for needle in \
  "PR14.12 defines source-independent credential boundary state, not credential capture." \
  "Canias is a source profile, not the credential architecture." \
  "No plaintext connector secrets are stored in product tables." \
  "credentials_ref is an opaque server-side reference, not a secret value." \
  "No live connector runtime is enabled in PR14.12." \
  "The client adapter must not select credentials_ref."; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR14.12 doc missing boundary needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "connector_auth_mode" \
  "connector_credential_state" \
  "auth_mode" \
  "credential_required" \
  "credential_state" \
  "credential_last_verified_at" \
  "credential_last_failed_at" \
  "credential_error_code" \
  "credentials_ref" \
  "apply_connector_credential_defaults" \
  "puls_integration_credential_state_ref_check" \
  "server_side_future"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: migration missing credential boundary needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorAuthMode" \
  "ConnectorCredentialState" \
  "ConnectorCredentialBoundary" \
  "defaultAuthModeForMethod" \
  "buildConnectorCredentialBoundary" \
  "credentialBoundary" \
  "authMode" \
  "credentialRequired" \
  "credentialState"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing source credential boundary needle: $needle" >&2
    exit 1
  fi
done

if grep -Fq "select('*')" <<< "$ERP_ADAPTER"; then
  echo "FAIL: ERP adapter must not use select('*') on connector data" >&2
  exit 1
fi

if grep -Fq "credentials_ref" <<< "$ERP_ADAPTER"; then
  echo "FAIL: ERP adapter must not select or expose credentials_ref" >&2
  exit 1
fi

for needle in \
  "credentialBoundary" \
  "KeyRound" \
  "erp.sections.credentialBoundary" \
  "erp.credentialBoundary.noReadback" \
  "erp.authModes."; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route missing credential boundary UI needle: $needle" >&2
    exit 1
  fi
done

if grep -Eiq 'type=["'\'']password["'\'']|name=["'\''](apiKey|api_key|token|secret|password|connectionString)["'\'']|placeholder=.*(API key|token|password|secret)' <<< "$ERP_ROUTE"; then
  echo "FAIL: ERP route introduced credential/secret input UI" >&2
  exit 1
fi

for needle in \
  '"credentialPending"' \
  '"credentialBoundary"' \
  '"authModes"' \
  '"custom_secret_ref"' \
  '"not_required"' \
  '"missing"' \
  '"verified"'; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing credential boundary key: $needle" >&2
    exit 1
  fi
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing credential boundary key: $needle" >&2
    exit 1
  fi
done

for needle in \
  "credentialBoundary" \
  "credential_required" \
  "credential_state" \
  "secret://must-not-leak" \
  "not.toContain('secret://must-not-leak')" \
  "CSV / Excel setup as credential-not-required"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP tests missing credential boundary case: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.12 Source credential boundary" \
  "14_source_credential_boundary.md" \
  "20260603100000_puls_integration_source_credential_boundary.sql" \
  "scripts/verify-14-source-credential-boundary.sh"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR14.12 reference: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.12" \
  "Source Credential Boundary" \
  "Canias remains a source profile, not the credential architecture."; do
  if ! grep -Fq "$needle" <<< "$ROADMAP"; then
    echo "FAIL: connector roadmap missing PR14.12 reference: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR14.12 source credential boundary" <<< "$VERIFY_SELF"; then
  echo "FAIL: verify script self-check missing PR14.12 label" >&2
  exit 1
fi

if grep -Eiq "chat\.completions|responses\.create|OPENAI_API_KEY|CANIAS_API_KEY|sync_canias_now|write_to_canias|delete_or_overwrite|live connector runtime enabled" <<< "$ERP_ADAPTER"$'\n'"$ERP_ROUTE"; then
  echo "FAIL: adapter/route contain runtime or AI enablement tokens" >&2
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
      docs/product/14_source_credential_boundary.md) ;;
      docs/product/14_connector_implementation_roadmap.md) ;;
      docs/product/README.md) ;;
      scripts/verify-14-source-credential-boundary.sh) ;;
      supabase/migrations/20260603100000_puls_integration_source_credential_boundary.sql) ;;
      src/i18n/locales/en-US.json) ;;
      src/i18n/locales/tr-TR.json) ;;
      src/lib/data/setup/erp.test.ts) ;;
      src/lib/data/setup/erp.ts) ;;
      src/routes/_app/erp.tsx) ;;
      *)
        echo "FAIL: unexpected changed path for PR14.12 source credential boundary: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      supabase/seed/puls-sanayi-v1/csv/*|supabase/seed/puls-sanayi-v1/manifest.json|services/*/src/*|package.json|.env*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR14.12 source credential boundary: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

echo "OK: PR14.12 source credential boundary verification passed"
