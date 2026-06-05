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

echo "Checking ${REF}: PR16.1 apply safety contract ..."

DOC="$(file_at_ref docs/product/16_1_apply_safety_contract_permission_hardening.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
MIGRATION="$(file_at_ref supabase/migrations/20260605100000_puls_integration_apply_safety_contract.sql)"
ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/erp.tsx)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
DATA_INDEX="$(file_at_ref src/lib/data/index.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"
VERIFY_SELF="$(file_at_ref scripts/verify-16-1-apply-safety-contract.sh)"

for needle in \
  "PR16.1 is the first implementation step" \
  "apply_import_batch(UUID, TEXT)" \
  "service-role only" \
  "\`connector_jobs\` rejects \`import_apply\`" \
  "90 days" \
  "PR16.2 can now build immutable change-sets"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.1 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "connector_apply_policy_state" \
  "connector_apply_operation" \
  "connector_apply_audit_tier" \
  "reject_closed_import_apply_job" \
  "PULS_CONNECTOR_IMPORT_APPLY_CLOSED" \
  "puls_integration_connector_jobs_import_apply_closed" \
  "list_connector_apply_safety_contracts" \
  "authenticated_apply_rpc_exposed" \
  "worker_import_apply_enqueue_enabled" \
  "field_diff_hot_retention_days" \
  "rollback_snapshot_hot_retention_days" \
  "REVOKE ALL ON FUNCTION puls_integration.apply_import_batch(UUID, TEXT)" \
  "GRANT EXECUTE ON FUNCTION puls_integration.apply_import_batch(UUID, TEXT)" \
  "TO service_role"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: PR16.1 migration missing needle: $needle" >&2
    exit 1
  fi
done

if grep -A2 -F "GRANT EXECUTE ON FUNCTION puls_integration.apply_import_batch(UUID, TEXT)" <<< "$MIGRATION" | grep -Fq "authenticated"; then
  echo "FAIL: apply_import_batch must not be granted to authenticated in PR16.1" >&2
  exit 1
fi

if ! grep -A2 -F "GRANT EXECUTE ON FUNCTION puls_integration.list_connector_apply_safety_contracts(UUID)" <<< "$MIGRATION" | grep -Fq "TO authenticated, service_role"; then
  echo "FAIL: apply safety contract read model must be available to authenticated readers and service_role" >&2
  exit 1
fi

for needle in \
  "ConnectorApplySafetyContract" \
  "ConnectorApplySafetyPolicyState" \
  "ConnectorApplyOperation" \
  "ConnectorApplyAuditTier" \
  "list_connector_apply_safety_contracts" \
  "pr16.1-apply-safety-contract-v1" \
  "authenticatedApplyRpcExposed: false" \
  "workerImportApplyEnqueueEnabled: false" \
  "workerImportApplyClaimEnabled: false" \
  "fieldDiffHotRetentionDays" \
  "rollbackSnapshotHotRetentionDays" \
  "applySafetyContract"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing PR16.1 safety contract needle: $needle" >&2
    exit 1
  fi
done

if grep -Fq "apply_import_batch" <<< "$ERP_ADAPTER$ERP_ROUTE"; then
  echo "FAIL: app code must not reference apply_import_batch" >&2
  exit 1
fi

for needle in \
  "direct_rpc_permission" \
  "worker_apply_gate" \
  "crud_audit_policy" \
  "retention_policy"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing execution control: $needle" >&2
    exit 1
  fi
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing execution control: $needle" >&2
    exit 1
  fi
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing execution control: $needle" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorApplySafetyContract" \
  "ConnectorApplySafetyPolicyState" \
  "ConnectorApplyOperation" \
  "ConnectorApplyAuditTier"; do
  if ! grep -Fq "$needle" <<< "$DATA_INDEX"; then
    echo "FAIL: data index missing PR16.1 export: $needle" >&2
    exit 1
  fi
done

for needle in \
  "applySafetyContract" \
  "list_connector_apply_safety_contracts" \
  "pr16.1-apply-safety-contract-v1" \
  "serviceRoleOnly" \
  "importApplyClosed" \
  "ninetyDayHotRetention" \
  "not.toContain('apply_import_batch')"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP tests missing PR16.1 assertion: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.1 closes the direct apply surface" \
  "rejects \`import_apply\` connector jobs" \
  "Canonical writes, Canias API import, ERP/source writeback, rollback execution, and AI autonomous apply remain closed"; do
  if ! grep -Fq "$needle" <<< "$ROADMAP"; then
    echo "FAIL: roadmap missing PR16.1 status needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.1 apply safety contract and permission hardening" \
  "16_1_apply_safety_contract_permission_hardening.md" \
  "20260605100000_puls_integration_apply_safety_contract.sql" \
  "scripts/verify-16-1-apply-safety-contract.sh"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR16.1 reference: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR16.1 apply safety contract" <<< "$VERIFY_SELF"; then
  echo "FAIL: verify script self-check missing PR16.1 label" >&2
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
      docs/product/16_1_apply_safety_contract_permission_hardening.md) ;;
      docs/product/README.md) ;;
      scripts/verify-16-controlled-data-movement-safety-plan.sh) ;;
      scripts/verify-16-1-apply-safety-contract.sh) ;;
      supabase/migrations/20260605100000_puls_integration_apply_safety_contract.sql) ;;
      src/i18n/locales/en-US.json) ;;
      src/i18n/locales/tr-TR.json) ;;
      src/lib/data/index.ts) ;;
      src/lib/data/setup/erp.test.ts) ;;
      src/lib/data/setup/erp.ts) ;;
      *)
        echo "FAIL: unexpected changed path for PR16.1 apply safety contract: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      services/**|supabase/seed/**|src/routes/_app/erp.tsx|package.json|pnpm-lock.yaml|.env*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR16.1 apply safety contract: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

echo "OK: PR16.1 apply safety contract verification passed"
