# PR16.9 App-Wide Notification Center Strategy

Date: 6 June 2026

## Purpose

PR16.9 must turn notifications into an application-wide capability, not an `/erp` feature. `/erp` is the first producer and first visible product surface because PR16.1-PR16.8 created the strongest operational event stream there, but the Notification Center must be usable later by workflow, approvals, security, AI recommendations, billing, profile/setup, and any future connector.

This document is the PR16.9 follow-up contract. It defines the development discipline, schema decision, risk mitigations, forbidden shortcuts, sub-phase order, and production-grade strategy before implementation starts.

## Scope Decision

Use a dedicated application schema:

- `puls_app`

The long-term domain boundary is cleaner than placing app-wide notification objects in `puls_core` or `puls_integration`.

`puls_core` remains the canonical HR/company data domain. `puls_integration` remains connector/runtime domain. `puls_app` becomes the app experience domain for notification inbox, delivery preferences, user-visible app events, and future app-level surfaces.

## Why puls_app

| Reason | Decision impact |
| --- | --- |
| App-wide ownership | Notifications are not connector-specific and should not live under `puls_integration`. |
| Future capability growth | Preferences, delivery channels, inbox state, app announcements, and AI recommendation notices can share one app domain. |
| Cleaner product language | Producers emit app notifications; consumers read an app inbox. The producer source remains metadata, not schema ownership. |
| Lower long-term coupling | Canias, CSV, workflow, security, and AI can all become producers without touching connector-specific tables. |
| Better retention policy boundary | App notifications can have their own retention, archive, and read-state rules. |

## Known Risks And Mitigations

| Risk | Why it matters | Mitigation |
| --- | --- | --- |
| Schema exposure drift | A migration can succeed while PostgREST cannot serve `puls_app` RPCs or tables. | Add a PR16.9.0 bootstrap phase that exposes `puls_app`, verifies local config, verifies remote API visibility, and runs schema-cache smoke before any product logic. |
| PostgREST schema cache lag | New RPCs can return cache-related errors until PostgREST reloads. | Include `NOTIFY pgrst, 'reload schema'` in smoke guidance and verify RPC discovery after `supabase db push`. Treat repeated `PGRST202` as a schema-cache/profile issue first. |
| Wrong schema selected in client | Supabase defaults can call the wrong schema if the app does not explicitly select `puls_app`. | Client adapters must call `supabase.schema('puls_app').rpc(...)` for notification RPCs. No implicit default schema usage. |
| Overexposed tables | App notifications may contain operational metadata and role targeting. | Authenticated direct table insert/update/delete stays closed. Authenticated reads go through RPC only unless a later PR proves direct RLS table reads are safer. |
| RLS mistake | App-wide inbox must never leak cross-tenant or cross-role notifications. | Every notification RPC derives tenant and employee context server-side. Smoke must prove cross-tenant denial, role visibility, and no tenant context failure behavior. |
| SECURITY DEFINER search path bugs | New schema plus helper functions can accidentally resolve objects from unsafe schemas. | Every SECURITY DEFINER function sets `search_path = pg_catalog, puls_app, puls_core, puls_integration` only as needed. Avoid unqualified cross-schema references. |
| Payload leakage | Notifications are user-facing and can be copied into AI context later. | Notification payloads store safe summaries only: no credential values, provider responses, raw import payload, raw snapshot payload, field values, or personal data beyond safe labels. |
| Duplicate spam | Runtime events can be retried or replayed. | Use tenant-scoped deterministic `dedupe_key` plus idempotent emit/refresh RPCs. Replayed producer events must not create duplicate notifications. |
| Realtime leakage | Realtime channels can leak metadata if channel names or payloads are too broad. | Realtime is optional and additive. Durable DB ledger is source of truth. Broadcast only minimal ids/count hints on private tenant channels; UI refetches details through RPC. |
| Realtime dependency failure | UI must work if realtime disconnects. | Poll/refetch fallback remains mandatory. Realtime is never required for correctness. |
| Retention growth | A notification ledger can grow quickly if every low-value event is persisted. | Use severity/source filters, dedupe keys, expiration, retention policy, and producer allowlist. Default hot retention is bounded. |
| Producer coupling | `/erp` implementation can accidentally make Notification Center connector-only. | Use app-wide naming: `AppNotificationCenter`, `app_notifications`, `emit_app_notification`. ERP is first producer, not owner. |
| UI noise | Operators may ignore the center if every event becomes a notification. | Only persist actionable, status-changing, or high-value informational events. Routine activity remains in activity timeline. |
| Railway overuse | A notification center does not need a new worker unless fanout becomes async/heavy. | PR16.9 uses DB RPCs and app UI first. Railway is reserved for future email digest, scheduled purge, or provider fanout. |

## Non-Negotiable Rules

- Notification Center is app-wide, even if PR16.9 first renders it inside `/erp`.
- `/erp` is a producer and consumer surface, not the notification owner.
- No email, push, SMS, Slack, or external delivery provider in PR16.9.
- No AI autonomous notification action.
- No secret, credential value, provider response, raw source payload, raw snapshot payload, or field value in notification payloads.
- No browser direct write to notification tables.
- No unauthenticated notification access.
- No cross-tenant notification read.
- No notification creation without a deterministic source event or explicit service-role emit RPC.
- No realtime-only correctness path.
- No broad public channel payloads.
- No global notification count that ignores tenant and role visibility.
- No hidden fallback to demo notifications on product paths.

## Architecture Strategy

### Source Of Truth

The durable database ledger is the source of truth.

Realtime, polling, optimistic UI, and browser state are delivery optimizations only. If realtime fails, the UI must still load, filter, mark read, and dismiss notifications through RPCs.

### Schema

PR16.9 should introduce:

- `puls_app`
- `puls_app.app_notifications`
- `puls_app.app_notification_reads`

Optional future objects can include:

- `puls_app.app_notification_preferences`
- `puls_app.app_notification_deliveries`
- `puls_app.app_notification_subscriptions`

PR16.9 should not introduce external delivery tables unless delivery is implemented.

### Minimum Notification Shape

Each notification should carry:

- `tenant_id`
- `source_domain`
- `source_event_key`
- `source_table`
- `source_id`
- `severity`
- `priority`
- `target_roles`
- `target_employee_ids`
- `subject_type`
- `subject_id`
- `title_key`
- `body_key`
- `route_hint`
- `action_key`
- `dedupe_key`
- `safe_summary`
- `occurred_at`
- `expires_at`
- `created_at`

The safe summary must use booleans, counts, ids, state names, route hints, contract versions, and next-action keys. It must not contain raw values.

### Read State

Read/dismiss state should be per employee, not stored directly on the notification row.

Use a separate read ledger:

- `notification_id`
- `employee_id`
- `read_at`
- `dismissed_at`

This keeps one notification visible to multiple roles while allowing independent read state.

### RPC Boundary

Authenticated users interact through RPCs:

- `list_app_notifications(...)`
- `get_app_notification_summary(...)`
- `mark_app_notification_read(...)`
- `dismiss_app_notification(...)`

Service-role producers use:

- `emit_app_notification(...)`
- `refresh_connector_app_notifications(...)`

Internal helpers can include:

- `_app_notification_visible_to_current_user(...)`
- `_redact_app_notification_safe_summary(...)`
- `_build_app_notification_dedupe_key(...)`

Direct authenticated table writes remain closed.

## Schema Exposure Protocol

PR16.9.0 must be a small bootstrap phase before real Notification Center logic.

Required steps:

1. Create `puls_app`.
2. Grant schema usage intentionally.
3. Add a minimal service/auth RPC smoke object.
4. Ensure Supabase exposed schemas include `puls_app`.
5. Align local Supabase config with remote exposure.
6. Push migration.
7. Reload PostgREST schema cache if needed.
8. Verify RPC visibility through the same access path the app uses.
9. Verify unauthorized/public access is closed.
10. Record smoke SQL in the PR verify script.

Important distinction:

- `NOTIFY pgrst, 'reload schema'` refreshes object metadata for schemas PostgREST already exposes.
- It does not add a schema that is absent from the exposed schema configuration.
- Local `supabase/config.toml` schema changes require restarting the local Supabase stack before REST-profile smoke.
- Remote Supabase requires the project API exposed schema setting to include `puls_app`.

Stop condition:

- If `puls_app` RPCs are not visible or return schema-cache/profile errors, do not proceed to notification model work.

## Realtime Strategy

PR16.9 should be correct without realtime. Realtime can be added only after the durable ledger and RPCs pass.

Recommended approach:

- Use private tenant-scoped channels.
- Broadcast minimal payloads: notification id, occurred timestamp, severity, unread count hint.
- Fetch full details through `list_app_notifications`.
- Keep polling/refetch fallback.
- Avoid Postgres Changes as the primary UI contract for high-volume inbox updates.

Do not broadcast:

- raw payloads,
- safe summary bodies with sensitive context,
- employee-specific private data to a tenant-wide channel,
- source values,
- provider responses,
- credential or token context.

## UI Strategy

The UI must be app-wide in naming and behavior.

Recommended components:

- `AppNotificationCenter`
- `NotificationList`
- `NotificationSummaryBadge`
- `NotificationFilterBar`

First surface:

- `/erp` should render the center as the first operational proof because connector runtime now produces actionable events.

Future surfaces:

- global shell/topbar bell,
- `/dashboard`,
- `/ai-koc`,
- `/ayarlar` notification preferences.

Minimum UX states:

- loading,
- empty,
- unread/all,
- severity filter,
- source-domain filter,
- action-required grouping,
- mark read/unread,
- dismiss,
- route/action link,
- error state,
- realtime disconnected fallback state if realtime is implemented.

Design rules:

- No marketing-style notification page.
- No nested cards.
- Dense, scannable, operational UI.
- Clear priority and severity without alarming low-risk events.
- No raw technical payloads in visible text.

## Producer Strategy

PR16.9 should start with connector producer events because PR16.1-PR16.8 already created safe evidence.

Initial source domain:

- `connector_runtime`

Initial source events:

- `connector_job_failed`
- `connector_job_dead_letter`
- `connector_job_succeeded`
- `import_apply_change_set_ready`
- `import_apply_approval_required`
- `import_apply_create_only_completed`
- `import_apply_guarded_update_completed`
- `import_apply_rollback_required`
- `import_apply_rollback_preview_ready`
- `import_apply_rollback_approval_recorded`
- `import_apply_rollback_worker_ready`
- `import_apply_rollback_completed`
- `runtime_preflight_failed`

Only high-value `succeeded` events should notify. Routine success can stay in activity timeline unless it completes a major operator workflow such as apply or rollback.

## Retention Strategy

Default:

- app notifications: 180 days hot retention,
- read/dismiss state: same as notification retention,
- critical object-event-linked notifications: retain safe summary up to 24 months if tenant policy requires,
- expired notifications should be hidden by default but can remain until purge.

Purge/archive:

- PR16.9 can define retention metadata.
- A scheduled purge job can wait until a later PR unless data volume requires it immediately.
- Do not open high-volume low-value notification producers before purge ownership is defined.

## PR16.9 Sub-Phase Plan

### PR16.9.0 - puls_app Bootstrap And Exposure Smoke

Goal:

- Prove `puls_app` can be safely exposed and served by Supabase/PostgREST.

Scope:

- `puls_app` schema.
- Minimal smoke RPC.
- Grants and schema-cache reload guidance.
- Verify script for local/remote alignment.

Verification:

- Exposed schema visible.
- Authenticated RPC works only when tenant context exists.
- Service-role RPC works.
- Public access remains closed.
- No `PGRST202` or schema-profile mismatch remains after reload.

Stop condition:

- No Notification Center tables until this passes.

### PR16.9.1 - Durable Notification Ledger

Goal:

- Create app-wide notification source of truth.

Scope:

- `app_notifications`
- `app_notification_reads`
- RLS policies.
- `list`, `summary`, `mark read`, `dismiss` RPCs.
- Service-role `emit` RPC.

Verification:

- Cross-tenant read denied.
- Role visibility works.
- Direct authenticated writes denied.
- Safe summary redaction enforced.
- Dedupe key prevents duplicate notifications.

### PR16.9.2 - Connector Producer Mapping

Goal:

- Convert selected PR16 connector/runtime events into app notifications.

Scope:

- Idempotent producer refresh/emit RPC.
- ERP connector event mappings.
- Rollback completion and failure notifications.
- Action keys and route hints.

Verification:

- PR16.8 rollback success emits one notification.
- Dead-letter/failure emits action-required notification.
- Re-running producer refresh creates no duplicates.
- Payload has no raw values or secrets.

### PR16.9.3 - App Notification Center UI

Goal:

- Deliver a production-grade app-wide Notification Center UI, first embedded in `/erp`.

Scope:

- App-wide data adapter.
- Reusable UI components.
- `/erp` integration.
- Read/unread/dismiss actions.
- Filters and summary counts.
- I18n strings.

Verification:

- UI loads with real RPC data.
- Empty/loading/error states work.
- Mark read/dismiss persists after refetch.
- Role-filtered results match DB smoke.
- No layout overlap at mobile and desktop sizes.

### PR16.9.4 - Optional Realtime Enhancement

Goal:

- Add live update behavior without making realtime required.

Scope:

- Private tenant channel.
- Minimal broadcast payload.
- Refetch on event.
- Polling fallback.

Verification:

- Notification appears after producer event without manual refresh.
- UI still works when realtime is disabled.
- Cross-tenant channel leakage smoke passes.
- Broadcast payload contains only ids/count hints.

## Smoke Matrix

Every PR16.9 sub-phase must include SQL or UI smoke that proves:

- local and remote migrations align,
- `puls_app` exposure is intentional,
- schema cache is refreshed,
- public access is closed,
- authenticated access is tenant-scoped,
- service-role writes are controlled,
- direct table mutation is closed to authenticated users,
- RPC results contain no secret/raw payload keys,
- dedupe/idempotency works,
- UI state matches the DB ledger,
- fallback path works without realtime.

## What To Avoid

- Do not implement notification center as an `/erp` local array.
- Do not reuse activity timeline rows as notification rows without a notification contract.
- Do not use `puls_integration` as the app-wide notification owner.
- Do not expose notification tables broadly just to make the UI easier.
- Do not rely on Supabase Realtime Postgres Changes as the only delivery mechanism.
- Do not store translated text only; store keys plus safe metadata so i18n remains possible.
- Do not create one notification per low-value runtime heartbeat.
- Do not send notifications for every successful background poll.
- Do not create notification preferences until the first inbox and producer are proven.
- Do not add Railway notification worker work until DB/UI/realtime needs justify it.

## Acceptance Criteria For PR16.9 Completion

PR16.9 is complete only when:

- `puls_app` is exposed and smoke-tested locally and remotely.
- Durable app notification ledger exists.
- Authenticated users can list only their tenant/role-visible notifications.
- Service-role can emit idempotent app notifications.
- `/erp` is the first producer/consumer surface, but code and schema names remain app-wide.
- At least one PR16.8 rollback or connector runtime event appears in Notification Center.
- Read/unread and dismiss actions work.
- UI has production-ready loading, empty, error, and filtered states.
- Safe summaries contain no raw payload, credential, provider response, field value, or snapshot value.
- Realtime, if added, is optional and fallback-safe.
- The next PR can add more producers without rewriting the notification model.

## Handoff After PR16.9

After PR16.9, future PRs can add:

- global shell notification bell,
- notification preferences,
- email digest through Railway or an external provider,
- more workflow/security/AI producers,
- notification retention purge automation,
- AI-safe priority recommendations.

Those future PRs must reuse the app-wide ledger and visibility contract instead of creating domain-specific notification systems.
