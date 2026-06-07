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

echo "Checking ${REF}: PR16.9.7x settings notification status hotfix ..."

DOC="$(file_at_ref docs/product/16_9_7x_settings_notification_status_hotfix.md)"
ROADMAP="$(file_at_ref docs/product/15_16_connector_runtime_ai_roadmap.md)"
README="$(file_at_ref docs/product/README.md)"
OVERVIEW="$(file_at_ref src/lib/data/settings/overview.ts)"
TESTS="$(file_at_ref src/lib/data/settings/overview.test.ts)"
TR_LOCALE="$(file_at_ref src/i18n/locales/tr-TR.json)"
EN_LOCALE="$(file_at_ref src/i18n/locales/en-US.json)"

for needle in \
  "PR16.9.7x Settings Notification Status Hotfix" \
  "No database schema, RLS, grants, or RPC contract changes" \
  "No external delivery, email, push, provider call, credential readback, or source writeback" \
  "No-tenant adapter coverage keeps the notification card"; do
  if ! grep -Fq "$needle" <<< "$DOC"; then
    echo "FAIL: PR16.9.7x doc missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "section('notifications', 'ready'" \
  "valueKey('settingsSetup.values.enabled')" \
  "settingsSetup.helpers.notificationsReady" \
  "settingsSetup.evidence.preference"; do
  if ! grep -Fq "$needle" <<< "$OVERVIEW"; then
    echo "FAIL: settings overview missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "section('notifications', 'locked'" \
  "settingsSetup.helpers.notificationsNoTenant"; do
  if ! grep -Fq "$needle" <<< "$OVERVIEW"; then
    echo "FAIL: settings overview missing no-tenant guard needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "section.id === 'notifications'" \
  "status: 'ready'" \
  "settingsSetup.values.enabled" \
  "settingsSetup.helpers.notificationsReady" \
  "?.status).toBe(" \
  "'locked'"; do
  if ! grep -Fq "$needle" <<< "$TESTS"; then
    echo "FAIL: settings overview test missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "notificationsReady" \
  "Uygulama içi bildirim tercihleri Bildirimler panelinden yönetilir"; do
  if ! grep -Fq "$needle" <<< "$TR_LOCALE"; then
    echo "FAIL: Turkish locale missing needle: $needle" >&2
    exit 1
  fi
done

for needle in \
  "notificationsReady" \
  "In-app notification preferences are managed from the Notifications panel"; do
  if ! grep -Fq "$needle" <<< "$EN_LOCALE"; then
    echo "FAIL: English locale missing needle: $needle" >&2
    exit 1
  fi
done

if ! grep -Fq "PR16.9.7x aligns /ayarlar notification status" <<< "$ROADMAP"; then
  echo "FAIL: roadmap missing PR16.9.7x implementation status" >&2
  exit 1
fi

if ! grep -Fq "PR16.9.7x settings notification status hotfix" <<< "$README"; then
  echo "FAIL: README missing PR16.9.7x section" >&2
  exit 1
fi

echo "PR16.9.7x settings notification status hotfix verification passed."
