#!/usr/bin/env bash
# Verifies PR13.6 AI Coach DB context readiness pack.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
VERIFY_SCRIPT="scripts/verify-13-ai-coach-db-context-readiness.sh"
AI_COACH_DIR="src/lib/data/ai-coach"

file_at_ref() {
  local path="$1"
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

echo "Checking ${REF}: PR13.6 AI Coach DB context readiness ..."

REQUIRED_FILES=(
  "docs/product/13_ai_coach_db_context_readiness.md"
  "docs/product/README.md"
  "${AI_COACH_DIR}/types.ts"
  "${AI_COACH_DIR}/context-readiness.ts"
  "${AI_COACH_DIR}/overview.ts"
  "${AI_COACH_DIR}/overview.test.ts"
  "src/routes/_app/ai-koc.tsx"
  "src/i18n/locales/tr-TR.json"
  "src/i18n/locales/en-US.json"
  "supabase/seed/puls-sanayi-v1/sql/08_validate_ai_context_readiness.sql"
  "$VERIFY_SCRIPT"
)

for f in "${REQUIRED_FILES[@]}"; do
  if ! file_at_ref "$f" >/dev/null; then
    echo "FAIL: missing required file: $f"
    exit 1
  fi
done

DOC="$(file_at_ref docs/product/13_ai_coach_db_context_readiness.md)"
README="$(file_at_ref docs/product/README.md)"
OVERVIEW="$(file_at_ref ${AI_COACH_DIR}/overview.ts)"
CONTEXT="$(file_at_ref ${AI_COACH_DIR}/context-readiness.ts)"
ROUTE="$(file_at_ref src/routes/_app/ai-koc.tsx)"
AI_COACH_COMBINED="$(file_at_ref ${AI_COACH_DIR}/types.ts)"
AI_COACH_COMBINED+="$(file_at_ref ${AI_COACH_DIR}/context-readiness.ts)"
AI_COACH_COMBINED+="$(file_at_ref ${AI_COACH_DIR}/overview.ts)"

doc_needles=(
  "Production-facing product behavior must not depend on embedded TypeScript business fixtures for AI context."
  "AI Coach is a process-embedded value layer, not only the /ai-koc page."
  "VITE_PULS_DEMO_MODE=false"
  "source: real"
  "human-in-the-loop"
  "no autonomous mutations"
  "no auto-approvals"
  "no ERP writes"
  "puls_vault.conversation_messages is sensitive/system and must not be seeded for PR13.6"
  "llm-gateway is a future service-boundary hint, not a physical MVP microservice"
  "PR13.6 proves DB context readiness, not live LLM chat"
)

for needle in "${doc_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: doc missing needle: $needle"
    exit 1
  fi
done

if ! grep -Fq "PR13.6 AI Coach DB context readiness" <<< "$README"; then
  echo "FAIL: README missing PR13.6 section"
  exit 1
fi

# Adapter checks
if ! grep -Fq "resolveTenantContext" <<< "$OVERVIEW"; then
  echo "FAIL: overview.ts missing resolveTenantContext"
  exit 1
fi
if ! grep -Fq "fetchAiCoachOverviewWithMeta" <<< "$OVERVIEW"; then
  echo "FAIL: overview.ts missing fetchAiCoachOverviewWithMeta"
  exit 1
fi
if ! grep -Fq "buildDemoAiCoachOverview" <<< "$CONTEXT"; then
  echo "FAIL: context-readiness.ts missing buildDemoAiCoachOverview"
  exit 1
fi
if grep -Fq "STATIC_AI_COACH_OVERVIEW" <<< "$OVERVIEW"; then
  echo "FAIL: overview.ts must not use STATIC_AI_COACH_OVERVIEW"
  exit 1
fi
if ! grep -Fq "Promise.allSettled" <<< "$OVERVIEW"; then
  echo "FAIL: overview.ts must use Promise.allSettled for query robustness"
  exit 1
fi
if ! grep -Fq "countRows" <<< "$OVERVIEW"; then
  echo "FAIL: overview.ts missing countRows helper"
  exit 1
fi

schema_hits=0
for helper in pulsCore pulsWorkflow pulsPerformance pulsIntegration pulsCalc; do
  if grep -Fq "$helper" <<< "$OVERVIEW"; then
    schema_hits=$((schema_hits + 1))
  fi
done
if [[ "$schema_hits" -lt 3 ]]; then
  echo "FAIL: overview.ts must use at least 3 schema helpers (found $schema_hits)"
  exit 1
fi

if ! grep -Fq "fetchDemoAiCoachOverview" <<< "$AI_COACH_COMBINED"; then
  echo "FAIL: ai-coach must import fetchDemoAiCoachOverview for demo wrapper"
  exit 1
fi
for banned_demo_type in DemoAiCoachOverview DemoAiCoachCapability DemoAiCoachReadinessItem; do
  if grep -E "(import|type).*\b${banned_demo_type}\b" <<< "$AI_COACH_COMBINED"; then
    echo "FAIL: ai-coach must not import demo type $banned_demo_type from puls-demo-data"
    exit 1
  fi
done

# Route checks
if ! grep -Fq "aiCoachSetup.sections.contextReadiness" <<< "$ROUTE"; then
  echo "FAIL: route missing context readiness section"
  exit 1
fi
if ! grep -Fq "aiCoachSetup.sections.guardrails" <<< "$ROUTE"; then
  echo "FAIL: route missing guardrails section"
  exit 1
fi
if ! grep -Fq "productPostureLabelKey" <<< "$ROUTE"; then
  echo "FAIL: route must map productPosture via productPostureLabelKey helper"
  exit 1
fi

chat_bans=(
  "chat.completions"
  "responses.create"
  "OPENAI_API_KEY"
  "OpenAI"
  "Ask AI"
  "Bir şey sor"
  "live chat"
  "active chat"
)
ROUTE_ADAPTER="${ROUTE}${OVERVIEW}${CONTEXT}"
for ban in "${chat_bans[@]}"; do
  if grep -Fq "$ban" <<< "$ROUTE_ADAPTER"; then
    echo "FAIL: chat/LLM pattern forbidden: $ban"
    exit 1
  fi
done

if grep -Ei 'INSERT INTO puls_vault\.conversation_messages|UPDATE puls_vault\.conversation_messages|DELETE FROM puls_vault\.conversation_messages' <<< "$AI_COACH_COMBINED"; then
  echo "FAIL: must not write to puls_vault.conversation_messages"
  exit 1
fi

# Diff guard
BASE_REF="$(git merge-base "${REF}" origin/main 2>/dev/null || echo "")"
if [[ -n "$BASE_REF" && "$BASE_REF" != "$REF" ]]; then
  CHANGED=$(git diff --name-only "$BASE_REF" "$REF" 2>/dev/null || true)
  if [[ -n "$CHANGED" ]]; then
    while IFS= read -r path; do
      [[ -z "$path" ]] && continue
      case "$path" in
        docs/product/13_ai_coach_db_context_readiness.md) ;;
        docs/product/README.md) ;;
        docs/product/13_route_packaging_proof_matrix.md) ;;
        src/lib/data/ai-coach/*) ;;
        src/routes/_app/ai-koc.tsx) ;;
        src/i18n/locales/*.json) ;;
        scripts/verify-13-ai-coach-db-context-readiness.sh) ;;
        supabase/seed/puls-sanayi-v1/sql/08_validate_ai_context_readiness.sql) ;;
        *)
          case "$path" in
            supabase/migrations/*)
              echo "FAIL: forbidden path vs merge-base: $path"
              exit 1
              ;;
            supabase/seed/puls-sanayi-v1/csv/*)
              echo "FAIL: forbidden path vs merge-base: $path"
              exit 1
              ;;
            supabase/seed/puls-sanayi-v1/manifest.json)
              echo "FAIL: forbidden path vs merge-base: $path"
              exit 1
              ;;
            package.json|.env|.env.*)
              echo "FAIL: forbidden path vs merge-base: $path"
              exit 1
              ;;
            docs/api/openapi.yaml|openapi.json|swagger.json)
              echo "FAIL: forbidden path vs merge-base: $path"
              exit 1
              ;;
          esac
          ;;
      esac
    done <<< "$CHANGED"
  fi
fi

echo "OK: PR13.6 AI Coach DB context readiness verification passed"
