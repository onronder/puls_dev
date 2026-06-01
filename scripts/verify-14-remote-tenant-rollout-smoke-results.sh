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

echo "Checking ${REF}: PR14.5 remote tenant rollout smoke results ..."

DOC="$(file_at_ref docs/product/14_remote_tenant_rollout_smoke_results.md)"
README="$(file_at_ref docs/product/README.md)"
STRATEGY="$(file_at_ref docs/product/13_v1_product_packaging_strategy.md)"
VERIFY_SELF="$(file_at_ref scripts/verify-14-remote-tenant-rollout-smoke-results.sh)"

for needle in \
  "Remote Vercel smoke passed for PULS Connector Lab no-connector posture." \
  "Remote Vercel smoke passed for Puls Teknik seeded connector posture." \
  "connector-admin@puls.demo remained public-tenant linked only during smoke." \
  "No runtime sync, no credentials, and no ERP writes were exercised." \
  "VITE_PULS_DEMO_MODE=false" \
  "source: real" \
  "Kaynak yok" \
  "Kaynak tanımlı değil" \
  "Taslağı incele" \
  "Bağlantı kaydı oluşturma kapalı" \
  "disabled: true" \
  "Canias ERP (Pasif)" \
  "12 / 12" \
  "100%"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR14.5 results doc missing required smoke needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.5 Remote tenant rollout smoke results" \
  "live remote UI smoke" \
  "PULS Connector Lab"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR14.5 smoke results section: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.5" \
  "Remote tenant rollout smoke results"; do
  if ! grep -Fq "$needle" <<< "$STRATEGY"; then
    echo "FAIL: packaging strategy missing PR14.5 reference: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR14.5 remote tenant rollout smoke results" <<< "$VERIFY_SELF"; then
  echo "FAIL: verify script self-check missing PR14.5 label" >&2
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
      docs/product/14_remote_tenant_rollout_smoke_results.md) ;;
      docs/product/README.md) ;;
      docs/product/13_v1_product_packaging_strategy.md) ;;
      scripts/verify-14-remote-tenant-rollout-smoke-results.sh) ;;
      *)
        echo "FAIL: unexpected changed path for PR14.5 remote smoke results: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      src/*|src/**|supabase/migrations/*|supabase/seed/puls-sanayi-v1/csv/*|supabase/seed/puls-sanayi-v1/manifest.json|services/*/src/*|package.json|.env*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR14.5 remote smoke results: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"

  CHANGED_CONTENT="$(
    while IFS= read -r changed; do
      [[ -z "$changed" ]] && continue
      [[ "$changed" == "scripts/verify-14-remote-tenant-rollout-smoke-results.sh" ]] && continue
      [[ "$REF" == "WORKTREE" && "$changed" == supabase/.temp/* ]] && continue
      file_at_ref "$changed"
      printf '\n'
    done <<< "$CHANGED_FILES"
  )"
  if grep -Eiq "OPENAI_API_KEY|CANIAS_API_KEY|chat\.completions|responses\.create|sync_canias_now|write_to_canias|delete_or_overwrite|service_role|supabase_service_role|DATABASE_URL|password|token" <<< "$CHANGED_CONTENT"; then
    echo "FAIL: changed files contain secret/runtime/ERP-write enablement tokens" >&2
    exit 1
  fi
fi

echo "OK: PR14.5 remote tenant rollout smoke results verification passed"
