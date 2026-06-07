# PR16.9.4 Notification Realtime Fallback

PR16.9.4 adds optional realtime hints to the app-wide Notification Center without making
realtime the correctness path. It follows
[`16_9_app_wide_notification_center_strategy.md`](./16_9_app_wide_notification_center_strategy.md):
`puls_app` remains the owner, `/erp` remains only the first producer/action surface, and
the UI still reads durable state through authenticated RPCs.

## Scope

- Adds deterministic private tenant topics for Notification Center broadcasts.
- Adds a service-triggered `app_notifications` insert broadcast hint.
- Adds a `realtime.messages` RLS policy so authenticated clients can join only their own
  tenant Notification Center topic.
- Updates `get_notification_center_bootstrap_status()` to
  `pr16.9.4-notification-realtime-fallback-v1`.
- Adds a typed frontend subscription helper.
- Refetches summary/page RPCs when a valid realtime hint arrives.
- Keeps polling as the fallback and correctness path.
- Adds compact live/fallback status copy inside the notification pane.

## Safety Contract

- Direct authenticated table access remains closed for `puls_app.app_notifications` and
  `puls_app.app_notification_reads`.
- Authenticated clients receive broadcast read authorization only for their own tenant topic.
- PR16.9.4 adds no authenticated `INSERT` policy on `realtime.messages`; browser-originated
  notification broadcasts remain closed by RLS.
- Broadcast payloads contain only:
  - `notification_id`
  - `source_domain`
  - `source_event_key`
  - `severity`
  - `occurred_at`
  - `count_hint`
- Broadcast payloads must not contain `safe_summary`, raw payloads, provider responses,
  credentials, before/after values, field values, or snapshot payloads.
- Realtime, if unavailable, degrades to polling without blocking notification reads.
- External delivery, email, push, SMS, Slack, provider fanout, and notification preferences
  remain deferred.
- No AI autonomous notification action is introduced.

## UI Contract

- The bell and notification pane stay global shell components.
- Realtime status is presented as a small operational status line, not as a blocking alert.
- When realtime is connected, incoming safe hints invalidate the notification summary and
  current page cache; the UI then refetches through RPCs.
- When realtime is disabled, connecting, timed out, closed, or errored, the UI continues
  polling and manual refresh still works.
- Mobile/Capacitor behavior is unchanged: full-height sheet, safe-area padding, visible
  buttons, and no hover-only controls.

## Smoke SQL

### Objects, Trigger, And Policy

```sql
select
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'puls_app'
      and p.proname = 'app_notification_realtime_topic'
  ) as topic_rpc_exists,
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'puls_app'
      and p.proname = 'broadcast_app_notification_hint'
  ) as broadcast_trigger_rpc_exists,
  exists (
    select 1
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'puls_app'
      and c.relname = 'app_notifications'
      and t.tgname = 'puls_app_app_notifications_realtime_hint'
      and not t.tgisinternal
  ) as realtime_trigger_exists,
  exists (
    select 1
    from pg_policies
    where schemaname = 'realtime'
      and tablename = 'messages'
      and policyname = 'puls_app_notification_broadcast_select'
      and cmd = 'SELECT'
  ) as realtime_policy_exists;
```

Expected: all booleans are `true`.

### Tenant Topic Policy Smoke

```sql
select
  puls_app.app_notification_realtime_topic('a0000001-0001-4001-8001-000000000001'::uuid)
    as tenant_topic,
  pg_get_expr(pol.polqual, pol.polrelid) like '%realtime.topic()%'
    as uses_realtime_topic,
  pg_get_expr(pol.polqual, pol.polrelid) like '%puls_core.current_tenant_id()%'
    as uses_current_tenant,
  pg_get_expr(pol.polqual, pol.polrelid) like '%broadcast%'
    as broadcast_only
from pg_policy pol
join pg_class cls on cls.oid = pol.polrelid
join pg_namespace ns on ns.oid = cls.relnamespace
where ns.nspname = 'realtime'
  and cls.relname = 'messages'
  and pol.polname = 'puls_app_notification_broadcast_select';
```

Expected:

- `tenant_topic` starts with `puls_app:notification-center:tenant:`
- `uses_realtime_topic = true`
- `uses_current_tenant = true`
- `broadcast_only = true`

### Minimal Payload Contract

```sql
with fn as (
  select pg_get_functiondef('puls_app.broadcast_app_notification_hint()'::regprocedure) as body
)
select
  body like '%realtime.send%' as uses_realtime_send,
  body like '%app_notification_hint%' as emits_hint_event,
  body like '%notification_id%' as includes_notification_id,
  body like '%source_domain%' as includes_source_domain,
  body like '%source_event_key%' as includes_source_event_key,
  body like '%count_hint%' as includes_count_hint,
  body not like '%safe_summary%' as excludes_safe_summary,
  body not like '%raw_payload%' as excludes_raw_payload,
  body not like '%provider_response%' as excludes_provider_response,
  body not like '%credential_value%' as excludes_credential_value,
  body not like '%before_value%' as excludes_before_value,
  body not like '%after_value%' as excludes_after_value,
  body not like '%snapshot_payload%' as excludes_snapshot_payload
from fn;
```

Expected: all booleans are `true`.

### Bootstrap Status

```sql
select contract_version,
       notification_ledger_enabled,
       notification_realtime_enabled,
       external_delivery_enabled,
       next_action_key,
       safe_summary
from puls_app.get_notification_center_bootstrap_status();
```

Expected:

- `contract_version = pr16.9.4-notification-realtime-fallback-v1`
- `notification_ledger_enabled = true`
- `notification_realtime_enabled = true`
- `external_delivery_enabled = false`
- `safe_summary->>'notification_polling_fallback_enabled' = true`
- `safe_summary->>'notification_realtime_private_channel_enabled' = true`
- `safe_summary->>'notification_realtime_payload_minimal' = true`
- `safe_summary->>'realtime_required' = false`

## Verification

Run:

```bash
scripts/verify-16-9-4-notification-realtime-fallback.sh WORKTREE
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

- bell still renders in the global header,
- pane opens at desktop and mobile widths,
- realtime status says live when the private channel subscribes,
- if realtime fails, status switches to auto-refreshing/fallback and the list still loads,
- manual refresh still works,
- a producer-created notification appears after the broadcast hint without a page reload,
- no console errors from notification RPCs or realtime subscription cleanup.

## Handoff To PR16.9.5

PR16.9.5 can plan notification preferences and delivery settings. It must not add email,
push, SMS, Slack, or provider fanout until the app-wide inbox and realtime fallback have
passed remote smoke with no tenant leakage.
