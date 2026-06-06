# PR16.9.1 Durable Notification Ledger

PR16.9.1 creates the durable app-wide Notification Center source of truth under `puls_app`.

This PR follows [`16_9_app_wide_notification_center_strategy.md`](./16_9_app_wide_notification_center_strategy.md) and keeps Notification Center app-wide. `/erp` remains the first planned producer/consumer surface, but no `/erp`-specific notification model is introduced here.

## Scope

- Creates `puls_app.app_notifications`.
- Creates `puls_app.app_notification_reads`.
- Adds immutable notification header protection.
- Adds per-employee read/dismiss state.
- Adds authenticated RPCs:
  - `list_app_notifications`
  - `get_app_notification_summary`
  - `mark_app_notification_read`
  - `mark_all_app_notifications_read`
  - `dismiss_app_notification`
- Adds service-role-only `emit_app_notification`.
- Updates `get_notification_center_bootstrap_status()` so ledger readiness is visible.
- Keeps direct authenticated table access closed.
- Keeps realtime, external delivery, email, push, AI autonomous action, and producer mapping closed.

## Safety Contract

- Contract version is `pr16.9.1-app-notification-ledger-v1`.
- Notification rows are tenant-scoped and deduped by `(tenant_id, dedupe_key)`.
- Service-role emit is idempotent; replaying a source event does not create duplicates.
- Browser users do not insert/update/delete notification tables directly.
- Authenticated users read and mutate only through RPCs.
- Authenticated RPCs resolve tenant, employee, role, and admin state server-side.
- Cross-tenant notification reads are denied.
- Role visibility uses `target_roles`, `target_employee_ids`, current persona role, and admin status.
- Safe summaries reject blocked sensitive keys.
- Safe summaries may contain safe booleans/counts/ids/state labels/action keys only.
- No credential value, provider response, raw import payload, raw snapshot payload, source field value, or rollback field value is stored or returned.

## Ledger Shape

`puls_app.app_notifications` stores:

- source metadata,
- severity and priority,
- role/employee targets,
- subject/action/route hints,
- i18n title/body keys,
- dedupe key,
- safe summary,
- occurrence and expiry timestamps.

`puls_app.app_notification_reads` stores:

- `notification_id`,
- `employee_id`,
- `read_at`,
- `dismissed_at`.

Read/dismiss state is intentionally per employee.

## Access Model

Tables:

- `authenticated`: no direct table privileges.
- `anon`: no schema/table/function access.
- `service_role`: table access for controlled emit/read-state operations and smoke verification.

Functions:

- `emit_app_notification`: `service_role` only.
- List/summary/read/dismiss RPCs: `authenticated` and `service_role`.
- Internal helpers: closed to `anon` and `authenticated`.

## Smoke SQL

### Objects And Grants

```sql
select
  to_regclass('puls_app.app_notifications') is not null as notifications_table_exists,
  to_regclass('puls_app.app_notification_reads') is not null as reads_table_exists,
  exists(
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'puls_app'
      and p.proname = 'emit_app_notification'
  ) as emit_rpc_exists,
  exists(
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'puls_app'
      and p.proname = 'list_app_notifications'
  ) as list_rpc_exists;
```

Expected: all `true`.

```sql
select
  has_table_privilege('authenticated', 'puls_app.app_notifications', 'select') as authenticated_notifications_select,
  has_table_privilege('authenticated', 'puls_app.app_notifications', 'insert') as authenticated_notifications_insert,
  has_table_privilege('authenticated', 'puls_app.app_notification_reads', 'insert') as authenticated_reads_insert,
  has_function_privilege(
    'authenticated',
    'puls_app.emit_app_notification(UUID, TEXT, TEXT, TEXT, TEXT, UUID, TEXT, INTEGER, TEXT[], UUID[], TEXT, UUID, TEXT, TEXT, TEXT, TEXT, JSONB, TIMESTAMPTZ, TIMESTAMPTZ)',
    'execute'
  ) as authenticated_emit_exec,
  has_function_privilege(
    'service_role',
    'puls_app.emit_app_notification(UUID, TEXT, TEXT, TEXT, TEXT, UUID, TEXT, INTEGER, TEXT[], UUID[], TEXT, UUID, TEXT, TEXT, TEXT, TEXT, JSONB, TIMESTAMPTZ, TIMESTAMPTZ)',
    'execute'
  ) as service_role_emit_exec;
```

Expected:

- authenticated table privileges are `false`,
- authenticated emit is `false`,
- service-role emit is `true`.

### Service-Role Idempotent Emit

```sql
select set_config('request.jwt.claim.role', 'service_role', true);

select *
from puls_app.emit_app_notification(
  p_tenant_id := '<tenant-id>',
  p_source_domain := 'connector_runtime',
  p_source_event_key := 'smoke_notification_ready',
  p_title_key := 'notifications.connector.smoke.title',
  p_severity := 'warning',
  p_priority := 80,
  p_target_roles := array['admin']::text[],
  p_action_key := 'review_smoke_notification',
  p_dedupe_key := 'pr16.9.1-smoke-dedupe',
  p_safe_summary := jsonb_build_object(
    'contract_version', 'pr16.9.1-app-notification-ledger-v1',
    'raw_payload_readback', false,
    'credential_readback', false,
    'field_value_readback', false
  )
);
```

Expected first call: `inserted = true`.

Run the same call again.

Expected second call:

- `inserted = false`,
- only one row exists for the dedupe key.

### Authenticated Read State

With an authenticated user that belongs to the target tenant:

```sql
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '<auth-user-id>', true);

select notification_id, is_read, is_dismissed, is_action_required
from puls_app.list_app_notifications(10, true, false, null, null, null);

select notification_id, is_read, is_dismissed
from puls_app.mark_app_notification_read('<notification-id>');

select visible_count, unread_count, action_required_count
from puls_app.get_app_notification_summary(null);

select notification_id, is_read, is_dismissed
from puls_app.dismiss_app_notification('<notification-id>');
```

Expected:

- list returns only visible tenant/role notifications,
- mark-read sets `is_read = true`,
- dismiss sets `is_dismissed = true`,
- dismissed rows disappear from default list/visible count.

### Cross-Tenant Denial

With an authenticated user from another tenant:

```sql
select set_config('request.jwt.claim.sub', '<other-tenant-auth-user-id>', true);

select count(*) as cross_tenant_visible_count
from puls_app.list_app_notifications(10, true, false, null, null, null);
```

Expected: `cross_tenant_visible_count = 0`.

### Safe Summary Rejection

```sql
select set_config('request.jwt.claim.role', 'service_role', true);

select *
from puls_app.emit_app_notification(
  p_tenant_id := '<tenant-id>',
  p_source_domain := 'connector_runtime',
  p_source_event_key := 'unsafe_summary_smoke',
  p_title_key := 'notifications.connector.unsafe.title',
  p_dedupe_key := 'pr16.9.1-unsafe-summary-smoke',
  p_safe_summary := jsonb_build_object('raw_payload', jsonb_build_object('secret', 'blocked'))
);
```

Expected: raises `PULS_APP_NOTIFICATION_SAFE_SUMMARY_BLOCKED_KEY`.

## Verification

Run:

```bash
scripts/verify-16-9-1-durable-notification-ledger.sh WORKTREE
supabase db reset
supabase db lint --local --schema puls_app --fail-on error
supabase db lint --local --fail-on error
git diff --check
supabase db push --dry-run
```

After remote migration:

```sql
notify pgrst, 'reload schema';
```

Then run the smoke SQL above.

## Handoff To PR16.9.2

PR16.9.2 can map selected connector/runtime events into app notifications through the service-role producer boundary.

It should not create another notification ledger. It should call `emit_app_notification` or a narrow producer refresh RPC and prove:

- selected PR16 connector events emit one notification,
- repeated refresh does not duplicate notifications,
- payloads remain safe-summary only,
- route/action hints are app-wide and not `/erp`-hardcoded where a generic app route is more appropriate.
