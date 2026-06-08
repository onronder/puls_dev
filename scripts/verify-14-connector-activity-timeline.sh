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

echo "Checking ${REF}: PR14.15 connector activity timeline ..."

DOC="$(file_at_ref docs/product/14_connector_activity_timeline.md)"
README="$(file_at_ref docs/product/README.md)"
ROADMAP="$(file_at_ref docs/product/14_connector_implementation_roadmap.md)"
MIGRATION="$(file_at_ref supabase/migrations/20260603130000_puls_integration_connector_activity_timeline.sql)"
ERP_ADAPTER="$(file_at_ref src/lib/data/setup/erp.ts)"
ERP_ROUTE="$(file_at_ref src/routes/_app/verikaynaklari.tsx)"
ERP_TEST="$(file_at_ref src/lib/data/setup/erp.test.ts)"
DATA_INDEX="$(file_at_ref src/lib/data/index.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"
VERIFY_SELF="$(file_at_ref scripts/verify-14-connector-activity-timeline.sh)"

for needle in \
  "PR14.15 adds connector activity timeline, not runtime sync." \
  "Activity details are sanitized and source-independent." \
  "Safe error details must not include API keys, passwords, tokens, connection strings, FTP credentials, credentials_ref, or provider payloads." \
  "\`erp_sync_batches remains metadata-only setup history.\`" \
  "Canias is one source profile; activity timeline is connector-agnostic." \
  "No import, export, sync execution, credential capture, or ERP writeback is enabled."; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR14.15 doc missing activity timeline needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "event_key" \
  "actor_employee_id" \
  "safe_error_code" \
  "safe_error_context" \
  "next_action_key" \
  "erp_sync_batches_tenant_event_created_idx" \
  "metadata-only setup history"; do
  if ! grep -Fq "$needle" <<< "$MIGRATION"; then
    echo "FAIL: PR14.15 migration missing activity timeline needle: $needle" >&2
    exit 1
  fi
done

if grep -Fq "status IN ('partial'" <<< "$MIGRATION"; then
  echo "FAIL: migration must not compare sync_status enum to non-enum literal partial" >&2
  exit 1
fi

for needle in \
  "ConnectorActivityEvent" \
  "activityTimeline" \
  "buildConnectorActivityEvent" \
  "setup_lifecycle" \
  "setup_mapping_contract_ready" \
  "setup_preflight_completed" \
  "credential_handoff_requested" \
  "safe_error_context" \
  "setup_preflight_has_warnings" \
  "setup_preflight_blocked" \
  "next_action_key"; do
  if ! grep -Fq "$needle" <<< "$ERP_ADAPTER"; then
    echo "FAIL: ERP adapter missing activity timeline needle: $needle" >&2
    exit 1
  fi
done

if grep -Fq "row.error_summary ??" <<< "$ERP_ADAPTER"; then
  echo "FAIL: adapter must not expose raw error_summary through connector logs" >&2
  exit 1
fi

if grep -Fq "credentials_ref" <<< "$ERP_ADAPTER"; then
  echo "FAIL: ERP adapter must not select or expose credentials_ref" >&2
  exit 1
fi

if grep -Fq "select('*')" <<< "$ERP_ADAPTER"; then
  echo "FAIL: ERP adapter must not use select('*') on connector data" >&2
  exit 1
fi

for needle in \
  "data.activityTimeline" \
  "erp.sections.activityTimeline" \
  "erp.activityTimeline.labels.safeDetails" \
  "erp.activityTimeline.labels.nextAction" \
  "formatActivityDetailValue" \
  "event.safeErrorSummaryKey"; do
  if ! grep -Fq "$needle" <<< "$ERP_ROUTE"; then
    echo "FAIL: ERP route missing activity timeline UI needle: $needle" >&2
    exit 1
  fi
done

if grep -Fq "data.syncLogs.map" <<< "$ERP_ROUTE"; then
  echo "FAIL: ERP route must render activityTimeline instead of raw syncLogs" >&2
  exit 1
fi

if grep -Eiq 'type=["'\'']password["'\'']|name=["'\''](apiKey|api_key|token|secret|password|connectionString|ftpPassword)["'\'']|placeholder=.*(API key|token|password|secret|connection string)|sync_canias_now|write_to_canias|delete_or_overwrite|live connector runtime enabled' <<< "$ERP_ROUTE"$'\n'"$ERP_ADAPTER"; then
  echo "FAIL: PR14.15 introduced credential input or runtime/writeback enablement pattern" >&2
  exit 1
fi

for needle in \
  '"activityTimeline"' \
  '"setupLifecycle"' \
  '"setup_mapping_contract_ready"' \
  '"setup_preflight_has_warnings"' \
  '"wait_for_secure_reference"' \
  '"safeDetails"' \
  '"nextAction"'; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing activity timeline key: $needle" >&2
    exit 1
  fi
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing activity timeline key: $needle" >&2
    exit 1
  fi
done

for needle in \
  "activityTimeline" \
  "setup_preflight_has_warnings" \
  "setup_lifecycle" \
  "safe_error_context" \
  "not.toContain('secret://')" \
  "credential_handoff_requested"; do
  if ! grep -Fq "$needle" <<< "$ERP_TEST"; then
    echo "FAIL: ERP tests missing activity timeline case: $needle" >&2
    exit 1
  fi
done

for needle in \
  "ConnectorActivityEvent" \
  "ConnectorActivityDetail" \
  "ConnectorActivityEventKind"; do
  if ! grep -Fq "$needle" <<< "$DATA_INDEX"; then
    echo "FAIL: data index missing activity timeline type export: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.15 Connector activity timeline" \
  "14_connector_activity_timeline.md" \
  "20260603130000_puls_integration_connector_activity_timeline.sql" \
  "scripts/verify-14-connector-activity-timeline.sh"; do
  if ! grep -Fq "$needle" <<< "$README"; then
    echo "FAIL: README missing PR14.15 reference: $needle" >&2
    exit 1
  fi
done

for needle in \
  "PR14.15 - Connector Activity Timeline" \
  "Canias is treated as one source profile" \
  "Connector setup activities leave safe, durable history records."; do
  if ! grep -Fq "$needle" <<< "$ROADMAP"; then
    echo "FAIL: roadmap missing PR14.15 reference: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR14.15 connector activity timeline" <<< "$VERIFY_SELF"; then
  echo "FAIL: verify script self-check missing PR14.15 label" >&2
  exit 1
fi

if [[ "$REF" == "WORKTREE" ]]; then
  CHANGED_FILES="$(
    git diff --name-only "$(git merge-base origin/main HEAD)"
    git ls-files --others --exclude-standard
  )"
else
  CHANGED_FILES="$(git diff --name-only "$(git merge-base origin/main "$REF")...$REF")"
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
      docs/product/14_connector_activity_timeline.md) ;;
      docs/product/14_connector_implementation_roadmap.md) ;;
      docs/product/README.md) ;;
      scripts/verify-14-connector-activity-timeline.sh) ;;
      supabase/migrations/20260603130000_puls_integration_connector_activity_timeline.sql) ;;
      src/i18n/locales/en-US.json) ;;
      src/i18n/locales/tr-TR.json) ;;
      src/lib/data/index.ts) ;;
      src/lib/data/setup/erp.test.ts) ;;
      src/lib/data/setup/erp.ts) ;;
      src/routes/_app/verikaynaklari.tsx) ;;
      *)
        echo "FAIL: unexpected changed path for PR14.15 activity timeline: $changed" >&2
        exit 1
        ;;
    esac

    case "$changed" in
      supabase/seed/puls-sanayi-v1/csv/*|supabase/seed/puls-sanayi-v1/manifest.json|services/*/src/*|package.json|.env*|docs/api/openapi.yaml|openapi.json|swagger.json)
        echo "FAIL: forbidden path changed for PR14.15 activity timeline: $changed" >&2
        exit 1
        ;;
    esac
  done <<< "$CHANGED_FILES"
fi

echo "OK: PR14.15 connector activity timeline verification passed"
