#!/usr/bin/env bash
# Verifies 11 PR11.6 contracts data readiness (POSIX grep/awk).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
MATRIX="docs/data/11_contracts_data_readiness_matrix.md"
SMOKE="docs/data/11_contracts_data_readiness_smoke.sql"
OVERVIEW="src/lib/data/contracts/overview.ts"
OVERVIEW_TEST="src/lib/data/contracts/overview.test.ts"
ROUTE="src/routes/_app/sozlesmeler.tsx"
DATA_INDEX="src/lib/data/index.ts"

smoke() {
  git show "${REF}:${SMOKE}" 2>/dev/null || cat "${SMOKE}"
}

file_at_ref() {
  local path="$1"
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

MATRIX_CONTENT="$(file_at_ref "$MATRIX")"
SMOKE_CONTENT="$(smoke)"
OVERVIEW_CONTENT="$(file_at_ref "$OVERVIEW")"
OVERVIEW_TEST_CONTENT="$(file_at_ref "$OVERVIEW_TEST")"
ROUTE_CONTENT="$(file_at_ref "$ROUTE")"
DATA_INDEX_CONTENT="$(file_at_ref "$DATA_INDEX")"

echo "Checking ${REF}: PR11.6 contracts data readiness ..."

for file in "$MATRIX" "$SMOKE" "$OVERVIEW" "$OVERVIEW_TEST" "$ROUTE" "$DATA_INDEX"; do
  if [[ ! -f "$file" ]]; then
    echo "FAIL: missing required file: $file"
    exit 1
  fi
done

MIGRATION_CHANGES="$(git diff --name-only --diff-filter=A origin/main...HEAD -- supabase/migrations/ 2>/dev/null || true)"
if [[ -n "$(echo "$MIGRATION_CHANGES" | sed '/^$/d')" ]]; then
  echo "FAIL: PR11.6 must not add migrations:"
  echo "$MIGRATION_CHANGES" | sed '/^$/d'
  exit 1
fi

matrix_needles=(
  "metadata-only"
  "read-only"
  "No migration"
  "dashboard_overview"
  "contracts_overview"
)

for needle in "${matrix_needles[@]}"; do
  if ! grep -Fiq "$needle" <<< "$MATRIX_CONTENT"; then
    echo "FAIL: matrix missing topic: $needle"
    exit 1
  fi
done

smoke_needles=(
  "BEGIN;"
  "ROLLBACK;"
  "demo_contracts_data_readiness_"
  "puls_workflow.contracts"
  "contract_files"
  "metadata_only"
  "puls_calc.dashboard_overview"
  "puls_calc.contracts_overview"
  "external_source"
  "external_contract_id"
  "request.jwt.claim.sub"
  "puls_core.current_employee_id()"
  "SMOKE_FAIL self contract metadata not selectable"
  "v_self_contract_count"
)

for needle in "${smoke_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$SMOKE_CONTENT"; then
    echo "FAIL: smoke missing fragment: $needle"
    exit 1
  fi
done

adapter_needles=(
  "fetchContractsOverviewWithMeta"
  "resolveAdapterDataWithMeta"
  "mapContractSignatureStatus"
  "mapContractRiskStatus"
  "mapContractRow"
)

for needle in "${adapter_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$OVERVIEW_CONTENT"; then
    echo "FAIL: contracts overview adapter missing fragment: $needle"
    exit 1
  fi
done

if ! grep -Fq "fetchContractsOverviewWithMeta" <<< "$DATA_INDEX_CONTENT"; then
  echo "FAIL: data index must export fetchContractsOverviewWithMeta"
  exit 1
fi

for needle in mapContractSignatureStatus mapContractRiskStatus mapContractRow fetchContractsOverviewWithMeta; do
  if ! grep -Fq "$needle" <<< "$OVERVIEW_TEST_CONTENT"; then
    echo "FAIL: contracts overview tests must cover $needle"
    exit 1
  fi
done

for needle in fetchContractsOverviewWithMeta contractsOverviewResult orgSetupReadiness.source.demo common.soon; do
  if ! grep -Fq "$needle" <<< "$ROUTE_CONTENT"; then
    echo "FAIL: sozlesmeler route missing fragment: $needle"
    exit 1
  fi
done

if ! grep -Fq "uploadUnavailable" <<< "$ROUTE_CONTENT" || ! grep -Fq "disabled" <<< "$ROUTE_CONTENT"; then
  echo "FAIL: sozlesmeler route must keep upload disabled"
  exit 1
fi

CHANGED_FILES=()
while IFS= read -r file; do
  [[ -n "$file" ]] && CHANGED_FILES+=("$file")
done < <(git diff --name-only origin/main...HEAD -- 'src/**' 2>/dev/null || true)

scan_forbidden() {
  local pattern="$1"
  local label="$2"
  for file in "${CHANGED_FILES[@]}"; do
    if [[ -f "$file" ]] && grep -Eiq "$pattern" "$file"; then
      echo "FAIL: forbidden pattern ($label) in $file"
      grep -Ein "$pattern" "$file" || true
      exit 1
    fi
  done
}

if ((${#CHANGED_FILES[@]} > 0)); then
  if ! printf '%s\n' "${CHANGED_FILES[@]}" | grep -Fxq "$ROUTE"; then
    echo "FAIL: PR11.6 must change route $ROUTE"
    exit 1
  fi

  scan_forbidden '\.from\('"'"'contracts'"'"'\).*\.(insert|update|delete|upsert)\(' 'contracts-table-mutation'
  scan_forbidden '\.from\('"'"'contract_files'"'"'\).*\.(insert|update|delete|upsert)\(' 'contract-files-mutation'
  scan_forbidden 'supabase\.storage' 'supabase-storage'
  scan_forbidden 'supabase\.functions\.invoke' 'supabase-functions-invoke'
  scan_forbidden 'write.*erp' 'write-erp-en'
  scan_forbidden '\bsync\b.*erp' 'sync-erp-en'
  scan_forbidden 'push.*erp' 'push-erp-en'
  scan_forbidden 'resolveApprover\(|decideApproval\(|importApply\(' 'resolver-decide-import-runtime'
fi

chmod +x "$0" 2>/dev/null || true

echo "OK: PR11.6 contracts data readiness checks passed for ${REF}"
