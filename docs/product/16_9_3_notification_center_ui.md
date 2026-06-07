# PR16.9.3 Notification Center UI

PR16.9.3 opens the first production-grade app-wide Notification Center UI. It follows
[`16_9_app_wide_notification_center_strategy.md`](./16_9_app_wide_notification_center_strategy.md):
the feature is owned by `puls_app`, appears in the global shell, and `/erp` remains the
first source/action surface rather than the notification owner.

## Scope

- Adds cursor-paged `puls_app.list_app_notifications_page`.
- Keeps legacy `list_app_notifications` unchanged.
- Updates `get_notification_center_bootstrap_status()` to `pr16.9.3-notification-center-ui-v1`.
- Adds a typed app notification data adapter that explicitly calls `supabase.schema('puls_app')`.
- Adds the global shell notification bell.
- Adds the notification pane with:
  - unread/action-required badge,
  - all/unread/action-required filters,
  - cursor paging through "load more",
  - loading, empty, error, and end-of-list states,
  - mark all read,
  - mark read on selection,
  - dismiss,
  - detail view inside the pane,
  - explicit action CTA after detail review.
- Adds connector runtime i18n keys for PR16.9.2 producer notifications.

## UI Contract

- Desktop: the bell lives in the app header before sign-out.
- Mobile/Capacitor: the same control opens a safe-area-aware full-height sheet.
- Selecting a notification opens detail inside the pane; it does not navigate immediately.
- The detail CTA navigates only after the user explicitly chooses to review the source.
- Connector runtime notifications route to `/erp`.
- Visible badge count represents unread count only; action-required count stays in
  the accessible label and pane summary.
- Counts and list data are fetched through authenticated RPCs only.
- Realtime is not required for correctness; the UI uses RPC fetch/refetch.

## Safety Contract

- Direct authenticated table access remains closed.
- Browser writes to notification tables remain closed.
- UI never displays raw payloads, provider responses, credential values, field values, or snapshot payloads.
- Detail safe summary is allowlisted to safe ids, counts, states, booleans, and action keys.
- Realtime, push, email, SMS, Slack, and external delivery remain closed.
- No AI autonomous notification action is introduced.
- No `/erp`-local notification array or connector-specific notification model is introduced.

## Capacitor / Mobile Requirements

- Touch targets are at least 44px.
- The sheet respects `env(safe-area-inset-top)` and `env(safe-area-inset-bottom)`.
- Primary actions are available through visible buttons, not hover or gesture-only controls.
- Android/iOS back-stack behavior remains sheet-first because notification detail is inside the sheet.
- Push notification permission, native delivery, and preferences are intentionally deferred.

## Smoke SQL

### Objects And Grants

```sql
select
  exists(
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'puls_app'
      and p.proname = 'list_app_notifications_page'
  ) as page_rpc_exists,
  has_function_privilege(
    'authenticated',
    'puls_app.list_app_notifications_page(INTEGER, TEXT, TEXT, JSONB)',
    'execute'
  ) as authenticated_page_exec,
  has_function_privilege(
    'service_role',
    'puls_app.list_app_notifications_page(INTEGER, TEXT, TEXT, JSONB)',
    'execute'
  ) as service_role_page_exec,
  has_table_privilege('authenticated', 'puls_app.app_notifications', 'select')
    as authenticated_notifications_select,
  has_table_privilege('authenticated', 'puls_app.app_notifications', 'insert')
    as authenticated_notifications_insert;
```

Expected:

- `page_rpc_exists = true`
- `authenticated_page_exec = true`
- `service_role_page_exec = true`
- direct authenticated table privileges remain `false`

### Cursor Page Smoke

Run with an authenticated user that has tenant and employee context:

```sql
select notification_id, source_domain, source_event_key, is_read, page_has_more, next_cursor
from puls_app.list_app_notifications_page(3, 'all', null, null);
```

If `page_has_more = true`, run the next page:

```sql
with first_page as (
  select next_cursor
  from puls_app.list_app_notifications_page(3, 'all', null, null)
  where next_cursor is not null
  limit 1
)
select notification_id, source_domain, source_event_key, is_read, page_has_more, next_cursor
from puls_app.list_app_notifications_page(
  3,
  'all',
  null,
  (select next_cursor from first_page)
);
```

Expected:

- second page does not repeat first-page notification ids,
- dismissed notifications are hidden,
- unread/action-required filters return the expected narrower set.

### Bootstrap Status

```sql
select contract_version, notification_ledger_enabled, notification_realtime_enabled,
       external_delivery_enabled, next_action_key, safe_summary
from puls_app.get_notification_center_bootstrap_status();
```

Expected:

- `contract_version = pr16.9.3-notification-center-ui-v1`
- `notification_ledger_enabled = true`
- `notification_realtime_enabled = false`
- `external_delivery_enabled = false`
- `safe_summary->>'notification_center_ui_enabled' = true`
- `safe_summary->>'notification_cursor_paging_enabled' = true`

## Verification

Run:

```bash
scripts/verify-16-9-3-notification-center-ui.sh WORKTREE
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

Before merge, verify in browser:

- bell is visible in the global header,
- unread/action badge is accessible and does not shift layout,
- pane opens on desktop and mobile widths,
- filters work,
- detail opens inside the pane,
- CTA routes to `/erp` for connector runtime notifications,
- mark read/dismiss persists after refetch,
- loading, empty, and error states are polished.

## Handoff To PR16.9.4

PR16.9.4 can add realtime/poll hybrid delivery if the durable UI is stable.
It must keep DB/RPC as the source of truth and broadcast only minimal notification ids/count hints.
