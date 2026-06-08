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

echo "Checking ${REF}: PR14.7 role tenant empty-state gate ..."

DOC="$(file_at_ref docs/product/14_role_tenant_empty_state_matrix.md)"
README="$(file_at_ref docs/product/README.md)"
STRATEGY="$(file_at_ref docs/product/13_v1_product_packaging_strategy.md)"
DASHBOARD_ROUTE="$(file_at_ref src/routes/_app/dashboard.tsx)"
ERP_ROUTE="$(file_at_ref src/routes/_app/verikaynaklari.tsx)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"
ROLE_E2E="$(file_at_ref e2e/role-tenant-matrix.spec.ts)"
UI_E2E="$(file_at_ref e2e/ui-stabilization.spec.ts)"
PACKAGE_JSON="$(file_at_ref package.json)"
CI_WORKFLOW="$(file_at_ref .github/workflows/ci.yml)"
VERIFY_SELF="$(file_at_ref scripts/verify-14-role-tenant-empty-state-gate.sh)"

for needle in \
  "Role and tenant posture must be proven before connector setup persistence." \
  "PULS Connector Lab is the first-run empty-state tenant for product onboarding." \
  "Puls Teknik A.S. remains the seeded operational tenant for source-real regression proof." \
  "Empty tenant behavior is a product state, not a missing-data bug." \
  "Connector setup persistence stays future until the first-run empty-state contract is stable."; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR14.7 doc missing product claim: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PULS Connector Lab" \
  "Puls Teknik A.S." \
  "E2E_CONNECTOR_ADMIN_*" \
  "E2E_MANAGER_*" \
  "E2E_EMPLOYEE_*" \
  "Connection setup" \
  "no runtime sync, no credential storage, and no ERP writes"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR14.7 doc missing matrix/guardrail needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "dashboard.emptyTenant.badge" \
  "dashboard.emptyTenant.primaryAction" \
  "dashboard.emptyTenant.secondaryAction" \
  "dashboard.emptyTenant.steps" \
  "isEmptyRealDashboard"; do
  if ! grep -Fq "$needle" <<< "$DASHBOARD_ROUTE"; then
    echo "FAIL: dashboard route missing empty-state contract needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "erp.noConnector.title" \
  "erp.noConnector.stepsTitle" \
  "erp.noConnector.sourceStepTitle" \
  "hasNoConnector"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route missing no-connector wizard needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  '"badge": "Kurulum bekliyor"' \
  '"title": "PULS çalışma alanın hazır, veriler bekleniyor"' \
  '"noConnector"' \
  '"sourceStepTitle": "1. Veri kaynağını seç"'; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing PR14.7 copy: $needle" >&2
    exit 1
  fi
done

for needle in \
  '"badge": "Setup pending"' \
  '"title": "Your PULS workspace is ready; data is next"' \
  '"noConnector"' \
  '"sourceStepTitle": "1. Choose data source"'; do
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing PR14.7 copy: $needle" >&2
    exit 1
  fi
done

for needle in \
  "@auth role and tenant posture matrix" \
  "E2E_CONNECTOR_ADMIN_EMAIL" \
  "E2E_HR_EMAIL" \
  "E2E_MANAGER_EMAIL" \
  "PULS Connector Lab" \
  "Puls Teknik" \
  "first-run empty dashboard" \
  "employee remains self-scoped"; do
  if ! grep -Fq "$needle" <<< "$ROLE_E2E"; then
    echo "FAIL: role tenant e2e missing needle: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "@auth authenticated stabilization" <<< "$UI_E2E"; then
  echo "FAIL: ui stabilization auth tests must be tagged with @auth" >&2
  exit 1
fi

for needle in \
  "e2e/role-tenant-matrix.spec.ts" \
  "@auth"; do
  if ! grep -Fq -- "$needle" <<< "$PACKAGE_JSON"; then
    echo "FAIL: package.json missing auth role matrix command needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "secrets.E2E_ADMIN_EMAIL" \
  "secrets.E2E_HR_EMAIL" \
  "secrets.E2E_MANAGER_EMAIL" \
  "secrets.E2E_EMPLOYEE_EMAIL" \
  "secrets.E2E_CONNECTOR_ADMIN_EMAIL"; do
  if ! grep -Fq "$needle" <<< "$CI_WORKFLOW"; then
    echo "FAIL: CI workflow missing role secret needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.7 Role + tenant empty-state gate" \
  "e2e/role-tenant-matrix.spec.ts" \
  "scripts/verify-14-role-tenant-empty-state-gate.sh"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR14.7 reference: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR14.7" <<< "$STRATEGY"; then
  echo "FAIL: packaging strategy missing PR14.7" >&2
  exit 1
fi

if ! grep -Fq "PR14.7 role tenant empty-state gate" <<< "$VERIFY_SELF"; then
  echo "FAIL: verify script self-check missing PR14.7 label" >&2
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
      .github/workflows/ci.yml) ;;
      e2e/ui-stabilization.spec.ts) ;;
      e2e/role-tenant-matrix.spec.ts) ;;
      package.json) ;;
      src/routes/_app/dashboard.tsx) ;;
      src/routes/_app/verikaynaklari.tsx) ;;
      src/i18n/locales/tr-TR.json) ;;
      src/i18n/locales/en-US.json) ;;
      docs/product/14_role_tenant_empty_state_matrix.md) ;;
      docs/product/14_authenticated_e2e_gate.md) ;;
      docs/product/README.md) ;;
      docs/product/13_v1_product_packaging_strategy.md) ;;
      scripts/verify-14-authenticated-e2e-gate.sh) ;;
      scripts/verify-14-role-tenant-empty-state-gate.sh) ;;
      *)
        echo "FAIL: unexpected changed path for PR14.7 role tenant empty-state gate: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      supabase/migrations/*|supabase/seed/puls-sanayi-v1/csv/*|supabase/seed/puls-sanayi-v1/manifest.json|services/*/src/*|.env*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR14.7 role tenant empty-state gate: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"

  CHANGED_CONTENT="$(
    while IFS= read -r changed; do
      [[ -z "$changed" ]] && continue
      [[ "$changed" == scripts/verify-14-role-tenant-empty-state-gate.sh ]] && continue
      [[ "$changed" == scripts/verify-14-authenticated-e2e-gate.sh ]] && continue
      [[ "$REF" == "WORKTREE" && "$changed" == supabase/.temp/* ]] && continue
      file_at_ref "$changed"
      printf '\n'
    done <<< "$CHANGED_FILES"
  )"
  if grep -Eiq "OPENAI_API_KEY|CANIAS_API_KEY|chat\.completions|responses\.create|sync_canias_now|write_to_canias|delete_or_overwrite|service_role|supabase_service_role|DATABASE_URL" <<< "$CHANGED_CONTENT"; then
    echo "FAIL: changed files contain secret/runtime/ERP-write enablement tokens" >&2
    exit 1
  fi
fi

echo "OK: PR14.7 role tenant empty-state gate verification passed"
