#!/usr/bin/env bash
# Verifies PR13.7 Canias + AI Coach connector boundary pack.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
VERIFY_SCRIPT="scripts/verify-13-canias-ai-connector-boundary.sh"

file_at_ref() {
  local path="$1"
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

echo "Checking ${REF}: PR13.7 Canias + AI connector boundary ..."

REQUIRED_FILES=(
  "docs/product/13_canias_connector_discovery.md"
  "docs/product/13_ai_coach_action_boundary.md"
  "docs/product/13_canias_ai_connector_readiness_matrix.md"
  "docs/product/13_canias_field_mapping_matrix.json"
  "docs/product/README.md"
  "docs/product/13_canias_first_integration_boundary.md"
  "docs/product/13_v1_product_packaging_strategy.md"
  "docs/product/13_v1_feature_traceability_matrix.md"
  "docs/product/13_route_packaging_proof_matrix.md"
  "supabase/seed/puls-sanayi-v1/sql/09_validate_canias_connector_readiness.sql"
  "services/erp-connector/README.md"
  "services/llm-gateway/README.md"
  "$VERIFY_SCRIPT"
)

for f in "${REQUIRED_FILES[@]}"; do
  if ! file_at_ref "$f" >/dev/null; then
    echo "FAIL: missing required file: $f"
    exit 1
  fi
done

DISCOVERY="$(file_at_ref docs/product/13_canias_connector_discovery.md)"
ACTION="$(file_at_ref docs/product/13_ai_coach_action_boundary.md)"
README="$(file_at_ref docs/product/README.md)"
SQL09="$(file_at_ref supabase/seed/puls-sanayi-v1/sql/09_validate_canias_connector_readiness.sql)"
ERP_README="$(file_at_ref services/erp-connector/README.md)"
LLM_README="$(file_at_ref services/llm-gateway/README.md)"
CHANGED_DOCS="${DISCOVERY}${ACTION}${README}${ERP_README}${LLM_README}"
CHANGED_DOCS+="$(file_at_ref docs/product/13_canias_ai_connector_readiness_matrix.md)"
CHANGED_DOCS+="$(file_at_ref docs/product/13_canias_first_integration_boundary.md)"
CHANGED_DOCS+="$(file_at_ref docs/product/13_v1_product_packaging_strategy.md)"
CHANGED_DOCS+="$(file_at_ref docs/product/13_v1_feature_traceability_matrix.md)"
CHANGED_DOCS+="$(file_at_ref docs/product/13_route_packaging_proof_matrix.md)"

doc_needles=(
  "Canias is the first native ERP integration track for PULS v1.0."
  "PR13.7 is connector discovery and action-boundary readiness, not runtime integration."
  "PULS remains the workflow system of record"
  "No automatic destructive ERP writes."
  "AI Coach may suggest, explain, and draft; humans confirm every workflow action."
  "AI Coach must not call workflow mutation RPCs autonomously."
  "Source disclosure is required"
  "no autonomous mutations"
  "no auto-approvals"
  "no ERP writes"
  "no credentials"
  "credentials_ref"
  "llm-gateway is a future service-boundary hint"
  "erp-connector is a future connector boundary"
)

for needle in "${doc_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "${DISCOVERY}${ACTION}"; then
    echo "FAIL: discovery/action docs missing needle: $needle"
    exit 1
  fi
done

if ! grep -Fq "PR13.7 Canias + AI connector boundary readiness" <<< "$README"; then
  echo "FAIL: README missing PR13.7 section"
  exit 1
fi

# AI boundary action classes
for allowed in explain summarize detect_gap draft_next_step prepare_review source_disclosure; do
  if ! grep -Fq "$allowed" <<< "$ACTION"; then
    echo "FAIL: action boundary missing allowed action: $allowed"
    exit 1
  fi
done

for forbidden in decide_approval_request sync_canias_now write_to_canias; do
  if ! grep -Fq "$forbidden" <<< "$ACTION"; then
    echo "FAIL: action boundary missing forbidden action: $forbidden"
    exit 1
  fi
done

# Positive enablement bans only — allow negated guardrails like "no live chat"
enablement_bans=(
  "live chat enabled"
  "Ask AI"
  "Bir şey sor"
  "chat.completions"
  "responses.create"
  "OPENAI_API_KEY"
  "CANIAS_API_KEY"
)
for ban in "${enablement_bans[@]}"; do
  if grep -Fq "$ban" <<< "$CHANGED_DOCS"; then
    echo "FAIL: positive enablement pattern forbidden: $ban"
    exit 1
  fi
done

# JSON validation via node
JSON_PATH="docs/product/13_canias_field_mapping_matrix.json"
JSON_CONTENT="$(file_at_ref "$JSON_PATH")"
export JSON_CONTENT
node -e '
const fs = require("fs");
const data = JSON.parse(process.env.JSON_CONTENT);
if (data.provider !== "canias") { console.error("FAIL: provider must be canias"); process.exit(1); }
if (data.posture !== "discovery_only_no_runtime") { console.error("FAIL: posture mismatch"); process.exit(1); }
const requiredIds = [
  "departments","positions","employees","cost_centers","legal_entities","locations",
  "leave_balances","approved_leave_results","posted_expense_results","approval_audit_summary",
  "performance_data","contracts","source_identity_mappings"
];
const ids = new Set((data.dataClasses || []).map((d) => d.id));
for (const id of requiredIds) {
  if (!ids.has(id)) { console.error("FAIL: missing data class id:", id); process.exit(1); }
}
const requiredKeys = ["direction","sourceOfTruth","pulsTarget","mvpStatus","mutabilityInPuls","identityStrategy","fieldMappings"];
for (const dc of data.dataClasses) {
  for (const key of requiredKeys) {
    if (!(key in dc)) { console.error("FAIL:", dc.id, "missing key", key); process.exit(1); }
  }
  if (!Array.isArray(dc.fieldMappings) || dc.fieldMappings.length < 1) {
    console.error("FAIL:", dc.id, "fieldMappings must be non-empty");
    process.exit(1);
  }
}
const lb = data.dataClasses.find((d) => d.id === "leave_balances");
if (!lb || lb.sourceOfTruth !== "tbd_workshop") {
  console.error("FAIL: leave_balances sourceOfTruth must be tbd_workshop");
  process.exit(1);
}
'

# SQL 09 checks — case-insensitive forbidden token scan on raw file
if ! grep -Fq "read-only validation" <<< "$SQL09"; then
  echo "FAIL: SQL 09 must describe read-only validation posture"
  exit 1
fi

for table in erp_connections erp_field_mappings source_namespaces entity_identity_map credentials_ref; do
  if ! grep -Fq "$table" <<< "$SQL09"; then
    echo "FAIL: SQL 09 must reference $table"
    exit 1
  fi
done

if grep -Fq "auth.users" <<< "$SQL09"; then
  echo "FAIL: SQL 09 must not reference auth.users"
  exit 1
fi
if grep -Fq "puls_vault.conversation_messages" <<< "$SQL09"; then
  echo "FAIL: SQL 09 must not reference puls_vault.conversation_messages"
  exit 1
fi

sql_lower="$(tr '[:upper:]' '[:lower:]' <<< "$SQL09")"
for token in insert update delete truncate alter drop "create table"; do
  if grep -Fq "$token" <<< "$sql_lower"; then
    echo "FAIL: SQL 09 must not contain forbidden token: $token"
    exit 1
  fi
done
if grep -Fq "create " <<< "$sql_lower"; then
  echo "FAIL: SQL 09 must not contain forbidden token: create"
  exit 1
fi

# Service README posture
if ! grep -Fq "Health-only skeleton" <<< "$ERP_README"; then
  echo "FAIL: erp-connector README missing skeleton posture"
  exit 1
fi
if ! grep -Fq "future connector boundary" <<< "$ERP_README"; then
  echo "FAIL: erp-connector README missing future boundary note"
  exit 1
fi
if ! grep -Fq "future service-boundary hint" <<< "$LLM_README"; then
  echo "FAIL: llm-gateway README missing future boundary note"
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
        docs/product/13_canias_connector_discovery.md) ;;
        docs/product/13_ai_coach_action_boundary.md) ;;
        docs/product/13_canias_ai_connector_readiness_matrix.md) ;;
        docs/product/13_canias_field_mapping_matrix.json) ;;
        docs/product/README.md) ;;
        docs/product/13_canias_first_integration_boundary.md) ;;
        docs/product/13_v1_product_packaging_strategy.md) ;;
        docs/product/13_v1_feature_traceability_matrix.md) ;;
        docs/product/13_route_packaging_proof_matrix.md) ;;
        scripts/verify-13-canias-ai-connector-boundary.sh) ;;
        supabase/seed/puls-sanayi-v1/sql/09_validate_canias_connector_readiness.sql) ;;
        services/erp-connector/README.md) ;;
        services/llm-gateway/README.md) ;;
        *)
          echo "FAIL: forbidden path vs merge-base: $path"
          exit 1
          ;;
      esac
    done <<< "$CHANGED"
  fi
fi

echo "OK: PR13.7 Canias + AI connector boundary verification passed"
