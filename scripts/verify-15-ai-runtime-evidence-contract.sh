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

echo "Checking ${REF}: PR15.6 AI runtime evidence contract ..."

DOC="$(file_at_ref docs/product/15_ai_runtime_evidence_contract.md)"
README="$(file_at_ref docs/product/README.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
AI_TYPES="$(file_at_ref src/lib/data/ai-coach/types.ts)"
AI_CONTEXT="$(file_at_ref src/lib/data/ai-coach/context-readiness.ts)"
AI_OVERVIEW="$(file_at_ref src/lib/data/ai-coach/overview.ts)"
AI_TEST="$(file_at_ref src/lib/data/ai-coach/overview.test.ts)"
AI_ROUTE="$(file_at_ref src/routes/_app/ai-koc.tsx)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"
VERIFY_SELF="$(file_at_ref scripts/verify-15-ai-runtime-evidence-contract.sh)"

for needle in \
  "PR15.6, connector runtime sinyallerini AI Coach için güvenli ve kaynak açıklamalı bir kanıt sözleşmesine bağlar." \
  "AI Coach runtime bağlamı yalnızca aşağıdaki safe read-model sinyallerinden beslenir" \
  "Her öneri, kullandığı kaynağı açıkça belirtmek zorundadır." \
  "AI Coach aşağıdaki aksiyonları başlatamaz" \
  "Live LLM chat, autonomous workflow mutation, AI tarafından job başlatma, import apply ve ERP/source writeback kapsam dışıdır."; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR15.6 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR15.6 implements the AI-safe runtime evidence contract" \
  "adds the \`connector_runtime\` context domain to AI Coach" \
  "No migration, job start, credential read, import apply, canonical write, ERP/source writeback, or autonomous AI action is added."; do
  if ! grep -Fq "$needle" <<< "$ROADMAP"; then
    echo "FAIL: roadmap missing PR15.6 status needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR15.6 AI runtime evidence contract" \
  "15_ai_runtime_evidence_contract.md" \
  "verify-15-ai-runtime-evidence-contract.sh"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR15.6 reference: $needle" >&2
    exit 1
  fi
done

for needle in \
  "AiCoachRuntimeEvidenceContract" \
  "AiCoachRuntimeEvidenceActionId" \
  "AiCoachRuntimeEvidenceForbiddenActionId" \
  "connector_runtime" \
  "source_disclosure" \
  "start_connector_job" \
  "read_credential" \
  "apply_import" \
  "write_to_source" \
  "mutate_workflow"; do
  if ! grep -Fq "$needle" <<< "$AI_TYPES"; then
    echo "FAIL: AI types missing runtime evidence needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "buildRuntimeEvidenceContract" \
  "sourceDisclosureRequired: true" \
  "connector_runtime" \
  "connectorRuntimeJobCount" \
  "connectorJobEventCount" \
  "connectorCredentialVerifiedCount" \
  "connectorImportPreviewBatchCount" \
  "connectorSafeActivityCount" \
  "aiCoachSetup.guardrails.sourceDisclosure.label" \
  "aiCoachSetup.guardrails.noCredentialRead.label"; do
  if ! grep -Fq "$needle" <<< "$AI_CONTEXT"; then
    echo "FAIL: AI context missing runtime evidence needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "connector_jobs" \
  "connector_job_events" \
  "credential_state" \
  "import_batches" \
  "erp_sync_batches" \
  "connectorRuntimeFailedJobCount" \
  "connectorRuntimeDeadLetterJobCount" \
  "connectorCredentialMissingCount"; do
  if ! grep -Fq "$needle" <<< "$AI_OVERVIEW"; then
    echo "FAIL: AI overview missing safe runtime query needle: $needle" >&2
    exit 1
  fi
done

for forbidden in \
  "select('*')" \
  "provider_payload" \
  "request_body" \
  "response_body" \
  "OPENAI_API_KEY" \
  "CANIAS_API_KEY" \
  "chat.completions" \
  "responses.create" \
  "claim_next_connector_job" \
  "complete_connector_job" \
  "request_connector_runtime_preflight" \
  "apply_import_batch" \
  "write_to_canias" \
  "sync_canias_now"; do
  if grep -Fq "$forbidden" <<< "$AI_TYPES"$'\n'"$AI_CONTEXT"$'\n'"$AI_OVERVIEW"$'\n'"$AI_ROUTE"; then
    echo "FAIL: AI runtime evidence files contain forbidden runtime/secret pattern: $forbidden" >&2
    exit 1
  fi
done

for needle in \
  "aiCoachSetup.sections.runtimeEvidence" \
  "data?.runtimeEvidence.sourceDisclosureRequired" \
  "data?.runtimeEvidence.signals" \
  "allowedSuggestionActions" \
  "forbiddenActions" \
  "aiCoachSetup.runtimeEvidence.sourcePrefix"; do
  if ! grep -Fq "$needle" <<< "$AI_ROUTE"; then
    echo "FAIL: AI route missing runtime evidence UI needle: $needle" >&2
    exit 1
  fi
done

if grep -Eiq "type=[\"']password[\"']|name=[\"'](apiKey|api_key|token|secret|password|connectionString|ftpPassword)[\"']" <<< "$AI_ROUTE"; then
  echo "FAIL: AI route introduced credential collection UI" >&2
  exit 1
fi

for needle in \
  '"runtimeEvidence"' \
  '"connector_runtime"' \
  '"sourceDisclosure"' \
  '"noCredentialRead"' \
  '"connectorJobs"' \
  '"connectorJobEvents"' \
  '"credentialState"' \
  '"importPreview"' \
  '"runtimeBlockers"' \
  '"source_disclosure"' \
  '"start_connector_job"' \
  '"read_credential"' \
  '"apply_import"' \
  '"write_to_source"' \
  '"mutate_workflow"'; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing PR15.6 key: $needle" >&2
    exit 1
  fi
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing PR15.6 key: $needle" >&2
    exit 1
  fi
done

for needle in \
  "buildRuntimeEvidenceContract" \
  "sourceDisclosureRequired" \
  "connector_runtime" \
  "start_connector_job" \
  "read_credential" \
  "runtime_blockers"; do
  if ! grep -Fq "$needle" <<< "$AI_TEST"; then
    echo "FAIL: AI tests missing runtime evidence assertion: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR15.6 AI runtime evidence contract" <<< "$VERIFY_SELF"; then
  echo "FAIL: verify script self-check missing PR15.6 label" >&2
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
      docs/product/15_ai_runtime_evidence_contract.md) ;;
      docs/product/15_16_connector_runtime_ai_roadmap.md) ;;
      docs/product/README.md) ;;
      scripts/verify-15-ai-runtime-evidence-contract.sh) ;;
      src/i18n/locales/en-US.json) ;;
      src/i18n/locales/tr-TR.json) ;;
      src/lib/data/ai-coach/context-readiness.ts) ;;
      src/lib/data/ai-coach/overview.test.ts) ;;
      src/lib/data/ai-coach/overview.ts) ;;
      src/lib/data/ai-coach/types.ts) ;;
      src/routes/_app/ai-koc.tsx) ;;
      *)
        echo "FAIL: unexpected changed path for PR15.6 AI runtime evidence contract: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      supabase/migrations/*|supabase/seed/*|services/*|src/lib/data/setup/*|src/routes/_app/erp.tsx|package.json|.env*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR15.6 AI runtime evidence contract: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

echo "OK: PR15.6 AI runtime evidence contract verification passed"
