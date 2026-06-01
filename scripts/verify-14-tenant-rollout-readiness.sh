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

echo "Checking ${REF}: PR14.4 tenant rollout readiness ..."

DOC="$(file_at_ref docs/product/14_tenant_rollout_readiness.md)"
README="$(file_at_ref docs/product/README.md)"
STRATEGY="$(file_at_ref docs/product/13_v1_product_packaging_strategy.md)"
ROUTE_MATRIX="$(file_at_ref docs/product/13_route_packaging_proof_matrix.md)"
VERIFY_SELF="$(file_at_ref scripts/verify-14-tenant-rollout-readiness.sh)"

for needle in \
  "Puls Teknik A.S. proves seeded connector metadata posture." \
  "PULS Connector Lab proves no-connector onboarding posture." \
  "connector-admin@puls.demo must remain public-tenant linked only." \
  "No runtime sync, no credentials, and no ERP writes are introduced in this rollout readiness gate." \
  "VITE_PULS_DEMO_MODE=false" \
  "source: real" \
  "/dashboard" \
  "/erp" \
  "Kaynak yok" \
  "Taslağı incele"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR14.4 doc missing rollout readiness needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.4 Tenant rollout readiness" \
  "two tenant postures" \
  "PULS Connector Lab"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR14.4 rollout readiness section: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.4" \
  "Tenant rollout readiness"; do
  if ! grep -Fq "$needle" <<< "$STRATEGY"; then
    echo "FAIL: packaging strategy missing PR14.4 reference: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PULS Connector Lab" \
  "provider draft review" \
  "no-connector onboarding"; do
  if ! grep -Fq "$needle" <<< "$ROUTE_MATRIX"; then
    echo "FAIL: route matrix missing PR14.4 rollout posture: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR14.4 tenant rollout readiness" <<< "$VERIFY_SELF"; then
  echo "FAIL: verify script self-check missing PR14.4 label" >&2
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
      docs/product/14_tenant_rollout_readiness.md) ;;
      docs/product/README.md) ;;
      docs/product/13_v1_product_packaging_strategy.md) ;;
      docs/product/13_route_packaging_proof_matrix.md) ;;
      scripts/verify-14-tenant-rollout-readiness.sh) ;;
      *)
        echo "FAIL: unexpected changed path for PR14.4 tenant rollout readiness: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      src/*|src/**|supabase/migrations/*|supabase/seed/puls-sanayi-v1/csv/*|supabase/seed/puls-sanayi-v1/manifest.json|services/*/src/*|package.json|.env*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR14.4 tenant rollout readiness: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"

  CHANGED_CONTENT="$(
    while IFS= read -r changed; do
      [[ -z "$changed" ]] && continue
      [[ "$changed" == "scripts/verify-14-tenant-rollout-readiness.sh" ]] && continue
      [[ "$REF" == "WORKTREE" && "$changed" == supabase/.temp/* ]] && continue
      file_at_ref "$changed"
      printf '\n'
    done <<< "$CHANGED_FILES"
  )"
  if grep -Eiq "OPENAI_API_KEY|CANIAS_API_KEY|chat\.completions|responses\.create|sync_canias_now|write_to_canias|delete_or_overwrite|service_role|supabase_service_role" <<< "$CHANGED_CONTENT"; then
    echo "FAIL: changed files contain secret/runtime/ERP-write enablement tokens" >&2
    exit 1
  fi
fi

echo "OK: PR14.4 tenant rollout readiness verification passed"
