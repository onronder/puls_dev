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

echo "Checking ${REF}: PR16 controlled data movement safety plan ..."

ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
SAFETY_DOC="$(file_at_ref docs/product/16_controlled_data_movement_safety_model.md)"
README="$(file_at_ref docs/product/README.md)"
VERIFY_SELF="$(file_at_ref scripts/verify-16-controlled-data-movement-safety-plan.sh)"

for needle in \
  "PULS blind overwrite yapmaz." \
  "Apply Safety Contract Ve Permission Hardening" \
  "Change Set, Before Snapshot Ve Risk Ledger" \
  "Create-Only Worker Apply" \
  "Guarded Update Apply" \
  "Rollback / Compensating Preview And Execution" \
  "Notification Center Foundation" \
  "Canias Runtime Spike" \
  "AI Operational Recommendations" \
  "Missing field does not clear existing value" \
  "Stale before hash update'i durdurur." \
  "Rollback de preview + approval + worker execution ister."; do
  if ! grep -Fq "$needle" <<< "$ROADMAP"; then
    echo "FAIL: roadmap missing PR16 safety needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16 must not open a blind import apply path." \
  "No browser direct canonical write." \
  "No authenticated direct \`apply_import_batch\` execution from app code." \
  "No blind overwrite." \
  "No missing-field clear." \
  "create_only" \
  "guarded_overwrite" \
  "destructive_equivalent" \
  "source_conflict" \
  "stale_preview" \
  "Rollback / Compensating Preview And Execution" \
  "AI reads safe evidence"; do
  if ! grep -Fq "$needle" <<< "$SAFETY_DOC"; then
    echo "FAIL: safety model doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16 controlled data movement safety model" \
  "16_controlled_data_movement_safety_model.md" \
  "overwrite-safe change-set model"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: product README missing PR16 safety index needle: $needle" >&2
    exit 1
  fi
done

if grep -Eiq "providerApiCalls: true|credentialReadback: true|canonicalWrites: true|sourceWriteback: true|AI tarafından otomatik import/apply.*allowed|raw_payload\\s*=|credentials_ref\\s*=|response_body\\s*=" <<< "$ROADMAP$SAFETY_DOC$README"; then
  echo "FAIL: PR16 safety plan weakens closed runtime, credential, source writeback, or raw payload boundaries" >&2
  exit 1
fi

if ! grep -Fq "PR16 controlled data movement safety plan" <<< "$VERIFY_SELF"; then
  echo "FAIL: verify script self-check missing PR16 label" >&2
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
      docs/product/15_16_connector_runtime_ai_roadmap.md) ;;
      docs/product/16_controlled_data_movement_safety_model.md) ;;
      docs/product/README.md) ;;
      scripts/verify-16-controlled-data-movement-safety-plan.sh) ;;
      *)
        echo "FAIL: unexpected changed path for PR16 controlled data movement safety plan: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      supabase/migrations/*|supabase/seed/*|src/**|services/**|package.json|pnpm-lock.yaml|.env*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR16 controlled data movement safety plan: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

echo "OK: PR16 controlled data movement safety plan verification passed"
