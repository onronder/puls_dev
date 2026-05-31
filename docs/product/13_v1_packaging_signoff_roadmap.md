# PR13 Closeout — V1 Packaging Signoff Roadmap

This roadmap is the stop-and-breathe plan after PR13.7. PR13.0-13.7 produced the strategy, inventories, seed artifacts, scenario proof scripts, AI Coach context readiness, and Canias/AI boundaries. The remaining work is not "open endless PRs"; it is a bounded signoff sequence.

## Executive Summary

PR13.8-PR13.10 should close the packaging loop:

1. Prove the Puls Sanayi seed and scenario scripts on the target Supabase/Postgres environment.
2. Walk the V1 routes with `VITE_PULS_DEMO_MODE=false` and record honest screen readiness.
3. Add lightweight guardrails so packaging proof cannot silently regress into embedded demo fallback.

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
| Remote Supabase proof | Pending | Needs `DATABASE_URL`/Postgres URI proof run |
| Auth persona proof on target env | Pending | Needs Dashboard users + `05`/`06` |
| Demo-off route smoke | Pending | Needs 20-route walkthrough with `source: real` |
| Screen readiness truth table | Pending | Needs final route-by-route status and gaps |
| Demo fallback hardening | Pending | Needs guard against new packaging dependencies on `fetchDemo*` |

## Remaining PR Cap

Target at most three more PRs for PR13 closeout:

| PR | Name | Goal | Exit Criteria |
|----|------|------|---------------|
| PR13.8 | Remote packaging proof | Load and validate seed/scenario proof on target DB | SQL `00-09` proof run recorded, remote caveats documented |
| PR13.9 | Demo-off route smoke and truth table | Verify V1 routes under demo mode off | 20-route matrix updated with observed `source: real`/gap posture |
| PR13.10 | Packaging fallback hardening | Prevent new demo fallback from being mistaken as proof | Guard script/docs added; final PR13 closeout checklist complete |

If PR13.8 and PR13.9 expose a blocker, use a small fix PR only when the blocker cannot be honestly documented as a V1 gap.

## PR13.8 Prompt — Remote Packaging Proof

```md
---
name: PR13.8 Remote Packaging Proof
overview: "Run the merged PR13.4-13.7 Puls Sanayi seed/proof stack against the target Supabase/Postgres environment and record sanitized proof results. No app feature work, no migrations, no seed CSV/manifest changes, no secrets."
todos:
  - id: inspect
    content: Confirm origin/main includes PR13.7; inspect local seed SQL 00-09 and target DB connection posture without exposing secrets
    status: pending
  - id: runbook
    content: Create remote proof runbook with exact psql order, env handling, expected outputs, failure triage, and no-secret policy
    status: pending
  - id: proof-run
    content: Run 00_reset, 01_load, 02_validate, 03, 04, 07, 08, 09 on target DB using DATABASE_URL/Postgres URI
    status: pending
  - id: auth-personas
    content: Document Dashboard auth user creation; run 05/06 only when real auth UUIDs are supplied
    status: pending
  - id: results
    content: Capture sanitized counts, notices, skipped optional auth state, and known gaps in docs/product/13_remote_packaging_proof_results.md
    status: pending
  - id: verify
    content: Add or update a PR13.8 verify script for required docs, no secrets, no migrations, no seed CSV/manifest drift
    status: pending
  - id: validate-pr
    content: Run verify + sensitive grep + pnpm gate; optional live proof must not print secrets; open draft PR
    status: pending
isProject: false
---

# PR13.8 — Remote Packaging Proof

## Scope Lock

In scope:
- Remote proof runbook and sanitized proof results
- Optional helper script wrapping existing SQL order if it stores no secrets
- Product docs updates pointing to proof status

Out of scope:
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

Optional after Dashboard users exist:

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

- Remote proof docs include absolute run date, environment label, and sanitized result summary.
- No secret value is committed.
- All mandatory validation SQL passes or failures are documented with exact remediation.
- Auth smoke is either passed with real UUIDs or explicitly marked not run because users were not created.
- No app behavior is changed in PR13.8.
```

## PR13.9 Prompt — Demo-Off Route Smoke and Screen Truth Table

```md
---
name: PR13.9 Demo-Off Route Smoke
overview: "Walk all 20 V1 routes against the remote DB-backed Puls Sanayi proof environment with VITE_PULS_DEMO_MODE=false, record source posture, screen readiness, canonical DB model coverage, accepted gaps, and customer-demo status."
todos:
  - id: inspect
    content: Confirm PR13.8 remote proof status and available persona logins; read route matrix and feature coverage inventory
    status: pending
  - id: truth-table
    content: Create docs/product/13_v1_screen_readiness_truth_table.md with 20 routes, business logic status, DB model, seed coverage, demo readiness, production gaps
    status: pending
  - id: route-smoke
    content: Execute manual or browser-assisted route smoke with demo mode off; record DemoSourcePill absence/source real where observable
    status: pending
  - id: persona-smoke
    content: Smoke admin/hr_admin/manager/employee/incomplete setup routes where auth users exist
    status: pending
  - id: gap-register
    content: Update remaining work register with blockers, accepted gaps, future/non-V1 items, and PR14 handoff candidates
    status: pending
  - id: verify
    content: Add verify for 20 route strings, status taxonomy, no over-claiming, and no Canias/runtime/live AI claim
    status: pending
  - id: validate-pr
    content: Run verify + sensitive grep + pnpm gate; open draft PR
    status: pending
isProject: false
---

# PR13.9 — Demo-Off Route Smoke and V1 Screen Truth Table

## Scope Lock

In scope:
- Route smoke docs and screen truth table
- Product docs updates
- Optional smoke helper/checklist script

Out of scope:
- Broad app refactors
- Canias runtime
- Live AI/LLM
- Migrations
- Seed CSV/manifest changes unless PR13.8 found a seed blocker and the change is separately approved

## Required Screen Status Taxonomy

| Status | Meaning |
|--------|---------|
| `demo_ready_core` | Good for customer demo with DB-backed proof |
| `partial_v1` | Usable/visible, but limited depth or known gaps |
| `placeholder_future` | Explicit future/non-V1 surface |
| `requires_auth_persona` | Needs linked auth user to prove |
| `blocked` | Cannot be demoed honestly until fixed |

## Required Routes

`/dashboard`, `/sirket-kurulum`, `/calisanlar`, `/departmanlar`, `/pozisyonlar`, `/izin-tanimlari`, `/izin`, `/masraf-kategorileri`, `/masraf`, `/performans`, `/performans-parametreleri`, `/kariyer`, `/egitim`, `/is-degerleme`, `/sozlesmeler`, `/profil`, `/ayarlar`, `/erp`, `/ai-koc`, `/menu`

## Acceptance Criteria

- Every route has a readiness row with:
  - business logic status
  - adapter/backend path
  - DB objects/calc views
  - seed/scenario coverage
  - demo mode off result
  - accepted gap
  - next owner
- The final claim says "customer-demo ready / packaging proof complete", not "production complete".
- `/is-degerleme`, `/erp`, and `/ai-koc` retain honest future/partial labels.
```

## PR13.10 Prompt — Packaging Fallback Hardening and Closeout

```md
---
name: PR13.10 Packaging Fallback Hardening
overview: "Close PR13 by adding guardrails that prevent embedded demo fallback from being confused with V1 packaging proof, and publish the final PR13 closeout checklist. Keep runtime behavior stable unless an explicit minimal guard is approved."
todos:
  - id: inspect
    content: Read PR13.8 remote proof and PR13.9 screen truth table; inspect current fetchDemo usage and demo mode behavior
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

# PR13.10 — Packaging Fallback Hardening and Closeout

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

- PR13.8 remote proof is green or documented with only accepted optional-auth gaps.
- PR13.9 route smoke truth table has no `blocked` core route.
- PR13.10 closeout guard is merged or consciously skipped with written rationale.

If a route is `partial_v1` but accepted for customer demo, do not open another PR just to make the label prettier. Put it in PR14 backlog.

