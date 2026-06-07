# PR16.9.5 Notification Scenario Coverage

PR16.9.5 makes the app-wide Notification Center testable across the important in-app
scenarios before any external delivery is opened. It adds per-employee in-app preferences,
applies those preferences to summary/list/bulk-read RPCs, and exposes a read-only scenario
contract RPC for smoke coverage.

## Scope

- Creates `puls_app.app_notification_preferences`.
- Adds current-employee RPCs:
  - `list_app_notification_preferences`
  - `upsert_app_notification_preference`
  - `clear_app_notification_preference`
- Adds `list_app_notification_scenario_contracts`.
- Applies preferences to:
  - `list_app_notifications_page`
  - `get_app_notification_summary`
  - `mark_all_app_notifications_read`
- Keeps critical notifications always visible in the in-app inbox.
- Updates bootstrap and summary contracts to
  `pr16.9.5-notification-scenario-coverage-v1`.

## Safety Contract

- Direct authenticated table access remains closed for:
  - `puls_app.app_notifications`
  - `puls_app.app_notification_reads`
  - `puls_app.app_notification_preferences`
- Preference mutation is current-employee scoped through RPC only.
- Realtime remains optional and still refetches durable RPC state.
- External delivery remains closed:
  - no email,
  - no push,
  - no SMS,
  - no Slack,
  - no provider fanout.
- No raw payload, provider response, credential, field value, before/after value, or
  snapshot payload readback is introduced.
- Preference muting never hides `critical` notifications.

## Scenarios Covered

- Empty inbox.
- Service-role safe notification emission.
- Dedupe by tenant/dedupe key.
- Role visibility.
- Employee target visibility.
- Cursor paging.
- Unread filter.
- Action-required filter.
- Per-employee read state.
- Per-employee dismiss state.
- Mark-all-read with preference-aware visibility.
- Source/event preference mute.
- Minimum severity preference.
- Critical always visible despite mute.
- Minimal realtime hint contract.
- Safe summary blocked-key guard.
- External delivery closed.

## Smoke SQL

### Object And Permission Smoke

```sql
select
  to_regclass('puls_app.app_notification_preferences') is not null as preferences_table_exists,
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'puls_app'
      and p.proname = 'list_app_notification_preferences'
  ) as list_preferences_rpc_exists,
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'puls_app'
      and p.proname = 'upsert_app_notification_preference'
  ) as upsert_preference_rpc_exists,
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'puls_app'
      and p.proname = 'clear_app_notification_preference'
  ) as clear_preference_rpc_exists,
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'puls_app'
      and p.proname = 'list_app_notification_scenario_contracts'
  ) as scenario_contract_rpc_exists,
  has_table_privilege('authenticated', 'puls_app.app_notification_preferences', 'select')
    as authenticated_preferences_select,
  has_table_privilege('authenticated', 'puls_app.app_notification_preferences', 'insert')
    as authenticated_preferences_insert,
  has_function_privilege(
    'authenticated',
    'puls_app.upsert_app_notification_preference(TEXT, TEXT, BOOLEAN, TEXT, TIMESTAMPTZ, BOOLEAN)',
    'execute'
  ) as authenticated_upsert_preference_exec;
```

Expected:

- all `*_exists = true`
- `authenticated_preferences_select = false`
- `authenticated_preferences_insert = false`
- `authenticated_upsert_preference_exec = true`

### Bootstrap And Contract Smoke

```sql
select
  contract_version,
  notification_ledger_enabled,
  notification_realtime_enabled,
  external_delivery_enabled,
  next_action_key,
  safe_summary->>'notification_preferences_enabled' as preferences_enabled,
  safe_summary->>'notification_scenario_contracts_enabled' as scenario_contracts_enabled,
  safe_summary->>'critical_notifications_always_visible' as critical_always_visible
from puls_app.get_notification_center_bootstrap_status();
```

Expected:

- `contract_version = pr16.9.5-notification-scenario-coverage-v1`
- `notification_ledger_enabled = true`
- `notification_realtime_enabled = true`
- `external_delivery_enabled = false`
- `preferences_enabled = true`
- `scenario_contracts_enabled = true`
- `critical_always_visible = true`

### Scenario Contract Smoke

```sql
select
  scenario_key,
  scenario_status,
  notification_preferences_enabled,
  notification_realtime_enabled,
  external_delivery_enabled,
  safe_summary
from puls_app.list_app_notification_scenario_contracts()
order by scenario_key;
```

Expected:

- includes `empty_inbox`, `service_role_emit`, `dedupe`, `role_visibility`,
  `employee_target`, `cursor_paging`, `unread_filter`, `action_required_filter`,
  `read_state`, `dismiss_state`, `mark_all_read`, `preference_mute`,
  `preference_minimum_severity`, `critical_always_visible`, `realtime_hint`,
  `safe_summary_guard`, and `external_delivery_closed`.
- every row has `scenario_status = ready`.
- every row has `external_delivery_enabled = false`.

### Preference Behavior Smoke

Use a real tenant/employee context. The exact IDs can be selected from seeded/local data or
from the authenticated user session.

```sql
select set_config('request.jwt.claim.role', 'authenticated', false);
select set_config('request.jwt.claim.tenant_id', '<tenant-id>', false);
select set_config('request.jwt.claim.employee_id', '<employee-id>', false);

select *
from puls_app.upsert_app_notification_preference(
  'connector_runtime',
  'all',
  false,
  'info',
  now() + interval '1 hour',
  false
);

select *
from puls_app.list_app_notification_preferences('connector_runtime');

select *
from puls_app.clear_app_notification_preference('connector_runtime', 'all');
```

Expected:

- upsert returns the current employee preference,
- list returns the scope,
- clear returns `deleted_count = 1`.

## Verification

Run:

```bash
scripts/verify-16-9-5-notification-scenario-coverage.sh WORKTREE
```

Recommended technical checks:

```bash
supabase db reset
supabase db lint --local --schema puls_app --fail-on error
supabase db lint --local --fail-on error
pnpm test -- src/lib/data/app/notifications.test.ts
pnpm typecheck
pnpm build
```

Browser smoke:

- `/erp` loads for an authenticated user.
- Notification bell opens.
- The pane shows live or safe fallback realtime status.
- Refresh/filter/read/dismiss/detail flows still work.
- No `406` notification RPC errors appear.
- External delivery remains absent from UI behavior.

## Handoff

PR16.9.6 can plan external/native delivery only after PR16.9.5 smoke passes on remote.
External delivery must still be opt-in, auditable, and separated from the durable inbox.
