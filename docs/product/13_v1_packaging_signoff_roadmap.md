# PR13 Closeout — V1 Packaging Signoff Roadmap

This roadmap is the stop-and-breathe plan after PR13.7. PR13.0-13.7 produced the strategy, inventories, seed artifacts, scenario proof scripts, AI Coach context readiness, and Canias/AI boundaries. The remaining work is not "open endless PRs"; it is a bounded signoff sequence.

## Executive Summary

PR13.8-PR13.10 should close the packaging loop without opening unbounded follow-up PRs:

1. Prove the Puls Sanayi seed and scenario scripts on local Supabase/Postgres with mandatory auth persona smoke.
2. Repeat the proof on the remote development Supabase/Postgres environment only after local signoff, using a separate Puls Teknik A.S. tenant strategy.
3. Walk the V1 routes with `VITE_PULS_DEMO_MODE=false`, record honest screen readiness, and close fallback guardrails.

After these phases, the honest claim is:

> V1 customer demo / packaging proof is DB-backed for the core product path, with explicit partial/future labels for non-core depth. ERP runtime and live AI remain future work.

Do not claim:

> Every screen's full production business logic, canonical customer data model, and ERP integration are complete.

## Current State

| Area | Status | Evidence |
|------|--------|----------|
| PR13.0-13.2 strategy/inventory | Done | Product packaging strategy, DB coverage, demo retirement docs |
| PR13.3-13.3A seed specification | Done | Puls Sanayi 120-person spec + data dictionary crosswalk |
| PR13.4 baseline seed pack | Done | 22 CSVs, manifest, reset/load/validate SQL |
| PR13.5 scenario/bootstrap proof | Done | Workflow/performance scenario SQL, auth/JWT templates, route matrix |
| PR13.6 AI Coach DB context readiness | Done | `/ai-koc` DB context readiness + guardrails |
| PR13.7 Canias/AI connector boundary | Done | Canias discovery, AI action boundary, SQL 09 |
| Local Supabase proof | Pending | Needs Docker/Supabase running and local `DATABASE_URL` |
| Mandatory auth persona proof | Pending | Needs local auth users + `05`/`06` |
| Remote Puls Teknik A.S. tenant proof | Waiting | Starts only after local proof and tenant strategy |
| Demo-off route smoke | Pending | Needs 20-route walkthrough with `source: real` |
| Screen readiness truth table | Pending | Needs final route-by-route status and gaps |
| Demo fallback hardening | Pending | Needs guard against new packaging dependencies on `fetchDemo*` |

## Remaining PR Cap

Target at most three more PRs for PR13 closeout:

| PR | Name | Goal | Exit Criteria |
|----|------|------|---------------|
| PR13.8 | Local Supabase packaging + auth proof | Load and validate seed/scenario proof locally with mandatory auth smoke | SQL `00-09` + `05`/`06` proof run recorded |
| PR13.9 | Remote Puls Teknik tenant proof | Repeat the proof on remote dev Supabase with a separate tenant posture | Remote proof recorded without secrets or baseline drift |
| PR13.10 | Demo-off route smoke + fallback closeout | Verify V1 routes under demo mode off and close guardrails | 20-route truth table + fallback guard + final PR13 claim |

If PR13.8 and PR13.9 expose a blocker, use a small fix PR only when the blocker cannot be honestly documented as a V1 gap.

## PR13.8 Prompt — Local Supabase Packaging + Auth Proof

```md
---
name: PR13.8 Local Supabase Packaging Auth Proof
overview: "Run the merged PR13.4-13.7 Puls Sanayi seed/proof stack against local Supabase/Postgres and require auth persona JWT/RPC smoke before remote tenant work. No app feature work, no migrations, no seed CSV/manifest changes, no secrets."
todos:
  - id: inspect
    content: Confirm origin/main includes PR13.7; inspect local Supabase status, seed SQL 00-09, and psql connection posture without exposing secrets
    status: pending
  - id: runbook
    content: Create local proof runbook with exact psql order, env handling, expected outputs, failure triage, and no-secret policy
    status: pending
  - id: proof-run
    content: Run 00_reset, 01_load, 02_validate, 03, 04, 07, 08, 09 on local DB using DATABASE_URL/Postgres URI
    status: pending
  - id: auth-personas
    content: Create local auth users; run 05/06 with real admin/hr/manager/employee UUIDs as a mandatory gate
    status: pending
  - id: results
    content: Capture sanitized counts, notices, mandatory auth state, and known gaps in docs/product/13_local_supabase_packaging_auth_proof_results.md
    status: pending
  - id: verify
    content: Add PR13.8 verify script for required docs/runner, mandatory auth, no secrets, no migrations, no seed CSV/manifest drift
    status: pending
  - id: validate-pr
    content: Run verify + sensitive grep + pnpm gate; optional live proof must not print secrets; open draft PR
    status: pending
isProject: false
---

# PR13.8 — Local Supabase Packaging + Mandatory Auth Proof

## Scope Lock

In scope:
- Local proof runbook and sanitized proof results
- Helper script wrapping existing SQL order with mandatory auth persona smoke
- Product docs updates pointing to proof status

Out of scope:
- Remote Puls Teknik A.S. tenant setup
- `src/**`
- `supabase/migrations/**`
- Seed CSV or `manifest.json` edits
- New runtime connector, LLM, OpenAPI, package changes
- Committing `.env*` or database credentials

## Required SQL Order

Run from `supabase/seed/puls-sanayi-v1`:

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/00_reset_puls_sanayi_seed.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/01_load_puls_sanayi_seed.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/02_validate_puls_sanayi_seed.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/03_generate_workflow_scenarios.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/04_generate_performance_scenarios.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/07_validate_packaging_proof.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/08_validate_ai_context_readiness.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/09_validate_canias_connector_readiness.sql
```

Mandatory after local auth users exist:

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 \
  -v admin_user_id='...' \
  -v hr_admin_user_id='...' \
  -v manager_user_id='...' \
  -v employee_user_id='...' \
  -v incomplete_setup_user_id='...' \
  -f sql/05_link_auth_personas_template.sql

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 \
  -v admin_user_id='...' \
  -v hr_admin_user_id='...' \
  -v manager_user_id='...' \
  -v employee_user_id='...' \
  -f sql/06_jwt_mutation_proof_smoke.sql
```

## Acceptance Criteria

- Local proof docs include absolute run date, environment label, and sanitized result summary.
- No secret value is committed.
- All mandatory validation SQL passes or failures are documented with exact remediation.
- Auth smoke passes with real local UUIDs; PR13.8 is not signed off without `06_jwt_mutation_proof_smoke.sql`.
- No app behavior is changed in PR13.8.
```

## PR13.9 Prompt — Remote Puls Teknik Tenant Proof

```md
---
name: PR13.9 Remote Puls Teknik Tenant Proof
overview: "After PR13.8 local proof is green, repeat the seed/proof stack on remote development Supabase/Postgres with a separate Puls Teknik A.S. tenant posture. No runtime ERP, no live AI, no secrets, no seed baseline drift."
todos:
  - id: inspect
    content: Confirm PR13.8 local proof is green; decide remote tenant strategy without mutating PR13.4 baseline silently
    status: pending
  - id: tenant-posture
    content: Document Puls Teknik A.S. tenant posture, source of truth, and whether data is cloned/overlaid from Puls Sanayi proof
    status: pending
  - id: proof-run
    content: Run SQL 00-09 on remote dev Supabase/Postgres using psql and sanitized logs
    status: pending
  - id: auth-proof
    content: Run 05/06 with remote auth personas; do not sign off without JWT/RPC smoke
    status: pending
  - id: results
    content: Record sanitized remote proof results and any tenant-delta caveats
    status: pending
  - id: verify
    content: Add verify for remote proof docs, no secrets, no migrations, no CSV/manifest drift
    status: pending
  - id: validate-pr
    content: Run verify + sensitive grep + pnpm gate; open draft PR
    status: pending
isProject: false
---

# PR13.9 — Remote Puls Teknik Tenant Proof

## Scope Lock

In scope:
- Remote development Supabase proof docs
- Puls Teknik A.S. tenant posture
- Sanitized SQL/auth proof results

Out of scope:
- Broad app refactors
- Canias runtime
- Live AI/LLM
- Migrations
- Seed CSV/manifest changes unless a separate tenant overlay is explicitly approved

## Acceptance Criteria

- Remote proof is not attempted until PR13.8 local proof is green.
- Puls Teknik A.S. tenant posture is explicit and does not silently rewrite PR13.4 baseline artifacts.
- SQL `00-09` and mandatory `05`/`06` auth proof results are recorded without secrets.
- Any gap is documented as a tenant/proof gap, not hidden as success.
```

## PR13.10 Prompt — Demo-Off Route Smoke, Fallback Hardening, and Closeout

```md
---
name: PR13.10 Demo-Off Route Smoke Closeout
overview: "Walk all 20 V1 routes with VITE_PULS_DEMO_MODE=false, record screen readiness, add fallback guardrails, and publish the final PR13 closeout checklist. Keep runtime behavior stable unless an explicit minimal guard is approved."
todos:
  - id: inspect
    content: Read PR13.8 local proof, PR13.9 remote tenant proof, and PR13.10 screen truth table inputs; inspect current fetchDemo usage and demo mode behavior
    status: pending
  - id: truth-table
    content: Create docs/product/13_v1_screen_readiness_truth_table.md with 20 routes, business logic status, DB model, seed coverage, demo readiness, production gaps
    status: pending
  - id: route-smoke
    content: Execute manual or browser-assisted route smoke with demo mode off; record DemoSourcePill absence/source real where observable
    status: pending
  - id: guard-script
    content: Add script/check that flags new product-path fetchDemo additions unless classified in the retirement map
    status: pending
  - id: closeout-doc
    content: Create docs/product/13_v1_packaging_closeout.md with final claims, non-claims, proof links, and PR14 handoff
    status: pending
  - id: docs
    content: Update README/strategy/retirement docs with final PR13 closeout posture
    status: pending
  - id: validate-pr
    content: Run guard + sensitive grep + pnpm gate; open final PR13 closeout PR
    status: pending
isProject: false
---

# PR13.10 — Demo-Off Route Smoke, Fallback Hardening, and Closeout

## Acceptance Criteria

- No new embedded business fixture can enter product proof path without classification.
- Final docs distinguish:
  - customer-demo ready
  - production partial
  - future/non-V1
  - ERP runtime future
  - live AI future
- PR14 handoff is explicit and finite.
```

## Stop Conditions

PR13 is complete when:

- PR13.8 local proof and mandatory auth smoke are green.
- PR13.9 remote Puls Teknik tenant proof is green or blocked with explicit tenant-strategy rationale.
- PR13.10 route smoke truth table has no `blocked` core route, and closeout guard is merged or consciously skipped with written rationale.

If a route is `partial_v1` but accepted for customer demo, do not open another PR just to make the label prettier. Put it in PR14 backlog.
