# PR16.10.9 Runtime Safety Hardening

PR16.10.9 closes the production safety gaps found after PR16.10.8 without
changing the DataSource Manager user journey. This phase hardens the audit tenant boundary, notification idempotency, worker lease ownership, credential
revocation behavior, production Supabase configuration, and CI regression
coverage.

## Product Contract

- Admin-facing DataSource Manager behavior remains unchanged.
- No DataSource Manager UI refactor is included in this PR.
- No technical inspector redesign is included in this PR.
- Runtime safety must improve without adding new user-facing complexity.
- Existing CSV / Excel package upload and preview handoff remain intact.
- Existing connector runtime boundaries remain service-role controlled.

## Backend Contract

- Authenticated audit inserts into `puls_audit.audit_logs` must be tenant-bound.
- Nullable tenant audit writes are not accepted through the authenticated table
  policy.
- System-wide audit events must stay behind service-role or explicit RPC
  boundaries.
- Connector job notification idempotency must not depend on mutable job status.
- Connector job notification dedupe is normalized at the durable ledger
  boundary.
- Existing notification ledger rows remain immutable; PR16.10.9 normalizes new
  connector job notification inserts only.
- Connector worker completion requires an active worker lease.
- Create-only apply execution requires an active worker lease.
- Guarded-update apply execution requires an active worker lease.
- Guarded-update rollback execution requires an active worker lease.
- Revoked credential references cancel queued, retrying, and running runtime
  preflight jobs.
- A revoked credential cannot be marked verified by a late verification result.
- production Supabase env fail-fast behavior prevents missing configuration
  from silently connecting to localhost in production.
- No provider calls, source writeback, credential readback, raw payload readback,
  field value readback, or snapshot payload readback are opened.

## Frontend / CI Contract

- Production builds fail fast when `VITE_SUPABASE_URL` or
  `VITE_SUPABASE_ANON_KEY` is missing.
- Local development keeps the existing localhost fallback warning.
- CI runs Vitest regression tests in addition to typecheck, lint, build, i18n,
  and e2e checks.

## Verification

```bash
scripts/verify-16-10-9-runtime-safety-hardening.sh WORKTREE
pnpm run test
pnpm run typecheck
pnpm run lint
pnpm run check-i18n
supabase db push --local --yes
supabase db lint --local --schema puls_app --fail-on error
supabase db lint --local --schema puls_integration --fail-on error
supabase db lint --local --schema puls_audit --fail-on error
```

Remote smoke should additionally verify:

- `puls_audit.audit_logs` authenticated insert policy no longer permits
  `tenant_id IS NULL`.
- `puls_workflow.resolve_approver(uuid, uuid)` is absent in live `pg_proc`.
- `puls_app.app_notification_reads` has no authenticated direct table grant.
- Connector job notification dedupe no longer changes when job status changes.
- Expired worker leases are rejected before completion or apply execution.
