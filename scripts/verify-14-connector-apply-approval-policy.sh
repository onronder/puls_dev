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

echo "Checking ${REF}: PR14.19 connector apply approval policy ..."

DOC="$(file_at_ref docs/product/14_connector_apply_approval_policy.md)"
README="$(file_at_ref docs/product/README.md)"
ROADMAP="$(file_at_ref docs/product/14_connector_implementation_roadmap.md)"
ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/erp.tsx)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
DATA_INDEX="$(file_at_ref src/lib/data/index.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"
VERIFY_SELF="$(file_at_ref scripts/verify-14-connector-apply-approval-policy.sh)"

for needle in \
  "PR14.19 defines the MVP approval policy for future connector apply without opening canonical import apply." \
  "PULS remains a source-independent connectivity product." \
  "Canias is one connector profile, not the connectivity architecture." \
  "Admin approval is an audit signal, not canonical import apply." \
  "No apply_import_batch call is opened from the app." \
  "\`applyApprovalPolicy.safeToApply\` is always \`false\`." \
  "\`controlledApplyPlan.executionOpen\` is always \`false\`." \
  "\`controlledApplyPlan.applyRpcExposed\` is always \`false\`."; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR14.19 doc missing approval policy needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorApplyApprovalPolicy" \
  "ConnectorApplyApprovalPolicyStatus" \
  "recordConnectorApplyApproval" \
  "buildConnectorApplyApprovalPolicy" \
  "import_apply_approval_recorded" \
  "hold_for_apply_execution_design" \
  "approval_policy: 'admin_only'" \
  "safeToApply: false" \
  "apply_execution_open: false" \
  "canonical_write_open: false"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing approval policy needle: $needle" >&2
    exit 1
  fi
done

if grep -Eiq "apply_import_batch|credentials_ref|raw_payload|sanitized_payload|normalized_payload|select\\('\\*'\\)" <<< "$ERP_ADAPTER"; then
  echo "FAIL: ERP adapter introduced apply execution, credential readback, payload readback, or broad select" >&2
  exit 1
fi

for needle in \
  "recordConnectorApplyApproval" \
  "data.applyApprovalPolicy" \
  "erp.applyApprovalPolicy" \
  "recordApplyApprovalMutation" \
  "canRecordApplyApproval" \
  "erp-controlled-apply"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route missing approval policy UI needle: $needle" >&2
    exit 1
  fi
done

if grep -Eiq "raw_payload|sanitized_payload|normalized_payload|credentials_ref|apply_import_batch|type=[\"']password[\"']|name=[\"'](apiKey|api_key|token|secret|password|connectionString|ftpPassword)[\"']|sync_canias_now|write_to_canias|delete_or_overwrite|live connector runtime enabled" <<< "$ERP_ROUTE"; then
  echo "FAIL: ERP route introduced payload readback, credential input, apply, or runtime/writeback enablement" >&2
  exit 1
fi

for needle in \
  '"applyApprovalPolicy"' \
  '"approval_recorded"' \
  '"admin_only"' \
  '"record_admin_approval"' \
  '"import_apply_approval_recorded"' \
  '"hold_for_apply_execution_design"' \
  '"policyAdminOnly"' \
  '"policyApproved"'; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing approval policy key: $needle" >&2
    exit 1
  fi
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing approval policy key: $needle" >&2
    exit 1
  fi
done

for needle in \
  "applyApprovalPolicy" \
  "recordConnectorApplyApproval" \
  "import_apply_approval_recorded" \
  "approval_policy: 'admin_only'" \
  "canonical_write_open: false" \
  "not.toContain('apply_import_batch')" \
  "not.toContain('credentials_ref')" \
  "PULS_CONNECTOR_APPLY_APPROVAL_BLOCKED"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP tests missing approval policy case: $needle" >&2
    exit 1
  fi
done

for needle in \
  "recordConnectorApplyApproval" \
  "ConnectorApplyApprovalPolicy" \
  "ConnectorApplyApprovalPolicyAction" \
  "ConnectorApplyApprovalPolicyStatus" \
  "RecordConnectorApplyApprovalResult"; do
  if ! grep -Fq "$needle" <<< "$DATA_INDEX"; then
    echo "FAIL: data index missing approval policy export: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.19 Connector apply approval policy" \
  "14_connector_apply_approval_policy.md" \
  "scripts/verify-14-connector-apply-approval-policy.sh"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR14.19 reference: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.19 - Connector Apply Approval Policy" \
  "PR14.19 defines admin approval policy, not canonical import apply." \
  "No product UI action calls \`apply_import_batch\`."; do
  if ! grep -Fq "$needle" <<< "$ROADMAP"; then
    echo "FAIL: roadmap missing PR14.19 reference: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR14.19 connector apply approval policy" <<< "$VERIFY_SELF"; then
  echo "FAIL: verify script self-check missing PR14.19 label" >&2
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
      docs/product/14_connector_apply_approval_policy.md) ;;
      docs/product/14_connector_implementation_roadmap.md) ;;
      docs/product/README.md) ;;
      scripts/verify-14-connector-apply-approval-policy.sh) ;;
      src/i18n/locales/en-US.json) ;;
      src/i18n/locales/tr-TR.json) ;;
      src/lib/data/index.ts) ;;
      src/lib/data/setup/erp.test.ts) ;;
      src/lib/data/setup/erp.ts) ;;
      src/routes/_app/erp.tsx) ;;
      *)
        echo "FAIL: unexpected changed path for PR14.19 connector apply approval policy: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

FORBIDDEN_CHANGED="$(
  printf '%s\n' "$CHANGED_FILES" | grep -E '^(supabase/migrations/|supabase/seed/puls-sanayi-v1/csv/|supabase/seed/puls-sanayi-v1/manifest\\.json|package\\.json|\\.env|docs/api/openapi\\.yaml|openapi\\.json|swagger\\.json)' || true
)"
if [[ -n "$FORBIDDEN_CHANGED" ]]; then
  echo "FAIL: forbidden PR14.19 path changed:" >&2
  printf '%s\n' "$FORBIDDEN_CHANGED" >&2
  exit 1
fi

echo "OK: PR14.19 connector apply approval policy verification passed"
