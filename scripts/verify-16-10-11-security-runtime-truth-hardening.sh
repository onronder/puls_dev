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

echo "Checking ${REF}: PR16.10.11 security and runtime truth hardening ..."

DOC="$(file_at_ref docs/product/16_10_11_security_runtime_truth_hardening.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
PACKAGE="$(file_at_ref package.json)"
LOCKFILE="$(file_at_ref pnpm-lock.yaml)"
CONTRACT="$(file_at_ref src/lib/data/setup/file-import-contract.ts)"
CONTRACT_TEST="$(file_at_ref src/lib/data/setup/file-import-contract.test.ts)"
DEMO_PILL="$(file_at_ref src/components/puls/DemoSourcePill.tsx)"
ERP_ROUTE="$(file_at_ref src/routes/_app/verikaynaklari.tsx)"
WORKER="$(file_at_ref services/erp-connector/src/worker.ts)"
WORKER_TEST="$(file_at_ref services/erp-connector/src/worker.test.ts)"
CI="$(file_at_ref .github/workflows/ci.yml)"
SUPABASE_AUDIT="$(file_at_ref scripts/audit-supabase-schema.mjs)"

for needle in \
  "PR16.10.11 Security & Runtime Truth Hardening" \
  "vulnerable \`xlsx@0.18.x\` is not shipped" \
  "real data fails and sample data is shown" \
  "bounded jitter" \
  "Dependency audit blocks high-severity"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.10.11 doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.10.11 - Security & Runtime Truth Hardening" \
  "Vulnerable xlsx parser" \
  "Demo fallback truthfulness" \
  "Worker loop fixed interval"; do
  if ! grep -Fq "$needle" <<< "$ROADMAP"; then
    echo "FAIL: roadmap missing PR16.10.11 needle: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR16.10.11 security and runtime truth hardening" <<< "$README"; then
  echo "FAIL: README missing PR16.10.11 section" >&2
  exit 1
fi

if grep -Fq '"xlsx"' <<< "$PACKAGE"; then
  echo "FAIL: vulnerable xlsx package must not be a dependency" >&2
  exit 1
fi

if ! grep -Fq '"exceljs"' <<< "$PACKAGE"; then
  echo "FAIL: maintained Excel parser dependency missing" >&2
  exit 1
fi

if grep -Eq '(^|/)xlsx@|xlsx:' <<< "$LOCKFILE"; then
  echo "FAIL: xlsx must not remain in pnpm lockfile" >&2
  exit 1
fi

for needle in \
  "await import('exceljs')" \
  "collectFormulaIssues(sheet)" \
  "XLSX_FORMULA_VALUE_MISSING" \
  "excelWorksheetToRows" \
  "isExcelFormulaValue"; do
  if ! grep -Fq "$needle" <<< "$CONTRACT"; then
    echo "FAIL: file import contract missing Excel hardening needle: $needle" >&2
    exit 1
  fi
done

if grep -Fq "import('xlsx')" <<< "$CONTRACT" || grep -Fq "from 'xlsx'" <<< "$CONTRACT"; then
  echo "FAIL: file import contract must not import xlsx" >&2
  exit 1
fi

for needle in \
  "await import('exceljs')" \
  "sheet.getCell('B2').value = { formula: '1+1' }" \
  "XLSX_FORMULA_VALUE_MISSING"; do
  if ! grep -Fq "$needle" <<< "$CONTRACT_TEST"; then
    echo "FAIL: file import tests missing ExcelJS/formula needle: $needle" >&2
    exit 1
  fi
done

if grep -Fq "from 'xlsx'" <<< "$CONTRACT_TEST"; then
  echo "FAIL: file import tests must not import xlsx" >&2
  exit 1
fi

for needle in \
  "fallbackReason?: 'empty' | 'error'" \
  "role=\"alert\"" \
  "demoSource.errorTitle" \
  "demoSource.errorBody"; do
  if ! grep -Fq "$needle" <<< "$DEMO_PILL"; then
    echo "FAIL: DemoSourcePill missing truthfulness needle: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "fallbackReason={erpResult?.fallbackReason}" <<< "$ERP_ROUTE"; then
  echo "FAIL: DataSource Manager must pass demo fallback reason to DemoSourcePill" >&2
  exit 1
fi

for needle in \
  "calculateWorkerLoopDelayMs" \
  "retryAfterSeconds" \
  "buildSafeWorkerFailureObservation(code, 'retry_worker_loop')" \
  "setTimeout(" \
  "redactConnectorWorkerHeaders" \
  "buildSupabaseRpcHeaders"; do
  if ! grep -Fq "$needle" <<< "$WORKER"; then
    echo "FAIL: worker missing runtime hardening needle: $needle" >&2
    exit 1
  fi
done

if grep -Fq "setInterval(" <<< "$WORKER"; then
  echo "FAIL: worker loop must not use fixed setInterval polling" >&2
  exit 1
fi

for needle in \
  "calculates worker loop delay from retry windows" \
  "backs off worker loop retries" \
  "redacts service-role headers"; do
  if ! grep -Fq "$needle" <<< "$WORKER_TEST"; then
    echo "FAIL: worker tests missing runtime hardening needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "pnpm audit --audit-level high" \
  "pnpm run audit:supabase" \
  "secrets.VITE_SUPABASE_URL" \
  "secrets.VITE_SUPABASE_ANON_KEY"; do
  if ! grep -Fq "$needle" <<< "$CI"; then
    echo "FAIL: CI missing audit gate: $needle" >&2
    exit 1
  fi
done

for needle in \
  "process.env.VITE_SUPABASE_URL" \
  "process.env.GITHUB_ACTIONS === 'true'" \
  "Supabase schema audit skipped"; do
  if ! grep -Fq "$needle" <<< "$SUPABASE_AUDIT"; then
    echo "FAIL: Supabase audit script missing CI-compatible env handling: $needle" >&2
    exit 1
  fi
done

echo "PASS: PR16.10.11 security and runtime truth hardening contract verified."
