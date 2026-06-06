# PR16.9.0 puls_app Bootstrap And Exposure Smoke

PR16.9.0 creates the application-wide `puls_app` schema and proves that Supabase/PostgREST can safely expose it before any Notification Center ledger, UI, realtime, or delivery behavior is added.

This PR intentionally follows [`16_9_app_wide_notification_center_strategy.md`](./16_9_app_wide_notification_center_strategy.md). It is the stop-condition gate for all later PR16.9 notification work.

## Scope

- Adds `puls_app` as the app experience schema.
- Adds `puls_app.get_notification_center_bootstrap_status()` as a minimal authenticated/service-role smoke RPC.
- Grants `puls_app` schema usage only to `authenticated` and `service_role`.
- Keeps public/anon execution closed.
- Adds `puls_app` to local Supabase API exposed schemas in `supabase/config.toml`.
- Emits a PostgREST schema-cache reload notification after the migration.
- Adds a verify script that checks the bootstrap contract and guards against accidental ledger/UI/realtime scope creep.

## Safety Contract

- Contract version is `pr16.9.0-puls-app-bootstrap-v1`.
- No `puls_app.app_notifications` table exists in this PR.
- No `puls_app.app_notification_reads` table exists in this PR.
- No browser direct notification table writes exist.
- No realtime channel, publication, trigger, or external delivery provider exists.
- No ERP/source writeback, provider API call, credential readback, raw payload readback, field value readback, or snapshot payload readback is opened.
- Authenticated callers need tenant context to run the smoke RPC.
- Service-role callers can run the smoke RPC without tenant context for deployment verification.

## Remote Operator Requirement

`supabase db push` creates the database schema and RPC. It does not by itself guarantee that the remote Supabase Data API is configured to expose `puls_app`.

Before remote API smoke for PR16.9.0, the Supabase project API exposed schema list must include:

- `puls_app`

Local development is aligned by `supabase/config.toml`. Remote development must be checked in Supabase project settings or equivalent project configuration. If RPCs exist in SQL but are not visible through the API, treat it as schema exposure or PostgREST cache drift before debugging product code.

## Smoke SQL

### Schema And RPC Existence

```sql
select
  exists(select 1 from pg_namespace where nspname = 'puls_app') as app_schema_exists,
  exists(
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'puls_app'
      and p.proname = 'get_notification_center_bootstrap_status'
  ) as bootstrap_rpc_exists,
  exists(
    select 1
    from information_schema.tables
    where table_schema = 'puls_app'
      and table_name in ('app_notifications', 'app_notification_reads')
  ) as notification_tables_exist;
```

Expected:

- `app_schema_exists = true`
- `bootstrap_rpc_exists = true`
- `notification_tables_exist = false`

### Grants

```sql
select
  has_schema_privilege('anon', 'puls_app', 'usage') as anon_schema_usage,
  has_schema_privilege('authenticated', 'puls_app', 'usage') as authenticated_schema_usage,
  has_schema_privilege('service_role', 'puls_app', 'usage') as service_role_schema_usage,
  has_function_privilege('anon', 'puls_app.get_notification_center_bootstrap_status()', 'execute') as anon_exec,
  has_function_privilege('authenticated', 'puls_app.get_notification_center_bootstrap_status()', 'execute') as authenticated_exec,
  has_function_privilege('service_role', 'puls_app.get_notification_center_bootstrap_status()', 'execute') as service_role_exec;
```

Expected:

- `anon_schema_usage = false`
- `authenticated_schema_usage = true`
- `service_role_schema_usage = true`
- `anon_exec = false`
- `authenticated_exec = true`
- `service_role_exec = true`

### Service-Role Smoke

```sql
select set_config('request.jwt.claim.role', 'service_role', true);

select
  contract_version,
  schema_name,
  auth_role,
  app_schema_available,
  notification_ledger_enabled,
  notification_realtime_enabled,
  external_delivery_enabled,
  next_action_key,
  safe_summary
from puls_app.get_notification_center_bootstrap_status();
```

Expected:

- `contract_version = pr16.9.0-puls-app-bootstrap-v1`
- `schema_name = puls_app`
- `auth_role = service_role`
- `app_schema_available = true`
- `notification_ledger_enabled = false`
- `notification_realtime_enabled = false`
- `external_delivery_enabled = false`
- `next_action_key = implement_notification_ledger_pr16_9_1`
- `safe_summary` contains only safe booleans/labels and no payload, credential, provider response, or field value.

### Authenticated Caller Without Tenant

```sql
select set_config('request.jwt.claim.role', 'authenticated', true);
select * from puls_app.get_notification_center_bootstrap_status();
```

Expected:

- raises `PULS_APP_NOTIFICATION_BOOTSTRAP_TENANT_REQUIRED`

## Verification

Run:

```bash
scripts/verify-16-9-0-puls-app-bootstrap.sh WORKTREE
git diff --check
supabase db push --dry-run
```

After remote migration:

```sql
notify pgrst, 'reload schema';
```

Then run the smoke SQL above.

## Handoff To PR16.9.1

Only after PR16.9.0 passes local and remote smoke should PR16.9.1 create the durable notification ledger:

- `puls_app.app_notifications`
- `puls_app.app_notification_reads`
- list/summary/read/dismiss RPCs
- service-role idempotent emit RPC

If `puls_app` API exposure or cache reload is not stable, do not proceed to ledger or UI work.
