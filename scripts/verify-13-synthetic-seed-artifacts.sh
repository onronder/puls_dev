#!/usr/bin/env bash
# Verifies PR13.4 synthetic seed artifacts pack.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REF="${1:-HEAD}"
VERIFY_SCRIPT="scripts/verify-13-synthetic-seed-artifacts.sh"
PACK="supabase/seed/puls-sanayi-v1"
MANIFEST="${PACK}/manifest.json"

PR133_REFERENCE_DOCS=(
  "docs/product/13_synthetic_company_seed_spec.md"
  "docs/product/13_seed_table_coverage_manifest.md"
  "docs/product/13_data_dictionary_seed_crosswalk.json"
)

CSV_FILES=(
  "01_tenant.csv" "02_legal_entities.csv" "03_locations.csv" "04_departments.csv"
  "05_positions.csv" "06_employees.csv" "07_employee_reporting_lines.csv"
  "08_employee_legal_entity_assignments.csv" "09_employee_location_assignments.csv"
  "10_cost_centers.csv" "11_employee_cost_center_assignments.csv" "12_leave_types.csv"
  "13_approval_policies.csv" "14_leave_balances.csv" "15_expense_categories.csv"
  "16_erp_connections.csv" "17_erp_field_mappings.csv" "18_source_namespaces.csv"
  "19_entity_identity_map.csv" "20_performance_cycles.csv" "21_performance_parameters.csv"
  "22_contracts.csv"
)

file_at_ref() {
  local path="$1"
  git show "${REF}:${path}" 2>/dev/null || cat "${path}"
}

echo "Checking ${REF}: PR13.4 synthetic seed artifacts ..."

REQUIRED_FILES=(
  "${PR133_REFERENCE_DOCS[@]}"
  "${PACK}/README.md"
  "${PACK}/load-order.md"
  "${MANIFEST}"
  "${PACK}/sql/00_reset_puls_sanayi_seed.sql"
  "${PACK}/sql/01_load_puls_sanayi_seed.sql"
  "${PACK}/sql/02_validate_puls_sanayi_seed.sql"
  "docs/product/README.md"
  "$VERIFY_SCRIPT"
)

for f in "${CSV_FILES[@]}"; do
  REQUIRED_FILES+=("${PACK}/csv/${f}")
done

for file in "${REQUIRED_FILES[@]}"; do
  if ! file_at_ref "$file" >/dev/null; then
    echo "FAIL: missing required file: $file"
    exit 1
  fi
done

README_CONTENT="$(file_at_ref "${PACK}/README.md")"
MANIFEST_CONTENT="$(file_at_ref "${MANIFEST}")"

doc_needles=(
  "Puls Sanayi A.Ş."
  "Canias"
  "Production-facing product behavior must not depend on embedded TypeScript business fixtures"
  "The canonical V1 demo company is DB-backed, source-aware, resettable, and large enough to exercise real product workflows."
  "PR13.4 seed artifacts must follow the data dictionary alignment crosswalk."
  "VITE_PULS_DEMO_MODE=false"
  "source: demo is not packaging proof"
  "metadata seed only"
  "no Canias runtime"
  "no automatic destructive ERP writes"
  "Numbered CSV filenames are artifact identifiers, not load order"
  "Supabase SQL Editor cannot read local CSV file paths directly"
  "21_performance_parameters.csv"
  "multi-table baseline context"
  "PR13.5"
  "source-aware"
  "PULS-owned"
  "imported"
)

for needle in "${doc_needles[@]}"; do
  if ! grep -Fq "$needle" <<< "$README_CONTENT"; then
    echo "FAIL: README missing needle: $needle"
    exit 1
  fi
done

if ! grep -Fq "baselineSeedArtifacts" <<< "$MANIFEST_CONTENT"; then
  echo "FAIL: manifest missing baselineSeedArtifacts"
  exit 1
fi

if ! grep -Fq "scenarioSeedArtifactsDeferredTo" <<< "$MANIFEST_CONTENT"; then
  echo "FAIL: manifest missing scenarioSeedArtifactsDeferredTo"
  exit 1
fi

if grep -Fq "Mert Teknik" <<< "$MANIFEST_CONTENT"; then
  echo "FAIL: Mert Teknik must not appear in manifest.json"
  exit 1
fi

# Node: manifest parse, loadOrder, tableColumnMap, row counts, multi-table guards
node - "$ROOT" "$REF" <<'NODE'
const fs = require('fs');
const { execSync } = require('child_process');

const root = process.argv[2];
const ref = process.argv[3];
const pack = `${root}/supabase/seed/puls-sanayi-v1`;

function atRef(rel) {
  try {
    return execSync(`git show ${ref}:${rel}`, { encoding: 'utf8', cwd: root, stdio: ['pipe', 'pipe', 'ignore'] });
  } catch {
    return fs.readFileSync(`${root}/${rel}`, 'utf8');
  }
}

function readCsv(rel) {
  const text = atRef(rel);
  const lines = text.trim().split('\n');
  const headers = lines[0].replace(/\r$/, '').split(',');
  const rows = lines.slice(1).filter(Boolean).map((line) => {
    const cols = [];
    let cur = '';
    let inQ = false;
    for (let i = 0; i < line.length; i++) {
      const c = line[i];
      if (c === '"') { inQ = !inQ; continue; }
      if (c === ',' && !inQ) { cols.push(cur); cur = ''; continue; }
      cur += c;
    }
    cols.push(cur);
    const obj = {};
    headers.forEach((h, i) => { obj[h] = cols[i] ?? ''; });
    return obj;
  });
  return { headers, rows };
}

function countInRange(n, spec) {
  if (typeof spec === 'number') return n === spec;
  if (spec.min != null && n < spec.min) return false;
  if (spec.max != null && n > spec.max) return false;
  return true;
}

const manifest = JSON.parse(atRef('supabase/seed/puls-sanayi-v1/manifest.json'));
const loadOrder = manifest.loadOrder;
if (loadOrder[0] !== '01_tenant.csv' || loadOrder[1] !== '16_erp_connections.csv') {
  console.error('FAIL: loadOrder must start with tenant then erp_connections (FK-safe phase order)');
  process.exit(1);
}
if (loadOrder.includes('12_leave_types.csv') && loadOrder.indexOf('12_leave_types.csv') < loadOrder.indexOf('13_approval_policies.csv')) {
  console.error('FAIL: leave_types must load after approval_policies in loadOrder');
  process.exit(1);
}

for (const entry of manifest.csvFiles) {
  const rel = `supabase/seed/puls-sanayi-v1/${entry.file}`;
  const { rows } = readCsv(rel);
  const spec = entry.expectedRows;
  if (!countInRange(rows.length, spec)) {
    console.error(`FAIL: ${entry.file} row count ${rows.length} outside ${JSON.stringify(spec)}`);
    process.exit(1);
  }
}

const emp = readCsv('supabase/seed/puls-sanayi-v1/csv/06_employees.csv');
if (emp.rows.length !== 120) {
  console.error('FAIL: expected exactly 120 employees');
  process.exit(1);
}
if (emp.headers.includes('user_id')) {
  console.error('FAIL: employees CSV must not include user_id');
  process.exit(1);
}

for (const [fileKey, map] of Object.entries(manifest.tableColumnMap)) {
  const actualRel = `supabase/seed/puls-sanayi-v1/${fileKey}`;
  const { headers, rows } = readCsv(actualRel);

  if (map.multiTable) {
    const union = new Set([...(map.stagingOnlyColumns || [])]);
    for (const t of Object.values(map.targets)) {
      (t.insertableColumns || []).forEach((c) => union.add(c));
    }
    for (const h of headers) {
      if (!union.has(h)) {
        console.error(`FAIL: ${fileKey} header '${h}' not in staging union`);
        process.exit(1);
      }
    }
    const counts = {};
    for (const row of rows) {
      const tt = row.target_table;
      if (!map.targets[tt]) {
        console.error(`FAIL: ${fileKey} unknown target_table '${tt}'`);
        process.exit(1);
      }
      counts[tt] = (counts[tt] || 0) + 1;
      for (const req of map.targets[tt].requiredColumns || []) {
        if (!row[req] || row[req].trim() === '') {
          console.error(`FAIL: ${fileKey} row missing required ${req} for ${tt}`);
          process.exit(1);
        }
      }
    }
    for (const [tt, tmap] of Object.entries(map.targets)) {
      const n = counts[tt] || 0;
      if (!countInRange(n, tmap.expectedRows)) {
        console.error(`FAIL: ${fileKey} ${tt} count ${n} outside ${JSON.stringify(tmap.expectedRows)}`);
        process.exit(1);
      }
    }
    if (fileKey.includes('21_') && (counts.career_profiles || 0) >= 100) {
      console.error('FAIL: career_profiles bloat guard');
      process.exit(1);
    }
  } else {
    const allowed = new Set([...(map.insertableColumns || []), ...(map.stagingOnlyColumns || [])]);
    for (const h of headers) {
      if (!allowed.has(h)) {
        console.error(`FAIL: ${fileKey} header '${h}' not insertable/staging`);
        process.exit(1);
      }
    }
    if (map.excludedColumns) {
      for (const ex of Object.keys(map.excludedColumns)) {
        if (headers.includes(ex)) {
          console.error(`FAIL: ${fileKey} contains excluded column ${ex}`);
          process.exit(1);
        }
      }
    }
  }
}

const forbidden = ['api_key', 'secret', 'password', 'token', 'credentials_ref'];
for (const f of forbidden) {
  if (manifest.forbiddenFields && !manifest.forbiddenFields.includes(f === 'credentials_ref' ? 'credentials_ref' : f)) {
    // manifest lists forbidden fields
  }
}

// CSV data scope checks (not README)
const csvDataFiles = [
  '01_tenant.csv','02_legal_entities.csv','03_locations.csv','04_departments.csv',
  '05_positions.csv','06_employees.csv','07_employee_reporting_lines.csv',
  '08_employee_legal_entity_assignments.csv','09_employee_location_assignments.csv',
  '10_cost_centers.csv','11_employee_cost_center_assignments.csv','12_leave_types.csv',
  '13_approval_policies.csv','14_leave_balances.csv','15_expense_categories.csv',
  '16_erp_connections.csv','17_erp_field_mappings.csv','18_source_namespaces.csv',
  '19_entity_identity_map.csv','20_performance_cycles.csv','21_performance_parameters.csv',
  '22_contracts.csv',
];
for (const f of csvDataFiles) {
  const content = atRef(`supabase/seed/puls-sanayi-v1/csv/${f}`);
  if (/Mert Teknik/i.test(content)) {
    console.error(`FAIL: Mert Teknik in CSV ${f}`);
    process.exit(1);
  }
  if (/fetchDemo/i.test(content)) {
    console.error(`FAIL: fetchDemo reference in CSV ${f}`);
    process.exit(1);
  }
}

for (const f of ['07_employee_reporting_lines.csv','08_employee_legal_entity_assignments.csv','09_employee_location_assignments.csv','11_employee_cost_center_assignments.csv']) {
  const { rows } = readCsv(`supabase/seed/puls-sanayi-v1/csv/${f}`);
  for (const row of rows) {
    if (row.source === 'demo') {
      console.error(`FAIL: source=demo in CSV data ${f}`);
      process.exit(1);
    }
  }
}

const erpHeaders = readCsv('supabase/seed/puls-sanayi-v1/csv/16_erp_connections.csv').headers;
if (erpHeaders.includes('credentials_ref')) {
  console.error('FAIL: credentials_ref column in erp_connections CSV');
  process.exit(1);
}

console.log('OK: manifest/tableColumnMap/csv guards passed');
NODE

# SQL guards
RESET_SQL="$(file_at_ref "${PACK}/sql/00_reset_puls_sanayi_seed.sql")"
LOAD_SQL="$(file_at_ref "${PACK}/sql/01_load_puls_sanayi_seed.sql")"

if ! grep -Fq "LEGACY_PUBLIC_EXCLUSION" <<< "$RESET_SQL"; then
  echo "FAIL: reset SQL missing LEGACY_PUBLIC_EXCLUSION comment"
  exit 1
fi

if ! grep -Fq $'\\copy' <<< "$LOAD_SQL"; then
  echo "FAIL: load SQL must document psql-local \\copy"
  exit 1
fi

if grep -Fq "supabase/migrations" <<< "$LOAD_SQL"; then
  echo "FAIL: load SQL must not reference supabase/migrations"
  exit 1
fi

# public.* only on LEGACY_PUBLIC_EXCLUSION comment lines
check_sql_no_public() {
  local sql="$1"
  local label="$2"
  while IFS= read -r line; do
    case "$line" in
      *"LEGACY_PUBLIC_EXCLUSION"*) continue ;;
      *"public."*)
        echo "FAIL: ${label} contains public. outside LEGACY_PUBLIC_EXCLUSION: $line"
        exit 1
        ;;
    esac
  done <<< "$sql"
}
check_sql_no_public "$RESET_SQL" "reset SQL"
check_sql_no_public "$LOAD_SQL" "load SQL"

# Diff guard
if git rev-parse --verify origin/main >/dev/null 2>&1; then
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    case "$file" in
      supabase/seed/puls-sanayi-v1/*|docs/product/README.md|scripts/verify-13-synthetic-seed-artifacts.sh)
        ;;
      src/*|supabase/migrations/*|docs/api/openapi.yaml|.env*|.env.example|package.json|openapi.json|swagger.json)
        echo "FAIL: forbidden changed path: $file"
        exit 1
        ;;
      *)
        echo "FAIL: PR13.4 must not change: $file"
        exit 1
        ;;
    esac
  done < <(git diff --name-only origin/main...HEAD 2>/dev/null || true)
fi

chmod +x "$0" 2>/dev/null || true
echo "OK: PR13.4 synthetic seed artifacts checks passed for ${REF}"
