# PR13 Remaining Work Register

Living checklist for the remaining V1 packaging work. Use this instead of opening unbounded PRs.

## Working Rule

PR13 closeout is limited to proof, route smoke, and fallback hardening. New product features, deep domain completion, Canias runtime, live AI, SDK/API productization, and CRM integrations move to PR14+ unless they block a core demo route.

## Summary Board

| ID | Workstream | Status | Target | Blocker / Input |
|----|------------|--------|--------|-----------------|
| W1 | Remote DB seed/proof | Not started | PR13.8 | `DATABASE_URL` / target Postgres URI |
| W2 | Auth persona proof | Not started | PR13.8 | Dashboard users + UUIDs |
| W3 | Demo-off route smoke | Not started | PR13.9 | Remote proof complete |
| W4 | Screen readiness truth table | Not started | PR13.9 | Route smoke observations |
| W5 | Demo fallback guard | Not started | PR13.10 | Final route truth table |
| W6 | Canias customer discovery | Waiting | PR14+ | Customer export/API/data model |
| W7 | Live AI / LLM gateway | Waiting | PR14+ | Product decision + security boundary |
| W8 | Production hardening | Waiting | PR14+ | Post-demo acceptance |

## Detailed Checklist

### W1 — Remote DB Seed / Proof

| Task | Status | Notes |
|------|--------|-------|
| Confirm target Supabase/Postgres project | Pending | Do not commit connection string |
| Run `00_reset_puls_sanayi_seed.sql` | Pending | Target DB only |
| Run `01_load_puls_sanayi_seed.sql` | Pending | psql-local `\copy`; SQL Editor cannot read local CSV |
| Run `02_validate_puls_sanayi_seed.sql` | Pending | Baseline proof |
| Run `03_generate_workflow_scenarios.sql` | Pending | Workflow scenario proof |
| Run `04_generate_performance_scenarios.sql` | Pending | Performance scenario proof |
| Run `07_validate_packaging_proof.sql` | Pending | Main packaging proof |
| Run `08_validate_ai_context_readiness.sql` | Pending | AI context proof |
| Run `09_validate_canias_connector_readiness.sql` | Pending | Canias metadata proof |
| Record sanitized results | Pending | No secrets, no full connection strings |

### W2 — Auth Persona Proof

| Persona | Purpose | Status | Notes |
|---------|---------|--------|-------|
| `admin_user_id` | Admin/settings/lifecycle smoke | Pending | Create in Dashboard |
| `hr_admin_user_id` | Setup and HR admin routes | Pending | Create in Dashboard |
| `manager_user_id` | Approval/performance manager proof | Pending | Create in Dashboard |
| `employee_user_id` | Leave/expense/profile proof | Pending | Create in Dashboard |
| `incomplete_setup_user_id` | Edge case | Optional | Only if useful |

Required scripts:

- `05_link_auth_personas_template.sql`
- `06_jwt_mutation_proof_smoke.sql`

If persona UUIDs are unavailable, document as "not run" in PR13.8. Do not fake auth proof.

### W3 — Demo-Off Route Smoke

| Route | Target Status | Smoke Status | Notes |
|-------|---------------|--------------|-------|
| `/dashboard` | demo_ready_core | Pending | Calc KPIs and queues |
| `/sirket-kurulum` | demo_ready_core | Pending | Setup readiness |
| `/calisanlar` | demo_ready_core | Pending | 120 employees |
| `/departmanlar` | demo_ready_core | Pending | PULS-owned + imported read-only |
| `/pozisyonlar` | demo_ready_core | Pending | PULS-owned + imported read-only |
| `/izin-tanimlari` | demo_ready_core | Pending | Types + lifecycle history |
| `/izin` | demo_ready_core | Pending | Balances + scenario requests |
| `/masraf-kategorileri` | demo_ready_core | Pending | Categories + cost center readiness |
| `/masraf` | demo_ready_core | Pending | Claims + policy status examples |
| `/performans` | partial_v1 | Pending | Demo-ready, production depth limited |
| `/performans-parametreleri` | demo_ready_core | Pending | Params from seed |
| `/kariyer` | partial_v1 | Pending | Representative career profiles |
| `/egitim` | partial_v1 | Pending | Training needs baseline |
| `/is-degerleme` | placeholder_future | Pending | Future/not V1 |
| `/sozlesmeler` | demo_ready_core | Pending | Metadata/risk surface |
| `/profil` | requires_auth_persona | Pending | Needs linked employee |
| `/ayarlar` | partial_v1 | Pending | Hub/read-only settings |
| `/erp` | partial_v1 | Pending | Metadata/discovery only, no runtime |
| `/ai-koc` | partial_v1 | Pending | Context readiness, no live chat |
| `/menu` | demo_ready_core | Pending | Shell exception |

Smoke evidence should record:

- `VITE_PULS_DEMO_MODE=false`
- no visible demo pill where route uses `DemoSourcePill`
- expected core content present
- accepted gaps

### W4 — Screen Readiness Truth Table

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

### W5 — Demo Fallback Guard

| Task | Status | Notes |
|------|--------|-------|
| List current `fetchDemo*` product-path imports | Pending | Baseline only; not all must be removed |
| Add guard for new `fetchDemo*` product additions | Pending | Classification required |
| Update retirement docs with final packaging posture | Pending | Demo fallback remains dev-only |
| Final PR13 closeout doc | Pending | Claims and non-claims |

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

