#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(pwd)}"
cd "$ROOT_DIR"

fail() {
  echo "verify-16-10-15: $1" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "missing file: $path"
}

require_file "docs/product/16_10_15_route_boundary_hr_cache_hardening.md"
require_file "src/lib/data/query-invalidation.ts"
require_file "src/lib/data/query-invalidation.test.ts"
require_file "scripts/verify-16-10-15-route-boundary-hr-cache-hardening.sh"

grep -q '<AppErrorBoundary>' src/routes/__root.tsx \
  || fail "root app boundary must remain in __root.tsx"

grep -q 'area="app_route"' src/routes/_app.tsx \
  || fail "_app route outlet must use a route-scoped AppErrorBoundary"

grep -q 'key={pathname}' src/routes/_app.tsx \
  || fail "route boundary must reset on pathname change"

grep -q 'invalidateOrgStructureQueries(queryClient, user.id)' src/routes/_app/departmanlar.tsx \
  || fail "departments save success must use org structure invalidation"

grep -q 'invalidateOrgStructureQueries(queryClient, user.id)' src/routes/_app/pozisyonlar.tsx \
  || fail "positions save success must use org structure invalidation"

for query_key in \
  departments-overview \
  positions-overview \
  employee-assignment-readiness \
  employees-overview-leave \
  dashboard-overview \
  setup-readiness-dashboard
do
  grep -q "$query_key" src/lib/data/query-invalidation.ts \
    || fail "org structure helper missing query key: $query_key"
done

if git diff --name-only HEAD -- supabase/migrations | grep -q .; then
  fail "PR16.10.15 must not include Supabase migrations"
fi

echo "verify-16-10-15: OK"
