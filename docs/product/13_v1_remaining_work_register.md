# PR13 Remaining Work Register

Living checklist for the remaining V1 packaging work. Use this instead of opening unbounded PRs.

## Working Rule

PR13 closeout is limited to local proof, remote tenant proof, route smoke, and fallback hardening. New product features, deep domain completion, Canias runtime, live AI, SDK/API productization, and CRM integrations move to PR14+ unless they block a core demo route.

## Summary Board

| ID | Workstream | Status | Target | Blocker / Input |
|----|------------|--------|--------|-----------------|
| W1 | Local Supabase seed/proof | Done | PR13.8 | SQL `00-09` passed locally |
| W2 | Mandatory auth persona proof | Done | PR13.8 | `05`/`06` and password-grant smoke passed locally |
| W3 | Remote Puls Teknik tenant proof | Done | PR13.9 | Remote SQL/auth proof passed |
| W4 | Demo-off route smoke | Done | PR13.10 | 20-route truth table recorded; persona/deep-link blockers fixed |
| W5 | Screen readiness truth table + fallback guard | Done | PR13.10 | Closeout doc, copy cleanup, and fallback regression guard added |
| W6 | Canias customer discovery | Waiting | PR14+ | Customer export/API/data model |
| W7 | Live AI / LLM gateway | Waiting | PR14+ | Product decision + security boundary |
| W8 | Production hardening | Waiting | PR14+ | Post-demo acceptance |

## Detailed Checklist

### W1 — Local Supabase Seed / Proof

| Task | Status | Notes |
|------|--------|-------|
| Confirm local Supabase/Postgres is running | Passed | Docker/Supabase stack was reachable after Docker start |
| Export local `DATABASE_URL` | Passed | Connection string not committed |
| Run `00_reset_puls_sanayi_seed.sql` | Passed | Local DB only |
| Run `01_load_puls_sanayi_seed.sql` | Passed | Dockerized `psql` fallback used |
| Run `02_validate_puls_sanayi_seed.sql` | Passed | Baseline proof |
| Run `03_generate_workflow_scenarios.sql` | Passed | Workflow scenario proof |
| Run `04_generate_performance_scenarios.sql` | Passed | Performance scenario proof |
| Run `07_validate_packaging_proof.sql` | Passed | Main packaging proof |
| Run `08_validate_ai_context_readiness.sql` | Passed | AI context proof |
| Run `09_validate_canias_connector_readiness.sql` | Passed | Canias metadata proof |
| Record sanitized results | Passed | See `13_local_supabase_packaging_auth_proof_results.md` |

### W2 — Mandatory Auth Persona Proof

| Persona | Purpose | Status | Notes |
|---------|---------|--------|-------|
| `admin_user_id` | Admin/settings/lifecycle smoke | Passed | Local auth UUID omitted from docs |
| `hr_admin_user_id` | Setup and HR admin routes | Passed | Local auth UUID omitted from docs |
| `manager_user_id` | Approval/performance manager proof | Passed | Local auth UUID omitted from docs |
| `employee_user_id` | Leave/expense/profile proof | Passed | Local auth UUID omitted from docs |
| `incomplete_setup_user_id` | Edge case | Passed | Optional local edge was staged |

Required scripts:

- `05_link_auth_personas_template.sql`
- `06_jwt_mutation_proof_smoke.sql`

PR13.8 is signed off locally. Do not fake the same auth proof remotely; PR13.9 still requires remote auth UUIDs.

### W3 — Remote Puls Teknik Tenant Proof

| Task | Status | Notes |
|------|--------|-------|
| Decide remote tenant strategy | Passed | Use fixed PR13 proof tenant with Puls Teknik A.S. label overlay; do not mutate PR13.4 CSV/manifest |
| Read-only remote inspect | Passed | Remote schemas/migrations present; Mert Teknik exists; fixed PR13 tenant absent |
| Prepare Puls Teknik A.S. tenant posture | Passed | `10_apply_puls_teknik_remote_posture.sql` labeled the fixed proof tenant |
| Run SQL proof remotely | Passed | Explicit `REMOTE_PROOF_CONFIRM` was required |
| Run auth proof remotely | Passed | Remote auth personas linked and JWT/RPC smoke passed |
| Record sanitized remote results | Passed | See `13_remote_puls_teknik_tenant_proof_results.md` |

### W4 — Demo-Off Route Smoke

| Route | Target Status | Smoke Status | Notes |
|-------|---------------|--------------|-------|
| `/dashboard` | demo_ready_core | Passed | Calc KPIs and queues |
| `/sirket-kurulum` | demo_ready_core | Passed | Setup readiness |
| `/calisanlar` | demo_ready_core | Passed | 120 employees |
| `/departmanlar` | demo_ready_core | Passed | PULS-owned + imported read-only |
| `/pozisyonlar` | demo_ready_core | Passed | PULS-owned + imported read-only |
| `/izin-tanimlari` | demo_ready_core | Passed | Types + lifecycle history |
| `/izin` | demo_ready_core | Passed | Balances + scenario requests |
| `/masraf-kategorileri` | demo_ready_core | Passed | Categories + cost center readiness |
| `/masraf` | demo_ready_core | Passed | Claims + policy status examples |
| `/performans` | demo_ready_core | Passed | DB-backed demo-ready, production depth limited |
| `/performans-parametreleri` | demo_ready_core | Passed | Params from seed |
| `/kariyer` | partial_v1 | Passed | Representative career profiles |
| `/egitim` | partial_v1 | Passed | Training needs baseline |
| `/is-degerleme` | placeholder_future | Passed | Future/not V1 |
| `/sozlesmeler` | demo_ready_core | Passed | Metadata/risk surface |
| `/profil` | requires_auth_persona | Passed | Linked employee persona |
| `/ayarlar` | partial_v1 | Passed | Hub/read-only settings |
| `/erp` | partial_v1 | Passed | Metadata/discovery only, no runtime |
| `/ai-koc` | partial_v1 | Passed | Context readiness, no live chat |
| `/menu` | demo_ready_core | Passed | Shell exception |

Smoke evidence should record:

- `VITE_PULS_DEMO_MODE=false`
- no visible demo pill where route uses `DemoSourcePill`
- expected core content present
- accepted gaps
- PR13.10 app fixes: `puls_core`-first persona resolver and persona-aware setup route guard

### W5 — Screen Readiness Truth Table + Demo Fallback Guard

For each route, record:

- user-facing purpose
- business logic completeness
- canonical DB objects / calc views
- seed/scenario coverage
- auth/persona requirement
- source posture
- readiness status
- accepted gap
- next owner

This is the document that answers: "What is actually ready, what is demo-ready, and what is future?"

#### Demo Fallback Guard Tasks

| Task | Status | Notes |
|------|--------|-------|
| List current `fetchDemo*` product-path imports | Passed | Baseline remains documented; not all dev fallback removed |
| Add guard for new `fetchDemo*` product additions | Passed | `check-13-demo-fallback-regression.sh` |
| Update retirement docs with final packaging posture | Passed | Demo fallback remains dev-only |
| Final PR13 closeout doc | Passed | Claims and non-claims recorded |

### W6 — Canias Customer Discovery

Do not implement runtime before these inputs exist:

- Canias export samples
- actual field names
- transport mode
- API/SOAP/file access details
- source-of-truth decisions
- leave balance ownership decision
- export/writeback expectation
- customer approval workflow

Current status: boundary/discovery ready, runtime blocked by missing customer inputs.

### W7 — Live AI / LLM Gateway

Do not implement live AI before:

- product decision on use cases
- model/provider decision
- security and logging policy
- vault/audit design
- human confirmation UX
- action/tool boundary enforcement

Current status: DB context readiness and action boundary ready; live runtime future.

## Final PR13 Claim Template

Use this when PR13 closes:

> PULS V1 has a DB-backed customer-demo packaging proof for the core product route set using Puls Sanayi A.S. seed data, scenario scripts, and demo mode off. ERP runtime and live AI are explicitly future work. Some screens are partial or future by design and are tracked in the V1 screen readiness truth table.

Do not say:

> Every screen is production complete.

Do not say:

> Canias integration is implemented.

Do not say:

> AI Coach is live.
