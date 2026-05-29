#!/usr/bin/env bash
# Verifies 11 PR11.4 leave consumption hardening (POSIX grep/awk).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
MATRIX="docs/data/11_leave_consumption_hardening_matrix.md"
SMOKE="docs/data/11_leave_consumption_hardening_smoke.sql"
OVERVIEW="src/lib/data/leave/overview.ts"
OVERVIEW_TEST="src/lib/data/leave/overview.test.ts"
REQUESTS="src/lib/data/leave/requests.ts"
REQUESTS_TEST="src/lib/data/leave/requests.test.ts"
LEAVE_ROUTE="src/routes/_app/izin.tsx"
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
REQUESTS_CONTENT="$(file_at_ref "$REQUESTS")"
REQUESTS_TEST_CONTENT="$(file_at_ref "$REQUESTS_TEST")"
LEAVE_ROUTE_CONTENT="$(file_at_ref "$LEAVE_ROUTE")"
DATA_INDEX_CONTENT="$(file_at_ref "$DATA_INDEX")"

echo "Checking ${REF}: PR11.4 leave consumption hardening ..."

for file in "$MATRIX" "$SMOKE" "$OVERVIEW" "$OVERVIEW_TEST" "$REQUESTS" "$REQUESTS_TEST" "$LEAVE_ROUTE" "$DATA_INDEX"; do
  if [[ ! -f "$file" ]]; then
    echo "FAIL: missing required file: $file"
    exit 1
  fi
done

MIGRATION_CHANGES="$(git diff --name-only --diff-filter=A origin/main...HEAD -- supabase/migrations/ 2>/dev/null || true)"
if [[ -n "$(echo "$MIGRATION_CHANGES" | sed '/^$/d')" ]]; then
  echo "FAIL: PR11.4 must not add migrations:"
  echo "$MIGRATION_CHANGES" | sed '/^$/d'
  exit 1
fi

matrix_needles=(
  "active-only"
  "inactive historical"
  "JWT"
  "create_leave_request"
  "decide_approval_request"
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
  "demo_leave_consumption_hardening_"
  "request.jwt.claim.sub"
  "puls_core.current_employee_id()"
  "PULS_INVALID_LEAVE_TYPE"
  "create_leave_request"
  "decide_approval_request"
  "pg_proc"
)

for needle in "${smoke_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$SMOKE_CONTENT"; then
    echo "FAIL: smoke missing fragment: $needle"
    exit 1
  fi
done

adapter_needles=(
  "fetchLeaveOverviewWithMeta"
  "resolveAdapterDataWithMeta"
  "mapDemoLeaveOverviewToOverview"
)

for needle in "${adapter_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$OVERVIEW_CONTENT"; then
    echo "FAIL: overview adapter missing fragment: $needle"
    exit 1
  fi
done

if ! grep -Fq "parseCreateLeaveRequestResult" <<< "$REQUESTS_CONTENT"; then
  echo "FAIL: requests adapter missing parseCreateLeaveRequestResult"
  exit 1
fi

if ! grep -Fq "invalid_rpc_result" <<< "$REQUESTS_CONTENT"; then
  echo "FAIL: requests adapter missing invalid_rpc_result"
  exit 1
fi

if ! grep -Fq "fetchLeaveOverviewWithMeta" <<< "$DATA_INDEX_CONTENT"; then
  echo "FAIL: data index must export fetchLeaveOverviewWithMeta"
  exit 1
fi

for needle in fetchLeaveOverviewWithMeta; do
  if ! grep -Fq "$needle" <<< "$OVERVIEW_TEST_CONTENT"; then
    echo "FAIL: overview tests must cover $needle"
    exit 1
  fi
done

if ! grep -Fq "parseCreateLeaveRequestResult" <<< "$REQUESTS_TEST_CONTENT"; then
  echo "FAIL: requests tests must cover parseCreateLeaveRequestResult"
  exit 1
fi

for needle in fetchLeaveOverviewWithMeta leaveOverviewResult "source === 'demo'" orgSetupReadiness.source.demo requestCreationReadiness inactiveTypeBadge; do
  if ! grep -Fq "$needle" <<< "$LEAVE_ROUTE_CONTENT"; then
    echo "FAIL: izin route missing fragment: $needle"
    exit 1
  fi
done

if grep -Fq "common.soon" <<< "$LEAVE_ROUTE_CONTENT"; then
  echo "FAIL: izin route must not use common.soon"
  exit 1
fi

if ! grep -Fq ".eq('is_active', true)" <<< "$OVERVIEW_CONTENT"; then
  echo "FAIL: overview must filter active-only picker with .eq('is_active', true)"
  exit 1
fi

for needle in mapLeaveTypeFromLookup ".select('id, name, is_active')" ".in('id', leaveTypeIds)"; do
  if ! grep -Fq "$needle" <<< "$OVERVIEW_CONTENT"; then
    echo "FAIL: overview missing historical readability fragment: $needle"
    exit 1
  fi
done

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
  if ! printf '%s\n' "${CHANGED_FILES[@]}" | grep -Fxq "$LEAVE_ROUTE"; then
    echo "FAIL: PR11.4 must change consumption route $LEAVE_ROUTE"
    exit 1
  fi

  for forbidden_route in "src/routes/_app/izin-tanimlari.tsx" "src/lib/data/setup/leave-types.ts"; do
    if printf '%s\n' "${CHANGED_FILES[@]}" | grep -Fxq "$forbidden_route"; then
      echo "FAIL: PR11.4 must not change setup route/adapter $forbidden_route"
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
  scan_forbidden 'CREATE OR REPLACE FUNCTION' 'new-rpc-function'
fi

chmod +x "$0" 2>/dev/null || true

echo "OK: PR11.4 leave consumption hardening checks passed for ${REF}"
