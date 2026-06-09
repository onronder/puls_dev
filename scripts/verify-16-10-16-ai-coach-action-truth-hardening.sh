#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(pwd)}"
cd "$ROOT_DIR"

fail() {
  echo "verify-16-10-16: $1" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "missing file: $path"
}

require_file "docs/product/16_10_16_ai_coach_action_truth_hardening.md"
require_file "scripts/verify-16-10-16-ai-coach-action-truth-hardening.sh"
require_file "src/routes/_app/ai-koc.tsx"
require_file "src/i18n/locales/tr-TR.json"
require_file "src/i18n/locales/en-US.json"

if grep -q "toast.info" src/routes/_app/ai-koc.tsx; then
  fail "AI Coach must not use toast.info as a fake notify signup"
fi

if grep -q "from 'sonner'" src/routes/_app/ai-koc.tsx; then
  fail "AI Coach must not import sonner only to fake notify signup"
fi

if grep -q "Bell" src/routes/_app/ai-koc.tsx; then
  fail "AI Coach notify Bell action must not return without a real backend contract"
fi

for forbidden in \
  "useQuery" \
  "fetchAiCoachOverviewWithMeta" \
  "SectionHeader" \
  "ContextDomain" \
  "runtimeEvidence" \
  "guardrails" \
  "capabilities" \
  "readiness"
do
  if grep -q "$forbidden" src/routes/_app/ai-koc.tsx; then
    fail "AI Coach page must stay chat-first and not render technical readiness content: $forbidden"
  fi
done

grep -q "aiCoachSetup.chat.prompts" src/routes/_app/ai-koc.tsx \
  || fail "AI Coach must render disabled example prompt chips"

grep -q "Textarea" src/routes/_app/ai-koc.tsx \
  || fail "AI Coach must keep a chat composer surface"

grep -q "disabled" src/routes/_app/ai-koc.tsx \
  || fail "AI Coach chat surface must remain disabled until a real backend contract exists"

for key in notifyMe notifySheet notifyToast; do
  if grep -q "\"$key\"" src/i18n/locales/tr-TR.json src/i18n/locales/en-US.json; then
    fail "AI Coach fake notify locale key remains: $key"
  fi
done

grep -q "aiCoachSetup.actions.backToDashboard" src/routes/_app/ai-koc.tsx \
  || fail "AI Coach must keep the real dashboard navigation action"

if git diff --name-only HEAD -- supabase/migrations | grep -q .; then
  fail "PR16.10.16 must not include Supabase migrations"
fi

echo "verify-16-10-16: OK"
