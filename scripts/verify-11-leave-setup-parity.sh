#!/usr/bin/env bash
# Verifies 11 PR11.3 leave setup parity (POSIX grep/awk).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
MATRIX="docs/data/11_leave_setup_parity_matrix.md"
SMOKE="docs/data/11_leave_setup_parity_smoke.sql"
LEAVE_TYPES="src/lib/data/setup/leave-types.ts"
LEAVE_TYPES_TEST="src/lib/data/setup/leave-types.test.ts"
LEAVE_ROUTE="src/routes/_app/izin-tanimlari.tsx"
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
LEAVE_TYPES_CONTENT="$(file_at_ref "$LEAVE_TYPES")"
LEAVE_TYPES_TEST_CONTENT="$(file_at_ref "$LEAVE_TYPES_TEST")"
LEAVE_ROUTE_CONTENT="$(file_at_ref "$LEAVE_ROUTE")"
DATA_INDEX_CONTENT="$(file_at_ref "$DATA_INDEX")"

echo "Checking ${REF}: PR11.3 leave setup parity ..."

for file in "$MATRIX" "$SMOKE" "$LEAVE_TYPES" "$LEAVE_TYPES_TEST" "$LEAVE_ROUTE" "$DATA_INDEX"; do
  if [[ ! -f "$file" ]]; then
    echo "FAIL: missing required file: $file"
    exit 1
  fi
done

MIGRATION_CHANGES="$(git diff --name-only --diff-filter=A origin/main...HEAD -- supabase/migrations/ 2>/dev/null || true)"
if [[ -n "$(echo "$MIGRATION_CHANGES" | sed '/^$/d')" ]]; then
  echo "FAIL: PR11.3 must not add migrations:"
  echo "$MIGRATION_CHANGES" | sed '/^$/d'
  exit 1
fi

matrix_needles=(
  "Leave-vs-expense"
  "intentional difference"
  "lifecycle audit"
  "policy binding"
  "active-only"
  "No migration"
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
  "demo_leave_setup_parity_"
  "pg_constraint"
  "pg_get_constraintdef"
  "puls_workflow_leave_types_validate_guardrails"
  "leave_type_lifecycle_events"
  "deactivate_leave_type"
  "restore_leave_type"
)

for needle in "${smoke_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$SMOKE_CONTENT"; then
    echo "FAIL: smoke missing fragment: $needle"
    exit 1
  fi
done

adapter_needles=(
  "fetchLeaveTypesOverviewWithMeta"
  "resolveAdapterDataWithMeta"
  "fetchLeaveTypesOverview"
)

for needle in "${adapter_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$LEAVE_TYPES_CONTENT"; then
    echo "FAIL: leave-types adapter missing fragment: $needle"
    exit 1
  fi
done

if ! grep -Fq "fetchLeaveTypesOverviewWithMeta" <<< "$DATA_INDEX_CONTENT"; then
  echo "FAIL: data index must export fetchLeaveTypesOverviewWithMeta"
  exit 1
fi

for needle in fetchLeaveTypesOverviewWithMeta; do
  if ! grep -Fq "$needle" <<< "$LEAVE_TYPES_TEST_CONTENT"; then
    echo "FAIL: leave-types tests must cover $needle"
    exit 1
  fi
done

for needle in leaveTypesResult "source === 'demo'" orgSetupReadiness.source.demo ApprovalPolicyBindingSection fetchLeaveTypeLifecycleEvents; do
  if ! grep -Fq "$needle" <<< "$LEAVE_ROUTE_CONTENT"; then
    echo "FAIL: izin-tanimlari route missing fragment: $needle"
    exit 1
  fi
done

if grep -Fq "common.soon" <<< "$LEAVE_ROUTE_CONTENT"; then
  echo "FAIL: izin-tanimlari must not use common.soon"
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
  for forbidden_route in "src/routes/_app/izin.tsx"; do
    if printf '%s\n' "${CHANGED_FILES[@]}" | grep -Fxq "$forbidden_route"; then
      echo "FAIL: PR11.3 must not change consumption route $forbidden_route"
      exit 1
    fi
  done

  scan_forbidden 'resolveApprover\(|decideApproval\(|importApply\(' 'resolver-decide-import-runtime'
  scan_forbidden 'supabase\.functions\.invoke' 'supabase-functions-invoke'
  scan_forbidden 'write.*erp' 'write-erp-en'
  scan_forbidden '\bsync\b.*erp' 'sync-erp-en'
  scan_forbidden 'push.*erp' 'push-erp-en'
  scan_forbidden '\.from\('"'"'leave_types'"'"'\).*\.delete\(' 'hard-delete-leave-types'
  scan_forbidden 'CREATE TABLE.*leave_type_lifecycle_events' 'new-lifecycle-audit-table'
fi

chmod +x "$0" 2>/dev/null || true

echo "OK: PR11.3 leave setup parity checks passed for ${REF}"
