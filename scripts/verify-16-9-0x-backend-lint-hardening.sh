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

echo "Checking ${REF}: PR16.9.0x backend lint hardening ..."

DOC="$(file_at_ref docs/product/16_9_0x_backend_lint_hardening.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
MIGRATION="$(file_at_ref supabase/migrations/20260606171000_puls_integration_backend_lint_hardening.sql)"

for needle in \
  "PR16.9.0x Backend Lint Hardening" \
  "Remote Supabase should not expose every table and every function by default." \
  "c.provider::TEXT" \
  "c.connection_method::TEXT" \
  "typed in-memory plan" \
  "Classify each import record exactly once." \
  "supabase db lint --local --fail-on error" \
  "supabase db lint --linked --fail-on error" \
  "Handoff To PR16.9.1"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: backend lint hardening doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "puls_integration.get_connector_runtime_preflight_context" \
  "c.provider::TEXT" \
  "c.connection_method::TEXT" \
  "puls_integration.create_connector_apply_change_set" \
  "v_plan_items puls_integration.connector_apply_change_set_items[]" \
  "array_append(v_plan_items, v_plan_item)" \
  "FROM unnest(v_plan_items) AS plan_item" \
  "Keeps one-pass classification semantics with a typed in-memory plan" \
  "GRANT EXECUTE ON FUNCTION puls_integration.get_connector_runtime_preflight_context(UUID)" \
  "TO service_role" \
  "GRANT EXECUTE ON FUNCTION puls_integration.create_connector_apply_change_set(UUID)" \
  "TO authenticated, service_role" \
  "NOTIFY pgrst, 'reload schema'"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: backend lint hardening migration missing needle: $needle" >&2
    exit 1
  fi
done

for forbidden in \
  "CREATE TEMP TABLE" \
  "tmp_connector_apply_change_set_items" \
  "EXECUTE '" \
  "CREATE TABLE puls_app.app_notifications" \
  "CREATE TABLE puls_app.app_notification_reads" \
  "notification_realtime_enabled', TRUE" \
  "external_delivery_enabled', TRUE" \
  "credential_readback', TRUE" \
  "provider_api_calls', TRUE" \
  "raw_payload_readback', TRUE" \
  "field_value_readback', TRUE" \
  "snapshot_payload_readback', TRUE"; do
  if grep -Fq "$forbidden" <<< "$MIGRATION"; then
    echo "FAIL: backend lint hardening migration contains forbidden needle: $forbidden" >&2
    exit 1
  fi
done

for needle in \
  "PR16.9.0x backend lint hardening" \
  "20260606171000_puls_integration_backend_lint_hardening.sql" \
  "16_9_0x_backend_lint_hardening.md" \
  "scripts/verify-16-9-0x-backend-lint-hardening.sh"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing backend lint hardening reference: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR16.9.0x hardens two pre-existing puls_integration lint errors" \
  "PR16.9.1 should start only after local and linked backend lint pass"; do
  if ! grep -Fq "$needle" <<< "$ROADMAP"; then
    echo "FAIL: roadmap missing backend lint hardening reference: $needle" >&2
    exit 1
  fi
done

if [[ "$REF" == "WORKTREE" ]]; then
  BASE="$(git merge-base origin/main HEAD)"
  CHANGED_FILES="$(
    git diff --name-only "$BASE"
    git ls-files --others --exclude-standard
  )"
else
  BASE="$(git merge-base origin/main "$REF")"
  CHANGED_FILES="$(git diff --name-only "$BASE...$REF")"
fi

if [[ -n "$CHANGED_FILES" ]]; then
  while IFS= read -r changed; do
    [[ -z "$changed" ]] && continue
    if [[ "$REF" == "WORKTREE" && "$changed" == supabase/.temp/* ]]; then
      continue
    fi
    if [[ "$REF" == "WORKTREE" && "$changed" == supabase/.branches/* ]]; then
      continue
    fi

    case "$changed" in
      docs/product/15_16_connector_runtime_ai_roadmap.md) ;;
      docs/product/16_9_0x_backend_lint_hardening.md) ;;
      docs/product/README.md) ;;
      scripts/verify-16-9-0x-backend-lint-hardening.sh) ;;
      supabase/migrations/20260606171000_puls_integration_backend_lint_hardening.sql) ;;
      *)
        echo "FAIL: unexpected changed path for PR16.9.0x backend lint hardening: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

echo "PR16.9.0x backend lint hardening verification passed."
