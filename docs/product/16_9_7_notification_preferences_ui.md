# PR16.9.7 Notification Preferences UI

PR16.9.7 makes the existing app-wide in-app notification preference contract usable from
the product. It keeps Notification Center as a PULS app capability, with `/erp` still only
the first producer and first visible operational source.

## Scope

- Adds Notification Center preference UI inside the global notification sheet.
- Uses the existing `puls_app` preference RPCs:
  - `list_app_notification_preferences`
  - `upsert_app_notification_preference`
  - `clear_app_notification_preference`
- Starts with the `connector_runtime/all` source scope, labelled as ERP connection.
- Supports:
  - in-app visibility on/off,
  - minimum severity,
  - action-required-only visibility,
  - temporary mute,
  - reset to defaults.
- Updates bootstrap status to
  `pr16.9.7-notification-preferences-ui-v1`.

## Product Behavior

The Notification Center header now includes a settings action. The settings view opens
inside the same mobile-safe sheet instead of sending users to another page.

Current first scope:

| Source domain | Source event | Product label |
| --- | --- | --- |
| `connector_runtime` | `all` | ERP connection |

Critical notifications always stay visible even when the source is muted or filtered.
That guard is enforced by the database preference contract and repeated in the UI copy.

## Safety Contract

- No new authenticated table access.
- No browser direct writes to notification tables.
- Preference mutation stays current-employee scoped through RPCs.
- External delivery remains closed:
  - no email,
  - no push,
  - no SMS,
  - no Slack.
- No provider API calls, source writeback, credential readback, raw payload readback, field
  value readback, before/after value readback, or snapshot payload readback are introduced.
- Realtime remains optional. RPC list/summary/preference reads are still the correctness
  path.

## Smoke SQL

### Bootstrap Smoke

Run with service-role, or with an authenticated tenant/employee claim context.

```sql
select set_config('request.jwt.claim.role', 'service_role', false);

select
  contract_version,
  notification_ledger_enabled,
  notification_realtime_enabled,
  external_delivery_enabled,
  next_action_key,
  safe_summary->>'notification_preferences_enabled' as preferences_enabled,
  safe_summary->>'notification_preferences_ui_enabled' as preferences_ui_enabled,
  safe_summary->>'notification_preference_first_scope' as first_preference_scope,
  safe_summary->>'critical_notifications_always_visible' as critical_always_visible
from puls_app.get_notification_center_bootstrap_status();
```

Expected:

- `contract_version = pr16.9.7-notification-preferences-ui-v1`
- `notification_ledger_enabled = true`
- `notification_realtime_enabled = true`
- `external_delivery_enabled = false`
- `preferences_enabled = true`
- `preferences_ui_enabled = true`
- `first_preference_scope = connector_runtime/all`
- `critical_always_visible = true`

### Permission Smoke

```sql
select
  has_table_privilege('authenticated', 'puls_app.app_notification_preferences', 'select')
    as authenticated_preferences_select,
  has_table_privilege('authenticated', 'puls_app.app_notification_preferences', 'insert')
    as authenticated_preferences_insert,
  has_function_privilege(
    'authenticated',
    'puls_app.list_app_notification_preferences(TEXT)',
    'execute'
  ) as authenticated_list_preferences_exec,
  has_function_privilege(
    'authenticated',
    'puls_app.upsert_app_notification_preference(TEXT, TEXT, BOOLEAN, TEXT, TIMESTAMPTZ, BOOLEAN)',
    'execute'
  ) as authenticated_upsert_preferences_exec,
  has_function_privilege(
    'authenticated',
    'puls_app.clear_app_notification_preference(TEXT, TEXT)',
    'execute'
  ) as authenticated_clear_preferences_exec;
```

Expected:

- table select/insert remain `false`
- preference RPC execute privileges are `true`

## Verification

Run:

```bash
scripts/verify-16-9-7-notification-preferences-ui.sh WORKTREE
```

Recommended technical checks:

```bash
supabase db reset
supabase db lint --local --schema puls_app --fail-on error
pnpm test -- src/lib/data/app/notifications.test.ts
pnpm check-i18n
pnpm typecheck
pnpm build
```

Browser smoke:

- `/erp` loads for an authenticated user.
- Notification bell opens.
- Settings action opens notification preferences.
- Saving ERP connection preferences updates the inbox through RPCs.
- Reset returns the source scope to default behavior.
- Critical always-visible copy is present.
- No `406` notification RPC errors appear.
- External delivery remains absent from UI behavior.

## Handoff

PR16.10 can add more app surfaces or producers by reusing:

- `puls_app.app_notifications`,
- `puls_app.app_notification_reads`,
- `puls_app.app_notification_preferences`,
- the Notification Center preference UI source-scope pattern,
- app-wide action routing helpers.

Do not create domain-specific notification systems for future workflow, security, or AI
notification producers.
