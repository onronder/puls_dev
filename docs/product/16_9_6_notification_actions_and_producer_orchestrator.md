# PR16.9.6 Notification Actions And Producer Orchestrator

PR16.9.6 turns the Notification Center from a visible inbox into an operationally usable
app-wide surface. `/erp` remains the first producer/surface, but the action model is
plug-and-play for future app domains.

## Scope

- Adds `puls_app.run_app_notification_producers`.
- Keeps `refresh_connector_app_notifications` dedupe keys unchanged to avoid duplicate
  notifications for already-produced connector evidence.
- Calls the app notification producer orchestrator from the Railway connector worker after
  real connector/runtime jobs complete.
- Adds a frontend notification action resolver:
  - known `/erp` events route to exact workbench tabs and sections,
  - unknown error events do not show a vague review action,
  - error notifications can be exported as safe CSV for support sharing.
- Adds `/erp` search deep-link support:
  - `tab`
  - `focus`
- Updates notification copy from internal connector vocabulary to user-friendly language.

## Product Behavior

The detail footer no longer has a generic no-op `Review` action:

- Known ERP events show `Sürece git` / `Go to process`.
- Errors also show `Hatayı paylaş` / `Share issue`.
- Unknown ERP error events show only the CSV issue export plus dismiss.

Current exact ERP targets:

| Source event | Route |
| --- | --- |
| `connector_job_failed` | `/erp?tab=activity&focus=erp-runtime-queue` |
| `connector_job_dead_letter` | `/erp?tab=activity&focus=erp-runtime-queue` |
| `runtime_preflight_failed` | `/erp?tab=activity&focus=erp-runtime-queue` |
| `import_apply_create_only_completed` | `/erp?tab=previewApply&focus=erp-controlled-apply` |
| `import_apply_guarded_update_completed` | `/erp?tab=previewApply&focus=erp-controlled-apply` |
| `import_apply_rollback_completed` | `/erp?tab=previewApply&focus=erp-guarded-update-rollback-worker-apply` |
| `import_apply_rollback_preview_ready` | `/erp?tab=previewApply&focus=erp-guarded-update-rollback-preview` |
| `import_apply_rollback_approval_recorded` | `/erp?tab=previewApply&focus=erp-guarded-update-rollback-approval` |
| `import_apply_rollback_worker_ready` | `/erp?tab=previewApply&focus=erp-guarded-update-rollback-worker-readiness` |

## Safety Contract

- `run_app_notification_producers` is service-role only.
- Authenticated users still cannot select/insert/update/delete notification tables directly.
- Worker notification refresh is best-effort and must not fail the source connector job.
- CSV export contains only notification metadata and `safe_summary`.
- No external delivery is opened:
  - no email,
  - no push,
  - no SMS,
  - no Slack.
- No provider API calls, source writeback, credential readback, raw payload readback, field
  value readback, before/after value readback, or snapshot payload readback are introduced.
- DB triggers are intentionally avoided; producer work remains in service-role RPC/worker
  orchestration to avoid coupling source-table transactions to notification fanout.

## Smoke SQL

### Object And Permission Smoke

```sql
select
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'puls_app'
      and p.proname = 'run_app_notification_producers'
  ) as producer_orchestrator_rpc_exists,
  has_function_privilege(
    'authenticated',
    'puls_app.run_app_notification_producers(INTEGER, UUID)',
    'execute'
  ) as authenticated_producer_exec,
  has_function_privilege(
    'service_role',
    'puls_app.run_app_notification_producers(INTEGER, UUID)',
    'execute'
  ) as service_role_producer_exec;
```

Expected:

- `producer_orchestrator_rpc_exists = true`
- `authenticated_producer_exec = false`
- `service_role_producer_exec = true`

### Bootstrap Smoke

```sql
select
  contract_version,
  notification_ledger_enabled,
  notification_realtime_enabled,
  external_delivery_enabled,
  next_action_key,
  safe_summary->>'notification_action_routing_enabled' as action_routing_enabled,
  safe_summary->>'notification_error_csv_export_enabled' as error_csv_export_enabled,
  safe_summary->>'notification_producer_orchestrator_enabled' as producer_orchestrator_enabled,
  safe_summary->>'notification_worker_refresh_enabled' as worker_refresh_enabled
from puls_app.get_notification_center_bootstrap_status();
```

Expected:

- `contract_version = pr16.9.6-notification-action-routing-v1`
- `notification_ledger_enabled = true`
- `notification_realtime_enabled = true`
- `external_delivery_enabled = false`
- `action_routing_enabled = true`
- `error_csv_export_enabled = true`
- `producer_orchestrator_enabled = true`
- `worker_refresh_enabled = true`

### Producer Smoke

Run as service-role:

```sql
select *
from puls_app.run_app_notification_producers(100, null)
order by occurred_at desc
limit 20;
```

Expected:

- rows are idempotent with existing connector notification dedupe behavior,
- `safe_summary` does not include raw payload, credential value, provider response,
  before/after value, or snapshot payload.

## Verification

Run:

```bash
scripts/verify-16-9-6-notification-actions-and-producer-orchestrator.sh WORKTREE
```

Recommended technical checks:

```bash
supabase db reset
supabase db lint --local --schema puls_app --fail-on error
pnpm test -- src/lib/notifications/app-notification-actions.test.ts services/erp-connector/src/worker.test.ts
pnpm check-i18n
pnpm typecheck
pnpm build
```

Browser smoke:

- `/erp` loads for an authenticated user.
- Notification bell opens.
- Known ERP notification detail has `Sürece git`.
- Clicking it opens the correct `/erp` tab and scrolls to the expected section.
- Error notification detail can download safe CSV.
