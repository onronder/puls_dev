#!/usr/bin/env bash
# Verifies 10 PR10.3 ERP readiness UI (POSIX grep/awk).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ADAPTER="src/lib/data/setup/cost-center-readiness.ts"
I18N_TR="src/i18n/locales/tr-TR.json"
I18N_EN="src/i18n/locales/en-US.json"

echo "Checking PR10.3 ERP readiness UI ..."

if [[ ! -f "$ADAPTER" ]]; then
  echo "FAIL: missing adapter: $ADAPTER"
  exit 1
fi

for mutation in '.insert(' '.update(' '.upsert(' '.delete('; do
  if grep -Fq "$mutation" "$ADAPTER"; then
    echo "FAIL: adapter must not contain mutation: $mutation"
    exit 1
  fi
done

if ! grep -Fq 'resolveTenantContext' "$ADAPTER"; then
  echo "FAIL: adapter must use resolveTenantContext"
  exit 1
fi

if ! grep -Fq ".eq('tenant_id'" "$ADAPTER"; then
  echo "FAIL: adapter must filter queries by tenant_id"
  exit 1
fi

for key in export_ready_erp export_ready_external needs_mapping puls_only inactive; do
  if ! grep -Fq "\"$key\"" "$I18N_TR" || ! grep -Fq "\"$key\"" "$I18N_EN"; then
    echo "FAIL: missing i18n readiness key: $key"
    exit 1
  fi
done

if ! grep -Fq 'costCenterMappings' "$I18N_TR" || ! grep -Fq 'costCenterMappings' "$I18N_EN"; then
  echo "FAIL: missing costCenterMappings i18n namespace"
  exit 1
fi

MIGRATION_CHANGES=""
if git rev-parse origin/cursor/10-resolver-config-v1-b5b2 >/dev/null 2>&1; then
  BASE_REF="$(git merge-base HEAD origin/cursor/10-resolver-config-v1-b5b2)"
  for commit in $(git rev-list "${BASE_REF}"..HEAD 2>/dev/null || true); do
    COMMIT_MIGRATIONS="$(git diff-tree --no-commit-id --name-only -r "$commit" -- supabase/migrations/ 2>/dev/null || true)"
    if [[ -n "$COMMIT_MIGRATIONS" ]]; then
      MIGRATION_CHANGES="${MIGRATION_CHANGES}${COMMIT_MIGRATIONS}"$'\n'
    fi
  done
else
  MIGRATION_CHANGES="$(git diff --name-only --diff-filter=AM origin/main...HEAD -- supabase/migrations/ 2>/dev/null || true)"
fi

if [[ -n "$(echo "$MIGRATION_CHANGES" | sed '/^$/d')" ]]; then
  echo "FAIL: PR10.3 must not add or modify migrations:"
  echo "$MIGRATION_CHANGES" | sed '/^$/d'
  exit 1
fi

if grep -Riq 'supabase\.functions\.invoke' src/lib/data/setup/cost-center-readiness.ts src/routes/_app/masraf-kategorileri.tsx 2>/dev/null; then
  echo "FAIL: ERP readiness UI must not invoke edge functions"
  exit 1
fi

PR103_SCAN_FILES=(
  "$ADAPTER"
  "src/routes/_app/masraf-kategorileri.tsx"
  "$I18N_TR"
  "$I18N_EN"
)

scan_forbidden() {
  local pattern="$1"
  local label="$2"
  for file in "${PR103_SCAN_FILES[@]}"; do
    if [[ -f "$file" ]] && grep -iq "$pattern" "$file"; then
      echo "FAIL: forbidden ERP write pattern ($label) in $file: $pattern"
      grep -in "$pattern" "$file" || true
      exit 1
    fi
  done
}

# Turkish apostrophe variants (ASCII, Unicode U+2019, spaced)
scan_forbidden "ERP'ye" "ascii-apostrophe-ye"
scan_forbidden "ERP’ye" "unicode-apostrophe-ye"
scan_forbidden "ERP ye" "spaced-ye"
scan_forbidden "ERP'de" "ascii-apostrophe-de"
scan_forbidden "ERP’de" "unicode-apostrophe-de"
scan_forbidden "ERP'ye gönder" "ascii-send"
scan_forbidden "ERP’ye gönder" "unicode-send"
scan_forbidden "Masrafı ERP" "expense-to-erp"
scan_forbidden "ERP master data" "erp-master-data"
scan_forbidden "Otomatik ERP kaydı" "auto-erp-record"
scan_forbidden "sync.*erp" "sync-erp-en"
scan_forbidden "push.*erp" "push-erp-en"
scan_forbidden "write.*erp" "write-erp-en"
scan_forbidden "create.*erp" "create-erp-en"
scan_forbidden "update.*erp" "update-erp-en"

if [[ ! -f "src/lib/data/setup/cost-center-readiness.test.ts" ]]; then
  echo "FAIL: missing pure function tests"
  exit 1
fi

if ! grep -Fq 'computeCostCenterReadinessStatus' src/lib/data/setup/cost-center-readiness.test.ts; then
  echo "FAIL: tests must cover computeCostCenterReadinessStatus"
  exit 1
fi

echo "OK: PR10.3 ERP readiness UI checks passed."
