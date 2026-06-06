# PR16.9.2 Connector Notification Producers

PR16.9.2 maps selected connector/runtime evidence into the app-wide Notification Center ledger.

This PR follows [`16_9_app_wide_notification_center_strategy.md`](./16_9_app_wide_notification_center_strategy.md) and reuses the PR16.9.1 ledger. It does not create another notification system, another ledger, an `/erp`-owned notification model, realtime delivery, or external delivery.

## Scope

- Adds `puls_app.refresh_connector_app_notifications`.
- Keeps notification ownership in `puls_app`.
- Uses `puls_app.emit_app_notification` as the only write boundary.
- Maps selected `connector_runtime` source events:
  - `connector_job_failed`
  - `connector_job_dead_letter`
  - `runtime_preflight_failed`
  - `import_apply_create_only_completed`
  - `import_apply_guarded_update_completed`
  - `import_apply_rollback_completed`
  - `import_apply_rollback_preview_ready`
  - `import_apply_rollback_approval_recorded`
  - `import_apply_rollback_worker_ready`
- Updates `get_notification_center_bootstrap_status()` so producer mapping readiness is visible.
- Keeps UI, realtime, preferences, external delivery, email, push, AI autonomous action, and Railway fanout closed.

## Safety Contract

- Contract version is `pr16.9.2-connector-notification-producer-v1`.
- `refresh_connector_app_notifications` is service-role only.
- Browser users cannot emit or refresh producer notifications.
- Authenticated users still read/mutate notification state only through PR16.9.1 list/summary/read/dismiss RPCs.
- Producer refresh is idempotent through tenant-scoped deterministic dedupe keys.
- Re-running refresh for the same connector evidence does not duplicate notifications.
- Routine success, heartbeat, polling, and low-value background activity are not mapped.
- Safe summaries contain ids, counts, statuses, safe error codes, action keys, booleans, and contract flags only.
- Safe summaries do not copy `safe_error_context`.
- Safe summaries do not contain credential values, provider responses, raw import payloads, raw snapshot payloads, field values, source field values, or rollback field values.
- Realtime and external delivery flags remain false.

## Producer Mapping

| Source evidence | Notification event | Severity | Action posture |
| --- | --- | --- | --- |
| `connector_jobs.status = failed` | `connector_job_failed` | warning/error/critical from safe severity | action required |
| `connector_jobs.status = dead_letter` | `connector_job_dead_letter` | critical | action required |
| failed `connector_runtime_preflight` job | `runtime_preflight_failed` | warning/error/critical from safe severity | action required |
| `connector_apply_object_events.operation = insert` | `import_apply_create_only_completed` | success | informational workflow completion |
| `connector_apply_object_events.operation = update` | `import_apply_guarded_update_completed` | success | informational workflow completion |
| `connector_apply_object_events.operation = rollback` | `import_apply_rollback_completed` | success | high-value workflow completion |
| ready rollback preview | `import_apply_rollback_preview_ready` | warning | review required |
| rollback approval recorded | `import_apply_rollback_approval_recorded` | warning | next rollback handoff step |
| rollback worker readiness | `import_apply_rollback_worker_ready` | warning | worker handoff step |

Route hints remain app-domain hints such as `connector_runtime.jobs`, `connector_runtime.apply`, and `connector_runtime.rollback`. They are not URL-hardcoded to `/erp`; PR16.9.3 can decide how the first `/erp` surface resolves them.

## Access Model

Tables:

- No new tables are created.
- Direct authenticated access to `app_notifications` and `app_notification_reads` remains unchanged and closed.

Functions:

- `refresh_connector_app_notifications`: `service_role` only.
- `emit_app_notification`: unchanged, `service_role` only.
- List/summary/read/dismiss RPCs: unchanged, authenticated and service-role.

## Smoke SQL

### Objects And Grants

```sql
select
  exists(
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'puls_app'
      and p.proname = 'refresh_connector_app_notifications'
  ) as refresh_rpc_exists,
  has_function_privilege(
    'authenticated',
    'puls_app.refresh_connector_app_notifications(INTEGER, UUID, TEXT)',
    'execute'
  ) as authenticated_refresh_exec,
  has_function_privilege(
    'service_role',
    'puls_app.refresh_connector_app_notifications(INTEGER, UUID, TEXT)',
    'execute'
  ) as service_role_refresh_exec;
```

Expected:

- `refresh_rpc_exists = true`
- `authenticated_refresh_exec = false`
- `service_role_refresh_exec = true`

### Functional Producer Smoke

Run inside a transaction and roll it back. The smoke should create one safe failed connector job and one rollback object event, then call:

```sql
select set_config('request.jwt.claim.role', 'service_role', true);

create temp table first_refresh as
select *
from puls_app.refresh_connector_app_notifications(
  20,
  '<tenant-id>'::uuid,
  null
);

create temp table second_refresh as
select *
from puls_app.refresh_connector_app_notifications(
  20,
  '<tenant-id>'::uuid,
  null
);
```

Expected:

- first refresh emits exactly one `connector_job_failed` notification for the failed job,
- first refresh emits exactly one `import_apply_rollback_completed` notification for the rollback object event,
- second refresh returns the same candidates with `inserted = false`,
- `puls_app._app_notification_safe_summary_has_blocked_key(safe_summary)` is false for emitted rows,
- `external_delivery_enabled` and `notification_realtime_enabled` remain false,
- authenticated execution of `refresh_connector_app_notifications` raises `PULS_APP_CONNECTOR_NOTIFICATION_REFRESH_SERVICE_ROLE_REQUIRED`.

## Verification

Run:

```bash
scripts/verify-16-9-2-connector-notification-producers.sh WORKTREE
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

Then run the smoke SQL above with real or transactional connector evidence.

## Handoff To PR16.9.3

PR16.9.3 should build the reusable app-wide Notification Center UI and use the existing RPCs:

- `list_app_notifications`
- `get_app_notification_summary`
- `mark_app_notification_read`
- `mark_all_app_notifications_read`
- `dismiss_app_notification`

It should not create another ledger or write notifications directly from the browser. It should render real `connector_runtime` notifications first, while keeping the UI component names and data adapter app-wide.
