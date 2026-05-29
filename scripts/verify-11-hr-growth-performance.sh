#!/usr/bin/env bash
# Verifies 11 PR11.5 HR growth & performance hardening (POSIX grep/awk).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
MATRIX="docs/data/11_hr_growth_performance_matrix.md"
SMOKE="docs/data/11_hr_growth_performance_smoke.sql"
CYCLES="src/lib/data/performance/cycles.ts"
CYCLES_TEST="src/lib/data/performance/cycles.test.ts"
PERF_OVERVIEW="src/lib/data/performance/overview.ts"
PERF_OVERVIEW_TEST="src/lib/data/performance/overview.test.ts"
CAREER_OVERVIEW="src/lib/data/career/overview.ts"
CAREER_OVERVIEW_TEST="src/lib/data/career/overview.test.ts"
TRAINING_OVERVIEW="src/lib/data/training/overview.ts"
TRAINING_OVERVIEW_TEST="src/lib/data/training/overview.test.ts"
JOB_EVAL_OVERVIEW="src/lib/data/job-evaluation/overview.ts"
JOB_EVAL_OVERVIEW_TEST="src/lib/data/job-evaluation/overview.test.ts"
PERF_ROUTE="src/routes/_app/performans.tsx"
KARIYER_ROUTE="src/routes/_app/kariyer.tsx"
EGITIM_ROUTE="src/routes/_app/egitim.tsx"
IS_DEGERLEME_ROUTE="src/routes/_app/is-degerleme.tsx"
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
CYCLES_CONTENT="$(file_at_ref "$CYCLES")"
CYCLES_TEST_CONTENT="$(file_at_ref "$CYCLES_TEST")"
PERF_OVERVIEW_CONTENT="$(file_at_ref "$PERF_OVERVIEW")"
PERF_OVERVIEW_TEST_CONTENT="$(file_at_ref "$PERF_OVERVIEW_TEST")"
CAREER_OVERVIEW_CONTENT="$(file_at_ref "$CAREER_OVERVIEW")"
CAREER_OVERVIEW_TEST_CONTENT="$(file_at_ref "$CAREER_OVERVIEW_TEST")"
TRAINING_OVERVIEW_CONTENT="$(file_at_ref "$TRAINING_OVERVIEW")"
TRAINING_OVERVIEW_TEST_CONTENT="$(file_at_ref "$TRAINING_OVERVIEW_TEST")"
JOB_EVAL_OVERVIEW_CONTENT="$(file_at_ref "$JOB_EVAL_OVERVIEW")"
JOB_EVAL_OVERVIEW_TEST_CONTENT="$(file_at_ref "$JOB_EVAL_OVERVIEW_TEST")"
PERF_ROUTE_CONTENT="$(file_at_ref "$PERF_ROUTE")"
KARIYER_ROUTE_CONTENT="$(file_at_ref "$KARIYER_ROUTE")"
EGITIM_ROUTE_CONTENT="$(file_at_ref "$EGITIM_ROUTE")"
IS_DEGERLEME_ROUTE_CONTENT="$(file_at_ref "$IS_DEGERLEME_ROUTE")"
DATA_INDEX_CONTENT="$(file_at_ref "$DATA_INDEX")"

echo "Checking ${REF}: PR11.5 HR growth & performance hardening ..."

for file in "$MATRIX" "$SMOKE" "$CYCLES" "$CYCLES_TEST" "$PERF_OVERVIEW" "$PERF_OVERVIEW_TEST" \
  "$CAREER_OVERVIEW" "$CAREER_OVERVIEW_TEST" "$TRAINING_OVERVIEW" "$TRAINING_OVERVIEW_TEST" \
  "$JOB_EVAL_OVERVIEW" "$JOB_EVAL_OVERVIEW_TEST" "$PERF_ROUTE" "$KARIYER_ROUTE" "$EGITIM_ROUTE" \
  "$IS_DEGERLEME_ROUTE" "$DATA_INDEX"; do
  if [[ ! -f "$file" ]]; then
    echo "FAIL: missing required file: $file"
    exit 1
  fi
done

MIGRATION_CHANGES="$(git diff --name-only --diff-filter=A origin/main...HEAD -- supabase/migrations/ 2>/dev/null || true)"
if [[ -n "$(echo "$MIGRATION_CHANGES" | sed '/^$/d')" ]]; then
  echo "FAIL: PR11.5 must not add migrations:"
  echo "$MIGRATION_CHANGES" | sed '/^$/d'
  exit 1
fi

matrix_needles=(
  "performance cycle"
  "demo_fallback"
  "placeholder"
  "No migration"
  "career_profiles"
  "training_needs"
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
  "demo_hr_growth_performance_"
  "performance_cycles"
  "career_profiles"
  "training_needs"
  "competency_templates"
  "competency_evaluations"
)

for needle in "${smoke_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$SMOKE_CONTENT"; then
    echo "FAIL: smoke missing fragment: $needle"
    exit 1
  fi
done

adapter_needles=(
  "fetchPerformanceOverviewWithMeta"
  "fetchPerformanceCyclesWithMeta"
  "fetchCareerOverviewWithMeta"
  "fetchTrainingOverviewWithMeta"
  "fetchJobEvaluationOverviewWithMeta"
  "resolveAdapterDataWithMeta"
  "validatePerformanceCycleInput"
  "parsePerformanceCycleMutationResult"
)

for needle in "${adapter_needles[@]}"; do
  case "$needle" in
    fetchPerformanceOverviewWithMeta)
      content="$PERF_OVERVIEW_CONTENT"
      ;;
    fetchPerformanceCyclesWithMeta|validatePerformanceCycleInput|parsePerformanceCycleMutationResult)
      content="$CYCLES_CONTENT"
      ;;
    fetchCareerOverviewWithMeta)
      content="$CAREER_OVERVIEW_CONTENT"
      ;;
    fetchTrainingOverviewWithMeta)
      content="$TRAINING_OVERVIEW_CONTENT"
      ;;
    fetchJobEvaluationOverviewWithMeta)
      content="$JOB_EVAL_OVERVIEW_CONTENT"
      ;;
    resolveAdapterDataWithMeta)
      content="$PERF_OVERVIEW_CONTENT$CYCLES_CONTENT$CAREER_OVERVIEW_CONTENT$TRAINING_OVERVIEW_CONTENT$JOB_EVAL_OVERVIEW_CONTENT"
      ;;
    *)
      content=""
      ;;
  esac
  if ! grep -Fq "$needle" <<< "$content"; then
    echo "FAIL: adapter missing fragment: $needle"
    exit 1
  fi
done

if ! grep -Fq ".eq('tenant_id'" <<< "$CYCLES_CONTENT"; then
  echo "FAIL: updatePerformanceCycle must filter by tenant_id"
  exit 1
fi

for needle in fetchPerformanceOverviewWithMeta fetchPerformanceCyclesWithMeta; do
  if ! grep -Fq "$needle" <<< "$DATA_INDEX_CONTENT"; then
    echo "FAIL: data index must export $needle"
    exit 1
  fi
done

for needle in validatePerformanceCycleInput parsePerformanceCycleMutationResult; do
  if ! grep -Fq "$needle" <<< "$CYCLES_TEST_CONTENT"; then
    echo "FAIL: cycles tests must cover $needle"
    exit 1
  fi
done

if ! grep -Fq "fetchPerformanceOverviewWithMeta" <<< "$PERF_OVERVIEW_TEST_CONTENT"; then
  echo "FAIL: performance overview tests must cover fetchPerformanceOverviewWithMeta"
  exit 1
fi

if ! grep -Fq "fetchCareerOverviewWithMeta" <<< "$CAREER_OVERVIEW_TEST_CONTENT"; then
  echo "FAIL: career overview tests must cover fetchCareerOverviewWithMeta"
  exit 1
fi

if ! grep -Fq "fetchTrainingOverviewWithMeta" <<< "$TRAINING_OVERVIEW_TEST_CONTENT"; then
  echo "FAIL: training overview tests must cover fetchTrainingOverviewWithMeta"
  exit 1
fi

if ! grep -Fq "fetchJobEvaluationOverviewWithMeta" <<< "$JOB_EVAL_OVERVIEW_TEST_CONTENT"; then
  echo "FAIL: job evaluation overview tests must cover fetchJobEvaluationOverviewWithMeta"
  exit 1
fi

for route_label in performans kariyer egitim is-degerleme; do
  case "$route_label" in
    performans) content="$PERF_ROUTE_CONTENT" ;;
    kariyer) content="$KARIYER_ROUTE_CONTENT" ;;
    egitim) content="$EGITIM_ROUTE_CONTENT" ;;
    is-degerleme) content="$IS_DEGERLEME_ROUTE_CONTENT" ;;
  esac
  if ! grep -Fq "orgSetupReadiness.source.demo" <<< "$content"; then
    echo "FAIL: $route_label route missing demo source pill key"
    exit 1
  fi
done

for needle in fetchPerformanceOverviewWithMeta fetchPerformanceCyclesWithMeta; do
  if ! grep -Fq "$needle" <<< "$PERF_ROUTE_CONTENT"; then
    echo "FAIL: performans route missing $needle"
    exit 1
  fi
done

for needle in fetchCareerOverviewWithMeta fetchTrainingOverviewWithMeta fetchJobEvaluationOverviewWithMeta; do
  route_file=""
  case "$needle" in
    fetchCareerOverviewWithMeta) route_file="$KARIYER_ROUTE_CONTENT" ;;
    fetchTrainingOverviewWithMeta) route_file="$EGITIM_ROUTE_CONTENT" ;;
    fetchJobEvaluationOverviewWithMeta) route_file="$IS_DEGERLEME_ROUTE_CONTENT" ;;
  esac
  if ! grep -Fq "$needle" <<< "$route_file"; then
    echo "FAIL: route missing $needle"
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
  for required_route in "$PERF_ROUTE" "$KARIYER_ROUTE" "$EGITIM_ROUTE" "$IS_DEGERLEME_ROUTE"; do
    if ! printf '%s\n' "${CHANGED_FILES[@]}" | grep -Fxq "$required_route"; then
      echo "FAIL: PR11.5 must change route $required_route"
      exit 1
    fi
  done

  if printf '%s\n' "${CHANGED_FILES[@]}" | grep -Fxq "src/routes/_app/performans-parametreleri.tsx"; then
    echo "FAIL: PR11.5 must not change performans-parametreleri route"
    exit 1
  fi

  scan_forbidden 'supabase\.functions\.invoke' 'supabase-functions-invoke'
  scan_forbidden 'write.*erp' 'write-erp-en'
  scan_forbidden '\bsync\b.*erp' 'sync-erp-en'
  scan_forbidden 'push.*erp' 'push-erp-en'
  scan_forbidden '\.from\('"'"'career_profiles'"'"'\).*\.(insert|update|delete)\(' 'career-profiles-write'
  scan_forbidden '\.from\('"'"'training_needs'"'"'\).*\.(insert|update|delete)\(' 'training-needs-write'
  scan_forbidden '\.from\('"'"'competency_evaluations'"'"'\).*\.(insert|update|delete)\(' 'competency-evaluations-write'
  scan_forbidden '\.from\('"'"'performance_scores'"'"'\).*\.(insert|update|delete)\(' 'performance-scores-write'
  scan_forbidden 'CREATE OR REPLACE FUNCTION' 'new-rpc-function'
fi

chmod +x "$0" 2>/dev/null || true

echo "OK: PR11.5 HR growth & performance hardening checks passed for ${REF}"
