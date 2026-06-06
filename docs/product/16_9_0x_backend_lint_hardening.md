# PR16.9.0x Backend Lint Hardening

PR16.9.0x fixes two pre-existing `puls_integration` lint errors found after PR16.9.0 merged. It is intentionally separate from Notification Center product work so PR16.9.1 can start from an error-free backend gate.

## Scope

- Keeps PR16.9.0 `puls_app` bootstrap unchanged.
- Keeps Notification Center tables, realtime, delivery, producer mapping, and UI closed.
- Replaces the runtime preflight enum/text mismatch with explicit `TEXT` casts.
- Replaces the apply change-set temp-table plan with a typed in-memory plan.
- Preserves one-pass classification semantics for change-set counters and item inserts.
- Leaves warning-level lint cleanup for a separate pass.

## Supabase Data API Exposure Posture

Remote Supabase should not expose every table and every function by default.

Recommended posture for PR16.9 onward:

- Expose only schemas that are product API surfaces.
- Keep internal helper schemas private unless a route/RPC explicitly needs Data API access.
- For exposed schemas, select only tables/functions that are intentionally callable from the app.
- Keep table access behind grants plus RLS.
- Keep function access behind explicit `EXECUTE` grants.
- Treat warning badges in the Supabase UI as prompts to verify RLS/grants, not as a reason to blanket-select everything.
- For `puls_app`, expose the schema, then opt in only the notification RPCs/tables as each PR16.9 sub-phase implements and verifies them.

This matches Supabase's Data API model: schema exposure makes a namespace available to PostgREST, but actual table/function reachability still depends on explicit Postgres privileges and RLS/function grants.

## Fixed Errors

### `puls_integration.get_connector_runtime_preflight_context`

The function returns `provider TEXT` and `connection_method TEXT`, but the previous query returned enum columns directly.

Fix:

- `c.provider::TEXT`
- `c.connection_method::TEXT`

The RPC remains service-role only and keeps provider API calls, credential readback, canonical writes, and source writeback closed.

### `puls_integration.create_connector_apply_change_set`

The previous function used `CREATE TEMP TABLE tmp_connector_apply_change_set_items`. Runtime smoke had already proven it could work, but `plpgsql_check` could not resolve the temp relation during compile-time lint.

Fix:

- Build a typed `puls_integration.connector_apply_change_set_items[]` plan in memory.
- Classify each import record exactly once.
- Use that same typed plan for counters and item insert.
- Avoid dynamic SQL and avoid repeated CTE classification.
- Preserve idempotency, existing grants, existing return contract, and safe summary fields.

## Success Criteria

Run locally after Docker is available:

```bash
supabase db reset
supabase db lint --local --schema puls_integration --fail-on error
supabase db lint --local --fail-on error
scripts/verify-16-9-0x-backend-lint-hardening.sh WORKTREE
git diff --check
```

Expected:

- Local reset applies `20260606171000_puls_integration_backend_lint_hardening.sql`.
- `puls_integration` lint exits `0`.
- General local backend lint exits `0`.
- Remaining issues, if any, are warning-level only.

Remote acceptance after merge/push:

```bash
supabase db push --dry-run
supabase db push
supabase db lint --linked --schema puls_integration --fail-on error
supabase db lint --linked --fail-on error
```

Expected:

- Only `20260606171000_puls_integration_backend_lint_hardening.sql` is pending before push.
- Linked `puls_integration` and general backend lint exit `0`.

## Handoff To PR16.9.1

PR16.9.1 should start only after local and linked backend lint are error-free. Notification ledger work should remain app-wide under `puls_app` and should continue the opt-in table/function exposure discipline from this hardening note.
