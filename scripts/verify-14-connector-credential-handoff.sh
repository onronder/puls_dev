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

echo "Checking ${REF}: PR14.14 connector credential handoff ..."

DOC="$(file_at_ref docs/product/14_connector_credential_handoff.md)"
README="$(file_at_ref docs/product/README.md)"
ROADMAP="$(file_at_ref docs/product/14_connector_implementation_roadmap.md)"
MIGRATION="$(file_at_ref supabase/migrations/20260603120000_puls_integration_connector_credential_handoff.sql)"
ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/verikaynaklari.tsx)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"
VERIFY_SELF="$(file_at_ref scripts/verify-14-connector-credential-handoff.sh)"

for needle in \
  "PR14.14 models credential handoff, not credential capture." \
  "Secure credential capture is write-only and server-side in future runtime." \
  "credentials_ref remains an opaque server-side reference." \
  "No API keys, passwords, tokens, connection strings, or FTP credentials are collected in the product UI." \
  "Canias is one source profile; credential handoff is source-independent."; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR14.14 doc missing credential handoff needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "connector_credential_handoff_status" \
  "credential_handoff_status" \
  "credential_handoff_requested_at" \
  "credential_handoff_requested_by_employee_id" \
  "credential_handoff_updated_at" \
  "apply_connector_credential_handoff_defaults" \
  "secret values stay outside product tables"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: PR14.14 migration missing handoff needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorCredentialHandoff" \
  "ConnectorCredentialHandoffStatus" \
  "buildConnectorCredentialHandoff" \
  "requestConnectorCredentialHandoff" \
  "credentialHandoff" \
  "credential_handoff_status" \
  "credential_handoff_requested_at" \
  "credential_handoff_requested_by_employee_id" \
  "credential_handoff"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing credential handoff needle: $needle" >&2
    exit 1
  fi
done

if grep -Fq "credentials_ref" <<< "$ERP_ADAPTER"; then
  echo "FAIL: ERP adapter must not select or expose credentials_ref" >&2
  exit 1
fi

if grep -Fq "select('*')" <<< "$ERP_ADAPTER"; then
  echo "FAIL: ERP adapter must not use select('*') on connector data" >&2
  exit 1
fi

if grep -Eiq "credential_state: 'configured'|credential_state: 'verified'|credential_state = 'configured'|credential_state = 'verified'" <<< "$ERP_ADAPTER"; then
  echo "FAIL: handoff action must not configure or verify credential_state" >&2
  exit 1
fi

for needle in \
  "requestConnectorCredentialHandoff" \
  "credentialSheetOpen" \
  "erp.credentialHandoff.openSheet" \
  "erp.credentialHandoff.sheet" \
  "ShieldCheck"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route missing credential handoff UI needle: $needle" >&2
    exit 1
  fi
done

if grep -Eiq 'type=["'\'']password["'\'']|name=["'\''](apiKey|api_key|token|secret|password|connectionString|ftpPassword)["'\'']|placeholder=.*(API key|token|password|secret|connection string)' <<< "$ERP_ROUTE"; then
  echo "FAIL: ERP route introduced credential/secret input UI" >&2
  exit 1
fi

if grep -Eiq "chat\.completions|responses\.create|OPENAI_API_KEY|CANIAS_API_KEY|sync_canias_now|write_to_canias|delete_or_overwrite|live connector runtime enabled" <<< "$ERP_ADAPTER"$'\n'"$ERP_ROUTE"; then
  echo "FAIL: runtime, AI, or destructive connector enablement token found" >&2
  exit 1
fi

for needle in \
  '"credentialHandoff"' \
  '"reference_pending"' \
  '"request_secure_reference"' \
  "server-side" \
  "write-only"; do
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing credential handoff key: $needle" >&2
    exit 1
  fi
done

for needle in \
  '"credentialHandoff"' \
  '"reference_pending"' \
  '"request_secure_reference"' \
  "sunucu tarafı" \
  "write-only"; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing credential handoff key: $needle" >&2
    exit 1
  fi
done

for needle in \
  "credential handoff request" \
  "not.toContain('credential_state')" \
  "not.toContain('configured')" \
  "action: 'request_secure_reference'" \
  "blockedBy: 'namespace'"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP tests missing credential handoff case: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.14 Connector credential handoff" \
  "14_connector_credential_handoff.md" \
  "20260603120000_puls_integration_connector_credential_handoff.sql" \
  "scripts/verify-14-connector-credential-handoff.sh"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR14.14 reference: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.14 - Connector Credential Handoff" \
  "PR14.14 models credential handoff, not credential capture." \
  "The admin handoff action never sets \`credential_state\` to \`configured\` or \`verified\`."; do
  if ! grep -Fq "$needle" <<< "$ROADMAP"; then
    echo "FAIL: roadmap missing PR14.14 reference: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR14.14 connector credential handoff" <<< "$VERIFY_SELF"; then
  echo "FAIL: verify script self-check missing PR14.14 label" >&2
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
      docs/product/14_connector_credential_handoff.md) ;;
      docs/product/14_connector_implementation_roadmap.md) ;;
      docs/product/README.md) ;;
      scripts/verify-14-connector-credential-handoff.sh) ;;
      supabase/migrations/20260603120000_puls_integration_connector_credential_handoff.sql) ;;
      src/i18n/locales/en-US.json) ;;
      src/i18n/locales/tr-TR.json) ;;
      src/lib/data/index.ts) ;;
      src/lib/data/setup/erp.test.ts) ;;
      src/lib/data/setup/erp.ts) ;;
      src/routes/_app/verikaynaklari.tsx) ;;
      *)
        echo "FAIL: unexpected changed path for PR14.14 credential handoff: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      supabase/seed/puls-sanayi-v1/csv/*|supabase/seed/puls-sanayi-v1/manifest.json|services/*/src/*|package.json|.env*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR14.14 credential handoff: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

echo "OK: PR14.14 connector credential handoff verification passed"
