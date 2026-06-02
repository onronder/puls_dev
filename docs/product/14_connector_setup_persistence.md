# PR14.8 — Connector Setup Persistence

PR14.8 turns the connector setup workbench from a local preview into persisted tenant state. It keeps the runtime boundary closed: no connector execution, no credentials, no imports, no ERP writes.

## Product Claim

Connector setup persistence is the first durable step between an empty PULS tenant and future connector runtime.

PULS remains source independent. Canias and CSV / Excel are MVP setup sources; Logo and Custom API remain visible future candidates without persisted setup actions in PR14.8.

Each persisted connection is tenant-scoped and source-keyed. The setup record stores lifecycle state, setup step, enabled posture, selected domains, and safe metadata only. Secret material stays outside the application database until a future credentials boundary is explicitly designed.

## What PR14.8 Proves

| Area | PR14.8 behavior |
|------|-----------------|
| Empty tenant | Admin can start a connector setup draft from `/erp` |
| Source selection | Canias and CSV / Excel persist setup records; Logo and Custom API remain future-only |
| Seeded tenant | Existing Canias metadata remains preflight-ready and is not downgraded to draft |
| Dashboard | ERP status reflects draft, disabled, preflight, or runtime posture from DB state |
| Manager role | Manager can inspect connector readiness but cannot start or change setup |
| Employee role | Employee remains blocked from setup routes |
| Source model | `connection_key` and `owned_domains` prepare multiple source ownership without connector runtime |

## What PR14.8 Does Not Prove

- No runtime sync is enabled.
- No credentials, API keys, tokens, passwords, or secret references are captured.
- No import job, file upload, field-mapping editor, source discovery, or connector execution is implemented.
- No ERP writeback, export, approval action, or destructive mutation is introduced.

## Data Model

PR14.8 extends `puls_integration.erp_connections` instead of creating a separate draft table:

| Column | Purpose |
|--------|---------|
| `connection_key` | Tenant-scoped stable setup key such as `canias-default` or `csv-excel-default` |
| `setup_status` | Lifecycle status: draft, setup in progress, mapping ready, preflight ready, connected, disabled, archived, or error |
| `setup_step` | Current wizard step: source, mapping, namespace, preflight, or runtime |
| `is_enabled` | Product-level enablement flag; this is not runtime sync activation |
| `selected_at` / `setup_started_at` | Audit timestamps for source selection and setup start |
| `owned_domains` | Canonical PULS domains this source may own after mapping is validated |
| `setup_metadata` | Non-secret setup metadata only |
| `created_by_employee_id` / `updated_by_employee_id` | Employee audit anchors |

The migration also widens connector metadata read access to manager/admin roles while keeping writes admin-only.

## Setup Flow

```mermaid
flowchart LR
  Empty["No connector"] --> Source["Choose source"]
  Source --> Draft["Persist draft"]
  Draft --> Mapping["Mapping step"]
  Mapping --> Namespace["Namespace step"]
  Namespace --> Preflight["Preflight ready"]
  Preflight -. future .-> Runtime["Runtime connector"]
```

Admin flow in PR14.8:

1. Open `/erp` on an empty tenant.
2. Select Canias or CSV / Excel.
3. Start setup.
4. The app creates a draft `puls_integration.erp_connections` row and returns to DB-backed connector posture.

Manager flow in PR14.8:

1. Open `/erp`.
2. Inspect connector setup posture.
3. See a friendly admin-required notice for setup actions.

Manager can inspect connector setup posture.

## Role Boundary

| Role | `/erp` access | Setup action |
|------|---------------|--------------|
| Employee | Blocked by setup guard | Not available |
| Manager | Read-only inspection | Disabled with admin-required copy |
| HR admin / Superadmin | Full setup action | Can create setup draft |

## Local Verification

Run the PR14.8 verify gate and normal quality gates:

```bash
./scripts/verify-14-connector-setup-persistence.sh HEAD
pnpm check-i18n
pnpm test
pnpm build
```

Preferred local Supabase proof is a clean reset:

```bash
supabase db reset
```

Current local reset still has a pre-existing Lovable/public bootstrap mismatch before PR14.8 migrations run. If that appears, validate PR14.8 by applying the canonical prerequisites in local Docker Postgres and then applying `20260602090000_puls_integration_connector_setup_lifecycle.sql`; the migration must create the setup enum columns and manager/admin RLS policies without error. Full `supabase db reset` repair should be treated as a separate infra closeout item, not hidden inside connector setup persistence.

Expected local smoke:

- PULS Connector Lab shows no connector on `/dashboard`.
- `/erp` shows source selection.
- Admin can start Canias or CSV / Excel setup.
- Dashboard ERP status changes from no source to setup draft.
- Puls Teknik seeded Canias remains preflight-ready.

## Remote Rollout Boundary

Remote deployment should happen only after local migration and app gates pass. Remote database migration must be applied before smoke-testing the persisted setup action on the live development project.

PR14.8 does not require live authenticated e2e to click the new setup action in pull-request CI because authenticated Playwright currently targets the live Vercel URL. The live post-merge smoke should cover the new action after the migration and deployment are both present.

## Handoff

PR14.9 should define connector setup error/log posture and Sentry coverage for frontend/backend diagnostics. Later connector PRs can add mapping editors, source discovery, credentials references, and runtime execution without changing the PR14.8 source-independent setup boundary.
