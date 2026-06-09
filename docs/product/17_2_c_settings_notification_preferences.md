# PR17.2C — Settings Notification Preferences

> **Status:** PR17.2 third implementation slice.

PR17.2A wired HR workflow notification producers and PR17.2B added a
rollback-only closed-loop proof. PR17.2C connects the existing in-app
notification preference RPCs to `/ayarlar` so the Settings page is no longer a
read-only note for notification preferences.

## Product Contract

The notification preference area in Settings must let the signed-in user manage
source-level in-app preferences for:

1. HR workflow notifications (`puls_workflow`).
2. Data source and connector runtime notifications (`connector_runtime`).

For each source the user can:

1. Show or mute non-critical notifications in Notification Center.
2. Choose the minimum visible severity.
3. Show all notifications or only action-required notifications.
4. Temporarily mute non-critical notifications.
5. Reset the source preference to the server default.

Critical notifications remain visible by policy.

## Runtime Boundary

- The UI uses existing browser-facing RPC adapters:
  `fetchAppNotificationPreferences`, `upsertAppNotificationPreference`, and
  `clearAppNotificationPreference`.
- Preference writes stay inside `puls_app` RPC boundaries.
- The page invalidates Notification Center summary, page, and preference query
  keys after preference changes.
- No browser direct-write to notification ledger tables is introduced.

## Non-Goals

- No new notification producer.
- No external delivery, e-mail, mobile push, or webhook delivery.
- No Railway worker code.
- No new database migration.
- No raw workflow, connector, credential, or file payload readback.

## Verification

```bash
scripts/verify-17-2-c-settings-notification-preferences.sh
pnpm run typecheck
pnpm run lint
pnpm run check-i18n
```
