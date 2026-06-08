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

changed_file_at_ref() {
  local path="$1"
  if [[ "$REF" == "WORKTREE" ]]; then
    cat "$path"
    return
  fi
  git show "${REF}:${path}" 2>/dev/null || true
}

echo "Checking ${REF}: PR15.4 secure credential runtime boundary ..."

DOC="$(file_at_ref docs/product/15_connector_secure_credential_runtime_boundary.md)"
README="$(file_at_ref docs/product/README.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
MIGRATION="$(file_at_ref supabase/migrations/20260604130000_puls_integration_secure_credential_runtime_boundary.sql)"
ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/verikaynaklari.tsx)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
DATA_INDEX="$(file_at_ref src/lib/data/index.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"
VERIFY_SELF="$(file_at_ref scripts/verify-15-secure-credential-runtime-boundary.sh)"

for needle in \
  "PR15.4, connector runtime'a geçmeden önce PULS'un credential sınırını production-grade hale getirir." \
  "PULS uygulama ekranı secret toplamaz, göstermez veya geri okumaz." \
  "Product DB yalnızca server-side secret manager tarafından üretilen opaque reference" \
  "AI sadece" \
  "AI job claim edemez, complete edemez, credential okuyamaz, import apply başlatamaz veya ERP'ye yazamaz."; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR15.4 doc missing secure credential needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR15.4 implements the source-independent secure credential runtime boundary" \
  "Provider API runtime, secret manager implementation, import apply, canonical writes, and ERP/source writeback remain closed."; do
  if ! grep -Fq "$needle" <<< "$ROADMAP"; then
    echo "FAIL: roadmap missing PR15.4 status needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR15.4 Secure credential runtime boundary" \
  "15_connector_secure_credential_runtime_boundary.md" \
  "20260604130000_puls_integration_secure_credential_runtime_boundary.sql" \
  "scripts/verify-15-secure-credential-runtime-boundary.sh"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR15.4 reference: $needle" >&2
    exit 1
  fi
done

for needle in \
  "connector_credential_event_key" \
  "connector_credential_reference_is_safe" \
  "erp_connections_credentials_ref_safe_format" \
  "connector_credential_events" \
  "set_connector_credential_reference" \
  "revoke_connector_credential_reference" \
  "mark_connector_credential_verification" \
  "list_connector_credential_events" \
  "PULS_CONNECTOR_CREDENTIAL_WORKER_ONLY" \
  "PULS_CONNECTOR_CREDENTIAL_REFERENCE_INVALID" \
  "PULS_CONNECTOR_JOB_CREDENTIAL_BLOCKED" \
  "connector_runtime_preflight"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: PR15.4 migration missing credential boundary needle: $needle" >&2
    exit 1
  fi
done

for fn in \
  "set_connector_credential_reference" \
  "revoke_connector_credential_reference" \
  "mark_connector_credential_verification" \
  "record_connector_credential_event" \
  "assert_connector_credential_actor"; do
  if ! grep -Fq "GRANT EXECUTE ON FUNCTION puls_integration.${fn}" <<< "$MIGRATION"; then
    echo "FAIL: ${fn} grant missing" >&2
    exit 1
  fi
  GRANT_BLOCK="$(awk "/GRANT EXECUTE ON FUNCTION puls_integration\\.${fn}/,/;/" <<< "$MIGRATION")"
  if grep -Fq "authenticated" <<< "$GRANT_BLOCK"; then
    echo "FAIL: ${fn} must not be granted to authenticated" >&2
    exit 1
  fi
done

if ! grep -Fq "GRANT EXECUTE ON FUNCTION puls_integration.list_connector_credential_events(UUID, INTEGER)" <<< "$MIGRATION" || \
   ! grep -A2 -F "GRANT EXECUTE ON FUNCTION puls_integration.list_connector_credential_events(UUID, INTEGER)" <<< "$MIGRATION" | grep -Fq "TO authenticated, service_role"; then
  echo "FAIL: list_connector_credential_events must be readable by authenticated tenant operators" >&2
  exit 1
fi

for needle in \
  "ConnectorCredentialEventRow" \
  "buildCredentialEventActivityEvent" \
  "list_connector_credential_events" \
  "credential_reference" \
  "erp.activityTimeline.summaries.credentialReference" \
  "erp.activityTimeline.nextActions.run_credential_verification"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing credential event read-model needle: $needle" >&2
    exit 1
  fi
done

if grep -Fq "credentials_ref" <<< "$ERP_ADAPTER"; then
  echo "FAIL: ERP adapter must not select or emit credentials_ref" >&2
  exit 1
fi

if grep -Eiq "type=[\"']password[\"']|name=[\"'](apiKey|api_key|token|secret|password|connectionString|ftpPassword)[\"']|placeholder=.*(API key|token|password|secret|connection string)" <<< "$ERP_ROUTE"; then
  echo "FAIL: ERP route introduced credential collection UI" >&2
  exit 1
fi

for needle in \
  "formatActivityDetailValue" \
  "erp.authModes." \
  "erp.credentialBoundary.states." \
  "item.labelKey"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route missing credential activity formatting needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorAuthMode" \
  "ConnectorCredentialBoundary" \
  "ConnectorCredentialState"; do
  if ! grep -Fq "$needle" <<< "$DATA_INDEX"; then
    echo "FAIL: data index missing credential boundary export: $needle" >&2
    exit 1
  fi
done

for needle in \
  "rpc:list_connector_credential_events" \
  "credential_reference" \
  "erp.activityTimeline.events.credential_reference_configured.title" \
  "not.toContain('credentials_ref')" \
  "not.toContain('pulsref://')"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP tests missing credential event assertion: $needle" >&2
    exit 1
  fi
done

for needle in \
  '"credential_reference_configured"' \
  '"credential_reference_updated"' \
  '"credential_reference_revoked"' \
  '"credential_verification_succeeded"' \
  '"credential_verification_failed"' \
  '"credentialReference"' \
  '"run_credential_verification"' \
  '"restore_secure_reference"' \
  '"run_runtime_preflight"' \
  '"review_secure_reference"'; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing credential boundary key: $needle" >&2
    exit 1
  fi
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing credential boundary key: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR15.4 secure credential runtime boundary" <<< "$VERIFY_SELF"; then
  echo "FAIL: verify script self-check missing PR15.4 label" >&2
  exit 1
fi

if [[ "$REF" == "WORKTREE" ]]; then
  BASE="$(git merge-base origin/main HEAD)"
  CHANGED_FILES="$(
    git diff --name-only "$BASE"
    git ls-files --others --exclude-standard
  )"
else
  BASE="$(git merge-base origin/main "$REF")"
  CHANGED_FILES="$(git diff --name-only "$BASE...$REF")"
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
      docs/product/15_connector_secure_credential_runtime_boundary.md) ;;
      docs/product/15_16_connector_runtime_ai_roadmap.md) ;;
      docs/product/README.md) ;;
      scripts/verify-15-secure-credential-runtime-boundary.sh) ;;
      supabase/migrations/20260604130000_puls_integration_secure_credential_runtime_boundary.sql) ;;
      src/i18n/locales/en-US.json) ;;
      src/i18n/locales/tr-TR.json) ;;
      src/lib/data/index.ts) ;;
      src/lib/data/setup/erp.test.ts) ;;
      src/lib/data/setup/erp.ts) ;;
      src/routes/_app/verikaynaklari.tsx) ;;
      *)
        echo "FAIL: unexpected changed path for PR15.4 secure credential runtime boundary: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      services/*|supabase/seed/puls-sanayi-v1/csv/*|supabase/seed/puls-sanayi-v1/manifest.json|package.json|.env*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR15.4 secure credential runtime boundary: $changed" >&2
        exit 1
        ;;
    esac

    if [[ "$changed" == src/* && "$changed" != *.test.ts ]]; then
      CONTENT="$(changed_file_at_ref "$changed")"
      if grep -Eiq "OPENAI_API_KEY|CANIAS_API_KEY|chat\\.completions|responses\\.create|request_body|response_body|raw_payload|sanitized_payload|normalized_payload|apply_import_batch|sync_canias_now|write_to_canias|delete_or_overwrite" <<< "$CONTENT"; then
        echo "FAIL: runtime, payload, or secret pattern found in changed source file: $changed" >&2
        exit 1
      fi
    fi
  done <<< "$CHANGED_FILES"
fi

echo "OK: PR15.4 secure credential runtime boundary verification passed"
