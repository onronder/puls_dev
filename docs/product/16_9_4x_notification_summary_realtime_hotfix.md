# PR16.9.4x Notification Summary Realtime Hotfix

PR16.9.4x is a narrow follow-up to PR16.9.4 live UI smoke. The Notification Center
pane loaded correctly and no longer returned 406 errors, but the UI stayed in
polling-only mode because `get_app_notification_summary()` still returned
`notification_realtime_enabled = false`.

## Scope

- Replaces only `puls_app.get_app_notification_summary(TEXT)`.
- Aligns summary contract with `pr16.9.4-notification-realtime-fallback-v1`.
- Returns `notification_realtime_enabled = true` so the UI can subscribe to the
  private tenant realtime channel.
- Keeps `external_delivery_enabled = false`.
- Keeps polling/refetch as the correctness path and fallback.
- Leaves notification tables, producer mapping, preferences, and external delivery unchanged.

## Safety Contract

- No direct authenticated table grants are added.
- No browser-originated realtime broadcast path is opened.
- No raw payload, provider response, credential, field value, or snapshot payload readback is added.
- The UI still reads durable state through RPCs after realtime hints.
- Realtime remains optional; failures fall back to polling and manual refresh.

## Smoke SQL

```sql
select set_config('request.jwt.claim.role', 'service_role', false);

select
  safe_summary->>'contract_version' as contract_version,
  notification_ledger_enabled,
  notification_realtime_enabled,
  external_delivery_enabled,
  next_action_key,
  safe_summary->>'notification_polling_fallback_enabled' as polling_fallback,
  safe_summary->>'notification_realtime_private_channel_enabled' as private_channel,
  safe_summary->>'notification_realtime_payload_minimal' as minimal_payload,
  safe_summary->>'realtime_required' as realtime_required
from puls_app.get_app_notification_summary();
```

Expected:

- `contract_version = pr16.9.4-notification-realtime-fallback-v1`
- `notification_ledger_enabled = true`
- `notification_realtime_enabled = true`
- `external_delivery_enabled = false`
- `next_action_key = plan_notification_preferences_pr16_9_5`
- `polling_fallback = true`
- `private_channel = true`
- `minimal_payload = true`
- `realtime_required = false`

## Browser Smoke

- `/erp` loads without login redirect for an authenticated user.
- Notification bell opens the pane.
- The pane does not show `Bildirimler yüklenemedi`.
- The pane shows either live, connecting, or fallback realtime status instead of being
  permanently polling-disabled.
- Manual refresh and filters still work.
- Console has no notification RPC 406 errors.

## Handoff

After this hotfix, PR16.9.5 can start notification preferences with the summary and
bootstrap contracts aligned.
