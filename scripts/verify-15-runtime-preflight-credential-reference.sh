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

echo "Checking ${REF}: PR15.5 runtime preflight credential reference ..."

DOC="$(file_at_ref docs/product/15_connector_runtime_preflight_credential_reference.md)"
README="$(file_at_ref docs/product/README.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
MIGRATION="$(file_at_ref supabase/migrations/20260604140000_puls_integration_runtime_preflight_credential_reference.sql)"
WORKER="$(file_at_ref services/erp-connector/src/worker.ts)"
WORKER_TEST="$(file_at_ref services/erp-connector/src/worker.test.ts)"
ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/erp.tsx)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
DATA_INDEX="$(file_at_ref src/lib/data/index.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"
VERIFY_SELF="$(file_at_ref scripts/verify-15-runtime-preflight-credential-reference.sh)"

for needle in \
  "PR15.5, connector runtime'a geçişte ilk güvenli çalışma adımını açar" \
  "verified credential reference varsa admin" \
  "provider API çağrısı, credential readback, import apply, canonical write veya ERP/source writeback yapmaz" \
  "Canias entegrasyonunu tamamlamaz" \
  "HR AI, connector runtime'ın neden hazır veya bloklu olduğunu"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR15.5 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR15.5 implementation status" \
  "source-independent runtime preflight queue request" \
  "provider API calls, credential readback, import apply, canonical writes, ERP/source writeback, and AI autonomous actions remain closed"; do
  if ! grep -Fq "$needle" <<< "$ROADMAP"; then
    echo "FAIL: roadmap missing PR15.5 status needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR15.5 Runtime preflight with credential reference" \
  "15_connector_runtime_preflight_credential_reference.md" \
  "20260604140000_puls_integration_runtime_preflight_credential_reference.sql" \
  "scripts/verify-15-runtime-preflight-credential-reference.sh"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR15.5 reference: $needle" >&2
    exit 1
  fi
done

for needle in \
  "request_connector_runtime_preflight" \
  "get_connector_runtime_preflight_context" \
  "PULS_CONNECTOR_JOB_CREDENTIAL_NOT_VERIFIED" \
  "PULS_CONNECTOR_RUNTIME_PREFLIGHT_CREDENTIAL_NOT_VERIFIED" \
  "connector_runtime_preflight" \
  "IS DISTINCT FROM 'verified'" \
  "credentials_ref IS NOT NULL" \
  "provider_api_calls" \
  "canonical_write" \
  "source_writeback"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: PR15.5 migration missing runtime preflight needle: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "GRANT EXECUTE ON FUNCTION puls_integration.request_connector_runtime_preflight(UUID, UUID)" <<< "$MIGRATION" || \
   ! grep -A2 -F "GRANT EXECUTE ON FUNCTION puls_integration.request_connector_runtime_preflight(UUID, UUID)" <<< "$MIGRATION" | grep -Fq "TO authenticated, service_role"; then
  echo "FAIL: request_connector_runtime_preflight must be callable by authenticated admins and service_role" >&2
  exit 1
fi

if ! grep -Fq "GRANT EXECUTE ON FUNCTION puls_integration.get_connector_runtime_preflight_context(UUID)" <<< "$MIGRATION" || \
   ! grep -A2 -F "GRANT EXECUTE ON FUNCTION puls_integration.get_connector_runtime_preflight_context(UUID)" <<< "$MIGRATION" | grep -Fq "TO service_role"; then
  echo "FAIL: get_connector_runtime_preflight_context must be service_role only" >&2
  exit 1
fi

if grep -A2 -F "GRANT EXECUTE ON FUNCTION puls_integration.get_connector_runtime_preflight_context(UUID)" <<< "$MIGRATION" | grep -Fq "authenticated"; then
  echo "FAIL: get_connector_runtime_preflight_context must not be granted to authenticated" >&2
  exit 1
fi

for needle in \
  "ConnectorRuntimePreflightContext" \
  "buildRuntimePreflightCompletionFromContext" \
  "get_connector_runtime_preflight_context" \
  "runtime_preflight_credential_not_verified" \
  "provider_api_calls: false" \
  "credential_readback: false" \
  "canonical_write: false" \
  "source_writeback: false"; do
  if ! grep -Fq "$needle" <<< "$WORKER"; then
    echo "FAIL: worker missing PR15.5 safe runtime needle: $needle" >&2
    exit 1
  fi
done

for forbidden in \
  "credentials_ref" \
  "raw_payload" \
  "provider_payload" \
  "request_body" \
  "response_body" \
  "CANIAS_API_KEY"; do
  if grep -Fq "$forbidden" <<< "$WORKER"; then
    echo "FAIL: worker contains forbidden runtime detail: $forbidden" >&2
    exit 1
  fi
done

for needle in \
  "requestConnectorRuntimePreflight" \
  "request_connector_runtime_preflight" \
  "PULS_CONNECTOR_RUNTIME_PREFLIGHT_CREDENTIAL_NOT_VERIFIED" \
  "erp.errors.runtimePreflightBlocked"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing runtime preflight needle: $needle" >&2
    exit 1
  fi
done

if grep -Fq "credentials_ref" <<< "$ERP_ADAPTER"; then
  echo "FAIL: ERP adapter must not select or emit credentials_ref" >&2
  exit 1
fi

for needle in \
  "requestConnectorRuntimePreflight" \
  "runtimePreflightWorkerReady" \
  "erp.runtimePreflight.title" \
  "requestRuntimePreflightMutation"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route missing runtime preflight UI needle: $needle" >&2
    exit 1
  fi
done

if grep -Eiq "type=[\"']password[\"']|name=[\"'](apiKey|api_key|token|secret|password|connectionString|ftpPassword)[\"']|placeholder=.*(API key|token|password|secret|connection string)" <<< "$ERP_ROUTE"; then
  echo "FAIL: ERP route introduced credential collection UI" >&2
  exit 1
fi

for needle in \
  "requestConnectorRuntimePreflight" \
  "RequestConnectorRuntimePreflightResult"; do
  if ! grep -Fq "$needle" <<< "$DATA_INDEX"; then
    echo "FAIL: data index missing runtime preflight export: $needle" >&2
    exit 1
  fi
done

for needle in \
  "buildRuntimePreflightCompletionFromContext" \
  "connector_runtime_preflight" \
  "runtime_preflight_credential_not_verified" \
  "not.toContain('credentials_ref')" \
  "not.toContain('raw_payload')"; do
  if ! grep -Fq "$needle" <<< "$WORKER_TEST"; then
    echo "FAIL: worker tests missing runtime preflight assertion: $needle" >&2
    exit 1
  fi
done

for needle in \
  "request_connector_runtime_preflight" \
  "PULS_CONNECTOR_RUNTIME_PREFLIGHT_CREDENTIAL_NOT_VERIFIED" \
  "not.toContain('credentials_ref')"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP tests missing runtime preflight assertion: $needle" >&2
    exit 1
  fi
done

for needle in \
  '"runtimePreflight"' \
  '"runtimePreflightBlocked"' \
  '"runtime_preflight_context_missing"' \
  '"runtime_preflight_credential_not_verified"' \
  '"wait_for_worker_runtime_preflight"' \
  '"provider_runtime_implementation_required"'; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing runtime preflight key: $needle" >&2
    exit 1
  fi
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing runtime preflight key: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR15.5 runtime preflight credential reference" <<< "$VERIFY_SELF"; then
  echo "FAIL: verify script self-check missing PR15.5 label" >&2
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
      docs/product/15_connector_runtime_preflight_credential_reference.md) ;;
      docs/product/15_16_connector_runtime_ai_roadmap.md) ;;
      docs/product/README.md) ;;
      scripts/verify-15-runtime-preflight-credential-reference.sh) ;;
      supabase/migrations/20260604140000_puls_integration_runtime_preflight_credential_reference.sql) ;;
      services/erp-connector/src/worker.ts) ;;
      services/erp-connector/src/worker.test.ts) ;;
      src/lib/data/setup/erp.ts) ;;
      src/lib/data/setup/erp.test.ts) ;;
      src/lib/data/index.ts) ;;
      src/routes/_app/erp.tsx) ;;
      src/i18n/locales/tr-TR.json) ;;
      src/i18n/locales/en-US.json) ;;
      *)
        echo "FAIL: unexpected changed file in PR15.5 scope: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

while IFS= read -r changed; do
  [[ -z "$changed" ]] && continue
  if [[ "$REF" == "WORKTREE" && "$changed" == supabase/.temp/* ]]; then
    continue
  fi
  if [[ "$REF" == "WORKTREE" && "$changed" == supabase/.branches/* ]]; then
    continue
  fi
  case "$changed" in
    docs/product/*) continue ;;
    scripts/verify-15-runtime-preflight-credential-reference.sh) continue ;;
    *.test.ts) continue ;;
    supabase/migrations/20260604140000_puls_integration_runtime_preflight_credential_reference.sql) continue ;;
  esac
  content="$(changed_file_at_ref "$changed")"
  if grep -Eiq "OPENAI_API_KEY|CANIAS_API_KEY|chat\\.completions|responses\\.create|provider_payload|raw_payload|request_body|response_body" <<< "$content"; then
    echo "FAIL: runtime/secret forbidden pattern in changed file: $changed" >&2
    exit 1
  fi
done <<< "$CHANGED_FILES"

echo "OK: PR15.5 runtime preflight credential reference verification passed"
