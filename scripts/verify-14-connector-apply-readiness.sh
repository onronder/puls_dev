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

echo "Checking ${REF}: PR14.17 connector apply readiness ..."

DOC="$(file_at_ref docs/product/14_connector_apply_readiness_boundary.md)"
README="$(file_at_ref docs/product/README.md)"
ROADMAP="$(file_at_ref docs/product/14_connector_implementation_roadmap.md)"
ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/verikaynaklari.tsx)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
DATA_INDEX="$(file_at_ref src/lib/data/index.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"
VERIFY_SELF="$(file_at_ref scripts/verify-14-connector-apply-readiness.sh)"

for needle in \
  "PR14.17 defines apply readiness and human review boundary, not canonical import apply." \
  "safeToApply remains false in PR14.17." \
  "No apply_import_batch call is opened from the app." \
  "Human review records are audit signals, not ERP or canonical write approvals." \
  "Canias is one source profile; apply readiness is connector-agnostic." \
  "Payload readback remains forbidden."; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR14.17 doc missing apply readiness needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorApplyReadiness" \
  "RequestConnectorApplyReviewResult" \
  "applyReadiness" \
  "buildConnectorApplyReadiness" \
  "requestConnectorApplyReview" \
  "safeToApply: false" \
  "sync_type: 'import_apply_review'" \
  "event_key: 'import_apply_review_requested'" \
  "next_action_key: 'hold_for_apply_design'"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing apply readiness needle: $needle" >&2
    exit 1
  fi
done

if grep -Eiq "apply_import_batch|credentials_ref|select\\('\\*'\\)" <<< "$ERP_ADAPTER"; then
  echo "FAIL: ERP adapter introduced apply execution, credential readback, or broad select" >&2
  exit 1
fi

for needle in \
  "requestConnectorApplyReview" \
  "erp.sections.applyReadiness" \
  "erp.applyReadiness.safeToApplyFalse" \
  "data.applyReadiness.checks" \
  "data.applyReadiness.blockers" \
  "ClipboardCheck"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route missing apply readiness UI needle: $needle" >&2
    exit 1
  fi
done

if grep -Eiq "raw_payload|sanitized_payload|normalized_payload|credentials_ref|apply_import_batch|type=[\"']password[\"']|name=[\"'](apiKey|api_key|token|secret|password|connectionString|ftpPassword)[\"']|sync_canias_now|write_to_canias|delete_or_overwrite|live connector runtime enabled" <<< "$ERP_ROUTE"; then
  echo "FAIL: ERP route introduced payload readback, credential input, apply, or runtime/writeback enablement" >&2
  exit 1
fi

for needle in \
  '"applyReadiness"' \
  '"request_human_review"' \
  '"review_requested"' \
  '"safeToApplyFalse"' \
  '"import_apply_review_requested"' \
  '"importApplyReview"' \
  '"hold_for_apply_design"'; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing apply readiness key: $needle" >&2
    exit 1
  fi
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing apply readiness key: $needle" >&2
    exit 1
  fi
done

for needle in \
  "requestConnectorApplyReview" \
  "applyReadiness" \
  "review_ready" \
  "review_requested" \
  "import_apply_review_requested" \
  "not.toContain('raw_payload')" \
  "not.toContain('credentials_ref')" \
  "apply_import_batch"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP tests missing apply readiness case: $needle" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorApplyReadiness" \
  "ConnectorApplyReadinessCheck" \
  "ConnectorApplyReadinessBlocker" \
  "RequestConnectorApplyReviewResult" \
  "requestConnectorApplyReview"; do
  if ! grep -Fq "$needle" <<< "$DATA_INDEX"; then
    echo "FAIL: data index missing apply readiness export: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.17 Connector apply readiness boundary" \
  "14_connector_apply_readiness_boundary.md" \
  "scripts/verify-14-connector-apply-readiness.sh"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR14.17 reference: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.17 - Connector Apply Readiness Boundary" \
  "PR14.17 defines apply readiness and human review boundary, not canonical import apply." \
  "Human review records are audit signals, not ERP or canonical write approvals."; do
  if ! grep -Fq "$needle" <<< "$ROADMAP"; then
    echo "FAIL: roadmap missing PR14.17 reference: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR14.17 connector apply readiness" <<< "$VERIFY_SELF"; then
  echo "FAIL: verify script self-check missing PR14.17 label" >&2
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
      docs/product/14_connector_apply_readiness_boundary.md) ;;
      docs/product/14_connector_implementation_roadmap.md) ;;
      docs/product/README.md) ;;
      scripts/verify-14-connector-apply-readiness.sh) ;;
      src/i18n/locales/en-US.json) ;;
      src/i18n/locales/tr-TR.json) ;;
      src/lib/data/index.ts) ;;
      src/lib/data/setup/erp.test.ts) ;;
      src/lib/data/setup/erp.ts) ;;
      src/routes/_app/verikaynaklari.tsx) ;;
      *)
        echo "FAIL: unexpected changed path for PR14.17 apply readiness: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

FORBIDDEN_CHANGED="$(
  printf '%s\n' "$CHANGED_FILES" | grep -E '^(supabase/migrations/|supabase/seed/puls-sanayi-v1/csv/|supabase/seed/puls-sanayi-v1/manifest\\.json|package\\.json|\\.env|docs/api/openapi\\.yaml|openapi\\.json|swagger\\.json)' || true
)"
if [[ -n "$FORBIDDEN_CHANGED" ]]; then
  echo "FAIL: forbidden PR14.17 path changed:" >&2
  printf '%s\n' "$FORBIDDEN_CHANGED" >&2
  exit 1
fi

echo "OK: PR14.17 connector apply readiness verification passed"
